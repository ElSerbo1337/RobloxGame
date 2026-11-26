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

-- TestConfig 30-day calendar (#101): 1 5 gems, 2 10 gems, 3 1 potion, 4 1 potion, 5 20 gems,
-- 6 2 potions, 7 50 gems + 3 potions (big), 8-29 (day) gems, 14 50 gems + 2 potions (big),
-- 30 the pet Dragon + 100 gems (big).

-- Same config with the 30-day calendar switched off: the old 7-day calendar.
local sevenDayConfig = table.clone(TestConfig)
sevenDayConfig.features = { loginCalendar30 = false }
local sevenDayRules = GameRules.new(sevenDayConfig)

-- Claims on the days 0 .. count - 1 (day offsets from NOW).
local function series(count: number): { number }
	local days = {}
	for day = 0, count - 1 do
		table.insert(days, day)
	end
	return days
end

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
		expect(#calendar.days).toBe(30)
		expect(calendar.days[1].status).toBe("Ready")
		expect(calendar.days[2].status).toBe("Waiting")
		expect(calendar.days[30].status).toBe("Waiting")
	end)

	it("shows the fixed rewards of the days, the pet of day 30 with its id", function()
		local days = rules.loginCalendar(rules.newPlayerState(), NOW).days

		expect(days[1].rewards).toEqual({ { kind = "Gems", amount = 5 } })
		expect(days[2].rewards).toEqual({ { kind = "Gems", amount = 10 } })
		expect(days[3].rewards).toEqual({ { kind = "Potion", amount = 1 } })
		expect(days[4].rewards).toEqual({ { kind = "Potion", amount = 1 } })
		expect(days[7].rewards).toEqual({ { kind = "Gems", amount = 50 }, { kind = "Potion", amount = 3 } })
		expect(days[20].rewards).toEqual({ { kind = "Gems", amount = 20 } })
		expect(days[30].rewards).toEqual({
			{ kind = "Pet", amount = 1, petId = "Dragon" },
			{ kind = "Gems", amount = 100 },
		})
	end)

	it("marks days 7, 14 and 30 as big reward days", function()
		local big = {}
		for _, day in rules.loginCalendar(rules.newPlayerState(), NOW).days do
			if day.big then
				table.insert(big, day.day)
			end
		end

		expect(big).toEqual({ 7, 14, 30 })
	end)

	it("in the middle of the series earlier days are claimed and later ones waiting", function()
		local calendar = rules.loginCalendar(claimOn(rules.newPlayerState(), series(19)), DAY(19))

		expect(calendar.today).toBe(20)
		expect(calendar.claimable).toBe(true)
		expect(calendar.days[19].status).toBe("Claimed")
		expect(calendar.days[20].status).toBe("Ready")
		expect(calendar.days[21].status).toBe("Waiting")
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

describe("login rewards are fixed", function()
	it("do not depend on worlds, pets or rebirths", function()
		local advanced = rules.newPlayerState()
		advanced.unlockedWorlds = { "Farm" }
		advanced.rebirths = 3
		advanced.pets = { { uid = 1, petId = "Dragon" } }
		advanced.equipped = { 1 }
		local before = rules.loginCalendar(rules.newPlayerState(), NOW)

		local after = rules.loginCalendar(advanced, NOW)

		for index, day in before.days do
			expect(after.days[index].rewards).toEqual(day.rewards)
		end
	end)
end)

describe("claiming the login reward", function()
	it("first day: pays the day 1 gems and remembers the claim", function()
		local result = rules.claimLoginReward(rules.newPlayerState(), NOW, NO_RANDOM)

		expect(result.ok).toBe(true)
		expect(result.day).toBe(1)
		expect(result.rewards).toEqual({ { kind = "Gems", amount = 5 } })
		expect(result.state.gems).toBe(5)
		expect(result.state.coins).toBe(0)
	end)

	it("next day: the series goes up by one", function()
		local state = claimOn(rules.newPlayerState(), { 0 })

		local result = rules.claimLoginReward(state, DAY(1), NO_RANDOM)

		expect(result.ok).toBe(true)
		expect(result.day).toBe(2)
		expect(result.state.gems - state.gems).toBe(10)
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

	it("after day 7 the series goes on with day 8", function()
		local state = claimOn(rules.newPlayerState(), series(7))

		local eighth = rules.claimLoginReward(state, DAY(7), NO_RANDOM)

		expect(eighth.day).toBe(8)
		expect(eighth.rewards).toEqual({ { kind = "Gems", amount = 8 } })
	end)

	it("a missed day late in the series also starts over at day 1", function()
		local state = claimOn(rules.newPlayerState(), series(25))

		local result = rules.claimLoginReward(state, DAY(26), NO_RANDOM)

		expect(result.day).toBe(1)
		expect(result.rewards).toEqual({ { kind = "Gems", amount = 5 } })
	end)

	it("day 14 pays its big reward", function()
		local state = claimOn(rules.newPlayerState(), series(13))

		local result = rules.claimLoginReward(state, DAY(13), sequenceRandom({ 0 }))

		expect(result.day).toBe(14)
		expect(result.state.gems - state.gems).toBe(50)
		expect(rules.potionCount(result.state, "Coins") - rules.potionCount(state, "Coins")).toBe(2)
	end)

	it("day 30 gives the calendar pet and the gems", function()
		local state = claimOn(rules.newPlayerState(), series(29))

		local result = rules.claimLoginReward(state, DAY(29), NO_RANDOM)

		expect(result.ok).toBe(true)
		expect(result.day).toBe(30)
		expect(result.rewards).toEqual({
			{ kind = "Pet", amount = 1, petId = "Dragon" },
			{ kind = "Gems", amount = 100 },
		})
		expect(#result.state.pets).toBe(#state.pets + 1)
		local pet = result.state.pets[#result.state.pets]
		expect(pet.petId).toBe("Dragon")
		expect(pet.foundAt).toBe(DAY(29))
		expect(result.state.nextPetUid).toBe(pet.uid + 1)
		expect(rules.hasOwnedPet(result.state, "Dragon")).toBe(true)
		expect(result.state.gems - state.gems).toBe(100)
	end)

	it("day 30 gives the pet even with a full inventory", function()
		local state = claimOn(rules.newPlayerState(), series(29))
		state.pets = {}
		for uid = 1, rules.inventorySlots(state) do
			table.insert(state.pets, { uid = uid, petId = "Hamster" })
		end
		state.nextPetUid = #state.pets + 1

		local result = rules.claimLoginReward(state, DAY(29), NO_RANDOM)

		expect(result.ok).toBe(true)
		expect(#result.state.pets).toBe(rules.inventorySlots(state) + 1)
	end)

	it("after day 30 the calendar starts over at day 1", function()
		local state = claimOn(rules.newPlayerState(), series(30))

		local result = rules.claimLoginReward(state, DAY(30), NO_RANDOM)

		expect(result.day).toBe(1)
		expect(rules.loginCalendar(result.state, DAY(30)).days[30].status).toBe("Waiting")
	end)

	it("pays gems and random potions like gifts (sorted ids: Coins, Luck, Speed)", function()
		local state = claimOn(rules.newPlayerState(), series(6))

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

describe("login calendar switched off (features.loginCalendar30 = false)", function()
	it("uses the 7-day calendar without big days", function()
		local calendar = sevenDayRules.loginCalendar(sevenDayRules.newPlayerState(), NOW)

		expect(#calendar.days).toBe(7)
		expect(calendar.days[7].big).toBe(false)
	end)

	it("after day 7 starts over at day 1", function()
		local state = sevenDayRules.newPlayerState()
		for day = 0, 6 do
			state = sevenDayRules.claimLoginReward(state, DAY(day), NO_RANDOM).state
		end

		expect(sevenDayRules.claimLoginReward(state, DAY(7), NO_RANDOM).day).toBe(1)
	end)

	it("a series beyond day 7 (switched off later) stays inside the 7 days", function()
		local state = claimOn(rules.newPlayerState(), series(12))

		local claimed = sevenDayRules.loginCalendar(state, DAY(11))
		local next = sevenDayRules.claimLoginReward(state, DAY(12), NO_RANDOM)

		expect(claimed.today).toBe(5)
		expect(claimed.claimable).toBe(false)
		expect(next.ok).toBe(true)
		expect(next.day).toBe(6)
	end)
end)

describe("setting the calendar day (admin, #101)", function()
	it("makes the given day claimable today", function()
		local result = rules.setLoginCalendarDay(rules.newPlayerState(), 30, NOW)

		expect(result.ok).toBe(true)
		local calendar = rules.loginCalendar(result.state, NOW)
		expect(calendar.today).toBe(30)
		expect(calendar.claimable).toBe(true)
		expect(rules.claimLoginReward(result.state, NOW, NO_RANDOM).day).toBe(30)
	end)

	it("also after today's reward was claimed", function()
		local state = claimOn(rules.newPlayerState(), { 0 })

		local result = rules.setLoginCalendarDay(state, 7, NOW)

		expect(rules.loginCalendar(result.state, NOW).today).toBe(7)
		expect(rules.loginCalendar(result.state, NOW).claimable).toBe(true)
	end)

	it("refuses days outside the calendar", function()
		local state = rules.newPlayerState()

		expect(rules.setLoginCalendarDay(state, 0, NOW).reason).toBe("UnknownDay")
		expect(rules.setLoginCalendarDay(state, 31, NOW).reason).toBe("UnknownDay")
		expect(sevenDayRules.setLoginCalendarDay(state, 8, NOW).reason).toBe("UnknownDay")
	end)
end)
