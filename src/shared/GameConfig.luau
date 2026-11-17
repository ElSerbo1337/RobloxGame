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
				{ price = 120, value = 4 },
				{ price = 500, value = 6 },
				-- Shop 2 (world 4)
				{ price = 5000, value = 8 },
				{ price = 15000, value = 10 },
				{ price = 40000, value = 12 },
				-- Shop 3 (world 7): priced as goals for world 7 (about 15 / 45 min of income there).
				{ price = 400000000, value = 15 },
				{ price = 1200000000, value = 20 },
			},
		},
		CollectRange = {
			displayName = "Reichweite",
			description = "Beläge aus größerer Entfernung antippen",
			levels = {
				{ price = 40, value = 14 },
				{ price = 200, value = 18 },
				{ price = 800, value = 22 },
				{ price = 8000, value = 26 },
				{ price = 25000, value = 30 },
				{ price = 60000, value = 35 },
				-- Shop 3 (world 7)
				{ price = 250000000, value = 40 },
				{ price = 700000000, value = 45 },
			},
		},
		Magnet = {
			displayName = "Magnet",
			description = "Zieht Beläge beim Auto-Sammeln an",
			levels = {
				{ price = 600, value = 12 },
				{ price = 30000, value = 18 },
				{ price = 100000, value = 25 },
				-- Shop 3 (world 7)
				{ price = 300000000, value = 32 },
				{ price = 900000000, value = 40 },
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
		-- `playtimeGems` per full `playtimeSeconds` of play time (1 per 15 min).
		playtimeSeconds = 900,
		playtimeGems = 1,
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
	pets = {
		DoughHamster = { displayName = "Teig-Hamster", rarity = "Common", bonus = 0.1 },
		BasilBunny = { displayName = "Basilikum-Hase", rarity = "Uncommon", bonus = 0.15 },
		TomatoCat = { displayName = "Tomaten-Katze", rarity = "Rare", bonus = 0.25 },
		CheeseMouse = { displayName = "Käse-Maus", rarity = "Epic", bonus = 0.4 },
		OliveOwl = { displayName = "Oliven-Eule", rarity = "Legendary", bonus = 0.75 },
		PizzaDragon = { displayName = "Pizza-Drache", rarity = "Mythic", bonus = 1.5 },
		-- World 2 (Bauernhof): about 2x world 1.
		FarmChick = { displayName = "Hof-Küken", rarity = "Common", bonus = 0.2 },
		CornPiglet = { displayName = "Mais-Ferkel", rarity = "Uncommon", bonus = 0.3 },
		PepperGoat = { displayName = "Paprika-Ziege", rarity = "Rare", bonus = 0.5 },
		OnionCow = { displayName = "Zwiebel-Kuh", rarity = "Epic", bonus = 0.8 },
		HayHorse = { displayName = "Heu-Pferd", rarity = "Legendary", bonus = 1.5 },
		GoldenRooster = { displayName = "Goldener Hahn", rarity = "Mythic", bonus = 3 },
		-- World 3 (Strand): about 2x world 2.
		SandCrab = { displayName = "Sand-Krabbe", rarity = "Common", bonus = 0.4 },
		ShellTurtle = { displayName = "Muschel-Schildkröte", rarity = "Uncommon", bonus = 0.6 },
		ShrimpSeal = { displayName = "Garnelen-Robbe", rarity = "Rare", bonus = 1 },
		PineappleParrot = { displayName = "Ananas-Papagei", rarity = "Epic", bonus = 1.6 },
		TunaDolphin = { displayName = "Thunfisch-Delfin", rarity = "Legendary", bonus = 3 },
		CoralKraken = { displayName = "Korallen-Krake", rarity = "Mythic", bonus = 6 },
		-- World 4 (Eisberge): about 2x world 3.
		IcePenguin = { displayName = "Eis-Pinguin", rarity = "Common", bonus = 0.8 },
		SnowFox = { displayName = "Schnee-Fuchs", rarity = "Uncommon", bonus = 1.2 },
		PeaWalrus = { displayName = "Erbsen-Walross", rarity = "Rare", bonus = 2 },
		SalmonBear = { displayName = "Lachs-Bär", rarity = "Epic", bonus = 3.2 },
		LettuceYeti = { displayName = "Salat-Yeti", rarity = "Legendary", bonus = 6 },
		FrostPhoenix = { displayName = "Frost-Phönix", rarity = "Mythic", bonus = 12 },
		-- World 5 (Vulkan): about 2.25x world 4 (the pizza stays at 12 until shop 3, pets carry the curve).
		LavaLizard = { displayName = "Lava-Echse", rarity = "Common", bonus = 1.8 },
		ChiliSalamander = { displayName = "Chili-Salamander", rarity = "Uncommon", bonus = 2.7 },
		MagmaMole = { displayName = "Magma-Maulwurf", rarity = "Rare", bonus = 4.5 },
		JalapenoGolem = { displayName = "Jalapeño-Golem", rarity = "Epic", bonus = 7.2 },
		FireWolf = { displayName = "Feuer-Wolf", rarity = "Legendary", bonus = 13.5 },
		LavaTitan = { displayName = "Lava-Titan", rarity = "Mythic", bonus = 27 },
		-- World 6 (Süßigkeitenland): about 2.2x world 5.
		GummyWorm = { displayName = "Gummi-Wurm", rarity = "Common", bonus = 4 },
		LollipopPoodle = { displayName = "Lolli-Pudel", rarity = "Uncommon", bonus = 6 },
		MarshmallowSheep = { displayName = "Marshmallow-Schaf", rarity = "Rare", bonus = 10 },
		ChocoBear = { displayName = "Schoko-Bär", rarity = "Epic", bonus = 16 },
		CottonCandyUnicorn = { displayName = "Zuckerwatte-Einhorn", rarity = "Legendary", bonus = 30 },
		CaramelGriffin = { displayName = "Karamell-Greif", rarity = "Mythic", bonus = 60 },
		-- World 7 (Weltraum): about 2x world 6.
		MoonMouse = { displayName = "Mond-Maus", rarity = "Common", bonus = 8 },
		StarCat = { displayName = "Sternen-Katze", rarity = "Uncommon", bonus = 12 },
		AlienFrog = { displayName = "Alien-Frosch", rarity = "Rare", bonus = 20 },
		RocketDog = { displayName = "Raketen-Hund", rarity = "Epic", bonus = 32 },
		CometWhale = { displayName = "Kometen-Wal", rarity = "Legendary", bonus = 60 },
		GalaxyDragon = { displayName = "Galaxie-Drache", rarity = "Mythic", bonus = 120 },
	},

	-- Egg id -> price in coins and pets with their chance in percent (must add up to 100).
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
		FarmEgg = {
			displayName = "Bauernhof-Ei",
			look = { color = "F2CF6B", accent = "8A5A2B", pattern = "Stripes" },
			price = 200,
			pets = {
				{ pet = "FarmChick", chance = 50 },
				{ pet = "CornPiglet", chance = 28 },
				{ pet = "PepperGoat", chance = 15 },
				{ pet = "OnionCow", chance = 5.5 },
				{ pet = "HayHorse", chance = 1 },
				{ pet = "GoldenRooster", chance = 0.5 },
			},
		},
		BeachEgg = {
			displayName = "Strand-Ei",
			look = { color = "4FCFE0", accent = "FFF1C1", pattern = "Waves" },
			price = 1500,
			pets = {
				{ pet = "SandCrab", chance = 50 },
				{ pet = "ShellTurtle", chance = 28 },
				{ pet = "ShrimpSeal", chance = 15 },
				{ pet = "PineappleParrot", chance = 5.5 },
				{ pet = "TunaDolphin", chance = 1 },
				{ pet = "CoralKraken", chance = 0.5 },
			},
		},
		IceEgg = {
			displayName = "Eis-Ei",
			look = { color = "DDF3FF", accent = "3E9BE6", pattern = "Diamonds" },
			price = 12000,
			pets = {
				{ pet = "IcePenguin", chance = 50 },
				{ pet = "SnowFox", chance = 28 },
				{ pet = "PeaWalrus", chance = 15 },
				{ pet = "SalmonBear", chance = 5.5 },
				{ pet = "LettuceYeti", chance = 1 },
				{ pet = "FrostPhoenix", chance = 0.5 },
			},
		},
		VolcanoEgg = {
			displayName = "Vulkan-Ei",
			look = { color = "5A2A24", accent = "FF7A1A", pattern = "Cracks", glow = true },
			price = 100000,
			pets = {
				{ pet = "LavaLizard", chance = 50 },
				{ pet = "ChiliSalamander", chance = 28 },
				{ pet = "MagmaMole", chance = 15 },
				{ pet = "JalapenoGolem", chance = 5.5 },
				{ pet = "FireWolf", chance = 1 },
				{ pet = "LavaTitan", chance = 0.5 },
			},
		},
		CandyEgg = {
			displayName = "Süßigkeiten-Ei",
			look = { color = "FF8CC6", accent = "FFFFFF", pattern = "Swirl" },
			price = 800000,
			pets = {
				{ pet = "GummyWorm", chance = 50 },
				{ pet = "LollipopPoodle", chance = 28 },
				{ pet = "MarshmallowSheep", chance = 15 },
				{ pet = "ChocoBear", chance = 5.5 },
				{ pet = "CottonCandyUnicorn", chance = 1 },
				{ pet = "CaramelGriffin", chance = 0.5 },
			},
		},
		SpaceEgg = {
			displayName = "Weltraum-Ei",
			look = { color = "3B2A7A", accent = "FFD84A", pattern = "Stars", glow = true },
			price = 6400000,
			pets = {
				{ pet = "MoonMouse", chance = 50 },
				{ pet = "StarCat", chance = 28 },
				{ pet = "AlienFrog", chance = 15 },
				{ pet = "RocketDog", chance = 5.5 },
				{ pet = "CometWhale", chance = 1 },
				{ pet = "GalaxyDragon", chance = 0.5 },
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
		-- Shop 2: everything from shop 1 plus higher levels; a bigger building in world 4.
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
		-- Shop 3: the biggest shop with every upgrade up to its last level; a 2x building in world 7.
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

	-- Worlds in unlock order. `unlockPrice` is paid once per player at the barrier in
	-- front of the world (0 = open from the start). `toppingSpawns` weights are relative chances.
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
			-- Eggs standing in this world.
			eggs = { "GardenEgg" },
		},
		{
			id = "Farm",
			displayName = "Bauernhof",
			unlockPrice = 1500,
			color = { 250, 210, 70 },
			toppingSpawns = {
				{ topping = "Onion", weight = 45 },
				{ topping = "BellPepper", weight = 30 },
				{ topping = "Corn", weight = 17 },
				{ topping = "Ham", weight = 8 },
			},
			eggs = { "FarmEgg" },
		},
		{
			id = "Beach",
			displayName = "Strand",
			unlockPrice = 15000,
			color = { 60, 200, 230 },
			toppingSpawns = {
				{ topping = "Tuna", weight = 55 },
				{ topping = "Shrimp", weight = 30 },
				{ topping = "Pineapple", weight = 15 },
			},
			eggs = { "BeachEgg" },
		},
		{
			id = "Icebergs",
			displayName = "Eisberge",
			unlockPrice = 150000,
			color = { 150, 225, 255 },
			toppingSpawns = {
				{ topping = "FrozenPeas", weight = 55 },
				{ topping = "Salmon", weight = 30 },
				{ topping = "IcebergLettuce", weight = 15 },
			},
			eggs = { "IceEgg" },
		},
		{
			id = "Volcano",
			displayName = "Vulkan",
			unlockPrice = 1500000,
			color = { 255, 80, 30 },
			toppingSpawns = {
				{ topping = "Chili", weight = 55 },
				{ topping = "Pepperoni", weight = 30 },
				{ topping = "Jalapeno", weight = 15 },
			},
			eggs = { "VolcanoEgg" },
		},
		{
			id = "CandyLand",
			displayName = "Süßigkeitenland",
			unlockPrice = 15000000,
			color = { 255, 110, 200 },
			toppingSpawns = {
				{ topping = "ChocolateChips", weight = 55 },
				{ topping = "GummyBears", weight = 30 },
				{ topping = "Marshmallow", weight = 15 },
			},
			eggs = { "CandyEgg" },
		},
		{
			id = "Space",
			displayName = "Weltraum",
			unlockPrice = 150000000,
			color = { 150, 100, 255 },
			toppingSpawns = {
				{ topping = "MoonCheese", weight = 55 },
				{ topping = "StarOlives", weight = 30 },
				{ topping = "AlienMushroom", weight = 15 },
			},
			eggs = { "SpaceEgg" },
		},
	},
}

return GameConfig
