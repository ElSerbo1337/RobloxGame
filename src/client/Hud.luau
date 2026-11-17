--!strict
-- HUD: coins and gems at the top, pizza fill level and auto-collect switch at the bottom,
-- short messages in between. Reads the replicated player attributes (Coins,
-- PizzaCount, PizzaCapacity, AutoCollect) and Notify events. The switch only
-- sends a wish to the server; its look follows the replicated attribute.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local UiKit = require(script.Parent.UiKit)

local FONT = Enum.Font.FredokaOne
local CREAM = Color3.fromRGB(255, 248, 230)
local DARK = Color3.fromRGB(60, 35, 20)
local COIN = Color3.fromRGB(255, 200, 40)
local GEM = Color3.fromRGB(60, 230, 255)
local FULL = Color3.fromRGB(230, 70, 50)
local ON = Color3.fromRGB(110, 200, 90)
local OFF = Color3.fromRGB(190, 180, 170)

local MESSAGES: { [string]: string } = {
	PizzaFull = "Pizza voll! Ab zum Ofen.",
	OutOfRange = "Zu weit weg!",
	NotEnoughCoins = "Nicht genug Münzen!",
	WorldLocked = "Diese Welt ist noch gesperrt!",
	PreviousWorldLocked = "Erst die vorige Welt freischalten!",
	WorldUnlocked = "Neue Welt freigeschaltet!",
	InventoryFull = "Pet-Inventar voll! Lösche erst ein Pet.",
	NotEnoughGems = "Nicht genug Gems!",
	-- Delivery service
	PhoneRinging = "📞 Das Telefon klingelt!",
	OrderAccepted = "Auftrag angenommen! Beläge sammeln, dann zum 🚚.",
	OrderDeclined = "Auftrag abgelehnt.",
	OrderExpired = "Zeit um – der Auftrag ist verfallen.",
	WrongToppings = "Falsche Beläge! Überzählige am Ofen verkaufen.",
	NoOrder = "Kein Auftrag – geh ans Telefon!",
}

local Hud = {}

