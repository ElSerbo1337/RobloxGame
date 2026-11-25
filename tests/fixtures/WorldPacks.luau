-- The new worlds of the MEGA UPDATE (world 8 on, #82-#89) ship their models as one FBX
-- per world (tools/blender/build_world.py): assets/models/worlds/<WorldId>.fbx with every
-- topping, pet (Secret pet included) and egg of that world, plus one preview picture
-- assets/previews/worlds/<WorldId>.png. Worlds 1-7 keep one file per model.
local GameConfig = require("../../src/shared/GameConfig")

local FIRST_PACKED_WORLD = 8

local WorldPacks = {}

WorldPacks.MODELS = "assets/models/worlds"
WorldPacks.PREVIEWS = "assets/previews/worlds"

-- Asset ids (toppings, pets, eggs) of one world, sorted.
function WorldPacks.assetsOf(world: any): { string }
	local ids = {}
	local seen = {}
	local function add(id: string?)
		if id and not seen[id] then
			seen[id] = true
			table.insert(ids, id)
		end
	end
	for _, spawn in world.toppingSpawns do
		add(spawn.topping)
	end
	for _, eggId in world.eggs do
		add(eggId)
		for _, entry in GameConfig.eggs[eggId].pets do
			add(entry.pet)
		end
	end
	add(world.secretPet)
	table.sort(ids)
	return ids
end

-- The worlds whose models come as one FBX per world.
function WorldPacks.worlds(): { any }
	local list = {}
	for index, world in GameConfig.worlds do
		if index >= FIRST_PACKED_WORLD then
			table.insert(list, world)
		end
	end
	return list
end

-- Asset id -> world id, for every asset that lives in a world pack.
function WorldPacks.packedAssets(): { [string]: string }
	local map = {}
	for _, world in WorldPacks.worlds() do
		for _, id in WorldPacks.assetsOf(world) do
			map[id] = world.id
		end
	end
	return map
end

return WorldPacks
