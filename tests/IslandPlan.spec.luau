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

-- Every world is an island in the shared floor plan (#27, #31, #32).
local WORLD_INDICES = {}
for index in GameConfig.worlds do
	table.insert(WORLD_INDICES, index)
end

for _, worldIndex in WORLD_INDICES do
	describe(`world island layout (shared floor plan), world {worldIndex}`, function()
		local island = plan.worldIsland(worldIndex)
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

		it("hangs a rock cliff below the rim and walls in the rim", function()
			local lowest, walls = 0, 0
			for _, spec in island.parts do
				if spec.role == "Cliff" then
					lowest = math.min(lowest, spec.cframe[2] - spec.size[2] / 2)
				elseif spec.role == "Wall" then
					walls += 1
				end
			end
			expect(lowest < center[2] - 20).toBe(true)
			expect(walls >= 24).toBe(true)
		end)

		it("has a landmark and a visible rim", function()
			local landmark, rim = 0, 0
			for _, spec in island.parts do
				if spec.role == "Landmark" then
					landmark += 1
				elseif spec.role == "Rim" then
					rim += 1
				end
			end
			expect(landmark >= 5).toBe(true)
			expect(rim >= 20).toBe(true)
		end)
	end)
end

describe("egg spots in every world", function()
	it("gives every world island two separate egg stands", function()
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

describe("world themes (worlds 2-7, #31, #32)", function()
	local function indexOf(id: string): number
		for index, world in GameConfig.worlds do
			if world.id == id then
				return index
			end
		end
		error(`no world {id}`)
	end

	local function names(parts: { IslandPlan.PartSpec }): { [string]: number }
		local count = {}
		for _, spec in parts do
			count[spec.name] = (count[spec.name] or 0) + 1
		end
		return count
	end

	local THEMED = { "Farm", "Beach", "Icebergs", "Volcano", "CandyLand", "Space", "Atlantis", "JungleTemple" }

	it("builds every world as an island, worlds 2-8 with their own theme", function()
		for index = 1, WORLD_COUNT do
			expect(plan.worldIsland(index).kind).toBe("world")
		end
		for _, id in THEMED do
			expect(cfg.themes[id] ~= nil).toBe(true)
		end
	end)

	it("gives every island world its own landmark, rim and ground colour", function()
		local landmarks, rims, grounds = {}, {}, {}
		for _, index in WORLD_INDICES do
			local theme = cfg.themes[GameConfig.worlds[index].id]
			local landmark = theme.landmark or "GiantPizza"
			local rim = theme.rimStyle or "Hedge"
			local ground = table.concat(theme.grass, ",")
			expect(landmarks[landmark]).toBe(nil)
			expect(rims[rim]).toBe(nil)
			expect(grounds[ground]).toBe(nil)
			landmarks[landmark], rims[rim], grounds[ground] = true, true, true
		end
	end)

	it("puts the landmark parts at the back of the island", function()
		for _, id in THEMED do
			local island = plan.worldIsland(indexOf(id))
			local fieldBack = island.field.center[3] - island.field.size[2] / 2
			for _, spec in island.parts do
				if spec.role == "Landmark" then
					expect(spec.cframe[3] < fieldBack).toBe(true)
				end
			end
		end
	end)

	it("uses the world's own decoration models", function()
		local expected = {
			Farm = "HayBale",
			Beach = "PalmTree",
			Icebergs = "SnowPine",
			Volcano = "DeadTree",
			CandyLand = "Lollipop",
			Space = "MoonRock",
		}
		for id, model in expected do
			local found = false
			for _, m in plan.worldIsland(indexOf(id)).models do
				found = found or m.model == model
			end
			expect(found).toBe(true)
		end
	end)

	it("leads into each world over a matching bridge", function()
		local bridges = plan.bridges()
		-- Bridge k leads into world k (bridge 1 starts at the spawn island).
		expect(names(bridges[indexOf("PizzeriaGarden")].parts).Rope ~= nil).toBe(true)
		expect(names(bridges[indexOf("Farm")].parts).Rope ~= nil).toBe(true)
		local walk = names(bridges[indexOf("Beach")].parts)
		expect(walk.Stilt ~= nil and walk.HandRail ~= nil and walk.Rope == nil).toBe(true)
		local ice = names(bridges[indexOf("Icebergs")].parts)
		expect(ice.IceSlab ~= nil and ice.IceRail ~= nil and ice.Rope == nil).toBe(true)
		local basalt = names(bridges[indexOf("Volcano")].parts)
		expect(basalt.BasaltSlab ~= nil and basalt.BasaltColumn ~= nil and basalt.Rope == nil).toBe(true)
		local candy = names(bridges[indexOf("CandyLand")].parts)
		expect(candy.WaferSlab ~= nil and candy.CaneRail ~= nil and candy.CaneHook ~= nil).toBe(true)
		local light = names(bridges[indexOf("Space")].parts)
		expect(light.LightSlab ~= nil and light.LightStrip ~= nil and light.Rope == nil).toBe(true)
	end)

	it("keeps glowing lights few on every island and bridge (no glare)", function()
		local function lights(parts: { IslandPlan.PartSpec }): number
			local count = 0
			for _, spec in parts do
				-- The server gives every Neon part with role Glow a PointLight.
				if spec.role == "Glow" and spec.material == "Neon" then
					count += 1
				end
			end
			return count
		end
		for index = 1, WORLD_COUNT do
			expect(lights(plan.worldIsland(index).parts) <= 6).toBe(true)
		end
		for _, bridge in plan.bridges() do
			expect(lights(bridge.parts) <= 4).toBe(true)
		end
	end)

	it("keeps the volcano light enough to see everything (#24)", function()
		local theme = cfg.themes.Volcano
		local function brightness(c: { number }): number
			return 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3]
		end
		expect(brightness(theme.grass) > 120).toBe(true)
		expect(brightness(theme.field) > 160).toBe(true)
		expect(brightness(theme.path) > 160).toBe(true)
		-- Lava glows around the island: crater, cracks and the lava pond.
		local glows = 0
		for _, spec in plan.worldIsland(indexOf("Volcano")).parts do
			if spec.material == "Neon" then
				glows += 1
			end
		end
		expect(glows >= 5).toBe(true)
	end)

	it("builds the volcano as a dark tapering basalt cone with lava streams and smoke (#47)", function()
		local function brightness(c: { number }): number
			return 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3]
		end
		local rocks, streams, crater, lava, smoke = {}, {}, nil, nil, nil
		for _, spec in plan.worldIsland(indexOf("Volcano")).parts do
			if spec.name == "VolcanoRock" then
				table.insert(rocks, spec)
			elseif spec.name == "LavaStream" then
				table.insert(streams, spec)
			elseif spec.name == "VolcanoCrater" then
				crater = spec
			elseif spec.name == "VolcanoLava" then
				lava = spec
			elseif spec.name == "VolcanoSmoke" then
				smoke = spec
			end
		end
		-- Cone: many layers, each narrower than the one below, in dark basalt tones.
		expect(#rocks >= 8).toBe(true)
		table.sort(rocks, function(a, b)
			return a.cframe[2] < b.cframe[2]
		end)
		for k, rock in rocks do
			expect(brightness(rock.color) < 90).toBe(true)
			if k > 1 then
				expect(rock.size[2] < rocks[k - 1].size[2]).toBe(true)
			end
		end
		local top = rocks[#rocks]
		expect(top.size[2] < rocks[1].size[2] * 0.45).toBe(true)
		-- Crater lava stays neon; 2-3 neon streams run down different flanks.
		assert(crater and lava and smoke, "crater, lava and smoke expected")
		expect(lava.material).toBe("Neon")
		local directions: { number } = {}
		for _, stream in streams do
			expect(stream.material).toBe("Neon")
			local dx, dz = stream.cframe[1] - top.cframe[1], stream.cframe[3] - top.cframe[3]
			local angle = math.atan2(dz, dx)
			local known = false
			for _, other in directions do
				local diff = math.abs(math.atan2(math.sin(angle - other), math.cos(angle - other)))
				known = known or diff < math.rad(5)
			end
			if not known then
				table.insert(directions, angle)
			end
		end
		expect(#directions >= 2 and #directions <= 3).toBe(true)
		-- Smoke: an invisible emitter above the crater.
		expect(smoke.role).toBe("Smoke")
		expect(smoke.transparency).toBe(1)
		expect(smoke.collide).toBe(false)
		expect(smoke.cframe[2] > lava.cframe[2]).toBe(true)
		expect(math.abs(smoke.cframe[1] - top.cframe[1]) < 1).toBe(true)
	end)

	it("lets the planet float above the space terrace", function()
		local island = plan.worldIsland(indexOf("Space"))
		local found = false
		for _, m in island.models do
			if m.model == "Planet" then
				found = true
				expect(m.position[2] > island.center[2] + 10).toBe(true)
			end
		end
		expect(found).toBe(true)
	end)

	it("keeps every bridge deck walkable and level with the islands at both ends", function()
		for _, bridge in plan.bridges() do
			local deck = 0
			for _, spec in bridge.parts do
				local isDeck = spec.name == "Plank"
					or spec.name == "IceSlab"
					or spec.name == "BasaltSlab"
					or spec.name == "WaferSlab"
					or spec.name == "LightSlab"
				if spec.role == "Bridge" and spec.collide and isDeck then
					deck += 1
					local top = spec.cframe[2] + spec.size[2] / 2
					expect(math.abs(top - cfg.groundY) < 2.5).toBe(true)
				end
			end
			expect(deck >= 8).toBe(true)
		end
	end)
end)

describe("no flickering at island edges (#46)", function()
	local MIN_GAP = 0.1

	local function allIslands(): { IslandPlan.Island }
		local islands = { plan.spawnIsland() }
		for index in GameConfig.worlds do
			table.insert(islands, plan.worldIsland(index))
		end
		return islands
	end

	local function top(spec: IslandPlan.PartSpec): number
		local c, s = spec.cframe, spec.size
		return c[2] + (math.abs(c[7]) * s[1] + math.abs(c[8]) * s[2] + math.abs(c[9]) * s[3]) / 2
	end

	local function sameColor(a: IslandPlan.PartSpec, b: IslandPlan.PartSpec): boolean
		return a.color[1] == b.color[1] and a.color[2] == b.color[2] and a.color[3] == b.color[3]
	end

	-- Top faces of two level blocks overlap (separating axis test on their rectangles).
	local function topsOverlap(a: IslandPlan.PartSpec, b: IslandPlan.PartSpec): boolean
		local function corners(spec: IslandPlan.PartSpec): { { number } }
			local c, s = spec.cframe, spec.size
			local out = {}
			for _, k in { { -1, -1 }, { -1, 1 }, { 1, 1 }, { 1, -1 } } do
				local x, z = k[1] * s[1] / 2, k[2] * s[3] / 2
				table.insert(out, { c[1] + c[4] * x + c[6] * z, c[3] + c[10] * x + c[12] * z })
			end
			return out
		end
		local ca, cb = corners(a), corners(b)
		for _, spec in { a, b } do
			for _, axis in { { spec.cframe[4], spec.cframe[10] }, { spec.cframe[6], spec.cframe[12] } } do
				local minA, maxA, minB, maxB = math.huge, -math.huge, math.huge, -math.huge
				for _, p in ca do
					local d = p[1] * axis[1] + p[2] * axis[2]
					minA, maxA = math.min(minA, d), math.max(maxA, d)
				end
				for _, p in cb do
					local d = p[1] * axis[1] + p[2] * axis[2]
					minB, maxB = math.min(minB, d), math.max(maxB, d)
				end
				if maxA <= minB + 1e-6 or maxB <= minA + 1e-6 then
					return false
				end
			end
		end
		return true
	end

	it("never gives overlapping, differently coloured cliff blocks the same top", function()
		for _, island in allIslands() do
			local cliffs = {}
			for _, spec in island.parts do
				if spec.name == "Cliff" then
					table.insert(cliffs, spec)
				end
			end
			for i, a in cliffs do
				for j = i + 1, #cliffs do
					local b = cliffs[j]
					local sameTop = math.abs(top(a) - top(b)) < 0.05
					if sameTop and not sameColor(a, b) and topsOverlap(a, b) then
						expect(sameTop).toBe(false)
					end
				end
			end
		end
	end)

	it("keeps the cliff's outer faces out of the plane of the ground's side faces", function()
		for _, island in allIslands() do
			local outline, count = island.outline, #island.outline
			for i = 1, count do
				local p, q = outline[i], outline[i % count + 1]
				local ex, ez = q[1] - p[1], q[2] - p[2]
				local len = math.sqrt(ex * ex + ez * ez)
				if len > 0.01 then
					local nx, nz = -ez / len, ex / len
					local mx, mz = (p[1] + q[1]) / 2, (p[2] + q[2]) / 2
					for _, spec in island.parts do
						if spec.name == "Cliff" then
							local c = spec.cframe
							-- Faces at +-right (column 1) are the cliff's outer and inner sides.
							local parallel = math.abs(c[4] * nx + c[10] * nz) > 0.9999
							for _, sign in { -1, 1 } do
								local fx = c[1] + sign * c[4] * spec.size[1] / 2
								local fz = c[3] + sign * c[10] * spec.size[1] / 2
								-- Only the block of this very edge (its face center sits on the edge).
								local close = math.sqrt((fx - mx) ^ 2 + (fz - mz) ^ 2) < 1
								if parallel and close then
									local offset = math.abs((fx - p[1]) * nx + (fz - p[2]) * nz)
									expect(offset >= 0.05).toBe(true)
								end
							end
						end
					end
				end
			end
		end
	end)

	it("keeps overlapping thin ground layers a minimum distance apart", function()
		local thin =
			{ ToppingArea = true, FieldRow = true, PathPlate = true, LavaCrack = true, Pond = true, Stream = true }
		local function footprint(spec: IslandPlan.PartSpec): { number }
			local c, s = spec.cframe, spec.size
			local hx = (math.abs(c[4]) * s[1] + math.abs(c[5]) * s[2] + math.abs(c[6]) * s[3]) / 2
			local hz = (math.abs(c[10]) * s[1] + math.abs(c[11]) * s[2] + math.abs(c[12]) * s[3]) / 2
			return { c[1] - hx, c[1] + hx, c[3] - hz, c[3] + hz }
		end
		for _, island in allIslands() do
			local groundY = island.center[2]
			local layers = {}
			for _, spec in island.parts do
				if thin[spec.name] then
					expect(top(spec) - groundY >= MIN_GAP - 1e-6).toBe(true)
					table.insert(layers, { spec = spec, box = footprint(spec), top = top(spec) })
				end
			end
			for i, a in layers do
				for j = i + 1, #layers do
					local b = layers[j]
					if a.spec.name ~= b.spec.name then
						local overlapping = a.box[1] < b.box[2]
							and b.box[1] < a.box[2]
							and a.box[3] < b.box[4]
							and b.box[3] < a.box[4]
						if overlapping then
							expect(math.abs(a.top - b.top) >= MIN_GAP - 1e-6).toBe(true)
						end
					end
				end
			end
		end
	end)
end)
