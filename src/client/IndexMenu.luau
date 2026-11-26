--!strict
-- Pet index and topping index on the client (#95): one menu with two tabs.
-- * Side bar tile "Index" (order 90, star icon); its caption shows the complete worlds
--   ("3/15").
-- * Tab "Pets": per world (all worlds of GameConfig, also new ones) a heading with
--   "found/total" (✓ +4 % when complete) and a card per normal pet: 3D picture (a dark
--   silhouette and "???" until found), name, rarity colour and the extra stars
--   ⭐ Gold / 🌈 Rainbow / ✨ Shiny (dimmed until owned). Above: the index coin bonus.
-- * Tab "Toppings": per world a card per topping with "Normal" and "✨ Golden" marks.
-- Reads the Index attribute (JSON GameRules.IndexStatus, see IndexService); nothing is
-- sent to the server. The toast for a completed world comes as Notify("IndexComplete").

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
local TILE_COLOR = Color3.fromRGB(240, 170, 40)
local HEADER_HEIGHT = 150
local SECTION_HEIGHT = 40
local CARD_SIZE = Vector2.new(132, 176)
local CARD_GAP = 8
local CARD_COLOR = Color3.fromRGB(255, 236, 200)
local COMPLETE_COLOR = Color3.fromRGB(210, 240, 200)
local UNKNOWN_COLOR = Color3.fromRGB(215, 205, 190)
local HINT_COLOR = Color3.fromRGB(110, 80, 55)
local GOLD_COLOR = Color3.fromRGB(255, 200, 40)
local DIM = 0.75
local PANEL_SIZE = Vector2.new(700, 800)
local MIN_HEIGHT = HEADER_HEIGHT + SECTION_HEIGHT + CARD_SIZE.Y + 24

type PetEntry = { petId: string, found: boolean, gold: boolean, rainbow: boolean, shiny: boolean }
type PetWorld = { worldId: string, pets: { PetEntry }, found: number, total: number, complete: boolean }
type ToppingEntry = { toppingId: string, normal: boolean, golden: boolean }
type ToppingWorld = { worldId: string, toppings: { ToppingEntry } }
type Status = {
	pets: { PetWorld },
	toppings: { ToppingWorld },
	completeWorlds: number,
	coinBonus: number,
	petIndexOn: boolean,
	toppingIndexOn: boolean,
}

local IndexMenu = {}

local function readStatus(player: Player): (Status?, string?)
	local json = player:GetAttribute("Index")
	if type(json) ~= "string" then
		return nil, nil
	end
	local ok, value = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok or type(value) ~= "table" or type(value.pets) ~= "table" or type(value.toppings) ~= "table" then
		return nil, nil
	end
	return value :: Status, json
end

local function percentText(share: number): string
	return Lang.percent(share)
end

-- 3D picture of a pet or topping (ModelLibrary); dark silhouette while not found.
local function picture(card: Frame, modelId: string, known: boolean)
	local holder = Instance.new("Frame")
	holder.Name = "Picture"
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.new(0.5, 0, 0, 8)
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Size = UDim2.fromOffset(96, 96)
	holder.Parent = card
	local view = ModelLibrary.viewport(modelId)
	if view then
		view.AnchorPoint = Vector2.new(0.5, 0.5)
		view.Position = UDim2.fromScale(0.5, 0.5)
		view.Size = UDim2.fromScale(1.15, 1.15)
		view.Parent = holder
		if not known then
			view.ImageColor3 = Color3.new(0, 0, 0)
			view.ImageTransparency = 0.35
		end
	else
		-- Without the Studio import: a round dot.
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(0.5, 0.5)
		dot.Size = UDim2.fromOffset(70, 70)
		dot.BackgroundColor3 = if known then GOLD_COLOR else UNKNOWN_COLOR
		UiKit.corner(dot, 35)
		dot.Parent = holder
	end
end

local function smallLabel(card: Frame, text: string, y: number, height: number): TextLabel
	local label = UiKit.label(card, text)
	label.Position = UDim2.fromOffset(4, y)
	label.Size = UDim2.new(1, -8, 0, height)
	label.TextScaled = true
	return label
end

local function newCard(parent: Instance, order: number, color: Color3): Frame
	local card = Instance.new("Frame")
	card.LayoutOrder = order
	card.BackgroundColor3 = color
	UiKit.corner(card, 16)
	UiKit.stroke(card, 2)
	card.Parent = parent
	return card
end

-- One mark (star or "Normal"/"Golden"): bright when reached, dimmed otherwise.
local function mark(label: TextLabel, reached: boolean)
	label.TextTransparency = if reached then 0 else DIM
end

function IndexMenu.start()
	local features = Features.new(GameConfig.features)
	local petsOn = features.enabled("petIndex")
	local toppingsOn = features.enabled("toppingIndex")
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

	-- Tabs (only the ones whose feature is on).
	local tab: string = if petsOn then "pets" else "toppings"
	local tabButtons: { [string]: TextButton } = {}
	local tabX = 24
	local tabSpecs = {
		{ id = "pets", on = petsOn, key = "index.tabPets" },
		{ id = "toppings", on = toppingsOn, key = "index.tabToppings" },
	}
	for _, spec in tabSpecs do
		if spec.on then
			local button = UiKit.button(panel, Lang.t(spec.key), UiKit.CREAM)
			button.Name = `Tab_{spec.id}`
			button.Position = UDim2.fromOffset(tabX, 64)
			button.Size = UDim2.fromOffset(180, 44)
			tabButtons[spec.id] = button
			tabX += 190
		end
	end

	local hint = UiKit.label(panel, "")
	hint.Position = UDim2.fromOffset(24, 112)
	hint.Size = UDim2.new(1, -48, 0, 30)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextColor3 = HINT_COLOR
	hint.TextScaled = true

	local list = Instance.new("ScrollingFrame")
	list.Name = "Worlds"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(12, HEADER_HEIGHT)
	list.Size = UDim2.new(1, -24, 1, -HEADER_HEIGHT - 12)
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = UiKit.DARK
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, CARD_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0, 4)
	listPadding.PaddingLeft = UDim.new(0, 4)
	listPadding.PaddingRight = UDim.new(0, 14)
	listPadding.PaddingBottom = UDim.new(0, 8)
	listPadding.Parent = list

	local content: Frame? = nil
	local function clear()
		if content then
			content:Destroy()
		end
		local frame = Instance.new("Frame")
		frame.Name = "Content"
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.fromScale(1, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.Parent = list
		local inner = Instance.new("UIListLayout")
		inner.Padding = UDim.new(0, CARD_GAP)
		inner.SortOrder = Enum.SortOrder.LayoutOrder
		inner.Parent = frame
		content = frame
	end

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local function heading(text: string, done: boolean)
		local label = UiKit.label(content :: Frame, text)
		label.LayoutOrder = nextOrder()
		label.Size = UDim2.new(1, 0, 0, SECTION_HEIGHT)
		label.TextXAlignment = Enum.TextXAlignment.Left
		if done then
			label.TextColor3 = Color3.fromRGB(60, 150, 50)
		end
	end

	local function grid(): Frame
		local frame = Instance.new("Frame")
		frame.LayoutOrder = nextOrder()
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.fromScale(1, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.Parent = content
		local gridLayout = Instance.new("UIGridLayout")
		gridLayout.CellSize = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
		gridLayout.CellPadding = UDim2.fromOffset(CARD_GAP, CARD_GAP)
		gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
		gridLayout.Parent = frame
		return frame
	end

	local bonusPercent = percentText((GameConfig.petIndex and GameConfig.petIndex.worldCoinBonus) or 0)

	local function buildPets(status: Status)
		hint.Text = Lang.t("index.bonus", { bonus = percentText(status.coinBonus), worlds = status.completeWorlds })
			.. "   "
			.. Lang.t("index.stars")
		local note = UiKit.label(content :: Frame, Lang.t("index.petsHint", { bonus = bonusPercent }))
		note.LayoutOrder = nextOrder()
		note.Size = UDim2.new(1, 0, 0, 28)
		note.TextScaled = true
		note.TextXAlignment = Enum.TextXAlignment.Left
		note.TextColor3 = HINT_COLOR
		for _, world in status.pets do
			local name = Lang.worldName(world.worldId)
			if world.complete then
				heading(Lang.t("index.worldComplete", { world = name, bonus = bonusPercent }), true)
			else
				local params = { world = name, found = world.found, total = world.total }
				heading(Lang.t("index.worldProgress", params), false)
			end
			local cards = grid()
			for i, entry in world.pets do
				local pet = GameConfig.pets[entry.petId]
				local color = if not entry.found
					then UNKNOWN_COLOR
					elseif world.complete then COMPLETE_COLOR
					else CARD_COLOR
				local card = newCard(cards, i, color)
				picture(card, entry.petId, entry.found)
				local petName = if entry.found and pet then Lang.name(pet) else Lang.t("index.unknown")
				local label = smallLabel(card, petName, 108, 26)
				if entry.found and pet and GameConfig.rarities[pet.rarity] then
					label.TextColor3 = UiKit.rarityColor(pet.rarity)
				end
				local stars = Instance.new("Frame")
				stars.BackgroundTransparency = 1
				stars.Position = UDim2.fromOffset(4, 138)
				stars.Size = UDim2.new(1, -8, 0, 30)
				stars.Parent = card
				for index, spec in { { "⭐", entry.gold }, { "🌈", entry.rainbow }, { "✨", entry.shiny } } do
					local star = UiKit.label(stars, spec[1])
					star.Position = UDim2.fromScale((index - 1) / 3, 0)
					star.Size = UDim2.fromScale(1 / 3, 1)
					star.TextScaled = true
					mark(star, spec[2] :: boolean)
				end
			end
		end
	end

	local function buildToppings(status: Status)
		hint.Text = Lang.t("index.toppingsHint")
		for _, world in status.toppings do
			local found = 0
			for _, entry in world.toppings do
				found += (if entry.normal then 1 else 0) + (if entry.golden then 1 else 0)
			end
			local total = #world.toppings * 2
			heading(
				Lang.t("index.worldToppings", { world = Lang.worldName(world.worldId), found = found, total = total }),
				found == total
			)
			local cards = grid()
			for i, entry in world.toppings do
				local topping = GameConfig.toppings[entry.toppingId]
				local known = entry.normal or entry.golden
				local card = newCard(cards, i, if known then CARD_COLOR else UNKNOWN_COLOR)
				picture(card, entry.toppingId, known)
				smallLabel(card, if known and topping then Lang.name(topping) else Lang.t("index.unknown"), 108, 24)
				local normal = smallLabel(card, Lang.t("index.normal"), 134, 18)
				mark(normal, entry.normal)
				local golden = smallLabel(card, Lang.t("index.golden"), 154, 18)
				golden.TextColor3 = Color3.fromRGB(200, 140, 0)
				mark(golden, entry.golden)
			end
		end
	end

	local builtJson: string? = nil
	local builtTab: string? = nil
	local function refresh()
		local status, json = readStatus(player)
		if status then
			SideBar.setCaption(TILE_ID, if petsOn then `{status.completeWorlds}/{#status.pets}` else nil)
		end
		if not panel.Visible then
			return
		end
		for id, button in tabButtons do
			button.BackgroundColor3 = if id == tab then GOLD_COLOR else UiKit.CREAM
		end
		if status == nil or (json == builtJson and tab == builtTab) then
			return
		end
		builtJson, builtTab = json, tab
		order = 0
		clear()
		if tab == "pets" then
			buildPets(status)
		else
			buildToppings(status)
		end
	end

	for id, button in tabButtons do
		button.Activated:Connect(function()
			if tab ~= id then
				tab = id
				list.CanvasPosition = Vector2.zero
				refresh()
			end
		end)
	end

	player:GetAttributeChangedSignal("Index"):Connect(refresh)
	refresh()

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
		panel.Visible = true
		refresh()
		UiKit.menuOpened(TILE_ID)
		UiKit.pop(panel)
	end
	closeButton.Activated:Connect(close)
	gui.Parent = player:WaitForChild("PlayerGui")
end

return IndexMenu
