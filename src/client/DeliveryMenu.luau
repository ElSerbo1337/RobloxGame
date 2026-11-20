--!strict
-- Delivery service on the client:
-- * Ringing: while PhoneRinging is set, every phone in the world rings for this player
--   (bouncing "RING!" bubble, ringing sound a few times per call), and the HUD says so.
-- * Phone panel: opens when the server says the player stands at a phone (PhoneOpen).
--   While it rings: order, reward ("bis zu …"), time limit and big "Annehmen" / "Ablehnen"
--   buttons, plus a small "Keine Anrufe mehr" switch; without a call only that switch
--   (calls can be turned off at any time). With calls switched off the panel
--   says so and offers "Anrufe einschalten". The buttons only send the wishes AnswerPhone /
--   SetPhoneCalls; the server decides.
-- * Order card (right side, below the potion timers): toppings with progress, timer and
--   the reward if delivered now. Reads DeliveryOrder (JSON, see Net / DeliveryService).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Sounds)
local Lang = require(script.Parent.Lang)
local UiKit = require(script.Parent.UiKit)

type Order = GameRules.Order
type DeliveryReward = GameRules.DeliveryReward

local PANEL_SIZE = Vector2.new(540, 430)
local CARD_WIDTH = 260
local RING_EVERY_SECONDS = 3
-- The ringing sound plays this often per call; bubble and HUD hint stay until answered.
local RINGS_PER_CALL = 3

local DeliveryMenu = {}

local function clockText(seconds: number): string
	local total = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", total // 60, total % 60)
end

local function toppingName(toppingId: string): string
	local topping = GameConfig.toppings[toppingId]
	return if topping then Lang.name(topping) else toppingId
end

-- Toppings sorted by name, so the list does not jump around.
local function sortedToppings(toppings: { [string]: number }): { string }
	local ids = {}
	for toppingId in toppings do
		table.insert(ids, toppingId)
	end
	table.sort(ids, function(a, b)
		return toppingName(a) < toppingName(b)
	end)
	return ids
end

local function rewardText(reward: string, amount: number, potionId: string?): string
	if reward == "Gems" then
		return Lang.t("delivery.rewardGems", { amount = Lang.integer(amount) })
	elseif reward == "Potion" then
		local potion = potionId and GameConfig.potions[potionId]
		return Lang.t("delivery.rewardPotion", {
			amount = amount,
			potion = if potion then Lang.name(potion) else Lang.t("delivery.potion"),
		})
	end
	return Lang.t("delivery.rewardCoins", { amount = UiKit.shortNumber(amount) })
end

local function readOrder(player: Player): any?
	local json = player:GetAttribute("DeliveryOrder")
	if type(json) ~= "string" or json == "" then
		return nil
	end
	local ok, value = pcall(HttpService.JSONDecode, HttpService, json)
	return if ok and type(value) == "table" and type(value.toppings) == "table" then value else nil
end

