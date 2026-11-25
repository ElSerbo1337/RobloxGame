-- Secret pets (#81): rarity "Secret" above Mythic, one pet per world, 1 in 20,000 per
-- egg, doubled by the luck potion.
local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local CHANCE = 1 / 20000

-- TestConfig with a Secret pet in world 1 (none in world 2) and a luck potion that doubles it.
local function secretConfig(features: { [string]: boolean }?): any
	local config = table.clone(TestConfig)
	config.features = features
	config.secretPets = { chance = CHANCE }
	config.rarities = table.clone(TestConfig.rarities)
	config.rarities.Secret = { displayName = "Geheim", order = 7, color = { 0, 230, 200 } }
	config.pets = table.clone(TestConfig.pets)
	config.pets.GhostPet = { displayName = "Geist", rarity = "Secret", bonus = 5 }
	config.potions = table.clone(TestConfig.potions)
	config.potions.Luck = table.clone(TestConfig.potions.Luck)
	config.potions.Luck.rarityWeights = { Rare = 2, Mythic = 3, Secret = 2 }
	config.worlds = table.clone(TestConfig.worlds)
	config.worlds[1] = table.clone(TestConfig.worlds[1])
	config.worlds[1].secretPet = "GhostPet"
	return config
end

local rules = GameRules.new(secretConfig())

local function rich(r)
	local state = r.newPlayerState()
	state.coins = 10000
	state.upgrades = { InventorySpace = 2 }
	return state
end

local function withLuck(state)
	local newState = table.clone(state)
	newState.activePotions = { Luck = 600 }
	return newState
end

local function approx(actual: number, expected: number)
	if math.abs(actual - expected) > 1e-12 then
		error(`expected {expected}, got {actual}`)
	end
end

describe("secret chance", function()
	it("is 1 in 20,000 for an egg of a world with a Secret pet", function()
		approx(rules.secretChance(rich(rules), "TestEgg"), CHANCE)
	end)

	it("is doubled while the luck potion runs", function()
		approx(rules.secretChance(withLuck(rich(rules)), "TestEgg"), 2 * CHANCE)
	end)

	it("is 0 for eggs of a world without a Secret pet and for unknown eggs", function()
		expect(rules.secretChance(rich(rules), "FarmTestEgg")).toBe(0)
		expect(rules.secretChance(rich(rules), "NoEgg")).toBe(0)
	end)

	it("is 0 without secretPets config or with the feature switched off", function()
		local plain = GameRules.new(TestConfig)
		expect(plain.secretChance(rich(plain), "TestEgg")).toBe(0)
		local off = GameRules.new(secretConfig({ secretPets = false }))
		expect(off.secretChance(rich(off), "TestEgg")).toBe(0)
	end)

	it("names the Secret pet of an egg's world", function()
		expect(rules.secretPetOf("TestEgg")).toBe("GhostPet")
		expect(rules.secretPetOf("FarmTestEgg")).toBe(nil)
	end)
end)

describe("secret roll when hatching", function()
	it("hatches the world's Secret pet when the secret roll is below the chance", function()
		-- First roll: secret check, no further roll needed.
		local result = rules.openEgg(rich(rules), "TestEgg", TestKit.sequenceRandom({ CHANCE * 0.99 }))
		expect(result.ok).toBe(true)
		expect(result.pet.petId).toBe("GhostPet")
		expect(result.state.pets[1].petId).toBe("GhostPet")
	end)

	it("draws a normal pet with the next roll when the secret roll misses", function()
		local result = rules.openEgg(rich(rules), "TestEgg", TestKit.sequenceRandom({ CHANCE * 1.01, 0 }))
		expect(result.pet.petId).toBe("Hamster")
	end)

	it("with luck a roll between the normal and the doubled chance hits", function()
		local roll = CHANCE * 1.5
		local without = rules.openEgg(rich(rules), "TestEgg", TestKit.sequenceRandom({ roll, 0 }))
		expect(without.pet.petId).toBe("Hamster")
		local with = rules.openEgg(withLuck(rich(rules)), "TestEgg", TestKit.sequenceRandom({ roll, 0 }))
		expect(with.pet.petId).toBe("GhostPet")
		local beyond = rules.openEgg(withLuck(rich(rules)), "TestEgg", TestKit.sequenceRandom({ CHANCE * 2.01, 0 }))
		expect(beyond.pet.petId).toBe("Hamster")
	end)

	it("rolls once per egg when opening 3 at once", function()
		local state = rich(rules)
		state.upgrades.TripleOpen = 1
		-- egg 1: miss + Hamster, egg 2: secret, egg 3: miss + Hamster
		local result = rules.openEggs(state, "TestEgg", 3, TestKit.sequenceRandom({ 0.5, 0, 0, 0.5, 0 }))
		expect(result.ok).toBe(true)
		expect(result.pets[1].petId).toBe("Hamster")
		expect(result.pets[2].petId).toBe("GhostPet")
		expect(result.pets[3].petId).toBe("Hamster")
	end)

	it("never hatches a Secret pet from an egg of a world without one", function()
		local state = rich(rules)
		state.unlockedWorlds = { "Farm" }
		local result = rules.openEgg(state, "FarmTestEgg", TestKit.sequenceRandom({ 0 }))
		expect(result.pet.petId).toBe("Cat")
	end)

	it("never hatches a Secret pet while the feature is off", function()
		local off = GameRules.new(secretConfig({ secretPets = false }))
		local result = off.openEgg(rich(off), "TestEgg", TestKit.sequenceRandom({ 0 }))
		expect(result.pet.petId).toBe("Hamster")
	end)

	it("lets the Secret pet count like every other pet for the coin bonus", function()
		local state = rules.openEgg(rich(rules), "TestEgg", TestKit.sequenceRandom({ 0 })).state
		state = rules.equipPet(state, state.pets[1].uid).state
		approx(rules.petMultiplier(state), 6)
	end)
end)

describe("egg preview with a Secret pet", function()
	it("adds the Secret pet with its chance and scales the other chances down", function()
		local preview = rules.eggPreview("TestEgg", rich(rules))
		expect(preview.secret).toEqual({ petId = "GhostPet", rarity = "Secret", chancePercent = 0.005, bonus = 5 })
		expect(preview.pets[1].chancePercent).toBe(69.9965)
	end)

	it("shows the doubled chance with luck and no Secret entry without one", function()
		expect(rules.eggPreview("TestEgg", withLuck(rich(rules))).secret.chancePercent).toBe(0.01)
		expect(rules.eggPreview("FarmTestEgg", rich(rules)).secret).toBe(nil)
	end)
end)
