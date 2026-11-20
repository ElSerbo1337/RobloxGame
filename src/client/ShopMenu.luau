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
local Lang = require(script.Parent.Lang)
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

local SHOP = UiKit.Layout.SHOP
local PANEL_SIZE = Vector2.new(SHOP.width, SHOP.height)
local CARD_HEIGHT = SHOP.card
local HEADER_HEIGHT = SHOP.header

-- Purchase refusal reason → text key.
local MESSAGES: { [string]: string } = {
	NotEnoughCoins = "notify.NotEnoughCoins",
	NotEnoughGems = "notify.NotEnoughGems",
	ShopLevelLimit = "shop.ShopLevelLimit",
	MaxLevel = "shop.MaxLevel",
	WorldLocked = "notify.WorldLocked",
}

local ShopMenu = {}

local function formatNumber(value: number): string
	return Lang.integer(value)
end

-- What an upgrade's value means for the player.
local function effectText(upgradeId: string, value: number): string
	if upgradeId == "PizzaSpace" then
		return Lang.t("shop.effectToppings", { value = value })
	elseif upgradeId == "CollectRange" then
		return Lang.t("shop.effectStuds", { value = value })
	elseif upgradeId == "Magnet" then
		return if value > 0 then Lang.t("shop.effectStuds", { value = value }) else Lang.t("shop.effectOff")
	elseif upgradeId == "PetSlots" then
		return Lang.t("shop.effectPets", { value = value })
	elseif upgradeId == "InventorySpace" then
		return Lang.t("shop.effectSlots", { value = value })
	elseif upgradeId == "WalkSpeed" then
		return Lang.t("shop.effectSpeed", { value = value })
	elseif upgradeId == "TripleOpen" then
		return if value >= 3 then Lang.t("shop.effectOn") else Lang.t("shop.effectOff")
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
	-- The offer list scrolls: the panel may get as short as one card; on small screens
	-- as a section header plus one whole card with its full buy button.
	UiKit.placeMenu(gui, panel, PANEL_SIZE, UiKit.Layout.shopMinHeight(UiKit.isSmallScreen()))

	local title = label(panel, Lang.t("shop.title"), {
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
	list.Position = UDim2.fromOffset(16, SHOP.listTop)
	list.Size = UDim2.new(1, -32, 1, -(SHOP.listTop + SHOP.listBottom))
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 10
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, SHOP.gap)
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
				label(header, if isGem then Lang.t("shop.gemCounter") else Lang.t("shop.coinCounter"), {
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
			label(card, Lang.t("shop.level", { level = offer.level, max = offer.maxLevel }), {
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
					Lang.t(
						if isGem then "shop.priceGems" else "shop.priceCoins",
						{ price = formatNumber(offer.nextPrice) }
					),
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
				button = bigButton(card, Lang.t("shop.levelLimit"), GREY, buttonSize)
				button.AutoButtonColor = false
				button.Active = false
			else
				button = bigButton(card, Lang.t("shop.max"), COIN, buttonSize)
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
			label(header, Lang.t("shop.potionCounter"), {
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
			label(card, Lang.t("shop.minutes", { minutes = math.floor(offer.durationSeconds / 60) }), {
				Position = UDim2.fromOffset(14, 76),
				Size = UDim2.new(0.42, -14, 0, 22),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(110, 80, 55),
			})
			label(card, Lang.t("shop.owned", { count = offer.owned }), {
				Position = UDim2.new(0.42, 4, 0, 0),
				Size = UDim2.new(0.28, -8, 1, 0),
			})

			local canAfford = balance.Gems >= offer.price
			local button = bigButton(
				card,
				Lang.t("shop.priceGems", { price = formatNumber(offer.price) }),
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
		title.Text = if shop then shop.displayName else Lang.t("shop.title")
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
			UiKit.menuOpened("shop")
			local scale = panel:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			scale.Parent = panel
			scale.Scale = 0.85
			TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end

	-- Same for "X", leaving the shop and another menu opening: ShopOpen only comes again
	-- when the player enters a shop, so a closed shop stays closed while standing in it.
	local function close()
		currentShop = nil
		gui.Enabled = false
	end
	UiKit.registerMenu("shop", close)

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
			local key = if GameConfig.potions[detail] then "shop.boughtPotion" else "shop.bought"
			showStatus(Lang.t(key, { item = item and item.displayName or detail }), Color3.fromRGB(40, 150, 60))
		else
			showStatus(Lang.t(MESSAGES[detail] or "shop.failed"), RED)
		end
	end)
end

return ShopMenu
