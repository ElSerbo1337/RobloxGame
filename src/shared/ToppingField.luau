--!strict
-- The toppings lying around in one world, shared by all players on the server.
-- Pure Luau, no Roblox API: randomness is injected, and time is passed in.

export type Topping = {
	toppingId: string,
	-- Spawn position inside the world's topping area, each axis normalized to [0, 1).
	x: number,
	z: number,
}

type Slot = {
	topping: Topping?,
	-- Time at which an empty slot gets a new topping.
	respawnAt: number?,
}

local ToppingField = {}
ToppingField.__index = ToppingField

export type ToppingField = typeof(setmetatable(
	{} :: {
		slotCount: number,
		_slots: { Slot },
		_respawnSeconds: number,
		_spawn: () -> Topping,
	},
	ToppingField
))

local function findWorld(config: any, worldId: string): any
	for _, world in config.worlds do
		if world.id == worldId then
			return world
		end
	end
	error(`unknown world "{worldId}"`)
end

local function rollTopping(spawns: { any }, totalWeight: number, random: () -> number): Topping
	local roll = random() * totalWeight
	local chosen = spawns[#spawns].topping
	for _, spawn in spawns do
		if roll < spawn.weight then
			chosen = spawn.topping
			break
		end
		roll -= spawn.weight
	end
	return { toppingId = chosen, x = random(), z = random() }
end

-- `random` returns a number in [0, 1), e.g. `function() return rng:NextNumber() end`.
function ToppingField.new(config: any, worldId: string, random: () -> number): ToppingField
	local spawns = findWorld(config, worldId).toppingSpawns
	local totalWeight = 0
	for _, spawn in spawns do
		totalWeight += spawn.weight
	end

	local self = setmetatable({
		slotCount = config.toppingField.count,
		_slots = {},
		_respawnSeconds = config.toppingField.respawnSeconds,
		_spawn = function()
			return rollTopping(spawns, totalWeight, random)
		end,
	}, ToppingField)
	for slotId = 1, self.slotCount do
		self._slots[slotId] = { topping = self._spawn() }
	end
	return self
end

-- The topping lying in this slot, or nil while it is waiting to respawn.
function ToppingField.get(self: ToppingField, slotId: number): Topping?
	local slot = self._slots[slotId]
	return slot and slot.topping
end

-- Removes the topping from the field. Returns false if the slot is empty, so a
-- topping can only ever be taken by one player.
function ToppingField.take(self: ToppingField, slotId: number, now: number): boolean
	local slot = self._slots[slotId]
	if slot == nil or slot.topping == nil then
		return false
	end
	slot.topping = nil
	slot.respawnAt = now + self._respawnSeconds
	return true
end

-- Spawns a new topping in every empty slot whose delay has passed and returns
-- the ids of those slots, so the caller can show them.
function ToppingField.respawnDue(self: ToppingField, now: number): { number }
	local respawned = {}
	for slotId, slot in self._slots do
		if slot.topping == nil and slot.respawnAt ~= nil and now >= slot.respawnAt then
			slot.topping = self._spawn()
			slot.respawnAt = nil
			table.insert(respawned, slotId)
		end
	end
	return respawned
end

return ToppingField
