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
