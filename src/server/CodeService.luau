--!strict
-- Codes (#99, feature "codes"). The settings menu (#76) sends RedeemCode(code); the rules
-- (rules.redeemCode, GameConfig.codes) decide, the result is stored via PlayerStates.set
-- and answered with CodeResult(ok, reason?, rewards?). The client shows `codes.<reason>`.
-- At most MAX_TRIES attempts per player within WINDOW seconds (guessing codes);
-- further attempts get the reason "TooManyTries".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerStates = require(script.Parent.PlayerStates)

local MAX_TRIES = 5
local WINDOW = 60

local CodeService = {}

function CodeService.start()
	local features = Features.new(GameConfig.features)
	local rules = PlayerStates.rules
	local tries: { [Player]: { number } } = {}
	local result = Net.event("CodeResult")

	Players.PlayerRemoving:Connect(function(player)
		tries[player] = nil
	end)

	Net.event("RedeemCode").OnServerEvent:Connect(features.guard("codes", function(player: Player, code: any)
		local now = os.time()
		local recent = {}
		for _, at in tries[player] or {} do
			if now - at < WINDOW then
				table.insert(recent, at)
			end
		end
		tries[player] = recent
		if #recent >= MAX_TRIES then
			result:FireClient(player, false, "TooManyTries")
			return
		end
		table.insert(recent, now)

		local state = PlayerStates.get(player)
		if state == nil then
			return
		end
		local redeemed = rules.redeemCode(state, code, now, math.random)
		if not redeemed.ok then
			result:FireClient(player, false, redeemed.reason)
			return
		end
		PlayerStates.set(player, redeemed.state)
		result:FireClient(player, true, nil, redeemed.rewards)
	end))
end

return CodeService
