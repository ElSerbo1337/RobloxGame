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

return WorldDeco
