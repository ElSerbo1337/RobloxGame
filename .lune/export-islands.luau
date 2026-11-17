--!strict
-- Exports the island plan (src/shared/IslandPlan.luau) as JSON for the Blender preview
-- renders, so the previews show exactly the geometry the server builds.
-- Usage: lune run export-islands [out.json]   (default: build/islands.json)
-- Then:  python tools/blender/render_islands.py build/islands.json

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local GameConfig = require("../src/shared/GameConfig")
local IslandPlan = require("../src/shared/IslandPlan")

local out = process.args[1] or "build/islands.json"
local plan = IslandPlan.new(GameConfig.islands, GameConfig.worlds)

local islands = { plan.spawnIsland() }
for index = 1, #GameConfig.worlds do
	table.insert(islands, plan.worldIsland(index))
end

local gates = {}
for index = 2, #GameConfig.worlds do
	local gate = plan.gate(index)
	table.insert(gates, { worldId = GameConfig.worlds[index].id, parts = gate.parts, barrier = gate.barrier })
end

local worlds = {}
for index, world in GameConfig.worlds do
	table.insert(worlds, { id = world.id, color = world.color, center = plan.worldCenter(index) })
end

local data = {
	config = {
		groundY = GameConfig.islands.groundY,
		worldHalfSize = GameConfig.islands.worldHalfSize,
		bridgeWidth = GameConfig.islands.bridgeWidth,
	},
	worlds = worlds,
	islands = islands,
	bridges = plan.bridges(),
	gates = gates,
}

local dir = string.match(out, "^(.*)/[^/]+$")
if dir and not fs.isDir(dir) then
	fs.writeDir(dir)
end
fs.writeFile(out, serde.encode("json", data, false))
print(`wrote {out}`)
