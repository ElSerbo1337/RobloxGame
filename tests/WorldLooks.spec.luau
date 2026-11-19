local TestKit = require("./TestKit")
local GameConfig = require("../src/shared/GameConfig")
local WorldLooks = require("../src/shared/WorldLooks")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function sameValue(a: any, b: any): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for key, value in a do
		if not sameValue(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local function average(rgb: { number }): number
	return (rgb[1] + rgb[2] + rgb[3]) / 3
end

describe("WorldLooks", function()
	it("gives every world its own look", function()
		for _, world in GameConfig.worlds do
			expect(WorldLooks[world.id] ~= nil).toBe(true)
		end
	end)

	it("gives all worlds one shared look, only the music differs (#45)", function()
		local first = WorldLooks[GameConfig.worlds[1].id]
		local musics: { [string]: boolean } = {}
		for _, world in GameConfig.worlds do
			local look = WorldLooks[world.id]
			for key, value in first do
				if key ~= "music" then
					expect(sameValue(look[key], value)).toBe(true)
				end
			end
			expect(musics[look.music]).toBe(nil)
			musics[look.music] = true
		end
	end)

	it("lets only neon bloom: white non-neon surfaces stay below the threshold (#45)", function()
		for _, world in GameConfig.worlds do
			local look = WorldLooks[world.id]
			-- Rough lit brightness of a white surface: direct sun plus sky ambient,
			-- scaled by the color correction.
			local litWhite = (look.brightness + average(look.outdoorAmbient) / 255)
				* (1 + look.colorCorrection.brightness)
			expect(look.bloom.threshold > litWhite).toBe(true)
		end
	end)
end)
