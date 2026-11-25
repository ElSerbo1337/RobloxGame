-- Pet management (#91): auto-delete by rarity when hatching, deleting several pets at
-- once, locks, 3 saved pet teams, renaming, "ever owned" (for the pet index) and foundAt.
local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function managementConfig(features: { [string]: boolean }?): any
	local config = table.clone(TestConfig)
	config.features = features
	config.petVariants = {
		order = { "Normal", "Gold", "Rainbow" },
		Normal = { bonusMultiplier = 1 },
		Gold = { from = "Normal", count = 5, bonusMultiplier = 2.5 },
		Rainbow = { from = "Gold", count = 5, bonusMultiplier = 6 },
	}
	config.shinyPets = { chance = 1 / 200, bonusMultiplier = 1.5 }
	config.rarities = table.clone(TestConfig.rarities)
	config.rarities.Secret = { displayName = "Geheim", order = 7, color = { 0, 255, 200 } }
	config.pets = table.clone(TestConfig.pets)
	config.pets.Ghost = { displayName = "Geist", rarity = "Secret", bonus = 5 }
	config.petManagement = { teams = 3, nameMaxLength = 10, noAutoDelete = { "Secret" } }
	return config
end

local rules = GameRules.new(managementConfig())

-- A state with the given pets ({ petId, locked?, shiny? }) as uids 1..n, 10 inventory
-- slots and 5 pet slots.
local function withPets(list: { any }, equipped: { number }?)
	local state = rules.newPlayerState()
	state.upgrades = { InventorySpace = 2, PetSlots = 2 }
	for i, spec in list do
		table.insert(state.pets, { uid = i, petId = spec[1], locked = spec.locked, shiny = spec.shiny })
	end
	state.nextPetUid = #list + 1
	state.equipped = equipped or {}
	return state
end

local function uids(state): { number }
	local list = {}
	for _, pet in state.pets do
		table.insert(list, pet.uid)
	end
	return list
end

local function find(state, uid: number)
	for _, pet in state.pets do
		if pet.uid == uid then
			return pet
		end
	end
	return nil
end

-- Random values that draw Hamster (Common), Cat (Rare), Dragon (Mythic) from TestEgg
-- (no shiny roll needed: shiny chance 1/200 misses with 0.9).
local HAMSTER, CAT, DRAGON, NO_SHINY = 0.1, 0.8, 0.999, 0.9

describe("new player state", function()
	it("starts with no auto-delete, nothing owned and 3 empty teams", function()
		local state = rules.newPlayerState()
		expect(state.autoDelete).toEqual({})
		expect(state.petsOwnedEver).toEqual({})
		expect(state.petTeams).toEqual({ {}, {}, {} })
	end)
end)

describe("lock", function()
	it("locks and unlocks a pet (sparse field)", function()
		local state = withPets({ { "Cat" } })
		local locked = rules.setPetLocked(state, 1, true)
		expect(locked.ok).toBe(true)
		expect(locked.state.pets[1].locked).toBe(true)
		expect(state.pets[1].locked).toBeNil()
		local unlocked = rules.setPetLocked(locked.state, 1, false)
		expect(unlocked.ok).toBe(true)
		expect(unlocked.state.pets[1].locked).toBeNil()
	end)

	it("rejects unknown pets, non-boolean values and no change", function()
		local state = withPets({ { "Cat" } })
		expect(rules.setPetLocked(state, 9, true).reason).toBe("UnknownPet")
		expect(rules.setPetLocked(state, 1, "yes" :: any).reason).toBe("InvalidValue")
		expect(rules.setPetLocked(state, 1, false).reason).toBe("Unchanged")
	end)

	it("protects from deleting", function()
		local state = withPets({ { "Cat", locked = true } })
		local result = rules.deletePet(state, 1)
		expect(result.ok).toBe(false)
		expect(result.reason).toBe("PetLocked")
	end)

	it("protects from merging", function()
		local list = {}
		for i = 1, 5 do
			list[i] = { "Cat", locked = i == 1 }
		end
		local state = withPets(list)
		expect(rules.mergePets(state, "Cat", "Normal").reason).toBe("NotEnoughPets")
	end)

	it("protects from auto-delete", function()
		local state = withPets({ { "Cat", locked = true } })
		state.autoDelete = { Rare = true }
		state.coins = 100
		-- A hatched pet is never locked yet, so auto-delete still takes the new one ...
		local result = rules.openEggs(state, "TestEgg", 1, TestKit.sequenceRandom({ CAT, NO_SHINY }))
		expect(result.autoDeleted).toEqual({ true })
		-- ... and the locked one stays.
		expect(uids(result.state)).toEqual({ 1 })
	end)

	it("is ignored while the petLock switch is off (and refused)", function()
		local off = GameRules.new(managementConfig({ petLock = false }))
		local state = withPets({ { "Cat", locked = true } })
		expect(off.isPetLocked(state.pets[1])).toBe(false)
		expect(off.deletePet(state, 1).ok).toBe(true)
		expect(off.setPetLocked(state, 1, false).reason).toBe("FeatureOff")
	end)
end)

describe("delete several pets", function()
	it("deletes all chosen pets, puts equipped ones away and removes them from teams", function()
		local state = withPets({ { "Cat" }, { "Hamster" }, { "Dragon" }, { "Cat" } }, { 1, 3 })
		state.petTeams = { { 1, 3 }, { 2 }, {} }
		local result = rules.deletePets(state, { 1, 2, 2 })
		expect(result.ok).toBe(true)
		expect(result.deleted).toBe(2)
		expect(uids(result.state)).toEqual({ 3, 4 })
		expect(result.state.equipped).toEqual({ 3 })
		expect(result.state.petTeams).toEqual({ { 3 }, {}, {} })
		-- The old state is untouched.
		expect(#state.pets).toBe(4)
	end)

	it("is all or nothing", function()
		local state = withPets({ { "Cat" }, { "Hamster", locked = true } })
		expect(rules.deletePets(state, { 1, 2 }).reason).toBe("PetLocked")
		expect(rules.deletePets(state, { 1, 7 }).reason).toBe("UnknownPet")
		expect(rules.deletePets(state, { 1, "x" :: any }).reason).toBe("UnknownPet")
		expect(rules.deletePets(state, {}).reason).toBe("InvalidCount")
		expect(rules.deletePets(state, { 1, 1, 1 }).reason).toBe("InvalidCount")
		expect(rules.deletePets(state, nil :: any).reason).toBe("InvalidCount")
	end)

	it("is refused while the switch is off", function()
		local off = GameRules.new(managementConfig({ petMultiDelete = false }))
		expect(off.deletePets(withPets({ { "Cat" } }), { 1 }).reason).toBe("FeatureOff")
	end)

	it("single delete also cleans the teams", function()
		local state = withPets({ { "Cat" }, { "Hamster" } })
		state.petTeams = { { 1, 2 }, { 1 }, {} }
		local result = rules.deletePet(state, 1)
		expect(result.state.petTeams).toEqual({ { 2 }, {}, {} })
	end)
end)

describe("auto-delete", function()
	it("ticks and unticks rarities (sparse)", function()
		local state = rules.newPlayerState()
		local on = rules.setAutoDelete(state, "Common", true)
		expect(on.ok).toBe(true)
		expect(on.state.autoDelete).toEqual({ Common = true })
		expect(state.autoDelete).toEqual({})
		local off = rules.setAutoDelete(on.state, "Common", false)
		expect(off.state.autoDelete).toEqual({})
	end)

	it("rejects unknown rarities, Secret, bad values and no change", function()
		local state = rules.newPlayerState()
		expect(rules.setAutoDelete(state, "Ultra", true).reason).toBe("UnknownRarity")
		expect(rules.setAutoDelete(state, "Secret", true).reason).toBe("AutoDeleteBlocked")
		expect(rules.setAutoDelete(state, "Common", 1 :: any).reason).toBe("InvalidValue")
		expect(rules.setAutoDelete(state, "Common", false).reason).toBe("Unchanged")
	end)

	it("lists the rarities that can be ticked, common first, without Secret", function()
		expect(rules.autoDeleteRarities()).toEqual({ "Common", "Rare", "Mythic" })
	end)

	it("deletes hatched pets of a ticked rarity and keeps the others", function()
		local state = rules.newPlayerState()
		state.coins = 100
		state.upgrades = { TripleOpen = 1 }
		state.autoDelete = { Common = true }
		local result = rules.openEggs(
			state,
			"TestEgg",
			3,
			TestKit.sequenceRandom({ HAMSTER, NO_SHINY, CAT, NO_SHINY, HAMSTER, NO_SHINY }),
			1000
		)
		expect(result.ok).toBe(true)
		expect(#result.pets).toBe(3)
		expect(result.autoDeleted).toEqual({ true, false, true })
		expect(#result.state.pets).toBe(1)
		expect(result.state.pets[1].petId).toBe("Cat")
		-- Still paid for all eggs, uids stay unique, the eggs count for quests/tutorial.
		expect(result.state.coins).toBe(70)
		expect(result.state.nextPetUid).toBe(4)
		expect(result.state.pets[1].uid).toBe(2)
	end)

	it("counts auto-deleted pets as ever owned (pet index)", function()
		local state = rules.newPlayerState()
		state.coins = 100
		state.autoDelete = { Common = true }
		local result = rules.openEggs(state, "TestEgg", 1, TestKit.sequenceRandom({ HAMSTER, NO_SHINY }))
		expect(#result.state.pets).toBe(0)
		expect(rules.hasOwnedPet(result.state, "Hamster")).toBe(true)
		expect(rules.hasOwnedPet(result.state, "Cat")).toBe(false)
	end)

	it("never deletes Shiny pets", function()
		local state = rules.newPlayerState()
		state.coins = 100
		state.autoDelete = { Common = true }
		state.adminShinyChance = 1
		local result = rules.openEggs(state, "TestEgg", 1, TestKit.sequenceRandom({ HAMSTER, 0.5 }))
		expect(result.autoDeleted).toEqual({ false })
		expect(result.state.pets[1].shiny).toBe(true)
	end)

	it("still needs free inventory space for every egg", function()
		local state = withPets({ { "Cat" }, { "Cat" }, { "Cat" }, { "Cat" }, { "Cat" } })
		state.upgrades = {}
		state.coins = 100
		state.autoDelete = { Common = true }
		expect(rules.openEggs(state, "TestEgg", 1, TestKit.sequenceRandom({ HAMSTER })).reason).toBe("InventoryFull")
	end)

	it("does nothing while the switch is off", function()
		local off = GameRules.new(managementConfig({ petAutoDelete = false }))
		local state = off.newPlayerState()
		state.coins = 100
		state.autoDelete = { Common = true }
		local result = off.openEggs(state, "TestEgg", 1, TestKit.sequenceRandom({ HAMSTER, NO_SHINY }))
		expect(result.autoDeleted).toEqual({ false })
		expect(#result.state.pets).toBe(1)
		expect(off.setAutoDelete(state, "Rare", true).reason).toBe("FeatureOff")
	end)
end)

describe("ever owned and found at", function()
	it("records hatched pets with their found time", function()
		local state = rules.newPlayerState()
		state.coins = 100
		local result = rules.openEggs(state, "TestEgg", 1, TestKit.sequenceRandom({ DRAGON, NO_SHINY }), 1234)
		expect(result.state.pets[1].foundAt).toBe(1234)
		expect(result.state.petsOwnedEver).toEqual({ Dragon = true })
		expect(state.petsOwnedEver).toEqual({})
	end)

	it("keeps counting a pet after it was deleted", function()
		local state = rules.givePets(rules.newPlayerState(), "Cat", 1, nil, nil, 50).state
		expect(state.pets[1].foundAt).toBe(50)
		local deleted = rules.deletePet(state, state.pets[1].uid).state
		expect(#deleted.pets).toBe(0)
		expect(rules.hasOwnedPet(deleted, "Cat")).toBe(true)
	end)

	it("counts pets in the inventory of old saves", function()
		local state = withPets({ { "Cat" } })
		state.petsOwnedEver = {}
		expect(rules.hasOwnedPet(state, "Cat")).toBe(true)
	end)

	it("gives a merged pet its own found time", function()
		local list = {}
		for i = 1, 5 do
			list[i] = { "Cat" }
		end
		local result = rules.mergePets(withPets(list), "Cat", "Normal", 777)
		expect((result.pet :: any).foundAt).toBe(777)
	end)
end)

describe("teams", function()
	it("saves the equipped pets as a team", function()
		local state = withPets({ { "Cat" }, { "Hamster" }, { "Dragon" } }, { 3, 1 })
		local result = rules.saveTeam(state, 2)
		expect(result.ok).toBe(true)
		expect(result.state.petTeams).toEqual({ {}, { 3, 1 }, {} })
		expect(state.petTeams).toEqual({ {}, {}, {} })
	end)

	it("equips a saved team (replaces the equipped pets)", function()
		local state = withPets({ { "Cat" }, { "Hamster" }, { "Dragon" } }, { 2 })
		state.petTeams = { { 3, 1 }, {}, {} }
		local result = rules.equipTeam(state, 1)
		expect(result.ok).toBe(true)
		expect(result.state.equipped).toEqual({ 3, 1 })
	end)

	it("skips pets that are gone and stops at the pet slots", function()
		local state = withPets({ { "Cat" }, { "Hamster" }, { "Dragon" }, { "Cat" }, { "Cat" }, { "Cat" } })
		state.petTeams = { { 9, 1, 2, 3, 4, 5, 6 }, {}, {} }
		expect(rules.petTeam(state, 1)).toEqual({ 1, 2, 3, 4, 5, 6 })
		local result = rules.equipTeam(state, 1)
		expect(result.state.equipped).toEqual({ 1, 2, 3, 4, 5 })
	end)

	it("rejects unknown and empty teams and saving without equipped pets", function()
		local state = withPets({ { "Cat" } })
		expect(rules.saveTeam(state, 1).reason).toBe("NoPets")
		state.equipped = { 1 }
		expect(rules.saveTeam(state, 4).reason).toBe("UnknownTeam")
		expect(rules.saveTeam(state, 1.5).reason).toBe("UnknownTeam")
		expect(rules.equipTeam(state, 0).reason).toBe("UnknownTeam")
		expect(rules.equipTeam(state, 1).reason).toBe("EmptyTeam")
		state.petTeams = { { 9 }, {}, {} }
		expect(rules.equipTeam(state, 1).reason).toBe("EmptyTeam")
	end)

	it("follow merges: the new pet takes the place of the first used pet", function()
		local list = {}
		for i = 1, 6 do
			list[i] = { "Cat" }
		end
		local state = withPets(list)
		state.petTeams = { { 2, 6 }, { 6 }, { 1, 3 } }
		local result = rules.mergePets(state, "Cat", "Normal")
		local newUid = (result.pet :: any).uid
		-- Uids 1-5 are used (unequipped, oldest first).
		expect(result.consumed).toEqual({ 1, 2, 3, 4, 5 })
		expect(result.state.petTeams).toEqual({ { newUid, 6 }, { 6 }, { newUid } })
	end)

	it("work with teams saved in old states (missing field)", function()
		local state = withPets({ { "Cat" } }, { 1 })
		state.petTeams = nil :: any
		expect(rules.saveTeam(state, 3).state.petTeams).toEqual({ {}, {}, { 1 } })
		expect(rules.equipTeam(state, 1).reason).toBe("EmptyTeam")
	end)

	it("are refused while the switch is off", function()
		local off = GameRules.new(managementConfig({ petTeams = false }))
		local state = withPets({ { "Cat" } }, { 1 })
		expect(off.saveTeam(state, 1).reason).toBe("FeatureOff")
		expect(off.equipTeam(state, 1).reason).toBe("FeatureOff")
	end)
end)

describe("rename", function()
	it("sets a trimmed name and clears it with an empty one", function()
		local state = withPets({ { "Cat" } })
		local named = rules.renamePet(state, 1, "  Mietzi ")
		expect(named.ok).toBe(true)
		expect(find(named.state, 1).name).toBe("Mietzi")
		expect(state.pets[1].name).toBeNil()
		local cleared = rules.renamePet(named.state, 1, "   ")
		expect(cleared.ok).toBe(true)
		expect(find(cleared.state, 1).name).toBeNil()
	end)

	it("counts characters, not bytes", function()
		local state = withPets({ { "Cat" } })
		expect(rules.renamePet(state, 1, "Käsekätzchen" :: any).reason).toBe("InvalidName") -- 12 > 10
		expect(rules.renamePet(state, 1, "Kätzchenää").ok).toBe(true) -- exactly 10
	end)

	it("rejects bad names, unknown pets and no change", function()
		local state = withPets({ { "Cat" } })
		expect(rules.renamePet(state, 1, 5 :: any).reason).toBe("InvalidName")
		expect(rules.renamePet(state, 1, "a\nb").reason).toBe("InvalidName")
		expect(rules.renamePet(state, 1, "\255\254").reason).toBe("InvalidName")
		expect(rules.renamePet(state, 2, "Bob").reason).toBe("UnknownPet")
		expect(rules.renamePet(state, 1, "").reason).toBe("Unchanged")
	end)

	it("works on locked pets and is refused while the switch is off", function()
		local state = withPets({ { "Cat", locked = true } })
		expect(rules.renamePet(state, 1, "Bob").ok).toBe(true)
		local off = GameRules.new(managementConfig({ petRename = false }))
		expect(off.renamePet(state, 1, "Bob").reason).toBe("FeatureOff")
	end)

	it("knows the longest name", function()
		expect(rules.petNameMaxLength()).toBe(10)
	end)
end)

describe("rebirth", function()
	it("keeps locks, names, teams, auto-delete and ever owned", function()
		local state = withPets({ { "Cat", locked = true } }, { 1 })
		state.pets[1].name = "Bob"
		state.petTeams = { { 1 }, {}, {} }
		state.autoDelete = { Common = true }
		state.petsOwnedEver = { Cat = true, Hamster = true }
		state.coins = 1e12
		local result = rules.rebirth(state, 0)
		expect(result.ok).toBe(true)
		expect(result.state.pets[1].locked).toBe(true)
		expect(result.state.pets[1].name).toBe("Bob")
		expect(result.state.petTeams).toEqual({ { 1 }, {}, {} })
		expect(result.state.autoDelete).toEqual({ Common = true })
		expect(result.state.petsOwnedEver).toEqual({ Cat = true, Hamster = true })
	end)
end)
