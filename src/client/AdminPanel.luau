--!strict
-- Admin panel on the client (#74, feature "adminPanel"): a test tool only for
-- GameConfig.admin.userIds. Everyone else gets no UI at all (and the server refuses
-- their requests anyway). A small 🛠️ button top right (and F2) opens its own window;
-- it is not one of the game menus, so it stays open next to them.
-- The window is built from AdminActions.list(): one row per action with its
-- parameters (number box, or ◀ value ▶ for choices) and a "Los" button that only sends
-- the wish AdminRun; the server checks and answers AdminResult (shown as status line).
-- New actions are entries in Shared.AdminActions; this file needs no change.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local AdminActions = require(ReplicatedStorage.Shared.AdminActions)
local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Net = require(ReplicatedStorage.Shared.Net)
local Texts = require(ReplicatedStorage.Shared.Texts)
local Lang = require(script.Parent.Lang)
local UiKit = require(script.Parent.UiKit)

local PANEL_SIZE = Vector2.new(640, 660)
local MIN_HEIGHT = 320
local HEADER_HEIGHT = 128
local ROW_HEIGHT = 118
local ROW_GAP = 8
local RUN_WIDTH = 120
local CONFIRM_SECONDS = 3
local ROW_COLOR = Color3.fromRGB(255, 236, 200)
local HINT_COLOR = Color3.fromRGB(110, 80, 55)
local TOGGLE_KEY = Enum.KeyCode.F2

type Param = AdminActions.Param
type ActionInfo = AdminActions.ActionInfo

local AdminPanel = {}

-- Name of a choice value in the player's language (config names, see AdminActions).
local function choiceText(param: Param, value: string): string
	local entry = if param.names == "pet"
		then GameConfig.pets[value]
		elseif param.names == "potion" then GameConfig.potions[value]
		elseif param.names == "upgrade" then GameConfig.upgrades[value]
		else nil
	if entry then
		return Lang.name(entry)
	elseif param.names == "world" then
		return Lang.worldName(value)
	end
	return value
end

-- Failure reason: the normal message if the game has one, else the reason code.
local function reasonText(reason: string?): string
	if reason and Texts.strings[`notify.{reason}`] then
		return Lang.t(`notify.{reason}`)
	end
	return reason or "?"
end

local function textBox(parent: Instance, text: string): TextBox
	local box = Instance.new("TextBox")
	box.BackgroundColor3 = Color3.new(1, 1, 1)
	box.Font = UiKit.FONT
	box.TextScaled = true
	box.TextColor3 = UiKit.DARK
	box.ClearTextOnFocus = false
	box.Text = text
	UiKit.corner(box, 14)
	UiKit.stroke(box, 3)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = box
	box.Parent = parent
	return box
end

-- One control per parameter; returns a function that reads the current value.
local function buildControl(parent: Instance, param: Param, order: number): () -> any
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.LayoutOrder = order
	holder.Parent = parent

	if param.kind == "integer" then
		holder.Size = UDim2.fromOffset(if param.name == "amount" then 220 else 110, UiKit.MIN_TOUCH)
		local box = textBox(holder, tostring(param.default or 0))
		box.Size = UDim2.fromScale(1, 1)
		box.PlaceholderText = Lang.t(`admin.param.{param.name}`)
		return function(): any
			-- "1.000.000" / "1,000,000" are fine too; "1e6" works via tonumber.
			local cleaned = string.gsub(string.gsub(box.Text, "[%.,%s]", ""), "_", "")
			return tonumber(if string.find(box.Text, "[eE]") then box.Text else cleaned)
		end
	end

	local choices = param.choices :: { string }
	local index = math.max(1, table.find(choices, param.default) or 1)
	holder.Size = UDim2.fromOffset(300, UiKit.MIN_TOUCH)
	local previous = UiKit.button(holder, "◀", UiKit.ORANGE)
	previous.Size = UDim2.fromOffset(UiKit.MIN_TOUCH, UiKit.MIN_TOUCH)
	local nextButton = UiKit.button(holder, "▶", UiKit.ORANGE)
	nextButton.AnchorPoint = Vector2.new(1, 0)
	nextButton.Position = UDim2.fromScale(1, 0)
	nextButton.Size = UDim2.fromOffset(UiKit.MIN_TOUCH, UiKit.MIN_TOUCH)
	local valueLabel = UiKit.label(holder, "")
	valueLabel.Position = UDim2.fromOffset(UiKit.MIN_TOUCH + 6, 6)
	valueLabel.Size = UDim2.new(1, -2 * UiKit.MIN_TOUCH - 12, 1, -12)

	local function show()
		valueLabel.Text = choiceText(param, choices[index])
	end
	previous.Activated:Connect(function()
		index = (index - 2) % #choices + 1
		show()
	end)
	nextButton.Activated:Connect(function()
		index = index % #choices + 1
		show()
	end)
	show()
	return function(): any
		return choices[index]
	end
end

function AdminPanel.start()
	local player = Players.LocalPlayer
	local features = Features.new(GameConfig.features)
	if not features.enabled("adminPanel") then
		return
	end
	local admin = AdminActions.new(GameRules.new(GameConfig), GameConfig, features)
	if not admin.isAdmin(player.UserId) then
		return -- not even a hidden UI for anyone else
	end
	local adminRun = Net.event("AdminRun")

	local gui = Instance.new("ScreenGui")
	gui.Name = "AdminPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	UiKit.autoScale(gui)

	-- Dev tool, not part of the HUD grid: small button in the free top-right corner.
	local openButton = UiKit.button(gui, Lang.t("admin.open"), UiKit.DARK)
	openButton.Name = "AdminButton"
	openButton.AnchorPoint = Vector2.new(1, 0)
	openButton.Position = UDim2.new(1, -12, 0, 12)
	openButton.Size = UDim2.fromOffset(UiKit.MIN_TOUCH, UiKit.MIN_TOUCH)

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = UiKit.CREAM
	panel.Visible = false
	UiKit.corner(panel, 24)
	UiKit.stroke(panel, 4)
	UiKit.placeMenu(gui, panel, PANEL_SIZE, MIN_HEIGHT)

	local title = UiKit.label(panel, Lang.t("admin.title"))
	title.Position = UDim2.fromOffset(24, 14)
	title.Size = UDim2.new(1, -120, 0, 48)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local hint = UiKit.label(panel, Lang.t("admin.hint"))
	hint.Position = UDim2.fromOffset(24, 64)
	hint.Size = UDim2.new(1, -120, 0, 24)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextColor3 = HINT_COLOR

	local status = UiKit.label(panel, "")
	status.Name = "Status"
	status.Position = UDim2.fromOffset(24, 92)
	status.Size = UDim2.new(1, -48, 0, 28)
	status.TextXAlignment = Enum.TextXAlignment.Left

	local closeButton = UiKit.button(panel, "X", UiKit.RED)
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -14, 0, 14)
	closeButton.Size = UDim2.fromOffset(72, 72)

	local list = Instance.new("ScrollingFrame")
	list.Name = "Actions"
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
	listPadding.PaddingBottom = UDim.new(0, 4)
	listPadding.Parent = list

	local function actionName(actionId: string): string
		return Lang.t(`admin.action.{actionId}`)
	end

	for order, info: ActionInfo in admin.list() do
		local row = Instance.new("Frame")
		row.Name = info.id
		row.LayoutOrder = order
		row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
		row.BackgroundColor3 = ROW_COLOR
		UiKit.corner(row, 16)
		UiKit.stroke(row, 2)
		row.Parent = list

		local name = UiKit.label(row, actionName(info.id))
		name.Position = UDim2.fromOffset(14, 8)
		name.Size = UDim2.new(1, -RUN_WIDTH - 40, 0, 36)
		name.TextXAlignment = Enum.TextXAlignment.Left

		local controls = Instance.new("Frame")
		controls.BackgroundTransparency = 1
		controls.Position = UDim2.fromOffset(12, 48)
		controls.Size = UDim2.new(1, -RUN_WIDTH - 36, 0, UiKit.MIN_TOUCH)
		controls.Parent = row
		local controlsLayout = Instance.new("UIListLayout")
		controlsLayout.FillDirection = Enum.FillDirection.Horizontal
		controlsLayout.Padding = UDim.new(0, 8)
		controlsLayout.SortOrder = Enum.SortOrder.LayoutOrder
		controlsLayout.Parent = controls

		local readers: { () -> any } = {}
		for index, param in info.params do
			readers[index] = buildControl(controls, param, index)
		end

		local runColor = if info.confirm then UiKit.RED else UiKit.GREEN
		local runButton = UiKit.button(row, Lang.t("admin.run"), runColor)
		runButton.AnchorPoint = Vector2.new(1, 1)
		runButton.Position = UDim2.new(1, -12, 1, -10)
		runButton.Size = UDim2.fromOffset(RUN_WIDTH, UiKit.MIN_TOUCH)

		-- Actions with `confirm` need a second tap within a few seconds.
		local armedAt: number? = nil
		runButton.Activated:Connect(function()
			UiKit.pop(runButton)
			if info.confirm and (armedAt == nil or os.clock() - armedAt > CONFIRM_SECONDS) then
				armedAt = os.clock()
				runButton.Text = Lang.t("admin.confirm")
				task.delay(CONFIRM_SECONDS, function()
					if armedAt and os.clock() - armedAt >= CONFIRM_SECONDS then
						armedAt = nil
						runButton.Text = Lang.t("admin.run")
					end
				end)
				return
			end
			armedAt = nil
			runButton.Text = Lang.t("admin.run")
			local args = {}
			for index, read in readers do
				args[index] = read()
			end
			status.Text = "…"
			status.TextColor3 = UiKit.DARK
			adminRun:FireServer(info.id, args)
		end)
	end

	Net.event("AdminResult").OnClientEvent:Connect(function(actionId: string, ok: boolean, reason: string?)
		if ok then
			status.Text = Lang.t("admin.done", { action = actionName(actionId) })
			status.TextColor3 = Color3.fromRGB(60, 140, 50)
		else
			status.Text = Lang.t("admin.failed", { action = actionName(actionId), reason = reasonText(reason) })
			status.TextColor3 = UiKit.RED
		end
	end)

	local function setOpen(open: boolean)
		panel.Visible = open
		if open then
			UiKit.pop(panel)
		end
	end
	openButton.Activated:Connect(function()
		setOpen(not panel.Visible)
	end)
	closeButton.Activated:Connect(function()
		setOpen(false)
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == TOGGLE_KEY then
			setOpen(not panel.Visible)
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return AdminPanel
