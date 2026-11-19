-- Every topping in the real configuration has its Blender model and preview (#18).
-- The Roblox side dresses a topping disc with the model named after the topping id
-- (ReplicatedStorage.GameAssets.Models[.Toppings].<ToppingId>), so the file names must
-- match. World 1 toppings (#15) live in assets/models, worlds 2-7 in assets/models/toppings
-- (tools/blender/build_toppings.py).
local fs = require("@lune/fs")

local TestKit = require("./TestKit")
local GameConfig = require("../src/shared/GameConfig")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local MODELS = "assets/models/toppings"
local PREVIEWS = "assets/previews/toppings"

describe("Topping models", function()
	it("has a model (FBX) and a preview picture named after every topping id", function()
		local missing = {}
		for toppingId in GameConfig.toppings do
			if not (fs.isFile(`{MODELS}/{toppingId}.fbx`) or fs.isFile(`assets/models/{toppingId}.fbx`)) then
				table.insert(missing, `{toppingId}.fbx`)
			end
			if not (fs.isFile(`{PREVIEWS}/{toppingId}.png`) or fs.isFile(`assets/previews/{toppingId}.png`)) then
				table.insert(missing, `{toppingId}.png`)
			end
		end
		table.sort(missing)
		expect(table.concat(missing, ", ")).toBe("")
	end)

	it("has no model files for toppings that are not in the configuration", function()
		local unknown = {}
		for _, name in fs.readDir(MODELS) do
			local toppingId = string.match(name, "^(.+)%.fbx$")
			if toppingId and GameConfig.toppings[toppingId] == nil then
				table.insert(unknown, name)
			end
		end
		table.sort(unknown)
		expect(table.concat(unknown, ", ")).toBe("")
	end)

	it("has a check picture (on the ground and on the pizza) for every world", function()
		local missing = {}
		for index = 2, #GameConfig.worlds do
			if not fs.isFile(`{PREVIEWS}/World{index}.png`) then
				table.insert(missing, `World{index}.png`)
			end
		end
		expect(table.concat(missing, ", ")).toBe("")
	end)

	-- The alien mushroom's cap is matte, only its small violet spots glow (#48).
	it("lets only the violet spots of the alien mushroom glow", function()
		local model = fs.readFile(`{MODELS}/AlienMushroom.fbx`)
		local neon = {}
		for color in string.gmatch(model, "Top_(%x%x%x%x%x%x)_Neon") do
			neon[color] = true
		end
		local colors = {}
		for color in neon do
			table.insert(colors, color)
		end
		table.sort(colors)
		expect(table.concat(colors, ", ")).toBe("B45AFF")
	end)
end)
