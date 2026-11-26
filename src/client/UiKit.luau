--!strict
-- Small UI helpers and the shared look (colors, font) for all game UI.
-- The rules behind it are written down in docs/ui-style.md; new UI uses UiKit.
-- Everything is sized for touch: buttons are at least 60 px high.
-- Where things sit on screen comes from the HUD grid (src/shared/HudLayout.luau):
-- UiKit.place, UiKit.rightColumn, UiKit.potionColumn and UiKit.placeMenu apply it; the
-- side bar tiles live in src/client/SideBar.luau (#75).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local MenuSwitch = require(ReplicatedStorage.Shared.MenuSwitch)
local Texts = require(ReplicatedStorage.Shared.Texts)
local Lang = require(script.Parent.Lang)
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

function UiKit.stroke(parent: Instance, thickness: number?): UIStroke
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Thickness = thickness or 3
	uiStroke.Color = UiKit.DARK
	uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	uiStroke.Parent = parent
	return uiStroke
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

-- Round icon button (side bar tiles with the sideBar feature off): a circle `size` px wide.
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
	gui.AutoLocalize = false
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

-- Short number for small labels in the player's language (Texts.shortNumber):
-- 999.999 stays as is, then "1,5 Mio", "12 Mrd", "3,4 Bio" / "1.5M", "12B", "3.4T".
UiKit.shortNumber = Lang.shortNumber

-- HUD grid ------------------------------------------------------------------------

UiKit.Layout = HudLayout

-- Is this device a small screen (phone)? Menus then fill nearly the whole screen and
-- scroll instead of shrinking below HudLayout.MENU_MIN_SCALE.
function UiKit.isSmallScreen(): boolean
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return false
	end
	return HudLayout.isSmallScreen(camera.ViewportSize.X, camera.ViewportSize.Y)
end

-- Sets anchor, position and size of `object` from a HUD zone (see HudLayout.zones).
function UiKit.applyZone(object: GuiObject, zone: HudLayout.Zone)
	object.AnchorPoint = Vector2.new(zone.anchor[1], zone.anchor[2])
	object.Position = UDim2.new(zone.position[1], zone.position[2], zone.position[3], zone.position[4])
	object.Size = UDim2.new(zone.size[1], zone.size[2], zone.size[3], zone.size[4])
	local constraint = object:FindFirstChild("ZoneConstraint") :: UISizeConstraint?
	if zone.maxWidth or zone.minHeight then
		if constraint == nil then
			local created = Instance.new("UISizeConstraint")
			created.Name = "ZoneConstraint"
			created.Parent = object
			constraint = created
		end
		local c = constraint :: UISizeConstraint
		c.MinSize = Vector2.new(0, zone.minHeight or 0)
		c.MaxSize = Vector2.new(zone.maxWidth or math.huge, math.huge)
	elseif constraint then
		constraint:Destroy()
	end
end
local applyZone = UiKit.applyZone

-- Puts `object` into a named zone of the HUD grid (see HudLayout.zones).
function UiKit.place(object: GuiObject, zoneName: string)
	applyZone(object, HudLayout.zone(zoneName))
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

-- One shared ScreenGui holds the right column: at the top the active bonuses and the
-- order card, at the bottom (above the jump button) the active potions (#75). Both
-- stacks shrink together when they need more room than the column has (HudLayout.fitStacks).
local grid: { right: Frame, top: Frame, bottom: Frame }? = nil
local function hudGrid(): { right: Frame, top: Frame, bottom: Frame }
	if grid then
		return grid
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "HudGrid"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	UiKit.autoScale(gui)

	local rightArea = zoneFrame(gui, "rightColumn")
	local function stack(name: string, bottom: boolean): (Frame, UIScale)
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BackgroundTransparency = 1
		frame.AnchorPoint = Vector2.new(1, if bottom then 1 else 0)
		frame.Position = UDim2.fromScale(1, if bottom then 1 else 0)
		frame.Size = UDim2.fromScale(1, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.Parent = rightArea
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 8)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		layout.VerticalAlignment = if bottom then Enum.VerticalAlignment.Bottom else Enum.VerticalAlignment.Top
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = frame
		local scale = Instance.new("UIScale")
		scale.Parent = frame
		return frame, scale
	end
	local top, topScale = stack("Stack", false)
	local bottom, bottomScale = stack("Potions", true)

	local function contentHeight(frame: Frame, scale: UIScale): number
		local anyVisible = false
		for _, child in frame:GetChildren() do
			if child:IsA("GuiObject") and child.Visible then
				anyVisible = true
			end
		end
		return if anyVisible then frame.AbsoluteSize.Y / scale.Scale else 0
	end
	local function fitStacks()
		local guiScale = gui:FindFirstChildOfClass("UIScale")
		local factor = if guiScale then guiScale.Scale else 1
		local areaH = rightArea.AbsoluteSize.Y / factor
		if areaH <= 0 then
			return
		end
		local fit = HudLayout.fitStacks(
			contentHeight(top, topScale) / factor,
			contentHeight(bottom, bottomScale) / factor,
			areaH,
			8
		)
		if math.abs(fit.top - topScale.Scale) > 0.01 then
			topScale.Scale = fit.top
		end
		if math.abs(fit.bottom - bottomScale.Scale) > 0.01 then
			bottomScale.Scale = fit.bottom
		end
	end
	top:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitStacks)
	bottom:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitStacks)
	rightArea:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitStacks)
	for _, frame in { top, bottom } do
		frame.ChildAdded:Connect(function(child)
			if child:IsA("GuiObject") then
				child:GetPropertyChangedSignal("Visible"):Connect(fitStacks)
			end
		end)
	end

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	grid = { right = rightArea, top = top, bottom = bottom }
	return grid :: { right: Frame, top: Frame, bottom: Frame }
