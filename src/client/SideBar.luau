--!strict
-- The side bar on the left of the HUD (#75): glossy rounded tiles (gradient, thick dark
-- rim, a slightly tilted live 3D icon, press bounce) that open the menus, with a red dot
-- while a menu has news. One column on PC, two columns above the joystick on phones;
-- tiles that do not fit go behind a "More" tile (HudLayout.sideBarGrid, SideBarModel).
--
-- A menu joins the bar with one call and reports news with another:
--
--   local button = SideBar.register({
--       id = "gifts", order = 30, text = Lang.t("side.gifts"), color = UiKit.PINK,
--       icon = { shape = "gift" },            -- or { model = "DoughHamster", shape = "pet" }
--       open = toggleGiftMenu,                -- called on tap (also from the More popup)
--   })
--   SideBar.setBadge("gifts", true)            -- red dot on / off
--   SideBar.setCaption("gifts", "4:59")        -- text under the icon (nil = back to `text`)
--
-- `order` (smaller = higher up / further left): pets 10, potions 20, gifts 30,
-- calendar 40, rebirth 50, worlds 60; later menus pick free numbers (docs/ui-style.md).
-- With GameConfig.features.sideBar off the tiles are plain round buttons without dots.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local SideBarModel = require(ReplicatedStorage.Shared.SideBarModel)
local Lang = require(script.Parent.Lang)
local TileIcon = require(script.Parent.TileIcon)
local UiKit = require(script.Parent.UiKit)

export type Spec = {
	id: string,
	order: number,
	text: string,
	color: Color3,
	icon: TileIcon.Icon?,
	open: () -> (),
}

type Tile = {
	spec: Spec,
	button: TextButton,
	caption: TextLabel?,
	dot: Frame?,
}

local SideBar = {}

local features = Features.new(GameConfig.features)
local glossy = features.enabled("sideBar")
local model = SideBarModel.new()
local tiles: { [string]: Tile } = {}

local MORE_ID = "more"
local MORE_COLOR = Color3.fromRGB(120, 110, 105)
local POPUP_TILE = 96
local POPUP_GAP = 12
local POPUP_COLUMNS = 4

local function shade(color: Color3, factor: number): Color3
	return Color3.new(color.R * factor, color.G * factor, color.B * factor)
end

-- Press bounce: squeeze while held, spring back when let go.
local function addBounce(button: GuiButton)
	local scale = Instance.new("UIScale")
	scale.Name = "Press"
	scale.Parent = button
	local function to(value: number, style: Enum.EasingStyle, seconds: number)
		TweenService:Create(scale, TweenInfo.new(seconds, style, Enum.EasingDirection.Out), { Scale = value }):Play()
	end
	button.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			to(0.88, Enum.EasingStyle.Quad, 0.08)
		elseif kind == Enum.UserInputType.MouseMovement then
			to(1.06, Enum.EasingStyle.Quad, 0.12)
		end
	end)
	button.InputEnded:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			to(1, Enum.EasingStyle.Back, 0.3)
		elseif kind == Enum.UserInputType.MouseMovement then
			to(1, Enum.EasingStyle.Quad, 0.12)
		end
	end)
end

-- Red dot in the top right corner, gently pulsing while visible.
local function addDot(button: GuiObject): Frame
	local dot = Instance.new("Frame")
	dot.Name = "RedDot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(1, -6, 0, 6)
	dot.Size = UDim2.fromScale(0.3, 0.3)
	dot.BackgroundColor3 = UiKit.RED
	dot.ZIndex = 6
	dot.Visible = false
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.Parent = dot
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = dot
	local rim = Instance.new("UIStroke")
	rim.Thickness = 2
	rim.Color = UiKit.DARK
	rim.Parent = dot
	local shine = Instance.new("Frame")
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.35
	shine.Position = UDim2.fromScale(0.22, 0.18)
	shine.Size = UDim2.fromScale(0.3, 0.3)
	shine.ZIndex = 7
	local shineRound = Instance.new("UICorner")
	shineRound.CornerRadius = UDim.new(0.5, 0)
	shineRound.Parent = shine
	shine.Parent = dot
	local pulse = Instance.new("UIScale")
	pulse.Parent = dot
	local tween = TweenService:Create(
		pulse,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.18 }
	)
	dot:GetPropertyChangedSignal("Visible"):Connect(function()
		if dot.Visible then
			tween:Play()
		else
			tween:Cancel()
			pulse.Scale = 1
		end
	end)
	dot.Parent = button
	return dot
end

