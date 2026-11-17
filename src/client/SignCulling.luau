--!strict
-- Owns `Enabled` of every BillboardGui in the Workspace that has a MaxDistance
-- (station signs, price signs, pet name tags, pizza counters).
--
-- Why: in the playtest, signs of far worlds (e.g. the shop sign of world 7) were
-- visible from world 1 although every one of them has `MaxDistance = 150`. The engine
-- applies MaxDistance from the camera and does not hide those signs reliably, so this
-- module hides them itself: a sign is shown only while the local character (or, without
-- one, the camera) is within the sign's own MaxDistance of its adornee.
--
-- Other client code never sets `Enabled` on these signs directly; it asks for a sign
-- to be hidden for a reason (`setHidden`), e.g. an unlocked barrier's price sign.
-- Pet name tags near an open egg preview are hidden with `setPetTagZone`.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SignCulling = {}

-- Billboard -> set of reasons it is hidden for.
local hiddenFor: { [BillboardGui]: { [string]: boolean } } = {}
local tracked: { [BillboardGui]: boolean } = {}
local petTagZone: { center: Vector3, radius: number }? = nil
local petsFolder: Instance? = nil

local function isTracked(billboard: BillboardGui): boolean
	local maxDistance = billboard.MaxDistance
	return maxDistance > 0 and maxDistance < math.huge
end

local function adorneePosition(billboard: BillboardGui): Vector3?
	local adornee = billboard.Adornee or billboard.Parent
	if adornee == nil then
		return nil
	end
	if adornee:IsA("BasePart") then
		return adornee.Position
	elseif adornee:IsA("Model") then
		return adornee:GetPivot().Position
	elseif adornee:IsA("Attachment") then
		return adornee.WorldPosition
	end
	return nil
end

local function shouldShow(billboard: BillboardGui, viewer: Vector3): boolean
	local reasons = hiddenFor[billboard]
	if reasons and next(reasons) ~= nil then
		return false
	end
	local position = adorneePosition(billboard)
	if position == nil then
		return false
	end
	if (position - viewer).Magnitude > billboard.MaxDistance then
		return false
	end
	local zone = petTagZone
	if zone and petsFolder and billboard:IsDescendantOf(petsFolder) then
		if (position - zone.center).Magnitude <= zone.radius then
			return false
		end
	end
	return true
end

-- Hides (`hidden = true`) or releases a sign for `reason`. A sign is shown only when no
-- reason hides it and it is in range.
function SignCulling.setHidden(billboard: BillboardGui, reason: string, hidden: boolean)
	local reasons = hiddenFor[billboard]
	if hidden then
		if reasons == nil then
			reasons = {}
			hiddenFor[billboard] = reasons
		end
		(reasons :: { [string]: boolean })[reason] = true
	elseif reasons then
		reasons[reason] = nil
		if next(reasons) == nil then
			hiddenFor[billboard] = nil
		end
	end
	if not tracked[billboard] then
		-- Not managed by distance (no MaxDistance): apply directly.
		billboard.Enabled = not hidden
	end
end

-- Hides all pet name tags within `radius` studs of `center` (nil = no zone).
function SignCulling.setPetTagZone(center: Vector3?, radius: number?)
	petTagZone = if center then { center = center, radius = radius or 0 } else nil
end

function SignCulling.start()
	petsFolder = Workspace:WaitForChild("Pets", 30)
	local player = Players.LocalPlayer

	local function track(instance: Instance)
		if instance:IsA("BillboardGui") and isTracked(instance) then
			tracked[instance] = true
			instance.Destroying:Connect(function()
				tracked[instance] = nil
				hiddenFor[instance] = nil
			end)
		end
	end
	for _, instance in Workspace:GetDescendants() do
		track(instance)
	end
	Workspace.DescendantAdded:Connect(track)
	Workspace.DescendantRemoving:Connect(function(instance)
		if instance:IsA("BillboardGui") then
			tracked[instance] = nil
		end
	end)

	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local camera = Workspace.CurrentCamera
		local viewer = if root then root.Position elseif camera then camera.CFrame.Position else nil
		if viewer == nil then
			return
		end
		for billboard in tracked do
			local show = shouldShow(billboard, viewer)
			if billboard.Enabled ~= show then
				billboard.Enabled = show
			end
		end
	end)
end

return SignCulling
