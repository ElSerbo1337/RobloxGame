--!strict
-- Central game configuration: every balancing number lives here.
-- Pure data, no Roblox API, so the game rules can be tested outside Roblox (Lune).
-- New worlds and toppings are added here only.

local GameConfig = {
	save = {
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
			{ id = "Playtime", store = "Leaderboard_Playtime_v1", title = "⏱ Spielzeit", format = "Duration" },
			{
				id = "CoinsEarned",
				store = "Leaderboard_CoinsEarned_v1",
				title = "💰 Münzen verdient",
				format = "Number",
			},
			{ id = "Rebirths", store = "Leaderboard_Rebirths_v1", title = "🔁 Rebirths", format = "Number" },
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
		Salami = { displayName = "Salami", value = 1 },
		Mushroom = { displayName = "Pilz", value = 2 },
		Mozzarella = { displayName = "Mozzarella", value = 5 },
		-- World 2 (Bauernhof): about 4x world 1.
		Onion = { displayName = "Zwiebel", value = 4 },
		BellPepper = { displayName = "Paprika", value = 8 },
		Corn = { displayName = "Mais", value = 12 },
		Ham = { displayName = "Schinken", value = 20 },
		-- World 3 (Strand): about 4x world 2.
		Tuna = { displayName = "Thunfisch", value = 25 },
		Shrimp = { displayName = "Garnele", value = 45 },
		Pineapple = { displayName = "Ananas", value = 65 },
		-- World 4 (Eisberge): about 4x world 3.
		FrozenPeas = { displayName = "Gefrorene Erbsen", value = 100 },
		Salmon = { displayName = "Lachs", value = 180 },
		IcebergLettuce = { displayName = "Eisberg-Salat", value = 260 },
		-- World 5 (Vulkan): about 4.8x world 4 (the pizza stays at 12 until shop 3).
		Chili = { displayName = "Chili", value = 500 },
		Pepperoni = { displayName = "Peperoni", value = 850 },
		Jalapeno = { displayName = "Jalapeño", value = 1250 },
		-- World 6 (Süßigkeitenland): about 4.8x world 5.
		ChocolateChips = { displayName = "Schoko-Stücke", value = 2400 },
		GummyBears = { displayName = "Gummibärchen", value = 4100 },
		Marshmallow = { displayName = "Marshmallow", value = 6000 },
		-- World 7 (Weltraum): about 4.8x world 6.
		MoonCheese = { displayName = "Mond-Käse", value = 11500 },
		StarOlives = { displayName = "Sternen-Oliven", value = 20000 },
		AlienMushroom = { displayName = "Alien-Pilz", value = 29000 },
	},

	-- Coin upgrades bought in shops. `levels` are in buy order: price in coins and the
	-- effect at that level (pizza space in toppings, range/magnet radius in studs).
	-- Level 0 is the base value (pizza.startCapacity, collect.range, no magnet).
	-- Levels beyond a shop's maxLevel show up there as "im größeren Shop erhältlich".
	upgrades = {
		PizzaSpace = {
			displayName = "Pizza-Platz",
			description = "Mehr Beläge pro Pizza",
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
			description = "Beläge aus größerer Entfernung antippen",
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
			description = "Zieht Beläge beim Auto-Sammeln an",
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
			description = "Mehr Pets gleichzeitig ausrüsten",
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
			description = "Mehr Platz für Pets",
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
			description = "Schneller laufen",
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
			description = "Schaltet „3 öffnen“ an jedem Ei frei",
			currency = "Gems",
			-- value = eggs per press.
			levels = {
				{ price = 150, value = 3 },
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

	-- New HUD buttons that pulse (with a short explanation) until the player opened them
	-- once; remembered per player (GameRules.markHintSeen): play time gifts (#36) and the
	-- rebirth button (#35, pulses the first time a rebirth is affordable).
	hints = { "Gifts", "Rebirth" },

	-- Income estimate (GameRules.incomePerMinute): average topping value of the highest
	-- unlocked world x pizza space x rounds per minute x coin multiplier (pets, rebirths).
	income = {
		-- Assumed rounds per minute (collect a full pizza and sell it).
		roundsPerMinute = 2,
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

	-- Potions: bought with gems at a shop's gem counter, kept in the potion inventory and
	-- drunk from there. Each runs `durationSeconds` of play time (it pauses while offline);
	-- drinking the same kind again adds its duration to the time left.
	potions = {
		Coins = {
			displayName = "Münz-Trank",
			description = "Doppelte Münzen beim Verkaufen",
			price = 25,
			durationSeconds = 600,
			coinMultiplier = 2,
		},
		Luck = {
			displayName = "Glücks-Trank",
			description = "Seltene Pets kommen öfter aus Eiern",
			price = 30,
			durationSeconds = 600,
			-- Egg chances are multiplied per rarity, then scaled back to 100 %.
			rarityWeights = { Common = 1, Uncommon = 1.2, Rare = 1.5, Epic = 2, Legendary = 2.5, Mythic = 3 },
		},
		Speed = {
			displayName = "Speed-Trank",
			description = "Schneller laufen",
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
		-- Price of the first rebirth: about 32 min of play in world 7 (#57, docs/balancing.md).
		startPrice = 74000000,
		-- Each further rebirth costs this many times the one before: the kept pets make
		-- worlds 1-6 fast, so the second run up to the next rebirth takes about as long
		-- as the first (#57).
		priceFactor = 14,
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
		Common = { displayName = "Gewöhnlich", order = 1, color = { 190, 190, 190 } },
		Uncommon = { displayName = "Ungewöhnlich", order = 2, color = { 90, 200, 90 } },
		Rare = { displayName = "Selten", order = 3, color = { 70, 150, 255 } },
		Epic = { displayName = "Episch", order = 4, color = { 170, 80, 240 } },
		Legendary = { displayName = "Legendär", order = 5, color = { 255, 170, 30 } },
		Mythic = { displayName = "Mythisch", order = 6, color = { 255, 60, 120 } },
	},

	-- Pet id -> display name, rarity and coin bonus (0.1 = +10 % sell value; bonuses add up).
	-- Flat curve (#57): the best pet of a world (both eggs) gives +75/110/160/230/320/400/500 %
	-- in worlds 1-7; the other pets of a world are scaled in the same proportion.
	pets = {
		DoughHamster = { displayName = "Teig-Hamster", rarity = "Common", bonus = 0.03 },
		BasilBunny = { displayName = "Basilikum-Hase", rarity = "Uncommon", bonus = 0.05 },
		TomatoCat = { displayName = "Tomaten-Katze", rarity = "Rare", bonus = 0.08 },
		CheeseMouse = { displayName = "Käse-Maus", rarity = "Epic", bonus = 0.13 },
		OliveOwl = { displayName = "Oliven-Eule", rarity = "Legendary", bonus = 0.25 },
		PizzaDragon = { displayName = "Pizza-Drache", rarity = "Mythic", bonus = 0.5 },
		-- World 2 (Bauernhof)
		FarmChick = { displayName = "Hof-Küken", rarity = "Common", bonus = 0.05 },
		CornPiglet = { displayName = "Mais-Ferkel", rarity = "Uncommon", bonus = 0.07 },
		PepperGoat = { displayName = "Paprika-Ziege", rarity = "Rare", bonus = 0.12 },
		OnionCow = { displayName = "Zwiebel-Kuh", rarity = "Epic", bonus = 0.2 },
		HayHorse = { displayName = "Heu-Pferd", rarity = "Legendary", bonus = 0.37 },
		GoldenRooster = { displayName = "Goldener Hahn", rarity = "Mythic", bonus = 0.73 },
		-- World 3 (Strand)
		SandCrab = { displayName = "Sand-Krabbe", rarity = "Common", bonus = 0.07 },
		ShellTurtle = { displayName = "Muschel-Schildkröte", rarity = "Uncommon", bonus = 0.11 },
		ShrimpSeal = { displayName = "Garnelen-Robbe", rarity = "Rare", bonus = 0.18 },
		PineappleParrot = { displayName = "Ananas-Papagei", rarity = "Epic", bonus = 0.28 },
		TunaDolphin = { displayName = "Thunfisch-Delfin", rarity = "Legendary", bonus = 0.53 },
		CoralKraken = { displayName = "Korallen-Krake", rarity = "Mythic", bonus = 1.07 },
		-- World 4 (Eisberge)
		IcePenguin = { displayName = "Eis-Pinguin", rarity = "Common", bonus = 0.1 },
		SnowFox = { displayName = "Schnee-Fuchs", rarity = "Uncommon", bonus = 0.15 },
		PeaWalrus = { displayName = "Erbsen-Walross", rarity = "Rare", bonus = 0.26 },
		SalmonBear = { displayName = "Lachs-Bär", rarity = "Epic", bonus = 0.41 },
		LettuceYeti = { displayName = "Salat-Yeti", rarity = "Legendary", bonus = 0.77 },
		FrostPhoenix = { displayName = "Frost-Phönix", rarity = "Mythic", bonus = 1.53 },
		-- World 5 (Vulkan)
		LavaLizard = { displayName = "Lava-Echse", rarity = "Common", bonus = 0.14 },
		ChiliSalamander = { displayName = "Chili-Salamander", rarity = "Uncommon", bonus = 0.21 },
		MagmaMole = { displayName = "Magma-Maulwurf", rarity = "Rare", bonus = 0.36 },
		JalapenoGolem = { displayName = "Jalapeño-Golem", rarity = "Epic", bonus = 0.57 },
		FireWolf = { displayName = "Feuer-Wolf", rarity = "Legendary", bonus = 1.07 },
		LavaTitan = { displayName = "Lava-Titan", rarity = "Mythic", bonus = 2.13 },
		-- World 6 (Süßigkeitenland)
		GummyWorm = { displayName = "Gummi-Wurm", rarity = "Common", bonus = 0.18 },
		LollipopPoodle = { displayName = "Lolli-Pudel", rarity = "Uncommon", bonus = 0.27 },
		MarshmallowSheep = { displayName = "Marshmallow-Schaf", rarity = "Rare", bonus = 0.44 },
		ChocoBear = { displayName = "Schoko-Bär", rarity = "Epic", bonus = 0.71 },
		CottonCandyUnicorn = { displayName = "Zuckerwatte-Einhorn", rarity = "Legendary", bonus = 1.33 },
		CaramelGriffin = { displayName = "Karamell-Greif", rarity = "Mythic", bonus = 2.67 },
		-- World 7 (Weltraum)
		MoonMouse = { displayName = "Mond-Maus", rarity = "Common", bonus = 0.22 },
		StarCat = { displayName = "Sternen-Katze", rarity = "Uncommon", bonus = 0.33 },
		AlienFrog = { displayName = "Alien-Frosch", rarity = "Rare", bonus = 0.56 },
		RocketDog = { displayName = "Raketen-Hund", rarity = "Epic", bonus = 0.89 },
		CometWhale = { displayName = "Kometen-Wal", rarity = "Legendary", bonus = 1.67 },
		GalaxyDragon = { displayName = "Galaxie-Drache", rarity = "Mythic", bonus = 3.33 },

		-- Second egg per world (#39): Selten to Mythisch only, each about 1.5x the bonus of
		-- the same rarity in the world's first egg. Models: tools/blender/build_pets.py (#40).
		-- World 1 (Steinofen-Ei)
		RucolaHedgehog = { displayName = "Rucola-Igel", rarity = "Rare", bonus = 0.12 },
		ParmesanRaccoon = { displayName = "Parmesan-Waschbär", rarity = "Epic", bonus = 0.2 },
		TruffleFox = { displayName = "Trüffel-Fuchs", rarity = "Legendary", bonus = 0.38 },
		StoneOvenPhoenix = { displayName = "Steinofen-Phönix", rarity = "Mythic", bonus = 0.75 },
		-- World 2 (Scheunen-Ei)
		PumpkinCat = { displayName = "Kürbis-Katze", rarity = "Rare", bonus = 0.18 },
		ButterDonkey = { displayName = "Butter-Esel", rarity = "Epic", bonus = 0.29 },
		HoneyBear = { displayName = "Honig-Bär", rarity = "Legendary", bonus = 0.55 },
		GoldGrainBull = { displayName = "Goldkorn-Stier", rarity = "Mythic", bonus = 1.1 },
		-- World 3 (Muschel-Ei)
		CoconutMonkey = { displayName = "Kokos-Affe", rarity = "Rare", bonus = 0.27 },
		ShellSeahorse = { displayName = "Muschel-Seepferdchen", rarity = "Epic", bonus = 0.43 },
		SardineShark = { displayName = "Sardinen-Hai", rarity = "Legendary", bonus = 0.8 },
		PearlSeaSerpent = { displayName = "Perlen-Seeschlange", rarity = "Mythic", bonus = 1.6 },
		-- World 4 (Gletscher-Ei)
		MintReindeer = { displayName = "Minz-Rentier", rarity = "Rare", bonus = 0.38 },
		SundaePolarBear = { displayName = "Eisbecher-Eisbär", rarity = "Epic", bonus = 0.61 },
		VanillaMammoth = { displayName = "Vanille-Mammut", rarity = "Legendary", bonus = 1.15 },
		SorbetNarwhal = { displayName = "Sorbet-Narwal", rarity = "Mythic", bonus = 2.3 },
		-- World 5 (Magma-Ei)
		PepperScorpion = { displayName = "Pfeffer-Skorpion", rarity = "Rare", bonus = 0.53 },
		HabaneroRhino = { displayName = "Habanero-Nashorn", rarity = "Epic", bonus = 0.85 },
		CurryTiger = { displayName = "Curry-Tiger", rarity = "Legendary", bonus = 1.6 },
		CalzoneHydra = { displayName = "Calzone-Hydra", rarity = "Mythic", bonus = 3.2 },
		-- World 6 (Bonbon-Ei)
		DonutDachshund = { displayName = "Donut-Dackel", rarity = "Rare", bonus = 0.67 },
		PuddingPanda = { displayName = "Pudding-Panda", rarity = "Epic", bonus = 1.07 },
		LicoricePanther = { displayName = "Lakritz-Panther", rarity = "Legendary", bonus = 2 },
		CakePegasus = { displayName = "Torten-Pegasus", rarity = "Mythic", bonus = 4 },
		-- World 7 (Nebula-Ei)
		MooncakeBunny = { displayName = "Mondkuchen-Hase", rarity = "Rare", bonus = 0.83 },
		StarfruitJellyfish = { displayName = "Sternfrucht-Qualle", rarity = "Epic", bonus = 1.33 },
		StardustLion = { displayName = "Sternenstaub-Löwe", rarity = "Legendary", bonus = 2.5 },
		GalaxyPizzaLeviathan = { displayName = "Galaxie-Pizza-Leviathan", rarity = "Mythic", bonus = 5 },
	},

	-- Egg id -> price in coins and pets with their chance in percent (must add up to 100).
	-- Every world has two eggs: the first with 6 pets (Gewöhnlich to Mythisch) and a
	-- second one (#39, `fancy` look) at about 5x the price with 4 stronger pets (Selten
	-- to Mythisch), open as soon as the world is unlocked.
	-- `look`: colours (hex) and pattern of the egg model (tools/blender/build_eggs.py reads
	-- them from here) and of the placeholder egg. Patterns: Spots, Stripes, Waves, Diamonds,
	-- Cracks, Swirl, Stars. `glow` = accent glows (Neon); `fancy` = showier variant
	-- (gold band and beads, meant for a second egg per world).
	eggs = {
		GardenEgg = {
			displayName = "Garten-Ei",
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
			look = { color = "14163A", accent = "C86BFF", pattern = "Spots", glow = true, fancy = true },
			price = 2000000,
			pets = {
				{ pet = "MooncakeBunny", chance = 68 },
				{ pet = "StarfruitJellyfish", chance = 25 },
				{ pet = "StardustLion", chance = 6 },
				{ pet = "GalaxyPizzaLeviathan", chance = 1 },
			},
		},
	},

	-- Shops by id. Each sells its `offers` up to `maxLevel`; bigger shops in later
	-- worlds offer the same upgrades with higher max levels (config only).
	shops = {
		World1Shop = {
			worldId = "PizzeriaGarden",
			displayName = "Pizza-Shop",
			offers = {
				{ upgrade = "PizzaSpace", maxLevel = 3 },
				{ upgrade = "CollectRange", maxLevel = 3 },
				{ upgrade = "Magnet", maxLevel = 1 },
				-- Gem counter
				{ upgrade = "PetSlots", maxLevel = 2 },
				{ upgrade = "InventorySpace", maxLevel = 2 },
				{ upgrade = "WalkSpeed", maxLevel = 2 },
				{ upgrade = "TripleOpen", maxLevel = 1 },
			},
			-- Potions sold at the gem counter.
			potions = { "Coins", "Luck", "Speed" },
		},
		-- Shop 2: everything from shop 1 plus higher levels, in world 4.
		World4Shop = {
			worldId = "Icebergs",
			displayName = "Großer Pizza-Shop",
			offers = {
				{ upgrade = "PizzaSpace", maxLevel = 6 },
				{ upgrade = "CollectRange", maxLevel = 6 },
				{ upgrade = "Magnet", maxLevel = 3 },
				-- Gem counter
				{ upgrade = "PetSlots", maxLevel = 4 },
				{ upgrade = "InventorySpace", maxLevel = 4 },
				{ upgrade = "WalkSpeed", maxLevel = 4 },
				{ upgrade = "TripleOpen", maxLevel = 1 },
			},
			-- Potions sold at the gem counter.
			potions = { "Coins", "Luck", "Speed" },
		},
		-- Shop 3: the biggest shop with every upgrade up to its last level, in world 7.
		World7Shop = {
			worldId = "Space",
			displayName = "Riesiger Pizza-Shop",
			offers = {
				{ upgrade = "PizzaSpace", maxLevel = 8 },
				{ upgrade = "CollectRange", maxLevel = 8 },
				{ upgrade = "Magnet", maxLevel = 5 },
				-- Gem counter
				{ upgrade = "PetSlots", maxLevel = 5 },
				{ upgrade = "InventorySpace", maxLevel = 5 },
				{ upgrade = "WalkSpeed", maxLevel = 5 },
				{ upgrade = "TripleOpen", maxLevel = 1 },
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
		spawnLayout = {
			spawn = { 0, 26 },
			fountain = { 0, 0 },
			portal = { -34, -12 },
			boards = { { -30, 20 }, { 0, 42 }, { 30, 20 } },
			pond = { 38, -8 },
		},
		-- Look of each island world (others use PizzeriaGarden). Colours are RGB 0-255.
		-- Optional per world (defaults = world 1):
		--   rimStyle     "Hedge" | "Fence" | "Rocks" | "IceEdge" | "Basalt" | "Peppermint" | "Moonbase"
		--                (low visible rim)
		--   landmark     "GiantPizza" | "Windmill" | "Lighthouse" | "IcePeak" | "Volcano" | "Cake"
		--                | "Rocket" (back left terrace)
		--   bridge       "Rope" | "Boardwalk" | "Ice" | "Basalt" | "CandyCane" | "Light": style of
		--                the bridge leading INTO the world
		--   trees        tree models scattered along the rim (ModelLibrary names)
		--   treeScale    size factor for those (default 1: 10-16 studs wide)
		--   accents      { model, width } props along the field's long sides
		--   terraceProps { terrace, model, width, at = { x, z }, yaw?, collide?, lift? } on a
		--                terrace (lift = studs above the terrace top, e.g. a floating planet)
		--   fieldRows    colour of furrows across the topping field
		--   flowerStems  false = flowers are pebbles/shells lying on the ground
		--   cracks       glowing cracks in the ground { x, z, length, yaw (degrees) } in the
		--                colour `glow` (Neon with a small light each, so keep them few)
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
		},
	},

	-- Worlds in unlock order. `unlockPrice` is paid once per player at the barrier in
	-- front of the world (0 = open from the start). `toppingSpawns` weights are relative chances.
	-- Unlock, shop and rebirth prices are tuned with `lune run balance` (#41, docs/balancing.md)
	-- to about 6/9/12/16/20/25 min of play in worlds 1-6 and 32 min in world 7 (#57).
	-- Optional `requiredRebirths` (default 0, #43): rebirths needed besides the price. Worlds
	-- 1-7 need none; later worlds follow the plan in docs/balancing.md (1 rebirth up to
	-- world 10, 2 up to 12, 3 up to 14, then 2-3 new worlds per rebirth).
	worlds = {
		{
			id = "PizzeriaGarden",
			displayName = "Pizzeria-Garten",
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
		},
		{
			id = "Farm",
			displayName = "Bauernhof",
			unlockPrice = 26,
			color = { 250, 210, 70 },
			toppingSpawns = {
				{ topping = "Onion", weight = 45 },
				{ topping = "BellPepper", weight = 30 },
				{ topping = "Corn", weight = 17 },
				{ topping = "Ham", weight = 8 },
			},
			eggs = { "FarmEgg", "BarnEgg" },
		},
		{
			id = "Beach",
			displayName = "Strand",
			unlockPrice = 690,
			color = { 60, 200, 230 },
			toppingSpawns = {
				{ topping = "Tuna", weight = 55 },
				{ topping = "Shrimp", weight = 30 },
				{ topping = "Pineapple", weight = 15 },
			},
			eggs = { "BeachEgg", "ShellEgg" },
		},
		{
			id = "Icebergs",
			displayName = "Eisberge",
			unlockPrice = 12000,
			color = { 150, 225, 255 },
			toppingSpawns = {
				{ topping = "FrozenPeas", weight = 55 },
				{ topping = "Salmon", weight = 30 },
				{ topping = "IcebergLettuce", weight = 15 },
			},
			eggs = { "IceEgg", "GlacierEgg" },
		},
		{
			id = "Volcano",
			displayName = "Vulkan",
			unlockPrice = 35000,
			color = { 255, 80, 30 },
			toppingSpawns = {
				{ topping = "Chili", weight = 55 },
				{ topping = "Pepperoni", weight = 30 },
				{ topping = "Jalapeno", weight = 15 },
			},
			eggs = { "VolcanoEgg", "MagmaEgg" },
		},
		{
			id = "CandyLand",
			displayName = "Süßigkeitenland",
			unlockPrice = 900000,
			color = { 255, 110, 200 },
			toppingSpawns = {
				{ topping = "ChocolateChips", weight = 55 },
				{ topping = "GummyBears", weight = 30 },
				{ topping = "Marshmallow", weight = 15 },
			},
			eggs = { "CandyEgg", "BonbonEgg" },
		},
		{
			id = "Space",
			displayName = "Weltraum",
			unlockPrice = 12000000,
			color = { 150, 100, 255 },
			toppingSpawns = {
				{ topping = "MoonCheese", weight = 55 },
				{ topping = "StarOlives", weight = 30 },
				{ topping = "AlienMushroom", weight = 15 },
			},
			eggs = { "SpaceEgg", "NebulaEgg" },
		},
	},
}

return GameConfig
