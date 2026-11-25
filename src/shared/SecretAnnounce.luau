--!strict
-- Global "Secret pet hatched" announcement (#81): pure Luau without Roblox API, tested
-- in Lune (tests/SecretAnnounce.spec.luau). The server (src/server/AnnounceService.luau)
-- publishes it via MessagingService and checks every incoming message with `parse`.
--
--   local throttle = SecretAnnounce.throttle(5, 60)  -- at most 5 per 60 s per server
--   if throttle.allow(os.clock()) then publish(SecretAnnounce.message(name, petId, game.JobId)) end
--   local announcement = SecretAnnounce.parse(data, GameConfig) -- nil = ignore

export type Message = { name: string, petId: string, jobId: string }

export type Throttle = { allow: (now: number) -> boolean }

-- Longest player name that is passed on (Roblox display names have at most 20 characters).
local MAX_NAME_LENGTH = 32

local SecretAnnounce = {}

SecretAnnounce.TOPIC = "SecretPetHatched"

-- Sliding window: at most `max` announcements within any `windowSeconds`.
function SecretAnnounce.throttle(max: number, windowSeconds: number): Throttle
	local sent: { number } = {}
	return {
		allow = function(now: number): boolean
			while #sent > 0 and now - sent[1] >= windowSeconds do
				table.remove(sent, 1)
			end
			if #sent >= max then
				return false
			end
			table.insert(sent, now)
			return true
		end,
	}
end

-- The data sent to all servers: player name, pet id and the sending server (which already
-- showed it and skips its own message).
function SecretAnnounce.message(name: string, petId: string, jobId: string): Message
	return { name = string.sub(name, 1, MAX_NAME_LENGTH), petId = petId, jobId = jobId }
end

-- Checks a received message: a table with a short name and the id of a Secret pet.
-- Returns the cleaned message or nil (anything else is ignored).
function SecretAnnounce.parse(data: unknown, config: any): Message?
	if type(data) ~= "table" then
		return nil
	end
	local message = data :: any
	local name, petId, jobId = message.name, message.petId, message.jobId
	if type(name) ~= "string" or type(petId) ~= "string" or type(jobId) ~= "string" then
		return nil
	end
	if #name == 0 or #name > MAX_NAME_LENGTH then
		return nil
	end
	local pet = config.pets[petId]
	if pet == nil or pet.rarity ~= "Secret" then
		return nil
	end
	return { name = name, petId = petId, jobId = jobId }
end

return SecretAnnounce
