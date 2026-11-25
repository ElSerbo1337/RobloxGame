local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")
local SaveData = require("../src/shared/SaveData")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- Test config plus one event island (#77) with its own currency, open from t=1000
-- to t=2000. Its toppings pay Snowflakes instead of coins.
local config = table.clone(TestConfig)
config.toppings = table.clone(TestConfig.toppings)
config.toppings.Snowball =
	{ displayName = "Schneeball", displayNameEn = "Snowball", value = 3, currency = "Snowflakes" }
config.eventCurrencies = {
	Snowflakes = { displayName = "Schneeflocken", displayNameEn = "Snowflakes" },
}
config.eventWorlds = {
	{
		id = "WinterIsland",
		displayName = "Winterinsel",
		displayNameEn = "Winter Island",
		currency = "Snowflakes",
		startsAt = 1000,
		endsAt = 2000,
		toppingSpawns = { { topping = "Snowball", weight = 1 } },
	},
}

local rules = GameRules.new(config)

local function player()
	local state = rules.newPlayerState()
	state.tutorialStep = 1000
	return state
end

describe("event islands with their own currency (#77)", function()
	it("starts every player with no event currency", function()
		local state = player()

		expect(state.eventCurrencies).toEqual({})
		expect(rules.eventCurrency(state, "Snowflakes")).toBe(0)
	end)

	it("is open only between its start and end", function()
		expect(rules.isEventWorldOpen("WinterIsland", 999)).toBe(false)
		expect(rules.isEventWorldOpen("WinterIsland", 1000)).toBe(true)
		expect(rules.isEventWorldOpen("WinterIsland", 1999)).toBe(true)
		expect(rules.isEventWorldOpen("WinterIsland", 2000)).toBe(false)
		expect(rules.isEventWorldOpen("PizzeriaGarden", 1500)).toBe(false)
		expect(rules.isEventWorldOpen("Nowhere", 1500)).toBe(false)
	end)

	it("lets the portal send players there only while the event runs", function()
		local state = player()

		expect(rules.eventTeleport(state, "WinterIsland", 500).reason).toBe("EventClosed")
		local result = rules.eventTeleport(state, "WinterIsland", 1500)
		expect(result.ok).toBe(true)
		expect(result.state).toBe(state)
		expect(rules.eventTeleport(state, "Nowhere", 1500).reason).toBe("UnknownWorld")
	end)

	it("lists the event islands with their state for the portal menu", function()
		local entries = rules.eventWorldMenu(player(), 1500)

		expect(#entries).toBe(1)
		expect(entries[1].worldId).toBe("WinterIsland")
		expect(entries[1].currency).toBe("Snowflakes")
		expect(entries[1].amount).toBe(0)
		expect(entries[1].open).toBe(true)
		expect(entries[1].endsAt).toBe(2000)
		expect(rules.eventWorldMenu(player(), 2500)[1].open).toBe(false)
	end)

	it("pays event toppings in the event currency, without coins or multipliers", function()
		local state = player()
		state.rebirths = 2
		state.activePotions = { Coins = 100 }
		state.pizza = { "Snowball", "Snowball" }

		local result = rules.sellPizza(state)

		expect(result.ok).toBe(true)
		expect(result.coinsEarned).toBe(0)
		expect(result.currencyEarned).toEqual({ Snowflakes = 6 })
		expect(result.state.coins).toBe(0)
		expect(result.state.totalCoinsEarned).toBe(0)
		expect(rules.eventCurrency(result.state, "Snowflakes")).toBe(6)
		expect(rules.eventCurrency(state, "Snowflakes")).toBe(0)
	end)

	it("sells a mixed pizza: coins for normal toppings, event currency for event toppings", function()
		local state = player()
		state.pizza = { "Salami", "Snowball", "Mozzarella" }

		local result = rules.sellPizza(state)

		expect(result.coinsEarned).toBe(6)
		expect(result.state.coins).toBe(6)
		expect(result.currencyEarned).toEqual({ Snowflakes = 3 })
	end)

	it("reports no event currency when only normal toppings are sold", function()
		local state = player()
		state.pizza = { "Salami" }

		expect(rules.sellPizza(state).currencyEarned).toEqual({})
	end)

	it("spends event currency and refuses too little or an unknown currency", function()
		local state = player()
		state.eventCurrencies = { Snowflakes = 10 }

		local result = rules.spendEventCurrency(state, "Snowflakes", 4)
		expect(result.ok).toBe(true)
		expect(rules.eventCurrency(result.state, "Snowflakes")).toBe(6)
		expect(rules.eventCurrency(state, "Snowflakes")).toBe(10)

		expect(rules.spendEventCurrency(state, "Snowflakes", 11).reason).toBe("NotEnoughEventCurrency")
		expect(rules.spendEventCurrency(state, "Gold", 1).reason).toBe("UnknownCurrency")
		expect(rules.spendEventCurrency(state, "Snowflakes", -1).reason).toBe("InvalidAmount")
	end)

	it("keeps event currency through a rebirth", function()
		local state = player()
		state.coins = 1000
		state.eventCurrencies = { Snowflakes = 42 }

		local after = rules.rebirth(state, 0).state

		expect(after.eventCurrencies).toEqual({ Snowflakes = 42 })
	end)

	it("gives old saves an empty event purse when they are loaded", function()
		local old = player()
		old.eventCurrencies = nil :: any
		local loaded = SaveData.load(old, rules.newPlayerState())

		expect(loaded.ok).toBe(true)
		expect(loaded.state.eventCurrencies).toEqual({})
	end)

	it("works without any event islands in the config (normal worlds unchanged)", function()
		local plain = GameRules.new(TestConfig)

		expect(plain.eventWorldMenu(plain.newPlayerState(), 1500)).toEqual({})
		expect(plain.isEventWorldOpen("WinterIsland", 1500)).toBe(false)
	end)
end)
