--!strict
-- Loads and stores PlayerStates in a DataStore. All decisions about what a save
-- means (versions, migrations, missing fields) live in Shared.SaveData; this
-- module only talks to Roblox.
--
-- Safety: if loading fails (DataStore error, corrupt or newer save), the player
-- plays with a fresh state but is never saved, so the stored state survives.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SaveData = require(ReplicatedStorage.Shared.SaveData)

local STORE_NAME = "PlayerState"
local LOAD_ATTEMPTS = 3
local SAVE_ATTEMPTS = 3
local RETRY_SECONDS = 2

local SaveService = {}

-- Players whose save loaded correctly; only they are ever written back.
local loaded: { [number]: boolean } = {}

local storeOk, store = pcall(function()
	return DataStoreService:GetDataStore(STORE_NAME)
end)
if not storeOk then
	warn(`[Save] DataStore nicht verfügbar, Fortschritt wird nicht gespeichert: {store}`)
end

local function keyFor(userId: number): string
	return `player_{userId}`
end

local function withRetries<T>(attempts: number, fn: () -> T): (boolean, any)
	local ok, result = false, nil
	for attempt = 1, attempts do
		ok, result = pcall(fn)
		if ok then
			return true, result
		end
		if attempt < attempts then
			task.wait(RETRY_SECONDS)
		end
	end
	return false, result
end

-- Yields. Returns the player's current PlayerState: loaded and migrated, or
-- `fresh` if nothing is saved or loading failed (then saving stays disabled).
function SaveService.load(player: Player, fresh: any): any
	if not storeOk then
		return fresh
	end

	local ok, saved = withRetries(LOAD_ATTEMPTS, function()
		return store:GetAsync(keyFor(player.UserId))
	end)
	if not ok then
		warn(`[Save] Laden für {player.Name} fehlgeschlagen, es wird nicht gespeichert: {saved}`)
		return fresh
	end

	local result = SaveData.load(saved, fresh)
	if not result.ok then
		warn(`[Save] Spielstand von {player.Name} nicht lesbar ({result.reason}), es wird nicht gespeichert`)
		return result.state
	end

	loaded[player.UserId] = true
	return result.state
end

-- Yields. Writes the state if this player's save loaded correctly.
function SaveService.save(userId: number, state: any)
	if not storeOk or not loaded[userId] then
		return
	end

	local ok, err = withRetries(SAVE_ATTEMPTS, function()
		return store:UpdateAsync(keyFor(userId), function(old)
			-- Never replace a save written by a newer server version.
			if type(old) == "table" and type(old.version) == "number" and old.version > state.version then
				return nil
			end
			return state
		end)
	end)
	if not ok then
		warn(`[Save] Speichern für Spieler {userId} fehlgeschlagen: {err}`)
	end
end

-- Call after the final save of a player who left.
function SaveService.forget(userId: number)
	loaded[userId] = nil
end

return SaveService
