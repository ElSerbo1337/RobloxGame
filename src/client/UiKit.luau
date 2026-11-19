--!strict
-- Small UI helpers and the shared look (colors, font) for all game UI.
-- The rules behind it are written down in docs/ui-style.md; new UI uses UiKit.
-- Everything is sized for touch: buttons are at least 60 px high.
-- Where things sit on screen comes from the HUD grid (src/shared/HudLayout.luau):
-- UiKit.place, UiKit.sideButton, UiKit.rightColumn and UiKit.placeMenu apply it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local MenuSwitch = require(ReplicatedStorage.Shared.MenuSwitch)
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UiKit = {}

UiKit.FONT = Enum.Font.FredokaOne
UiKit.CREAM = Color3.fromRGB(255, 248, 230)
UiKit.DARK = Color3.fromRGB(60, 35, 20)
UiKit.COIN = Color3.fromRGB(255, 200, 40)
UiKit.GREEN = Color3.fromRGB(110, 200, 90)
UiKit.RED = Color3.fromRGB(230, 70, 50)
UiKit.GEM = Color3.fromRGB(60, 230, 255)
UiKit.ORANGE = Color3.fromRGB(240, 130, 60)
UiKit.GREY = Color3.fromRGB(190, 180, 170)
-- Smallest tappable size (px, before UIScale) for anything the player presses.
UiKit.MIN_TOUCH = 60

function UiKit.corner(parent: Instance, radius: number)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius)
	uiCorner.Parent = parent
end

function UiKit.stroke(parent: Instance, thickness: number?)
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Thickness = thickness or 3
	uiStroke.Color = UiKit.DARK
	uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	uiStroke.Parent = parent
end

function UiKit.label(parent: Instance, text: string): TextLabel
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Font = UiKit.FONT
	textLabel.TextScaled = true
	textLabel.TextColor3 = UiKit.DARK
	textLabel.Text = text
	textLabel.Parent = parent
	return textLabel
end