-- One glossy tile: gradient body, gloss on the upper half, live 3D icon, caption.
local function buildTile(parent: Instance, spec: Spec): (TextButton, TextLabel?, Frame?)
	if not glossy then
		local round = UiKit.roundButton(parent, spec.text, spec.color, HudLayout.SIDE_BAR.tile)
		round.Name = spec.id
		return round, nil, nil
	end
	local button = Instance.new("TextButton")
	button.Name = spec.id
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundColor3 = spec.color:Lerp(Color3.new(1, 1, 1), 0.2)
	button.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.24, 0)
	corner.Parent = button
	local rim = Instance.new("UIStroke")
	rim.Thickness = 4
	rim.Color = UiKit.DARK
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Parent = button
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.55, shade(Color3.new(1, 1, 1), 0.9)),
		ColorSequenceKeypoint.new(1, shade(Color3.new(1, 1, 1), 0.68)),
	})
	gradient.Parent = button

	-- Gloss: a soft white band over the upper half.
	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.BackgroundTransparency = 0.45
	gloss.Position = UDim2.new(0.08, 0, 0.05, 0)
	gloss.Size = UDim2.fromScale(0.84, 0.42)
	gloss.ZIndex = 2
	local glossCorner = Instance.new("UICorner")
	glossCorner.CornerRadius = UDim.new(0.4, 0)
	glossCorner.Parent = gloss
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = gloss
	gloss.Parent = button

	local iconHolder = Instance.new("Frame")
	iconHolder.Name = "Icon"
	iconHolder.BackgroundTransparency = 1
	iconHolder.AnchorPoint = Vector2.new(0.5, 0)
	iconHolder.Position = UDim2.fromScale(0.5, 0.02)
	iconHolder.Size = UDim2.fromScale(0.82, 0.72)
	iconHolder.ZIndex = 3
	iconHolder.Parent = button
	TileIcon.build(iconHolder, spec.icon or { shape = "star" })

	local caption = UiKit.label(button, spec.text)
	caption.Name = "Caption"
	caption.AnchorPoint = Vector2.new(0.5, 1)
	caption.Position = UDim2.new(0.5, 0, 1, -3)
	caption.Size = UDim2.new(1, -8, 0.27, 0)
	caption.TextColor3 = UiKit.CREAM
	caption.ZIndex = 5
	local textStroke = Instance.new("UIStroke")
	textStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	textStroke.Color = UiKit.DARK
	textStroke.Thickness = 2
	textStroke.Parent = caption

	addBounce(button)
	local dot = addDot(button)
	button.Parent = parent
	return button, caption, dot
end

-- Bar ------------------------------------------------------------------------------

local bar: { gui: ScreenGui, area: Frame }? = nil
local moreTile: Tile? = nil
local popup: { gui: ScreenGui, panel: Frame, grid: Frame }? = nil
local hiddenIds: { string } = {}
local relayoutQueued = false

local function isTouch(): boolean
	return UserInputService.TouchEnabled
end

local function refreshDots()
	for id, tile in tiles do
		if tile.dot then
			tile.dot.Visible = model.badge(id)
		end
	end
end

local closePopup: () -> () = function() end
local openPopup: () -> () = function() end

