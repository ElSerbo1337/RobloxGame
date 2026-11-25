local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameConfig = require("../src/shared/GameConfig")
local GameRules = require("../src/shared/GameRules")
local Texts = require("../src/shared/Texts")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local rules = GameRules.new(TestConfig)

-- Timestamps are Unix seconds (UTC); German time is UTC+1 in December.
local NOV_25_NOON = 1795608000 -- 25.11.2026 12:00 UTC
local DEC_16_LAST_MINUTE = 1797461940 -- 16.12. 22:59 UTC = 23:59 CET
local DEC_17_MIDNIGHT = 1797462000 -- 16.12. 23:00 UTC = 17.12. 00:00 CET
local DEC_17_LAST_MINUTE = 1797548340 -- 17.12. 22:59 UTC = 23:59 CET
local DEC_18_MIDNIGHT = 1797548400 -- 17.12. 23:00 UTC = 18.12. 00:00 CET
local JAN_05 = 1799150400 -- 05.01.2027 12:00 UTC

describe("days until a German calendar day", function()
	it("counts whole German days, not 24-hour blocks", function()
		local target = { year = 2026, month = 12, day = 18 }
		expect(GameRules.daysUntil(NOV_25_NOON, target)).toBe(23)
		expect(GameRules.daysUntil(DEC_16_LAST_MINUTE, target)).toBe(2)
		expect(GameRules.daysUntil(DEC_17_MIDNIGHT, target)).toBe(1)
		expect(GameRules.daysUntil(DEC_18_MIDNIGHT, target)).toBe(0)
		expect(GameRules.daysUntil(JAN_05, target)).toBe(-18)
	end)
end)

describe("Christmas countdown sign (#106)", function()
	it("shows the days until the event start", function()
		expect(rules.christmasCountdown(NOV_25_NOON)).toBe(23)
		expect(rules.christmasCountdown(DEC_16_LAST_MINUTE)).toBe(2)
	end)

	it("shows 1 on the last day before the event, up to German midnight", function()
		expect(rules.christmasCountdown(DEC_17_MIDNIGHT)).toBe(1)
		expect(rules.christmasCountdown(DEC_17_LAST_MINUTE)).toBe(1)
	end)

	it("is hidden (nil) from the event day on", function()
		expect(rules.christmasCountdown(DEC_18_MIDNIGHT)).toBeNil()
		expect(rules.christmasCountdown(JAN_05)).toBeNil()
	end)

	it("is hidden without a countdown target in the config", function()
		local config = table.clone(TestConfig)
		config.spawnMarket = nil
		expect(GameRules.new(config).christmasCountdown(NOV_25_NOON)).toBeNil()
	end)

	it("has a sign text for many days and for the last day, in both languages", function()
		for _, language in { "de", "en" } do
			local many = Texts.render(language :: Texts.Language, "countdown.days", { days = { integer = 23 } })
			expect(string.find(many, "23", 1, true) ~= nil).toBe(true)
			expect(string.find(many, "🎄", 1, true) ~= nil).toBe(true)
			expect(Texts.strings["countdown.tomorrow"] ~= nil).toBe(true)
		end
	end)

	it("counts down to 18.12.2026 in the real config", function()
		local target = GameConfig.spawnMarket.countdownTo
		expect(target.year).toBe(2026)
		expect(target.month).toBe(12)
		expect(target.day).toBe(18)
	end)
end)

describe("What's new window (#106)", function()
	local hint = TestConfig.spawnMarket.whatsNewHint

	it("is shown until the player closed it once, then never again", function()
		local fresh = rules.newPlayerState()
		expect(rules.hasSeenHint(fresh, hint)).toBe(false)

		local result = rules.markHintSeen(fresh, hint)

		expect(result.ok).toBe(true)
		expect(rules.hasSeenHint(result.state, hint)).toBe(true)
		expect(rules.hasSeenHint(fresh, hint)).toBe(false)
		expect(rules.markHintSeen(result.state, hint).reason).toBe("HintSeen")
	end)

	it("uses a hint id the real config knows", function()
		expect(table.find(GameConfig.hints, GameConfig.spawnMarket.whatsNewHint) ~= nil).toBe(true)
	end)

	it("has a title, a list and a button text in both languages", function()
		for _, key in { "whatsNew.title", "whatsNew.list", "whatsNew.ok", "whatsNew.prompt" } do
			local entry = Texts.strings[key]
			expect(entry ~= nil).toBe(true)
			expect(#entry.de > 0 and #entry.en > 0).toBe(true)
		end
	end)
end)
