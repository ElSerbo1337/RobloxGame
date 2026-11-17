local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- Test config plus a fourth world behind 2 rebirths (#43). Worlds 1-3 have no field.
local config = table.clone(TestConfig)
config.worlds = table.clone(TestConfig.worlds)
table.insert(config.worlds, {
	id = "Icebergs",
	displayName = "Eisberge",
	unlockPrice = 50000,
	requiredRebirths = 2,
	toppingSpawns = {},
})

local rules = GameRules.new(config)

-- A player who bought worlds 2-3, with `rebirths` rebirths done and plenty of coins.
local function atBeach(rebirths: number)
	local state = rules.newPlayerState()
	state.rebirths = rebirths
	state.unlockedWorlds = { "Farm", "Beach" }
	state.coins = 100000
	return state
end

describe("worlds with a minimum number of rebirths", function()
	it("refuses to unlock a world while the player has too few rebirths", function()
		local before = atBeach(1)

		local result = rules.unlockWorld(before, "Icebergs")

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("NotEnoughRebirths")
		expect(result.state.coins).toBe(100000)
		expect(rules.isWorldUnlocked(result.state, "Icebergs")).toBe(false)
	end)

	it("unlocks the world for its price once the player has enough rebirths", function()
		local result = rules.unlockWorld(atBeach(2), "Icebergs")

		expect(result.ok).toBe(true)
		expect(result.state.coins).toBe(50000)
		expect(rules.isWorldUnlocked(result.state, "Icebergs")).toBe(true)
	end)

	it("also allows more rebirths than required", function()
		expect(rules.unlockWorld(atBeach(5), "Icebergs").ok).toBe(true)
	end)

	it("still asks for the previous world first", function()
		local state = atBeach(2)
		state.unlockedWorlds = { "Farm" }

		expect(rules.unlockWorld(state, "Icebergs").reason).toBe("PreviousWorldLocked")
	end)

	it("treats a world without the field as needing 0 rebirths", function()
		local state = rules.newPlayerState()
		state.coins = 1500

		expect(rules.rebirthsNeeded("Farm")).toBe(0)
		expect(rules.hasRebirthsFor(state, "Farm")).toBe(true)
		expect(rules.unlockWorld(state, "Farm").ok).toBe(true)
	end)

	it("tells how many rebirths a world needs and whether the player has them", function()
		expect(rules.rebirthsNeeded("Icebergs")).toBe(2)
		expect(rules.hasRebirthsFor(atBeach(1), "Icebergs")).toBe(false)
		expect(rules.hasRebirthsFor(atBeach(2), "Icebergs")).toBe(true)
		expect(rules.rebirthsNeeded("Atlantis")).toBe(0)
	end)

	it("does not treat a free world behind rebirths as open", function()
		local freeConfig = table.clone(config)
		freeConfig.worlds = table.clone(config.worlds)
		freeConfig.worlds[4] = table.clone(config.worlds[4])
		freeConfig.worlds[4].unlockPrice = 0
		local freeRules = GameRules.new(freeConfig)

		expect(freeRules.isWorldUnlocked(atBeach(0), "Icebergs")).toBe(false)
		expect(freeRules.unlockWorld(atBeach(0), "Icebergs").reason).toBe("NotEnoughRebirths")
		local result = freeRules.unlockWorld(atBeach(2), "Icebergs")
		expect(result.ok).toBe(true)
		expect(result.state.coins).toBe(100000)
	end)

	it("puts the condition into the portal menu", function()
		local menu = rules.portalMenu(atBeach(1))

		expect(menu[2].requiredRebirths).toBe(0)
		expect(menu[2].enoughRebirths).toBe(true)
		expect(menu[4].requiredRebirths).toBe(2)
		expect(menu[4].enoughRebirths).toBe(false)
		expect(menu[4].unlocked).toBe(false)
		expect(rules.portalMenu(atBeach(2))[4].enoughRebirths).toBe(true)
	end)

	it("closes the world again on a rebirth like every bought world", function()
		local state = rules.unlockWorld(atBeach(2), "Icebergs").state
		state.coins = 1000000000

		local result = rules.rebirth(state, 0)

		expect(result.ok).toBe(true)
		expect(rules.isWorldUnlocked(result.state, "Icebergs")).toBe(false)
		expect(rules.hasRebirthsFor(result.state, "Icebergs")).toBe(true)
	end)
end)
