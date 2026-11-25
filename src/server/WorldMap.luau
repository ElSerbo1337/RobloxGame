--!strict
-- Builds the flying islands (#27) from the island plan (ReplicatedStorage.Shared.IslandPlan):
-- the spawn island, the bridges, and every world. Every world is an island in the shared
-- floor plan with its theme (GameConfig.islands.themes: rim, landmark, bridge,
-- decoration). Adding a world = config entry (+ island theme), no new map code; the plan
-- is tested for all 15 worlds of the MEGA UPDATE (tests/IslandPlan15.spec.luau). Event
-- islands (#77, GameConfig.eventWorlds) float beside the spawn island.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local EggService = require(script.Parent.EggService)
local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GroundMarker = require(script.Parent.GroundMarker)
local IslandBuilder = require(script.Parent.IslandBuilder)
local IslandPlan = require(ReplicatedStorage.Shared.IslandPlan)
local SignText = require(script.Parent.SignText)
local Texts = require(ReplicatedStorage.Shared.Texts)
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
}

local HALF = GameConfig.islands.worldHalfSize

local WorldMap = {}

local plan = IslandPlan.new(GameConfig.islands, GameConfig.worlds, GameConfig.eventWorlds)
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

local function sign(
	parent: Instance,
	adornee: BasePart,
	key: string,
	args: Texts.SignArgs?,
	height: number?,
	name: string?
)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = name or "Sign"
	billboard.Size = UDim2.fromScale(12, 3)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, height or (adornee.Size.Y / 2 + 2.5), 0)
	billboard.MaxDistance = 150
	billboard.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	SignText.set(label, key, args)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(255, 240, 200)
	label.TextStrokeTransparency = 0.2
	label.Parent = billboard
	billboard.Parent = parent
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
	if world.id == GameConfig.worlds[1].id then
		sign(folder, oven, "sign.oven")
	else
		sign(folder, oven, "sign.ovenWorld", { world = Texts.nameArg(world) })
	end
	-- The zone box stays as the (invisible) detection volume; the floor marking shows it (#60).
	local sellColor = Color3.fromRGB(255, 150, 40)
	GroundMarker.build(folder, cf * CFrame.new(0, 0, -9.5), 14, 10, sellColor, "sign.sell")
	return part({
		Name = "SellZone",
		Size = Vector3.new(14, 6, 10),
		CFrame = cf * CFrame.new(0, 3, -9.5),
		Transparency = 1,
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
	barrier:SetAttribute("UnlockPrice", world.unlockPrice)
	local requiredRebirths = world.requiredRebirths or 0
	barrier:SetAttribute("RequiredRebirths", requiredRebirths)
	CollectionService:AddTag(barrier, "WorldBarrier")
	-- Worlds behind rebirths (#43) name the condition above the price.
	local price = { integer = world.unlockPrice }
	if requiredRebirths > 0 then
		local condition = {
			key = if requiredRebirths == 1 then "unlock.rebirthsOne" else "unlock.rebirthsMany",
			args = { count = requiredRebirths },
		}
		sign(barrier, barrier, "sign.gateRebirths", {
			world = Texts.nameArg(world),
			condition = condition,
			price = price,
		}, -barrier.Size.Y / 2 + 9, "PriceSign")
	else
		sign(
			barrier,
			barrier,
			"sign.gate",
			{ world = Texts.nameArg(world), price = price },
			-barrier.Size.Y / 2 + 9,
			"PriceSign"
		)
	end
	return barrier, IslandBuilder.vector(gate.returnPoint)
end

local function toppingsFolder(folder: Instance): Folder
	local toppings = Instance.new("Folder")
	toppings.Name = "Toppings"
	toppings.Parent = folder
	return toppings
end

-- World or event island, built from the shared floor plan. `index` = world index
-- (event islands: 0, no gate).
-- Reserved spots (#106) for the lucky wheel (#98), the merchant stand (#107) and the
-- leaderboards Board4/Board5 (#109) on the spawn island, and the hidden chest (#100) of a
-- world (theme.secretChest, #83): invisible anchor parts "<name>Anchor" on the ground
-- point (front = local -Z), attribute ClearRadius = studs kept free of trees and deco,
-- plus an Attachment "Ground". Every station with a `clear` radius gets one.
local function buildAnchors(island: IslandPlan.Island, folder: Instance)
	local anchors = Instance.new("Folder")
	anchors.Name = "Anchors"
	for name, station in island.stations do
		if station.clear then
			local anchor = part({
				Name = `{name}Anchor`,
				Size = Vector3.one,
				Transparency = 1,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
			})
			anchor.CFrame = IslandBuilder.station(station)
			anchor:SetAttribute("ClearRadius", station.clear)
			local ground = Instance.new("Attachment")
			ground.Name = "Ground"
			ground.Parent = anchor
			anchor.Parent = anchors
		end
	end
	anchors.Parent = folder
end

local function buildIsland(island: IslandPlan.Island, world: any, index: number, name: string): Layout
	local center = IslandBuilder.vector(island.center)
	local folder = IslandBuilder.island(island, name, Workspace)
	folder.Parent = nil

	local ovenCf = IslandBuilder.station(island.stations.Oven)
	local sellZone = buildOven(folder, ovenCf, world, Color3.fromRGB(226, 112, 62), Enum.Material.SmoothPlastic)
	WorldDeco.dressOven(folder)
	buildAnchors(island, folder)

	local eggStands = {}
	for i, name in { "Egg1", "Egg2" } do
		local station = island.stations[name]
		local eggId = world.eggs and world.eggs[i]
		-- The new worlds (#82 on) have one egg: no empty "coming soon" stand beside it.
		if eggId == nil and world.eggs and #world.eggs == 1 then
			continue
		end
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
	}
end

-- World island `index` (1 = first world).
function WorldMap.build(world: any, index: number): Layout
	return buildIsland(plan.worldIsland(index), world, index, `World{index}_{world.id}`)
end

-- Event island `slot` (GameConfig.eventWorlds[slot], #77) beside the spawn island: same
-- floor plan as a world, no bridge and no gate (the portal leads there while the event
-- runs). Prepared only: the event update wires toppings, oven and portal to it.
function WorldMap.buildEvent(world: any, slot: number): Layout
	local layout = buildIsland(plan.eventIsland(slot), world, 0, `Event{slot}_{world.id}`)
	layout.folder:SetAttribute("EventWorldId", world.id)
	return layout
end

-- Builds every event island of the config (none in this update) when the feature
-- "eventWorlds" is on.
function WorldMap.buildEvents(): { Layout }
	local layouts = {}
	if Features.new(GameConfig.features).enabled("eventWorlds") then
		for slot, world in GameConfig.eventWorlds do
			table.insert(layouts, WorldMap.buildEvent(world, slot))
		end
	end
	return layouts
end

-- Index of the event island containing the position, or nil (#77).
function WorldMap.eventIndexAt(position: Vector3): number?
	return plan.eventIndexAt(position.X, position.Z)
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
-- panel, filled by LeaderboardService), the marketplace deco (#106), anchors for the
-- reserved spots, the trees and the rim. The portal gate is built by PortalService,
-- the update board and countdown texts by SpawnMarketService.

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
			SignText.set(label, "board.loadingTitled", {
				title = { key = if board then `board.{board.id}` else "board.fallbackTitle" },
			})
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

	buildAnchors(island, folder)
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
