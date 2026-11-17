local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")
local SaveData = require("../src/shared/SaveData")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect
local sequenceRandom = TestKit.sequenceRandom

local rules = GameRules.new(TestConfig)

-- 15.01.2026 11:00 CET, and the same time a day later (German days 20468 / 20469).
local NOW = 1768431600 + 11 * 3600
local NEXT_DAY = NOW + 24 * 3600
local NO_RANDOM = sequenceRandom({ 0 })

-- TestConfig gifts: 5 min coins (2 min of income), 10 min 5 gems, 15 min 1 potion,
-- 20 min 15 gems + 2 potions.
local function played(minutes: number, now: number?)
	return rules.addPlayTime(rules.newPlayerState(), minutes * 60, now or NOW).state
end

describe("daily play time", function()
	it("a new player has played 0 seconds today and in total", function()
		local state = rules.newPlayerState()

		expect(rules.dailyPlaytime(state, NOW)).toBe(0)
		expect(state.totalPlaytimeSeconds).toBe(0)
	end)

	it("counts play time of the day and in total", function()
		local state = rules.addPlayTime(rules.newPlayerState(), 60, NOW).state
		local result = rules.addPlayTime(state, 90, NOW + 90)

		expect(result.ok).toBe(true)
		expect(rules.dailyPlaytime(result.state, NOW + 90)).toBe(150)
		expect(result.state.totalPlaytimeSeconds).toBe(150)
	end)

	it("starts the day's play time over on a new German day, the total keeps counting", function()
		local state = played(30)

		local result = rules.addPlayTime(state, 60, NEXT_DAY)

		expect(rules.dailyPlaytime(result.state, NEXT_DAY)).toBe(60)
		expect(result.state.totalPlaytimeSeconds).toBe(30 * 60 + 60)
	end)

	it("reads as 0 on a new day even before any play time is added", function()
		expect(rules.dailyPlaytime(played(30), NEXT_DAY)).toBe(0)
	end)

	it("no longer pays gems for play time", function()
		local result = rules.addPlayTime(rules.newPlayerState(), 60 * 60, NOW)

		expect(result.state.gems).toBe(0)
	end)

	it("ignores zero, negative and non-finite time", function()
		for _, seconds in { 0, -100, 0 / 0, math.huge } do
			local state = rules.newPlayerState()
			local result = rules.addPlayTime(state, seconds, NOW)
			expect(result.ok).toBe(false)
			expect(result.reason).toBe("InvalidTime")
			expect(result.state).toBe(state)
		end
	end)

	it("does not change the old state", function()
		local state = rules.newPlayerState()
		rules.addPlayTime(state, 60, NOW)

		expect(state.totalPlaytimeSeconds).toBe(0)
	end)
end)

