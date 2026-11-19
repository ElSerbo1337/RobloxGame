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
	-- Rebirths done so far; each adds config.rebirth.multiplierPerRebirth to the coin
	-- multiplier for selling and delivery coins (see rebirthMultiplier).
	rebirths: number,
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
	-- Second currency: from gem toppings, deliveries and gifts, spent at the gem counter.
	gems: number,
	-- Play time gifts: seconds played on German day `playtimeDay` (see dayNumber; 0 = never)
	-- and the indices (into config.gifts) of the gifts claimed on that day.
	dailyPlaytimeSeconds: number,
	playtimeDay: number,
	giftsClaimed: { number },
	-- Seconds played in total (never reset).
	totalPlaytimeSeconds: number,
	-- Coins earned in total from selling, deliveries, login calendar and gifts. Never
	-- lowered by spending and kept through rebirths (leaderboard "Münzen verdient").
	totalCoinsEarned: number,
	-- Ids (config.hints) of new HUD buttons the player has opened once (they stop pulsing).
	seenHints: { string },
	-- Login calendar: calendar day (1-7) of the last claimed reward and the German day
	-- (see dayNumber) it was claimed on, and the German day the calendar last opened by
	-- itself on join (0 = never).
	loginStreak: number,
	loginClaimDay: number,
	loginShownDay: number,
	-- Current step of the new-player tutorial (index into the tutorial steps;
	-- past the last step = finished, never shown again).
	tutorialStep: number,
	-- Potion id -> how many the player owns (bought, not drunk yet).
	potions: { [string]: number },
	-- Potion id -> seconds of effect left for potions that are running (missing = not active).
	-- Counts down only while the player is online (see tickPotions).
	activePotions: { [string]: number },
	-- Delivery service (phone -> order -> delivery van). All fields optional:
	-- `call` = order offered by the ringing phone, `order` = accepted order being delivered,
	-- `nextCallAt` = earliest time (server clock, seconds) the phone rings again.
	delivery: Delivery,
	-- World the player was last in (walked into or teleported to); "" = none yet.
	-- Deaths and rejoins spawn there while it is unlocked (see spawnWorld).
	lastWorldId: string,
}

export type Delivery = { call: Order?, order: Order?, nextCallAt: number? }

-- A delivery order: toppings (id -> count) from one world and the kind of reward.
export type Order = {
	worldId: string,
	toppings: { [string]: number },
	-- "Coins" | "Gems" | "Potion"
	reward: string,
	-- Gem reward before the speed bonus (reward "Gems").
	gems: number?,
	-- Potion handed out (reward "Potion").
	potionId: string?,
	-- Set once accepted: when the time is up (same clock as `now`).
	expiresAt: number?,
}

export type OwnedPet = { uid: number, petId: string }

export type LeaderboardScores = { Playtime: number, CoinsEarned: number, Rebirths: number }

export type Result = {
	ok: boolean,
	-- Set when ok == false: "UnknownTopping" | "OutOfRange" | "PizzaFull" | "PizzaEmpty" | "AutoCollectOff"
	-- | "UnknownShop" | "UnknownUpgrade" | "NotOffered" | "MaxLevel" | "ShopLevelLimit" | "NotEnoughCoins"
	-- | "UnknownWorld" | "AlreadyUnlocked" | "PreviousWorldLocked" | "WorldLocked" | "NotEnoughRebirths"
	-- | "UnknownEgg" | "UnknownPet" | "AlreadyEquipped" | "PetSlotsFull" | "NotEquipped"
	-- | "InventoryFull" | "NoPets" | "NotEnoughGems" | "InvalidTime" | "MultiOpenLocked" | "InvalidCount"
	-- | "UnknownPotion" | "NoPotion" | "OrderToppingsOnly"
	-- | "TutorialRunning" | "CallWaiting" | "OrderActive" | "PhoneNotReady" | "NoCall" | "NoOrder"
	-- | "OrderExpired" | "WrongToppings" | "NotExpired"
	-- | "UnknownGift" | "GiftNotReady" | "GiftClaimed" | "UnknownHint" | "HintSeen"
	-- | "LoginClaimed" | "CalendarShown"
	reason: string?,
	state: PlayerState,
}

export type SellResult = Result & { coinsEarned: number }

