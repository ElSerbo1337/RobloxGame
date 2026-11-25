local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local AdminActions = require("../src/shared/AdminActions")
local Features = require("../src/shared/Features")
local GameConfig = require("../src/shared/GameConfig")
local GameRules = require("../src/shared/GameRules")
local Texts = require("../src/shared/Texts")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local rules = GameRules.new(TestConfig)
local features = Features.new({ adminPanel = true, luckyWheel = false, goldenToppings = true, whatsNew = true })
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
		expect(result.state.pets).toEqual({ { uid = 1, petId = "Dragon" }, { uid = 2, petId = "Dragon" } })
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

	it("resetProgress starts the player over with a fresh state", function()
		local state = player()
		state.coins = 999
		state.rebirths = 3

		local result = admin.run(ADMIN, state, "resetProgress", {}, ctx)

		expect(result.ok).toBe(true)
		expect(result.state).toEqual(rules.newPlayerState())
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
			Features.new({ adminPanel = true, goldenToppings = false, whatsNew = true })
		)

		expect(table.find(ids(offAdmin.list()), "setGoldenChance")).toBeNil()
		expect(offAdmin.run(ADMIN, player(), "giveGoldenToppings", { "Salami", 1 }, ctx).reason).toBe("FeatureOff")
	end)
end)
