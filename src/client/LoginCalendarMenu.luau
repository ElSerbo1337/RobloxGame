--!strict
-- Login calendar window on the client:
-- * Seven day tiles (reward, ✓ for claimed days, today's tile highlighted) and an
--   "Abholen" button while today's reward is still open.
-- * Opens by itself once per German day on join: when the server sets the attribute
--   LoginCalendarAutoOpen (after the tutorial, so it does not get in its way).
--   LoginCalendarMenu.open() opens it by hand (button in the gifts menu).
-- Reads the attribute LoginCalendar (JSON, see Net / LoginCalendarService).
-- "Abholen" only sends the wish ClaimLoginReward; the server decides and answers
-- LoginRewardResult.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Sounds)
local UiKit = require(script.Parent.UiKit)

local DAY_COUNT = #GameConfig.loginCalendar
local TILE_WIDTH = 100
local TILE_HEIGHT = 190
local TILE_GAP = 8
local TILES_TOP = 104
local CLAIM_TOP = TILES_TOP + TILE_HEIGHT + 16
local PANEL_SIZE = Vector2.new(32 + DAY_COUNT * TILE_WIDTH + (DAY_COUNT - 1) * TILE_GAP, CLAIM_TOP + 64 + 16)

local TILE_WAITING = Color3.fromRGB(255, 236, 200)
local TILE_CLAIMED = Color3.fromRGB(225, 215, 200)
local HINT_COLOR = Color3.fromRGB(110, 80, 55)

local MESSAGES: { [string]: string } = {
	LoginClaimed = "Heute schon abgeholt – morgen gibt es den nächsten Tag!",
}

type Reward = { kind: string, amount: number, potionId: string? }
type Day = { day: number, status: string, rewards: { Reward } }
type Calendar = { today: number, claimable: boolean, days: { Day } }

local LoginCalendarMenu = {}

-- Set by start(); opens the window (no-op before start).
local openWindow: () -> () = function() end

function LoginCalendarMenu.open()
	openWindow()
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
	UiKit.placeMenu(gui, panel, PANEL_SIZE)

	local title = UiKit.label(panel, "Login-Kalender")
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

	local tiles: { { frame: Frame, stroke: UIStroke, rewards: TextLabel, mark: TextLabel } } = {}
	for day = 1, DAY_COUNT do
		local tile = Instance.new("Frame")
		tile.Name = `Day{day}`
		tile.Position = UDim2.fromOffset(16 + (day - 1) * (TILE_WIDTH + TILE_GAP), TILES_TOP)
		tile.Size = UDim2.fromOffset(TILE_WIDTH, TILE_HEIGHT)
		tile.BackgroundColor3 = TILE_WAITING
		UiKit.corner(tile, 16)
		UiKit.stroke(tile, 2)
		tile.Parent = panel

		local dayLabel = UiKit.label(tile, `Tag {day}`)
		dayLabel.Position = UDim2.fromOffset(6, 8)
		dayLabel.Size = UDim2.new(1, -12, 0, 32)

		local rewards = UiKit.label(tile, "")
		rewards.Position = UDim2.fromOffset(6, 46)
		rewards.Size = UDim2.new(1, -12, 0, 92)
		rewards.TextWrapped = true

		local mark = UiKit.label(tile, "")
		mark.Position = UDim2.fromOffset(6, 144)
		mark.Size = UDim2.new(1, -12, 0, 36)

		tiles[day] = {
			frame = tile,
			stroke = tile:FindFirstChildOfClass("UIStroke") :: UIStroke,
			rewards = rewards,
			mark = mark,
		}
	end

	local claimButton = UiKit.button(panel, "Abholen", UiKit.GREEN)
	claimButton.Name = "Claim"
	claimButton.AnchorPoint = Vector2.new(0.5, 0)
	claimButton.Position = UDim2.new(0.5, 0, 0, CLAIM_TOP)
	claimButton.Size = UDim2.fromOffset(300, 64)

	gui.Parent = player:WaitForChild("PlayerGui")

	local current = readCalendar(player)

	local function defaultStatus(): string
		return if current.claimable
			then `Tag {current.today}: hol dir deine Belohnung!`
			else "Komm morgen wieder – jeden Tag in Folge wird es besser!"
	end

	local function update()
		for day, tile in tiles do
			local entry = current.days[day]
			if entry == nil then
				continue
			end
			tile.rewards.Text = UiKit.rewardsText(entry.rewards)
			if entry.status == "Claimed" then
				tile.frame.BackgroundColor3 = TILE_CLAIMED
				tile.mark.Text = "✓"
				tile.mark.TextColor3 = Color3.fromRGB(40, 150, 60)
			elseif entry.status == "Ready" then
				tile.frame.BackgroundColor3 = UiKit.COIN
				tile.mark.Text = "Heute"
				tile.mark.TextColor3 = UiKit.DARK
			else
				tile.frame.BackgroundColor3 = TILE_WAITING
				tile.mark.Text = ""
			end
			tile.stroke.Thickness = if day == current.today then 4 else 2
		end
		claimButton.Text = if current.claimable then "Abholen" else "Morgen wieder"
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
		if statusId == 0 or status.TextColor3 == HINT_COLOR then
			status.Text = defaultStatus()
		end
	end
	player:GetAttributeChangedSignal("LoginCalendar"):Connect(sync)
	sync()

	local function close()
		panel.Visible = false
	end
	UiKit.registerMenu("calendar", close)

	openWindow = function()
		sync()
		panel.Visible = true
		UiKit.menuOpened("calendar")
		UiKit.pop(panel)
	end

	closeButton.Activated:Connect(close)
	claimButton.Activated:Connect(function()
		UiKit.pop(claimButton)
		if current.claimable then
			claimEvent:FireServer()
		end
	end)

	Net.event("LoginRewardResult").OnClientEvent:Connect(function(ok: boolean, dayOrReason: any, rewards: { Reward })
		if ok then
			Sounds.play("Gem")
			showStatus(`Tag {dayOrReason}! +{UiKit.rewardsText(rewards)}`, Color3.fromRGB(40, 150, 60))
		else
			showStatus(MESSAGES[dayOrReason] or "Geht gerade nicht.", UiKit.RED)
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
			while player:GetAttribute("TutorialStep") ~= "" do
				task.wait(1)
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
