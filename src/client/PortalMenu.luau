--!strict
-- Portal / world menu: opens when the server says the player stands in a portal, closes
-- when they walk out (or tap X). Buttons only send the wish (Teleport); the server
-- checks again and moves the character.
-- The side bar tile "Welten" (#75) asks for the same list from anywhere (PortalPreview);
-- outside a portal it is for viewing only ("Zum Reisen in ein Portal stellen").
--
-- World menu (#78, feature `worldMenu`): every world in GameConfig.worlds is a card with
-- a small live 3D island (theme colours + landmark model, or a fallback shape for
-- worlds whose models are missing). Locked cards are dark with a lock and list what is
-- missing, straight from the rules (rules.portalMenu → entry.missing). Cards are built
-- once and only updated afterwards, so the many state updates stay cheap.
-- Feature off: the old list with one button per world (#43).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local WorldPreview = require(ReplicatedStorage.Shared.WorldPreview)
local Lang = require(script.Parent.Lang)
local SideBar = require(script.Parent.SideBar)
local TileIcon = require(script.Parent.TileIcon)
local Juice = require(script.Parent.Juice)
local UiKit = require(script.Parent.UiKit)

type PortalEntry = GameRules.PortalEntry

local features = Features.new(GameConfig.features)
local cardsEnabled = features.enabled("worldMenu")

local ROW_HEIGHT = 84
local HEADER_HEIGHT = 92
-- Cards: 3 per row on the 720 px panel, the grid scrolls (phones: at least one row).
local CARD_SIZE = Vector2.new(212, 224)
local CARD_GAP = 12
local PANEL_SIZE = if cardsEnabled then Vector2.new(720, 520) else Vector2.new(520, 440)
local MIN_PANEL_HEIGHT = if cardsEnabled then HEADER_HEIGHT + CARD_SIZE.Y + 24 else HEADER_HEIGHT + ROW_HEIGHT + 16
local PURPLE = Color3.fromRGB(150, 90, 230)
local GREY = Color3.fromRGB(170, 165, 160)
local HERE = Color3.fromRGB(240, 170, 60)
local LOCKED_TINT = Color3.fromRGB(90, 85, 95)
local MUTED = Color3.fromRGB(110, 80, 55)

local PortalMenu = {}

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

-- "Ab 1 Rebirth" / "Ab 3 Rebirths" (#43).
local function rebirthsText(count: number): string
	return Lang.t(if count == 1 then "unlock.rebirthsOne" else "unlock.rebirthsMany", { count = count })
end

-- "Erst Strand · 2 Rebirths · 5 Mio Münzen" from the rules' missing list (#78).
local function missingText(entry: PortalEntry): string
	local parts = {}
	for _, need in entry.missing do
		if need.kind == "PreviousWorld" and need.worldId then
			table.insert(parts, Lang.t("worldMenu.missingPrevious", { world = Lang.worldName(need.worldId) }))
		elseif need.kind == "Rebirths" then
			local count = need.amount or 0
			table.insert(
				parts,
				Lang.t(if count == 1 then "worldMenu.missingRebirthsOne" else "worldMenu.missingRebirthsMany", {
					count = count,
				})
			)
		elseif need.kind == "Coins" then
			table.insert(parts, Lang.t("worldMenu.missingCoins", { amount = Lang.shortNumber(need.amount or 0) }))
		end
	end
	return table.concat(parts, "\n")
end

-- ------------------------------------------------------------------ 3D preview
local function addPart(model: Model, props: { [string]: any })
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = model
end

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

-- A little floating island: grass disc on a narrowing rock base, the world's landmark
-- model on top or, when it is missing (worlds 8-15 before their import), a simple
-- landmark of parts in the world colour.
local function islandModel(world: any): Model
	local preview = WorldPreview.forWorld(world, GameConfig.islands and GameConfig.islands.themes)
	local model = Instance.new("Model")
	model.Name = `Preview_{world.id}`
	addPart(model, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 10, 10),
		CFrame = CFrame.new(0, 0, 0) * UPRIGHT,
		Color = rgb(preview.ground),
	})
	addPart(model, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.6, 8.6, 8.6),
		CFrame = CFrame.new(0, -1.3, 0) * UPRIGHT,
		Color = rgb(preview.cliff),
	})
	addPart(model, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.6, 5.4, 5.4),
		CFrame = CFrame.new(0, -2.8, 0) * UPRIGHT,
		Color = rgb(preview.cliff):Lerp(Color3.new(0, 0, 0), 0.2),
	})

	local top = CFrame.new(0.6, 0.5, 0.6)
	local placed = preview.landmark ~= nil
		and ModelLibrary.has(preview.landmark)
		and ModelLibrary.place(preview.landmark :: string, 5, top, model)
	if not placed then
		local accent = rgb(preview.accent)
		addPart(model, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3, 2.6, 2.6),
			CFrame = top * CFrame.new(0, 1.5, 0) * UPRIGHT,
			Color = accent:Lerp(Color3.new(1, 1, 1), 0.3),
		})
		addPart(model, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2.8,
			CFrame = top * CFrame.new(0, 3.6, 0),
			Color = accent,
		})
	end
	-- A tree and a bush, so even the fallback reads as an island.
	addPart(model, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2.2,
		CFrame = CFrame.new(-3, 1.6, -1.5),
		Color = rgb(preview.ground):Lerp(Color3.new(0, 0, 0), 0.25),
	})
	addPart(model, {
		Size = Vector3.new(0.5, 1.2, 0.5),
		CFrame = CFrame.new(-3, 0.9, -1.5),
		Color = Color3.fromRGB(140, 95, 60),
	})
	addPart(model, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.2,
		CFrame = CFrame.new(-1, 0.8, -3.4),
		Color = rgb(preview.ground):Lerp(Color3.new(0, 0, 0), 0.15),
	})
	return model
