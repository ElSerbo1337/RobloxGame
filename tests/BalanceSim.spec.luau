local TestKit = require("./TestKit")
local GameConfig = require("../src/shared/GameConfig")
local BalanceSim = require("../tools/BalanceSim")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- Real configuration with the rebirth tiers of #77 (worlds 1-4: 0, 5-6: 1, 7: 2 rebirths).
-- Prices are provisional until the balancing ticket (#108); medians over a few runs.
local result = BalanceSim.median(GameConfig, 9)

describe("balancing simulation with rebirth-gated worlds (#43, #77)", function()
	it("rebirths in world 4 before world 5, which needs a rebirth, without entering it", function()
		expect(result.first.worlds[4] > 0).toBe(true)
		for index = 5, 7 do
			expect(result.first.worlds[index]).toBe(0)
		end
	end)

	it("plays worlds 5-6 in the run after the first rebirth, world 7 only after the second", function()
		expect(result.afterRebirth.worlds[5] > 0).toBe(true)
		expect(result.afterRebirth.worlds[6] > 0).toBe(true)
		expect(result.afterRebirth.worlds[7]).toBe(0)
	end)
end)

describe("balancing simulation with the flat pet curve (#57)", function()
	-- Targets (#56): worlds 1-3 about 6/9/12 min; world 4 now lasts until the first
	-- rebirth (#77). Checked with some slack for the luck of few runs.
	local TARGETS = { 6, 9, 12 }

	it("plays worlds 1-3 of the first run in about 6/9/12 min", function()
		for index, target in TARGETS do
			local minutes = result.first.worlds[index]
			if minutes < target * 0.5 or minutes > target * 1.5 then
				error(`{GameConfig.worlds[index].id}: {string.format("%.1f", minutes)} min (target {target})`)
			end
		end
	end)

	it("reaches the first rebirth after about 45-90 min (#72: a rebirth every 45-90 min)", function()
		local total = result.first.total
		if total < 45 or total > 90 then
			error(`first run: {string.format("%.1f", total)} min`)
		end
	end)

	it("plays world 1 faster after the rebirth", function()
		expect(result.afterRebirth.worlds[1] < result.first.worlds[1]).toBe(true)
	end)

	it("plays the second run up to the next rebirth in about 40-90 min", function()
		local total = result.afterRebirth.total
		if total < 40 or total > 90 then
			error(`second run: {string.format("%.1f", result.afterRebirth.total)} min`)
		end
	end)
end)
