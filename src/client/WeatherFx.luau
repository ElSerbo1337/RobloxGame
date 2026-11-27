--!strict
-- Weather and night effects on the client (#105), purely cosmetic and local:
-- * Weather (switch weather): particles above the player while the world they stand in
--   has weather (Workspace attribute `Weather_<worldId>` from WeatherService), the pill
--   in the active bonuses (BonusPills) with name, +20 % and the time left, and lightning
--   flashes for weathers with `lightning` – only with the setting "screen flashes" on
--   (#76); the thunder sound plays either way.
-- * Night (switch dayNight, WorldAmbience.isNight): lanterns tagged NightLight (#104)
--   switch on their PointLight and glow in Neon; fireflies fly around the player.
-- Graphics "Low" throttles all these emitters to 30 % via GraphicsQuality (#76).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local BonusPills = require(script.Parent.BonusPills)
local Lang = require(script.Parent.Lang)
local Settings = require(script.Parent.Settings)
local Sounds = require(script.Parent.Sounds)
local WorldAmbience = require(script.Parent.WorldAmbience)

local NIGHT_TAG = "NightLight" -- IslandBuilder.NIGHT_TAG (#104)
local CHECK_SECONDS = 0.5
local WEATHER_BLUE = Color3.fromRGB(90, 150, 230)
local ICONS = { rain = "🌧️", snow = "❄️", dust = "🌪️", bubbles = "🫧", sparkle = "✨" }

-- Emitter settings per weather style (rates before the "Low" factor).
local STYLES = {
	rain = { rate = 220, speed = { 70, 90 }, lifetime = 1.2, size = 0.25, stretch = true },
	snow = { rate = 90, speed = { 6, 10 }, lifetime = 6, size = 0.45 },
	dust = { rate = 70, speed = { 14, 22 }, lifetime = 4, size = 1.4, sideways = true },
	bubbles = { rate = 50, speed = { 4, 8 }, lifetime = 6, size = 0.7, rising = true },
	sparkle = { rate = 60, speed = { 1, 3 }, lifetime = 3, size = 0.35, glow = true },
}

local WeatherFx = {}

local function colorSequence(colors: { { number } }): ColorSequence
	if #colors == 1 then
		local c = colors[1]
		return ColorSequence.new(Color3.fromRGB(c[1], c[2], c[3]))
	end
	local points = {}
	for i, c in colors do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), Color3.fromRGB(c[1], c[2], c[3])))
	end
	return ColorSequence.new(points)
end

-- Invisible box that follows the player; its emitters spawn inside it.
local function followBox(name: string, size: Vector3): Part
	local box = Instance.new("Part")
	box.Name = name
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.CastShadow = false
	box.Transparency = 1
	box.Size = size
	box.Parent = Workspace
	return box
end

local function newEmitter(box: Part, style: string): ParticleEmitter
	local spec = (STYLES :: any)[style]
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = `Weather_{style}`
	emitter.Enabled = false
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.EmissionDirection = if spec.rising then Enum.NormalId.Top else Enum.NormalId.Bottom
	emitter.Rate = spec.rate
	emitter.Speed = NumberRange.new(spec.speed[1], spec.speed[2])
	emitter.Lifetime = NumberRange.new(spec.lifetime * 0.8, spec.lifetime)
	emitter.Size = NumberSequence.new(spec.size)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.2),
		NumberSequenceKeypoint.new(0.85, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.LightEmission = if spec.glow then 1 else 0.2
	if spec.stretch then
		emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
		emitter.Squash = NumberSequence.new(-2.5)
	end
	if spec.sideways then
		emitter.Acceleration = Vector3.new(18, -2, 6)
	end
	if spec.glow then
		emitter.RotSpeed = NumberRange.new(-90, 90)
	end
	emitter.Parent = box
	return emitter
end

local function startNightLights()
	local original: { [BasePart]: Enum.Material } = setmetatable({}, { __mode = "k" }) :: any
	local on = false
	local function apply(part: Instance)
		if not part:IsA("BasePart") then
			return
		end
		if original[part] == nil then
			original[part] = part.Material
		end
		part.Material = if on then Enum.Material.Neon else original[part]
		local light = part:FindFirstChild("NightLight")
		if light and light:IsA("Light") then
			light.Enabled = on
		end
	end
	CollectionService:GetInstanceAddedSignal(NIGHT_TAG):Connect(apply)
	return function(night: boolean)
		if night == on then
			return
		end
		on = night
		for _, part in CollectionService:GetTagged(NIGHT_TAG) do
			apply(part)
		end
	end
end

function WeatherFx.start()
	local features = Features.new(GameConfig.features)
	local weatherOn = features.enabled("weather")
	local nightOn = features.enabled("dayNight")
	if not weatherOn and not nightOn then
		return
	end
	local player = Players.LocalPlayer

	local skyBox = followBox("WeatherParticles", Vector3.new(70, 1, 70))
	local emitters: { [string]: ParticleEmitter } = {}
	local fireflyBox = followBox("NightFireflies", Vector3.new(44, 6, 44))
	local fireflies = Instance.new("ParticleEmitter")
	fireflies.Name = "Fireflies"
	fireflies.Enabled = false
	fireflies.Shape = Enum.ParticleEmitterShape.Box
	fireflies.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	fireflies.Rate = 8
	fireflies.Speed = NumberRange.new(0.3, 1)
	fireflies.SpreadAngle = Vector2.new(180, 180)
	fireflies.Lifetime = NumberRange.new(4, 7)
	fireflies.Size = NumberSequence.new(0.22)
	fireflies.LightEmission = 1
	fireflies.Color = ColorSequence.new(Color3.fromRGB(230, 255, 120))
	fireflies.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0),
		NumberSequenceKeypoint.new(0.6, 0.6),
		NumberSequenceKeypoint.new(0.8, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	fireflies.Parent = fireflyBox

	local flash = Instance.new("ColorCorrectionEffect")
	flash.Name = "WeatherFlash"
	flash.Enabled = false
	flash.Brightness = 0.6
	flash.Parent = Lighting

	local pill = BonusPills.pill("Weather", 2, WEATHER_BLUE)
	local setNight = startNightLights()
	local activeStyle: string? = nil
	local nextLightning = 0

	local function lightning(withFlash: boolean)
		Sounds.play("Thunder")
		if withFlash then
			task.spawn(function()
				flash.Enabled = true
				task.wait(0.08)
				flash.Enabled = false
				task.wait(0.12)
				flash.Enabled = true
				task.wait(0.06)
				flash.Enabled = false
			end)
		end
	end

	local function update()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local worldId = WorldAmbience.currentWorld()

		-- Night: lanterns and fireflies.
		local night = nightOn and WorldAmbience.isNight()
		setNight(night)
		fireflies.Enabled = night and root ~= nil
		if root then
			fireflyBox.CFrame = CFrame.new(root.Position + Vector3.new(0, 1, 0))
			skyBox.CFrame = CFrame.new(root.Position + Vector3.new(0, 28, 0))
		end

		-- Weather of the current world.
		local id = if weatherOn then Workspace:GetAttribute(`Weather_{worldId}`) else nil
		local kind = id and GameConfig.weathers[id]
		local style = if kind and root then kind.style or "rain" else nil
		if style ~= activeStyle then
			if activeStyle then
				emitters[activeStyle].Enabled = false
			end
			activeStyle = style
		end
		if kind and style then
			local emitter = emitters[style]
			if emitter == nil then
				emitter = newEmitter(skyBox, style)
				emitters[style] = emitter
			end
			emitter.Color = colorSequence(kind.particles)
			emitter.Enabled = true
			local endsAt = Workspace:GetAttribute(`WeatherEnds_{worldId}`) or 0
			local left = math.max(0, math.ceil(endsAt - Workspace:GetServerTimeNow()))
			pill.Text = Lang.t("hud.weatherBonus", {
				icon = (ICONS :: any)[style] or "🌦️",
				weather = Lang.name(kind),
				percent = Lang.percent(GameConfig.weather.spawnBonus),
				time = string.format("%d:%02d", left // 60, left % 60),
			})
			pill.Visible = true
			if kind.lightning and os.clock() >= nextLightning then
				if nextLightning > 0 then
					lightning(Settings.screenFlashes())
				end
				nextLightning = os.clock() + 6 + math.random() * 8
			end
		else
			pill.Visible = false
			nextLightning = 0
		end
	end

	Lang.onLanguageChanged(function()
		update()
	end)
	while true do
		update()
		task.wait(CHECK_SECONDS)
	end
end

return WeatherFx
