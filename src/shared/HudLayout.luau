--!strict
-- The HUD grid: where every HUD element and every menu sits on screen. Pure data and
-- maths without Roblox API, so the "nothing overlaps" rules are tested in Lune
-- (tests/HudLayout.spec.luau). The client reads it through UiKit (UiKit.place,
-- UiKit.rightColumn, UiKit.potionColumn, UiKit.placeMenu) and the side bar
-- (src/client/SideBar.luau, #75); docs/ui-style.md explains it.
--
-- Coordinates are virtual GUI pixels: after UiKit.autoScale and below the Roblox top bar.
-- A zone is like a UDim2 pair: anchor point, position (scale/offset) and size (scale/offset).

export type Zone = {
	anchor: { number }, -- { x, y } like AnchorPoint
	position: { number }, -- { xScale, xOffset, yScale, yOffset }
	size: { number }, -- { xScale, xOffset, yScale, yOffset }
	maxWidth: number?,
	minHeight: number?,
}

export type Rect = { x: number, y: number, w: number, h: number }

export type Layout = {
	screen: { w: number, h: number },
	coins: Rect,
	gems: Rect,
	toast: Rect,
	tutorialCard: Rect,
	sideBar: Rect,
	pizzaBar: Rect,
	autoCollect: Rect,
	unlockButton: Rect,
	rightColumn: Rect,
	eggPreview: Rect,
	menuArea: Rect,
	joystick: Rect,
	jump: Rect,
}

local HudLayout = {}

HudLayout.MARGIN = 16
HudLayout.MIN_TOUCH = 60

-- Top bar (#75): coins left of the middle, gems right of it, the pizza bar right below
-- both, then the messages.
local TOP = 12
local CURRENCY_HEIGHT = 60
-- The right column starts beside the pizza bar, right below the gems row.
local RIGHT_TOP = TOP + CURRENCY_HEIGHT + 12 -- 84
local PIZZA_TOP = TOP + CURRENCY_HEIGHT + 8 -- 80
local PIZZA_WIDTH = 260
local PIZZA_HEIGHT = 48
local TOAST_TOP = PIZZA_TOP + PIZZA_HEIGHT + 8 -- 136
local TOAST_HEIGHT = 40
-- Everything below the top bar (menus) starts here.
HudLayout.BELOW_TOP_BAR = TOAST_TOP + TOAST_HEIGHT + 8 -- 184

-- Bottom middle: auto-collect switch, the unlock button right of it.
local BAR_WIDTH = 260
local BAR_HEIGHT = 64
local BAR_GAP = 12
-- The tutorial card (top left) ends here.
local TUTORIAL_HEIGHT = 104

-- Phone touch controls (Roblox draws them, we keep out): joystick bottom left,
-- jump button bottom right. Generous enough for small and large phone layouts.
HudLayout.JOYSTICK_SIZE = { w = 260, h = 220 }
HudLayout.JUMP_SIZE = { w = 180, h = 220 }

-- Side bar (#75): glossy tiles on the left. Normal screens: one column (more only when
-- the tiles do not fit), tiles shrink from TILE down to MIN_TILE first. Small screens
-- (phones): two columns of smaller tiles right above the joystick. Tiles that do not fit
-- go behind a "More" tile in the last place (see HudLayout.sideBarGrid).
HudLayout.SIDE_BAR = { tile = 84, minTile = HudLayout.MIN_TOUCH, gap = 8, maxColumns = 3 }
HudLayout.SIDE_BAR_SMALL = { tile = 64, minTile = 64, gap = 8, maxColumns = 2 }
-- Normal screens: the bar starts below the Roblox chat (top left).
local SIDE_BAR_TOP = 0.3
local SIDE_BAR_WIDTH = HudLayout.SIDE_BAR.maxColumns * HudLayout.SIDE_BAR.tile
	+ (HudLayout.SIDE_BAR.maxColumns - 1) * HudLayout.SIDE_BAR.gap
local SIDE_BAR_SMALL_WIDTH = HudLayout.SIDE_BAR_SMALL.maxColumns * HudLayout.SIDE_BAR_SMALL.tile
	+ (HudLayout.SIDE_BAR_SMALL.maxColumns - 1) * HudLayout.SIDE_BAR_SMALL.gap
-- Phones: the bar starts below the tutorial card.
local SIDE_BAR_SMALL_TOP = TOP + TUTORIAL_HEIGHT + 8
-- Room kept free for the joystick on small screens (Roblox draws it lower there).
HudLayout.JOYSTICK_SMALL_HEIGHT = 180

HudLayout.RIGHT_COLUMN_WIDTH = 260

-- Egg preview panel (right, in place of the hidden right column): header, one row per
-- pet (the list scrolls), the open buttons. minH = header + one row + buttons.
HudLayout.EGG_PREVIEW = { width = 360, header = 60, row = 44, footer = 96 }
HudLayout.EGG_PREVIEW_SIZE = {
	w = HudLayout.EGG_PREVIEW.width,
	h = HudLayout.EGG_PREVIEW.header + 6 * HudLayout.EGG_PREVIEW.row + HudLayout.EGG_PREVIEW.footer,
	minH = HudLayout.EGG_PREVIEW.header + HudLayout.EGG_PREVIEW.row + HudLayout.EGG_PREVIEW.footer,
}
-- The gems counter ends 6 + 190 px right of the middle; the panel keeps 8 px from it.
local EGG_PREVIEW_CLEAR = 6 + 190 + 8 + 16

-- Small screens (phones): the short side of the real viewport is below this many pixels.
-- There menus fill nearly the whole screen, never shrink below MENU_MIN_SCALE and scroll
-- instead; the egg preview gets narrower and starts beside the gems counter.
HudLayout.SMALL_SCREEN = 500
HudLayout.MENU_MIN_SCALE = 0.85
HudLayout.SMALL_MARGIN = 8
HudLayout.EGG_PREVIEW_SMALL_WIDTH = 300

-- Shop menu (ShopMenu.luau): panel size, offer list inset, header and card rows.
HudLayout.SHOP = {
	width = 680,
	height = 460,
	listTop = 104,
	listBottom = 16,
	header = 44,
	card = 104,
	gap = 10,
}

HudLayout.zones = {
	coins = {
		anchor = { 1, 0 },
		position = { 0.5, -6, 0, TOP },
		size = { 0, 240, 0, CURRENCY_HEIGHT },
	},
	gems = {
		anchor = { 0, 0 },
		position = { 0.5, 6, 0, TOP },
		size = { 0, 190, 0, CURRENCY_HEIGHT },
	},
	toast = {
		anchor = { 0.5, 0 },
		position = { 0.5, 0, 0, TOAST_TOP },
		size = { 0, 380, 0, TOAST_HEIGHT },
	},
	-- Top left, under the Roblox menu; never wider than the room left of the coins.
	tutorialCard = {
		anchor = { 0, 0 },
		position = { 0, 16, 0, TOP },
		size = { 0.5, -270, 0, TUTORIAL_HEIGHT },
		maxWidth = 360,
	},
	-- Side bar, normal screens with touch (tablets): below the Roblox chat down to the
	-- joystick, at least one tile high.
	sideBar = {
		anchor = { 0, 0 },
		position = { 0, 16, SIDE_BAR_TOP, 0 },
		size = { 0, SIDE_BAR_WIDTH, 1 - SIDE_BAR_TOP, -HudLayout.JOYSTICK_SIZE.h },
		minHeight = HudLayout.SIDE_BAR.tile,
	},
	-- Normal screens without touch (PC): no joystick, the bar reaches down to the margin.
	sideBarMouse = {
		anchor = { 0, 0 },
		position = { 0, 16, SIDE_BAR_TOP, 0 },
		size = { 0, SIDE_BAR_WIDTH, 1 - SIDE_BAR_TOP, -16 },
	},
	-- Small screens: two columns from below the tutorial card down to the joystick.
	sideBarSmall = {
		anchor = { 0, 1 },
		position = { 0, 16, 1, -HudLayout.JOYSTICK_SMALL_HEIGHT },
		size = { 0, SIDE_BAR_SMALL_WIDTH, 1, -(HudLayout.JOYSTICK_SMALL_HEIGHT + SIDE_BAR_SMALL_TOP) },
		minHeight = HudLayout.SIDE_BAR_SMALL.tile,
	},
	-- Top middle, right below coins and gems (drawn in their layer, see Hud.luau).
	pizzaBar = {
		anchor = { 0.5, 0 },
		position = { 0.5, 0, 0, PIZZA_TOP },
		size = { 0, PIZZA_WIDTH, 0, PIZZA_HEIGHT },
	},
	autoCollect = {
		anchor = { 0.5, 1 },
		position = { 0.5, 0, 1, -16 },
		size = { 0, BAR_WIDTH, 0, BAR_HEIGHT },
	},
	-- Right of the auto-collect switch, ending before the jump button.
	unlockButton = {
		anchor = { 0, 1 },
		position = { 0.5, BAR_WIDTH / 2 + BAR_GAP, 1, -16 },
		size = { 0.5, -(BAR_WIDTH / 2 + BAR_GAP + HudLayout.JUMP_SIZE.w + 8), 0, 72 },
		maxWidth = 320,
	},
	-- Right: active bonuses and the running order at the top, active potions at the
	-- bottom (HudLayout.fitStacks); ends above the jump button.
	rightColumn = {
		anchor = { 1, 0 },
		position = { 1, -16, 0, RIGHT_TOP },
		size = { 0, HudLayout.RIGHT_COLUMN_WIDTH, 1, -(RIGHT_TOP + HudLayout.JUMP_SIZE.h + 8) },
	},
	-- Egg preview: same right edge and top as the right column (which hides meanwhile),
	-- never under the gems counter, ends above the jump button.
	eggPreview = {
		anchor = { 1, 0 },
		position = { 1, -16, 0, RIGHT_TOP },
		size = { 0.5, -EGG_PREVIEW_CLEAR, 1, -(RIGHT_TOP + HudLayout.JUMP_SIZE.h + 8) },
		maxWidth = HudLayout.EGG_PREVIEW.width,
	},
	-- Small screens: the egg preview starts beside the gems counter (taller panel).
	eggPreviewSmall = {
		anchor = { 1, 0 },
		position = { 1, -16, 0, TOP },
		size = { 0.5, -EGG_PREVIEW_CLEAR, 1, -(TOP + HudLayout.JUMP_SIZE.h + 8) },
		maxWidth = HudLayout.EGG_PREVIEW.width,
	},
	-- Small screens: menus fill nearly the whole screen (below the Roblox top bar).
	menuAreaSmall = {
		anchor = { 0.5, 0 },
		position = { 0.5, 0, 0, HudLayout.SMALL_MARGIN },
		size = { 1, -2 * HudLayout.SMALL_MARGIN, 1, -2 * HudLayout.SMALL_MARGIN },
	},
	-- Menus: below currencies, pizza bar and messages, with room above auto-collect.
	menuArea = {
		anchor = { 0.5, 0 },
		position = { 0.5, 0, 0, HudLayout.BELOW_TOP_BAR },
		size = { 1, -32, 1, -(HudLayout.BELOW_TOP_BAR + 16 + BAR_HEIGHT + 16) },
	},
	joystick = {
		anchor = { 0, 1 },
		position = { 0, 0, 1, 0 },
		size = { 0, HudLayout.JOYSTICK_SIZE.w, 0, HudLayout.JOYSTICK_SIZE.h },
	},
	joystickSmall = {
		anchor = { 0, 1 },
		position = { 0, 0, 1, 0 },
		size = { 0, HudLayout.JOYSTICK_SIZE.w, 0, HudLayout.JOYSTICK_SMALL_HEIGHT },
	},
	jump = {
		anchor = { 1, 1 },
		position = { 1, 0, 1, 0 },
		size = { 0, HudLayout.JUMP_SIZE.w, 0, HudLayout.JUMP_SIZE.h },
	},
} :: { [string]: Zone }

-- Rectangle of a zone on a screen of `w` x `h` virtual pixels.
function HudLayout.rect(zone: Zone, w: number, h: number): Rect
	local width = zone.size[1] * w + zone.size[2]
	if zone.maxWidth then
		width = math.min(width, zone.maxWidth)
	end
	local height = zone.size[3] * h + zone.size[4]
	if zone.minHeight then
		height = math.max(height, zone.minHeight)
	end
	local x = zone.position[1] * w + zone.position[2] - zone.anchor[1] * width
	local y = zone.position[3] * h + zone.position[4] - zone.anchor[2] * height
	return { x = x, y = y, w = width, h = height }
end

-- Is a real viewport of `w` x `h` pixels a small screen (phone)?
function HudLayout.isSmallScreen(w: number, h: number): boolean
	return math.min(w, h) < HudLayout.SMALL_SCREEN
end

-- The zone to use for `name` on a small or normal screen (small variants: `<name>Small`).
function HudLayout.zone(name: string, small: boolean?): Zone
	local zone = (small and HudLayout.zones[name .. "Small"]) or HudLayout.zones[name]
	assert(zone, `Unknown HUD zone {name}`)
	return zone
end

-- Lowest scale a menu may get before it scrolls instead (nil: it may shrink freely).
function HudLayout.menuMinScale(small: boolean?): number?
	return if small then HudLayout.MENU_MIN_SCALE else nil
end

-- Design size of the egg preview panel (narrower on small screens).
function HudLayout.eggPreviewSize(small: boolean?): { w: number, h: number, minH: number }
	local size = HudLayout.EGG_PREVIEW_SIZE
	return {
		w = if small then HudLayout.EGG_PREVIEW_SMALL_WIDTH else size.w,
		h = size.h,
		minH = size.minH,
	}
end

-- Shortest shop panel: one card (on small screens a section header plus one whole card).
function HudLayout.shopMinHeight(small: boolean?): number
	local shop = HudLayout.SHOP
	local rows = if small then shop.header + shop.gap + shop.card else shop.card
	return shop.listTop + rows + shop.listBottom
end

-- Zone of the side bar: small screens (phones), touch screens (joystick kept free) or
-- mouse only (PC, no joystick).
function HudLayout.sideBarZone(small: boolean?, touch: boolean?): Zone
	if small then
		return HudLayout.zones.sideBarSmall
	end
	return if touch == false then HudLayout.zones.sideBarMouse else HudLayout.zones.sideBar
end

-- Resolves every zone on a screen of `w` x `h` virtual pixels; `small` picks the
-- small-screen variants (see HudLayout.isSmallScreen), `touch = false` the side bar
-- without joystick (PC). Touch is assumed when not given.
function HudLayout.resolve(w: number, h: number, small: boolean?, touch: boolean?): Layout
	local layout: any = { screen = { w = w, h = h } }
	for name in HudLayout.zones do
		if not string.find(name, "Small$") and not string.find(name, "Mouse$") then
			layout[name] = HudLayout.rect(HudLayout.zone(name, small), w, h)
		end
	end
	layout.sideBar = HudLayout.rect(HudLayout.sideBarZone(small, touch), w, h)
	return layout :: Layout
end

export type SideBarGrid = {
	tile: number, -- tile size (square)
	gap: number,
	columns: number,
	rows: number,
	-- How many places the bar has; with more tiles the last place becomes "More".
	capacity: number,
	overflow: boolean,
	-- One rectangle per place in fill order (at most `capacity`).
	places: { Rect },
}

-- Places for `count` tiles in the side bar `area`.
-- Normal screens: as few columns as possible (one if it fits), tiles from SIDE_BAR.tile
-- down to minTile; the block is centred vertically and filled column by column.
-- Small screens: two columns of SIDE_BAR_SMALL tiles, filled row by row, the block sits
-- at the bottom of the area (right above the joystick). Whatever does not fit goes
-- behind a "More" tile in the last place (`overflow`).
function HudLayout.sideBarGrid(area: Rect, count: number, small: boolean?): SideBarGrid
	local spec = if small then HudLayout.SIDE_BAR_SMALL else HudLayout.SIDE_BAR
	local gap = spec.gap
	local function rowsFitting(tile: number): number
		return math.max(1, math.floor((area.h + gap) / (tile + gap)))
	end

	local tile, columns, rows
	if small then
		tile = spec.tile
		columns = spec.maxColumns
		rows = math.min(math.max(1, math.ceil(count / columns)), rowsFitting(tile))
	else
		for tryColumns = 1, spec.maxColumns do
			local tryRows = math.max(1, math.ceil(count / tryColumns))
			local size = math.min(spec.tile, math.floor((area.h - (tryRows - 1) * gap) / tryRows))
			if size >= spec.minTile then
				tile, columns, rows = size, tryColumns, tryRows
				break
			end
		end
		if tile == nil then
			tile = spec.minTile
			columns = spec.maxColumns
			rows = rowsFitting(tile)
		end
	end

	local fits = columns * rows
	local overflow = count > fits
	local placesCount = math.min(count, fits)
	-- Rows actually used (phones: row by row, so fewer rows for few tiles).
	local usedRows = if small then math.max(1, math.ceil(placesCount / columns)) else rows
	local blockH = usedRows * tile + (usedRows - 1) * gap
	local top = if small then area.y + area.h - blockH else area.y + (area.h - blockH) / 2

	local places = {}
	for index = 1, placesCount do
		local column, row
		if small then
			column = (index - 1) % columns
			row = (index - 1) // columns
		else
			column = (index - 1) // rows
			row = (index - 1) % rows
		end
		table.insert(places, {
			x = area.x + column * (tile + gap),
			y = top + row * (tile + gap),
			w = tile,
			h = tile,
		})
	end
	return {
		tile = tile,
		gap = gap,
		columns = columns,
		rows = usedRows,
		capacity = fits,
		overflow = overflow,
		places = places,
	}
end

-- Right column: the top stack (bonuses, order card) and the bottom stack (potions)
-- share an area `areaH` high, `gap` apart. The bottom stack keeps its size up to half
-- of the area (while the top stack has content), the top stack gets the rest; both
-- only shrink, never overlap. Returns the UIScale of each stack.
function HudLayout.fitStacks(topH: number, bottomH: number, areaH: number, gap: number): { top: number, bottom: number }
	local spacing = if topH > 0 and bottomH > 0 then gap else 0
	if topH + bottomH + spacing <= areaH then
		return { top = 1, bottom = 1 }
	end
	if topH <= 0 then
		return { top = 1, bottom = math.min(1, areaH / bottomH) }
	end
	if bottomH <= 0 then
		return { top = math.min(1, areaH / topH), bottom = 1 }
	end
	local room = areaH - spacing
	local bottomRoom = math.max(room - topH, math.min(bottomH, room / 2))
	local bottom = math.min(1, bottomRoom / bottomH)
	local top = math.min(1, (room - bottomH * bottom) / topH)
	return { top = top, bottom = bottom }
end

-- How a menu of `width` x `height` fits into an area of `areaW` x `areaH`.
-- A menu with a scrolling list may get shorter down to `minHeight` before it shrinks;
-- without `minHeight` it only shrinks. With `minScale` (small screens) it never shrinks
-- below that for lack of height: it keeps `content` height and scrolls in a window of
-- `height` instead. Returns the UIScale, the (unscaled) height and, when it scrolls, the
-- (unscaled) content height.
function HudLayout.fitMenu(
	width: number,
	height: number,
	minHeight: number?,
	areaW: number,
	areaH: number,
	minScale: number?
): { scale: number, height: number, content: number? }
	local scale = math.min(1, areaW / width)
	if height * scale <= areaH then
		return { scale = scale, height = height }
	end
	local shortest = math.min(minHeight or height, height)
	if shortest * scale <= areaH then
		return { scale = scale, height = areaH / scale }
	end
	local fitScale = areaH / shortest
	if minScale and fitScale < minScale then
		local floor = math.min(scale, minScale)
		return { scale = floor, height = areaH / floor, content = shortest }
	end
	return { scale = fitScale, height = shortest }
end

return HudLayout
