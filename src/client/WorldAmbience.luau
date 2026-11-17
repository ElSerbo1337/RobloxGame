--!strict
-- Applies the look (lighting, atmosphere, post-processing, clouds) and music of the
-- world the local player is standing in. Data: ReplicatedStorage.Shared.WorldLooks.
-- Purely cosmetic and local: every client sees the look of its own world.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local IslandPlan = require(ReplicatedStorage.Shared.IslandPlan)
local WorldLooks = require(ReplicatedStorage.Shared.WorldLooks)
local Sounds = require(script.Parent.Sounds)

-- Island chain from IslandPlan (#27): the spawn island, then the worlds along -Z.
-- Used only to pick the look, never for game rules.
local plan = IslandPlan.new(GameConfig.islands, GameConfig.worlds)
local CHECK_SECONDS = 1
local DEFAULT_WORLD = "PizzeriaGarden"

local WorldAmbience = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- Finds or creates the effect object the look controls (so Studio-made ones are reused).
local function effect<T>(parent: Instance, className: string, name: string): T
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing :: any
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = parent
	return created :: any
end

local function apply(look: WorldLooks.Look)
	Lighting.ClockTime = look.clockTime
	Lighting.Brightness = look.brightness
	Lighting.Ambient = rgb(look.ambient)
	Lighting.OutdoorAmbient = rgb(look.outdoorAmbient)
	Lighting.ColorShift_Top = rgb(look.colorShiftTop)
	Lighting.GlobalShadows = true

	local atmosphere = effect(Lighting, "Atmosphere", "WorldAtmosphere") :: Atmosphere
	atmosphere.Density = look.atmosphere.density
	atmosphere.Offset = look.atmosphere.offset
	atmosphere.Color = rgb(look.atmosphere.color)
	atmosphere.Decay = rgb(look.atmosphere.decay)
	atmosphere.Glare = look.atmosphere.glare
	atmosphere.Haze = look.atmosphere.haze

	local bloom = effect(Lighting, "BloomEffect", "WorldBloom") :: BloomEffect
	bloom.Intensity = look.bloom.intensity
	bloom.Size = look.bloom.size
	bloom.Threshold = look.bloom.threshold

	local color = effect(Lighting, "ColorCorrectionEffect", "WorldColor") :: ColorCorrectionEffect
	color.Brightness = look.colorCorrection.brightness
	color.Contrast = look.colorCorrection.contrast
	color.Saturation = look.colorCorrection.saturation
	color.TintColor = rgb(look.colorCorrection.tint)

	local sunRays = effect(Lighting, "SunRaysEffect", "WorldSunRays") :: SunRaysEffect
	sunRays.Intensity = look.sunRays.intensity
	sunRays.Spread = look.sunRays.spread

	local clouds = effect(Workspace.Terrain, "Clouds", "WorldClouds") :: Clouds
	clouds.Cover = look.clouds.cover
	clouds.Density = look.clouds.density
	clouds.Color = rgb(look.clouds.color)

	Sounds.playMusic(look.music)
end

-- World look for a position: its island's world; the spawn island looks like world 1;
-- on a bridge the look of the world being left stays (nil).
local function worldAt(position: Vector3): string?
	local index = plan.worldIndexAt(position.X, position.Z)
	if index then
		return GameConfig.worlds[index].id
	end
	if position.Z > plan.worldCenter(1)[3] + GameConfig.islands.worldHalfSize then
		return DEFAULT_WORLD
	end
	return nil
end

function WorldAmbience.start()
	local player = Players.LocalPlayer
	local current: string? = nil

	local function update()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local worldId = (if root then worldAt(root.Position) else nil) or current or DEFAULT_WORLD
		if worldId ~= current then
			current = worldId
			apply(WorldLooks[worldId] or WorldLooks[DEFAULT_WORLD])
		end
	end

	update()
	while true do
		task.wait(CHECK_SECONDS)
		update()
	end
end

return WorldAmbience
