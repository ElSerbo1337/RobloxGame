local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local rules = GameRules.new(TestConfig)

local function names(events: { any }): { string }
	local list = {}
	for _, event in events do
		table.insert(list, if event.step then `{event.name}#{event.step}` else event.name)
	end
	return list
end

local function keys(events: { any }): { string }
	local list = {}
	for _, event in events do
		if event.key then
			table.insert(list, event.key)
		end
	end
	return list
end

local function quest(claimed: boolean)
	return {
		kind = "CollectToppings",
		goal = 10,
		progress = 10,
		reward = { kind = "Gems", amount = 5 },
		claimed = claimed,
	}
end

describe("analytics events", function()
	it("logs the onboarding start and the free first world for a new player", function()
		local events = rules.analyticsEvents(nil, rules.newPlayerState())
		expect(names(events)).toEqual({ "Start#1", "PizzeriaGarden#1" })
		expect(events[1].kind).toBe("Onboarding")
		expect(events[2].kind).toBe("Funnel")
		expect(events[2].funnel).toBe("WorldUnlocks")
	end)

	it("logs one onboarding step per finished tutorial step, once", function()
		local state = rules.newPlayerState()
		state = rules.markAnalyticsLogged(state, keys(rules.analyticsEvents(nil, state))).state
		local after = table.clone(state)
		after.tutorialStep = 3
		local events = rules.analyticsEvents(state, after)
		expect(names(events)).toEqual({ "CollectToppings#2", "SellPizza#3" })
		after = rules.markAnalyticsLogged(after, keys(events)).state
		expect(#rules.analyticsEvents(state, after)).toBe(0)
	end)

	it("ends the onboarding funnel after the last tutorial step", function()
		local state = rules.newPlayerState()
		state.tutorialStep = 1000
		local events = rules.analyticsEvents(nil, state)
		expect(names(events)[5]).toBe("OpenEgg#5")
		expect(#events).toBe(6) -- 5 onboarding steps + first world
	end)

	it("logs the first unlock of each world only once, also after a rebirth", function()
		local state = rules.newPlayerState()
		state.unlockedWorlds = { "Farm" }
		local events = rules.analyticsEvents(nil, state)
		expect(names(events)).toEqual({ "Start#1", "PizzeriaGarden#1", "Farm#2" })
		state = rules.markAnalyticsLogged(state, keys(events)).state
		state.coins = 1000000
		local reborn = rules.rebirth(state, 0).state
		reborn.unlockedWorlds = { "Farm" }
		expect(names(rules.analyticsEvents(nil, reborn))).toEqual({ "FirstRebirth" })
		reborn = rules.markAnalyticsLogged(reborn, { "rebirth:1" }).state
		local again = rules.rebirth(
			(function()
				reborn.coins = 1000000000
				return reborn
			end)(),
			0
		).state
		expect(#rules.analyticsEvents(nil, again)).toBe(0)
	end)

	it("logs claimed quests and wheel spins during the session, never from a load", function()
		local state = rules.newPlayerState()
		state = rules.markAnalyticsLogged(state, keys(rules.analyticsEvents(nil, state))).state
		state.dailyQuests = { quest(false), quest(true) }
		state.weeklyQuests = { quest(false) }
		local after = table.clone(state)
		after.dailyQuests = { quest(true), quest(true) }
		after.weeklyQuests = { quest(true) }
		after.wheelSpins = 2
		local events = rules.analyticsEvents(state, after)
		expect(names(events)).toEqual({ "QuestClaimed", "QuestClaimed", "WheelSpin" })
		expect(events[1].field).toBe("Daily")
		expect(events[2].field).toBe("Weekly")
		expect(events[3].value).toBe(2)
		expect(#rules.analyticsEvents(nil, after)).toBe(0)
	end)

	it("logs nothing while the analytics switch is off", function()
		local config = table.clone(TestConfig)
		config.features = table.clone(TestConfig.features or {})
		config.features.analytics = false
		local off = GameRules.new(config)
		expect(#off.analyticsEvents(nil, off.newPlayerState())).toBe(0)
	end)

	it("marks keys without changing the old state", function()
		local state = rules.newPlayerState()
		local marked = rules.markAnalyticsLogged(state, { "rebirth:1" }).state
		expect(marked.analyticsLogged["rebirth:1"]).toBe(true)
		expect(state.analyticsLogged["rebirth:1"]).toBeNil()
	end)
end)
