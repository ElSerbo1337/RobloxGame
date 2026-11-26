--!strict
-- Moves every player's equipped pets (Workspace.Pets.<UserId>) behind their owner.
-- Runs on every client for all players, so movement is smooth and everyone sees
-- everyone's pets. The pet models are anchored; the server never moves them.
-- Rainbow pets (#80) get their glow colour cycled here.
-- Auras and animations (#92, switch features.petAuras): Legendary/Mythic/Secret pets get
-- an aura (light + particles in the rarity colour, PetAura), Gold pets shine (pulsing
-- glow), own pets spin once when the player sells. Graphics "Low" (#76) turns aura
-- lights off and keeps few particles (weakest aura none, GraphicsQuality scales the rest).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local PetAura = require(ReplicatedStorage.Shared.PetAura)
local Settings = require(script.Parent.Settings)

-- Distance behind the owner and spacing between pets (studs).
local BEHIND = 5
local SPACING = 3.2
-- Height above the ground the pets hover at, and how much they hop while walking.
local HOVER = 1.4
local HOP = 0.6
-- How quickly pets catch up (higher = snappier).
local FOLLOW_SPEED = 8
-- Highest step (studs above the owner's feet) a pet may stand on: anything higher
-- (oven roof, shop counter, egg stand) is not walkable ground for pets.
local MAX_STEP = 1.5
-- Distance pets keep from walls between the owner and their spot.
local WALL_GAP = 1.5
-- Height above the owner's feet of the ray that checks for walls.
local WALL_RAY_HEIGHT = 1.2
-- Where pets of owners without a loaded character wait, out of sight below the islands.
local HIDDEN_Y = -500

-- Seconds of the spin on a sale, and how often pets turn in that time.
local SELL_SPIN_SECONDS = 0.7
local SELL_SPIN_TURNS = 1
-- Gold shine: glow brightness pulses between these values.
local GOLD_SHINE_MIN, GOLD_SHINE_MAX = 1, 2.6

local PetFollow = {}

type Look = { level: number, light: PointLight?, emitter: ParticleEmitter? }

local function rarityColor(petId: any): Color3?
	local pet = type(petId) == "string" and GameConfig.pets[petId]
	local rarity = pet and GameConfig.rarities[pet.rarity]
	if rarity == nil then
		return nil
	end
	return Color3.fromRGB(rarity.color[1], rarity.color[2], rarity.color[3])
end

-- Adds the aura of a pet once (rarity from its PetId attribute). Returns its parts.
local function addAura(pet: Model): Look
	local petId = pet:GetAttribute("PetId")
	local info = type(petId) == "string" and GameConfig.pets[petId]
	local level = PetAura.level(info and info.rarity, GameConfig.rarities)
	local body = pet.PrimaryPart or pet:FindFirstChildWhichIsA("BasePart", true)
	local color = rarityColor(petId)
	if level == 0 or body == nil or color == nil then
		return { level = 0 }
	end
	local light = Instance.new("PointLight")
	light.Name = "AuraGlow"
	light.Color = color
	light.Range = 5 + level * 2
	light.Brightness = 0.8 + level * 0.4
	light.Parent = body

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "AuraParticles"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3 + level * 0.15),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(0.6, 1.4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, 1.5, 0)
	-- Full rate; on "Low" GraphicsQuality scales every emitter down itself.
	emitter.Rate = PetAura.particleRate(level, false)
	emitter.Parent = body
	return { level = level, light = light, emitter = emitter }
end

local function applyQuality(look: Look, low: boolean)
	if look.light then
		look.light.Enabled = not low
	end
	if look.emitter then
		look.emitter.Enabled = PetAura.particleRate(look.level, low) > 0
	end
end

-- Offset of pet `slot` of `count` relative to the owner: a row behind, centered.
local function formationOffset(slot: number, count: number): Vector3
	local x = (slot - (count + 1) / 2) * SPACING
	local z = BEHIND + math.abs(x) * 0.35
	return Vector3.new(x, 0, z)
end

-- Puts a formation spot on walkable ground near the owner: never inside or behind a
-- wall (station) and never on top of something higher than a small step. Returns the
-- ground point (hover and hop are added by the caller).
local function groundTarget(spot: Vector3, root: BasePart, rayParams: RaycastParams): Vector3
	local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
	local hipHeight = if humanoid then humanoid.HipHeight else 2
	local feetY = root.Position.Y - root.Size.Y / 2 - hipHeight

	-- Walls: walk the line from the owner to the spot and stop in front of an obstacle.
	local from = Vector3.new(root.Position.X, feetY + WALL_RAY_HEIGHT, root.Position.Z)
	local to = Vector3.new(spot.X, feetY + WALL_RAY_HEIGHT, spot.Z)
	local offset = to - from
	local x, z = spot.X, spot.Z
	if offset.Magnitude > 0.01 then
		local wall = Workspace:Raycast(from, offset, rayParams)
		if wall then
			local direction = offset.Unit
			local reach = math.max((wall.Position - from).Magnitude - WALL_GAP, 0)
			local stop = from + direction * reach
			x, z = stop.X, stop.Z
		end
	end

	-- Ground: cast down from just above step height, so roofs are never hit.
	local origin = Vector3.new(x, feetY + MAX_STEP + 0.5, z)
	local hit = Workspace:Raycast(origin, Vector3.new(0, -12, 0), rayParams)
	local groundY = if hit and hit.Normal.Y > 0.6 then hit.Position.Y else feetY
	return Vector3.new(x, math.min(groundY, feetY + MAX_STEP), z)
end

function PetFollow.start()
	local petsFolder = Workspace:WaitForChild("Pets")
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	-- Only solid parts count as walls or ground (not toppings, zones or decals).
	rayParams.RespectCanCollide = true

	local auras = Features.new(GameConfig.features).enabled("petAuras")
	local looks: { [Model]: Look } = setmetatable({}, { __mode = "k" }) :: any
	local low = Settings.lowGraphics()
	local spinStart = -math.huge
	if auras then
		Settings.observe("graphics", function()
			low = Settings.lowGraphics()
			for _, look in looks do
				applyQuality(look, low)
			end
		end)
		Net.event("Notify").OnClientEvent:Connect(function(kind: string)
			if kind == "Sold" then
				spinStart = os.clock()
			end
		end)
	end
	local localUserId = tostring(Players.LocalPlayer.UserId)

	RunService.RenderStepped:Connect(function(dt: number)
		local alpha = 1 - math.exp(-FOLLOW_SPEED * dt)
		local t = os.clock()
		-- Pets and characters are neither walls nor ground.
		local ignore: { Instance } = { petsFolder }
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(ignore, player.Character)
			end
		end
		rayParams.FilterDescendantsInstances = ignore
		for _, ownerFolder in petsFolder:GetChildren() do
			local owner = Players:GetPlayerByUserId(tonumber(ownerFolder.Name) or 0)
			local character = owner and owner.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root == nil then
				-- Owner not loaded on this client (streamed out on phones, respawning):
				-- park the pets out of sight instead of leaving them at their server spot.
				for _, pet in ownerFolder:GetChildren() do
					if pet:IsA("Model") and pet:GetPivot().Position.Y > HIDDEN_Y + 1 then
						pet:PivotTo(CFrame.new(0, HIDDEN_Y, 0))
					end
				end
				continue
			end
			local pets = ownerFolder:GetChildren()
			local moving = root.AssemblyLinearVelocity.Magnitude > 1
			local flat = CFrame.new(root.Position) * CFrame.Angles(0, select(2, root.CFrame:ToEulerAnglesYXZ()), 0)
			-- Sale (#92): own pets turn once around (ease out), one after the other.
			local spinAge = if ownerFolder.Name == localUserId then t - spinStart else math.huge
			for index, pet in pets do
				if not pet:IsA("Model") then
					continue
				end
				local slot = (pet:GetAttribute("Slot") :: number?) or index
				local target = groundTarget(flat:PointToWorldSpace(formationOffset(slot, #pets)), root, rayParams)
				local hop = if moving then math.abs(math.sin(t * 10 + slot)) * HOP else math.sin(t * 2 + slot) * 0.15
				target += Vector3.new(0, HOVER + hop, 0)

				local current = pet:GetPivot()
				-- Coming back from the hiding spot: appear at once instead of flying up.
				local position = if current.Position.Y < HIDDEN_Y + 10
					then target
					else current.Position:Lerp(target, alpha)
				-- Face the walking direction of the owner.
				local look = flat.LookVector
				local facing = CFrame.lookAt(position, position + look)
				local progress = (spinAge - slot * 0.06) / SELL_SPIN_SECONDS
				if progress > 0 and progress < 1 then
					local eased = 1 - (1 - progress) ^ 3
					facing *= CFrame.Angles(0, eased * SELL_SPIN_TURNS * 2 * math.pi, 0)
				end
				pet:PivotTo(facing)
				local variant = pet:GetAttribute("Variant")
				if auras and looks[pet] == nil then
					looks[pet] = addAura(pet)
					applyQuality(looks[pet], low)
				end
				-- Rainbow pets (#80): their glow cycles through the colours; with auras
				-- (#92) the aura and the particles cycle too. Gold pets shine (pulse).
				if variant == "Rainbow" or (auras and variant == "Gold") then
					local glow = pet:FindFirstChild("VariantGlow", true)
					if variant == "Rainbow" then
						local color = Color3.fromHSV((t * 0.25 + slot * 0.13) % 1, 0.7, 1)
						if glow and glow:IsA("PointLight") then
							glow.Color = color
						end
						local aura = looks[pet]
						if aura and aura.light then
							aura.light.Color = color
						end
					elseif glow and glow:IsA("PointLight") then
						local pulse = (math.sin(t * 3 + slot) + 1) / 2
						glow.Brightness = GOLD_SHINE_MIN + (GOLD_SHINE_MAX - GOLD_SHINE_MIN) * pulse
						glow.Enabled = not low
					end
				end
			end
		end
	end)
end

return PetFollow