end

-- ------------------------------------------------------------------ cards
type Card = {
	frame: Frame,
	view: ViewportFrame,
	lock: TextLabel,
	name: TextLabel,
	status: TextLabel,
	travel: TextButton,
}

local function buildCard(parent: Instance, world: any, index: number, onTravel: () -> ()): Card
	local frame = Instance.new("Frame")
	frame.Name = `World_{world.id}`
	frame.LayoutOrder = index
	frame.BackgroundColor3 = UiKit.CREAM
	UiKit.corner(frame, 18)
	UiKit.stroke(frame, 3)
	frame.Parent = parent

	local accent = rgb(WorldPreview.forWorld(world, nil).accent)
	local sky = Instance.new("Frame")
	sky.Name = "Preview"
	sky.Position = UDim2.fromOffset(8, 8)
	sky.Size = UDim2.new(1, -16, 0, 104)
	sky.BackgroundColor3 = accent:Lerp(Color3.new(1, 1, 1), 0.6)
	sky.ClipsDescendants = true
	UiKit.corner(sky, 14)
	sky.Parent = frame
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200))
	gradient.Parent = sky

	local view = TileIcon.buildModel(sky, islandModel(world))

	local number = UiKit.label(sky, tostring(index))
	number.Name = "Number"
	number.Position = UDim2.fromOffset(6, 6)
	number.Size = UDim2.fromOffset(34, 34)
	number.BackgroundTransparency = 0
	number.BackgroundColor3 = accent
	number.TextColor3 = UiKit.CREAM
	number.ZIndex = 5
	UiKit.corner(number, 17)
	UiKit.stroke(number, 2)

	local lock = UiKit.label(sky, "🔒")
	lock.Name = "Lock"
	lock.AnchorPoint = Vector2.new(0.5, 0.5)
	lock.Position = UDim2.fromScale(0.5, 0.5)
	lock.Size = UDim2.fromOffset(56, 56)
	lock.ZIndex = 5

	local name = UiKit.label(frame, Lang.worldName(world.id))
	name.Name = "WorldName"
	name.Position = UDim2.fromOffset(10, 116)
	name.Size = UDim2.new(1, -20, 0, 30)

	local status = UiKit.label(frame, "")
	status.Name = "Status"
	status.Position = UDim2.fromOffset(10, 150)
	status.Size = UDim2.new(1, -20, 0, 66)
	status.TextColor3 = MUTED

	local travel = UiKit.button(frame, Lang.t("worldMenu.travel"), PURPLE)
	travel.Name = "Travel"
	travel.AnchorPoint = Vector2.new(0.5, 1)
	travel.Position = UDim2.new(0.5, 0, 1, -10)
	travel.Size = UDim2.new(1, -24, 0, UiKit.MIN_TOUCH)
	travel.Activated:Connect(function()
		UiKit.pop(travel)
		onTravel()
	end)

	return { frame = frame, view = view, lock = lock, name = name, status = status, travel = travel }
