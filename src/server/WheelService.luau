--!strict
-- Lucky wheel (#98, feature "luckyWheel"):
-- * 3D wheel on the reserved spot of the spawn island (#106: Anchors.WheelAnchor, front =
--   -Z towards the middle): stand, gold rim with 16 lights, 8 coloured fields (two
--   WedgeParts each, colours from GameConfig.luckyWheel.fields) with labels, a pointer on
--   top, a sign "🎡 Glücksrad", a ProximityPrompt "WheelPrompt" and a ClickDetector that open
--   the menu on the client. The disc (model "Disc") is turned only on the client that spins.
-- * Spins: the client wishes SpinWheel(expectFree); the rules decide (free spin of the
--   day / play time bonus, else gems) and draw the field here on the server. The answer
--   goes back as WheelResult(ok, fieldOrReason, rewards, free); the rewards are paid right
--   away, the client shows them when its wheel stops.
-- * Replication: attribute Wheel (JSON, see Net).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerStates = require(script.Parent.PlayerStates)
local SignText = require(script.Parent.SignText)
local Texts = require(ReplicatedStorage.Shared.Texts)

type PlayerState = GameRules.PlayerState

-- Seconds between two spins of one player (the client animation takes about 4.5 s).
local SPIN_COOLDOWN = 4
-- Wheel size (studs): disc radius and height of the hub above the ground.
local RADIUS = 5
local HUB_HEIGHT = 7.5
local LIGHT_COUNT = 16

local DARK = Color3.fromRGB(60, 35, 20)
local CREAM = Color3.fromRGB(255, 248, 230)
local GOLD = Color3.fromRGB(255, 200, 40)
local WOOD = Color3.fromRGB(150, 95, 55)

local WheelService = {}

local function part(props: { [string]: any }, class: string?): BasePart
	local p = Instance.new(class or "Part") :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- Label text of a field on the wheel (SignText, per player language).
local function fieldLabel(label: TextLabel, field: any)
	if field.jackpot then
		SignText.set(label, "sign.wheelJackpot")
		return
	end
	local reward = field.rewards[1]
	if reward.kind == "Coins" then
		SignText.set(label, "sign.wheelCoins", { minutes = { integer = reward.minutes } })
	elseif reward.kind == "Gems" then
		SignText.set(label, "sign.wheelGems", { amount = { integer = reward.amount } })
	else
		SignText.set(label, "sign.wheelPotions", { amount = { integer = reward.amount } })
	end
end

-- Builds the wheel on the anchor (ground point, front = -Z). Hub-local axes: X = anchor X,
-- Y = up, Z = away from the viewer; a field at angle a (clockwise from the top, as the
-- viewer sees it) points along (-sin a, cos a, 0).
function WheelService.build(anchor: BasePart): Model
	local model = Instance.new("Model")
	model.Name = "LuckyWheel"
	local base = anchor.CFrame
	local hub = base * CFrame.new(0, HUB_HEIGHT, 0)

	-- Stand: round platform, two legs, sign board on top.
	part({
		Name = "Platform",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 9, 9),
		CFrame = base * CFrame.new(0, 0.4, 0.8) * CFrame.Angles(0, 0, math.pi / 2),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
	}).Parent =
		model
	for _, side in { -1, 1 } do
		part({
			Name = "Leg",
			Size = Vector3.new(0.8, HUB_HEIGHT, 0.8),
			CFrame = base * CFrame.new(side * 2.2, HUB_HEIGHT / 2 + 0.4, 0.6) * CFrame.Angles(0, 0, side * 0.25),
			Color = WOOD,
			Material = Enum.Material.Wood,
		}).Parent =
			model
	end
	local rim = part({
		Name = "Rim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, RADIUS * 2 + 1.4, RADIUS * 2 + 1.4),
		CFrame = hub * CFrame.new(0, 0, -0.1) * CFrame.Angles(0, math.pi / 2, 0),
		Color = GOLD,
		Material = Enum.Material.SmoothPlastic,
	})
	rim.Parent = model
	local click = Instance.new("ClickDetector")
	click.Name = "WheelClick"
	click.MaxActivationDistance = 40
	click.Parent = rim

	-- Lights around the rim (the client lets them blink).
	local lights = Instance.new("Folder")
	lights.Name = "Lights"
	for index = 1, LIGHT_COUNT do
		local angle = (index - 1) / LIGHT_COUNT * math.pi * 2
		local offset = Vector3.new(-math.sin(angle), math.cos(angle), 0) * (RADIUS + 0.4)
		part({
			Name = `Light{index}`,
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.55,
			CFrame = hub * CFrame.new(offset.X, offset.Y, -0.5),
			Color = if index % 2 == 0 then GOLD else CREAM,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
		}).Parent =
			lights
	end
	lights.Parent = model

	-- Disc: two right-angled WedgeParts per field (apex in the middle), labels, hub.
	local disc = Instance.new("Model")
	disc.Name = "Disc"
	local fields = GameConfig.luckyWheel.fields
	local count = #fields
	local half = math.pi / count
	local h, b = RADIUS * math.cos(half), RADIUS * math.sin(half)
	for index, field in fields do
		local angle = (index - 1) * 2 * half
		local u = Vector3.new(-math.sin(angle), math.cos(angle), 0)
		local v = Vector3.new(math.cos(angle), math.sin(angle), 0)
		for _, sideSign in { 1, -1 } do
			-- Right angle at h*u, legs towards the middle (wedge +Y) and to the rim corner (wedge -Z).
			local corner = h * u + sideSign * b * v
			local yAxis = -u
			local zAxis = -sideSign * v
			local xAxis = yAxis:Cross(zAxis)
			local center = corner / 2 + Vector3.new(0, 0, -0.55)
			local wedge = part({
				Name = `Field{index}`,
				Size = Vector3.new(0.3, h, b),
				Color = color(field.color),
				Material = Enum.Material.SmoothPlastic,
				CastShadow = false,
			}, "WedgePart")
			wedge.CFrame = hub * CFrame.fromMatrix(center, xAxis, yAxis, zAxis)
			wedge:SetAttribute("FieldIndex", index)
			wedge.Parent = disc
		end
		-- Label: text runs across the field, its top points outwards.
		local labelPart = part({
			Name = `Label{index}`,
			Size = Vector3.new(2.6, 1.3, 0.05),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		})
		local at = u * RADIUS * 0.62 + Vector3.new(0, 0, -0.75)
		labelPart.CFrame = hub * CFrame.fromMatrix(at, u:Cross(Vector3.zAxis), u, Vector3.zAxis)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.LightInfluence = 0.2
		gui.MaxDistance = 120
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = CREAM
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = DARK
		stroke.Parent = label
		fieldLabel(label, field)
		label.Parent = gui
		gui.Parent = labelPart
		labelPart.Parent = disc
	end
	local hubPart = part({
		Name = "Hub",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 1.6, 1.6),
		CFrame = hub * CFrame.new(0, 0, -0.75) * CFrame.Angles(0, math.pi / 2, 0),
		Color = GOLD,
		Material = Enum.Material.SmoothPlastic,
	})
	hubPart.Parent = disc
	disc.PrimaryPart = hubPart
	disc.Parent = model

	-- Pointer on top (diamond) that marks the winning field.
	part({
		Name = "Pointer",
		Size = Vector3.new(1.1, 1.1, 0.5),
		CFrame = hub * CFrame.new(0, RADIUS + 0.5, -0.85) * CFrame.Angles(0, 0, math.pi / 4),
		Color = Color3.fromRGB(230, 70, 50),
		Material = Enum.Material.SmoothPlastic,
	}).Parent =
		model

	-- Sign above the wheel.
	local sign = part({
		Name = "Sign",
		Size = Vector3.new(7, 1.6, 0.4),
		CFrame = hub * CFrame.new(0, RADIUS + 2.1, 0),
		Color = Color3.fromRGB(230, 70, 50),
		Material = Enum.Material.SmoothPlastic,
	})
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 40
	signGui.LightInfluence = 0.2
	signGui.MaxDistance = 150
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.Font = Enum.Font.FredokaOne
	signLabel.TextScaled = true
	signLabel.TextColor3 = CREAM
	local signStroke = Instance.new("UIStroke")
	signStroke.Thickness = 2
	signStroke.Color = DARK
	signStroke.Parent = signLabel
	SignText.set(signLabel, "sign.wheel")
	signLabel.Parent = signGui
	signGui.Parent = sign
	sign.Parent = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WheelPrompt"
	-- German default; the client shows it in the player's language.
	prompt.ActionText = Texts.format("de", "sign.wheelPrompt")
	prompt.ObjectText = Texts.format("de", "sign.wheel")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = hubPart

	model.PrimaryPart = rim
	return model
