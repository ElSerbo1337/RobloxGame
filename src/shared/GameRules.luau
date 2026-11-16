--!strict
-- Game rules: pure Luau, no Roblox API. Works on a PlayerState table and returns
-- a result with success/failure reason plus the new state. Old states are never
-- mutated. The Roblox layer only calls these functions; it never changes a
-- PlayerState by itself.
--
-- Usage: local rules = GameRules.new(GameConfig)

export type PlayerState = {
	version: number,
	coins: number,
	-- Topping ids currently on the pizza, in collection order.
	pizza: { string },
	-- HUD switch: collect toppings by walking over them. Free from the start.
	autoCollect: boolean,
	-- Multiplies coins earned from selling; raised by rebirths (not built yet).
	rebirthMultiplier: number,
	-- Upgrade id -> bought level (missing = level 0).
	upgrades: { [string]: number },
	-- Ids of the worlds this player bought. Free worlds (unlockPrice 0) count as unlocked without being listed.
	unlockedWorlds: { string },
	-- Owned pets. `uid` is unique per player, `petId` refers to config.pets.
	pets: { OwnedPet },
	-- Next uid handed out when a pet is added.
	nextPetUid: number,
	-- Uids of equipped pets (follow the player and add their coin bonus).
	equipped: { number },
	-- Second currency: from gem toppings and play time, spent at the gem counter.
	gems: number,
	-- Play time not yet turned into gems (seconds).
	playtimeSeconds: number,
}

export type OwnedPet = { uid: number, petId: string }

export type Result = {
	ok: boolean,
	-- Set when ok == false: "UnknownTopping" | "OutOfRange" | "PizzaFull" | "PizzaEmpty" | "AutoCollectOff"
	-- | "UnknownShop" | "UnknownUpgrade" | "NotOffered" | "MaxLevel" | "ShopLevelLimit" | "NotEnoughCoins"
	-- | "UnknownWorld" | "AlreadyUnlocked" | "PreviousWorldLocked" | "WorldLocked"
	-- | "UnknownEgg" | "UnknownPet" | "AlreadyEquipped" | "PetSlotsFull" | "NotEquipped"
	-- | "InventoryFull" | "NoPets" | "NotEnoughGems" | "InvalidTime" | "MultiOpenLocked" | "InvalidCount"
	reason: string?,
	state: PlayerState,
}

export type SellResult = Result & { coinsEarned: number }

-- Collecting a gem topping or adding play time can earn gems (0 otherwise).
export type GemResult = Result & { gemsEarned: number }

-- One upgrade as shown in a shop menu.
export type ShopOffer = {
	upgrade: string,
	displayName: string,
	-- Level the player owns, the highest level this shop sells, the highest level that exists.
	level: number,
	shopMaxLevel: number,
	maxLevel: number,
	-- "Coins" (coin counter) or "Gems" (gem counter): what the price is paid with.
	currency: string,
	-- Current effect (pizza space, studs, ...), and price/effect of the next level if there is one.
	value: number,
	nextPrice: number?,
	nextValue: number?,
	-- "Available" | "ShopLevelLimit" (next level only in a bigger shop) | "MaxLevel"
	status: string,
}

export type EggPreview = {
	price: number,
	-- Sorted from most common to rarest.
	pets: { { petId: string, rarity: string, chancePercent: number, bonus: number } },
}

-- One world as shown in the portal menu; locked worlds are greyed out with their price.
export type PortalEntry = { worldId: string, displayName: string, unlockPrice: number, unlocked: boolean }

export type OpenEggResult = Result & { pet: OwnedPet? }

-- Opening several eggs at once: the drawn pets in order (empty on failure).
export type OpenEggsResult = Result & { pets: { OwnedPet } }

-- Bump together with a migration step in SaveData when a field changes shape.
local STATE_VERSION = 2

local GameRules = {}

