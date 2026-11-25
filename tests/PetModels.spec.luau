-- Every pet and egg in the real configuration has its Blender model and preview
-- (tools/blender/build_pets.py). The Roblox side finds a pet model by its pet id
-- (ReplicatedStorage.GameAssets.Models.Pets.<PetId>), so the file names must match.
local fs = require("@lune/fs")

local TestKit = require("./TestKit")
local GameConfig = require("../src/shared/GameConfig")
local WorldPacks = require("./fixtures/WorldPacks")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local MODELS = "assets/models/pets"
local PREVIEWS = "assets/previews/pets"
-- Pets and eggs of the new worlds (#82 on) live in one FBX per world (WorldModels.spec).
local packed = WorldPacks.packedAssets()

describe("Pet models", function()
	it("has a model (FBX) and a preview picture named after every pet id", function()
		local missing = {}
		for petId in GameConfig.pets do
			if packed[petId] then
				continue
			end
			if not fs.isFile(`{MODELS}/{petId}.fbx`) then
				table.insert(missing, `{petId}.fbx`)
			end
			if not fs.isFile(`{PREVIEWS}/{petId}.png`) then
				table.insert(missing, `{petId}.png`)
			end
		end
		table.sort(missing)
		expect(table.concat(missing, ", ")).toBe("")
	end)

	it("has no model files for pets that are not in the configuration", function()
		local unknown = {}
		for _, name in fs.readDir(MODELS) do
			local petId = string.match(name, "^(.+)%.fbx$")
			if petId and GameConfig.pets[petId] == nil then
				table.insert(unknown, name)
			end
		end
		table.sort(unknown)
		expect(table.concat(unknown, ", ")).toBe("")
	end)

	it("has a preview sheet with all pets side by side for every egg", function()
		local missing = {}
		for eggId in GameConfig.eggs do
			if packed[eggId] then
				continue
			end
			if not fs.isFile(`{PREVIEWS}/{eggId}.png`) then
				table.insert(missing, eggId)
			end
		end
		table.sort(missing)
		expect(table.concat(missing, ", ")).toBe("")
	end)

	-- Only eggs with an explicit `glow` keep Neon parts; fancy eggs without it glow no
	-- more (#48). Part names carry the material ("Egg_FF7A1A_Neon").
	it("gives Neon parts only to eggs whose look has glow", function()
		local wrong = {}
		for eggId, egg in GameConfig.eggs do
			if packed[eggId] then
				continue
			end
			local model = fs.readFile(`assets/models/eggs/{eggId}.fbx`)
			local hasNeon = string.find(model, "_Neon", 1, true) ~= nil
			if hasNeon ~= (egg.look.glow == true) then
				table.insert(wrong, eggId)
			end
		end
		table.sort(wrong)
		expect(table.concat(wrong, ", ")).toBe("")
	end)
end)
