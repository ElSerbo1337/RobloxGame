--!strict
-- Juice (#110), purely visual and local, behind features.juice:
-- * big coloured sale number (white -> yellow -> orange -> pink, SaleNumbers) when a
--   pizza is sold; the flying coins into the counter are SellAnimation (#49),
-- * Juice.shakeCamera: short camera shake (Mythic/Secret hatch, EggAnimation), only with
--   Settings.cameraShake(),
-- * a swirl of sparkles in front of every portal in the colour of its target world
--   (fewer particles on "Low" graphics via GraphicsQuality),
-- * Juice.teleportSwirl: a white spinning pizza covering the screen while teleporting
--   (only a small, see-through pizza with Settings.screenFlashes() off),
-- * the delivery van drives off when an order is delivered and comes back.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local SaleNumbers = require(ReplicatedStorage.Shared.SaleNumbers)
local Lang = require(script.Parent.Lang)
local Settings = require(script.Parent.Settings)
local UiKit = require(script.Parent.UiKit)

local enabled = Features.new(GameConfig.features).enabled("juice")
local player = Players.LocalPlayer

-- Matches SellAnimation's pizza flight, so the number appears with the coins.
local SALE_NUMBER_DELAY = 0.45
local SALE_NUMBER_SECONDS = 1.2
local SALE_TEXT_SIZE = 46
local VAN_DISTANCE = 60
local VAN_DRIVE_SECONDS = 1.6
local VAN_AWAY_SECONDS = 1.5
local SWIRL_SECONDS = 0.9

local Juice = {}

local layer: ScreenGui? = nil
local saleAverage: number? = nil

local function getLayer(): ScreenGui
	if layer == nil then
		local gui = Instance.new("ScreenGui")
		gui.Name = "JuiceEffects"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 20
		gui.Parent = player:WaitForChild("PlayerGui")
		layer = gui
	end
	return layer :: ScreenGui
end

local function tween(target: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?): Tween
	local t = TweenService:Create(target, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad), goal)
	t:Play()
	return t
end

local function showSaleNumber(amount: number)
	local stage = SaleNumbers.stage(amount, saleAverage)
	saleAverage = SaleNumbers.nextAverage(saleAverage, amount)
	local rgb = SaleNumbers.COLORS[stage]
	local size = math.floor(SALE_TEXT_SIZE * SaleNumbers.SCALES[stage])

	local label = UiKit.label(getLayer(), Lang.t("juice.saleNumber", { amount = Lang.shortNumber(amount) }))
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.new(0.5 + (math.random() - 0.5) * 0.1, 0, 0.42, 0)
	label.Size = UDim2.fromOffset(500, size)
	label.TextSize = size
	label.TextScaled = false
	label.TextColor3 = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	label.TextStrokeColor3 = UiKit.DARK
	label.TextStrokeTransparency = 0
	label.Rotation = math.random(-6, 6)
	UiKit.pop(label, 0.4)
	tween(label, SALE_NUMBER_SECONDS, { Position = label.Position - UDim2.fromScale(0, 0.12) }, Enum.EasingStyle.Sine)
	task.delay(SALE_NUMBER_SECONDS * 0.6, function()
		tween(label, SALE_NUMBER_SECONDS * 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	task.delay(SALE_NUMBER_SECONDS, function()
		label:Destroy()
	end)
end

-- Shakes the camera for `seconds` (strength in studs), only with Settings.cameraShake().
function Juice.shakeCamera(seconds: number, strength: number)
	if not enabled or not Settings.cameraShake() then
		return
	end
	local started = os.clock()
	local name = `JuiceShake{started}`
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
		local t = (os.clock() - started) / seconds
		local camera = Workspace.CurrentCamera
		if t >= 1 or camera == nil then
			RunService:UnbindFromRenderStep(name)
			return
		end
		local power = strength * (1 - t)
		local offset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * power
		camera.CFrame = camera.CFrame * CFrame.new(offset)
	end)
end

-- White spinning pizza over the screen while the teleport happens.
function Juice.teleportSwirl()
	if not enabled then
		return
	end
	local full = Settings.screenFlashes()
	local pizza = Instance.new("Frame")
	pizza.Name = "TeleportSwirl"
	pizza.AnchorPoint = Vector2.new(0.5, 0.5)
	pizza.Position = UDim2.fromScale(0.5, 0.5)
	pizza.Size = UDim2.fromScale(0, 0)
	pizza.SizeConstraint = Enum.SizeConstraint.RelativeXX
	pizza.BackgroundColor3 = Color3.new(1, 1, 1)
	pizza.BackgroundTransparency = if full then 0 else 0.5
	pizza.BorderSizePixel = 0
	UiKit.corner(pizza, 9999)
	-- Slice lines, so the spin is visible.
	for index = 0, 3 do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale(0.5, 0.5)
		line.Size = UDim2.new(1, 0, 0.015, 0)
		line.Rotation = index * 45
		line.BackgroundColor3 = Color3.fromRGB(240, 225, 200)
		line.BackgroundTransparency = pizza.BackgroundTransparency
		line.BorderSizePixel = 0
		line.Parent = pizza
	end
	pizza.Parent = getLayer()
	local grown = if full then 2.2 else 0.35
	local half = SWIRL_SECONDS / 2
	tween(pizza, half, { Size = UDim2.fromScale(grown, grown), Rotation = 360 }, Enum.EasingStyle.Quad)
	task.delay(half, function()
		tween(pizza, half, { Size = UDim2.fromScale(0, 0), Rotation = 720 }, Enum.EasingStyle.Quad)
		task.wait(half)
		pizza:Destroy()
	end)
end

-- Sparkles swirling in front of a portal's glowing face, in the face's colour.
local function addPortalSwirl(glow: BasePart)
	if glow:FindFirstChild("JuiceSwirl") then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "JuiceSwirl"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(glow.Color, glow.Color:Lerp(Color3.new(1, 1, 1), 0.6))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.Lifetime = NumberRange.new(1, 1.6)
	emitter.Rate = 18
	emitter.Speed = NumberRange.new(1, 2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	-- Drag keeps the sparkles close to the face: a swirl instead of a spray.
	emitter.Drag = 1.5
	emitter.Shape = Enum.ParticleEmitterShape.Disc
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.Parent = glow
end

local function decoratePortals(folder: Instance)
	local function check(item: Instance)
		if item:IsA("BasePart") and string.match(item.Name, "^PortalGlow") then
			addPortalSwirl(item)
		end
	end
	for _, item in folder:GetDescendants() do
		check(item)
	end
	folder.DescendantAdded:Connect(check)
end

local driving: { [Model]: boolean } = {}

local function nearestVan(position: Vector3): Model?
	local best: Model? = nil
	local bestDistance = math.huge
	for _, item in Workspace:GetDescendants() do
		if item:IsA("Model") and item.Name == "DeliveryVan" then
			local distance = (item:GetPivot().Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = item, distance
			end
		end
	end
	return best
end

-- The van drives off forwards, then comes back from behind to its spot (local only).
local function driveVan(van: Model)
	if driving[van] then
		return
	end
	driving[van] = true
	local home = van:GetPivot()
	local forward = home.LookVector
	local function drive(from: CFrame, to: CFrame, style: Enum.EasingDirection)
		local started = os.clock()
		while true do
			local t = math.min((os.clock() - started) / VAN_DRIVE_SECONDS, 1)
			local eased = TweenService:GetValue(t, Enum.EasingStyle.Quad, style)
			van:PivotTo(from:Lerp(to, eased))
			if t >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
	end
	task.spawn(function()
		drive(home, home + forward * VAN_DISTANCE, Enum.EasingDirection.In)
		task.wait(VAN_AWAY_SECONDS)
		drive(home - forward * VAN_DISTANCE, home, Enum.EasingDirection.Out)
		van:PivotTo(home)
		driving[van] = nil
	end)
end

function Juice.start()
	if not enabled then
		return
	end
	Net.event("Notify").OnClientEvent:Connect(function(kind: string, amount: number?)
		if kind == "Sold" and type(amount) == "number" and amount > 0 then
			task.delay(SALE_NUMBER_DELAY, showSaleNumber, amount)
		elseif kind == "Delivered" then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local van = root and nearestVan(root.Position)
			if van then
				driveVan(van)
			end
		end
	end)
	task.spawn(function()
		local portals = Workspace:WaitForChild("Portals", 60)
		if portals then
			decoratePortals(portals)
		end
	end)
end

return Juice
