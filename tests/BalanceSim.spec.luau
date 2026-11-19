local TestKit = require("./TestKit")
local GameConfig = require("../src/shared/GameConfig")
local BalanceSim = require("../tools/BalanceSim")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- The real configuration plus an eighth world behind 1 rebirth (#43), priced like a
-- step after Weltraum and sharing its toppings and eggs.
local config = table.clone(GameConfig)
config.worlds = table.clone(GameConfig.worlds)
local space = GameConfig.worlds[#GameConfig.worlds]
local extra = table.clone(space)
extra.id = "TestWorld8"
extra.displayName = "Testwelt 8"
extra.unlockPrice = space.unlockPrice * 20
extra.requiredRebirths = 1
table.insert(config.worlds, extra)

describe("balancing simulation with rebirth-gated worlds", function()
	local result = BalanceSim.run(config, { seed = 7919 })

	it("rebirths before a world that needs a rebirth, without entering it", function()
		expect(result.first.worlds[8]).toBe(0)
		expect(result.first.worlds[7] > 0).toBe(true)
	end)

	it("plays the gated world in the run after the first rebirth", function()
		expect(result.afterRebirth.worlds[7] > 0).toBe(true)
		expect(result.afterRebirth.worlds[8] > 0).toBe(true)
	end)
end)

describe("balancing simulation with the flat pet curve (#57)", function()
	-- Real configuration, medians over a few runs with different luck.
	-- Targets (#56): worlds 1-7 about 6/9/12/16/20/25/32 min (world 7 = until the first
	-- rebirth), about 120 min in total; checked with some slack for the luck of few runs.
	local result = BalanceSim.median(GameConfig, 9)
	local TARGETS = { 6, 9, 12, 16, 20, 25, 32 }

	it("plays the first run in about 6/9/12/16/20/25/32 min per world", function()
		for index, target in TARGETS do
			local minutes = result.first.worlds[index]
			if minutes < target * 0.5 or minutes > target * 1.5 then
				error(`{GameConfig.worlds[index].id}: {string.format("%.1f", minutes)} min (target {target})`)
			end
		end
	end)

	it("reaches the first rebirth after about 120 min", function()
		local total = result.first.total
		if total < 100 or total > 140 then
			error(`first run: {string.format("%.1f", total)} min`)
		end
	end)

	it("plays world 1 faster after the rebirth", function()
		expect(result.afterRebirth.worlds[1] < result.first.worlds[1]).toBe(true)
	end)

	it("plays the second run up to the next rebirth in about 40-50 min (#58)", function()
		local total = result.afterRebirth.total
		if total < 38 or total > 52 then
			error(`second run: {string.format("%.1f", result.afterRebirth.total)} min`)
		end
	end)
end)
