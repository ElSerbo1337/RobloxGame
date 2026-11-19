--!strict
-- The HUD grid: where every HUD element and every menu sits on screen. Pure data and
-- maths without Roblox API, so the "nothing overlaps" rules are tested in Lune
-- (tests/HudLayout.spec.luau). The client reads it through UiKit (UiKit.place,
-- UiKit.sideButton, UiKit.rightColumn, UiKit.placeMenu); docs/ui-style.md explains it.
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
	sideArea: Rect,
	sideSlots: { [string]: Rect },
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

-- Top bar: coins left of the middle, gems right of it, messages right below.
local TOP = 12
local CURRENCY_HEIGHT = 60
local TOAST_TOP = TOP + CURRENCY_HEIGHT + 12 -- 84
local TOAST_HEIGHT = 40
-- Everything below the top bar (menus, side buttons) starts here.
HudLayout.BELOW_TOP_BAR = TOAST_TOP + TOAST_HEIGHT + 8 -- 132

-- Bottom middle: pizza bar, auto-collect switch above it.
local BAR_WIDTH = 260
local BAR_HEIGHT = 64
local BAR_GAP = 12

-- Phone touch controls (Roblox draws them, we keep out): joystick bottom left,
-- jump button bottom right. Generous enough for small and large phone layouts.
HudLayout.JOYSTICK_SIZE = { w = 260, h = 220 }
HudLayout.JUMP_SIZE = { w = 180, h = 220 }

-- Left side: round buttons in fixed slots, column by column.
HudLayout.SIDE_BUTTON = 96
HudLayout.SIDE_GAP = 12
HudLayout.SIDE_SLOTS = { "pets", "potions", "gifts", "rebirth" }

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
		size = { 0.5, -270, 0, 104 },
		maxWidth = 360,
	},
	-- Left, from half height down to the joystick, so the Roblox chat (top left) never
	-- covers the buttons. Grows upwards to at least one row on short screens.
	sideArea = {
		anchor = { 0, 1 },
		position = { 0, 16, 1, -HudLayout.JOYSTICK_SIZE.h },
		size = { 0, 4 * 96 + 3 * 12, 0.5, -HudLayout.JOYSTICK_SIZE.h },
		minHeight = HudLayout.SIDE_BUTTON,
	},
	pizzaBar = {
		anchor = { 0.5, 1 },
		position = { 0.5, 0, 1, -16 },
		size = { 0, BAR_WIDTH, 0, BAR_HEIGHT },
	},
	autoCollect = {
		anchor = { 0.5, 1 },
		position = { 0.5, 0, 1, -(16 + BAR_HEIGHT + BAR_GAP) },
		size = { 0, BAR_WIDTH, 0, BAR_HEIGHT },
	},
	-- Right of the pizza bar, ending before the jump button.
	unlockButton = {
		anchor = { 0, 1 },
		position = { 0.5, BAR_WIDTH / 2 + BAR_GAP, 1, -16 },
		size = { 0.5, -(BAR_WIDTH / 2 + BAR_GAP + HudLayout.JUMP_SIZE.w + 8), 0, 72 },
		maxWidth = 320,
	},
	-- Right: active potions, then the running order; ends above the jump button.
	rightColumn = {
		anchor = { 1, 0 },
		position = { 1, -16, 0, TOAST_TOP },
		size = { 0, HudLayout.RIGHT_COLUMN_WIDTH, 1, -(TOAST_TOP + HudLayout.JUMP_SIZE.h + 8) },
	},
	-- Egg preview: same right edge and top as the right column (which hides meanwhile),
	-- never under the gems counter, ends above the jump button.
	eggPreview = {
		anchor = { 1, 0 },
		position = { 1, -16, 0, TOAST_TOP },
		size = { 0.5, -EGG_PREVIEW_CLEAR, 1, -(TOAST_TOP + HudLayout.JUMP_SIZE.h + 8) },
		maxWidth = HudLayout.EGG_PREVIEW.width,
	},
	-- Menus: below currencies and messages, with room above the pizza bar.
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

-- Side buttons fill the side area top to bottom, then start the next column
-- (like a UIGridLayout with FillDirection Vertical).
function HudLayout.sideSlotRect(area: Rect, slot: number): Rect
	local pitch = HudLayout.SIDE_BUTTON + HudLayout.SIDE_GAP
	local rows = math.max(1, math.floor((area.h + HudLayout.SIDE_GAP) / pitch))
	local column = (slot - 1) // rows
	local row = (slot - 1) % rows
	return {
		x = area.x + column * pitch,
		y = area.y + row * pitch,
		w = HudLayout.SIDE_BUTTON,
		h = HudLayout.SIDE_BUTTON,
	}
end

function HudLayout.resolve(w: number, h: number): Layout
	local layout: any = { screen = { w = w, h = h }, sideSlots = {} }
	for name, zone in HudLayout.zones do
		layout[name] = HudLayout.rect(zone, w, h)
	end
	for slot, name in HudLayout.SIDE_SLOTS do
		layout.sideSlots[name] = HudLayout.sideSlotRect(layout.sideArea, slot)
	end
	return layout :: Layout
end

-- How a menu of `width` x `height` fits into an area of `areaW` x `areaH`.
-- A menu with a scrolling list may get shorter down to `minHeight` before it shrinks;
-- without `minHeight` it only shrinks. Returns the UIScale and the (unscaled) height.
function HudLayout.fitMenu(
	width: number,
	height: number,
	minHeight: number?,
	areaW: number,
	areaH: number
): { scale: number, height: number }
	local scale = math.min(1, areaW / width)
	if height * scale <= areaH then
		return { scale = scale, height = height }
	end
	local shortest = math.min(minHeight or height, height)
	if shortest * scale <= areaH then
		return { scale = scale, height = areaH / scale }
	end
	return { scale = areaH / shortest, height = shortest }
end

return HudLayout
