local TestKit = require("./TestKit")
local GameConfig = require("../src/shared/GameConfig")
local IslandPlan = require("../src/shared/IslandPlan")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- The island plan with all 15 worlds of the MEGA UPDATE (#77): the real worlds plus
-- placeholders for the worlds of #82-#89 (config entry only, no island theme yet), and
-- one event island beside the spawn island.
local NEW_WORLDS = {
	"Atlantis",
	"JungleTemple",
	"DesertPyramids",
	"HauntedCastle",
	"DinoAge",
	"CrystalCave",
	"CloudCity",
	"PizzaParadise",
}

local worlds = table.clone(GameConfig.worlds)
for _, id in NEW_WORLDS do
	if #worlds >= 15 then
		break
	end
	local known = false
	for _, world in worlds do
		known = known or world.id == id
	end
	if not known then
		table.insert(worlds, { id = id, displayName = id, unlockPrice = 1, toppingSpawns = {}, eggs = {} })
	end
end

local cfg = GameConfig.islands
local half = cfg.worldHalfSize
local eventWorlds = { { id = "WinterIsland", displayName = "Winterinsel", currency = "Snowflakes" } }
local plan = IslandPlan.new(cfg, worlds, eventWorlds)

local function overlaps(a: { number }, b: { number }, gap: number): boolean
	return math.abs(a[1] - b[1]) < 2 * half + gap and math.abs(a[3] - b[3]) < 2 * half + gap
end

describe("island plan for 15 worlds (#77)", function()
	it("builds all 15 world islands, bridges and gates from config entries alone", function()
		expect(#worlds).toBe(15)
		for index = 1, 15 do
			local island = plan.worldIsland(index)
			expect(island.worldIndex).toBe(index)
			expect(#island.parts > 0).toBe(true)
			expect(island.stations.Oven ~= nil and island.stations.Portal ~= nil).toBe(true)
			if index >= 2 then
				expect(plan.gate(index).barrier ~= nil).toBe(true)
			end
		end
		expect(#plan.bridges()).toBe(15)
	end)

	it("opens the last world only towards the bridge it comes from", function()
		expect(plan.worldIsland(15).openings.back).toBe(nil)
		expect(plan.worldIsland(14).openings.back ~= nil).toBe(true)
	end)

	it("finds every one of the 15 worlds by position", function()
		for index = 1, 15 do
			local c = plan.worldCenter(index)
			expect(plan.worldIndexAt(c[1], c[3])).toBe(index)
		end
	end)
end)

describe("event islands (#77)", function()
	local spawn = plan.spawnIsland()
	local event = plan.eventIsland(1)

	it("puts the event island beside the spawn island at the same height", function()
		local c = plan.eventCenter(1)
		expect(c[2]).toBe(spawn.center[2])
		expect(c[3]).toBe(spawn.center[3])
		expect(c[1] - half > cfg.spawnRadius).toBe(true)
		expect(event.kind).toBe("event")
		expect(event.eventIndex).toBe(1)
	end)

	it("keeps it clear of the spawn island, every world and every bridge", function()
		local c = plan.eventCenter(1)
		expect(c[1] - half - (spawn.center[1] + cfg.spawnRadius) >= cfg.bridgeLength - 1e-6).toBe(true)
		for index = 1, 15 do
			expect(overlaps(c, plan.worldCenter(index), 10)).toBe(false)
		end
		for _, point in event.outline do
			expect(math.abs(point[1]) > cfg.bridgeWidth).toBe(true)
		end
	end)

	it("has no bridge openings: the rim is walled all round (the portal leads there)", function()
		expect(event.openings.front).toBe(nil)
		expect(event.openings.back).toBe(nil)
		local walls = 0
		for _, spec in event.parts do
			if spec.role == "Wall" then
				walls += 1
			end
		end
		expect(walls >= 4).toBe(true)
	end)

	it("has the stations of a world (spawn, oven, portal, shop, eggs)", function()
		for _, name in { "Spawn", "Oven", "Portal", "Shop", "Egg1", "Egg2" } do
			expect(event.stations[name] ~= nil).toBe(true)
		end
		expect(event.field ~= nil).toBe(true)
	end)

	it("finds the event island by position, and no world there", function()
		local c = plan.eventCenter(1)
		expect(plan.eventIndexAt(c[1], c[3])).toBe(1)
		expect(plan.worldIndexAt(c[1], c[3])).toBe(nil)
		expect(plan.eventIndexAt(0, 0)).toBe(nil)
	end)

	it("puts further event islands in a row, one island spacing apart", function()
		local first, second = plan.eventCenter(1), plan.eventCenter(2)
		expect(second[1] - first[1]).toBe(2 * half + cfg.bridgeLength)
	end)

	it("has no event islands without event worlds (the real config of this update)", function()
		local plain = IslandPlan.new(cfg, GameConfig.worlds, GameConfig.eventWorlds)
		local c = plain.eventCenter(1)
		expect(plain.eventIndexAt(c[1], c[3])).toBe(nil)
	end)
end)
