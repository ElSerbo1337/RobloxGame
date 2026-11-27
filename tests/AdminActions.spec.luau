local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local AdminActions = require("../src/shared/AdminActions")
local Features = require("../src/shared/Features")
local GameConfig = require("../src/shared/GameConfig")
local GameRules = require("../src/shared/GameRules")
local Texts = require("../src/shared/Texts")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local rules = GameRules.new(TestConfig)
local features = Features.new({
	adminPanel = true,
	loginCalendar30 = true,
	codes = false,
	luckyWheel = false,
	goldenToppings = true,
	whatsNew = true,
	petIndex = true,
	friendsBonus = true,
	secretPets = true,
	worldIntro = true,
	shinyPets = true,
	petLevels = true,
	dailyQuests = true,
	weeklyQuests = true,
	travelingMerchant = true,
	stats = true,
	titles = true,
})
local admin = AdminActions.new(rules, TestConfig, features)

local NOW = 1_800_000_000
local ctx = { now = NOW, random = TestKit.sequenceRandom({ 0.5 }) }

-- TestConfig admins: user 42 only.
local ADMIN = 42

local function player()
	local state = rules.newPlayerState()
	state.tutorialStep = 1000
	return state
end

local function ids(list: { any }): { string }
	local out = {}
	for _, info in list do
		table.insert(out, info.id)
	end
	return out
end

describe("admin access", function()
	it("accepts only the configured admin user ids", function()
		expect(admin.isAdmin(ADMIN)).toBe(true)
		expect(admin.isAdmin(43)).toBe(false)
		expect(admin.isAdmin(-1)).toBe(false)
	end)

	it("the real config lets exactly the developer (372358501) in", function()
		expect(GameConfig.admin.userIds).toEqual({ 372358501 })
		local real = AdminActions.new(GameRules.new(GameConfig), GameConfig, Features.new(GameConfig.features))
		expect(real.isAdmin(372358501)).toBe(true)
		expect(real.isAdmin(1)).toBe(false)
	end)

	it("refuses every action from a non-admin and leaves the state untouched", function()
		local state = player()

		local result = admin.run(43, state, "addCoins", { 1000 }, ctx)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("NotAdmin")
		expect(result.state).toBe(state)
	end)
end)

