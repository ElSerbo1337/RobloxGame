--!strict
-- Spawn island marketplace (#106): texts of the update board and the Christmas
-- countdown sign (the stands themselves come from the island plan, WorldMap).
-- * Update board (feature "spawnMarketplace"): "Neu im Update!" and the list of new
--   things, shown per player language (SignText, #71). With feature "whatsNew" it has a
--   ProximityPrompt "WhatsNewPrompt" that opens the "What's new" window on the client.
-- * Countdown sign (feature "christmasCountdown"): "🎄 Weihnachts-Event startet in X
--   Tagen", days from rules.christmasCountdown (German days until 18.12.); from that
--   day on the sign is removed.
-- A switched-off feature removes its stand (all parts with its IslandRole).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local PlayerStates = require(script.Parent.PlayerStates)
local SignText = require(script.Parent.SignText)
local Texts = require(ReplicatedStorage.Shared.Texts)

local DARK = Color3.fromRGB(60, 35, 20)
local CREAM = Color3.fromRGB(255, 248, 230)

local SpawnMarketService = {}

-- All parts of one stand (IslandRole = role).
local function standParts(folder: Instance, role: string): { BasePart }
	local parts = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("IslandRole") == role then
			table.insert(parts, child)
		end
	end
	return parts
end

local function removeStand(folder: Instance, role: string)
	for _, p in standParts(folder, role) do
		p:Destroy()
	end
end

-- Text on the front (local -Z) of a sign part, filled per player language by SignText.
local function surfaceText(
	target: BasePart,
	key: string,
	args: Texts.SignArgs?,
	color: Color3,
	pixels: number
): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixels
	gui.LightInfluence = 0.2
	gui.MaxDistance = 150
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	SignText.set(label, key, args)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.06, 0)
	padding.PaddingBottom = UDim.new(0.06, 0)
	padding.PaddingLeft = UDim.new(0.05, 0)
	padding.PaddingRight = UDim.new(0.05, 0)
	padding.Parent = label
	label.Parent = gui
	gui.Parent = target
	return label
end

local function buildUpdateBoard(folder: Instance, features: Features.Features)
	local panel = folder:FindFirstChild("UpdateBoardPanel")
	local title = folder:FindFirstChild("UpdateBoardTitle")
	if not (panel and panel:IsA("BasePart") and title and title:IsA("BasePart")) then
		warn("[SpawnMarket] Update-Tafel fehlt im Inselplan")
		return
	end
	surfaceText(title, "whatsNew.board", nil, CREAM, 40)
	local list = surfaceText(panel, "whatsNew.list", nil, DARK, 40)
	list.TextXAlignment = Enum.TextXAlignment.Left
	if features.enabled("whatsNew") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "WhatsNewPrompt"
		-- German default; the client shows it in the player's language.
		prompt.ActionText = Texts.format("de", "whatsNew.prompt")
		prompt.ObjectText = Texts.format("de", "whatsNew.board")
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = panel
	end
end

local function buildCountdown(folder: Instance)
	local panel = folder:FindFirstChild("CountdownPanel")
	local title = folder:FindFirstChild("CountdownTitle")
	if not (panel and panel:IsA("BasePart") and title and title:IsA("BasePart")) then
		warn("[SpawnMarket] Countdown-Schild fehlt im Inselplan")
		return
	end
	surfaceText(title, "countdown.title", nil, CREAM, 40)
	local label = surfaceText(panel, "countdown.days", { days = { integer = 0 } }, Color3.fromRGB(180, 40, 40), 40)
	local rules = PlayerStates.rules
	local refresh = GameConfig.spawnMarket.countdownRefreshSeconds
	task.spawn(function()
		while true do
			local days = rules.christmasCountdown(os.time())
			if days == nil then
				removeStand(folder, "Countdown")
				return
			end
			if days == 1 then
				SignText.set(label, "countdown.tomorrow")
			else
				SignText.set(label, "countdown.days", { days = { integer = days } })
			end
			task.wait(refresh)
		end
	end)
end

function SpawnMarketService.start(spawnIsland: Folder)
	local features = Features.new(GameConfig.features)
	if features.enabled("spawnMarketplace") then
		buildUpdateBoard(spawnIsland, features)
	else
		removeStand(spawnIsland, "UpdateBoard")
	end
	if features.enabled("christmasCountdown") then
		buildCountdown(spawnIsland)
	else
		removeStand(spawnIsland, "Countdown")
	end
end

return SpawnMarketService
