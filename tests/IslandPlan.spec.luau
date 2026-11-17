local TestKit = require("./TestKit")
local GameConfig = require("../src/shared/GameConfig")
local IslandPlan = require("../src/shared/IslandPlan")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local plan = IslandPlan.new(GameConfig.islands, GameConfig.worlds)
local cfg = GameConfig.islands
local WORLD_COUNT = #GameConfig.worlds

local function near(a: number, b: number, tolerance: number?): boolean
	return math.abs(a - b) <= (tolerance or 1e-6)
end

-- Point in the oriented box of a part spec (cframe = position + rotation columns).
local function insidePart(spec: IslandPlan.PartSpec, p: { number }, margin: number?): boolean
	local c = spec.cframe
	local d = { p[1] - c[1], p[2] - c[2], p[3] - c[3] }
	local m = margin or 0
	for axis = 1, 3 do
		-- Column `axis` of the rotation matrix (right, up, back).
		local along = d[1] * c[3 + axis] + d[2] * c[6 + axis] + d[3] * c[9 + axis]
		if math.abs(along) > spec.size[axis] / 2 + m then
			return false
		end
	end
	return true
end

-- Corners of a wedge's upper triangular face in world space (Roblox wedge: the sloped
-- face goes down towards -Z, the triangles are its two X faces).
local function wedgeTriangle(spec: IslandPlan.PartSpec): { { number } }
	local c, s = spec.cframe, spec.size
	local best, bestY = {}, -math.huge
	for _, x in { -s[1] / 2, s[1] / 2 } do
		local corners, sumY = {}, 0
		for _, yz in { { -s[2] / 2, -s[3] / 2 }, { -s[2] / 2, s[3] / 2 }, { s[2] / 2, s[3] / 2 } } do
			local y, z = yz[1], yz[2]
			local corner = {
				c[1] + c[4] * x + c[5] * y + c[6] * z,
				c[2] + c[7] * x + c[8] * y + c[9] * z,
				c[3] + c[10] * x + c[11] * y + c[12] * z,
			}
			sumY += corner[2]
			table.insert(corners, corner)
		end
		if sumY > bestY then
			best, bestY = corners, sumY
		end
	end
	return best
end

local function hasCorner(corners: { { number } }, p: { number }): boolean
	for _, corner in corners do
		if near(corner[1], p[1], 1e-4) and near(corner[2], p[2], 1e-4) and near(corner[3], p[3], 1e-4) then
			return true
		end
	end
	return false
end

local function solidParts(island: IslandPlan.Island): { IslandPlan.PartSpec }
	local result = {}
	for _, spec in island.parts do
		-- Ground and the invisible walls never block the camera (walls are see-through).
		if spec.collide and spec.role ~= "Ground" and spec.role ~= "Wall" then
			table.insert(result, spec)
		end
	end
	return result
end