describe("admin registry", function()
	it("lists the built-in actions in panel order", function()
		expect(ids(admin.list())).toEqual({
			"addCoins",
			"addGems",
			"givePet",
			"givePotion",
			"setRebirths",
			"unlockWorld",
			"setUpgrade",
			"finishTutorial",
			"skipDays",
			"giveGoldenToppings",
			"setGoldenChance",
			"resetWhatsNew",
			"resetHints",
			"giveSecretPet",
			"setSecretChance",
			"resetWorldIntros",
			"givePetVariant",
			"setShinyChance",
			"setPetLevel",
			"givePetXp",
			"spawnMerchant",
			"setCalendarDay",
			"completeQuest",
			"rerollQuests",
			"completePetIndex",
			"simulateFriends",
			"addStat",
			"giveWeeklyChampion",
			"resetProgress",
		})
	end)

	it("describes parameters with bounds, defaults and the choices from the config", function()
		local byId = {}
		for _, info in admin.list() do
			byId[info.id] = info
		end

		local coins = byId.addCoins.params[1]
		expect(coins.name).toBe("amount")
		expect(coins.kind).toBe("integer")
		expect(coins.default > 0).toBe(true)

		local pet = byId.givePet.params[1]
		expect(pet.kind).toBe("choice")
		expect(pet.names).toBe("pet")
		expect(pet.choices).toEqual({ "Cat", "Dragon", "Hamster" })

		expect(byId.unlockWorld.params[1].choices).toEqual({ "PizzeriaGarden", "Farm", "Beach" })
		expect(byId.givePotion.params[1].choices).toEqual({ "Coins", "Luck", "Speed" })
		expect(byId.resetProgress.confirm).toBe(true)
		expect(byId.addCoins.confirm).toBe(false)
	end)

	it("has a German and English name for every action and parameter (real config)", function()
		local real = AdminActions.new(GameRules.new(GameConfig), GameConfig, Features.new(GameConfig.features))
		for _, info in real.list() do
			expect(Texts.strings[`admin.action.{info.id}`] ~= nil).toBe(true)
			for _, param in info.params do
				expect(Texts.strings[`admin.param.{param.name}`] ~= nil).toBe(true)
			end
		end
	end)

	it("refuses unknown actions", function()
		local result = admin.run(ADMIN, player(), "makeMeRich", {}, ctx)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("UnknownAction")
	end)

	it("a new action is one entry: it is listed and runs through the same checks", function()
		local custom = AdminActions.new(rules, TestConfig, features, {
			{
				id = "setCoins",
				params = { { name = "amount", kind = "integer", min = 0, max = 100, default = 5 } },
				run = function(_env, state, args)
					local newState = table.clone(state)
					newState.coins = args[1]
					return { ok = true, state = newState }
				end,
			},
		})

		expect(ids(custom.list())).toEqual({ "setCoins" })
		expect(custom.run(ADMIN, player(), "setCoins", { 7 }, ctx).state.coins).toBe(7)
		expect(custom.run(ADMIN, player(), "setCoins", { 101 }, ctx).reason).toBe("InvalidArgument")
		expect(custom.run(43, player(), "setCoins", { 7 }, ctx).reason).toBe("NotAdmin")
	end)

	it("hides and refuses actions whose feature is switched off", function()
		local custom = AdminActions.new(rules, TestConfig, features, {
			{
				id = "spinWheel",
				feature = "luckyWheel",
				params = {},
				run = function(_env, state)
					return { ok = true, state = state }
				end,
			},
		})

		expect(#custom.list()).toBe(0)
		expect(custom.run(ADMIN, player(), "spinWheel", {}, ctx).reason).toBe("FeatureOff")
	end)

	it("fails loudly for an action bound to an unknown feature id", function()
		local ok = pcall(AdminActions.new, rules, TestConfig, features, {
			{
				id = "x",
				feature = "noSuchFeature",
				params = {},
				run = function(_env, state)
					return { ok = true, state = state }
				end,
			},
		})

		expect(ok).toBe(false)
	end)
end)

describe("argument checks", function()
	it("rejects missing, non-integer, out-of-range and non-number amounts", function()
		for _, args in { {}, { 1.5 }, { 1e16 }, { "100" }, { 0 / 0 }, { math.huge } } do
			local result = admin.run(ADMIN, player(), "addCoins", args, ctx)
			expect(result.ok).toBe(false)
			expect(result.reason).toBe("InvalidArgument")
		end
	end)

	it("rejects choices that are not in the list", function()
		local result = admin.run(ADMIN, player(), "givePet", { "Unicorn", 1 }, ctx)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("InvalidArgument")
	end)

	it("rejects arguments that are not a list", function()
		expect(admin.run(ADMIN, player(), "addCoins", "lots" :: any, ctx).reason).toBe("InvalidArgument")
	end)
end)

describe("admin actions", function()
	it("addCoins adds (or removes, never below 0) coins without counting them as earned", function()
		local state = player()
		state.coins = 50

		local added = admin.run(ADMIN, state, "addCoins", { 1000 }, ctx)
		local removed = admin.run(ADMIN, state, "addCoins", { -500 }, ctx)

		expect(added.ok).toBe(true)
		expect(added.state.coins).toBe(1050)
		expect(added.state.totalCoinsEarned).toBe(0)
		expect(removed.state.coins).toBe(0)
		expect(state.coins).toBe(50)
	end)

	it("addGems adds (or removes, never below 0) gems", function()
		local state = player()
		state.gems = 10

		expect(admin.run(ADMIN, state, "addGems", { 25 }, ctx).state.gems).toBe(35)
		expect(admin.run(ADMIN, state, "addGems", { -99 }, ctx).state.gems).toBe(0)
	end)

	it("givePet adds pets with fresh uids, as long as the inventory has room", function()
		local state = player()

		local result = admin.run(ADMIN, state, "givePet", { "Dragon", 2 }, ctx)

		expect(result.ok).toBe(true)
		expect(result.state.pets).toEqual({
			{ uid = 1, petId = "Dragon", foundAt = NOW },
			{ uid = 2, petId = "Dragon", foundAt = NOW },
		})
		expect(result.state.nextPetUid).toBe(3)
		expect(#state.pets).toBe(0)

		-- TestConfig inventory: 5 slots.
		local full = admin.run(ADMIN, result.state, "givePet", { "Cat", 4 }, ctx)
		expect(full.ok).toBe(false)
		expect(full.reason).toBe("InventoryFull")
	end)

	it("givePotion adds potions to the potion inventory", function()
		local state = player()
		state.potions = { Luck = 1 }

		local result = admin.run(ADMIN, state, "givePotion", { "Luck", 3 }, ctx)

		expect(result.state.potions).toEqual({ Luck = 4 })
		expect(state.potions).toEqual({ Luck = 1 })
	end)

	it("setRebirths sets the number of rebirths (and so the multiplier)", function()
		local result = admin.run(ADMIN, player(), "setRebirths", { 4 }, ctx)

		expect(result.state.rebirths).toBe(4)
		expect(rules.rebirthMultiplier(result.state)).toBe(3)
	end)

	it("unlockWorld unlocks the world and every world before it, ignoring price and rebirths", function()
		local result = admin.run(ADMIN, player(), "unlockWorld", { "Beach" }, ctx)

		expect(result.ok).toBe(true)
		expect(result.state.unlockedWorlds).toEqual({ "Farm", "Beach" })
		expect(result.state.coins).toBe(0)
		expect(rules.isWorldUnlocked(result.state, "Beach")).toBe(true)
	end)

	it("unlockWorld reports an already unlocked world", function()
		local result = admin.run(ADMIN, player(), "unlockWorld", { "PizzeriaGarden" }, ctx)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("AlreadyUnlocked")
	end)

	it("setUpgrade sets an upgrade to any existing level (0 = not bought)", function()
		local result = admin.run(ADMIN, player(), "setUpgrade", { "InventorySpace", 2 }, ctx)

		expect(result.ok).toBe(true)
		expect(rules.inventorySlots(result.state)).toBe(10)

		local reset = admin.run(ADMIN, result.state, "setUpgrade", { "InventorySpace", 0 }, ctx)
		expect(reset.state.upgrades.InventorySpace).toBeNil()
		expect(rules.inventorySlots(reset.state)).toBe(5)

		local tooHigh = admin.run(ADMIN, player(), "setUpgrade", { "TripleOpen", 2 }, ctx)
		expect(tooHigh.ok).toBe(false)
		expect(tooHigh.reason).toBe("InvalidArgument")
	end)

	it("finishTutorial ends the tutorial; refuses when it is already over", function()
		local fresh = rules.newPlayerState()

		local result = admin.run(ADMIN, fresh, "finishTutorial", {}, ctx)

		expect(result.ok).toBe(true)
		expect(rules.tutorial(result.state)).toBeNil()
		expect(admin.run(ADMIN, result.state, "finishTutorial", {}, ctx).reason).toBe("TutorialDone")
	end)

	it("resetWhatsNew lets the What's new window open again; refuses when it was not seen (#106)", function()
		local hint = TestConfig.spawnMarket.whatsNewHint
		local seen = rules.markHintSeen(rules.newPlayerState(), hint).state

		local result = admin.run(ADMIN, seen, "resetWhatsNew", {}, ctx)

		expect(result.ok).toBe(true)
		expect(rules.hasSeenHint(result.state, hint)).toBe(false)
		expect(rules.hasSeenHint(seen, hint)).toBe(true)
		expect(admin.run(ADMIN, result.state, "resetWhatsNew", {}, ctx).reason).toBe("NotSeen")
	end)

	it("resetHints shows every one-time hint again; refuses when none was seen (#113)", function()
		local seen = rules.markHintSeen(rules.newPlayerState(), "Gifts").state

		local result = admin.run(ADMIN, seen, "resetHints", {}, ctx)

		expect(result.ok).toBe(true)
		expect(rules.hasSeenHint(result.state, "Gifts")).toBe(false)
		expect(rules.hasSeenHint(seen, "Gifts")).toBe(true)
		expect(admin.run(ADMIN, result.state, "resetHints", {}, ctx).reason).toBe("NotSeen")
	end)

	it("resetWorldIntros lets every world intro play again; refuses when none was seen (#79)", function()
		local state = player()
		state.unlockedWorlds = { "Farm" }
		local seen = rules.enterWorld(state, "Farm").state

		local result = admin.run(ADMIN, seen, "resetWorldIntros", {}, ctx)

		expect(result.ok).toBe(true)
		expect(result.state.seenWorldIntros).toEqual({})
		expect(rules.enterWorld(result.state, "Farm").intro).toBe(true)
		expect(seen.seenWorldIntros).toEqual({ "Farm" })
		expect(admin.run(ADMIN, result.state, "resetWorldIntros", {}, ctx).reason).toBe("NotSeen")
	end)

	it("skipDays makes today's daily things look like they happened days ago", function()
		local today = rules.dayNumber(NOW)
		local state = player()
		local claimed = rules.claimLoginReward(state, NOW, TestKit.sequenceRandom({ 0.5 })).state
		claimed = rules.addPlayTime(claimed, 600, NOW).state
		claimed = rules.markLoginCalendarShown(claimed, NOW).state
		claimed.giftsClaimed = { 1 }

		local result = admin.run(ADMIN, claimed, "skipDays", { 1 }, ctx)

		expect(result.ok).toBe(true)
		expect(result.state.loginClaimDay).toBe(today - 1)
		expect(result.state.loginShownDay).toBe(today - 1)
		expect(result.state.playtimeDay).toBe(today - 1)
		-- The calendar continues with day 2, gifts and daily play time start over.
		local calendar = rules.loginCalendar(result.state, NOW)
		expect(calendar.today).toBe(2)
		expect(calendar.claimable).toBe(true)
		expect(rules.dailyPlaytime(result.state, NOW)).toBe(0)
		expect(rules.giftStatus(result.state, NOW).gifts[1].status).toBe("Waiting")
		-- Total play time is not touched.
		expect(result.state.totalPlaytimeSeconds).toBe(600)
	end)

	it("skipDays over a week breaks the login series and leaves 'never' (0) days alone", function()
		local state = player()
		local claimed = rules.claimLoginReward(state, NOW, TestKit.sequenceRandom({ 0.5 })).state

		local result = admin.run(ADMIN, claimed, "skipDays", { 7 }, ctx)

		expect(rules.loginCalendar(result.state, NOW).today).toBe(1)
		expect(result.state.playtimeDay).toBe(0)
		expect(result.state.loginShownDay).toBe(0)
	end)

	it("resetProgress starts the player over with a fresh state but keeps the settings", function()
		local state = player()
		state.coins = 999
		state.rebirths = 3
		state.settings = { musicVolume = 40, graphics = "Low" }

		local result = admin.run(ADMIN, state, "resetProgress", {}, ctx)

		expect(result.ok).toBe(true)
		local expected = rules.newPlayerState()
		expected.settings = { musicVolume = 40, graphics = "Low" }
		expect(result.state).toEqual(expected)
	end)
end)

describe("admin actions for golden toppings (#94)", function()
	it("giveGoldenToppings puts golden toppings on the pizza, up to its capacity", function()
		local state = player()
		state.pizza = { "Salami" } -- capacity 2

		local result = admin.run(ADMIN, state, "giveGoldenToppings", { "Mozzarella", 5 }, ctx)

		expect(result.ok).toBe(true)
		expect(result.state.pizza).toEqual({ "Salami", "Mozzarella" })
		expect(rules.goldenOnPizza(result.state)).toEqual({ Mozzarella = 1 })
		expect(state.pizza).toEqual({ "Salami" })
	end)

	it("giveGoldenToppings fails on a full pizza and lists the config toppings", function()
		local state = player()
		state.pizza = { "Salami", "Salami" }
		local info
		for _, entry in admin.list() do
			if entry.id == "giveGoldenToppings" then
				info = entry
			end
		end

		expect(admin.run(ADMIN, state, "giveGoldenToppings", { "Salami", 1 }, ctx).reason).toBe("PizzaFull")
		expect(info.params[1].choices).toEqual({ "Ham", "Mozzarella", "Mushroom", "Onion", "Salami" })
		expect(info.params[1].names).toBe("topping")
	end)

	it("setGoldenChance sets the admin test chance in percent (0 = off)", function()
		local result = admin.run(ADMIN, player(), "setGoldenChance", { 100 }, ctx)
		local off = admin.run(ADMIN, result.state, "setGoldenChance", { 0 }, ctx)

		expect(result.ok).toBe(true)
		expect(result.state.adminGoldenChance).toBe(1)
		expect(off.state.adminGoldenChance).toBe(0)
		expect(admin.run(ADMIN, player(), "setGoldenChance", { 101 }, ctx).reason).toBe("InvalidArgument")
	end)

	it("hides both golden actions while the feature is off", function()
		local offAdmin = AdminActions.new(
			rules,
			TestConfig,
			Features.new({
				travelingMerchant = true,
				adminPanel = true,
				stats = true,
				titles = true,
				loginCalendar30 = true,
				codes = false,
				petLevels = true,
				luckyWheel = true,
				goldenToppings = false,
				whatsNew = true,
				petIndex = true,
				friendsBonus = true,
				secretPets = true,
				worldIntro = true,
				shinyPets = true,
				dailyQuests = true,
			})
		)

		expect(table.find(ids(offAdmin.list()), "setGoldenChance")).toBeNil()
		expect(offAdmin.run(ADMIN, player(), "giveGoldenToppings", { "Salami", 1 }, ctx).reason).toBe("FeatureOff")
	end)
end)

describe("admin Secret pet actions (#81)", function()
	-- TestConfig with a Secret pet in world 1 only.
	local config = table.clone(TestConfig)
	config.secretPets = { chance = 1 / 20000 }
	config.pets = table.clone(TestConfig.pets)
	config.pets.GhostPet = { displayName = "Geist", rarity = "Secret", bonus = 5 }
	config.worlds = table.clone(TestConfig.worlds)
	config.worlds[1] = table.clone(TestConfig.worlds[1])
	config.worlds[1].secretPet = "GhostPet"
	local secretRules = GameRules.new(config)
	local secretAdmin = AdminActions.new(secretRules, config, features)

	local function fresh()
		local state = secretRules.newPlayerState()
		state.tutorialStep = 1000
		return state
	end

	it("offers only worlds with a Secret pet", function()
		for _, info in secretAdmin.list() do
			if info.id == "giveSecretPet" then
				expect(info.params[1].choices).toEqual({ "PizzeriaGarden" })
				expect(info.params[1].names).toBe("world")
			end
		end
	end)

	it("giveSecretPet adds the world's Secret pet to the inventory", function()
		local state = fresh()
		local result = secretAdmin.run(ADMIN, state, "giveSecretPet", { "PizzeriaGarden" }, ctx)

		expect(result.ok).toBe(true)
		expect(result.state.pets[#result.state.pets].petId).toBe("GhostPet")
		expect(result.state.nextPetUid).toBe(state.nextPetUid + 1)
		expect(#state.pets).toBe(0)
		expect(secretAdmin.run(ADMIN, state, "giveSecretPet", { "Farm" }, ctx).reason).toBe("InvalidArgument")
	end)

	it("giveSecretPet respects the inventory limit", function()
		local state = fresh()
		for i = 1, secretRules.inventorySlots(state) do
			table.insert(state.pets, { uid = i, petId = "Hamster" })
		end
		expect(secretAdmin.run(ADMIN, state, "giveSecretPet", { "PizzeriaGarden" }, ctx).reason).toBe("InventoryFull")
	end)

	it("setSecretChance makes the next egg hatch the Secret pet (0 = off again)", function()
		local state = fresh()
		state.coins = 1000
		local on = secretAdmin.run(ADMIN, state, "setSecretChance", { 100 }, ctx).state
		expect(on.adminSecretChance).toBe(1)
		expect(secretRules.openEgg(on, "TestEgg", TestKit.sequenceRandom({ 0.99, 0 })).pet.petId).toBe("GhostPet")

		local off = secretAdmin.run(ADMIN, on, "setSecretChance", { 0 }, ctx).state
		expect(off.adminSecretChance).toBe(0)
		expect(secretRules.openEgg(off, "TestEgg", TestKit.sequenceRandom({ 0.99, 0 })).pet.petId).toBe("Hamster")
	end)

	it("hides both Secret actions while the feature is off", function()
		local offAdmin = AdminActions.new(
			secretRules,
			config,
			Features.new({
				travelingMerchant = true,
				adminPanel = true,
				stats = true,
				titles = true,
				loginCalendar30 = true,
				codes = false,
				petLevels = true,
				luckyWheel = true,
				goldenToppings = true,
				whatsNew = true,
				petIndex = true,
				friendsBonus = true,
				secretPets = false,
				worldIntro = true,
				shinyPets = true,
				dailyQuests = true,
			})
		)
		local listed = ids(offAdmin.list())
		expect(table.find(listed, "giveSecretPet")).toBe(nil)
		expect(offAdmin.run(ADMIN, fresh(), "setSecretChance", { 5 }, ctx).reason).toBe("FeatureOff")
	end)
end)

describe("pet variant admin actions (#80)", function()
	local config = table.clone(TestConfig)
	config.petVariants = {
		order = { "Normal", "Gold", "Rainbow" },
		Normal = { bonusMultiplier = 1 },
		Gold = { from = "Normal", count = 5, bonusMultiplier = 2.5 },
		Rainbow = { from = "Gold", count = 5, bonusMultiplier = 6 },
	}
	config.shinyPets = { chance = 1 / 200, bonusMultiplier = 1.5 }
	local variantRules = GameRules.new(config)
	local variantAdmin = AdminActions.new(variantRules, config, features)

	local function fresh()
		local state = variantRules.newPlayerState()
		state.upgrades = { InventorySpace = 2 }
		return state
	end

	it("offers the variants in merge order and yes/no for Shiny", function()
		for _, info in variantAdmin.list() do
			if info.id == "givePetVariant" then
				expect(info.params[2].choices).toEqual({ "Normal", "Gold", "Rainbow" })
				expect(info.params[2].names).toBe("variant")
				expect(info.params[3].choices).toEqual({ "no", "yes" })
				expect(info.params[3].names).toBe("yesNo")
			end
		end
	end)

	it("givePetVariant adds Gold/Rainbow/Shiny pets within the inventory limit", function()
		local state = fresh()
		local result = variantAdmin.run(ADMIN, state, "givePetVariant", { "Cat", "Rainbow", "yes", 2 }, ctx)
		expect(result.ok).toBe(true)
		expect(result.state.pets).toEqual({
			{ uid = 1, petId = "Cat", variant = "Rainbow", shiny = true, foundAt = NOW },
			{ uid = 2, petId = "Cat", variant = "Rainbow", shiny = true, foundAt = NOW },
		})
		local gold = variantAdmin.run(ADMIN, state, "givePetVariant", { "Cat", "Gold", "no", 5 }, ctx)
		expect(gold.state.pets[5]).toEqual({ uid = 5, petId = "Cat", variant = "Gold", foundAt = NOW })
		expect(variantAdmin.run(ADMIN, state, "givePetVariant", { "Cat", "Gold", "no", 11 }, ctx).reason).toBe(
			"InventoryFull"
		)
		expect(variantAdmin.run(ADMIN, state, "givePetVariant", { "Cat", "Silver", "no", 1 }, ctx).reason).toBe(
			"InvalidArgument"
		)
		expect(variantAdmin.run(ADMIN, state, "givePetVariant", { "Cat", "Gold", "maybe", 1 }, ctx).reason).toBe(
			"InvalidArgument"
		)
		expect(variantAdmin.run(43, state, "givePetVariant", { "Cat", "Gold", "no", 1 }, ctx).reason).toBe("NotAdmin")
	end)

	it("setShinyChance sets the test chance and is hidden while shinyPets is off", function()
		local result = variantAdmin.run(ADMIN, fresh(), "setShinyChance", { 100 }, ctx)
		expect(result.ok).toBe(true)
		expect(variantRules.shinyChance(result.state)).toBe(1)
		local back = variantAdmin.run(ADMIN, result.state, "setShinyChance", { 0 }, ctx)
		expect(variantRules.shinyChance(back.state)).toBe(1 / 200)

		local offAdmin = AdminActions.new(
			variantRules,
			config,
			Features.new({
				travelingMerchant = true,
				adminPanel = true,
				stats = true,
				titles = true,
				loginCalendar30 = true,
				codes = false,
				luckyWheel = true,
				goldenToppings = true,
				whatsNew = true,
				petIndex = true,
				friendsBonus = true,
				secretPets = true,
				shinyPets = false,
				worldIntro = true,
				petLevels = true,
				dailyQuests = true,
			})
		)
		expect(table.find(ids(offAdmin.list()), "setShinyChance")).toBe(nil)
		expect(offAdmin.run(ADMIN, fresh(), "setShinyChance", { 5 }, ctx).reason).toBe("FeatureOff")
	end)
end)

describe("pet level admin action (#90)", function()
	local config = table.clone(TestConfig)
	config.petLevels =
		{ maxLevel = 10, bonusPerLevel = 0.02, xpPerSecond = 1, xpToNext = { 1, 2, 3, 4, 5, 6, 7, 8, 9 } }
	local levelRules = GameRules.new(config)
	local levelAdmin = AdminActions.new(levelRules, config, features)

	local function withTwoPets()
		local state = levelRules.newPlayerState()
		state.pets = { { uid = 1, petId = "Cat", xp = 0.5 }, { uid = 2, petId = "Hamster" } }
		state.nextPetUid = 3
		state.equipped = { 1 }
		return state
	end

	it("setPetLevel sets the equipped pets, or all pets", function()
		local result = levelAdmin.run(ADMIN, withTwoPets(), "setPetLevel", { 10, "no" }, ctx)
		expect(result.ok).toBe(true)
		expect(result.state.pets[1]).toEqual({ uid = 1, petId = "Cat", level = 10 })
		expect(result.state.pets[2]).toEqual({ uid = 2, petId = "Hamster" })
		local all = levelAdmin.run(ADMIN, withTwoPets(), "setPetLevel", { 4, "yes" }, ctx)
		expect(all.state.pets[2].level).toBe(4)
	end)

	it("givePetXp credits minutes of play time as XP to the equipped pets", function()
		local result = levelAdmin.run(ADMIN, withTwoPets(), "givePetXp", { 1 }, ctx)
		expect(result.ok).toBe(true)
		-- 0.5 + 60 XP with 1, 2, ..., 9 XP per level: 1+2+...+9 = 45 -> level 10.
		expect(result.state.pets[1].level).toBe(10)
		expect(result.state.pets[2].level).toBe(nil)
		expect(levelAdmin.run(ADMIN, withTwoPets(), "givePetXp", { 601 }, ctx).reason).toBe("InvalidArgument")
	end)

	it("checks the level and the switch", function()
		expect(levelAdmin.run(ADMIN, withTwoPets(), "setPetLevel", { 11, "no" }, ctx).reason).toBe("InvalidArgument")
		expect(levelAdmin.run(ADMIN, withTwoPets(), "setPetLevel", { 0, "no" }, ctx).reason).toBe("InvalidArgument")
		local offAdmin = AdminActions.new(
			levelRules,
			config,
			Features.new({
				travelingMerchant = true,
				adminPanel = true,
				stats = true,
				titles = true,
				loginCalendar30 = true,
				codes = false,
				luckyWheel = true,
				goldenToppings = true,
				whatsNew = true,
				petIndex = true,
				friendsBonus = true,
				secretPets = true,
				shinyPets = true,
				worldIntro = true,
				petLevels = false,
				dailyQuests = true,
			})
		)
		expect(table.find(ids(offAdmin.list()), "setPetLevel")).toBe(nil)
		expect(table.find(ids(offAdmin.list()), "givePetXp")).toBe(nil)
		expect(offAdmin.run(ADMIN, withTwoPets(), "setPetLevel", { 3, "no" }, ctx).reason).toBe("FeatureOff")
	end)
end)

describe("admin lucky wheel (#98)", function()
	local wheelAdmin = AdminActions.new(
		rules,
		TestConfig,
		Features.new({
			travelingMerchant = true,
			adminPanel = true,
			stats = true,
			titles = true,
			loginCalendar30 = true,
			codes = false,
			petLevels = true,
			luckyWheel = true,
			goldenToppings = true,
			whatsNew = true,
			petIndex = true,
			friendsBonus = true,
			secretPets = true,
			worldIntro = true,
			shinyPets = true,
			dailyQuests = true,
		})
	)

	it("resetWheelSpins gives today's free spins back", function()
		local state = rules.spinWheel(player(), NOW, TestKit.sequenceRandom({ 0.3 })).state
		expect(rules.wheelStatus(state, NOW).freeSpins).toBe(0)

		local result = wheelAdmin.run(ADMIN, state, "resetWheelSpins", {}, ctx)

		expect(result.ok).toBe(true)
		expect(rules.wheelStatus(result.state, NOW).freeSpins).toBe(1)
		expect(state.wheelFreeUsed).toBe(1)
	end)

	it("is hidden and refused while the lucky wheel is switched off", function()
		expect(table.find(ids(admin.list()), "resetWheelSpins")).toBe(nil)
		expect(admin.run(ADMIN, player(), "resetWheelSpins", {}, ctx).reason).toBe("FeatureOff")
		expect(table.find(ids(wheelAdmin.list()), "resetWheelSpins") ~= nil).toBe(true)
	end)

	it("skipDays moves the wheel day back, so the free spins come back", function()
		local state = rules.spinWheel(player(), NOW, TestKit.sequenceRandom({ 0.3 })).state
		local skipped = wheelAdmin.run(ADMIN, state, "skipDays", { 1 }, ctx).state

		expect(skipped.wheelDay).toBe(rules.dayNumber(NOW) - 1)
		expect(rules.wheelStatus(skipped, NOW).freeSpins).toBe(1)
	end)
end)

describe("admin actions: quests (#97)", function()
	-- 15.01.2026 11:00 CET.
	local QUEST_NOW = 1768431600 + 11 * 3600
	local questCtx = { now = QUEST_NOW, random = TestKit.sequenceRandom({ 0 }) }

	it("completeQuest makes today's quests if needed and finishes one", function()
		local result = admin.run(ADMIN, player(), "completeQuest", { "Daily", 2 }, questCtx)

		expect(result.ok).toBe(true)
		local quest = result.state.dailyQuests[2]
		expect(quest.progress).toBe(quest.goal)
		expect(rules.claimQuest(result.state, "Daily", 2, QUEST_NOW).ok).toBe(true)
		local weekly = admin.run(ADMIN, result.state, "completeQuest", { "Weekly", 1 }, questCtx)
		expect(weekly.state.weeklyQuests[1].progress).toBe(weekly.state.weeklyQuests[1].goal)
		expect(admin.run(ADMIN, result.state, "completeQuest", { "Daily", 2 }, questCtx).reason).toBe("QuestDone")
		expect(admin.run(ADMIN, result.state, "completeQuest", { "Daily", 5 }, questCtx).reason).toBe("UnknownQuest")
		expect(admin.run(ADMIN, player(), "completeQuest", { "Monthly", 1 }, questCtx).reason).toBe("InvalidArgument")
	end)

	it("rerollQuests makes new quests at once", function()
		local state = rules.refreshQuests(player(), QUEST_NOW, TestKit.sequenceRandom({ 0 })).state
		state.questRerolls = 2

		local result = admin.run(ADMIN, state, "rerollQuests", {}, questCtx)

		expect(result.ok).toBe(true)
		expect(result.state.dailyQuests == state.dailyQuests).toBe(false)
		expect(result.state.questRerolls).toBe(0)
	end)

	it("skipDays moves the quest days back too", function()
		local state = rules.refreshQuests(player(), QUEST_NOW, TestKit.sequenceRandom({ 0 })).state
		state.questStreakDay = state.questDay

		local result = admin.run(ADMIN, state, "skipDays", { 1 }, questCtx)

		expect(result.state.questDay).toBe(state.questDay - 1)
		expect(result.state.questStreakDay).toBe(state.questDay - 1)
		expect(result.state.questWeekDay).toBe(state.questWeekDay - 1)
		expect(rules.refreshQuests(result.state, QUEST_NOW, TestKit.sequenceRandom({ 0 })).ok).toBe(true)
	end)
end)

describe("admin codes (#99)", function()
	local function withCodes(on: boolean)
		local map = {}
		for id in GameConfig.features do
			map[id] = false
		end
		map.adminPanel = true
		map.codes = on
		return Features.new(map)
	end
	local codesAdmin = AdminActions.new(rules, TestConfig, withCodes(true))

	it("resetCodes lets the player redeem every code again", function()
		local state = rules.redeemCode(player(), "HELLO", NOW, TestKit.sequenceRandom({ 0.5 })).state
		local result = codesAdmin.run(ADMIN, state, "resetCodes", {}, ctx)
		expect(result.ok).toBe(true)
		expect(result.state.redeemedCodes).toEqual({})
		expect(rules.redeemCode(result.state, "hello", NOW, TestKit.sequenceRandom({ 0.5 })).ok).toBe(true)
		expect(state.redeemedCodes).toEqual({ "HELLO" })
	end)

	it("is hidden and refused while codes are switched off", function()
		local offAdmin = AdminActions.new(rules, TestConfig, withCodes(false))
		expect(offAdmin.run(ADMIN, player(), "resetCodes", {}, ctx).reason).toBe("FeatureOff")
	end)
end)

describe("admin friends action (#102)", function()
	it("simulateFriends sets the simulated count, 0 goes back to the real count", function()
		local result = admin.run(ADMIN, player(), "simulateFriends", { 2 }, ctx)
		expect(result.ok).toBe(true)
		expect(rules.friendsCount(result.state)).toBe(2)
		expect(math.abs(rules.friendsBonus(result.state) - 0.2) < 1e-9).toBe(true)
		local off = admin.run(ADMIN, result.state, "simulateFriends", { 0 }, ctx)
		expect(rules.friendsCount(off.state)).toBe(0)
		expect(admin.run(ADMIN, player(), "simulateFriends", { 6 }, ctx).reason).toBe("InvalidArgument")
	end)
end)

describe("admin pet index action (#95)", function()
	it("completePetIndex marks every index pet of the world as found, without giving pets", function()
		local result = admin.run(ADMIN, player(), "completePetIndex", { "PizzeriaGarden" }, ctx)

		expect(result.ok).toBe(true)
		expect(#result.state.pets).toBe(0)
		expect(rules.hasOwnedPet(result.state, "Hamster")).toBe(true)
		expect(rules.hasOwnedPet(result.state, "Dragon")).toBe(true)
		expect(rules.petIndex(result.state).worlds[1].complete).toBe(true)
		expect(admin.run(ADMIN, result.state, "completePetIndex", { "PizzeriaGarden" }, ctx).reason).toBe(
			"IndexComplete"
		)
		expect(admin.run(ADMIN, player(), "completePetIndex", { "Nowhere" }, ctx).reason).toBe("InvalidArgument")
	end)

	it("is hidden while the pet index is off", function()
		local map = {}
		for id in GameConfig.features do
			map[id] = true
		end
		map.petIndex = false
		local offAdmin = AdminActions.new(rules, TestConfig, Features.new(map))

		expect(table.find(ids(offAdmin.list()), "completePetIndex")).toBeNil()
		expect(offAdmin.run(ADMIN, player(), "completePetIndex", { "PizzeriaGarden" }, ctx).reason).toBe("FeatureOff")
	end)
end)

describe("admin login calendar (#101)", function()
	local function withCalendar(on: boolean)
		local map = {}
		for id in GameConfig.features do
			map[id] = false
		end
		map.adminPanel = true
		map.loginCalendar30 = on
		return Features.new(map)
	end
	local calendarAdmin = AdminActions.new(rules, TestConfig, withCalendar(true))

	it("setCalendarDay makes the chosen day claimable today", function()
		local result = calendarAdmin.run(ADMIN, player(), "setCalendarDay", { 30 }, ctx)

		expect(result.ok).toBe(true)
		local calendar = rules.loginCalendar(result.state, NOW)
		expect(calendar.today).toBe(30)
		expect(calendar.claimable).toBe(true)
	end)

	it("only offers days 1-30", function()
		expect(calendarAdmin.run(ADMIN, player(), "setCalendarDay", { 31 }, ctx).reason).toBe("InvalidArgument")
		expect(calendarAdmin.run(ADMIN, player(), "setCalendarDay", { 0 }, ctx).reason).toBe("InvalidArgument")
	end)

	it("is hidden and refused while the 30-day calendar is switched off", function()
		local offAdmin = AdminActions.new(rules, TestConfig, withCalendar(false))

		expect(table.find(ids(offAdmin.list()), "setCalendarDay")).toBeNil()
		expect(offAdmin.run(ADMIN, player(), "setCalendarDay", { 7 }, ctx).reason).toBe("FeatureOff")
	end)
end)

describe("profile admin actions (#103)", function()
	it("addStat raises a lifetime counter", function()
		local result = admin.run(ADMIN, player(), "addStat", { "EggsOpened", 25 }, ctx)
		expect(result.ok).toBe(true)
		expect(result.state.eggsOpened).toBe(25)
		local coins = admin.run(ADMIN, player(), "addStat", { "CoinsEarned", 1000 }, ctx)
		expect(coins.state.totalCoinsEarned).toBe(1000)
		expect(admin.run(ADMIN, player(), "addStat", { "Gems", 1 }, ctx).reason).toBe("InvalidArgument")
	end)

	it("giveWeeklyChampion grants the title for the chosen days", function()
		local result = admin.run(ADMIN, player(), "giveWeeklyChampion", { 7 }, ctx)
		expect(result.ok).toBe(true)
		expect(result.state.weeklyChampionUntil).toBe(NOW + 7 * 86400)
	end)
end)