-- Bouncing "RING!" bubbles above every phone, only for this player.
local function startRinging(player: Player)
	local bubbles: { BillboardGui } = {}
	local folder = Workspace:WaitForChild("Delivery", 30)
	local function phones(): { BasePart }
		local found = {}
		if folder then
			for _, descendant in folder:GetDescendants() do
				if descendant:IsA("BasePart") and descendant:GetAttribute("DeliveryPhone") then
					table.insert(found, descendant)
				end
			end
		end
		return found
	end

	local function setRinging(ringing: boolean)
		for _, bubble in bubbles do
			bubble:Destroy()
		end
		table.clear(bubbles)
		if not ringing then
			return
		end
		for _, handset in phones() do
			local bubble = Instance.new("BillboardGui")
			bubble.Name = "RingBubble"
			bubble.Size = UDim2.fromScale(5, 2)
			bubble.StudsOffsetWorldSpace = Vector3.new(0, 5.5, 0)
			bubble.AlwaysOnTop = true
			bubble.MaxDistance = 250
			bubble.Adornee = handset
			local label = UiKit.label(bubble, Lang.t("delivery.ring"))
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 0
			label.BackgroundColor3 = UiKit.RED
			label.TextColor3 = UiKit.CREAM
			UiKit.corner(label, 12)
			bubble.Parent = player:WaitForChild("PlayerGui")
			table.insert(bubbles, bubble)
		end
	end

	local lastRing = -math.huge
	local ringsLeft = 0
	RunService.Heartbeat:Connect(function()
		if #bubbles == 0 then
			return
		end
		local t = os.clock()
		-- Hop and wiggle so the phone is noticed from afar.
		local offset = Vector3.new(0, 5.5 + math.abs(math.sin(t * 6)) * 0.8, 0)
		for _, bubble in bubbles do
			bubble.StudsOffsetWorldSpace = offset
		end
		if ringsLeft > 0 and t - lastRing >= RING_EVERY_SECONDS then
			lastRing = t
			ringsLeft -= 1
			Sounds.play("PhoneRing")
		end
	end)

	local wasRinging = false
	local function update()
		local ringing = player:GetAttribute("PhoneRinging") == true
		if ringing and not wasRinging then
			ringsLeft = RINGS_PER_CALL -- a new call
			lastRing = -math.huge
		end
		wasRinging = ringing
		setRinging(ringing)
	end
	player:GetAttributeChangedSignal("PhoneRinging"):Connect(update)
	update()
end

