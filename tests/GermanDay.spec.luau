local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local day = GameRules.dayNumber

-- Day numbers count German calendar days since 1970-01-01 (e.g. 20468 = 15.01.2026).
-- Timestamps are Unix seconds (UTC).
describe("day number in German time", function()
	it("starts the day at 23:00 UTC in winter (CET = UTC+1)", function()
		expect(day(1768431540)).toBe(20467) -- 14.01.2026 22:59 UTC = 23:59 CET
		expect(day(1768431600)).toBe(20468) -- 14.01.2026 23:00 UTC = 00:00 CET
	end)

	it("starts the day at 22:00 UTC in summer (CEST = UTC+2)", function()
		expect(day(1784066340)).toBe(20648) -- 14.07.2026 21:59 UTC = 23:59 CEST
		expect(day(1784066400)).toBe(20649) -- 14.07.2026 22:00 UTC = 00:00 CEST
	end)

	it("switches to summer time on the last Sunday of March at 01:00 UTC", function()
		-- Sunday 29.03.2026 still begins on winter time ...
		expect(day(1774738740)).toBe(20540) -- 28.03. 22:59 UTC
		expect(day(1774738800)).toBe(20541) -- 28.03. 23:00 UTC = 29.03. 00:00 CET
		-- ... and ends on summer time.
		expect(day(1774821540)).toBe(20541) -- 29.03. 21:59 UTC = 23:59 CEST
		expect(day(1774821600)).toBe(20542) -- 29.03. 22:00 UTC = 30.03. 00:00 CEST
	end)

	it("switches back to winter time on the last Sunday of October at 01:00 UTC", function()
		-- Sunday 25.10.2026 begins on summer time ...
		expect(day(1792879140)).toBe(20750) -- 24.10. 21:59 UTC
		expect(day(1792879200)).toBe(20751) -- 24.10. 22:00 UTC = 25.10. 00:00 CEST
		-- ... and ends on winter time (that day has 25 hours).
		expect(day(1792969140)).toBe(20751) -- 25.10. 22:59 UTC = 23:59 CET
		expect(day(1792969200)).toBe(20752) -- 25.10. 23:00 UTC = 26.10. 00:00 CET
	end)

	it("uses the switch day of each year (31.03.2024, a Sunday in a leap year)", function()
		-- 31.03.2024 00:59 UTC is 01:59 CET; 01:00 UTC is 03:00 CEST: same day either way.
		expect(day(1711846740)).toBe(day(1711846800))
		expect(day(1711846800 + 21 * 3600 - 1)).toBe(day(1711846740)) -- 21:59 UTC = 23:59 CEST
		expect(day(1711846800 + 21 * 3600)).toBe(day(1711846740) + 1)
	end)

	it("is also available on a rules object", function()
		expect(GameRules.new(TestConfig).dayNumber(1768431600)).toBe(20468)
	end)
end)
