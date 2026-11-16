local TestKit = require("./TestKit")
local GameConfig = require("../src/shared/GameConfig")
local GameRules = require("../src/shared/GameRules")
local ToppingField = require("../src/shared/ToppingField")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("GameConfig", function()
	it("starts world 1 (Pizzeria-Garten) with 60 toppings, respawning after 5 seconds", function()
		local field = ToppingField.new(GameConfig, "PizzeriaGarden", TestKit.sequenceRandom({ 0.5 }))

		expect(field.slotCount).toBe(60)
		expect(GameConfig.toppingField.respawnSeconds).toBe(5)
	end)

	it("starts players with a pizza of 2 and a collect range of 10 studs", function()
		local rules = GameRules.new(GameConfig)
		local state = rules.newPlayerState()

		expect(rules.pizzaCapacity(state)).toBe(2)
		expect(rules.collectRange(state)).toBe(10)
	end)

	it("only spawns toppings that exist in the topping list", function()
		for _, world in GameConfig.worlds do
			for _, spawn in world.toppingSpawns do
				expect(GameConfig.toppings[spawn.topping] ~= nil).toBe(true)
			end
		end
	end)

	it("makes rarer toppings in a world worth more", function()
		for _, world in GameConfig.worlds do
			local spawns = table.clone(world.toppingSpawns)
			table.sort(spawns, function(a, b)
				return a.weight > b.weight
			end)
			for i = 2, #spawns do
				local commoner = GameConfig.toppings[spawns[i - 1].topping].value
				local rarer = GameConfig.toppings[spawns[i].topping].value
				expect(rarer > commoner).toBe(true)
			end
		end
	end)
end)
