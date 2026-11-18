--!strict
-- Nicer models on top of the code-built islands (#15, #16): the dome oven, and simple
-- stand-in parts for every deco model of the island themes (IslandPlan, #27, #31, #32)
-- while it is not imported in Studio, so the game also looks fine before the import.
-- Changes nothing the game logic uses: sell zones, oven openings, shop zones stay.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)

local OVEN_WIDTH = 12
-- The round oven is deeper than the placeholder box; push it back, away from the sell zone.
local OVEN_SHIFT_BACK = 1.5

local WorldDeco = {}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

-- Replaces the placeholder oven box of a world folder with the dome oven model.
-- The OvenOpening part (target of the sell animation) moves to the model's mouth.
function WorldDeco.dressOven(folder: Instance)
	local oven = folder:FindFirstChild("Oven") :: BasePart?
	if oven == nil or not ModelLibrary.has("PizzaOven") then
		return
	end
	-- The oven box may be turned (island worlds, #27): shift back along its own axes.
	local base = (oven.CFrame * CFrame.new(0, -oven.Size.Y / 2, OVEN_SHIFT_BACK)).Position
	local model = ModelLibrary.place("PizzaOven", OVEN_WIDTH, CFrame.new(base) * oven.CFrame.Rotation, folder, true)
	if model == nil then
		return
	end
	model.Name = "OvenModel"
	oven.Transparency = 1
	oven.CanCollide = false
	oven.CastShadow = false
	local chimney = folder:FindFirstChild("Chimney") :: BasePart?
	if chimney then
		chimney.Transparency = 1
		chimney.CanCollide = false
	end
	local opening = folder:FindFirstChild("OvenOpening") :: BasePart?
	local glow = model:FindFirstChild("Glow", true) :: BasePart?
	if opening and glow then
		opening.Position = glow.Position
		opening.Transparency = 1
	end
	-- Lift the oven sign above the chimney.
	for _, child in folder:GetChildren() do
		if child:IsA("BillboardGui") and child.Adornee == oven then
			child.StudsOffsetWorldSpace += Vector3.new(0, 3.5, 0)
		end
	end
	-- Warm glow from the mouth.
	if glow then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 150, 60)
		light.Range = 14
		light.Brightness = 2
		light.Parent = glow
	end
end

-- ---------------------------------------------------------------- deco stand-ins

-- Simple stand-in parts per model, used while the model isn't imported yet. Sizes and
-- offsets are in multiples of the model width (y = height above the ground).
type Piece = { shape: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material? }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local FALLBACK: { [string]: { Piece } } = {
	Tree = {
		{
			shape = "Cylinder",
			size = Vector3.new(0.25, 0.9, 0.25),
			offset = Vector3.new(0, 0.45, 0),
			color = rgb(150, 96, 52),
			material = Enum.Material.Wood,
		},
		{ shape = "Ball", size = Vector3.new(1, 1, 1), offset = Vector3.new(0, 1.2, 0), color = rgb(96, 196, 82) },
	},
	HayBale = {
		{
			shape = "Cylinder",
			size = Vector3.new(1, 0.9, 0.9),
			offset = Vector3.new(0, 0.45, 0),
			color = rgb(232, 196, 96),
			material = Enum.Material.Fabric,
		},
	},
	Sunflower = {
		{
			shape = "Block",
			size = Vector3.new(0.08, 2.2, 0.08),
			offset = Vector3.new(0, 1.1, 0),
			color = rgb(96, 196, 82),
		},
		{ shape = "Ball", size = Vector3.new(1, 1, 0.25), offset = Vector3.new(0, 2.2, 0), color = rgb(255, 206, 40) },
	},
	Barn = {
		{
			shape = "Block",
			size = Vector3.new(1, 0.65, 0.8),
			offset = Vector3.new(0, 0.33, 0),
			color = rgb(204, 62, 52),
		},
		{
			shape = "Wedge",
			size = Vector3.new(1, 0.35, 0.8),
			offset = Vector3.new(0, 0.82, 0),
			color = rgb(92, 72, 64),
		},
	},
	Fence = {
		{
			shape = "Block",
			size = Vector3.new(1, 0.06, 0.04),
			offset = Vector3.new(0, 0.28, 0),
			color = rgb(250, 246, 236),
		},
		{
			shape = "Block",
			size = Vector3.new(1, 0.06, 0.04),
			offset = Vector3.new(0, 0.15, 0),
			color = rgb(250, 246, 236),
		},
	},
	PalmTree = {
		{
			shape = "Cylinder",
			size = Vector3.new(0.12, 1.4, 0.12),
			offset = Vector3.new(0, 0.7, 0),
			color = rgb(196, 150, 92),
			material = Enum.Material.Wood,
		},
		{ shape = "Ball", size = Vector3.new(1, 0.25, 1), offset = Vector3.new(0, 1.4, 0), color = rgb(64, 182, 84) },
	},
	BeachUmbrella = {
		{
			shape = "Cylinder",
			size = Vector3.new(0.03, 0.85, 0.03),
			offset = Vector3.new(0, 0.42, 0),
			color = rgb(250, 246, 236),
		},
		{ shape = "Ball", size = Vector3.new(1, 0.25, 1), offset = Vector3.new(0, 0.85, 0), color = rgb(240, 84, 84) },
	},
	BeachRock = {
		{
			shape = "Ball",
			size = Vector3.new(1, 0.5, 0.8),
			offset = Vector3.new(0, 0.15, 0),
			color = rgb(186, 176, 166),
			material = Enum.Material.Slate,
		},
	},
	SnowPine = {
		{
			shape = "Cylinder",
			size = Vector3.new(0.12, 0.4, 0.12),
			offset = Vector3.new(0, 0.2, 0),
			color = rgb(150, 96, 52),
			material = Enum.Material.Wood,
		},
		{ shape = "Ball", size = Vector3.new(0.9, 1.4, 0.9), offset = Vector3.new(0, 1, 0), color = rgb(44, 128, 96) },
	},
	IceCrystal = {
		{
			shape = "Block",
			size = Vector3.new(0.35, 1.6, 0.35),
			offset = Vector3.new(0, 0.8, 0),
			color = rgb(150, 214, 255),
			material = Enum.Material.Glass,
		},
	},
	Snowman = {
		{
			shape = "Ball",
			size = Vector3.new(1, 1, 1),
			offset = Vector3.new(0, 0.5, 0),
			color = rgb(246, 250, 255),
			material = Enum.Material.Snow,
		},
		{
			shape = "Ball",
			size = Vector3.new(0.7, 0.7, 0.7),
			offset = Vector3.new(0, 1.25, 0),
			color = rgb(246, 250, 255),
			material = Enum.Material.Snow,
		},
	},
	LavaMountain = {
		{
			shape = "Ball",
			size = Vector3.new(1, 1, 1),
			offset = Vector3.new(0, 0, 0),
			color = rgb(112, 86, 80),
			material = Enum.Material.Basalt,
		},
		{
			shape = "Cylinder",
			size = Vector3.new(0.2, 0.04, 0.2),
			offset = Vector3.new(0, 0.5, 0),
			color = rgb(255, 128, 36),
			material = Enum.Material.Neon,
		},
	},
	LavaRock = {
		{
			shape = "Ball",
			size = Vector3.new(1, 0.7, 0.9),
			offset = Vector3.new(0, 0.2, 0),
			color = rgb(112, 86, 80),
			material = Enum.Material.Basalt,
		},
	},
	DeadTree = {
		{
			shape = "Cylinder",
			size = Vector3.new(0.12, 1.1, 0.12),
			offset = Vector3.new(0, 0.55, 0),
			color = rgb(88, 66, 60),
		},
	},
	Lollipop = {
		{
			shape = "Cylinder",
			size = Vector3.new(0.05, 1.4, 0.05),
			offset = Vector3.new(0, 0.7, 0),
			color = rgb(255, 246, 250),
		},
		{ shape = "Ball", size = Vector3.new(1, 1, 0.2), offset = Vector3.new(0, 1.6, 0), color = rgb(255, 92, 162) },
	},
	CandyCane = {
		{
			shape = "Cylinder",
			size = Vector3.new(0.25, 3.2, 0.25),
			offset = Vector3.new(0, 1.6, 0),
			color = rgb(232, 42, 62),
		},
	},
	Cupcake = {
		{
			shape = "Cylinder",
			size = Vector3.new(0.8, 0.5, 0.8),
			offset = Vector3.new(0, 0.25, 0),
			color = rgb(120, 200, 242),
		},
		{ shape = "Ball", size = Vector3.new(1, 0.6, 1), offset = Vector3.new(0, 0.6, 0), color = rgb(255, 182, 216) },
	},
	MoonRock = {
		{
			shape = "Ball",
			size = Vector3.new(1, 0.5, 0.85),
			offset = Vector3.new(0, 0.15, 0),
			color = rgb(152, 152, 168),
			material = Enum.Material.Slate,
		},
	},
	Planet = {
		{
			shape = "Ball",
			size = Vector3.new(0.65, 0.65, 0.65),
			offset = Vector3.new(0, 0.33, 0),
			color = rgb(150, 110, 232),
		},
	},
	SpaceCrystal = {
		{
			shape = "Block",
			size = Vector3.new(0.3, 1.5, 0.3),
			offset = Vector3.new(0, 0.75, 0),
			color = rgb(110, 255, 212),
			material = Enum.Material.Neon,
		},
	},
	Rocket = {
		{
			shape = "Cylinder",
			size = Vector3.new(0.45, 2.6, 0.45),
			offset = Vector3.new(0, 1.5, 0),
			color = rgb(240, 240, 246),
		},
		{
			shape = "Ball",
			size = Vector3.new(0.45, 0.6, 0.45),
			offset = Vector3.new(0, 2.8, 0),
			color = rgb(232, 62, 62),
		},
	},
}

-- Builds the stand-in for `name` with its bottom center at `cframe`.
local function fallback(parent: Instance, name: string, width: number, cframe: CFrame, collide: boolean)
	local pieces = FALLBACK[name]
	if pieces == nil then
		return
	end
	local model = Instance.new("Model")
	model.Name = name
	for _, piece in pieces do
		local size = piece.size * width
		local at = cframe * CFrame.new(piece.offset * width)
		local p = part({
			Name = name,
			Color = piece.color,
			Material = piece.material or Enum.Material.SmoothPlastic,
			CanCollide = collide,
			Parent = model,
		})
		if piece.shape == "Cylinder" then
			-- Roblox cylinders lie along X; stand them up.
			p.Shape = Enum.PartType.Cylinder
			p.Size = Vector3.new(size.Y, size.X, size.Z)
			p.CFrame = at * CFrame.Angles(0, 0, math.rad(90))
		elseif piece.shape == "Wedge" then
			p:Destroy()
			local wedge = Instance.new("WedgePart")
			wedge.Anchored = true
			wedge.Name = name
			wedge.Color = piece.color
			wedge.Material = piece.material or Enum.Material.SmoothPlastic
			wedge.CanCollide = collide
			wedge.Size = Vector3.new(size.X, size.Y, size.Z)
			wedge.CFrame = at
			wedge.Parent = model
		else
			p.Shape = if piece.shape == "Ball" then Enum.PartType.Ball else Enum.PartType.Block
			p.Size = size
			p.CFrame = at
		end
	end
	model.Parent = parent
end

-- Stand-in parts for a deco model that is not imported yet (also used for the island
-- decoration, see IslandBuilder). Returns false if there is no stand-in for `name`.
function WorldDeco.fallback(parent: Instance, name: string, width: number, cframe: CFrame, collide: boolean): boolean
	if FALLBACK[name] == nil then
		return false
	end
	fallback(parent, name, width, cframe, collide)
	return true
end

return WorldDeco
