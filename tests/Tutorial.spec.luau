local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")
local SaveData = require("../src/shared/SaveData")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local rules = GameRules.new(TestConfig)

local function fixedRandom()
	return TestKit.sequenceRandom({ 0 })
end

-- Plays the real actions up to the given tutorial step.
local function playUntil(stepId: string)
	local state = rules.newPlayerState()
	if stepId == "CollectToppings" then
		return state
	end
	state = rules.collectTopping(state, "Salami", 1).state
	state = rules.collectTopping(state, "Salami", 1).state
	if stepId == "SellPizza" then
		return state
	end
	state = rules.sellPizza(state).state
	state.coins = 100
	if stepId == "BuyUpgrade" then
		return state
	end
	state = rules.buyUpgrade(state, "SmallShop", "PizzaSpace").state
	return state
end

describe("tutorial", function()
	it("starts a new player at the first step: collect 2 toppings", function()
		local tutorial = rules.tutorial(rules.newPlayerState())

		expect(tutorial).toEqual({ step = "CollectToppings", number = 1, total = 4, progress = 0, goal = 2 })
	end)

	it("counts collected toppings and moves on to selling after the second one", function()
		local state = rules.newPlayerState()

		state = rules.collectTopping(state, "Salami", 1).state
		expect(rules.tutorial(state).step).toBe("CollectToppings")
		expect(rules.tutorial(state).progress).toBe(1)

		state = rules.collectTopping(state, "Mushroom", 1).state
		expect(rules.tutorial(state).step).toBe("SellPizza")
		expect(rules.tutorial(state).number).toBe(2)
	end)

	it("also counts toppings picked up with auto-collect", function()
		local state = rules.setAutoCollect(rules.newPlayerState(), true).state

		state = rules.autoCollectTopping(state, "Salami", 1).state
		state = rules.autoCollectTopping(state, "Salami", 1).state

		expect(rules.tutorial(state).step).toBe("SellPizza")
	end)

	it("does not move on when an action fails", function()
		local state = playUntil("SellPizza")

		local full = rules.collectTopping(state, "Salami", 1)
		local tooFar = rules.collectTopping(rules.newPlayerState(), "Salami", 99)

		expect(full.ok).toBe(false)
		expect(rules.tutorial(full.state).step).toBe("SellPizza")
		expect(rules.tutorial(tooFar.state).progress).toBe(0)
	end)

	it("moves from selling to buying an upgrade", function()
		local state = rules.sellPizza(playUntil("SellPizza")).state

		expect(rules.tutorial(state)).toEqual({ step = "BuyUpgrade", number = 3, total = 4, progress = 0, goal = 1 })
	end)

	it("does not count selling before the second topping was collected", function()
		local state = rules.collectTopping(rules.newPlayerState(), "Salami", 1).state

		state = rules.sellPizza(state).state

		expect(rules.tutorial(state).step).toBe("CollectToppings")
		expect(rules.tutorial(state).progress).toBe(0)
	end)

	it("moves from buying an upgrade to opening the first egg", function()
		local state = rules.buyUpgrade(playUntil("BuyUpgrade"), "SmallShop", "PizzaSpace").state

		expect(rules.tutorial(state).step).toBe("OpenEgg")
	end)

	it("keeps waiting for an upgrade when the purchase is refused", function()
		local state = playUntil("BuyUpgrade")
		state.coins = 0

		local result = rules.buyUpgrade(state, "SmallShop", "PizzaSpace")

		expect(rules.tutorial(result.state).step).toBe("BuyUpgrade")
	end)

	it("is finished after the first egg is opened", function()
		local state = rules.openEgg(playUntil("OpenEgg"), "TestEgg", fixedRandom()).state

		expect(rules.tutorial(state)).toBeNil()
	end)

	it("ignores actions of a later step until the current step is done", function()
		local state = rules.newPlayerState()
		state.coins = 100

		state = rules.buyUpgrade(state, "SmallShop", "PizzaSpace").state
		state = rules.openEgg(state, "TestEgg", fixedRandom()).state

		expect(rules.tutorial(state).step).toBe("CollectToppings")
	end)

	it("stays finished whatever the player does afterwards", function()
		local state = rules.openEgg(playUntil("OpenEgg"), "TestEgg", fixedRandom()).state

		state = rules.collectTopping(state, "Salami", 1).state
		state = rules.sellPizza(state).state

		expect(rules.tutorial(state)).toBeNil()
	end)

	it("does not change the state it was given", function()
		local state = rules.newPlayerState()

		rules.collectTopping(state, "Salami", 1)
		rules.collectTopping(rules.collectTopping(state, "Salami", 1).state, "Salami", 1)

		expect(state.tutorialStep).toBe(1)
	end)
end)

describe("tutorial progress in saves", function()
	it("is saved and loaded, so a player continues at the step they reached", function()
		local state = rules.sellPizza(playUntil("SellPizza")).state

		local loaded = SaveData.load(state, rules.newPlayerState())

		expect(rules.tutorial(loaded.state).step).toBe("BuyUpgrade")
	end)

	it("is never shown again once finished and saved", function()
		local finished = rules.openEgg(playUntil("OpenEgg"), "TestEgg", fixedRandom()).state

		local loaded = SaveData.load(finished, rules.newPlayerState())

		expect(rules.tutorial(loaded.state)).toBeNil()
	end)

	it("counts as finished for players whose save is older than the tutorial", function()
		local saved = { version = 2, coins = 800, pizza = {}, rebirthMultiplier = 1 }

		local loaded = SaveData.load(saved, rules.newPlayerState())

		expect(loaded.ok).toBe(true)
		expect(rules.tutorial(loaded.state)).toBeNil()
	end)

	it("still starts for brand-new players without a save", function()
		local loaded = SaveData.load(nil, rules.newPlayerState())

		expect(rules.tutorial(loaded.state).step).toBe("CollectToppings")
	end)
end)
