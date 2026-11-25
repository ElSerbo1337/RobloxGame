--!strict
-- Daily and weekly quests (#97) on the server:
-- * New quests: rules.refreshQuests on join and every few seconds (a new German day or
--   week makes new ones without rejoining). Progress itself comes from the rule actions
--   (collecting, selling, eggs, deliveries, play time, merging, unlocking worlds), so
--   this service never counts anything.
-- * Wishes ClaimQuest / RerollQuest / ClaimQuestBonus: the rules decide, the answer goes
--   back as QuestResult. Guarded by features.dailyQuests (weekly claims additionally by
--   weeklyQuests inside the rules).
-- * Replication: Quests attribute (JSON GameRules.QuestStatus), on every state change and
--   with every refresh tick (the countdowns).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerStates = require(script.Parent.PlayerStates)

type PlayerState = GameRules.PlayerState

local REFRESH_SECONDS = 15

local QuestService = {}

function QuestService.start()
	local features = Features.new(GameConfig.features)
	if not features.enabled("dailyQuests") and not features.enabled("weeklyQuests") then
		return
	end
	local rules = PlayerStates.rules
	local resultEvent = Net.event("QuestResult")
	local random = Random.new()
	local function draw(): number
		return random:NextNumber()
	end

	local lastJson: { [Player]: string } = {}
	local function replicate(player: Player, state: PlayerState)
		local json = HttpService:JSONEncode(rules.questStatus(state, os.time()))
		if lastJson[player] ~= json then
			lastJson[player] = json
			player:SetAttribute("Quests", json)
		end
	end

	-- Makes new quests when the day/week changed; returns true if it set a new state
	-- (the onChanged listener then replicates).
	local function refresh(player: Player, state: PlayerState): boolean
		local result = rules.refreshQuests(state, os.time(), draw)
		if result.ok then
			PlayerStates.set(player, result.state)
			return true
		end
		return false
	end

	PlayerStates.onChanged(function(player)
		-- Listeners run deferred: read the latest state, never overwrite a newer one.
		local state = PlayerStates.get(player)
		if player.Parent == nil or state == nil then
			return
		end
		if not refresh(player, state) then
			replicate(player, state)
		end
	end)
	for _, player in Players:GetPlayers() do
		local state = PlayerStates.get(player)
		if state and not refresh(player, state) then
			replicate(player, state)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		lastJson[player] = nil
	end)

	local function withState(handler: (Player, PlayerState, ...any) -> ())
		return features.guard("dailyQuests", function(player: Player, ...: any)
			local state = PlayerStates.get(player)
			if state then
				handler(player, state, ...)
			end
		end)
	end

	Net.event("ClaimQuest").OnServerEvent:Connect(withState(function(player, state, period: any, index: any)
		if (period ~= "Daily" and period ~= "Weekly") or type(index) ~= "number" then
			return
		end
		local result = rules.claimQuest(state, period, index, os.time())
		if result.ok then
			PlayerStates.set(player, result.state)
			resultEvent:FireClient(player, true, "Claim", result.rewards)
		else
			resultEvent:FireClient(player, false, "Claim", result.reason)
		end
	end))

	Net.event("RerollQuest").OnServerEvent:Connect(withState(function(player, state, index: any)
		if type(index) ~= "number" then
			return
		end
		local result = rules.rerollQuest(state, index, os.time(), draw)
		if result.ok then
			PlayerStates.set(player, result.state)
			resultEvent:FireClient(player, true, "Reroll", {})
		else
			resultEvent:FireClient(player, false, "Reroll", result.reason)
		end
	end))

	Net.event("ClaimQuestBonus").OnServerEvent:Connect(withState(function(player, state)
		local result = rules.claimQuestBonus(state, os.time(), draw)
		if result.ok then
			PlayerStates.set(player, result.state)
			resultEvent:FireClient(player, true, "Bonus", result.rewards, result.streakChest)
		else
			resultEvent:FireClient(player, false, "Bonus", result.reason)
		end
	end))

	task.spawn(function()
		while true do
			task.wait(REFRESH_SECONDS)
			for _, player in Players:GetPlayers() do
				local state = PlayerStates.get(player)
				if state and not refresh(player, state) then
					replicate(player, state)
				end
			end
		end
	end)
end

return QuestService
