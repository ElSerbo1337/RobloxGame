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
-- Every DataStore call is wrapped in pcall: on errors a board keeps its last rows (or
-- shows a loading text), the game goes on.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Leaderboard = require(ReplicatedStorage.Shared.Leaderboard)
local PlayerStates = require(script.Parent.PlayerStates)
local SignText = require(script.Parent.SignText)

local CONFIG = GameConfig.leaderboards
local CREAM = Color3.fromRGB(255, 248, 230)
local DARK = Color3.fromRGB(60, 35, 20)
local ORANGE = Color3.fromRGB(240, 130, 60)
local MEDALS = { Color3.fromRGB(230, 170, 30), Color3.fromRGB(150, 150, 160), Color3.fromRGB(190, 110, 60) }

type Board = { id: string, store: string, title: string, format: Leaderboard.Format }
type Page = { { key: string, value: number } }

local LeaderboardService = {}

-- Board id -> ordered DataStore (missing if it could not be opened).
local stores: { [string]: OrderedDataStore } = {}
-- User id -> display name, cached for the whole server.
local names: { [number]: string } = {}

local function openStores()
	for _, board in CONFIG.boards do
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
	local key = tostring(userId)
	for _, board in CONFIG.boards do
		local store = stores[board.id]
		local score = (scores :: any)[board.id] :: number
		if store and score > 0 then
			local ok, err = pcall(function()
				store:SetAsync(key, score)
			end)
			if not ok then
				warn(`[Bestenliste] Schreiben von {board.id} für {userId} fehlgeschlagen: {err}`)
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

	local list = Instance.new("Frame")
	list.Name = "Rows"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0.05, 0.04 + titleHeight)
	list.Size = UDim2.fromScale(0.9, 0.94 - titleHeight)
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

-- Starts writing (after saves) and the refresh loop for the boards on the spawn island.
-- `island` holds the panels' SurfaceGuis (name "Leaderboard", attribute Board = index
-- into GameConfig.leaderboards.boards).
function LeaderboardService.start(island: Instance)
	openStores()
	PlayerStates.onSaved(LeaderboardService.submit)

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