describe("gift status", function()
	it("shows every gift waiting with the time left until it is reached", function()
		local status = rules.giftStatus(played(3), NOW)

		expect(#status.gifts).toBe(4)
		expect(status.gifts[1].status).toBe("Waiting")
		expect(status.gifts[1].secondsLeft).toBe(2 * 60)
		expect(status.gifts[4].secondsLeft).toBe(17 * 60)
		expect(status.readyCount).toBe(0)
		expect(status.nextSeconds).toBe(2 * 60)
	end)

	it("marks reached gifts ready and counts down to the next one", function()
		local status = rules.giftStatus(played(12), NOW)

		expect(status.gifts[1].status).toBe("Ready")
		expect(status.gifts[2].status).toBe("Ready")
		expect(status.gifts[3].status).toBe("Waiting")
		expect(status.readyCount).toBe(2)
		expect(status.nextSeconds).toBe(3 * 60)
	end)

	it("shows the rewards, coins from the income estimate", function()
		local status = rules.giftStatus(played(0.5), NOW)

		expect(status.gifts[1].minutes).toBe(5)
		expect(status.gifts[1].rewards).toEqual({ { kind = "Coins", amount = 13 } })
		expect(status.gifts[4].rewards).toEqual({ { kind = "Gems", amount = 15 }, { kind = "Potion", amount = 2 } })
	end)

	it("has no next gift once all are reached", function()
		local status = rules.giftStatus(played(25), NOW)

		expect(status.readyCount).toBe(4)
		expect(status.nextSeconds).toBeNil()
	end)
end)

describe("claiming gifts", function()
	it("cannot claim a gift before its play time is reached", function()
		local state = played(4)

		local result = rules.claimGift(state, 1, NOW, NO_RANDOM)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("GiftNotReady")
		expect(result.state).toBe(state)
	end)

	it("claims coins worth minutes of income", function()
		local result = rules.claimGift(played(5), 1, NOW, NO_RANDOM)

		expect(result.ok).toBe(true)
		expect(result.state.coins).toBe(13)
		expect(result.rewards).toEqual({ { kind = "Coins", amount = 13 } })
		expect(rules.giftStatus(result.state, NOW).gifts[1].status).toBe("Claimed")
	end)

	it("claims gems", function()
		local result = rules.claimGift(played(10), 2, NOW, NO_RANDOM)

		expect(result.state.gems).toBe(5)
	end)

	it("claims a random potion like delivery orders (sorted ids: Coins, Luck, Speed)", function()
		local result = rules.claimGift(played(15), 3, NOW, sequenceRandom({ 0.5 }))

		expect(result.rewards).toEqual({ { kind = "Potion", amount = 1, potionId = "Luck" } })
		expect(rules.potionCount(result.state, "Luck")).toBe(1)
	end)

	it("claims several rewards of one gift at once", function()
		local result = rules.claimGift(played(20), 4, NOW, sequenceRandom({ 0.9 }))

		expect(result.state.gems).toBe(15)
		expect(rules.potionCount(result.state, "Speed")).toBe(2)
	end)

	it("cannot claim the same gift twice on one day", function()
		local state = rules.claimGift(played(12), 2, NOW, NO_RANDOM).state

		local result = rules.claimGift(state, 2, NOW + 60, NO_RANDOM)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("GiftClaimed")
		expect(result.state.gems).toBe(5)
	end)

	it("can claim every gift again on the next day once it is reached again", function()
		local state = rules.claimGift(played(12), 2, NOW, NO_RANDOM).state
		state = rules.addPlayTime(state, 10 * 60, NEXT_DAY).state

		local result = rules.claimGift(state, 2, NEXT_DAY, NO_RANDOM)

		expect(result.ok).toBe(true)
		expect(result.state.gems).toBe(10)
	end)

	it("a gift reached yesterday but not claimed is gone on the next day", function()
		local result = rules.claimGift(played(12), 2, NEXT_DAY, NO_RANDOM)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("GiftNotReady")
	end)

	it("rejects unknown gifts", function()
		for _, index in { 0, 5, 1.5 } do
			expect(rules.claimGift(played(30), index, NOW, NO_RANDOM).reason).toBe("UnknownGift")
		end
	end)
end)

describe("gifts and saving", function()
	it("leaving and rejoining keeps the day's play time, claimed gifts and total", function()
		local state = rules.claimGift(played(12), 1, NOW, NO_RANDOM).state

		local loaded = SaveData.load(state, rules.newPlayerState()).state

		expect(rules.dailyPlaytime(loaded, NOW)).toBe(12 * 60)
		expect(loaded.totalPlaytimeSeconds).toBe(12 * 60)
		expect(rules.giftStatus(loaded, NOW).gifts[1].status).toBe("Claimed")
		expect(rules.claimGift(loaded, 1, NOW, NO_RANDOM).reason).toBe("GiftClaimed")
	end)

	it("a rebirth keeps the day's play time, claimed gifts and total", function()
		local state = rules.claimGift(played(12), 1, NOW, NO_RANDOM).state
		state.coins = 1000000

		local reborn = rules.rebirth(state, NOW).state

		expect(rules.dailyPlaytime(reborn, NOW)).toBe(12 * 60)
		expect(reborn.totalPlaytimeSeconds).toBe(12 * 60)
		expect(rules.giftStatus(reborn, NOW).gifts[1].status).toBe("Claimed")
	end)

	it("a version 4 save drops the leftover play time of the old play time gems", function()
		local saved = { version = 4, gems = 4, rebirths = 1, playtimeSeconds = 840 }

		local loaded = SaveData.load(saved, rules.newPlayerState()).state

		expect(loaded.version).toBe(5)
		expect(loaded.gems).toBe(4)
		expect(loaded.rebirths).toBe(1)
		expect(loaded.playtimeSeconds).toBeNil()
		expect(rules.dailyPlaytime(loaded, NOW)).toBe(0)
		expect(loaded.totalPlaytimeSeconds).toBe(0)
		expect(loaded.giftsClaimed).toEqual({})
	end)

	it("a version 3 save runs the rebirth migration first, then drops the old play time", function()
		local saved = { version = 3, gems = 4, rebirthMultiplier = 1, playtimeSeconds = 840 }

		local loaded = SaveData.load(saved, rules.newPlayerState()).state

		expect(loaded.rebirths).toBe(0)
		expect(loaded.rebirthMultiplier).toBeNil()
		expect(loaded.playtimeSeconds).toBeNil()
		expect(loaded.totalPlaytimeSeconds).toBe(0)
	end)
end)

describe("new button hints", function()
	it("a new player has seen no hint yet", function()
		expect(rules.hasSeenHint(rules.newPlayerState(), "Gifts")).toBe(false)
	end)

	it("marking a hint as seen remembers it (also after saving and loading)", function()
		local result = rules.markHintSeen(rules.newPlayerState(), "Gifts")

		expect(result.ok).toBe(true)
		expect(rules.hasSeenHint(result.state, "Gifts")).toBe(true)
		local loaded = SaveData.load(result.state, rules.newPlayerState()).state
		expect(rules.hasSeenHint(loaded, "Gifts")).toBe(true)
	end)

	it("marking it again changes nothing", function()
		local state = rules.markHintSeen(rules.newPlayerState(), "Gifts").state

		local result = rules.markHintSeen(state, "Gifts")

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("HintSeen")
		expect(result.state).toBe(state)
	end)

	it("rejects hints that are not configured", function()
		expect(rules.markHintSeen(rules.newPlayerState(), "Anything").reason).toBe("UnknownHint")
	end)
end)
