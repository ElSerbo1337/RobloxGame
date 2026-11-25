-- Scripted decoration of the new worlds (#82, islands.themes[id].deco): built from kits
-- in IslandPlan, within the part budget, clear of everything the game uses, optional
-- bits marked for graphics "Low" (#76).
local TestKit = require("./TestKit")
local GameConfig = require("../src/shared/GameConfig")
local IslandPlan = require("../src/shared/IslandPlan")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local cfg = GameConfig.islands
local plan = IslandPlan.new(cfg, GameConfig.worlds)

local function indexOf(id: string): number
	for index, world in GameConfig.worlds do
		if world.id == id then
			return index
		end
	end
	error(`no world {id}`)
end

local function decoParts(index: number): { IslandPlan.PartSpec }
	local list = {}
	for _, spec in plan.worldIsland(index).parts do
		if spec.deco then
			table.insert(list, spec)
		end
	end
	return list
end

describe("scripted world deco (#82)", function()
	local atlantis = indexOf("Atlantis")

	it("gives Atlantis corals, ruin columns, kelp, bubble vents and blue lamps", function()
		local roles = {}
		for _, spec in decoParts(atlantis) do
			roles[spec.role or ""] = (roles[spec.role or ""] or 0) + 1
		end
		expect((roles.Coral or 0) > 60).toBe(true)
		expect((roles.Ruin or 0) >= 20).toBe(true)
		expect((roles.Kelp or 0) > 40).toBe(true)
		expect((roles.Bubbles or 0) >= 6).toBe(true)
		expect((roles.Glow or 0) >= 3).toBe(true)
	end)

	it("stays within the part budget of every themed world (~400 parts)", function()
		for index, world in GameConfig.worlds do
			local theme = cfg.themes[world.id]
			local deco = theme and theme.deco
			local count = #decoParts(index)
			if deco then
				expect(deco.budget <= 400).toBe(true)
				expect(count <= deco.budget).toBe(true)
				-- Most of the budget is used: the island looks full.
				expect(count >= deco.budget * 0.75).toBe(true)
			else
				expect(count).toBe(0)
			end
		end
	end)

	it("keeps the deco on the island and clear of the stations, field and main path", function()
		local island = plan.worldIsland(atlantis)
		local center = island.center
		local field = island.field :: any
		for _, spec in decoParts(atlantis) do
			local x, z = spec.cframe[1], spec.cframe[3]
			expect(IslandPlan.isInsideOutline(island.outline, x, z)).toBe(true)
			local inField = math.abs(x - field.center[1]) < field.size[1] / 2
				and math.abs(z - field.center[3]) < field.size[2] / 2
			expect(inField).toBe(false)
			expect(math.abs(x - center[1]) < cfg.pathWidth / 2).toBe(false)
			for name, station in island.stations do
				if name ~= "Landmark" then
					local p = station.position
					expect(math.sqrt((x - p[1]) ^ 2 + (z - p[3]) ^ 2) > 8).toBe(true)
				end
			end
		end
	end)

	it("marks optional bits as detail (hidden on Low) and lets them never collide", function()
		local details = 0
		for _, spec in decoParts(atlantis) do
			if spec.detail then
				details += 1
				expect(spec.collide).toBe(false)
			end
		end
		expect(details > 30).toBe(true)
	end)

	it("lets only the standing ruins collide, and makes the bubble vents invisible", function()
		for _, spec in decoParts(atlantis) do
			if spec.collide then
				expect(spec.role == "Ruin" or spec.role == "Lamp").toBe(true)
			end
			if spec.role == "Bubbles" then
				expect(spec.transparency).toBe(1)
				expect(spec.collide).toBe(false)
			end
		end
	end)

	it("builds the same deco every time (deterministic)", function()
		local again = IslandPlan.new(cfg, GameConfig.worlds).worldIsland(atlantis)
		local first = plan.worldIsland(atlantis)
		expect(#again.parts).toBe(#first.parts)
		for i, spec in first.parts do
			expect(again.parts[i].cframe).toEqual(spec.cframe)
		end
	end)

	it("puts a sunken temple with a glowing pearl on the landmark terrace", function()
		local found = {}
		for _, spec in plan.worldIsland(atlantis).parts do
			found[spec.name] = true
		end
		expect(found.TemplePearl and found.TempleColumn and found.TempleClam).toBe(true)
	end)

	it("knows no deco kit names that the plan cannot build", function()
		local KITS = {
			Coral = true,
			Column = true,
			Kelp = true,
			Bubbles = true,
			Lamp = true,
			JungleTree = true,
			Fern = true,
			Idol = true,
			Fireflies = true,
			Mist = true,
		}
		for _, theme in cfg.themes do
			for _, item in (theme.deco and theme.deco.kits) or {} do
				expect(KITS[item.kit]).toBe(true)
				expect(item.count > 0 and item.size[1] <= item.size[2]).toBe(true)
			end
		end
	end)
end)

describe("jungle temple deco (#83)", function()
	local jungle = indexOf("JungleTemple")
	local island = plan.worldIsland(jungle)

	it("gives the jungle trees with lianas, ferns, ruins and idols, fireflies and mist", function()
		local roles, names = {}, {}
		for _, spec in decoParts(jungle) do
			roles[spec.role or ""] = (roles[spec.role or ""] or 0) + 1
			names[spec.name] = (names[spec.name] or 0) + 1
		end
		expect((names.JungleTrunk or 0) >= 12).toBe(true)
		expect((roles.Liana or 0) >= 24).toBe(true)
		expect((roles.Fern or 0) >= 80).toBe(true)
		expect((names.IdolHead or 0) >= 3).toBe(true)
		expect((roles.Fireflies or 0) >= 6).toBe(true)
		expect((roles.Mist or 0) >= 5).toBe(true)
	end)

	it("keeps the jungle deco on the island and off the field and the main path", function()
		local field = island.field :: any
		for _, spec in decoParts(jungle) do
			local x, z = spec.cframe[1], spec.cframe[3]
			expect(IslandPlan.isInsideOutline(island.outline, x, z)).toBe(true)
			local inField = math.abs(x - field.center[1]) < field.size[1] / 2
				and math.abs(z - field.center[3]) < field.size[2] / 2
			expect(inField).toBe(false)
			expect(math.abs(x - island.center[1]) < cfg.pathWidth / 2).toBe(false)
		end
	end)

	it("lets only trunks, standing ruins, idols and lamps collide; emitters are invisible", function()
		for _, spec in decoParts(jungle) do
			if spec.collide then
				expect(spec.name == "JungleTrunk" or spec.role == "Ruin" or spec.role == "Lamp").toBe(true)
			end
			if spec.role == "Fireflies" or spec.role == "Mist" then
				expect(spec.transparency).toBe(1)
				expect(spec.collide).toBe(false)
			end
			if spec.role == "Liana" then
				expect(spec.detail).toBe(true)
			end
		end
	end)

	it("builds a stepped temple with a stair and a glowing jade gem on the landmark terrace", function()
		local found = {}
		for _, spec in island.parts do
			found[spec.name] = (found[spec.name] or 0) + 1
		end
		expect(found.TempleTier).toBe(3)
		expect((found.TempleStair or 0) >= 4).toBe(true)
		expect(found.JadeGem).toBe(1)
		expect((found.TempleLiana or 0) >= 4).toBe(true)
	end)

	it("keeps a spot for the hidden chest (#100) behind the temple, on the terrace, free of deco", function()
		local chest = island.stations.SecretChest
		expect(chest ~= nil).toBe(true)
		local landmark = island.stations.Landmark.position
		local p = chest.position
		expect(chest.clear ~= nil and chest.clear >= 4).toBe(true)
		-- Behind the temple as seen from the main path (path at the island's middle x).
		expect(math.abs(p[1] - island.center[1]) > math.abs(landmark[1] - island.center[1]) + 8).toBe(true)
		-- On the terrace top, not under it.
		local terrace = cfg.layout.terraces[1]
		expect(p[2]).toBe(landmark[2] + terrace[4])
		expect(IslandPlan.isInsideOutline(island.outline, p[1], p[3])).toBe(true)
		for _, spec in decoParts(jungle) do
			local d = math.sqrt((spec.cframe[1] - p[1]) ^ 2 + (spec.cframe[3] - p[3]) ^ 2)
			expect(d > chest.clear).toBe(true)
		end
		-- No temple part stands on the chest spot.
		for _, spec in island.parts do
			if spec.role == "Landmark" and spec.collide then
				local dx, dz = math.abs(spec.cframe[1] - p[1]), math.abs(spec.cframe[3] - p[3])
				expect(dx < spec.size[1] / 2 and dz < spec.size[3] / 2).toBe(false)
			end
		end
	end)

	it("gives only the jungle a chest spot so far", function()
		for index, world in GameConfig.worlds do
			local theme = cfg.themes[world.id]
			local has = plan.worldIsland(index).stations.SecretChest ~= nil
			expect(has).toBe(theme ~= nil and theme.secretChest ~= nil)
		end
	end)
end)
