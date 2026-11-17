--!strict
-- Save data: pure Luau, no Roblox API. Turns what the DataStore returned into a
-- current PlayerState (versioned, with migrations) and a PlayerState into
-- something storable. The Roblox layer only stores/loads; it never patches
-- saved data by itself.
--
-- Adding a field to PlayerState: add it to rules.newPlayerState(); load() fills
-- it in for old saves automatically. Only when an existing field changes its
-- meaning/shape: bump GameRules' state version and add a migration step below.

-- Session lock stored next to the PlayerState fields in the saved record: the
-- server that currently owns the save and when it last claimed/renewed it
-- (os.time(), seconds). Never part of the PlayerState itself.
export type Lock = {
	serverId: string,
	time: number,
}

export type LoadResult = {
	ok: boolean,
	-- Set when ok == false: "Corrupt" | "NewerVersion". The state is then a fresh
	-- PlayerState to play with, and the Roblox layer must NOT save it.
	reason: string?,
	state: any,
}

-- Result of claiming a save on join. ok == true: `record` must be written back
-- (atomically, in the same UpdateAsync) and `state` is the player's PlayerState.
-- ok == false: reason is "Locked" (another server holds a fresh lock; retry
-- later), "Corrupt" or "NewerVersion" (play with `state`, never save).
export type ClaimResult = {
	ok: boolean,
	reason: string?,
	state: any,
	record: { [string]: any }?,
}

-- Result of preparing a save. ok == true: write `record`. ok == false: reason is
-- "NotOwner" (this server does not hold the lock; stop saving this player) or
-- "NewerVersion" (a newer server wrote the save; keep it).
export type SaveResult = {
	ok: boolean,
	reason: string?,
	record: { [string]: any }?,
}

local SaveData = {}

-- MIGRATIONS[v] upgrades a save from version v to v + 1 (mutates a private copy).
local MIGRATIONS: { [number]: (save: { [string]: any }) -> () } = {
	[1] = function(save)
		-- v2: rebirth multiplier, prepared for the rebirth system.
		save.rebirthMultiplier = 1
	end,
	[2] = function(save)
		-- v3: new-player tutorial. Players who saved before it existed already know
		-- the game, so it counts as finished for them (new players start at step 1).
		-- Any number past the last step means finished (math.huge cannot be stored as JSON).
		save.tutorialStep = 1000
	end,
	[3] = function(save)
		-- v4: the prepared rebirth multiplier becomes a rebirth counter (the multiplier
		-- is now computed as 1 + 0.5 x rebirths). It was never raised, so this gives 0.
		local multiplier = save.rebirthMultiplier
		save.rebirthMultiplier = nil
		save.rebirths = if type(multiplier) == "number" then math.max(0, math.round((multiplier - 1) / 0.5)) else 0
	end,
	[4] = function(save)
		-- v5: play time gifts replace the play time gems. The leftover play time towards
		-- the next gem is dropped; daily and total play time start at 0.
		save.playtimeSeconds = nil
	end,
}

-- `fresh` is a brand-new PlayerState (rules.newPlayerState()); it provides the
-- current version and defaults for every field the save does not have yet.
function SaveData.load(saved: any, fresh: any): LoadResult
	if saved == nil then
		return { ok = true, state = fresh }
	end
	if type(saved) ~= "table" then
		return { ok = false, reason = "Corrupt", state = fresh }
	end

	local save = table.clone(saved)
	local version = if type(save.version) == "number" then save.version else 1
	if version > fresh.version then
		-- Written by a newer server; loading it here would lose data on save.
		return { ok = false, reason = "NewerVersion", state = fresh }
	end
	while version < fresh.version do
		local migrate = MIGRATIONS[version]
		if migrate then
			migrate(save)
		end
		version += 1
	end

	local state = table.clone(fresh)
	for key, default in fresh do
		local value = save[key]
		if value ~= nil and type(value) == type(default) then
			state[key] = value
		end
	end
	state.version = fresh.version
	return { ok = true, state = state }
end

local function isLock(lock: any): boolean
	return type(lock) == "table" and type(lock.serverId) == "string" and type(lock.time) == "number"
end

-- May this server take over a save carrying `lock`? Yes if there is no (valid)
-- lock, the lock is this server's own, or it is older than `expirySeconds`
-- (its server crashed without releasing it).
function SaveData.canTakeOver(lock: any, serverId: string, now: number, expirySeconds: number): boolean
	if not isLock(lock) then
		return true
	end
	return lock.serverId == serverId or now - lock.time >= expirySeconds
end

-- Claim the stored record `saved` for this server when a player joins. Pure;
-- call it inside UpdateAsync so reading and locking happen atomically.
function SaveData.claim(saved: any, fresh: any, serverId: string, now: number, expirySeconds: number): ClaimResult
	local loadResult = SaveData.load(saved, fresh)
	if not loadResult.ok then
		return { ok = false, reason = loadResult.reason, state = loadResult.state }
	end
	if saved ~= nil and not SaveData.canTakeOver(saved.lock, serverId, now, expirySeconds) then
		return { ok = false, reason = "Locked", state = fresh }
	end

	-- Keep the stored data as it is (migrations are written on the next save);
	-- a new player gets the fresh state so the record is a valid save right away.
	local record = table.clone(if saved == nil then fresh else saved)
	record.lock = { serverId = serverId, time = now }
	return { ok = true, state = loadResult.state, record = record }
end

-- Build the record to store for `state`, given the currently stored `saved`.
-- Only the server holding the lock may save. `release` drops the lock (player
-- left / server shuts down), otherwise the lock is renewed.
function SaveData.prepareSave(saved: any, state: any, serverId: string, now: number, release: boolean): SaveResult
	if type(saved) ~= "table" or not isLock(saved.lock) or saved.lock.serverId ~= serverId then
		return { ok = false, reason = "NotOwner" }
	end
	if type(saved.version) == "number" and saved.version > state.version then
		return { ok = false, reason = "NewerVersion" }
	end

	local record = table.clone(state)
	record.lock = if release then nil else { serverId = serverId, time = now }
	return { ok = true, record = record }
end

return SaveData
