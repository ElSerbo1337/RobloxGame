--!strict
-- Global announcement when someone hatches a Secret pet (#81). EggService calls
-- `secretHatched`; this server shows it at once (RemoteEvent "SecretAnnounce" to all
-- players) and publishes it to all other servers via MessagingService. Every server
-- subscribes, checks incoming data (SecretAnnounce.parse) and skips its own messages.
-- Publishing is throttled per server (GameConfig.secretPets.announceMax per
-- announceWindowSeconds); a throttled or failed publish is still shown on this server.
-- Feature switch: secretAnnouncement (off = only the hatching player's own animation).

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local SecretAnnounce = require(ReplicatedStorage.Shared.SecretAnnounce)

local features = Features.new(GameConfig.features)

local AnnounceService = {}

local announce: RemoteEvent? = nil
local throttle = SecretAnnounce.throttle(GameConfig.secretPets.announceMax, GameConfig.secretPets.announceWindowSeconds)

local function show(name: string, petId: string)
	if announce then
		announce:FireAllClients(name, petId)
	end
end

-- Someone on this server hatched the Secret pet `petId`.
function AnnounceService.secretHatched(player: Player, petId: string)
	if announce == nil then
		return
	end
	local message = SecretAnnounce.message(player.DisplayName, petId, game.JobId)
	show(message.name, message.petId)
	if not throttle.allow(os.clock()) then
		warn("[AnnounceService] Secret announcement throttled, shown on this server only")
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:PublishAsync(SecretAnnounce.TOPIC, message)
		end)
		if not ok then
			warn(`[AnnounceService] publish failed: {err}`)
		end
	end)
end

function AnnounceService.start()
	if not features.enabled("secretAnnouncement") then
		return
	end
	announce = Net.event("SecretAnnounce")
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(SecretAnnounce.TOPIC, function(received)
				local message = SecretAnnounce.parse(received.Data, GameConfig)
				-- This server showed its own announcement already.
				if message == nil or message.jobId == game.JobId then
					return
				end
				if #Players:GetPlayers() > 0 then
					show(message.name, message.petId)
				end
			end)
		end)
		if not ok then
			warn(`[AnnounceService] subscribe failed (other servers' announcements stay hidden): {err}`)
		end
	end)
end

return AnnounceService
