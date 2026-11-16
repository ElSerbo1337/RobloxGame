local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local rules = GameRules.new(TestConfig)

local function withFarm()
	local state = rules.newPlayerState()
	state.coins = 1500
	return rules.unlockWorld(state, "Farm").state
end

describe("portals", function()
	it("lets a player teleport into the free first world", function()
		local before = rules.newPlayerState()

		local result = rules.teleport(before, "PizzeriaGarden")

		expect(result.ok).toBe(true)
		expect(result.state).toEqual(before)
	end)

	it("refuses to teleport into a world the player has not unlocked", function()
		local result = rules.teleport(rules.newPlayerState(), "Farm")

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("WorldLocked")
	end)

	it("lets a player teleport into a world once it is unlocked", function()
		local result = rules.teleport(withFarm(), "Farm")

		expect(result.ok).toBe(true)
	end)

	it("rejects teleport targets that are not in the config", function()
		local result = rules.teleport(withFarm(), "Atlantis")

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("UnknownWorld")
	end)

	it("does not charge coins for teleporting", function()
		local before = withFarm()
		before.coins = 42

		local result = rules.teleport(before, "Farm")

		expect(result.state.coins).toBe(42)
	end)

	it("lists every configured world in order for the portal menu", function()
		local menu = rules.portalMenu(rules.newPlayerState())

		expect(#menu).toBe(#TestConfig.worlds)
		for index, world in TestConfig.worlds do
			expect(menu[index].worldId).toBe(world.id)
			expect(menu[index].displayName).toBe(world.displayName)
			expect(menu[index].unlockPrice).toBe(world.unlockPrice)
		end
	end)

	it("marks unlocked worlds as selectable and locked ones with their price", function()
		local menu = rules.portalMenu(withFarm())

		expect(menu[1].unlocked).toBe(true)
		expect(menu[2].unlocked).toBe(true)
		expect(menu[3].unlocked).toBe(false)
		expect(menu[3].unlockPrice).toBe(15000)
	end)
end)
