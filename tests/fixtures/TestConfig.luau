-- Small, stable game config for tests, so balancing changes in GameConfig don't break them.
return {
	admin = { userIds = { 42 } },
	pizza = { startCapacity = 2 },
	collect = { range = 10, autoRadius = 3 },
	toppingField = { count = 4, respawnSeconds = 5 },
	toppings = {
		Salami = { displayName = "Salami", value = 1 },
		Mushroom = { displayName = "Pilz", value = 2 },
		Mozzarella = { displayName = "Mozzarella", value = 5 },
		Onion = { displayName = "Zwiebel", value = 4 },
		Ham = { displayName = "Schinken", value = 20 },
	},
	-- Upgrade levels in buy order; `value` is the stat at that level (level 0 = base value).
	upgrades = {
		PizzaSpace = {
			displayName = "Pizza-Platz",
			levels = { { price = 10, value = 3 }, { price = 50, value = 4 }, { price = 200, value = 6 } },
		},
		CollectRange = {
			displayName = "Reichweite",
			levels = { { price = 20, value = 14 }, { price = 80, value = 18 } },
		},
		Magnet = {
			displayName = "Magnet",
			levels = { { price = 100, value = 8 }, { price = 1000, value = 12 } },
		},
		-- Gem upgrades: same shape, paid with gems.
		PetSlots = {
			displayName = "Pet-Plätze",
			currency = "Gems",
			levels = { { price = 50, value = 4 }, { price = 150, value = 5 } },
		},
		InventorySpace = {
			displayName = "Inventar",
			currency = "Gems",
			levels = { { price = 30, value = 7 }, { price = 100, value = 10 } },
		},
		WalkSpeed = {
			displayName = "Laufgeschwindigkeit",
			currency = "Gems",
			levels = { { price = 40, value = 20 }, { price = 120, value = 24 } },
		},
		TripleOpen = {
			displayName = "3 Eier auf einmal",
			currency = "Gems",
			levels = { { price = 150, value = 3 } },
		},
		-- Golden topping chance (#94); hidden while features.goldenToppings is false.
		GoldLuck = {
			displayName = "Gold-Glück",
			currency = "Gems",
			feature = "goldenToppings",
			levels = {
				{ price = 10, value = 0.012 },
				{ price = 20, value = 0.014 },
				{ price = 30, value = 0.016 },
				{ price = 40, value = 0.018 },
				{ price = 50, value = 0.02 },
			},
		},
	},
	shops = {
		SmallShop = {
			worldId = "PizzeriaGarden",
			offers = {
				{ upgrade = "PizzaSpace", maxLevel = 2 },
				{ upgrade = "CollectRange", maxLevel = 2 },
				{ upgrade = "Magnet", maxLevel = 1 },
			},
		},
		BigShop = {
			worldId = "PizzeriaGarden",
			offers = {
				{ upgrade = "PizzaSpace", maxLevel = 3 },
				{ upgrade = "Magnet", maxLevel = 2 },
				{ upgrade = "PetSlots", maxLevel = 2 },
			},
		},
		GemShop = {
			worldId = "PizzeriaGarden",
			offers = {
				{ upgrade = "PizzaSpace", maxLevel = 1 },
				{ upgrade = "PetSlots", maxLevel = 1 },
				{ upgrade = "InventorySpace", maxLevel = 1 },
				{ upgrade = "WalkSpeed", maxLevel = 1 },
				{ upgrade = "TripleOpen", maxLevel = 1 },
			},
			-- Potions sold at this shop's gem counter.
			potions = { "Coins", "Luck", "Speed" },
		},
		GoldShop = {
			worldId = "PizzeriaGarden",
			offers = { { upgrade = "GoldLuck", maxLevel = 5 } },
		},
		-- Stands in a world that must be unlocked first.
		BeachShop = {
			worldId = "Beach",
			offers = {
				{ upgrade = "PizzaSpace", maxLevel = 3 },
			},
			potions = { "Coins" },
		},
	},
	petSlots = { start = 3 },
	inventory = { start = 5 },
	movement = { walkSpeed = 16 },
	gems = {
		toppingId = "Gem",
		-- Chance that a spawning topping is a gem topping, and how many gems it gives.
		-- 0 here keeps the ToppingField draw order of other tests; Gems.spec sets its own chance.
		toppingChance = 0,
		toppingMin = 1,
		toppingMax = 3,
	},
	-- Golden toppings (#94): chance per spawned topping (before Gold Luck) and value factor.
	-- 0 here keeps the ToppingField draw order of other tests; GoldenToppings.spec sets its own chance.
	goldenToppings = { chance = 0, valueMultiplier = 10 },
	-- New HUD buttons that pulse until the player opened them once.
	hints = { "Gifts", "Rebirth", "WhatsNew1" },
	-- Spawn marketplace (#106): one-time "What's new" window and the countdown target.
	spawnMarket = {
		whatsNewHint = "WhatsNew1",
		countdownTo = { year = 2026, month = 12, day = 18 },
		countdownRefreshSeconds = 60,
	},
	-- Income estimate: rounds (collect + sell a full pizza) per minute.
	income = { roundsPerMinute = 2 },
	-- Play time gifts: reached after `minutes` of play time on a (German) day.
	-- Fixed gems and potions (a potion is a random one).
	gifts = {
		{ minutes = 5, rewards = { { kind = "Gems", amount = 3 } } },
		{ minutes = 10, rewards = { { kind = "Gems", amount = 5 } } },
		{ minutes = 15, rewards = { { kind = "Potion", amount = 1 } } },
		{ minutes = 20, rewards = { { kind = "Gems", amount = 15 }, { kind = "Potion", amount = 2 } } },
	},
	-- Login calendar: one reward per day in a row (day 1-7, then day 1 again; a missed day
	-- starts over at day 1). Same reward kinds as gifts.
	loginCalendar = {
		{ rewards = { { kind = "Gems", amount = 5 } } },
		{ rewards = { { kind = "Gems", amount = 10 } } },
		{ rewards = { { kind = "Potion", amount = 1 } } },
		{ rewards = { { kind = "Potion", amount = 1 } } },
		{ rewards = { { kind = "Gems", amount = 20 } } },
		{ rewards = { { kind = "Potion", amount = 2 } } },
		{ rewards = { { kind = "Gems", amount = 50 }, { kind = "Potion", amount = 3 } } },
	},
	-- Lucky wheel (#98): free spins per German day (+1 after bonusSpinMinutes of play time
	-- that day), more for spinPrice gems. Fields drawn by weight; "Coins" pays `minutes` of
	-- income (incomePerMinute, at least minCoins).
	luckyWheel = {
		spinPrice = 25,
		freeSpinsPerDay = 1,
		bonusSpinMinutes = 30,
		minCoins = 10,
		fields = {
			{ id = "Coins5", weight = 30, rewards = { { kind = "Coins", minutes = 5 } } },
			{ id = "Gems5", weight = 20, rewards = { { kind = "Gems", amount = 5 } } },
			{ id = "Potion1", weight = 15, rewards = { { kind = "Potion", amount = 1 } } },
			{ id = "Gems10", weight = 10, rewards = { { kind = "Gems", amount = 10 } } },
			{ id = "Coins15", weight = 10, rewards = { { kind = "Coins", minutes = 15 } } },
			{ id = "Potion2", weight = 8, rewards = { { kind = "Potion", amount = 2 } } },
			{ id = "Gems25", weight = 5, rewards = { { kind = "Gems", amount = 25 } } },
			{
				id = "Jackpot",
				weight = 2,
				jackpot = true,
				rewards = { { kind = "Gems", amount = 100 }, { kind = "Potion", amount = 3 } },
			},
		},
	},
	-- Quests (#97): small numbers so tests can finish them quickly.
	quests = {
		dailyCount = 3,
		weeklyCount = 2,
		dailyRewards = {
			{ kind = "Gems", amount = 8, weight = 1 },
			{ kind = "Potion", amount = 1, weight = 1 },
		},
		weeklyRewards = { { kind = "Gems", amount = 30, weight = 1 } },
		bonusRewards = { { kind = "Gems", amount = 20 }, { kind = "Potion", amount = 1 } },
		freeRerolls = 1,
		rerollGems = 10,
		streakDays = 3,
		streakRewards = { { kind = "Gems", amount = 100 }, { kind = "Potion", amount = 1, potionId = "Speed" } },
		kinds = {
			{ id = "CollectToppings", daily = { base = 4, perWorld = 2 }, weekly = { base = 20, perWorld = 10 } },
			{ id = "SellPizzas", daily = { base = 2, perWorld = 1 }, weekly = { base = 10, perWorld = 0 } },
			{ id = "OpenEggs", daily = { base = 1, perWorld = 1 } },
			{ id = "Deliveries", daily = { base = 1, perWorld = 0 } },
			{ id = "EarnCoins", daily = { incomeMinutes = 10 } },
			{ id = "PlayMinutes", daily = { base = 5, perWorld = 0 } },
			{ id = "MergePets", feature = "petMerge", daily = { base = 1, perWorld = 0 } },
			{ id = "GoldenToppings", feature = "goldenToppings", daily = { base = 2, perWorld = 0 } },
			{ id = "SpinWheel", feature = "luckyWheel", daily = { base = 2, perWorld = 0 } },
			{ id = "OpenChest", feature = "hiddenChests", minWorld = 2, daily = { base = 1, perWorld = 0 } },
			{ id = "UnlockWorld", daily = { base = 1, perWorld = 0 } },
		},
	},
	-- Potions: bought with gems, drunk from the potion inventory, active for `durationSeconds`.
	potions = {
		Coins = { displayName = "Münz-Trank", price = 20, durationSeconds = 600, coinMultiplier = 2 },
		Luck = {
			displayName = "Glücks-Trank",
			price = 25,
			durationSeconds = 600,
			-- Egg chance weights are multiplied per rarity (missing = 1).
			rarityWeights = { Rare = 2, Mythic = 3 },
		},
		Speed = { displayName = "Speed-Trank", price = 15, durationSeconds = 600, walkSpeedMultiplier = 1.5 },
	},
	tutorial = { collectToppings = 2 },
	-- Rebirth: price = startPrice x priceFactor ^ rebirths done; coins x (1 + multiplierPerRebirth x rebirths).
	rebirth = { startPrice = 1000, priceFactor = 3, multiplierPerRebirth = 0.5 },
	-- Delivery service: phone -> order -> delivery van.
	delivery = {
		-- Seconds between the end of one call/order and the next ring.
		callIntervalSeconds = 120,
		-- Time to deliver an accepted order.
		timeLimitSeconds = 180,
		-- Fewest toppings in an order (never more than the pizza holds).
		minToppings = 2,
		-- Reward x (1 + speedBonus x share of time left).
		speedBonus = 0.5,
		-- Coin reward = topping values x pet bonus x coin potion x coinFactor (x speed).
		coinFactor = 3,
		-- Gem reward: base drawn from gemsMin..gemsBaseMax, x speed, at most gemsMax.
		gemsMin = 3,
		gemsBaseMax = 7,
		gemsMax = 10,
		-- Potion reward: 1 potion, 2 when delivered with at least this share of time left.
		fastPotionShare = 0.5,
		rewardWeights = {
			{ reward = "Coins", weight = 60 },
			{ reward = "Gems", weight = 25 },
			{ reward = "Potion", weight = 15 },
		},
	},
	rarities = {
		Common = { displayName = "Gewöhnlich", order = 1, color = { 200, 200, 200 } },
		Rare = { displayName = "Selten", order = 3, color = { 80, 150, 255 } },
		Mythic = { displayName = "Mythisch", order = 6, color = { 255, 60, 120 } },
	},
	pets = {
		Hamster = { displayName = "Hamster", rarity = "Common", bonus = 0.1 },
		Cat = { displayName = "Katze", rarity = "Rare", bonus = 0.2 },
		Dragon = { displayName = "Drache", rarity = "Mythic", bonus = 1.5 },
	},
	eggs = {
		TestEgg = {
			displayName = "Test-Ei",
			price = 10,
			pets = {
				{ pet = "Hamster", chance = 70 },
				{ pet = "Cat", chance = 29.5 },
				{ pet = "Dragon", chance = 0.5 },
			},
		},
		FarmTestEgg = {
			displayName = "Hof-Test-Ei",
			price = 100,
			pets = {
				{ pet = "Cat", chance = 100 },
			},
		},
	},
	worlds = {
		{
			id = "PizzeriaGarden",
			displayName = "Pizzeria-Garten",
			unlockPrice = 0,
			toppingSpawns = {
				{ topping = "Salami", weight = 6 },
				{ topping = "Mushroom", weight = 3 },
				{ topping = "Mozzarella", weight = 1 },
			},
			eggs = { "TestEgg" },
		},
		{
			id = "Farm",
			displayName = "Bauernhof",
			unlockPrice = 1500,
			toppingSpawns = {
				{ topping = "Onion", weight = 3 },
				{ topping = "Ham", weight = 1 },
			},
			eggs = { "FarmTestEgg" },
		},
		{
			id = "Beach",
			displayName = "Strand",
			unlockPrice = 15000,
			toppingSpawns = {},
		},
	},
}
