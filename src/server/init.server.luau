-- Server entry point (ServerScriptService.Server). Wires up the services.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)

local BarrierService = require(script.BarrierService)
local CameraService = require(script.CameraService)
local DeliveryService = require(script.DeliveryService)
local EggService = require(script.EggService)
local GemService = require(script.GemService)
local GiftService = require(script.GiftService)
local LoginCalendarService = require(script.LoginCalendarService)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local OvenService = require(script.OvenService)
local PetService = require(script.PetService)
local PizzaVisual = require(script.PizzaVisual)
local PlayerStates = require(script.PlayerStates)
local PortalService = require(script.PortalService)
local PotionService = require(script.PotionService)
local RebirthService = require(script.RebirthService)
local ShopService = require(script.ShopService)
local SpawnService = require(script.SpawnService)
local ToppingService = require(script.ToppingService)
local TutorialService = require(script.TutorialService)
local IslandBuilder = require(script.IslandBuilder)
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
for _, name in { "PhoneOpen", "PhoneClose", "AnswerPhone", "Rebirth", "Rebirthed" } do
	Net.event(name)
end
for _, name in { "ClaimGift", "GiftResult", "HintSeen", "ClaimLoginReward", "LoginRewardResult" } do
	Net.event(name)
end

CameraService.start()
-- Flying islands (#27): spawn island -> bridge -> world 1 -> bridge -> world 2 ...
WorldMap.removeBaseplate()
WorldMap.buildSpawnIsland()
WorldMap.buildBridges()
local worlds = WorldMap.buildAll()
local layout = worlds[1]
local laterWorlds = {}
for index = 2, #worlds do
	table.insert(laterWorlds, worlds[index])
end
PlayerStates.start()
PizzaVisual.start()
for _, world in worlds do
	ToppingService.start(world.worldId, world)
	OvenService.start(world.sellZone)
end
BarrierService.start(laterWorlds)
-- Respawn (death, fall, rejoin) in the world the player was last in.
SpawnService.start()
-- Shops stand on their world's shop spot, facing the path; in the old square worlds
-- every 3 worlds the building grows by half.
local shopStands = {}
for _, world in worlds do
	for shopId, shop in GameConfig.shops do
		if shop.worldId == world.worldId then
			local scale = if world.isIsland then 1 else 1 + 0.5 * math.floor((world.index - 1) / 3)
			local spot = world.shopSpot
			local stand = ShopService.buildStand(world.folder, shopId, spot.Position, scale)
			local _, yaw = spot:ToEulerAnglesYXZ()
			IslandBuilder.turn(stand.zone.Parent :: Model, spot.Position, yaw)
			if shopId == "World1Shop" then
				table.insert(shopStands, 1, stand)
			else
				table.insert(shopStands, stand)
			end
		end
	end
end
ShopService.start(shopStands)
-- Look of worlds 2-7 (#16): themed paths, props and landmarks (world 1 is an island).
for _, world in laterWorlds do
	if not world.isIsland then
		WorldDeco.dressOven(world.folder)
		WorldDeco.decorateWorld(world.folder, world.worldId, world.boundsCenter)
	end
end
-- Eggs on the egg stands of every world (stands without an egg wait for #39).
local eggSpots = {}
for _, world in worlds do
	for _, stand in world.eggStands do
		local eggId = stand:GetAttribute("EggId")
		if type(eggId) == "string" then
			table.insert(eggSpots, { eggId = eggId, stand = stand })
		end
	end
end
EggService.start(eggSpots)
-- New-player tutorial: starts on the spawn island; the arrow leads over the bridge
-- (waypoint at the bridge head of world 1), then to toppings, oven, shop and egg.
TutorialService.start({
	CollectToppings = layout.toppingsFolder,
	SellPizza = layout.sellZone,
	BuyUpgrade = shopStands[1].zone,
	OpenEgg = layout.eggStands[1],
}, WorldMap.buildTutorialWaypoint())
PetService.start()
GemService.start()
-- Play time (per German day and in total) and the play time gifts.
GiftService.start()
-- Login calendar: opens once per German day on join, one reward per day.
LoginCalendarService.start()
PotionService.start()
-- Delivery service: a phone and a delivery van in every world (same spot in each world).
DeliveryService.start(DeliveryService.buildAll())
-- One teleport portal per configured world (same spot in each world).
PortalService.start(PortalService.buildAll())
-- Rebirth (#35): HUD button + menu on the client, the rules decide.
RebirthService.start()

print(`[{Constants.GAME_NAME}] Server gestartet`)
