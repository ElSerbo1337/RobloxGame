--!strict
-- World intro (#79): the first time the player enters a world, the server sends
-- "WorldIntro" (world id; already marked as seen and saved, so it never plays twice).
-- The camera flies a 3-4 s arc over the island (GameConfig.worldIntro.seconds) and
-- glides back to the normal view behind the character, while the screen shows the
-- world name in big letters and the toppings that are new in this world
-- (rules.newToppingsOf: 3D model or a coloured circle with the initial as fallback).
-- A tap, click or key skips it. Camera shake (a soft rumble when the name lands) only
-- with Settings.cameraShake(), the white flash at the start only with
-- Settings.screenFlashes(). Works for every world in GameConfig.worlds (island
-- position from IslandPlan). Purely cosmetic; switch: features.worldIntro.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local IslandPlan = require(ReplicatedStorage.Shared.IslandPlan)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local Lang = require(script.Parent.Lang)
local Settings = require(script.Parent.Settings)
local Sounds = require(script.Parent.Sounds)
local UiKit = require(script.Parent.UiKit)

local rules = GameRules.new(GameConfig)
local plan = IslandPlan.new(GameConfig.islands, GameConfig.worlds)

-- Share of the flight spent on the arc over the island; the rest glides back.
local ARC_SHARE = 0.78
-- Arc around the island centre: from the far side (-Z) round to the arrival side (+Z),
-- where the bridge from the previous world comes in.
local ARC_FROM = math.rad(200)
local ARC_TO = math.rad(40)
local SHAKE_SECONDS = 0.6
local SHAKE_STUDS = 0.5
local CARD = 92
local MAX_TOPPINGS = 6
local BAR_HEIGHT = 0.11

local WorldIntro = {}

local function rgb(c: { number }?): Color3
	return if c then Color3.fromRGB(c[1], c[2], c[3]) else UiKit.ORANGE
end

local function ease(t: number): number
	return t * t * (3 - 2 * t)
end

local function worldIndex(worldId: string): number?
	for index, world in GameConfig.worlds do
		if world.id == worldId then
			return index
		end
	end
	return nil
end

-- Freezes or frees the character's controls (PlayerModule); fails quietly without it.
local function setControls(enabled: boolean)
	local player = Players.LocalPlayer
	local scripts = player:FindFirstChild("PlayerScripts")
	local module = scripts and scripts:FindFirstChild("PlayerModule")
	if module == nil or not module:IsA("ModuleScript") then
		return
	end
	pcall(function()
		local controls = (require(module) :: any):GetControls()
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end)
end

-- One topping card: 3D model in a cream circle (or the world colour with the initial)
-- and the name below.
local function toppingCard(parent: Instance, toppingId: string, color: Color3, order: number): Frame
	local topping = GameConfig.toppings[toppingId]
	local card = Instance.new("Frame")
	card.LayoutOrder = order
	card.BackgroundTransparency = 1
	card.Size = UDim2.fromOffset(CARD, CARD + 30)
	card.Parent = parent

	local circle = Instance.new("Frame")
	circle.AnchorPoint = Vector2.new(0.5, 0)
	circle.Position = UDim2.fromScale(0.5, 0)
	circle.Size = UDim2.fromOffset(CARD - 8, CARD - 8)
	circle.BackgroundColor3 = UiKit.CREAM
	UiKit.corner(circle, (CARD - 8) / 2)
	UiKit.stroke(circle, 3)
	circle.Parent = card

	local view = ModelLibrary.viewport(toppingId)
	if view then
		view.AnchorPoint = Vector2.new(0.5, 0.5)
		view.Position = UDim2.fromScale(0.5, 0.5)
		view.Size = UDim2.fromScale(1.2, 1.2)
		view.Parent = circle
	else
		circle.BackgroundColor3 = color
		local name = if topping then Lang.name(topping) else toppingId
		local initial = UiKit.label(circle, utf8.char(utf8.codepoint(name, 1)))
		initial.Size = UDim2.fromScale(0.6, 0.6)
		initial.AnchorPoint = Vector2.new(0.5, 0.5)
		initial.Position = UDim2.fromScale(0.5, 0.5)
		initial.TextColor3 = UiKit.CREAM
		initial.TextStrokeColor3 = UiKit.DARK
		initial.TextStrokeTransparency = 0
	end

	local label = UiKit.label(card, if topping then Lang.name(topping) else toppingId)
	label.Position = UDim2.new(0, -6, 0, CARD - 2)
	label.Size = UDim2.new(1, 12, 0, 28)
	label.TextColor3 = UiKit.CREAM
	label.TextStrokeColor3 = UiKit.DARK
	label.TextStrokeTransparency = 0
	return card
end

function WorldIntro.start()
	if not Features.new(GameConfig.features).enabled("worldIntro") then
		return
	end
	local player = Players.LocalPlayer
	local half: number = GameConfig.islands.worldHalfSize
	local seconds: number = GameConfig.worldIntro.seconds

	local gui = Instance.new("ScreenGui")
	gui.Name = "WorldIntro"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Enabled = false
	UiKit.autoScale(gui)

	-- Cinema bars top and bottom (they slide in).
	local bars: { Frame } = {}
	for i = 1, 2 do
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.Size = UDim2.fromScale(1, BAR_HEIGHT)
		bar.AnchorPoint = Vector2.new(0, if i == 1 then 1 else 0)
		bar.Parent = gui
		bars[i] = bar
	end

	local flash = Instance.new("Frame")
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundTransparency = 1
	flash.Parent = gui

	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.AnchorPoint = Vector2.new(0.5, 0)
	content.Position = UDim2.fromScale(0.5, 0.16)
	content.Size = UDim2.new(1, -32, 0.7, 0)
	content.Parent = gui

	local subtitle = UiKit.label(content, "")
	subtitle.Size = UDim2.new(1, 0, 0, 40)
	subtitle.TextColor3 = UiKit.COIN
	subtitle.TextStrokeColor3 = UiKit.DARK
	subtitle.TextStrokeTransparency = 0

	local title = UiKit.label(content, "")
	title.Position = UDim2.fromOffset(0, 40)
	title.Size = UDim2.new(1, 0, 0, 96)
	title.TextColor3 = UiKit.CREAM
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = UiKit.DARK
	titleStroke.Thickness = 4
	titleStroke.Parent = title
	local titleMax = Instance.new("UITextSizeConstraint")
	titleMax.MaxTextSize = 90
	titleMax.Parent = title

	local toppingsTitle = UiKit.label(content, "")
	toppingsTitle.Position = UDim2.fromOffset(0, 150)
	toppingsTitle.Size = UDim2.new(1, 0, 0, 34)
	toppingsTitle.TextColor3 = UiKit.CREAM
	toppingsTitle.TextStrokeColor3 = UiKit.DARK
	toppingsTitle.TextStrokeTransparency = 0

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, 192)
	row.Size = UDim2.new(1, 0, 0, CARD + 30)
	row.Parent = content
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Padding = UDim.new(0, 10)
	rowLayout.Parent = row

	local hint = UiKit.label(gui, "")
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -12)
	hint.Size = UDim2.new(0.8, 0, BAR_HEIGHT * 0.45, 0)
	hint.TextColor3 = UiKit.CREAM

	-- Catches the tap/click anywhere on the screen.
	local catcher = Instance.new("TextButton")
	catcher.Text = ""
	catcher.BackgroundTransparency = 1
	catcher.Size = UDim2.fromScale(1, 1)
	catcher.ZIndex = 10
	catcher.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")

	local queue: { string } = {}
	local playing = false
	local skipRequested = false

	catcher.Activated:Connect(function()
		skipRequested = true
	end)
	UserInputService.InputBegan:Connect(function(input)
		if not playing then
			return
		end
		local kind = input.UserInputType
		if
			kind == Enum.UserInputType.Keyboard
			or kind == Enum.UserInputType.Touch
			or kind == Enum.UserInputType.MouseButton1
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			skipRequested = true
		end
	end)

	local function fill(worldId: string, color: Color3)
		subtitle.Text = Lang.t("intro.newWorld")
		title.Text = Lang.worldName(worldId)
		title.TextColor3 = color:Lerp(UiKit.CREAM, 0.35)
		hint.Text = Lang.t(if Settings.isTouch then "intro.skipTouch" else "intro.skipMouse")
		for _, child in row:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local toppings = rules.newToppingsOf(worldId)
		toppingsTitle.Visible = #toppings > 0
		toppingsTitle.Text = Lang.t("intro.newToppings")
		local cards = {}
		for i, toppingId in toppings do
			if i > MAX_TOPPINGS then
				break
			end
			local card = toppingCard(row, toppingId, color, i)
			card.Visible = false
			table.insert(cards, card)
		end
		return cards
	end

	local function play(worldId: string)
		local index = worldIndex(worldId)
		local camera = Workspace.CurrentCamera
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if index == nil or camera == nil or humanoid == nil then
			return
		end
		local world = GameConfig.worlds[index]
		local color = rgb(world.color)
		local c = plan.worldCenter(index)
		local center = Vector3.new(c[1], c[2], c[3])
		local focus = center + Vector3.new(0, 6, 0)

		local cards = fill(worldId, color)
		skipRequested = false
		-- Where the flight ends: the usual view from behind and above the character. Worked
		-- out every frame, because after a portal the character may arrive a moment later.
		local function returnTo(): CFrame
			local root = (character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
			if root == nil then
				return camera.CFrame
			end
			local back = -root.CFrame.LookVector * Vector3.new(1, 0, 1)
			back = if back.Magnitude > 0.01 then back.Unit else Vector3.new(0, 0, 1)
			return CFrame.lookAt(root.Position + back * 14 + Vector3.new(0, 7, 0), root.Position + Vector3.new(0, 2, 0))
		end
		local oldType = camera.CameraType
		camera.CameraType = Enum.CameraType.Scriptable
		setControls(false)
		humanoid:Move(Vector3.zero)

		gui.Enabled = true
		content.Visible = true
		bars[1].Position = UDim2.fromScale(0, 0)
		bars[2].Position = UDim2.fromScale(0, 1)
		TweenService:Create(bars[1], TweenInfo.new(0.35), { Position = UDim2.fromScale(0, BAR_HEIGHT) }):Play()
		TweenService:Create(bars[2], TweenInfo.new(0.35), { Position = UDim2.fromScale(0, 1 - BAR_HEIGHT) }):Play()
		if Settings.screenFlashes() then
			flash.BackgroundTransparency = 0.2
			TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		else
			flash.BackgroundTransparency = 1
		end
		Sounds.play("Gem")
		UiKit.pop(title, 1.6)
		UiKit.pop(subtitle, 1.3)
		for i, card in cards do
			task.delay(0.35 + 0.15 * i, function()
				if playing then
					card.Visible = true
					UiKit.pop(card, 0.4)
				end
			end)
		end

		local shake = Settings.cameraShake()
		local arcEnd: CFrame? = nil
		local elapsed = 0
		while elapsed < seconds and not skipRequested and player.Character == character do
			elapsed += RunService.RenderStepped:Wait()
			local t = math.min(elapsed / seconds, 1)
			local frame: CFrame
			if t < ARC_SHARE then
				local a = ease(t / ARC_SHARE)
				local angle = ARC_FROM + (ARC_TO - ARC_FROM) * a
				local radius = half * (1.6 - 0.5 * a)
				local height = half * (1.0 - 0.55 * a)
				local position = center + Vector3.new(math.sin(angle) * radius, height, math.cos(angle) * radius)
				frame = CFrame.lookAt(position, focus)
				arcEnd = frame
			else
				local from = arcEnd or camera.CFrame
				frame = from:Lerp(returnTo(), ease((t - ARC_SHARE) / (1 - ARC_SHARE)))
			end
			if shake and elapsed < SHAKE_SECONDS then
				local strength = SHAKE_STUDS * (1 - elapsed / SHAKE_SECONDS)
				frame = frame
					* CFrame.new((math.random() - 0.5) * 2 * strength, (math.random() - 0.5) * 2 * strength, 0)
			end
			camera.CFrame = frame
		end

		-- Back to the normal camera behind the character (also when skipped).
		camera.CFrame = returnTo()
		camera.CameraType = if oldType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else oldType
		if humanoid.Parent then
			camera.CameraSubject = humanoid
		end
		setControls(true)
		content.Visible = false
		local out = TweenInfo.new(0.25)
		TweenService:Create(bars[1], out, { Position = UDim2.fromScale(0, 0) }):Play()
		TweenService:Create(bars[2], out, { Position = UDim2.fromScale(0, 1) }):Play()
		task.wait(0.25)
	end

	local function playQueue()
		playing = true
		while #queue > 0 do
			local worldId = table.remove(queue, 1) :: string
			local ok, err = pcall(play, worldId)
			if not ok then
				warn(`[WorldIntro] {worldId}: {err}`)
				local camera = Workspace.CurrentCamera
				if camera then
					camera.CameraType = Enum.CameraType.Custom
				end
				setControls(true)
			end
		end
		gui.Enabled = false
		playing = false
	end

	Net.event("WorldIntro").OnClientEvent:Connect(function(worldId: unknown)
		if type(worldId) ~= "string" or worldIndex(worldId) == nil or table.find(queue, worldId) then
			return
		end
		table.insert(queue, worldId)
		if not playing then
			task.spawn(playQueue)
		end
	end)
end

return WorldIntro
