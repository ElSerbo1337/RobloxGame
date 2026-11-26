-- Pet index and topping index (#95).
local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- TestConfig with the pet index bonus (+4 % per complete world, like the real game)
-- and a Secret pet in world 1 (never needed for the index).
local config = table.clone(TestConfig)
config.petIndex = { worldBonus = 0.04 }
config.pets = table.clone(TestConfig.pets)
config.pets.Ghost = { displayName = "Geist", rarity = "Secret", bonus = 5 }
config.worlds = table.clone(TestConfig.worlds)
config.worlds[1] = table.clone(TestConfig.worlds[1])
config.worlds[1].secretPet = "Ghost"
config.petVariants = {
	order = { "Normal", "Gold", "Rainbow" },
	Normal = { bonusMultiplier = 1 },
	Gold = { from = "Normal", count = 5, bonusMultiplier = 2.5 },
	Rainbow = { from = "Gold", count = 5, bonusMultiplier = 6 },
}
config.shinyPets = { chance = 0, bonusMultiplier = 1.5 }

local rules = GameRules.new(config)

local function approx(actual: number, expected: number)
	if math.abs(actual - expected) > 1e-9 then
		error(`expected {expected}, got {actual}`)
	end
end

local function player()
	local state = rules.newPlayerState()
	state.upgrades = { PizzaSpace = 3, InventorySpace = 2 }
	return state
end

local function give(state, petId: string, count: number?, variant: string?, shiny: boolean?)
	local result = rules.givePets(state, petId, count or 1, variant, shiny)
	expect(result.ok).toBe(true)
	return result.state
end

local function worldEntry(index, worldId: string)
	for _, entry in index.worlds do
		if entry.worldId == worldId then
			return entry
		end
	end
	return nil
end

local function petEntry(world, petId: string)
	for _, entry in world.pets do
		if entry.petId == petId then
			return entry
		end
	end
	return nil
end

describe("pet index pets per world", function()
	it("lists the egg pets of each world without the Secret pet, in egg order", function()
		expect(rules.indexPets("PizzeriaGarden")).toEqual({ "Hamster", "Cat", "Dragon" })
		expect(rules.indexPets("Farm")).toEqual({ "Cat" })
		expect(rules.indexPets("Beach")).toEqual({})
		expect(rules.indexPets("Nowhere")).toEqual({})
	end)

	it("lists only worlds with pets, in world order", function()
		local index = rules.petIndex(player())
		local ids = {}
		for _, entry in index.worlds do
			table.insert(ids, entry.worldId)
		end

		expect(ids).toEqual({ "PizzeriaGarden", "Farm" })
	end)
end)

describe("pet index progress", function()
	it("starts empty", function()
		local index = rules.petIndex(player())
		local garden = worldEntry(index, "PizzeriaGarden")

		expect(garden.found).toBe(0)
		expect(garden.total).toBe(3)
		expect(garden.complete).toBe(false)
		expect(index.found).toBe(0)
		expect(index.total).toBe(4)
		expect(index.completeWorlds).toBe(0)
		expect(rules.indexBonus(player())).toBe(0)
	end)

	it("counts each found pet once per world", function()
		local state = give(player(), "Hamster", 2)
		state = give(state, "Cat")
		local index = rules.petIndex(state)

		expect(worldEntry(index, "PizzeriaGarden").found).toBe(2)
		expect(petEntry(worldEntry(index, "PizzeriaGarden"), "Hamster").found).toBe(true)
		expect(petEntry(worldEntry(index, "PizzeriaGarden"), "Dragon").found).toBe(false)
		-- The Cat also stands in the Farm egg: that world is complete.
		expect(worldEntry(index, "Farm").complete).toBe(true)
		expect(index.found).toBe(3)
		expect(index.completeWorlds).toBe(1)
	end)

	it("completes a world without its Secret pet", function()
		local state = give(give(give(player(), "Hamster"), "Cat"), "Dragon")

		expect(worldEntry(rules.petIndex(state), "PizzeriaGarden").complete).toBe(true)
	end)

	it("keeps deleted pets in the index", function()
		local state = give(player(), "Dragon")
		local deleted = rules.deletePet(state, state.pets[1].uid)
		expect(deleted.ok).toBe(true)

		expect(#deleted.state.pets).toBe(0)
		expect(petEntry(worldEntry(rules.petIndex(deleted.state), "PizzeriaGarden"), "Dragon").found).toBe(true)
	end)

	it("keeps auto-deleted pets in the index", function()
		local state = player()
		state.coins = 1000
		state = rules.setAutoDelete(state, "Common", true).state
		local opened = rules.openEggs(state, "TestEgg", 1, TestKit.sequenceRandom({ 0.1 }))
		expect(opened.ok).toBe(true)
		expect(opened.autoDeleted[1]).toBe(true)

		expect(petEntry(worldEntry(rules.petIndex(opened.state), "PizzeriaGarden"), "Hamster").found).toBe(true)
	end)

	it("keeps merged pets in the index", function()
		local state = give(player(), "Hamster", 5)
		local merged = rules.mergePets(state, "Hamster", "Normal")
		expect(merged.ok).toBe(true)
		local hamster = petEntry(worldEntry(rules.petIndex(merged.state), "PizzeriaGarden"), "Hamster")

		expect(hamster.found).toBe(true)
		expect(hamster.gold).toBe(true)
	end)

	it("counts pets of old saves that are only in the inventory", function()
		local state = give(player(), "Cat")
		state.petsOwnedEver = {}
		state.petIndexStars = nil

		expect(worldEntry(rules.petIndex(state), "Farm").complete).toBe(true)
	end)
end)

describe("pet index stars", function()
	it("adds Gold, Rainbow and Shiny stars without changing completion", function()
		local state = give(player(), "Cat", 1, "Gold")
		state = give(state, "Cat", 1, "Rainbow", true)
		local cat = petEntry(worldEntry(rules.petIndex(state), "PizzeriaGarden"), "Cat")

		expect(cat.found).toBe(true)
		expect(cat.gold).toBe(true)
		expect(cat.rainbow).toBe(true)
		expect(cat.shiny).toBe(true)
		expect(petEntry(worldEntry(rules.petIndex(state), "PizzeriaGarden"), "Hamster").gold).toBe(false)
	end)

	it("counts stars per world and keeps them after deleting", function()
		local state = give(player(), "Hamster", 1, nil, true)
		state = rules.deletePet(state, state.pets[1].uid).state
		local garden = worldEntry(rules.petIndex(state), "PizzeriaGarden")

		expect(garden.stars).toBe(1)
		expect(garden.starsTotal).toBe(9)
		expect(petEntry(garden, "Hamster").shiny).toBe(true)
	end)

	it("pays nothing for stars", function()
		local state = give(player(), "Hamster", 1, "Rainbow", true)

		expect(rules.indexBonus(state)).toBe(0)
	end)
end)

describe("pet index coin bonus", function()
	it("gives worldBonus per complete world", function()
		local state = give(player(), "Cat")
		approx(rules.indexBonus(state), 0.04)

		state = give(give(state, "Hamster"), "Dragon")
		approx(rules.indexBonus(state), 0.08)
	end)

	it("is part of the coin multiplier", function()
		local state = give(player(), "Cat")
		local before = rules.coinMultiplier(state)
		state = give(give(state, "Hamster"), "Dragon")

		-- Unequipped pets: pets x rebirths stays the same, only the index bonus grows.
		approx(rules.coinMultiplier(state), before / 1.04 * 1.08)
	end)

	it("raises the coins of a sale", function()
		local state = player()
		state.pizza = table.create(10, "Ham")
		local plain = rules.sellPizza(state).coinsEarned
		state = give(state, "Cat")

		expect(plain).toBe(200)
		expect(rules.sellPizza(state).coinsEarned).toBe(208)
	end)

	it("stays after a rebirth", function()
		local state = give(player(), "Cat")
		state.coins = 1e12
		local reborn = rules.rebirth(state, 0)
		expect(reborn.ok).toBe(true)

		approx(rules.indexBonus(reborn.state), 0.04)
	end)

	it("is 0 without the config and with the switch off", function()
		local state = give(player(), "Cat")
		local plain = GameRules.new(TestConfig)
		local offConfig = table.clone(config)
		offConfig.features = { petIndex = false }
		local off = GameRules.new(offConfig)

		expect(plain.indexBonus(state)).toBe(0)
		expect(off.indexBonus(state)).toBe(0)
		expect(off.petIndex(state).completeWorlds).toBe(1)
	end)
end)

describe("topping index", function()
	local function collect(state, toppingId: string, goldRoll: number?)
		local result = rules.collectTopping(state, toppingId, 0, nil, goldRoll)
		expect(result.ok).toBe(true)
		return result.state
	end

	local function goldenRules()
		local goldConfig = table.clone(config)
		goldConfig.goldenToppings = { chance = 0.5, valueMultiplier = 10 }
		return GameRules.new(goldConfig)
	end

	local function toppingEntry(index, worldId: string, toppingId: string)
		for _, entry in worldEntry(index, worldId).toppings do
			if entry.toppingId == toppingId then
				return entry
			end
		end
		return nil
	end

	it("lists the toppings of every world with toppings, in spawn order", function()
		local index = rules.toppingIndex(player())

		expect(#index.worlds).toBe(2)
		expect(worldEntry(index, "PizzeriaGarden").toppings[1].toppingId).toBe("Salami")
		expect(#worldEntry(index, "PizzeriaGarden").toppings).toBe(3)
		expect(worldEntry(index, "PizzeriaGarden").total).toBe(6)
		expect(index.total).toBe(10)
		expect(index.found).toBe(0)
	end)

	it("records a normal topping when collected", function()
		local state = collect(player(), "Mushroom")
		local mushroom = toppingEntry(rules.toppingIndex(state), "PizzeriaGarden", "Mushroom")

		expect(mushroom.normal).toBe(true)
		expect(mushroom.golden).toBe(false)
		expect(rules.toppingIndex(state).found).toBe(1)
	end)

	it("counts golden toppings separately", function()
		local gold = goldenRules()
		local state = gold.collectTopping(player(), "Salami", 0, nil, 0.1).state
		local salami = toppingEntry(gold.toppingIndex(state), "PizzeriaGarden", "Salami")

		expect(salami.golden).toBe(true)
		expect(salami.normal).toBe(false)
		expect(worldEntry(gold.toppingIndex(state), "PizzeriaGarden").found).toBe(1)

		state = gold.collectTopping(state, "Salami", 0, nil, 0.9).state
		expect(toppingEntry(gold.toppingIndex(state), "PizzeriaGarden", "Salami").normal).toBe(true)
		expect(worldEntry(gold.toppingIndex(state), "PizzeriaGarden").found).toBe(2)
	end)

	it("records auto-collected toppings", function()
		local state = rules.setAutoCollect(player(), true).state
		state = rules.autoCollectTopping(state, "Salami", 0).state

		expect(toppingEntry(rules.toppingIndex(state), "PizzeriaGarden", "Salami").normal).toBe(true)
	end)

	it("keeps found toppings after selling and rebirth", function()
		local state = collect(player(), "Salami")
		state = rules.sellPizza(state).state
		state.coins = 1e12
		state = rules.rebirth(state, 0).state

		expect(toppingEntry(rules.toppingIndex(state), "PizzeriaGarden", "Salami").normal).toBe(true)
	end)

	it("counts toppings that are on the pizza of an old save", function()
		local state = player()
		state.pizza = { "Onion", "Ham" }
		state.pizzaGolden = { Ham = 1 }
		local index = rules.toppingIndex(state)

		expect(toppingEntry(index, "Farm", "Onion").normal).toBe(true)
		expect(toppingEntry(index, "Farm", "Ham").golden).toBe(true)
		expect(toppingEntry(index, "Farm", "Ham").normal).toBe(false)
	end)

	it("does not record failed collects or gem toppings", function()
		local state = player()
		local far = rules.collectTopping(state, "Salami", 1000)
		local gems = rules.collectTopping(state, config.gems.toppingId, 0, 5)

		expect(far.ok).toBe(false)
		expect(rules.toppingIndex(gems.state).found).toBe(0)
	end)
end)
