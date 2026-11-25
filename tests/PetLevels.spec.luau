-- Pet levels (#90): equipped pets gain XP from play time, max level 10, +2 % bonus per
-- level above 1, merging keeps the highest level, equip best counts the level.
local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function levelConfig(features: { [string]: boolean }?): any
	local config = table.clone(TestConfig)
	config.features = features
	config.petVariants = {
		order = { "Normal", "Gold", "Rainbow" },
		Normal = { bonusMultiplier = 1 },
		Gold = { from = "Normal", count = 5, bonusMultiplier = 2.5 },
		Rainbow = { from = "Gold", count = 5, bonusMultiplier = 6 },
	}
	config.shinyPets = { chance = 1 / 200, bonusMultiplier = 1.5 }
	-- Level 1 -> 2 needs 10 XP, 2 -> 3 needs 20, ... 9 -> 10 needs 90.
	config.petLevels = {
		maxLevel = 10,
		bonusPerLevel = 0.02,
		xpPerSecond = 1,
		xpToNext = { 10, 20, 30, 40, 50, 60, 70, 80, 90 },
	}
	return config
end

local rules = GameRules.new(levelConfig())

local function approx(actual: number, expected: number)
	if math.abs(actual - expected) > 1e-9 then
		error(`expected {expected}, got {actual}`)
	end
end

-- A state with the given pets ({ petId, level?, xp?, variant?, shiny? }) as uids 1..n.
local function withPets(list: { any }, equipped: { number }?)
	local state = rules.newPlayerState()
	state.upgrades = { InventorySpace = 2, PetSlots = 2 }
	for i, spec in list do
		table.insert(state.pets, {
			uid = i,
			petId = spec[1],
			level = spec.level,
			xp = spec.xp,
			variant = spec.variant,
			shiny = spec.shiny,
		})
	end
	state.nextPetUid = #list + 1
	state.equipped = equipped or {}
	return state
end

local function petByUid(state: any, uid: number): any
	for _, pet in state.pets do
		if pet.uid == uid then
			return pet
		end
	end
	return nil
end

describe("pet level", function()
	it("is 1 with 0 XP for a new pet", function()
		local pet = { uid = 1, petId = "Cat" }
		expect(rules.petLevel(pet)).toBe(1)
		expect(rules.petXp(pet)).toBe(0)
		expect(rules.petXpNeeded(1)).toBe(10)
	end)

	it("is clamped to 1..maxLevel", function()
		expect(rules.petLevel({ uid = 1, petId = "Cat", level = 99 })).toBe(10)
		expect(rules.petLevel({ uid = 1, petId = "Cat", level = 0 })).toBe(1)
	end)

	it("needs no XP at the max level", function()
		expect(rules.petXpNeeded(10)).toBeNil()
	end)

	it("is always 1 without the config", function()
		local plain = GameRules.new(TestConfig)
		expect(plain.petLevel({ uid = 1, petId = "Cat", level = 5 })).toBe(1)
	end)
end)

describe("level bonus", function()
	it("adds +2 % per level above 1", function()
		approx(rules.levelMultiplier(1), 1)
		approx(rules.levelMultiplier(2), 1.02)
		approx(rules.levelMultiplier(10), 1.18)
	end)

	it("multiplies into the effective pet bonus (with variant and shiny)", function()
		approx(rules.petBonus({ uid = 1, petId = "Cat", level = 6 }), 0.2 * 1.1)
		approx(
			rules.petBonus({ uid = 1, petId = "Cat", level = 10, variant = "Gold", shiny = true }),
			0.2 * 2.5 * 1.5 * 1.18
		)
	end)

	it("counts in the coin multiplier", function()
		local state = withPets({ { "Cat", level = 10 }, { "Hamster" } }, { 1, 2 })
		approx(rules.petMultiplier(state), 1 + 0.2 * 1.18 + 0.1)
	end)

	it("is ignored while the feature is switched off", function()
		local off = GameRules.new(levelConfig({ petLevels = false }))
		approx(off.petBonus({ uid = 1, petId = "Cat", level = 10 }), 0.2)
		approx(off.levelMultiplier(10), 1)
	end)
end)

describe("collecting XP", function()
	it("gives XP from play time to equipped pets only", function()
		local state = withPets({ { "Cat" }, { "Hamster" } }, { 1 })
		local result = rules.addPetXp(state, 4)
		expect(result.ok).toBe(true)
		expect(petByUid(result.state, 1).xp).toBe(4)
		expect(petByUid(result.state, 2).xp).toBeNil()
		expect(#result.leveledUp).toBe(0)
	end)

	it("does not change the old state", function()
		local state = withPets({ { "Cat" } }, { 1 })
		rules.addPetXp(state, 5)
		expect(state.pets[1].xp).toBeNil()
	end)

	it("levels up and keeps the rest of the XP", function()
		local state = withPets({ { "Cat", xp = 8 } }, { 1 })
		local result = rules.addPetXp(state, 5)
		local pet = petByUid(result.state, 1)
		expect(pet.level).toBe(2)
		expect(pet.xp).toBe(3)
		expect(#result.leveledUp).toBe(1)
		expect(result.leveledUp[1].uid).toBe(1)
		expect(result.leveledUp[1].petId).toBe("Cat")
		expect(result.leveledUp[1].level).toBe(2)
	end)

	it("can climb several levels at once", function()
		local state = withPets({ { "Cat" } }, { 1 })
		local result = rules.addPetXp(state, 10 + 20 + 30 + 1)
		local pet = petByUid(result.state, 1)
		expect(pet.level).toBe(4)
		expect(pet.xp).toBe(1)
		expect(#result.leveledUp).toBe(1)
		expect(result.leveledUp[1].level).toBe(4)
	end)

	it("stops at level 10 and drops the XP there", function()
		local state = withPets({ { "Cat", level = 9, xp = 50 } }, { 1 })
		local result = rules.addPetXp(state, 1000)
		local pet = petByUid(result.state, 1)
		expect(pet.level).toBe(10)
		expect(pet.xp).toBeNil()
		local again = rules.addPetXp(result.state, 1000)
		expect(again.ok).toBe(true)
		expect(#again.leveledUp).toBe(0)
		expect(again.state).toBe(result.state)
	end)

	it("scales with xpPerSecond", function()
		local config = levelConfig()
		config.petLevels = table.clone(config.petLevels)
		config.petLevels.xpPerSecond = 2
		local fast = GameRules.new(config)
		local result = fast.addPetXp(withPets({ { "Cat" } }, { 1 }), 3)
		expect(result.state.pets[1].xp).toBe(6)
	end)

	it("keeps the state when no pet is equipped", function()
		local state = withPets({ { "Cat" } }, {})
		local result = rules.addPetXp(state, 10)
		expect(result.ok).toBe(true)
		expect(result.state).toBe(state)
	end)

	it("refuses invalid times", function()
		local state = withPets({ { "Cat" } }, { 1 })
		expect(rules.addPetXp(state, 0).reason).toBe("InvalidTime")
		expect(rules.addPetXp(state, -5).reason).toBe("InvalidTime")
		expect(rules.addPetXp(state, math.huge).reason).toBe("InvalidTime")
		expect(rules.addPetXp(state, 0 / 0).reason).toBe("InvalidTime")
	end)

	it("is refused while the feature is switched off", function()
		local off = GameRules.new(levelConfig({ petLevels = false }))
		local result = off.addPetXp(withPets({ { "Cat" } }, { 1 }), 10)
		expect(result.ok).toBe(false)
		expect(result.reason).toBe("FeatureOff")
	end)
end)

describe("merging keeps the highest level", function()
	it("gives the new pet the highest level and its XP", function()
		local state = withPets({
			{ "Cat", level = 3, xp = 5 },
			{ "Cat", level = 7, xp = 2 },
			{ "Cat", level = 7, xp = 9 },
			{ "Cat" },
			{ "Cat", level = 2 },
		})
		local result = rules.mergePets(state, "Cat", "Normal")
		expect(result.ok).toBe(true)
		local pet = result.pet :: any
		expect(pet.variant).toBe("Gold")
		expect(pet.level).toBe(7)
		expect(pet.xp).toBe(9)
		approx(rules.petBonus(pet), 0.2 * 2.5 * 1.12)
	end)

	it("stays level 1 without fields when all were level 1", function()
		local state = withPets({ { "Cat" }, { "Cat" }, { "Cat" }, { "Cat" }, { "Cat" } })
		local pet = rules.mergePets(state, "Cat", "Normal").pet :: any
		expect(pet.level).toBeNil()
		expect(pet.xp).toBeNil()
	end)

	it("keeps level 10 without XP", function()
		local state = withPets({ { "Cat", level = 10 }, { "Cat" }, { "Cat" }, { "Cat" }, { "Cat" } })
		local pet = rules.mergePets(state, "Cat", "Normal").pet :: any
		expect(pet.level).toBe(10)
		expect(pet.xp).toBeNil()
	end)
end)

describe("equip best with levels", function()
	it("prefers a higher level of the same pet", function()
		local state = withPets({ { "Cat" }, { "Cat", level = 5 }, { "Cat", level = 3 } })
		local equipped = rules.equipBest(state).state.equipped
		expect(equipped[1]).toBe(2)
		expect(equipped[2]).toBe(3)
		expect(equipped[3]).toBe(1)
	end)

	it("lets a high level beat a slightly better pet", function()
		local config = levelConfig()
		config.pets = table.clone(config.pets)
		config.pets.Rival = table.clone(config.pets.Cat)
		config.pets.Rival.bonus = 0.21
		local custom = GameRules.new(config)
		local state = custom.newPlayerState()
		state.pets = { { uid = 1, petId = "Rival" }, { uid = 2, petId = "Cat", level = 4 } }
		state.nextPetUid = 3
		expect(custom.equipBest(state).state.equipped[1]).toBe(2)
	end)
end)

describe("setting pet levels (admin)", function()
	it("sets the equipped pets' level and clears their XP", function()
		local state = withPets({ { "Cat", xp = 4 }, { "Hamster", level = 2 } }, { 1 })
		local result = rules.setPetLevels(state, 6, false)
		expect(result.ok).toBe(true)
		expect(petByUid(result.state, 1).level).toBe(6)
		expect(petByUid(result.state, 1).xp).toBeNil()
		expect(petByUid(result.state, 2).level).toBe(2)
	end)

	it("can set all pets, level 1 clears the field", function()
		local state = withPets({ { "Cat", level = 4 }, { "Hamster", level = 2 } }, {})
		local result = rules.setPetLevels(state, 1, true)
		expect(petByUid(result.state, 1).level).toBeNil()
		expect(petByUid(result.state, 2).level).toBeNil()
	end)

	it("refuses invalid levels and no pets", function()
		local state = withPets({ { "Cat" } }, { 1 })
		expect(rules.setPetLevels(state, 0, false).reason).toBe("InvalidLevel")
		expect(rules.setPetLevels(state, 11, false).reason).toBe("InvalidLevel")
		expect(rules.setPetLevels(state, 2.5, false).reason).toBe("InvalidLevel")
		expect(rules.setPetLevels(withPets({ { "Cat" } }, {}), 3, false).reason).toBe("NoPets")
	end)
end)
