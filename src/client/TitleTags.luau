--!strict
-- Titles over the head (#103, features.titles): a small billboard above every player's
-- head with the active title (attribute TitleId, see ProfileService) and the rebirth
-- level (attribute Rebirths, only from 1 rebirth on). Built on each client so the text
-- follows the viewer's language. The Weekly Champion title glows in gold.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Lang = require(script.Parent.Lang)
local UiKit = require(script.Parent.UiKit)

local MAX_DISTANCE = 70
local CHAMPION_COLOR = Color3.fromRGB(255, 215, 60)
local TITLE_COLOR = Color3.fromRGB(255, 248, 230)

local TitleTags = {}

function TitleTags.start()
	if not Features.new(GameConfig.features).enabled("titles") then
		return
	end
	local localPlayer = Players.LocalPlayer
	local folder = Instance.new("Folder")
	folder.Name = "TitleTags"
	folder.Parent = localPlayer:WaitForChild("PlayerGui")

	local tags: { [Player]: BillboardGui } = {}

	local function refresh(player: Player)
		local tag = tags[player]
		if tag == nil then
			return
		end
		local titleId = player:GetAttribute("TitleId")
		local rebirths = (player:GetAttribute("Rebirths") :: number?) or 0
		local title = tag:FindFirstChild("Title") :: TextLabel
		local level = tag:FindFirstChild("Rebirths") :: TextLabel
		title.Text = if type(titleId) == "string" and titleId ~= "" then Lang.t(`title.{titleId}`) else ""
		title.TextColor3 = if titleId == "WeeklyChampion" then CHAMPION_COLOR else TITLE_COLOR
		level.Text = if rebirths > 0 then Lang.t("titleTag.rebirths", { count = rebirths }) else ""
		tag.Enabled = title.Text ~= "" or level.Text ~= ""
	end

	local function attach(player: Player, character: Model)
		local head = character:WaitForChild("Head", 10)
		if head == nil or not head:IsA("BasePart") then
			return
		end
		if tags[player] then
			tags[player]:Destroy()
		end
		local tag = Instance.new("BillboardGui")
		tag.Name = player.Name
		tag.Adornee = head
		tag.Size = UDim2.new(7, 0, 1.6, 0)
		tag.StudsOffset = Vector3.new(0, 3.2, 0)
		tag.MaxDistance = MAX_DISTANCE
		tag.LightInfluence = 0
		tag.ResetOnSpawn = false
		local title = UiKit.label(tag, "")
		title.Name = "Title"
		title.Size = UDim2.fromScale(1, 0.6)
		title.TextScaled = true
		local level = UiKit.label(tag, "")
		level.Name = "Rebirths"
		level.Position = UDim2.fromScale(0, 0.6)
		level.Size = UDim2.fromScale(1, 0.4)
		level.TextScaled = true
		level.TextColor3 = UiKit.COIN
		for _, label in { title, level } do
			label.TextStrokeColor3 = UiKit.DARK
			label.TextStrokeTransparency = 0
		end
		tag.Parent = folder
		tags[player] = tag
		refresh(player)
	end

	local function watch(player: Player)
		player:GetAttributeChangedSignal("TitleId"):Connect(function()
			refresh(player)
		end)
		player:GetAttributeChangedSignal("Rebirths"):Connect(function()
			refresh(player)
		end)
		player.CharacterAdded:Connect(function(character)
			attach(player, character)
		end)
		if player.Character then
			task.spawn(attach, player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		if tags[player] then
			tags[player]:Destroy()
			tags[player] = nil
		end
	end)
	Lang.onLanguageChanged(function()
		for player in tags do
			refresh(player)
		end
	end)
end

return TitleTags
