-- Small, stable game config for tests, so balancing changes in GameConfig don't break them.
return {
	pizza = { startCapacity = 2 },
	collect = { range = 10, autoRadius = 3 },
	toppingField = { count = 4, respawnSeconds = 5 },
	toppings = {
		Salami = { displayName = "Salami", value = 1 },
		Mushroom = { displayName = "Pilz", value = 2 },
		Mozzarella = { displayName = "Mozzarella", value = 5 },
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
			},
		},
	},
	worlds = {
		{
			id = "PizzeriaGarden",
			displayName = "Pizzeria-Garten",
			toppingSpawns = {
				{ topping = "Salami", weight = 6 },
				{ topping = "Mushroom", weight = 3 },
				{ topping = "Mozzarella", weight = 1 },
			},
		},
	},
}
