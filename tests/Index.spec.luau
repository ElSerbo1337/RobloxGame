-- Pet index and topping index (#95): per world all normal pets (no Secret pet) -> a
-- permanent coin bonus per complete world; Gold/Rainbow/Shiny as extra stars without a
-- reward; deleted, auto-deleted and merged pets count. Topping index: normal and golden
-- per topping, counted separately, no rewards.
local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function indexConfig(features: { [string]: boolean }?): any
	local config = table.clone(TestConfig)
	config.features = features
	config.petIndex = { worldCoinBonus = 0.05 }
	config.petVariants = {
		order = { "Normal", "Gold", "Rainbow" },
		Normal = { bonusMultiplier = 1 },
		Gold = { from = "Normal", count = 5, bonusMultiplier = 2.5 },
		Rainbow = { from = "Gold", count = 5, bonusMultiplier = 6 },
	}
	config.shinyPets = { chance = 1 / 200, bonusMultiplier = 1.5 }
	config.goldenToppings = { chance = 0.5, valueMultiplier = 10 }
	config.rarities = table.clone(TestConfig.rarities)
	config.rarities.Secret = { displayName = "Geheim", order = 7, color = { 0, 255, 200 } }
	config.pets = table.clone(TestConfig.pets)
	config.pets.Ghost = { displayName = "Geist", rarity = "Secret", bonus = 5 }
	config.petManagement = { teams = 3, nameMaxLength = 10, noAutoDelete = { "Secret" } }
	-- World 1: TestEgg (Hamster, Cat, Dragon) with the Secret pet Ghost.
	config.worlds = table.clone(TestConfig.worlds)
	config.worlds[1] = table.clone(TestConfig.worlds[1])
	config.worlds[1].secretPet = "Ghost"
	return config
end

local rules = GameRules.new(indexConfig())

local function withPets(r, list: { any })
	local state = r.newPlayerState()
	state.upgrades = { InventorySpace = 2, PetSlots = 2 }
	for i, spec in list do
		table.insert(state.pets, { uid = i, petId = spec[1], variant = spec.variant, shiny = spec.shiny })
	end
	state.nextPetUid = #list + 1
	return state
end

local function give(r, state, petId: string, count: number?, variant: string?, shiny: boolean?)
	local result = r.givePets(state, petId, count or 1, variant, shiny)
	expect(result.ok).toBe(true)
	return result.state
end

local function world(index, worldId: string)
	for _, entry in index do
		if entry.worldId == worldId then
			return entry
		end
	end
	return nil
end

describe("pet index", function()
	it("lists the egg pets of each world without the Secret pet, worlds without pets left out", function()
		expect(rules.indexPetsOf("PizzeriaGarden")).toEqual({ "Hamster", "Cat", "Dragon" })
		expect(rules.indexPetsOf("Farm")).toEqual({ "Cat" })
		expect(rules.indexPetsOf("Beach")).toEqual({})
		local index = rules.petIndex(rules.newPlayerState())
		expect(#index).toBe(2)
		expect(index[1].worldId).toBe("PizzeriaGarden")
		expect(index[1].total).toBe(3)
		expect(index[1].found).toBe(0)
		expect(index[1].complete).toBe(false)
	end)

	it("starts empty: no stars, no toppings found, no bonus", function()
		local state = rules.newPlayerState()
		expect(state.petIndexStars).toEqual({})
		expect(state.toppingsFound).toEqual({})
		expect(state.goldenToppingsFound).toEqual({})
		expect(rules.indexCompleteWorlds(state)).toBe(0)
		expect(rules.indexCoinBonus(state)).toBe(0)
	end)

	it("counts found pets and completes a world when all its normal pets were found", function()
		local state = give(rules, rules.newPlayerState(), "Hamster")
		state = give(rules, state, "Cat")
		local garden = world(rules.petIndex(state), "PizzeriaGarden")
		expect(garden.found).toBe(2)
		expect(garden.complete).toBe(false)
		-- Cat alone completes the Farm.
		expect(world(rules.petIndex(state), "Farm").complete).toBe(true)
		expect(rules.indexCompleteWorlds(state)).toBe(1)
		state = give(rules, state, "Dragon")
		expect(world(rules.petIndex(state), "PizzeriaGarden").complete).toBe(true)
		expect(rules.indexCompleteWorlds(state)).toBe(2)
	end)

	it("does not need the Secret pet", function()
		local state = give(rules, rules.newPlayerState(), "Ghost")
		expect(world(rules.petIndex(state), "PizzeriaGarden").found).toBe(0)
		state = give(rules, state, "Hamster")
		state = give(rules, state, "Cat")
		state = give(rules, state, "Dragon")
		expect(world(rules.petIndex(state), "PizzeriaGarden").complete).toBe(true)
	end)

	it("keeps deleted pets in the index", function()
		local state = give(rules, rules.newPlayerState(), "Cat")
		local deleted = rules.deletePets(state, { 1 })
		expect(deleted.ok).toBe(true)
		expect(#deleted.state.pets).toBe(0)
		expect(world(rules.petIndex(deleted.state), "Farm").complete).toBe(true)
		expect(rules.indexCompleteWorlds(deleted.state)).toBe(1)
	end)

	it("keeps auto-deleted pets in the index", function()
		local state = rules.newPlayerState()
		state.coins = 100
		state.upgrades = { InventorySpace = 2 }
		state = rules.setAutoDelete(state, "Rare", true).state
		-- No secretPets config, so no Secret roll: 0.8 draws Cat (Rare), 0.9 misses Shiny.
		local opened = rules.openEggs(state, "TestEgg", 1, TestKit.sequenceRandom({ 0.8, 0.9 }))
		expect(opened.ok).toBe(true)
		expect(opened.autoDeleted[1]).toBe(true)
		expect(#opened.state.pets).toBe(0)
		expect(world(rules.petIndex(opened.state), "Farm").complete).toBe(true)
	end)

	it("keeps merged pets in the index and adds the Gold star", function()
		local state = withPets(rules, { { "Cat" }, { "Cat" }, { "Cat" }, { "Cat" }, { "Cat" } })
		local merged = rules.mergePets(state, "Cat", "Normal")
		expect(merged.ok).toBe(true)
		local cat = world(rules.petIndex(merged.state), "Farm").pets[1]
		expect(cat.found).toBe(true)
		expect(cat.gold).toBe(true)
		expect(cat.rainbow).toBe(false)
		expect(cat.shiny).toBe(false)
	end)

	it("keeps Gold, Rainbow and Shiny stars after the pet is gone", function()
		local state = give(rules, rules.newPlayerState(), "Hamster", 1, "Rainbow", true)
		expect(state.petIndexStars.Hamster).toEqual({ Rainbow = true, Shiny = true })
		state = rules.deletePets(state, { 1 }).state
		local hamster = world(rules.petIndex(state), "PizzeriaGarden").pets[1]
		expect(hamster.found).toBe(true)
		expect(hamster.gold).toBe(false)
		expect(hamster.rainbow).toBe(true)
		expect(hamster.shiny).toBe(true)
	end)

	it("counts pets and stars of old saves from the inventory", function()
		local state = withPets(rules, { { "Cat", variant = "Gold", shiny = true } })
		state.petsOwnedEver = {}
		state.petIndexStars = {}
		local cat = world(rules.petIndex(state), "Farm").pets[1]
		expect(cat.found).toBe(true)
		expect(cat.gold).toBe(true)
		expect(cat.shiny).toBe(true)
	end)

	it("gives no reward for stars: the bonus only counts complete worlds", function()
		local plain = give(rules, rules.newPlayerState(), "Cat")
		local starred = give(rules, rules.newPlayerState(), "Cat", 1, "Rainbow", true)
		expect(rules.indexCoinBonus(plain)).toBe(0.05)
		expect(rules.indexCoinBonus(starred)).toBe(0.05)
	end)

	it("adds the bonus per complete world into the coin multiplier", function()
		local state = rules.newPlayerState()
		expect(rules.coinMultiplier(state)).toBe(1)
		state = give(rules, state, "Cat")
		state = rules.deletePets(state, { 1 }).state
		expect(rules.coinMultiplier(state)).toBe(1.05)
		state = give(rules, state, "Hamster")
		state = give(rules, state, "Dragon")
		state = rules.deletePets(state, { 2, 3 }).state
		expect(rules.indexCoinBonus(state)).toBe(0.1)
		expect(rules.coinMultiplier(state)).toBe(1.1)
		-- Multiplies with the rebirth multiplier (1 + 0.5 per rebirth).
		state.rebirths = 2
		expect(rules.coinMultiplier(state)).toBe(2.2)
	end)

	it("pays the bonus when selling", function()
		local state = give(rules, rules.newPlayerState(), "Cat")
		state = rules.deletePets(state, { 1 }).state
		-- 2 Ham x 20 = 40 coins, +5 % index bonus = 42.
		state.pizza = { "Ham", "Ham" }
		expect(rules.sellPizza(state).coinsEarned).toBe(42)
	end)

	it("keeps the index through a rebirth", function()
		local state = give(rules, rules.newPlayerState(), "Cat", 1, "Gold")
		state.coins = 1000
		local reborn = rules.rebirth(state, 0)
		expect(reborn.ok).toBe(true)
		expect(rules.indexCompleteWorlds(reborn.state)).toBe(1)
		expect(reborn.state.petIndexStars.Cat).toEqual({ Gold = true })
	end)

	it("gives no bonus while features.petIndex is off (the index still records)", function()
		local off = GameRules.new(indexConfig({ petIndex = false }))
		local state = give(off, off.newPlayerState(), "Cat")
		expect(off.indexCompleteWorlds(state)).toBe(0)
		expect(off.indexCoinBonus(state)).toBe(0)
		expect(off.coinMultiplier(state)).toBe(1)
		expect(off.indexStatus(state).petIndexOn).toBe(false)
		expect(state.petsOwnedEver.Cat).toBe(true)
	end)

	it("gives no bonus without a petIndex config", function()
		local plain = GameRules.new(TestConfig)
		local state = plain.givePets(plain.newPlayerState(), "Cat", 1).state
		expect(plain.indexCoinBonus(state)).toBe(0)
	end)
end)

describe("topping index", function()
	local function collect(state, toppingId: string, goldRoll: number)
		local result = rules.collectTopping(state, toppingId, 0, nil, goldRoll)
		expect(result.ok).toBe(true)
		return result
	end

	it("lists the spawning toppings of each world", function()
		expect(rules.indexToppingsOf("PizzeriaGarden")).toEqual({ "Salami", "Mushroom", "Mozzarella" })
		expect(rules.indexToppingsOf("Farm")).toEqual({ "Onion", "Ham" })
		expect(#rules.toppingIndex(rules.newPlayerState())).toBe(2)
	end)

	it("records a normal topping without marking it golden", function()
		local result = collect(rules.newPlayerState(), "Salami", 0.9)
		expect(result.golden).toBe(false)
		expect(rules.hasFoundTopping(result.state, "Salami", false)).toBe(true)
		expect(rules.hasFoundTopping(result.state, "Salami", true)).toBe(false)
	end)

	it("counts golden toppings separately", function()
		local result = collect(rules.newPlayerState(), "Mushroom", 0.1)
		expect(result.golden).toBe(true)
		expect(rules.hasFoundTopping(result.state, "Mushroom", true)).toBe(true)
		expect(rules.hasFoundTopping(result.state, "Mushroom", false)).toBe(false)
		local both = collect(result.state, "Mushroom", 0.9)
		local garden = world(rules.toppingIndex(both.state), "PizzeriaGarden")
		expect(garden.toppings[2]).toEqual({ toppingId = "Mushroom", normal = true, golden = true })
		expect(garden.toppings[1]).toEqual({ toppingId = "Salami", normal = false, golden = false })
	end)

	it("does not copy the found maps when nothing is new", function()
		local first = collect(rules.newPlayerState(), "Salami", 0.9)
		local second = collect(first.state, "Salami", 0.9)
		expect(second.state.toppingsFound).toBe(first.state.toppingsFound)
	end)

	it("gives no reward and keeps the finds through a rebirth", function()
		local state = collect(rules.newPlayerState(), "Salami", 0.1).state
		expect(rules.coinMultiplier(state)).toBe(1)
		state.coins = 1000
		local reborn = rules.rebirth(state, 0)
		expect(rules.hasFoundTopping(reborn.state, "Salami", true)).toBe(true)
	end)

	it("reports both indexes and the switches in indexStatus", function()
		local state = give(rules, rules.newPlayerState(), "Cat")
		local status = rules.indexStatus(state)
		expect(#status.pets).toBe(2)
		expect(#status.toppings).toBe(2)
		expect(status.completeWorlds).toBe(1)
		expect(status.coinBonus).toBe(0.05)
		expect(status.petIndexOn).toBe(true)
		expect(status.toppingIndexOn).toBe(true)
	end)
end)
