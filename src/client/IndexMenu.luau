--!strict
-- Pet index and topping index (#95) on the client: side bar tile "Index" (order 90) and
-- one menu with two tabs (only the switched-on ones: features.petIndex / toppingIndex).
-- * Pets: one world per page (◀ ▶, starts at the current world), a card per egg pet of
--   the world (3D view, black silhouette + "???" while not found) with three stars
--   Gold / Rainbow / Shiny (no reward), the world's progress and its coin bonus
--   (GameConfig.petIndex.worldBonus once every pet was found), the total index bonus.
-- * Toppings: same pages, a card per topping with two halves: normal and golden.
-- Only the current page has 3D views. Reads the Index attribute (JSON, see IndexService);
-- nothing is sent to the server. Red dot: something new was found since the menu was
-- last opened (this session).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Lang = require(script.Parent.Lang)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local SideBar = require(script.Parent.SideBar)
local UiKit = require(script.Parent.UiKit)

local TILE_ID = "index"
local TILE_COLOR = Color3.fromRGB(70, 160, 220)
local PANEL_SIZE = Vector2.new(700, 760)
local HEADER_HEIGHT = 250
local MIN_HEIGHT = HEADER_HEIGHT + 170
local CARD_COLOR = Color3.fromRGB(255, 236, 200)
local DONE_COLOR = Color3.fromRGB(210, 240, 200)
local HINT_COLOR = Color3.fromRGB(110, 80, 55)
local SILHOUETTE = Color3.fromRGB(20, 12, 8)
local GOLD_TINT = Color3.fromRGB(255, 215, 80)
local STAR_OFF = Color3.fromRGB(205, 195, 185)
local STARS = {
	{ field = "gold", color = Color3.fromRGB(255, 200, 40) },
	{ field = "rainbow", color = Color3.fromRGB(200, 90, 255) },
	{ field = "shiny", color = Color3.fromRGB(255, 120, 190) },
}
local PET_CELL = Vector2.new(124, 168)
local TOPPING_CELL = Vector2.new(196, 196)

type PetEntry = { petId: string, found: boolean, gold: boolean, rainbow: boolean, shiny: boolean }
type PetWorld = {
	worldId: string,
	pets: { PetEntry },
	found: number,
	total: number,
	complete: boolean,
	stars: number,
	starsTotal: number,
}
type ToppingEntry = { toppingId: string, normal: boolean, golden: boolean }
type ToppingWorld = { worldId: string, toppings: { ToppingEntry }, found: number, total: number }
type Index = {
	pets: { worlds: { PetWorld }, found: number, total: number, completeWorlds: number }?,
	toppings: { worlds: { ToppingWorld }, found: number, total: number }?,
	bonus: number,
	worldBonus: number,
}

local IndexMenu = {}

local function readIndex(player: Player): Index?
	local json = player:GetAttribute("Index")
	if type(json) ~= "string" then
		return nil
	end
	local ok, value = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok or type(value) ~= "table" then
		return nil
	end
	return value :: Index
end

local function worldNumber(worldId: string): number
	for i, world in GameConfig.worlds do
		if world.id == worldId then
			return i
		end
	end
	return 0
end

-- Found entries + stars of both tabs: grows whenever something new was found.
local function progressCount(index: Index?): number
	if index == nil then
		return 0
	end
	local count = 0
	if index.pets then
		count += index.pets.found
		for _, world in index.pets.worlds do
			count += world.stars
		end
	end
	if index.toppings then
		count += index.toppings.found
	end
	return count
end

-- 3D view of a pet or topping in `holder`; `tint` colours it (silhouette, gold).
-- Without the Studio import: a circle with the initial (or "?").
local function modelView(holder: GuiObject, modelName: string, fallbackText: string, tint: Color3?)
	local view = ModelLibrary.viewport(modelName)
	if view then
		view.AnchorPoint = Vector2.new(0.5, 0.5)
		view.Position = UDim2.fromScale(0.5, 0.5)
		view.Size = UDim2.fromScale(1.2, 1.2)
		view.ZIndex = holder.ZIndex + 1
		if tint then
			view.ImageColor3 = tint
		end
		view.Parent = holder
		return
	end
	local initial = UiKit.label(holder, fallbackText)
	initial.AnchorPoint = Vector2.new(0.5, 0.5)
	initial.Position = UDim2.fromScale(0.5, 0.5)
	initial.Size = UDim2.fromScale(0.6, 0.6)
end

local function circle(parent: Instance, size: number, color: Color3, position: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = position
	frame.Size = UDim2.fromOffset(size, size)
	frame.BackgroundColor3 = color
	UiKit.corner(frame, size / 2)
	UiKit.stroke(frame, 3)
	frame.Parent = parent
	return frame
end

local function initialOf(name: string): string
	return utf8.char(utf8.codepoint(name, 1))
end

function IndexMenu.start()
	local features = Features.new(GameConfig.features)
	local petsOn, toppingsOn = features.enabled("petIndex"), features.enabled("toppingIndex")
	if not petsOn and not toppingsOn then
		return
	end
	local player = Players.LocalPlayer

	local gui = Instance.new("ScreenGui")
	gui.Name = "IndexMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	UiKit.autoScale(gui)

	local toggle: () -> () = function() end
	local tileButton = SideBar.register({
		id = TILE_ID,
		order = 90,
		text = Lang.t("side.index"),
		color = TILE_COLOR,
		icon = { shape = "star" },
		open = function()
			toggle()
		end,
	})

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = UiKit.CREAM
	panel.Visible = false
	UiKit.corner(panel, 24)
	UiKit.stroke(panel, 4)
	UiKit.placeMenu(gui, panel, PANEL_SIZE, MIN_HEIGHT)

	local title = UiKit.label(panel, Lang.t("index.title"))
	title.Position = UDim2.fromOffset(24, 12)
	title.Size = UDim2.new(1, -120, 0, 48)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local closeButton = UiKit.button(panel, "X", UiKit.RED)
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -14, 0, 14)
	closeButton.Size = UDim2.fromOffset(72, 72)

	-- Tabs (only the switched-on ones) and the total line beside them.
	local tabs: { [string]: TextButton } = {}
	local tabOrder: { string } = {}
	if petsOn then
		table.insert(tabOrder, "pets")
	end
	if toppingsOn then
		table.insert(tabOrder, "toppings")
	end
	for i, tabId in tabOrder do
		local key = if tabId == "pets" then "index.tabPets" else "index.tabToppings"
		local tab = UiKit.button(panel, Lang.t(key), UiKit.GREY)
		tab.Position = UDim2.fromOffset(24 + (i - 1) * 196, 92)
		tab.Size = UDim2.fromOffset(184, 60)
		tabs[tabId] = tab
	end
	local totalLabel = UiKit.label(panel, "")
	totalLabel.AnchorPoint = Vector2.new(1, 0)
	totalLabel.Position = UDim2.new(1, -24, 0, 104)
	totalLabel.Size = UDim2.new(1, -24 - #tabOrder * 196 - 24, 0, 36)
	totalLabel.TextXAlignment = Enum.TextXAlignment.Right

	-- World pages.
	local previousButton = UiKit.button(panel, Lang.t("index.previous"), UiKit.ORANGE)
	previousButton.Position = UDim2.fromOffset(24, 164)
	previousButton.Size = UDim2.fromOffset(64, 64)
	local nextButton = UiKit.button(panel, Lang.t("index.next"), UiKit.ORANGE)
	nextButton.AnchorPoint = Vector2.new(1, 0)
	nextButton.Position = UDim2.new(1, -24, 0, 164)
	nextButton.Size = UDim2.fromOffset(64, 64)
	local worldLabel = UiKit.label(panel, "")
	worldLabel.Position = UDim2.fromOffset(100, 162)
	worldLabel.Size = UDim2.new(1, -200, 0, 38)
	local infoLabel = UiKit.label(panel, "")
	infoLabel.Position = UDim2.fromOffset(100, 200)
	infoLabel.Size = UDim2.new(1, -200, 0, 28)
	infoLabel.TextColor3 = HINT_COLOR

	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Cards"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.fromOffset(12, HEADER_HEIGHT)
	grid.Size = UDim2.new(1, -24, 1, -HEADER_HEIGHT - 12)
	grid.ScrollBarThickness = 8
	grid.ScrollBarImageColor3 = UiKit.DARK
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = panel
	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = grid
	local gridPadding = Instance.new("UIPadding")
	gridPadding.PaddingTop = UDim.new(0, 6)
	gridPadding.PaddingBottom = UDim.new(0, 8)
	gridPadding.Parent = grid

	local current: Index? = readIndex(player)
	local tab = tabOrder[1]
	local page = 1

	local function worlds(): { any }
		local index = current
		if index == nil then
			return {}
		end
		local data = if tab == "pets" then index.pets else index.toppings
		return if data then data.worlds else {}
	end

	local function clearCards()
		for _, child in grid:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function card(order: number, done: boolean, strokeColor: Color3?): Frame
		local frame = Instance.new("Frame")
		frame.LayoutOrder = order
		frame.BackgroundColor3 = if done then DONE_COLOR else CARD_COLOR
		UiKit.corner(frame, 16)
		local stroke = UiKit.stroke(frame, 3)
		if strokeColor then
			stroke.Color = strokeColor
		end
		frame.Parent = grid
		return frame
	end

	local function petCard(entry: PetEntry, order: number)
		local pet = GameConfig.pets[entry.petId]
		local rarityColor = if pet then UiKit.rarityColor(pet.rarity) else UiKit.GREY
		local frame = card(order, false, if entry.found then rarityColor else nil)
		local holder = circle(frame, 86, if entry.found then rarityColor else UiKit.GREY, UDim2.new(0.5, 0, 0, 8))
		local name = if pet then Lang.name(pet) else entry.petId
		if entry.found then
			modelView(holder, entry.petId, initialOf(name))
		else
			modelView(holder, entry.petId, "?", SILHOUETTE)
		end
		local nameLabel = UiKit.label(frame, if entry.found then name else Lang.t("index.unknown"))
		nameLabel.Position = UDim2.fromOffset(6, 100)
		nameLabel.Size = UDim2.new(1, -12, 0, 28)
		for i, star in STARS do
			local label = UiKit.label(frame, "★")
			label.AnchorPoint = Vector2.new(0.5, 0)
			label.Position = UDim2.new(0.5, (i - 2) * 30, 0, 130)
			label.Size = UDim2.fromOffset(30, 30)
			label.TextColor3 = if (entry :: any)[star.field] then star.color else STAR_OFF
		end
	end

	local function toppingHalf(parent: Frame, toppingId: string, golden: boolean, found: boolean, x: number)
		local topping = GameConfig.toppings[toppingId]
		local name = if topping then Lang.name(topping) else toppingId
		local color = if not found then UiKit.GREY elseif golden then UiKit.COIN else UiKit.CREAM
		local holder = circle(parent, 76, color, UDim2.new(x, 0, 0, 44))
		if found then
			modelView(holder, toppingId, initialOf(name), if golden then GOLD_TINT else nil)
		else
			modelView(holder, toppingId, "?", SILHOUETTE)
		end
		local label = UiKit.label(parent, Lang.t(if golden then "index.golden" else "index.normal"))
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.new(x, 0, 0, 126)
		label.Size = UDim2.new(0.5, -8, 0, 26)
		label.TextColor3 = if found then UiKit.DARK else STAR_OFF
		local check = UiKit.label(parent, if found then "✓" else "")
		check.AnchorPoint = Vector2.new(0.5, 0)
		check.Position = UDim2.new(x, 0, 0, 154)
		check.Size = UDim2.fromOffset(30, 30)
		check.TextColor3 = Color3.fromRGB(40, 150, 60)
	end

	local function toppingCard(entry: ToppingEntry, order: number)
		local topping = GameConfig.toppings[entry.toppingId]
		local known = entry.normal or entry.golden
		local frame = card(order, entry.normal and entry.golden, nil)
		local name = if topping and known then Lang.name(topping) else Lang.t("index.unknown")
		local nameLabel = UiKit.label(frame, name)
		nameLabel.Position = UDim2.fromOffset(8, 8)
		nameLabel.Size = UDim2.new(1, -16, 0, 30)
		toppingHalf(frame, entry.toppingId, false, entry.normal, 0.27)
		toppingHalf(frame, entry.toppingId, true, entry.golden, 0.73)
	end

	local function render()
		for tabId, button in tabs do
			button.BackgroundColor3 = if tabId == tab then UiKit.ORANGE else UiKit.GREY
		end
		local index = current
		if index and tab == "pets" and index.pets then
			totalLabel.Text = Lang.t("index.bonusTotal", { percent = Lang.percent(index.bonus) })
		elseif index and tab == "toppings" and index.toppings then
			totalLabel.Text = Lang.t("index.found", { found = index.toppings.found, total = index.toppings.total })
		else
			totalLabel.Text = ""
		end

		local list = worlds()
		page = math.clamp(page, 1, math.max(1, #list))
		local world = list[page]
		previousButton.Visible = page > 1
		nextButton.Visible = page < #list
		clearCards()
		if world == nil then
			worldLabel.Text = ""
			infoLabel.Text = ""
			return
		end
		worldLabel.Text = Lang.t("index.worldPage", {
			number = worldNumber(world.worldId),
			world = Lang.worldName(world.worldId),
		})
		local found = Lang.t("index.found", { found = world.found, total = world.total })
		if tab == "pets" then
			local petWorld = world :: PetWorld
			local percent = Lang.percent(if index then index.worldBonus else 0)
			local reward = if petWorld.complete
				then Lang.t("index.worldComplete", { percent = percent })
				else Lang.t("index.worldReward", { percent = percent })
			local stars = Lang.t("index.stars", { found = petWorld.stars, total = petWorld.starsTotal })
			infoLabel.Text = `{found} · {reward} · {stars}`
			layout.CellSize = UDim2.fromOffset(PET_CELL.X, PET_CELL.Y)
			for i, entry in petWorld.pets do
				petCard(entry, i)
			end
		else
			infoLabel.Text = `{found} · {Lang.t("index.toppingsHint")}`
			layout.CellSize = UDim2.fromOffset(TOPPING_CELL.X, TOPPING_CELL.Y)
			for i, entry in (world :: ToppingWorld).toppings do
				toppingCard(entry, i)
			end
		end
	end

	-- Page of the player's current world (else the first).
	local function currentWorldPage(): number
		local lastWorld = player:GetAttribute("LastWorldId")
		for i, world in worlds() do
			if world.worldId == lastWorld then
				return i
			end
		end
		return 1
	end

	for tabId, button in tabs do
		button.Activated:Connect(function()
			if tab ~= tabId then
				tab = tabId
				page = currentWorldPage()
				UiKit.pop(button)
				render()
			end
		end)
	end
	previousButton.Activated:Connect(function()
		page -= 1
		UiKit.pop(previousButton)
		render()
	end)
	nextButton.Activated:Connect(function()
		page += 1
		UiKit.pop(nextButton)
		render()
	end)

	-- Red dot: more found than when the menu was last open (or at join).
	local seen = progressCount(current)
	player:GetAttributeChangedSignal("Index"):Connect(function()
		current = readIndex(player)
		local count = progressCount(current)
		if panel.Visible then
			seen = count
			render()
		else
			SideBar.setBadge(TILE_ID, count > seen)
		end
	end)

	local function close()
		panel.Visible = false
	end
	UiKit.registerMenu(TILE_ID, close)
	toggle = function()
		UiKit.pop(tileButton)
		if panel.Visible then
			close()
			return
		end
		seen = progressCount(current)
		SideBar.setBadge(TILE_ID, false)
		page = currentWorldPage()
		render()
		panel.Visible = true
		UiKit.menuOpened(TILE_ID)
		UiKit.pop(panel)
	end
	closeButton.Activated:Connect(close)
end

return IndexMenu
