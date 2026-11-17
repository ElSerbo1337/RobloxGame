--!strict
-- Builds the flying islands (#27) from the island plan (ReplicatedStorage.Shared.IslandPlan):
-- the spawn island, the bridges, and every world. Worlds in GameConfig.islands.newStyle
-- are islands in the shared floor plan; the others keep their old square look (worlds
-- 2-7 until B5/B6) but hang on the same chain with bridges, gates and walls.
-- Adding a world = config entry (+ optional theme below), no new map code.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local EggService = require(script.Parent.EggService)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local IslandBuilder = require(script.Parent.IslandBuilder)
local IslandPlan = require(ReplicatedStorage.Shared.IslandPlan)
local WorldDeco = require(script.Parent.WorldDeco)

export type Layout = {
	worldId: string,
	index: number,
	folder: Folder,
	-- Toppings spawn on a rectangle centered here (y = ground surface).
	toppingAreaCenter: Vector3,
	toppingAreaSize: Vector2,
	toppingsFolder: Folder,
	sellZone: BasePart,
	-- Gate barrier on the bridge head (tag "WorldBarrier"); nil for world 1.
	barrier: BasePart?,
	-- Ground rectangle of the world (y ignored); players without access are sent back.
	boundsCenter: Vector3,
	boundsSize: Vector2,
	-- Where players without access are put back (on the bridge in front of the gate).
	returnPoint: Vector3,
	-- Egg stand drums (attributes WorldId, EggId); EggService puts the eggs on them.
	eggStands: { BasePart },
	-- Ground point and facing of the world's shop stand (worlds with a shop).
	shopSpot: CFrame,
	isIsland: boolean,
}

type Theme = { ground: Color3, area: Color3, accent: Color3, material: Enum.Material }

local HALF = GameConfig.islands.worldHalfSize

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

local plan = IslandPlan.new(GameConfig.islands, GameConfig.worlds)
WorldMap.plan = plan

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

local function isNewStyle(index: number): boolean
	return GameConfig.islands.newStyle[GameConfig.worlds[index].id] == true
end

function WorldMap.centerOf(index: number): Vector3
	return IslandBuilder.vector(plan.worldCenter(index))
end

-- Ground point and facing of a station of world `index` ("Oven", "Portal", "Phone", ...).
function WorldMap.station(index: number, name: string): CFrame?
	local station = plan.worldIsland(index).stations[name]
	return if station then IslandBuilder.station(station) else nil
end

-- Where players (re)spawn in a world: the world's spawn spot, facing the field (-Z).
function WorldMap.spawnPointOf(index: number): CFrame
	local ground = (WorldMap.station(index, "Spawn") :: CFrame).Position
	local position = ground + Vector3.new(0, 3, 0)
	return CFrame.lookAt(position, position - Vector3.zAxis)
end

-- Spawn point on the spawn island (new players, and players without a respawn world).
function WorldMap.startSpawnPoint(): CFrame
	local ground = IslandBuilder.vector(plan.spawnIsland().stations.Spawn.position)
	local position = ground + Vector3.new(0, 3, 0)
	return CFrame.lookAt(position, position - Vector3.zAxis)
end

-- Ground point and facing of a station on the spawn island ("Portal", "Fountain", ...).
function WorldMap.spawnStation(name: string): CFrame
	return IslandBuilder.station(plan.spawnIsland().stations[name])
end

-- Index of the world whose island contains the position, or nil (spawn island, bridges).
function WorldMap.worldIndexAt(position: Vector3): number?
	return plan.worldIndexAt(position.X, position.Z)
end

-- True once a character fell below the islands.
function WorldMap.hasFallen(position: Vector3): boolean
	return plan.hasFallen(position.Y)
end

-- Oven box with glowing opening and the sell zone in front of it, at `cf` (front -Z).
local function buildOven(folder: Instance, cf: CFrame, world: any, color: Color3, material: Enum.Material): BasePart
	local oven = part({
		Name = "Oven",
		Size = Vector3.new(12, 9, 8),
		CFrame = cf * CFrame.new(0, 4.5, 0),
		Color = color,
		Material = material,
		Parent = folder,
	})
	part({
		Name = "OvenOpening",
		Size = Vector3.new(6, 3.5, 0.2),
		CFrame = cf * CFrame.new(0, 3, -4.05),
		Color = Color3.fromRGB(255, 120, 30),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = folder,
	})
	sign(
		folder,
		oven,
		if world.id == GameConfig.worlds[1].id
			then "Ofen – hier verkaufen"
			else `Ofen ({world.displayName}) – hier verkaufen`
	)
	return part({
		Name = "SellZone",
		Size = Vector3.new(14, 6, 10),
		CFrame = cf * CFrame.new(0, 3, -9.5),
		Color = Color3.fromRGB(255, 150, 40),
		Material = Enum.Material.ForceField,
		Transparency = 0.3,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = folder,
	})
end

-- Glowing gate on the bridge head of world `index` (>= 2). Its barrier is solid for
-- everyone on the server; each client makes it passable once its player unlocked the world.
local function buildGate(folder: Instance, world: any, index: number): (BasePart, Vector3)
	local gate = plan.gate(index)
	local gateModel = Instance.new("Model")
	gateModel.Name = "Gate"
	IslandBuilder.parts(gate.parts, gateModel)
	gateModel.Parent = folder
	local barrier = IslandBuilder.part(gate.barrier, folder)
	barrier.CastShadow = false
	barrier:SetAttribute("WorldId", world.id)
	barrier:SetAttribute("WorldName", world.displayName)
	barrier:SetAttribute("UnlockPrice", world.unlockPrice)
	CollectionService:AddTag(barrier, "WorldBarrier")
	sign(
		barrier,
		barrier,
		`🔒 {world.displayName}\n{formatCoins(world.unlockPrice)} Münzen`,
		-barrier.Size.Y / 2 + 9,
		"PriceSign"
	)
	return barrier, IslandBuilder.vector(gate.returnPoint)
end

local function toppingsFolder(folder: Instance): Folder
	local toppings = Instance.new("Folder")
	toppings.Name = "Toppings"
	toppings.Parent = folder
	return toppings
end

-- World in the new island look, built from the shared floor plan.
local function buildIsland(world: any, index: number): Layout
	local island = plan.worldIsland(index)
	local center = IslandBuilder.vector(island.center)
	local folder = IslandBuilder.island(island, `World{index}_{world.id}`, Workspace)
	folder.Parent = nil

	local ovenCf = IslandBuilder.station(island.stations.Oven)
	local sellZone = buildOven(folder, ovenCf, world, Color3.fromRGB(226, 112, 62), Enum.Material.SmoothPlastic)
	WorldDeco.dressOven(folder)

	local eggStands = {}
	for i, name in { "Egg1", "Egg2" } do
		local station = island.stations[name]
		local eggId = world.eggs and world.eggs[i]
		local stand = EggService.buildStand(folder, IslandBuilder.vector(station.position), eggId, station.yaw)
		stand:SetAttribute("WorldId", world.id)
		table.insert(eggStands, stand)
	end

	local barrier, returnPoint = nil, center + Vector3.new(0, 3, HALF + 12)
	if index >= 2 then
		barrier, returnPoint = buildGate(folder, world, index)
	end

	local field = island.field :: any
	local fieldCenter = IslandBuilder.vector(field.center)
	local toppings = toppingsFolder(folder)
	folder.Parent = Workspace
	return {
		worldId = world.id,
		index = index,
		folder = folder,
		toppingAreaCenter = fieldCenter,
		toppingAreaSize = Vector2.new(field.size[1], field.size[2]),
		toppingsFolder = toppings,
		sellZone = sellZone,
		barrier = barrier,
		boundsCenter = center,
		boundsSize = Vector2.new(2 * HALF, 2 * HALF),
		returnPoint = returnPoint,
		eggStands = eggStands,
		shopSpot = IslandBuilder.station(island.stations.Shop),
		isIsland = true,
	}
end

-- World in the old square look (worlds 2-7 until B5/B6), on the island chain.
local function buildClassic(world: any, index: number): Layout
	local theme = THEMES[world.id] or DEFAULT_THEME
	local island = plan.worldIsland(index)
	local center = WorldMap.centerOf(index)

	local folder = Instance.new("Folder")
	folder.Name = `World{index}_{world.id}`
	-- Walls along the rim and a rock underside from the plan; the ground is the old plate.
	IslandBuilder.parts(island.parts, folder)

	part({
		Name = "Ground",
		Size = Vector3.new(2 * HALF, 1, 2 * HALF),
		Position = center - Vector3.new(0, 0.5, 0),
		Color = theme.ground,
		Material = theme.material,
		Parent = folder,
	})

	local field = island.field :: any
	local areaCenter = IslandBuilder.vector(field.center)
	local areaSize = Vector2.new(field.size[1], field.size[2])
	part({
		Name = "ToppingArea",
		Size = Vector3.new(areaSize.X + 6, 0.1, areaSize.Y + 6),
		Position = areaCenter + Vector3.new(0, 0.05, 0),
		Color = theme.area,
		Material = theme.material,
		CanCollide = false,
		Parent = folder,
	})

	-- Oven near the entrance, both egg stands on the other side of the path.
	local sellZone =
		buildOven(folder, IslandBuilder.station(island.stations.Oven), world, theme.accent, Enum.Material.Brick)
	local eggStands = {}
	for i, name in { "Egg1", "Egg2" } do
		local eggId = world.eggs and world.eggs[i]
		local stand = EggService.buildStand(folder, IslandBuilder.vector(island.stations[name].position), eggId)
		stand:SetAttribute("WorldId", world.id)
		table.insert(eggStands, stand)
	end

	local barrier, returnPoint = buildGate(folder, world, index)
	local toppings = toppingsFolder(folder)
	folder.Parent = Workspace

	return {
		worldId = world.id,
		index = index,
		folder = folder,
		toppingAreaCenter = areaCenter,
		toppingAreaSize = areaSize,
		toppingsFolder = toppings,
		sellZone = sellZone,
		barrier = barrier,
		boundsCenter = center,
		boundsSize = Vector2.new(2 * HALF, 2 * HALF),
		returnPoint = returnPoint,
		eggStands = eggStands,
		shopSpot = IslandBuilder.station(island.stations.Shop),
		isIsland = false,
	}
end

function WorldMap.build(world: any, index: number): Layout
	if isNewStyle(index) then
		return buildIsland(world, index)
	end
	return buildClassic(world, index)
end

-- Builds every world from the config, in unlock order (world 1 first).
function WorldMap.buildAll(): { Layout }
	local layouts = {}
	for index, world in GameConfig.worlds do
		table.insert(layouts, WorldMap.build(world, index))
	end
	return layouts
end

-- Spawn island: SpawnLocation, pizza fountain, leaderboard boards (a SurfaceGui per
-- panel, filled by LeaderboardService), the trees and the rim. The portal gate is
-- built by PortalService.

function WorldMap.buildSpawnIsland(): Folder
	local island = plan.spawnIsland()
	local folder = IslandBuilder.island(island, "SpawnIsland", Workspace)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = IslandBuilder.station(island.stations.Spawn) + Vector3.new(0, 0.5, 0)
	spawn.Color = Color3.fromRGB(255, 200, 80)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = folder

	-- Leaderboards: the panels come from the plan, the text goes on their front
	-- (board `index` = GameConfig.leaderboards.boards[index]).
	local index = 0
	for _, panel in folder:GetChildren() do
		if panel:IsA("BasePart") and panel.Name == "BoardPanel" then
			index += 1
			local gui = Instance.new("SurfaceGui")
			gui.Name = "Leaderboard"
			gui.Face = Enum.NormalId.Front
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 40
			gui.LightInfluence = 0.2
			gui.MaxDistance = 150
			gui:SetAttribute("Board", index)
			local label = Instance.new("TextLabel")
			label.Name = "Text"
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.TextColor3 = Color3.fromRGB(60, 35, 20)
			local board = GameConfig.leaderboards.boards[index]
			label.Text = `{if board then board.title else "Bestenliste"}\nBestenliste lädt …`
			label.Parent = gui
			local padding = Instance.new("UIPadding")
			padding.PaddingTop = UDim.new(0.1, 0)
			padding.PaddingBottom = UDim.new(0.1, 0)
			padding.PaddingLeft = UDim.new(0.06, 0)
			padding.PaddingRight = UDim.new(0.06, 0)
			padding.Parent = label
			gui.Parent = panel
		end
	end
	return folder
end

-- Bridges between all islands (spawn -> world 1 -> world 2 ...).
function WorldMap.buildBridges(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Bridges"
	for i, bridge in plan.bridges() do
		local model = Instance.new("Model")
		model.Name = `Bridge{i}`
		IslandBuilder.parts(bridge.parts, model)
		model.Parent = folder
	end
	folder.Parent = Workspace
	return folder
end

-- Invisible point at the bridge head of world 1: the tutorial arrow leads there first
-- while the player is still on the spawn island or the bridge.
function WorldMap.buildTutorialWaypoint(): BasePart
	local front = IslandBuilder.vector(plan.worldIsland(1).openings.front :: { number })
	return part({
		Name = "TutorialWaypoint",
		Size = Vector3.new(2, 2, 2),
		Position = front + Vector3.new(0, 1, -4),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = Workspace,
	})
end

-- The islands float: a Baseplate from the place template would be a floor under them.
function WorldMap.removeBaseplate()
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		warn("[WorldMap] Baseplate entfernt (die Inseln schweben) – bitte in Studio löschen und speichern.")
		baseplate:Destroy()
	end
end

return WorldMap
