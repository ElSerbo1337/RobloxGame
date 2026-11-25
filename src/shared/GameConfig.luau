--!strict
-- Central game configuration: every balancing number lives here.
-- Pure data, no Roblox API, so the game rules can be tested outside Roblox (Lune).
-- New worlds and toppings are added here only.

local GameConfig = {
	-- MEGA UPDATE feature switches (#73): one boolean per new feature. A switched-off
	-- feature shows no UI and its server handlers refuse requests (Shared.Features).
	-- New feature: add its id here (default true) and check it via Features.new(...).
	features = {
		-- Foundation and tools
		adminPanel = true, -- admin panel, only user 372358501
		analytics = true, -- funnel events (tutorial, first unlocks, first rebirth, quests)
		-- Worlds and rebirth
		eventWorlds = true, -- event islands with their own currency (prepared only)
		worldMenu = true, -- world menu with cards and 3D preview
		worldIntro = true, -- camera flight on the first visit of a world
		rebirthPreview = true, -- rebirth menu shows multiplier before/after and opened worlds
		-- Pets
		petMerge = true, -- 5 equal -> Gold, 5 Gold -> Rainbow
		shinyPets = true,
		secretPets = true, -- rarity "Secret", one pet per world
		secretAnnouncement = true, -- message to all servers on a Secret hatch
		petLevels = true,
		petIndex = true,
		toppingIndex = true,
		petAutoDelete = true,
		petMultiDelete = true,
		petLock = true,
		petDetails = true, -- pet detail card
		petTeams = true,
		petRename = true,
		petAuras = true, -- auras, shine and animations
		effectiveEggChances = true, -- egg panel shows chances incl. potions/upgrades
		-- Gameplay
		goldenToppings = true, -- incl. the "Gold Luck" gem upgrade
		newPotions = true, -- Shiny, Gold, Mega
		dailyQuests = true,
		weeklyQuests = true,
		luckyWheel = true,
		codes = true,
		hiddenChests = true,
		loginCalendar30 = true, -- 30-day login calendar
		travelingMerchant = true,
		friendsBonus = true,
		weather = true,
		dayNight = true,
		worldDeco = true, -- scripted decoration of the new worlds (corals, ruins, bubbles, lights; #82)
		-- Progress and social
		stats = true, -- lifetime statistics
		badges = true,
		titles = true,
		profile = true,
		newLeaderboards = true, -- eggs opened, toppings collected
		weeklyChampion = true,
		-- Look and UI
		sideBar = true, -- new HUD side bar with tiles and red dots
		settings = true,
		spawnMarketplace = true, -- spawn island stands (wheel, update board, merchant)
		christmasCountdown = true,
		whatsNew = true,
		juice = true,
		loadingScreen = true,
		featureHints = true,
	},

	-- Admin panel (#74): only these Roblox user ids see it and may run its actions
	-- (checked on the server for every action, in Studio and live).
	admin = {
		userIds = { 372358501 },
	},

	save = {
		-- DataStore of all player states. MEGA UPDATE (#73): fresh start for everybody
		-- in a new store; the old "PlayerState" store is left untouched (no migration).
		storeName = "PlayerState_Mega1",
		-- Seconds between periodic saves of every player (also renews the session lock).
		autosaveSeconds = 120,
		-- A session lock older than this is treated as orphaned (its server crashed)
		-- and may be taken over. Must be clearly longer than autosaveSeconds.
		lockExpirySeconds = 300,
		-- While another server holds a fresh lock, loading retries this often ...
		lockRetrySeconds = 5,
		-- ... for at most this long; then the player is kicked with a hint to rejoin.
		lockWaitSeconds = 60,
	},

	-- Global leaderboards on the spawn island (#38): one ordered DataStore per board,
	-- written on every periodic save and on leave; every server reads the top entries
	-- this often. Board ids match rules.leaderboardScores; boards are shown in this
	-- order on the island's panels. Bump a store name to start a board over.
	leaderboards = {
		refreshSeconds = 120,
		top = 10,
		boards = {
			{ id = "Playtime", store = "Leaderboard_Playtime_mega1", title = "⏱ Spielzeit", format = "Duration" },
			{
				id = "CoinsEarned",
				store = "Leaderboard_CoinsEarned_mega1",
				title = "💰 Münzen verdient",
				format = "Number",
			},
			{ id = "Rebirths", store = "Leaderboard_Rebirths_mega1", title = "🔁 Rebirths", format = "Number" },
		},
	},

	pizza = {
		-- Toppings a new player's pizza can hold.
		startCapacity = 2,
	},

	collect = {
		-- Max distance (studs) between player and topping for clicking/tapping it.
		range = 10,
		-- Pickup radius (studs, horizontal) when walking over toppings with auto-collect on.
		autoRadius = 4,
	},

	toppingField = {
		-- Toppings lying around per world at the same time.
		count = 60,
		-- Seconds until a collected topping reappears at a random spot.
		respawnSeconds = 5,
	},

	-- Topping id -> display name and sell value in coins.
	toppings = {
		Salami = { displayName = "Salami", displayNameEn = "Salami", value = 1 },
		Mushroom = { displayName = "Pilz", displayNameEn = "Mushroom", value = 2 },
		Mozzarella = { displayName = "Mozzarella", displayNameEn = "Mozzarella", value = 5 },
		-- World 2 (Bauernhof): about 4x world 1.
		Onion = { displayName = "Zwiebel", displayNameEn = "Onion", value = 4 },
		BellPepper = { displayName = "Paprika", displayNameEn = "Bell Pepper", value = 8 },
		Corn = { displayName = "Mais", displayNameEn = "Corn", value = 12 },
		Ham = { displayName = "Schinken", displayNameEn = "Ham", value = 20 },
		-- World 3 (Strand): about 4x world 2.
		Tuna = { displayName = "Thunfisch", displayNameEn = "Tuna", value = 25 },
		Shrimp = { displayName = "Garnele", displayNameEn = "Shrimp", value = 45 },
		Pineapple = { displayName = "Ananas", displayNameEn = "Pineapple", value = 65 },
		-- World 4 (Eisberge): about 4x world 3.
		FrozenPeas = { displayName = "Gefrorene Erbsen", displayNameEn = "Frozen Peas", value = 100 },
		Salmon = { displayName = "Lachs", displayNameEn = "Salmon", value = 180 },
		IcebergLettuce = { displayName = "Eisberg-Salat", displayNameEn = "Iceberg Lettuce", value = 260 },
		-- World 5 (Vulkan): about 4.8x world 4 (the pizza stays at 12 until shop 3).
		Chili = { displayName = "Chili", displayNameEn = "Chili", value = 500 },
		Pepperoni = { displayName = "Peperoni", displayNameEn = "Hot Pepper", value = 850 },
		Jalapeno = { displayName = "Jalapeño", displayNameEn = "Jalapeño", value = 1250 },
		-- World 6 (Süßigkeitenland): about 4.8x world 5.
		ChocolateChips = { displayName = "Schoko-Stücke", displayNameEn = "Choco Chips", value = 2400 },
		GummyBears = { displayName = "Gummibärchen", displayNameEn = "Gummy Bears", value = 4100 },
		Marshmallow = { displayName = "Marshmallow", displayNameEn = "Marshmallow", value = 6000 },
		-- World 7 (Weltraum): about 4.8x world 6.
		MoonCheese = { displayName = "Mond-Käse", displayNameEn = "Moon Cheese", value = 11500 },
		StarOlives = { displayName = "Sternen-Oliven", displayNameEn = "Star Olives", value = 20000 },
		AlienMushroom = { displayName = "Alien-Pilz", displayNameEn = "Alien Mushroom", value = 29000 },
		-- World 8 (Atlantis, #82): about 4.8x world 7. Provisional, tuned in #108.
		Seaweed = { displayName = "Seetang", displayNameEn = "Seaweed", value = 55000 },
		PearlCapers = { displayName = "Perlen-Kapern", displayNameEn = "Pearl Capers", value = 96000 },
		SquidRings = { displayName = "Tintenfisch-Ringe", displayNameEn = "Squid Rings", value = 140000 },
	},

	-- Coin upgrades bought in shops. `levels` are in buy order: price in coins and the
	-- effect at that level (pizza space in toppings, range/magnet radius in studs).
	-- Level 0 is the base value (pizza.startCapacity, collect.range, no magnet).
	-- Levels beyond a shop's maxLevel show up there as "im größeren Shop erhältlich".
	upgrades = {
		PizzaSpace = {
			displayName = "Pizza-Platz",
			displayNameEn = "Pizza Space",
			description = "Mehr Beläge pro Pizza",
			descriptionEn = "More toppings per pizza",
			levels = {
				-- Shop 1 (world 1)
				{ price = 12, value = 3 }, -- first upgrade after 3-4 rounds (#23)
				{ price = 26, value = 4 },
				{ price = 48, value = 6 },
				-- Shop 2 (world 4)
				{ price = 1600, value = 8 },
				{ price = 4500, value = 10 },
				{ price = 11000, value = 12 },
				-- Shop 3 (world 7): bought on the way to the first rebirth (below its price).
				{ price = 16000000, value = 15 },
				{ price = 40000000, value = 20 },
			},
		},
		CollectRange = {
			displayName = "Reichweite",
			displayNameEn = "Reach",
			description = "Beläge aus größerer Entfernung antippen",
			descriptionEn = "Tap toppings from farther away",
			levels = {
				{ price = 25, value = 14 },
				{ price = 26, value = 18 },
				{ price = 110, value = 22 },
				{ price = 2500, value = 26 },
				{ price = 7300, value = 30 },
				{ price = 15000, value = 35 },
				-- Shop 3 (world 7)
				{ price = 12000000, value = 40 },
				{ price = 28000000, value = 45 },
			},
		},
		Magnet = {
			displayName = "Magnet",
			displayNameEn = "Magnet",
			description = "Zieht Beläge beim Auto-Sammeln an",
			descriptionEn = "Pulls in toppings while auto-collecting",
			levels = {
				{ price = 77, value = 12 },
				{ price = 8700, value = 18 },
				{ price = 20000, value = 25 },
				-- Shop 3 (world 7)
				{ price = 14000000, value = 32 },
				{ price = 34000000, value = 40 },
			},
		},

		-- Gem counter: same shape, but `currency = "Gems"` (paid with gems). Staged per shop like coin upgrades.
		PetSlots = {
			displayName = "Pet-Plätze",
			displayNameEn = "Pet Slots",
			description = "Mehr Pets gleichzeitig ausrüsten",
			descriptionEn = "Equip more pets at once",
			currency = "Gems",
			levels = {
				-- Shop 1 (world 1)
				{ price = 50, value = 4 },
				{ price = 150, value = 5 },
				-- Shop 2 (world 4)
				{ price = 400, value = 6 },
				{ price = 1000, value = 7 },
				-- Shop 3 (world 7)
				{ price = 2500, value = 8 },
			},
		},
		InventorySpace = {
			displayName = "Inventar",
			displayNameEn = "Inventory",
			description = "Mehr Platz für Pets",
			descriptionEn = "More room for pets",
			currency = "Gems",
			levels = {
				{ price = 30, value = 75 },
				{ price = 100, value = 100 },
				{ price = 300, value = 150 },
				{ price = 800, value = 200 },
				{ price = 2000, value = 300 },
			},
		},
		WalkSpeed = {
			displayName = "Laufgeschwindigkeit",
			displayNameEn = "Walk Speed",
			description = "Schneller laufen",
			descriptionEn = "Walk faster",
			currency = "Gems",
			levels = {
				{ price = 40, value = 19 },
				{ price = 120, value = 22 },
				{ price = 350, value = 25 },
				{ price = 900, value = 28 },
				{ price = 2000, value = 32 },
			},
		},
		TripleOpen = {
			displayName = "3 Eier auf einmal",
			displayNameEn = "3 Eggs at Once",
			description = "Schaltet „3 öffnen“ an jedem Ei frei",
			descriptionEn = "Unlocks “Open 3” at every egg",
			currency = "Gems",
			-- value = eggs per press.
			levels = {
				{ price = 150, value = 3 },
			},
		},
		-- Golden toppings (#94): value = chance that a topping is golden for the player
		-- (level 0 = goldenToppings.chance). Hidden and not sold while the feature is off.
		GoldLuck = {
			displayName = "Gold-Glück",
			displayNameEn = "Gold Luck",
			description = "Mehr goldene Beläge (10-facher Wert)",
			descriptionEn = "More golden toppings (10x value)",
			currency = "Gems",
			feature = "goldenToppings",
			levels = {
				-- Shop 1 (world 1)
				{ price = 60, value = 0.012 },
				{ price = 180, value = 0.014 },
				-- Shop 2 (world 4)
				{ price = 450, value = 0.016 },
				{ price = 1100, value = 0.018 },
				-- Shop 3 (world 7)
				{ price = 2500, value = 0.02 },
			},
		},
	},

	petSlots = {
		-- Pets a new player can equip at the same time.
		start = 3,
	},

	inventory = {
		-- Pets a new player can own. A full inventory blocks opening eggs.
		start = 50,
	},

	movement = {
		-- Walk speed (studs/s) before the WalkSpeed gem upgrade (Roblox default).
		walkSpeed = 16,
	},

	-- Second currency. Target: about 20-40 gems per hour.
	gems = {
		-- Id of the gem topping in a ToppingField (not a config.toppings entry: it never goes on the pizza).
		toppingId = "Gem",
		-- Chance that a spawning topping is a gem topping instead, and how many gems it gives.
		toppingChance = 1 / 150,
		toppingMin = 1,
		toppingMax = 3,
	},

	-- Golden toppings (#94): every normal topping has `chance` to be golden for a player
	-- (raised by the GoldLuck gem upgrade and gold-chance potions, never by weather) and
	-- then sells for `valueMultiplier` x its value. Kept separate from normal toppings in
	-- the rules (collect result `golden`, pizza `pizzaGolden`) for the index and quests.
	goldenToppings = {
		chance = 0.01,
		valueMultiplier = 10,
	},

	-- New HUD buttons that pulse (with a short explanation) until the player opened them
	-- once; remembered per player (GameRules.markHintSeen): play time gifts (#36) and the
	-- rebirth button (#35, pulses the first time a rebirth is affordable). Also one-time
	-- windows: "WhatsNew1" = the "What's new" window of the MEGA UPDATE (#106).
	hints = { "Gifts", "Rebirth", "WhatsNew1" },

	-- Spawn island as a marketplace (#106): "Neu im Update!" board and "What's new"
	-- window (shown once per player: the hint `whatsNewHint` is remembered when the
	-- player closes it), and the Christmas countdown sign. The countdown counts German
	-- calendar days until `countdownTo` (GameRules.christmasCountdown) and is hidden from
	-- that day on (the event itself is a later update).
	spawnMarket = {
		whatsNewHint = "WhatsNew1",
		countdownTo = { year = 2026, month = 12, day = 18 },
		-- Seconds between countdown sign updates on the server.
		countdownRefreshSeconds = 60,
	},

	-- Income estimate (GameRules.incomePerMinute): average topping value of the highest
	-- unlocked world x pizza space x rounds per minute x coin multiplier (pets, rebirths).
	income = {
		-- Assumed rounds per minute (collect a full pizza and sell it).
		roundsPerMinute = 2,
	},

	-- Lucky wheel (#98, feature "luckyWheel"): 1 free spin per German day + 1 more after
	-- bonusSpinMinutes of play time that day, further spins for spinPrice gems. The server
	-- draws the field by weight (sum 100 = percent). "Coins" pays `minutes` of the player's
	-- income (rules.incomePerMinute, at least minCoins); potions are random ones like gifts.
	-- Average per spin: ~5.5 gems + 0.4 potions + ~3 minutes of income, so a paid spin
	-- (25 gems) is a gamble, the two free spins add ~11 gems a day.
	luckyWheel = {
		spinPrice = 25,
		freeSpinsPerDay = 1,
		bonusSpinMinutes = 30,
		minCoins = 50,
		-- Wheel order (clockwise from the top); `color` = field colour on wheel and menu.
		fields = {
			{ id = "Coins5", weight = 24, color = { 255, 200, 40 }, rewards = { { kind = "Coins", minutes = 5 } } },
			{ id = "Gems5", weight = 20, color = { 60, 230, 255 }, rewards = { { kind = "Gems", amount = 5 } } },
			{ id = "Potion1", weight = 15, color = { 170, 110, 230 }, rewards = { { kind = "Potion", amount = 1 } } },
			{ id = "Gems10", weight = 12, color = { 40, 170, 230 }, rewards = { { kind = "Gems", amount = 10 } } },
			{ id = "Coins15", weight = 14, color = { 240, 150, 30 }, rewards = { { kind = "Coins", minutes = 15 } } },
			{ id = "Potion2", weight = 8, color = { 130, 70, 200 }, rewards = { { kind = "Potion", amount = 2 } } },
			{ id = "Gems25", weight = 5, color = { 30, 110, 210 }, rewards = { { kind = "Gems", amount = 25 } } },
			{
				id = "Jackpot",
				weight = 2,
				jackpot = true,
				color = { 230, 70, 50 },
				rewards = { { kind = "Gems", amount = 100 }, { kind = "Potion", amount = 3 } },
			},
		},
	},

	-- Play time gifts: reached after `minutes` of play time on a German day (the day's
	-- play time starts over at midnight German time), each claimable once per day.
	-- Fixed rewards, independent of progress: Gems / Potion (`amount`; a potion is a random
	-- one, like delivery orders). No coins. Gifts give 26 gems a day, the calendar about 12
	-- a day on average: together about 38 for a 60 minute day (20-40 gems/hour target).
	gifts = {
		{ minutes = 5, rewards = { { kind = "Gems", amount = 3 } } },
		{ minutes = 10, rewards = { { kind = "Gems", amount = 5 } } },
		{ minutes = 15, rewards = { { kind = "Potion", amount = 1 } } },
		{ minutes = 25, rewards = { { kind = "Potion", amount = 1 } } },
		{ minutes = 40, rewards = { { kind = "Gems", amount = 8 } } },
		{ minutes = 60, rewards = { { kind = "Gems", amount = 10 }, { kind = "Potion", amount = 1 } } },
	},

	-- Login calendar: one reward per German day (new day at midnight German time). Claimed
	-- on the following day, the series goes on to the next calendar day; a missed day
	-- starts over at day 1, and so does the day after day 7. Fixed gems and potions like
	-- gifts (85 gems a week).
	loginCalendar = {
		{ rewards = { { kind = "Gems", amount = 5 } } },
		{ rewards = { { kind = "Gems", amount = 10 } } },
		{ rewards = { { kind = "Potion", amount = 1 } } },
		{ rewards = { { kind = "Potion", amount = 1 } } },
		{ rewards = { { kind = "Gems", amount = 20 } } },
		{ rewards = { { kind = "Potion", amount = 2 } } },
		{ rewards = { { kind = "Gems", amount = 50 }, { kind = "Potion", amount = 3 } } },
	},

	-- Daily and weekly quests (#97, GameRules "Quests"). Daily: `dailyCount` quests per German
	-- day, each paying one of `dailyRewards` (drawn when the quest is made); all of them
	-- done = bonus chest; `freeRerolls` rerolls a day, then `rerollGems` each. Bonus chests
	-- on `streakDays` days in a row = streak chest. Weekly: `weeklyCount` bigger quests,
	-- new ones on Monday 00:00 German time. Gem budget: ~3 x 8 x 1/2 + 20 + 100/7 = ~46 a day
	-- from dailies, ~13 a day from weeklies.
	-- `kinds`: the pool, drawn without repeats inside a set. Goal = base + perWorld x (index
	-- of the highest unlocked world - 1); EarnCoins: `incomeMinutes` x the income per minute
	-- (rules.incomePerMinute). `feature`: only drawn while that switch is on; `minWorld`:
	-- only from that world index on. Kinds whose progress source does not exist yet
	-- (OpenChest #100) are only drawn once GameRules.QUEST_SOURCES lists them.
	quests = {
		dailyCount = 3,
		weeklyCount = 3,
		dailyRewards = {
			{ kind = "Gems", amount = 8, weight = 1 },
			{ kind = "Potion", amount = 1, weight = 1 },
		},
		weeklyRewards = {
			{ kind = "Gems", amount = 30, weight = 1 },
		},
		bonusRewards = { { kind = "Gems", amount = 20 }, { kind = "Potion", amount = 1 } },
		freeRerolls = 1,
		rerollGems = 10,
		streakDays = 7,
		-- `potionId`: that potion (Mega, #new potions); a random one while it does not exist.
		streakRewards = { { kind = "Gems", amount = 100 }, { kind = "Potion", amount = 1, potionId = "Mega" } },
		kinds = {
			{ id = "CollectToppings", daily = { base = 60, perWorld = 20 }, weekly = { base = 400, perWorld = 120 } },
			{ id = "SellPizzas", daily = { base = 10, perWorld = 2 }, weekly = { base = 60, perWorld = 12 } },
			{ id = "OpenEggs", daily = { base = 3, perWorld = 1 }, weekly = { base = 20, perWorld = 5 } },
			{ id = "Deliveries", daily = { base = 2, perWorld = 0 }, weekly = { base = 10, perWorld = 1 } },
			{ id = "EarnCoins", daily = { incomeMinutes = 10 }, weekly = { incomeMinutes = 60 } },
			{ id = "PlayMinutes", daily = { base = 15, perWorld = 0 }, weekly = { base = 120, perWorld = 0 } },
			{
				id = "MergePets",
				feature = "petMerge",
				daily = { base = 1, perWorld = 0 },
				weekly = { base = 3, perWorld = 0 },
			},
			{
				id = "GoldenToppings",
				feature = "goldenToppings",
				daily = { base = 2, perWorld = 0 },
				weekly = { base = 10, perWorld = 1 },
			},
			{
				id = "SpinWheel",
				feature = "luckyWheel",
				daily = { base = 2, perWorld = 0 },
				weekly = { base = 10, perWorld = 0 },
			},
			{
				id = "OpenChest",
				feature = "hiddenChests",
				minWorld = 3,
				daily = { base = 1, perWorld = 0 },
				weekly = { base = 4, perWorld = 0 },
			},
			-- Daily only, and only while the next world is in reach (rebirths); see rules.
			{ id = "UnlockWorld", daily = { base = 1, perWorld = 0 } },
		},
	},

	-- Potions: bought with gems at a shop's gem counter, kept in the potion inventory and
	-- drunk from there. Each runs `durationSeconds` of play time (it pauses while offline);
	-- drinking the same kind again adds its duration to the time left.
	potions = {
		Coins = {
			displayName = "Münz-Trank",
			displayNameEn = "Coin Potion",
			description = "Doppelte Münzen beim Verkaufen",
			descriptionEn = "Double coins when selling",
			price = 25,
			durationSeconds = 600,
			coinMultiplier = 2,
		},
		Luck = {
			displayName = "Glücks-Trank",
			displayNameEn = "Luck Potion",
			description = "Seltene Pets kommen öfter aus Eiern",
			descriptionEn = "Rare pets hatch more often",
			price = 30,
			durationSeconds = 600,
			-- Egg chances are multiplied per rarity, then scaled back to 100 %.
			rarityWeights = {
				Common = 1,
				Uncommon = 1.2,
				Rare = 1.5,
				Epic = 2,
				Legendary = 2.5,
				Mythic = 3,
				-- Secret pets (#81): not in the chance table, a separate roll (secretPets.chance x 2).
				Secret = 2,
			},
			-- Shiny chance (#80) x2 while it runs (1 in 200 -> 1 in 100).
			shinyChanceMultiplier = 2,
		},
		Speed = {
			displayName = "Speed-Trank",
			displayNameEn = "Speed Potion",
			description = "Schneller laufen",
			descriptionEn = "Walk faster",
			price = 15,
			durationSeconds = 600,
			-- Multiplies the walk speed (including the WalkSpeed upgrade).
			walkSpeedMultiplier = 1.5,
		},
	},

	-- Delivery service: every world has a phone and a delivery van. The phone rings with
	-- an order (toppings of the highest unlocked world, at most the pizza space); accepted,
	-- it has to be delivered at the van within the time limit. Faster = bigger reward.
	delivery = {
		-- Seconds of quiet phone after an order or call ended (and after joining it rings at once).
		callIntervalSeconds = 150,
		-- Seconds to deliver an accepted order; afterwards it expires (nothing else is lost).
		timeLimitSeconds = 180,
		-- Fewest toppings in an order (never more than the pizza holds).
		minToppings = 2,
		-- Reward x (1 + speedBonus x share of the time left): up to +50 % for instant delivery.
		speedBonus = 0.5,
		-- Coin reward = topping values x pet bonus x coin potion x coinFactor (x speed),
		-- i.e. about 3-4.5 times what selling the same toppings would pay.
		coinFactor = 3,
		-- Gem reward: base drawn from gemsMin..gemsBaseMax, x speed, at most gemsMax (3-10).
		gemsMin = 3,
		gemsBaseMax = 7,
		gemsMax = 10,
		-- Potion reward (a random potion): 1, or 2 when delivered with at least this share of time left.
		fastPotionShare = 0.5,
		-- Chance of each reward kind (relative weights). Gems kept low for the 20-40 gems/hour target.
		rewardWeights = {
			{ reward = "Coins", weight = 65 },
			{ reward = "Gems", weight = 20 },
			{ reward = "Potion", weight = 15 },
		},
	},

	-- Rebirth: pay coins to start over (coins, coin upgrades and worlds are reset) with a
	-- permanently higher coin multiplier for selling and delivery coins (not gems).
	rebirth = {
		-- Price of the first rebirth: about 28 min of play in world 4, the last world before
		-- the first rebirth tier (#77; provisional, tuned for 15 worlds in #108).
		startPrice = 150000,
		-- Each further rebirth costs this many times the one before: the second run up to
		-- the next rebirth (worlds 1-6) takes about 47 min (#77, provisional until #108).
		priceFactor = 60,
		-- Coin multiplier = 1 + multiplierPerRebirth x rebirths (1 rebirth = x1,5, 2 = x2, ...).
		multiplierPerRebirth = 0.5,
	},

	-- New-player tutorial: collect toppings -> sell -> buy an upgrade -> open an egg.
	tutorial = {
		-- Toppings to collect in the first step (must fit on the starting pizza).
		collectToppings = 2,
	},

	-- Pet rarities. `order` sorts from common (1) to rarest; `color` is RGB 0-255.
	rarities = {
		Common = { displayName = "Gewöhnlich", displayNameEn = "Common", order = 1, color = { 190, 190, 190 } },
		Uncommon = { displayName = "Ungewöhnlich", displayNameEn = "Uncommon", order = 2, color = { 90, 200, 90 } },
		Rare = { displayName = "Selten", displayNameEn = "Rare", order = 3, color = { 70, 150, 255 } },
		Epic = { displayName = "Episch", displayNameEn = "Epic", order = 4, color = { 170, 80, 240 } },
		Legendary = { displayName = "Legendär", displayNameEn = "Legendary", order = 5, color = { 255, 170, 30 } },
		Mythic = { displayName = "Mythisch", displayNameEn = "Mythic", order = 6, color = { 255, 60, 120 } },
		-- One pet per world, never in an egg's chance table (#81, see `secretPets`).
		Secret = { displayName = "Geheim", displayNameEn = "Secret", order = 7, color = { 20, 235, 210 } },
	},

	-- Secret pets (#81): every egg of a world with a `secretPet` first rolls this chance
	-- (per egg, x the luck potion's rarityWeights.Secret); a hit hatches that pet instead
	-- of one from the chance table. A hit is announced on all servers (MessagingService).
	secretPets = {
		chance = 1 / 20000,
		-- Server side throttle of the global announcement: at most this many per window
		-- per server (MessagingService allows ~150 + 60 x players publishes per minute).
		announceMax = 5,
		announceWindowSeconds = 60,
	},

	-- Pet variants (#80): `count` equal pets of the `from` variant merge into one of this
	-- variant (always succeeds). `bonusMultiplier` scales the pet's config bonus
	-- (GameRules.petBonus). Names: Texts "pets.variant.<id>".
	petVariants = {
		order = { "Normal", "Gold", "Rainbow" },
		Normal = { bonusMultiplier = 1 },
		Gold = { from = "Normal", count = 5, bonusMultiplier = 2.5 },
		Rainbow = { from = "Gold", count = 5, bonusMultiplier = 6 },
	},

	-- Shiny pets (#80): every hatched pet rolls this chance (x the `shinyChanceMultiplier`
	-- of running potions); Shiny adds +50 % on top of the variant (also Gold/Rainbow).
	shinyPets = {
		chance = 1 / 200,
		bonusMultiplier = 1.5,
	},

	-- Pet levels (#90): equipped pets gain `xpPerSecond` XP per second of play time.
	-- `xpToNext[n]` = XP from level n to n + 1 (here: seconds of play time, ~5.2 h to
	-- level 10 in total). Every level above 1 adds `bonusPerLevel` to the pet's effective
	-- bonus (x1.02 per level, x1.18 at level 10; GameRules.petBonus). Merging keeps the
	-- highest level of the used pets.
	petLevels = {
		maxLevel = 10,
		bonusPerLevel = 0.02,
		xpPerSecond = 1,
		xpToNext = { 300, 600, 900, 1200, 1800, 2400, 3000, 3600, 4800 },
	},

	-- Pet id -> display name, rarity and coin bonus (0.1 = +10 % sell value; bonuses add up).
	-- Flat curve (#57): the best pet of a world (both eggs) gives +75/110/160/230/320/400/500 %
	-- in worlds 1-7; the other pets of a world are scaled in the same proportion.
	pets = {
		DoughHamster = {
			displayName = "Teig-Hamster",
			displayNameEn = "Dough Hamster",
			rarity = "Common",
			bonus = 0.03,
		},
		BasilBunny = {
			displayName = "Basilikum-Hase",
			displayNameEn = "Basil Bunny",
			rarity = "Uncommon",
			bonus = 0.05,
		},
		TomatoCat = { displayName = "Tomaten-Katze", displayNameEn = "Tomato Cat", rarity = "Rare", bonus = 0.08 },
		CheeseMouse = { displayName = "Käse-Maus", displayNameEn = "Cheese Mouse", rarity = "Epic", bonus = 0.13 },
		OliveOwl = { displayName = "Oliven-Eule", displayNameEn = "Olive Owl", rarity = "Legendary", bonus = 0.25 },
		PizzaDragon = { displayName = "Pizza-Drache", displayNameEn = "Pizza Dragon", rarity = "Mythic", bonus = 0.5 },
		-- World 2 (Bauernhof)
		FarmChick = { displayName = "Hof-Küken", displayNameEn = "Farm Chick", rarity = "Common", bonus = 0.05 },
		CornPiglet = { displayName = "Mais-Ferkel", displayNameEn = "Corn Piglet", rarity = "Uncommon", bonus = 0.07 },
		PepperGoat = { displayName = "Paprika-Ziege", displayNameEn = "Pepper Goat", rarity = "Rare", bonus = 0.12 },
		OnionCow = { displayName = "Zwiebel-Kuh", displayNameEn = "Onion Cow", rarity = "Epic", bonus = 0.2 },
		HayHorse = { displayName = "Heu-Pferd", displayNameEn = "Hay Horse", rarity = "Legendary", bonus = 0.37 },
		GoldenRooster = {
			displayName = "Goldener Hahn",
			displayNameEn = "Golden Rooster",
			rarity = "Mythic",
			bonus = 0.73,
		},
		-- World 3 (Strand)
		SandCrab = { displayName = "Sand-Krabbe", displayNameEn = "Sand Crab", rarity = "Common", bonus = 0.07 },
		ShellTurtle = {
			displayName = "Muschel-Schildkröte",
			displayNameEn = "Shell Turtle",
			rarity = "Uncommon",
			bonus = 0.11,
		},
		ShrimpSeal = { displayName = "Garnelen-Robbe", displayNameEn = "Shrimp Seal", rarity = "Rare", bonus = 0.18 },
		PineappleParrot = {
			displayName = "Ananas-Papagei",
			displayNameEn = "Pineapple Parrot",
			rarity = "Epic",
			bonus = 0.28,
		},
		TunaDolphin = {
			displayName = "Thunfisch-Delfin",
			displayNameEn = "Tuna Dolphin",
			rarity = "Legendary",
			bonus = 0.53,
		},
		CoralKraken = {
			displayName = "Korallen-Krake",
			displayNameEn = "Coral Kraken",
			rarity = "Mythic",
			bonus = 1.07,
		},
		-- World 4 (Eisberge)
		IcePenguin = { displayName = "Eis-Pinguin", displayNameEn = "Ice Penguin", rarity = "Common", bonus = 0.1 },
		SnowFox = { displayName = "Schnee-Fuchs", displayNameEn = "Snow Fox", rarity = "Uncommon", bonus = 0.15 },
		PeaWalrus = { displayName = "Erbsen-Walross", displayNameEn = "Pea Walrus", rarity = "Rare", bonus = 0.26 },
		SalmonBear = { displayName = "Lachs-Bär", displayNameEn = "Salmon Bear", rarity = "Epic", bonus = 0.41 },
		LettuceYeti = { displayName = "Salat-Yeti", displayNameEn = "Lettuce Yeti", rarity = "Legendary", bonus = 0.77 },
		FrostPhoenix = {
			displayName = "Frost-Phönix",
			displayNameEn = "Frost Phoenix",
			rarity = "Mythic",
			bonus = 1.53,
		},
		-- World 5 (Vulkan)
		LavaLizard = { displayName = "Lava-Echse", displayNameEn = "Lava Lizard", rarity = "Common", bonus = 0.14 },
		ChiliSalamander = {
			displayName = "Chili-Salamander",
			displayNameEn = "Chili Salamander",
			rarity = "Uncommon",
			bonus = 0.21,
		},
		MagmaMole = { displayName = "Magma-Maulwurf", displayNameEn = "Magma Mole", rarity = "Rare", bonus = 0.36 },
		JalapenoGolem = {
			displayName = "Jalapeño-Golem",
			displayNameEn = "Jalapeño Golem",
			rarity = "Epic",
			bonus = 0.57,
		},
		FireWolf = { displayName = "Feuer-Wolf", displayNameEn = "Fire Wolf", rarity = "Legendary", bonus = 1.07 },
		LavaTitan = { displayName = "Lava-Titan", displayNameEn = "Lava Titan", rarity = "Mythic", bonus = 2.13 },
		-- World 6 (Süßigkeitenland)
		GummyWorm = { displayName = "Gummi-Wurm", displayNameEn = "Gummy Worm", rarity = "Common", bonus = 0.18 },
		LollipopPoodle = {
			displayName = "Lolli-Pudel",
			displayNameEn = "Lollipop Poodle",
			rarity = "Uncommon",
			bonus = 0.27,
		},
		MarshmallowSheep = {
			displayName = "Marshmallow-Schaf",
			displayNameEn = "Marshmallow Sheep",
			rarity = "Rare",
			bonus = 0.44,
		},
		ChocoBear = { displayName = "Schoko-Bär", displayNameEn = "Choco Bear", rarity = "Epic", bonus = 0.71 },
		CottonCandyUnicorn = {
			displayName = "Zuckerwatte-Einhorn",
			displayNameEn = "Cotton Candy Unicorn",
			rarity = "Legendary",
			bonus = 1.33,
		},
		CaramelGriffin = {
			displayName = "Karamell-Greif",
			displayNameEn = "Caramel Griffin",
			rarity = "Mythic",
			bonus = 2.67,
		},
		-- World 7 (Weltraum)
		MoonMouse = { displayName = "Mond-Maus", displayNameEn = "Moon Mouse", rarity = "Common", bonus = 0.22 },
		StarCat = { displayName = "Sternen-Katze", displayNameEn = "Star Cat", rarity = "Uncommon", bonus = 0.33 },
		AlienFrog = { displayName = "Alien-Frosch", displayNameEn = "Alien Frog", rarity = "Rare", bonus = 0.56 },
		RocketDog = { displayName = "Raketen-Hund", displayNameEn = "Rocket Dog", rarity = "Epic", bonus = 0.89 },
		CometWhale = { displayName = "Kometen-Wal", displayNameEn = "Comet Whale", rarity = "Legendary", bonus = 1.67 },
		GalaxyDragon = {
			displayName = "Galaxie-Drache",
			displayNameEn = "Galaxy Dragon",
			rarity = "Mythic",
			bonus = 3.33,
		},

		-- World 8 (Atlantis-Ei, #82): one egg; its Mythic pet is the world's best (+620 %,
		-- continuing the flat curve), the others scaled like the Space egg. Provisional (#108).
		-- Models: tools/blender/build_world.py Atlantis (one FBX for the whole world).
		KelpSnail = { displayName = "Seetang-Schnecke", displayNameEn = "Kelp Snail", rarity = "Common", bonus = 0.41 },
		BubblePufferfish = {
			displayName = "Blasen-Kugelfisch",
			displayNameEn = "Bubble Pufferfish",
			rarity = "Uncommon",
			bonus = 0.62,
		},
		CaperClownfish = {
			displayName = "Kapern-Clownfisch",
			displayNameEn = "Caper Clownfish",
			rarity = "Rare",
			bonus = 1.04,
		},
		LanternAnglerfish = {
			displayName = "Laternen-Anglerfisch",
			displayNameEn = "Lantern Anglerfish",
			rarity = "Epic",
			bonus = 1.66,
		},
		PearlMantaRay = {
			displayName = "Perlen-Mantarochen",
			displayNameEn = "Pearl Manta Ray",
			rarity = "Legendary",
			bonus = 3.1,
		},
		PoseidonSeaDragon = {
			displayName = "Poseidon-Seedrache",
			displayNameEn = "Poseidon Sea Dragon",
			rarity = "Mythic",
			bonus = 6.2,
		},

		-- Second egg per world (#39): Selten to Mythisch only, each about 1.5x the bonus of
		-- the same rarity in the world's first egg. Models: tools/blender/build_pets.py (#40).
		-- World 1 (Steinofen-Ei)
		RucolaHedgehog = {
			displayName = "Rucola-Igel",
			displayNameEn = "Arugula Hedgehog",
			rarity = "Rare",
			bonus = 0.12,
		},
		ParmesanRaccoon = {
			displayName = "Parmesan-Waschbär",
			displayNameEn = "Parmesan Raccoon",
			rarity = "Epic",
			bonus = 0.2,
		},
		TruffleFox = {
			displayName = "Trüffel-Fuchs",
			displayNameEn = "Truffle Fox",
			rarity = "Legendary",
			bonus = 0.38,
		},
		StoneOvenPhoenix = {
			displayName = "Steinofen-Phönix",
			displayNameEn = "Stone Oven Phoenix",
			rarity = "Mythic",
			bonus = 0.75,
		},
		-- World 2 (Scheunen-Ei)
		PumpkinCat = { displayName = "Kürbis-Katze", displayNameEn = "Pumpkin Cat", rarity = "Rare", bonus = 0.18 },
		ButterDonkey = { displayName = "Butter-Esel", displayNameEn = "Butter Donkey", rarity = "Epic", bonus = 0.29 },
		HoneyBear = { displayName = "Honig-Bär", displayNameEn = "Honey Bear", rarity = "Legendary", bonus = 0.55 },
		GoldGrainBull = {
			displayName = "Goldkorn-Stier",
			displayNameEn = "Gold Grain Bull",
			rarity = "Mythic",
			bonus = 1.1,
		},
		-- World 3 (Muschel-Ei)
		CoconutMonkey = { displayName = "Kokos-Affe", displayNameEn = "Coconut Monkey", rarity = "Rare", bonus = 0.27 },
		ShellSeahorse = {
			displayName = "Muschel-Seepferdchen",
			displayNameEn = "Shell Seahorse",
			rarity = "Epic",
			bonus = 0.43,
		},
		SardineShark = {
			displayName = "Sardinen-Hai",
			displayNameEn = "Sardine Shark",
			rarity = "Legendary",
			bonus = 0.8,
		},
		PearlSeaSerpent = {
			displayName = "Perlen-Seeschlange",
			displayNameEn = "Pearl Sea Serpent",
			rarity = "Mythic",
			bonus = 1.6,
		},
		-- World 4 (Gletscher-Ei)
		MintReindeer = { displayName = "Minz-Rentier", displayNameEn = "Mint Reindeer", rarity = "Rare", bonus = 0.38 },
		SundaePolarBear = {
			displayName = "Eisbecher-Eisbär",
			displayNameEn = "Sundae Polar Bear",
			rarity = "Epic",
			bonus = 0.61,
		},
		VanillaMammoth = {
			displayName = "Vanille-Mammut",
			displayNameEn = "Vanilla Mammoth",
			rarity = "Legendary",
			bonus = 1.15,
		},
		SorbetNarwhal = {
			displayName = "Sorbet-Narwal",
			displayNameEn = "Sorbet Narwhal",
			rarity = "Mythic",
			bonus = 2.3,
		},
		-- World 5 (Magma-Ei)
		PepperScorpion = {
			displayName = "Pfeffer-Skorpion",
			displayNameEn = "Pepper Scorpion",
			rarity = "Rare",
			bonus = 0.53,
		},
		HabaneroRhino = {
			displayName = "Habanero-Nashorn",
			displayNameEn = "Habanero Rhino",
			rarity = "Epic",
			bonus = 0.85,
		},
		CurryTiger = { displayName = "Curry-Tiger", displayNameEn = "Curry Tiger", rarity = "Legendary", bonus = 1.6 },
		CalzoneHydra = {
			displayName = "Calzone-Hydra",
			displayNameEn = "Calzone Hydra",
			rarity = "Mythic",
			bonus = 3.2,
		},
		-- World 6 (Bonbon-Ei)
		DonutDachshund = {
			displayName = "Donut-Dackel",
			displayNameEn = "Donut Dachshund",
			rarity = "Rare",
			bonus = 0.67,
		},
		PuddingPanda = { displayName = "Pudding-Panda", displayNameEn = "Pudding Panda", rarity = "Epic", bonus = 1.07 },
		LicoricePanther = {
			displayName = "Lakritz-Panther",
			displayNameEn = "Licorice Panther",
			rarity = "Legendary",
			bonus = 2,
		},
		CakePegasus = { displayName = "Torten-Pegasus", displayNameEn = "Cake Pegasus", rarity = "Mythic", bonus = 4 },
		-- World 7 (Nebula-Ei)
		MooncakeBunny = {
			displayName = "Mondkuchen-Hase",
			displayNameEn = "Mooncake Bunny",
			rarity = "Rare",
			bonus = 0.83,
		},
		StarfruitJellyfish = {
			displayName = "Sternfrucht-Qualle",
			displayNameEn = "Starfruit Jellyfish",
			rarity = "Epic",
			bonus = 1.33,
		},
		StardustLion = {
			displayName = "Sternenstaub-Löwe",
			displayNameEn = "Stardust Lion",
			rarity = "Legendary",
			bonus = 2.5,
		},
		GalaxyPizzaLeviathan = {
			displayName = "Galaxie-Pizza-Leviathan",
			displayNameEn = "Galaxy Pizza Leviathan",
			rarity = "Mythic",
			bonus = 5,
		},
		-- Secret pets (#81): one per world, twice the bonus of the world's best pet.
		-- Models: tools/blender/build_secret_pets.py.
		MozzarellaGhost = {
			displayName = "Mozzarella-Geist",
			displayNameEn = "Mozzarella Ghost",
			rarity = "Secret",
			bonus = 1.5,
		},
		ScarecrowRaven = {
			displayName = "Vogelscheuchen-Rabe",
			displayNameEn = "Scarecrow Raven",
			rarity = "Secret",
			bonus = 2.2,
		},
		TreasureOctopus = {
			displayName = "Schatz-Oktopus",
			displayNameEn = "Treasure Octopus",
			rarity = "Secret",
			bonus = 3.2,
		},
		AuroraWolf = {
			displayName = "Polarlicht-Wolf",
			displayNameEn = "Aurora Wolf",
			rarity = "Secret",
			bonus = 4.6,
		},
		ObsidianDragon = {
			displayName = "Obsidian-Drache",
			displayNameEn = "Obsidian Dragon",
			rarity = "Secret",
			bonus = 6.4,
		},
		GingerbreadGolem = {
			displayName = "Lebkuchen-Golem",
			displayNameEn = "Gingerbread Golem",
			rarity = "Secret",
			bonus = 8,
		},
		BlackHoleCat = {
			displayName = "Schwarzloch-Katze",
			displayNameEn = "Black Hole Cat",
			rarity = "Secret",
			bonus = 10,
		},
		PearlKingOtter = {
			displayName = "Perlenkönig-Otter",
			displayNameEn = "Pearl King Otter",
			rarity = "Secret",
			bonus = 12.4,
		},
	},

	-- Egg id -> price in coins and pets with their chance in percent (must add up to 100).
	-- Every world has two eggs: the first with 6 pets (Gewöhnlich to Mythisch) and a
	-- second one (#39, `fancy` look) at about 5x the price with 4 stronger pets (Selten
	-- to Mythisch), open as soon as the world is unlocked.
	-- `look`: colours (hex) and pattern of the egg model (tools/blender/build_eggs.py reads
	-- them from here) and of the placeholder egg. Patterns: Spots, Stripes, Waves, Diamonds,
	-- Cracks, Swirl, Stars, Bubbles. `glow` = accent glows (Neon); `fancy` = showier variant
	-- (gold band and beads, meant for a second egg per world).
	eggs = {
		GardenEgg = {
			displayName = "Garten-Ei",
			displayNameEn = "Garden Egg",
			look = { color = "FFF3DC", accent = "E8452E", pattern = "Spots" },
			price = 25,
			pets = {
				{ pet = "DoughHamster", chance = 50 },
				{ pet = "BasilBunny", chance = 28 },
				{ pet = "TomatoCat", chance = 15 },
				{ pet = "CheeseMouse", chance = 5.5 },
				{ pet = "OliveOwl", chance = 1 },
				{ pet = "PizzaDragon", chance = 0.5 },
			},
		},
		StoneOvenEgg = {
			displayName = "Steinofen-Ei",
			displayNameEn = "Stone Oven Egg",
			look = { color = "C9653A", accent = "FFD27A", pattern = "Cracks", fancy = true },
			price = 130,
			pets = {
				{ pet = "RucolaHedgehog", chance = 68 },
				{ pet = "ParmesanRaccoon", chance = 25 },
				{ pet = "TruffleFox", chance = 6 },
				{ pet = "StoneOvenPhoenix", chance = 1 },
			},
		},
		FarmEgg = {
			displayName = "Bauernhof-Ei",
			displayNameEn = "Farm Egg",
			look = { color = "F2CF6B", accent = "8A5A2B", pattern = "Stripes" },
			price = 48,
			pets = {
				{ pet = "FarmChick", chance = 50 },
				{ pet = "CornPiglet", chance = 28 },
				{ pet = "PepperGoat", chance = 15 },
				{ pet = "OnionCow", chance = 5.5 },
				{ pet = "HayHorse", chance = 1 },
				{ pet = "GoldenRooster", chance = 0.5 },
			},
		},
		BarnEgg = {
			displayName = "Scheunen-Ei",
			displayNameEn = "Barn Egg",
			look = { color = "B8322A", accent = "FFFFFF", pattern = "Diamonds", fancy = true },
			price = 240,
			pets = {
				{ pet = "PumpkinCat", chance = 68 },
				{ pet = "ButterDonkey", chance = 25 },
				{ pet = "HoneyBear", chance = 6 },
				{ pet = "GoldGrainBull", chance = 1 },
			},
		},
		BeachEgg = {
			displayName = "Strand-Ei",
			displayNameEn = "Beach Egg",
			look = { color = "4FCFE0", accent = "FFF1C1", pattern = "Waves" },
			price = 500,
			pets = {
				{ pet = "SandCrab", chance = 50 },
				{ pet = "ShellTurtle", chance = 28 },
				{ pet = "ShrimpSeal", chance = 15 },
				{ pet = "PineappleParrot", chance = 5.5 },
				{ pet = "TunaDolphin", chance = 1 },
				{ pet = "CoralKraken", chance = 0.5 },
			},
		},
		ShellEgg = {
			displayName = "Muschel-Ei",
			displayNameEn = "Shell Egg",
			look = { color = "FFD7C9", accent = "E86F8F", pattern = "Swirl", fancy = true },
			price = 2500,
			pets = {
				{ pet = "CoconutMonkey", chance = 68 },
				{ pet = "ShellSeahorse", chance = 25 },
				{ pet = "SardineShark", chance = 6 },
				{ pet = "PearlSeaSerpent", chance = 1 },
			},
		},
		IceEgg = {
			displayName = "Eis-Ei",
			displayNameEn = "Ice Egg",
			look = { color = "DDF3FF", accent = "3E9BE6", pattern = "Diamonds" },
			price = 3700,
			pets = {
				{ pet = "IcePenguin", chance = 50 },
				{ pet = "SnowFox", chance = 28 },
				{ pet = "PeaWalrus", chance = 15 },
				{ pet = "SalmonBear", chance = 5.5 },
				{ pet = "LettuceYeti", chance = 1 },
				{ pet = "FrostPhoenix", chance = 0.5 },
			},
		},
		GlacierEgg = {
			displayName = "Gletscher-Ei",
			displayNameEn = "Glacier Egg",
			look = { color = "8FD8E8", accent = "FFFFFF", pattern = "Stars", fancy = true },
			price = 19000,
			pets = {
				{ pet = "MintReindeer", chance = 68 },
				{ pet = "SundaePolarBear", chance = 25 },
				{ pet = "VanillaMammoth", chance = 6 },
				{ pet = "SorbetNarwhal", chance = 1 },
			},
		},
		VolcanoEgg = {
			displayName = "Vulkan-Ei",
			displayNameEn = "Volcano Egg",
			look = { color = "5A2A24", accent = "FF7A1A", pattern = "Cracks", glow = true },
			price = 20000,
			pets = {
				{ pet = "LavaLizard", chance = 50 },
				{ pet = "ChiliSalamander", chance = 28 },
				{ pet = "MagmaMole", chance = 15 },
				{ pet = "JalapenoGolem", chance = 5.5 },
				{ pet = "FireWolf", chance = 1 },
				{ pet = "LavaTitan", chance = 0.5 },
			},
		},
		MagmaEgg = {
			displayName = "Magma-Ei",
			displayNameEn = "Magma Egg",
			look = { color = "2A1A1A", accent = "FF3A1A", pattern = "Waves", glow = true, fancy = true },
			price = 100000,
			pets = {
				{ pet = "PepperScorpion", chance = 68 },
				{ pet = "HabaneroRhino", chance = 25 },
				{ pet = "CurryTiger", chance = 6 },
				{ pet = "CalzoneHydra", chance = 1 },
			},
		},
		CandyEgg = {
			displayName = "Süßigkeiten-Ei",
			displayNameEn = "Candy Egg",
			look = { color = "FF8CC6", accent = "FFFFFF", pattern = "Swirl" },
			price = 82000,
			pets = {
				{ pet = "GummyWorm", chance = 50 },
				{ pet = "LollipopPoodle", chance = 28 },
				{ pet = "MarshmallowSheep", chance = 15 },
				{ pet = "ChocoBear", chance = 5.5 },
				{ pet = "CottonCandyUnicorn", chance = 1 },
				{ pet = "CaramelGriffin", chance = 0.5 },
			},
		},
		BonbonEgg = {
			displayName = "Bonbon-Ei",
			displayNameEn = "Sweets Egg",
			look = { color = "9B6BFF", accent = "FFE14A", pattern = "Stripes", fancy = true },
			price = 410000,
			pets = {
				{ pet = "DonutDachshund", chance = 68 },
				{ pet = "PuddingPanda", chance = 25 },
				{ pet = "LicoricePanther", chance = 6 },
				{ pet = "CakePegasus", chance = 1 },
			},
		},
		SpaceEgg = {
			displayName = "Weltraum-Ei",
			displayNameEn = "Space Egg",
			look = { color = "3B2A7A", accent = "FFD84A", pattern = "Stars", glow = true },
			price = 390000,
			pets = {
				{ pet = "MoonMouse", chance = 50 },
				{ pet = "StarCat", chance = 28 },
				{ pet = "AlienFrog", chance = 15 },
				{ pet = "RocketDog", chance = 5.5 },
				{ pet = "CometWhale", chance = 1 },
				{ pet = "GalaxyDragon", chance = 0.5 },
			},
		},
		NebulaEgg = {
			displayName = "Nebula-Ei",
			displayNameEn = "Nebula Egg",
			look = { color = "14163A", accent = "C86BFF", pattern = "Spots", glow = true, fancy = true },
			price = 2000000,
			pets = {
				{ pet = "MooncakeBunny", chance = 68 },
				{ pet = "StarfruitJellyfish", chance = 25 },
				{ pet = "StardustLion", chance = 6 },
				{ pet = "GalaxyPizzaLeviathan", chance = 1 },
			},
		},
		-- World 8 (#82): the new worlds have one egg with 6 pets. Price provisional (#108).
		AtlantisEgg = {
			displayName = "Atlantis-Ei",
			displayNameEn = "Atlantis Egg",
			look = { color = "1E8FB8", accent = "FFE9A8", pattern = "Bubbles", glow = true },
			price = 4800000,
			pets = {
				{ pet = "KelpSnail", chance = 50 },
				{ pet = "BubblePufferfish", chance = 28 },
				{ pet = "CaperClownfish", chance = 15 },
				{ pet = "LanternAnglerfish", chance = 5.5 },
				{ pet = "PearlMantaRay", chance = 1 },
				{ pet = "PoseidonSeaDragon", chance = 0.5 },
			},
		},
	},

	-- Shops by id. Each sells its `offers` up to `maxLevel`; bigger shops in later
	-- worlds offer the same upgrades with higher max levels (config only).
	shops = {
		World1Shop = {
			worldId = "PizzeriaGarden",
			displayName = "Pizza-Shop",
			displayNameEn = "Pizza Shop",
			offers = {
				{ upgrade = "PizzaSpace", maxLevel = 3 },
				{ upgrade = "CollectRange", maxLevel = 3 },
				{ upgrade = "Magnet", maxLevel = 1 },
				-- Gem counter
				{ upgrade = "PetSlots", maxLevel = 2 },
				{ upgrade = "InventorySpace", maxLevel = 2 },
				{ upgrade = "WalkSpeed", maxLevel = 2 },
				{ upgrade = "TripleOpen", maxLevel = 1 },
				{ upgrade = "GoldLuck", maxLevel = 2 },
			},
			-- Potions sold at the gem counter.
			potions = { "Coins", "Luck", "Speed" },
		},
		-- Shop 2: everything from shop 1 plus higher levels, in world 4.
		World4Shop = {
			worldId = "Icebergs",
			displayName = "Großer Pizza-Shop",
			displayNameEn = "Big Pizza Shop",
			offers = {
				{ upgrade = "PizzaSpace", maxLevel = 6 },
				{ upgrade = "CollectRange", maxLevel = 6 },
				{ upgrade = "Magnet", maxLevel = 3 },
				-- Gem counter
				{ upgrade = "PetSlots", maxLevel = 4 },
				{ upgrade = "InventorySpace", maxLevel = 4 },
				{ upgrade = "WalkSpeed", maxLevel = 4 },
				{ upgrade = "TripleOpen", maxLevel = 1 },
				{ upgrade = "GoldLuck", maxLevel = 4 },
			},
			-- Potions sold at the gem counter.
			potions = { "Coins", "Luck", "Speed" },
		},
		-- Shop 3: the biggest shop with every upgrade up to its last level, in world 7.
		World7Shop = {
			worldId = "Space",
			displayName = "Riesiger Pizza-Shop",
			displayNameEn = "Giant Pizza Shop",
			offers = {
				{ upgrade = "PizzaSpace", maxLevel = 8 },
				{ upgrade = "CollectRange", maxLevel = 8 },
				{ upgrade = "Magnet", maxLevel = 5 },
				-- Gem counter
				{ upgrade = "PetSlots", maxLevel = 5 },
				{ upgrade = "InventorySpace", maxLevel = 5 },
				{ upgrade = "WalkSpeed", maxLevel = 5 },
				{ upgrade = "TripleOpen", maxLevel = 1 },
				{ upgrade = "GoldLuck", maxLevel = 5 },
			},
			-- Potions sold at the gem counter.
			potions = { "Coins", "Luck", "Speed" },
		},
		-- Every new world (#82-#89) has its own shop. For now with the levels of shop 3
		-- (all levels there are); #108 adds higher levels for the new worlds.
		World8Shop = {
			worldId = "Atlantis",
			displayName = "Atlantis-Shop",
			displayNameEn = "Atlantis Shop",
			offers = {
				{ upgrade = "PizzaSpace", maxLevel = 8 },
				{ upgrade = "CollectRange", maxLevel = 8 },
				{ upgrade = "Magnet", maxLevel = 5 },
				-- Gem counter
				{ upgrade = "PetSlots", maxLevel = 5 },
				{ upgrade = "InventorySpace", maxLevel = 5 },
				{ upgrade = "WalkSpeed", maxLevel = 5 },
				{ upgrade = "TripleOpen", maxLevel = 1 },
				{ upgrade = "GoldLuck", maxLevel = 5 },
			},
			-- Potions sold at the gem counter.
			potions = { "Coins", "Luck", "Speed" },
		},
	},

	-- Flying islands (#27): spawn island, then world 1, 2, ... in a chain along -Z, all at
	-- the same height, joined by bridges. Geometry is planned by IslandPlan (pure) and
	-- built by the server; local coordinates below: x = right of the main path, z = +front
	-- (where the bridge arrives), studs.
	islands = {
		groundY = 0.1,
		-- World islands are at most this far from their center (topping field unchanged).
		worldHalfSize = 100,
		spawnRadius = 62,
		-- Most parts the spawn island may have (marketplace deco included, #106).
		spawnPartBudget = 1000,
		bridgeLength = 40,
		bridgeWidth = 12,
		-- Invisible collision wall around every island and along every bridge.
		wallHeight = 24,
		-- Below this height a character has fallen off and respawns in its current world.
		fallY = -70,
		-- Main path from the arriving bridge to the field (and from the field to the next bridge).
		pathWidth = 12,
		-- Shared floor plan of every world island. Stations left of the path (x < 0) face
		-- +X, right of it (x > 0) face -X, so the camera stays over the path while using them.
		layout = {
			spawn = { 0, 86 },
			field = { center = { 0, -25 }, size = { 120, 100 } },
			oven = { 31, 84 },
			portal = { -30, 86 },
			shop = { -31, 68 },
			eggs = { { -27, 52 }, { -27, 38 } },
			phone = { 24, 66 },
			van = { 31, 47 },
			landmark = { -48, -86 },
			pond = { 72, 58 },
			-- Raised grass terraces behind the field (x, z, radius, height).
			terraces = { { -48, -86, 15, 4 }, { 50, -84, 13, 3 } },
		},
		-- Spawn island floor plan (bridge to world 1 leaves at -z).
		-- Marketplace (#106): update board and Christmas countdown beside the spawn (facing
		-- it), benches and lanterns around the fountain, and spots kept free for later
		-- tickets (`reserved`: name -> { x, z, clear radius }; the server puts an invisible
		-- anchor part "<name>Anchor" there): the lucky wheel (#98), the merchant stand
		-- (#107) and the two new leaderboards Board4/Board5 (#109) beside the three boards.
		spawnLayout = {
			spawn = { 0, 26 },
			fountain = { 0, 0 },
			portal = { -34, -12 },
			boards = { { -30, 20 }, { 0, 42 }, { 30, 20 } },
			pond = { 38, -8 },
			updateBoard = { -14, 20 },
			countdown = { 14, 20 },
			reserved = {
				Wheel = { 28, -34, 11 },
				Merchant = { -26, -38, 10 },
				Board4 = { -17, 47, 8 },
				Board5 = { 17, 47, 8 },
			},
			-- Benches around the fountain (angle in degrees, x = 0, z = 90) and lanterns
			-- ({ x, z }, at most 6: each lamp has a light).
			benchAngles = { 45, 135, 240, 300 },
			benchRadius = 21.5,
			lanterns = { { -8, -52 }, { 8, -52 }, { -8, -30 }, { 8, -26 }, { -21.5, 0 }, { 21.5, 0 } },
			flowerBeds = { { -40, -36 }, { 44, -30 }, { -46, 6 }, { 48, 30 }, { -22, 32 }, { 22, 32 } },
		},
		-- Look of each island world (others use PizzeriaGarden). Colours are RGB 0-255.
		-- Optional per world (defaults = world 1):
		--   rimStyle     "Hedge" | "Fence" | "Rocks" | "IceEdge" | "Basalt" | "Peppermint" | "Moonbase"
		--                | "CoralReef" (with `corals` = knob colours)
		--                (low visible rim)
		--   landmark     "GiantPizza" | "Windmill" | "Lighthouse" | "IcePeak" | "Volcano" | "Cake"
		--                | "Rocket" | "SunkenTemple" (back left terrace)
		--   bridge       "Rope" | "Boardwalk" | "Ice" | "Basalt" | "CandyCane" | "Light": style of
		--                the bridge leading INTO the world
		--   trees        tree models scattered along the rim (ModelLibrary names); false = none
		--   treeScale    size factor for those (default 1: 10-16 studs wide)
		--   accents      { model, width } props along the field's long sides
		--   terraceProps { terrace, model, width, at = { x, z }, yaw?, collide?, lift? } on a
		--                terrace (lift = studs above the terrace top, e.g. a floating planet)
		--   fieldRows    colour of furrows across the topping field
		--   flowerStems  false = flowers are pebbles/shells lying on the ground
		--   cracks       glowing cracks in the ground { x, z, length, yaw (degrees) } in the
		--                colour `glow` (Neon with a small light each, so keep them few)
		--   deco         scripted decoration of the new worlds (#82), no import needed:
		--                { budget = max parts, kits = { { kit, count, size = { min, max },
		--                colors? } } } with kits "Coral", "Column", "Kelp", "Bubbles", "Lamp"
		--                (IslandPlan DECO_KITS). Optional bits are hidden on graphics "Low"
		--                (#76); everything is left out when features.worldDeco is off.
		--   ruin, ruinDark, shell  stone colours of the SunkenTemple / lamps, clam shell colour
		themes = {
			PizzeriaGarden = {
				grass = { 104, 196, 72 },
				grassLight = { 132, 214, 88 },
				field = { 146, 222, 100 },
				cliff = { 168, 120, 84 },
				cliffDark = { 132, 92, 66 },
				cliffLight = { 196, 150, 104 },
				rim = { 66, 150, 60 },
				path = { 236, 214, 170 },
				pathDark = { 214, 188, 142 },
				water = { 70, 190, 240 },
				wood = { 160, 104, 58 },
				rope = { 222, 196, 140 },
				flowers = { { 255, 110, 150 }, { 255, 220, 70 }, { 160, 130, 255 }, { 255, 255, 255 } },
			},
			-- World 2: meadow with a ploughed field, white fence, windmill and red barn.
			Farm = {
				grass = { 124, 196, 76 },
				grassLight = { 150, 214, 92 },
				field = { 182, 136, 88 },
				fieldRows = { 156, 112, 70 },
				cliff = { 176, 124, 82 },
				cliffDark = { 140, 96, 64 },
				cliffLight = { 214, 176, 128 },
				rim = { 250, 246, 236 },
				rimStyle = "Fence",
				path = { 226, 190, 132 },
				pathDark = { 204, 166, 110 },
				water = { 80, 186, 236 },
				wood = { 168, 110, 62 },
				woodDark = { 128, 82, 48 },
				rope = { 222, 196, 140 },
				flowers = { { 255, 206, 40 }, { 255, 255, 255 }, { 255, 140, 60 }, { 220, 90, 160 } },
				landmark = "Windmill",
				bridge = "Rope",
				trees = { "RoundTree", "Tree" },
				accents = { { model = "HayBale", width = 6 }, { model = "Sunflower", width = 4 } },
				terraceProps = {
					{ terrace = 2, model = "Barn", width = 20, at = { 0, -1 }, yaw = 200, collide = true },
				},
			},
			-- World 3: sandy island with palms, a turquoise lagoon, boulder rim and lighthouse.
			Beach = {
				grass = { 242, 220, 160 },
				grassLight = { 248, 232, 186 },
				field = { 228, 200, 146 },
				cliff = { 210, 170, 116 },
				cliffDark = { 178, 136, 92 },
				cliffLight = { 232, 200, 146 },
				rim = { 196, 186, 172 },
				rimStyle = "Rocks",
				path = { 214, 168, 112 },
				pathDark = { 188, 140, 90 },
				water = { 50, 206, 220 },
				waterfall = { 150, 236, 245 },
				wood = { 196, 146, 92 },
				woodDark = { 150, 104, 64 },
				rope = { 232, 210, 160 },
				flowers = { { 255, 170, 180 }, { 255, 246, 236 }, { 255, 190, 120 }, { 240, 120, 120 } },
				flowerStems = false,
				landmark = "Lighthouse",
				bridge = "Boardwalk",
				trees = { "PalmTree" },
				accents = { { model = "BeachUmbrella", width = 8 }, { model = "BeachRock", width = 4 } },
				terraceProps = {
					{ terrace = 2, model = "BeachUmbrella", width = 9, at = { -4, 2 } },
					{ terrace = 2, model = "BeachRock", width = 5, at = { 5, -4 }, collide = true },
				},
			},
			-- World 4: snowy island with pines, ice-block rim, frozen pond and an ice peak.
			Icebergs = {
				grass = { 236, 244, 252 },
				grassLight = { 248, 252, 255 },
				field = { 214, 234, 250 },
				cliff = { 150, 196, 230 },
				cliffDark = { 112, 164, 210 },
				cliffLight = { 196, 226, 248 },
				rim = { 176, 218, 248 },
				rimStyle = "IceEdge",
				path = { 196, 226, 248 },
				pathDark = { 170, 208, 240 },
				water = { 120, 200, 240 },
				waterfall = { 200, 240, 255 },
				wood = { 150, 104, 70 },
				woodDark = { 112, 76, 52 },
				rope = { 220, 236, 248 },
				snow = { 248, 252, 255 },
				ice = { 170, 222, 255 },
				iceDark = { 130, 196, 240 },
				flowers = { { 150, 214, 255 }, { 255, 255, 255 }, { 190, 170, 255 } },
				flowerStems = false,
				landmark = "IcePeak",
				bridge = "Ice",
				trees = { "SnowPine" },
				accents = { { model = "Snowman", width = 4.5 }, { model = "IceCrystal", width = 3.5 } },
				terraceProps = {
					{ terrace = 2, model = "Snowman", width = 5, at = { -3, 1 }, yaw = 160, collide = true },
					{ terrace = 2, model = "IceCrystal", width = 6, at = { 5, -3 }, yaw = 30, collide = true },
				},
			},
			-- World 5: warm basalt island with a lava pond, basalt-column rim and a volcano.
			-- Kept light (#24): light ash ground and field, lava only as a few accents.
			Volcano = {
				grass = { 188, 138, 112 },
				grassLight = { 208, 160, 132 },
				field = { 224, 194, 166 },
				cliff = { 150, 108, 92 },
				cliffDark = { 120, 88, 80 },
				cliffLight = { 182, 136, 114 },
				rim = { 120, 98, 94 },
				rimStyle = "Basalt",
				path = { 216, 190, 168 },
				pathDark = { 196, 168, 146 },
				water = { 255, 122, 40 },
				waterfall = { 255, 150, 60 },
				wood = { 132, 100, 88 },
				woodDark = { 104, 80, 74 },
				rope = { 200, 170, 150 },
				glow = { 255, 128, 36 },
				-- Volcano landmark (#47): dark basalt layers and crater rim.
				basalt = { { 62, 54, 56 }, { 76, 66, 66 }, { 50, 45, 48 } },
				basaltDark = { 38, 34, 38 },
				flowers = { { 255, 140, 50 }, { 255, 200, 80 }, { 236, 92, 56 } },
				flowerStems = false,
				landmark = "Volcano",
				bridge = "Basalt",
				trees = { "LavaRock", "DeadTree", "LavaRock" },
				treeScale = 0.75,
				accents = { { model = "LavaRock", width = 5 }, { model = "DeadTree", width = 5 } },
				terraceProps = {
					{ terrace = 2, model = "LavaRock", width = 9, at = { -3, 2 }, yaw = 40, collide = true },
					{ terrace = 2, model = "DeadTree", width = 6, at = { 5, -4 }, yaw = 120 },
				},
				cracks = { { -78, -30, 12, 20 }, { 80, -40, 12, -15 }, { 18, -90, 12, 80 }, { -70, 20, 10, -25 } },
			},
			-- World 6: pink candy island with a chocolate lake, peppermint rim and a layer cake.
			CandyLand = {
				grass = { 255, 188, 220 },
				grassLight = { 255, 210, 232 },
				field = { 198, 238, 214 },
				cliff = { 218, 156, 102 },
				cliffDark = { 156, 98, 64 },
				cliffLight = { 244, 200, 146 },
				rim = { 232, 42, 62 },
				rimStyle = "Peppermint",
				path = { 156, 98, 64 },
				pathDark = { 132, 82, 54 },
				water = { 124, 74, 46 },
				waterfall = { 150, 94, 60 },
				wood = { 255, 246, 250 },
				woodDark = { 240, 214, 226 },
				rope = { 255, 246, 250 },
				frosting = { 255, 246, 250 },
				candy = { { 255, 92, 162 }, { 120, 200, 242 }, { 255, 220, 70 }, { 150, 220, 110 }, { 190, 140, 255 } },
				flowers = {
					{ 255, 92, 162 },
					{ 120, 200, 242 },
					{ 255, 220, 70 },
					{ 150, 220, 110 },
					{ 190, 140, 255 },
				},
				flowerStems = false,
				landmark = "Cake",
				bridge = "CandyCane",
				trees = { "Lollipop" },
				treeScale = 0.55,
				accents = { { model = "Cupcake", width = 5 }, { model = "CandyCane", width = 2.5 } },
				terraceProps = {
					{ terrace = 2, model = "Cupcake", width = 9, at = { -3, 2 }, collide = true },
					{ terrace = 2, model = "Lollipop", width = 5, at = { 6, -3 }, yaw = 30 },
				},
			},
			-- World 7: moon island at night with a starlight pond, a moon-base rim, a rocket on
			-- its launch pad and a planet floating above the right terrace. Ground kept light;
			-- glowing parts only as small tips (Neon is strong at night).
			Space = {
				grass = { 176, 172, 208 },
				grassLight = { 200, 196, 228 },
				field = { 150, 140, 206 },
				cliff = { 124, 120, 156 },
				cliffDark = { 100, 96, 132 },
				cliffLight = { 156, 152, 186 },
				rim = { 226, 230, 242 },
				rimStyle = "Moonbase",
				path = { 214, 218, 232 },
				pathDark = { 188, 194, 214 },
				water = { 110, 214, 255 },
				waterfall = { 170, 236, 255 },
				wood = { 200, 204, 220 },
				woodDark = { 150, 156, 176 },
				rope = { 226, 230, 242 },
				glow = { 120, 255, 210 },
				flowers = { { 120, 255, 210 }, { 255, 230, 120 }, { 190, 150, 255 } },
				flowerStems = false,
				landmark = "Rocket",
				bridge = "Light",
				trees = { "MoonRock" },
				accents = { { model = "SpaceCrystal", width = 3 }, { model = "MoonRock", width = 4 } },
				terraceProps = {
					{ terrace = 2, model = "Planet", width = 12, at = { 0, 0 }, yaw = 20, lift = 14 },
					{ terrace = 2, model = "SpaceCrystal", width = 4, at = { 5, -4 }, yaw = 60 },
				},
			},
			-- World 8 (#82): sunken island on the sea floor - pale sand, turquoise water,
			-- coral rocks as rim, a glassy sea-glass bridge, ruins of a sunken temple with a
			-- glowing pearl, corals, kelp, ruin columns, rising bubbles and blue lamps
			-- (scripted deco, ~400 parts). The pattern for the worlds of #83-#89.
			Atlantis = {
				grass = { 222, 212, 176 },
				grassLight = { 236, 228, 196 },
				field = { 196, 222, 214 },
				cliff = { 120, 150, 170 },
				cliffDark = { 92, 118, 140 },
				cliffLight = { 158, 186, 200 },
				rim = { 255, 128, 120 },
				rimStyle = "CoralReef",
				corals = { { 255, 128, 120 }, { 190, 120, 255 }, { 255, 200, 100 }, { 80, 220, 210 } },
				path = { 232, 236, 226 },
				pathDark = { 206, 216, 208 },
				water = { 60, 200, 230 },
				waterfall = { 160, 236, 255 },
				wood = { 150, 176, 188 },
				woodDark = { 110, 136, 150 },
				rope = { 230, 240, 236 },
				ice = { 110, 220, 240 },
				iceDark = { 40, 120, 170 },
				snow = { 236, 252, 255 },
				glow = { 120, 220, 255 },
				ruin = { 226, 230, 222 },
				ruinDark = { 180, 194, 196 },
				shell = { 255, 206, 222 },
				flowers = { { 255, 206, 222 }, { 255, 244, 214 }, { 140, 230, 230 }, { 255, 160, 120 } },
				flowerStems = false,
				landmark = "SunkenTemple",
				bridge = "Ice",
				trees = false,
				accents = { { model = "BeachRock", width = 4 } },
				deco = {
					budget = 400,
					kits = {
						{ kit = "Lamp", count = 4, size = { 2.6, 3 }, colors = { { 90, 190, 255 } } },
						{
							kit = "Column",
							count = 14,
							size = { 7, 12 },
							colors = { { 226, 230, 222 }, { 180, 194, 196 } },
						},
						{
							kit = "Kelp",
							count = 36,
							size = { 6, 11 },
							colors = { { 60, 170, 90 }, { 90, 196, 110 }, { 40, 140, 100 } },
						},
						{
							kit = "Coral",
							count = 42,
							size = { 3.5, 7 },
							colors = {
								{ 255, 110, 130 },
								{ 255, 160, 90 },
								{ 190, 120, 255 },
								{ 80, 220, 210 },
								{ 255, 220, 110 },
							},
						},
						{ kit = "Bubbles", count = 10, size = { 2, 4 }, colors = { { 210, 244, 255 } } },
					},
				},
			},
		},
	},

	-- Weather kinds (#72): names and look only. The rules (every ~15 min for 2 min per
	-- world, +20 % toppings) and the effects come with #105; worlds pick theirs with
	-- `weather = "<id>"`. `particles`: colours (RGB) of the weather particles.
	weathers = {
		BubbleStorm = {
			displayName = "Blasen-Sturm",
			displayNameEn = "Bubble Storm",
			particles = { { 200, 240, 255 }, { 150, 220, 255 } },
		},
	},

	-- Event islands (#77), prepared for event updates (e.g. Christmas); none in this update.
	-- They stand outside the world order: no coin price, no rebirth tier. The portal sends
	-- players there while the event runs (startsAt <= now < endsAt, Unix seconds); toppings
	-- with a `currency` (in `toppings`) pay that event currency instead of coins, at their
	-- plain value (no pet/rebirth/potion multiplier). The island sits beside the spawn
	-- island (IslandPlan.eventCenter) and uses `islands.themes[id]` like a world.
	-- Entry: { id, displayName, displayNameEn, currency, startsAt, endsAt, color,
	--          toppingSpawns = { { topping, weight } }, eggs = { ... }? }
	eventWorlds = {},
	-- Event currency id -> { displayName, displayNameEn }; kept through rebirths.
	eventCurrencies = {},

	-- First visit of a world (#79, switch features.worldIntro): length of the camera flight
	-- over the island in seconds (3-4 s, skippable by a tap). The start world has none.
	worldIntro = { seconds = 3.5 },

	-- Worlds in unlock order. `unlockPrice` is paid once per player at the barrier in
	-- front of the world (0 = open from the start). `toppingSpawns` weights are relative chances.
	-- Unlock, shop and rebirth prices are tuned with `lune run balance` (#41, docs/balancing.md)
	-- to about 6/9/12/16/20/25 min of play in worlds 1-6 and 32 min in world 7 (#57).
	-- Optional `requiredRebirths` (default 0, #43): rebirths needed besides the price.
	-- Rebirth tiers of the 15 worlds (#72, #77): worlds 1-4: 0, 5-6: 1, 7-8: 2, 9-10: 3,
	-- 11-12: 5, 13-14: 7, 15: 10 (order and tiers checked in tests/GameConfig.spec.luau).
	-- A new world = one entry here (+ toppings, eggs, pets, island theme); no new map code.
	worlds = {
		{
			id = "PizzeriaGarden",
			displayName = "Pizzeria-Garten",
			displayNameEn = "Pizzeria Garden",
			unlockPrice = 0,
			-- World colour (RGB 0-255), e.g. the glowing face of the world's portal.
			color = { 255, 150, 60 },
			toppingSpawns = {
				{ topping = "Salami", weight = 60 },
				{ topping = "Mushroom", weight = 30 },
				{ topping = "Mozzarella", weight = 10 },
			},
			-- Eggs standing in this world: first egg, then the pricier second egg (#39).
			eggs = { "GardenEgg", "StoneOvenEgg" },
			-- Secret pet of this world (#81): a separate 1 in 20,000 roll per egg.
			secretPet = "MozzarellaGhost",
		},
		{
			id = "Farm",
			displayName = "Bauernhof",
			displayNameEn = "Farm",
			unlockPrice = 26,
			color = { 250, 210, 70 },
			toppingSpawns = {
				{ topping = "Onion", weight = 45 },
				{ topping = "BellPepper", weight = 30 },
				{ topping = "Corn", weight = 17 },
				{ topping = "Ham", weight = 8 },
			},
			eggs = { "FarmEgg", "BarnEgg" },
			-- Secret pet of this world (#81): a separate 1 in 20,000 roll per egg.
			secretPet = "ScarecrowRaven",
		},
		{
			id = "Beach",
			displayName = "Strand",
			displayNameEn = "Beach",
			unlockPrice = 690,
			color = { 60, 200, 230 },
			toppingSpawns = {
				{ topping = "Tuna", weight = 55 },
				{ topping = "Shrimp", weight = 30 },
				{ topping = "Pineapple", weight = 15 },
			},
			eggs = { "BeachEgg", "ShellEgg" },
			-- Secret pet of this world (#81): a separate 1 in 20,000 roll per egg.
			secretPet = "TreasureOctopus",
		},
		{
			id = "Icebergs",
			displayName = "Eisberge",
			displayNameEn = "Icebergs",
			unlockPrice = 12000,
			color = { 150, 225, 255 },
			toppingSpawns = {
				{ topping = "FrozenPeas", weight = 55 },
				{ topping = "Salmon", weight = 30 },
				{ topping = "IcebergLettuce", weight = 15 },
			},
			eggs = { "IceEgg", "GlacierEgg" },
			-- Secret pet of this world (#81): a separate 1 in 20,000 roll per egg.
			secretPet = "AuroraWolf",
		},
		{
			id = "Volcano",
			requiredRebirths = 1,
			displayName = "Vulkan",
			displayNameEn = "Volcano",
			unlockPrice = 35000,
			color = { 255, 80, 30 },
			toppingSpawns = {
				{ topping = "Chili", weight = 55 },
				{ topping = "Pepperoni", weight = 30 },
				{ topping = "Jalapeno", weight = 15 },
			},
			eggs = { "VolcanoEgg", "MagmaEgg" },
			-- Secret pet of this world (#81): a separate 1 in 20,000 roll per egg.
			secretPet = "ObsidianDragon",
		},
		{
			id = "CandyLand",
			requiredRebirths = 1,
			displayName = "Süßigkeitenland",
			displayNameEn = "Candy Land",
			unlockPrice = 900000,
			color = { 255, 110, 200 },
			toppingSpawns = {
				{ topping = "ChocolateChips", weight = 55 },
				{ topping = "GummyBears", weight = 30 },
				{ topping = "Marshmallow", weight = 15 },
			},
			eggs = { "CandyEgg", "BonbonEgg" },
			-- Secret pet of this world (#81): a separate 1 in 20,000 roll per egg.
			secretPet = "GingerbreadGolem",
		},
		{
			id = "Space",
			requiredRebirths = 2,
			displayName = "Weltraum",
			displayNameEn = "Space",
			unlockPrice = 12000000,
			color = { 150, 100, 255 },
			toppingSpawns = {
				{ topping = "MoonCheese", weight = 55 },
				{ topping = "StarOlives", weight = 30 },
				{ topping = "AlienMushroom", weight = 15 },
			},
			eggs = { "SpaceEgg", "NebulaEgg" },
			-- Secret pet of this world (#81): a separate 1 in 20,000 roll per egg.
			secretPet = "BlackHoleCat",
		},
		-- World 8 (#82), the pattern for worlds 9-15: toppings, one egg with 6 pets, a Secret
		-- pet, a shop (shops.World8Shop), weather, island theme (islands.themes.Atlantis,
		-- incl. scripted `deco`), look and music (WorldLooks), models in one FBX per world
		-- (tools/blender/build_world.py). Price provisional (#108).
		{
			id = "Atlantis",
			requiredRebirths = 2,
			displayName = "Atlantis",
			displayNameEn = "Atlantis",
			unlockPrice = 150000000,
			color = { 40, 170, 230 },
			toppingSpawns = {
				{ topping = "Seaweed", weight = 55 },
				{ topping = "PearlCapers", weight = 30 },
				{ topping = "SquidRings", weight = 15 },
			},
			eggs = { "AtlantisEgg" },
			secretPet = "PearlKingOtter",
			weather = "BubbleStorm",
		},
	},
}

return GameConfig
