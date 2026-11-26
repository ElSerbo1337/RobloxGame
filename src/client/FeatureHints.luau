--!strict
-- One-time hints for new MEGA UPDATE features (#113): a side bar tile pulses with a
-- short note while its hint is "active" (e.g. the first merge is possible) until the
-- player taps it once. Remembered per player on the server (HintSeen -> SeenHints,
-- GameConfig.hints). Only one hint shows at a time (smallest priority first), so a new
-- player is not greeted by five pulsing tiles. Switch: GameConfig.features.featureHints.
--
--   FeatureHints.attach("Merge", "pets", "hint.merge", 10)   -- once, after SideBar.register
--   FeatureHints.setActive("Merge", canMerge)                -- whenever the condition changes

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Lang = require(script.Parent.Lang)
local SideBar = require(script.Parent.SideBar)
local UiKit = require(script.Parent.UiKit)

type Hint = {
	id: string,
	tileId: string,
	textKey: string,
	priority: number,
	active: boolean,
	note: TextLabel?,
}

local FeatureHints = {}

local enabled = Features.new(GameConfig.features).enabled("featureHints")
local player = Players.LocalPlayer
local hints: { [string]: Hint } = {}
local seenLocally: { [string]: boolean } = {}
local shown: Hint? = nil
local tween: Tween? = nil

local function seen(id: string): boolean
	if seenLocally[id] then
		return true
	end
	local list = player:GetAttribute("SeenHints")
	return type(list) == "string" and table.find(string.split(list, ","), id) ~= nil
end

local function hide()
	local hint = shown
	if hint == nil then
		return
	end
	shown = nil
	if tween then
		tween:Cancel()
		tween = nil
	end
	local button = SideBar.button(hint.tileId)
	local scale = button and button:FindFirstChildOfClass("UIScale")
	if scale then
		scale.Scale = 1
	end
	if hint.note then
		hint.note.Visible = false
	end
end

local function show(hint: Hint)
	local button = SideBar.button(hint.tileId)
	if button == nil then
		return
	end
	shown = hint
	if hint.note == nil then
		local note = UiKit.label(button, Lang.t(hint.textKey))
		note.Name = "FeatureHint"
		UiKit.placeSideNote(note, button, 12)
		note.Size = UDim2.fromOffset(200, 44)
		note.BackgroundTransparency = 0
		note.BackgroundColor3 = UiKit.CREAM
		note.ZIndex = 3
		UiKit.corner(note, 14)
		UiKit.stroke(note, 2)
		hint.note = note
	end
	(hint.note :: TextLabel).Visible = true
	-- Same UIScale as UiKit.pop (RebirthMenu does the same).
	local scale = button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = button
	scale.Scale = 1
	tween = TweenService:Create(
		scale,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.12 }
	);
	(tween :: Tween):Play()
end

local function refresh()
	if player:GetAttribute("SeenHints") == nil then
		return -- not loaded yet
	end
	local best: Hint? = nil
	for _, hint in hints do
		if hint.active and not seen(hint.id) and (best == nil or hint.priority < best.priority) then
			best = hint
		end
	end
	if best ~= shown then
		hide()
		if best then
			show(best)
		end
	end
end

-- Links the hint `id` (must be in GameConfig.hints) to the tile `tileId`.
function FeatureHints.attach(id: string, tileId: string, textKey: string, priority: number)
	if not enabled or hints[id] then
		return
	end
	local hint: Hint = { id = id, tileId = tileId, textKey = textKey, priority = priority, active = false }
	hints[id] = hint
	SideBar.onOpen(tileId, function()
		if shown == hint then
			seenLocally[id] = true
			Net.event("HintSeen"):FireServer(id)
			refresh()
		end
	end)
end

-- Whether the hint's condition holds right now (it still shows only once per player).
function FeatureHints.setActive(id: string, on: boolean)
	local hint = hints[id]
	if hint == nil or hint.active == on then
		return
	end
	hint.active = on
	refresh()
end

if enabled then
	player:GetAttributeChangedSignal("SeenHints"):Connect(refresh)
end

return FeatureHints
