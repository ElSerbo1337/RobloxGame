--!strict
-- Builds every world after the first by the same pattern, driven by GameConfig.worlds:
-- ground, topping area, oven with sell zone, egg stand and the barrier in front of it.
-- World n lies directly behind world n - 1 along -Z; the barrier sits on their border.
-- Adding a world = config entry (+ optional theme below), no new map code.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

export type Layout = {
	worldId: string,
	folder: Folder,
	-- Toppings spawn on a rectangle centered here (y = ground surface).
	toppingAreaCenter: Vector3,
	toppingAreaSize: Vector2,
	toppingsFolder: Folder,
	sellZone: BasePart,
	-- Blocks the way in until the player unlocked this world (tag "WorldBarrier").
	barrier: BasePart,
	-- Ground rectangle of the world (y ignored); players without access are sent back.
	boundsCenter: Vector3,
	boundsSize: Vector2,
	-- Where players without access are put back (in front of the barrier, previous world).
	returnPoint: Vector3,
	-- Where the world's egg sits (attributes WorldId, EggId); the egg service hooks in here.
	eggStand: BasePart,
	-- Free ground spot left of the egg stand for a shop stand facing -Z (worlds with a shop).
	shopSpot: Vector3,
}

type Theme = { ground: Color3, area: Color3, accent: Color3, material: Enum.Material }

local GROUND_Y = 0.1
-- Same size as world 1 (World1Map), so the worlds line up edge to edge.
local WORLD_SIZE = 200
local BARRIER_HEIGHT = 40

local THEMES: { [string]: Theme } = {
	Farm = {
		ground = Color3.fromRGB(196, 170, 100),
		area = Color3.fromRGB(150, 120, 70),
		accent = Color3.fromRGB(200, 60, 50),
		material = Enum.Material.Ground,
	},
	Beach = {
		ground = Color3.fromRGB(240, 220, 160),
		area = Color3.fromRGB(225, 200, 135),
		accent = Color3.fromRGB(40, 170, 200),
		material = Enum.Material.Sand,
	},
	Icebergs = {
		ground = Color3.fromRGB(225, 240, 250),
		area = Color3.fromRGB(180, 215, 240),
		accent = Color3.fromRGB(90, 150, 230),
		material = Enum.Material.Snow,
	},
	Volcano = {
		ground = Color3.fromRGB(118, 88, 78),
		area = Color3.fromRGB(150, 86, 62),
		accent = Color3.fromRGB(255, 90, 30),
		material = Enum.Material.Basalt,
	},
	CandyLand = {
		ground = Color3.fromRGB(255, 190, 220),
		area = Color3.fromRGB(255, 230, 245),
		accent = Color3.fromRGB(150, 90, 230),
		material = Enum.Material.SmoothPlastic,
	},
	Space = {
		ground = Color3.fromRGB(150, 150, 165),
		area = Color3.fromRGB(110, 105, 140),
		accent = Color3.fromRGB(120, 255, 200),
		material = Enum.Material.Slate,
	},
}
local DEFAULT_THEME: Theme = {
	ground = Color3.fromRGB(120, 180, 120),
	area = Color3.fromRGB(150, 200, 130),
	accent = Color3.fromRGB(80, 120, 220),
	material = Enum.Material.Grass,
}

local WorldMap = {}

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

local function sign(parent: Instance, adornee: BasePart, text: string, height: number?, name: string?)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = name or "Sign"
	billboard.Size = UDim2.fromScale(12, 3)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, height or (adornee.Size.Y / 2 + 2.5), 0)
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

local function formatCoins(value: number): string
	local text = tostring(math.floor(value))
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1.")))
	return (string.gsub(formatted, "^%.", ""))
end

-- World 1 (index 1) is built by World1Map and centered at the origin.
function WorldMap.centerOf(index: number): Vector3
	return Vector3.new(0, GROUND_Y, -WORLD_SIZE * (index - 1))
end

