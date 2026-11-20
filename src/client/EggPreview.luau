--!strict
-- Egg preview panel on the right of the HUD (zone eggPreview, in place of the right
-- column, which hides meanwhile): all pets of the nearest egg with rarity color, chance
-- in % and bonus, plus a big "1 öffnen" button (and "3 öffnen" after the gem upgrade).
-- Opens when the player comes close to an egg and closes when leaving. It is a menu
-- (UiKit.registerMenu "eggPreview"): opening it closes other menus; closed by another
-- menu, it stays closed until the player leaves the egg and comes back.
-- While the luck potion runs, the chances shown are the lucky ones (from the
-- ActivePotions attribute) and the title says so.
-- The button only sends the wish "OpenEgg"; the server decides.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Net = require(ReplicatedStorage.Shared.Net)
local Lang = require(script.Parent.Lang)
local PetIcon = require(script.Parent.PetIcon)
local SignCulling = require(script.Parent.SignCulling)
local UiKit = require(script.Parent.UiKit)

-- Studs between player and egg at which the preview appears.
local SHOW_DISTANCE = 20
-- Studs within which a closed panel opens (smaller than SHOW_DISTANCE, see Heartbeat).
local OPEN_DISTANCE = 14
-- Pet name tags this far beyond SHOW_DISTANCE from the nearest egg are hidden
-- (pets follow a few studs behind their owner).
local PET_TAG_MARGIN = 10
-- Button stays disabled this long after a request (the hatch animation is playing).
local BUTTON_COOLDOWN = 2.6

local SIZES = UiKit.Layout.EGG_PREVIEW
local WIDTH = SIZES.width
local HEADER = SIZES.header
local ROW_HEIGHT = SIZES.row
local FOOTER = SIZES.footer

local EggPreview = {}

local rules = GameRules.new(GameConfig)

type Panel = {
	gui: ScreenGui,
	show: (eggId: string) -> (),
	hide: () -> (),
	isOpen: () -> boolean,
}

