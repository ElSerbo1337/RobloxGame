local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")
local SaveData = require("../src/shared/SaveData")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local rules = GameRules.new(TestConfig)

describe("SaveData.load", function()
	it("gives a new player a fresh state when nothing is saved", function()
		local result = SaveData.load(nil, rules.newPlayerState())

		expect(result.ok).toBe(true)
		expect(result.state).toEqual(rules.newPlayerState())
	end)

	it("keeps coins and pizza of a version 1 save and adds a rebirth multiplier of 1", function()
		local saved = { version = 1, coins = 1234, pizza = { "Salami", "Mozzarella" } }

		local result = SaveData.load(saved, rules.newPlayerState())

		expect(result.ok).toBe(true)
		expect(result.state.coins).toBe(1234)
		expect(result.state.pizza).toEqual({ "Salami", "Mozzarella" })
		expect(result.state.rebirthMultiplier).toBe(1)
		expect(result.state.version).toBe(rules.newPlayerState().version)
	end)

	it("fills fields that did not exist when the save was written with their defaults", function()
		local fresh = rules.newPlayerState()
		fresh.gems = 0
		fresh.unlockedWorlds = { "PizzeriaGarden" }
		local saved = { version = fresh.version, coins = 40, pizza = {}, rebirthMultiplier = 3 }

		local result = SaveData.load(saved, fresh)

		expect(result.ok).toBe(true)
		expect(result.state.coins).toBe(40)
		expect(result.state.rebirthMultiplier).toBe(3)
		expect(result.state.gems).toBe(0)
		expect(result.state.unlockedWorlds).toEqual({ "PizzeriaGarden" })
	end)

	it("replaces a field of the wrong type with its default", function()
		local saved = { version = 2, coins = "lots", pizza = { "Salami" }, rebirthMultiplier = 1 }

		local result = SaveData.load(saved, rules.newPlayerState())

		expect(result.ok).toBe(true)
		expect(result.state.coins).toBe(0)
		expect(result.state.pizza).toEqual({ "Salami" })
	end)

	it("refuses a save from a newer game version so it is never overwritten", function()
		local saved = { version = 99, coins = 5000, pizza = {}, rebirthMultiplier = 2 }

		local result = SaveData.load(saved, rules.newPlayerState())

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("NewerVersion")
	end)

	it("refuses saved data that is not a table", function()
		local result = SaveData.load("garbage", rules.newPlayerState())

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("Corrupt")
	end)

	it("does not change the saved data it was given", function()
		local saved = { version = 1, coins = 7, pizza = { "Salami" } }

		SaveData.load(saved, rules.newPlayerState())

		expect(saved).toEqual({ version = 1, coins = 7, pizza = { "Salami" } })
	end)
end)
