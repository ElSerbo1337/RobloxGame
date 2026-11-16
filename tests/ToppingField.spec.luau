local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local ToppingField = require("../src/shared/ToppingField")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function newField(random: (() -> number)?)
	return ToppingField.new(TestConfig, "PizzeriaGarden", random or TestKit.sequenceRandom({ 0 }))
end

describe("ToppingField", function()
	it("spawns the configured number of toppings", function()
		local field = newField()

		local present = 0
		for slotId = 1, field.slotCount do
			if field:get(slotId) then
				present += 1
			end
		end
		expect(field.slotCount).toBe(4)
		expect(present).toBe(4)
	end)

	it("picks topping kinds by spawn weight (Salami 6, Mushroom 3, Mozzarella 1)", function()
		-- Each spawn draws: kind roll, x, z. Weights total 10, so the kind roll maps
		-- [0, 0.6) -> Salami, [0.6, 0.9) -> Mushroom, [0.9, 1) -> Mozzarella.
		local rolls = {}
		for _, spawn in
			{
				{ 0.59, 0.1, 0.2 }, -- slot 1
				{ 0.6, 0.3, 0.4 }, -- slot 2
				{ 0.89, 0.5, 0.6 }, -- slot 3
				{ 0.95, 0.7, 0.8 }, -- slot 4
			}
		do
			table.move(spawn, 1, 3, #rolls + 1, rolls)
		end
		local field = newField(TestKit.sequenceRandom(rolls))

		expect(field:get(1)).toEqual({ toppingId = "Salami", x = 0.1, z = 0.2 })
		expect(field:get(2)).toEqual({ toppingId = "Mushroom", x = 0.3, z = 0.4 })
		expect(field:get(3)).toEqual({ toppingId = "Mushroom", x = 0.5, z = 0.6 })
		expect(field:get(4)).toEqual({ toppingId = "Mozzarella", x = 0.7, z = 0.8 })
	end)

	it("lets a topping be taken only once", function()
		local field = newField()

		expect(field:take(2, 100)).toBe(true)
		expect(field:take(2, 100)).toBe(false)
		expect(field:get(2)).toBeNil()
	end)

	it("respawns a taken topping at a new random spot after the respawn delay", function()
		local rolls = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } -- initial 4 spawns
		for _, value in { 0.95, 0.25, 0.75 } do -- respawn: Mozzarella at (0.25, 0.75)
			table.insert(rolls, value)
		end
		local field = newField(TestKit.sequenceRandom(rolls))
		field:take(3, 100)

		expect(field:respawnDue(104.9)).toEqual({})
		expect(field:get(3)).toBeNil()

		expect(field:respawnDue(105)).toEqual({ 3 })
		expect(field:get(3)).toEqual({ toppingId = "Mozzarella", x = 0.25, z = 0.75 })

		expect(field:respawnDue(200)).toEqual({})
	end)

	it("refuses to take a slot that does not exist", function()
		expect(newField():take(99, 0)).toBe(false)
	end)
end)
