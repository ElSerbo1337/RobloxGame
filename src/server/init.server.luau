-- Server entry point (ServerScriptService.Server). Wires up the services.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)

local AdminService = require(script.AdminService)
local AnnounceService = require(script.AnnounceService)
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
local QuestService = require(script.QuestService)
local RebirthService = require(script.RebirthService)
local SettingsService = require(script.SettingsService)
local ShopService = require(script.ShopService)
local SpawnMarketService = require(script.SpawnMarketService)
local SpawnService = require(script.SpawnService)
local ToppingService = require(script.ToppingService)
local TutorialService = require(script.TutorialService)
local IslandBuilder = require(script.IslandBuilder)
local LeaderboardService = require(script.LeaderboardService)
local WheelService = require(script.WheelService)
local WorldMap = require(script.WorldMap)

-- Create remotes before any client asks for them.
Net.event("CollectTopping")
Net.event("SetAutoCollect")
Net.event("Notify")
Net.event("UnlockWorld")
for _, name in { "OpenEgg", "EggOpened", "EquipPet", "UnequipPet", "MergePets", "PetMerged" } do
	Net.event(name)
end
for _, name in { "PortalOpen", "PortalClose", "PortalPreview", "Teleport" } do
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
Net.event("AdminRun")
Net.event("AdminResult")
Net.event("WorldIntro")
for _, name in { "SetSetting", "RedeemCode", "CodeResult" } do
	Net.event(name)
end
Net.event("SpinWheel")
Net.event("WheelResult")
for _, name in { "ClaimQuest", "RerollQuest", "ClaimQuestBonus", "QuestResult" } do
	Net.event(name)
end

CameraService.start()
-- Flying islands (#27): spawn island -> bridge -> world 1 -> bridge -> world 2 ...
WorldMap.removeBaseplate()
local spawnIsland = WorldMap.buildSpawnIsland()
WorldMap.buildBridges()
local worlds = WorldMap.buildAll()
-- Event islands (#77): none in this update; the event update wires them to the services.
WorldMap.buildEvents()
local layout = worlds[1]
local laterWorlds = {}
for index = 2, #worlds do
	table.insert(laterWorlds, worlds[index])
end
-- Global leaderboards (#38) on the spawn island's boards; before PlayerStates.start so
-- every save (also an early leave) submits the scores.
LeaderboardService.start(spawnIsland)
-- Spawn marketplace (#106): update board and Christmas countdown texts.
SpawnMarketService.start(spawnIsland)
PlayerStates.start()
PizzaVisual.start()
for _, world in worlds do
	ToppingService.start(world.worldId, world)
	OvenService.start(world.sellZone)
end
BarrierService.start(laterWorlds)
-- Respawn (death, fall, rejoin) in the world the player was last in.
SpawnService.start()
-- Shops stand on their world's shop spot, facing the path (all in normal size, so the
-- big shops do not reach into the egg stands).
local shopStands = {}
for _, world in worlds do
	for shopId, shop in GameConfig.shops do
		if shop.worldId == world.worldId then
			local spot = world.shopSpot
			local stand = ShopService.buildStand(world.folder, shopId, spot.Position, 1)
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
-- Eggs on the egg stands of every world (two per world, #39).
local eggSpots = {}
for _, world in worlds do
	for _, stand in world.eggStands do
		local eggId = stand:GetAttribute("EggId")
		if type(eggId) == "string" then
			table.insert(eggSpots, { eggId = eggId, stand = stand })
		end
	end
end
-- Global announcement of Secret pets (#81), before eggs can be opened.
AnnounceService.start()
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
-- Lucky wheel (#98): 3D wheel on the reserved spot of the spawn island, spins drawn here.
WheelService.start(spawnIsland)
PotionService.start()
-- Delivery service: a phone and a delivery van in every world (same spot in each world).
DeliveryService.start(DeliveryService.buildAll())
-- One teleport portal per configured world (same spot in each world).
PortalService.start(PortalService.buildAll())
-- Rebirth (#35): HUD button + menu on the client, the rules decide.
RebirthService.start()
-- Admin panel (#74): only GameConfig.admin.userIds, checked per action.
AdminService.start()
-- Settings menu (#76): volume, graphics, camera, egg animation; saved per player.
SettingsService.start()
-- Daily and weekly quests (#97): new quests per German day / week, claims and rerolls.
QuestService.start()

print(`[{Constants.GAME_NAME}] Server gestartet`)
