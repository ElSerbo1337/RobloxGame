local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")
local Leaderboard = require("../src/shared/Leaderboard")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect
local sequenceRandom = TestKit.sequenceRandom

local rules = GameRules.new(TestConfig)

-- 15.01.2026 11:00 CET.
local NOW = 1768431600 + 11 * 3600
local NO_RANDOM = sequenceRandom({ 0 })

-- A player who finished the tutorial (the phone stays quiet during it).
local function player()
	local state = rules.newPlayerState()
	state.tutorialStep = 1000
	return state
end

describe("coins earned in total", function()
	it("a new player has earned 0 coins", function()
		expect(rules.newPlayerState().totalCoinsEarned).toBe(0)
	end)

	it("counts coins from selling at the oven", function()
		local state = player()
		state.totalCoinsEarned = 10
		state = rules.collectTopping(state, "Salami", 1).state
		state = rules.collectTopping(state, "Mushroom", 1).state

		local result = rules.sellPizza(state)

		expect(result.ok).toBe(true)
		expect(result.coinsEarned > 0).toBe(true)
		expect(result.state.totalCoinsEarned).toBe(10 + result.coinsEarned)
	end)

	it("counts coins from a delivery order", function()
		-- Rolls: 2 toppings, Salami, Mushroom, coin reward.
		local state = rules.ringPhone(player(), 1000, sequenceRandom({ 0, 0.1, 0.7, 0 })).state
		state = rules.acceptOrder(state, 1000).state
		state = rules.collectTopping(state, "Mushroom", 1).state
		state = rules.collectTopping(state, "Salami", 1).state

		local result = rules.deliverOrder(state, 1000)

		expect(result.ok).toBe(true)
		expect(result.reward.reward).toBe("Coins")
		expect(result.state.totalCoinsEarned).toBe(result.reward.amount)
	end)

	it("login calendar gems and potions do not count", function()
		local result = rules.claimLoginReward(player(), NOW, NO_RANDOM)

		expect(result.ok).toBe(true)
		expect(result.state.totalCoinsEarned).toBe(0)
	end)

	it("play time gift gems and potions do not count", function()
		local state = rules.addPlayTime(player(), 20 * 60, NOW).state
		for index = 1, 3 do
			state = rules.claimGift(state, index, NOW, NO_RANDOM).state
		end

		expect(state.totalCoinsEarned).toBe(0)
	end)

	it("spending coins does not lower it", function()
		local state = player()
		state.coins = 1000000
		state.totalCoinsEarned = 1000000

		local result = rules.unlockWorld(state, "Farm")

		expect(result.ok).toBe(true)
		expect(result.state.coins < 1000000).toBe(true)
		expect(result.state.totalCoinsEarned).toBe(1000000)
	end)

	it("stays through a rebirth", function()
		local state = player()
		state.coins = 5000
		state.totalCoinsEarned = 12345
		state.totalPlaytimeSeconds = 600

		local result = rules.rebirth(state, 0)

		expect(result.ok).toBe(true)
		expect(result.state.coins).toBe(0)
		expect(result.state.totalCoinsEarned).toBe(12345)
		expect(result.state.totalPlaytimeSeconds).toBe(600)
	end)
end)

describe("leaderboard scores", function()
	it("are whole numbers for play time, coins earned and rebirths", function()
		local state = player()
		state.totalPlaytimeSeconds = 3725.6
		state.totalCoinsEarned = 98765
		state.rebirths = 3

		expect(rules.leaderboardScores(state)).toEqual({
			Playtime = 3725,
			CoinsEarned = 98765,
			Rebirths = 3,
			EggsOpened = 0,
			ToppingsCollected = 0,
		})
	end)
end)

describe("leaderboard display", function()
	it("writes numbers in German format", function()
		expect(Leaderboard.formatValue("Number", 0)).toBe("0")
		expect(Leaderboard.formatValue("Number", 999)).toBe("999")
		expect(Leaderboard.formatValue("Number", 1234)).toBe("1.234")
		expect(Leaderboard.formatValue("Number", 1234567)).toBe("1.234.567")
	end)

	it("writes play time in hours and minutes", function()
		expect(Leaderboard.formatValue("Duration", 59)).toBe("0 Min.")
		expect(Leaderboard.formatValue("Duration", 45 * 60)).toBe("45 Min.")
		expect(Leaderboard.formatValue("Duration", 3 * 3600 + 5 * 60 + 30)).toBe("3 Std. 5 Min.")
		expect(Leaderboard.formatValue("Duration", 1234 * 3600)).toBe("1.234 Std. 0 Min.")
	end)

	it("numbers the rows by rank and formats each value", function()
		local rows = Leaderboard.rows({ { name = "Anna", value = 5000 }, { name = "Ben", value = 42 } }, "Number")

		expect(rows).toEqual({
			{
				rank = 1,
				name = "Anna",
				value = "5.000",
				valueKey = "board.number",
				valueArgs = { value = { integer = 5000 } },
			},
			{
				rank = 2,
				name = "Ben",
				value = "42",
				valueKey = "board.number",
				valueArgs = { value = { integer = 42 } },
			},
		})
	end)
end)

describe("leaderboard values as sign texts (#71)", function()
	local Texts = require("../src/shared/Texts")
	local function render(language, format, value)
		local key, args = Leaderboard.valueText(format, value)
		return Texts.render(language, key, args)
	end

	it("matches the German format and shows English", function()
		for _, case in { { "Number", 1234567 }, { "Duration", 45 * 60 }, { "Duration", 1234 * 3600 + 5 * 60 } } do
			expect(render("de", case[1], case[2])).toBe(Leaderboard.formatValue(case[1], case[2]))
		end
		expect(render("en", "Number", 1234567)).toBe("1,234,567")
		expect(render("en", "Duration", 3 * 3600 + 5 * 60)).toBe("3 h 5 min")
	end)
end)
