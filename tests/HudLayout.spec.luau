local TestKit = require("./TestKit")
local HudLayout = require("../src/shared/HudLayout")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

type Rect = HudLayout.Rect

-- Virtual GUI sizes (after UiKit.autoScale, below the Roblox top bar):
-- small phone, phone, laptop, tablet, full HD, 4K. The third value: is the real viewport
-- a small screen (short side below HudLayout.SMALL_SCREEN, see HudLayout.isSmallScreen)?
local SCREENS = {
	{ 950, 450, true },
	{ 1100, 520, true },
	{ 1157, 600, false },
	{ 1100, 763, false },
	{ 1371, 730, false },
	{ 2743, 1500, false },
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

-- Every screen with touch (joystick and jump button kept free); normal screens also
-- without touch (PC: the side bar reaches lower).
local function forEachScreen(fn: (layout: HudLayout.Layout, label: string, small: boolean, touch: boolean) -> ())
	for _, screen in SCREENS do
		local small = screen[3] == true
		fn(HudLayout.resolve(screen[1], screen[2], small, true), `{screen[1]}x{screen[2]}`, small, true)
		if not small then
			fn(HudLayout.resolve(screen[1], screen[2], small, false), `{screen[1]}x{screen[2]} (mouse)`, small, false)
		end
	end
end

-- Side bar tiles for `count` registered menus (the last place is "More" on overflow).
local function sideTiles(layout: HudLayout.Layout, small: boolean, count: number): { Rect }
	return HudLayout.sideBarGrid(layout.sideBar, count, small).places
end

-- Today's menus on the bar (pets, potions, gifts, calendar, rebirth, worlds) and room
-- for the later MEGA UPDATE menus (quests, wheel, index, profile, settings, ...).
local TILE_COUNTS = { 1, 4, 6, 8, 12 }

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
	return elements
end

local function withTiles(elements: { [string]: Rect }, layout: HudLayout.Layout, small: boolean, count: number)
	for index, rect in sideTiles(layout, small, count) do
		elements[`tile{index}`] = rect
	end
	return elements
end

describe("HUD layout", function()
	it("keeps every HUD element on screen", function()
		forEachScreen(function(layout, label, small)
			local screen = { x = 0, y = 0, w = layout.screen.w, h = layout.screen.h }
			for _, count in TILE_COUNTS do
				for name, rect in withTiles(fixedElements(layout), layout, small, count) do
					if not inside(rect, screen) then
						error(`{name} leaves the screen on {label} with {count} tiles`)
					end
				end
			end
		end)
	end)

	it("never lets two HUD elements overlap", function()
		forEachScreen(function(layout, label, small)
			for _, count in TILE_COUNTS do
				local elements = withTiles(fixedElements(layout), layout, small, count)
				for nameA, a in elements do
					for nameB, b in elements do
						if nameA < nameB and overlaps(a, b) then
							error(`{nameA} overlaps {nameB} on {label} with {count} tiles`)
						end
					end
				end
			end
		end)
	end)

	it("puts no button into the phone joystick or jump button area", function()
		forEachScreen(function(layout, label, small, touch)
			for _, count in TILE_COUNTS do
				local buttons = withTiles(
					{ autoCollect = layout.autoCollect, unlockButton = layout.unlockButton },
					layout,
					small,
					count
				)
				for name, rect in buttons do
					local inJoystick = touch and overlaps(rect, layout.joystick)
					if inJoystick or overlaps(rect, layout.jump) then
						error(`{name} lies in the joystick/jump area on {label} with {count} tiles`)
					end
				end
			end
		end)
	end)

	it("keeps buttons at least thumb sized", function()
		forEachScreen(function(layout, label, small)
			for _, count in TILE_COUNTS do
				local buttons = withTiles(
					{ autoCollect = layout.autoCollect, unlockButton = layout.unlockButton },
					layout,
					small,
					count
				)
				for name, rect in buttons do
					if rect.w < HudLayout.MIN_TOUCH or rect.h < HudLayout.MIN_TOUCH then
						error(`{name} is smaller than a thumb on {label} with {count} tiles`)
					end
				end
			end
		end)
	end)

	it("puts coins, gems and the pizza bar together at the top centre", function()
		forEachScreen(function(layout)
			local middle = layout.screen.w / 2
			expect(layout.pizzaBar.x + layout.pizzaBar.w / 2).toBe(middle)
			expect(layout.pizzaBar.y >= layout.coins.y + layout.coins.h).toBe(true)
			expect(layout.pizzaBar.y >= layout.gems.y + layout.gems.h).toBe(true)
			expect(layout.toast.y >= layout.pizzaBar.y + layout.pizzaBar.h).toBe(true)
		end)
	end)

	it("places the unlock button right of auto-collect at the bottom", function()
		forEachScreen(function(layout)
			expect(layout.unlockButton.x >= layout.autoCollect.x + layout.autoCollect.w).toBe(true)
			expect(layout.autoCollect.y + layout.autoCollect.h).toBe(layout.screen.h - HudLayout.MARGIN)
		end)
	end)

	it("keeps the potion pills and the order card above the jump button", function()
		forEachScreen(function(layout)
			expect(overlaps(layout.rightColumn, layout.jump)).toBe(false)
		end)
	end)

	it("keeps the right column clear of the pizza bar and the gems counter", function()
		forEachScreen(function(layout)
			expect(overlaps(layout.rightColumn, layout.pizzaBar)).toBe(false)
			expect(overlaps(layout.rightColumn, layout.gems)).toBe(false)
		end)
	end)

	it("places the tutorial card top left, clear of messages", function()
		forEachScreen(function(layout)
			expect(layout.tutorialCard.x).toBe(HudLayout.MARGIN)
			expect(layout.tutorialCard.x + layout.tutorialCard.w <= layout.coins.x).toBe(true)
			expect(overlaps(layout.tutorialCard, layout.toast)).toBe(false)
		end)
	end)

	it("starts the side bar below the Roblox chat on normal screens", function()
		forEachScreen(function(layout, label, small, touch)
			if small then
				return
			end
			local area = layout.sideBar
			expect(area.x).toBe(HudLayout.MARGIN)
			if area.y < layout.screen.h * 0.3 - 0.001 then
				error(`side bar starts too high on {label}`)
			end
			expect(area.y >= layout.tutorialCard.y + layout.tutorialCard.h).toBe(true)
			if touch then
				expect(area.y + area.h <= layout.joystick.y + 0.001).toBe(true)
			else
				expect(area.y + area.h <= layout.screen.h - HudLayout.MARGIN + 0.001).toBe(true)
			end
		end)
	end)

	it("shows today's six menus in one column on a PC", function()
		for _, screen in { { 1157, 600 }, { 1371, 730 }, { 2743, 1500 } } do
			local layout = HudLayout.resolve(screen[1], screen[2], false, false)
			local grid = HudLayout.sideBarGrid(layout.sideBar, 6, false)
			expect(grid.columns).toBe(1)
			expect(grid.overflow).toBe(false)
			expect(#grid.places).toBe(6)
		end
	end)

	it("uses two columns right above the joystick on small screens", function()
		forEachScreen(function(layout, label, small)
			if not small then
				return
			end
			local area = layout.sideBar
			expect(area.y + area.h).toBe(layout.screen.h - HudLayout.JOYSTICK_SMALL_HEIGHT)
			if area.y < layout.tutorialCard.y + layout.tutorialCard.h - 0.001 then
				error(`side bar reaches into the tutorial card on {label}`)
			end
			local grid = HudLayout.sideBarGrid(area, 6, true)
			expect(grid.columns).toBe(2)
			local places = grid.places
			-- Row by row: first tile left, second right of it, the third below the first.
			expect(places[2].y).toBe(places[1].y)
			expect(places[2].x > places[1].x).toBe(true)
			expect(places[3].x).toBe(places[1].x)
			expect(places[3].y > places[1].y).toBe(true)
			-- The block ends right above the joystick.
			local last = places[#places]
			expect(last.y + last.h).toBe(area.y + area.h)
		end)
	end)

	it("keeps every tile inside the side bar, and the bar clear of the bottom middle", function()
		forEachScreen(function(layout, label, small)
			for _, count in TILE_COUNTS do
				for index, rect in sideTiles(layout, small, count) do
					if not inside(rect, layout.sideBar) then
						error(`tile {index} leaves the side bar on {label} with {count} tiles`)
					end
				end
			end
			expect(layout.sideBar.x + layout.sideBar.w < layout.autoCollect.x).toBe(true)
		end)
	end)

	it("fits today's six menus without a More tile on phones that are not the smallest", function()
		local layout = HudLayout.resolve(1100, 520, true)
		local grid = HudLayout.sideBarGrid(layout.sideBar, 6, true)
		expect(grid.overflow).toBe(false)
		expect(#grid.places).toBe(6)
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
			-- Below the gems counter; on small screens beside it (taller panel).
			local belowGems = zone.y >= layout.gems.y + layout.gems.h
			local besideGems = zone.x >= layout.gems.x + layout.gems.w
			expect(belowGems or besideGems).toBe(true)
		end)
	end)

	it("fits the egg preview with at least one pet row into its zone", function()
		forEachScreen(function(layout, label, small)
			local zone = layout.eggPreview
			local design = HudLayout.eggPreviewSize(small)
			local fit = HudLayout.fitMenu(design.w, design.h, design.minH, zone.w, zone.h)
			if design.w * fit.scale > zone.w + 0.001 or fit.height * fit.scale > zone.h + 0.001 then
				error(`egg preview does not fit on {label}`)
			end
			-- On small screens the panel stays readable: never below the menu minimum scale.
			if small and fit.scale < HudLayout.MENU_MIN_SCALE - 0.001 then
				error(`egg preview is scaled to {fit.scale} on {label}`)
			end
		end)
	end)

	it("starts menus below the top bar and ends them above auto-collect", function()
		forEachScreen(function(layout, label, small)
			if small then
				return
			end
			for _, name in { "coins", "gems", "toast", "pizzaBar", "autoCollect" } do
				if overlaps(layout.menuArea, (layout :: any)[name]) then
					error(`menu area overlaps {name} on {label}`)
				end
			end
			expect(layout.menuArea.y >= layout.toast.y + layout.toast.h).toBe(true)
			expect(layout.menuArea.y + layout.menuArea.h <= layout.autoCollect.y).toBe(true)
		end)
	end)

	it("lets menus fill nearly the whole screen on small screens", function()
		forEachScreen(function(layout, label, small)
			if not small then
				return
			end
			local area, screen = layout.menuArea, layout.screen
			if not inside(area, { x = 0, y = 0, w = screen.w, h = screen.h }) then
				error(`menu area leaves the screen on {label}`)
			end
			expect(area.w >= screen.w - 2 * HudLayout.MARGIN).toBe(true)
			expect(area.h >= screen.h - 2 * HudLayout.MARGIN).toBe(true)
		end)
	end)
end)

describe("small screen", function()
	it("counts a viewport as small when its short side is below the limit", function()
		expect(HudLayout.isSmallScreen(667, 375)).toBe(true)
		expect(HudLayout.isSmallScreen(375, 667)).toBe(true)
		expect(HudLayout.isSmallScreen(1366, 1024)).toBe(false)
		expect(HudLayout.isSmallScreen(1920, 1080)).toBe(false)
	end)

	it("shows the shop with at least one whole card and its buy button", function()
		forEachScreen(function(layout, label, small)
			if not small then
				return
			end
			local shop = HudLayout.SHOP
			local area = layout.menuArea
			local fit = HudLayout.fitMenu(
				shop.width,
				shop.height,
				HudLayout.shopMinHeight(true),
				area.w,
				area.h,
				HudLayout.MENU_MIN_SCALE
			)
			local listHeight = (fit.content or fit.height) - shop.listTop - shop.listBottom
			if listHeight < shop.header + shop.gap + shop.card then
				error(`shop shows no whole card on {label}`)
			end
			expect(fit.scale >= HudLayout.MENU_MIN_SCALE).toBe(true)
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
		forEachScreen(function(layout, label, small)
			local area = layout.menuArea
			local minScale = HudLayout.menuMinScale(small)
			for _, menu in { { 680, 460, 250 }, { 640, 560, 366 }, { 520, 440, 184 }, { 560, 470 }, { 540, 430 } } do
				local fit = HudLayout.fitMenu(menu[1], menu[2], menu[3], area.w, area.h, minScale)
				if menu[1] * fit.scale > area.w + 0.001 or fit.height * fit.scale > area.h + 0.001 then
					error(`menu {menu[1]}x{menu[2]} does not fit on {label}`)
				end
				if small and fit.scale < HudLayout.MENU_MIN_SCALE - 0.001 then
					error(`menu {menu[1]}x{menu[2]} is scaled to {fit.scale} on {label}`)
				end
			end
		end)
	end)

	it("scrolls a menu instead of shrinking it below the minimum scale", function()
		local fit = HudLayout.fitMenu(600, 400, nil, 800, 150, 0.5)

		expect(fit).toEqual({ scale = 0.5, height = 300, content = 400 })
	end)

	it("scrolls a flexible menu at its minimum height instead of shrinking it", function()
		local fit = HudLayout.fitMenu(600, 400, 250, 800, 100, 0.5)

		expect(fit).toEqual({ scale = 0.5, height = 200, content = 250 })
	end)

	it("still shrinks a too wide menu to the area width before it scrolls", function()
		local fit = HudLayout.fitMenu(1000, 400, nil, 400, 100, 0.5)

		expect(fit).toEqual({ scale = 0.4, height = 250, content = 400 })
	end)
end)

describe("side bar grid", function()
	local area = { x = 16, y = 100, w = 272, h = 500 }

	it("puts few tiles in one centred column at full size", function()
		local grid = HudLayout.sideBarGrid(area, 3, false)

		expect(grid.columns).toBe(1)
		expect(grid.tile).toBe(HudLayout.SIDE_BAR.tile)
		expect(#grid.places).toBe(3)
		local blockH = 3 * grid.tile + 2 * grid.gap
		expect(grid.places[1].y).toBe(area.y + (area.h - blockH) / 2)
		expect(grid.places[2].y).toBe(grid.places[1].y + grid.tile + grid.gap)
	end)

	it("shrinks the tiles before it starts a second column", function()
		local grid = HudLayout.sideBarGrid(area, 6, false)

		expect(grid.columns).toBe(1)
		expect(grid.tile < HudLayout.SIDE_BAR.tile).toBe(true)
		expect(grid.tile >= HudLayout.SIDE_BAR.minTile).toBe(true)
	end)

	it("starts more columns, filled top to bottom, when one column is too long", function()
		local grid = HudLayout.sideBarGrid(area, 12, false)

		expect(grid.columns).toBe(2)
		expect(grid.rows).toBe(6)
		expect(grid.places[7].x > grid.places[1].x).toBe(true)
		expect(grid.places[7].y).toBe(grid.places[1].y)
		expect(grid.overflow).toBe(false)
	end)

	it("hides the rest behind a More place when even the last column is full", function()
		local short = { x = 16, y = 100, w = 272, h = 150 }
		local grid = HudLayout.sideBarGrid(short, 12, false)

		expect(grid.overflow).toBe(true)
		expect(#grid.places).toBe(grid.capacity)
		expect(grid.capacity < 12).toBe(true)
	end)

	it("fills phones row by row in two columns and overflows into More", function()
		local phone = { x = 16, y = 124, w = 136, h = 146 }
		local grid = HudLayout.sideBarGrid(phone, 6, true)

		expect(grid.columns).toBe(2)
		expect(grid.capacity).toBe(4)
		expect(grid.overflow).toBe(true)
		expect(#grid.places).toBe(4)
		expect(grid.places[4].y + grid.places[4].h).toBe(phone.y + phone.h)
	end)

	it("keeps few phone tiles in one row right above the joystick", function()
		local phone = { x = 16, y = 124, w = 136, h = 300 }
		local grid = HudLayout.sideBarGrid(phone, 2, true)

		expect(grid.rows).toBe(1)
		expect(grid.places[1].y + grid.tile).toBe(phone.y + phone.h)
	end)
end)

describe("right column stacks", function()
	it("keeps both stacks at full size when they fit", function()
		expect(HudLayout.fitStacks(150, 72, 300, 8)).toEqual({ top = 1, bottom = 1 })
	end)

	it("never lets the stacks overlap, keeping the potions up to half the room", function()
		for _, case in { { 200, 64, 138 }, { 200, 208, 138 }, { 400, 400, 300 }, { 50, 300, 200 } } do
			local fit = HudLayout.fitStacks(case[1], case[2], case[3], 8)
			local used = case[1] * fit.top + case[2] * fit.bottom + 8
			if used > case[3] + 0.001 then
				error(`stacks {case[1]} + {case[2]} overlap in {case[3]}`)
			end
		end
		-- One potion pill keeps its size on a small phone; the order card shrinks.
		local fit = HudLayout.fitStacks(200, 64, 138, 8)
		expect(fit.bottom).toBe(1)
		expect(fit.top < 1).toBe(true)
	end)

	it("lets a lone stack use the whole column", function()
		expect(HudLayout.fitStacks(0, 400, 200, 8)).toEqual({ top = 1, bottom = 0.5 })
		expect(HudLayout.fitStacks(400, 0, 200, 8)).toEqual({ top = 0.5, bottom = 1 })
	end)
end)
