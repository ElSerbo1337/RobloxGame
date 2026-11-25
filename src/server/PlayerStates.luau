--!strict
-- Owns every player's PlayerState on the server. State only changes through
-- results of the game rules; each change is replicated to the client as attributes.
-- States are loaded on join and saved on leave, periodically and on shutdown
-- (leave and shutdown release the session lock, see SaveService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local SaveService = require(script.Parent.SaveService)

type PlayerState = GameRules.PlayerState

local PlayerStates = {}

PlayerStates.rules = GameRules.new(GameConfig)

local states: { [Player]: PlayerState } = {}
local listeners: { (Player, PlayerState) -> () } = {}
local savedListeners: { (number, PlayerState) -> () } = {}

local function replicate(player: Player, state: PlayerState)
	player:SetAttribute("Coins", state.coins)
	player:SetAttribute("Gems", state.gems)
	player:SetAttribute("EggsPerOpen", PlayerStates.rules.eggsPerOpen(state))
	player:SetAttribute("PizzaCount", #state.pizza)
	player:SetAttribute("PizzaCapacity", PlayerStates.rules.pizzaCapacity(state))
	-- Golden toppings (#94): the player's chance (client glitters field toppings whose
	-- GoldRoll is below it) and how many golden toppings are on the pizza.
	player:SetAttribute("GoldenChance", PlayerStates.rules.goldenChance(state))
	player:SetAttribute("PizzaGolden", PlayerStates.rules.goldenCount(state))
	player:SetAttribute("AutoCollect", state.autoCollect == true)
	player:SetAttribute("UnlockedWorlds", table.concat(state.unlockedWorlds, ","))
	player:SetAttribute("LastWorldId", state.lastWorldId)
	local tutorial = PlayerStates.rules.tutorial(state)
	player:SetAttribute("TutorialStep", if tutorial then tutorial.step else "")
	player:SetAttribute("TutorialNumber", if tutorial then tutorial.number else 0)
	player:SetAttribute("TutorialTotal", if tutorial then tutorial.total else 0)
	player:SetAttribute("TutorialProgress", if tutorial then tutorial.progress else 0)
	player:SetAttribute("TutorialGoal", if tutorial then tutorial.goal else 0)
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

-- Called (may yield) after a player's state was written to the save, with the user id
-- and the written state: periodic saves, leave and shutdown. Never for states that
-- were not written (load failed, save taken over by another server).
function PlayerStates.onSaved(listener: (number, PlayerState) -> ())
	table.insert(savedListeners, listener)
end

local AUTOSAVE_SECONDS = GameConfig.save.autosaveSeconds

-- Saves and, if written, runs the onSaved listeners (one after another, so the
-- caller can wait for all of them, e.g. on shutdown). Listener errors are contained.
local function saveAndNotify(userId: number, state: PlayerState, release: boolean?)
	if not SaveService.save(userId, state, release) then
		return
	end
	for _, listener in savedListeners do
		local ok, err = pcall(listener, userId, state)
		if not ok then
			warn(`[Save] Nach-Speichern für Spieler {userId} fehlgeschlagen: {err}`)
		end
	end
end

-- Saves still running for players who left; shutdown waits for them.
local pendingLeaveSaves = 0

function PlayerStates.start()
	local function onPlayerAdded(player: Player)
		local state = SaveService.load(player, PlayerStates.rules.newPlayerState())
		if player.Parent == nil then
			-- Left while loading: release the session lock right away.
			SaveService.save(player.UserId, state, true)
			SaveService.forget(player.UserId)
			return
		end
		states[player] = state
		PlayerStates.set(player, state)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local state = states[player]
		states[player] = nil
		if state == nil then
			return
		end
		pendingLeaveSaves += 1
		saveAndNotify(player.UserId, state, true)
		SaveService.forget(player.UserId)
		pendingLeaveSaves -= 1
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player, state in states do
				task.spawn(saveAndNotify, player.UserId, state)
			end
		end
	end)

	game:BindToClose(function()
		local running = 0
		for player, state in states do
			running += 1
			task.spawn(function()
				saveAndNotify(player.UserId, state, true)
				running -= 1
			end)
		end
		while running > 0 or pendingLeaveSaves > 0 do
			task.wait()
		end
	end)
end

return PlayerStates
