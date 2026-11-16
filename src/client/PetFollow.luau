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

local PetFollow = {}

-- Offset of pet `slot` of `count` relative to the owner: a row behind, centered.
local function formationOffset(slot: number, count: number): Vector3
	local x = (slot - (count + 1) / 2) * SPACING
	local z = BEHIND + math.abs(x) * 0.35
	return Vector3.new(x, 0, z)
end

function PetFollow.start()
	local petsFolder = Workspace:WaitForChild("Pets")
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	RunService.RenderStepped:Connect(function(dt: number)
		local alpha = 1 - math.exp(-FOLLOW_SPEED * dt)
		local t = os.clock()
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
				local target = flat:PointToWorldSpace(formationOffset(slot, #pets))

				-- Stand on the ground below the target spot.
				rayParams.FilterDescendantsInstances = { petsFolder, character :: Instance }
				local hit = Workspace:Raycast(target + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), rayParams)
				local groundY = if hit then hit.Position.Y else root.Position.Y - 3
				local hop = if moving then math.abs(math.sin(t * 10 + slot)) * HOP else math.sin(t * 2 + slot) * 0.15
				target = Vector3.new(target.X, groundY + HOVER + hop, target.Z)

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