function DeliveryMenu.start()
	local player = Players.LocalPlayer
	local answerPhone = Net.event("AnswerPhone")
	local setPhoneCalls = Net.event("SetPhoneCalls")

	local gui = Instance.new("ScreenGui")
	gui.Name = "DeliveryMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	UiKit.autoScale(gui)

	-- Phone panel ------------------------------------------------------------
	local panel = Instance.new("Frame")
	panel.Name = "PhonePanel"
	panel.BackgroundColor3 = UiKit.CREAM
	panel.Visible = false
	UiKit.corner(panel, 24)
	UiKit.stroke(panel, 4)
	UiKit.placeMenu(gui, panel, PANEL_SIZE)

	local title = UiKit.label(panel, Lang.t("delivery.newOrder"))
	title.Position = UDim2.fromOffset(24, 14)
	title.Size = UDim2.new(1, -268, 0, 52)
	title.TextXAlignment = Enum.TextXAlignment.Left

	-- Small switch in the corner: no more calls for this player.
	local callsOffButton = UiKit.button(panel, Lang.t("delivery.callsOff"), UiKit.GREY)
	callsOffButton.Name = "CallsOff"
	callsOffButton.AnchorPoint = Vector2.new(1, 0)
	callsOffButton.Position = UDim2.new(1, -20, 0, 14)
	callsOffButton.Size = UDim2.fromOffset(220, UiKit.MIN_TOUCH)

	local orderList = UiKit.label(panel, "")
	orderList.Position = UDim2.fromOffset(24, 76)
	orderList.Size = UDim2.new(1, -48, 0, 150)
	orderList.TextScaled = false
	orderList.TextSize = 32
	orderList.TextWrapped = true
	orderList.TextXAlignment = Enum.TextXAlignment.Left
	orderList.TextYAlignment = Enum.TextYAlignment.Top

	local rewardLine = UiKit.label(panel, "")
	rewardLine.Position = UDim2.fromOffset(24, 232)
	rewardLine.Size = UDim2.new(1, -48, 0, 40)
	rewardLine.TextXAlignment = Enum.TextXAlignment.Left

	local timeLine = UiKit.label(panel, "")
	timeLine.Position = UDim2.fromOffset(24, 276)
	timeLine.Size = UDim2.new(1, -48, 0, 32)
	timeLine.TextXAlignment = Enum.TextXAlignment.Left
	timeLine.TextColor3 = Color3.fromRGB(110, 80, 55)

	local acceptButton = UiKit.button(panel, Lang.t("delivery.accept"), UiKit.GREEN)
	acceptButton.Name = "Accept"
	acceptButton.AnchorPoint = Vector2.new(0, 1)
	acceptButton.Position = UDim2.new(0, 24, 1, -20)
	acceptButton.Size = UDim2.new(0.5, -36, 0, 84)

	local declineButton = UiKit.button(panel, Lang.t("delivery.decline"), UiKit.RED)
	declineButton.Name = "Decline"
	declineButton.AnchorPoint = Vector2.new(1, 1)
	declineButton.Position = UDim2.new(1, -24, 1, -20)
	declineButton.Size = UDim2.new(0.5, -36, 0, 84)

	local callsOnButton = UiKit.button(panel, Lang.t("delivery.callsOn"), UiKit.GREEN)
	callsOnButton.Name = "CallsOn"
	callsOnButton.AnchorPoint = Vector2.new(0.5, 1)
	callsOnButton.Position = UDim2.new(0.5, 0, 1, -20)
	callsOnButton.Size = UDim2.new(1, -48, 0, 84)

	-- Order view (a call), idle view (calls on, no call: only the off switch) or
	-- "Anrufe sind aus" view.
	local function showView(callsOn: boolean, hasCall: boolean)
		title.Size = if callsOn then UDim2.new(1, -268, 0, 52) else UDim2.new(1, -48, 0, 52)
		callsOffButton.Visible = callsOn
		for _, part in { rewardLine, timeLine, acceptButton, declineButton } do
			part.Visible = hasCall
		end
		callsOnButton.Visible = not callsOn
	end

	callsOffButton.Activated:Connect(function()
		UiKit.pop(callsOffButton)
		setPhoneCalls:FireServer(false)
	end)
	callsOnButton.Activated:Connect(function()
		UiKit.pop(callsOnButton)
		setPhoneCalls:FireServer(true)
	end)
	acceptButton.Activated:Connect(function()
		UiKit.pop(acceptButton)
		answerPhone:FireServer(true)
	end)
	declineButton.Activated:Connect(function()
		UiKit.pop(declineButton)
		answerPhone:FireServer(false)
	end)

	-- `callsOn` true without an order: calls are on but nobody calls right now.
	local function onPhoneOpen(order: Order?, maxReward: DeliveryReward?, seconds: number?, callsOn: boolean?)
		showView(order ~= nil or callsOn == true, order ~= nil)
		if order == nil and callsOn then
			title.Text = Lang.t("delivery.phoneTitle")
			orderList.Text = Lang.t("delivery.noCall")
		elseif order == nil then
			title.Text = Lang.t("delivery.callsOffTitle")
			orderList.Text = Lang.t("delivery.callsOffBody")
		else
			title.Text = Lang.t("delivery.newOrder")
			local lines = {}
			for _, toppingId in sortedToppings(order.toppings) do
				table.insert(lines, `{order.toppings[toppingId]}× {toppingName(toppingId)}`)
			end
			orderList.Text = table.concat(lines, "\n")
			rewardLine.Text = if maxReward
				then Lang.t("delivery.maxReward", {
					reward = rewardText(maxReward.reward, maxReward.amount, maxReward.potionId),
				})
				else ""
			timeLine.Text = Lang.t("delivery.timeLimit", { time = clockText(seconds or 0) })
		end
		if not panel.Visible then
			panel.Visible = true
			UiKit.menuOpened("phone")
			UiKit.pop(panel, 0.85)
		end
	end
	Net.event("PhoneOpen").OnClientEvent:Connect(onPhoneOpen)
	Net.event("PhoneClose").OnClientEvent:Connect(function()
		panel.Visible = false
	end)
	-- Another menu opening hides the phone panel; it comes back with the next call or
	-- when the player steps up to the phone again.
	UiKit.registerMenu("phone", function()
		panel.Visible = false
	end)

	-- Order card (right side) --------------------------------------------------
	local card = Instance.new("Frame")
	card.Name = "OrderCard"
	card.LayoutOrder = 2
	card.Size = UDim2.fromOffset(CARD_WIDTH, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = UiKit.CREAM
	card.Visible = false
	UiKit.corner(card, 18)
	UiKit.stroke(card)
	-- Right column of the HUD grid, below the potion pills.
	card.Parent = UiKit.rightColumn()
	local cardPadding = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(cardPadding :: any)[side] = UDim.new(0, 10)
	end
	cardPadding.Parent = card
	local cardLayout = Instance.new("UIListLayout")
	cardLayout.Padding = UDim.new(0, 4)
	cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardLayout.Parent = card

	local function cardLine(order: number, height: number): TextLabel
		local line = UiKit.label(card, "")
		line.LayoutOrder = order
		line.Size = UDim2.new(1, 0, 0, height)
		line.TextXAlignment = Enum.TextXAlignment.Left
		return line
	end
	local header = cardLine(1, 36)
	local toppingLines = Instance.new("Frame")
	toppingLines.Name = "Toppings"
	toppingLines.LayoutOrder = 2
	toppingLines.BackgroundTransparency = 1
	toppingLines.Size = UDim2.new(1, 0, 0, 0)
	toppingLines.AutomaticSize = Enum.AutomaticSize.Y
	toppingLines.Parent = card
	local linesLayout = Instance.new("UIListLayout")
	linesLayout.Padding = UDim.new(0, 2)
	linesLayout.SortOrder = Enum.SortOrder.LayoutOrder
	linesLayout.Parent = toppingLines
	local rewardNow = cardLine(3, 28)
	local hint = cardLine(4, 22)
	hint.TextColor3 = Color3.fromRGB(110, 80, 55)

	gui.Parent = player:WaitForChild("PlayerGui")

	-- Seconds left as of `syncedAt` (os.clock()).
	local current: any? = nil
	local secondsLeft = 0
	local syncedAt = os.clock()

	local function updateTimer()
		if current then
			local left = math.max(0, secondsLeft - (os.clock() - syncedAt))
			header.Text = Lang.t("delivery.cardHeader", { time = clockText(left) })
			header.TextColor3 = if left <= 30 then UiKit.RED else UiKit.DARK
		end
	end

	local function render()
		current = readOrder(player)
		local ringing = player:GetAttribute("PhoneRinging") == true
		for _, child in toppingLines:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		if current == nil then
			-- No order: the card only reminds of a ringing phone.
			card.Visible = ringing
			header.Text = Lang.t("delivery.ringing")
			header.TextColor3 = UiKit.RED
			rewardNow.Text = ""
			hint.Text = Lang.t("delivery.ringingHint")
			return
		end
		secondsLeft = tonumber(current.secondsLeft) or 0
		syncedAt = os.clock()
		local allThere = true
		for index, toppingId in sortedToppings(current.toppings) do
			local need = current.toppings[toppingId]
			local have = math.min(need, (current.have and current.have[toppingId]) or 0)
			local done = have >= need
			allThere = allThere and done
			local line =
				UiKit.label(toppingLines, `{if done then "✓" else "•"} {have}/{need} {toppingName(toppingId)}`)
			line.LayoutOrder = index
			line.Size = UDim2.new(1, 0, 0, 28)
			line.TextXAlignment = Enum.TextXAlignment.Left
			line.TextColor3 = if done then Color3.fromRGB(40, 140, 50) else UiKit.DARK
		end
		rewardNow.Text = rewardText(current.reward, tonumber(current.rewardNow) or 0, current.potionId)
		hint.Text = if allThere then Lang.t("delivery.allThere") else Lang.t("delivery.hurry")
		updateTimer()
		if not card.Visible then
			card.Visible = true
			UiKit.pop(card)
		end
	end

	player:GetAttributeChangedSignal("DeliveryOrder"):Connect(render)
	player:GetAttributeChangedSignal("PhoneRinging"):Connect(render)
	render()

	local lastShown = -1
	RunService.Heartbeat:Connect(function()
		local now = math.floor(os.clock())
		if now ~= lastShown then
			lastShown = now
			updateTimer()
		end
	end)

	task.spawn(startRinging, player)
end

return DeliveryMenu
