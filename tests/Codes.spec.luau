local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameConfig = require("../src/shared/GameConfig")
local GameRules = require("../src/shared/GameRules")
local SaveData = require("../src/shared/SaveData")
local Texts = require("../src/shared/Texts")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local rules = GameRules.new(TestConfig)

-- 2026-11-26 12:00 UTC
local NOW = 1_795_694_400
local random = TestKit.sequenceRandom({ 0.5 })

describe("codes (#99)", function()
	it("redeems a code once and pays its gems", function()
		local old = rules.newPlayerState()
		local result = rules.redeemCode(old, "HELLO", NOW, random)
		expect(result.ok).toBe(true)
		expect(result.state.gems).toBe(old.gems + 50)
		expect(result.rewards).toEqual({ { kind = "Gems", amount = 50 } })
		expect(result.state.redeemedCodes).toEqual({ "HELLO" })
		expect(old.redeemedCodes).toEqual({})
	end)

	it("pays the configured potion, not a random one", function()
		local result = rules.redeemCode(rules.newPlayerState(), "LUCKY", NOW, random)
		expect(result.ok).toBe(true)
		expect(result.state.potions.Luck).toBe(2)
		expect(result.rewards).toEqual({ { kind = "Potion", amount = 2, potionId = "Luck" } })
	end)

	it("ignores case and surrounding spaces", function()
		local result = rules.redeemCode(rules.newPlayerState(), "  hElLo ", NOW, random)
		expect(result.ok).toBe(true)
		expect(result.state.redeemedCodes).toEqual({ "HELLO" })
	end)

	it("refuses a code the player already used, in any spelling", function()
		local state = rules.redeemCode(rules.newPlayerState(), "HELLO", NOW, random).state
		local again = rules.redeemCode(state, "hello", NOW + 1, random)
		expect(again.ok).toBe(false)
		expect(again.reason).toBe("AlreadyUsed")
		expect(again.state).toBe(state)
	end)

	it("one player's code does not block another code", function()
		local state = rules.redeemCode(rules.newPlayerState(), "HELLO", NOW, random).state
		expect(rules.redeemCode(state, "LUCKY", NOW, random).ok).toBe(true)
	end)

	it("is valid until 31.12.2026 23:59 German time (22:59 UTC in winter)", function()
		local lastMinute = GameRules.germanTime({ year = 2026, month = 12, day = 31, hour = 23, minute = 59 })
		expect(lastMinute).toBe(1_798_757_940) -- 2026-12-31T22:59:00Z
		local state = rules.newPlayerState()
		expect(rules.redeemCode(state, "LUCKY", lastMinute + 59, random).ok).toBe(true)
		local late = rules.redeemCode(state, "LUCKY", lastMinute + 60, random)
		expect(late.ok).toBe(false)
		expect(late.reason).toBe("Expired")
		expect(late.state).toBe(state)
	end)

	it("German time follows summer time", function()
		-- 2026-07-01 12:00 CEST = 10:00 UTC
		expect(GameRules.germanTime({ year = 2026, month = 7, day = 1, hour = 12, minute = 0 })).toBe(1_782_900_000)
	end)

	it("refuses unknown codes and anything that is not a short string", function()
		local state = rules.newPlayerState()
		for _, code in { "NOPE", "", "   ", 42, nil, {}, string.rep("A", 33) } :: { any } do
			local result = rules.redeemCode(state, code, NOW, random)
			expect(result.ok).toBe(false)
			expect(result.reason).toBe("Unknown")
			expect(result.state).toBe(state)
		end
	end)

	it("redeemed codes survive saving and loading", function()
		local state = rules.redeemCode(rules.newPlayerState(), "HELLO", NOW, random).state
		local loaded = SaveData.load(state, rules.newPlayerState())
		expect(loaded.ok).toBe(true)
		expect(rules.redeemCode(loaded.state, "HELLO", NOW, random).reason).toBe("AlreadyUsed")
	end)

	it("old saves without redeemed codes can redeem", function()
		local state = rules.newPlayerState()
		state.redeemedCodes = nil :: any
		expect(rules.redeemCode(state, "HELLO", NOW, random).ok).toBe(true)
	end)
end)

describe("codes in GameConfig (#99)", function()
	local real = GameRules.new(GameConfig)

	it("WELCOME = 50 gems and PIZZA = 2 luck potions until 31.12.2026 23:59 German time", function()
		local state = real.newPlayerState()
		local welcome = real.redeemCode(state, "welcome", NOW, random)
		expect(welcome.ok).toBe(true)
		expect(welcome.state.gems).toBe(state.gems + 50)
		local pizza = real.redeemCode(welcome.state, "Pizza", NOW, random)
		expect(pizza.ok).toBe(true)
		expect(pizza.state.potions.Luck).toBe(2)
		local lastMinute = GameRules.germanTime({ year = 2026, month = 12, day = 31, hour = 23, minute = 59 })
		expect(real.redeemCode(state, "WELCOME", lastMinute + 60, random).reason).toBe("Expired")
		expect(real.redeemCode(state, "PIZZA", lastMinute + 60, random).reason).toBe("Expired")
	end)

	it("every code id is upper case and every potion reward names a potion", function()
		for id, code in GameConfig.codes do
			expect(string.upper(id)).toBe(id)
			for _, reward in code.rewards do
				if reward.kind == "Potion" and reward.potionId ~= nil then
					expect(GameConfig.potions[reward.potionId] ~= nil).toBe(true)
				end
			end
		end
	end)

	it("every failure reason has a text", function()
		for _, reason in { "Unknown", "AlreadyUsed", "Expired", "TooManyTries" } do
			expect(Texts.strings[`codes.{reason}`] ~= nil).toBe(true)
		end
	end)
end)
