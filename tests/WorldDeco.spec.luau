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
			Dune = true,
			Pyramid = true,
			Oasis = true,
			Cactus = true,
			SpookyTree = true,
			Pumpkin = true,
			Bats = true,
			Lantern = true,
			FlowerBed = true,
			FenceRow = true,
			HayStack = true,
			Shell = true,
			Driftwood = true,
			Starfish = true,
			IceSpike = true,
			SnowPile = true,
			BasaltCluster = true,
			Lolli = true,
			CandyStick = true,
			Gumdrop = true,
			Crystal = true,
			Crater = true,
			Snowfall = true,
			Embers = true,
			Stars = true,
		}
		for _, theme in cfg.themes do
			for _, item in (theme.deco and theme.deco.kits) or {} do
				expect(KITS[item.kit]).toBe(true)
				expect(item.count > 0 and item.size[1] <= item.size[2]).toBe(true)
			end
		end
	end)

	local desert = indexOf("DesertPyramids")

	it("gives the Desert Pyramids dunes, small pyramids, oases with palms and cacti (#84)", function()
		local roles = {}
		for _, spec in decoParts(desert) do
			roles[spec.role or ""] = (roles[spec.role or ""] or 0) + 1
		end
		expect((roles.Dune or 0) >= 40).toBe(true)
		expect((roles.Pyramid or 0) >= 20).toBe(true)
		expect((roles.Oasis or 0) >= 20).toBe(true)
		expect((roles.Cactus or 0) >= 60).toBe(true)
	end)

	it("keeps the desert deco on the island, clear of the field and path, with detail never colliding (#84)", function()
		local island = plan.worldIsland(desert)
		local center = island.center
		local field = island.field :: any
		local details = 0
		for _, spec in decoParts(desert) do
			local x, z = spec.cframe[1], spec.cframe[3]
			expect(IslandPlan.isInsideOutline(island.outline, x, z)).toBe(true)
			local inField = math.abs(x - field.center[1]) < field.size[1] / 2
				and math.abs(z - field.center[3]) < field.size[2] / 2
			expect(inField).toBe(false)
			expect(math.abs(x - center[1]) < cfg.pathWidth / 2).toBe(false)
			if spec.detail then
				details += 1
				expect(spec.collide).toBe(false)
			end
			-- Oasis water and palm leaves never block the way.
			if spec.name == "OasisWater" or spec.name == "PalmLeaf" or spec.name == "OasisShore" then
				expect(spec.collide).toBe(false)
			end
		end
		expect(details > 20).toBe(true)
	end)

	it("puts a step pyramid with a glowing capstone and obelisks on the landmark terrace (#84)", function()
		local found = {}
		for _, spec in plan.worldIsland(desert).parts do
			found[spec.name] = (found[spec.name] or 0) + 1
		end
		expect(found.PyramidTier).toBe(5)
		expect(found.PyramidCapstone).toBe(1)
		expect(found.Obelisk).toBe(2)
		expect((found.Sandstone or 0) > 20).toBe(true)
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

	it("gives a chest spot exactly to the worlds whose theme has one (#83, #85)", function()
		for index, world in GameConfig.worlds do
			local theme = cfg.themes[world.id]
			local has = plan.worldIsland(index).stations.SecretChest ~= nil
			expect(has).toBe(theme ~= nil and theme.secretChest ~= nil)
		end
	end)
end)

