--!strict
-- Pet menu: big "Pets" button on the left side of the screen opens the inventory.
-- Tapping a pet card equips or puts it away (only sends the wish; the server decides).
-- "Beste ausrüsten" asks the server to equip the strongest pets. "Löschen" switches the
-- menu into delete mode: tapping a card then asks for confirmation before deleting it.
-- Reads the player attributes Pets (JSON), PetSlots, InventorySlots and CoinMultiplier (see PetService).
-- Merging (#80): every pet card of a group that can still grow shows "Vergolden (n/5)" /
-- "Regenbogen (n/5)"; at 5/5 it asks the server to merge (MergePets) and plays a short
-- fly-together animation on PetMerged (skipped with "skip egg animation", flash only
-- with screen flashes on). Red dot on the pet tile while any group is ready.
-- Pet levels (#90): "Lv. n" badge in the card's top right corner and a thin XP bar
-- under the icon (full and golden at the max level); the merge result shows the level.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Net = require(ReplicatedStorage.Shared.Net)
local PetIcon = require(script.Parent.PetIcon)
local Lang = require(script.Parent.Lang)
local Settings = require(script.Parent.Settings)
local SideBar = require(script.Parent.SideBar)
local Sounds = require(script.Parent.Sounds)
local TweenService = game:GetService("TweenService")
local UiKit = require(script.Parent.UiKit)

-- variant/shiny/locked/bonus from #80 (bonus = effective bonus; missing on old data).
type PetEntry = {
	uid: number,
	petId: string,
	equipped: boolean,
	variant: string?,
	shiny: boolean?,
	locked: boolean?,
	bonus: number?,
	-- #90 (missing on old data / while petLevels is off: no badge).
	level: number?,
	xp: number?,
	xpNeeded: number?,
}

local rules = GameRules.new(GameConfig)
local features = Features.new(GameConfig.features)

local GOLD_COLOR = Color3.fromRGB(255, 200, 40)
local SHINY_COLOR = Color3.fromRGB(255, 245, 170)
local XP_COLOR = Color3.fromRGB(120, 200, 255)
local SHOW_LEVELS = features.enabled("petLevels") and GameConfig.petLevels ~= nil
-- Seconds the merge animation takes (fly together + result).
local MERGE_FLY_SECONDS = 0.55

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

local function bonusOf(entry: PetEntry): number
	return entry.bonus or GameConfig.pets[entry.petId].bonus
end

-- Equipped first, then best bonus, then newest.
local function sortPets(pets: { PetEntry })
	table.sort(pets, function(a, b)
		if a.equipped ~= b.equipped then
			return a.equipped
		end
		local bonusA, bonusB = bonusOf(a), bonusOf(b)
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

	-- Side bar tile (first place), with the first pet of world 1 as live 3D icon.
	local toggle: () -> () = function() end
	SideBar.register({
		id = "pets",
		order = 10,
		text = Lang.t("side.pets"),
		color = UiKit.ORANGE,
		icon = { model = "DoughHamster", shape = "pet" },
		open = function()
			toggle()
		end,
	})

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = UiKit.CREAM
	panel.Visible = false
	UiKit.corner(panel, 28)
	UiKit.stroke(panel, 4)
	UiKit.placeMenu(gui, panel, PANEL_SIZE, MIN_PANEL_HEIGHT)

	local title = UiKit.label(panel, Lang.t("pets.title"))
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
	local bestButton = UiKit.button(panel, Lang.t("pets.equipBest"), UiKit.GREEN)
	bestButton.Name = "EquipBestButton"
	bestButton.Position = UDim2.fromOffset(24, 100)
	bestButton.Size = UDim2.fromOffset(260, 64)

	local deleteButton = UiKit.button(panel, Lang.t("pets.delete"), UiKit.RED)
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
	grid.CellSize = UDim2.fromOffset(140, if features.enabled("petMerge") then 206 else 170)
	grid.CellPadding = UDim2.fromOffset(12, 12)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list

	local empty = UiKit.label(list, Lang.t("pets.empty"))
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

	local yesButton = UiKit.button(dialog, Lang.t("pets.delete"), UiKit.RED)
	yesButton.Position = UDim2.new(0, 20, 1, -96)
	yesButton.Size = UDim2.new(0.5, -30, 0, 76)
	yesButton.ZIndex = 12

	local noButton = UiKit.button(dialog, Lang.t("pets.keep"), UiKit.GREEN)
	noButton.AnchorPoint = Vector2.new(1, 0)
	noButton.Position = UDim2.new(1, -20, 1, -96)
	noButton.Size = UDim2.new(0.5, -30, 0, 76)
	noButton.ZIndex = 12

	for _, descendant in dialog:GetDescendants() do
		if descendant:IsA("GuiObject") then
			descendant.ZIndex = 12
		end
	end

	-- Covers the panel while the merge animation plays (#80, filled on PetMerged).
	local overlay = Instance.new("Frame")
	overlay.Name = "MergeOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = UiKit.DARK
	overlay.BackgroundTransparency = 1
	overlay.ZIndex = 20
	overlay.Visible = false
	UiKit.corner(overlay, 28)
	overlay.Parent = panel

	local deleteMode = false
	local pendingDelete: number? = nil

	local function askDelete(entry: PetEntry)
		pendingDelete = entry.uid
		local key = if entry.equipped then "pets.confirmDeleteEquipped" else "pets.confirmDelete"
		local name = UiKit.petName(entry.petId, entry.variant, entry.shiny)
		question.Text = Lang.t(key, { pet = name, bonus = UiKit.bonusText(bonusOf(entry)) })
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

	-- Merge groups of the current pets ("petId|variant" -> group), set in refresh().
	local groups: { [string]: GameRules.MergeGroup } = {}

	local function card(entry: PetEntry, order: number)
		local pet = GameConfig.pets[entry.petId]
		local variant = entry.variant or "Normal"
		local color = UiKit.rarityColor(pet.rarity)

		-- The whole card is the button: big touch target.
		local button = Instance.new("TextButton")
		button.Name = `Pet_{entry.uid}`
		button.LayoutOrder = order
		button.Text = ""
		button.AutoButtonColor = true
		button.BackgroundColor3 = color
		UiKit.corner(button, 18)
		local frame = UiKit.stroke(button, if entry.equipped then 5 else 2)
		button.Parent = list
		-- Variant look (#80): gold frame, rainbow frame, Shiny sparkle in the corner.
		if variant == "Gold" then
			frame.Color = GOLD_COLOR
			frame.Thickness += 2
		elseif variant == "Rainbow" then
			frame.Color = Color3.new(1, 1, 1)
			frame.Thickness += 2
			local rainbow = Instance.new("UIGradient")
			rainbow.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
				ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 220, 120)),
				ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 90, 255)),
			})
			rainbow.Rotation = 45
			rainbow.Parent = frame
		end
		if entry.shiny then
			local sparkle = UiKit.label(button, "✨")
			sparkle.Position = UDim2.fromOffset(4, 4)
			sparkle.Size = UDim2.fromOffset(30, 30)
			sparkle.TextColor3 = SHINY_COLOR
		end

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

		-- Level badge and XP bar (#90).
		if SHOW_LEVELS and entry.level then
			local maxed = (entry.xpNeeded or -1) < 0
			local badge =
				UiKit.label(button, Lang.t(if maxed then "pets.levelMax" else "pets.level", { level = entry.level }))
			badge.Name = "Level"
			badge.AnchorPoint = Vector2.new(1, 0)
			badge.Position = UDim2.new(1, -4, 0, 4)
			badge.Size = UDim2.fromOffset(if maxed then 74 else 50, 24)
			badge.BackgroundTransparency = 0
			badge.BackgroundColor3 = if maxed then GOLD_COLOR else UiKit.DARK
			badge.TextColor3 = if maxed then UiKit.DARK else UiKit.CREAM
			UiKit.corner(badge, 10)

			local bar = Instance.new("Frame")
			bar.Name = "XpBar"
			bar.AnchorPoint = Vector2.new(0.5, 0)
			bar.Position = UDim2.new(0.5, 0, 0, 74)
			bar.Size = UDim2.new(0.7, 0, 0, 6)
			bar.BackgroundColor3 = UiKit.DARK
			bar.BorderSizePixel = 0
			UiKit.corner(bar, 3)
			bar.Parent = button
			local share = if maxed then 1 else math.clamp((entry.xp or 0) / math.max(entry.xpNeeded or 1, 1), 0, 1)
			local fill = Instance.new("Frame")
			fill.Size = UDim2.fromScale(share, 1)
			fill.BackgroundColor3 = if maxed then GOLD_COLOR else XP_COLOR
			fill.BorderSizePixel = 0
			UiKit.corner(fill, 3)
			fill.Parent = bar
		end

		local name = UiKit.label(button, UiKit.petName(entry.petId, variant, entry.shiny))
		name.Position = UDim2.fromOffset(6, 78)
		name.Size = UDim2.new(1, -12, 0, 28)
		name.TextColor3 = UiKit.CREAM
		name.TextStrokeColor3 = UiKit.DARK
		name.TextStrokeTransparency = 0

		local bonus = UiKit.label(button, UiKit.bonusText(bonusOf(entry)))
		bonus.Position = UDim2.fromOffset(6, 106)
		bonus.Size = UDim2.new(1, -12, 0, 24)
		bonus.TextColor3 = UiKit.CREAM
		bonus.TextStrokeColor3 = UiKit.DARK
		bonus.TextStrokeTransparency = 0

		local actionText = if deleteMode
			then Lang.t("pets.delete")
			elseif entry.equipped then Lang.t("pets.unequip")
			else Lang.t("pets.equip")
		local state = UiKit.label(button, actionText)
		state.Position = UDim2.new(0, 10, 1, -38)
		state.Size = UDim2.new(1, -20, 0, 30)
		state.BackgroundTransparency = 0
		state.BackgroundColor3 = if deleteMode then UiKit.RED elseif entry.equipped then UiKit.DARK else UiKit.GREEN
		state.TextColor3 = UiKit.CREAM
		UiKit.corner(state, 12)

		-- Merge button (#80): on every card of a group that can still grow.
		local group = groups[`{entry.petId}|{variant}`]
		if group and not deleteMode and not entry.locked then
			local ready = group.have >= group.need
			local merge = UiKit.button(
				button,
				Lang.t(`pets.merge.{group.target}`, { have = math.min(group.have, group.need), need = group.need }),
				if ready then GOLD_COLOR else Color3.fromRGB(170, 160, 150)
			)
			merge.Name = "MergeButton"
			merge.Position = UDim2.new(0, 8, 1, -74)
			merge.Size = UDim2.new(1, -16, 0, 32)
			merge.AutoButtonColor = ready
			merge.Activated:Connect(function()
				if ready then
					Net.event("MergePets"):FireServer(entry.petId, variant)
					UiKit.pop(merge)
				else
					UiKit.pop(merge, 0.9)
				end
			end)
		end

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
		groups = {}
		for _, group in rules.mergeGroups(pets :: any) do
			groups[`{group.petId}|{group.variant}`] = group
		end
		-- Red dot on the pet tile while a merge is ready (#80).
		SideBar.setBadge("pets", rules.canMergeAny(pets :: any))
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
		summary.Text = Lang.t("pets.summary", {
			equipped = equippedCount,
			slots = slots,
			count = #pets,
			inventory = inventorySlots,
			bonus = bonusText,
		})
		summary.TextColor3 = if #pets >= inventorySlots and inventorySlots > 0 then UiKit.RED else UiKit.DARK
	end

	local function setDeleteMode(enabled: boolean)
		deleteMode = enabled
		deleteButton.Text = if enabled then Lang.t("pets.done") else Lang.t("pets.delete")
		deleteButton.BackgroundColor3 = if enabled then UiKit.DARK else UiKit.RED
		bestButton.Visible = not enabled
		title.Text = if enabled then Lang.t("pets.deleteTitle") else Lang.t("pets.title")
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
		overlay.Visible = false
		closeConfirm()
		setDeleteMode(false)
	end
	UiKit.registerMenu("pets", close)

	toggle = function()
		if panel.Visible then
			close()
		else
			panel.Visible = true
			UiKit.menuOpened("pets")
			UiKit.pop(panel, 0.8)
		end
	end
	closeButton.Activated:Connect(close)

	-- Merge animation (#80): five pet icons fly into the middle, then the new pet pops
	-- up with its name and bonus. "Skip egg animation" shows only the result,
	-- the golden flash needs screen flashes on.
	local mergeId = 0

	local function icon(petId: string, size: number, parent: Instance): Frame
		local holder = Instance.new("Frame")
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Size = UDim2.fromOffset(size, size)
		holder.BackgroundColor3 = UiKit.rarityColor(GameConfig.pets[petId].rarity)
		holder.ZIndex = 21
		UiKit.corner(holder, size // 2)
		UiKit.stroke(holder, 3)
		holder.Parent = parent
		PetIcon.show(holder, petId, 1.2)
		return holder
	end

	Net.event("PetMerged").OnClientEvent:Connect(function(pet: any)
		if type(pet) ~= "table" or GameConfig.pets[pet.petId] == nil then
			return
		end
		Sounds.play("Merge")
		local name = UiKit.petName(pet.petId, pet.variant, pet.shiny)
		local bonusText = UiKit.bonusText(tonumber(pet.bonus) or 0)
		local level = tonumber(pet.level)
		local message = if SHOW_LEVELS
				and level
				and level > 1
			then Lang.t("pets.mergedLevel", { pet = name, bonus = bonusText, level = level })
			else Lang.t("pets.merged", { pet = name, bonus = bonusText })
		if not panel.Visible then
			return
		end
		mergeId += 1
		local myId = mergeId
		for _, child in overlay:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		overlay.Visible = true
		overlay.BackgroundTransparency = 0.35
		local need = GameConfig.petVariants[pet.variant] and GameConfig.petVariants[pet.variant].count or 5
		if not Settings.skipEggAnimation() then
			local flyers = {}
			for i = 1, need do
				local angle = (i - 1) / need * math.pi * 2
				local flyer = icon(pet.petId, 70, overlay)
				flyer.Position = UDim2.new(0.5, math.cos(angle) * 190, 0.5, math.sin(angle) * 150)
				table.insert(flyers, flyer)
			end
			task.wait(0.25)
			for _, flyer in flyers do
				TweenService:Create(
					flyer,
					TweenInfo.new(MERGE_FLY_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.In),
					{ Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 30) }
				):Play()
			end
			task.wait(MERGE_FLY_SECONDS)
			if myId ~= mergeId then
				return
			end
			for _, flyer in flyers do
				flyer:Destroy()
			end
			if Settings.screenFlashes() then
				overlay.BackgroundColor3 = GOLD_COLOR
				overlay.BackgroundTransparency = 0.1
				TweenService:Create(overlay, TweenInfo.new(0.4), { BackgroundTransparency = 0.35 }):Play()
				task.delay(0.4, function()
					overlay.BackgroundColor3 = UiKit.DARK
				end)
			end
		end
		local result = icon(pet.petId, 150, overlay)
		result.Position = UDim2.fromScale(0.5, 0.42)
		local frame = result:FindFirstChildOfClass("UIStroke")
		if frame then
			frame.Color = if pet.variant == "Gold" then GOLD_COLOR else Color3.fromRGB(255, 120, 220)
			frame.Thickness = 6
		end
		UiKit.pop(result, 0.3)
		local text = UiKit.label(overlay, message)
		text.AnchorPoint = Vector2.new(0.5, 0)
		text.Position = UDim2.new(0.5, 0, 0.42, 96)
		text.Size = UDim2.new(1, -60, 0, 50)
		text.TextColor3 = UiKit.CREAM
		text.TextStrokeColor3 = UiKit.DARK
		text.TextStrokeTransparency = 0
		text.ZIndex = 22
		task.delay(1.8, function()
			if myId == mergeId then
				overlay.Visible = false
			end
		end)
	end)

	-- "All slots taken" feedback right in the menu.
	Net.event("Notify").OnClientEvent:Connect(function(kind: string)
		local message = if kind == "PetSlotsFull"
			then Lang.t("pets.slotsFull")
			elseif kind == "NoPets" then Lang.t("pets.empty")
			elseif kind == "NotEnoughPets" then Lang.t("notify.NotEnoughPets")
			elseif kind == "MaxVariant" then Lang.t("notify.MaxVariant")
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
