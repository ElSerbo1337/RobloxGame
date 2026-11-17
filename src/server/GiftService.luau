--!strict
-- Play time and play time gifts:
-- * Play time: every PLAYTIME_TICK seconds each player gets the elapsed time credited
--   (rules.addPlayTime with os.time(): day's play time, starting over at midnight German
--   time, and total play time).
-- * Gifts: the client wishes ClaimGift(index); the rules decide (reached today, not yet
--   claimed) and pay the rewards. The answer goes back as GiftResult.
-- * New button hints: HintSeen(hintId) from the client, remembered in the PlayerState.
-- * Replication: Gifts (JSON, see Net) and SeenHints (comma-separated) attributes.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerStates = require(script.Parent.PlayerStates)

type PlayerState = GameRules.PlayerState

local PLAYTIME_TICK = 10

local GiftService = {}

local function replicate(player: Player, state: PlayerState)
	local status = PlayerStates.rules.giftStatus(state, os.time())
	local gifts = {}
	for _, gift in status.gifts do
		table.insert(gifts, {
			minutes = gift.minutes,
			status = gift.status,
			secondsLeft = gift.secondsLeft,
			rewards = gift.rewards,
		})
	end
	player:SetAttribute(
		"Gifts",
		HttpService:JSONEncode({ ready = status.readyCount, nextSeconds = status.nextSeconds or -1, gifts = gifts })
	)
	player:SetAttribute("SeenHints", table.concat(state.seenHints, ","))
end

function GiftService.start()
	local rules = PlayerStates.rules
	local giftResult = Net.event("GiftResult")
	local random = Random.new()
	local function draw(): number
		return random:NextNumber()
	end
	-- When each player's play time was last credited (os.clock()).
	local lastCredit: { [Player]: number } = {}

	PlayerStates.onChanged(replicate)
	local function onPlayerAdded(player: Player)
		lastCredit[player] = os.clock()
		local state = PlayerStates.get(player)
		if state then
			replicate(player, state)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastCredit[player] = nil
	end)

	Net.event("ClaimGift").OnServerEvent:Connect(function(player: Player, index: unknown)
		if type(index) ~= "number" then
			return
		end
		local state = PlayerStates.get(player)
		if state == nil then
			return
		end
		local result = rules.claimGift(state, index, os.time(), draw)
		if result.ok then
			PlayerStates.set(player, result.state)
			giftResult:FireClient(player, true, index, result.rewards)
		else
			giftResult:FireClient(player, false, result.reason, {})
		end
	end)

	Net.event("HintSeen").OnServerEvent:Connect(function(player: Player, hintId: unknown)
		if type(hintId) ~= "string" then
			return
		end
		local state = PlayerStates.get(player)
		if state == nil then
			return
		end
		local result = rules.markHintSeen(state, hintId)
		if result.ok then
			PlayerStates.set(player, result.state)
		end
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
				local result = rules.addPlayTime(state, now - since, os.time())
				if result.ok then
					PlayerStates.set(player, result.state)
				end
			end
		end
	end)
end

return GiftService
