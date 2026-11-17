--!strict
-- Gem perks that live outside the shop:
-- * Walk speed: the humanoid's WalkSpeed follows rules.walkSpeed (gem upgrade times the
--   speed potion), re-applied on every state change, so it also drops when the potion ends.
-- (Play time no longer pays gems; play time gifts live in GiftService.)

local Players = game:GetService("Players")

local PlayerStates = require(script.Parent.PlayerStates)

local GemService = {}

local function applyWalkSpeed(player: Player)
	local state = PlayerStates.get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if state and humanoid then
		local speed = PlayerStates.rules.walkSpeed(state)
		if humanoid.WalkSpeed ~= speed then
			humanoid.WalkSpeed = speed
		end
	end
end

function GemService.start()
	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			applyWalkSpeed(player)
		end)
		if player.Character then
			applyWalkSpeed(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	PlayerStates.onChanged(function(player)
		applyWalkSpeed(player)
	end)
end

return GemService