end

-- Places a "Neu! …" note (child of a side bar tile) where it covers no other tile:
-- right of the button while the buttons stand in a column, above it while they stand
-- in a row (low screens, #52), where the right side holds the next button.
function UiKit.placeSideNote(note: GuiObject, button: GuiObject, gap: number)
	local function update()
		local inRow = false
		local parent = button.Parent
		if parent then
			for _, sibling in parent:GetChildren() do
				if
					sibling ~= button
					and sibling:IsA("GuiObject")
					and sibling.Visible
					and math.abs(sibling.AbsolutePosition.Y - button.AbsolutePosition.Y) < 4
					and sibling.AbsolutePosition.X > button.AbsolutePosition.X
				then
					inRow = true
				end
			end
		end
		if inRow then
			note.AnchorPoint = Vector2.new(0, 1)
			note.Position = UDim2.fromOffset(0, -gap)
		else
			note.AnchorPoint = Vector2.new(0, 0.5)
			note.Position = UDim2.new(1, gap, 0.5, 0)
		end
	end
	button:GetPropertyChangedSignal("AbsolutePosition"):Connect(update)
	task.defer(update)
end

-- Top of the right column: active bonuses (LayoutOrder 1, e.g. friends, weather) and
-- the order card (2). Width is HudLayout.RIGHT_COLUMN_WIDTH; hidden children take no room.
function UiKit.rightColumn(): Frame
	return hudGrid().top
end

-- Bottom of the right column, right above the jump button: the active potion pills.
-- Children stack upwards from the bottom.
function UiKit.potionColumn(): Frame
	return hudGrid().bottom
end

-- Puts `panel` into a HUD zone, designed at `designSize`: it gets shorter down to
-- `minHeight` (panels with a scrolling list) and shrinks only after that (HudLayout.fitMenu).
-- On small screens the zone's small variant is used and the panel never shrinks below
-- HudLayout.MENU_MIN_SCALE: what does not fit scrolls.
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

	-- Only used when the panel is taller than the room (small screens): the whole panel scrolls.
	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "PanelScroller"
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Size = UDim2.fromScale(1, 1)
	scroller.CanvasSize = UDim2.new()
	scroller.ScrollingDirection = Enum.ScrollingDirection.Y
	scroller.ScrollBarThickness = 10
	scroller.ScrollBarImageColor3 = UiKit.DARK
	scroller.Visible = false
	scroller.Parent = holder

	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(1, 1)
	panel.Parent = holder

	local function syncScroller()
		local scrolling = panel.Parent == scroller
		local visible = scrolling and panel.Visible
		if visible and not scroller.Visible then
			scroller.CanvasPosition = Vector2.zero
		end
		scroller.Visible = visible
	end
	panel:GetPropertyChangedSignal("Visible"):Connect(syncScroller)

	local size, shortest = designSize, minHeight
	local function update()
		local small = UiKit.isSmallScreen()
		applyZone(area, HudLayout.zone(zoneName, small))
		local guiScale = gui:FindFirstChildOfClass("UIScale")
		local scale = if guiScale then guiScale.Scale else 1
		local areaSize = area.AbsoluteSize / scale
		if areaSize.X <= 0 or areaSize.Y <= 0 then
			return
		end
		local fit = HudLayout.fitMenu(size.X, size.Y, shortest, areaSize.X, areaSize.Y, HudLayout.menuMinScale(small))
		holder.Size = UDim2.fromOffset(size.X, fit.height)
		fitScale.Scale = fit.scale
		if fit.content then
			-- Inset by 4 px so the panel's stroke is not clipped, room for the scroll bar.
			panel.Parent = scroller
			panel.AnchorPoint = Vector2.zero
			panel.Position = UDim2.fromOffset(4, 4)
			panel.Size = UDim2.new(1, -(8 + scroller.ScrollBarThickness), 0, fit.content - 8)
			scroller.CanvasSize = UDim2.fromOffset(0, fit.content)
		else
			panel.Parent = holder
			panel.AnchorPoint = Vector2.new(0.5, 0.5)
			panel.Position = UDim2.fromScale(0.5, 0.5)
			panel.Size = UDim2.fromScale(1, 1)
		end
		syncScroller()
	end
	area:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	update()
	task.defer(update)
	return function(newSize: Vector2, newMinHeight: number?)
		size, shortest = newSize, newMinHeight
		update()
	end
end

-- Puts a menu panel into the menu area (below currencies and messages, above the
-- auto-collect switch). The panel is designed at `designSize`; it gets shorter down to
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

-- Pet name in the player's language with its variant and Shiny mark (#80):
-- "Gold-Katze", "✨ Regenbogen-Katze" / "Golden Cat", "✨ Rainbow Cat".
function UiKit.petName(petId: string, variant: string?, shiny: boolean?): string
	local name = Lang.name(GameConfig.pets[petId])
	if variant and variant ~= "Normal" and Texts.strings[`pets.name.{variant}`] then
		name = Lang.t(`pets.name.{variant}`, { pet = name })
	end
	if shiny then
		name = Lang.t("pets.name.shiny", { pet = name })
	end
	return name
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

-- A reward of gifts or the login calendar ({ kind = "Gems" | "Potion" | "Pet", amount,
-- potionId?, petId? }) as short text: "10 Gems", "2× Glücks-Trank", "1 Trank",
-- "Kalender-Fuchs" (#101).
function UiKit.rewardText(reward: { kind: string, amount: number, potionId: string?, petId: string? }): string
	if reward.kind == "Gems" then
		return Lang.t("reward.gems", { amount = UiKit.shortNumber(reward.amount) })
	elseif reward.kind == "Coins" then
		return Lang.t("reward.coins", { amount = UiKit.shortNumber(reward.amount) })
	elseif reward.kind == "Pet" then
		local pet = reward.petId and GameConfig.pets[reward.petId]
		local name = if pet then Lang.name(pet) else Lang.t("reward.pet")
		return if reward.amount == 1 then name else `{reward.amount}× {name}`
	end
	local potion = reward.potionId and GameConfig.potions[reward.potionId]
	if potion then
		return `{reward.amount}× {Lang.name(potion)}`
	end
	return if reward.amount == 1
		then Lang.t("reward.potionOne")
		else Lang.t("reward.potionMany", { count = reward.amount })
end

-- Several rewards joined with " + ".
function UiKit.rewardsText(rewards: { { kind: string, amount: number, potionId: string?, petId: string? } }): string
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
