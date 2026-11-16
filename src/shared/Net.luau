--!strict
-- RemoteEvents between client and server. The server creates them, the client waits for them.
--
-- CollectTopping  client -> server  (slotId: number, worldId: string)  "I tapped this topping"
-- SetAutoCollect  client -> server  (enabled: boolean)          "switch auto-collect on/off"
-- UnlockWorld     client -> server  (worldId: string)          "I want to buy the barrier to this world"
-- Notify          server -> client  (kind: string, amount: number?)  feedback, e.g. "PizzaFull", "Sold"
-- ShopOpen        server -> client  (shopId: string, offers: { GameRules.ShopOffer })  player entered a shop stand
-- ShopUpdate      server -> client  (shopId: string, offers: { GameRules.ShopOffer })  offers changed while inside
-- ShopClose       server -> client  ()                           player left the shop stand
-- BuyUpgrade      client -> server  (shopId: string, upgradeId: string)  "I want the next level"
-- ShopPurchase    server -> client  (ok: boolean, reasonOrUpgradeId: string)  result of BuyUpgrade
-- OpenEgg         client -> server  (eggId: string)             "open one of this egg"
-- EggOpened       server -> client  (eggId: string, petId: string)  plays the hatch animation
-- EquipPet        client -> server  (uid: number)               "equip this pet"
-- UnequipPet      client -> server  (uid: number)               "put this pet away"
--
-- Player state for the HUD is replicated via player attributes (see PlayerStates on the server):
-- Coins, PizzaCount, PizzaCapacity, AutoCollect, UnlockedWorlds (comma-separated world ids bought).
-- Pets (see PetService): Pets (JSON list of { uid, petId, equipped }), PetSlots, CoinMultiplier.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local EVENTS = {
	CollectTopping = true,
	SetAutoCollect = true,
	Notify = true,
	UnlockWorld = true,
	ShopOpen = true,
	ShopUpdate = true,
	ShopClose = true,
	BuyUpgrade = true,
	ShopPurchase = true,
	OpenEgg = true,
	EggOpened = true,
	EquipPet = true,
	UnequipPet = true,
}

local Net = {}

function Net.event(name: string): RemoteEvent
	assert(EVENTS[name], `unknown remote event "{name}"`)

	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if folder == nil then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		local event = folder:FindFirstChild(name)
		if event == nil then
			event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
		end
		return event :: RemoteEvent
	end

	return ReplicatedStorage:WaitForChild(FOLDER_NAME):WaitForChild(name) :: RemoteEvent
end

return Net
