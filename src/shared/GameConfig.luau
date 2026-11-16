--!strict
-- Central game configuration: every balancing number lives here.
-- Pure data, no Roblox API, so the game rules can be tested outside Roblox (Lune).
-- New worlds and toppings are added here only.

local GameConfig = {
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
				{ price = 25, value = 3 },
				{ price = 120, value = 4 },
				{ price = 500, value = 6 },
				-- Shop 2 (world 4)
				{ price = 5000, value = 8 },
				{ price = 15000, value = 10 },
				{ price = 40000, value = 12 },
				-- Shop 3 (world 7)
				{ price = 400000, value = 15 },
				{ price = 2000000, value = 20 },
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
			},
		},
		Magnet = {
			displayName = "Magnet",
			description = "Zieht Beläge beim Auto-Sammeln an",
			levels = {
				{ price = 600, value = 12 },
				{ price = 30000, value = 18 },
				{ price = 100000, value = 25 },
			},
		},
	},

	-- Shops by id. Each sells its `offers` up to `maxLevel`; bigger shops in later
	-- worlds offer the same upgrades with higher max levels (config only).
	shops = {
		World1Shop = {
			worldId = "PizzeriaGarden",
			displayName = "Münz-Tresen",
			offers = {
				{ upgrade = "PizzaSpace", maxLevel = 3 },
				{ upgrade = "CollectRange", maxLevel = 3 },
				{ upgrade = "Magnet", maxLevel = 1 },
			},
		},
	},

	-- Worlds in unlock order. `unlockPrice` is paid once per player at the barrier in
	-- front of the world (0 = open from the start). `toppingSpawns` weights are relative chances.
	worlds = {
		{
			id = "PizzeriaGarden",
			displayName = "Pizzeria-Garten",
			unlockPrice = 0,
			toppingSpawns = {
				{ topping = "Salami", weight = 60 },
				{ topping = "Mushroom", weight = 30 },
				{ topping = "Mozzarella", weight = 10 },
			},
		},
		{
			id = "Farm",
			displayName = "Bauernhof",
			unlockPrice = 1500,
			toppingSpawns = {
				{ topping = "Onion", weight = 45 },
				{ topping = "BellPepper", weight = 30 },
				{ topping = "Corn", weight = 17 },
				{ topping = "Ham", weight = 8 },
			},
		},
	},
}

return GameConfig
