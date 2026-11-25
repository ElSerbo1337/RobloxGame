-- World intro (#79): the first time a player enters a world, the server marks it as seen
-- and the client plays a short camera flight with the world name and the toppings that
-- are new in this world. Once per player and world, saved, kept on rebirth.
local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameConfig = require("../src/shared/GameConfig")
local GameRules = require("../src/shared/GameRules")
local SaveData = require("../src/shared/SaveData")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local rules = GameRules.new(TestConfig)

local function withWorlds(...: string)
	local state = rules.newPlayerState()
	state.unlockedWorlds = { ... }
	return state
end

-- Config whose third world reuses a topping of world 1 next to a new one.
local function reuseConfig(features: { [string]: boolean }?)
	local config = table.clone(TestConfig)
	config.features = features
	config.worlds = table.clone(TestConfig.worlds)
	config.worlds[3] = table.clone(TestConfig.worlds[3])
	config.worlds[3].toppingSpawns = {
		{ topping = "Salami", weight = 5 },
		{ topping = "Mozzarella", weight = 1 },
		{ topping = "Ham", weight = 2 },
	}
	config.toppings = table.clone(TestConfig.toppings)
	config.toppings.Mozzarella = table.clone(TestConfig.toppings.Mozzarella)
	return config
end

describe("world intro: when it plays", function()
	it("plays on the first entry of an unlocked world and remembers that world", function()
		local state = withWorlds("Farm")

		local result = rules.enterWorld(state, "Farm")

		expect(result.ok).toBe(true)
		expect(result.intro).toBe(true)
		expect(rules.hasSeenWorldIntro(result.state, "Farm")).toBe(true)
		expect(rules.hasSeenWorldIntro(state, "Farm")).toBe(false)
	end)

	it("does not play a second time, also after leaving and coming back", function()
		local first = rules.enterWorld(withWorlds("Farm"), "Farm").state
		local away = rules.enterWorld(first, "PizzeriaGarden").state

		local again = rules.enterWorld(away, "Farm")

		expect(again.ok).toBe(true)
		expect(again.intro).toBe(nil)
		expect(again.state.seenWorldIntros).toEqual({ "Farm" })
	end)

	it("does not play again after saving and loading (rejoin)", function()
		local seen = rules.enterWorld(withWorlds("Farm"), "Farm").state
		-- A save is a plain copy of the state (DataStore stores tables).
		local loaded = SaveData.load(table.clone(seen), rules.newPlayerState())

		expect(rules.enterWorld(loaded.state, "Farm").intro).toBe(nil)
	end)

	it("plays when the world is the respawn world but its intro was never seen (older saves)", function()
		local state = withWorlds("Farm")
		state.lastWorldId = "Farm"

		local result = rules.enterWorld(state, "Farm")

		expect(result.intro).toBe(true)
		expect(result.state.lastWorldId).toBe("Farm")
	end)

	it("keeps the seen intros on a rebirth, so a world never plays twice", function()
		local state = rules.enterWorld(withWorlds("Farm"), "Farm").state
		state.coins = 1e12

		local reborn = rules.rebirth(state, 0).state

		expect(reborn.unlockedWorlds).toEqual({})
		expect(rules.hasSeenWorldIntro(reborn, "Farm")).toBe(true)
	end)

	it("never plays in the start world (open from the beginning, the tutorial runs there)", function()
		local result = rules.enterWorld(rules.newPlayerState(), "PizzeriaGarden")

		expect(result.ok).toBe(true)
		expect(result.intro).toBe(nil)
		expect(rules.hasWorldIntro("PizzeriaGarden")).toBe(false)
		expect(rules.hasWorldIntro("Farm")).toBe(true)
	end)

	it("never plays for locked or unknown worlds", function()
		expect(rules.enterWorld(rules.newPlayerState(), "Farm").ok).toBe(false)
		expect(rules.enterWorld(rules.newPlayerState(), "Moon").ok).toBe(false)
		expect(rules.hasWorldIntro("Moon")).toBe(false)
	end)

	it("plays nothing and remembers nothing while the worldIntro switch is off", function()
		local off = GameRules.new(reuseConfig({ worldIntro = false }))
		local state = off.newPlayerState()
		state.unlockedWorlds = { "Farm" }

		local result = off.enterWorld(state, "Farm")

		expect(result.ok).toBe(true)
		expect(result.intro).toBe(nil)
		expect(result.state.seenWorldIntros).toEqual({})
		expect(off.hasWorldIntro("Farm")).toBe(false)
	end)
end)

describe("world intro: what it shows", function()
	it("lists the toppings of the world in spawn order", function()
		expect(rules.newToppingsOf("Farm")).toEqual({ "Onion", "Ham" })
		expect(rules.newToppingsOf("PizzeriaGarden")).toEqual({ "Salami", "Mushroom", "Mozzarella" })
	end)

	it("leaves out toppings an earlier world already has", function()
		local reuse = GameRules.new(reuseConfig())

		expect(reuse.newToppingsOf("Beach")).toEqual({})
		expect(reuse.newToppingsOf("Farm")).toEqual({ "Onion", "Ham" })
	end)

	it("returns an empty list for worlds without toppings and unknown worlds", function()
		expect(rules.newToppingsOf("Beach")).toEqual({})
		expect(rules.newToppingsOf("Moon")).toEqual({})
	end)
end)

describe("world intro: real configuration", function()
	local real = GameRules.new(GameConfig)

	it("is switchable and has a 3-4 second flight", function()
		expect(GameConfig.features.worldIntro ~= nil).toBe(true)
		expect(GameConfig.worldIntro.seconds >= 3 and GameConfig.worldIntro.seconds <= 4).toBe(true)
	end)

	it("plays in every world after the first and shows at least one new topping there", function()
		for index, world in GameConfig.worlds do
			if index > 1 then
				expect(real.hasWorldIntro(world.id)).toBe(true)
				expect(#real.newToppingsOf(world.id) > 0).toBe(true)
			end
		end
	end)

	it("only shows toppings that exist in the config with German and English names", function()
		for _, world in GameConfig.worlds do
			for _, toppingId in real.newToppingsOf(world.id) do
				local topping = GameConfig.toppings[toppingId]
				expect(topping ~= nil).toBe(true)
				expect(type(topping.displayName)).toBe("string")
				expect(type(topping.displayNameEn)).toBe("string")
			end
		end
	end)
end)
