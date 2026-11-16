--!strict
-- Floating preview above each egg: all pets with rarity color, chance in % and bonus,
-- plus a big "1 öffnen" button. Shows up when the player comes close.
-- The button only sends the wish "OpenEgg"; the server decides.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Net = require(ReplicatedStorage.Shared.Net)
local UiKit = require(script.Parent.UiKit)

-- Studs between player and egg at which the preview appears.
local SHOW_DISTANCE = 20
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

		-- Placeholder picture: a dot in the rarity color.
		local icon = Instance.new("Frame")
		icon.Position = UDim2.fromOffset(6, 4)
		icon.Size = UDim2.fromOffset(32, 32)
		icon.BackgroundColor3 = color
		UiKit.corner(icon, 16)
		UiKit.stroke(icon, 2)
		icon.Parent = row

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

		local bonus = UiKit.label(row, UiKit.bonusText(entry.bonus))
		bonus.Position = UDim2.new(0.75, 0, 0, 6)
		bonus.Size = UDim2.new(0.25, -8, 0, 28)
		bonus.TextColor3 = Color3.fromRGB(40, 130, 40)
	end

	local openText = `1 öffnen – {preview.price} Münzen`
	local button = UiKit.button(root, openText, UiKit.GREEN)
	button.Name = "OpenOne"
	button.Position = UDim2.new(0, 16, 1, -84)
	button.Size = UDim2.new(1, -32, 0, 70)

	billboard.Parent = playerGui

	local busyUntil = 0
	local lastRequest = -math.huge
	button.Activated:Connect(function()
		local now = os.clock()
		if now < busyUntil then
			return
		end
		busyUntil = now + BUTTON_COOLDOWN
		lastRequest = now
		Net.event("OpenEgg"):FireServer(eggId)
	end)

	-- Feedback when the server says no (only for a request from this preview).
	Net.event("Notify").OnClientEvent:Connect(function(kind: string)
		if os.clock() - lastRequest > 2 or not billboard.Enabled then
			return
		end
		if kind == "NotEnoughCoins" then
			busyUntil = 0
			button.Text = "Zu wenig Münzen!"
			button.BackgroundColor3 = UiKit.RED
			UiKit.pop(button)
			task.delay(1.5, function()
				button.Text = openText
				button.BackgroundColor3 = UiKit.GREEN
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
		for _, preview in previews do
			local near = root ~= nil and (root.Position - preview.part.Position).Magnitude <= SHOW_DISTANCE
			if near ~= preview.billboard.Enabled then
				preview.billboard.Enabled = near
			end
		end
	end)
end

return EggPreview
