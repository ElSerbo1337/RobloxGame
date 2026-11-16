--!strict
-- Placeholder map for world 1 (Pizzeria-Garten), built by code on server start.
-- Will be replaced by a proper map later; the returned layout is what the services use.

local Workspace = game:GetService("Workspace")

export type Layout = {
	folder: Folder,
	-- Toppings spawn on a rectangle centered here (y = ground surface).
	toppingAreaCenter: Vector3,
	toppingAreaSize: Vector2,
	toppingsFolder: Folder,
	sellZone: BasePart,
}

local GROUND_Y = 0.1

local World1Map = {}

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

local function sign(parent: Instance, adornee: BasePart, text: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(10, 2.5)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, adornee.Size.Y / 2 + 2.5, 0)
	billboard.MaxDistance = 150
	billboard.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(255, 240, 200)
	label.TextStrokeTransparency = 0.2
	label.Parent = billboard
	billboard.Parent = parent
end

function World1Map.build(): Layout
	local folder = Instance.new("Folder")
	folder.Name = "World1_PizzeriaGarden"

	part({
		Name = "Ground",
		Size = Vector3.new(200, 1, 200),
		Position = Vector3.new(0, GROUND_Y - 0.5, 0),
		Color = Color3.fromRGB(110, 190, 90),
		Material = Enum.Material.Grass,
		Parent = folder,
	})

	local areaCenter = Vector3.new(0, GROUND_Y, -10)
	local areaSize = Vector2.new(120, 100)
	part({
		Name = "ToppingArea",
		Size = Vector3.new(areaSize.X + 6, 0.1, areaSize.Y + 6),
		Position = areaCenter + Vector3.new(0, 0.05, 0),
		Color = Color3.fromRGB(150, 210, 110),
		Material = Enum.Material.Grass,
		CanCollide = false,
		Parent = folder,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, GROUND_Y + 0.5, 60)
	spawn.Color = Color3.fromRGB(255, 200, 80)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = folder

	-- Oven: brick box with a dark opening, players sell by walking into the zone in front of it.
	local ovenPos = Vector3.new(30, GROUND_Y, 68)
	local oven = part({
		Name = "Oven",
		Size = Vector3.new(12, 9, 8),
		Position = ovenPos + Vector3.new(0, 4.5, 0),
		Color = Color3.fromRGB(170, 70, 45),
		Material = Enum.Material.Brick,
		Parent = folder,
	})
	part({
		Name = "OvenOpening",
		Size = Vector3.new(6, 3.5, 0.2),
		Position = ovenPos + Vector3.new(0, 3, -4.05),
		Color = Color3.fromRGB(255, 120, 30),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = folder,
	})
	part({
		Name = "Chimney",
		Size = Vector3.new(2, 4, 2),
		Position = ovenPos + Vector3.new(3, 11, 2),
		Color = Color3.fromRGB(120, 60, 45),
		Material = Enum.Material.Brick,
		Parent = folder,
	})
	sign(folder, oven, "Ofen – hier verkaufen")

	local sellZone = part({
		Name = "SellZone",
		Size = Vector3.new(14, 6, 10),
		Position = ovenPos + Vector3.new(0, 3, -9.5),
		Color = Color3.fromRGB(255, 150, 40),
		Material = Enum.Material.ForceField,
		Transparency = 0.3,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = folder,
	})

	local toppingsFolder = Instance.new("Folder")
	toppingsFolder.Name = "Toppings"
	toppingsFolder.Parent = folder

	folder.Parent = Workspace

	return {
		folder = folder,
		toppingAreaCenter = areaCenter,
		toppingAreaSize = areaSize,
		toppingsFolder = toppingsFolder,
		sellZone = sellZone,
	}
end

return World1Map