describe("island chain", function()
	it("puts the spawn island first, then world 1, 2, ... along -Z at the same height", function()
		local spawn = plan.spawnIsland()
		local previousZ = spawn.center[3]
		for index = 1, WORLD_COUNT do
			local center = plan.worldCenter(index)
			expect(center[2]).toBe(spawn.center[2])
			expect(center[3] < previousZ).toBe(true)
			previousZ = center[3]
		end
	end)

	it("leaves a bridge of the configured length (about 40 studs) between neighbours", function()
		expect(cfg.bridgeLength >= 35 and cfg.bridgeLength <= 45).toBe(true)
		local spawn = plan.spawnIsland()
		local world1 = plan.worldIsland(1)
		expect(near(spawn.openings.back[3] - world1.openings.front[3], cfg.bridgeLength)).toBe(true)
		for index = 1, WORLD_COUNT - 1 do
			local a, b = plan.worldIsland(index), plan.worldIsland(index + 1)
			expect(near(a.openings.back[3] - b.openings.front[3], cfg.bridgeLength)).toBe(true)
		end
	end)

	it("finds the world whose island contains a position, and none on bridges", function()
		for index = 1, WORLD_COUNT do
			local center = plan.worldCenter(index)
			expect(plan.worldIndexAt(center[1], center[3])).toBe(index)
		end
		local world1 = plan.worldIsland(1)
		expect(plan.worldIndexAt(0, world1.openings.back[3] - cfg.bridgeLength / 2)).toBe(nil)
		expect(plan.worldIndexAt(0, plan.spawnIsland().center[3])).toBe(nil)
	end)

	it("lists one bridge per gap, from the spawn island to the last world", function()
		local bridges = plan.bridges()
		expect(#bridges).toBe(WORLD_COUNT)
		for _, bridge in bridges do
			expect(near(bridge.fromZ - bridge.toZ, cfg.bridgeLength)).toBe(true)
			expect(#bridge.parts > 0).toBe(true)
		end
	end)
end)

describe("island shape", function()
	it("gives world islands a rounded, irregular outline (not a square)", function()
		local outline = plan.worldIsland(1).outline
		expect(#outline >= 24).toBe(true)
		local center = plan.worldCenter(1)
		local smallest, largest = math.huge, 0
		for _, p in outline do
			local d = math.sqrt((p[1] - center[1]) ^ 2 + (p[2] - center[3]) ^ 2)
			smallest = math.min(smallest, d)
			largest = math.max(largest, d)
		end
		-- Corners are cut (a square would reach half * sqrt(2)) and the rim wobbles.
		expect(largest < cfg.worldHalfSize * 1.3).toBe(true)
		expect(largest - smallest > 5).toBe(true)
	end)

	it("covers the whole outline with ground triangles that meet exactly at the rim", function()
		local island = plan.worldIsland(1)
		local groundY = island.center[2]
		local triangles = {}
		for _, spec in island.parts do
			if spec.role == "Ground" and spec.shape == "Wedge" then
				table.insert(triangles, wedgeTriangle(spec))
			end
		end
		expect(#triangles >= #island.outline * 2).toBe(true)
		-- Every rim point is a corner of a ground triangle (at the ground surface).
		for _, p in island.outline do
			local found = false
			for _, corners in triangles do
				if hasCorner(corners, { p[1], groundY, p[2] }) then
					found = true
					break
				end
			end
			expect(found).toBe(true)
		end
	end)

	it("hangs a rock cliff below the rim of every new-style island", function()
		for _, island in { plan.spawnIsland(), plan.worldIsland(1) } do
			local lowest = 0
			for _, spec in island.parts do
				if spec.role == "Cliff" then
					lowest = math.min(lowest, spec.cframe[2] - spec.size[2] / 2)
				end
			end
			expect(lowest < island.center[2] - 20).toBe(true)
		end
	end)

	it("keeps players on every island with an invisible wall tall enough not to jump over", function()
		expect(cfg.wallHeight >= 15).toBe(true)
		for _, island in { plan.spawnIsland(), plan.worldIsland(1), plan.worldIsland(2) } do
			local walls = 0
			for _, spec in island.parts do
				if spec.role == "Wall" then
					walls += 1
					expect(spec.collide).toBe(true)
					expect(spec.transparency).toBe(1)
					expect(spec.size[2] >= cfg.wallHeight).toBe(true)
				end
			end
			expect(walls >= 4).toBe(true)
		end
	end)

	it("closes the rim with walls everywhere except the bridge openings", function()
		local island = plan.worldIsland(1)
		local center = island.center
		-- Walk around the rim just inside the outline: every point next to a wall, except openings.
		for i, p in island.outline do
			local q = island.outline[i % #island.outline + 1]
			local mid = { (p[1] + q[1]) / 2, center[2] + 4, (p[2] + q[2]) / 2 }
			local isOpening = math.abs(mid[1] - center[1]) < cfg.bridgeWidth / 2
			local walled = false
			for _, spec in island.parts do
				if spec.role == "Wall" and insidePart(spec, mid, 0.6) then
					walled = true
					break
				end
			end
			expect(walled).toBe(not isOpening)
		end
	end)

	it("walls in both sides of every bridge", function()
		for _, bridge in plan.bridges() do
			local midZ = (bridge.fromZ + bridge.toZ) / 2
			local y = plan.worldCenter(1)[2] + 4
			local left, right = false, false
			for _, spec in bridge.parts do
				if spec.role == "Wall" then
					left = left or insidePart(spec, { -cfg.bridgeWidth / 2, y, midZ }, 0.6)
					right = right or insidePart(spec, { cfg.bridgeWidth / 2, y, midZ }, 0.6)
				end
			end
			expect(left and right).toBe(true)
		end
	end)

	it("sends players who fell below the islands back (fall height)", function()
		expect(plan.hasFallen(plan.worldCenter(1)[2] - 5)).toBe(false)
		expect(plan.hasFallen(cfg.fallY - 1)).toBe(true)
		-- Deep enough that the cliffs (and the waterfalls) end above it.
		expect(cfg.fallY < plan.worldCenter(1)[2] - 50).toBe(true)
	end)
end)

describe("world island layout (shared floor plan)", function()
	local island = plan.worldIsland(1)
	local center = island.center

	local function insideOutline(x: number, z: number): boolean
		return plan.isInsideOutline(island.outline, x, z)
	end

	it("has every station of the floor plan, two egg spots included", function()
		for _, name in { "Spawn", "Oven", "Shop", "Egg1", "Egg2", "Phone", "Van", "Portal", "Landmark" } do
			expect(island.stations[name] ~= nil).toBe(true)
		end
	end)

	it("places the stations left and right of the main path, facing it", function()
		for _, name in { "Oven", "Shop", "Egg1", "Egg2", "Phone", "Van", "Portal" } do
			local station = island.stations[name]
			local side = station.position[1] - center[1]
			expect(math.abs(side) > cfg.pathWidth / 2 + 4).toBe(true)
			-- Front direction of a station turned by yaw from facing -Z.
			local frontX = -math.sin(station.yaw)
			expect(frontX * side < 0).toBe(true)
		end
	end)

	it("puts the stations between the arriving bridge and the topping field", function()
		local fieldFront = island.field.center[3] + island.field.size[2] / 2
		for _, name in { "Spawn", "Oven", "Shop", "Egg1", "Egg2", "Phone", "Van", "Portal" } do
			local station = island.stations[name]
			expect(station.position[3] > fieldFront + 8).toBe(true)
			expect(station.position[3] < island.openings.front[3]).toBe(true)
		end
		-- Landmark at the back, behind the field.
		local fieldBack = island.field.center[3] - island.field.size[2] / 2
		expect(island.stations.Landmark.position[3] < fieldBack).toBe(true)
	end)

	it("keeps the field, the stations and the decoration on the island", function()
		local f = island.field
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				expect(insideOutline(f.center[1] + sx * f.size[1] / 2, f.center[3] + sz * f.size[2] / 2)).toBe(true)
			end
		end
		for _, station in island.stations do
			expect(insideOutline(station.position[1], station.position[3])).toBe(true)
		end
		for _, model in island.models do
			expect(insideOutline(model.position[1], model.position[3])).toBe(true)
		end
	end)

	it("keeps trees and props off the field, the paths and the station fronts", function()
		local f = island.field
		for _, model in island.models do
			local x, z, r = model.position[1], model.position[3], model.width / 2
			local onField = math.abs(x - f.center[1]) < f.size[1] / 2 + r
				and math.abs(z - f.center[3]) < f.size[2] / 2 + r
			expect(onField).toBe(false)
			expect(math.abs(x - center[1]) < cfg.pathWidth / 2 + r).toBe(false)
			for name, station in island.stations do
				if name ~= "Landmark" then
					local d = math.sqrt((x - station.position[1]) ^ 2 + (z - station.position[3]) ^ 2)
					expect(d > r + 9).toBe(true)
				end
			end
		end
	end)

	it("keeps the camera free while a station is used (nothing between player and camera)", function()
		local solids = solidParts(island)
		for _, name in { "Oven", "Shop", "Egg1", "Egg2", "Phone", "Van", "Portal" } do
			local station = island.stations[name]
			local fx, fz = -math.sin(station.yaw), -math.cos(station.yaw)
			-- Player stands in front of the station, the camera ~14 studs behind and above.
			local standX, standZ = station.position[1] + fx * 9, station.position[3] + fz * 9
			for step = 0, 28 do
				local t = step / 28
				local p = { standX + fx * 14 * t, center[2] + 3 + 5 * t, standZ + fz * 14 * t }
				for _, spec in solids do
					if insidePart(spec, p) then
						error(`{name}: camera path blocked by {spec.name}`)
					end
				end
				for _, model in island.models do
					if model.collide then
						local d = math.sqrt((p[1] - model.position[1]) ^ 2 + (p[3] - model.position[3]) ^ 2)
						expect(d > model.width / 2).toBe(true)
					end
				end
			end
		end
	end)

	it("has water: a pond with a waterfall over the rim, and raised terraces", function()
		local water, fall, terraces = 0, 0, 0
		for _, spec in island.parts do
			if spec.role == "Water" then
				water += 1
			elseif spec.role == "Waterfall" then
				fall += 1
				expect(spec.size[2] > 20).toBe(true)
			elseif spec.role == "Terrace" then
				terraces += 1
				expect(spec.cframe[2] + spec.size[2] / 2 > center[2] + 2).toBe(true)
			end
		end
		expect(water > 0).toBe(true)
		expect(fall > 0).toBe(true)
		expect(terraces > 0).toBe(true)
	end)

	it("uses only SmoothPlastic (plus glowing and see-through accents) in the new style", function()
		local allowed = { SmoothPlastic = true, Neon = true, Glass = true, ForceField = true }
		for _, spec in island.parts do
			expect(allowed[spec.material] == true).toBe(true)
		end
	end)
end)

describe("egg spots in every world", function()
	it("gives every world island, the old-style ones included, two separate egg stands", function()
		for index = 1, WORLD_COUNT do
			local island = plan.worldIsland(index)
			local first, second = island.stations.Egg1, island.stations.Egg2
			expect(first ~= nil and second ~= nil).toBe(true)
			-- Stands are 10 studs wide: keep them (and the other stations) apart.
			for name, station in island.stations do
				if name ~= "Egg2" then
					local d = math.sqrt(
						(second.position[1] - station.position[1]) ^ 2 + (second.position[3] - station.position[3]) ^ 2
					)
					expect(d >= 14).toBe(true)
				end
			end
			expect(plan.worldIndexAt(second.position[1], second.position[3])).toBe(index)
		end
	end)
end)

describe("spawn island", function()
	local spawn = plan.spawnIsland()

	it("has a spawn point, a pizza fountain, a portal gate and three leaderboards", function()
		for _, name in { "Spawn", "Fountain", "Portal", "Board1", "Board2", "Board3" } do
			expect(spawn.stations[name] ~= nil).toBe(true)
		end
	end)

	it("is smaller than a world island and opens only towards world 1", function()
		expect(cfg.spawnRadius < cfg.worldHalfSize).toBe(true)
		expect(spawn.openings.front).toBe(nil)
		expect(spawn.openings.back ~= nil).toBe(true)
	end)

	it("lets the boards and the portal face the middle of the island", function()
		for _, name in { "Board1", "Board2", "Board3", "Portal" } do
			local station = spawn.stations[name]
			local fx, fz = -math.sin(station.yaw), -math.cos(station.yaw)
			local toCenterX = spawn.center[1] - station.position[1]
			local toCenterZ = spawn.center[3] - station.position[3]
			expect(fx * toCenterX + fz * toCenterZ > 0).toBe(true)
		end
	end)

	it("keeps everything on the island", function()
		for _, station in spawn.stations do
			expect(plan.isInsideOutline(spawn.outline, station.position[1], station.position[3])).toBe(true)
		end
		for _, model in spawn.models do
			expect(plan.isInsideOutline(spawn.outline, model.position[1], model.position[3])).toBe(true)
		end
	end)
end)

describe("gates", function()
	it("puts a glowing gate with a solid barrier on the bridge head of every locked world", function()
		for index = 2, WORLD_COUNT do
			local gate = plan.gate(index)
			local front = plan.worldIsland(index).openings.front
			expect(gate.barrier.collide).toBe(true)
			expect(gate.barrier.size[1] >= cfg.bridgeWidth).toBe(true)
			expect(gate.barrier.size[2] >= cfg.wallHeight).toBe(true)
			expect(near(gate.barrier.cframe[3], front[3], 3)).toBe(true)
			local glows = false
			for _, spec in gate.parts do
				glows = glows or spec.material == "Neon"
			end
			expect(glows).toBe(true)
		end
	end)

	it("returns players to the bridge in front of the gate", function()
		local gate = plan.gate(2)
		local front = plan.worldIsland(2).openings.front
		expect(gate.returnPoint[3] > front[3] + 3).toBe(true)
		expect(plan.worldIndexAt(gate.returnPoint[1], gate.returnPoint[3])).toBe(nil)
	end)
end)
