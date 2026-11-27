--!strict
-- Travelling merchant (#107, feature "travelingMerchant"):
-- * Banner at the top for the announcement (MerchantNotice "soon" / "arrived").
-- * Trade menu: opened by the ProximityPrompt "MerchantPrompt" at the stand. One row per
--   offer of the attribute Merchant (Mega potion, egg, sometimes the exclusive pet) with
--   stock and a gem price button that sends the wish BuyMerchant(offerId). Shows the time
--   left of the visit; the server decides everything (MerchantResult).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Lang = require(script.Parent.Lang)
local UiKit = require(script.Parent.UiKit)

local PANEL_SIZE = Vector2.new(620, 520)
local PROMPT_NAME = "MerchantPrompt"
local ROW_HEIGHT = 110

local MerchantMenu = {}

type Offer = {
	id: string,
	price: number,
	limit: number,
	left: number,
	potionId: string?,
	eggId: string?,
	secretChance: number?,
	petId: string?,
}

local function offerName(offer: Offer): string
	if offer.potionId and GameConfig.potions[offer.potionId] then
		return Lang.t("merchant.potion", { potion = Lang.name(GameConfig.potions[offer.potionId]) })
	elseif offer.eggId and GameConfig.eggs[offer.eggId] then
		local merchant = GameConfig.travelingMerchant
		return Lang.t(
			"merchant.egg",
			{ egg = Lang.name(GameConfig.eggs[offer.eggId]), factor = merchant.egg.secretMultiplier }
		)
	elseif offer.petId and GameConfig.pets[offer.petId] then
		return Lang.t("merchant.pet", { pet = Lang.name(GameConfig.pets[offer.petId]) })
	end
	return offer.id
end

local function itemName(offer: Offer?, petId: string?): string
	if petId and GameConfig.pets[petId] then
		return Lang.name(GameConfig.pets[petId])
	elseif offer and offer.potionId and GameConfig.potions[offer.potionId] then
		return Lang.name(GameConfig.potions[offer.potionId])
	end
	return if offer then offer.id else "?"
end

local function clockText(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function MerchantMenu.start()
	if not Features.new(GameConfig.features).enabled("travelingMerchant") then
		return
	end
	local player = Players.LocalPlayer
	local buy = Net.event("BuyMerchant")

	local gui = Instance.new("ScreenGui")
	gui.Name = "MerchantMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	UiKit.autoScale(gui)

	-- Announcement banner (top middle).
	local banner = UiKit.label(gui, "")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 90)
	banner.Size = UDim2.fromOffset(760, 64)
	banner.BackgroundTransparency = 0.1
	banner.BackgroundColor3 = UiKit.DARK
	banner.TextColor3 = UiKit.COIN
	banner.Visible = false
	UiKit.corner(banner, 16)

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = UiKit.CREAM
	panel.Visible = false
	UiKit.corner(panel, 24)
	UiKit.stroke(panel, 4)
	UiKit.placeMenu(gui, panel, PANEL_SIZE)

	local title = UiKit.label(panel, Lang.t("merchant.title"))
	title.Position = UDim2.fromOffset(24, 14)
	title.Size = UDim2.new(1, -120, 0, 52)

	local timeLabel = UiKit.label(panel, "")
	timeLabel.Position = UDim2.fromOffset(24, 66)
	timeLabel.Size = UDim2.new(1, -48, 0, 34)
	timeLabel.TextColor3 = UiKit.ORANGE

	local closeButton = UiKit.button(panel, "X", UiKit.RED)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -14, 0, 14)
	closeButton.Size = UDim2.fromOffset(72, 72)

	local rows = Instance.new("Frame")
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromOffset(20, 110)
	rows.Size = UDim2.new(1, -40, 0, ROW_HEIGHT * 3 + 20)
	rows.Parent = panel

	local status = UiKit.label(panel, "")
	status.AnchorPoint = Vector2.new(0.5, 1)
	status.Position = UDim2.new(0.5, 0, 1, -16)
	status.Size = UDim2.new(1, -48, 0, 40)

	gui.Parent = player:WaitForChild("PlayerGui")

	local data: { active: boolean, startsAt: number, endsAt: number, offers: { Offer } } =
		{ active = false, startsAt = 0, endsAt = 0, offers = {} }

	local function render()
		for _, child in rows:GetChildren() do
			child:Destroy()
		end
		if not data.active then
			timeLabel.Text = Lang.t("merchant.away")
			return
		end
		for index, offer in data.offers do
			local row = Instance.new("Frame")
			row.BackgroundColor3 = Color3.fromRGB(255, 235, 200)
			row.Position = UDim2.fromOffset(0, (index - 1) * ROW_HEIGHT)
			row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT - 10)
			UiKit.corner(row, 16)
			row.Parent = rows
			local name = UiKit.label(row, offerName(offer))
			name.Position = UDim2.fromOffset(16, 8)
			name.Size = UDim2.new(1, -230, 0, 50)
			name.TextXAlignment = Enum.TextXAlignment.Left
			if offer.petId then
				name.TextColor3 = UiKit.rarityColor(GameConfig.pets[offer.petId].rarity)
			end
			local stock = UiKit.label(row, Lang.t("merchant.stock", { left = offer.left, limit = offer.limit }))
			stock.Position = UDim2.fromOffset(16, 58)
			stock.Size = UDim2.new(1, -230, 0, 32)
			stock.TextXAlignment = Enum.TextXAlignment.Left
			stock.TextColor3 = UiKit.GREY
			local soldOut = offer.left <= 0
			local button = UiKit.button(
				row,
				if soldOut then Lang.t("merchant.soldOut") else `💎 {offer.price}`,
				if soldOut then UiKit.GREY else UiKit.GREEN
			)
			button.AnchorPoint = Vector2.new(1, 0.5)
			button.Position = UDim2.new(1, -12, 0.5, 0)
			button.Size = UDim2.fromOffset(200, 72)
			button.Activated:Connect(function()
				if not soldOut then
					UiKit.pop(button)
					buy:FireServer(offer.id)
				end
			end)
		end
	end

	local function readAttribute()
		local raw = player:GetAttribute("Merchant")
		if type(raw) ~= "string" then
			return
		end
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(decoded) == "table" then
			data = decoded
			data.offers = data.offers or {}
			if panel.Visible then
				render()
			end
		end
	end
	player:GetAttributeChangedSignal("Merchant"):Connect(readAttribute)
	readAttribute()

	local function close()
		panel.Visible = false
	end
	UiKit.registerMenu("merchant", close)
	closeButton.Activated:Connect(close)

	local function open()
		status.Text = ""
		render()
		panel.Visible = true
		UiKit.menuOpened("merchant")
		UiKit.pop(panel)
	end

	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == PROMPT_NAME then
			prompt.ActionText = Lang.t("merchant.prompt")
			prompt.ObjectText = Lang.t("merchant.sign")
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		if prompt.Name == PROMPT_NAME and who == player then
			open()
		end
	end)

	Net.event("MerchantResult").OnClientEvent:Connect(function(ok: boolean, idOrReason: string, petId: string?)
		if ok then
			local offer: Offer? = nil
			for _, entry in data.offers do
				if entry.id == idOrReason then
					offer = entry
				end
			end
			status.Text = Lang.t("merchant.bought", { item = itemName(offer, petId) })
			status.TextColor3 = UiKit.GREEN
		else
			status.Text = Lang.t(`merchant.fail.{idOrReason}`)
			status.TextColor3 = UiKit.RED
		end
	end)

	local bannerId = 0
	Net.event("MerchantNotice").OnClientEvent:Connect(function(kind: string, minutes: number?)
		bannerId += 1
		local myId = bannerId
		banner.Text = if kind == "soon"
			then Lang.t("merchant.soon", { minutes = minutes or 1 })
			else Lang.t("merchant.arrived")
		banner.Visible = true
		UiKit.pop(banner)
		task.delay(8, function()
			if bannerId == myId then
				banner.Visible = false
			end
		end)
	end)

	-- Time left of the visit while the menu is open.
	task.spawn(function()
		while true do
			if panel.Visible and data.active then
				local left = data.endsAt - workspace:GetServerTimeNow()
				timeLabel.Text = Lang.t("merchant.left", { time = clockText(left) })
				if left <= 0 then
					timeLabel.Text = Lang.t("merchant.away")
				end
			end
			task.wait(1)
		end
	end)
end

return MerchantMenu