local function buildPanel(playerGui: Instance): Panel
	local player = Players.LocalPlayer

	local gui = Instance.new("ScreenGui")
	gui.Name = "EggPreview"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 2
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	UiKit.autoScale(gui)

	local root = Instance.new("Frame")
	root.Name = "Panel"
	root.BackgroundColor3 = UiKit.CREAM
	root.BackgroundTransparency = 0.05
	UiKit.corner(root, 22)
	UiKit.stroke(root)
	local resize = UiKit.placePanel(
		gui,
		root,
		"eggPreview",
		Vector2.new(WIDTH, HEADER + ROW_HEIGHT + FOOTER),
		HEADER + ROW_HEIGHT + FOOTER,
		Vector2.new(1, 0)
	)

	local title = UiKit.label(root, "")
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -32, 0, 44)

	-- Pet rows scroll when the panel is shorter than all of them.
	local list = Instance.new("ScrollingFrame")
	list.Name = "Pets"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(12, HEADER)
	list.Size = UDim2.new(1, -24, 1, -(HEADER + FOOTER))
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = UiKit.DARK
	list.Parent = root
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 4)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list

	local button = UiKit.button(root, "", UiKit.GREEN)
	button.Name = "OpenOne"
	button.Position = UDim2.new(0, 16, 1, -84)
	button.Size = UDim2.new(1, -32, 0, 70)

	-- "3 öffnen" only after the gem upgrade; then both buttons share the row.
	local tripleButton = UiKit.button(root, "", UiKit.COIN)
	tripleButton.Name = "OpenThree"
	tripleButton.AnchorPoint = Vector2.new(1, 0)
	tripleButton.Position = UDim2.new(1, -16, 1, -84)
	tripleButton.Size = UDim2.new(0.5, -22, 0, 70)
	tripleButton.Visible = false

	gui.Parent = playerGui

	-- The egg the panel currently shows (content is rebuilt when it changes).
	local eggId: string? = nil
	local price = 0
	-- Chance label per pet id, updated when the luck potion starts or ends.
	local chanceLabels: { [string]: TextLabel } = {}

	local function updateLuck()
		local current = eggId
		if current == nil then
			return
		end
		local egg = GameConfig.eggs[current]
		local ok, active = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("ActivePotions") or "{}")
		local activePotions = if ok and type(active) == "table" then active else {}
		-- eggPreview only reads the running potions from the state.
		local lucky = rules.eggPreview(current, { activePotions = activePotions } :: any)
		local hasLuck = (activePotions.Luck or 0) > 0
		title.Text = if hasLuck then Lang.t("egg.luck", { egg = Lang.name(egg) }) else Lang.name(egg)
		for _, entry in lucky.pets do
			local chance = chanceLabels[entry.petId]
			if chance then
				chance.Text = UiKit.chanceText(entry.chancePercent)
				chance.TextColor3 = if hasLuck then Color3.fromRGB(40, 130, 40) else UiKit.DARK
			end
		end
	end
	-- Only re-render when luck switches on or off (the attribute also changes while it counts down).
	local hadLuck: boolean? = nil
	player:GetAttributeChangedSignal("ActivePotions"):Connect(function()
		local hasLuck = string.find(tostring(player:GetAttribute("ActivePotions")), '"Luck"') ~= nil
		if hasLuck ~= hadLuck then
			hadLuck = hasLuck
			updateLuck()
		end
	end)

	local function tripleText(): string
		return Lang.t("egg.openThree", { price = price * 3 })
	end
	local function updateTriple()
		local unlocked = ((player:GetAttribute("EggsPerOpen") :: number?) or 1) >= 3
		tripleButton.Visible = unlocked
		tripleButton.Text = tripleText()
		button.Size = if unlocked then UDim2.new(0.5, -22, 0, 70) else UDim2.new(1, -32, 0, 70)
		button.Text = if unlocked
			then Lang.t("egg.openOne", { price = price })
			else Lang.t("egg.openOneCoins", { price = price })
	end
	player:GetAttributeChangedSignal("EggsPerOpen"):Connect(updateTriple)

	local function fill(newEggId: string)
		eggId = newEggId
		local preview = rules.eggPreview(newEggId)
		price = preview.price
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		table.clear(chanceLabels)

		for i, entry in preview.pets do
			local pet = GameConfig.pets[entry.petId]
			local color = UiKit.rarityColor(entry.rarity)
			local row = Instance.new("Frame")
			row.LayoutOrder = i
			row.Size = UDim2.new(1, -12, 0, ROW_HEIGHT - 4)
			row.BackgroundColor3 = color
			row.BackgroundTransparency = 0.55
			UiKit.corner(row, 12)
			row.Parent = list

			-- Picture: the 3D pet (imported model), otherwise a dot in the rarity color.
			local icon = Instance.new("Frame")
			icon.Position = UDim2.fromOffset(6, 4)
			icon.Size = UDim2.fromOffset(32, 32)
			icon.BackgroundColor3 = color
			UiKit.corner(icon, 16)
			UiKit.stroke(icon, 2)
			icon.Parent = row
			if PetIcon.show(icon, entry.petId, 1.35) then
				icon.BackgroundColor3 = UiKit.CREAM
			end

			local name = UiKit.label(row, Lang.name(pet))
			name.Position = UDim2.fromOffset(46, 2)
			name.Size = UDim2.new(0.5, -46, 0, 22)
			name.TextXAlignment = Enum.TextXAlignment.Left

			local rarity = UiKit.label(row, Lang.name(GameConfig.rarities[entry.rarity]))
			rarity.Position = UDim2.fromOffset(46, 23)
			rarity.Size = UDim2.new(0.5, -46, 0, 15)
			rarity.TextXAlignment = Enum.TextXAlignment.Left
			rarity.TextColor3 = color
			rarity.TextStrokeColor3 = UiKit.DARK
			rarity.TextStrokeTransparency = 0.3

			local chance = UiKit.label(row, UiKit.chanceText(entry.chancePercent))
			chance.Position = UDim2.new(0.5, 0, 0, 6)
			chance.Size = UDim2.new(0.25, 0, 0, 28)
			chanceLabels[entry.petId] = chance

			local bonus = UiKit.label(row, UiKit.bonusText(entry.bonus))
			bonus.Position = UDim2.new(0.75, 0, 0, 6)
			bonus.Size = UDim2.new(0.25, -8, 0, 28)
			bonus.TextColor3 = Color3.fromRGB(40, 130, 40)
		end
		list.CanvasPosition = Vector2.zero
		-- Tall enough for all rows; on short screens it gets shorter and the list scrolls.
		-- Narrower on small screens, so it stays readable (HudLayout.eggPreviewSize).
		local width = UiKit.Layout.eggPreviewSize(UiKit.isSmallScreen()).w
		resize(Vector2.new(width, HEADER + #preview.pets * ROW_HEIGHT + FOOTER), HEADER + ROW_HEIGHT + FOOTER)
		updateLuck()
		updateTriple()
	end

	local busyUntil = 0
	local lastRequest = -math.huge
	local lastButton = button
	local function request(source: TextButton, count: number)
		local now = os.clock()
		if now < busyUntil or eggId == nil then
			return
		end
		busyUntil = now + BUTTON_COOLDOWN
		lastRequest = now
		lastButton = source
		Net.event("OpenEgg"):FireServer(eggId, count)
	end
	button.Activated:Connect(function()
		request(button, 1)
	end)
	tripleButton.Activated:Connect(function()
		request(tripleButton, 3)
	end)

	-- Feedback when the server says no (only for a request from this panel).
	Net.event("Notify").OnClientEvent:Connect(function(kind: string)
		if os.clock() - lastRequest > 2 or not gui.Enabled then
			return
		end
		local message = if kind == "NotEnoughCoins"
			then Lang.t("egg.notEnoughCoins")
			elseif kind == "InventoryFull" then Lang.t("egg.inventoryFull")
			else nil
		if message then
			busyUntil = 0
			local target = lastButton
			local color = target.BackgroundColor3
			target.Text = message
			target.BackgroundColor3 = UiKit.RED
			UiKit.pop(target)
			task.delay(1.5, function()
				target.BackgroundColor3 = color
				updateTriple()
			end)
		end
	end)

	local function show(newEggId: string)
		if newEggId ~= eggId then
			fill(newEggId)
		end
		if not gui.Enabled then
			gui.Enabled = true
			UiKit.setRightColumnHidden(true)
			UiKit.menuOpened("eggPreview")
			UiKit.pop(root, 0.85)
		end
	end
	local function hide()
		if gui.Enabled then
			gui.Enabled = false
			UiKit.setRightColumnHidden(false)
		end
	end
	return {
		gui = gui,
		show = show,
		hide = hide,
		isOpen = function()
			return gui.Enabled
		end,
	}
end

function EggPreview.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local eggsFolder = Workspace:WaitForChild("Eggs")
	local panel = buildPanel(playerGui)

	type Egg = { eggId: string, part: BasePart }
	local eggs: { Egg } = {}

	-- The egg the panel is open for, and an egg whose panel another menu closed: it
	-- stays closed until the player leaves that egg.
	local shownFor: Egg? = nil
	local closedFor: Egg? = nil
	UiKit.registerMenu("eggPreview", function()
		if panel.isOpen() then
			closedFor = shownFor
		end
		shownFor = nil
		panel.hide()
	end)

	local function addEgg(model: Instance)
		local eggId = model:GetAttribute("EggId")
		if type(eggId) ~= "string" or GameConfig.eggs[eggId] == nil then
			return
		end
		local body = model:WaitForChild("Body", 10) :: BasePart?
		if body == nil then
			return
		end
		table.insert(eggs, { eggId = eggId, part = body })
	end

	eggsFolder.ChildAdded:Connect(addEgg)
	for _, model in eggsFolder:GetChildren() do
		task.spawn(addEgg, model)
	end

	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		-- Only the nearest egg in range is shown: two eggs stand side by side in every world (#39).
		local nearest: Egg? = nil
		-- Hysteresis: a closed panel only opens within OPEN_DISTANCE, an open one stays
		-- until SHOW_DISTANCE. The shop zone is ~17 studs from the egg next to it, so
		-- opening at 20 let the shop close the panel at once and keep it closed (#54).
		local nearestDistance = if shownFor ~= nil then SHOW_DISTANCE else OPEN_DISTANCE
		if root ~= nil then
			for _, egg in eggs do
				local distance = (root.Position - egg.part.Position).Magnitude
				if distance <= nearestDistance then
					nearest, nearestDistance = egg, distance
				end
			end
		end
		if closedFor ~= nil and nearest ~= closedFor then
			closedFor = nil
		end
		if nearest == nil or nearest == closedFor then
			if shownFor ~= nil then
				shownFor = nil
				panel.hide()
			end
		elseif nearest ~= shownFor then
			shownFor = nearest
			panel.show(nearest.eggId)
		end
		local openAt: Vector3? = if nearest then nearest.part.Position else nil
		-- Pet name tags near the egg would cover it and the hatching: hide them.
		SignCulling.setPetTagZone(openAt, SHOW_DISTANCE + PET_TAG_MARGIN)
	end)
end

return EggPreview