end

local function replicate(player: Player, state: PlayerState)
	local status = PlayerStates.rules.wheelStatus(state, os.time())
	player:SetAttribute(
		"Wheel",
		HttpService:JSONEncode({
			free = status.freeSpins,
			freeTotal = status.freeTotal,
			bonusSeconds = status.bonusSecondsLeft or -1,
			price = status.price,
			fields = status.fields,
		})
	)
end

function WheelService.start(spawnIsland: Instance)
	local features = Features.new(GameConfig.features)
	if not features.enabled("luckyWheel") then
		return
	end
	local anchors = spawnIsland:FindFirstChild("Anchors")
	local anchor = anchors and anchors:FindFirstChild("WheelAnchor")
	if anchor and anchor:IsA("BasePart") then
		WheelService.build(anchor).Parent = spawnIsland
	else
		warn("[Wheel] Anker WheelAnchor fehlt auf der Spawn-Insel")
	end

	local rules = PlayerStates.rules
	local wheelResult = Net.event("WheelResult")
	local random = Random.new()
	local function draw(): number
		return random:NextNumber()
	end
	local lastSpin: { [Player]: number } = {}

	PlayerStates.onChanged(replicate)
	local function onPlayerAdded(player: Player)
		local state = PlayerStates.get(player)
		if state then
			replicate(player, state)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastSpin[player] = nil
	end)

	Net.event("SpinWheel").OnServerEvent:Connect(features.guard("luckyWheel", function(player: Player, expectFree: any)
		local state = PlayerStates.get(player)
		if state == nil then
			return
		end
		local now = os.clock()
		if lastSpin[player] and now - lastSpin[player] < SPIN_COOLDOWN then
			wheelResult:FireClient(player, false, "Busy", {}, false)
			return
		end
		local result = rules.spinWheel(state, os.time(), draw, expectFree == true)
		if result.ok then
			lastSpin[player] = now
			PlayerStates.set(player, result.state)
			wheelResult:FireClient(player, true, result.field, result.rewards, result.free)
		else
			wheelResult:FireClient(player, false, result.reason, {}, false)
		end
	end))
end

return WheelService
