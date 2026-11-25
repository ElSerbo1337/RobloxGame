--!strict
-- Teleport portals: every world in GameConfig.worlds gets one portal, so new worlds
-- get theirs without code changes. Walking into a portal opens the world menu on the
-- client, walking out closes it. The client only sends the wished target; the server
-- checks that the player stands in a portal and lets the game rules decide.
-- The side bar tile "Worlds" (#75) asks for the same list from anywhere (PortalPreview);
-- it is for viewing only, travelling still needs a portal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerStates = require(script.Parent.PlayerStates)
local SignText = require(script.Parent.SignText)
local SpawnService = require(script.Parent.SpawnService)
local WorldMap = require(script.Parent.WorldMap)

local CHECK_SECONDS = 0.2
local TELEPORT_COOLDOWN = 1
local PREVIEW_COOLDOWN = 0.5
-- Viewing-only list (#78): at most one update per this many seconds while it is open.
local PREVIEW_REFRESH = 1
local features = Features.new(GameConfig.features)
-- The spawn island's portal gate has no world of its own.
local SPAWN_PORTAL_ID = "SpawnIsland"
local RING_SIZE = 12
-- Width of the stone arch model (#28) = width of the placeholder base.
local ARCH_MODEL_WIDTH = RING_SIZE + 4
-- Arrival in front of the portal (−Z), outside its zone so the menu does not pop up again.
local ARRIVAL_OFFSET = Vector3.new(0, 3, -12)

export type Portal = { worldId: string, zone: BasePart, arrival: CFrame }

local PortalService = {}

local function isInside(zone: BasePart, position: Vector3): boolean
	local relative = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z
end

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

-- Portal facing −Z: the round stone arch model with a glowing face in the world's
-- colour or, until it is imported, a ring of blocks around a glowing disk.
-- `yaw` turns the whole portal around its ground point (island worlds face the path, #27).
function PortalService.build(parent: Instance, world: any, groundPosition: Vector3, yaw: number?): Portal
	local model = Instance.new("Model")
	model.Name = `Portal_{world.id}`

	local center = groundPosition + Vector3.new(0, RING_SIZE / 2 + 1, 0)
	part({
		Name = "Base",
		Size = Vector3.new(RING_SIZE + 4, 1, 6),
		Position = groundPosition + Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(90, 80, 110),
		Material = Enum.Material.Slate,
		Parent = model,
	})
	local segments = 16
	local radius = RING_SIZE / 2
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		part({
			Name = "Ring",
			Size = Vector3.new(2.6, 1.4, 1.4),
			CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius, 0))
				* CFrame.Angles(0, 0, angle + math.pi / 2),
			Color = Color3.fromRGB(150, 90, 230),
			Material = Enum.Material.Neon,
			Parent = model,
		})
	end
	local disk = part({
		Name = "Swirl",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, RING_SIZE - 1, RING_SIZE - 1),
		CFrame = CFrame.new(center) * CFrame.Angles(0, math.pi / 2, 0),
		Color = Color3.fromRGB(120, 200, 255),
		Material = Enum.Material.ForceField,
		Transparency = 0.1,
		CanCollide = false,
		CastShadow = false,
		Parent = model,
	})
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(Color3.fromRGB(200, 170, 255))
	sparkles.LightEmission = 1
	sparkles.Rate = 15
	sparkles.Lifetime = NumberRange.new(1, 2)
	sparkles.Speed = NumberRange.new(1, 3)
	sparkles.Size = NumberSequence.new(0.4, 0)
	sparkles.Parent = disk

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(10, 2.5)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, RING_SIZE / 2 + 2.5, 0)
	billboard.MaxDistance = 150
	billboard.Adornee = disk
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	SignText.set(label, "sign.portal")
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(255, 240, 200)
	label.TextStrokeTransparency = 0.2
	label.Parent = billboard
	billboard.Parent = model

	-- Walk into the ring (from either side) to open the menu.
	local zone = part({
		Name = "PortalZone",
		Size = Vector3.new(RING_SIZE, RING_SIZE, 8),
		Position = center,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = model,
	})

	local look = ModelLibrary.dressPlaceholder(
		model,
		"PortalArch",
		ARCH_MODEL_WIDTH,
		CFrame.new(groundPosition),
		{ "Base", "Ring", "Swirl" }
	)
	if look and world.color then
		local color = Color3.fromRGB(world.color[1], world.color[2], world.color[3])
		for _, descendant in look:GetDescendants() do
			if descendant:IsA("BasePart") and string.match(descendant.Name, "^PortalGlow") then
				descendant.Color = color
			end
		end
		sparkles.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.5))
	end

	local base = CFrame.new(groundPosition) * CFrame.Angles(0, yaw or 0, 0)
	model.WorldPivot = CFrame.new(groundPosition)
	model:PivotTo(base)
	model.Parent = parent
	-- Arrival in front of the portal, looking away from it.
	return {
		worldId = world.id,
		zone = zone,
		arrival = base * CFrame.new(ARRIVAL_OFFSET),
	}