end

local function updateCard(card: Card, entry: PortalEntry, here: boolean, preview: boolean)
	local locked = not entry.unlocked
	card.lock.Visible = locked
	card.view.ImageColor3 = if locked then LOCKED_TINT else Color3.new(1, 1, 1)
	card.frame.BackgroundColor3 = if locked then UiKit.GREY:Lerp(UiKit.CREAM, 0.35) else UiKit.CREAM
	card.name.Text = Lang.worldName(entry.worldId)
	card.travel.Visible = entry.unlocked and not here and not preview
	card.status.TextColor3 = MUTED
	if here then
		card.status.Text = Lang.t("worldMenu.here")
		card.status.TextColor3 = HERE
	elseif entry.unlocked then
		card.status.Text = if preview then Lang.t("worldMenu.open") else ""
	elseif entry.canUnlock then
		card.status.Text = `{Lang.t("worldMenu.canUnlock")}\n{Lang.t("worldMenu.price", {
			price = Lang.shortNumber(entry.unlockPrice),
		})}`
		card.status.TextColor3 = Color3.fromRGB(70, 150, 60)
	else
		card.status.Text = `{Lang.t("worldMenu.missing")}\n{missingText(entry)}`
	end
	-- Travel button and status share the lower part of the card.
	card.status.Size = if card.travel.Visible then UDim2.new(1, -20, 0, 0) else UDim2.new(1, -20, 0, 66)
end

