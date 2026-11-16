local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")
local SaveData = require("../src/shared/SaveData")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local rules = GameRules.new(TestConfig)

local function withCoins(coins: number)
	local state = rules.newPlayerState()
	state.coins = coins
	return state
end

describe("worlds", function()
	it("starts a new player with only the free first world unlocked", function()
		local state = rules.newPlayerState()

		expect(rules.isWorldUnlocked(state, "PizzeriaGarden")).toBe(true)
		expect(rules.isWorldUnlocked(state, "Farm")).toBe(false)
	end)

	it("unlocks the next world for its price", function()
		local before = withCoins(2000)

		local result = rules.unlockWorld(before, "Farm")

		expect(result.ok).toBe(true)
		expect(result.state.coins).toBe(500)
		expect(rules.isWorldUnlocked(result.state, "Farm")).toBe(true)
		expect(rules.isWorldUnlocked(before, "Farm")).toBe(false)
		expect(before.coins).toBe(2000)
	end)

	it("refuses to unlock a world the player cannot afford", function()
		local result = rules.unlockWorld(withCoins(1499), "Farm")

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("NotEnoughCoins")
		expect(result.state.coins).toBe(1499)
		expect(rules.isWorldUnlocked(result.state, "Farm")).toBe(false)
	end)

	it("does not charge twice for a world that is already unlocked", function()
		local state = rules.unlockWorld(withCoins(5000), "Farm").state

		local result = rules.unlockWorld(state, "Farm")

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("AlreadyUnlocked")
		expect(result.state.coins).toBe(3500)
	end)

	it("only unlocks worlds in order, so a barrier behind a locked world stays closed", function()
		local result = rules.unlockWorld(withCoins(100000), "Beach")

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("PreviousWorldLocked")
		expect(result.state.coins).toBe(100000)
	end)

	it("rejects worlds that are not in the config", function()
		local result = rules.unlockWorld(withCoins(100000), "Atlantis")

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("UnknownWorld")
		expect(rules.isWorldUnlocked(result.state, "Atlantis")).toBe(false)
	end)

	it("refuses to collect toppings of a world the player has not unlocked", function()
		local result = rules.collectTopping(rules.newPlayerState(), "Ham", 1)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("WorldLocked")
		expect(result.state.pizza).toEqual({})
	end)

	it("collects toppings of a world once it is unlocked", function()
		local state = rules.unlockWorld(withCoins(1500), "Farm").state

		local result = rules.collectTopping(state, "Ham", 1)

		expect(result.ok).toBe(true)
		expect(result.state.pizza).toEqual({ "Ham" })
	end)

	it("keeps an unlocked world after saving and rejoining", function()
		local unlocked = rules.unlockWorld(withCoins(1500), "Farm").state

		local rejoined = SaveData.load(unlocked, rules.newPlayerState()).state

		expect(rules.isWorldUnlocked(rejoined, "Farm")).toBe(true)
	end)

	it("loads a save from before worlds existed with only the first world open", function()
		local saved = { version = 1, coins = 5000, pizza = {} }

		local state = SaveData.load(saved, rules.newPlayerState()).state

		expect(rules.isWorldUnlocked(state, "PizzeriaGarden")).toBe(true)
		expect(rules.isWorldUnlocked(state, "Farm")).toBe(false)
	end)
end)
