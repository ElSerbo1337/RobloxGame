--!strict
-- Lucky wheel on the client (#98, feature "luckyWheel"):
-- * Side bar tile "Glücksrad" (#75, order 80) with a red dot and the caption "Gratis!"
--   while a free spin is left today.
-- * Menu (from anywhere, also from the 3D wheel's prompt/click on the spawn island): a live
--   3D view of the wheel (ViewportFrame with a copy of the world wheel, labels drawn on
--   top), the fields with reward and chance, today's free spins / time to the play time
--   bonus spin, and the spin button ("Gratis drehen!" or the gem price).
-- * Spinning only sends the wish SpinWheel(expectFree); the server draws the field and
--   answers WheelResult. Then the wheel in the menu and the 3D wheel (only for this player)
--   turn onto that field with ticks, the lights blink faster, and the win is shown at the end.
--   Jackpot: a golden screen flash only with Settings.screenFlashes().
-- Reads the attribute Wheel (JSON, see Net / WheelService).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Lang = require(script.Parent.Lang)
local Net = require(ReplicatedStorage.Shared.Net)
local Settings = require(script.Parent.Settings)
local SideBar = require(script.Parent.SideBar)
local Sounds = require(script.Parent.Sounds)
local UiKit = require(script.Parent.UiKit)

local TILE_ID = "wheel"
local MENU_ID = "wheel"
local PROMPT_NAME = "WheelPrompt"
local TILE_COLOR = Color3.fromRGB(170, 90, 220)
local PANEL_SIZE = Vector2.new(760, 500)
local VIEW_SIZE = 380
local SPIN_SECONDS = 4.5
local TURNS = 4
-- Camera distance and field of view of the menu view; labels sit at 62 % of the radius.
local CAMERA_DISTANCE = 20
local CAMERA_FOV = 40
local LABEL_RADIUS = 5 * 0.62

type Reward = { kind: string, amount: number, potionId: string? }
type Field = { id: string, jackpot: boolean, chance: number, rewards: { Reward } }
type Status = { free: number, freeTotal: number, bonusSeconds: number, price: number, fields: { Field } }

local WheelMenu = {}

local function readStatus(player: Player): Status
	local empty: Status = { free = 0, freeTotal = 0, bonusSeconds = -1, price = 0, fields = {} }
	local json = player:GetAttribute("Wheel")
	if type(json) ~= "string" then
		return empty
	end
	local ok, value = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok or type(value) ~= "table" or type(value.fields) ~= "table" then
		return empty
	end
	return value :: Status
end

local function clockText(seconds: number): string
	local total = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", total // 60, total % 60)
end

local function percentText(chance: number): string
	local text = string.format("%g", math.floor(chance * 1000 + 0.5) / 10)
	if Lang.language == "de" then
		text = string.gsub(text, "%.", ",")
	end
	return Lang.t("wheel.chance", { percent = text })
end

-- Short label of a field (same as on the 3D wheel).
local function fieldLabel(index: number): string
	local field = GameConfig.luckyWheel.fields[index]
	if field.jackpot then
		return Lang.t("sign.wheelJackpot")
	end
	local reward = field.rewards[1]
	if reward.kind == "Coins" then
		return Lang.t("sign.wheelCoins", { minutes = reward.minutes })
	elseif reward.kind == "Gems" then
		return Lang.t("sign.wheelGems", { amount = reward.amount })
	end
	return Lang.t("sign.wheelPotions", { amount = reward.amount })
end

local function fieldColor(index: number): Color3
	local rgb = GameConfig.luckyWheel.fields[index].color
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- Angle (degrees, clockwise from the top) of a field's middle on the wheel.
local function fieldAngle(index: number): number
	return (index - 1) * 360 / #GameConfig.luckyWheel.fields
end

function WheelMenu.start()
	if not Features.new(GameConfig.features).enabled("luckyWheel") then
		return
	end
	local player = Players.LocalPlayer
	local spinWheel = Net.event("SpinWheel")
	local fieldCount = #GameConfig.luckyWheel.fields

	local gui = Instance.new("ScreenGui")
	gui.Name = "WheelMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	UiKit.autoScale(gui)

	local toggle: () -> () = function() end
	local openButton = SideBar.register({
		id = TILE_ID,
		order = 80,
		text = Lang.t("side.wheel"),
		color = TILE_COLOR,
		icon = { shape = "wheel" },
		open = function()
			toggle()
		end,
	})

	-- Menu panel
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = UiKit.CREAM
	panel.Visible = false
	UiKit.corner(panel, 24)
	UiKit.stroke(panel, 4)
	UiKit.placeMenu(gui, panel, PANEL_SIZE)

	local title = UiKit.label(panel, Lang.t("wheel.title"))
	title.Position = UDim2.fromOffset(24, 14)
	title.Size = UDim2.new(1, -120, 0, 52)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local closeButton = UiKit.button(panel, "X", UiKit.RED)
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -14, 0, 14)
	closeButton.Size = UDim2.fromOffset(72, 72)

	-- Live 3D view of the wheel (copy of the world wheel, filled once it exists).
	local view = Instance.new("ViewportFrame")
	view.Name = "Wheel"
	view.Position = UDim2.fromOffset(20, 96)
	view.Size = UDim2.fromOffset(VIEW_SIZE, VIEW_SIZE)
	view.BackgroundColor3 = Color3.fromRGB(255, 236, 200)
	view.Ambient = Color3.fromRGB(200, 200, 200)
	view.LightColor = Color3.fromRGB(255, 255, 255)
	view.LightDirection = Vector3.new(0, -0.4, 1)
	UiKit.corner(view, 20)
	UiKit.stroke(view, 3)
	view.Parent = panel
	local camera = Instance.new("Camera")
	camera.FieldOfView = CAMERA_FOV
	camera.Parent = view
	view.CurrentCamera = camera
	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = view

	-- Field labels over the view (ViewportFrames do not draw SurfaceGuis).
	local labels: { TextLabel } = {}
	for index = 1, fieldCount do
		local label = UiKit.label(view, fieldLabel(index))
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Size = UDim2.fromOffset(96, 34)
		label.TextColor3 = UiKit.CREAM
		label.ZIndex = 2
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = UiKit.DARK
		stroke.Parent = label
		labels[index] = label
	end

	-- Fields: colour, reward for this player, chance.
	local list = Instance.new("Frame")
	list.Name = "Fields"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(VIEW_SIZE + 40, 96)
	list.Size = UDim2.new(1, -(VIEW_SIZE + 60), 0, 270)
	list.Parent = panel
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 4)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list
	local rows: { { reward: TextLabel, chance: TextLabel } } = {}
	for index = 1, fieldCount do
		local row = Instance.new("Frame")
		row.Name = `Field{index}`
		row.LayoutOrder = index
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 29)
		row.Parent = list
		local swatch = Instance.new("Frame")
		swatch.BackgroundColor3 = fieldColor(index)
		swatch.Size = UDim2.fromOffset(22, 22)
		swatch.Position = UDim2.fromOffset(0, 3)
		UiKit.corner(swatch, 11)
		UiKit.stroke(swatch, 2)
		swatch.Parent = row
		local reward = UiKit.label(row, "")
		reward.Position = UDim2.fromOffset(30, 0)
		reward.Size = UDim2.new(1, -100, 1, 0)
		reward.TextXAlignment = Enum.TextXAlignment.Left
		local chance = UiKit.label(row, "")
		chance.AnchorPoint = Vector2.new(1, 0)
		chance.Position = UDim2.new(1, 0, 0, 0)
		chance.Size = UDim2.fromOffset(66, 29)
		chance.TextXAlignment = Enum.TextXAlignment.Right
		chance.TextColor3 = Color3.fromRGB(110, 80, 55)
		rows[index] = { reward = reward, chance = chance }
	end

	local hintColor = Color3.fromRGB(110, 80, 55)
	local status = UiKit.label(panel, "")
	status.Position = UDim2.fromOffset(VIEW_SIZE + 40, 372)
	status.Size = UDim2.new(1, -(VIEW_SIZE + 60), 0, 36)
	status.TextColor3 = hintColor

	local spinButton = UiKit.button(panel, "", UiKit.GREEN)
	spinButton.Name = "Spin"
	spinButton.Position = UDim2.fromOffset(VIEW_SIZE + 40, 414)
	spinButton.Size = UDim2.new(1, -(VIEW_SIZE + 60), 0, 66)
	local priceIcon = Instance.new("Frame")
	priceIcon.BackgroundTransparency = 1
	priceIcon.AnchorPoint = Vector2.new(1, 0.5)
	priceIcon.Position = UDim2.new(1, -4, 0.5, 0)
	priceIcon.Size = UDim2.fromOffset(34, 34)
	priceIcon.Parent = spinButton
	UiKit.gemIcon(priceIcon, 34)

	-- Big win text over the view at the end of a spin.
	local winLabel = UiKit.label(view, "")
	winLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	winLabel.Position = UDim2.fromScale(0.5, 0.5)
	winLabel.Size = UDim2.new(0.9, 0, 0, 70)
	winLabel.TextColor3 = UiKit.COIN
	winLabel.ZIndex = 4
	winLabel.Visible = false
	local winStroke = Instance.new("UIStroke")
	winStroke.Thickness = 3
	winStroke.Color = UiKit.DARK
	winStroke.Parent = winLabel

	-- Golden flash for the jackpot (only with screen flashes on).
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = UiKit.COIN
	flash.BackgroundTransparency = 1
	flash.ZIndex = 10
	flash.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")

	-- State ------------------------------------------------------------------
	local current = readStatus(player)
	local syncedAt = os.clock()
	local angle = 0 -- current disc angle (degrees, clockwise)
	local spinning = false
	local waiting = false

	-- The world wheel (built by the server on the spawn island) and its copy in the view.
	local worldDisc: Model? = nil
	local worldDiscPivot: CFrame? = nil
	local worldLights: { BasePart } = {}
	local viewDisc: Model? = nil
	local viewDiscPivot: CFrame? = nil
	local viewLights: { BasePart } = {}

	local function lightsOf(model: Instance): { BasePart }
		local out = {}
		local folder = model:FindFirstChild("Lights")
		if folder then
			for _, child in folder:GetChildren() do
				if child:IsA("BasePart") then
					table.insert(out, child)
				end
			end
		end
		return out
	end

	local function applyAngle()
		-- Disc pivot = hub part, whose X axis points to the viewer: turning by -angle about
		-- it turns the disc clockwise as seen from the front.
		local rotation = CFrame.Angles(-math.rad(angle), 0, 0)
		if worldDisc and worldDiscPivot then
			worldDisc:PivotTo(worldDiscPivot * rotation)
		end
		if viewDisc and viewDiscPivot then
			viewDisc:PivotTo(viewDiscPivot * rotation)
		end
		local half = VIEW_SIZE / 2
		local radius = LABEL_RADIUS / (CAMERA_DISTANCE * math.tan(math.rad(CAMERA_FOV / 2))) * half
		for index, label in labels do
			local a = math.rad(fieldAngle(index) + angle)
			label.Position = UDim2.fromOffset(half + radius * math.sin(a), half - radius * math.cos(a))
			label.Rotation = math.deg(a)
		end
	end

	local function attachWheel(model: Model)
		local disc = model:WaitForChild("Disc", 10)
		if not (disc and disc:IsA("Model")) then
			return
		end
		worldDisc = disc
		worldDiscPivot = disc:GetPivot()
		worldLights = lightsOf(model)
		-- Copy for the menu view.
		local copy = model:Clone()
		for _, item in copy:GetDescendants() do
			if item:IsA("ProximityPrompt") or item:IsA("ClickDetector") or item:IsA("SurfaceGui") then
				item:Destroy()
			end
		end
		copy.Parent = worldModel
		local copyDisc = copy:FindFirstChild("Disc") :: Model?
		viewDisc = copyDisc
		viewDiscPivot = if copyDisc then copyDisc:GetPivot() else nil
		viewLights = lightsOf(copy)
		local hub = worldDiscPivot :: CFrame
		-- Hub part's X axis points to the front (towards the viewer).
		camera.CFrame = CFrame.lookAt(hub.Position + hub.XVector * CAMERA_DISTANCE, hub.Position, Vector3.yAxis)
		applyAngle()
		-- Click on the 3D wheel opens the menu.
		for _, item in model:GetDescendants() do
			if item:IsA("ClickDetector") then
				item.MouseClick:Connect(function(who: Player)
					if who == player and not panel.Visible then
						toggle()
					end
				end)
			end
		end
	end
	task.spawn(function()
		local island = Workspace:WaitForChild("SpawnIsland", 60)
		local model = island and island:WaitForChild("LuckyWheel", 60)
		if model and model:IsA("Model") then
			attachWheel(model)
		end
	end)
	applyAngle()

	-- UI updates ---------------------------------------------------------------
	local function bonusLeft(): number
		return if current.bonusSeconds >= 0 then current.bonusSeconds - (os.clock() - syncedAt) else -1
	end

	-- A message (win, refusal) stays until this time (os.clock()) before the status returns.
	local messageUntil = 0
	local function updateStatusLine()
		if os.clock() < messageUntil then
			return
		end
		if current.free > 0 then
			status.Text = Lang.t("wheel.freeLeft", { left = current.free, total = current.freeTotal })
		elseif bonusLeft() > 0 then
			status.Text = Lang.t("wheel.bonusIn", { time = clockText(bonusLeft()) })
		else
			status.Text = Lang.t("wheel.noFreeLeft")
		end
	end

	local function updateButton()
		if spinning or waiting then
			spinButton.Text = Lang.t("wheel.spinning")
			spinButton.BackgroundColor3 = UiKit.GREY
			priceIcon.Visible = false
		elseif current.free > 0 then
			spinButton.Text = if current.free > 1
				then Lang.t("wheel.spinFreeCount", { count = current.free })
				else Lang.t("wheel.spinFree")
			spinButton.BackgroundColor3 = UiKit.GREEN
			priceIcon.Visible = false
		else
			spinButton.Text = Lang.t("wheel.spinPaid", { price = Lang.integer(current.price) })
			local gems = player:GetAttribute("Gems")
			local affordable = type(gems) == "number" and gems >= current.price
			spinButton.BackgroundColor3 = if affordable then UiKit.ORANGE else UiKit.GREY
			priceIcon.Visible = true
		end
	end

	local function updateRows()
		for index, row in rows do
			local field = current.fields[index]
			if field then
				row.reward.Text = if field.jackpot
					then `{Lang.t("wheel.jackpot")} {UiKit.rewardsText(field.rewards)}`
					else UiKit.rewardsText(field.rewards)
				row.chance.Text = percentText(field.chance)
			end
		end
	end

	local function sync()
		current = readStatus(player)
		syncedAt = os.clock()
		SideBar.setBadge(TILE_ID, current.free > 0)
		SideBar.setCaption(TILE_ID, if current.free > 0 then Lang.t("side.wheelFree") else nil)
		updateButton()
		updateStatusLine()
		if panel.Visible then
			updateRows()
		end
	end
	player:GetAttributeChangedSignal("Wheel"):Connect(sync)
	player:GetAttributeChangedSignal("Gems"):Connect(updateButton)
	sync()

	local statusId = 0
	local function showMessage(text: string, color: Color3)
		statusId += 1
		local myId = statusId
		messageUntil = os.clock() + 2.5
		status.Text = text
		status.TextColor3 = color
		task.delay(2.5, function()
			if statusId == myId then
				messageUntil = 0
				status.TextColor3 = hintColor
				updateStatusLine()
			end
		end)
	end

	-- Lights: slow alternating blink, fast running light while spinning.
	local lightStep = 0
	local lastLight = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local interval = if spinning then 0.08 else 0.5
		if now - lastLight >= interval then
			lastLight = now
			lightStep += 1
			for _, lights in { worldLights, viewLights } do
				for index, light in lights do
					local on = if spinning then (index + lightStep) % 4 == 0 else (index + lightStep) % 2 == 0
					light.Color = if on then UiKit.COIN else UiKit.CREAM
				end
			end
			if not spinning then
				updateStatusLine()
			end
		end
	end)

	local function close()
		panel.Visible = false
	end
	UiKit.registerMenu(MENU_ID, close)

	toggle = function()
		UiKit.pop(openButton)
		if panel.Visible then
			close()
			return
		end
		updateRows()
		updateButton()
		panel.Visible = true
		UiKit.menuOpened(MENU_ID)
		UiKit.pop(panel)
	end
	closeButton.Activated:Connect(close)

	spinButton.Activated:Connect(function()
		if spinning or waiting then
			return
		end
		UiKit.pop(spinButton)
		waiting = true
		winLabel.Visible = false
		updateButton()
		spinWheel:FireServer(current.free > 0)
		-- No answer (e.g. feature switched off on the server): free the button again.
		task.delay(5, function()
			if waiting then
				waiting = false
				updateButton()
			end
		end)
	end)

	local function celebrate(fieldIndex: number, rewards: { Reward })
		local field = GameConfig.luckyWheel.fields[fieldIndex]
		local text = Lang.t("wheel.won", { rewards = UiKit.rewardsText(rewards) })
		if field and field.jackpot then
			text = `{Lang.t("wheel.jackpot")}\n{UiKit.rewardsText(rewards)}`
			Sounds.play("Rebirth")
			if Settings.screenFlashes() then
				flash.BackgroundTransparency = 0.3
				TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
			end
		end
		Sounds.play("WheelWin")
		winLabel.Text = text
		winLabel.Visible = true
		UiKit.pop(winLabel, 0.5)
		showMessage(Lang.t("wheel.won", { rewards = UiKit.rewardsText(rewards) }), Color3.fromRGB(40, 150, 60))
		task.delay(3, function()
			if not spinning then
				winLabel.Visible = false
			end
		end)
	end

	local function spinTo(fieldIndex: number, rewards: { Reward })
		spinning = true
		updateButton()
		local segment = 360 / fieldCount
		local jitter = (math.random() - 0.5) * segment * 0.6
		local target = (-fieldAngle(fieldIndex) + jitter) % 360
		local start = angle
		local delta = TURNS * 360 + (target - start % 360) % 360
		local began = os.clock()
		local lastTick = math.floor((start + segment / 2) / segment)
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			local t = math.min(1, (os.clock() - began) / SPIN_SECONDS)
			angle = start + delta * (1 - (1 - t) ^ 3)
			applyAngle()
			local passed = math.floor((angle + segment / 2) / segment)
			if passed ~= lastTick then
				lastTick = passed
				Sounds.play("WheelTick")
			end
			if t >= 1 then
				connection:Disconnect()
				angle %= 360
				applyAngle()
				spinning = false
				updateButton()
				updateStatusLine()
				celebrate(fieldIndex, rewards)
			end
		end)
	end

	Net.event("WheelResult").OnClientEvent:Connect(function(ok: boolean, fieldOrReason: any, rewards: { Reward })
		waiting = false
		if ok and type(fieldOrReason) == "number" then
			if not panel.Visible then
				toggle()
			end
			spinTo(fieldOrReason, rewards)
		else
			updateButton()
			local key = `wheel.{fieldOrReason}`
			local text = Lang.t(key)
			showMessage(if text == key then Lang.t("common.notNow") else text, UiKit.RED)
		end
	end)

	-- Prompt on the 3D wheel: text in the player's language, opens the menu.
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == PROMPT_NAME then
			prompt.ActionText = Lang.t("sign.wheelPrompt")
			prompt.ObjectText = Lang.t("sign.wheel")
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		if prompt.Name == PROMPT_NAME and who == player and not panel.Visible then
			toggle()
		end
	end)
end

return WheelMenu