function GameRules.new(config: any)
	local rules = {}

	local function fail(state: PlayerState, reason: string): Result
		return { ok = false, reason = reason, state = state }
	end

	function rules.newPlayerState(): PlayerState
		return {
			version = STATE_VERSION,
			coins = 0,
			pizza = {},
			autoCollect = false,
			rebirthMultiplier = 1,
			upgrades = {},
			unlockedWorlds = {},
			pets = {},
			nextPetUid = 1,
			equipped = {},
			gems = 0,
			playtimeSeconds = 0,
		}
	end

	-- Returns the world's config entry and its position in the unlock order.
	local function findWorld(worldId: string): (any, number)
		for index, world in config.worlds do
			if world.id == worldId then
				return world, index
			end
		end
		return nil, 0
	end

	function rules.isWorldUnlocked(state: PlayerState, worldId: string): boolean
		local world = findWorld(worldId)
		if world == nil then
			return false
		end
		if (world.unlockPrice or 0) == 0 then
			return true
		end
		return table.find(state.unlockedWorlds, worldId) ~= nil
	end

	-- A topping can be collected if at least one world it spawns in is unlocked.
	local function isToppingReachable(state: PlayerState, toppingId: string): boolean
		local spawnsSomewhere = false
		for _, world in config.worlds do
			for _, spawn in world.toppingSpawns do
				if spawn.topping == toppingId then
					spawnsSomewhere = true
					if rules.isWorldUnlocked(state, world.id) then
						return true
					end
				end
			end
		end
		return not spawnsSomewhere
	end

	-- An egg can be opened if a world it stands in is unlocked (eggs in no world: always).
	local function isEggReachable(state: PlayerState, eggId: string): boolean
		local standsSomewhere = false
		for _, world in config.worlds do
			if world.eggs and table.find(world.eggs, eggId) then
				standsSomewhere = true
				if rules.isWorldUnlocked(state, world.id) then
					return true
				end
			end
		end
		return not standsSomewhere
	end

	-- Buys access to a world (the barrier in front of it) for this player only.
	function rules.unlockWorld(state: PlayerState, worldId: string): Result
		local world, index = findWorld(worldId)
		if world == nil then
			return fail(state, "UnknownWorld")
		end
		if rules.isWorldUnlocked(state, worldId) then
			return fail(state, "AlreadyUnlocked")
		end
		if not rules.isWorldUnlocked(state, config.worlds[index - 1].id) then
			return fail(state, "PreviousWorldLocked")
		end
		if state.coins < world.unlockPrice then
			return fail(state, "NotEnoughCoins")
		end
		local newState = table.clone(state)
		newState.coins = state.coins - world.unlockPrice
		newState.unlockedWorlds = table.clone(state.unlockedWorlds)
		table.insert(newState.unlockedWorlds, worldId)
		return { ok = true, state = newState }
	end

	-- Whether a portal may send the player into this world. Free; the state stays unchanged.
	function rules.teleport(state: PlayerState, worldId: string): Result
		if findWorld(worldId) == nil then
			return fail(state, "UnknownWorld")
		end
		if not rules.isWorldUnlocked(state, worldId) then
			return fail(state, "WorldLocked")
		end
		return { ok = true, state = state }
	end

	-- Every world in unlock order, as shown in the portal menu.
	function rules.portalMenu(state: PlayerState): { PortalEntry }
		local entries = {}
		for _, world in config.worlds do
			table.insert(entries, {
				worldId = world.id,
				displayName = world.displayName,
				unlockPrice = world.unlockPrice or 0,
				unlocked = rules.isWorldUnlocked(state, world.id),
			})
		end
		return entries
	end

	function rules.upgradeLevel(state: PlayerState, upgradeId: string): number
		return state.upgrades[upgradeId] or 0
	end

	-- Effect of each upgrade before the first purchase (level 0).
	local baseValues: { [string]: number } = {
		PizzaSpace = config.pizza.startCapacity,
		CollectRange = config.collect.range,
		Magnet = 0,
		PetSlots = config.petSlots.start,
		InventorySpace = config.inventory.start,
		WalkSpeed = config.movement.walkSpeed,
		-- Eggs opened per press; the TripleOpen level sets it to 3.
		TripleOpen = 1,
	}

	-- The effect an upgrade gives at the player's current level.
	local function upgradeValue(state: PlayerState, upgradeId: string): number
		local level = rules.upgradeLevel(state, upgradeId)
		if level == 0 then
			return baseValues[upgradeId] or 0
		end
		return config.upgrades[upgradeId].levels[level].value
	end

	function rules.pizzaCapacity(state: PlayerState): number
		return upgradeValue(state, "PizzaSpace")
	end

	-- Max distance for clicking/tapping a topping.
	function rules.collectRange(state: PlayerState): number
		return upgradeValue(state, "CollectRange")
	end

	-- Radius in which auto-collect pulls toppings towards the player (0 = no magnet).
	function rules.magnetRange(state: PlayerState): number
		return upgradeValue(state, "Magnet")
	end

	-- Humanoid walk speed (studs per second).
	function rules.walkSpeed(state: PlayerState): number
		return upgradeValue(state, "WalkSpeed")
	end

	-- Most eggs the player may open with one press (1, or 3 after the gem upgrade).
	function rules.eggsPerOpen(state: PlayerState): number
		return upgradeValue(state, "TripleOpen")
	end

	function rules.isPizzaFull(state: PlayerState): boolean
		return #state.pizza >= rules.pizzaCapacity(state)
	end

	-- Pickup radius around the player while auto-collect is on; a magnet grows it.
	function rules.autoCollectRadius(state: PlayerState): number
		return math.max(config.collect.autoRadius, rules.magnetRange(state))
	end

	-- A gem topping goes straight into the gem counter, not onto the pizza (works with a full pizza).
	-- `gems` comes from the ToppingField spawn; it is clamped to the configured range.
	local function addGems(state: PlayerState, gems: number?, distance: number, range: number): GemResult
		if distance > range then
			return { ok = false, reason = "OutOfRange", state = state, gemsEarned = 0 }
		end
		local amount = math.clamp(math.floor(gems or 0), config.gems.toppingMin, config.gems.toppingMax)
		local newState = table.clone(state)
		newState.gems = state.gems + amount
		return { ok = true, state = newState, gemsEarned = amount }
	end

	local function addTopping(state: PlayerState, toppingId: string, distance: number, range: number): Result
		if config.toppings[toppingId] == nil then
			return fail(state, "UnknownTopping")
		end
		if not isToppingReachable(state, toppingId) then
			return fail(state, "WorldLocked")
		end
		if distance > range then
			return fail(state, "OutOfRange")
		end
		if rules.isPizzaFull(state) then
			return fail(state, "PizzaFull")
		end

		local newState = table.clone(state)
		newState.pizza = table.clone(state.pizza)
		table.insert(newState.pizza, toppingId)
		return { ok = true, state = newState }
	end

	local function collectWithin(state: PlayerState, toppingId: string, distance: number, range: number, gems: number?)
		if toppingId == config.gems.toppingId then
			return addGems(state, gems, distance, range)
		end
		local result: any = addTopping(state, toppingId, distance, range)
		result.gemsEarned = 0
		return result
	end

	-- Player clicked/tapped a topping. `distance` is measured by the server
	-- between the player and the topping. `gems`: amount of a gem topping (from the ToppingField).
	function rules.collectTopping(state: PlayerState, toppingId: string, distance: number, gems: number?): GemResult
		return collectWithin(state, toppingId, distance, rules.collectRange(state), gems)
	end

	-- Player walked over a topping with auto-collect switched on.
	function rules.autoCollectTopping(state: PlayerState, toppingId: string, distance: number, gems: number?): GemResult
		if not state.autoCollect then
			return { ok = false, reason = "AutoCollectOff", state = state, gemsEarned = 0 }
		end
		return collectWithin(state, toppingId, distance, rules.autoCollectRadius(state), gems)
	end

	-- Credits play time; every full `gems.playtimeSeconds` gives `gems.playtimeGems`.
	-- The rest is kept in the state (and saved), so no play time is lost between sessions.
	function rules.addPlayTime(state: PlayerState, seconds: number): GemResult
		if not (seconds > 0 and seconds < math.huge) then
			return { ok = false, reason = "InvalidTime", state = state, gemsEarned = 0 }
		end
		local total = state.playtimeSeconds + seconds
		local periods = math.floor(total / config.gems.playtimeSeconds)
		local earned = periods * config.gems.playtimeGems
		local newState = table.clone(state)
		newState.playtimeSeconds = total - periods * config.gems.playtimeSeconds
		newState.gems = state.gems + earned
		return { ok = true, state = newState, gemsEarned = earned }
	end

	function rules.setAutoCollect(state: PlayerState, enabled: boolean): Result
		local newState = table.clone(state)
		newState.autoCollect = enabled
		return { ok = true, state = newState }
	end

	-- 1 + sum of the coin bonuses of all equipped pets (bonuses are additive).
	function rules.coinMultiplier(state: PlayerState): number
		local bonus = 0
		for _, pet in state.pets do
			if table.find(state.equipped, pet.uid) then
				bonus += config.pets[pet.petId].bonus
			end
		end
		-- Round to 6 decimals so 0.2 + 0.2 + 0.2 reads as 0.6 in the HUD and tests.
		return math.round((1 + bonus) * 1e6) / 1e6
	end

	-- Sells every topping on the pizza at once:
	-- earned = sum of topping values x coinMultiplier (rounded down).
	function rules.sellPizza(state: PlayerState): SellResult
		if #state.pizza == 0 then
			return { ok = false, reason = "PizzaEmpty", state = state, coinsEarned = 0 }
		end

		local toppingValue = 0
		for _, toppingId in state.pizza do
			toppingValue += config.toppings[toppingId].value
		end
		-- Rounded down; the epsilon guards against float noise like 7 * 1.6 = 11.19999.
		local earned = math.floor(toppingValue * rules.coinMultiplier(state) + 1e-6)

		local newState = table.clone(state)
		newState.pizza = {}
		newState.coins = state.coins + earned
		return { ok = true, state = newState, coinsEarned = earned }
	end

	-- Highest level of an upgrade the given shop sells (0 = not offered there).
	local function shopMaxLevel(shopId: string, upgradeId: string): number
		for _, offer in config.shops[shopId].offers do
			if offer.upgrade == upgradeId then
				return offer.maxLevel
			end
		end
		return 0
	end

	-- Buys the next level of an upgrade in a shop. Each shop only sells up to its own max level,
	-- and only to players who unlocked the world it stands in.
	function rules.buyUpgrade(state: PlayerState, shopId: string, upgradeId: string): Result
		local shop = config.shops[shopId]
		if shop == nil then
			return fail(state, "UnknownShop")
		end
		local upgrade = config.upgrades[upgradeId]
		if upgrade == nil then
			return fail(state, "UnknownUpgrade")
		end
		if shop.worldId and not rules.isWorldUnlocked(state, shop.worldId) then
			return fail(state, "WorldLocked")
		end
		local shopMax = shopMaxLevel(shopId, upgradeId)
		if shopMax == 0 then
			return fail(state, "NotOffered")
		end
		local level = rules.upgradeLevel(state, upgradeId)
		local nextLevel = upgrade.levels[level + 1]
		if nextLevel == nil then
			return fail(state, "MaxLevel")
		end
		if level >= shopMax then
			return fail(state, "ShopLevelLimit")
		end
		local paysWithGems = upgrade.currency == "Gems"
		if paysWithGems and state.gems < nextLevel.price then
			return fail(state, "NotEnoughGems")
		elseif not paysWithGems and state.coins < nextLevel.price then
			return fail(state, "NotEnoughCoins")
		end

		local newState = table.clone(state)
		newState.upgrades = table.clone(state.upgrades)
		newState.upgrades[upgradeId] = level + 1
		if paysWithGems then
			newState.gems = state.gems - nextLevel.price
		else
			newState.coins = state.coins - nextLevel.price
		end
		return { ok = true, state = newState }
	end

	-- Everything a shop menu shows, in the shop's configured order.
	function rules.shopOffers(state: PlayerState, shopId: string): { ShopOffer }
		local offers = {}
		for _, offer in config.shops[shopId].offers do
			local upgrade = config.upgrades[offer.upgrade]
			local level = rules.upgradeLevel(state, offer.upgrade)
			local nextLevel = upgrade.levels[level + 1]
			table.insert(offers, {
				upgrade = offer.upgrade,
				displayName = upgrade.displayName,
				currency = upgrade.currency or "Coins",
				level = level,
				shopMaxLevel = offer.maxLevel,
				maxLevel = #upgrade.levels,
				value = upgradeValue(state, offer.upgrade),
				nextPrice = nextLevel and nextLevel.price,
				nextValue = nextLevel and nextLevel.value,
				status = if nextLevel == nil
					then "MaxLevel"
					elseif level >= offer.maxLevel then "ShopLevelLimit"
					else "Available",
			})
		end
		return offers
	end

	-- Picks a pet id from the egg's chance table. `random` returns a number in [0, 1).
	local function drawPet(egg: any, random: () -> number): string
		local total = 0
		for _, entry in egg.pets do
			total += entry.chance
		end
		local roll = random() * total
		for _, entry in egg.pets do
			roll -= entry.chance
			if roll < 0 then
				return entry.pet
			end
		end
		return egg.pets[#egg.pets].pet
	end

	-- What the egg can contain, for the floating preview above the egg.
	function rules.eggPreview(eggId: string): EggPreview
		local egg = config.eggs[eggId]
		local total = 0
		for _, entry in egg.pets do
			total += entry.chance
		end
		local pets = {}
		for _, entry in egg.pets do
			local pet = config.pets[entry.pet]
			table.insert(pets, {
				petId = entry.pet,
				rarity = pet.rarity,
				chancePercent = math.round(entry.chance / total * 100 * 1e4) / 1e4,
				bonus = pet.bonus,
			})
		end
		table.sort(pets, function(a, b)
			return a.chancePercent > b.chancePercent
		end)
		return { price = egg.price, pets = pets }
	end

	-- Whether `count` eggs per press is a size the multi-open upgrade can unlock at all.
	local function isMultiOpenSize(count: number): boolean
		for _, level in config.upgrades.TripleOpen.levels do
			if level.value == count then
				return true
			end
		end
		return false
	end

	-- Opens `count` eggs at once (1, or 3 after the "TripleOpen" gem upgrade): pays
	-- count x price and adds count randomly drawn pets. All or nothing.
	function rules.openEggs(state: PlayerState, eggId: string, count: number, random: () -> number): OpenEggsResult
		local function reject(reason: string): OpenEggsResult
			return { ok = false, reason = reason, state = state, pets = {} }
		end
		local egg = config.eggs[eggId]
		if egg == nil then
			return reject("UnknownEgg")
		end
		if count ~= 1 and count ~= rules.eggsPerOpen(state) then
			return reject(if isMultiOpenSize(count) then "MultiOpenLocked" else "InvalidCount")
		end
		if not isEggReachable(state, eggId) then
			return reject("WorldLocked")
		end
		if #state.pets + count > rules.inventorySlots(state) then
			return reject("InventoryFull")
		end
		if state.coins < egg.price * count then
			return reject("NotEnoughCoins")
		end

		local newState = table.clone(state)
		newState.coins = state.coins - egg.price * count
		newState.pets = table.clone(state.pets)
		local drawn = {}
		for i = 1, count do
			local pet: OwnedPet = { uid = state.nextPetUid + i - 1, petId = drawPet(egg, random) }
			table.insert(newState.pets, pet)
			table.insert(drawn, pet)
		end
		newState.nextPetUid = state.nextPetUid + count
		return { ok = true, state = newState, pets = drawn }
	end

	-- Pays the egg price and adds a randomly drawn pet to the inventory.
	function rules.openEgg(state: PlayerState, eggId: string, random: () -> number): OpenEggResult
		local result = rules.openEggs(state, eggId, 1, random)
		return { ok = result.ok, reason = result.reason, state = result.state, pet = result.pets[1] }
	end

	-- How many pets can be equipped at once; grows with the "PetSlots" gem upgrade.
	function rules.petSlots(state: PlayerState): number
		return upgradeValue(state, "PetSlots")
	end

	-- How many pets the player can own; opening an egg needs a free slot.
	-- Grows with the "InventorySpace" gem upgrade.
	function rules.inventorySlots(state: PlayerState): number
		return upgradeValue(state, "InventorySpace")
	end

	local function ownsPet(state: PlayerState, uid: number): boolean
		for _, pet in state.pets do
			if pet.uid == uid then
				return true
			end
		end
		return false
	end

	function rules.equipPet(state: PlayerState, uid: number): Result
		if not ownsPet(state, uid) then
			return fail(state, "UnknownPet")
		end
		if table.find(state.equipped, uid) then
			return fail(state, "AlreadyEquipped")
		end
		if #state.equipped >= rules.petSlots(state) then
			return fail(state, "PetSlotsFull")
		end

		local newState = table.clone(state)
		newState.equipped = table.clone(state.equipped)
		table.insert(newState.equipped, uid)
		return { ok = true, state = newState }
	end

	function rules.unequipPet(state: PlayerState, uid: number): Result
		local index = table.find(state.equipped, uid)
		if index == nil then
			return fail(state, "NotEquipped")
		end

		local newState = table.clone(state)
		newState.equipped = table.clone(state.equipped)
		table.remove(newState.equipped, index)
		return { ok = true, state = newState }
	end

	-- Removes a pet for good; an equipped pet is put away first. Its uid is never reused.
	function rules.deletePet(state: PlayerState, uid: number): Result
		if not ownsPet(state, uid) then
			return fail(state, "UnknownPet")
		end

		local newState = table.clone(state)
		newState.pets = {}
		for _, pet in state.pets do
			if pet.uid ~= uid then
				table.insert(newState.pets, pet)
			end
		end
		newState.equipped = table.clone(state.equipped)
		local index = table.find(newState.equipped, uid)
		if index then
			table.remove(newState.equipped, index)
		end
		return { ok = true, state = newState }
	end

	-- Equips the pets with the highest coin bonus, filling all pet slots. On equal bonus,
	-- pets that are already equipped stay, then older pets (lower uid) win.
	-- `equipped` ends up ordered from best to weakest.
	function rules.equipBest(state: PlayerState): Result
		if #state.pets == 0 then
			return fail(state, "NoPets")
		end

		local ranked = table.clone(state.pets)
		table.sort(ranked, function(a, b)
			local bonusA, bonusB = config.pets[a.petId].bonus, config.pets[b.petId].bonus
			if bonusA ~= bonusB then
				return bonusA > bonusB
			end
			local equippedA = table.find(state.equipped, a.uid) ~= nil
			local equippedB = table.find(state.equipped, b.uid) ~= nil
			if equippedA ~= equippedB then
				return equippedA
			end
			return a.uid < b.uid
		end)

		local newState = table.clone(state)
		newState.equipped = {}
		for i = 1, math.min(rules.petSlots(state), #ranked) do
			table.insert(newState.equipped, ranked[i].uid)
		end
		return { ok = true, state = newState }
	end

	return rules
end

return GameRules
