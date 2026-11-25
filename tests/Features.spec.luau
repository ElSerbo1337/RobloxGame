local TestKit = require("./TestKit")
local Features = require("../src/shared/Features")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local SWITCHES = { luckyWheel = true, codes = false }

describe("Features", function()
	it("reports a switched-on feature as enabled and a switched-off one as disabled", function()
		local features = Features.new(SWITCHES)

		expect(features.enabled("luckyWheel")).toBe(true)
		expect(features.enabled("codes")).toBe(false)
	end)

	it("fails loudly for an unknown feature id, so typos are caught", function()
		local features = Features.new(SWITCHES)

		local ok, err = pcall(features.enabled, "luckyWheeel")

		expect(ok).toBe(false)
		expect(string.find(tostring(err), "luckyWheeel", 1, true) ~= nil).toBe(true)
	end)

	it("runs a guarded handler only while its feature is enabled", function()
		local features = Features.new(SWITCHES)
		local calls = {}

		local wheel = features.guard("luckyWheel", function(player: string, amount: number)
			table.insert(calls, `{player}:{amount}`)
			return "spun"
		end)
		local code = features.guard("codes", function(player: string)
			table.insert(calls, `code:{player}`)
			return "redeemed"
		end)

		expect(wheel("Ana", 2)).toBe("spun")
		expect(code("Ana")).toBe(nil)
		expect(#calls).toBe(1)
		expect(calls[1]).toBe("Ana:2")
	end)

	it("checks the feature id of a guard when it is created, not on the first request", function()
		local features = Features.new(SWITCHES)

		local ok = pcall(features.guard, "unknownFeature", function() end)

		expect(ok).toBe(false)
	end)

	it("lists all feature ids sorted", function()
		local ids = Features.new(SWITCHES).ids()

		expect(#ids).toBe(2)
		expect(ids[1]).toBe("codes")
		expect(ids[2]).toBe("luckyWheel")
	end)

	it("does not change when the switch table is changed later", function()
		local switches = table.clone(SWITCHES)
		local features = Features.new(switches)

		switches.luckyWheel = false

		expect(features.enabled("luckyWheel")).toBe(true)
	end)
end)
