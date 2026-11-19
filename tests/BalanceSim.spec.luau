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

describe("balancing simulation with the pet cap per world (#51)", function()
	-- Real configuration, medians over a few runs with different luck.
	local result = BalanceSim.median(GameConfig, 9)
	local function worlds1to6(run: BalanceSim.Run): number
		local minutes = 0
		for index = 1, 6 do
			minutes += run.worlds[index]
		end
		return minutes
	end

	it("plays worlds 1-6 after the first rebirth in about 1/3 of the first run's time", function()
		local first, second = worlds1to6(result.first), worlds1to6(result.afterRebirth)
		local ratio = second / first
		if ratio < 0.25 or ratio > 0.42 then
			error(`worlds 1-6: {string.format("%.1f", first)} min, then {string.format("%.1f", second)} min`)
		end
	end)
end)
