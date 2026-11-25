--!strict
-- Admin panel on the server (#74, feature "adminPanel"). The client sends AdminRun
-- (actionId, args); this service checks the sender's user id (GameConfig.admin.userIds)
-- and every argument via Shared.AdminActions and applies the result through
-- PlayerStates.set. Requests from anyone else are refused (and logged), whatever the
-- client claims. Answers the admin with AdminResult (actionId, ok, reason?).
-- New admin actions are entries in AdminActions.BUILT_IN, nothing to add here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminActions = require(ReplicatedStorage.Shared.AdminActions)
local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerStates = require(script.Parent.PlayerStates)
local WorldMap = require(script.Parent.WorldMap)

-- Ignore requests faster than this (held-down key, double taps).
local COOLDOWN_SECONDS = 0.25

local AdminService = {}

function AdminService.start()
	local features = Features.new(GameConfig.features)
	local admin = AdminActions.new(PlayerStates.rules, GameConfig, features)
	local adminResult = Net.event("AdminResult")
	local lastRequest: { [Player]: number } = {}
	local random = Random.new()

	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)

	Net.event("AdminRun").OnServerEvent
		:Connect(features.guard("adminPanel", function(player: Player, actionId: any, args: any)
			if not admin.isAdmin(player.UserId) then
				warn(`[Admin] Abgelehnt: {player.Name} ({player.UserId}) ist kein Admin`)
				return
			end
			local now = os.clock()
			if now - (lastRequest[player] or -math.huge) < COOLDOWN_SECONDS then
				return
			end
			lastRequest[player] = now
			local state = PlayerStates.get(player)
			if state == nil then
				return
			end
			local result = admin.run(player.UserId, state, actionId, args, {
				now = os.time(),
				random = function()
					return random:NextNumber()
				end,
			})
			local shownId = if type(actionId) == "string" then actionId else "?"
			if result.ok then
				PlayerStates.set(player, result.state)
				print(`[Admin] {player.Name}: {shownId} ok`)
				if actionId == "resetProgress" then
					-- Fresh start: back to the spawn of world 1 like a new player.
					local character = player.Character
					if character then
						character:PivotTo(WorldMap.spawnPointOf(1))
					end
				end
			end
			adminResult:FireClient(player, shownId, result.ok, result.reason)
		end))
end

return AdminService
