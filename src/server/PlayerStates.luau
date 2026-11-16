--!strict
-- Owns every player's PlayerState on the server. State only changes through
-- results of the game rules; each change is replicated to the client as attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameRules = require(ReplicatedStorage.Shared.GameRules)

type PlayerState = GameRules.PlayerState

local PlayerStates = {}

PlayerStates.rules = GameRules.new(GameConfig)

local states: { [Player]: PlayerState } = {}
local listeners: { (Player, PlayerState) -> () } = {}

local function replicate(player: Player, state: PlayerState)
	player:SetAttribute("Coins", state.coins)
	player:SetAttribute("PizzaCount", #state.pizza)
	player:SetAttribute("PizzaCapacity", PlayerStates.rules.pizzaCapacity(state))
end

function PlayerStates.get(player: Player): PlayerState?
	return states[player]
end

function PlayerStates.set(player: Player, state: PlayerState)
	if states[player] == nil then
		return -- player already left
	end
	states[player] = state
	replicate(player, state)
	for _, listener in listeners do
		task.spawn(listener, player, state)
	end
end

-- Called after every state change of a player.
function PlayerStates.onChanged(listener: (Player, PlayerState) -> ())
	table.insert(listeners, listener)
end

function PlayerStates.start()
	local function onPlayerAdded(player: Player)
		-- TODO(save): load from DataStore once saving is implemented.
		states[player] = PlayerStates.rules.newPlayerState()
		PlayerStates.set(player, states[player])
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return PlayerStates