local function relayout()
	relayoutQueued = false
	local current = bar
	if current == nil then
		return
	end
	local small = UiKit.isSmallScreen()
	UiKit.applyZone(current.area, HudLayout.sideBarZone(small, isTouch()))
	local guiScale = current.gui:FindFirstChildOfClass("UIScale")
	local scale = if guiScale then guiScale.Scale else 1
	local size = current.area.AbsoluteSize / scale
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local count = 0
	for _ in tiles do
		count += 1
	end
	local grid = HudLayout.sideBarGrid({ x = 0, y = 0, w = size.X, h = size.Y }, count, small)
	local arranged = model.arrange(grid.capacity)
	local function put(button: GuiObject, index: number)
		local place = grid.places[index]
		button.Position = UDim2.fromOffset(place.x, place.y)
		button.Size = UDim2.fromOffset(place.w, place.h)
		button.Visible = true
	end
	for index, id in arranged.shown do
		put(tiles[id].button, index)
	end
	for _, id in arranged.hidden do
		tiles[id].button.Visible = false
	end
	hiddenIds = arranged.hidden
	local more = moreTile
	if more then
		if arranged.more then
			put(more.button, #arranged.shown + 1)
			if more.dot then
				more.dot.Visible = arranged.moreBadge
			end
		else
			more.button.Visible = false
			closePopup()
		end
	end
	refreshDots()
end

local function queueRelayout()
	if relayoutQueued then
		return
	end
	relayoutQueued = true
	task.defer(relayout)
end

local function ensureBar(): { gui: ScreenGui, area: Frame }
	if bar then
		return bar
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SideBar"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	UiKit.autoScale(gui)
	local area = Instance.new("Frame")
	area.Name = "Tiles"
	area.BackgroundTransparency = 1
	area.Active = false
	UiKit.applyZone(area, HudLayout.sideBarZone(UiKit.isSmallScreen(), isTouch()))
	area.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	bar = { gui = gui, area = area }

	-- "More" tile: opens a popup with the tiles that do not fit.
	local moreSpec: Spec = {
		id = MORE_ID,
		order = math.huge,
		text = Lang.t("side.more"),
		color = MORE_COLOR,
		icon = { shape = "more" },
		open = function()
			openPopup()
		end,
	}
	local button, caption, dot = buildTile(area, moreSpec)
	button.Visible = false
	button.Activated:Connect(moreSpec.open)
	moreTile = { spec = moreSpec, button = button, caption = caption, dot = dot }

	area:GetPropertyChangedSignal("AbsoluteSize"):Connect(queueRelayout)
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(queueRelayout)
	end
	return bar :: { gui: ScreenGui, area: Frame }
end

-- More popup ---------------------------------------------------------------------------

local function ensurePopup(): { gui: ScreenGui, panel: Frame, grid: Frame }
	if popup then
		return popup
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SideBarMore"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	UiKit.autoScale(gui)
	local width = POPUP_COLUMNS * POPUP_TILE + (POPUP_COLUMNS - 1) * POPUP_GAP + 48
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = UiKit.CREAM
	panel.Visible = false
	UiKit.corner(panel, 24)
	UiKit.stroke(panel, 4)
	UiKit.placeMenu(gui, panel, Vector2.new(width, 96 + 2 * (POPUP_TILE + POPUP_GAP) + 12))

	local title = UiKit.label(panel, Lang.t("side.moreTitle"))
	title.Position = UDim2.fromOffset(24, 14)
	title.Size = UDim2.new(1, -120, 0, 48)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local closeButton = UiKit.button(panel, "X", UiKit.RED)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -14, 0, 14)
	closeButton.Size = UDim2.fromOffset(72, 72)
	closeButton.Activated:Connect(function()
		closePopup()
	end)

	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Tiles"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.fromOffset(24, 96)
	grid.Size = UDim2.new(1, -48, 1, -108)
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.ScrollBarThickness = 8
	grid.Parent = panel
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(POPUP_TILE, POPUP_TILE)
	layout.CellPadding = UDim2.fromOffset(POPUP_GAP, POPUP_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.Parent = grid

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	popup = { gui = gui, panel = panel, grid = grid :: any }
	return popup :: { gui: ScreenGui, panel: Frame, grid: Frame }
end

closePopup = function()
	local current = popup
	if current then
		current.panel.Visible = false
	end
end

openPopup = function()
	local current = ensurePopup()
	if current.panel.Visible then
		closePopup()
		return
	end
	for _, child in current.grid:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	for index, id in hiddenIds do
		local tile = tiles[id]
		local caption = if tile.caption then tile.caption.Text else tile.spec.text
		local copy, _, dot = buildTile(current.grid, {
			id = id,
			order = tile.spec.order,
			text = caption,
			color = tile.spec.color,
			icon = tile.spec.icon,
			open = tile.spec.open,
		})
		copy.LayoutOrder = index
		if dot then
			dot.Visible = model.badge(id)
		end
		copy.Activated:Connect(function()
			closePopup()
			tile.spec.open()
		end)
	end
	current.panel.Visible = true
	UiKit.menuOpened(MORE_ID)
	UiKit.pop(current.panel)
end

UiKit.registerMenu(MORE_ID, function()
	closePopup()
end)

-- API ------------------------------------------------------------------------------

-- Adds a tile for a menu (see the top of this file). Returns its button, e.g. for a
-- "New!" note (UiKit.placeSideNote) or an extra badge.
function SideBar.register(spec: Spec): TextButton
	assert(spec.id ~= MORE_ID, `"{MORE_ID}" is reserved for the More tile`)
	model.register(spec.id, spec.order)
	local current = ensureBar()
	local button, caption, dot = buildTile(current.area, spec)
	button.LayoutOrder = spec.order
	button.Visible = false
	button.Activated:Connect(function()
		spec.open()
	end)
	tiles[spec.id] = { spec = spec, button = button, caption = caption, dot = dot }
	queueRelayout()
	return button
end

-- Red dot on the tile `id` (and on "More" while that tile hides behind it). Works before
-- the tile registered; does nothing visible with the sideBar feature off.
function SideBar.setBadge(id: string, on: boolean)
	if model.badge(id) == (on == true) then
		return
	end
	model.setBadge(id, on)
	if tiles[id] and tiles[id].dot then
		(tiles[id].dot :: Frame).Visible = on == true
	end
	queueRelayout()
end

-- Text under the icon (e.g. a countdown); nil shows the tile's name again.
function SideBar.setCaption(id: string, text: string?)
	local tile = tiles[id]
	if tile == nil then
		return
	end
	local shown = text or tile.spec.text
	if tile.caption then
		tile.caption.Text = shown
	else
		tile.button.Text = shown
	end
end

-- The tile's button (nil before it registered).
function SideBar.button(id: string): TextButton?
	local tile = tiles[id]
	return tile and tile.button
end

return SideBar
