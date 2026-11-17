--!strict
-- Shop menu: opens when the server says the player entered a shop stand, closes when
-- they walk out (or tap X). Shows price, effect and level of every upgrade the shop
-- sells, split into the coin counter ("Münz-Tresen") and the gem counter ("Gem-Tresen").
-- Levels read "Stufe x / total" (all levels of the upgrade, the same in every shop); at this
-- shop's limit the card says "Weitere Stufen im größeren Shop". The list starts at the top
-- every time the menu opens.
-- The gem counter also sells potions (they land in the potion inventory, see PotionMenu).
-- Buttons only send wishes (BuyUpgrade, BuyPotion); the server decides and answers ShopPurchase.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Net = require(ReplicatedStorage.Shared.Net)
local UiKit = require(script.Parent.UiKit)

type ShopOffer = GameRules.ShopOffer
type PotionOffer = GameRules.PotionOffer

local FONT = Enum.Font.FredokaOne
local CREAM = Color3.fromRGB(255, 248, 230)
local CARD = Color3.fromRGB(255, 236, 200)
local DARK = Color3.fromRGB(60, 35, 20)
local COIN = Color3.fromRGB(255, 200, 40)
local GEM = Color3.fromRGB(60, 230, 255)
local GREEN = Color3.fromRGB(90, 200, 100)
local GREY = Color3.fromRGB(190, 180, 165)
local RED = Color3.fromRGB(230, 70, 50)

local PANEL_SIZE = Vector2.new(680, 460)
local CARD_HEIGHT = 104
local HEADER_HEIGHT = 44
-- The offer list scrolls: the panel may get as short as header + one card.
local MIN_PANEL_HEIGHT = 104 + CARD_HEIGHT + 16

local MESSAGES: { [string]: string } = {
	NotEnoughCoins = "Nicht genug Münzen!",
	NotEnoughGems = "Nicht genug Gems!",
	ShopLevelLimit = "Diese Stufe gibt es nur im größeren Shop.",
	MaxLevel = "Schon auf höchster Stufe!",
	WorldLocked = "Diese Welt ist noch gesperrt!",
}

local ShopMenu = {}

local function formatNumber(value: number): string
	local text = tostring(math.floor(value))
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1.")))
	return (string.gsub(formatted, "^%.", ""))
end

-- What an upgrade's value means for the player.
local function effectText(upgradeId: string, value: number): string
	if upgradeId == "PizzaSpace" then
		return `{value} Beläge`
	elseif upgradeId == "CollectRange" then
		return `{value} Studs`
	elseif upgradeId == "Magnet" then
		return if value > 0 then `{value} Studs` else "aus"
	elseif upgradeId == "PetSlots" then
		return `{value} Pets`
	elseif upgradeId == "InventorySpace" then
		return `{value} Plätze`
	elseif upgradeId == "WalkSpeed" then
		return `Tempo {value}`
	elseif upgradeId == "TripleOpen" then
		return if value >= 3 then "an" else "aus"
	end
	return tostring(value)
end

local function corner(parent: Instance, radius: number)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius)
	uiCorner.Parent = parent
end

local function stroke(parent: Instance, thickness: number?)
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Thickness = thickness or 3
	uiStroke.Color = DARK
	uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	uiStroke.Parent = parent
end

