-- Every pet and egg in the real configuration has its Blender model and preview
-- (tools/blender/build_pets.py). The Roblox side finds a pet model by its pet id
-- (ReplicatedStorage.GameAssets.Models.Pets.<PetId>), so the file names must match.
local fs = require("@lune/fs")

local TestKit = require("./TestKit")
local GameConfig = require("../src/shared/GameConfig")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local MODELS = "assets/models/pets"
local PREVIEWS = "assets/previews/pets"

describe("Pet models", function()
	it("has a model (FBX) and a preview picture named after every pet id", function()
		local missing = {}
		for petId in GameConfig.pets do
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
			if not fs.isFile(`{PREVIEWS}/{eggId}.png`) then
				table.insert(missing, eggId)
			end
		end
		table.sort(missing)
		expect(table.concat(missing, ", ")).toBe("")
	end)
end)
