--!strict
-- Floating preview above each egg: all pets with rarity color, chance in % and bonus,
-- plus a big "1 öffnen" button (and "3 öffnen" after the gem upgrade). Shows up when
-- the player comes close. While the luck potion runs, the chances shown are the lucky ones
-- (from the ActivePotions attribute) and the title says so.
-- The button only sends the wish "OpenEgg"; the server decides.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Net = require(ReplicatedStorage.Shared.Net)
local PetIcon = require(script.Parent.PetIcon)
local SignCulling = require(script.Parent.SignCulling)
local UiKit = require(script.Parent.UiKit)

-- Studs between player and egg at which the preview appears.
local SHOW_DISTANCE = 20
-- Pet name tags this far beyond SHOW_DISTANCE from an open preview are hidden too
-- (pets follow a few studs behind their owner).
local PET_TAG_MARGIN = 10
-- Button stays disabled this long after a request (the hatch animation is playing).
local BUTTON_COOLDOWN = 2.6

local ROW_HEIGHT = 44
local WIDTH = 400

local EggPreview = {}

local rules = GameRules.new(GameConfig)

local function buildPreview(eggId: string, adornee: BasePart, playerGui: Instance)
	local egg = GameConfig.eggs[eggId]
	local preview = rules.eggPreview(eggId)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = `EggPreview_{eggId}`
	billboard.Adornee = adornee
	billboard.Active = true
	billboard.ResetOnSpawn = false
	billboard.Enabled = false
	billboard.LightInfluence = 0
	-- Draw above other billboards (e.g. pet name tags), which are not AlwaysOnTop.
	billboard.AlwaysOnTop = true
	local height = 64 + #preview.pets * ROW_HEIGHT + 96
	billboard.Size = UDim2.fromOffset(WIDTH, height)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, adornee.Size.Y / 2 + 6, 0)

	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = UiKit.CREAM
	root.BackgroundTransparency = 0.05
	UiKit.corner(root, 22)
	UiKit.stroke(root)
	root.Parent = billboard

	-- Shrink on small screens, like the HUD.
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = root
	local camera = Workspace.CurrentCamera
	if camera then
		uiScale.Scale = math.clamp(math.min(camera.ViewportSize.X / 1100, camera.ViewportSize.Y / 650), 0.6, 1.2)
	end

	local title = UiKit.label(root, egg.displayName)
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -32, 0, 44)

	-- Chance label per pet id, updated when the luck potion starts or ends.
	local chanceLabels: { [string]: TextLabel } = {}

	for i, entry in preview.pets do
		local pet = GameConfig.pets[entry.petId]
		local color = UiKit.rarityColor(entry.rarity)
		local row = Instance.new("Frame")
		row.Position = UDim2.fromOffset(12, 60 + (i - 1) * ROW_HEIGHT)
		row.Size = UDim2.new(1, -24, 0, ROW_HEIGHT - 4)
		row.BackgroundColor3 = color
		row.BackgroundTransparency = 0.55
		UiKit.corner(row, 12)
		row.Parent = root

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

		local name = UiKit.label(row, pet.displayName)
		name.Position = UDim2.fromOffset(46, 2)
		name.Size = UDim2.new(0.5, -46, 0, 22)
		name.TextXAlignment = Enum.TextXAlignment.Left

		local rarity = UiKit.label(row, GameConfig.rarities[entry.rarity].displayName)
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

	local player = Players.LocalPlayer

	local function updateLuck()
		local ok, active = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("ActivePotions") or "{}")
		local activePotions = if ok and type(active) == "table" then active else {}
		-- eggPreview only reads the running potions from the state.
		local lucky = rules.eggPreview(eggId, { activePotions = activePotions } :: any)
		local hasLuck = (activePotions.Luck or 0) > 0
		title.Text = if hasLuck then `{egg.displayName} 🍀 Glück!` else egg.displayName
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
	updateLuck()

	local openText = `1 öffnen – {preview.price} Münzen`
	local button = UiKit.button(root, openText, UiKit.GREEN)
	button.Name = "OpenOne"
	button.Position = UDim2.new(0, 16, 1, -84)
	button.Size = UDim2.new(1, -32, 0, 70)

	-- "3 öffnen" only after the gem upgrade; then both buttons share the row.
	local tripleText = `3 öffnen – {preview.price * 3}`
	local tripleButton = UiKit.button(root, tripleText, UiKit.COIN)
	tripleButton.Name = "OpenThree"
	tripleButton.AnchorPoint = Vector2.new(1, 0)
	tripleButton.Position = UDim2.new(1, -16, 1, -84)
	tripleButton.Size = UDim2.new(0.5, -22, 0, 70)
	tripleButton.Visible = false

	local function updateTriple()
		local unlocked = ((player:GetAttribute("EggsPerOpen") :: number?) or 1) >= 3
		tripleButton.Visible = unlocked
		button.Size = if unlocked then UDim2.new(0.5, -22, 0, 70) else UDim2.new(1, -32, 0, 70)
		button.Text = if unlocked then `1 öffnen – {preview.price}` else openText
	end
	player:GetAttributeChangedSignal("EggsPerOpen"):Connect(updateTriple)
	updateTriple()

	billboard.Parent = playerGui

	local busyUntil = 0
	local lastRequest = -math.huge
	local lastButton = button
	local function request(source: TextButton, count: number)
		local now = os.clock()
		if now < busyUntil then
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

	-- Feedback when the server says no (only for a request from this preview).
	Net.event("Notify").OnClientEvent:Connect(function(kind: string)
		if os.clock() - lastRequest > 2 or not billboard.Enabled then
			return
		end
		local message = if kind == "NotEnoughCoins"
			then "Zu wenig Münzen!"
			elseif kind == "InventoryFull" then "Inventar voll!"
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
				if target == tripleButton then
					target.Text = tripleText
				else
					updateTriple()
				end
			end)
		end
	end)

	return billboard
end

function EggPreview.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local eggsFolder = Workspace:WaitForChild("Eggs")

	local previews: { { billboard: BillboardGui, part: BasePart } } = {}

	local function addEgg(model: Instance)
		local eggId = model:GetAttribute("EggId")
		if type(eggId) ~= "string" or GameConfig.eggs[eggId] == nil then
			return
		end
		local body = model:WaitForChild("Body", 10) :: BasePart?
		if body == nil then
			return
		end
		table.insert(previews, { billboard = buildPreview(eggId, body, playerGui), part = body })
	end

	eggsFolder.ChildAdded:Connect(addEgg)
	for _, model in eggsFolder:GetChildren() do
		task.spawn(addEgg, model)
	end

	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local openAt: Vector3? = nil
		for _, preview in previews do
			local near = root ~= nil and (root.Position - preview.part.Position).Magnitude <= SHOW_DISTANCE
			if near ~= preview.billboard.Enabled then
				preview.billboard.Enabled = near
			end
			if near then
				openAt = preview.part.Position
			end
		end
		-- Pet name tags near an open preview would cover its buttons: hide them.
		SignCulling.setPetTagZone(openAt, SHOW_DISTANCE + PET_TAG_MARGIN)
	end)
end

return EggPreview
