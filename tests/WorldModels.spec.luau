-- One FBX per new world (#82 on, tools/blender/build_world.py): every topping, pet
-- (Secret pet included) and egg of the world is a model named after its id inside
-- assets/models/worlds/<WorldId>.fbx (imported into GameAssets/Models/Worlds, found by
-- ModelLibrary), with one preview picture per world.
local fs = require("@lune/fs")

local TestKit = require("./TestKit")
local GameConfig = require("../src/shared/GameConfig")
local WorldPacks = require("./fixtures/WorldPacks")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("World model packs (#82)", function()
	it("has an FBX and a preview picture for every new world", function()
		local missing = {}
		for _, world in WorldPacks.worlds() do
			if not fs.isFile(`{WorldPacks.MODELS}/{world.id}.fbx`) then
				table.insert(missing, `{world.id}.fbx`)
			end
			if not fs.isFile(`{WorldPacks.PREVIEWS}/{world.id}.png`) then
				table.insert(missing, `{world.id}.png`)
			end
		end
		expect(table.concat(missing, ", ")).toBe("")
	end)

	it("puts every topping, pet and egg of the world into its FBX as a model named after its id", function()
		local missing = {}
		for _, world in WorldPacks.worlds() do
			local path = `{WorldPacks.MODELS}/{world.id}.fbx`
			if fs.isFile(path) then
				local fbx = fs.readFile(path)
				for _, id in WorldPacks.assetsOf(world) do
					-- FBX node names are stored as "<name>\0\1Model".
					if string.find(fbx, id .. "\0\1Model", 1, true) == nil then
						table.insert(missing, `{world.id}/{id}`)
					end
				end
			end
		end
		expect(table.concat(missing, ", ")).toBe("")
	end)

	it("names the parts after their colour, like the single-model files", function()
		for _, world in WorldPacks.worlds() do
			local path = `{WorldPacks.MODELS}/{world.id}.fbx`
			if fs.isFile(path) then
				local fbx = fs.readFile(path)
				for _, prefix in { "Top_", "Pet_", "Egg_" } do
					expect(string.find(fbx, prefix, 1, true) ~= nil).toBe(true)
				end
			end
		end
	end)

	it("has no world files for worlds that are not in the configuration", function()
		local known = {}
		for _, world in GameConfig.worlds do
			known[world.id] = true
		end
		local unknown = {}
		for _, name in fs.readDir(WorldPacks.MODELS) do
			local id = string.match(name, "^(.+)%.fbx$")
			if id and not known[id] then
				table.insert(unknown, name)
			end
		end
		expect(table.concat(unknown, ", ")).toBe("")
	end)

	it("lists the Atlantis assets: 3 toppings, 6 pets, the Secret pet and the egg", function()
		expect(WorldPacks.assetsOf(GameConfig.worlds[8])).toEqual({
			"AtlantisEgg",
			"BubblePufferfish",
			"CaperClownfish",
			"KelpSnail",
			"LanternAnglerfish",
			"PearlCapers",
			"PearlKingOtter",
			"PearlMantaRay",
			"PoseidonSeaDragon",
			"Seaweed",
			"SquidRings",
		})
	end)

	it("lists the Jungle Temple assets: 3 toppings, 6 pets, the Secret pet and the egg (#83)", function()
		expect(WorldPacks.assetsOf(GameConfig.worlds[9])).toEqual({
			"CocoaBean",
			"CocoaFrog",
			"DragonFruit",
			"DragonFruitJaguar",
			"FireflyChameleon",
			"GoldenMonkeyKing",
			"JadeTempleSerpent",
			"JungleEgg",
			"Mango",
			"MangoToucan",
			"VineSloth",
		})
	end)

	it("lists the Desert Pyramids assets: 3 toppings, 6 pets, the Secret pet and the egg (#84)", function()
		local desert
		for _, world in GameConfig.worlds do
			if world.id == "DesertPyramids" then
				desert = world
			end
		end
		expect(WorldPacks.assetsOf(desert)).toEqual({
			"CactusFennec",
			"Date",
			"DateGecko",
			"DesertTruffle",
			"OasisCamel",
			"PharaohCat",
			"PricklyPear",
			"PyramidEgg",
			"SandScarab",
			"ScorpionKing",
			"SunSphinx",
		})
	end)
end)
