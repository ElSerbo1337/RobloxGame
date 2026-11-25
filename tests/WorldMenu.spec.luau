local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")
local WorldPreview = require("../src/shared/WorldPreview")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- Test config plus a world behind 2 rebirths (#77) and one without anything but its
-- config entry (like worlds 8-15 before their models exist).
local config = table.clone(TestConfig)
config.worlds = table.clone(TestConfig.worlds)
table.insert(config.worlds, {
	id = "Volcano",
	displayName = "Vulkan",
	unlockPrice = 5000000,
	requiredRebirths = 2,
	toppingSpawns = {},
})
table.insert(config.worlds, {
	id = "Atlantis",
	displayName = "Atlantis",
	unlockPrice = 9000000,
	requiredRebirths = 2,
	toppingSpawns = {},
})

local rules = GameRules.new(config)

local function entryFor(entries: { GameRules.PortalEntry }, worldId: string): GameRules.PortalEntry
	for _, entry in entries do
		if entry.worldId == worldId then
			return entry
		end
	end
	error(`no entry for {worldId}`)
end

local function player(coins: number, rebirths: number, unlocked: { string })
	local state = rules.newPlayerState()
	state.coins = coins
	state.rebirths = rebirths
	state.unlockedWorlds = unlocked
	return state
end

describe("world menu: cards for every world (#78)", function()
	it("lists every configured world in order with its number", function()
		local entries = rules.portalMenu(rules.newPlayerState())

		expect(#entries).toBe(#config.worlds)
		for index, entry in entries do
			expect(entry.worldId).toBe(config.worlds[index].id)
			expect(entry.index).toBe(index)
		end
	end)

	it("needs nothing for unlocked worlds", function()
		local entry = entryFor(rules.portalMenu(rules.newPlayerState()), "PizzeriaGarden")

		expect(entry.unlocked).toBe(true)
		expect(entry.canUnlock).toBe(false)
		expect(#entry.missing).toBe(0)
	end)

	it("shows the missing coins of the next world", function()
		local entry = entryFor(rules.portalMenu(player(400, 0, {})), "Farm")

		expect(entry.unlocked).toBe(false)
		expect(entry.canUnlock).toBe(false)
		expect(entry.missing).toEqual({ { kind = "Coins", amount = 1100 } })
	end)

	it("marks a world that can be bought at its gate right now", function()
		local entry = entryFor(rules.portalMenu(player(1500, 0, {})), "Farm")

		expect(entry.canUnlock).toBe(true)
		expect(#entry.missing).toBe(0)
	end)

	it("lists the previous world first when it is still locked", function()
		local entry = entryFor(rules.portalMenu(player(20000, 0, {})), "Beach")

		expect(entry.canUnlock).toBe(false)
		expect(entry.missing).toEqual({ { kind = "PreviousWorld", worldId = "Farm" } })
	end)

	it('shows missing rebirths and coins together ("2 Rebirths, 5 Mio")', function()
		local entry = entryFor(rules.portalMenu(player(0, 0, { "Farm", "Beach" })), "Volcano")

		expect(entry.missing).toEqual({
			{ kind = "Rebirths", amount = 2 },
			{ kind = "Coins", amount = 5000000 },
		})
	end)

	it("counts only the rebirths still missing", function()
		local entry = entryFor(rules.portalMenu(player(5000000, 1, { "Farm", "Beach" })), "Volcano")

		expect(entry.missing).toEqual({ { kind = "Rebirths", amount = 1 } })
		expect(entry.canUnlock).toBe(false)
	end)

	it("matches what unlockWorld says", function()
		local cases = {
			player(0, 0, {}),
			player(1500, 0, {}),
			player(20000, 0, { "Farm" }),
			player(5000000, 2, { "Farm", "Beach" }),
			player(5000000, 1, { "Farm", "Beach" }),
			player(100, 3, { "Farm", "Beach", "Volcano" }),
		}
		for _, state in cases do
			for _, entry in rules.portalMenu(state) do
				if not entry.unlocked then
					expect(entry.canUnlock).toBe(rules.unlockWorld(state, entry.worldId).ok)
				end
			end
		end
	end)
end)

describe("world menu: 3D preview (#78)", function()
	local themes = {
		Farm = { grass = { 124, 196, 76 }, cliff = { 176, 124, 82 }, landmark = "Windmill" },
	}

	it("uses the theme's colours and landmark", function()
		local preview = WorldPreview.forWorld({ id = "Farm", color = { 200, 100, 50 } }, themes)

		expect(preview.ground).toEqual({ 124, 196, 76 })
		expect(preview.cliff).toEqual({ 176, 124, 82 })
		expect(preview.landmark).toBe("Windmill")
		expect(preview.accent).toEqual({ 200, 100, 50 })
	end)

	it("falls back to the world colour for worlds without a theme or models", function()
		local preview = WorldPreview.forWorld({ id = "Atlantis", color = { 40, 120, 220 } }, themes)

		expect(preview.landmark).toBe(nil)
		expect(preview.accent).toEqual({ 40, 120, 220 })
		expect(#preview.ground).toBe(3)
		expect(#preview.cliff).toBe(3)
	end)

	it("still gives colours when the world has none", function()
		local preview = WorldPreview.forWorld({ id = "Unknown" }, nil)

		expect(#preview.accent).toBe(3)
		expect(#preview.ground).toBe(3)
	end)
end)

describe("world menu with the real config (#78)", function()
	local GameConfig = require("../src/shared/GameConfig")
	local realRules = GameRules.new(GameConfig)

	it("has a card with preview colours for every configured world", function()
		local entries = realRules.portalMenu(realRules.newPlayerState())

		expect(#entries).toBe(#GameConfig.worlds)
		for index, world in GameConfig.worlds do
			expect(entries[index].worldId).toBe(world.id)
			local preview = WorldPreview.forWorld(world, GameConfig.islands.themes)
			expect(#preview.ground).toBe(3)
			expect(#preview.cliff).toBe(3)
			expect(#preview.accent).toBe(3)
		end
	end)

	it("explains every locked world of a fresh player", function()
		for _, entry in realRules.portalMenu(realRules.newPlayerState()) do
			if not entry.unlocked then
				expect(entry.canUnlock or #entry.missing > 0).toBe(true)
			end
		end
	end)
end)
