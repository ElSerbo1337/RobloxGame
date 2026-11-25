--!strict
-- Play time gifts on the client:
-- * Side bar tile "Geschenke" (#75) with a countdown to the next gift as caption and a
--   red dot while one is ready. It pulses (with a short note) until the
--   player opened it once (hint "Gifts", remembered on the server), starting after the tutorial.
-- * The menu lists every gift of the day: play time needed, rewards and a button
--   ("Abholen" when ready, the time left while waiting, a tick once claimed), and a
--   "Kalender" button that opens the login calendar.
-- Reads the attributes Gifts (JSON) and SeenHints (see Net / GiftService); the play time
-- left is re-synced by the server every few seconds and counted down locally in between.
-- "Abholen" only sends the wish ClaimGift; the server decides and answers GiftResult.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local LoginCalendarMenu = require(script.Parent.LoginCalendarMenu)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Sounds)
local Lang = require(script.Parent.Lang)
local SideBar = require(script.Parent.SideBar)
local UiKit = require(script.Parent.UiKit)

local HINT_ID = "Gifts"
local BUTTON_COLOR = Color3.fromRGB(235, 90, 140)
local TILE_ID = "gifts"
local ROW_HEIGHT = 64
local ROW_GAP = 8
local HEADER_HEIGHT = 124
local PANEL_SIZE = Vector2.new(560, HEADER_HEIGHT + #GameConfig.gifts * (ROW_HEIGHT + ROW_GAP) + 12)

local MESSAGES: { [string]: string } = {
	GiftNotReady = Lang.t("gifts.GiftNotReady"),
	GiftClaimed = Lang.t("gifts.GiftClaimed"),
	UnknownGift = Lang.t("gifts.UnknownGift"),
}

type Reward = { kind: string, amount: number, potionId: string? }
type Gift = { minutes: number, status: string, secondsLeft: number, rewards: { Reward } }
type Status = { ready: number, nextSeconds: number, gifts: { Gift } }

local GiftMenu = {}

local function readStatus(player: Player): Status
	local json = player:GetAttribute("Gifts")
	local empty: Status = { ready = 0, nextSeconds = -1, gifts = {} }
	if type(json) ~= "string" then
		return empty
	end
	local ok, value = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok or type(value) ~= "table" or type(value.gifts) ~= "table" then
		return empty
	end
	return value :: Status
end

-- "9:05" from 545 seconds.
local function clockText(seconds: number): string
	local total = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", total // 60, total % 60)
end

function GiftMenu.start()
	local player = Players.LocalPlayer
	local claimGift = Net.event("ClaimGift")
	local hintSeen = Net.event("HintSeen")

	local gui = Instance.new("ScreenGui")
	gui.Name = "GiftMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	UiKit.autoScale(gui)

	-- Side bar tile: the countdown to the next gift is its caption, a red dot while one
	-- is ready.
	local toggle: () -> () = function() end
	local openButton = SideBar.register({
		id = TILE_ID,
		order = 30,
		text = Lang.t("side.gifts"),
		color = BUTTON_COLOR,
		icon = { shape = "gift" },
		open = function()
			toggle()
		end,
	})

	-- Short note next to the button while it is new.
	local note = UiKit.label(openButton, Lang.t("side.giftsNote"))
	note.Name = "Note"
	UiKit.placeSideNote(note, openButton, 22)
	note.Size = UDim2.fromOffset(200, 52)
	note.BackgroundTransparency = 0
	note.BackgroundColor3 = UiKit.CREAM
	note.ZIndex = 3
	note.Visible = false
	UiKit.corner(note, 14)
	UiKit.stroke(note, 3)
	local notePadding = Instance.new("UIPadding")
	notePadding.PaddingLeft = UDim.new(0, 8)
	notePadding.PaddingRight = UDim.new(0, 8)
	notePadding.PaddingTop = UDim.new(0, 4)
	notePadding.PaddingBottom = UDim.new(0, 4)
	notePadding.Parent = note

	-- Menu panel
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = UiKit.CREAM
	panel.Visible = false
	UiKit.corner(panel, 24)
	UiKit.stroke(panel, 4)
	UiKit.placeMenu(gui, panel, PANEL_SIZE)

	local title = UiKit.label(panel, Lang.t("gifts.title"))
	title.Position = UDim2.fromOffset(24, 14)
	title.Size = UDim2.new(1, -290, 0, 48)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local status = UiKit.label(panel, "")
	status.Position = UDim2.fromOffset(24, 90)
	status.Size = UDim2.new(1, -48, 0, 28)
	status.TextXAlignment = Enum.TextXAlignment.Left
	local hintColor = Color3.fromRGB(110, 80, 55)
	status.TextColor3 = hintColor

	local closeButton = UiKit.button(panel, "X", UiKit.RED)
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -14, 0, 14)
	closeButton.Size = UDim2.fromOffset(72, 72)

	-- Opens the login calendar (it opens by itself only once a day on join).
	local calendarButton = UiKit.button(panel, Lang.t("gifts.calendar"), UiKit.ORANGE)
	calendarButton.Name = "Calendar"
	calendarButton.AnchorPoint = Vector2.new(1, 0)
	calendarButton.Position = UDim2.new(1, -96, 0, 14)
	calendarButton.Size = UDim2.fromOffset(170, UiKit.MIN_TOUCH)
	calendarButton.Activated:Connect(function()
		panel.Visible = false
		LoginCalendarMenu.open()
	end)

	local rows: { { minutes: TextLabel, rewards: TextLabel, button: TextButton } } = {}
	for index in GameConfig.gifts do
		local row = Instance.new("Frame")
		row.Name = `Gift{index}`
		row.Position = UDim2.fromOffset(16, HEADER_HEIGHT + (index - 1) * (ROW_HEIGHT + ROW_GAP))
		row.Size = UDim2.new(1, -32, 0, ROW_HEIGHT)
		row.BackgroundColor3 = Color3.fromRGB(255, 236, 200)
		UiKit.corner(row, 16)
		UiKit.stroke(row, 2)
		row.Parent = panel

		local minutes = UiKit.label(row, "")
		minutes.Position = UDim2.fromOffset(12, 10)
		minutes.Size = UDim2.fromOffset(90, ROW_HEIGHT - 20)

		local rewards = UiKit.label(row, "")
		rewards.Position = UDim2.fromOffset(110, 12)
		rewards.Size = UDim2.new(1, -290, 0, ROW_HEIGHT - 24)
		rewards.TextXAlignment = Enum.TextXAlignment.Left

		local button = UiKit.button(row, "", UiKit.GREY)
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -6, 0.5, 0)
		button.Size = UDim2.fromOffset(164, UiKit.MIN_TOUCH)
		button.Activated:Connect(function()
			UiKit.pop(button)
			claimGift:FireServer(index)
		end)

		rows[index] = { minutes = minutes, rewards = rewards, button = button }
	end

	gui.Parent = player:WaitForChild("PlayerGui")

	-- Last status from the server, as of `syncedAt` (os.clock()).
	local current = readStatus(player)
	local syncedAt = os.clock()
	local lastReady = current.ready

	local function passed(): number
		return os.clock() - syncedAt
	end

	local function seen(): boolean
		local hints = player:GetAttribute("SeenHints")
		return type(hints) == "string" and table.find(string.split(hints, ","), HINT_ID) ~= nil
	end

	local function updateButton()
		SideBar.setBadge(TILE_ID, current.ready > 0)
		if current.ready > 0 then
			SideBar.setCaption(TILE_ID, Lang.t("side.giftsReady"))
		elseif current.nextSeconds >= 0 then
			SideBar.setCaption(TILE_ID, clockText(current.nextSeconds - passed()))
		else
			SideBar.setCaption(TILE_ID, Lang.t("side.giftsTomorrow"))
		end
	end

	local function updateRows()
		for index, row in rows do
			local gift = current.gifts[index]
			if gift == nil then
				continue
			end
			row.minutes.Text = Lang.t("gifts.minutes", { minutes = gift.minutes })
			row.rewards.Text = UiKit.rewardsText(gift.rewards)
			if gift.status == "Claimed" then
				row.button.Text = "✓"
				row.button.BackgroundColor3 = UiKit.GREY
				row.button.AutoButtonColor = false
			elseif gift.status == "Ready" then
				row.button.Text = Lang.t("gifts.claim")
				row.button.BackgroundColor3 = UiKit.GREEN
				row.button.AutoButtonColor = true
			else
				row.button.Text = clockText(gift.secondsLeft - passed())
				row.button.BackgroundColor3 = UiKit.GREY
				row.button.AutoButtonColor = false
			end
		end
	end

	local defaultStatus = Lang.t("gifts.hint")
	local statusId = 0
	local function showStatus(text: string, color: Color3)
		statusId += 1
		local myId = statusId
		status.Text = text
		status.TextColor3 = color
		task.delay(2.5, function()
			if statusId == myId then
				status.Text = defaultStatus
				status.TextColor3 = hintColor
			end
		end)
	end
	status.Text = defaultStatus

	local function sync()
		current = readStatus(player)
		syncedAt = os.clock()
		if current.ready > lastReady then
			UiKit.pop(openButton)
		end
		lastReady = current.ready
		updateButton()
		updateRows()
	end
	player:GetAttributeChangedSignal("Gifts"):Connect(sync)
	sync()

	-- Pulse while the button is new (until the player opened it once); only after the
	-- tutorial, so it does not distract from it.
	local opened = false
	task.spawn(function()
		while player:GetAttribute("TutorialStep") ~= "" and not opened do
			task.wait(1)
		end
		while not opened and not seen() do
			note.Visible = true
			UiKit.pop(openButton, 0.85)
			task.wait(1.4)
		end
		note.Visible = false
	end)

	local lastShown = -1
	RunService.Heartbeat:Connect(function()
		-- Refresh the countdowns about once a second.
		local now = math.floor(os.clock())
		if now ~= lastShown then
			lastShown = now
			updateButton()
			if panel.Visible then
				updateRows()
			end
		end
	end)

	local function close()
		panel.Visible = false
	end
	UiKit.registerMenu("gifts", close)

	toggle = function()
		UiKit.pop(openButton)
		if panel.Visible then
			close()
			return
		end
		updateRows()
		panel.Visible = true
		UiKit.menuOpened("gifts")
		UiKit.pop(panel)
		if not opened then
			opened = true
			note.Visible = false
			if not seen() then
				hintSeen:FireServer(HINT_ID)
			end
		end
	end
	closeButton.Activated:Connect(close)

	Net.event("GiftResult").OnClientEvent:Connect(function(ok: boolean, indexOrReason: any, rewards: { Reward })
		if ok then
			Sounds.play("Gem")
			showStatus(Lang.t("gifts.claimed", { rewards = UiKit.rewardsText(rewards) }), Color3.fromRGB(40, 150, 60))
		else
			showStatus(MESSAGES[indexOrReason] or Lang.t("common.notNow"), UiKit.RED)
		end
	end)
end

return GiftMenu
