local TestKit = require("./TestKit")
local GameConfig = require("../src/shared/GameConfig")
local WorldLooks = require("../src/shared/WorldLooks")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function average(rgb: { number }): number
	return (rgb[1] + rgb[2] + rgb[3]) / 3
end

describe("WorldLooks", function()
	it("gives every world its own look", function()
		for _, world in GameConfig.worlds do
			expect(WorldLooks[world.id] ~= nil).toBe(true)
		end
	end)

	it("keeps the volcano readable: bright light, light ambient, thin haze (#24)", function()
		local volcano = WorldLooks.Volcano

		expect(volcano.brightness >= 2.8).toBe(true)
		expect(average(volcano.ambient) >= 110).toBe(true)
		expect(average(volcano.outdoorAmbient) >= 130).toBe(true)
		expect(volcano.atmosphere.density <= 0.35).toBe(true)
		expect(volcano.atmosphere.haze <= 2).toBe(true)
	end)

	it("keeps the volcano fiery: warm light from above and lava glow (#24)", function()
		local volcano = WorldLooks.Volcano

		expect(volcano.colorShiftTop[1] > volcano.colorShiftTop[3]).toBe(true)
		expect(volcano.atmosphere.decay[1] > volcano.atmosphere.decay[3]).toBe(true)
		-- Sun high enough to light the world from above (not a low sunset).
		expect(volcano.clockTime >= 13 and volcano.clockTime <= 17).toBe(true)
		expect(volcano.bloom.intensity >= 0.7).toBe(true)
	end)
end)
