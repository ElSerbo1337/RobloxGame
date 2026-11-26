--!strict
-- Pet index and topping index (#95) on the server:
-- * Nothing to ask for: the rules record finds themselves (addPet for pets and their
--   Gold/Rainbow/Shiny stars, collecting for toppings) and the coin bonus is part of
--   rules.coinMultiplier. This service only replicates.
-- * Replication: Index attribute (JSON GameRules.IndexStatus) on every state change.
-- * A world that just became complete: Notify("IndexComplete", worldId) for the toast.
-- Runs when features.petIndex or features.toppingIndex is on.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerStates = require(script.Parent.PlayerStates)

type PlayerState = GameRules.PlayerState

local IndexService = {}

function IndexService.start()
	local features = Features.new(GameConfig.features)
	if not features.enabled("petIndex") and not features.enabled("toppingIndex") then
		return
	end
	local rules = PlayerStates.rules
	local notify = Net.event("Notify")

	local lastJson: { [Player]: string } = {}
	-- World ids complete in the last replicated status (nil = not replicated yet, so the
	-- worlds complete on join give no toast).
	local lastComplete: { [Player]: { [string]: boolean } } = {}

	local function replicate(player: Player, state: PlayerState)
		local status = rules.indexStatus(state)
		local complete: { [string]: boolean } = {}
		for _, world in status.pets do
			if world.complete then
				complete[world.worldId] = true
			end
		end
		local before = lastComplete[player]
		lastComplete[player] = complete
		if before and status.petIndexOn then
			for _, world in status.pets do
				if world.complete and not before[world.worldId] then
					notify:FireClient(player, "IndexComplete", world.worldId)
				end
			end
		end
		local json = HttpService:JSONEncode(status)
		if lastJson[player] ~= json then
			lastJson[player] = json
			player:SetAttribute("Index", json)
		end
	end

	PlayerStates.onChanged(function(player)
		-- Listeners run deferred: read the latest state.
		local state = PlayerStates.get(player)
		if player.Parent ~= nil and state ~= nil then
			replicate(player, state)
		end
	end)
	for _, player in Players:GetPlayers() do
		local state = PlayerStates.get(player)
		if state then
			replicate(player, state)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		lastJson[player] = nil
		lastComplete[player] = nil
	end)
end

return IndexService
