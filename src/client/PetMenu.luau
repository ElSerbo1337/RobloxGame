--!strict
-- Pet menu: big "Pets" button on the left side of the screen opens the inventory.
-- Tapping a pet card equips or puts it away (only sends the wish; the server decides).
-- "Beste ausrüsten" asks the server to equip the strongest pets. "Löschen" switches the
-- menu into delete mode: tapping a card then asks for confirmation before deleting it.
-- Reads the player attributes Pets (JSON), PetSlots, InventorySlots and CoinMultiplier (see PetService).
-- Bonuses are shown as they count in the player's current world (pet cap, #51): a capped
-- pet's card reads "+X % hier" plus its full bonus.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local PetIcon = require(script.Parent.PetIcon)
local UiKit = require(script.Parent.UiKit)

-- bonusHere: what the pet counts in the current world (missing = full bonus).
type PetEntry = { uid: number, petId: string, equipped: boolean, bonusHere: number? }

-- The pet grid scrolls, so the panel may get as short as header + one row of pets.
local PANEL_SIZE = Vector2.new(640, 560)
local MIN_PANEL_HEIGHT = 180 + 170 + 16

local PetMenu = {}

local function readPets(player: Player): { PetEntry }
	local json = player:GetAttribute("Pets")
	if type(json) ~= "string" then
		return {}
	end
	local ok, list = pcall(HttpService.JSONDecode, HttpService, json)
	return if ok and type(list) == "table" then list else {}
end

local function bonusHere(entry: PetEntry): number
	return entry.bonusHere or GameConfig.pets[entry.petId].bonus
end

-- Equipped first, then best bonus in this world, then best full bonus, then newest.
local function sortPets(pets: { PetEntry })
	table.sort(pets, function(a, b)
		if a.equipped ~= b.equipped then
			return a.equipped
		end
		local hereA, hereB = bonusHere(a), bonusHere(b)
		if hereA ~= hereB then
			return hereA > hereB
		end
		local bonusA, bonusB = GameConfig.pets[a.petId].bonus, GameConfig.pets[b.petId].bonus
		if bonusA ~= bonusB then
			return bonusA > bonusB
		end
		return a.uid > b.uid
	end)
end

