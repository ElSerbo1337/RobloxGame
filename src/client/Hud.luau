--!strict
-- HUD: coins and gems at the top centre with the pizza fill level right below (#75),
-- short messages under them, the auto-collect switch at the bottom. Reads the replicated player attributes (Coins,
-- PizzaCount, PizzaCapacity, AutoCollect) and Notify events. The switch only
-- sends a wish to the server; its look follows the replicated attribute.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Lang = require(script.Parent.Lang)
local Sounds = require(script.Parent.Sounds)
local Texts = require(ReplicatedStorage.Shared.Texts)
local UiKit = require(script.Parent.UiKit)

local FONT = Enum.Font.FredokaOne
local CREAM = Color3.fromRGB(255, 248, 230)
local DARK = Color3.fromRGB(60, 35, 20)
local COIN = Color3.fromRGB(255, 200, 40)
local GEM = Color3.fromRGB(60, 230, 255)
local FULL = Color3.fromRGB(230, 70, 50)
local ON = Color3.fromRGB(110, 200, 90)
local OFF = Color3.fromRGB(190, 180, 170)

-- Notify kinds with a fixed text (Texts key "notify.<kind>").
local MESSAGE_KINDS = {
	PizzaFull = true,
	OutOfRange = true,
	NotEnoughCoins = true,
	WorldLocked = true,
	PreviousWorldLocked = true,
	NotEnoughRebirths = true,
	WorldUnlocked = true,
	InventoryFull = true,
	NotEnoughGems = true,
	-- Titles (#103)
	TitleLocked = true,
	-- Delivery service
	PhoneRinging = true,
	OrderAccepted = true,
	OrderDeclined = true,
	OrderExpired = true,
	WrongToppings = true,
	NoOrder = true,
	PhoneCallsOff = true,
	PhoneCallsOn = true,
	-- Pet management (#91)
	PetLocked = true,
	EmptyTeam = true,
	InvalidName = true,
	FilterFailed = true,
}

local Hud = {}

-- Short form from a million on ("1,5 Mio" / "1.5M"), so late-world amounts fit the counters on phones.
local formatNumber = Lang.shortNumber

local function corner(parent: Instance, radius: number)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius)
	uiCorner.Parent = parent
end

local function stroke(parent: Instance)
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Thickness = 3
	uiStroke.Color = DARK
	uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	uiStroke.Parent = parent
end

local function label(parent: Instance, text: string): TextLabel
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Font = FONT
	textLabel.TextScaled = true
	textLabel.TextColor3 = DARK
	textLabel.Text = text
	textLabel.Parent = parent
	return textLabel
end

local function pop(target: GuiObject)
	local uiScale = target:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	uiScale.Parent = target
	uiScale.Scale = 1.15
	TweenService:Create(uiScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

-- Returns the coins counter, so effects (e.g. flying coins) can aim at it.
function Hud.start(): GuiObject
	local player = Players.LocalPlayer
	-- The pizza tool must stay in hand, so the hotbar is hidden.
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	UiKit.autoScale(gui)

	-- Coins and gems sit right below the top edge of the screen: their own layer ignores
	-- the room Roblox keeps for its top bar (the counters stand in the middle, the Roblox
	-- buttons in the corners) but still keeps out of notches (device safe area).
	local currency = Instance.new("ScreenGui")
	currency.Name = "Currency"
	currency.ResetOnSpawn = false
	currency.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	currency.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	UiKit.autoScale(currency)

	-- Coins (top center, left of the middle)
	local coins = Instance.new("Frame")
	coins.Name = "Coins"
	UiKit.place(coins, "coins")
	coins.BackgroundColor3 = CREAM
	corner(coins, 30)
	stroke(coins)
	coins.Parent = currency

	local coinIcon = UiKit.coinIcon(coins, 44)
	coinIcon.Position = UDim2.fromOffset(8, 8)

	local coinsText = label(coins, "0")
	coinsText.Position = UDim2.fromOffset(62, 8)
	coinsText.Size = UDim2.new(1, -78, 0, 44)
	coinsText.TextXAlignment = Enum.TextXAlignment.Left

	-- Gems (top center, right of the middle): a faceted turquoise diamond icon.
	local gems = Instance.new("Frame")
	gems.Name = "Gems"
	UiKit.place(gems, "gems")
	gems.BackgroundColor3 = CREAM
	corner(gems, 30)
	stroke(gems)
	gems.Parent = currency

	local gemIcon = UiKit.gemIcon(gems, 48)
	gemIcon.Position = UDim2.fromOffset(6, 6)

	local gemsText = label(gems, "0")
	gemsText.Position = UDim2.fromOffset(58, 8)
	gemsText.Size = UDim2.new(1, -74, 0, 44)
	gemsText.TextXAlignment = Enum.TextXAlignment.Left

	-- Pizza fill level (top center, right below coins and gems: same layer, #75)
	local pizza = Instance.new("Frame")
	pizza.Name = "PizzaFill"
	UiKit.place(pizza, "pizzaBar")
	pizza.BackgroundColor3 = CREAM
	corner(pizza, 24)
	stroke(pizza)
	pizza.Parent = currency

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromOffset(6, 6)
	bar.Size = UDim2.new(0, 0, 1, -12)
	bar.BackgroundColor3 = Color3.fromRGB(240, 160, 60)
	corner(bar, 18)
	bar.Parent = pizza

	local pizzaText = label(pizza, Lang.t("hud.pizza", { count = 0, capacity = 2 }))
	pizzaText.Position = UDim2.fromOffset(12, 7)
	pizzaText.Size = UDim2.new(1, -24, 1, -14)
	pizzaText.ZIndex = 2

	-- Auto-collect switch (bottom center). Big for thumbs.
	local autoButton = Instance.new("TextButton")
	autoButton.Name = "AutoCollect"
	UiKit.place(autoButton, "autoCollect")
	autoButton.BackgroundColor3 = OFF
	autoButton.AutoButtonColor = true
	autoButton.Font = FONT
	autoButton.TextScaled = true
	autoButton.TextColor3 = DARK
	autoButton.Text = Lang.t("hud.autoCollectOff")
	corner(autoButton, 32)
	stroke(autoButton)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = autoButton
	autoButton.Parent = gui

	-- Short messages (below the pizza bar)
	local toast = label(gui, "")
	toast.Name = "Toast"
	UiKit.place(toast, "toast")
	toast.TextColor3 = CREAM
	toast.TextStrokeColor3 = DARK
	toast.TextStrokeTransparency = 0
	toast.Visible = false

	gui.Parent = player:WaitForChild("PlayerGui")
	currency.Parent = player:WaitForChild("PlayerGui")

	local toastId = 0
	local function showToast(text: string, color: Color3?, seconds: number?)
		toastId += 1
		local myId = toastId
		toast.Text = text
		toast.TextColor3 = color or CREAM
		toast.Visible = true
		pop(toast)
		task.delay(seconds or 1.8, function()
			if toastId == myId then
				toast.Visible = false
			end
		end)
	end

	-- Language switched in the Roblox menu while playing: the UI keeps the language it was
	-- built in, so ask (in the new language) to rejoin.
	Lang.onLanguageChanged(function(language)
		showToast(Texts.format(language, "notify.languageChanged"), CREAM, 6)
	end)

	local lastCoins = 0
	local function updateCoins()
		local value = (player:GetAttribute("Coins") :: number?) or 0
		coinsText.Text = formatNumber(value)
		if value ~= lastCoins then
			pop(coins)
		end
		lastCoins = value
	end

	local lastGems = 0
	local function updateGems()
		local value = (player:GetAttribute("Gems") :: number?) or 0
		gemsText.Text = formatNumber(value)
		if value ~= lastGems then
			pop(gems)
		end
		lastGems = value
	end

	local function updatePizza()
		local count = (player:GetAttribute("PizzaCount") :: number?) or 0
		local capacity = (player:GetAttribute("PizzaCapacity") :: number?) or 1
		local isFull = count >= capacity
		pizzaText.Text = Lang.t(if isFull then "hud.pizzaFull" else "hud.pizza", { count = count, capacity = capacity })
		bar.BackgroundColor3 = if isFull then FULL else Color3.fromRGB(240, 160, 60)
		TweenService:Create(bar, TweenInfo.new(0.2), {
			Size = UDim2.new(math.clamp(count / capacity, 0, 1), -12 * math.clamp(count / capacity, 0, 1), 1, -12),
		}):Play()
	end

	local function updateAutoCollect()
		local enabled = player:GetAttribute("AutoCollect") == true
		autoButton.Text = Lang.t(if enabled then "hud.autoCollectOn" else "hud.autoCollectOff")
		autoButton.BackgroundColor3 = if enabled then ON else OFF
	end

	local setAutoCollect = Net.event("SetAutoCollect")
	autoButton.Activated:Connect(function()
		setAutoCollect:FireServer(player:GetAttribute("AutoCollect") ~= true)
		pop(autoButton)
	end)

	player:GetAttributeChangedSignal("AutoCollect"):Connect(updateAutoCollect)
	player:GetAttributeChangedSignal("Coins"):Connect(updateCoins)
	player:GetAttributeChangedSignal("Gems"):Connect(updateGems)
	player:GetAttributeChangedSignal("PizzaCount"):Connect(updatePizza)
	player:GetAttributeChangedSignal("PizzaCapacity"):Connect(updatePizza)
	updateCoins()
	updateGems()
	updatePizza()
	updateAutoCollect()

	-- `amount`: coins/gems; for "GoldenTopping" the topping id. `rewardKind`: for "Sold" the
	-- number of golden toppings sold (#94), for "Delivered" the reward kind.
	local function onNotify(kind: string, amount: any, rewardKind: any, potionId: string?)
		if kind == "Delivered" and amount then
			local potion = potionId and GameConfig.potions[potionId]
			if rewardKind == "Gems" then
				showToast(Lang.t("notify.deliveredGems", { amount = formatNumber(amount) }), GEM)
			elseif rewardKind == "Potion" and potion then
				showToast(Lang.t("notify.deliveredPotion", { amount = amount, potion = Lang.name(potion) }), ON)
			else
				showToast(Lang.t("notify.deliveredCoins", { amount = formatNumber(amount) }), COIN)
			end
		elseif kind == "Sold" and amount then
			if type(rewardKind) == "number" and rewardKind > 0 then
				showToast(Lang.t("notify.soldGolden", { amount = formatNumber(amount), count = rewardKind }), COIN)
			else
				showToast(Lang.t("notify.sold", { amount = formatNumber(amount) }), COIN)
			end
		elseif kind == "GoldenTopping" and type(amount) == "string" and GameConfig.toppings[amount] then
			showToast(Lang.t("notify.goldenTopping", { topping = Lang.name(GameConfig.toppings[amount]) }), COIN)
		elseif kind == "PetLevelUp" and type(amount) == "number" and GameConfig.pets[rewardKind] then
			-- Pet levels (#90): an equipped pet reached a new level.
			local key = if amount >= GameConfig.petLevels.maxLevel then "notify.petLevelMax" else "notify.petLevelUp"
			showToast(Lang.t(key, { pet = Lang.name(GameConfig.pets[rewardKind]), level = amount }), ON)
			Sounds.play("PetLevelUp")
		elseif kind == "IndexWorldComplete" and type(amount) == "string" and GameConfig.petIndex then
			-- Pet index (#95): all pets of a world found -> permanent coin bonus.
			local text = Lang.t("notify.IndexWorldComplete", {
				world = Lang.worldName(amount),
				percent = Lang.percent(GameConfig.petIndex.worldBonus),
			})
			showToast(text, COIN)
			Sounds.play("QuestDone")
		elseif kind == "BadgeEarned" and type(amount) == "string" then
			-- Badges (#103): Roblox awarded a badge.
			showToast(Lang.t("notify.badgeEarned", { badge = Lang.t(`badge.{amount}.name`) }), COIN)
			Sounds.play("Badge")
		elseif kind == "Gems" and amount then
			showToast(Lang.t("notify.gems", { amount = formatNumber(amount) }), GEM)
		elseif MESSAGE_KINDS[kind] then
			local color = if kind == "PizzaFull"
					or kind == "NotEnoughCoins"
					or kind == "WorldLocked"
					or kind == "NotEnoughRebirths"
					or kind == "InventoryFull"
					or kind == "NotEnoughGems"
					or kind == "WrongToppings"
					or kind == "OrderExpired"
					or kind == "PetLocked"
					or kind == "InvalidName"
					or kind == "FilterFailed"
				then FULL
				elseif kind == "WorldUnlocked" then COIN
				else nil
			showToast(Lang.t(`notify.{kind}`), color)
		end
	end
	Net.event("Notify").OnClientEvent:Connect(onNotify)

	-- A potion ran out (the potion menu may be closed, so say it here).
	Net.event("PotionNotify").OnClientEvent:Connect(function(kind: string, potionId: string)
		local potion = GameConfig.potions[potionId]
		if kind == "Expired" and potion then
			showToast(Lang.t("notify.potionExpired", { potion = Lang.name(potion) }), CREAM)
		elseif kind == "Drunk" and potion then
			showToast(Lang.t("notify.potionDrunk", { potion = Lang.name(potion) }), ON)
		end
	end)

	return coins
end

return Hud
