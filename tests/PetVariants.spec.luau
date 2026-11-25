-- Pet variants (#80): 5 equal pets -> Gold (x2.5), 5 equal Gold -> Rainbow (x6), Shiny
-- (1 in 200 per hatched pet, +50 %, also as Gold/Rainbow) and the effective bonus.
local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local SHINY = 1 / 200

local function variantConfig(features: { [string]: boolean }?): any
	local config = table.clone(TestConfig)
	config.features = features
	config.petVariants = {
		order = { "Normal", "Gold", "Rainbow" },
		Normal = { bonusMultiplier = 1 },
		Gold = { from = "Normal", count = 5, bonusMultiplier = 2.5 },
		Rainbow = { from = "Gold", count = 5, bonusMultiplier = 6 },
	}
	config.shinyPets = { chance = SHINY, bonusMultiplier = 1.5 }
	config.potions = table.clone(TestConfig.potions)
	config.potions.Luck = table.clone(TestConfig.potions.Luck)
	config.potions.Luck.shinyChanceMultiplier = 2
	-- Stand-in for the shiny potion of #96: only the field is needed.
	config.potions.ShinyTest = { displayName = "Shiny", price = 1, durationSeconds = 60, shinyChanceMultiplier = 2 }
	return config
end

local rules = GameRules.new(variantConfig())

local function approx(actual: number, expected: number)
	if math.abs(actual - expected) > 1e-9 then
		error(`expected {expected}, got {actual}`)
	end
end

-- A state with the given pets ({ petId, variant?, shiny?, locked? }) as uids 1..n.
local function withPets(list: { any }, equipped: { number }?)
	local state = rules.newPlayerState()
	state.upgrades = { InventorySpace = 2, PetSlots = 2 }
	for i, spec in list do
		table.insert(state.pets, {
			uid = i,
			petId = spec[1],
			variant = spec.variant,
			shiny = spec.shiny,
			locked = spec.locked,
		})
	end
	state.nextPetUid = #list + 1
	state.equipped = equipped or {}
	return state
end

local function many(n: number, spec: any): { any }
	local list = {}
	for _ = 1, n do
		table.insert(list, table.clone(spec))
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

describe("pet bonus", function()
	it("is the config bonus for a normal pet", function()
		approx(rules.petBonus({ uid = 1, petId = "Cat" }), 0.2)
		approx(rules.petBonus({ uid = 1, petId = "Cat", variant = "Normal" }), 0.2)
	end)

	it("is x2.5 for Gold and x6 for Rainbow", function()
		approx(rules.petBonus({ uid = 1, petId = "Cat", variant = "Gold" }), 0.5)
		approx(rules.petBonus({ uid = 1, petId = "Cat", variant = "Rainbow" }), 1.2)
	end)

	it("adds +50 % for Shiny, also on top of Gold and Rainbow", function()
		approx(rules.petBonus({ uid = 1, petId = "Cat", shiny = true }), 0.3)
		approx(rules.petBonus({ uid = 1, petId = "Cat", variant = "Gold", shiny = true }), 0.75)
		approx(rules.petBonus({ uid = 1, petId = "Cat", variant = "Rainbow", shiny = true }), 1.8)
	end)

	it("counts in the coin multiplier of equipped pets", function()
		local state = withPets({ { "Cat", variant = "Gold" }, { "Hamster", shiny = true }, { "Dragon" } }, { 1, 2 })
		approx(rules.petMultiplier(state), 1 + 0.5 + 0.15)
	end)

	it("ignores variants and shiny without their config", function()
		local plain = GameRules.new(TestConfig)
		approx(plain.petBonus({ uid = 1, petId = "Cat", variant = "Gold", shiny = true }), 0.2)
	end)
end)

describe("equip best", function()
	it("ranks by effective bonus", function()
		-- Dragon 1.5 > Rainbow Cat 1.2 > Gold Shiny Hamster 0.375 > Cat 0.2.
		local state = withPets({
			{ "Cat" },
			{ "Hamster", variant = "Gold", shiny = true },
			{ "Cat", variant = "Rainbow" },
			{ "Dragon" },
			{ "Hamster" },
		})
		state.upgrades = { InventorySpace = 2 } -- 3 pet slots
		local result = rules.equipBest(state)
		expect(result.ok).toBe(true)
		expect(result.state.equipped).toEqual({ 4, 3, 2 })
	end)

	it("prefers a Rainbow pet over a stronger base pet when its bonus is higher", function()
		local state = withPets({ { "Dragon" }, { "Cat", variant = "Rainbow", shiny = true } })
		state.upgrades = { InventorySpace = 2 }
		-- Rainbow shiny Cat: 0.2 x 6 x 1.5 = 1.8 > Dragon 1.5.
		expect(rules.equipBest(state).state.equipped).toEqual({ 2, 1 })
	end)
end)

describe("shiny chance", function()
	it("is 1 in 200", function()
		approx(rules.shinyChance(rules.newPlayerState()), SHINY)
		approx(rules.shinyChance(nil), SHINY)
	end)

	it("is raised by the luck potion and multiplied by every running shiny potion", function()
		local state = rules.newPlayerState()
		state.activePotions = { Luck = 100 }
		approx(rules.shinyChance(state), 2 * SHINY)
		state.activePotions = { Luck = 100, ShinyTest = 10 }
		approx(rules.shinyChance(state), 4 * SHINY)
		state.activePotions = { Luck = 0, ShinyTest = 10 }
		approx(rules.shinyChance(state), 2 * SHINY)
	end)

	it("uses the admin test chance when it is higher, at most 1", function()
		local state = rules.newPlayerState()
		state.adminShinyChance = 1
		expect(rules.shinyChance(state)).toBe(1)
		state.adminShinyChance = 0.0001
		approx(rules.shinyChance(state), SHINY)
	end)

	it("is 0 while shinyPets is off or without the config", function()
		local off = GameRules.new(variantConfig({ shinyPets = false }))
		expect(off.shinyChance(off.newPlayerState())).toBe(0)
		local plain = GameRules.new(TestConfig)
		expect(plain.shinyChance(plain.newPlayerState())).toBe(0)
	end)
end)

describe("shiny roll when hatching", function()
	local function rich()
		local state = rules.newPlayerState()
		state.coins = 1000
		state.upgrades = { InventorySpace = 2, TripleOpen = 1 }
		return state
	end

	it("makes the pet Shiny when the roll after the draw is below the chance", function()
		-- Draw 0 -> Hamster, then shiny roll 0.004 < 0.005.
		local result = rules.openEgg(rich(), "TestEgg", TestKit.sequenceRandom({ 0, 0.004 }))
		expect(result.ok).toBe(true)
		expect(result.pet.petId).toBe("Hamster")
		expect(result.pet.shiny).toBe(true)
		expect(result.state.pets[1].shiny).toBe(true)
	end)

	it("leaves the pet normal when the roll misses (no shiny field)", function()
		local result = rules.openEgg(rich(), "TestEgg", TestKit.sequenceRandom({ 0, 0.005 }))
		expect(result.pet.shiny).toBe(nil)
		expect(result.pet).toEqual({ uid = 1, petId = "Hamster" })
	end)

	it("rolls once per pet when opening three", function()
		local result = rules.openEggs(rich(), "TestEgg", 3, TestKit.sequenceRandom({ 0, 0.9, 0.8, 0.001, 0, 0.9 }))
		expect(result.ok).toBe(true)
		expect(result.pets[1].shiny).toBe(nil)
		expect(result.pets[2].petId).toBe("Cat")
		expect(result.pets[2].shiny).toBe(true)
		expect(result.pets[3].shiny).toBe(nil)
		expect(result.state.nextPetUid).toBe(4)
	end)

	it("does not roll while shinyPets is off", function()
		local off = GameRules.new(variantConfig({ shinyPets = false }))
		local state = off.newPlayerState()
		state.coins = 100
		local result = off.openEgg(state, "TestEgg", TestKit.sequenceRandom({ 0, 0 }))
		expect(result.pet.shiny).toBe(nil)
	end)
end)

describe("merge groups", function()
	it("counts equal pets per petId and variant, without locked ones", function()
		local state = withPets({
			{ "Cat" },
			{ "Cat", shiny = true },
			{ "Cat", locked = true },
			{ "Cat", variant = "Gold" },
			{ "Hamster" },
			{ "Hamster", variant = "Rainbow" },
		})
		local groups = rules.mergeGroups(state.pets)
		expect(groups).toEqual({
			{ petId = "Cat", variant = "Normal", target = "Gold", have = 2, need = 5 },
			{ petId = "Cat", variant = "Gold", target = "Rainbow", have = 1, need = 5 },
			{ petId = "Hamster", variant = "Normal", target = "Gold", have = 1, need = 5 },
		})
		expect(rules.canMergeAny(state.pets)).toBe(false)
	end)

	it("reports a ready group", function()
		local state = withPets(many(5, { "Cat" }))
		expect(rules.canMergeAny(state.pets)).toBe(true)
	end)

	it("is empty while petMerge is off", function()
		local off = GameRules.new(variantConfig({ petMerge = false }))
		local state = withPets(many(5, { "Cat" }))
		expect(off.mergeGroups(state.pets)).toEqual({})
		expect(off.canMergeAny(state.pets)).toBe(false)
	end)
end)

describe("mergePets", function()
	it("turns 5 equal normal pets into one Gold pet", function()
		local state = withPets({ { "Cat" }, { "Cat" }, { "Hamster" }, { "Cat" }, { "Cat" }, { "Cat" } })
		local result = rules.mergePets(state, "Cat", "Normal")
		expect(result.ok).toBe(true)
		expect(result.consumed).toEqual({ 1, 2, 4, 5, 6 })
		expect(result.pet).toEqual({ uid = 7, petId = "Cat", variant = "Gold" })
		expect(#result.state.pets).toBe(2)
		expect(result.state.pets[1].petId).toBe("Hamster")
		expect(result.state.pets[2]).toEqual(result.pet)
		expect(result.state.nextPetUid).toBe(8)
		-- Old state untouched.
		expect(#state.pets).toBe(6)
	end)

	it("turns 5 equal Gold pets into one Rainbow pet", function()
		local result = rules.mergePets(withPets(many(5, { "Dragon", variant = "Gold" })), "Dragon", "Gold")
		expect(result.ok).toBe(true)
		expect(result.pet.variant).toBe("Rainbow")
		expect(#result.state.pets).toBe(1)
		approx(rules.petBonus(result.pet), 1.5 * 6)
	end)

	it("uses the 5 oldest unequipped pets first", function()
		local state = withPets(many(7, { "Cat" }), { 1, 2 })
		local result = rules.mergePets(state, "Cat", "Normal")
		expect(result.consumed).toEqual({ 3, 4, 5, 6, 7 })
		expect(result.state.equipped).toEqual({ 1, 2 })
	end)

	it("unequips used pets and puts the new pet into the first freed slot", function()
		local state = withPets({ { "Hamster" }, { "Cat" }, { "Cat" }, { "Cat" }, { "Cat" }, { "Cat" } }, { 1, 3, 5 })
		state.upgrades = { InventorySpace = 2 }
		local result = rules.mergePets(state, "Cat", "Normal")
		expect(result.ok).toBe(true)
		expect(result.state.equipped).toEqual({ 1, 7 })
		approx(rules.petMultiplier(result.state), 1 + 0.1 + 0.5)
	end)

	it("never uses locked pets", function()
		local list = many(5, { "Cat" })
		list[2].locked = true
		local result = rules.mergePets(withPets(list), "Cat", "Normal")
		expect(result.ok).toBe(false)
		expect(result.reason).toBe("NotEnoughPets")

		table.insert(list, { "Cat" })
		local ok = rules.mergePets(withPets(list), "Cat", "Normal")
		expect(ok.ok).toBe(true)
		expect(ok.consumed).toEqual({ 1, 3, 4, 5, 6 })
		expect(find(ok.state, 2).locked).toBe(true)
	end)

	it("does not mix variants", function()
		local list = many(4, { "Cat" })
		table.insert(list, { "Cat", variant = "Gold" })
		local result = rules.mergePets(withPets(list), "Cat", "Normal")
		expect(result.reason).toBe("NotEnoughPets")
	end)

	it("keeps Shiny: one Shiny among the 5 makes the new pet Shiny, other Shinies stay", function()
		local list = many(5, { "Cat" })
		table.insert(list, 2, { "Cat", shiny = true })
		table.insert(list, { "Cat", shiny = true })
		-- uids: 2 and 7 are shiny; 1, 3, 4, 5, 6 are normal.
		local result = rules.mergePets(withPets(list), "Cat", "Normal")
		expect(result.ok).toBe(true)
		expect(result.consumed).toEqual({ 2, 1, 3, 4, 5 })
		expect(result.pet.shiny).toBe(true)
		expect(result.pet.variant).toBe("Gold")
		expect(find(result.state, 7).shiny).toBe(true)
		expect(find(result.state, 6)).toEqual({ uid = 6, petId = "Cat" })
		approx(rules.petBonus(result.pet), 0.2 * 2.5 * 1.5)
	end)

	it("uses more Shinies only when there are not enough normal ones", function()
		local result = rules.mergePets(withPets(many(5, { "Cat", shiny = true })), "Cat", "Normal")
		expect(result.ok).toBe(true)
		expect(result.pet.shiny).toBe(true)
	end)

	it("fails without enough pets, for unknown pets and variants and for Rainbow", function()
		local state = withPets(many(4, { "Cat" }))
		expect(rules.mergePets(state, "Cat", "Normal").reason).toBe("NotEnoughPets")
		expect(rules.mergePets(state, "Unicorn", "Normal").reason).toBe("UnknownPet")
		expect(rules.mergePets(state, "Cat", "Silver").reason).toBe("UnknownVariant")
		expect(rules.mergePets(state, "Cat", 3 :: any).reason).toBe("UnknownVariant")
		expect(rules.mergePets(state, 3 :: any, "Normal").reason).toBe("UnknownPet")
		local rainbow = withPets(many(5, { "Cat", variant = "Rainbow" }))
		expect(rules.mergePets(rainbow, "Cat", "Rainbow").reason).toBe("MaxVariant")
		local failed = rules.mergePets(state, "Cat", "Normal")
		expect(failed.ok).toBe(false)
		expect(failed.state).toBe(state)
		expect(failed.consumed).toEqual({})
	end)

	it("is refused while petMerge is off", function()
		local off = GameRules.new(variantConfig({ petMerge = false }))
		local result = off.mergePets(withPets(many(5, { "Cat" })), "Cat", "Normal")
		expect(result.ok).toBe(false)
		expect(result.reason).toBe("FeatureOff")
	end)

	it("merged pets survive saving like other pets", function()
		local result = rules.mergePets(withPets(many(5, { "Cat", shiny = true })), "Cat", "Normal")
		local SaveData = require("../src/shared/SaveData")
		local loaded = SaveData.load(result.state, rules.newPlayerState())
		expect(loaded.ok).toBe(true)
		expect(loaded.state.pets[1]).toEqual({ uid = 6, petId = "Cat", variant = "Gold", shiny = true })
	end)
end)

describe("givePets", function()
	it("adds pets with variant and shiny within the inventory limit", function()
		local state = rules.newPlayerState()
		state.upgrades = { InventorySpace = 2 }
		local result = rules.givePets(state, "Cat", 2, "Rainbow", true)
		expect(result.ok).toBe(true)
		expect(result.state.pets).toEqual({
			{ uid = 1, petId = "Cat", variant = "Rainbow", shiny = true },
			{ uid = 2, petId = "Cat", variant = "Rainbow", shiny = true },
		})
		expect(rules.givePets(state, "Cat", 1, "Normal", false).state.pets[1]).toEqual({ uid = 1, petId = "Cat" })
		expect(rules.givePets(state, "Cat", 11).reason).toBe("InventoryFull")
		expect(rules.givePets(state, "Cat", 1, "Silver").reason).toBe("UnknownVariant")
		expect(rules.givePets(state, "Nope", 1).reason).toBe("UnknownPet")
	end)
end)
