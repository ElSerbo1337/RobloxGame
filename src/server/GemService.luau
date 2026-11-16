--!strict
-- Gem perks that live outside the shop:
-- * Play time: every PLAYTIME_TICK seconds each player gets the elapsed time credited;
--   the game rules turn every full 15 minutes into a gem (the rest is kept and saved).
-- * Walk speed: the humanoid's WalkSpeed follows rules.walkSpeed (gem upgrade times the
--   speed potion), re-applied on every state change, so it also drops when the potion ends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local PlayerStates = require(script.Parent.PlayerStates)

local PLAYTIME_TICK = 30

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
	local notify = Net.event("Notify")
	-- When each player's play time was last credited (os.clock()).
	local lastCredit: { [Player]: number } = {}

	local function onPlayerAdded(player: Player)
		lastCredit[player] = os.clock()
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
	Players.PlayerRemoving:Connect(function(player)
		lastCredit[player] = nil
	end)

	PlayerStates.onChanged(function(player)
		applyWalkSpeed(player)
	end)

	task.spawn(function()
		while true do
			task.wait(PLAYTIME_TICK)
			local now = os.clock()
			for player, since in lastCredit do
				lastCredit[player] = now
				local state = PlayerStates.get(player)
				if state == nil then
					continue -- still loading: that time is not credited
				end
				local result = PlayerStates.rules.addPlayTime(state, now - since)
				if result.ok then
					PlayerStates.set(player, result.state)
					if result.gemsEarned > 0 then
						notify:FireClient(player, "PlaytimeGems", result.gemsEarned)
					end
				end
			end
		end
	end)
end

return GemService
