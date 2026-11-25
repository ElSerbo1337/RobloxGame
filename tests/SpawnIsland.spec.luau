-- Spawn island as a marketplace (#106): reserved spots for later tickets, update board
-- and countdown sign, deco out of the way, part budget.
local TestKit = require("./TestKit")
local GameConfig = require("../src/shared/GameConfig")
local IslandPlan = require("../src/shared/IslandPlan")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local plan = IslandPlan.new(GameConfig.islands, GameConfig.worlds)
local cfg = GameConfig.islands
local spawn = plan.spawnIsland()

local function distance(a: { number }, b: { number }): number
	return math.sqrt((a[1] - b[1]) ^ 2 + (a[3] - b[3]) ^ 2)
end

-- Horizontal half-diagonal of a part (how far it reaches from its center). Island
-- cylinders stand upright (size = { height, diameter, diameter }).
local function reach(spec: IslandPlan.PartSpec): number
	if spec.shape == "Cylinder" then
		return spec.size[2] / 2
	end
	return math.sqrt(spec.size[1] ^ 2 + spec.size[3] ^ 2) / 2
end

-- Point (x, z) inside a level part's top rectangle, grown by `margin`.
local function onTop(spec: IslandPlan.PartSpec, x: number, z: number, margin: number): boolean
	local c = spec.cframe
	local dx, dz = x - c[1], z - c[3]
	local alongX = dx * c[4] + dz * c[10]
	local alongZ = dx * c[6] + dz * c[12]
	return math.abs(alongX) <= spec.size[1] / 2 + margin and math.abs(alongZ) <= spec.size[3] / 2 + margin
end

-- Parts a player could bump into that are not the island itself.
local function isProp(spec: IslandPlan.PartSpec): boolean
	return spec.role == "Deco" or spec.role == "Glow" or spec.role == "UpdateBoard" or spec.role == "Countdown"
end

local RESERVED = { "Wheel", "Merchant", "Board4", "Board5" }

describe("spawn marketplace (#106)", function()
	it("keeps the spawn point, the portal and the three leaderboards", function()
		for _, name in { "Spawn", "Fountain", "Portal", "Board1", "Board2", "Board3" } do
			expect(spawn.stations[name] ~= nil).toBe(true)
		end
	end)

	it("reserves spots for the lucky wheel, the merchant and two new leaderboards", function()
		for _, name in RESERVED do
			local station = spawn.stations[name]
			expect(station ~= nil).toBe(true)
			expect((station.clear or 0) >= 8).toBe(true)
			expect(plan.isInsideOutline(spawn.outline, station.position[1], station.position[3])).toBe(true)
		end
	end)

	it("lets the reserved spots face the middle of the island", function()
		for _, name in RESERVED do
			local station = spawn.stations[name]
			local fx, fz = -math.sin(station.yaw), -math.cos(station.yaw)
			local toCenterX = spawn.center[1] - station.position[1]
			local toCenterZ = spawn.center[3] - station.position[3]
			expect(fx * toCenterX + fz * toCenterZ > 0).toBe(true)
		end
	end)

	it("keeps the reserved spots free of trees, deco and other stands", function()
		for _, name in RESERVED do
			local station = spawn.stations[name]
			local clear = station.clear :: number
			for _, spec in spawn.parts do
				if isProp(spec) or spec.role == "Board" or spec.role == "Fountain" then
					expect(distance(spec.cframe, station.position) - reach(spec) >= clear).toBe(true)
				end
			end
			for _, model in spawn.models do
				expect(distance(model.position, station.position) - model.width / 2 >= clear).toBe(true)
			end
			for other, otherStation in spawn.stations do
				if other ~= name then
					expect(distance(otherStation.position, station.position) >= clear).toBe(true)
				end
			end
		end
	end)

	it("puts the update board and the countdown beside the spawn, facing it", function()
		local at = spawn.stations.Spawn.position
		for _, name in { "UpdateBoard", "Countdown" } do
			local station = spawn.stations[name]
			expect(station ~= nil).toBe(true)
			expect(distance(station.position, at) < 20).toBe(true)
			local fx, fz = -math.sin(station.yaw), -math.cos(station.yaw)
			local toSpawnX, toSpawnZ = at[1] - station.position[1], at[3] - station.position[3]
			local len = math.sqrt(toSpawnX ^ 2 + toSpawnZ ^ 2)
			expect((fx * toSpawnX + fz * toSpawnZ) / len > 0.9).toBe(true)
		end
		local panels = {}
		for _, spec in spawn.parts do
			panels[spec.name] = spec.role
		end
		expect(panels.UpdateBoardPanel).toBe("UpdateBoard")
		expect(panels.UpdateBoardTitle).toBe("UpdateBoard")
		expect(panels.CountdownPanel).toBe("Countdown")
	end)

	it("has benches, lanterns and flowers", function()
		local count = { BenchSeat = 0, LanternLamp = 0, Flower = 0 }
		for _, spec in spawn.parts do
			if count[spec.name] ~= nil then
				count[spec.name] += 1
			elseif string.find(spec.name, "Flower", 1, true) then
				count.Flower += 1
			end
		end
		expect(count.BenchSeat >= 4).toBe(true)
		expect(count.LanternLamp >= 4).toBe(true)
		expect(count.Flower >= 20).toBe(true)
	end)

	it("keeps solid props off the paths and off the spawn pad", function()
		local paths = {}
		for _, spec in spawn.parts do
			if spec.role == "Path" then
				table.insert(paths, spec)
			end
		end
		local pad = spawn.stations.Spawn.position
		for _, spec in spawn.parts do
			if isProp(spec) and spec.collide then
				local x, z = spec.cframe[1], spec.cframe[3]
				for _, path in paths do
					expect(onTop(path, x, z, 0)).toBe(false)
				end
				-- The SpawnLocation is 12 x 12 studs.
				expect(math.abs(x - pad[1]) > 6 or math.abs(z - pad[3]) > 6).toBe(true)
			end
		end
	end)

	it("keeps props and stands out of the fountain ring", function()
		local f = spawn.stations.Fountain.position
		for _, spec in spawn.parts do
			if isProp(spec) and spec.collide then
				-- Ring path: radius 15, 5.5 studs wide.
				expect(distance(spec.cframe, f) - reach(spec) > 17.75).toBe(true)
			end
		end
	end)

	it("keeps glowing lights few (each lamp has a light)", function()
		local lights = 0
		for _, spec in spawn.parts do
			if spec.role == "Glow" and spec.material == "Neon" then
				lights += 1
			end
		end
		expect(lights <= 6).toBe(true)
	end)

	it("stays within the part budget", function()
		expect(#spawn.parts + #spawn.models <= cfg.spawnPartBudget).toBe(true)
	end)
end)
