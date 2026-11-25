-- Golden toppings and the "Gold Luck" gem upgrade (#94).
local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")
local SaveData = require("../src/shared/SaveData")
local ToppingField = require("../src/shared/ToppingField")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- TestConfig with golden toppings switched on (1 in 100, like the real game).
local goldConfig = table.clone(TestConfig)
goldConfig.goldenToppings = table.clone(TestConfig.goldenToppings)
goldConfig.goldenToppings.chance = 0.01
-- A gold potion like #96 will add: doubles the golden chance while it runs.
goldConfig.potions = table.clone(TestConfig.potions)
goldConfig.potions.Gold = { displayName = "Gold-Trank", price = 30, durationSeconds = 600, goldenChanceMultiplier = 2 }

local rules = GameRules.new(goldConfig)

local function approx(actual: number, expected: number)
	if math.abs(actual - expected) > 1e-9 then
		error(`expected {expected}, got {actual}`)
	end
end

local function player()
	local state = rules.newPlayerState()
	state.upgrades = { PizzaSpace = 3 } -- room for 6 toppings
	return state
end

local function withGoldLuck(state, level: number)
	local newState = table.clone(state)
	newState.upgrades = table.clone(state.upgrades)
	newState.upgrades.GoldLuck = level
	return newState
end

local function collect(state, toppingId: string, goldRoll: number?)
	local result = rules.collectTopping(state, toppingId, 0, nil, goldRoll)
	assert(result.ok, result.reason)
	return result
end

describe("golden topping spawn", function()
	it("draws a gold roll for every normal topping after its kind and position", function()
		-- Per spawn: kind roll, x, z, gold roll.
		local field = ToppingField.new(
			goldConfig,
			"PizzeriaGarden",
			TestKit.sequenceRandom({ 0, 0.1, 0.2, 0.005, 0.6, 0.3, 0.4, 0.5 })
		)

		expect(field:get(1)).toEqual({ toppingId = "Salami", x = 0.1, z = 0.2, goldRoll = 0.005 })
		expect(field:get(2)).toEqual({ toppingId = "Mushroom", x = 0.3, z = 0.4, goldRoll = 0.5 })
	end)

	it("gives gem toppings no gold roll", function()
		local config = table.clone(goldConfig)
		config.gems = table.clone(TestConfig.gems)
		config.gems.toppingChance = 0.5
		-- Gem roll 0 -> gem topping: amount, x, z (no gold roll).
		local field = ToppingField.new(config, "PizzeriaGarden", TestKit.sequenceRandom({ 0, 0, 0.1, 0.2 }))

		expect(field:get(1)).toEqual({ toppingId = "Gem", gems = 1, x = 0.1, z = 0.2 })
	end)

	it("draws no gold roll while golden toppings are off in the config", function()
		local field = ToppingField.new(TestConfig, "PizzeriaGarden", TestKit.sequenceRandom({ 0, 0.1, 0.2 }))

		expect(field:get(1)).toEqual({ toppingId = "Salami", x = 0.1, z = 0.2 })
	end)
end)

describe("golden chance", function()
	it("is 1 % for a new player", function()
		approx(rules.goldenChance(rules.newPlayerState()), 0.01)
	end)

	it("rises with each of the 5 Gold Luck levels up to 2 %", function()
		local expected = { 0.012, 0.014, 0.016, 0.018, 0.02 }
		for level, chance in expected do
			approx(rules.goldenChance(withGoldLuck(player(), level)), chance)
		end
		expect(#goldConfig.upgrades.GoldLuck.levels).toBe(5)
	end)

	it("is doubled by a running potion with a gold chance factor (gold potion, #96)", function()
		local state = withGoldLuck(player(), 5)
		state.activePotions = { Gold = 60 }

		approx(rules.goldenChance(state), 0.04)
	end)

	it("ignores potions that are owned but not running", function()
		local state = player()
		state.potions = { Gold = 3 }

		approx(rules.goldenChance(state), 0.01)
	end)

	it("never goes above 100 %", function()
		local config = table.clone(goldConfig)
		config.potions = table.clone(goldConfig.potions)
		config.potions.Gold = table.clone(goldConfig.potions.Gold)
		config.potions.Gold.goldenChanceMultiplier = 1000
		local state = GameRules.new(config).newPlayerState()
		state.activePotions = { Gold = 60 }

		expect(GameRules.new(config).goldenChance(state)).toBe(1)
	end)

	it("is not changed by other boosts (weather #105, luck/coin potions)", function()
		-- Weather only adds toppings; the golden chance depends on Gold Luck and gold potions only.
		local state = player()
		state.activePotions = { Luck = 60, Coins = 60, Speed = 60 }

		approx(rules.goldenChance(state), 0.01)
	end)

	it("is 0 while the feature switch goldenToppings is off", function()
		local config = table.clone(goldConfig)
		config.features = { goldenToppings = false }
		local offRules = GameRules.new(config)

		expect(offRules.goldenChance(withGoldLuck(player(), 5))).toBe(0)
	end)

	it("uses the admin test chance when it is higher", function()
		local state = player()
		state.adminGoldenChance = 1

		expect(rules.goldenChance(state)).toBe(1)
	end)
end)

describe("collecting a golden topping", function()
	it("is golden when the topping's gold roll is below the player's chance", function()
		local result = collect(player(), "Salami", 0.0099)

		expect(result.golden).toBe(true)
		expect(result.state.pizza).toEqual({ "Salami" })
		expect(result.state.pizzaGolden).toEqual({ Salami = 1 })
	end)

	it("is normal at or above the chance, or without a gold roll", function()
		local state = player()
		local atChance = collect(state, "Salami", 0.01)
		local noRoll = collect(state, "Salami", nil)

		expect(atChance.golden).toBe(false)
		expect(atChance.state.pizzaGolden).toEqual({})
		expect(noRoll.golden).toBe(false)
	end)

	it("depends on the player: the same topping is golden only with enough Gold Luck", function()
		local roll = 0.015

		expect(collect(player(), "Mushroom", roll).golden).toBe(false)
		expect(collect(withGoldLuck(player(), 3), "Mushroom", roll).golden).toBe(true)
	end)

	it("also works with auto-collect", function()
		local state = player()
		state.autoCollect = true
		local result = rules.autoCollectTopping(state, "Salami", 0, nil, 0)

		expect(result.ok).toBe(true)
		expect(result.golden).toBe(true)
	end)

	it("never makes a gem topping golden", function()
		local result = rules.collectTopping(player(), "Gem", 0, 2, 0)

		expect(result.ok).toBe(true)
		expect(result.golden).toBe(false)
		expect(result.state.pizzaGolden).toEqual({})
	end)

	it("reports golden = false when collecting fails", function()
		local state = rules.newPlayerState()
		state.pizza = { "Salami", "Salami" } -- full (capacity 2)
		local result = rules.collectTopping(state, "Salami", 0, nil, 0)

		expect(result.ok).toBe(false)
		expect(result.golden).toBe(false)
	end)

	it("never golden while the feature switch is off", function()
		local config = table.clone(goldConfig)
		config.features = { goldenToppings = false }
		local offRules = GameRules.new(config)

		local result = offRules.collectTopping(offRules.newPlayerState(), "Salami", 0, nil, 0)

		expect(result.golden).toBe(false)
	end)

	it("does not change the old state", function()
		local state = player()
		collect(state, "Salami", 0)

		expect(state.pizza).toEqual({})
		expect(state.pizzaGolden).toEqual({})
	end)

	it("counts golden toppings per topping on the pizza", function()
		local state = player()
		state = collect(state, "Salami", 0).state
		state = collect(state, "Salami", 0.5).state
		state = collect(state, "Salami", 0).state
		state = collect(state, "Mushroom", 0).state

		expect(rules.goldenOnPizza(state)).toEqual({ Salami = 2, Mushroom = 1 })
		expect(rules.goldenCount(state)).toBe(3)
	end)
end)

describe("selling golden toppings", function()
	it("pays 10x the topping value for a golden topping", function()
		local state = player()
		state = collect(state, "Mozzarella", 0).state -- golden: 5 x 10
		state = collect(state, "Mushroom", 0.5).state -- normal: 2

		local result = rules.sellPizza(state)

		expect(result.coinsEarned).toBe(52)
		expect(result.goldenSold).toBe(1)
		expect(result.state.pizzaGolden).toEqual({})
	end)

	it("applies the coin multipliers on top", function()
		local state = player()
		state.rebirths = 2 -- x2
		state = collect(state, "Salami", 0).state

		expect(rules.sellPizza(state).coinsEarned).toBe(20)
	end)

	it("sells golden toppings first while a delivery order keeps the same kind", function()
		local state = player()
		state = collect(state, "Salami", 0.5).state
		state = collect(state, "Salami", 0).state -- golden
		state.delivery = { order = { worldId = "PizzeriaGarden", toppings = { Salami = 1 }, reward = "Coins" } }

		local result = rules.sellPizza(state)

		expect(result.coinsEarned).toBe(10)
		expect(result.state.pizza).toEqual({ "Salami" })
		expect(result.state.pizzaGolden).toEqual({})
	end)

	it("keeps a golden topping golden when the order needs more of that kind", function()
		local state = player()
		state = collect(state, "Salami", 0).state -- golden
		state = collect(state, "Salami", 0).state -- golden
		state = collect(state, "Mushroom", 0.5).state
		state.delivery = { order = { worldId = "PizzeriaGarden", toppings = { Salami = 1 }, reward = "Coins" } }

		local result = rules.sellPizza(state)

		expect(result.coinsEarned).toBe(12) -- golden Salami 10 + Mushroom 2
		expect(result.state.pizzaGolden).toEqual({ Salami = 1 })
	end)
end)

describe("golden toppings and other actions", function()
	it("a delivered order uses up golden toppings like normal ones", function()
		local state = player()
		state = collect(state, "Salami", 0).state
		state = collect(state, "Salami", 0.5).state
		state.delivery = {
			order = {
				worldId = "PizzeriaGarden",
				toppings = { Salami = 2 },
				reward = "Gems",
				gems = 3,
				expiresAt = 500,
			},
		}

		local result = rules.deliverOrder(state, 100)

		expect(result.ok).toBe(true)
		expect(result.state.pizzaGolden).toEqual({})
	end)

	it("rebirth clears golden toppings on the pizza but keeps Gold Luck", function()
		local state = withGoldLuck(player(), 4)
		state = collect(state, "Salami", 0).state
		state.coins = 1000

		local result = rules.rebirth(state, 0)

		expect(result.ok).toBe(true)
		expect(result.state.pizzaGolden).toEqual({})
		expect(result.state.upgrades.GoldLuck).toBe(4)
		approx(rules.goldenChance(result.state), 0.018)
	end)

	it("a new player has no golden toppings and no admin test chance", function()
		local state = rules.newPlayerState()

		expect(state.pizzaGolden).toEqual({})
		expect(state.adminGoldenChance).toBe(0)
	end)

	it("an old save without golden fields loads with empty golden fields", function()
		local loaded = SaveData.load({ version = 5, coins = 5, pizza = { "Salami" } }, rules.newPlayerState()).state

		expect(loaded.pizzaGolden).toEqual({})
		expect(loaded.adminGoldenChance).toBe(0)
		expect(rules.goldenOnPizza(loaded)).toEqual({})
	end)
end)

describe("Gold Luck upgrade", function()
	local function rich()
		local state = player()
		state.gems = 1e6
		return state
	end

	it("is bought with gems, level by level, up to the shop's max level", function()
		local state = rich()
		for level = 1, 5 do
			local result = rules.buyUpgrade(state, "GoldShop", "GoldLuck")
			expect(result.ok).toBe(true)
			expect(result.state.upgrades.GoldLuck).toBe(level)
			expect(result.state.gems).toBe(state.gems - goldConfig.upgrades.GoldLuck.levels[level].price)
			state = result.state
		end
		expect(rules.buyUpgrade(state, "GoldShop", "GoldLuck").reason).toBe("MaxLevel")
	end)

	it("needs enough gems", function()
		expect(rules.buyUpgrade(player(), "GoldShop", "GoldLuck").reason).toBe("NotEnoughGems")
	end)

	it("shows the chance as the upgrade value in the shop", function()
		local offer = rules.shopOffers(withGoldLuck(rich(), 2), "GoldShop")[1]

		expect(offer.upgrade).toBe("GoldLuck")
		expect(offer.currency).toBe("Gems")
		approx(offer.value, 0.014)
		approx(offer.nextValue :: number, 0.016)
	end)

	it("is not offered while the feature switch is off", function()
		local config = table.clone(goldConfig)
		config.features = { goldenToppings = false }
		local offRules = GameRules.new(config)

		expect(#offRules.shopOffers(rich(), "GoldShop")).toBe(0)
		expect(offRules.buyUpgrade(rich(), "GoldShop", "GoldLuck").reason).toBe("NotOffered")
	end)
end)