-- Short form from a million on ("1,5 Mio"), so late-world amounts fit the counters on phones.
local formatNumber = UiKit.shortNumber

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

	-- Coins (top center, left of the middle)
	local coins = Instance.new("Frame")
	coins.Name = "Coins"
	UiKit.place(coins, "coins")
	coins.BackgroundColor3 = CREAM
	corner(coins, 30)
	stroke(coins)
	coins.Parent = gui

	local coinIcon = Instance.new("Frame")
	coinIcon.Size = UDim2.fromOffset(44, 44)
	coinIcon.Position = UDim2.fromOffset(8, 8)
	coinIcon.BackgroundColor3 = COIN
	corner(coinIcon, 22)
	stroke(coinIcon)
	coinIcon.Parent = coins

	local coinsText = label(coins, "0")
	coinsText.Position = UDim2.fromOffset(62, 8)
	coinsText.Size = UDim2.new(1, -78, 0, 44)
	coinsText.TextXAlignment = Enum.TextXAlignment.Left

	-- Gems (top center, right of the middle): a turquoise diamond icon.
	local gems = Instance.new("Frame")
	gems.Name = "Gems"
	UiKit.place(gems, "gems")
	gems.BackgroundColor3 = CREAM
	corner(gems, 30)
	stroke(gems)
	gems.Parent = gui

	local gemIcon = Instance.new("Frame")
	gemIcon.Size = UDim2.fromOffset(32, 32)
	gemIcon.Position = UDim2.fromOffset(14, 14)
	gemIcon.Rotation = 45
	gemIcon.BackgroundColor3 = GEM
	corner(gemIcon, 6)
	stroke(gemIcon)
	gemIcon.Parent = gems

	local gemsText = label(gems, "0")
	gemsText.Position = UDim2.fromOffset(58, 8)
	gemsText.Size = UDim2.new(1, -74, 0, 44)
	gemsText.TextXAlignment = Enum.TextXAlignment.Left

	-- Pizza fill level (bottom center)
	local pizza = Instance.new("Frame")
	pizza.Name = "PizzaFill"
	UiKit.place(pizza, "pizzaBar")
	pizza.BackgroundColor3 = CREAM
	corner(pizza, 32)
	stroke(pizza)
	pizza.Parent = gui

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromOffset(8, 8)
	bar.Size = UDim2.new(0, 0, 1, -16)
	bar.BackgroundColor3 = Color3.fromRGB(240, 160, 60)
	corner(bar, 24)
	bar.Parent = pizza

	local pizzaText = label(pizza, "Pizza 0/2")
	pizzaText.Position = UDim2.fromOffset(12, 10)
	pizzaText.Size = UDim2.new(1, -24, 1, -20)
	pizzaText.ZIndex = 2

	-- Auto-collect switch (bottom center, above the pizza fill). Big for thumbs.
	local autoButton = Instance.new("TextButton")
	autoButton.Name = "AutoCollect"
	UiKit.place(autoButton, "autoCollect")
	autoButton.BackgroundColor3 = OFF
	autoButton.AutoButtonColor = true
	autoButton.Font = FONT
	autoButton.TextScaled = true
	autoButton.TextColor3 = DARK
	autoButton.Text = "Auto-Sammeln: AUS"
	corner(autoButton, 32)
	stroke(autoButton)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = autoButton
	autoButton.Parent = gui

	-- Short messages (below the coins)
	local toast = label(gui, "")
	toast.Name = "Toast"
	UiKit.place(toast, "toast")
	toast.TextColor3 = CREAM
	toast.TextStrokeColor3 = DARK
	toast.TextStrokeTransparency = 0
	toast.Visible = false

	gui.Parent = player:WaitForChild("PlayerGui")

	local toastId = 0
	local function showToast(text: string, color: Color3?)
		toastId += 1
		local myId = toastId
		toast.Text = text
		toast.TextColor3 = color or CREAM
		toast.Visible = true
		pop(toast)
		task.delay(1.8, function()
			if toastId == myId then
				toast.Visible = false
			end
		end)
	end

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
		pizzaText.Text = if isFull then `Pizza VOLL {count}/{capacity}` else `Pizza {count}/{capacity}`
		bar.BackgroundColor3 = if isFull then FULL else Color3.fromRGB(240, 160, 60)
		TweenService:Create(bar, TweenInfo.new(0.2), {
			Size = UDim2.new(math.clamp(count / capacity, 0, 1), -16 * math.clamp(count / capacity, 0, 1), 1, -16),
		}):Play()
	end

	local function updateAutoCollect()
		local enabled = player:GetAttribute("AutoCollect") == true
		autoButton.Text = if enabled then "Auto-Sammeln: AN" else "Auto-Sammeln: AUS"
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

	local function onNotify(kind: string, amount: number?, rewardKind: string?, potionId: string?)
		if kind == "Delivered" and amount then
			local potion = potionId and GameConfig.potions[potionId]
			if rewardKind == "Gems" then
				showToast(`Geliefert! +{formatNumber(amount)} Gems`, GEM)
			elseif rewardKind == "Potion" and potion then
				showToast(`Geliefert! +{amount}× {potion.displayName}`, ON)
			else
				showToast(`Geliefert! +{formatNumber(amount)} Münzen`, COIN)
			end
		elseif kind == "Sold" and amount then
			showToast(`+{formatNumber(amount)} Münzen`, COIN)
		elseif kind == "Gems" and amount then
			showToast(`+{formatNumber(amount)} Gems!`, GEM)
		elseif kind == "PlaytimeGems" and amount then
			showToast(`+{formatNumber(amount)} Gem fürs Spielen!`, GEM)
		elseif MESSAGES[kind] then
			local color = if kind == "PizzaFull"
					or kind == "NotEnoughCoins"
					or kind == "WorldLocked"
					or kind == "InventoryFull"
					or kind == "NotEnoughGems"
					or kind == "WrongToppings"
					or kind == "OrderExpired"
				then FULL
				elseif kind == "WorldUnlocked" then COIN
				else nil
			showToast(MESSAGES[kind], color)
		end
	end
	Net.event("Notify").OnClientEvent:Connect(onNotify)

	-- A potion ran out (the potion menu may be closed, so say it here).
	Net.event("PotionNotify").OnClientEvent:Connect(function(kind: string, potionId: string)
		local potion = GameConfig.potions[potionId]
		if kind == "Expired" and potion then
			showToast(`{potion.displayName} ist abgelaufen.`, CREAM)
		elseif kind == "Drunk" and potion then
			showToast(`{potion.displayName} wirkt 10 Minuten!`, ON)
		end
	end)

	return coins
end

return Hud
