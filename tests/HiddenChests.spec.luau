local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local AdminActions = require("../src/shared/AdminActions")
local GameConfig = require("../src/shared/GameConfig")
local GameRules = require("../src/shared/GameRules")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local rules = GameRules.new(TestConfig)

-- 15.01.2026 11:00 CET, the same day 12:59 CET (23:59 German time) and a day later.
local NOW = 1768431600 + 11 * 3600
local LATE = NOW + 12 * 3600 + 59 * 60
local NEXT_DAY = NOW + 24 * 3600

local function farmer()
	local state = rules.newPlayerState()
	state.unlockedWorlds = { "Farm", "Beach" }
	return state
end

local function withConfig(changes: { [string]: any })
	local config = table.clone(TestConfig)
	for key, value in changes do
		config[key] = value
	end
	return GameRules.new(config)
end

describe("hidden chests (#100)", function()
	it("pays the chest gems once per German day and chest", function()
		local result = rules.openSecretChest(farmer(), "Farm", NOW)
		expect(result.ok).toBe(true)
		expect(result.state.gems).toBe(10)
		expect(result.rewards[1].kind).toBe("Gems")
		expect(result.rewards[1].amount).toBe(10)
		expect(result.state.secretChestsOpened).toBe(1)
		expect(rules.secretChestReady(result.state, "Farm", NOW)).toBe(false)

		local again = rules.openSecretChest(result.state, "Farm", LATE)
		expect(again.ok).toBe(false)
		expect(again.reason).toBe("AlreadyOpened")
		expect(again.state).toBe(result.state)

		-- Another chest the same day is its own chest.
		local beach = rules.openSecretChest(result.state, "Beach", LATE)
		expect(beach.ok).toBe(true)
		expect(beach.state.gems).toBe(20)

		local tomorrow = rules.openSecretChest(beach.state, "Farm", NEXT_DAY)
		expect(tomorrow.ok).toBe(true)
		expect(tomorrow.state.gems).toBe(30)
	end)

	it("refuses worlds without a chest, locked worlds and a switched-off feature", function()
		expect(rules.openSecretChest(farmer(), "PizzeriaGarden", NOW).reason).toBe("NoChest")
		expect(rules.openSecretChest(rules.newPlayerState(), "Farm", NOW).reason).toBe("WorldLocked")
		local off = withConfig({ features = { hiddenChests = false } })
		local state = off.newPlayerState()
		state.unlockedWorlds = { "Farm" }
		expect(off.openSecretChest(state, "Farm", NOW).reason).toBe("NoChest")
		expect(off.secretChestReady(state, "Farm", NOW)).toBe(false)
		local none = withConfig({ hiddenChests = false })
		expect(none.openSecretChest(state, "Farm", NOW).reason).toBe("NoChest")
	end)

	it("counts for running OpenChest quests", function()
		local state = farmer()
		state.dailyQuests = { { kind = "OpenChest", goal = 2, progress = 0 } }
		local result = rules.openSecretChest(state, "Farm", NOW)
		expect(result.state.dailyQuests[1].progress).toBe(1)
		expect(state.dailyQuests[1].progress).toBe(0)
		expect(GameRules.QUEST_SOURCES.OpenChest).toBe(true)
	end)

	it("lets the admin skipDays make a chest openable again", function()
		local opened = rules.openSecretChest(farmer(), "Farm", NOW).state
		local field = rules.secretChestField("Farm")
		expect(opened[field]).toBe(GameRules.dayNumber(NOW))
		expect(field).toBe("chestDayFarm")
	end)

	it("has a chest spot and a skipDays day field for every chest world of the real config", function()
		local chests = GameConfig.hiddenChests
		expect(chests.gems).toBe(5) -- #108: 5 per chest, up to 25 gems a day
		expect(chests.sparkleDistance).toBe(30)
		local real = GameRules.new(GameConfig)
		local expected = { "Beach", "CandyLand", "JungleTemple", "DinoAge", "PizzaParadise" }
		expect(#chests.worlds).toBe(#expected)
		for index, worldId in expected do
			expect(chests.worlds[index]).toBe(worldId)
			expect(GameConfig.islands.themes[worldId].secretChest ~= nil).toBe(true)
			expect(table.find(AdminActions.DAY_FIELDS, real.secretChestField(worldId)) ~= nil).toBe(true)
			expect(real.newPlayerState()[real.secretChestField(worldId)]).toBe(0)
		end
	end)
end)
