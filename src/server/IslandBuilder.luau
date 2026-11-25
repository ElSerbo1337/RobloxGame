--!strict
-- Turns the island plan (ReplicatedStorage.Shared.IslandPlan, pure data) into parts and
-- models (#27). Knows nothing about the layout itself: every position, size and colour
-- comes from the plan, so the Blender previews (tools/blender/render_islands.py) show
-- exactly what is built here.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local IslandPlan = require(ReplicatedStorage.Shared.IslandPlan)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local WorldDeco = require(script.Parent.WorldDeco)

local IslandBuilder = {}

local features = Features.new(GameConfig.features)

-- Optional decoration (PartSpec.detail): the client hides it on graphics "Low" (#76,
-- client/GraphicsQuality.DETAIL_TAG).
local DETAIL_TAG = "GraphicsDetail"

-- Rising bubbles of the Atlantis deco (#82): small, light, a little wobbly. The client
-- lowers the rate on graphics "Low" (GraphicsQuality).
local function bubbles(p: BasePart)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Bubbles"
	emitter.Color = ColorSequence.new(p.Color)
	emitter.LightEmission = 0.5
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.8, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0.7),
	})
	emitter.Rate = 6
	emitter.Lifetime = NumberRange.new(4, 6)
	emitter.Speed = NumberRange.new(3, 5)
	emitter.SpreadAngle = Vector2.new(10, 10)
	emitter.Acceleration = Vector3.new(0, 1, 0)
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.Parent = p
end

