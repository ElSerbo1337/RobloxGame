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
-- Pet management (#91), each behind its own switch:
--   petDetails / petLock / petRename: tapping a card opens the detail card (big 3D pet,
--     bonus, rarity, variant, level, world, found date, how many of it you own) with
--     Equip/Unequip, 🔒 Lock/Unlock, Rename (sent to the server, filtered there) and
--     Delete. With all three off, tapping a card equips it like before.
--   petMultiDelete: "Löschen" switches to selection mode: tap cards to select them
--     (locked ones cannot be), "🗑 Löschen (n)" asks once and deletes all (DeletePets).
--   petTeams: a row of team buttons (Team 1-3): tap = equip that team (an empty team saves
--     the equipped pets), "💾 Speichern" then a team = save the equipped pets there.
-- Locked pets show a 🔒 on their card and no merge button; custom names replace the
-- config name on the card.

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
local FeatureHints = require(script.Parent.FeatureHints)
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
	-- #91: custom name (filtered on the server) and Unix time it was found.
	name: string?,
	foundAt: number?,
}

local rules = GameRules.new(GameConfig)
local features = Features.new(GameConfig.features)

local GOLD_COLOR = Color3.fromRGB(255, 200, 40)
local SHINY_COLOR = Color3.fromRGB(255, 245, 170)
local XP_COLOR = Color3.fromRGB(120, 200, 255)
local SHOW_LEVELS = features.enabled("petLevels") and GameConfig.petLevels ~= nil
-- Seconds the merge animation takes (fly together + result).
local MERGE_FLY_SECONDS = 0.55
-- Pet management switches (#91).
local DETAILS = features.enabled("petDetails")
local LOCKS = features.enabled("petLock")
local RENAME = features.enabled("petRename")
local MULTI_DELETE = features.enabled("petMultiDelete")
local TEAMS = features.enabled("petTeams")
-- Tapping a card opens the detail card when any of its parts is on.
local DETAIL_CARD = DETAILS or LOCKS or RENAME
local SELECT_COLOR = Color3.fromRGB(255, 255, 255)

-- The pet grid scrolls, so the panel may get as short as header + one row of pets.
-- The team row (#91) adds 72 px to the header.
local LIST_TOP = if TEAMS then 252 else 180
local CARD_HEIGHT = if features.enabled("petMerge") then 206 else 170
local PANEL_SIZE = Vector2.new(640, if TEAMS then 620 else 560)
local MIN_PANEL_HEIGHT = LIST_TOP + CARD_HEIGHT + 16
-- Height of the detail card's content (it scrolls on short panels).
local DETAIL_HEIGHT = 560

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

-- Card name: the custom name (#91), otherwise "Gold-Katze" etc.
local function displayName(entry: PetEntry): string
	if entry.name and entry.name ~= "" then
		return if entry.shiny then `✨ {entry.name}` else entry.name
	end
	return UiKit.petName(entry.petId, entry.variant, entry.shiny)
end

-- The world whose egg (or Secret slot) the pet comes from, nil for other pets.
local function worldOf(petId: string): string?
	for _, world in GameConfig.worlds do
		if world.secretPet == petId then
			return world.id
		end
		for _, eggId in world.eggs or {} do
			local egg = GameConfig.eggs[eggId]
			for _, entry in (egg and egg.pets) or {} do
				if entry.pet == petId then
					return world.id
				end
			end
		end
	end
	return nil
end

-- "25. November 2026" / "November 25, 2026" in the player's language.
local function dateText(unixSeconds: number?): string
	if type(unixSeconds) ~= "number" then
		return Lang.t("pets.detail.foundUnknown")
	end
	local ok, text = pcall(function()
		local locale = if Lang.language == "de" then "de-de" else "en-us"
		return DateTime.fromUnixTimestamp(unixSeconds):FormatLocalTime("LL", locale)
	end)
	return if ok then text else Lang.t("pets.detail.foundUnknown")
end

local function readTeams(player: Player): { { number } }
	local ok, teams = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("PetTeams") or "[]")
	return if ok and type(teams) == "table" then teams else {}
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
	FeatureHints.attach("Merge", "pets", "hint.merge", 10)

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

	-- Selection mode (#91): "🗑 Löschen (n)" where "Beste ausrüsten" was.
	local deleteSelectedButton = UiKit.button(panel, "", UiKit.RED)
	deleteSelectedButton.Name = "DeleteSelectedButton"
	deleteSelectedButton.Position = UDim2.fromOffset(24, 100)
	deleteSelectedButton.Size = UDim2.fromOffset(260, 64)
	deleteSelectedButton.Visible = false

	-- Team row (#91): Team 1-3 and "💾 Speichern".
	local teamButtons: { TextButton } = {}
	local saveTeamButton: TextButton? = nil
	if TEAMS then
		for i = 1, rules.teamCount() do
			local teamButton = UiKit.button(panel, "", UiKit.ORANGE)
			teamButton.Name = `Team{i}`
			teamButton.Position = UDim2.fromOffset(24 + (i - 1) * 140, 176)
			teamButton.Size = UDim2.fromOffset(128, 64)
			teamButtons[i] = teamButton
		end
		local saveButton = UiKit.button(panel, Lang.t("pets.team.save"), UiKit.GREY)
		saveButton.Name = "SaveTeamButton"
		saveButton.Position = UDim2.fromOffset(24 + rules.teamCount() * 140, 176)
		saveButton.Size = UDim2.fromOffset(170, 64)
		saveTeamButton = saveButton
	end

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(16, LIST_TOP)
	list.Size = UDim2.new(1, -32, 1, -(LIST_TOP + 16))
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 10
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(140, CARD_HEIGHT)
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
	-- Selection mode (#91): selected uids; pendingMany = the confirm dialog is for them.
	local selected: { [number]: boolean } = {}
	local pendingMany = false

	local function askDelete(entry: PetEntry)
		pendingDelete = entry.uid
		pendingMany = false
		local key = if entry.equipped then "pets.confirmDeleteEquipped" else "pets.confirmDelete"
		question.Text = Lang.t(key, { pet = displayName(entry), bonus = UiKit.bonusText(bonusOf(entry)) })
		confirm.Visible = true
		UiKit.pop(dialog, 0.8)
	end

	local function selectedUids(): { number }
		local uids = {}
		for uid in selected do
			table.insert(uids, uid)
		end
		table.sort(uids)
		return uids
	end

	local function askDeleteSelected()
		local count = #selectedUids()
		if count == 0 then
			UiKit.pop(deleteSelectedButton, 0.9)
			return
		end
		pendingDelete = nil
		pendingMany = true
		question.Text =
			Lang.t(if count == 1 then "pets.confirmDeleteOne" else "pets.confirmDeleteMany", { count = count })
		confirm.Visible = true
		UiKit.pop(dialog, 0.8)
	end

	local function closeConfirm()
		pendingDelete = nil
		pendingMany = false
		confirm.Visible = false
	end

	local setDeleteMode: (boolean) -> () = function() end
	yesButton.Activated:Connect(function()
		if pendingMany then
			Net.event("DeletePets"):FireServer(selectedUids())
			table.clear(selected)
			closeConfirm()
			setDeleteMode(false)
			return
		end
		if pendingDelete then
			Net.event("DeletePet"):FireServer(pendingDelete)
		end
		closeConfirm()
	end)
	noButton.Activated:Connect(closeConfirm)

	-- Detail card (#91): a page over the pet list (below the delete confirmation).
	local detail = Instance.new("ScrollingFrame")
	detail.Name = "PetDetail"
	detail.Size = UDim2.fromScale(1, 1)
	detail.BackgroundColor3 = UiKit.CREAM
	detail.BorderSizePixel = 0
	detail.ScrollBarThickness = 10
	detail.CanvasSize = UDim2.fromOffset(0, DETAIL_HEIGHT)
	detail.ScrollingDirection = Enum.ScrollingDirection.Y
	detail.ZIndex = 5
	detail.Visible = false
	UiKit.corner(detail, 28)
	detail.Parent = panel

	local detailClose = UiKit.button(detail, "X", UiKit.RED)
	detailClose.AnchorPoint = Vector2.new(1, 0)
	detailClose.Position = UDim2.new(1, -24, 0, 14)
	detailClose.Size = UDim2.fromOffset(72, 72)

	local detailIcon = Instance.new("Frame")
	detailIcon.Name = "Icon"
	detailIcon.Position = UDim2.fromOffset(24, 24)
	detailIcon.Size = UDim2.fromOffset(220, 220)
	UiKit.corner(detailIcon, 110)
	local detailFrame = UiKit.stroke(detailIcon, 5)
	detailIcon.Parent = detail

	local function infoLabel(y: number, height: number): TextLabel
		local label = UiKit.label(detail, "")
		label.Position = UDim2.fromOffset(264, y)
		label.Size = UDim2.new(1, -264 - 104, 0, height)
		label.TextXAlignment = Enum.TextXAlignment.Left
		return label
	end
	local detailName = infoLabel(20, 46)
	detailName.Size = UDim2.new(1, -264 - 104, 0, 46)
	local detailSpecies = infoLabel(66, 26)
	local detailRarity = infoLabel(98, 30)
	detailRarity.TextStrokeColor3 = UiKit.DARK
	detailRarity.TextStrokeTransparency = 0
	local detailBonus = infoLabel(132, 30)
	detailBonus.TextColor3 = Color3.fromRGB(40, 130, 40)
	local detailLevel = infoLabel(166, 26)
	local detailWorld = infoLabel(196, 26)
	local detailFound = infoLabel(226, 26)
	local detailCount = infoLabel(256, 26)
	for _, label in { detailRarity, detailBonus, detailLevel, detailWorld, detailFound, detailCount } do
		label.Size = UDim2.new(1, -288, 0, label.Size.Y.Offset)
	end

	-- Rename row: text box + OK (sent to the server, which filters the name).
	local renameBox = Instance.new("TextBox")
	renameBox.Name = "RenameBox"
	renameBox.Position = UDim2.fromOffset(24, 300)
	renameBox.Size = UDim2.new(1, -216, 0, 64)
	renameBox.BackgroundColor3 = Color3.new(1, 1, 1)
	renameBox.Font = UiKit.FONT
	renameBox.TextScaled = true
	renameBox.TextColor3 = UiKit.DARK
	renameBox.PlaceholderText = Lang.t("pets.rename.placeholder", { max = rules.petNameMaxLength() })
	renameBox.PlaceholderColor3 = UiKit.GREY
	renameBox.ClearTextOnFocus = false
	renameBox.Text = ""
	UiKit.corner(renameBox, 18)
	UiKit.stroke(renameBox, 3)
	renameBox.Parent = detail
	local renameButton = UiKit.button(detail, Lang.t("pets.rename.ok"), UiKit.ORANGE)
	renameButton.Name = "RenameButton"
	renameButton.AnchorPoint = Vector2.new(1, 0)
	renameButton.Position = UDim2.new(1, -24, 0, 300)
	renameButton.Size = UDim2.fromOffset(160, 64)
	renameBox.Visible = RENAME
	renameButton.Visible = RENAME
	local renameNote = UiKit.label(detail, "")
	renameNote.Position = UDim2.fromOffset(24, 368)
	renameNote.Size = UDim2.new(1, -48, 0, 26)
	renameNote.Visible = RENAME

	local actionsTop = if RENAME then 404 else 300
	local function actionButton(index: number, text: string, color: Color3): TextButton
		local actionButtonObject = UiKit.button(detail, text, color)
		actionButtonObject.Position = UDim2.new((index - 1) / 3, if index == 1 then 24 else 8, 0, actionsTop)
		actionButtonObject.Size = UDim2.new(1 / 3, -32, 0, 72)
		return actionButtonObject
	end
	local detailEquip = actionButton(1, "", UiKit.GREEN)
	detailEquip.Name = "EquipButton"
	local detailLock = actionButton(2, "", UiKit.GREY)
	detailLock.Name = "LockButton"
	detailLock.Visible = LOCKS
	local detailDelete = actionButton(3, Lang.t("pets.delete"), UiKit.RED)
	detailDelete.Name = "DeleteButton"
	detail.CanvasSize = UDim2.fromOffset(0, actionsTop + 72 + 24)

	local detailUid: number? = nil
	local function findEntry(uid: number?): PetEntry?
		for _, entry in readPets(player) do
			if entry.uid == uid then
				return entry
			end
		end
		return nil
	end

	local function closeDetail()
		detailUid = nil
		detail.Visible = false
	end

	-- Fills the detail card for `uid`, closes it when the pet is gone.
	local function fillDetail()
		local entry = findEntry(detailUid)
		if entry == nil then
			closeDetail()
			return
		end
		local pet = GameConfig.pets[entry.petId]
		local variant = entry.variant or "Normal"
		local color = UiKit.rarityColor(pet.rarity)
		for _, child in detailIcon:GetChildren() do
			if child:IsA("ViewportFrame") or child.Name == "Dot" then
				child:Destroy()
			end
		end
		detailIcon.BackgroundColor3 = color
		if not PetIcon.show(detailIcon, entry.petId, 1.15) then
			local dot = Instance.new("Frame")
			dot.Name = "Dot"
			dot.AnchorPoint = Vector2.new(0.5, 0.5)
			dot.Position = UDim2.fromScale(0.5, 0.5)
			dot.Size = UDim2.fromScale(0.5, 0.5)
			dot.BackgroundColor3 = UiKit.CREAM
			UiKit.corner(dot, 60)
			dot.Parent = detailIcon
		end
		detailFrame.Color = if variant == "Gold"
			then GOLD_COLOR
			elseif variant == "Rainbow" then Color3.fromRGB(255, 120, 220)
			elseif entry.shiny then SHINY_COLOR
			else UiKit.DARK

		detailName.Text = if entry.locked then `🔒 {displayName(entry)}` else displayName(entry)
		local species = UiKit.petName(entry.petId, variant, entry.shiny)
		detailSpecies.Text = if entry.name and entry.name ~= "" then species else ""
		detailSpecies.Visible = detailSpecies.Text ~= ""

		local rarityText = Lang.name(GameConfig.rarities[pet.rarity])
		if variant ~= "Normal" then
			rarityText = `{rarityText} · {Lang.t("pets.variant." .. variant)}`
		end
		if entry.shiny then
			rarityText = `{rarityText} · {Lang.t("pets.shiny")}`
		end
		detailRarity.Text = rarityText
		detailRarity.TextColor3 = color
		detailBonus.Text = Lang.t("egg.bonus", { bonus = UiKit.bonusText(bonusOf(entry)) })

		detailLevel.Visible = SHOW_LEVELS and entry.level ~= nil
		if detailLevel.Visible then
			local level = entry.level :: number
			detailLevel.Text = if (entry.xpNeeded or -1) < 0
				then Lang.t("pets.levelMax", { level = level })
				else Lang.t(
					"pets.detail.level",
					{ level = level, xp = Lang.integer(entry.xp or 0), need = Lang.integer(entry.xpNeeded or 0) }
				)
		end
		local worldId = worldOf(entry.petId)
		detailWorld.Text = Lang.t("pets.detail.world", {
			world = if worldId then Lang.worldName(worldId) else Lang.t("pets.detail.noWorld"),
		})
		detailFound.Text = Lang.t("pets.detail.found", { date = dateText(entry.foundAt) })
		local count = 0
		for _, other in readPets(player) do
			if other.petId == entry.petId then
				count += 1
			end
		end
		detailCount.Text = Lang.t("pets.detail.count", { count = count, pet = Lang.name(pet) })
		for _, label in { detailRarity, detailLevel, detailWorld, detailFound, detailCount } do
			if not DETAILS then
				label.Visible = false
			end
		end

		detailEquip.Text = if entry.equipped then Lang.t("pets.unequip") else Lang.t("pets.equip")
		detailEquip.BackgroundColor3 = if entry.equipped then UiKit.DARK else UiKit.GREEN
		detailLock.Text = if entry.locked then Lang.t("pets.unlock") else Lang.t("pets.lock")
		detailLock.BackgroundColor3 = if entry.locked then UiKit.COIN else UiKit.GREY
		detailDelete.BackgroundColor3 = if entry.locked then UiKit.GREY else UiKit.RED
		detailDelete.AutoButtonColor = not entry.locked
	end

	local function openDetail(entry: PetEntry)
		detailUid = entry.uid
		renameBox.Text = entry.name or ""
		renameNote.Text = ""
		detail.CanvasPosition = Vector2.zero
		detail.Visible = true
		fillDetail()
		UiKit.pop(detail, 0.9)
	end

	detailClose.Activated:Connect(closeDetail)
	detailEquip.Activated:Connect(function()
		local entry = findEntry(detailUid)
		if entry then
			Net.event(if entry.equipped then "UnequipPet" else "EquipPet"):FireServer(entry.uid)
			UiKit.pop(detailEquip)
		end
	end)
	detailLock.Activated:Connect(function()
		local entry = findEntry(detailUid)
		if entry then
			Net.event("LockPet"):FireServer(entry.uid, not entry.locked)
			UiKit.pop(detailLock)
		end
	end)
	detailDelete.Activated:Connect(function()
		local entry = findEntry(detailUid)
		if entry == nil then
			return
		end
		if entry.locked then
			-- Locked pets cannot be deleted: shake and say why.
			UiKit.pop(detailDelete, 0.85)
			renameNote.Text = Lang.t("notify.PetLocked")
			renameNote.Visible = true
			return
		end
		askDelete(entry)
	end)
	renameButton.Activated:Connect(function()
		local entry = findEntry(detailUid)
		if entry == nil then
			return
		end
		local name = renameBox.Text
		if utf8.len(name) == nil or (utf8.len(name) :: number) > rules.petNameMaxLength() then
			renameNote.Text = Lang.t("notify.InvalidName")
			renameNote.TextColor3 = UiKit.RED
			return
		end
		Net.event("RenamePet"):FireServer(entry.uid, name)
		renameNote.Text = Lang.t("pets.rename.sent")
		renameNote.TextColor3 = UiKit.DARK
		UiKit.pop(renameButton)
	end)

	gui.Parent = player:WaitForChild("PlayerGui")

	-- Merge groups of the current pets ("petId|variant" -> group), set in refresh().
	local groups: { [string]: GameRules.MergeGroup } = {}

	local refreshList: () -> () = function() end

	-- Team buttons (#91): green = the equipped pets are exactly this team, orange = saved,
	-- grey = empty (tap saves). In save mode every team shows "💾".
	local saveMode = false
	local function updateTeams(pets: { PetEntry })
		if not TEAMS then
			return
		end
		local equipped: { [number]: boolean } = {}
		local equippedCount = 0
		for _, entry in pets do
			if entry.equipped then
				equipped[entry.uid] = true
				equippedCount += 1
			end
		end
		local teams = readTeams(player)
		for i, teamButton in teamButtons do
			local team = teams[i] or {}
			local active = #team > 0 and #team == equippedCount
			for _, uid in team do
				if not equipped[uid] then
					active = false
				end
			end
			teamButton.Text = if saveMode
				then Lang.t("pets.team.saveTo", { n = i })
				elseif #team == 0 then Lang.t("pets.team.empty", { n = i })
				else Lang.t("pets.team.name", { n = i, count = #team })
			teamButton.BackgroundColor3 = if saveMode
				then UiKit.COIN
				elseif active then UiKit.GREEN
				elseif #team == 0 then UiKit.GREY
				else UiKit.ORANGE
		end
		if saveTeamButton then
			saveTeamButton.Text = if saveMode then Lang.t("pets.team.cancel") else Lang.t("pets.team.save")
			saveTeamButton.BackgroundColor3 = if saveMode then UiKit.DARK else UiKit.GREY
		end
	end

	for i, teamButton in teamButtons do
		teamButton.Activated:Connect(function()
			local team = readTeams(player)[i] or {}
			if saveMode or #team == 0 then
				Net.event("SaveTeam"):FireServer(i)
				saveMode = false
			else
				Net.event("EquipTeam"):FireServer(i)
			end
			UiKit.pop(teamButton)
			updateTeams(readPets(player))
		end)
	end
	if saveTeamButton then
		local saveButton = saveTeamButton
		saveButton.Activated:Connect(function()
			saveMode = not saveMode
			UiKit.pop(saveButton)
			updateTeams(readPets(player))
		end)
	end

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
		-- Lock (#91): padlock under the Shiny corner.
		if entry.locked then
			local padlock = UiKit.label(button, "🔒")
			padlock.Name = "Locked"
			padlock.Position = UDim2.fromOffset(4, 36)
			padlock.Size = UDim2.fromOffset(30, 30)
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

		local name = UiKit.label(button, displayName(entry))
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

		local isSelected = selected[entry.uid] == true
		local actionText = if deleteMode and MULTI_DELETE
			then (if entry.locked
				then Lang.t("pets.lockedShort")
				elseif isSelected then Lang.t("pets.selected")
				else Lang.t("pets.select"))
			elseif deleteMode then Lang.t("pets.delete")
			elseif entry.equipped then Lang.t("pets.unequip")
			else Lang.t("pets.equip")
		local state = UiKit.label(button, actionText)
		state.Position = UDim2.new(0, 10, 1, -38)
		state.Size = UDim2.new(1, -20, 0, 30)
		state.BackgroundTransparency = 0
		state.BackgroundColor3 = if deleteMode and MULTI_DELETE
			then (if entry.locked then UiKit.GREY elseif isSelected then UiKit.RED else UiKit.DARK)
			elseif deleteMode then UiKit.RED
			elseif entry.equipped then UiKit.DARK
			else UiKit.GREEN
		-- Selected for deleting (#91): white veil with a big check mark, red frame.
		if deleteMode and isSelected then
			local veil = UiKit.label(button, "✓")
			veil.Name = "Selected"
			veil.Size = UDim2.new(1, 0, 0, 100)
			veil.BackgroundTransparency = 0.45
			veil.BackgroundColor3 = SELECT_COLOR
			veil.TextColor3 = UiKit.RED
			UiKit.corner(veil, 18)
			frame.Color = UiKit.RED
			frame.Thickness = 5
		end
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
			if deleteMode and MULTI_DELETE then
				if entry.locked then
					UiKit.pop(button, 0.9)
					return
				end
				selected[entry.uid] = if selected[entry.uid] then nil else true
				refreshList()
			elseif deleteMode then
				if entry.locked then
					UiKit.pop(button, 0.9)
					return
				end
				askDelete(entry)
			elseif DETAIL_CARD then
				openDetail(entry)
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
		-- Drop selected pets that are gone (#91).
		local present: { [number]: boolean } = {}
		for _, entry in pets do
			present[entry.uid] = true
		end
		for uid in selected do
			if not present[uid] then
				selected[uid] = nil
			end
		end
		local selectedCount = #selectedUids()
		deleteSelectedButton.Text = Lang.t("pets.deleteSelected", { count = selectedCount })
		deleteSelectedButton.BackgroundColor3 = if selectedCount > 0 then UiKit.RED else UiKit.GREY
		updateTeams(pets)
		if detail.Visible then
			fillDetail()
		end
		groups = {}
		for _, group in rules.mergeGroups(pets :: any) do
			groups[`{group.petId}|{group.variant}`] = group
		end
		-- Red dot on the pet tile while a merge is ready (#80).
		SideBar.setBadge("pets", rules.canMergeAny(pets :: any))
		FeatureHints.setActive("Merge", rules.canMergeAny(pets :: any))
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

	refreshList = refresh

	setDeleteMode = function(enabled: boolean)
		deleteMode = enabled
		table.clear(selected)
		deleteButton.Text = if enabled then Lang.t("pets.done") else Lang.t("pets.delete")
		deleteButton.BackgroundColor3 = if enabled then UiKit.DARK else UiKit.RED
		bestButton.Visible = not enabled
		deleteSelectedButton.Visible = enabled and MULTI_DELETE
		title.Text = if enabled and MULTI_DELETE
			then Lang.t("pets.selectTitle")
			elseif enabled then Lang.t("pets.deleteTitle")
			else Lang.t("pets.title")
		if enabled then
			closeDetail()
		end
		refresh()
	end
	deleteSelectedButton.Activated:Connect(askDeleteSelected)

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
	player:GetAttributeChangedSignal("PetTeams"):Connect(function()
		updateTeams(readPets(player))
	end)
	refresh()

	local function close()
		panel.Visible = false
		overlay.Visible = false
		closeConfirm()
		closeDetail()
		saveMode = false
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
		-- Rename/lock answers (#91) go to the note on the detail card.
		if detail.Visible and (kind == "FilterFailed" or kind == "InvalidName" or kind == "PetLocked") then
			renameNote.Text = Lang.t(`notify.{kind}`)
			renameNote.TextColor3 = UiKit.RED
			renameNote.Visible = true
			return
		end
		local message = if kind == "PetSlotsFull"
			then Lang.t("pets.slotsFull")
			elseif kind == "NoPets" then Lang.t("pets.empty")
			elseif kind == "NotEnoughPets" then Lang.t("notify.NotEnoughPets")
			elseif kind == "MaxVariant" then Lang.t("notify.MaxVariant")
			elseif kind == "EmptyTeam" then Lang.t("notify.EmptyTeam")
			elseif kind == "PetLocked" then Lang.t("notify.PetLocked")
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
