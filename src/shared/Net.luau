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
-- EggOpened       server -> client  (eggId: string, pets: { { petId: string, shiny: boolean, autoDeleted: boolean } })  plays the
--                                    hatch animation (one pet per egg; shiny = Shiny pet, #80)
-- EquipPet        client -> server  (uid: number)               "equip this pet"
-- UnequipPet      client -> server  (uid: number)               "put this pet away"
-- PortalOpen      server -> client  (worldId: string, entries: { GameRules.PortalEntry }, preview: boolean?)
--                                     player stands in this world's portal; preview = true: answer to
--                                     PortalPreview (list for viewing only, the player is in no portal)
-- PortalPreview   client -> server  (open: boolean?)             "show me the world list" (side bar tile, #75);
--                                     false = closed again (stops its live updates, #78)
-- PortalClose     server -> client  ()                           player left the portal (or was teleported)
-- Teleport        client -> server  (worldId: string)            "send me to this world" (only from inside a portal)
-- EquipBest       client -> server  ()                           "equip my pets with the highest bonus"
-- DeletePet       client -> server  (uid: number)               "delete this pet for good" (client asked to confirm)
-- MergePets       client -> server  (petId: string, variant: string)  "merge 5 equal pets of this kind" (#80)
-- DeletePets      client -> server  (uids: { number })          "delete all these pets" (selection mode, #91)
-- LockPet         client -> server  (uid: number, locked: boolean)  "lock / unlock this pet" (#91)
-- RenamePet       client -> server  (uid: number, name: string)  "rename this pet" ("" = config name; the server
--                                   filters it with TextService, answers with Notify on failure, #91)
-- SetAutoDelete   client -> server  (rarity: string, enabled: boolean)  "auto-delete this rarity when hatching" (#91)
-- SaveTeam        client -> server  (index: number)             "save the equipped pets as team n" (#91)
-- EquipTeam       client -> server  (index: number)             "equip team n" (#91)
-- PetMerged       server -> client  (pet: { uid, petId, variant, shiny }, consumed: { number })  play the merge animation
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
-- SetSetting      client -> server  (key: string, value: any)   "store this setting" (#76; the server
--                                    validates key and value, see GameRules.SETTINGS)
-- RedeemCode      client -> server  (code: string)              "redeem this code" (settings menu, #76;
--                                    CodeService, #99; max. 5 tries per minute)
-- CodeResult      server -> client  (ok: boolean, reason: string?, rewards: { GameRules.Reward }?)
--                                    answer to RedeemCode (#99); reason (Unknown | AlreadyUsed | Expired |
--                                    TooManyTries) is shown as `codes.<reason>`
-- SecretAnnounce  server -> client  (playerName: string, petId: string)  someone (on any server) hatched
--                                    a Secret pet (#81): show the banner
-- ClaimQuest      client -> server  (period: "Daily" | "Weekly", index: number)  "pay out this finished quest" (#97)
-- RerollQuest     client -> server  (index: number)            "swap this daily quest" (free once a day, then gems)
-- ClaimQuestBonus client -> server  ()                           "open the bonus chest" (all daily quests done)
-- QuestResult     server -> client  (ok: boolean, action: "Claim" | "Reroll" | "Bonus", reasonOrRewards: string | { GameRules.Reward },
--                                    streakChest: boolean?)  answer to the three quest wishes
-- WorldIntro      server -> client  (worldId: string)            first visit of this world (#79): play the
--                                    camera flight with the world name and its new toppings (once per world,
--                                    already marked as seen on the server)
-- SpinWheel       client -> server  (expectFree: boolean)        "spin the lucky wheel" (#98); expectFree = the
--                                    client showed a free spin: refused (NoFreeSpin) instead of paying gems
-- WheelResult     server -> client  (ok: boolean, fieldOrReason: number | string, rewards: { GameRules.Reward },
--                                    free: boolean)  field = index into GameConfig.luckyWheel.fields (the
--                                    server drew it and already paid the rewards); reasons: NoFreeSpin,
--                                    NotEnoughGems, Busy (spun again too fast)
-- BuyMerchant     client -> server  (offerId: "Potion" | "Egg" | "Pet")  buy from the travelling merchant (#107)
-- MerchantResult  server -> client  (ok: boolean, offerIdOrReason: string, petId: string?)  reasons:
--                                    MerchantAway, NotOffered, SoldOut, NotEnoughGems, InventoryFull, Busy
-- MerchantNotice  server -> client  (kind: "soon" | "arrived", minutes: number?)  merchant announcement
--
-- Player state for the HUD is replicated via player attributes (see PlayerStates on the server):
-- Coins, Gems, PizzaCount, PizzaCapacity, AutoCollect, UnlockedWorlds (comma-separated world ids bought),
-- EggsPerOpen (1, or 3 after the gem upgrade).
-- Tutorial: TutorialStep (step id, "" = finished), TutorialNumber, TutorialTotal, TutorialProgress, TutorialGoal.
-- Pets (see PetService): Pets (JSON list of { uid, petId, equipped, variant, shiny, locked, bonus, level, xp,
-- xpNeeded, name?, foundAt? }), PetSlots, InventorySlots, CoinMultiplier (pets only), PetTeams (JSON list of
-- uid lists, #91), AutoDelete (JSON { [rarity]: true }, #91).
-- Rebirth (see RebirthService): Rebirths (number done), RebirthOffer (JSON GameRules.RebirthOffer).
-- Potions (see PotionService): Potions (JSON { [potionId]: count owned }),
-- ActivePotions (JSON { [potionId]: seconds left when the attribute was set; the client counts down from there }).
-- Delivery (see DeliveryService): PhoneRinging (boolean), PhoneCalls (boolean, false = switched off), DeliveryOrder (JSON, "" = no order:
-- { toppings = { [id]: count }, have = { [id]: count on the pizza }, reward, potionId?, secondsLeft,
--   rewardNow = amount if delivered now }; the client counts secondsLeft down until the next update).
-- Notify kinds of the delivery: PhoneRinging, OrderAccepted, OrderDeclined, OrderExpired, WrongToppings,
-- PhoneCallsOff, PhoneCallsOn,
-- NoOrder, Delivered (amount, rewardKind "Coins" | "Gems" | "Potion", potionId?).
-- Travelling merchant (see MerchantService, #107): Merchant (JSON { active, startsAt, endsAt (server time),
-- offers = { GameRules.MerchantOffer } (empty while away) }).
-- Lucky wheel (see WheelService, #98): Wheel (JSON { free = free spins left today, freeTotal, bonusSeconds =
-- play time until the bonus free spin (-1 = reached), price = gems per paid spin, fields = { { id, jackpot,
-- chance, rewards } } with the coins for this player's income }).
-- Gifts (see GiftService): Gifts (JSON { ready = gifts ready to claim, nextSeconds = play time until the
--   next gift (-1 = none left today), gifts = { { minutes, status "Claimed" | "Ready" | "Waiting",
--   secondsLeft, rewards = { { kind, amount } } } } }; the client counts the seconds down until the
--   next update), SeenHints (comma-separated GameConfig.hints ids the player has opened).
-- Settings (see SettingsService, #76): Settings (JSON of state.settings: only the keys the player
--   changed; the client fills in the defaults with GameRules.resolveSettings).
-- Login calendar (see LoginCalendarService): LoginCalendar (JSON { today = calendar day 1-7, claimable,
--   days = { { day, status "Claimed" | "Ready" | "Waiting", rewards = { { kind, amount } } } } }),
--   LoginCalendarAutoOpen (German day number: set on the first join of a day; the client opens the
--   calendar window once per value).
-- Quests (see QuestService, #97): Quests (JSON GameRules.QuestStatus, the seconds left are counted
--   down locally until the next update).
-- Index (see IndexService, #95): Index (JSON { pets = rules.petIndex, toppings = rules.toppingIndex,
--   bonus = rules.indexBonus, worldBonus }); Notify("IndexWorldComplete", worldId) when a world's
--   pet index becomes complete.
-- Profile (see ProfileService, #103): SetTitle  client -> server  (titleId: string, "" =
--   automatic); attributes Profile (JSON { stats, badges, titles, title, selected }) and
--   TitleId on every player; Notify("BadgeEarned", badgeId).

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
	PortalPreview = true,
	Teleport = true,
	EquipBest = true,
	DeletePet = true,
	MergePets = true,
	PetMerged = true,
	DeletePets = true,
	LockPet = true,
	RenamePet = true,
	SetAutoDelete = true,
	SaveTeam = true,
	EquipTeam = true,
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
	SetSetting = true,
	RedeemCode = true,
	CodeResult = true,
	SecretAnnounce = true,
	WorldIntro = true,
	SpinWheel = true,
	WheelResult = true,
	BuyMerchant = true,
	MerchantResult = true,
	MerchantNotice = true,
	ClaimQuest = true,
	RerollQuest = true,
	ClaimQuestBonus = true,
	QuestResult = true,
	SetTitle = true,
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
