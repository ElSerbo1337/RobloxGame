--!strict
-- Moves every player's equipped pets (Workspace.Pets.<UserId>) behind their owner.
-- Runs on every client for all players, so movement is smooth and everyone sees
-- everyone's pets. The pet models are anchored; the server never moves them.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Distance behind the owner and spacing between pets (studs).
local BEHIND = 5
local SPACING = 3.2
-- Height above the ground the pets hover at, and how much they hop while walking.
local HOVER = 1.4
local HOP = 0.6
-- How quickly pets catch up (higher = snappier).
local FOLLOW_SPEED = 8
-- Highest step (studs above the owner's feet) a pet may stand on: anything higher
-- (oven roof, shop counter, egg stand) is not walkable ground for pets.
local MAX_STEP = 1.5
-- Distance pets keep from walls between the owner and their spot.
local WALL_GAP = 1.5
-- Height above the owner's feet of the ray that checks for walls.
local WALL_RAY_HEIGHT = 1.2

local PetFollow = {}

-- Offset of pet `slot` of `count` relative to the owner: a row behind, centered.
local function formationOffset(slot: number, count: number): Vector3
	local x = (slot - (count + 1) / 2) * SPACING
	local z = BEHIND + math.abs(x) * 0.35
	return Vector3.new(x, 0, z)
end

-- Puts a formation spot on walkable ground near the owner: never inside or behind a
-- wall (station) and never on top of something higher than a small step. Returns the
-- ground point (hover and hop are added by the caller).
local function groundTarget(spot: Vector3, root: BasePart, rayParams: RaycastParams): Vector3
	local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
	local hipHeight = if humanoid then humanoid.HipHeight else 2
	local feetY = root.Position.Y - root.Size.Y / 2 - hipHeight

	-- Walls: walk the line from the owner to the spot and stop in front of an obstacle.
	local from = Vector3.new(root.Position.X, feetY + WALL_RAY_HEIGHT, root.Position.Z)
	local to = Vector3.new(spot.X, feetY + WALL_RAY_HEIGHT, spot.Z)
	local offset = to - from
	local x, z = spot.X, spot.Z
	if offset.Magnitude > 0.01 then
		local wall = Workspace:Raycast(from, offset, rayParams)
		if wall then
			local direction = offset.Unit
			local reach = math.max((wall.Position - from).Magnitude - WALL_GAP, 0)
			local stop = from + direction * reach
			x, z = stop.X, stop.Z
		end
	end

	-- Ground: cast down from just above step height, so roofs are never hit.
	local origin = Vector3.new(x, feetY + MAX_STEP + 0.5, z)
	local hit = Workspace:Raycast(origin, Vector3.new(0, -12, 0), rayParams)
	local groundY = if hit and hit.Normal.Y > 0.6 then hit.Position.Y else feetY
	return Vector3.new(x, math.min(groundY, feetY + MAX_STEP), z)
end

function PetFollow.start()
	local petsFolder = Workspace:WaitForChild("Pets")
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	-- Only solid parts count as walls or ground (not toppings, zones or decals).
	rayParams.RespectCanCollide = true

	RunService.RenderStepped:Connect(function(dt: number)
		local alpha = 1 - math.exp(-FOLLOW_SPEED * dt)
		local t = os.clock()
		-- Pets and characters are neither walls nor ground.
		local ignore: { Instance } = { petsFolder }
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(ignore, player.Character)
			end
		end
		rayParams.FilterDescendantsInstances = ignore
		for _, ownerFolder in petsFolder:GetChildren() do
			local owner = Players:GetPlayerByUserId(tonumber(ownerFolder.Name) or 0)
			local character = owner and owner.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root == nil then
				continue
			end
			local pets = ownerFolder:GetChildren()
			local moving = root.AssemblyLinearVelocity.Magnitude > 1
			local flat = CFrame.new(root.Position) * CFrame.Angles(0, select(2, root.CFrame:ToEulerAnglesYXZ()), 0)
			for index, pet in pets do
				if not pet:IsA("Model") then
					continue
				end
				local slot = (pet:GetAttribute("Slot") :: number?) or index
				local target = groundTarget(flat:PointToWorldSpace(formationOffset(slot, #pets)), root, rayParams)
				local hop = if moving then math.abs(math.sin(t * 10 + slot)) * HOP else math.sin(t * 2 + slot) * 0.15
				target += Vector3.new(0, HOVER + hop, 0)

				local current = pet:GetPivot()
				local position = current.Position:Lerp(target, alpha)
				-- Face the walking direction of the owner.
				local look = flat.LookVector
				pet:PivotTo(CFrame.lookAt(position, position + look))
			end
		end
	end)
end

return PetFollow
