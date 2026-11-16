--!strict
-- Click (PC) or tap (phone) a topping to ask the server to collect it.
-- The client only sends the wish; the server checks range and pizza space.
-- Taps are forgiving: the topping closest to the finger within TAP_RADIUS pixels counts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)

local TAP_RADIUS = 60
local MAX_PICK_DISTANCE = 80 -- studs from the camera; the server checks the real range

local ToppingInput = {}

-- Every world folder in the Workspace has its own "Toppings" folder.
local function allToppings(): { Instance }
	local parts = {}
	for _, child in Workspace:GetChildren() do
		local toppings = child:FindFirstChild("Toppings")
		if toppings and child:IsA("Folder") then
			table.move(toppings:GetChildren(), 1, #toppings:GetChildren(), #parts + 1, parts)
		end
	end
	return parts
end

local function pickTopping(screenPosition: Vector2): BasePart?
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil
	end

	local best: BasePart? = nil
	local bestDistance = TAP_RADIUS
	for _, part in allToppings() do
		if part:IsA("BasePart") then
			local point, onScreen = camera:WorldToScreenPoint(part.Position)
			local cameraDistance = (part.Position - camera.CFrame.Position).Magnitude
			if onScreen and cameraDistance <= MAX_PICK_DISTANCE then
				local distance = (Vector2.new(point.X, point.Y) - screenPosition).Magnitude
				if distance < bestDistance then
					best = part
					bestDistance = distance
				end
			end
		end
	end
	return best
end

function ToppingInput.start()
	local collect = Net.event("CollectTopping")

	local function tryCollectAt(screenPosition: Vector2)
		local part = pickTopping(screenPosition)
		local slotId = part and part:GetAttribute("SlotId")
		local worldId = part and part:GetAttribute("WorldId")
		if typeof(slotId) == "number" and typeof(worldId) == "string" then
			collect:FireServer(slotId, worldId)
		end
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		tryCollectAt(Vector2.new(input.Position.X, input.Position.Y))
	end)

	UserInputService.TouchTapInWorld:Connect(function(position, processed)
		if not processed then
			tryCollectAt(position)
		end
	end)
end

return ToppingInput
