local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect
local sequenceRandom = TestKit.sequenceRandom

local rules = GameRules.new(TestConfig)

-- 15.01.2026 11:00 CET, and the same time a day later.
local NOW = 1768431600 + 11 * 3600
local NEXT_DAY = NOW + 24 * 3600

-- TestConfig wheel: 1 free spin a day + 1 after 30 min, then 25 gems. Field rolls
-- (weights 30/20/15/10/10/8/5/2): 0 -> Coins5, 0.3 -> Gems5, 0.5 -> Potion1, 0.65 -> Gems10,
-- 0.75 -> Coins15, 0.85 -> Potion2, 0.93 -> Gems25, 0.98 -> Jackpot. A new player earns
-- 6.8 coins a minute (see Income.spec).
local function roll(fieldRoll: number, potionRoll: number?)
	return sequenceRandom({ fieldRoll, potionRoll or 0 })
end

local function played(minutes: number, state: any?)
	return rules.addPlayTime(state or rules.newPlayerState(), minutes * 60, NOW).state
end

local function withGems(gems: number)
	local state = rules.newPlayerState()
	state.gems = gems
	return state
end

describe("lucky wheel free spins", function()
	it("a new player has one free spin today", function()
		local status = rules.wheelStatus(rules.newPlayerState(), NOW)

		expect(status.freeSpins).toBe(1)
		expect(status.freeTotal).toBe(1)
		expect(status.bonusSecondsLeft).toBe(30 * 60)
		expect(status.price).toBe(25)
	end)

	it("gives a second free spin after 30 minutes of play time today", function()
		local status = rules.wheelStatus(played(30), NOW)

		expect(status.freeSpins).toBe(2)
		expect(status.freeTotal).toBe(2)
		expect(status.bonusSecondsLeft).toBeNil()
	end)

	it("counts down to the bonus spin with today's play time", function()
		expect(rules.wheelStatus(played(20), NOW).bonusSecondsLeft).toBe(10 * 60)
	end)

	it("uses the free spin first and costs no gems", function()
		local result = rules.spinWheel(withGems(40), NOW, roll(0.3))

		expect(result.ok).toBe(true)
		expect(result.free).toBe(true)
		expect(result.state.gems).toBe(45)
		expect(rules.wheelStatus(result.state, NOW).freeSpins).toBe(0)
	end)

	it("the bonus spin can still be used after the daily one", function()
		local first = rules.spinWheel(played(10), NOW, roll(0.3)).state
		local later = played(20, first)

		expect(rules.wheelStatus(later, NOW).freeSpins).toBe(1)
		expect(rules.spinWheel(later, NOW, roll(0.3)).free).toBe(true)
	end)

	it("gives new free spins on the next German day", function()
		local state = rules.spinWheel(rules.newPlayerState(), NOW, roll(0.3)).state

		expect(rules.wheelStatus(state, NOW).freeSpins).toBe(0)
		expect(rules.wheelStatus(state, NEXT_DAY).freeSpins).toBe(1)
		expect(rules.spinWheel(state, NEXT_DAY, roll(0.3)).free).toBe(true)
	end)

	it("the bonus spin needs 30 minutes on the new day again", function()
		local state = played(40)

		expect(rules.wheelStatus(state, NEXT_DAY).freeSpins).toBe(1)
	end)

	it("refuses when a free spin was expected but none is left", function()
		local state = rules.spinWheel(withGems(100), NOW, roll(0.3)).state
		local result = rules.spinWheel(state, NOW, roll(0.3), true)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("NoFreeSpin")
		expect(result.state).toBe(state)
	end)

	it("a spin expected as paid still uses a free spin when one is there", function()
		local result = rules.spinWheel(withGems(100), NOW, roll(0.3), false)

		expect(result.free).toBe(true)
		expect(result.state.gems).toBe(105)
	end)
end)

describe("lucky wheel paid spins", function()
	it("costs 25 gems once the free spins are used", function()
		local state = rules.spinWheel(withGems(30), NOW, roll(0.3)).state
		local result = rules.spinWheel(state, NOW, roll(0))

		expect(result.ok).toBe(true)
		expect(result.free).toBe(false)
		expect(result.state.gems).toBe(35 - 25)
	end)

	it("refuses without enough gems and keeps the state", function()
		local state = rules.spinWheel(withGems(20), NOW, roll(0)).state
		local result = rules.spinWheel(state, NOW, roll(0))

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("NotEnoughGems")
		expect(result.state).toBe(state)
	end)

	it("can spin for gems as often as the player can pay", function()
		local state = rules.spinWheel(withGems(50), NOW, roll(0)).state
		state = rules.spinWheel(state, NOW, roll(0)).state
		state = rules.spinWheel(state, NOW, roll(0)).state

		expect(state.gems).toBe(0)
		expect(state.wheelSpins).toBe(3)
	end)

	it("does not change the old state", function()
		local state = withGems(100)
		rules.spinWheel(state, NOW, roll(0.98))

		expect(state.gems).toBe(100)
		expect(state.wheelFreeUsed).toBe(0)
		expect(state.wheelSpins).toBe(0)
	end)
end)

