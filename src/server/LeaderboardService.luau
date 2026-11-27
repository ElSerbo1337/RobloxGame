--!strict
-- Global leaderboards (#38): one ordered DataStore per board in
-- GameConfig.leaderboards (play time, coins earned, rebirths).
--
-- Writing: after every save that was really written (PlayerStates.onSaved: periodic
-- saves and leave/shutdown), the player's scores (rules.leaderboardScores) go into the
-- boards. The boards are separate stores, so the session lock of the save is untouched;
-- states that were never loaded correctly are never saved and so never submitted.
--
-- Reading: every refreshSeconds each server reads the top entries of every board and
-- shows them on the panels of the spawn island (rank, display name, value in German
-- format, see Shared.Leaderboard).
--
-- New boards (#109, switch newLeaderboards): eggs opened and toppings collected stand on
-- the reserved spots Board4/Board5 (#106 anchors); the panels are built here. They also
-- write a weekly store per German week (switch weeklyChampion); the top 3 of last week's
-- weekly stores get the Weekly Champion title until the end of this week (checked for
-- every player on this server every few seconds, so offline champions get it on join).
--
-- Every DataStore call is wrapped in pcall: on errors a board keeps its last rows (or
-- shows a loading text), the game goes on.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Leaderboard = require(ReplicatedStorage.Shared.Leaderboard)
local PlayerStates = require(script.Parent.PlayerStates)
local ProfileService = require(script.Parent.ProfileService)
local SignText = require(script.Parent.SignText)

local CONFIG = GameConfig.leaderboards
local CREAM = Color3.fromRGB(255, 248, 230)
local DARK = Color3.fromRGB(60, 35, 20)
local ORANGE = Color3.fromRGB(240, 130, 60)
local MEDALS = { Color3.fromRGB(230, 170, 30), Color3.fromRGB(150, 150, 160), Color3.fromRGB(190, 110, 60) }

type Board = {
	id: string,
	store: string,
	title: string,
	format: Leaderboard.Format,
	weeklyStore: string?,
	anchor: string?,
	feature: string?,
}
type Page = { { key: string, value: number } }

local LeaderboardService = {}

-- Board id -> ordered DataStore (missing if it could not be opened).
local stores: { [string]: OrderedDataStore } = {}
-- User id -> display name, cached for the whole server.
local names: { [number]: string } = {}
-- Weekly store name -> ordered DataStore (opened on first use).
local weeklyStores: { [string]: OrderedDataStore } = {}

local features = Features.new(GameConfig.features)
local CHAMPION_CHECK_SECONDS = 10

local function boardOn(board: Board): boolean
	return board.feature == nil or features.enabled(board.feature)
end

local function weeklyOn(board: Board): boolean
	return board.weeklyStore ~= nil and boardOn(board) and features.enabled("weeklyChampion")
end

local function weeklyStore(board: Board, week: number): OrderedDataStore?
	local name = Leaderboard.weeklyStore(board.weeklyStore :: string, week)
	if weeklyStores[name] == nil then
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(name)
		end)
		if not ok then
			warn(`[Bestenliste] {name} nicht verfügbar: {store}`)
			return nil
		end
		weeklyStores[name] = store
	end
	return weeklyStores[name]
end

local function write(store: OrderedDataStore, key: string, score: number, what: string)
	local ok, err = pcall(function()
		store:SetAsync(key, score)
	end)
	if not ok then
		warn(`[Bestenliste] Schreiben von {what} für {key} fehlgeschlagen: {err}`)
	end
end

local function openStores()
	for _, board in CONFIG.boards do
		if not boardOn(board) then
			continue
		end
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(board.store)
		end)
		if ok then
			stores[board.id] = store
		else
			warn(`[Bestenliste] {board.store} nicht verfügbar: {store}`)
		end
	end
end

-- Yields. Writes the player's scores into every board (0 is skipped: nothing to show).
-- Studio test players (Clients and Servers) have user ids <= 0; they would land on
-- the real boards of the published game, so they are skipped.
function LeaderboardService.submit(userId: number, state: any)
	if userId <= 0 then
		return
	end
	local scores = PlayerStates.rules.leaderboardScores(state)
	local weekly = PlayerStates.rules.weeklyScores(state)
	local key = tostring(userId)
	for _, board in CONFIG.boards do
		local store = stores[board.id]
		local score = (scores :: any)[board.id] :: number
		if store and score > 0 then
			write(store, key, score, board.id)
		end
		local weekScore = (weekly :: any)[board.id]
		if weeklyOn(board) and weekly.week > 0 and weekScore and weekScore > 0 then
			local week = weeklyStore(board, weekly.week)
			if week then
				write(week, key, weekScore, `{board.id} (Woche {weekly.week})`)
			end
		end
	end
end

-- Yields. Top entries of a board, best first; nil if the read failed.
local function readTop(board: Board): Page?
	local store = stores[board.id]
	if store == nil then
		return nil
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, CONFIG.top):GetCurrentPage()
	end)
	if not ok then
		warn(`[Bestenliste] Lesen von {board.id} fehlgeschlagen: {page}`)
		return nil
	end
	return page