function PetMenu.start()
	local player = Players.LocalPlayer

	local gui = Instance.new("ScreenGui")
	gui.Name = "PetMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	UiKit.autoScale(gui)

	-- Left side, first slot of the HUD grid: big round button.
	local openButton = UiKit.sideButton("pets", "Pets", UiKit.ORANGE)
	openButton.Name = "PetsButton"

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = UiKit.CREAM
	panel.Visible = false
	UiKit.corner(panel, 28)
	UiKit.stroke(panel, 4)
	UiKit.placeMenu(gui, panel, PANEL_SIZE, MIN_PANEL_HEIGHT)

	local title = UiKit.label(panel, "Meine Pets")
	title.Position = UDim2.fromOffset(24, 14)
	title.Size = UDim2.new(0.5, -24, 0, 48)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local summary = UiKit.label(panel, "")
	summary.Position = UDim2.fromOffset(24, 62)
	summary.Size = UDim2.new(1, -120, 0, 30)
	summary.TextXAlignment = Enum.TextXAlignment.Left

	local closeButton = UiKit.button(panel, "X", UiKit.RED)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -14, 0, 14)
	closeButton.Size = UDim2.fromOffset(72, 72)

	-- Action row: big buttons, easy to tap on a phone.
	local bestButton = UiKit.button(panel, "Beste ausrüsten", UiKit.GREEN)
	bestButton.Name = "EquipBestButton"
	bestButton.Position = UDim2.fromOffset(24, 100)
	bestButton.Size = UDim2.fromOffset(260, 64)

	local deleteButton = UiKit.button(panel, "Löschen", UiKit.RED)
	deleteButton.Name = "DeleteModeButton"
	deleteButton.Position = UDim2.fromOffset(300, 100)
	deleteButton.Size = UDim2.fromOffset(180, 64)

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(16, 180)
	list.Size = UDim2.new(1, -32, 1, -196)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 10
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(140, 170)
	grid.CellPadding = UDim2.fromOffset(12, 12)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list

	local empty = UiKit.label(list, "Noch keine Pets – öffne ein Ei!")
	empty.Size = UDim2.fromOffset(560, 60)
	empty.Visible = false

	-- Confirmation dialog for deleting, covers the whole panel.
	local confirm = Instance.new("Frame")
	confirm.Name = "ConfirmDelete"
	confirm.Size = UDim2.fromScale(1, 1)
	confirm.BackgroundColor3 = UiKit.DARK
	confirm.BackgroundTransparency = 0.35
	confirm.Active = true
	confirm.ZIndex = 10
	confirm.Visible = false
	UiKit.corner(confirm, 28)
	confirm.Parent = panel

	local dialog = Instance.new("Frame")
	dialog.AnchorPoint = Vector2.new(0.5, 0.5)
	dialog.Position = UDim2.fromScale(0.5, 0.5)
	dialog.Size = UDim2.fromOffset(460, 250)
	dialog.BackgroundColor3 = UiKit.CREAM
	dialog.ZIndex = 11
	UiKit.corner(dialog, 24)
	UiKit.stroke(dialog, 4)
	dialog.Parent = confirm

	local question = UiKit.label(dialog, "")
	question.Position = UDim2.fromOffset(20, 20)
	question.Size = UDim2.new(1, -40, 0, 110)
	question.TextWrapped = true
	question.ZIndex = 12

	local yesButton = UiKit.button(dialog, "Löschen", UiKit.RED)
	yesButton.Position = UDim2.new(0, 20, 1, -96)
	yesButton.Size = UDim2.new(0.5, -30, 0, 76)
	yesButton.ZIndex = 12

	local noButton = UiKit.button(dialog, "Behalten", UiKit.GREEN)
	noButton.AnchorPoint = Vector2.new(1, 0)
	noButton.Position = UDim2.new(1, -20, 1, -96)
	noButton.Size = UDim2.new(0.5, -30, 0, 76)
	noButton.ZIndex = 12

	for _, descendant in dialog:GetDescendants() do
		if descendant:IsA("GuiObject") then
			descendant.ZIndex = 12
		end
	end

	local deleteMode = false
	local pendingDelete: number? = nil

	local function askDelete(entry: PetEntry)
		local pet = GameConfig.pets[entry.petId]
		pendingDelete = entry.uid
		question.Text = if entry.equipped
			then `{pet.displayName} ({UiKit.bonusText(pet.bonus)}) wirklich löschen? Es wird dabei abgelegt.`
			else `{pet.displayName} ({UiKit.bonusText(pet.bonus)}) wirklich löschen?`
		confirm.Visible = true
		UiKit.pop(dialog, 0.8)
	end

	local function closeConfirm()
		pendingDelete = nil
		confirm.Visible = false
	end

	yesButton.Activated:Connect(function()
		if pendingDelete then
			Net.event("DeletePet"):FireServer(pendingDelete)
		end
		closeConfirm()
	end)
	noButton.Activated:Connect(closeConfirm)

	gui.Parent = player:WaitForChild("PlayerGui")

	local function card(entry: PetEntry, order: number)
		local pet = GameConfig.pets[entry.petId]
		local color = UiKit.rarityColor(pet.rarity)

		-- The whole card is the button: big touch target.
		local button = Instance.new("TextButton")
		button.Name = `Pet_{entry.uid}`
		button.LayoutOrder = order
		button.Text = ""
		button.AutoButtonColor = true
		button.BackgroundColor3 = color
		UiKit.corner(button, 18)
		UiKit.stroke(button, if entry.equipped then 5 else 2)
		button.Parent = list

		local icon = Instance.new("Frame")
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 10)
		icon.Size = UDim2.fromOffset(64, 64)
		icon.BackgroundColor3 = UiKit.CREAM
		UiKit.corner(icon, 32)
		UiKit.stroke(icon, 2)
		icon.Parent = button
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(0.5, 0.5)
		dot.Size = UDim2.fromScale(0.6, 0.6)
		dot.BackgroundColor3 = color
		UiKit.corner(dot, 20)
		dot.Parent = icon
		-- The 3D pet (imported model) replaces the dot.
		dot.Visible = not PetIcon.show(icon, entry.petId, 1.2)

		local name = UiKit.label(button, pet.displayName)
		name.Position = UDim2.fromOffset(6, 78)
		name.Size = UDim2.new(1, -12, 0, 28)
		name.TextColor3 = UiKit.CREAM
		name.TextStrokeColor3 = UiKit.DARK
		name.TextStrokeTransparency = 0

		-- In this world (#51): capped pets show what they count here and their full bonus.
		local here = bonusHere(entry)
		local capped = here < pet.bonus - 1e-9
		local bonus = UiKit.label(
			button,
			if capped then `{UiKit.bonusText(here)} hier ({UiKit.bonusText(pet.bonus)})` else UiKit.bonusText(pet.bonus)
		)
		bonus.Position = UDim2.fromOffset(6, 106)
		bonus.Size = UDim2.new(1, -12, 0, 24)
		bonus.TextColor3 = if capped then UiKit.COIN else UiKit.CREAM
		bonus.TextStrokeColor3 = UiKit.DARK
		bonus.TextStrokeTransparency = 0

		local actionText = if deleteMode then "Löschen" elseif entry.equipped then "Ablegen" else "Ausrüsten"
		local state = UiKit.label(button, actionText)
		state.Position = UDim2.new(0, 10, 1, -38)
		state.Size = UDim2.new(1, -20, 0, 30)
		state.BackgroundTransparency = 0
		state.BackgroundColor3 = if deleteMode then UiKit.RED elseif entry.equipped then UiKit.DARK else UiKit.GREEN
		state.TextColor3 = UiKit.CREAM
		UiKit.corner(state, 12)

		button.Activated:Connect(function()
			if deleteMode then
				askDelete(entry)
			else
				Net.event(if entry.equipped then "UnequipPet" else "EquipPet"):FireServer(entry.uid)
			end
		end)
	end

	local function refresh()
		for _, child in list:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		local pets = readPets(player)
		sortPets(pets)
		local equippedCount = 0
		for i, entry in pets do
			if entry.equipped then
				equippedCount += 1
			end
			card(entry, i)
		end
		empty.Visible = #pets == 0
		local slots = (player:GetAttribute("PetSlots") :: number?) or 0
		local inventorySlots = (player:GetAttribute("InventorySlots") :: number?) or 0
		local multiplier = (player:GetAttribute("CoinMultiplier") :: number?) or 1
		local bonusText = UiKit.bonusText(multiplier - 1)
		summary.Text =
			`Ausgerüstet {equippedCount}/{slots}  ·  Inventar {#pets}/{inventorySlots}  ·  Bonus in dieser Welt {bonusText}`
		summary.TextColor3 = if #pets >= inventorySlots and inventorySlots > 0 then UiKit.RED else UiKit.DARK
	end

	local function setDeleteMode(enabled: boolean)
		deleteMode = enabled
		deleteButton.Text = if enabled then "Fertig" else "Löschen"
		deleteButton.BackgroundColor3 = if enabled then UiKit.DARK else UiKit.RED
		bestButton.Visible = not enabled
		title.Text = if enabled then "Pet zum Löschen antippen" else "Meine Pets"
		refresh()
	end

	bestButton.Activated:Connect(function()
		Net.event("EquipBest"):FireServer()
		UiKit.pop(bestButton)
	end)
	deleteButton.Activated:Connect(function()
		setDeleteMode(not deleteMode)
	end)

	player:GetAttributeChangedSignal("Pets"):Connect(refresh)
	player:GetAttributeChangedSignal("PetSlots"):Connect(refresh)
	player:GetAttributeChangedSignal("InventorySlots"):Connect(refresh)
	player:GetAttributeChangedSignal("CoinMultiplier"):Connect(refresh)
	refresh()

	local function close()
		panel.Visible = false
		closeConfirm()
		setDeleteMode(false)
	end
	UiKit.registerMenu("pets", close)

	openButton.Activated:Connect(function()
		if panel.Visible then
			close()
		else
			panel.Visible = true
			UiKit.menuOpened("pets")
			UiKit.pop(panel, 0.8)
		end
	end)
	closeButton.Activated:Connect(close)

	-- "All slots taken" feedback right in the menu.
	Net.event("Notify").OnClientEvent:Connect(function(kind: string)
		local message = if kind == "PetSlotsFull"
			then "Alle Pet-Plätze belegt – erst ein Pet ablegen!"
			elseif kind == "NoPets" then "Noch keine Pets – öffne ein Ei!"
			else nil
		if message and panel.Visible then
			local old = summary.Text
			summary.Text = message
			summary.TextColor3 = UiKit.RED
			task.delay(1.8, function()
				if summary.Text ~= old then
					summary.TextColor3 = UiKit.DARK
					refresh()
				end
			end)
		end
	end)
end

return PetMenu
