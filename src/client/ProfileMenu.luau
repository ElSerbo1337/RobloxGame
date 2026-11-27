--!strict
-- Profile menu (#103, features.profile): side bar tile "Profil" (order 100) and one menu
-- with up to three tabs (only the switched-on features): statistics (features.stats),
-- badges (features.badges, reached ones bright, the others with their progress) and
-- titles (features.titles; for the own profile with "Choose" buttons -> wish
-- SetTitle(titleId), "" = automatic). Data comes from the Profile attribute (JSON, see
-- ProfileService), which every player has, so tapping/clicking another player's
-- character opens their profile read only.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Lang = require(script.Parent.Lang)
local SideBar = require(script.Parent.SideBar)
local UiKit = require(script.Parent.UiKit)

local TILE_ID = "profile"
local TILE_COLOR = Color3.fromRGB(150, 110, 230)
local PANEL_SIZE = Vector2.new(680, 760)
local HEADER_HEIGHT = 230
local MIN_HEIGHT = HEADER_HEIGHT + 170
local ROW_COLOR = Color3.fromRGB(255, 236, 200)
local DONE_COLOR = Color3.fromRGB(210, 240, 200)
local LOCKED_COLOR = Color3.fromRGB(225, 215, 205)
local HINT_COLOR = Color3.fromRGB(110, 80, 55)
local TAP_DISTANCE = 120

type Profile = {
	stats: { [string]: number }?,
	badges: { string },
	titles: { string },
	title: string,
	selected: string,
}

local ProfileMenu = {}

local function readProfile(player: Player): Profile?
	local json = player:GetAttribute("Profile")
	if type(json) ~= "string" then
		return nil
	end
	local ok, value = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok or type(value) ~= "table" then
		return nil
	end
	return value :: Profile
end

local function playtimeText(seconds: number): string
	local minutes = math.floor(seconds / 60)
	return Lang.t("profile.playtime", { hours = Lang.integer(math.floor(minutes / 60)), minutes = minutes % 60 })
end

function ProfileMenu.start()
	local features = Features.new(GameConfig.features)
	if not features.enabled("profile") then
		return
	end
	local tabOrder: { string } = {}
	for _, id in { "stats", "badges", "titles" } do
		if features.enabled(id) then
			table.insert(tabOrder, id)
		end
	end
	if #tabOrder == 0 then
		return
	end
	local localPlayer = Players.LocalPlayer
	local setTitle = Net.event("SetTitle")

	local gui = Instance.new("ScreenGui")
	gui.Name = "ProfileMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	UiKit.autoScale(gui)

	local toggle: () -> () = function() end
	SideBar.register({
		id = TILE_ID,
		order = 100,
		text = Lang.t("side.profile"),
		color = TILE_COLOR,
		icon = { shape = "pet" },
		open = function()
			toggle()
		end,
	})

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = UiKit.CREAM
	panel.Visible = false
	UiKit.corner(panel, 24)
	UiKit.stroke(panel, 4)
	UiKit.placeMenu(gui, panel, PANEL_SIZE, MIN_HEIGHT)

	local heading = UiKit.label(panel, Lang.t("profile.title"))
	heading.Position = UDim2.fromOffset(24, 12)
	heading.Size = UDim2.new(1, -120, 0, 48)
	heading.TextXAlignment = Enum.TextXAlignment.Left

	local subline = UiKit.label(panel, "")
	subline.Position = UDim2.fromOffset(24, 62)
	subline.Size = UDim2.new(1, -120, 0, 30)
	subline.TextXAlignment = Enum.TextXAlignment.Left
	subline.TextColor3 = UiKit.ORANGE

	local closeButton = UiKit.button(panel, "X", UiKit.RED)
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -14, 0, 14)
	closeButton.Size = UDim2.fromOffset(72, 72)

	local tabs: { [string]: TextButton } = {}
	local tabWidth = math.floor((PANEL_SIZE.X - 48 - (#tabOrder - 1) * 12) / #tabOrder)
	for i, tabId in tabOrder do
		local button = UiKit.button(panel, Lang.t(`profile.tab.{tabId}`), UiKit.GREY)
		button.Position = UDim2.fromOffset(24 + (i - 1) * (tabWidth + 12), 104)
		button.Size = UDim2.fromOffset(tabWidth, 60)
		tabs[tabId] = button
	end

	local info = UiKit.label(panel, "")
	info.Position = UDim2.fromOffset(24, 176)
	info.Size = UDim2.new(1, -48, 0, 34)
	info.TextColor3 = HINT_COLOR

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
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = list
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = list

	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local target: Player = localPlayer
	local tab = tabOrder[1]
	local watchConnection: RBXScriptConnection? = nil

	local function row(order: number, color: Color3, height: number): Frame
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = color
		frame.Size = UDim2.new(1, -16, 0, height)
		frame.LayoutOrder = order
		UiKit.corner(frame, 14)
		UiKit.stroke(frame, 3)
		frame.Parent = list
		return frame
	end

	local function textIn(frame: Frame, text: string, x: number, y: number, w: number, h: number): TextLabel
		local label = UiKit.label(frame, text)
		label.Position = UDim2.new(0, x, 0, y)
		label.Size = UDim2.new(w, if w == 1 then -x - 12 else 0, 0, h)
		label.TextXAlignment = Enum.TextXAlignment.Left
		return label
	end

	local function statRows(profile: Profile)
		local stats = profile.stats or {}
		local function n(key: string): number
			return stats[key] or 0
		end
		local entries = {
			{ "profile.stat.coinsEarned", Lang.shortNumber(n("coinsEarned")) },
			{ "profile.stat.toppingsCollected", Lang.shortNumber(n("toppingsCollected")) },
			{ "profile.stat.eggsOpened", Lang.shortNumber(n("eggsOpened")) },
			{ "profile.stat.playtime", playtimeText(n("playtimeSeconds")) },
			{ "profile.stat.rebirths", Lang.integer(n("rebirths")) },
			{
				"profile.stat.highestWorld",
				Lang.worldName((GameConfig.worlds[n("highestWorld")] or GameConfig.worlds[1]).id),
			},
			{ "profile.stat.petIndex", `{n("petIndexFound")}/{n("petIndexTotal")}` },
			{ "profile.stat.toppingIndex", `{n("toppingIndexFound")}/{n("toppingIndexTotal")}` },
		}
		for i, entry in entries do
			local frame = row(i, ROW_COLOR, 64)
			textIn(frame, Lang.t(entry[1]), 16, 12, 0.55, 40)
			local value = UiKit.label(frame, entry[2])
			value.AnchorPoint = Vector2.new(1, 0)
			value.Position = UDim2.new(1, -16, 0, 12)
			value.Size = UDim2.new(0.42, 0, 0, 40)
			value.TextXAlignment = Enum.TextXAlignment.Right
		end
		info.Text = ""
	end

	local STAT_OF_KIND = {
		CoinsEarned = "coinsEarned",
		ToppingsCollected = "toppingsCollected",
		EggsOpened = "eggsOpened",
	}

	local function badgeRows(profile: Profile)
		local reached = 0
		for i, badge in GameConfig.badges do
			local done = table.find(profile.badges, badge.id) ~= nil
			reached += if done then 1 else 0
			local frame = row(i, if done then DONE_COLOR else LOCKED_COLOR, 84)
			local name =
				textIn(frame, (if done then "🏅 " else "🔒 ") .. Lang.t(`badge.{badge.id}.name`), 16, 8, 1, 38)
			name.TextColor3 = if done then UiKit.DARK else HINT_COLOR
			local desc = textIn(frame, Lang.t(`badge.{badge.id}.desc`), 16, 48, 0.7, 28)
			desc.TextColor3 = HINT_COLOR
			local statKey = STAT_OF_KIND[badge.kind]
			if statKey and not done and profile.stats then
				local progress =
					UiKit.label(frame, `{Lang.shortNumber(profile.stats[statKey] or 0)}/{Lang.shortNumber(badge.goal)}`)
				progress.AnchorPoint = Vector2.new(1, 0)
				progress.Position = UDim2.new(1, -16, 0, 48)
				progress.Size = UDim2.new(0.28, 0, 0, 28)
				progress.TextXAlignment = Enum.TextXAlignment.Right
				progress.TextColor3 = UiKit.ORANGE
			end
		end
		info.Text = Lang.t("profile.badgeCount", { count = reached, total = #GameConfig.badges })
	end

	local function titleRows(profile: Profile)
		local own = target == localPlayer
		local entries: { { id: string, text: string, how: string?, unlocked: boolean } } = {}
		if own then
			table.insert(entries, { id = "", text = Lang.t("profile.auto"), unlocked = true })
		end
		for _, title in GameConfig.titles do
			table.insert(entries, {
				id = title.id,
				text = Lang.t(`title.{title.id}`),
				how = Lang.t(`title.{title.id}.how`),
				unlocked = table.find(profile.titles, title.id) ~= nil,
			})
		end
		for i, entry in entries do
			local chosen = if own then profile.selected == entry.id else profile.title == entry.id
			local frame =
				row(i, if entry.unlocked then (if chosen then DONE_COLOR else ROW_COLOR) else LOCKED_COLOR, 76)
			textIn(frame, entry.text, 16, 6, 0.6, 38)
			if entry.how then
				local how = textIn(
					frame,
					if entry.unlocked then entry.how else Lang.t("profile.locked", { how = entry.how }),
					16,
					44,
					0.6,
					26
				)
				how.TextColor3 = HINT_COLOR
			end
			if own and entry.unlocked then
				local button = UiKit.button(
					frame,
					Lang.t(if chosen then "profile.chosen" else "profile.choose"),
					if chosen then UiKit.GREEN else UiKit.ORANGE
				)
				button.AnchorPoint = Vector2.new(1, 0.5)
				button.Position = UDim2.new(1, -12, 0.5, 0)
				button.Size = UDim2.fromOffset(180, 54)
				button.Activated:Connect(function()
					if not chosen then
						UiKit.pop(button)
						setTitle:FireServer(entry.id)
					end
				end)
			end
		end
		info.Text = if own then "" else Lang.t("profile.readOnly")
	end

	local function render()
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for tabId, button in tabs do
			button.BackgroundColor3 = if tabId == tab then UiKit.ORANGE else UiKit.GREY
		end
		heading.Text = if target == localPlayer
			then Lang.t("profile.title")
			else Lang.t("profile.titleOf", { name = target.DisplayName })
		local profile = readProfile(target)
		if profile == nil then
			subline.Text = ""
			info.Text = Lang.t("profile.loading")
			return
		end
		subline.Text = if profile.title ~= "" then Lang.t(`title.{profile.title}`) else ""
		if tab == "stats" then
			statRows(profile)
		elseif tab == "badges" then
			badgeRows(profile)
		else
			titleRows(profile)
		end
	end

	local function close()
		panel.Visible = false
		if watchConnection then
			watchConnection:Disconnect()
			watchConnection = nil
		end
	end
	UiKit.registerMenu(TILE_ID, close)

	local function open(player: Player)
		if watchConnection then
			watchConnection:Disconnect()
		end
		target = player
		watchConnection = player:GetAttributeChangedSignal("Profile"):Connect(function()
			if panel.Visible then
				render()
			end
		end)
		panel.Visible = true
		UiKit.menuOpened(TILE_ID)
		render()
		UiKit.pop(panel)
	end

	toggle = function()
		if panel.Visible and target == localPlayer then
			close()
		else
			open(localPlayer)
		end
	end
	closeButton.Activated:Connect(close)
	for tabId, button in tabs do
		button.Activated:Connect(function()
			tab = tabId
			render()
		end)
	end
	Lang.onLanguageChanged(function()
		if panel.Visible then
			render()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if player == target and panel.Visible then
			close()
		end
	end)

	-- Tapping / clicking another player's character opens their profile (read only).
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	UserInputService.InputEnded:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		local camera = workspace.CurrentCamera
		if camera == nil then
			return
		end
		params.FilterDescendantsInstances = if localPlayer.Character then { localPlayer.Character } else {}
		local ray = camera:ViewportPointToRay(input.Position.X, input.Position.Y)
		local hit = workspace:Raycast(ray.Origin, ray.Direction * TAP_DISTANCE, params)
		if hit == nil then
			return
		end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		while model and Players:GetPlayerFromCharacter(model) == nil do
			model = model:FindFirstAncestorOfClass("Model")
		end
		local player = if model then Players:GetPlayerFromCharacter(model) else nil
		if player and player ~= localPlayer then
			open(player)
		end
	end)
end

return ProfileMenu
