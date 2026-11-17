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
	if zone.maxWidth then
		local constraint = Instance.new("UISizeConstraint")
		constraint.MaxSize = Vector2.new(zone.maxWidth, math.huge)
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

-- Puts a menu panel into the menu area (below currencies and messages, above the
-- pizza bar). The panel is designed at `designSize`; it gets shorter down to
-- `minHeight` (menus with a scrolling list) and shrinks only after that.
-- Afterwards the panel fills its holder: keep using panel.Visible and UiKit.pop(panel).
function UiKit.placeMenu(gui: ScreenGui, panel: GuiObject, designSize: Vector2, minHeight: number?)
	local area = zoneFrame(gui, "menuArea")
	local holder = Instance.new("Frame")
	holder.Name = "MenuHolder"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(designSize.X, designSize.Y)
	holder.Parent = area
	local fitScale = Instance.new("UIScale")
	fitScale.Parent = holder

	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(1, 1)
	panel.Parent = holder

	local function update()
		local guiScale = gui:FindFirstChildOfClass("UIScale")
		local scale = if guiScale then guiScale.Scale else 1
		local areaSize = area.AbsoluteSize / scale
		if areaSize.X <= 0 or areaSize.Y <= 0 then
			return
		end
		local fit = HudLayout.fitMenu(designSize.X, designSize.Y, minHeight, areaSize.X, areaSize.Y)
		holder.Size = UDim2.fromOffset(designSize.X, fit.height)
		fitScale.Scale = fit.scale
	end
	area:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	task.defer(update)
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

return UiKit
