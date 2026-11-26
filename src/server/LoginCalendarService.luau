--!strict
-- Login calendar (30 days, #101; 7 while features.loginCalendar30 is off; new day at
-- midnight German time; day 30 adds the calendar pet to the inventory via the rules):
-- * On the first join of a German day the calendar opens by itself: once the player's
--   state is loaded, rules.markLoginCalendarShown decides (remembered in the PlayerState,
--   so rejoining the same day does not open it again) and the LoginCalendarAutoOpen
--   attribute is set to today's day number; the client opens the window when it sees it.
-- * Claiming: the client wishes ClaimLoginReward; the rules decide (once per German day,
--   series, rewards) and the answer goes back as LoginRewardResult. The claim day lives in
--   the saved PlayerState and the session lock (SaveService) lets only one server hold it,
--   so a reward cannot be claimed twice across servers.
-- * Replication: LoginCalendar attribute (JSON, see Net), refreshed on every state change
--   and every few seconds, so a new day shows up without rejoining.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerStates = require(script.Parent.PlayerStates)

type PlayerState = GameRules.PlayerState

local REFRESH_SECONDS = 15

local LoginCalendarService = {}

local function replicate(player: Player, state: PlayerState)
	local calendar = PlayerStates.rules.loginCalendar(state, os.time())
	local days = {}
	for _, day in calendar.days do
		table.insert(days, { day = day.day, status = day.status, big = day.big, rewards = day.rewards })
	end
	player:SetAttribute(
		"LoginCalendar",
		HttpService:JSONEncode({ today = calendar.today, claimable = calendar.claimable, days = days })
	)
end

function LoginCalendarService.start()
	local rules = PlayerStates.rules
	local resultEvent = Net.event("LoginRewardResult")
	local random = Random.new()
	local function draw(): number
		return random:NextNumber()
	end
	-- Players whose join was already checked for the automatic opening.
	local joinChecked: { [Player]: boolean } = {}

	local function checkJoin(player: Player, state: PlayerState)
		if joinChecked[player] then
			return
		end
		joinChecked[player] = true
		local now = os.time()
		local result = rules.markLoginCalendarShown(state, now)
		if result.ok then
			PlayerStates.set(player, result.state)
			player:SetAttribute("LoginCalendarAutoOpen", rules.dayNumber(now))
		end
	end

	PlayerStates.onChanged(function(player, state)
		if player.Parent == nil then
			return
		end
		replicate(player, state)
		checkJoin(player, state)
	end)
	for _, player in Players:GetPlayers() do
		local state = PlayerStates.get(player)
		if state then
			replicate(player, state)
			checkJoin(player, state)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		joinChecked[player] = nil
	end)

	Net.event("ClaimLoginReward").OnServerEvent:Connect(function(player: Player)
		local state = PlayerStates.get(player)
		if state == nil then
			return
		end
		local result = rules.claimLoginReward(state, os.time(), draw)
		if result.ok then
			PlayerStates.set(player, result.state)
			resultEvent:FireClient(player, true, result.day, result.rewards)
		else
			resultEvent:FireClient(player, false, result.reason, {})
		end
	end)

	-- A new German day makes the next calendar day claimable without a state change.
	task.spawn(function()
		while true do
			task.wait(REFRESH_SECONDS)
			for _, player in Players:GetPlayers() do
				local state = PlayerStates.get(player)
				if state then
					replicate(player, state)
				end
			end
		end
	end)
end

return LoginCalendarService
