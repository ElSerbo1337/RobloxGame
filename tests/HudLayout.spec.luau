local TestKit = require("./TestKit")
local HudLayout = require("../src/shared/HudLayout")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

type Rect = HudLayout.Rect

-- Virtual GUI sizes (after UiKit.autoScale, below the Roblox top bar):
-- small phone, phone, laptop, tablet, full HD, 4K.
local SCREENS = {
	{ 950, 450 },
	{ 1100, 520 },
	{ 1157, 600 },
	{ 1100, 763 },
	{ 1371, 730 },
	{ 2743, 1500 },
}

local function overlaps(a: Rect, b: Rect): boolean
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

local function inside(inner: Rect, outer: Rect): boolean
	return inner.x >= outer.x - 0.001
		and inner.y >= outer.y - 0.001
		and inner.x + inner.w <= outer.x + outer.w + 0.001
		and inner.y + inner.h <= outer.y + outer.h + 0.001
end

local function forEachScreen(fn: (layout: HudLayout.Layout, label: string) -> ())
	for _, screen in SCREENS do
		fn(HudLayout.resolve(screen[1], screen[2]), `{screen[1]}x{screen[2]}`)
	end
end

local function fixedElements(layout: HudLayout.Layout): { [string]: Rect }
	local elements = {
		coins = layout.coins,
		gems = layout.gems,
		toast = layout.toast,
		tutorialCard = layout.tutorialCard,
		pizzaBar = layout.pizzaBar,
		autoCollect = layout.autoCollect,
		unlockButton = layout.unlockButton,
		rightColumn = layout.rightColumn,
	}
	for name, rect in layout.sideSlots do
		elements["side:" .. name] = rect
	end
	return elements
end

describe("HUD layout", function()
	it("keeps every HUD element on screen", function()
		forEachScreen(function(layout, label)
			local screen = { x = 0, y = 0, w = layout.screen.w, h = layout.screen.h }
			for name, rect in fixedElements(layout) do
				if not inside(rect, screen) then
					error(`{name} leaves the screen on {label}`)
				end
			end
		end)
	end)

	it("never lets two HUD elements overlap", function()
		forEachScreen(function(layout, label)
			local elements = fixedElements(layout)
			for nameA, a in elements do
				for nameB, b in elements do
					if nameA < nameB and overlaps(a, b) then
						error(`{nameA} overlaps {nameB} on {label}`)
					end
				end
			end
		end)
	end)

	it("puts no button into the phone joystick or jump button area", function()
		forEachScreen(function(layout, label)
			local buttons = { autoCollect = layout.autoCollect, unlockButton = layout.unlockButton }
			for name, rect in layout.sideSlots do
				buttons["side:" .. name] = rect
			end
			for name, rect in buttons do
				if overlaps(rect, layout.joystick) or overlaps(rect, layout.jump) then
					error(`{name} lies in the joystick/jump area on {label}`)
				end
			end
		end)
	end)

	it("keeps buttons at least thumb sized", function()
		forEachScreen(function(layout, label)
			local buttons = { autoCollect = layout.autoCollect, unlockButton = layout.unlockButton }
			for name, rect in layout.sideSlots do
				buttons["side:" .. name] = rect
			end
			for name, rect in buttons do
				if rect.w < HudLayout.MIN_TOUCH or rect.h < HudLayout.MIN_TOUCH then
					error(`{name} is smaller than a thumb on {label}`)
				end
			end
		end)
	end)

	it("places the unlock button right of the pizza bar, not on auto-collect", function()
		forEachScreen(function(layout)
			expect(layout.unlockButton.x >= layout.pizzaBar.x + layout.pizzaBar.w).toBe(true)
			expect(overlaps(layout.unlockButton, layout.autoCollect)).toBe(false)
		end)
	end)

	it("keeps the potion pills and the order card above the jump button", function()
		forEachScreen(function(layout)
			expect(overlaps(layout.rightColumn, layout.jump)).toBe(false)
		end)
	end)

	it("places the tutorial card top left, clear of messages", function()
		forEachScreen(function(layout)
			expect(layout.tutorialCard.x).toBe(HudLayout.MARGIN)
			expect(layout.tutorialCard.x + layout.tutorialCard.w <= layout.coins.x).toBe(true)
			expect(overlaps(layout.tutorialCard, layout.toast)).toBe(false)
		end)
	end)

	it("keeps the side buttons in slot order: pets, potions, gifts, rebirth", function()
		forEachScreen(function(layout)
			local slots = layout.sideSlots
			-- Column-wise: the next slot is below, or starts a new column further right.
			local order = { slots.pets, slots.potions, slots.gifts, slots.rebirth }
			for i = 2, #order do
				local before, after = order[i - 1], order[i]
				expect(after.y > before.y or after.x > before.x).toBe(true)
			end
		end)
	end)

	it("puts the side buttons below the chat: from half height down to the joystick", function()
		forEachScreen(function(layout, label)
			local area, h = layout.sideArea, layout.screen.h
			-- Half height, unless that leaves no room for one row of buttons.
			local top = math.min(h * 0.5, layout.joystick.y - HudLayout.SIDE_BUTTON)
			if area.y < top - 0.001 then
				error(`side area starts above half height on {label}`)
			end
			expect(area.y + area.h <= layout.joystick.y + 0.001).toBe(true)
			expect(area.y >= layout.tutorialCard.y + layout.tutorialCard.h).toBe(true)
		end)
	end)

	it("keeps all four side buttons inside the side area, wrapping into more columns", function()
		forEachScreen(function(layout, label)
			for _, name in HudLayout.SIDE_SLOTS do
				local slot = layout.sideSlots[name]
				if not inside(slot, layout.sideArea) then
					error(`side:{name} leaves the side area on {label}`)
				end
			end
		end)
		local small = HudLayout.resolve(950, 450).sideSlots
		expect(small.potions.x > small.pets.x).toBe(true)
	end)

	it("puts the egg preview panel on the right, clear of the top bar and the jump button", function()
		forEachScreen(function(layout, label)
			local zone = layout.eggPreview
			local screen = { x = 0, y = 0, w = layout.screen.w, h = layout.screen.h }
			if not inside(zone, screen) then
				error(`egg preview leaves the screen on {label}`)
			end
			for _, name in { "coins", "gems", "toast", "jump", "pizzaBar", "unlockButton" } do
				if overlaps(zone, (layout :: any)[name]) then
					error(`egg preview overlaps {name} on {label}`)
				end
			end
			expect(zone.x >= layout.screen.w / 2).toBe(true)
			expect(zone.x + zone.w).toBe(layout.rightColumn.x + layout.rightColumn.w)
			expect(zone.y >= layout.gems.y + layout.gems.h).toBe(true)
		end)
	end)

	it("fits the egg preview with at least one pet row into its zone", function()
		forEachScreen(function(layout, label)
			local zone = layout.eggPreview
			local design = HudLayout.EGG_PREVIEW_SIZE
			local fit = HudLayout.fitMenu(design.w, design.h, design.minH, zone.w, zone.h)
			if design.w * fit.scale > zone.w + 0.001 or fit.height * fit.scale > zone.h + 0.001 then
				error(`egg preview does not fit on {label}`)
			end
		end)
	end)

	it("starts menus below the currencies and messages and ends them above the pizza bar", function()
		forEachScreen(function(layout, label)
			for _, name in { "coins", "gems", "toast", "pizzaBar" } do
				if overlaps(layout.menuArea, (layout :: any)[name]) then
					error(`menu area overlaps {name} on {label}`)
				end
			end
			expect(layout.menuArea.y >= layout.toast.y + layout.toast.h).toBe(true)
			expect(layout.menuArea.y + layout.menuArea.h <= layout.pizzaBar.y).toBe(true)
		end)
	end)
end)