local function label(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Font = FONT
	textLabel.TextScaled = true
	textLabel.TextColor3 = DARK
	textLabel.Text = text
	for key, value in props or {} do
		(textLabel :: any)[key] = value
	end
	textLabel.Parent = parent
	return textLabel
end

local function bigButton(parent: Instance, text: string, color: Color3, size: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	button.BackgroundColor3 = color
	button.AutoButtonColor = true
	button.Font = FONT
	button.TextScaled = true
	button.TextColor3 = DARK
	button.Text = text
	corner(button, 16)
	stroke(button)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = button
	button.Parent = parent
	return button
end

function ShopMenu.start()
	local player = Players.LocalPlayer
	local buyUpgrade = Net.event("BuyUpgrade")
	local buyPotion = Net.event("BuyPotion")

	local gui = Instance.new("ScreenGui")
	gui.Name = "ShopMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	UiKit.autoScale(gui)

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = CREAM
	corner(panel, 24)
	stroke(panel, 4)
	UiKit.placeMenu(gui, panel, PANEL_SIZE, MIN_PANEL_HEIGHT)

	local title = label(panel, "Shop", {
		Position = UDim2.fromOffset(24, 14),
		Size = UDim2.new(1, -120, 0, 48),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local closeButton = bigButton(panel, "X", RED, UDim2.fromOffset(64, 64))
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -12, 0, 10)
	closeButton.TextColor3 = CREAM

	local status = label(panel, "", {
		Name = "Status",
		Position = UDim2.fromOffset(24, 66),
		Size = UDim2.new(1, -48, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local list = Instance.new("ScrollingFrame")
	list.Name = "Offers"
	list.Position = UDim2.fromOffset(16, 104)
	list.Size = UDim2.new(1, -32, 1, -120)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 10
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	gui.Parent = player:WaitForChild("PlayerGui")

	local currentShop: string? = nil
	local currentOffers: { ShopOffer } = {}
	local currentPotions: { PotionOffer } = {}
	local statusId = 0

	local function showStatus(text: string, color: Color3)
		statusId += 1
		local myId = statusId
		status.Text = text
		status.TextColor3 = color
		task.delay(2.5, function()
			if statusId == myId then
				status.Text = ""
			end
		end)
	end

	local function render()
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local balance = {
			Coins = (player:GetAttribute("Coins") :: number?) or 0,
			Gems = (player:GetAttribute("Gems") :: number?) or 0,
		}

		local lastCurrency: string? = nil
		for index, offer in currentOffers do
			local isGem = offer.currency == "Gems"
			-- Section header whenever the counter changes (coin offers come first).
			if offer.currency ~= lastCurrency then
				lastCurrency = offer.currency
				local header = Instance.new("Frame")
				header.Name = `Header_{offer.currency}`
				header.LayoutOrder = index * 2 - 1
				header.Size = UDim2.new(1, -14, 0, HEADER_HEIGHT)
				header.BackgroundColor3 = if isGem then GEM else COIN
				corner(header, 14)
				stroke(header, 2)
				header.Parent = list
				label(header, if isGem then "Gem-Tresen" else "Münz-Tresen", {
					Position = UDim2.fromOffset(14, 4),
					Size = UDim2.new(1, -28, 1, -8),
					TextXAlignment = Enum.TextXAlignment.Left,
				})
			end

			local upgrade = GameConfig.upgrades[offer.upgrade]
			local card = Instance.new("Frame")
			card.Name = offer.upgrade
			card.LayoutOrder = index * 2
			card.Size = UDim2.new(1, -14, 0, CARD_HEIGHT)
			card.BackgroundColor3 = CARD
			corner(card, 16)
			stroke(card, 2)
			card.Parent = list

			label(card, offer.displayName, {
				Position = UDim2.fromOffset(14, 8),
				Size = UDim2.new(0.42, -14, 0, 38),
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			label(card, upgrade and upgrade.description or "", {
				Position = UDim2.fromOffset(14, 50),
				Size = UDim2.new(0.42, -14, 0, 24),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(110, 80, 55),
			})
			label(card, `Stufe {offer.level} / {offer.maxLevel}`, {
				Position = UDim2.fromOffset(14, 76),
				Size = UDim2.new(0.42, -14, 0, 22),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(110, 80, 55),
			})

			local effect = effectText(offer.upgrade, offer.value)
			if offer.nextValue then
				effect ..= `  →  {effectText(offer.upgrade, offer.nextValue)}`
			end
			label(card, effect, {
				Position = UDim2.new(0.42, 4, 0, 0),
				Size = UDim2.new(0.28, -8, 1, 0),
			})

			local buttonSize = UDim2.new(0.3, -14, 0, 76)
			local button: TextButton
			if offer.status == "Available" and offer.nextPrice then
				local canAfford = (balance[offer.currency] or 0) >= offer.nextPrice
				button = bigButton(
					card,
					`{formatNumber(offer.nextPrice)} {if isGem then "Gems" else "Münzen"}`,
					if canAfford then (if isGem then GEM else GREEN) else GREY,
					buttonSize
				)
				local upgradeId = offer.upgrade
				button.Activated:Connect(function()
					if currentShop then
						buyUpgrade:FireServer(currentShop, upgradeId)
					end
				end)
			elseif offer.status == "ShopLevelLimit" then
				button = bigButton(card, "Weitere Stufen im größeren Shop", GREY, buttonSize)
				button.AutoButtonColor = false
				button.Active = false
			else
				button = bigButton(card, "MAX", COIN, buttonSize)
				button.AutoButtonColor = false
				button.Active = false
			end
			button.AnchorPoint = Vector2.new(1, 0.5)
			button.Position = UDim2.new(1, -12, 0.5, 0)
		end

		-- Potions at the gem counter, below the gem upgrades.
		local order = #currentOffers * 2 + 1
		if #currentPotions > 0 then
			local header = Instance.new("Frame")
			header.Name = "Header_Potions"
			header.LayoutOrder = order
			header.Size = UDim2.new(1, -14, 0, HEADER_HEIGHT)
			header.BackgroundColor3 = GEM
			corner(header, 14)
			stroke(header, 2)
			header.Parent = list
			label(header, "Gem-Tresen: Tränke (je 10 Min.)", {
				Position = UDim2.fromOffset(14, 4),
				Size = UDim2.new(1, -28, 1, -8),
				TextXAlignment = Enum.TextXAlignment.Left,
			})
		end
		for index, offer in currentPotions do
			local potion = GameConfig.potions[offer.potionId]
			local card = Instance.new("Frame")
			card.Name = `Potion_{offer.potionId}`
			card.LayoutOrder = order + index
			card.Size = UDim2.new(1, -14, 0, CARD_HEIGHT)
			card.BackgroundColor3 = CARD
			corner(card, 16)
			stroke(card, 2)
			card.Parent = list

			label(card, offer.displayName, {
				Position = UDim2.fromOffset(14, 8),
				Size = UDim2.new(0.42, -14, 0, 38),
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			label(card, potion and potion.description or "", {
				Position = UDim2.fromOffset(14, 50),
				Size = UDim2.new(0.42, -14, 0, 24),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(110, 80, 55),
			})
			label(card, `{math.floor(offer.durationSeconds / 60)} Minuten`, {
				Position = UDim2.fromOffset(14, 76),
				Size = UDim2.new(0.42, -14, 0, 22),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(110, 80, 55),
			})
			label(card, `Im Inventar: {offer.owned}`, {
				Position = UDim2.new(0.42, 4, 0, 0),
				Size = UDim2.new(0.28, -8, 1, 0),
			})

			local canAfford = balance.Gems >= offer.price
			local button = bigButton(
				card,
				`{formatNumber(offer.price)} Gems`,
				if canAfford then GEM else GREY,
				UDim2.new(0.3, -14, 0, 76)
			)
			button.AnchorPoint = Vector2.new(1, 0.5)
			button.Position = UDim2.new(1, -12, 0.5, 0)
			local potionId = offer.potionId
			button.Activated:Connect(function()
				if currentShop then
					buyPotion:FireServer(currentShop, potionId)
				end
			end)
		end
	end

	local function open(shopId: string, offers: { ShopOffer }, potions: { PotionOffer }?)
		currentOffers = offers
		currentPotions = potions or {}
		local shop = GameConfig.shops[shopId]
		title.Text = if shop then shop.displayName else "Shop"
		status.Text = ""
		local reopened = not gui.Enabled or currentShop ~= shopId
		currentShop = shopId
		render()
		if reopened then
			-- Start at the top, not where the last visited shop was scrolled to.
			list.CanvasPosition = Vector2.zero
		end
		if not gui.Enabled then
			gui.Enabled = true
			local scale = panel:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			scale.Parent = panel
			scale.Scale = 0.85
			TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end

	local function close()
		currentShop = nil
		gui.Enabled = false
	end

	Net.event("ShopOpen").OnClientEvent:Connect(open)
	Net.event("ShopUpdate").OnClientEvent
		:Connect(function(shopId: string, offers: { ShopOffer }, potions: { PotionOffer }?)
			if currentShop == shopId then
				currentOffers = offers
				currentPotions = potions or {}
				render()
			end
		end)
	Net.event("ShopClose").OnClientEvent:Connect(close)
	closeButton.Activated:Connect(close)

	Net.event("ShopPurchase").OnClientEvent:Connect(function(ok: boolean, detail: string)
		if ok then
			local item = GameConfig.upgrades[detail] or GameConfig.potions[detail]
			local suffix = if GameConfig.potions[detail] then " – im Trank-Menü trinken" else ""
			showStatus(`Gekauft: {item and item.displayName or detail}!{suffix}`, Color3.fromRGB(40, 150, 60))
		else
			showStatus(MESSAGES[detail] or "Kauf nicht möglich.", RED)
		end
	end)
end

return ShopMenu
