--!strict
-- Admin panel actions (#74): pure Luau without Roblox API, tested in Lune
-- (tests/AdminActions.spec.luau). Like the game rules, every action works on a
-- PlayerState and returns { ok, reason?, state } without changing the old state.
-- Rules, config and feature switches are passed in, nothing is required here.
--
--   local admin = AdminActions.new(rules, GameConfig, Features.new(GameConfig.features))
--   admin.isAdmin(player.UserId)              -- GameConfig.admin.userIds
--   admin.list()                              -- actions for the panel (id, params, confirm)
--   admin.run(userId, state, actionId, args, { now = os.time(), random = math.random })
--
-- `run` checks everything the client could fake: the user id, the action id, the
-- action's feature switch and every argument (type, integer, bounds, choices).
--
-- NEW ACTION = ONE ENTRY in BUILT_IN below (later tickets add theirs there):
--   {
--     id = "spinWheel",               -- texts: admin.action.<id> (de + en in Texts)
--     feature = "luckyWheel",         -- optional: hidden and refused while switched off
--     confirm = true,                 -- optional: the panel asks once more before running
--     params = {                      -- texts: admin.param.<name>
--       { name = "count", kind = "integer", min = 1, max = 10, default = 1 },
--       { name = "pet", kind = "choice", names = "pet", choices = function(config) ... end },
--     },
--     run = function(env, state, args, ctx) ... return { ok = true, state = newState } end,
--   }
-- `args` arrive already checked, in `params` order. `env` = { rules, config },
-- `ctx` = { now, random }. Choice `names` tells the panel how to show a value:
-- "pet" | "potion" | "upgrade" | "topping" (config entry names) | "world" (world names)
-- | "variant" (Texts pets.variant.<id>) | "yesNo" (Texts admin.choice.<id>); missing = id.
-- Failure reasons: NotAdmin | UnknownAction | FeatureOff | InvalidArgument | rule reasons.

export type Param = {
	name: string,
	kind: "integer" | "choice",
	min: number?,
	max: number?,
	default: any?,
	names: string?,
	-- Definitions give a function of the config; `list` returns the resolved list.
	choices: any?,
}

export type Context = { now: number, random: () -> number }

export type Env = { rules: any, config: any }

export type Result = { ok: boolean, reason: string?, state: any }

export type Definition = {
	id: string,
	feature: string?,
	confirm: boolean?,
	params: { Param },
	run: (env: Env, state: any, args: { any }, ctx: Context) -> Result,
}

export type ActionInfo = {
	id: string,
	confirm: boolean,
	params: { Param },
}

export type Admin = {
	isAdmin: (userId: number) -> boolean,
	list: () -> { ActionInfo },
	run: (userId: number, state: any, actionId: string, args: { any }, ctx: Context) -> Result,
}

local MAX_AMOUNT = 1e15

local function fail(state: any, reason: string): Result
	return { ok = false, reason = reason, state = state }
end

local function sortedKeys(map: { [string]: any }): { string }
	local keys = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

local function petIds(config: any): { string }
	return sortedKeys(config.pets)
end

local function potionIds(config: any): { string }
	return sortedKeys(config.potions)
end

local function upgradeIds(config: any): { string }
	return sortedKeys(config.upgrades)
end

local function toppingIds(config: any): { string }
	return sortedKeys(config.toppings)
end

-- Worlds with a Secret pet (#81), in world order.
local function secretWorldIds(config: any): { string }
	local list = {}
	for _, world in config.worlds do
		if world.secretPet and config.pets[world.secretPet] then
			table.insert(list, world.id)
		end
	end
	return list
end

-- Pet variants (#80) in merge order ("Normal" only without the config).
local function variantIds(config: any): { string }
	return if config.petVariants then table.clone(config.petVariants.order) else { "Normal" }
end

local function worldIds(config: any): { string }
	local list = {}
	for _, world in config.worlds do
		table.insert(list, world.id)
	end
	return list
end

-- Day fields of the PlayerState that hold a German day number (GameRules.dayNumber;
-- 0 = never). skipDays moves them back so "today" looks like a later day.
-- New daily/weekly mechanics (quests, wheel, chests, ...) add their day fields here.
local DAY_FIELDS = {
	"playtimeDay",
	"loginClaimDay",
	"loginShownDay",
	"wheelDay",
	"questDay",
	"questStreakDay",
	"questWeekDay",
	-- Hidden chests (#100): GameRules secretChestField of every GameConfig.hiddenChests world.
	"chestDayBeach",
	"chestDayCandyLand",
	"chestDayJungleTemple",
	"chestDayDinoAge",
	"chestDayPizzaParadise",
}

local AdminActions = {}

-- Read by the tests (every hidden chest world has its day field here).
AdminActions.DAY_FIELDS = DAY_FIELDS

-- Built-in actions in panel order. Only for features that exist; later tickets
-- (quests, weather, merchant, pet variants, ...) add their own entries here.
AdminActions.BUILT_IN = {
	{
		id = "addCoins",
		params = { { name = "amount", kind = "integer", min = -MAX_AMOUNT, max = MAX_AMOUNT, default = 1000000 } },
		run = function(_env, state, args)
			-- Not counted as earned (leaderboard "Münzen verdient" stays honest).
			local newState = table.clone(state)
			newState.coins = math.max(0, state.coins + args[1])
			return { ok = true, state = newState }
		end,
	},
	{
		id = "addGems",
		params = { { name = "amount", kind = "integer", min = -MAX_AMOUNT, max = MAX_AMOUNT, default = 1000 } },
		run = function(_env, state, args)
			local newState = table.clone(state)
			newState.gems = math.max(0, state.gems + args[1])
			return { ok = true, state = newState }
		end,
	},
	{
		id = "givePet",
		params = {
			{ name = "pet", kind = "choice", names = "pet", choices = petIds },
			{ name = "count", kind = "integer", min = 1, max = 100, default = 1 },
		},
		run = function(env, state, args, ctx)
			-- Same inventory limit as hatching (raise it with setUpgrade InventorySpace).
			return env.rules.givePets(state, args[1], args[2], nil, nil, ctx.now)
		end,
	},
	{
		id = "givePotion",
		params = {
			{ name = "potion", kind = "choice", names = "potion", choices = potionIds },
			{ name = "count", kind = "integer", min = 1, max = 999, default = 5 },
		},
		run = function(_env, state, args)
			local newState = table.clone(state)
			newState.potions = table.clone(state.potions)
			newState.potions[args[1]] = (state.potions[args[1]] or 0) + args[2]
			return { ok = true, state = newState }
		end,
	},
	{
		id = "setRebirths",
		params = { { name = "count", kind = "integer", min = 0, max = 1000, default = 1 } },
		run = function(_env, state, args)
			local newState = table.clone(state)
			newState.rebirths = args[1]
			return { ok = true, state = newState }
		end,
	},
	{
		id = "unlockWorld",
		params = { { name = "world", kind = "choice", names = "world", choices = worldIds } },
		run = function(env, state, args)
			-- Unlocks the world and every world before it; price and rebirths are skipped.
			local newState = table.clone(state)
			newState.unlockedWorlds = table.clone(state.unlockedWorlds)
			local added = false
			for _, world in env.config.worlds do
				if not env.rules.isWorldUnlocked(newState, world.id) then
					table.insert(newState.unlockedWorlds, world.id)
					added = true
				end
				if world.id == args[1] then
					break
				end
			end
			if not added then
				return fail(state, "AlreadyUnlocked")
			end
			return { ok = true, state = newState }
		end,
	},
	{
		id = "setUpgrade",
		params = {
			{ name = "upgrade", kind = "choice", names = "upgrade", choices = upgradeIds },
			{ name = "level", kind = "integer", min = 0, max = 100, default = 1 },
		},
		run = function(env, state, args)
			local upgradeId, level = args[1], args[2]
			if level > #env.config.upgrades[upgradeId].levels then
				return fail(state, "InvalidArgument")
			end
			local newState = table.clone(state)
			newState.upgrades = table.clone(state.upgrades)
			newState.upgrades[upgradeId] = if level > 0 then level else nil
			return { ok = true, state = newState }
		end,
	},
	{
		id = "finishTutorial",
		params = {},
		run = function(env, state)
			local tutorial = env.rules.tutorial(state)
			if tutorial == nil then
				return fail(state, "TutorialDone")
			end
			local newState = table.clone(state)
			newState.tutorialStep = tutorial.total + 1
			return { ok = true, state = newState }
		end,
	},
	{
		id = "skipDays",
		params = { { name = "days", kind = "integer", min = 1, max = 30, default = 1 } },
		run = function(_env, state, args)
			local newState = table.clone(state)
			for _, field in DAY_FIELDS do
				if (state[field] or 0) > 0 then
					newState[field] = state[field] - args[1]
				end
			end
			return { ok = true, state = newState }
		end,
	},
	{
		-- #94: test selling golden toppings without waiting for a 1 % spawn.
		id = "giveGoldenToppings",
		feature = "goldenToppings",
		params = {
			{ name = "topping", kind = "choice", names = "topping", choices = toppingIds },
			{ name = "count", kind = "integer", min = 1, max = 100, default = 5 },
		},
		run = function(env, state, args)
			local room = env.rules.pizzaCapacity(state) - #state.pizza
			if room <= 0 then
				return fail(state, "PizzaFull")
			end
			local toppingId, count = args[1], math.min(args[2], room)
			local newState = table.clone(state)
			newState.pizza = table.clone(state.pizza)
			newState.pizzaGolden = env.rules.goldenOnPizza(state)
			for _ = 1, count do
				table.insert(newState.pizza, toppingId)
			end
			newState.pizzaGolden[toppingId] = (newState.pizzaGolden[toppingId] or 0) + count
			return { ok = true, state = newState }
		end,
	},
	{
		-- #94: golden chance for this player in percent (wins when above the real chance;
		-- 0 = off again). Makes the glitter on the field easy to check.
		id = "setGoldenChance",
		feature = "goldenToppings",
		params = { { name = "percent", kind = "integer", min = 0, max = 100, default = 100 } },
		run = function(_env, state, args)
			local newState = table.clone(state)
			newState.adminGoldenChance = args[1] / 100
			return { ok = true, state = newState }
		end,
	},
	{
		-- "What's new" window (#106) opens again on the next join.
		id = "resetWhatsNew",
		feature = "whatsNew",
		params = {},
		run = function(env, state)
			local index = table.find(state.seenHints, env.config.spawnMarket.whatsNewHint)
			if index == nil then
				return fail(state, "NotSeen")
			end
			local newState = table.clone(state)
			newState.seenHints = table.clone(state.seenHints)
			table.remove(newState.seenHints, index)
			return { ok = true, state = newState }
		end,
	},
	{
		-- Every one-time hint (#113 feature hints, gifts, rebirth, "What's new") shows again.
		id = "resetHints",
		params = {},
		run = function(_env, state)
			if #state.seenHints == 0 then
				return fail(state, "NotSeen")
			end
			local newState = table.clone(state)
			newState.seenHints = {}
			return { ok = true, state = newState }
		end,
	},
	{
		-- The Secret pet of a world (#81) straight into the inventory (no hatch, no announcement).
		id = "giveSecretPet",
		feature = "secretPets",
		params = { { name = "world", kind = "choice", names = "world", choices = secretWorldIds } },
		run = function(env, state, args)
			if #state.pets + 1 > env.rules.inventorySlots(state) then
				return fail(state, "InventoryFull")
			end
			local petId
			for _, world in env.config.worlds do
				if world.id == args[1] then
					petId = world.secretPet
				end
			end
			local newState = table.clone(state)
			newState.pets = table.clone(state.pets)
			table.insert(newState.pets, { uid = state.nextPetUid, petId = petId })
			newState.nextPetUid = state.nextPetUid + 1
			return { ok = true, state = newState }
		end,
	},
	{
		-- Test chance for the Secret roll per egg (#81): real hatch incl. animation and
		-- the announcement on all servers. 0 = normal chance again.
		id = "setSecretChance",
		feature = "secretPets",
		params = { { name = "percent", kind = "integer", min = 0, max = 100, default = 100 } },
		run = function(_env, state, args)
			local newState = table.clone(state)
			newState.adminSecretChance = args[1] / 100
			return { ok = true, state = newState }
		end,
	},
	{
		-- World intros (#79) play again: right away in the current world, else on entering.
		id = "resetWorldIntros",
		feature = "worldIntro",
		params = {},
		run = function(_env, state)
			if #state.seenWorldIntros == 0 then
				return fail(state, "NotSeen")
			end
			local newState = table.clone(state)
			newState.seenWorldIntros = {}
			return { ok = true, state = newState }
		end,
	},
	{
		-- A pet with variant (Normal/Gold/Rainbow) and Shiny flag (#80), within the inventory limit.
		id = "givePetVariant",
		params = {
			{ name = "pet", kind = "choice", names = "pet", choices = petIds },
			{ name = "variant", kind = "choice", names = "variant", choices = variantIds },
			{ name = "shiny", kind = "choice", names = "yesNo", choices = { "no", "yes" } },
			{ name = "count", kind = "integer", min = 1, max = 100, default = 5 },
		},
		run = function(env, state, args, ctx)
			return env.rules.givePets(state, args[1], args[4], args[2], args[3] == "yes", ctx.now)
		end,
	},
	{
		-- Test chance for the Shiny roll per hatched pet (#80); 0 = normal chance again.
		id = "setShinyChance",
		feature = "shinyPets",
		params = { { name = "percent", kind = "integer", min = 0, max = 100, default = 100 } },
		run = function(_env, state, args)
			local newState = table.clone(state)
			newState.adminShinyChance = args[1] / 100
			return { ok = true, state = newState }
		end,
	},
	{
		-- Level of the equipped pets (or all pets) for testing pet levels (#90), XP 0.
		id = "setPetLevel",
		feature = "petLevels",
		params = {
			{ name = "petLevel", kind = "integer", min = 1, max = 10, default = 10 },
			{ name = "allPets", kind = "choice", names = "yesNo", choices = { "no", "yes" } },
		},
		run = function(env, state, args)
			return env.rules.setPetLevels(state, args[1], args[2] == "yes")
		end,
	},
	{
		-- Play time as XP for the equipped pets (#90), e.g. to get just below a level up.
		id = "givePetXp",
		feature = "petLevels",
		params = { { name = "minutes", kind = "integer", min = 1, max = 600, default = 4 } },
		run = function(env, state, args)
			return env.rules.addPetXp(state, args[1] * 60)
		end,
	},
	{
		-- Lucky wheel (#98): today's free spins (daily + play time bonus) are available again.
		id = "resetWheelSpins",
		feature = "luckyWheel",
		params = {},
		run = function(env, state)
			return env.rules.resetWheelSpins(state)
		end,
	},
	{
		-- Travelling merchant (#107): comes for this admin right now for one visit (with the
		-- exclusive pet), whatever the clock says.
		id = "spawnMerchant",
		feature = "travelingMerchant",
		params = {},
		run = function(env, state, _args, ctx)
			return env.rules.forceMerchant(state, ctx.now)
		end,
	},
	{
		-- Login calendar (#101): makes the chosen day claimable today (e.g. 30 = calendar pet).
		id = "setCalendarDay",
		feature = "loginCalendar30",
		params = { { name = "day", kind = "integer", min = 1, max = 30, default = 30 } },
		run = function(env, state, args, ctx)
			return env.rules.setLoginCalendarDay(state, args[1], ctx.now)
		end,
	},
	{
		-- Codes (#99): every code can be redeemed again.
		id = "resetCodes",
		feature = "codes",
		params = {},
		run = function(env, state)
			return env.rules.resetCodes(state)
		end,
	},
	{
		-- Quests (#97): finishes a daily/weekly quest (claiming stays in the quest menu).
		-- Makes today's quests first if there are none yet.
		id = "completeQuest",
		feature = "dailyQuests",
		params = {
			{ name = "period", kind = "choice", names = "yesNo", choices = { "Daily", "Weekly" } },
			{ name = "quest", kind = "integer", min = 1, max = 5, default = 1 },
		},
		run = function(env, state, args, ctx)
			local refreshed = env.rules.refreshQuests(state, ctx.now, ctx.random)
			return env.rules.completeQuest(if refreshed.ok then refreshed.state else state, args[1], args[2])
		end,
	},
	{
		-- New daily and weekly quests at once (rerolls and bonus chest of today start over).
		id = "rerollQuests",
		feature = "dailyQuests",
		params = {},
		run = function(env, state, _args, ctx)
			return env.rules.refreshQuests(state, ctx.now, ctx.random, true)
		end,
	},
	{
		id = "completePetIndex",
		feature = "petIndex",
		params = { { name = "world", kind = "choice", names = "world", choices = worldIds } },
		run = function(env, state, args)
			-- Marks every index pet of the world as found (#95), without giving pets.
			local petIds = env.rules.indexPets(args[1])
			local owned = table.clone(state.petsOwnedEver or {})
			local added = false
			for _, petId in petIds do
				if not env.rules.hasOwnedPet(state, petId) then
					owned[petId] = true
					added = true
				end
			end
			if not added then
				return fail(state, "IndexComplete")
			end
			local newState = table.clone(state)
			newState.petsOwnedEver = owned
			return { ok = true, state = newState }
		end,
	},
	{
		-- Friends bonus (#102): pretend to have this many friends on the server; 0 = real count.
		id = "simulateFriends",
		feature = "friendsBonus",
		params = { { name = "friends", kind = "integer", min = 0, max = 5, default = 3 } },
		run = function(_env, state, args)
			local newState = table.clone(state)
			newState.adminFriends = args[1]
			return { ok = true, state = newState }
		end,
	},
	{
		-- Weather (#105): starts the chosen world's weather now for its full length. The
		-- weather is shared by the server, so the state stays as it is; AdminService then
		-- tells WeatherService (Weather.activeAt with `forcedAt`).
		id = "startWeather",
		feature = "weather",
		params = {
			{
				name = "world",
				kind = "choice",
				names = "world",
				choices = function(config)
					local list = {}
					for _, world in config.worlds do
						if world.weather and config.weathers and config.weathers[world.weather] then
							table.insert(list, world.id)
						end
					end
					return list
				end,
			},
		},
		run = function(_env, state)
			return { ok = true, state = state }
		end,
	},
	{
		-- Lifetime stats (#103): raises a lifetime counter (badges are then awarded at once).
		id = "addStat",
		feature = "stats",
		params = {
			{ name = "stat", kind = "choice", choices = { "CoinsEarned", "ToppingsCollected", "EggsOpened" } },
			{ name = "amount", kind = "integer", min = 0, max = MAX_AMOUNT, default = 1000 },
		},
		run = function(_env, state, args)
			local field = ({
				CoinsEarned = "totalCoinsEarned",
				ToppingsCollected = "toppingsCollected",
				EggsOpened = "eggsOpened",
			})[args[1]]
			local newState = table.clone(state)
			newState[field] = (state[field] or 0) + args[2]
			return { ok = true, state = newState }
		end,
	},
	{
		-- Titles (#103): the admin holds the "Weekly Champion" title for this many days.
		id = "giveWeeklyChampion",
		feature = "titles",
		params = { { name = "days", kind = "integer", min = 1, max = 14, default = 7 } },
		run = function(env, state, args, ctx)
			return env.rules.grantWeeklyChampion(state, ctx.now + args[1] * 86400)
		end,
	},
	{
		id = "resetProgress",
		confirm = true,
		params = {},
		run = function(env, state)
			-- Progress only: the player's own settings (#76, volume, graphics) stay.
			local newState = env.rules.newPlayerState()
			newState.settings = table.clone(state.settings or {})
			return { ok = true, state = newState }
		end,
	},
} :: { Definition }

local function validArgument(param: Param, value: any): boolean
	if param.kind == "integer" then
		return type(value) == "number"
			and value == value
			and math.floor(value) == value
			and value >= (param.min or -math.huge)
			and value <= (param.max or math.huge)
	elseif param.kind == "choice" then
		return type(value) == "string" and table.find(param.choices :: { string }, value) ~= nil
	end
	return false
end

-- `definitions` defaults to AdminActions.BUILT_IN (tests pass their own).
function AdminActions.new(rules: any, config: any, features: any, definitions: { Definition }?): Admin
	local env: Env = { rules = rules, config = config }
	local admins: { number } = config.admin.userIds

	-- Resolve choices once; also checks every feature id (unknown ids raise an error).
	local actions: { { definition: Definition, info: ActionInfo } } = {}
	local byId: { [string]: { definition: Definition, info: ActionInfo } } = {}
	for _, definition in definitions or AdminActions.BUILT_IN do
		if definition.feature then
			features.enabled(definition.feature)
		end
		local params = {}
		for _, param in definition.params do
			local resolved = table.clone(param)
			if type(param.choices) == "function" then
				resolved.choices = param.choices(config)
			end
			if resolved.kind == "choice" and resolved.default == nil then
				resolved.default = (resolved.choices :: { string })[1]
			end
			table.insert(params, resolved)
		end
		local entry = {
			definition = definition,
			info = { id = definition.id, confirm = definition.confirm == true, params = params },
		}
		table.insert(actions, entry)
		byId[definition.id] = entry
	end

	local function isOn(definition: Definition): boolean
		return definition.feature == nil or features.enabled(definition.feature)
	end

	local function isAdmin(userId: number): boolean
		return table.find(admins, userId) ~= nil
	end

	local function list(): { ActionInfo }
		local out = {}
		for _, entry in actions do
			if isOn(entry.definition) then
				table.insert(out, entry.info)
			end
		end
		return out
	end

	local function run(userId: number, state: any, actionId: string, args: { any }, ctx: Context): Result
		if not isAdmin(userId) then
			return fail(state, "NotAdmin")
		end
		local entry = if type(actionId) == "string" then byId[actionId] else nil
		if entry == nil then
			return fail(state, "UnknownAction")
		end
		if not isOn(entry.definition) then
			return fail(state, "FeatureOff")
		end
		if type(args) ~= "table" then
			return fail(state, "InvalidArgument")
		end
		local checked = {}
		for index, param in entry.info.params do
			if not validArgument(param, args[index]) then
				return fail(state, "InvalidArgument")
			end
			checked[index] = args[index]
		end
		return entry.definition.run(env, state, checked, ctx)
	end

	return { isAdmin = isAdmin, list = list, run = run }
end

return AdminActions