describe("menu fit", function()
	it("keeps a menu at full size when it fits", function()
		local fit = HudLayout.fitMenu(600, 400, nil, 800, 500)

		expect(fit).toEqual({ scale = 1, height = 400 })
	end)

	it("shrinks a fixed menu until it fits the menu area", function()
		local fit = HudLayout.fitMenu(600, 400, nil, 800, 200)

		expect(fit).toEqual({ scale = 0.5, height = 400 })
	end)

	it("shrinks a too wide menu to the area width", function()
		local fit = HudLayout.fitMenu(800, 300, nil, 400, 500)

		expect(fit).toEqual({ scale = 0.5, height = 300 })
	end)

	it("lets a menu with a scrolling list get shorter before it shrinks", function()
		local fit = HudLayout.fitMenu(600, 400, 250, 800, 300)

		expect(fit).toEqual({ scale = 1, height = 300 })
	end)

	it("shrinks a flexible menu once it reaches its minimum height", function()
		local fit = HudLayout.fitMenu(600, 400, 250, 800, 125)

		expect(fit).toEqual({ scale = 0.5, height = 250 })
	end)

	it("fits every menu into the menu area on every screen", function()
		forEachScreen(function(layout, label)
			local area = layout.menuArea
			for _, menu in { { 680, 460, 250 }, { 640, 560, 366 }, { 520, 440, 184 }, { 560, 470 }, { 540, 430 } } do
				local fit = HudLayout.fitMenu(menu[1], menu[2], menu[3], area.w, area.h)
				if menu[1] * fit.scale > area.w + 0.001 or fit.height * fit.scale > area.h + 0.001 then
					error(`menu {menu[1]}x{menu[2]} does not fit on {label}`)
				end
			end
		end)
	end)
end)