-- Where players (re)spawn in a world: on the path between egg and oven, facing the
-- topping area (same spot as world 1's SpawnLocation).
local SPAWN_OFFSET = Vector3.new(0, 3, 60)

function WorldMap.spawnPointOf(index: number): CFrame
	local position = WorldMap.centerOf(index) + SPAWN_OFFSET
	return CFrame.lookAt(position, position - Vector3.zAxis)
end

-- Index of the world (world 1 included) whose ground rectangle contains the position, or nil.
function WorldMap.worldIndexAt(position: Vector3): number?
	for index = 1, #GameConfig.worlds do
		local offset = position - WorldMap.centerOf(index)
		if math.abs(offset.X) <= WORLD_SIZE / 2 and math.abs(offset.Z) <= WORLD_SIZE / 2 then
			return index
		end
	end
	return nil
end

function WorldMap.build(world: any, index: number): Layout
	assert(index >= 2, "world 1 is built by World1Map")
	local theme = THEMES[world.id] or DEFAULT_THEME
	local center = WorldMap.centerOf(index)

	local folder = Instance.new("Folder")
	folder.Name = `World{index}_{world.id}`

	part({
		Name = "Ground",
		Size = Vector3.new(WORLD_SIZE, 1, WORLD_SIZE),
		Position = center - Vector3.new(0, 0.5, 0),
		Color = theme.ground,
		Material = theme.material,
		Parent = folder,
	})

	local areaCenter = center + Vector3.new(0, 0, -10)
	local areaSize = Vector2.new(120, 100)
	part({
		Name = "ToppingArea",
		Size = Vector3.new(areaSize.X + 6, 0.1, areaSize.Y + 6),
		Position = areaCenter + Vector3.new(0, 0.05, 0),
		Color = theme.area,
		Material = theme.material,
		CanCollide = false,
		Parent = folder,
	})

	-- Oven near the entrance, same spot as in world 1.
	local ovenPos = center + Vector3.new(30, 0, 68)
	local oven = part({
		Name = "Oven",
		Size = Vector3.new(12, 9, 8),
		Position = ovenPos + Vector3.new(0, 4.5, 0),
		Color = theme.accent,
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
	sign(folder, oven, `Ofen ({world.displayName}) – hier verkaufen`)

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

	-- Egg stand on the other side of the entrance; EggService puts the world's egg on it.
	local eggPos = center + Vector3.new(-30, 0, 68)
	local eggStand = part({
		Name = "EggStand",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.5, 10, 10),
		CFrame = CFrame.new(eggPos + Vector3.new(0, 0.75, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(240, 230, 210),
		Material = Enum.Material.SmoothPlastic,
		Parent = folder,
	})
	local eggId = world.eggs and world.eggs[1]
	eggStand:SetAttribute("WorldId", world.id)
	eggStand:SetAttribute("EggId", eggId)

	-- Barrier on the border to the previous world. Solid for everyone on the server;
	-- each client makes it passable locally once its player unlocked the world.
	local border = center + Vector3.new(0, 0, WORLD_SIZE / 2)
	local barrier = part({
		Name = "Barrier",
		Size = Vector3.new(WORLD_SIZE, BARRIER_HEIGHT, 2),
		Position = border + Vector3.new(0, BARRIER_HEIGHT / 2, 0),
		Color = theme.accent,
		Material = Enum.Material.ForceField,
		Transparency = 0.2,
		CastShadow = false,
		Parent = folder,
	})
	barrier:SetAttribute("WorldId", world.id)
	barrier:SetAttribute("WorldName", world.displayName)
	barrier:SetAttribute("UnlockPrice", world.unlockPrice)
	CollectionService:AddTag(barrier, "WorldBarrier")
	sign(
		barrier,
		barrier,
		`🔒 {world.displayName}\n{formatCoins(world.unlockPrice)} Münzen`,
		-BARRIER_HEIGHT / 2 + 9,
		"PriceSign"
	)

	local toppingsFolder = Instance.new("Folder")
	toppingsFolder.Name = "Toppings"
	toppingsFolder.Parent = folder

	folder.Parent = Workspace

	return {
		worldId = world.id,
		folder = folder,
		toppingAreaCenter = areaCenter,
		toppingAreaSize = areaSize,
		toppingsFolder = toppingsFolder,
		sellZone = sellZone,
		barrier = barrier,
		boundsCenter = center,
		boundsSize = Vector2.new(WORLD_SIZE, WORLD_SIZE),
		returnPoint = border + Vector3.new(0, 3, 10),
		eggStand = eggStand,
		shopSpot = center + Vector3.new(-72, 0, 72),
	}
end

-- Builds worlds 2..n from the config, in unlock order.
function WorldMap.buildAll(): { Layout }
	local layouts = {}
	for index = 2, #GameConfig.worlds do
		table.insert(layouts, WorldMap.build(GameConfig.worlds[index], index))
	end
	return layouts
end

return WorldMap