end

-- One portal per configured world on its station spot (WorldMap), plus the portal gate
-- on the spawn island (#27; it belongs to no world, so no menu entry counts as "here").
function PortalService.buildAll(): { Portal }
	local folder = Instance.new("Folder")
	folder.Name = "Portals"
	folder.Parent = Workspace
	local portals = {}
	for index, world in GameConfig.worlds do
		local spot = WorldMap.station(index, "Portal") :: CFrame
		local _, yaw = spot:ToEulerAnglesYXZ()
		table.insert(portals, PortalService.build(folder, world, spot.Position, yaw))
	end
	local spawnSpot = WorldMap.spawnStation("Portal")
	local _, spawnYaw = spawnSpot:ToEulerAnglesYXZ()
	local spawnWorld = { id = SPAWN_PORTAL_ID, color = GameConfig.worlds[1].color }
	table.insert(portals, PortalService.build(folder, spawnWorld, spawnSpot.Position, spawnYaw))
	return portals
end

function PortalService.start(portals: { Portal })
	local portalOpen = Net.event("PortalOpen")
	local portalClose = Net.event("PortalClose")
	local notify = Net.event("Notify")

	local byWorld: { [string]: Portal } = {}
	for _, portal in portals do
		byWorld[portal.worldId] = portal
	end

	-- Portal (its world id) each player is currently standing in.
	local insidePortal: { [Player]: string } = {}
	local lastTeleport: { [Player]: number } = {}

	Net.event("Teleport").OnServerEvent:Connect(function(player: Player, worldId: unknown)
		if typeof(worldId) ~= "string" then
			return
		end
		local state = PlayerStates.get(player)
		local character = player.Character
		local target = byWorld[worldId]
		if state == nil or character == nil or target == nil or insidePortal[player] == nil then
			return -- only teleport while standing in a portal
		end
		local now = os.clock()
		if now - (lastTeleport[player] or 0) < TELEPORT_COOLDOWN then
			return
		end
		local result = PlayerStates.rules.teleport(state, worldId)
		if not result.ok then
			notify:FireClient(player, result.reason)
			return
		end
		lastTeleport[player] = now
		insidePortal[player] = nil
		portalClose:FireClient(player)
		character:PivotTo(target.arrival)
		-- Respawn in the world the portal sent the player to.
		SpawnService.enterWorld(player, worldId)
	end)

	-- World list for viewing from anywhere (side bar tile "Worlds", #75). Teleporting
	-- still needs the player to stand in a portal (see Teleport above).
	-- PortalPreview(true / nothing) opens it; while open the list stays current (#78:
	-- missing coins on the world cards), throttled to PREVIEW_REFRESH. PortalPreview(false)
	-- = the player closed it.
	local lastPreview: { [Player]: number } = {}
	local previewers: { [Player]: boolean } = {}
	local refreshPending: { [Player]: boolean } = {}
	local rules = PlayerStates.rules

	local function sendPreview(player: Player)
		local state = PlayerStates.get(player)
		if state == nil or insidePortal[player] ~= nil then
			return
		end
		local currentWorld = rules.spawnWorld(state) or GameConfig.worlds[1].id
		portalOpen:FireClient(player, currentWorld, rules.portalMenu(state), true)
	end

	Net.event("PortalPreview").OnServerEvent:Connect(features.guard("sideBar", function(player: Player, open: unknown)
		if open == false then
			previewers[player] = nil
			return
		end
		local state = PlayerStates.get(player)
		local now = os.clock()
		if state == nil or now - (lastPreview[player] or 0) < PREVIEW_COOLDOWN then
			return
		end
		lastPreview[player] = now
		local inside = insidePortal[player]
		if inside then
			portalOpen:FireClient(player, inside, rules.portalMenu(state), false)
		else
			previewers[player] = true
			sendPreview(player)
		end
	end))

	-- Keep an open menu current (e.g. a world unlocked while standing in the portal).
	PlayerStates.onChanged(function(player, state)
		local worldId = insidePortal[player]
		if worldId then
			portalOpen:FireClient(player, worldId, rules.portalMenu(state))
		elseif previewers[player] and not refreshPending[player] then
			refreshPending[player] = true
			task.delay(PREVIEW_REFRESH, function()
				refreshPending[player] = nil
				if previewers[player] then
					sendPreview(player)
				end
			end)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		insidePortal[player] = nil
		lastTeleport[player] = nil
		lastPreview[player] = nil
		previewers[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local current: string? = nil
				if root then
					for _, portal in portals do
						if isInside(portal.zone, root.Position) then
							current = portal.worldId
							break
						end
					end
				end

				local previous = insidePortal[player]
				if current ~= previous then
					if previous then
						portalClose:FireClient(player)
					end
					local state = PlayerStates.get(player)
					if current and state then
						insidePortal[player] = current
						previewers[player] = nil
						portalOpen:FireClient(player, current, PlayerStates.rules.portalMenu(state))
					else
						insidePortal[player] = nil
					end
				end
			end
		end
	end)
end

return PortalService
