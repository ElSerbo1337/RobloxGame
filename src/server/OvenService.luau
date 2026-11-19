--!strict
-- Sells a player's whole pizza as soon as they stand in the oven's sell zone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local PlayerStates = require(script.Parent.PlayerStates)

local CHECK_SECONDS = 0.2

local OvenService = {}

local function isInside(zone: BasePart, position: Vector3): boolean
	local relative = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z
end

function OvenService.start(worldId: string, sellZone: BasePart)
	local notify = Net.event("Notify")

	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for _, player in Players:GetPlayers() do
				local state = PlayerStates.get(player)
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if state and root and #state.pizza > 0 and isInside(sellZone, root.Position) then
					local result = PlayerStates.rules.sellPizza(state, worldId)
					if result.ok then
						PlayerStates.set(player, result.state)
						notify:FireClient(player, "Sold", result.coinsEarned)
					end
				end
			end
		end
	end)
end

return OvenService