-- Big rounded button; use `.Activated` (works for mouse and touch).
function UiKit.button(parent: Instance, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BackgroundColor3 = color
	button.Font = UiKit.FONT
	button.TextScaled = true
	button.TextColor3 = UiKit.CREAM
	button.Text = text
	UiKit.corner(button, 18)
	UiKit.stroke(button)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = button
	local textStroke = Instance.new("UIStroke")
	textStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	textStroke.Color = UiKit.DARK
	textStroke.Thickness = 2
	textStroke.Parent = button
	button.Parent = parent
	return button
end

-- Round icon button (HUD side buttons like "Pets"): a circle `size` px wide.
function UiKit.roundButton(parent: Instance, text: string, color: Color3, size: number?): TextButton
	local button = UiKit.button(parent, text, color)
	local diameter = math.max(size or 96, UiKit.MIN_TOUCH)
	button.Size = UDim2.fromOffset(diameter, diameter)
	local round = button:FindFirstChildOfClass("UICorner") :: UICorner
	round.CornerRadius = UDim.new(0.5, 0)
	return button
end

-- Scales a ScreenGui so it stays readable on small phones and large monitors alike.
function UiKit.autoScale(gui: ScreenGui)
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = gui
	local function update()
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		local size = camera.ViewportSize
		uiScale.Scale = math.clamp(math.min(size.X / 1100, size.Y / 650), 0.7, 1.4)
	end
	update()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(update)
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
end

function UiKit.pop(target: GuiObject, from: number?)
	local uiScale = target:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	uiScale.Parent = target
	uiScale.Scale = from or 1.15
	TweenService:Create(uiScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

-- Short number for small labels: 999.999 stays as is, then "1,5 Mio", "12 Mrd", "3,4 Bio".
function UiKit.shortNumber(value: number): string
	local units = { { 1e12, "Bio" }, { 1e9, "Mrd" }, { 1e6, "Mio" } }
	for _, unit in units do
		if value >= unit[1] then
			local scaled = value / unit[1]
			local text = if scaled >= 100
				then tostring(math.floor(scaled))
				else string.format("%.1f", math.floor(scaled * 10) / 10)
			text = string.gsub(string.gsub(text, "%.0$", ""), "%.", ",")
			return `{text} {unit[2]}`
		end
	end
	local text = tostring(math.floor(value))
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1.")))
	return (string.gsub(formatted, "^%.", ""))
end

-- HUD grid ------------------------------------------------------------------------

UiKit.Layout = HudLayout

-- Puts `object` into a named zone of the HUD grid (see HudLayout.zones).
function UiKit.place(object: GuiObject, zoneName: string)
	local zone = HudLayout.zones[zoneName]
	assert(zone, `Unknown HUD zone {zoneName}`)
	object.AnchorPoint = Vector2.new(zone.anchor[1], zone.anchor[2])
	object.Position = UDim2.new(zone.position[1], zone.position[2], zone.position[3], zone.position[4])
	object.Size = UDim2.new(zone.size[1], zone.size[2], zone.size[3], zone.size[4])
	if zone.maxWidth or zone.minHeight then
		local constraint = Instance.new("UISizeConstraint")
		constraint.MinSize = Vector2.new(0, zone.minHeight or 0)
		constraint.MaxSize = Vector2.new(zone.maxWidth or math.huge, math.huge)
		constraint.Parent = object
	end
end

local function zoneFrame(parent: Instance, zoneName: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = zoneName
	frame.BackgroundTransparency = 1
	frame.Active = false
	UiKit.place(frame, zoneName)
	frame.Parent = parent
	return frame
end

-- One shared ScreenGui holds the side buttons (left) and the right column, so
-- buttons from different features line up in one grid instead of guessing positions.
local grid: { side: Frame, right: Frame }? = nil
local function hudGrid(): { side: Frame, right: Frame }
	if grid then
		return grid
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "HudGrid"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	UiKit.autoScale(gui)

	local side = zoneFrame(gui, "sideArea")
	local sideLayout = Instance.new("UIGridLayout")
	sideLayout.CellSize = UDim2.fromOffset(HudLayout.SIDE_BUTTON, HudLayout.SIDE_BUTTON)
	sideLayout.CellPadding = UDim2.fromOffset(HudLayout.SIDE_GAP, HudLayout.SIDE_GAP)
	sideLayout.FillDirection = Enum.FillDirection.Vertical
	sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sideLayout.Parent = side

	-- Right column: a stack (potion pills, order card) that shrinks when it gets taller
	-- than the room above the jump button.
	local rightArea = zoneFrame(gui, "rightColumn")
	local stack = Instance.new("Frame")
	stack.Name = "Stack"
	stack.BackgroundTransparency = 1
	stack.AnchorPoint = Vector2.new(1, 0)
	stack.Position = UDim2.fromScale(1, 0)
	stack.Size = UDim2.fromScale(1, 0)
	stack.AutomaticSize = Enum.AutomaticSize.Y
	stack.Parent = rightArea
	local stackLayout = Instance.new("UIListLayout")
	stackLayout.Padding = UDim.new(0, 8)
	stackLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	stackLayout.SortOrder = Enum.SortOrder.LayoutOrder
	stackLayout.Parent = stack
	local stackScale = Instance.new("UIScale")
	stackScale.Parent = stack
	local function fitStack()
		local content = stack.AbsoluteSize.Y / stackScale.Scale
		if content <= 0 then
			return
		end
		local target = math.clamp(rightArea.AbsoluteSize.Y / content, 0.5, 1)
		if math.abs(target - stackScale.Scale) > 0.01 then
			stackScale.Scale = target
		end
	end
	stack:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitStack)
	rightArea:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitStack)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	grid = { side = side, right = stack }
	return grid :: { side: Frame, right: Frame }
end

-- Round HUD button on the left in its fixed slot ("pets", "potions", "gifts", "rebirth").
function UiKit.sideButton(slot: string, text: string, color: Color3): TextButton
	local order = table.find(HudLayout.SIDE_SLOTS, slot)
	assert(order, `Unknown side slot {slot}`)
	local button = UiKit.roundButton(hudGrid().side, text, color, HudLayout.SIDE_BUTTON)
	button.Name = slot
	button.LayoutOrder = order
	return button
end

-- The right-hand stack: parent potion pills (LayoutOrder 1) and the order card (2) here.
-- Width is HudLayout.RIGHT_COLUMN_WIDTH; hidden children take no room.
function UiKit.rightColumn(): Frame
	return hudGrid().right
end

-- Puts `panel` into a HUD zone, designed at `designSize`: it gets shorter down to
-- `minHeight` (panels with a scrolling list) and shrinks only after that (HudLayout.fitMenu).
-- `align` places it inside the zone (0..1 per axis, default centered). Afterwards the
-- panel fills its holder. Returns a function to change the design size later.
function UiKit.placePanel(
	gui: ScreenGui,
	panel: GuiObject,
	zoneName: string,
	designSize: Vector2,
	minHeight: number?,
	align: Vector2?
): (Vector2, number?) -> ()
	local at = align or Vector2.new(0.5, 0.5)
	local area = zoneFrame(gui, zoneName)
	local holder = Instance.new("Frame")
	holder.Name = "PanelHolder"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = at
	holder.Position = UDim2.fromScale(at.X, at.Y)
	holder.Size = UDim2.fromOffset(designSize.X, designSize.Y)
	holder.Parent = area
	local fitScale = Instance.new("UIScale")
	fitScale.Parent = holder

	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(1, 1)
	panel.Parent = holder

	local size, shortest = designSize, minHeight
	local function update()
		local guiScale = gui:FindFirstChildOfClass("UIScale")
		local scale = if guiScale then guiScale.Scale else 1
		local areaSize = area.AbsoluteSize / scale
		if areaSize.X <= 0 or areaSize.Y <= 0 then
			return
		end
		local fit = HudLayout.fitMenu(size.X, size.Y, shortest, areaSize.X, areaSize.Y)
		holder.Size = UDim2.fromOffset(size.X, fit.height)
		fitScale.Scale = fit.scale
	end
	area:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	task.defer(update)
	return function(newSize: Vector2, newMinHeight: number?)
		size, shortest = newSize, newMinHeight
		update()
	end
end

-- Puts a menu panel into the menu area (below currencies and messages, above the
-- pizza bar). The panel is designed at `designSize`; it gets shorter down to
-- `minHeight` (menus with a scrolling list) and shrinks only after that.
-- Afterwards the panel fills its holder: keep using panel.Visible and UiKit.pop(panel).
function UiKit.placeMenu(gui: ScreenGui, panel: GuiObject, designSize: Vector2, minHeight: number?)
	UiKit.placePanel(gui, panel, "menuArea", designSize, minHeight)
end

-- Hides the right column (potion pills, order card) while a panel uses its place
-- (the egg preview); its children keep their own visibility.
function UiKit.setRightColumnHidden(hidden: boolean)
	hudGrid().right.Visible = not hidden
end

-- Only one menu at a time (#53, MenuSwitch): every menu registers its id and its normal
-- close function (the one "X" uses) and calls UiKit.menuOpened(id) whenever it opens;
-- all other open menus then close as if the player had closed them.
local menus = MenuSwitch.new()

function UiKit.registerMenu(id: string, close: () -> ())
	menus.register(id, close)
end

function UiKit.menuOpened(id: string)
	menus.opened(id)
end

function UiKit.rarityColor(rarityId: string): Color3
	local color = GameConfig.rarities[rarityId].color
	return Color3.fromRGB(color[1], color[2], color[3])
end

-- "+25 %" from a bonus of 0.25.
function UiKit.bonusText(bonus: number): string
	return `+{math.round(bonus * 100)} %`
end

-- "0,5 %" / "28 %" from a chance in percent.
function UiKit.chanceText(percent: number): string
	local text = if percent >= 10 or percent == math.floor(percent)
		then tostring(math.round(percent))
		else string.format("%.1f", percent)
	return (string.gsub(text, "%.", ",")) .. " %"
end

-- A reward of gifts or the login calendar ({ kind = "Gems" | "Potion", amount, potionId? })
-- as short German text: "10 Gems", "2× Glücks-Trank", "1 Trank".
function UiKit.rewardText(reward: { kind: string, amount: number, potionId: string? }): string
	if reward.kind == "Gems" then
		return `{UiKit.shortNumber(reward.amount)} Gems`
	end
	local potion = reward.potionId and GameConfig.potions[reward.potionId]
	if potion then
		return `{reward.amount}× {potion.displayName}`
	end
	return if reward.amount == 1 then "1 Trank" else `{reward.amount} Tränke`
end

-- Several rewards joined with " + ".
function UiKit.rewardsText(rewards: { { kind: string, amount: number, potionId: string? } }): string
	local parts = {}
	for _, reward in rewards do
		table.insert(parts, UiKit.rewardText(reward))
	end
	return table.concat(parts, " + ")
end

-- Currency icons (#49): built from GUI elements (no uploaded images), one look for the
-- HUD, the sell animation and every other place that shows a coin or a gem.

type Stop = { at: number, color: Color3 }

local function gradient(parent: Instance, stops: { Stop }, rotation: number)
	local points = {}
	for _, stop in stops do
		table.insert(points, ColorSequenceKeypoint.new(stop.at, stop.color))
	end
	local uiGradient = Instance.new("UIGradient")
	uiGradient.Color = ColorSequence.new(points)
	uiGradient.Rotation = rotation
	uiGradient.Parent = parent
end

local function iconPart(parent: Instance, size: UDim2, position: UDim2, color: Color3): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

local function round(frame: Frame)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0.5, 0)
	uiCorner.Parent = frame
end

local COIN_RIM = Color3.fromRGB(222, 146, 18)
local COIN_LIGHT = Color3.fromRGB(255, 236, 140)
local COIN_EMBOSS = Color3.fromRGB(214, 140, 16)
local COIN_EMBOSS_LIGHT = Color3.fromRGB(255, 226, 110)

-- A gold coin with a raised rim and an embossed pizza slice, `size` px square
-- (transparent holder; position and parent it like any Frame).
function UiKit.coinIcon(parent: Instance?, size: number): Frame
	local holder = Instance.new("Frame")
	holder.Name = "CoinIcon"
	holder.Size = UDim2.fromOffset(size, size)
	holder.BackgroundTransparency = 1

	local rim = iconPart(holder, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), Color3.new(1, 1, 1))
	round(rim)
	gradient(
		rim,
		{ { at = 0, color = COIN_LIGHT }, { at = 0.45, color = UiKit.COIN }, { at = 1, color = COIN_RIM } },
		60
	)
	UiKit.stroke(rim, math.max(2, math.floor(size / 16)))

	local face = iconPart(rim, UDim2.fromScale(0.74, 0.74), UDim2.fromScale(0.5, 0.5), Color3.new(1, 1, 1))
	round(face)
	gradient(
		face,
		{ { at = 0, color = COIN_RIM }, { at = 0.5, color = UiKit.COIN }, { at = 1, color = COIN_LIGHT } },
		60
	)
	local inner = Instance.new("UIStroke")
	inner.Thickness = math.max(1, math.floor(size / 24))
	inner.Color = COIN_RIM
	inner.Parent = face

	-- Pizza slice pointing down: stacked bars get narrower (a triangle without images),
	-- a light copy one pixel up-left makes it look pressed into the gold.
	local rows = 6
	local function slice(color: Color3, shift: number, zIndex: number)
		for row = 0, rows - 1 do
			local width = 0.62 * (1 - row / rows)
			local bar = iconPart(
				face,
				UDim2.fromScale(math.max(width, 0.08), 0.56 / rows + 0.01),
				UDim2.new(0.5, shift, 0.24 + (row + 0.5) * 0.56 / rows, shift),
				color
			)
			bar.ZIndex = zIndex
			if row == 0 then
				-- The crust: a rounded, slightly taller bar on top.
				bar.Size = UDim2.fromScale(0.66, 0.13)
				round(bar)
			end
		end
	end
	slice(COIN_EMBOSS_LIGHT, -1, 2)
	slice(COIN_EMBOSS, 0, 3)
	for _, spot in { Vector2.new(0.42, 0.42), Vector2.new(0.56, 0.5), Vector2.new(0.49, 0.62) } do
		local dot = iconPart(face, UDim2.fromScale(0.11, 0.11), UDim2.fromScale(spot.X, spot.Y), COIN_RIM)
		dot.ZIndex = 4
		round(dot)
	end

	holder.Parent = parent
	return holder
end

local GEM_LIGHT = Color3.fromRGB(190, 252, 255)
local GEM_DARK = Color3.fromRGB(20, 150, 200)
local GEM_DEEP = Color3.fromRGB(10, 110, 165)

-- A faceted turquoise diamond with a shine, `size` px square (transparent holder).
function UiKit.gemIcon(parent: Instance?, size: number): Frame
	local holder = Instance.new("Frame")
	holder.Name = "GemIcon"
	holder.Size = UDim2.fromOffset(size, size)
	holder.BackgroundTransparency = 1

	-- A square turned by 45° is the diamond; its diagonal fills the holder.
	local side = size * 0.66
	local body = iconPart(holder, UDim2.fromOffset(side, side), UDim2.fromScale(0.5, 0.5), Color3.new(1, 1, 1))
	body.Rotation = 45
	local bodyCorner = Instance.new("UICorner")
	bodyCorner.CornerRadius = UDim.new(0.1, 0)
	bodyCorner.Parent = body
	-- Hard colour steps = facets: light left half, dark right half (in screen space).
	gradient(body, {
		{ at = 0, color = GEM_LIGHT },
		{ at = 0.49, color = UiKit.GEM },
		{ at = 0.51, color = GEM_DARK },
		{ at = 1, color = GEM_DEEP },
	}, -45)
	UiKit.stroke(body, math.max(2, math.floor(size / 16)))

	-- The table facet in the middle: top half bright, bottom half darker.
	local table_ = iconPart(body, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.5, 0.5), Color3.new(1, 1, 1))
	gradient(table_, {
		{ at = 0, color = GEM_LIGHT },
		{ at = 0.49, color = GEM_LIGHT },
		{ at = 0.51, color = UiKit.GEM },
		{ at = 1, color = UiKit.GEM },
	}, 45)
	local tableStroke = Instance.new("UIStroke")
	tableStroke.Thickness = 1
	tableStroke.Color = GEM_DARK
	tableStroke.Transparency = 0.3
	tableStroke.Parent = table_

	-- Shine: a small white streak top left, plus a spark.
	local shine = iconPart(holder, UDim2.fromScale(0.24, 0.08), UDim2.fromScale(0.34, 0.3), Color3.new(1, 1, 1))
	shine.Rotation = -45
	shine.BackgroundTransparency = 0.15
	shine.ZIndex = 3
	round(shine)
	local spark = iconPart(holder, UDim2.fromScale(0.09, 0.09), UDim2.fromScale(0.5, 0.22), Color3.new(1, 1, 1))
	spark.ZIndex = 3
	round(spark)

	holder.Parent = parent
	return holder
end

return UiKit
