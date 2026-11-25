--!strict
-- RemoteEvents between client and server. The server creates them, the client waits for them.
--
-- CollectTopping  client -> server  (slotId: number, worldId: string)  "I tapped this topping"
-- SetAutoCollect  client -> server  (enabled: boolean)          "switch auto-collect on/off"
-- UnlockWorld     client -> server  (worldId: string)          "I want to buy the barrier to this world"
-- Notify          server -> client  (kind: string, amount: number?)  feedback, e.g. "PizzaFull", "Sold", "Gems"
-- ShopOpen        server -> client  (shopId: string, offers: { GameRules.ShopOffer }, potions: { GameRules.PotionOffer })
--                                    player entered a shop stand
-- ShopUpdate      server -> client  (shopId: string, offers: { GameRules.ShopOffer }, potions: { GameRules.PotionOffer })
--                                    offers changed while inside
-- ShopClose       server -> client  ()                           player left the shop stand
-- BuyUpgrade      client -> server  (shopId: string, upgradeId: string)  "I want the next level"
-- ShopPurchase    server -> client  (ok: boolean, reasonOrId: string)  result of BuyUpgrade / BuyPotion (upgrade or potion id)
-- BuyPotion       client -> server  (shopId: string, potionId: string)  "I want one of this potion" (gem counter)
-- DrinkPotion     client -> server  (potionId: string)           "drink one of my potions"
-- PotionNotify    server -> client  (kind: string, potionId: string)  "Drunk" | "Expired" | a rule's failure reason
-- OpenEgg         client -> server  (eggId: string, count: number?)  "open 1 (or 3, if bought) of this egg"
-- EggOpened       server -> client  (eggId: string, ...petId: string)  plays the hatch animation (one pet per egg)
-- EquipPet        client -> server  (uid: number)               "equip this pet"
-- UnequipPet      client -> server  (uid: number)               "put this pet away"
-- PortalOpen      server -> client  (worldId: string, entries: { GameRules.PortalEntry })  player stands in this world's portal
-- PortalClose     server -> client  ()                           player left the portal (or was teleported)
-- Teleport        client -> server  (worldId: string)            "send me to this world" (only from inside a portal)
-- EquipBest       client -> server  ()                           "equip my pets with the highest bonus"
-- DeletePet       client -> server  (uid: number)               "delete this pet for good" (client asked to confirm)
-- PhoneOpen       server -> client  (order: GameRules.Order?, maxReward: GameRules.DeliveryReward?, seconds: number?)
--                                    player stands at a ringing phone: show the order with accept/decline;
--                                    order nil = calls are switched off: show "Anrufe sind aus"
-- PhoneClose      server -> client  ()                           player left the phone (or answered)
-- AnswerPhone     client -> server  (accept: boolean)            "take / turn down this order" (only at a phone)
-- SetPhoneCalls   client -> server  (enabled: boolean)          "switch phone calls on/off" (only at a phone)
-- Rebirth         client -> server  ()                           "do a rebirth now" (client asked to confirm)
-- Rebirthed       server -> client  (rebirths: number, multiplier: number)  rebirth done: play the celebration
--                                    (a refused rebirth answers with Notify and the rule's reason)
-- ClaimGift       client -> server  (index: number)              "give me this play time gift" (index into GameConfig.gifts)
-- GiftResult      server -> client  (ok: boolean, indexOrReason: number | string, rewards: { GameRules.Reward })
--                                    result of ClaimGift
-- HintSeen        client -> server  (hintId: string)             "I opened this new HUD button" (stops its pulsing)
-- ClaimLoginReward client -> server ()                           "give me today's login calendar reward"
-- LoginRewardResult server -> client (ok: boolean, dayOrReason: number | string, rewards: { GameRules.Reward })
--                                    result of ClaimLoginReward (day = calendar day 1-7 that was claimed)
-- AdminRun        client -> server  (actionId: string, args: { any })  "run this admin action" (#74; the
--                                    server checks the user id and every argument, see AdminActions)
-- AdminResult     server -> client  (actionId: string, ok: boolean, reason: string?)  answer to AdminRun (admins only)
--
-- Player state for the HUD is replicated via player attributes (see PlayerStates on the server):
-- Coins, Gems, PizzaCount, PizzaCapacity, AutoCollect, UnlockedWorlds (comma-separated world ids bought),
-- EggsPerOpen (1, or 3 after the gem upgrade).
-- Tutorial: TutorialStep (step id, "" = finished), TutorialNumber, TutorialTotal, TutorialProgress, TutorialGoal.
-- Pets (see PetService): Pets (JSON list of { uid, petId, equipped }), PetSlots, InventorySlots,
-- CoinMultiplier (pets only).
-- Rebirth (see RebirthService): Rebirths (number done), RebirthOffer (JSON GameRules.RebirthOffer).
-- Potions (see PotionService): Potions (JSON { [potionId]: count owned }),
-- ActivePotions (JSON { [potionId]: seconds left when the attribute was set; the client counts down from there }).
-- Delivery (see DeliveryService): PhoneRinging (boolean), PhoneCalls (boolean, false = switched off), DeliveryOrder (JSON, "" = no order:
-- { toppings = { [id]: count }, have = { [id]: count on the pizza }, reward, potionId?, secondsLeft,
--   rewardNow = amount if delivered now }; the client counts secondsLeft down until the next update).
-- Notify kinds of the delivery: PhoneRinging, OrderAccepted, OrderDeclined, OrderExpired, WrongToppings,
-- PhoneCallsOff, PhoneCallsOn,
-- NoOrder, Delivered (amount, rewardKind "Coins" | "Gems" | "Potion", potionId?).
-- Gifts (see GiftService): Gifts (JSON { ready = gifts ready to claim, nextSeconds = play time until the
--   next gift (-1 = none left today), gifts = { { minutes, status "Claimed" | "Ready" | "Waiting",
--   secondsLeft, rewards = { { kind, amount } } } } }; the client counts the seconds down until the
--   next update), SeenHints (comma-separated GameConfig.hints ids the player has opened).
-- Login calendar (see LoginCalendarService): LoginCalendar (JSON { today = calendar day 1-7, claimable,
--   days = { { day, status "Claimed" | "Ready" | "Waiting", rewards = { { kind, amount } } } } }),
--   LoginCalendarAutoOpen (German day number: set on the first join of a day; the client opens the
--   calendar window once per value).

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
	PortalOpen = true,
	PortalClose = true,
	Teleport = true,
	EquipBest = true,
	DeletePet = true,
	BuyPotion = true,
	DrinkPotion = true,
	PotionNotify = true,
	PhoneOpen = true,
	PhoneClose = true,
	AnswerPhone = true,
	SetPhoneCalls = true,
	Rebirth = true,
	Rebirthed = true,
	ClaimGift = true,
	GiftResult = true,
	HintSeen = true,
	ClaimLoginReward = true,
	LoginRewardResult = true,
	AdminRun = true,
	AdminResult = true,
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
