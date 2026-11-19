local TestKit = require("./TestKit")
local MenuSwitch = require("../src/shared/MenuSwitch")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- A switch with menus whose close calls are recorded.
local function setup(ids: { string })
	local switch = MenuSwitch.new()
	local closed: { string } = {}
	for _, id in ids do
		switch.register(id, function()
			table.insert(closed, id)
		end)
	end
	return switch, closed
end

describe("MenuSwitch", function()
	it("closes nothing when the first menu opens", function()
		local switch, closed = setup({ "shop", "pets" })
		switch.opened("shop")
		expect(closed).toEqual({})
	end)

	it("closes the open menu when another one opens", function()
		local switch, closed = setup({ "shop", "pets", "potions" })
		switch.opened("shop")
		switch.opened("pets")
		expect(closed).toEqual({ "shop" })
	end)

	it("closes every other open menu, but only once", function()
		local switch, closed = setup({ "shop", "pets", "potions" })
		switch.opened("shop")
		switch.opened("pets")
		switch.opened("potions")
		switch.opened("potions")
		expect(closed).toEqual({ "shop", "pets" })
	end)

	it("never closes the menu that just opened", function()
		local switch, closed = setup({ "shop", "pets" })
		switch.opened("pets")
		switch.opened("pets")
		expect(closed).toEqual({})
	end)

	it("lets a menu register later (e.g. the egg preview)", function()
		local switch, closed = setup({ "shop" })
		switch.opened("shop")
		switch.register("eggPreview", function()
			table.insert(closed, "eggPreview")
		end)
		switch.opened("eggPreview")
		switch.opened("shop")
		expect(closed).toEqual({ "shop", "eggPreview" })
	end)
end)