end

-- Yields. Fills the name cache for the given user ids: players on this server first,
-- the rest in one batch request; fallback is the user name, then "Spieler".
local function resolveNames(userIds: { number })
	local missing = {}
	for _, userId in userIds do
		if names[userId] == nil then
			local player = Players:GetPlayerByUserId(userId)
			if player then
				names[userId] = player.DisplayName
			else
				table.insert(missing, userId)
			end
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(function()
		return UserService:GetUserInfosByUserIdsAsync(missing)
	end)
	if ok then
		for _, info in infos do
			names[info.Id] = info.DisplayName
		end
	end
	for _, userId in missing do
		if names[userId] == nil then
			local nameOk, name = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			if nameOk then
				names[userId] = name
			end
		end
	end
end

local function text(parent: Instance, name: string, value: string, color: Color3, xAlign: Enum.TextXAlignment)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextXAlignment = xAlign
	label.Text = value
	label.Parent = parent
	return label
end

-- Builds the panel layout on a board's SurfaceGui: title, status line and `top` rows
-- (rank, name, value). Returns the rows and the status label.
local function buildPanel(gui: SurfaceGui, board: Board): ({ Frame }, TextLabel)
	gui:ClearAllChildren()
	local rowCount = CONFIG.top
	local titleHeight = 1 / (rowCount + 2.5) * 1.5

	local title = text(gui, "Title", board.title, ORANGE, Enum.TextXAlignment.Center)
	SignText.set(title, `board.{board.id}`)
	title.Size = UDim2.new(0.9, 0, titleHeight, 0)
	title.Position = UDim2.fromScale(0.05, 0.02)
	local stroke = Instance.new("UIStroke")
	stroke.Color = DARK
	stroke.Thickness = 2
	stroke.Parent = title

	-- New boards (#109): column header under the title and the champion hint at the bottom.
	local top, bottom = 0.04 + titleHeight, 0.02
	if board.anchor then
		local headHeight = titleHeight * 0.45
		local valueKey = if board.id == "EggsOpened" then "board.colEggs" else "board.colToppings"
		for _, column in
			{
				{ "board.colRank", 0, 0.14, "Center" },
				{ "board.colPlayer", 0.14, 0.5, "Left" },
				{ valueKey, 0.64, 0.34, "Right" },
			}
		do
			local head = text(gui, "Column", "", ORANGE, (Enum.TextXAlignment :: any)[column[4]])
			SignText.set(head, column[1] :: string)
			head.Size = UDim2.fromScale(0.9 * (column[3] :: number), headHeight)
			head.Position = UDim2.fromScale(0.05 + 0.9 * (column[2] :: number), top)
		end
		top += headHeight
		if weeklyOn(board) then
			local hint = text(gui, "WeeklyHint", "", DARK, Enum.TextXAlignment.Center)
			SignText.set(hint, "board.weeklyHint")
			hint.Size = UDim2.fromScale(0.9, headHeight)
			hint.Position = UDim2.fromScale(0.05, 0.99 - headHeight)
			bottom += headHeight
		end
	end

	local list = Instance.new("Frame")
	list.Name = "Rows"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0.05, top)
	list.Size = UDim2.fromScale(0.9, 1 - top - bottom)
	list.Parent = gui

	local status = text(list, "Status", "", DARK, Enum.TextXAlignment.Center)
	SignText.set(status, "board.loading")
	status.Size = UDim2.fromScale(1, 1 / rowCount)

	local rows = {}
	for i = 1, rowCount do
		local row = Instance.new("Frame")
		row.Name = `Row{i}`
		row.BackgroundColor3 = if i % 2 == 1 then Color3.fromRGB(245, 230, 200) else CREAM
		row.BorderSizePixel = 0
		row.Size = UDim2.fromScale(1, 1 / rowCount)
		row.Position = UDim2.fromScale(0, (i - 1) / rowCount)
		row.Visible = false
		row.Parent = list
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = row

		local rank = text(row, "Rank", `{i}.`, MEDALS[i] or DARK, Enum.TextXAlignment.Center)
		rank.Size = UDim2.fromScale(0.12, 0.85)
		rank.Position = UDim2.fromScale(0, 0.075)
		local name = text(row, "Name", "", DARK, Enum.TextXAlignment.Left)
		name.Size = UDim2.fromScale(0.5, 0.75)
		name.Position = UDim2.fromScale(0.14, 0.125)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local value = text(row, "Value", "", DARK, Enum.TextXAlignment.Right)
		value.Size = UDim2.fromScale(0.34, 0.75)
		value.Position = UDim2.fromScale(0.64, 0.125)
		table.insert(rows, row)
	end
	return rows, status
end

local function show(rows: { Frame }, status: TextLabel, entries: { Leaderboard.Row })
	for i, row in rows do
		local entry = entries[i]
		row.Visible = entry ~= nil
		if entry then
			(row:FindFirstChild("Name") :: TextLabel).Text = entry.name
			SignText.set(row:FindFirstChild("Value") :: TextLabel, entry.valueKey, entry.valueArgs)
		end
	end
	status.Visible = #entries == 0
	SignText.set(status, "board.empty")
