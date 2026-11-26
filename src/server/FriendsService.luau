--!strict
-- Friends bonus (#102) on the server: counts each player's friends on this server with
-- Player:IsFriendsWith (cached per pair, the call yields and can fail) on every join and
-- leave, and writes the count with rules.setFriendsOnServer. The bonus itself lives in
-- rules.friendsBonus inside rules.coinMultiplier, so selling/delivery need no change.
-- Replicates the attributes Friends (counted friends, admin simulation included) and
-- FriendsBonus (share, e.g. 0.2) for the HUD pill top right.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local PlayerStates = require(script.Parent.PlayerStates)

local FriendsService = {}

function FriendsService.start()
	local features = Features.new(GameConfig.features)
	if not features.enabled("friendsBonus") then
		return
	end
	local rules = PlayerStates.rules

	-- "smallerId:biggerId" -> friends? Only successful answers are cached.
	local cache: { [string]: boolean } = {}
	-- Counted friends per player; nil until the first count after joining.
	local counts: { [Player]: number } = {}
	-- Players inside PlayerRemoving are still in GetPlayers(): never count them.
	local leaving: { [Player]: boolean } = {}

	local function areFriends(a: Player, b: Player): boolean
		local low, high = math.min(a.UserId, b.UserId), math.max(a.UserId, b.UserId)
		local key = `{low}:{high}`
		local known = cache[key]
		if known ~= nil then
			return known
		end
		local ok, result = pcall(function()
			return a:IsFriendsWith(b.UserId)
		end)
		if not ok then
			return false -- try again on the next join/leave
		end
		cache[key] = result == true
		return result == true
	end

	-- Brings the saved count in line with the counted one (also right after loading).
	local function apply(player: Player)
		local count = counts[player]
		local state = PlayerStates.get(player)
		if count == nil or state == nil or player.Parent == nil then
			return
		end
		if state.friendsOnServer ~= count then
			local result = rules.setFriendsOnServer(state, count)
			if result.ok then
				PlayerStates.set(player, result.state)
				return -- set() runs onChanged, which replicates
			end
		end
		player:SetAttribute("Friends", rules.friendsCount(state))
		player:SetAttribute("FriendsBonus", rules.friendsBonus(state))
	end

	-- Recounts everyone; joins/leaves while a count runs trigger one more pass.
	local running, again = false, false
	local function recount()
		if running then
			again = true
			return
		end
		running = true
		repeat
			again = false
			local players = {}
			for _, player in Players:GetPlayers() do
				if not leaving[player] then
					table.insert(players, player)
				end
			end
			for _, player in players do
				local count = 0
				for _, other in players do
					if other ~= player and not leaving[other] and areFriends(player, other) then
						count += 1
					end
				end
				if not leaving[player] then
					counts[player] = count
					apply(player)
				end
			end
		until not again
		running = false
	end

	PlayerStates.onChanged(function(player)
		if not leaving[player] then
			apply(player)
		end
	end)
	Players.PlayerAdded:Connect(function()
		task.spawn(recount)
	end)
	Players.PlayerRemoving:Connect(function(player)
		counts[player] = nil
		leaving[player] = true
		task.spawn(recount)
		task.delay(5, function()
			leaving[player] = nil
		end)
	end)
	task.spawn(recount)
end

return FriendsService