-- Collecting a gem topping can earn gems (0 otherwise).
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
export type PortalEntry = {
	worldId: string,
	displayName: string,
	unlockPrice: number,
	unlocked: boolean,
	-- Rebirths the world asks for besides its price (#43) and whether the player has them.
	requiredRebirths: number,
	enoughRebirths: boolean,
}

-- One potion as shown at a shop's gem counter.
export type PotionOffer = {
	potionId: string,
	displayName: string,
	-- Price in gems and how long one potion runs.
	price: number,
	durationSeconds: number,
	-- How many the player has in the potion inventory.
	owned: number,
}

-- Passing time for running potions: the potion ids whose time ran out with this tick.
export type PotionTickResult = Result & { expired: { string } }

-- What a delivered order pays: `amount` coins, gems or potions (of `potionId`).
export type DeliveryReward = { reward: string, amount: number, potionId: string? }

export type DeliveryResult = Result & { reward: DeliveryReward? }

export type OpenEggResult = Result & { pet: OwnedPet? }

-- Opening several eggs at once: the drawn pets in order (empty on failure).
export type OpenEggsResult = Result & { pets: { OwnedPet } }

-- The tutorial step a player is on, for the arrow and text on the client.
export type TutorialInfo = {
	-- "CollectToppings" | "SellPizza" | "BuyUpgrade" | "OpenEgg"
	step: string,
	-- Position of the step (1-based) and number of steps.
	number: number,
	total: number,
	-- How far the player is within the step, e.g. 1 of 2 toppings.
	progress: number,
	goal: number,
}

-- What the rebirth menu shows.
export type RebirthOffer = {
	-- Rebirths done so far and the coin price of the next one.
	rebirths: number,
	price: number,
	-- Rebirth coin multiplier now and after the next rebirth.
	multiplier: number,
	nextMultiplier: number,
	-- Coins / price, at most 1.
	progress: number,
	affordable: boolean,
	-- A potion is running: it would end with the rebirth.
	potionWarning: boolean,
}

-- A reward as configured for gifts (and the login calendar): a fixed `amount` of gems or
-- potions.
export type RewardSpec = { kind: string, amount: number }

-- A reward as paid out / shown: "Gems" | "Potion", how many, and which potion
-- (set once a potion reward was drawn).
export type Reward = { kind: string, amount: number, potionId: string? }

-- One play time gift as shown in the gifts menu.
export type GiftEntry = {
	index: number,
	-- Play time of the day at which it is reached.
	minutes: number,
	-- "Claimed" | "Ready" | "Waiting"
	status: string,
	-- Seconds of play time until it is reached (0 once reached).
	secondsLeft: number,
	rewards: { Reward },
}

export type GiftStatus = {
	gifts: { GiftEntry },
	-- Reached but not claimed yet today.
	readyCount: number,
	-- Seconds of play time until the next gift is reached (nil = all reached today).
	nextSeconds: number?,
}

export type RewardsResult = Result & { rewards: { Reward } }

-- One day of the login calendar as shown in the calendar window.
export type LoginDay = {
	day: number,
	-- "Claimed" (earlier in the current series, or today once claimed) | "Ready" (today,
	-- not claimed yet) | "Waiting" (later days)
	status: string,
	rewards: { Reward },
}

export type LoginCalendar = {
	-- Calendar day (1-7) of today: claimable now, or already claimed today.
	today: number,
	claimable: boolean,
	days: { LoginDay },
}

-- `day` = the calendar day that was claimed (0 when refused).
export type LoginClaimResult = RewardsResult & { day: number }

-- Bump together with a migration step in SaveData when a field changes shape.
local STATE_VERSION = 5

local DAY_SECONDS = 24 * 3600

-- Days since 1970-01-01 of a proleptic Gregorian date (Howard Hinnant's days_from_civil).
local function daysFromCivil(year: number, month: number, day: number): number
	local y = if month <= 2 then year - 1 else year
	local era = y // 400
	local yearOfEra = y - era * 400
	local dayOfYear = (153 * (if month > 2 then month - 3 else month + 9) + 2) // 5 + day - 1
	local dayOfEra = yearOfEra * 365 + yearOfEra // 4 - yearOfEra // 100 + dayOfYear
	return era * 146097 + dayOfEra - 719468
end

-- Year (UTC) of a day count since 1970-01-01 (inverse of daysFromCivil, year only).
local function yearOfDays(days: number): number
	local z = days + 719468
	local era = z // 146097
	local dayOfEra = z - era * 146097
	local yearOfEra = (dayOfEra - dayOfEra // 1460 + dayOfEra // 36524 - dayOfEra // 146096) // 365
	local dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra // 4 - yearOfEra // 100)
	local monthIndex = (5 * dayOfYear + 2) // 153 -- 0 = March
	return yearOfEra + era * 400 + (if monthIndex >= 10 then 1 else 0)
end

-- Unix time of the EU clock change in `year`: last Sunday of `month`, 01:00 UTC.
local function clockChange(year: number, month: number): number
	local lastDay = daysFromCivil(year, month, 31)
	local weekday = (lastDay + 4) % 7 -- 0 = Sunday (1970-01-01 was a Thursday)
	return (lastDay - weekday) * DAY_SECONDS + 3600
end

local GameRules = {}

-- Number of the calendar day in German time (CET/CEST, EU rule: summer time from the
-- last Sunday of March to the last Sunday of October, 01:00 UTC each) for a Unix time:
-- days since 1970-01-01 there. Daily resets (gifts, login calendar) compare these numbers.
function GameRules.dayNumber(unixSeconds: number): number
	local year = yearOfDays(unixSeconds // DAY_SECONDS)
	local summer = unixSeconds >= clockChange(year, 3) and unixSeconds < clockChange(year, 10)
	local offset = if summer then 2 * 3600 else 3600
	return (unixSeconds + offset) // DAY_SECONDS
end

function GameRules.new(config: any)
	local rules = {}

	local function fail(state: PlayerState, reason: string): Result
		return { ok = false, reason = reason, state = state }
	end

	rules.dayNumber = GameRules.dayNumber

	function rules.newPlayerState(): PlayerState
		return {
			version = STATE_VERSION,
			coins = 0,
			pizza = {},
			autoCollect = false,
			rebirths = 0,
			upgrades = {},
			unlockedWorlds = {},
			pets = {},
			nextPetUid = 1,
			equipped = {},
			gems = 0,
			dailyPlaytimeSeconds = 0,
			playtimeDay = 0,
			giftsClaimed = {},
			totalPlaytimeSeconds = 0,
			totalCoinsEarned = 0,
			seenHints = {},
			loginStreak = 0,
			loginClaimDay = 0,
			loginShownDay = 0,
			tutorialStep = 1,
			potions = {},
			activePotions = {},
			delivery = {},
			lastWorldId = "",
		}
	end

	-- Tutorial steps in order; each one is finished by a successful real action.
	local TUTORIAL_STEPS = { "CollectToppings", "SellPizza", "BuyUpgrade", "OpenEgg" }

	local function tutorialGoal(stepId: string): number
		return if stepId == "CollectToppings" then config.tutorial.collectToppings else 1
	end

	-- The step the player is on, or nil when the tutorial is finished.
	function rules.tutorial(state: PlayerState): TutorialInfo?
		local stepId = TUTORIAL_STEPS[state.tutorialStep]
		if stepId == nil then
			return nil
		end
		local goal = tutorialGoal(stepId)
		local progress = if stepId == "CollectToppings" then math.min(#state.pizza, goal) else 0
		return {
			step = stepId,
			number = state.tutorialStep,
			total = #TUTORIAL_STEPS,
			progress = progress,
			goal = goal,
		}
	end

	-- Called with the new state after a successful action; moves the tutorial on
	-- when that action finishes the current step. Mutates `newState` (a fresh copy).
	local function advanceTutorial(newState: PlayerState, stepId: string)
		if TUTORIAL_STEPS[newState.tutorialStep] ~= stepId then
			return
		end
		if stepId == "CollectToppings" and #newState.pizza < tutorialGoal(stepId) then
			return
		end
		newState.tutorialStep += 1
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
		if (world.unlockPrice or 0) == 0 and (world.requiredRebirths or 0) == 0 then
			return true
		end
		return table.find(state.unlockedWorlds, worldId) ~= nil
	end

	-- Rebirths a world asks for besides its coin price (#43); worlds without the field
	-- (and unknown worlds) need 0.
	function rules.rebirthsNeeded(worldId: string): number
		local world = findWorld(worldId)
		return if world then world.requiredRebirths or 0 else 0
	end

	-- Whether the player has done enough rebirths to buy this world.
	function rules.hasRebirthsFor(state: PlayerState, worldId: string): boolean
		return state.rebirths >= rules.rebirthsNeeded(worldId)
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
		if index > 1 and not rules.isWorldUnlocked(state, config.worlds[index - 1].id) then
			return fail(state, "PreviousWorldLocked")
		end
		if not rules.hasRebirthsFor(state, worldId) then
			return fail(state, "NotEnoughRebirths")
		end
		if state.coins < (world.unlockPrice or 0) then
			return fail(state, "NotEnoughCoins")
		end
		local newState = table.clone(state)
		newState.coins = state.coins - (world.unlockPrice or 0)
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

	-- The player walked or teleported into a world: remember it as the respawn world.
	-- Only unlocked worlds count; entering the current world again keeps the same state.
	function rules.enterWorld(state: PlayerState, worldId: string): Result
		if findWorld(worldId) == nil then
			return fail(state, "UnknownWorld")
		end
		if not rules.isWorldUnlocked(state, worldId) then
			return fail(state, "WorldLocked")
		end
		if state.lastWorldId == worldId then
			return { ok = true, state = state }
		end
		local newState = table.clone(state)
		newState.lastWorldId = worldId
		return { ok = true, state = newState }
	end

	-- World the player (re)spawns in after death or on join, or nil for the normal start
	-- (no world visited yet, or the last world is unknown or no longer unlocked).
	function rules.spawnWorld(state: PlayerState): string?
		local worldId = state.lastWorldId
		if worldId ~= "" and rules.isWorldUnlocked(state, worldId) then
			return worldId
		end
		return nil
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
				requiredRebirths = world.requiredRebirths or 0,
				enoughRebirths = rules.hasRebirthsFor(state, world.id),
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

	-- Effect setting of a potion while it runs, `default` otherwise (or for unknown potions).
	local function potionEffect(state: PlayerState, potionId: string, key: string, default: any): any
		local potion = config.potions and config.potions[potionId]
		if potion == nil or (state.activePotions[potionId] or 0) <= 0 then
			return default
		end
		return potion[key] or default
	end

	-- Humanoid walk speed (studs per second): the WalkSpeed upgrade, times the speed potion.
	function rules.walkSpeed(state: PlayerState): number
		return upgradeValue(state, "WalkSpeed") * potionEffect(state, "Speed", "walkSpeedMultiplier", 1)
	end

	-- Sell value factor from the coin potion (1 when it is not running).
	function rules.potionCoinMultiplier(state: PlayerState): number
		return potionEffect(state, "Coins", "coinMultiplier", 1)
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
		advanceTutorial(newState, "CollectToppings")
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

	-- Credits play time at Unix time `now`: to the play time of the (German) day and to the
	-- total. On a new day the day's play time and claimed gifts start over first.
	function rules.addPlayTime(state: PlayerState, seconds: number, now: number): Result
		if not (seconds > 0 and seconds < math.huge) then
			return fail(state, "InvalidTime")
		end
		local today = rules.dayNumber(now)
		local newState = table.clone(state)
		if state.playtimeDay ~= today then
			newState.playtimeDay = today
			newState.dailyPlaytimeSeconds = 0
			newState.giftsClaimed = {}
		end
		newState.dailyPlaytimeSeconds += seconds
		newState.totalPlaytimeSeconds = state.totalPlaytimeSeconds + seconds
		return { ok = true, state = newState }
	end

	-- Seconds played on the German day of `now` (0 when the last play time was on another day).
	function rules.dailyPlaytime(state: PlayerState, now: number): number
		return if state.playtimeDay == rules.dayNumber(now) then state.dailyPlaytimeSeconds else 0
	end

	function rules.hasSeenHint(state: PlayerState, hintId: string): boolean
		return table.find(state.seenHints, hintId) ~= nil
	end

	-- Remembers that the player opened a new HUD button (config.hints) once.
	function rules.markHintSeen(state: PlayerState, hintId: string): Result
		if not table.find(config.hints, hintId) then
			return fail(state, "UnknownHint")
		end
		if rules.hasSeenHint(state, hintId) then
			return fail(state, "HintSeen")
		end
		local newState = table.clone(state)
		newState.seenHints = table.clone(state.seenHints)
		table.insert(newState.seenHints, hintId)
		return { ok = true, state = newState }
	end

	function rules.setAutoCollect(state: PlayerState, enabled: boolean): Result
		local newState = table.clone(state)
		newState.autoCollect = enabled
		return { ok = true, state = newState }
	end

	-- Coin factor from rebirths: 1 + multiplierPerRebirth x rebirths (not for gems).
	function rules.rebirthMultiplier(state: PlayerState): number
		return 1 + config.rebirth.multiplierPerRebirth * state.rebirths
	end

	-- Pet cap per world (#51): every world's cap is the best bonus of a pet from its eggs
	-- (a world without eggs keeps the cap of the world before) x config.rebirth.petCapFactor.
	-- A pet's home world is the first world whose eggs hold it. Derived, never saved.
	local petCapFactor = (config.rebirth and config.rebirth.petCapFactor) or 1
	local capByWorld: { [string]: number } = {}
	local worldIndexById: { [string]: number } = {}
	local petHomeIndex: { [string]: number } = {}
	do
		local best = 0
		for index, world in config.worlds do
			worldIndexById[world.id] = index
			for _, eggId in world.eggs or {} do
				for _, entry in config.eggs[eggId].pets do
					best = math.max(best, config.pets[entry.pet].bonus)
					if petHomeIndex[entry.pet] == nil then
						petHomeIndex[entry.pet] = index
					end
				end
			end
			capByWorld[world.id] = math.round(best * petCapFactor * 1e6) / 1e6
		end
	end

	-- Highest bonus a pet from a later world counts in this world (see above).
	function rules.petCap(worldId: string): number
		return capByWorld[worldId] or math.huge
	end

	-- What one pet adds to the coin multiplier when selling or delivering in `worldId`:
	-- its full bonus in its home world and every later one, at most the world's cap in
	-- earlier worlds. Without a world (or for pets from no egg) the full bonus.
	function rules.petBonusIn(petId: string, worldId: string?): number
		local bonus = config.pets[petId].bonus
		if worldId == nil then
			return bonus
		end
		local worldIndex, homeIndex = worldIndexById[worldId], petHomeIndex[petId]
		if worldIndex == nil or homeIndex == nil or homeIndex <= worldIndex then
			return bonus
		end
		return math.min(bonus, rules.petCap(worldId))
	end

	-- 1 + sum of the coin bonuses of all equipped pets (bonuses are additive), each capped
	-- for the world the coins are earned in (petBonusIn). Without a world: uncapped.
	function rules.petMultiplier(state: PlayerState, worldId: string?): number
		local bonus = 0
		for _, pet in state.pets do
			if table.find(state.equipped, pet.uid) then
				bonus += rules.petBonusIn(pet.petId, worldId)
			end
		end
		-- Round to 6 decimals so 0.2 + 0.2 + 0.2 reads as 0.6 in the HUD and tests.
		return math.round((1 + bonus) * 1e6) / 1e6
	end

	-- Pet multiplier (capped for `worldId`) x rebirth multiplier: what selling and
	-- delivery coins in that world are multiplied by.
	function rules.coinMultiplier(state: PlayerState, worldId: string?): number
		return math.round(rules.petMultiplier(state, worldId) * rules.rebirthMultiplier(state) * 1e6) / 1e6
	end

	-- Splits the pizza into toppings the active delivery order still needs (kept, in
	-- pizza order) and the rest (sold at the oven). Without an order everything is sold.
	local function splitForOrder(state: PlayerState): ({ string }, { string })
		local order = state.delivery.order
		if order == nil then
			return {}, state.pizza
		end
		local needed = table.clone(order.toppings)
		local kept, sold = {}, {}
		for _, toppingId in state.pizza do
			if (needed[toppingId] or 0) > 0 then
				needed[toppingId] -= 1
				table.insert(kept, toppingId)
			else
				table.insert(sold, toppingId)
			end
		end
		return kept, sold
	end

	-- Sells every topping on the pizza at once (during a delivery order only the ones
	-- the order does not need): earned = sum of topping values x coinMultiplier x coin
	-- potion (rounded down). `worldId` = world of the oven (pet cap, #51; nil = uncapped).
	function rules.sellPizza(state: PlayerState, worldId: string?): SellResult
		if #state.pizza == 0 then
			return { ok = false, reason = "PizzaEmpty", state = state, coinsEarned = 0 }
		end
		local kept, sold = splitForOrder(state)
		if #sold == 0 then
			return { ok = false, reason = "OrderToppingsOnly", state = state, coinsEarned = 0 }
		end

		local toppingValue = 0
		for _, toppingId in sold do
			toppingValue += config.toppings[toppingId].value
		end
		-- Rounded down; the epsilon guards against float noise like 7 * 1.6 = 11.19999.
		local earned =
			math.floor(toppingValue * rules.coinMultiplier(state, worldId) * rules.potionCoinMultiplier(state) + 1e-6)

		local newState = table.clone(state)
		newState.pizza = kept
		newState.coins = state.coins + earned
		newState.totalCoinsEarned = state.totalCoinsEarned + earned
		advanceTutorial(newState, "SellPizza")
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
		advanceTutorial(newState, "BuyUpgrade")
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

	-- The egg's chance weights for this player: the configured chances, with the luck
	-- potion's per-rarity factors applied while it runs. Returns the weights (in egg order) and their sum.
	local function eggWeights(egg: any, state: PlayerState?): ({ number }, number)
		local rarityWeights = if state then potionEffect(state, "Luck", "rarityWeights", nil) else nil
		local weights, total = {}, 0
		for i, entry in egg.pets do
			local factor = rarityWeights and rarityWeights[config.pets[entry.pet].rarity] or 1
			weights[i] = entry.chance * factor
			total += weights[i]
		end
		return weights, total
	end

	-- Picks a pet id from the egg's chance table. `random` returns a number in [0, 1).
	local function drawPet(state: PlayerState, egg: any, random: () -> number): string
		local weights, total = eggWeights(egg, state)
		local roll = random() * total
		for i, entry in egg.pets do
			roll -= weights[i]
			if roll < 0 then
				return entry.pet
			end
		end
		return egg.pets[#egg.pets].pet
	end

	-- What the egg can contain, for the floating preview above the egg. With a state,
	-- the chances include that player's luck potion.
	function rules.eggPreview(eggId: string, state: PlayerState?): EggPreview
		local egg = config.eggs[eggId]
		local weights, total = eggWeights(egg, state)
		local pets = {}
		for i, entry in egg.pets do
			local pet = config.pets[entry.pet]
			table.insert(pets, {
				petId = entry.pet,
				rarity = pet.rarity,
				chancePercent = math.round(weights[i] / total * 100 * 1e4) / 1e4,
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
			local pet: OwnedPet = { uid = state.nextPetUid + i - 1, petId = drawPet(state, egg, random) }
			table.insert(newState.pets, pet)
			table.insert(drawn, pet)
		end
		newState.nextPetUid = state.nextPetUid + count
		advanceTutorial(newState, "OpenEgg")
		return { ok = true, state = newState, pets = drawn }
	end

	-- Pays the egg price and adds a randomly drawn pet to the inventory.
	function rules.openEgg(state: PlayerState, eggId: string, random: () -> number): OpenEggResult
		local result = rules.openEggs(state, eggId, 1, random)
		return { ok = result.ok, reason = result.reason, state = result.state, pet = result.pets[1] }
	end

	-- How many of a potion the player owns (in the potion inventory).
	function rules.potionCount(state: PlayerState, potionId: string): number
		return state.potions[potionId] or 0
	end

	-- Buys one potion at a shop's gem counter; it lands in the potion inventory.
	function rules.buyPotion(state: PlayerState, shopId: string, potionId: string): Result
		local shop = config.shops[shopId]
		if shop == nil then
			return fail(state, "UnknownShop")
		end
		local potion = config.potions[potionId]
		if potion == nil then
			return fail(state, "UnknownPotion")
		end
		if shop.worldId and not rules.isWorldUnlocked(state, shop.worldId) then
			return fail(state, "WorldLocked")
		end
		if not (shop.potions and table.find(shop.potions, potionId)) then
			return fail(state, "NotOffered")
		end
		if state.gems < potion.price then
			return fail(state, "NotEnoughGems")
		end
		local newState = table.clone(state)
		newState.gems = state.gems - potion.price
		newState.potions = table.clone(state.potions)
		newState.potions[potionId] = rules.potionCount(state, potionId) + 1
		return { ok = true, state = newState }
	end

	-- The potions a shop's gem counter sells, in the shop's configured order.
	function rules.potionOffers(state: PlayerState, shopId: string): { PotionOffer }
		local offers = {}
		for _, potionId in config.shops[shopId].potions or {} do
			local potion = config.potions[potionId]
			table.insert(offers, {
				potionId = potionId,
				displayName = potion.displayName,
				price = potion.price,
				durationSeconds = potion.durationSeconds,
				owned = rules.potionCount(state, potionId),
			})
		end
		return offers
	end

	-- Seconds of effect a potion has left (0 = not active).
	function rules.potionTimeLeft(state: PlayerState, potionId: string): number
		return state.activePotions[potionId] or 0
	end

	-- Drinks one potion from the inventory. Drinking a kind that is already running
	-- adds its duration to the time left instead of starting over.
	function rules.drinkPotion(state: PlayerState, potionId: string): Result
		local potion = config.potions[potionId]
		if potion == nil then
			return fail(state, "UnknownPotion")
		end
		if rules.potionCount(state, potionId) <= 0 then
			return fail(state, "NoPotion")
		end
		local newState = table.clone(state)
		newState.potions = table.clone(state.potions)
		newState.potions[potionId] = rules.potionCount(state, potionId) - 1
		if newState.potions[potionId] == 0 then
			newState.potions[potionId] = nil
		end
		newState.activePotions = table.clone(state.activePotions)
		newState.activePotions[potionId] = rules.potionTimeLeft(state, potionId) + potion.durationSeconds
		return { ok = true, state = newState }
	end

	-- Lets `seconds` of (online) time pass for every running potion; potions whose
	-- time is up end and are listed in `expired` (sorted).
	function rules.tickPotions(state: PlayerState, seconds: number): PotionTickResult
		if not (seconds > 0 and seconds < math.huge) then
			return { ok = false, reason = "InvalidTime", state = state, expired = {} }
		end
		local newState = table.clone(state)
		newState.activePotions = {}
		local expired = {}
		for potionId, left in state.activePotions do
			if left - seconds > 0 then
				newState.activePotions[potionId] = left - seconds
			else
				table.insert(expired, potionId)
			end
		end
		table.sort(expired)
		return { ok = true, state = newState, expired = expired }
	end

	-- Delivery service ---------------------------------------------------------

	-- Picks an entry of a { { [key]: any, weight: number } } list by weight.
	local function drawWeighted(entries: { any }, random: () -> number): any
		local total = 0
		for _, entry in entries do
			total += entry.weight
		end
		local roll = random() * total
		for _, entry in entries do
			roll -= entry.weight
			if roll < 0 then
				return entry
			end
		end
		return entries[#entries]
	end

	-- The last world in unlock order the player has unlocked.
	local function highestUnlockedWorld(state: PlayerState): any
		local highest = config.worlds[1]
		for _, world in config.worlds do
			if rules.isWorldUnlocked(state, world.id) then
				highest = world
			end
		end
		return highest
	end

	-- A random potion id, all potions equally likely (one random draw): delivery orders,
	-- gifts and the login calendar hand out potions this way.
	local function randomPotionId(random: () -> number): string
		local potionIds = {}
		for potionId in config.potions do
			table.insert(potionIds, potionId)
		end
		table.sort(potionIds)
		return potionIds[math.min(#potionIds, 1 + math.floor(random() * #potionIds))]
	end

	-- A new order for this player: toppings of the highest unlocked world (by spawn
	-- weight), between delivery.minToppings and the pizza space in total.
	local function newOrder(state: PlayerState, random: () -> number): Order
		local delivery = config.delivery
		local world = highestUnlockedWorld(state)
		local most = rules.pizzaCapacity(state)
		local fewest = math.min(delivery.minToppings, most)
		local count = math.min(most, fewest + math.floor(random() * (most - fewest + 1)))
		local toppings = {}
		for _ = 1, count do
			local toppingId = drawWeighted(world.toppingSpawns, random).topping
			toppings[toppingId] = (toppings[toppingId] or 0) + 1
		end
		local order: Order = {
			worldId = world.id,
			toppings = toppings,
			reward = drawWeighted(delivery.rewardWeights, random).reward,
		}
		if order.reward == "Gems" then
			local spread = delivery.gemsBaseMax - delivery.gemsMin + 1
			order.gems = delivery.gemsMin + math.min(spread - 1, math.floor(random() * spread))
		elseif order.reward == "Potion" then
			order.potionId = randomPotionId(random)
		end
		return order
	end

	-- Estimated coins per minute, deterministic (no potions, no luck): average topping
	-- value of the highest unlocked world (by spawn weight) x pizza space x
	-- income.roundsPerMinute x coin multiplier (pets capped for that world, rebirths).
	function rules.incomePerMinute(state: PlayerState): number
		local world = highestUnlockedWorld(state)
		local totalWeight, totalValue = 0, 0
		for _, spawn in world.toppingSpawns do
			totalWeight += spawn.weight
			totalValue += spawn.weight * config.toppings[spawn.topping].value
		end
		if totalWeight <= 0 then
			return 0
		end
		return totalValue
			/ totalWeight
			* rules.pizzaCapacity(state)
			* config.income.roundsPerMinute
			* rules.coinMultiplier(state, world.id)
	end

	-- Configured rewards as they will be paid out (fixed amounts; potions not drawn yet).
	local function previewRewards(specs: { RewardSpec }): { Reward }
		local rewards = {}
		for _, spec in specs do
			table.insert(rewards, { kind = spec.kind, amount = spec.amount })
		end
		return rewards
	end

	-- Pays configured rewards into a copy of the state; each potion reward draws one
	-- random potion (like delivery orders). Returns the new state and what was paid.
	local function payRewards(
		state: PlayerState,
		specs: { RewardSpec },
		random: () -> number
	): (PlayerState, { Reward })
		local newState = table.clone(state)
		newState.potions = table.clone(state.potions)
		local paid = previewRewards(specs)
		for _, reward in paid do
			if reward.kind == "Gems" then
				newState.gems += reward.amount
			elseif reward.kind == "Potion" then
				local potionId = randomPotionId(random)
				reward.potionId = potionId
				newState.potions[potionId] = (newState.potions[potionId] or 0) + reward.amount
			end
		end
		return newState, paid
	end

	-- Indices of the gifts claimed on the German day of `now`.
	local function claimedToday(state: PlayerState, now: number): { number }
		return if state.playtimeDay == rules.dayNumber(now) then state.giftsClaimed else {}
	end

	-- All play time gifts of the day of `now` (config.gifts order): claimed, ready to
	-- claim or still waiting, with time left and rewards.
	function rules.giftStatus(state: PlayerState, now: number): GiftStatus
		local played = rules.dailyPlaytime(state, now)
		local claimed = claimedToday(state, now)
		local gifts, readyCount, nextSeconds = {}, 0, nil
		for index, gift in config.gifts do
			local secondsLeft = math.max(0, gift.minutes * 60 - played)
			local status = if table.find(claimed, index)
				then "Claimed"
				elseif secondsLeft <= 0 then "Ready"
				else "Waiting"
			if status == "Ready" then
				readyCount += 1
			elseif status == "Waiting" and (nextSeconds == nil or secondsLeft < nextSeconds) then
				nextSeconds = secondsLeft
			end
			table.insert(gifts, {
				index = index,
				minutes = gift.minutes,
				status = status,
				secondsLeft = secondsLeft,
				rewards = previewRewards(gift.rewards),
			})
		end
		return { gifts = gifts, readyCount = readyCount, nextSeconds = nextSeconds }
	end

	-- Claims gift `index` (into config.gifts): only once its play time is reached
	-- today, and once per day.
	function rules.claimGift(state: PlayerState, index: number, now: number, random: () -> number): RewardsResult
		local function reject(reason: string): RewardsResult
			return { ok = false, reason = reason, state = state, rewards = {} }
		end
		local gift = config.gifts[index]
		if gift == nil then
			return reject("UnknownGift")
		end
		if table.find(claimedToday(state, now), index) then
			return reject("GiftClaimed")
		end
		if rules.dailyPlaytime(state, now) < gift.minutes * 60 then
			return reject("GiftNotReady")
		end
		local newState, paid = payRewards(state, gift.rewards, random)
		newState.giftsClaimed = table.clone(state.giftsClaimed)
		table.insert(newState.giftsClaimed, index)
		return { ok = true, state = newState, rewards = paid }
	end

	-- Today's calendar day and whether it can still be claimed: a claim yesterday continues
	-- the series (after day 7 back to day 1), a claim today means claimed, anything older
	-- starts over at day 1. A claim on a later day than today (clock of another server
	-- ahead) counts as claimed, so the reward cannot be taken twice.
	local function loginToday(state: PlayerState, now: number): (number, boolean)
		local today = rules.dayNumber(now)
		if state.loginClaimDay >= today then
			return math.max(1, state.loginStreak), false
		elseif state.loginClaimDay == today - 1 then
			return state.loginStreak % #config.loginCalendar + 1, true
		end
		return 1, true
	end

	-- The login calendar on the German day of `now`: today's calendar day, whether it can be
	-- claimed, and all days (config.loginCalendar) with status and rewards.
	function rules.loginCalendar(state: PlayerState, now: number): LoginCalendar
		local today, claimable = loginToday(state, now)
		local days = {}
		for day, entry in config.loginCalendar do
			local status = if day < today or (day == today and not claimable)
				then "Claimed"
				elseif day == today then "Ready"
				else "Waiting"
			table.insert(days, { day = day, status = status, rewards = previewRewards(entry.rewards) })
		end
		return { today = today, claimable = claimable, days = days }
	end

	-- Claims today's login reward (once per German day) and moves the series on.
	function rules.claimLoginReward(state: PlayerState, now: number, random: () -> number): LoginClaimResult
		local today, claimable = loginToday(state, now)
		if not claimable then
			return { ok = false, reason = "LoginClaimed", state = state, rewards = {}, day = 0 }
		end
		local newState, paid = payRewards(state, config.loginCalendar[today].rewards, random)
		newState.loginStreak = today
		newState.loginClaimDay = rules.dayNumber(now)
		return { ok = true, state = newState, rewards = paid, day = today }
	end

	-- The calendar opens by itself on the first join of each German day: succeeds (and
	-- remembers the day) only if it has not opened yet today.
	function rules.markLoginCalendarShown(state: PlayerState, now: number): Result
		local today = rules.dayNumber(now)
		if state.loginShownDay >= today then
			return fail(state, "CalendarShown")
		end
		local newState = table.clone(state)
		newState.loginShownDay = today
		return { ok = true, state = newState }
	end

	-- The order the ringing phone offers (nil = phone is quiet).
	function rules.deliveryCall(state: PlayerState): Order?
		return state.delivery.call
	end

	-- The accepted order being delivered (nil = none).
	function rules.activeOrder(state: PlayerState): Order?
		return state.delivery.order
	end

	-- Seconds left to deliver the active order (0 = none or time is up).
	function rules.orderTimeLeft(state: PlayerState, now: number): number
		local order = state.delivery.order
		return if order and order.expiresAt then math.max(0, order.expiresAt - now) else 0
	end

	-- A copy of the state with a changed delivery part; `nextCallAt` set when the phone
	-- should stay quiet for a call interval from `now`.
	local function withDelivery(state: PlayerState, call: Order?, order: Order?, quietFrom: number?): PlayerState
		local newState = table.clone(state)
		newState.delivery = {
			call = call,
			order = order,
			nextCallAt = if quietFrom
				then quietFrom + config.delivery.callIntervalSeconds
				else state.delivery.nextCallAt,
		}
		return newState
	end

	-- The phone rings with a new order offer, if it is time. It stays quiet during the
	-- tutorial, while a call waits or an order runs, and for a call interval after one ended.
	function rules.ringPhone(state: PlayerState, now: number, random: () -> number): Result
		if rules.tutorial(state) ~= nil then
			return fail(state, "TutorialRunning")
		end
		if state.delivery.call then
			return fail(state, "CallWaiting")
		end
		if state.delivery.order then
			return fail(state, "OrderActive")
		end
		if now < (state.delivery.nextCallAt or -math.huge) then
			return fail(state, "PhoneNotReady")
		end
		return { ok = true, state = withDelivery(state, newOrder(state, random), nil) }
	end

	-- Takes the offered order: it becomes the active order, to be delivered within the time limit.
	function rules.acceptOrder(state: PlayerState, now: number): Result
		local call = state.delivery.call
		if call == nil then
			return fail(state, "NoCall")
		end
		local order = table.clone(call)
		order.expiresAt = now + config.delivery.timeLimitSeconds
		return { ok = true, state = withDelivery(state, nil, order) }
	end

	-- Whether the pizza holds exactly the order's toppings (nothing missing, nothing extra).
	local function pizzaMatches(pizza: { string }, order: Order): boolean
		local counts = {}
		for _, toppingId in pizza do
			counts[toppingId] = (counts[toppingId] or 0) + 1
		end
		for toppingId, count in order.toppings do
			if counts[toppingId] ~= count then
				return false
			end
			counts[toppingId] = nil
		end
		return next(counts) == nil
	end

	-- What delivering the active order at `now` would give: faster = more.
	-- Coins: topping values x pet bonus x coin potion x coinFactor x speed.
	-- Gems: base x speed (rounded, at most gemsMax). Potion: 1, or 2 in the fast part of the time.
	-- Speed = 1 + speedBonus x share of the time left.
	-- `worldId` = world of the van (pet cap, #51; nil = uncapped).
	function rules.orderReward(state: PlayerState, now: number, worldId: string?): DeliveryReward?
		local order = state.delivery.order
		if order == nil then
			return nil
		end
		local delivery = config.delivery
		local share = math.clamp(rules.orderTimeLeft(state, now) / delivery.timeLimitSeconds, 0, 1)
		local speed = 1 + delivery.speedBonus * share
		if order.reward == "Gems" then
			return { reward = "Gems", amount = math.min(delivery.gemsMax, math.round((order.gems or 0) * speed)) }
		elseif order.reward == "Potion" then
			local amount = if share >= delivery.fastPotionShare then 2 else 1
			return { reward = "Potion", amount = amount, potionId = order.potionId }
		end
		local value = 0
		for toppingId, count in order.toppings do
			value += config.toppings[toppingId].value * count
		end
		local multiplier = rules.coinMultiplier(state, worldId)
			* rules.potionCoinMultiplier(state)
			* delivery.coinFactor
		-- The epsilon guards against float noise (see sellPizza).
		return { reward = "Coins", amount = math.floor(value * multiplier * speed + 1e-6) }
	end

	-- Hands the order pizza over at the delivery van. The pizza must hold exactly the
	-- ordered toppings; they are used up (not sold) and the reward is paid out.
	function rules.deliverOrder(state: PlayerState, now: number, worldId: string?): DeliveryResult
		local function reject(reason: string): DeliveryResult
			return { ok = false, reason = reason, state = state }
		end
		local order = state.delivery.order
		if order == nil then
			return reject("NoOrder")
		end
		if rules.orderTimeLeft(state, now) <= 0 then
			return reject("OrderExpired")
		end
		if not pizzaMatches(state.pizza, order) then
			return reject("WrongToppings")
		end
		local reward = rules.orderReward(state, now, worldId) :: DeliveryReward
		local newState = withDelivery(state, nil, nil, now)
		newState.pizza = {}
		if reward.reward == "Coins" then
			newState.coins = state.coins + reward.amount
			newState.totalCoinsEarned = state.totalCoinsEarned + reward.amount
		elseif reward.reward == "Gems" then
			newState.gems = state.gems + reward.amount
		elseif reward.potionId then
			newState.potions = table.clone(state.potions)
			newState.potions[reward.potionId] = rules.potionCount(state, reward.potionId) + reward.amount
		end
		return { ok = true, state = newState, reward = reward }
	end

	-- Ends the active order once its time is up. Nothing is lost but the reward: the
	-- pizza stays as it is. The phone rings again after a call interval.
	function rules.expireOrder(state: PlayerState, now: number): Result
		if state.delivery.order == nil then
			return fail(state, "NoOrder")
		end
		if rules.orderTimeLeft(state, now) > 0 then
			return fail(state, "NotExpired")
		end
		return { ok = true, state = withDelivery(state, nil, nil, now) }
	end

	-- Turns the offered order down; the phone rings again after a call interval.
	function rules.declineOrder(state: PlayerState, now: number): Result
		if state.delivery.call == nil then
			return fail(state, "NoCall")
		end
		return { ok = true, state = withDelivery(state, nil, nil, now) }
	end

	-- Leaderboards ----------------------------------------------------------------

	-- Whole-number scores for the global leaderboards (ordered DataStores only take
	-- integers), keyed by the board ids in config.leaderboards.boards.
	function rules.leaderboardScores(state: PlayerState): LeaderboardScores
		return {
			Playtime = math.floor(state.totalPlaytimeSeconds),
			CoinsEarned = math.floor(state.totalCoinsEarned),
			Rebirths = math.floor(state.rebirths),
		}
	end

	-- Rebirth -------------------------------------------------------------------

	-- Coin price of the next rebirth: startPrice x priceFactor ^ rebirths done.
	local function rebirthPrice(state: PlayerState): number
		local rebirth = config.rebirth
		return math.floor(rebirth.startPrice * rebirth.priceFactor ^ state.rebirths + 0.5)
	end

	function rules.rebirthOffer(state: PlayerState): RebirthOffer
		local price = rebirthPrice(state)
		local after = table.clone(state)
		after.rebirths = state.rebirths + 1
		return {
			rebirths = state.rebirths,
			price = price,
			multiplier = rules.rebirthMultiplier(state),
			nextMultiplier = rules.rebirthMultiplier(after),
			progress = math.min(1, state.coins / price),
			affordable = state.coins >= price,
			potionWarning = next(state.activePotions) ~= nil,
		}
	end

	-- Pays the price and starts over with a higher coin multiplier. Reset: coins, coin
	-- upgrades, bought worlds, pizza, last world, call and order (the phone rings again
	-- after a call interval from `now`); running potions end. Everything else stays
	-- (pets, gems, gem upgrades, potion inventory, tutorial, lifetime totals, ...).
	function rules.rebirth(state: PlayerState, now: number): Result
		if state.coins < rebirthPrice(state) then
			return fail(state, "NotEnoughCoins")
		end
		local newState = withDelivery(state, nil, nil, now)
		newState.rebirths = state.rebirths + 1
		newState.coins = 0
		newState.upgrades = {}
		for upgradeId, level in state.upgrades do
			local upgrade = config.upgrades[upgradeId]
			if upgrade and upgrade.currency == "Gems" then
				newState.upgrades[upgradeId] = level
			end
		end
		newState.unlockedWorlds = {}
		newState.pizza = {}
		newState.lastWorldId = ""
		newState.activePotions = {}
		return { ok = true, state = newState }
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
	-- With `worldId` (#51) the pets are ranked by what they count in that world (petBonusIn),
	-- ties by their full bonus.
	function rules.equipBest(state: PlayerState, worldId: string?): Result
		if #state.pets == 0 then
			return fail(state, "NoPets")
		end

		local ranked = table.clone(state.pets)
		table.sort(ranked, function(a, b)
			local countsA, countsB = rules.petBonusIn(a.petId, worldId), rules.petBonusIn(b.petId, worldId)
			if countsA ~= countsB then
				return countsA > countsB
			end
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
