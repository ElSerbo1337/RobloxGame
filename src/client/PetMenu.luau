--!strict
-- Pet menu: big "Pets" button on the left side of the screen opens the inventory.
-- Tapping a pet card equips or puts it away (only sends the wish; the server decides).
-- Reads the player attributes Pets (JSON), PetSlots and CoinMultiplier (see PetService).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local UiKit = require(script.Parent.UiKit)

type PetEntry = { uid: number, petId: string, equipped: boolean }

local PetMenu = {}

local function readPets(player: Player): { PetEntry }
	local json = player:GetAttribute("Pets")
	if type(json) ~= "string" then
		return {}
	end
	local ok, list = pcall(HttpService.JSONDecode, HttpService, json)
	return if ok and type(list) == "table" then list else {}
end

-- Equipped first, then best bonus, then newest.
local function sortPets(pets: { PetEntry })
	table.sort(pets, function(a, b)
		if a.equipped ~= b.equipped then
			return a.equipped
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

	-- Left side, vertically centered: big round button.
	local openButton = UiKit.button(gui, "Pets", Color3.fromRGB(240, 130, 60))
	openButton.Name = "PetsButton"
	openButton.AnchorPoint = Vector2.new(0, 0.5)
	openButton.Position = UDim2.new(0, 16, 0.5, 0)
	openButton.Size = UDim2.fromOffset(96, 96)
	local round = openButton:FindFirstChildOfClass("UICorner") :: UICorner
	round.CornerRadius = UDim.new(0.5, 0)

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(640, 480)
	panel.BackgroundColor3 = UiKit.CREAM
	panel.Visible = false
	UiKit.corner(panel, 28)
	UiKit.stroke(panel, 4)
	panel.Parent = gui

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

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(16, 104)
	list.Size = UDim2.new(1, -32, 1, -120)
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

		local name = UiKit.label(button, pet.displayName)
		name.Position = UDim2.fromOffset(6, 78)
		name.Size = UDim2.new(1, -12, 0, 28)
		name.TextColor3 = UiKit.CREAM
		name.TextStrokeColor3 = UiKit.DARK
		name.TextStrokeTransparency = 0

		local bonus = UiKit.label(button, UiKit.bonusText(pet.bonus))
		bonus.Position = UDim2.fromOffset(6, 106)
		bonus.Size = UDim2.new(1, -12, 0, 24)
		bonus.TextColor3 = UiKit.CREAM
		bonus.TextStrokeColor3 = UiKit.DARK
		bonus.TextStrokeTransparency = 0

		local state = UiKit.label(button, if entry.equipped then "Ablegen" else "Ausrüsten")
		state.Position = UDim2.new(0, 10, 1, -38)
		state.Size = UDim2.new(1, -20, 0, 30)
		state.BackgroundTransparency = 0
		state.BackgroundColor3 = if entry.equipped then UiKit.DARK else UiKit.GREEN
		state.TextColor3 = UiKit.CREAM
		UiKit.corner(state, 12)

		button.Activated:Connect(function()
			Net.event(if entry.equipped then "UnequipPet" else "EquipPet"):FireServer(entry.uid)
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
		local multiplier = (player:GetAttribute("CoinMultiplier") :: number?) or 1
		summary.Text = `Ausgerüstet {equippedCount}/{slots}   ·   Münz-Bonus {UiKit.bonusText(multiplier - 1)}`
	end

	player:GetAttributeChangedSignal("Pets"):Connect(refresh)
	player:GetAttributeChangedSignal("PetSlots"):Connect(refresh)
	player:GetAttributeChangedSignal("CoinMultiplier"):Connect(refresh)
	refresh()

	openButton.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			UiKit.pop(panel, 0.8)
		end
	end)
	closeButton.Activated:Connect(function()
		panel.Visible = false
	end)

	-- "All slots taken" feedback right in the menu.
	Net.event("Notify").OnClientEvent:Connect(function(kind: string)
		if kind == "PetSlotsFull" and panel.Visible then
			local old = summary.Text
			summary.Text = "Alle Pet-Plätze belegt – erst ein Pet ablegen!"
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
