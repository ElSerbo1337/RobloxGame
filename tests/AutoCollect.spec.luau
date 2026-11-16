local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local rules = GameRules.new(TestConfig)

describe("setAutoCollect", function()
	it("starts switched off for a new player", function()
		expect(rules.newPlayerState().autoCollect).toBe(false)
	end)

	it("switches auto-collect on for free without touching the old state", function()
		local state = rules.newPlayerState()

		local result = rules.setAutoCollect(state, true)

		expect(result.ok).toBe(true)
		expect(result.state.autoCollect).toBe(true)
		expect(result.state.coins).toBe(0)
		expect(state.autoCollect).toBe(false)
	end)

	it("switches auto-collect off again", function()
		local state = rules.setAutoCollect(rules.newPlayerState(), true).state

		local result = rules.setAutoCollect(state, false)

		expect(result.ok).toBe(true)
		expect(result.state.autoCollect).toBe(false)
	end)
end)

describe("autoCollectTopping", function()
	local function switchedOn()
		return rules.setAutoCollect(rules.newPlayerState(), true).state
	end

	it("picks up a topping the player walks over", function()
		local result = rules.autoCollectTopping(switchedOn(), "Mushroom", 2)

		expect(result.ok).toBe(true)
		expect(result.state.pizza).toEqual({ "Mushroom" })
	end)

	it("does nothing while the switch is off", function()
		local result = rules.autoCollectTopping(rules.newPlayerState(), "Mushroom", 2)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("AutoCollectOff")
		expect(result.state.pizza).toEqual({})
	end)

	it("only reaches toppings within the pickup radius, not the click range", function()
		expect(rules.autoCollectTopping(switchedOn(), "Salami", 3).ok).toBe(true)

		local result = rules.autoCollectTopping(switchedOn(), "Salami", 3.5)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("OutOfRange")
	end)

	it("respects the pizza capacity and leaves the topping for others", function()
		local state = switchedOn()
		state = rules.autoCollectTopping(state, "Salami", 1).state
		state = rules.autoCollectTopping(state, "Salami", 1).state

		local result = rules.autoCollectTopping(state, "Mozzarella", 1)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("PizzaFull")
		expect(result.state.pizza).toEqual({ "Salami", "Salami" })
	end)

	it("rejects a topping that is not in the config", function()
		local result = rules.autoCollectTopping(switchedOn(), "Pineapple", 1)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("UnknownTopping")
	end)
end)

describe("isPizzaFull", function()
	it("is false while there is room and true once the last slot is filled", function()
		local state = rules.newPlayerState()
		expect(rules.isPizzaFull(state)).toBe(false)

		state = rules.collectTopping(state, "Salami", 1).state
		expect(rules.isPizzaFull(state)).toBe(false)

		state = rules.collectTopping(state, "Salami", 1).state
		expect(rules.isPizzaFull(state)).toBe(true)
	end)

	it("is false again after selling", function()
		local state = rules.newPlayerState()
		state = rules.collectTopping(state, "Salami", 1).state
		state = rules.collectTopping(state, "Salami", 1).state

		expect(rules.isPizzaFull(rules.sellPizza(state).state)).toBe(false)
	end)
end)
