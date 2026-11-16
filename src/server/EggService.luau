--!strict
-- Eggs in the world: puts a placeholder egg on each egg stand and opens eggs on request.
-- The client only asks ("OpenEgg"); the server checks the distance and lets the game
-- rules decide (price, chances, "3 öffnen" bought). The drawn pets are sent back for the
-- hatch animation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerStates = require(script.Parent.PlayerStates)

export type EggSpot = {
	eggId: string,
	-- Cylinder stand lying on its side (height along X, as WorldMap and buildStand make them).
	stand: BasePart,
}

-- Players must stand this close to the egg to open it (preview shows up a bit earlier).
local OPEN_DISTANCE = 18
-- One egg per this many seconds per player, so the hatch animation can finish.
local OPEN_COOLDOWN = 2.5

local EggService = {}

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

-- Round egg stand for world 1 (later worlds get theirs from WorldMap).
function EggService.buildStand(parent: Instance, ground: Vector3): BasePart
	return part({
		Name = "EggStand",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.5, 10, 10),
		CFrame = CFrame.new(ground + Vector3.new(0, 0.75, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(240, 200, 120),
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

-- Placeholder egg: big cream egg with orange spots, standing on `ground`.
local function buildEgg(eggId: string, ground: Vector3, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = eggId
	model:SetAttribute("EggId", eggId)

	local body = part({
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(5.5, 5.5, 5.5),
		Position = ground + Vector3.new(0, 3.6, 0),
		Color = Color3.fromRGB(255, 245, 220),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	-- Stretch the ball into an egg shape.
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 1.3, 1)
	mesh.Parent = body

	for i, offset in { Vector3.new(1.6, 1, 2), Vector3.new(-2.2, -0.6, 1.2), Vector3.new(0.4, 2.4, -2.2) } do
		part({
			Name = `Spot{i}`,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.4, 1.4, 1.4),
			Position = body.Position + offset * 0.95,
			Color = Color3.fromRGB(245, 140, 50),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			Parent = model,
		})
	end

	model.PrimaryPart = body
	model.Parent = parent
	return model
end

function EggService.start(spots: { EggSpot })
	local folder = Instance.new("Folder")
	folder.Name = "Eggs"
	local eggs: { [string]: Model } = {}
	for _, spot in spots do
		if GameConfig.eggs[spot.eggId] == nil then
			warn(`[EggService] unknown egg "{spot.eggId}"`)
			continue
		end
		local top = spot.stand.Position + Vector3.new(0, spot.stand.Size.X / 2, 0)
		eggs[spot.eggId] = buildEgg(spot.eggId, top, folder)
	end
	folder.Parent = Workspace

	local notify = Net.event("Notify")
	local eggOpened = Net.event("EggOpened")
	local rng = Random.new()
	local lastOpen: { [Player]: number } = {}

	Net.event("OpenEgg").OnServerEvent:Connect(function(player: Player, eggId: unknown, count: unknown)
		if type(eggId) ~= "string" or eggs[eggId] == nil then
			return
		end
		-- Missing count = 1 egg; the rules reject anything but 1 or the unlocked multi-open size.
		local eggCount = if count == nil then 1 else count
		if type(eggCount) ~= "number" then
			return
		end
		local now = os.clock()
		if lastOpen[player] and now - lastOpen[player] < OPEN_COOLDOWN then
			return
		end
		local state = PlayerStates.get(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if state == nil or root == nil then
			return
		end
		local egg = eggs[eggId]
		if (root.Position - egg:GetPivot().Position).Magnitude > OPEN_DISTANCE then
			notify:FireClient(player, "OutOfRange")
			return
		end

		local result = PlayerStates.rules.openEggs(state, eggId, eggCount, function()
			return rng:NextNumber()
		end)
		if not result.ok then
			notify:FireClient(player, result.reason)
			return
		end
		lastOpen[player] = now
		PlayerStates.set(player, result.state)
		local petIds = {}
		for _, pet in result.pets do
			table.insert(petIds, pet.petId)
		end
		eggOpened:FireClient(player, eggId, table.unpack(petIds))
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastOpen[player] = nil
	end)
end

return EggService
