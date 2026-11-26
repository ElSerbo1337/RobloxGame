--!strict
-- Daily and weekly quests on the client (#97):
-- * Side bar tile "Quests" (order 70) with a red dot while a quest or the bonus chest is
--   ready to claim; its caption shows how many daily quests are done ("2/3").
-- * The menu (scrolls): daily quests (text, progress bar, reward, button "Abholen" /
--   🎲 reroll (free once a day, then gems) / ✓), the bonus chest, the 7-day streak and
--   the weekly quests, each with the time until new ones come.
-- * A quest that just got done: sound, tile bounce and a short note in the menu.
-- Reads the Quests attribute (JSON GameRules.QuestStatus, see QuestService); buttons only
-- send the wishes ClaimQuest / RerollQuest / ClaimQuestBonus, the server answers QuestResult.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Lang = require(script.Parent.Lang)
local Net = require(ReplicatedStorage.Shared.Net)
local FeatureHints = require(script.Parent.FeatureHints)
local SideBar = require(script.Parent.SideBar)
local Sounds = require(script.Parent.Sounds)
local UiKit = require(script.Parent.UiKit)

local TILE_ID = "quests"
local TILE_COLOR = Color3.fromRGB(150, 110, 230)
local HEADER_HEIGHT = 96
local ROW_HEIGHT = 84
local SECTION_HEIGHT = 40
local ROW_GAP = 8
local ROW_COLOR = Color3.fromRGB(255, 236, 200)
local DONE_COLOR = Color3.fromRGB(210, 240, 200)
local BAR_COLOR = Color3.fromRGB(110, 200, 90)
local HINT_COLOR = Color3.fromRGB(110, 80, 55)
local MAX_ROWS = 5
local PANEL_SIZE = Vector2.new(640, 780)
local MIN_HEIGHT = HEADER_HEIGHT + SECTION_HEIGHT + ROW_HEIGHT + 24

type Reward = { kind: string, amount: number, potionId: string? }
type Entry = { index: number, kind: string, goal: number, progress: number, reward: Reward, status: string }
type Status = {
	daily: { Entry },
	weekly: { Entry },
	rerollPrice: number,
	bonus: { status: string, rewards: { Reward } },
	streak: { days: number, goal: number, rewards: { Reward } },
	readyCount: number,
	dailySecondsLeft: number,
	weeklySecondsLeft: number,
}

type Row = {
	frame: Frame,
	text: TextLabel,
	reward: TextLabel,
	fill: Frame,
	count: TextLabel,
	button: TextButton,
}

local QuestMenu = {}

local function readStatus(player: Player): Status?
	local json = player:GetAttribute("Quests")
	if type(json) ~= "string" then
		return nil
	end
	local ok, value = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok or type(value) ~= "table" or type(value.daily) ~= "table" then
		return nil
	end
	return value :: Status
end

-- "5 h 12 min", "3 T 4 h" / "3 d 4 h", "12 min".
local function timeText(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local days, hours, minutes = total // 86400, (total % 86400) // 3600, (total % 3600) // 60
	if days > 0 then
		return Lang.t("quests.timeDays", { days = days, hours = hours })
	elseif hours > 0 then
		return Lang.t("quests.timeHours", { hours = hours, minutes = minutes })
	end
	return Lang.t("quests.timeMinutes", { minutes = math.max(1, minutes) })
end

local function questText(entry: Entry): string
	return Lang.t(`quests.kind.{entry.kind}`, { goal = Lang.shortNumber(entry.goal) })
end

local MESSAGE_KEYS = {
	QuestNotDone = true,
	QuestClaimed = true,
	QuestsExpired = true,
	QuestDone = true,
	BonusNotReady = true,
	BonusClaimed = true,
	NoOtherQuest = true,
	NotEnoughGems = true,
}

function QuestMenu.start()
	local features = Features.new(GameConfig.features)
	if GameConfig.quests == nil or not features.enabled("dailyQuests") then
		return
	end
	local weeklyOn = features.enabled("weeklyQuests")
	local player = Players.LocalPlayer
	local claimQuest = Net.event("ClaimQuest")
	local rerollQuest = Net.event("RerollQuest")
	local claimBonus = Net.event("ClaimQuestBonus")

	local gui = Instance.new("ScreenGui")
	gui.Name = "QuestMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	UiKit.autoScale(gui)

	local toggle: () -> () = function() end
	local tileButton = SideBar.register({
		id = TILE_ID,
		order = 70,
		text = Lang.t("side.quests"),
		color = TILE_COLOR,
		icon = { shape = "quest" },
		open = function()
			toggle()
		end,
	})
	FeatureHints.attach("Quests", TILE_ID, "hint.quests", 30)

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = UiKit.CREAM
	panel.Visible = false
	UiKit.corner(panel, 24)
	UiKit.stroke(panel, 4)
	UiKit.placeMenu(gui, panel, PANEL_SIZE, MIN_HEIGHT)

	local title = UiKit.label(panel, Lang.t("quests.title"))
	title.Position = UDim2.fromOffset(24, 12)
	title.Size = UDim2.new(1, -120, 0, 48)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local statusLabel = UiKit.label(panel, "")
	statusLabel.Position = UDim2.fromOffset(24, 62)
	statusLabel.Size = UDim2.new(1, -120, 0, 26)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextColor3 = HINT_COLOR

	local closeButton = UiKit.button(panel, "X", UiKit.RED)
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -14, 0, 14)
	closeButton.Size = UDim2.fromOffset(72, 72)

	local list = Instance.new("ScrollingFrame")
	list.Name = "Rows"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(12, HEADER_HEIGHT)
	list.Size = UDim2.new(1, -24, 1, -HEADER_HEIGHT - 12)
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = UiKit.DARK
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, ROW_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0, 4)
	listPadding.PaddingLeft = UDim.new(0, 4)
	listPadding.PaddingRight = UDim.new(0, 14)
	listPadding.PaddingBottom = UDim.new(0, 8)
	listPadding.Parent = list

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local function heading(): TextLabel
		local label = UiKit.label(list, "")
		label.LayoutOrder = nextOrder()
		label.Size = UDim2.new(1, 0, 0, SECTION_HEIGHT)
		label.TextXAlignment = Enum.TextXAlignment.Left
		return label
	end

	local function rowFrame(height: number): Frame
		local frame = Instance.new("Frame")
		frame.LayoutOrder = nextOrder()
		frame.Size = UDim2.new(1, 0, 0, height)
		frame.BackgroundColor3 = ROW_COLOR
		UiKit.corner(frame, 16)
		UiKit.stroke(frame, 2)
		frame.Parent = list
		return frame
	end

	-- A quest row: text and reward on the left, progress bar below, button on the right.
	local function questRow(onPress: () -> ()): Row
		local frame = rowFrame(ROW_HEIGHT)
		local text = UiKit.label(frame, "")
		text.Position = UDim2.fromOffset(12, 6)
		text.Size = UDim2.new(1, -200, 0, 30)
		text.TextXAlignment = Enum.TextXAlignment.Left

		local reward = UiKit.label(frame, "")
		reward.Position = UDim2.fromOffset(12, 36)
		reward.Size = UDim2.new(0.45, -12, 0, 20)
		reward.TextXAlignment = Enum.TextXAlignment.Left
		reward.TextColor3 = Color3.fromRGB(160, 110, 0)

		local bar = Instance.new("Frame")
		bar.Position = UDim2.fromOffset(12, 60)
		bar.Size = UDim2.new(1, -200, 0, 16)
		bar.BackgroundColor3 = UiKit.GREY
		UiKit.corner(bar, 8)
		UiKit.stroke(bar, 2)
		bar.Parent = frame
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = BAR_COLOR
		UiKit.corner(fill, 8)
		fill.Parent = bar

		local count = UiKit.label(frame, "")
		count.AnchorPoint = Vector2.new(1, 0)
		count.Position = UDim2.new(1, -188, 0, 36)
		count.Size = UDim2.new(0.4, 0, 0, 20)
		count.TextXAlignment = Enum.TextXAlignment.Right

		local button = UiKit.button(frame, "", UiKit.GREY)
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -8, 0.5, 0)
		button.Size = UDim2.fromOffset(168, UiKit.MIN_TOUCH)
		button.Activated:Connect(function()
			UiKit.pop(button)
			onPress()
		end)
		return { frame = frame, text = text, reward = reward, fill = fill, count = count, button = button }
	end

	local current: Status? = readStatus(player)
	local syncedAt = os.clock()

	local dailyHeading = heading()
	local dailyRows: { Row } = {}
	for index = 1, MAX_ROWS do
		dailyRows[index] = questRow(function()
			local entry = current and current.daily[index]
			if entry == nil then
				return
			end
			if entry.status == "Ready" then
				claimQuest:FireServer("Daily", index)
			elseif entry.status == "Running" then
				rerollQuest:FireServer(index)
			end
		end)
	end

	-- Bonus chest and streak.
	local bonusFrame = rowFrame(ROW_HEIGHT)
	local bonusText = UiKit.label(bonusFrame, "")
	bonusText.Position = UDim2.fromOffset(12, 8)
	bonusText.Size = UDim2.new(1, -200, 0, 34)
	bonusText.TextXAlignment = Enum.TextXAlignment.Left
	local streakText = UiKit.label(bonusFrame, "")
	streakText.Position = UDim2.fromOffset(12, 46)
	streakText.Size = UDim2.new(1, -200, 0, 28)
	streakText.TextXAlignment = Enum.TextXAlignment.Left
	streakText.TextColor3 = Color3.fromRGB(200, 90, 30)
	local bonusButton = UiKit.button(bonusFrame, "", UiKit.GREY)
	bonusButton.AnchorPoint = Vector2.new(1, 0.5)
	bonusButton.Position = UDim2.new(1, -8, 0.5, 0)
	bonusButton.Size = UDim2.fromOffset(168, UiKit.MIN_TOUCH)
	bonusButton.Activated:Connect(function()
		UiKit.pop(bonusButton)
		claimBonus:FireServer()
	end)

	local weeklyHeading = heading()
	weeklyHeading.Visible = weeklyOn
	local weeklyRows: { Row } = {}
	for index = 1, MAX_ROWS do
		weeklyRows[index] = questRow(function()
			local entry = current and current.weekly[index]
			if entry and entry.status == "Ready" then
				claimQuest:FireServer("Weekly", index)
			end
		end)
	end

	gui.Parent = player:WaitForChild("PlayerGui")

	local function passed(): number
		return os.clock() - syncedAt
	end

	local function showRow(row: Row, entry: Entry?, rerollPrice: number?)
		row.frame.Visible = entry ~= nil
		if entry == nil then
			return
		end
		row.text.Text = questText(entry)
		row.reward.Text = "🎁 " .. UiKit.rewardText(entry.reward)
		local shown = math.min(entry.goal, math.floor(entry.progress))
		row.count.Text = `{Lang.shortNumber(shown)}/{Lang.shortNumber(entry.goal)}`
		row.fill.Size = UDim2.fromScale(math.clamp(entry.progress / math.max(1, entry.goal), 0, 1), 1)
		row.frame.BackgroundColor3 = if entry.status == "Running" then ROW_COLOR else DONE_COLOR
		row.button.AutoButtonColor = entry.status ~= "Claimed"
		if entry.status == "Claimed" then
			row.button.Text = "✓"
			row.button.BackgroundColor3 = UiKit.GREY
			row.button.AutoButtonColor = false
		elseif entry.status == "Ready" then
			row.button.Text = Lang.t("quests.claim")
			row.button.BackgroundColor3 = UiKit.GREEN
		elseif rerollPrice ~= nil then
			row.button.Text = if rerollPrice <= 0
				then Lang.t("quests.rerollFree")
				else Lang.t("quests.reroll", { gems = rerollPrice })
			row.button.BackgroundColor3 = UiKit.ORANGE
		else
			row.button.Text = "…"
			row.button.BackgroundColor3 = UiKit.GREY
			row.button.AutoButtonColor = false
		end
	end

	local function updateTimers()
		local status = current
		if status == nil then
			return
		end
		dailyHeading.Text = Lang.t("quests.daily", { time = timeText(status.dailySecondsLeft - passed()) })
		weeklyHeading.Text = Lang.t("quests.weekly", { time = timeText(status.weeklySecondsLeft - passed()) })
	end

	local function updateAll()
		local status = current
		if status == nil then
			for _, row in dailyRows do
				row.frame.Visible = false
			end
			for _, row in weeklyRows do
				row.frame.Visible = false
			end
			bonusFrame.Visible = false
			return
		end
		for index, row in dailyRows do
			showRow(row, status.daily[index], status.rerollPrice)
		end
		for index, row in weeklyRows do
			showRow(row, if weeklyOn then status.weekly[index] else nil, nil)
		end
		bonusFrame.Visible = #status.daily > 0
		bonusText.Text = Lang.t("quests.bonus", { rewards = UiKit.rewardsText(status.bonus.rewards) })
		streakText.Text = Lang.t("quests.streak", {
			days = status.streak.days,
			goal = status.streak.goal,
			rewards = UiKit.rewardsText(status.streak.rewards),
		})
		if status.bonus.status == "Claimed" then
			bonusButton.Text = "✓"
			bonusButton.BackgroundColor3 = UiKit.GREY
			bonusButton.AutoButtonColor = false
		elseif status.bonus.status == "Ready" then
			bonusButton.Text = Lang.t("quests.open")
			bonusButton.BackgroundColor3 = UiKit.GREEN
			bonusButton.AutoButtonColor = true
		else
			bonusButton.Text = "🔒"
			bonusButton.BackgroundColor3 = UiKit.GREY
			bonusButton.AutoButtonColor = false
		end
		updateTimers()
	end

	local defaultStatus = Lang.t("quests.hint")
	local statusId = 0
	local function showStatus(text: string, color: Color3)
		statusId += 1
		local myId = statusId
		statusLabel.Text = text
		statusLabel.TextColor3 = color
		task.delay(2.5, function()
			if statusId == myId then
				statusLabel.Text = defaultStatus
				statusLabel.TextColor3 = HINT_COLOR
			end
		end)
	end
	statusLabel.Text = defaultStatus

	-- Keys of quests that were done at the last sync, to notice newly finished ones.
	local function doneKeys(status: Status?): { [string]: boolean }
		local keys = {}
		if status then
			for period, entries in { Daily = status.daily, Weekly = status.weekly } do
				for _, entry in entries do
					if entry.status ~= "Running" then
						keys[`{period}:{entry.index}:{entry.kind}:{entry.goal}`] = true
					end
				end
			end
		end
		return keys
	end
	local lastDone = doneKeys(current)

	local function sync()
		current = readStatus(player)
		syncedAt = os.clock()
		local status = current
		local done = doneKeys(status)
		local newlyDone = false
		for key in done do
			if not lastDone[key] then
				newlyDone = true
			end
		end
		lastDone = done
		if newlyDone then
			Sounds.play("QuestDone")
			UiKit.pop(tileButton)
			showStatus(Lang.t("quests.done"), Color3.fromRGB(40, 150, 60))
		end
		SideBar.setBadge(TILE_ID, status ~= nil and status.readyCount > 0)
		FeatureHints.setActive("Quests", status ~= nil)
		if status and #status.daily > 0 then
			local finished = 0
			for _, entry in status.daily do
				if entry.status ~= "Running" then
					finished += 1
				end
			end
			SideBar.setCaption(TILE_ID, `{finished}/{#status.daily}`)
		else
			SideBar.setCaption(TILE_ID, nil)
		end
		updateAll()
	end
	player:GetAttributeChangedSignal("Quests"):Connect(sync)
	sync()

	local lastShown = -1
	RunService.Heartbeat:Connect(function()
		local now = math.floor(os.clock())
		if now ~= lastShown and panel.Visible then
			lastShown = now
			updateTimers()
		end
	end)

	local function close()
		panel.Visible = false
	end
	UiKit.registerMenu(TILE_ID, close)
	toggle = function()
		UiKit.pop(tileButton)
		if panel.Visible then
			close()
			return
		end
		updateAll()
		panel.Visible = true
		UiKit.menuOpened(TILE_ID)
		UiKit.pop(panel)
	end
	closeButton.Activated:Connect(close)

	Net.event("QuestResult").OnClientEvent
		:Connect(function(ok: boolean, action: string, reasonOrRewards: any, streakChest: boolean?)
			if not ok then
				local key = if MESSAGE_KEYS[reasonOrRewards] then `quests.{reasonOrRewards}` else "common.notNow"
				showStatus(Lang.t(key), UiKit.RED)
				return
			end
			if action == "Reroll" then
				showStatus(Lang.t("quests.rerolled"), Color3.fromRGB(40, 150, 60))
				return
			end
			Sounds.play("Gem")
			local text = UiKit.rewardsText(reasonOrRewards :: { Reward })
			local key = if streakChest then "quests.streakClaimed" else "quests.claimed"
			showStatus(Lang.t(key, { rewards = text }), Color3.fromRGB(40, 150, 60))
		end)
end

return QuestMenu
