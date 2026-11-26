--!strict
-- Pet index and topping index (#95) on the server. The rules record everything
-- (addPet: found pets and Gold/Rainbow/Shiny stars, collecting: normal/golden toppings)
-- and put the index bonus into rules.coinMultiplier, so this service only replicates:
-- * Index attribute (JSON { pets = rules.petIndex, toppings = rules.toppingIndex,
--   bonus = rules.indexBonus, worldBonus }) on every state change that alters it.
-- * Notify("IndexWorldComplete", worldId) when a world's pet index becomes complete.

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
	local petsOn, toppingsOn = features.enabled("petIndex"), features.enabled("toppingIndex")
	if not petsOn and not toppingsOn then
		return
	end
	local rules = PlayerStates.rules
	local notify = Net.event("Notify")

	local lastJson: { [Player]: string } = {}
	local lastComplete: { [Player]: { [string]: boolean } } = {}

	local function replicate(player: Player, state: PlayerState)
		local pets = if petsOn then rules.petIndex(state) else nil
		local payload = {
			pets = pets,
			toppings = if toppingsOn then rules.toppingIndex(state) else nil,
			bonus = rules.indexBonus(state),
			worldBonus = if GameConfig.petIndex then GameConfig.petIndex.worldBonus else 0,
		}
		local json = HttpService:JSONEncode(payload)
		if lastJson[player] == json then
			return
		end
		lastJson[player] = json
		player:SetAttribute("Index", json)

		if pets then
			local complete: { [string]: boolean } = {}
			for _, world in pets.worlds do
				complete[world.worldId] = world.complete
			end
			local before = lastComplete[player]
			lastComplete[player] = complete
			if before then
				for worldId, done in complete do
					if done and not before[worldId] then
						notify:FireClient(player, "IndexWorldComplete", worldId)
					end
				end
			end
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
