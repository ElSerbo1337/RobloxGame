--!strict
-- Login calendar window on the client (30 days, #101; 7 days while
-- features.loginCalendar30 is off):
-- * Day tiles in week rows of 7 (5 rows for 30 days) in a scrolling list that jumps to
--   today's row: reward, ✓ for claimed days, today's tile highlighted. Big reward days
--   (7, 14, 30) are gold with a ⭐; day 30 shows the calendar pet as a live 3D icon
--   (PetIcon, its name as text without the Studio import). "Abholen" while today's
--   reward is still open.
-- * Opens by itself once per German day on join: when the server sets the attribute
--   LoginCalendarAutoOpen (after the tutorial, so it does not get in its way).
--   LoginCalendarMenu.open() opens it by hand (button in the gifts menu); the side bar
--   tile "Kalender" (#75) opens it too and shows a red dot while today's reward is ready.
-- Reads the attribute LoginCalendar (JSON, see Net / LoginCalendarService).
-- "Abholen" only sends the wish ClaimLoginReward; the server decides and answers
-- LoginRewardResult.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Sounds)
local Lang = require(script.Parent.Lang)
local PetIcon = require(script.Parent.PetIcon)
local SideBar = require(script.Parent.SideBar)
local UiKit = require(script.Parent.UiKit)

local features = Features.new(GameConfig.features)
local CALENDAR = if features.enabled("loginCalendar30") and GameConfig.loginCalendar30
	then GameConfig.loginCalendar30
	else GameConfig.loginCalendar
local DAY_COUNT = #CALENDAR
local PER_ROW = 7
local ROW_COUNT = math.ceil(DAY_COUNT / PER_ROW)
local TILE_WIDTH = 88
local TILE_HEIGHT = 120
local TILE_GAP = 8
local ROWS_TOP = 100
local LIST_PADDING = 6
local CLAIM_HEIGHT = 64
local FOOTER = CLAIM_HEIGHT + 28
local ROW_HEIGHT = TILE_HEIGHT + TILE_GAP
local LIST_WIDTH = PER_ROW * TILE_WIDTH + (PER_ROW - 1) * TILE_GAP + 2 * LIST_PADDING
local PANEL_SIZE = Vector2.new(LIST_WIDTH + 32 + 10, ROWS_TOP + ROW_COUNT * ROW_HEIGHT + LIST_PADDING + FOOTER)
-- Small screens: header, one full week row and the button.
local MIN_HEIGHT = ROWS_TOP + ROW_HEIGHT + LIST_PADDING * 2 + FOOTER

local TILE_WAITING = Color3.fromRGB(255, 236, 200)
local TILE_BIG = Color3.fromRGB(255, 214, 120)
local TILE_CLAIMED = Color3.fromRGB(225, 215, 200)
local HINT_COLOR = Color3.fromRGB(110, 80, 55)

local MESSAGES: { [string]: string } = {
	LoginClaimed = Lang.t("calendar.LoginClaimed"),
}

type Reward = { kind: string, amount: number, potionId: string?, petId: string? }
type Day = { day: number, status: string, big: boolean?, rewards: { Reward } }
type Tile = {
	frame: Frame,
	stroke: UIStroke,
	rewards: TextLabel,
	mark: TextLabel,
	-- The pet is shown as a 3D icon, so its reward text leaves it out.
	petShown: boolean,
}
type Calendar = { today: number, claimable: boolean, days: { Day } }

local LoginCalendarMenu = {}

-- Set by start(); opens the window (no-op before start).
local openWindow: () -> () = function() end

function LoginCalendarMenu.open()
	openWindow()
end

