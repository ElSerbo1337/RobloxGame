--!strict
-- Settings menu on the server (#76, feature "settings"). The client sends SetSetting
-- (key, value); the rules validate it (GameRules.SETTINGS) and the result is stored via
-- PlayerStates.set, so it is saved with the player and survives a rejoin. The saved
-- choices are replicated as the attribute Settings (JSON, only changed keys); the client
-- fills in the defaults itself (phones start on "Low" graphics).
-- RedeemCode is NOT handled here: the code rules and their handler come with #99.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerStates = require(script.Parent.PlayerStates)

-- At most this many changes per player and second (the client sends a slider only on
-- release; "reset" style buttons may send a few at once).
local MAX_PER_SECOND = 12

type PlayerState = GameRules.PlayerState

local SettingsService = {}

function SettingsService.start()
	local features = Features.new(GameConfig.features)
	local rules = PlayerStates.rules
	local budget: { [Player]: { second: number, count: number } } = {}
	local shown: { [Player]: string } = {}

	local function replicate(player: Player, state: PlayerState)
		local json = HttpService:JSONEncode(state.settings or {})
		if shown[player] ~= json then
			shown[player] = json
			player:SetAttribute("Settings", json)
		end
	end
	PlayerStates.onChanged(replicate)
	-- Players whose state was loaded before this service started.
	for _, player in Players:GetPlayers() do
		local state = PlayerStates.get(player)
		if state then
			replicate(player, state)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		budget[player] = nil
		shown[player] = nil
	end)

	Net.event("SetSetting").OnServerEvent
		:Connect(features.guard("settings", function(player: Player, key: any, value: any)
			local second = os.time()
			local used = budget[player]
			if used == nil or used.second ~= second then
				used = { second = second, count = 0 }
				budget[player] = used
			end
			if used.count >= MAX_PER_SECOND then
				return
			end
			used.count += 1
			local state = PlayerStates.get(player)
			if state == nil then
				return
			end
			local result = rules.setSetting(state, key, value)
			if result.ok then
				PlayerStates.set(player, result.state)
			end
		end))
end

return SettingsService
