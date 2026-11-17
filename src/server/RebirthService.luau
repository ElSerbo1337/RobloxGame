--!strict
-- Rebirth (#35): the client asks with Rebirth (after its own confirmation); the rules
-- decide (rules.rebirth) and reset the run. Afterwards the character is put on the spawn
-- point of world 1 and the client plays the celebration (Rebirthed).
-- Replication: Rebirths and RebirthOffer (JSON) for the HUD button and the menu.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerStates = require(script.Parent.PlayerStates)
local WorldMap = require(script.Parent.WorldMap)

type PlayerState = GameRules.PlayerState

-- Ignore repeated requests (double taps) for this long.
local COOLDOWN_SECONDS = 2

local RebirthService = {}

local function replicate(player: Player, state: PlayerState)
	player:SetAttribute("Rebirths", state.rebirths)
	player:SetAttribute("RebirthOffer", HttpService:JSONEncode(PlayerStates.rules.rebirthOffer(state)))
end

function RebirthService.start()
	local rules = PlayerStates.rules
	local notify = Net.event("Notify")
	local rebirthed = Net.event("Rebirthed")
	local lastRequest: { [Player]: number } = {}

	PlayerStates.onChanged(replicate)
	for _, player in Players:GetPlayers() do
		local state = PlayerStates.get(player)
		if state then
			replicate(player, state)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)

	Net.event("Rebirth").OnServerEvent:Connect(function(player: Player)
		local now = os.clock()
		if now - (lastRequest[player] or -math.huge) < COOLDOWN_SECONDS then
			return
		end
		lastRequest[player] = now
		local state = PlayerStates.get(player)
		if state == nil then
			return
		end
		local result = rules.rebirth(state, os.time())
		if not result.ok then
			notify:FireClient(player, result.reason)
			return
		end
		PlayerStates.set(player, result.state)
		-- Start over at the spawn of world 1 (the rules reset the respawn world too).
		local character = player.Character
		if character then
			character:PivotTo(WorldMap.spawnPointOf(1))
		end
		rebirthed:FireClient(player, result.state.rebirths, rules.rebirthMultiplier(result.state))
	end)
end

return RebirthService
