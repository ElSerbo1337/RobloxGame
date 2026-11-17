--!strict
-- Decoration and nicer models on top of the code-built maps (look pass, #15).
-- Uses the imported Blender models (ModelLibrary) where they exist; otherwise
-- simple low-poly parts, so the game also looks fine before the Studio import.
-- Changes nothing the game logic uses: sell zones, oven openings, shop zones stay.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)

local GROUND_Y = 0.1
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

-- Fallback tree: trunk + two leaf balls, low-poly enough to match the models.
local function simpleTree(parent: Instance, position: Vector3, height: number)
	local model = Instance.new("Model")
	model.Name = "Tree"
	part({
		Name = "Wood",
		Size = Vector3.new(height * 0.5, height * 0.14, height * 0.14),
		CFrame = CFrame.new(position + Vector3.new(0, height * 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Shape = Enum.PartType.Cylinder,
		Color = Color3.fromRGB(150, 96, 52),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	for i, offset in { Vector3.new(0, 0.62, 0), Vector3.new(0.12, 0.85, 0.05) } do
		local size = height * (if i == 1 then 0.55 else 0.4)
		part({
			Name = "Leaves",
			Size = Vector3.new(size, size, size),
			Position = position + offset * height,
			Shape = Enum.PartType.Ball,
			Color = if i == 1 then Color3.fromRGB(96, 196, 82) else Color3.fromRGB(140, 220, 96),
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
	end
	model.Parent = parent
end

local function simpleBush(parent: Instance, position: Vector3, width: number)
	part({
		Name = "Bush",
		Size = Vector3.new(width, width * 0.7, width * 0.85),
		Position = position + Vector3.new(0, width * 0.25, 0),
		Shape = Enum.PartType.Ball,
		Color = Color3.fromRGB(96, 196, 82),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = parent,
	})
end

local function tree(parent: Instance, position: Vector3, height: number, yaw: number)
	-- The tree model is about 0.55 times as wide as it is tall.
	local placed = ModelLibrary.place(
		"Tree",
		height * 0.55,
		CFrame.new(position) * CFrame.Angles(0, math.rad(yaw), 0),
		parent,
		true
	)
	if placed == nil then
		simpleTree(parent, position, height)
	end
end

local function bush(parent: Instance, position: Vector3, width: number, yaw: number)
	local placed = ModelLibrary.place("Bush", width, CFrame.new(position) * CFrame.Angles(0, math.rad(yaw), 0), parent)
	if placed == nil then
		simpleBush(parent, position, width)
	end
end

local function flower(parent: Instance, position: Vector3, color: Color3)
	part({
		Name = "FlowerStem",
		Size = Vector3.new(0.3, 1.4, 0.3),
		Position = position + Vector3.new(0, 0.7, 0),
		Color = Color3.fromRGB(70, 160, 60),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CastShadow = false,
		Parent = parent,
	})
	part({
		Name = "Flower",
		Size = Vector3.new(0.9, 0.9, 0.9),
		Position = position + Vector3.new(0, 1.5, 0),
		Shape = Enum.PartType.Ball,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CastShadow = false,
		Parent = parent,
	})
end

-- Replaces the placeholder oven box of a world folder with the dome oven model.
-- The OvenOpening part (target of the sell animation) moves to the model's mouth.
function WorldDeco.dressOven(folder: Instance)
	local oven = folder:FindFirstChild("Oven") :: BasePart?
	if oven == nil or not ModelLibrary.has("PizzaOven") then
		return
	end
	local base = oven.Position - Vector3.new(0, oven.Size.Y / 2, 0) + Vector3.new(0, 0, OVEN_SHIFT_BACK)
	local model = ModelLibrary.place("PizzaOven", OVEN_WIDTH, CFrame.new(base), folder, true)
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

-- World 1 (Pizzeria-Garten): oven model, paths, trees, bushes and flowers around the
-- edges, a pizza on the shop counter. Positions avoid the spawn (0, 60), egg (-30, 66),
-- oven (30, 68), shop (-60, 72), portal (65, 70) and the topping area (|x| < 63, z < 43).
function WorldDeco.decorateWorld1(folder: Instance)
	WorldDeco.dressOven(folder)

	local deco = Instance.new("Folder")
	deco.Name = "Deco"

	-- Sandy paths: one along the stations at the entrance, one from the spawn to the field.
	local pathColor = Color3.fromRGB(235, 205, 150)
	part({
		Name = "Path",
		Size = Vector3.new(150, 0.1, 9),
		Position = Vector3.new(2, GROUND_Y + 0.06, 58),
		Color = pathColor,
		Material = Enum.Material.Sand,
		CanCollide = false,
		Parent = deco,
	})
	part({
		Name = "Path",
		Size = Vector3.new(9, 0.1, 6),
		Position = Vector3.new(0, GROUND_Y + 0.06, 51),
		Color = pathColor,
		Material = Enum.Material.Sand,
		CanCollide = false,
		Parent = deco,
	})

	-- Trees along both sides and behind the stations; the front edge (barrier) stays open.
	local rng = Random.new(15)
	local treeSpots = {}
	for z = -85, 85, 20 do
		table.insert(treeSpots, Vector3.new(-88, GROUND_Y, z))
		table.insert(treeSpots, Vector3.new(88, GROUND_Y, z))
	end
	for x = -75, 75, 25 do
		table.insert(treeSpots, Vector3.new(x, GROUND_Y, 92))
	end
	for _, spot in treeSpots do
		local jitter = Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))
		tree(deco, spot + jitter, rng:NextNumber(16, 24), rng:NextNumber(0, 360))
	end

	-- Bushes between field and trees, and around the stations.
	local bushSpots = {
		Vector3.new(-72, GROUND_Y, -60),
		Vector3.new(-74, GROUND_Y, -20),
		Vector3.new(-72, GROUND_Y, 20),
		Vector3.new(72, GROUND_Y, -55),
		Vector3.new(74, GROUND_Y, -10),
		Vector3.new(72, GROUND_Y, 30),
		Vector3.new(-45, GROUND_Y, 80),
		Vector3.new(15, GROUND_Y, 80),
		Vector3.new(45, GROUND_Y, 80),
		Vector3.new(-12, GROUND_Y, 72),
		Vector3.new(12, GROUND_Y, 72),
	}
	for _, spot in bushSpots do
		bush(deco, spot, rng:NextNumber(5, 7.5), rng:NextNumber(0, 360))
	end

	-- Flower patches next to the bushes.
	local flowerColors = {
		Color3.fromRGB(255, 120, 150),
		Color3.fromRGB(255, 220, 70),
		Color3.fromRGB(150, 130, 255),
		Color3.fromRGB(255, 255, 255),
	}
	for _, spot in bushSpots do
		for _ = 1, 4 do
			local offset = Vector3.new(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5))
			flower(deco, spot + offset, flowerColors[rng:NextInteger(1, #flowerColors)])
		end
	end

	-- A pizza on the shop counter.
	local shop = folder:FindFirstChild("Shop_World1Shop")
	local counterTop = shop and shop:FindFirstChild("CounterTop") :: BasePart?
	if counterTop then
		local top = counterTop.Position + Vector3.new(0, counterTop.Size.Y / 2, 0)
		ModelLibrary.place("Pizza", 2.6, CFrame.new(top), deco)
	end

	deco.Parent = folder
end

-- ---------------------------------------------------------------- worlds 2-7 (#16)

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

-- Places a deco model (imported, else its stand-in).
local function prop(parent: Instance, name: string, width: number, cframe: CFrame, collide: boolean)
	if ModelLibrary.place(name, width, cframe, parent, collide) == nil then
		fallback(parent, name, width, cframe, collide)
	end
end

type PropKind = { model: string, width: { number }, weight: number, collide: boolean? }
type Landmark = { model: string, width: number, offset: Vector3, yaw: number?, collide: boolean? }
type WorldDecoSpec = {
	path: { color: Color3, material: Enum.Material },
	-- Big props along the left/right edges and the back of the world.
	edge: { PropKind },
	-- Small props between topping area and edges, and behind the stations.
	accents: { PropKind },
	landmarks: { Landmark },
}

local SPECS: { [string]: WorldDecoSpec } = {
	Farm = {
		path = { color = rgb(170, 128, 80), material = Enum.Material.Ground },
		edge = {
			{ model = "Tree", width = { 10, 13 }, weight = 3, collide = true },
			{ model = "Sunflower", width = { 3, 4 }, weight = 2 },
		},
		accents = {
			{ model = "HayBale", width = { 6, 8 }, weight = 3, collide = true },
			{ model = "Sunflower", width = { 2.5, 3.5 }, weight = 2 },
			{ model = "Fence", width = { 10, 12 }, weight = 1 },
		},
		landmarks = {
			{ model = "Barn", width = 26, offset = Vector3.new(-80, 0, -80), yaw = 135, collide = true },
		},
	},
	Beach = {
		path = { color = rgb(180, 130, 80), material = Enum.Material.WoodPlanks },
		edge = {
			{ model = "PalmTree", width = { 12, 16 }, weight = 4, collide = true },
			{ model = "BeachRock", width = { 6, 9 }, weight = 1, collide = true },
		},
		accents = {
			{ model = "BeachUmbrella", width = { 8, 10 }, weight = 3 },
			{ model = "BeachRock", width = { 3, 5 }, weight = 2 },
		},
		landmarks = {},
	},
	Icebergs = {
		path = { color = rgb(180, 215, 240), material = Enum.Material.Ice },
		edge = {
			{ model = "SnowPine", width = { 10, 14 }, weight = 4, collide = true },
			{ model = "IceCrystal", width = { 7, 10 }, weight = 2, collide = true },
		},
		accents = {
			{ model = "Snowman", width = { 4, 5 }, weight = 2, collide = true },
			{ model = "IceCrystal", width = { 3, 5 }, weight = 2 },
		},
		landmarks = {
			{ model = "IceCrystal", width = 26, offset = Vector3.new(-80, 0, -80), yaw = 20, collide = true },
			{ model = "IceCrystal", width = 20, offset = Vector3.new(80, 0, -82), yaw = 200, collide = true },
		},
	},
	Volcano = {
		path = { color = rgb(92, 70, 64), material = Enum.Material.Basalt },
		edge = {
			{ model = "DeadTree", width = { 7, 10 }, weight = 2, collide = true },
			{ model = "LavaRock", width = { 7, 11 }, weight = 3, collide = true },
		},
		accents = {
			{ model = "LavaRock", width = { 3, 5 }, weight = 3 },
			{ model = "DeadTree", width = { 4, 6 }, weight = 1 },
		},
		landmarks = {
			{ model = "LavaMountain", width = 40, offset = Vector3.new(-79, 0, -79), yaw = 0, collide = true },
		},
	},
	CandyLand = {
		path = { color = rgb(120, 70, 45), material = Enum.Material.SmoothPlastic },
		edge = {
			{ model = "Lollipop", width = { 7, 10 }, weight = 3, collide = true },
			{ model = "CandyCane", width = { 6, 8 }, weight = 2, collide = true },
		},
		accents = {
			{ model = "Cupcake", width = { 5, 7 }, weight = 3, collide = true },
			{ model = "Lollipop", width = { 3, 4 }, weight = 2 },
		},
		landmarks = {
			{ model = "Cupcake", width = 26, offset = Vector3.new(-80, 0, -80), collide = true },
		},
	},
	Space = {
		path = { color = rgb(120, 125, 140), material = Enum.Material.DiamondPlate },
		edge = {
			{ model = "MoonRock", width = { 8, 12 }, weight = 3, collide = true },
			{ model = "SpaceCrystal", width = { 5, 7 }, weight = 2, collide = true },
		},
		accents = {
			{ model = "SpaceCrystal", width = { 2.5, 4 }, weight = 2 },
			{ model = "MoonRock", width = { 3, 5 }, weight = 2 },
		},
		landmarks = {
			{ model = "Rocket", width = 10, offset = Vector3.new(-80, 0, -80), yaw = 30, collide = true },
			-- Floating in the sky behind the world, out of reach.
			{ model = "Planet", width = 60, offset = Vector3.new(70, 70, -90), yaw = 20 },
		},
	},
}

-- Volcano lava accents (#24), relative to the world center. Kept outside the topping
-- area, the stations, phone/van and the barriers (see decorateWorld).
local LAVA_COLOR = rgb(255, 128, 36)
local LAVA_LIGHT = rgb(255, 150, 70)
local LAVA_POOLS = {
	Vector3.new(-80, 0, 0),
	Vector3.new(84, 0, -60),
	Vector3.new(-30, 0, -84),
	Vector3.new(30, 0, -84),
	Vector3.new(-80, 0, -36),
	Vector3.new(76, 0, -10),
	Vector3.new(0, 0, -76),
	Vector3.new(-76, 0, 38),
}
local LAVA_CRACKS = {
	{ at = Vector3.new(-68, 0, -28), length = 14, yaw = 15 },
	{ at = Vector3.new(-68, 0, 12), length = 12, yaw = -20 },
	{ at = Vector3.new(68, 0, -40), length = 14, yaw = -10 },
	{ at = Vector3.new(-48, 0, -70), length = 12, yaw = 75 },
	{ at = Vector3.new(18, 0, -70), length = 14, yaw = 100 },
	{ at = Vector3.new(50, 0, -72), length = 10, yaw = 80 },
}

local function pick(rng: Random, kinds: { PropKind }): PropKind
	local total = 0
	for _, kind in kinds do
		total += kind.weight
	end
	local roll = rng:NextNumber(0, total)
	for _, kind in kinds do
		roll -= kind.weight
		if roll <= 0 then
			return kind
		end
	end
	return kinds[#kinds]
end

-- Worlds 2-7: path along the stations, props along the edges, small accents and a
-- landmark, all in the world's theme. Spots (relative to the world center) avoid the
-- topping area (|x| < 63, -63 < z < 43), the stations near the entrance (z 60-80:
-- egg x -30, oven x 30, portal x 65, shop x -72), the delivery phone and van (x 78,
-- z 10-50) and the barriers (z = ±100).
function WorldDeco.decorateWorld(folder: Instance, worldId: string, center: Vector3)
	local spec = SPECS[worldId]
	if spec == nil then
		return
	end
	local deco = Instance.new("Folder")
	deco.Name = "Deco"
	local base = center + Vector3.new(0, GROUND_Y - 0.1, 0)
	local rng = Random.new(#worldId * 31 + 16)

	part({
		Name = "Path",
		Size = Vector3.new(150, 0.1, 9),
		Position = base + Vector3.new(2, 0.16, 58),
		Color = spec.path.color,
		Material = spec.path.material,
		CanCollide = false,
		Parent = deco,
	})
	part({
		Name = "Path",
		Size = Vector3.new(9, 0.1, 6),
		Position = base + Vector3.new(0, 0.16, 51),
		Color = spec.path.color,
		Material = spec.path.material,
		CanCollide = false,
		Parent = deco,
	})

	-- Keep the edge props clear of the big landmarks on the ground.
	local function free(spot: Vector3): boolean
		for _, landmark in spec.landmarks do
			local offset = landmark.offset
			if
				offset.Y < 1
				and Vector2.new(spot.X - offset.X, spot.Z - offset.Z).Magnitude < landmark.width * 0.5 + 8
			then
				return false
			end
		end
		return true
	end

	local function place(kind: PropKind, spot: Vector3)
		if not free(spot) then
			return
		end
		local width = rng:NextNumber(kind.width[1], kind.width[2])
		local cframe = CFrame.new(base + spot) * CFrame.Angles(0, math.rad(rng:NextNumber(0, 360)), 0)
		prop(deco, kind.model, width, cframe, kind.collide == true)
	end

	-- Edges: left (up to the shop) and right (leaving room for phone and van), back.
	for z = -85, 85, 17 do
		if z < 52 then
			place(pick(rng, spec.edge), Vector3.new(-89 + rng:NextNumber(-3, 3), 0, z + rng:NextNumber(-3, 3)))
		end
		if z < -5 or z > 62 then
			place(pick(rng, spec.edge), Vector3.new(89 + rng:NextNumber(-3, 3), 0, z + rng:NextNumber(-3, 3)))
		end
	end
	for x = -55, 55, 22 do
		place(pick(rng, spec.edge), Vector3.new(x + rng:NextNumber(-4, 4), 0, -88 + rng:NextNumber(-3, 3)))
	end

	-- Accents: between the topping area and the edges, and behind the station row.
	local accentSpots = {
		Vector3.new(-73, 0, -45),
		Vector3.new(-74, 0, -10),
		Vector3.new(-72, 0, 25),
		Vector3.new(72, 0, -55),
		Vector3.new(74, 0, -25),
		Vector3.new(-42, 0, 88),
		Vector3.new(-12, 0, 84),
		Vector3.new(12, 0, 84),
		Vector3.new(48, 0, 86),
	}
	for _, spot in accentSpots do
		place(pick(rng, spec.accents), spot + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2)))
	end

	for _, landmark in spec.landmarks do
		local cframe = CFrame.new(base + landmark.offset) * CFrame.Angles(0, math.rad(landmark.yaw or 0), 0)
		prop(deco, landmark.model, landmark.width, cframe, landmark.collide == true)
	end

	-- Extra touches per theme.
	if worldId == "Beach" then
		-- Shallow sea beyond the left edge (walkable, so nobody falls into the void there).
		part({
			Name = "Sea",
			Size = Vector3.new(160, 1, 200),
			Position = base + Vector3.new(-180, -0.7, 0),
			Color = rgb(60, 180, 220),
			Material = Enum.Material.Glass,
			Transparency = 0.25,
			Parent = deco,
		})
	elseif worldId == "Volcano" then
		-- Glowing lava accents (#24): pools and cracks around the topping area, each with
		-- a warm light, so the world glows without getting dark. Purely visual.
		for _, spot in LAVA_POOLS do
			local pool = part({
				Name = "LavaPool",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.2, rng:NextNumber(8, 12), rng:NextNumber(8, 12)),
				CFrame = CFrame.new(base + spot + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color = LAVA_COLOR,
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = deco,
			})
			local light = Instance.new("PointLight")
			light.Color = LAVA_LIGHT
			light.Range = 22
			light.Brightness = 2
			light.Parent = pool
		end
		for _, crack in LAVA_CRACKS do
			local strip = part({
				Name = "LavaCrack",
				Size = Vector3.new(1.2, 0.12, crack.length),
				CFrame = CFrame.new(base + crack.at + Vector3.new(0, 0.18, 0))
					* CFrame.Angles(0, math.rad(crack.yaw), 0),
				Color = LAVA_COLOR,
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = deco,
			})
			local light = Instance.new("PointLight")
			light.Color = LAVA_LIGHT
			light.Range = 14
			light.Brightness = 1.2
			light.Parent = strip
		end
	elseif worldId == "Space" then
		-- Glowing crystals light up the night a little.
		for _, child in deco:GetDescendants() do
			if child:IsA("BasePart") and child.Material == Enum.Material.Neon then
				local light = Instance.new("PointLight")
				light.Color = child.Color
				light.Range = 10
				light.Brightness = 1
				light.Parent = child
			end
		end
	end

	deco.Parent = folder
end

return WorldDeco
