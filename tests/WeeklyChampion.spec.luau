-- New leaderboards and Weekly Champion (#109): weeks in German time, weekly scores,
-- champions of last week.
local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")
local Leaderboard = require("../src/shared/Leaderboard")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local rules = GameRules.new(TestConfig)

-- Monday 23.11.2026 00:00 CET = Sunday 22.11.2026 23:00 UTC.
local MONDAY_WINTER = 1795388400
-- Monday 13.07.2026 00:00 CEST = Sunday 12.07.2026 22:00 UTC.
local MONDAY_SUMMER = 1783893600

describe("week number in German time", function()
	it("starts the week on Monday 0:00 German time (winter)", function()
		local week = GameRules.weekNumber(MONDAY_WINTER)
		expect(GameRules.weekNumber(MONDAY_WINTER - 1)).toBe(week - 1)
		expect(GameRules.weekNumber(MONDAY_WINTER + 7 * 86400 - 1)).toBe(week)
		expect(GameRules.weekNumber(MONDAY_WINTER + 7 * 86400)).toBe(week + 1)
		expect(GameRules.weekStart(week)).toBe(MONDAY_WINTER)
	end)

	it("starts the week on Monday 0:00 German time (summer)", function()
		local week = GameRules.weekNumber(MONDAY_SUMMER)
		expect(GameRules.weekNumber(MONDAY_SUMMER - 1)).toBe(week - 1)
		expect(GameRules.weekStart(week)).toBe(MONDAY_SUMMER)
	end)

	it("handles the week with the clock change (Monday after the last Sunday of October)", function()
		-- Monday 26.10.2026 00:00 CET = Sunday 25.10. 23:00 UTC (summer time ended at 01:00 UTC).
		local monday = 1792969200
		local week = GameRules.weekNumber(monday)
		expect(GameRules.weekNumber(monday - 1)).toBe(week - 1)
		expect(GameRules.weekStart(week)).toBe(monday)
		-- The week before began on summer time: Monday 19.10. 00:00 CEST = 18.10. 22:00 UTC.
		expect(GameRules.weekStart(week - 1)).toBe(1792360800)
	end)

	it("lets the title run until the end of the following week", function()
		local week = GameRules.weekNumber(MONDAY_WINTER + 3600)
		expect(GameRules.championUntil(MONDAY_WINTER + 3600)).toBe(GameRules.weekStart(week + 1))
	end)
end)

describe("weekly scores", function()
	it("count eggs and toppings from the start of the week on", function()
		local state = rules.newPlayerState()
		state.eggsOpened = 10
		state.toppingsCollected = 100
		local result = rules.rollStatsWeek(state, MONDAY_WINTER + 60)
		expect(result.ok).toBe(true)
		local rolled = result.state
		rolled.eggsOpened = 13
		rolled.toppingsCollected = 150
		expect(rules.weeklyScores(rolled)).toEqual({
			week = GameRules.weekNumber(MONDAY_WINTER),
			EggsOpened = 3,
			ToppingsCollected = 50,
		})
	end)

	it("only rolls once per week", function()
		local state = rules.rollStatsWeek(rules.newPlayerState(), MONDAY_WINTER).state
		local again = rules.rollStatsWeek(state, MONDAY_WINTER + 6 * 86400)
		expect(again.ok).toBe(false)
		expect(again.reason).toBe("SameWeek")
		expect(rules.rollStatsWeek(state, MONDAY_WINTER + 7 * 86400).ok).toBe(true)
	end)

	it("has no week before the first roll", function()
		expect(rules.weeklyScores(rules.newPlayerState()).week).toBe(0)
	end)

	it("adds the lifetime eggs and toppings to the leaderboard scores", function()
		local state = rules.newPlayerState()
		state.eggsOpened = 7
		state.toppingsCollected = 42
		local scores = rules.leaderboardScores(state)
		expect(scores.EggsOpened).toBe(7)
		expect(scores.ToppingsCollected).toBe(42)
	end)
end)

describe("weekly champions", function()
	it("are the top 3 with a score of every weekly board", function()
		local champions = GameRules.weeklyChampions({
			{ { key = "1", value = 9 }, { key = "2", value = 5 }, { key = "3", value = 4 }, { key = "4", value = 3 } },
			{ { key = "2", value = 50 }, { key = "5", value = 0 } },
		}, 3)
		expect(champions).toEqual({ [1] = true, [2] = true, [3] = true })
	end)

	it("ignores broken keys", function()
		expect(GameRules.weeklyChampions({ { { key = "x", value = 9 } } }, 3)).toEqual({})
	end)
end)

describe("weekly store names", function()
	it("get the week number before the fresh-start suffix", function()
		expect(Leaderboard.weeklyStore("Leaderboard_EggsOpened_week", 2970)).toBe(
			"Leaderboard_EggsOpened_week2970_mega1"
		)
	end)
end)
