--!strict
-- Lifetime stats, badges and titles (#103) on the server. The rules count everything
-- (toppings, eggs, coins, play time, rebirths, highest world) and decide badges and
-- titles; this service only:
-- * replicates the Profile attribute (JSON { stats = rules.lifetimeStats, badges = ids
--   reached, titles = ids unlocked, title = active id }) and TitleId (active title,
--   "" when titles are off) at most every UPDATE_SECONDS. Attributes replicate to every
--   client, so other players' profiles are read from them (read only).
-- * awards reached badges with a real id through Roblox BadgeService (also retroactively
--   on join), stores them in badgesAwarded and sends Notify("BadgeEarned", id). A
--   missing / 0 id is skipped; an award that fails is retried on the next join only.
-- * handles the wish SetTitle(titleId) (features.titles).
-- * ProfileService.grantWeeklyChampion(player, untilTime): interface for #109.

local BadgeService = game:GetService("BadgeService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerStates = require(script.Parent.PlayerStates)

local UPDATE_SECONDS = 2

local ProfileService = {}

local features = Features.new(GameConfig.features)

function ProfileService.grantWeeklyChampion(player: Player, untilTime: number): boolean
	local state = PlayerStates.get(player)
	if state == nil or not features.enabled("titles") then
		return false
	end
	local result = PlayerStates.rules.grantWeeklyChampion(state, untilTime)
	if result.ok then
		PlayerStates.set(player, result.state)
	end
	return result.ok
end

function ProfileService.start()
	local statsOn, badgesOn = features.enabled("stats"), features.enabled("badges")
	local titlesOn, profileOn = features.enabled("titles"), features.enabled("profile")
	if not (statsOn or badgesOn or titlesOn or profileOn) then
		return
	end
	local rules = PlayerStates.rules
	local notify = Net.event("Notify")

	local TITLE_COOLDOWN = 0.5
	local lastTitleChange: { [Player]: number } = {}
	local dirty: { [Player]: boolean } = {}
	local lastJson: { [Player]: string } = {}
	-- Badge ids tried this session (running or failed), so a failing id is not spammed.
	local tried: { [Player]: { [string]: boolean } } = {}

	local function award(player: Player, id: string, badgeId: number)
		local ok, owned = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, badgeId)
		local awarded = ok and owned == true
		if ok and not owned then
			local awardOk, result = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, badgeId)
			awarded = awardOk and result == true
			if not awardOk then
				warn(`[Badges] {id} ({badgeId}) für {player.UserId} fehlgeschlagen: {result}`)
			end
		end
		local state = PlayerStates.get(player)
		if awarded and state and player.Parent ~= nil then
			local marked = rules.markBadgeAwarded(state, id)
			if marked.ok then
				PlayerStates.set(player, marked.state)
				notify:FireClient(player, "BadgeEarned", id)
			end
		end
	end

	local function update(player: Player)
		local state = PlayerStates.get(player)
		if state == nil or player.Parent == nil then
			return
		end
		local now = os.time()
		if badgesOn then
			local seen = tried[player] or {}
			tried[player] = seen
			for _, entry in rules.badgesToAward(state) do
				if not seen[entry.id] then
					seen[entry.id] = true
					task.spawn(award, player, entry.id, entry.badgeId)
				end
			end
		end
		local active = if titlesOn then rules.activeTitle(state, now) or "" else ""
		player:SetAttribute("TitleId", active)
		local reached, unlocked = {}, {}
		if badgesOn then
			for _, badge in rules.badges(state) do
				if badge.reached then
					table.insert(reached, badge.id)
				end
			end
		end
		if titlesOn then
			for _, title in rules.titles(state, now) do
				if title.unlocked then
					table.insert(unlocked, title.id)
				end
			end
		end
		local json = HttpService:JSONEncode({
			stats = if statsOn then rules.lifetimeStats(state) else nil,
			badges = reached,
			titles = unlocked,
			title = active,
			selected = state.selectedTitle or "",
		})
		if lastJson[player] ~= json then
			lastJson[player] = json
			player:SetAttribute("Profile", json)
		end
	end

	PlayerStates.onChanged(function(player)
		dirty[player] = true
	end)
	task.spawn(function()
		while true do
			task.wait(UPDATE_SECONDS)
			for player in dirty do
				dirty[player] = nil
				update(player)
			end
			-- The Weekly Champion title runs out by time alone.
			for _, player in Players:GetPlayers() do
				local state = PlayerStates.get(player)
				if state and (state.weeklyChampionUntil or 0) > 0 and os.time() >= state.weeklyChampionUntil then
					if player:GetAttribute("TitleId") == "WeeklyChampion" then
						update(player)
					end
				end
			end
		end
	end)
	for _, player in Players:GetPlayers() do
		dirty[player] = true
	end
	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
		lastJson[player] = nil
		tried[player] = nil
		lastTitleChange[player] = nil
	end)

	if titlesOn then
		Net.event("SetTitle").OnServerEvent:Connect(function(player: Player, titleId: any)
			local state = PlayerStates.get(player)
			if state == nil or type(titleId) ~= "string" or #titleId > 64 then
				return
			end
			-- Every change replicates Profile/TitleId to all players: at most a few per second.
			local clock = os.clock()
			if lastTitleChange[player] and clock - lastTitleChange[player] < TITLE_COOLDOWN then
				return
			end
			lastTitleChange[player] = clock
			local result = rules.setTitle(state, titleId, os.time())
			if result.ok then
				PlayerStates.set(player, result.state)
			else
				notify:FireClient(player, result.reason)
			end
		end)
	end
end

return ProfileService
