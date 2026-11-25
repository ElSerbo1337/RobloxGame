--!strict
-- Loads and stores PlayerStates in a DataStore. All decisions about what a save
-- means (versions, migrations, missing fields, session lock) live in
-- Shared.SaveData; this module only talks to Roblox.
--
-- Safety: if loading fails (DataStore error, corrupt or newer save), the player
-- plays with a fresh state but is never saved, so the stored state survives.
--
-- Session lock: loading claims the save for this server atomically (UpdateAsync),
-- periodic saves renew the claim, the final save on leave/shutdown releases it.
-- While another server holds a fresh claim (fast server hop: its final save may
-- still be running), loading waits and retries; a save is only written while
-- this server holds the claim, so an older state can never overwrite a newer one.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local SaveData = require(ReplicatedStorage.Shared.SaveData)

local LOAD_ATTEMPTS = 3
local SAVE_ATTEMPTS = 3
local RETRY_SECONDS = 2

local LOCK = GameConfig.save
local STORE_NAME = GameConfig.save.storeName
-- JobId is empty in Studio, so fall back to a random id per server.
local SERVER_ID = if game.JobId ~= "" then game.JobId else HttpService:GenerateGUID(false)

local SaveService = {}

-- Players whose save this server claimed (loaded correctly, lock held); only
-- they are ever written back.
local owned: { [number]: boolean } = {}

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

-- One atomic read-and-claim. Returns (DataStore ok, claim result or error).
local function tryClaim(userId: number, fresh: any): (boolean, any)
	local claim: SaveData.ClaimResult? = nil
	local ok, err = withRetries(LOAD_ATTEMPTS, function()
		return store:UpdateAsync(keyFor(userId), function(saved)
			-- May run more than once; the last run is the one that counts.
			local result = SaveData.claim(saved, fresh, SERVER_ID, os.time(), LOCK.lockExpirySeconds)
			claim = result
			return result.record -- nil cancels the write
		end)
	end)
	if not ok then
		return false, err
	end
	return true, claim
end

-- Yields. Returns the player's current PlayerState: loaded and migrated, or
-- `fresh` if nothing is saved or loading failed (then saving stays disabled).
-- If another server keeps its fresh lock for longer than lockWaitSeconds, the
-- player is kicked with a hint to rejoin later.
function SaveService.load(player: Player, fresh: any): any
	if not storeOk then
		return fresh
	end

	local attempts = math.floor(LOCK.lockWaitSeconds / LOCK.lockRetrySeconds) + 1
	for attempt = 1, attempts do
		local ok, result = tryClaim(player.UserId, fresh)
		if not ok then
			warn(`[Save] Laden für {player.Name} fehlgeschlagen, es wird nicht gespeichert: {result}`)
			return fresh
		end

		if result.ok then
			owned[player.UserId] = true
			return result.state
		end
		if result.reason ~= "Locked" then
			warn(`[Save] Spielstand von {player.Name} nicht lesbar ({result.reason}), es wird nicht gespeichert`)
			return result.state
		end

		if player.Parent == nil then
			return fresh -- left while waiting
		end
		if attempt < attempts then
			warn(`[Save] Spielstand von {player.Name} ist noch von einem anderen Server belegt, warte …`)
			task.wait(LOCK.lockRetrySeconds)
		end
	end

	warn(`[Save] Spielstand von {player.Name} blieb belegt, Spieler wird gekickt`)
	player:Kick(
		"Dein Spielstand wird gerade noch auf einem anderen Server gespeichert. Bitte tritt in ein paar Minuten erneut bei."
	)
	return fresh
end

-- Yields. Writes the state if this server owns the player's save. `release`
-- frees the session lock (final save on leave/shutdown); otherwise it is renewed.
-- Returns true if the state was written (only then is it this player's real state).
function SaveService.save(userId: number, state: any, release: boolean?): boolean
	if not storeOk or not owned[userId] then
		return false
	end

	local refused: string? = nil
	local ok, err = withRetries(SAVE_ATTEMPTS, function()
		return store:UpdateAsync(keyFor(userId), function(saved)
			local result = SaveData.prepareSave(saved, state, SERVER_ID, os.time(), release == true)
			refused = if result.ok then nil else result.reason
			return result.record -- nil keeps the stored record
		end)
	end)
	if not ok then
		warn(`[Save] Speichern für Spieler {userId} fehlgeschlagen: {err}`)
		return false
	elseif refused ~= nil then
		-- Another server took the save over (or a newer version wrote it): stop
		-- writing for this player, the other server's state wins.
		warn(`[Save] Speichern für Spieler {userId} verweigert ({refused}), es wird nicht mehr gespeichert`)
		owned[userId] = nil
		return false
	elseif release then
		owned[userId] = nil -- lock released; later saves (e.g. leave during shutdown) are skipped
	end
	return true
end

-- Call after the final save of a player who left.
function SaveService.forget(userId: number)
	owned[userId] = nil
end

return SaveService