describe("haunted castle deco (#85)", function()
	local castle = indexOf("HauntedCastle")
	local island = plan.worldIsland(castle)

	it("gives the castle spooky trees, pumpkins (some with faces), ruins, bats, mist and lanterns", function()
		local roles, names = {}, {}
		for _, spec in decoParts(castle) do
			roles[spec.role or ""] = (roles[spec.role or ""] or 0) + 1
			names[spec.name] = (names[spec.name] or 0) + 1
		end
		expect((names.SpookyTrunk or 0) >= 10).toBe(true)
		expect((names.PumpkinBody or 0) >= 24).toBe(true)
		expect((names.PumpkinMouth or 0) >= 6).toBe(true)
		expect((names.Bat or 0) >= 12).toBe(true)
		expect((names.SleepingBat or 0) >= 2).toBe(true)
		expect((roles.Mist or 0) >= 5).toBe(true)
		expect((roles.Ruin or 0) >= 8).toBe(true)
		expect((roles.Glow or 0) >= 3).toBe(true)
	end)

	it("keeps the castle deco on the island and off the field and the main path", function()
		local field = island.field :: any
		for _, spec in decoParts(castle) do
			local x, z = spec.cframe[1], spec.cframe[3]
			expect(IslandPlan.isInsideOutline(island.outline, x, z)).toBe(true)
			local inField = math.abs(x - field.center[1]) < field.size[1] / 2
				and math.abs(z - field.center[3]) < field.size[2] / 2
			expect(inField).toBe(false)
			expect(math.abs(x - island.center[1]) < cfg.pathWidth / 2).toBe(false)
		end
	end)

	it("lets only trunks, pumpkins, standing ruins and lamps collide; bats fly high and never collide", function()
		for _, spec in decoParts(castle) do
			if spec.collide then
				local ok = spec.name == "SpookyTrunk"
					or spec.name == "PumpkinBody"
					or spec.role == "Ruin"
					or spec.role == "Lamp"
				expect(ok).toBe(true)
			end
			if spec.role == "Bat" then
				expect(spec.collide).toBe(false)
			end
			if spec.name == "Bat" then
				expect(spec.cframe[2] > cfg.groundY + 10).toBe(true)
			end
			if spec.material == "Neon" and spec.role ~= "Glow" then
				expect(spec.detail).toBe(true)
			end
		end
	end)

	it("builds a castle with a keep, four towers and a middle tower, a gate lantern and a ghost", function()
		local found = {}
		for _, spec in island.parts do
			found[spec.name] = (found[spec.name] or 0) + 1
		end
		expect(found.CastleKeep).toBe(1)
		expect(found.CastleTower).toBe(5)
		expect(found.CastleRoof).toBe(15)
		expect(found.CastleLantern).toBe(1)
		expect(found.CastleGhost).toBe(1)
		expect((found.CastleWindow or 0) >= 6).toBe(true)
		expect((found.CastleMerlon or 0) >= 12).toBe(true)
		expect((found.FencePillar or 0) >= 10).toBe(true)
		expect((found.FencePumpkin or 0) >= 3).toBe(true)
	end)

	it("keeps a spot for the hidden chest (#100) behind the castle, on the terrace, free of deco", function()
		local chest = island.stations.SecretChest
		expect(chest ~= nil).toBe(true)
		local landmark = island.stations.Landmark.position
		local p = chest.position
		expect(math.abs(p[1] - island.center[1]) > math.abs(landmark[1] - island.center[1]) + 8).toBe(true)
		expect(p[2]).toBe(landmark[2] + cfg.layout.terraces[1][4])
		for _, spec in decoParts(castle) do
			local d = math.sqrt((spec.cframe[1] - p[1]) ^ 2 + (spec.cframe[3] - p[3]) ^ 2)
			expect(d > chest.clear).toBe(true)
		end
		for _, spec in island.parts do
			if spec.role == "Landmark" and spec.collide then
				local dx, dz = math.abs(spec.cframe[1] - p[1]), math.abs(spec.cframe[3] - p[3])
				expect(dx < spec.size[1] / 2 + 1 and dz < spec.size[3] / 2 + 1).toBe(false)
			end
		end
	end)
end)

describe("environment upgrade of the first seven worlds (#104)", function()
	local EXPECTED = {
		PizzeriaGarden = { "Lantern", "FlowerBed", "Fireflies" },
		Farm = { "Fence", "Hay", "Lantern", "Fireflies" },
		Beach = { "Shell", "Driftwood", "Starfish" },
		Icebergs = { "IceSpike", "Snow", "Snowfall" },
		Volcano = { "Basalt", "Embers", "Mist" },
		CandyLand = { "Lolli", "CandyStick", "Gumdrop" },
		Space = { "Crystal", "Crater", "Stars" },
	}
	local EMITTERS = { Fireflies = true, Mist = true, Snowfall = true, Embers = true, Stars = true }

	for id, roles in EXPECTED do
		local index = indexOf(id)

		it(`gives {id} its themed kits (2-4) and particles within the budget`, function()
			local theme = cfg.themes[id]
			expect(theme.deco ~= nil).toBe(true)
			expect(#theme.deco.kits >= 2 and #theme.deco.kits <= 4).toBe(true)
			local found = {}
			for _, spec in decoParts(index) do
				found[spec.role or ""] = (found[spec.role or ""] or 0) + 1
			end
			for _, role in roles do
				expect((found[role] or 0) >= 1).toBe(true)
			end
			expect(#decoParts(index) <= 400).toBe(true)
		end)

		it(
			`keeps the {id} deco on the island, off field, path and stations; detail and emitters never collide`,
			function()
				local island = plan.worldIsland(index)
				local center = island.center
				local field = island.field :: any
				for _, spec in decoParts(index) do
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
					if spec.detail then
						expect(spec.collide).toBe(false)
					end
					if EMITTERS[spec.role or ""] then
						expect(spec.transparency).toBe(1)
						expect(spec.collide).toBe(false)
					end
				end
			end
		)

		it(`builds the same {id} deco every time (deterministic)`, function()
			local again = IslandPlan.new(cfg, GameConfig.worlds).worldIsland(index)
			local first = plan.worldIsland(index)
			expect(#again.parts).toBe(#first.parts)
			for i, spec in first.parts do
				expect(again.parts[i].cframe).toEqual(spec.cframe)
			end
		end)
	end

	it("marks lantern lamps as night lights (for the day/night cycle of #105), and only them", function()
		local lamps = 0
		for index = 1, 7 do
			for _, spec in decoParts(index) do
				if spec.night then
					lamps += 1
					expect(spec.name).toBe("LanternLamp")
					-- Not a detail part: the light stays on graphics "Low".
					expect(spec.detail ~= true).toBe(true)
				elseif spec.name == "LanternLamp" then
					error("lantern lamp without night flag")
				end
			end
		end
		expect(lamps >= 10).toBe(true)
	end)

	it("adds no extra always-on lights (role Glow) to the old worlds", function()
		for index = 1, 7 do
			for _, spec in decoParts(index) do
				expect(spec.role == "Glow").toBe(false)
			end
		end
	end)
end)
