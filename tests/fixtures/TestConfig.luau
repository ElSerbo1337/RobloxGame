-- Small, stable game config for tests, so balancing changes in GameConfig don't break them.
return {
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
		-- One gem per this many seconds of play time.
		playtimeSeconds = 900,
		playtimeGems = 1,
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