end

-- Builds the panel of a new board (#109) on its reserved anchor: two posts, a cream
-- panel facing the anchor's front (local -Z) and an orange title strip.
local function buildAnchoredPanel(island: Instance, board: Board, index: number)
	local anchors = island:FindFirstChild("Anchors")
	local anchor = anchors and anchors:FindFirstChild(`{board.anchor}Anchor`)
	if not (anchor and anchor:IsA("BasePart")) then
		warn(`[Bestenliste] Anker {board.anchor}Anchor fehlt auf der Spawn-Insel`)
		return
	end
	local model = Instance.new("Model")
	model.Name = `Board_{board.id}`
	local function block(name: string, size: Vector3, offset: CFrame, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = anchor.CFrame * offset
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	for _, side in { -1, 1 } do
		block("BoardPost", Vector3.new(1.2, 10, 1.2), CFrame.new(side * 6.2, 5, 0), Color3.fromRGB(150, 100, 60))
	end
	local panel = block("BoardPanel", Vector3.new(12, 7.5, 0.8), CFrame.new(0, 6.2, 0), CREAM)
	block("BoardTitle", Vector3.new(13.2, 1.8, 1.2), CFrame.new(0, 10.6, 0), ORANGE)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Leaderboard"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.2
	gui.MaxDistance = 150
	gui:SetAttribute("Board", index)
	gui.Parent = panel
	model.Parent = island
end

-- Weekly Champion (#109): user ids of last week's champions, read once per week.
local championWeek = -1
local champions: { [number]: boolean } = {}

local function lastWeeksChampions(now: number): { [number]: boolean }
	local week = GameRules.weekNumber(now)
	if championWeek == week then
		return champions
	end
	local pages = {}
	for _, board in CONFIG.boards do
		if weeklyOn(board) then
			local store = weeklyStore(board, week - 1)
			if store == nil then
				return champions
			end
			local ok, page = pcall(function()
				return store:GetSortedAsync(false, CONFIG.championTop):GetCurrentPage()
			end)
			if not ok then
				warn(`[Bestenliste] Wochen-Champions von {board.id} nicht lesbar: {page}`)
				return champions -- retried on the next check
			end
			table.insert(pages, page)
		end
	end
	championWeek = week
	champions = GameRules.weeklyChampions(pages, CONFIG.championTop)
	return champions
end

-- Rolls every player's stats week and hands out the title to last week's champions.
local function checkWeeks()
	local now = os.time()
	local rules = PlayerStates.rules
	local winners = lastWeeksChampions(now)
	local untilTime = GameRules.championUntil(now)
	for _, player in Players:GetPlayers() do
		local state = PlayerStates.get(player)
		if state == nil then
			continue
		end
		local rolled = rules.rollStatsWeek(state, now)
		if rolled.ok then
			PlayerStates.set(player, rolled.state)
			state = rolled.state
		end
		if winners[player.UserId] and (state.weeklyChampionUntil or 0) < untilTime then
			ProfileService.grantWeeklyChampion(player, untilTime)
		end
	end
end

-- Starts writing (after saves) and the refresh loop for the boards on the spawn island.
-- `island` holds the panels' SurfaceGuis (name "Leaderboard", attribute Board = index
-- into GameConfig.leaderboards.boards).
function LeaderboardService.start(island: Instance)
	openStores()
	PlayerStates.onSaved(LeaderboardService.submit)
	for index, board in CONFIG.boards do
		if board.anchor and boardOn(board) then
			buildAnchoredPanel(island, board, index)
		end
	end
	if features.enabled("weeklyChampion") and features.enabled("newLeaderboards") then
		task.spawn(function()
			while true do
				checkWeeks()
				task.wait(CHAMPION_CHECK_SECONDS)
			end
		end)
	end

	local panels: { { board: Board, rows: { Frame }, status: TextLabel } } = {}
	for _, gui in island:GetDescendants() do
		local index = gui:GetAttribute("Board")
		local board = if typeof(index) == "number" then CONFIG.boards[index] else nil
		if gui:IsA("SurfaceGui") and gui.Name == "Leaderboard" and board then
			local rows, status = buildPanel(gui, board)
			table.insert(panels, { board = board, rows = rows, status = status })
		end
	end

	task.spawn(function()
		while true do
			for _, panel in panels do
				local page = readTop(panel.board)
				if page then
					local userIds = {}
					for _, item in page do
						local userId = tonumber(item.key)
						if userId then
							table.insert(userIds, userId)
						end
					end
					resolveNames(userIds)
					local entries = {}
					for _, item in page do
						local userId = tonumber(item.key)
						if userId then
							table.insert(entries, { name = names[userId] or "Spieler", value = item.value })
						end
					end
					show(panel.rows, panel.status, Leaderboard.rows(entries, panel.board.format))
				end
			end
			task.wait(CONFIG.refreshSeconds)
		end
	end)
end

return LeaderboardService
