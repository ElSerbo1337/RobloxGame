--!strict
-- Potions on the client:
-- * Side bar tile "Tränke" (after "Pets") opens the potion inventory: every
--   potion with how many the player owns, time left and a big "Trinken" button.
-- * Bottom right of the HUD (above the jump button, #75): one timer per running potion.
-- Reads the attributes Potions and ActivePotions (JSON, see Net / PotionService). The time
-- left is re-synced by the server every few seconds and counted down locally in between.
-- "Trinken" only sends the wish DrinkPotion; the server decides and answers PotionNotify.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Lang = require(script.Parent.Lang)
local SideBar = require(script.Parent.SideBar)
local UiKit = require(script.Parent.UiKit)

-- Display order and look of each potion (the effects live in GameConfig / GameRules).
local LOOKS: { { potionId: string, icon: string, color: Color3, effect: string } } = {
	{ potionId = "Coins", icon = "💰", color = UiKit.COIN, effect = Lang.t("potions.effectCoins") },
	{ potionId = "Luck", icon = "🍀", color = UiKit.GREEN, effect = Lang.t("potions.effectLuck") },
	{ potionId = "Speed", icon = "⚡", color = Color3.fromRGB(90, 170, 255), effect = Lang.t("potions.effectSpeed") },
}

-- Subtitle sits below the close button (full width, never covered); the cards follow.
local PANEL_SIZE = Vector2.new(560, 502)
local CARDS_TOP = 132
local CARD_HEIGHT = 112
local TIMER_SIZE = Vector2.new(230, 64)

local MESSAGES: { [string]: string } = {
	NoPotion = Lang.t("potions.NoPotion"),
	UnknownPotion = Lang.t("potions.UnknownPotion"),
}

local PotionMenu = {}

local function readJson(player: Player, attribute: string): { [string]: number }
	local json = player:GetAttribute(attribute)
	if type(json) ~= "string" then
		return {}
	end
	local ok, value = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok or type(value) ~= "table" then
		return {}
	end
	local result = {}
	for key, number in value do
		if type(key) == "string" and type(number) == "number" then
			result[key] = number
		end
	end
	return result
end

-- "9:05" from 545 seconds.
local function clockText(seconds: number): string
	local total = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", total // 60, total % 60)
end

function PotionMenu.start()
	local player = Players.LocalPlayer
	local drinkPotion = Net.event("DrinkPotion")

	local gui = Instance.new("ScreenGui")
	gui.Name = "PotionMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	UiKit.autoScale(gui)

	-- Side bar tile, the place after "Pets".
	local toggle: () -> () = function() end
	local openButton = SideBar.register({
		id = "potions",
		order = 20,
		text = Lang.t("side.potions"),
		color = Color3.fromRGB(170, 90, 230),
		icon = { shape = "potion" },
		open = function()
			toggle()
		end,
	})

	-- Running potions: bottom of the right column, above the jump button (#75).
	local timers = Instance.new("Frame")
	timers.Name = "PotionTimers"
	timers.LayoutOrder = 1
	timers.Size = UDim2.fromOffset(TIMER_SIZE.X, 0)
	timers.AutomaticSize = Enum.AutomaticSize.Y
	timers.BackgroundTransparency = 1
	timers.Visible = false
	timers.Parent = UiKit.potionColumn()
	local timerLayout = Instance.new("UIListLayout")
	timerLayout.Padding = UDim.new(0, 8)
	timerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	timerLayout.Parent = timers

	local timerLabels: { [string]: { frame: Frame, text: TextLabel } } = {}
	for index, look in LOOKS do
		local frame = Instance.new("Frame")
		frame.Name = look.potionId
		frame.LayoutOrder = index
		frame.Size = UDim2.fromOffset(TIMER_SIZE.X, TIMER_SIZE.Y)
		frame.BackgroundColor3 = UiKit.CREAM
		frame.Visible = false
		UiKit.corner(frame, 32)
		UiKit.stroke(frame)
		frame.Parent = timers

		local icon = UiKit.label(frame, look.icon)
		icon.Position = UDim2.fromOffset(8, 8)
		icon.Size = UDim2.fromOffset(48, 48)
		icon.BackgroundTransparency = 0
		icon.BackgroundColor3 = look.color
		UiKit.corner(icon, 24)

		local text = UiKit.label(frame, "")
		text.Position = UDim2.fromOffset(64, 10)
		text.Size = UDim2.new(1, -80, 1, -20)
		text.TextXAlignment = Enum.TextXAlignment.Left
		timerLabels[look.potionId] = { frame = frame, text = text }
	end

	-- Inventory panel
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = UiKit.CREAM
	panel.Visible = false
	UiKit.corner(panel, 24)
	UiKit.stroke(panel, 4)
	UiKit.placeMenu(gui, panel, PANEL_SIZE)

	local title = UiKit.label(panel, Lang.t("potions.title"))
	title.Position = UDim2.fromOffset(24, 14)
	title.Size = UDim2.new(1, -120, 0, 48)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local status = UiKit.label(panel, Lang.t("potions.hint"))
	status.Position = UDim2.fromOffset(24, 94)
	status.Size = UDim2.new(1, -48, 0, 30)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextColor3 = Color3.fromRGB(110, 80, 55)
	local hint = status.Text

	local closeButton = UiKit.button(panel, "X", UiKit.RED)
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -14, 0, 14)
	closeButton.Size = UDim2.fromOffset(72, 72)

	local cards: { [string]: { owned: TextLabel, left: TextLabel, button: TextButton } } = {}
	for index, look in LOOKS do
		local potion = GameConfig.potions[look.potionId]
		local card = Instance.new("Frame")
		card.Name = look.potionId
		card.Position = UDim2.fromOffset(16, CARDS_TOP + (index - 1) * (CARD_HEIGHT + 10))
		card.Size = UDim2.new(1, -32, 0, CARD_HEIGHT)
		card.BackgroundColor3 = Color3.fromRGB(255, 236, 200)
		UiKit.corner(card, 16)
		UiKit.stroke(card, 2)
		card.Parent = panel

		local icon = UiKit.label(card, look.icon)
		icon.Position = UDim2.fromOffset(12, 20)
		icon.Size = UDim2.fromOffset(72, 72)
		icon.BackgroundTransparency = 0
		icon.BackgroundColor3 = look.color
		UiKit.corner(icon, 36)
		UiKit.stroke(icon, 2)

		local name = UiKit.label(card, Lang.name(potion))
		name.Position = UDim2.fromOffset(96, 8)
		name.Size = UDim2.new(0.6, -96, 0, 36)
		name.TextXAlignment = Enum.TextXAlignment.Left

		local description = UiKit.label(card, Lang.description(potion))
		description.Position = UDim2.fromOffset(96, 46)
		description.Size = UDim2.new(0.6, -96, 0, 24)
		description.TextXAlignment = Enum.TextXAlignment.Left
		description.TextColor3 = Color3.fromRGB(110, 80, 55)

		local owned = UiKit.label(card, "")
		owned.Position = UDim2.fromOffset(96, 74)
		owned.Size = UDim2.new(0.3, -48, 0, 28)
		owned.TextXAlignment = Enum.TextXAlignment.Left

		local left = UiKit.label(card, "")
		left.Position = UDim2.new(0.3, 48, 0, 74)
		left.Size = UDim2.new(0.3, -48, 0, 28)
		left.TextXAlignment = Enum.TextXAlignment.Left
		left.TextColor3 = Color3.fromRGB(40, 130, 40)

		local button = UiKit.button(card, Lang.t("potions.drink"), UiKit.GREEN)
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -12, 0.5, 0)
		button.Size = UDim2.new(0.4, -24, 0, 76)
		local potionId = look.potionId
		button.Activated:Connect(function()
			drinkPotion:FireServer(potionId)
			UiKit.pop(button)
		end)

		cards[look.potionId] = { owned = owned, left = left, button = button }
	end

	gui.Parent = player:WaitForChild("PlayerGui")

	-- Time left per running potion, as of `syncedAt` (os.clock()).
	local active: { [string]: number } = {}
	local syncedAt = os.clock()

	local function timeLeft(potionId: string): number
		local left = active[potionId]
		return if left then math.max(0, left - (os.clock() - syncedAt)) else 0
	end

	local function updateInventory()
		local owned = readJson(player, "Potions")
		for _, look in LOOKS do
			local card = cards[look.potionId]
			local count = owned[look.potionId] or 0
			card.owned.Text = Lang.t("potions.owned", { count = Lang.integer(count) })
			card.button.BackgroundColor3 = if count > 0 then UiKit.GREEN else UiKit.GREY
			card.button.AutoButtonColor = count > 0
		end
	end

	local function updateTimers()
		local anyRunning = false
		for _, look in LOOKS do
			local left = timeLeft(look.potionId)
			local timer = timerLabels[look.potionId]
			local running = left > 0
			anyRunning = anyRunning or running
			if timer.frame.Visible ~= running then
				timer.frame.Visible = running
				if running then
					UiKit.pop(timer.frame)
				end
			end
			if running then
				timer.text.Text = `{look.effect}  {clockText(left)}`
			end
			cards[look.potionId].left.Text = if running
				then Lang.t("potions.running", { time = clockText(left) })
				else ""
		end
		-- Hidden when empty, so the order card moves up in the right column.
		timers.Visible = anyRunning
	end

	local function syncActive()
		active = readJson(player, "ActivePotions")
		syncedAt = os.clock()
		updateTimers()
	end

	player:GetAttributeChangedSignal("Potions"):Connect(updateInventory)
	player:GetAttributeChangedSignal("ActivePotions"):Connect(syncActive)
	updateInventory()
	syncActive()

	local lastShown = -1
	RunService.Heartbeat:Connect(function()
		-- Refresh the countdown about once a second.
		local now = math.floor(os.clock())
		if now ~= lastShown then
			lastShown = now
			updateTimers()
		end
	end)

	local statusId = 0
	local function showStatus(text: string, color: Color3)
		statusId += 1
		local myId = statusId
		status.Text = text
		status.TextColor3 = color
		task.delay(2.5, function()
			if statusId == myId then
				status.Text = hint
				status.TextColor3 = Color3.fromRGB(110, 80, 55)
			end
		end)
	end

	local function close()
		panel.Visible = false
	end
	UiKit.registerMenu("potions", close)

	local function open()
		panel.Visible = true
		UiKit.menuOpened("potions")
		local scale = panel:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		scale.Parent = panel
		scale.Scale = 0.85
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end

	toggle = function()
		UiKit.pop(openButton)
		if panel.Visible then
			close()
		else
			open()
		end
	end
	closeButton.Activated:Connect(close)

	Net.event("PotionNotify").OnClientEvent:Connect(function(kind: string, potionId: string)
		local potion = GameConfig.potions[potionId]
		local name = if potion then Lang.name(potion) else potionId
		if kind == "Drunk" then
			showStatus(Lang.t("potions.drunk", { potion = name }), Color3.fromRGB(40, 150, 60))
		elseif kind == "Expired" then
			showStatus(Lang.t("potions.expired", { potion = name }), UiKit.RED)
		else
			showStatus(MESSAGES[kind] or Lang.t("common.notNow"), UiKit.RED)
		end
	end)
end

return PotionMenu
