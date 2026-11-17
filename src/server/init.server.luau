-- Server entry point (ServerScriptService.Server). Wires up the services.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)

local BarrierService = require(script.BarrierService)
local CameraService = require(script.CameraService)
local DeliveryService = require(script.DeliveryService)
local EggService = require(script.EggService)
local GemService = require(script.GemService)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local OvenService = require(script.OvenService)
local PetService = require(script.PetService)
local PizzaVisual = require(script.PizzaVisual)
local PlayerStates = require(script.PlayerStates)
local PortalService = require(script.PortalService)
local PotionService = require(script.PotionService)
local ShopService = require(script.ShopService)
local SpawnService = require(script.SpawnService)
local ToppingService = require(script.ToppingService)
local TutorialService = require(script.TutorialService)
local World1Map = require(script.World1Map)
local WorldDeco = require(script.WorldDeco)
local WorldMap = require(script.WorldMap)

-- Create remotes before any client asks for them.
Net.event("CollectTopping")
Net.event("SetAutoCollect")
Net.event("Notify")
Net.event("UnlockWorld")
for _, name in { "OpenEgg", "EggOpened", "EquipPet", "UnequipPet" } do
	Net.event(name)
end
for _, name in { "PortalOpen", "PortalClose", "Teleport" } do
	Net.event(name)
end
for _, name in { "ShopOpen", "ShopUpdate", "ShopClose", "BuyUpgrade", "ShopPurchase", "BuyPotion" } do
	Net.event(name)
end
for _, name in { "DrinkPotion", "PotionNotify" } do
	Net.event(name)
end
for _, name in { "PhoneOpen", "PhoneClose", "AnswerPhone" } do
	Net.event(name)
end

CameraService.start()
local layout = World1Map.build()
local laterWorlds = WorldMap.buildAll()
PlayerStates.start()
PizzaVisual.start()
ToppingService.start("PizzeriaGarden", layout)
OvenService.start(layout.sellZone)
for _, world in laterWorlds do
	ToppingService.start(world.worldId, world)
	OvenService.start(world.sellZone)
end
BarrierService.start(laterWorlds)
-- Respawn (death, rejoin) in the world the player was last in.
SpawnService.start()
-- World 1 coin shop: far left of the spawn, outside the topping area (eggs get x = -30).
local shopStands = { ShopService.buildStand(layout.folder, "World1Shop", Vector3.new(-60, 0.1, 72)) }
-- Shops of later worlds stand on their world's shop spot; every 3 worlds the building grows by half.
for index, world in laterWorlds do
	local worldIndex = index + 1
	for shopId, shop in GameConfig.shops do
		if shop.worldId == world.worldId then
			local scale = 1 + 0.5 * math.floor((worldIndex - 1) / 3)
			table.insert(shopStands, ShopService.buildStand(world.folder, shopId, world.shopSpot, scale))
		end
	end
end
ShopService.start(shopStands)
-- Look pass (#15): models, trees and paths for world 1, dome ovens everywhere.
WorldDeco.decorateWorld1(layout.folder)
-- Look of worlds 2-7 (#16): themed paths, props and landmarks.
for _, world in laterWorlds do
	WorldDeco.dressOven(world.folder)
	WorldDeco.decorateWorld(world.folder, world.worldId, world.boundsCenter)
end
-- Eggs: world 1 gets its own stand (x = -30 next to the spawn), later worlds use their egg stand.
local eggSpots = {
	{
		eggId = GameConfig.worlds[1].eggs[1],
		stand = EggService.buildStand(layout.folder, Vector3.new(-30, 0.1, 66), GameConfig.worlds[1].eggs[1]),
	},
}
for _, world in laterWorlds do
	local eggId = world.eggStand:GetAttribute("EggId")
	if type(eggId) == "string" then
		table.insert(eggSpots, { eggId = eggId, stand = world.eggStand })
	end
end
EggService.start(eggSpots)
-- New-player tutorial arrows point at world 1: toppings, oven, shop, egg.
TutorialService.start({
	CollectToppings = layout.toppingsFolder,
	SellPizza = layout.sellZone,
	BuyUpgrade = shopStands[1].zone,
	OpenEgg = eggSpots[1].stand,
})
PetService.start()
GemService.start()
PotionService.start()
-- Delivery service: a phone and a delivery van in every world (same spot in each world).
DeliveryService.start(DeliveryService.buildAll())
-- One teleport portal per configured world (same spot in each world).
PortalService.start(PortalService.buildAll())

print(`[{Constants.GAME_NAME}] Server gestartet`)