-- Fireflies of the jungle deco (#83): tiny glowing dots drifting slowly in all
-- directions, fading in and out.
local function fireflies(p: BasePart)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Fireflies"
	emitter.Color = ColorSequence.new(p.Color)
	emitter.LightEmission = 1
	emitter.Brightness = 3
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.1),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(0.75, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new(0.22)
	emitter.Rate = 3
	emitter.Lifetime = NumberRange.new(5, 8)
	emitter.Speed = NumberRange.new(0.4, 1.2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 0.5
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Parent = p
end

-- Low mist of the jungle deco (#83): big, very faint puffs creeping over the ground.
local function mist(p: BasePart)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Mist"
	emitter.Color = ColorSequence.new(p.Color)
	emitter.LightEmission = 0.2
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.82),
		NumberSequenceKeypoint.new(0.7, 0.86),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new(5, 10)
	emitter.Rate = 1.2
	emitter.Lifetime = NumberRange.new(9, 13)
	emitter.Speed = NumberRange.new(0.3, 0.8)
	emitter.SpreadAngle = Vector2.new(80, 5)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = Vector3.new(0, -0.02, 0)
	emitter.RotSpeed = NumberRange.new(-6, 6)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.Parent = p
end

local SHAPES: { [string]: Enum.PartType } = {
	Block = Enum.PartType.Block,
	Ball = Enum.PartType.Ball,
	Cylinder = Enum.PartType.Cylinder,
}

local function toCFrame(c: { number }): CFrame
	return CFrame.new(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

function IslandBuilder.toCFrame(c: { number }): CFrame
	return toCFrame(c)
end

function IslandBuilder.vector(p: { number }): Vector3
	return Vector3.new(p[1], p[2], p[3])
end

-- One part from a PartSpec.
function IslandBuilder.part(spec: IslandPlan.PartSpec, parent: Instance): BasePart
	local p: BasePart
	if spec.shape == "Wedge" then
		p = Instance.new("WedgePart")
	else
		local block = Instance.new("Part")
		block.Shape = SHAPES[spec.shape] or Enum.PartType.Block
		p = block
	end
	p.Name = spec.name
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
	p.CFrame = toCFrame(spec.cframe)
	p.Color = rgb(spec.color)
	p.Material = (Enum.Material :: any)[spec.material] or Enum.Material.SmoothPlastic
	p.Transparency = spec.transparency or 0
	p.CanCollide = spec.collide
	if not spec.collide then
		p.CanQuery = false
	end
	p.CanTouch = false
	if spec.role then
		p:SetAttribute("IslandRole", spec.role)
	end
	if spec.role == "Wall" then
		-- Invisible: no shadow, and the camera/clicks look through it.
		p.CastShadow = false
	elseif spec.role == "Waterfall" then
		p.CastShadow = false
		local mist = Instance.new("ParticleEmitter")
		mist.Color = ColorSequence.new(Color3.fromRGB(235, 248, 255))
		mist.LightEmission = 0.4
		mist.Transparency = NumberSequence.new(0.4, 1)
		mist.Size = NumberSequence.new(1.5, 4)
		mist.Rate = 12
		mist.Lifetime = NumberRange.new(1.2, 2)
		mist.Speed = NumberRange.new(4, 8)
		mist.EmissionDirection = Enum.NormalId.Bottom
		mist.Parent = p
	elseif spec.role == "Smoke" then
		-- Volcano crater (#47): slow dark smoke rising and spreading.
		p.CastShadow = false
		local smoke = Instance.new("ParticleEmitter")
		smoke.Color = ColorSequence.new(Color3.fromRGB(70, 66, 66), Color3.fromRGB(140, 136, 136))
		smoke.LightEmission = 0
		smoke.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(0.6, 0.7),
			NumberSequenceKeypoint.new(1, 1),
		})
		smoke.Size = NumberSequence.new(2.5, 9)
		smoke.Rate = 6
		smoke.Lifetime = NumberRange.new(5, 7)
		smoke.Speed = NumberRange.new(3, 5)
		smoke.SpreadAngle = Vector2.new(12, 12)
		smoke.Acceleration = Vector3.new(0.6, 0.4, 0)
		smoke.RotSpeed = NumberRange.new(-15, 15)
		smoke.EmissionDirection = Enum.NormalId.Top
		smoke.Parent = p
	elseif spec.role == "Bubbles" then
		p.CastShadow = false
		bubbles(p)
	elseif spec.role == "Fireflies" then
		p.CastShadow = false
		fireflies(p)
	elseif spec.role == "Mist" then
		p.CastShadow = false
		mist(p)
	elseif spec.name == "FountainSpout" then
		local spray = Instance.new("ParticleEmitter")
		spray.Color = ColorSequence.new(Color3.fromRGB(190, 235, 255))
		spray.LightEmission = 0.3
		spray.Transparency = NumberSequence.new(0.2, 1)
		spray.Size = NumberSequence.new(0.6, 0.2)
		spray.Rate = 40
		spray.Lifetime = NumberRange.new(1, 1.4)
		spray.Speed = NumberRange.new(10, 13)
		spray.SpreadAngle = Vector2.new(18, 18)
		spray.Acceleration = Vector3.new(0, -30, 0)
		spray.Parent = p
	elseif spec.material == "Neon" and spec.role == "Glow" then
		local light = Instance.new("PointLight")
		light.Color = p.Color
		light.Range = 10
		light.Brightness = 1.2
		light.Parent = p
	end
	if spec.detail then
		p.CastShadow = false
		CollectionService:AddTag(p, DETAIL_TAG)
	end
	p.Parent = parent
	return p
end

-- All parts of a plan; the scripted world deco (#82) only with features.worldDeco.
function IslandBuilder.parts(specs: { IslandPlan.PartSpec }, parent: Instance)
	local withDeco = features.enabled("worldDeco")
	for _, spec in specs do
		if withDeco or not spec.deco then
			IslandBuilder.part(spec, parent)
		end
	end
end

-- Stand-ins while the Blender models are not imported (same proportions).
local function fallbackTree(parent: Instance, model: IslandPlan.ModelSpec)
	local w = model.width
	local base = IslandBuilder.vector(model.position)
	local group = Instance.new("Model")
	group.Name = model.model
	local trunk = Instance.new("Part")
	trunk.Name = "Wood"
	trunk.Anchored = true
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size = Vector3.new(w * 0.55, w * 0.22, w * 0.22)
	trunk.CFrame = CFrame.new(base + Vector3.new(0, w * 0.27, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	trunk.Color = Color3.fromRGB(150, 96, 52)
	trunk.Material = Enum.Material.SmoothPlastic
	trunk.Parent = group
	for i, ball in { { 0.95, Vector3.new(0, 0.95, 0) }, { 0.5, Vector3.new(0.27, 1.2, -0.24) } } do
		local crown = Instance.new("Part")
		crown.Name = if i == 1 then "Leaves" else "LeavesLight"
		crown.Anchored = true
		crown.Shape = Enum.PartType.Ball
		crown.Size = Vector3.one * w * (ball[1] :: number)
		crown.Position = base + (ball[2] :: Vector3) * w
		crown.Color = if i == 1 then Color3.fromRGB(96, 196, 82) else Color3.fromRGB(140, 220, 96)
		crown.Material = Enum.Material.SmoothPlastic
		crown.CanCollide = false
		crown.Parent = group
	end
	group.Parent = parent
end

local function fallbackBush(parent: Instance, model: IslandPlan.ModelSpec)
	local bush = Instance.new("Part")
	bush.Name = "Bush"
	bush.Anchored = true
	bush.Shape = Enum.PartType.Ball
	bush.Size = Vector3.one * model.width * 0.75
	bush.Position = IslandBuilder.vector(model.position) + Vector3.new(0, model.width * 0.25, 0)
	bush.Color = Color3.fromRGB(96, 196, 82)
	bush.Material = Enum.Material.SmoothPlastic
	bush.CanCollide = false
	bush.Parent = parent
end

function IslandBuilder.models(models: { IslandPlan.ModelSpec }, parent: Instance)
	for _, model in models do
		local cframe = CFrame.new(IslandBuilder.vector(model.position)) * CFrame.Angles(0, model.yaw, 0)
		if ModelLibrary.place(model.model, model.width, cframe, parent, model.collide) == nil then
			if model.model == "Bush" then
				fallbackBush(parent, model)
			elseif
				model.model == "RoundTree"
				or not WorldDeco.fallback(parent, model.model, model.width, cframe, model.collide)
			then
				fallbackTree(parent, model)
			end
		end
	end
end

-- Whole island: parts and models into a folder `name` under `parent`.
function IslandBuilder.island(island: IslandPlan.Island, name: string, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	IslandBuilder.parts(island.parts, folder)
	IslandBuilder.models(island.models, folder)
	folder.Parent = parent
	return folder
end

-- Ground point of a station as a CFrame (yaw 0 = front faces -Z).
function IslandBuilder.station(station: IslandPlan.Station): CFrame
	return CFrame.new(IslandBuilder.vector(station.position)) * CFrame.Angles(0, station.yaw, 0)
end

-- Turns a model built facing -Z at `ground` by `yaw` around that ground point.
function IslandBuilder.turn(model: Model, ground: Vector3, yaw: number)
	if yaw == 0 then
		return
	end
	model.WorldPivot = CFrame.new(ground)
	model:PivotTo(CFrame.new(ground) * CFrame.Angles(0, yaw, 0))
end

return IslandBuilder