function PortalMenu.start()
	local player = Players.LocalPlayer
	local teleport = Net.event("Teleport")
	local portalPreview = Net.event("PortalPreview")

	local gui = Instance.new("ScreenGui")
	gui.Name = "PortalMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Enabled = false
	UiKit.autoScale(gui)

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = UiKit.CREAM
	UiKit.corner(panel, 24)
	UiKit.stroke(panel, 4)
	UiKit.placeMenu(gui, panel, PANEL_SIZE, MIN_PANEL_HEIGHT)

	local title = UiKit.label(panel, Lang.t(if cardsEnabled then "worldMenu.title" else "portal.title"))
	title.Position = UDim2.fromOffset(20, 12)
	title.Size = UDim2.new(1, -120, 0, 52)
	title.TextXAlignment = Enum.TextXAlignment.Left

	-- Viewing only (opened from the side bar outside a portal) or, with cards, the
	-- number of unlocked worlds.
	local subtitle = UiKit.label(panel, Lang.t("portal.preview"))
	subtitle.Position = UDim2.fromOffset(20, 62)
	subtitle.Size = UDim2.new(1, -120, 0, 22)
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.TextColor3 = MUTED
	subtitle.Visible = false

	local closeButton = UiKit.button(panel, "X", UiKit.RED)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -12, 0, 10)
	closeButton.Size = UDim2.fromOffset(64, 64)

	local list = Instance.new("ScrollingFrame")
	list.Name = "Worlds"
	list.Position = UDim2.fromOffset(16, HEADER_HEIGHT)
	list.Size = UDim2.new(1, -32, 1, -(HEADER_HEIGHT + 12))
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 10
	list.ScrollBarImageColor3 = UiKit.DARK
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.Parent = panel
	if cardsEnabled then
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
		grid.CellPadding = UDim2.fromOffset(CARD_GAP, CARD_GAP)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
		grid.Parent = list
	else
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 10)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = list
	end
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = list

	local function clear()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	-- Old list (feature worldMenu off).
	local function renderList(currentWorldId: string, entries: { PortalEntry }, preview: boolean)
		clear()
		subtitle.Text = Lang.t("portal.preview")
		subtitle.Visible = preview
		for index, entry in entries do
			local here = entry.worldId == currentWorldId
			local text, color
			if not entry.unlocked and not entry.enoughRebirths then
				-- Behind rebirths (#43): the condition first, the price below.
				text = Lang.t("portal.lockedRebirths", {
					world = Lang.worldName(entry.worldId),
					condition = rebirthsText(entry.requiredRebirths),
					price = Lang.integer(entry.unlockPrice),
				})
				color = GREY
			elseif not entry.unlocked then
				text = Lang.t(
					"portal.locked",
					{ world = Lang.worldName(entry.worldId), price = Lang.integer(entry.unlockPrice) }
				)
				color = GREY
			elseif here then
				text = Lang.t("portal.here", { world = Lang.worldName(entry.worldId) })
				color = HERE
			else
				text = `{index}. {Lang.worldName(entry.worldId)}`
				color = PURPLE
			end
			local row = UiKit.button(list, text, color)
			row.LayoutOrder = index
			row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
			row.TextXAlignment = Enum.TextXAlignment.Left
			if entry.unlocked and not here and not preview then
				row.Activated:Connect(function()
					UiKit.pop(row)
					teleport:FireServer(entry.worldId)
					Juice.teleportSwirl()
				end)
			else
				-- Greyed out / current world: not selectable.
				row.AutoButtonColor = false
				row.Active = false
				if not entry.unlocked then
					row.TextTransparency = 0.25
				end
			end
		end
	end

	-- Cards (#78): one per configured world, built on first use.
	local cards: { [string]: Card } = {}
	local function renderCards(currentWorldId: string, entries: { PortalEntry }, preview: boolean)
		local open = 0
		for _, entry in entries do
			if entry.unlocked then
				open += 1
			end
		end
		subtitle.Visible = true
		subtitle.Text = if preview
			then Lang.t("portal.preview")
			else Lang.t("worldMenu.count", { open = open, total = #entries })
		for _, entry in entries do
			local card = cards[entry.worldId]
			if card == nil then
				local world = { id = entry.worldId }
				for _, configured in GameConfig.worlds do
					if configured.id == entry.worldId then
						world = configured :: any
					end
				end
				local worldId = entry.worldId
				card = buildCard(list, world, entry.index or 0, function()
					teleport:FireServer(worldId)
					Juice.teleportSwirl()
				end)
				cards[entry.worldId] = card
			end
			updateCard(card, entry, entry.worldId == currentWorldId, preview)
		end
	end

	local function render(currentWorldId: string, entries: { PortalEntry }, preview: boolean)
		if cardsEnabled then
			renderCards(currentWorldId, entries, preview)
		else
			renderList(currentWorldId, entries, preview)
		end
	end

	-- The server re-sends PortalOpen on every state change while the player stands in the
	-- portal (and, throttled, while the viewing-only list is open). Once closed ("X" or
	-- another menu opening), it stays closed until the player leaves the portal.
	local dismissed = false
	-- Showing the viewing-only list (side bar) rather than a portal's menu.
	local previewing = false
	-- The side bar tile asked for the list: show the next answer even if dismissed.
	local requested = false

	local function close()
		if gui.Enabled then
			gui.Enabled = false
			dismissed = not previewing
			if previewing then
				-- Stop the server's live updates of the viewing-only list.
				portalPreview:FireServer(false)
			end
		end
	end
	UiKit.registerMenu("portal", close)

	SideBar.register({
		id = "worlds",
		order = 60,
		text = Lang.t("side.worlds"),
		color = PURPLE,
		icon = { model = "PortalArch", shape = "portal" },
		open = function()
			if gui.Enabled then
				close()
				return
			end
			requested = true
			portalPreview:FireServer(true)
		end,
	})

	Net.event("PortalOpen").OnClientEvent
		:Connect(function(currentWorldId: string, entries: { PortalEntry }, preview: boolean?)
			if dismissed and not requested then
				return
			end
			if preview and not requested and not (gui.Enabled and previewing) then
				return
			end
			if requested then
				requested = false
				dismissed = false
			end
			local wasOpen = gui.Enabled
			previewing = preview == true
			render(currentWorldId, entries, previewing)
			gui.Enabled = true
			if not wasOpen then
				UiKit.menuOpened("portal")
				UiKit.pop(panel, 0.85)
			end
		end)

	Net.event("PortalClose").OnClientEvent:Connect(function()
		gui.Enabled = false
		dismissed = false
		previewing = false
	end)

	closeButton.Activated:Connect(close)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return PortalMenu