describe("lucky wheel fields", function()
	it("has 8 fields with the configured weights", function()
		local status = rules.wheelStatus(rules.newPlayerState(), NOW)

		expect(#status.fields).toBe(8)
		expect(status.fields[8].id).toBe("Jackpot")
		expect(status.fields[8].jackpot).toBe(true)
		expect(status.fields[1].jackpot).toBe(false)
		expect(status.fields[8].chance).toBe(0.02)
	end)

	it("draws fields by weight", function()
		local expected = {
			{ 0, "Coins5" },
			{ 0.29, "Coins5" },
			{ 0.3, "Gems5" },
			{ 0.5, "Potion1" },
			{ 0.65, "Gems10" },
			{ 0.75, "Coins15" },
			{ 0.85, "Potion2" },
			{ 0.93, "Gems25" },
			{ 0.979, "Gems25" },
			{ 0.98, "Jackpot" },
			{ 0.9999, "Jackpot" },
		}
		for _, case in expected do
			local result = rules.spinWheel(rules.newPlayerState(), NOW, roll(case[1]))
			expect(rules.wheelStatus(result.state, NOW).fields[result.field].id).toBe(case[2])
		end
	end)

	it("pays 5 minutes of income as coins, counted as earned", function()
		local result = rules.spinWheel(rules.newPlayerState(), NOW, roll(0))

		expect(result.state.coins).toBe(34)
		expect(result.state.totalCoinsEarned).toBe(34)
		expect(result.rewards).toEqual({ { kind = "Coins", amount = 34 } })
	end)

	it("pays 15 minutes of income for the big coin field", function()
		local state = rules.newPlayerState()
		state.unlockedWorlds = { "Farm" }
		local result = rules.spinWheel(state, NOW, roll(0.75))

		expect(result.state.coins).toBe(8 * 2 * 2 * 15)
	end)

	it("pays at least the minimum coins", function()
		local cfg = table.clone(TestConfig)
		cfg.luckyWheel = table.clone(TestConfig.luckyWheel)
		cfg.luckyWheel.minCoins = 500
		local result = GameRules.new(cfg).spinWheel(rules.newPlayerState(), NOW, roll(0))

		expect(result.state.coins).toBe(500)
	end)

	it("shows the coin amount of the player's income in the status", function()
		local fields = rules.wheelStatus(rules.newPlayerState(), NOW).fields

		expect(fields[1].rewards).toEqual({ { kind = "Coins", amount = 34 } })
		expect(fields[5].rewards).toEqual({ { kind = "Coins", amount = 102 } })
		expect(fields[2].rewards).toEqual({ { kind = "Gems", amount = 5 } })
	end)

	it("pays gems", function()
		expect(rules.spinWheel(rules.newPlayerState(), NOW, roll(0.65)).state.gems).toBe(10)
		expect(rules.spinWheel(rules.newPlayerState(), NOW, roll(0.93)).state.gems).toBe(25)
	end)

	it("pays a random potion", function()
		local result = rules.spinWheel(rules.newPlayerState(), NOW, roll(0.5, 0.5))

		expect(result.state.potions).toEqual({ Luck = 1 })
		expect(result.rewards).toEqual({ { kind = "Potion", amount = 1, potionId = "Luck" } })
	end)

	it("pays two potions", function()
		local result = rules.spinWheel(rules.newPlayerState(), NOW, roll(0.85, 0.9))

		expect(result.state.potions).toEqual({ Speed = 2 })
	end)

	it("the jackpot pays 100 gems and 3 potions", function()
		local result = rules.spinWheel(rules.newPlayerState(), NOW, roll(0.99, 0))

		expect(result.field).toBe(8)
		expect(result.state.gems).toBe(100)
		expect(result.state.potions).toEqual({ Coins = 3 })
		expect(#result.rewards).toBe(2)
	end)

	it("counts spins", function()
		local state = rules.spinWheel(rules.newPlayerState(), NOW, roll(0)).state

		expect(state.wheelSpins).toBe(1)
		expect(state.wheelDay).toBe(rules.dayNumber(NOW))
	end)
end)

describe("lucky wheel admin reset", function()
	it("resetWheelSpins gives today's free spins back", function()
		local state = rules.spinWheel(played(30), NOW, roll(0)).state
		state = rules.spinWheel(state, NOW, roll(0)).state
		local result = rules.resetWheelSpins(state)

		expect(result.ok).toBe(true)
		expect(rules.wheelStatus(result.state, NOW).freeSpins).toBe(2)
		expect(result.state.wheelSpins).toBe(2)
	end)
end)
