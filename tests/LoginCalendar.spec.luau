local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")
local SaveData = require("../src/shared/SaveData")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect
local sequenceRandom = TestKit.sequenceRandom

local rules = GameRules.new(TestConfig)

-- 15.01.2026 11:00 CET (German day 20468); DAY(n) is the same time n days later.
local NOW = 1768431600 + 11 * 3600
local function DAY(n: number): number
	return NOW + n * 24 * 3600
end
local NO_RANDOM = sequenceRandom({ 0 })

-- TestConfig calendar: 1 coins (5 min of income), 2 10 gems, 3 1 potion, 4 coins (10 min),
-- 5 20 gems, 6 2 potions, 7 50 gems + 3 potions. A new player earns 6.8 coins a minute
-- (Income.spec), with the farm unlocked 32.

-- Claims on each of the given days (day offsets from NOW), starting from `state`.
local function claimOn(state: any, days: { number }): any
	for _, day in days do
		local result = rules.claimLoginReward(state, DAY(day), NO_RANDOM)
		assert(result.ok, `claim on day {day} failed: {result.reason}`)
		state = result.state
	end
	return state
end

describe("login calendar status", function()
	it("a new player is on calendar day 1 and can claim it", function()
		local calendar = rules.loginCalendar(rules.newPlayerState(), NOW)

		expect(calendar.today).toBe(1)
		expect(calendar.claimable).toBe(true)
		expect(#calendar.days).toBe(7)
		expect(calendar.days[1].status).toBe("Ready")
		expect(calendar.days[2].status).toBe("Waiting")
		expect(calendar.days[7].status).toBe("Waiting")
	end)

	it("shows the rewards of all seven days, coins from the income estimate", function()
		local days = rules.loginCalendar(rules.newPlayerState(), NOW).days

		expect(days[1].rewards).toEqual({ { kind = "Coins", amount = 34 } })
		expect(days[2].rewards).toEqual({ { kind = "Gems", amount = 10 } })
		expect(days[3].rewards).toEqual({ { kind = "Potion", amount = 1 } })
		expect(days[4].rewards).toEqual({ { kind = "Coins", amount = 68 } })
		expect(days[7].rewards).toEqual({ { kind = "Gems", amount = 50 }, { kind = "Potion", amount = 3 } })
	end)

	it("after claiming, today is claimed and nothing is claimable until tomorrow", function()
		local calendar = rules.loginCalendar(claimOn(rules.newPlayerState(), { 0 }), DAY(0) + 3600)

		expect(calendar.today).toBe(1)
		expect(calendar.claimable).toBe(false)
		expect(calendar.days[1].status).toBe("Claimed")
		expect(calendar.days[2].status).toBe("Waiting")
	end)

	it("on the next day the next calendar day is ready, earlier ones show as claimed", function()
		local calendar = rules.loginCalendar(claimOn(rules.newPlayerState(), { 0, 1 }), DAY(2))

		expect(calendar.today).toBe(3)
		expect(calendar.claimable).toBe(true)
		expect(calendar.days[1].status).toBe("Claimed")
		expect(calendar.days[2].status).toBe("Claimed")
		expect(calendar.days[3].status).toBe("Ready")
	end)
end)

describe("claiming the login reward", function()
	it("first day: pays the day 1 coins and remembers the claim", function()
		local result = rules.claimLoginReward(rules.newPlayerState(), NOW, NO_RANDOM)

		expect(result.ok).toBe(true)
		expect(result.day).toBe(1)
		expect(result.rewards).toEqual({ { kind = "Coins", amount = 34 } })
		expect(result.state.coins).toBe(34)
	end)

	it("next day: the series goes up by one", function()
		local state = claimOn(rules.newPlayerState(), { 0 })

		local result = rules.claimLoginReward(state, DAY(1), NO_RANDOM)

		expect(result.ok).toBe(true)
		expect(result.day).toBe(2)
		expect(result.state.gems).toBe(10)
	end)

	it("a new day starts at midnight German time, not after 24 hours", function()
		-- 15.01.2026 23:30 CET, then 16.01.2026 00:10 CET.
		local lateEvening = 1768431600 + 23 * 3600 + 30 * 60
		local state = rules.claimLoginReward(rules.newPlayerState(), lateEvening, NO_RANDOM).state

		local result = rules.claimLoginReward(state, lateEvening + 40 * 60, NO_RANDOM)

		expect(result.ok).toBe(true)
		expect(result.day).toBe(2)
	end)

	it("a missed day starts the series over at day 1", function()
		local state = claimOn(rules.newPlayerState(), { 0, 1, 2 })

		local result = rules.claimLoginReward(state, DAY(4), NO_RANDOM)

		expect(result.day).toBe(1)
		expect(rules.loginCalendar(state, DAY(4)).today).toBe(1)
	end)

	it("after day 7 the calendar starts over at day 1", function()
		local state = claimOn(rules.newPlayerState(), { 0, 1, 2, 3, 4, 5 })

		local seventh = rules.claimLoginReward(state, DAY(6), NO_RANDOM)
		local eighth = rules.claimLoginReward(seventh.state, DAY(7), NO_RANDOM)

		expect(seventh.day).toBe(7)
		expect(eighth.day).toBe(1)
		expect(eighth.rewards).toEqual({ { kind = "Coins", amount = 34 } })
	end)

	it("pays gems and random potions like gifts (sorted ids: Coins, Luck, Speed)", function()
		local state = claimOn(rules.newPlayerState(), { 0, 1, 2, 3, 4, 5 })

		local result = rules.claimLoginReward(state, DAY(6), sequenceRandom({ 0.5 }))

		expect(result.rewards).toEqual({
			{ kind = "Gems", amount = 50 },
			{ kind = "Potion", amount = 3, potionId = "Luck" },
		})
		expect(result.state.gems - state.gems).toBe(50)
		expect(rules.potionCount(result.state, "Luck") - rules.potionCount(state, "Luck")).toBe(3)
	end)

	it("refuses a second claim on the same day", function()
		local state = claimOn(rules.newPlayerState(), { 0 })

		local result = rules.claimLoginReward(state, DAY(0) + 6 * 3600, NO_RANDOM)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("LoginClaimed")
		expect(result.state).toBe(state)
		expect(result.rewards).toEqual({})
	end)

	it("refuses a claim when the last claim lies in the future (clock of another server behind)", function()
		local state = claimOn(rules.newPlayerState(), { 1 })

		expect(rules.claimLoginReward(state, DAY(0), NO_RANDOM).reason).toBe("LoginClaimed")
		expect(rules.loginCalendar(state, DAY(0)).claimable).toBe(false)
	end)

	it("coins scale with the highest unlocked world", function()
		local state = rules.newPlayerState()
		state.unlockedWorlds = { "Farm" }

		local result = rules.claimLoginReward(state, NOW, NO_RANDOM)

		expect(result.state.coins).toBe(160)
	end)

	it("does not change the old state", function()
		local state = rules.newPlayerState()
		rules.claimLoginReward(state, NOW, NO_RANDOM)

		expect(state.coins).toBe(0)
		expect(rules.loginCalendar(state, NOW).claimable).toBe(true)
	end)
end)

describe("opening the calendar on join", function()
	it("opens on the first join of a day", function()
		local result = rules.markLoginCalendarShown(rules.newPlayerState(), NOW)

		expect(result.ok).toBe(true)
	end)

	it("does not open again on the same day (also after rejoining)", function()
		local state = rules.markLoginCalendarShown(rules.newPlayerState(), NOW).state
		local loaded = SaveData.load(state, rules.newPlayerState()).state

		local result = rules.markLoginCalendarShown(loaded, NOW + 3600)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("CalendarShown")
		expect(result.state).toBe(loaded)
	end)

	it("opens again on the next day", function()
		local state = rules.markLoginCalendarShown(rules.newPlayerState(), NOW).state

		expect(rules.markLoginCalendarShown(state, DAY(1)).ok).toBe(true)
	end)
end)

describe("login calendar and saving", function()
	it("leaving and rejoining keeps the series and today's claim (no second claim on another server)", function()
		local state = claimOn(rules.newPlayerState(), { 0, 1 })

		local loaded = SaveData.load(state, rules.newPlayerState()).state

		expect(rules.claimLoginReward(loaded, DAY(1) + 3600, NO_RANDOM).reason).toBe("LoginClaimed")
		expect(rules.claimLoginReward(loaded, DAY(2), NO_RANDOM).day).toBe(3)
	end)

	it("a save from before the calendar starts at day 1", function()
		local loaded = SaveData.load({ version = 5, coins = 7 }, rules.newPlayerState()).state

		expect(loaded.coins).toBe(7)
		expect(rules.loginCalendar(loaded, NOW).today).toBe(1)
		expect(rules.loginCalendar(loaded, NOW).claimable).toBe(true)
	end)

	it("a rebirth keeps the series", function()
		local state = claimOn(rules.newPlayerState(), { 0, 1 })
		state.coins = 1000000

		local reborn = rules.rebirth(state, DAY(1)).state

		expect(rules.loginCalendar(reborn, DAY(1)).claimable).toBe(false)
		expect(rules.claimLoginReward(reborn, DAY(2), NO_RANDOM).day).toBe(3)
	end)
end)