-- Set by start(); true while the window is shown (the "What's new" window waits, #106).
local isOpen: () -> boolean = function()
	return false
end

function LoginCalendarMenu.isOpen(): boolean
	return isOpen()
end

local function readCalendar(player: Player): Calendar
	local json = player:GetAttribute("LoginCalendar")
	local empty: Calendar = { today = 1, claimable = false, days = {} }
	if type(json) ~= "string" then
		return empty
	end
	local ok, value = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok or type(value) ~= "table" or type(value.days) ~= "table" then
		return empty
	end
	return value :: Calendar
end

function LoginCalendarMenu.start()
	local player = Players.LocalPlayer
	local claimEvent = Net.event("ClaimLoginReward")

	local gui = Instance.new("ScreenGui")
	gui.Name = "LoginCalendarMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	UiKit.autoScale(gui)

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = UiKit.CREAM
	panel.Visible = false
	UiKit.corner(panel, 24)
	UiKit.stroke(panel, 4)
	UiKit.placeMenu(gui, panel, PANEL_SIZE, MIN_HEIGHT)

	local title = UiKit.label(panel, Lang.t("calendar.title"))
	title.Position = UDim2.fromOffset(24, 14)
	title.Size = UDim2.new(1, -120, 0, 48)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local status = UiKit.label(panel, "")
	status.Position = UDim2.fromOffset(24, 64)
	status.Size = UDim2.new(1, -48, 0, 28)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextColor3 = HINT_COLOR

	local closeButton = UiKit.button(panel, "X", UiKit.RED)
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -14, 0, 14)
	closeButton.Size = UDim2.fromOffset(72, 72)

	-- Week rows in a scrolling list (fits on phones: at least one full row is visible).
	local list = Instance.new("ScrollingFrame")
	list.Name = "Days"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(16, ROWS_TOP)
	list.Size = UDim2.new(1, -32, 1, -ROWS_TOP - FOOTER)
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = UiKit.DARK
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.CanvasSize = UDim2.fromOffset(0, ROW_COUNT * ROW_HEIGHT - TILE_GAP + 2 * LIST_PADDING)
	list.Parent = panel

	local tiles: { Tile } = {}
	for day = 1, DAY_COUNT do
		local entry = CALENDAR[day]
		local big = entry.big == true
		local row, column = (day - 1) // PER_ROW, (day - 1) % PER_ROW
		local tile = Instance.new("Frame")
		tile.Name = `Day{day}`
		tile.Position =
			UDim2.fromOffset(LIST_PADDING + column * (TILE_WIDTH + TILE_GAP), LIST_PADDING + row * ROW_HEIGHT)
		tile.Size = UDim2.fromOffset(TILE_WIDTH, TILE_HEIGHT)
		tile.BackgroundColor3 = if big then TILE_BIG else TILE_WAITING
		UiKit.corner(tile, 14)
		local stroke = UiKit.stroke(tile, 2)
		tile.Parent = list

		local dayLabel = UiKit.label(tile, Lang.t(if big then "calendar.dayBig" else "calendar.day", { day = day }))
		dayLabel.Position = UDim2.fromOffset(4, 4)
		dayLabel.Size = UDim2.new(1, -8, 0, 24)

		-- The pet of a pet day as a live 3D icon; its name stays as text without a model.
		local petId: string? = nil
		for _, reward in entry.rewards do
			if reward.kind == "Pet" then
				petId = reward.petId
			end
		end
		local rewardsTop, rewardsHeight, petShown = 30, 60, false
		if petId then
			local holder = Instance.new("Frame")
			holder.Name = "Pet"
			holder.BackgroundTransparency = 1
			holder.AnchorPoint = Vector2.new(0.5, 0)
			holder.Position = UDim2.new(0.5, 0, 0, 26)
			holder.Size = UDim2.fromOffset(46, 46)
			holder.Parent = tile
			if PetIcon.show(holder, petId, 1.3) then
				rewardsTop, rewardsHeight, petShown = 72, 20, true
			end
		end

		local rewards = UiKit.label(tile, "")
		rewards.Position = UDim2.fromOffset(4, rewardsTop)
		rewards.Size = UDim2.new(1, -8, 0, rewardsHeight)
		rewards.TextWrapped = true

		local mark = UiKit.label(tile, "")
		mark.Position = UDim2.fromOffset(4, 92)
		mark.Size = UDim2.new(1, -8, 0, 24)

		tiles[day] = { frame = tile, stroke = stroke, rewards = rewards, mark = mark, petShown = petShown }
	end

	local claimButton = UiKit.button(panel, Lang.t("calendar.claim"), UiKit.GREEN)
	claimButton.Name = "Claim"
	claimButton.AnchorPoint = Vector2.new(0.5, 1)
	claimButton.Position = UDim2.new(0.5, 0, 1, -14)
	claimButton.Size = UDim2.fromOffset(300, CLAIM_HEIGHT)

	gui.Parent = player:WaitForChild("PlayerGui")

	local current = readCalendar(player)

	-- The last day with a pet reward (day 30) and its pet, for the countdown hint.
	local petDay, petName = nil :: number?, ""
	for day, entry in CALENDAR do
		for _, reward in entry.rewards do
			local pet = reward.kind == "Pet" and reward.petId and GameConfig.pets[reward.petId]
			if pet then
				petDay, petName = day, Lang.name(pet)
			end
		end
	end

	local function defaultStatus(): string
		if current.claimable then
			return Lang.t("calendar.ready", { day = current.today })
		end
		local daysLeft = if petDay then petDay - current.today else 0
		if daysLeft > 0 then
			return Lang.t(
				if daysLeft == 1 then "calendar.petTomorrow" else "calendar.petIn",
				{ days = daysLeft, pet = petName }
			)
		end
		return Lang.t("calendar.comeBack")
	end

	-- Scrolls so today's week row is visible (its row at the top, the last row at the end).
	local function scrollToToday()
		local row = (math.clamp(current.today, 1, DAY_COUNT) - 1) // PER_ROW
		list.CanvasPosition = Vector2.new(0, row * ROW_HEIGHT)
	end

	local function update()
		for day, tile in tiles do
			local entry = current.days[day]
			if entry == nil then
				continue
			end
			local shown = {}
			for _, reward in entry.rewards do
				if not (tile.petShown and reward.kind == "Pet") then
					table.insert(shown, reward)
				end
			end
			tile.rewards.Text = UiKit.rewardsText(shown)
			if entry.status == "Claimed" then
				tile.frame.BackgroundColor3 = TILE_CLAIMED
				tile.mark.Text = "✓"
				tile.mark.TextColor3 = Color3.fromRGB(40, 150, 60)
			elseif entry.status == "Ready" then
				tile.frame.BackgroundColor3 = UiKit.COIN
				tile.mark.Text = Lang.t("calendar.today")
				tile.mark.TextColor3 = UiKit.DARK
			else
				tile.frame.BackgroundColor3 = if entry.big then TILE_BIG else TILE_WAITING
				tile.mark.Text = ""
			end
			tile.stroke.Thickness = if day == current.today then 4 elseif entry.big then 3 else 2
			tile.stroke.Color = if entry.big and entry.status ~= "Claimed" then UiKit.ORANGE else UiKit.DARK
		end
		claimButton.Text = if current.claimable then Lang.t("calendar.claim") else Lang.t("calendar.tomorrow")
		claimButton.BackgroundColor3 = if current.claimable then UiKit.GREEN else UiKit.GREY
		claimButton.AutoButtonColor = current.claimable
	end

	local statusId = 0
	local function showStatus(text: string, color: Color3)
		statusId += 1
		local myId = statusId
		status.Text = text
		status.TextColor3 = color
		task.delay(2.5, function()
			if statusId == myId then
				status.Text = defaultStatus()
				status.TextColor3 = HINT_COLOR
			end
		end)
	end

	local function sync()
		current = readCalendar(player)
		update()
		SideBar.setBadge("calendar", current.claimable)
		if statusId == 0 or status.TextColor3 == HINT_COLOR then
			status.Text = defaultStatus()
		end
	end
	player:GetAttributeChangedSignal("LoginCalendar"):Connect(sync)

	local function close()
		panel.Visible = false
	end
	UiKit.registerMenu("calendar", close)
	isOpen = function()
		return panel.Visible
	end

	openWindow = function()
		sync()
		scrollToToday()
		panel.Visible = true
		UiKit.menuOpened("calendar")
		UiKit.pop(panel)
	end

	-- Side bar tile (#75): red dot while today's reward is ready.
	SideBar.register({
		id = "calendar",
		order = 40,
		text = Lang.t("side.calendar"),
		color = Color3.fromRGB(70, 170, 230),
		icon = { shape = "calendar" },
		open = function()
			if panel.Visible then
				close()
			else
				openWindow()
			end
		end,
	})
	sync()

	closeButton.Activated:Connect(close)
	claimButton.Activated:Connect(function()
		UiKit.pop(claimButton)
		if current.claimable then
			claimEvent:FireServer()
		end
	end)

	Net.event("LoginRewardResult").OnClientEvent:Connect(function(ok: boolean, dayOrReason: any, rewards: { Reward })
		if ok then
			-- Big days (7, 14, 30) get the fanfare and a bounce of their tile.
			local entry = CALENDAR[dayOrReason]
			Sounds.play(if entry and entry.big then "Rebirth" else "Gem")
			local tile = tiles[dayOrReason]
			if tile then
				UiKit.pop(tile.frame, if entry and entry.big then 1.3 else 1.15)
			end
			showStatus(
				Lang.t("calendar.claimed", { day = dayOrReason, rewards = UiKit.rewardsText(rewards) }),
				Color3.fromRGB(40, 150, 60)
			)
		else
			showStatus(MESSAGES[dayOrReason] or Lang.t("common.notNow"), UiKit.RED)
		end
	end)

	-- Opens by itself once per value of LoginCalendarAutoOpen (first join of a German day),
	-- but only once the tutorial is done.
	local handledAutoOpen: any = nil
	local waiting = false
	local function checkAutoOpen()
		local value = player:GetAttribute("LoginCalendarAutoOpen")
		if value == nil or value == handledAutoOpen or waiting then
			return
		end
		waiting = true
		task.spawn(function()
			local hadTutorial = false
			while player:GetAttribute("TutorialStep") ~= "" do
				hadTutorial = true
				task.wait(1)
			end
			if hadTutorial then
				-- Let the first pet card and "Tutorial complete!" (4 s) be seen first.
				task.wait(5)
			end
			waiting = false
			handledAutoOpen = player:GetAttribute("LoginCalendarAutoOpen")
			openWindow()
		end)
	end
	player:GetAttributeChangedSignal("LoginCalendarAutoOpen"):Connect(checkAutoOpen)
	checkAutoOpen()
end

return LoginCalendarMenu
