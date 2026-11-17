local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")
local SaveData = require("../src/shared/SaveData")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local rules = GameRules.new(TestConfig)

local function withFarm()
	local state = rules.newPlayerState()
	state.coins = 1500
	return rules.unlockWorld(state, "Farm").state
end

describe("entering a world", function()
	it("starts a new player without a last visited world, so they spawn at the start", function()
		local state = rules.newPlayerState()

		expect(rules.spawnWorld(state)).toBe(nil)
	end)

	it("remembers an unlocked world the player walked or teleported into", function()
		local result = rules.enterWorld(withFarm(), "Farm")

		expect(result.ok).toBe(true)
		expect(result.state.lastWorldId).toBe("Farm")
		expect(rules.spawnWorld(result.state)).toBe("Farm")
	end)

	it("remembers the free first world", function()
		local entered = rules.enterWorld(withFarm(), "Farm").state

		local result = rules.enterWorld(entered, "PizzeriaGarden")

		expect(result.ok).toBe(true)
		expect(rules.spawnWorld(result.state)).toBe("PizzeriaGarden")
	end)

	it("refuses a world the player has not unlocked and keeps the last world", function()
		local before = rules.enterWorld(rules.newPlayerState(), "PizzeriaGarden").state

		local result = rules.enterWorld(before, "Farm")

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("WorldLocked")
		expect(result.state.lastWorldId).toBe("PizzeriaGarden")
	end)

	it("refuses a world that is not in the config", function()
		local result = rules.enterWorld(withFarm(), "Atlantis")

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("UnknownWorld")
	end)

	it("does not change the old state", function()
		local before = withFarm()

		rules.enterWorld(before, "Farm")

		expect(before.lastWorldId).toBe("")
	end)

	it("keeps the very same state when the player is already in that world", function()
		local inFarm = rules.enterWorld(withFarm(), "Farm").state

		local result = rules.enterWorld(inFarm, "Farm")

		expect(result.ok).toBe(true)
		expect(result.state == inFarm).toBe(true)
	end)

	it("spawns at the start when the last world is no longer unlocked", function()
		local state = rules.newPlayerState()
		state.lastWorldId = "Farm"

		expect(rules.spawnWorld(state)).toBe(nil)
	end)

	it("spawns at the start when the last world is unknown", function()
		local state = withFarm()
		state.lastWorldId = "Atlantis"

		expect(rules.spawnWorld(state)).toBe(nil)
	end)

	it("loads an old save without a last world and spawns it at the start", function()
		local saved = { version = 3, coins = 1500, unlockedWorlds = { "Farm" } }

		local result = SaveData.load(saved, rules.newPlayerState())

		expect(result.ok).toBe(true)
		expect(result.state.lastWorldId).toBe("")
		expect(rules.spawnWorld(result.state)).toBe(nil)
	end)

	it("keeps the last world of a save", function()
		local saved = { version = 3, unlockedWorlds = { "Farm" }, lastWorldId = "Farm" }

		local result = SaveData.load(saved, rules.newPlayerState())

		expect(rules.spawnWorld(result.state)).toBe("Farm")
	end)
end)
