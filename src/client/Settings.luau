--!strict
-- Player settings on the client (#76): the one place every client module asks
-- "what did the player choose?". The server stores the choices (SetSetting ->
-- SettingsService, saved with the PlayerState) and replicates them as the attribute
-- Settings; this module fills in the defaults (GameRules.SETTINGS, phones start on
-- "Low" graphics) and applies a change locally right away, before the server answers.
--
-- API (documented in docs/ui-style.md, "Einstellungen"):
--   Settings.get(key)             current value, e.g. Settings.get("musicVolume") -> 0..100
--   Settings.set(key, value)      change it (settings menu); sent to the server shortly after
--   Settings.changed:Connect(fn)  fn(key, value) after every change (also from the server)
--   Settings.observe(key, fn)     fn(value) now and after every change of that key
--   Settings.lowGraphics()        true on "Low": fewer particles, hide decoration
--   Settings.cameraShake()        false: no camera shake
--   Settings.screenFlashes()      false: no white/colour screen flashes
--   Settings.skipEggAnimation()   true: show the hatched pets right away
--   Settings.volume("music" | "effects")  0..1 incl. mute
-- With features.settings = false every value is its default and set does nothing.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Net = require(ReplicatedStorage.Shared.Net)

-- Wait this long after the last change of a key before sending it (slider drags).
local SEND_DELAY = 0.4

local enabled = Features.new(GameConfig.features).enabled("settings")
-- Phones and tablets without a keyboard get the touch defaults ("Low" graphics).
local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local player = Players.LocalPlayer

local changedEvent = Instance.new("BindableEvent")

local Settings = {}

Settings.KEYS = GameRules.SETTINGS
-- (key: string, value: any) after every change of a resolved value.
Settings.changed = changedEvent.Event
Settings.isTouch = touch

-- What the server saved (attribute) and local changes the server has not confirmed yet.
local saved: { [string]: any } = {}
local pending: { [string]: any } = {}
local resolved: { [string]: any } = GameRules.resolveSettings(nil, touch)
local sendToken: { [string]: number } = {}

local function readSaved(): { [string]: any }
	local json = player:GetAttribute("Settings")
	if type(json) ~= "string" then
		return {}
	end
	local ok, value = pcall(HttpService.JSONDecode, HttpService, json)
	return if ok and type(value) == "table" then value else {}
end

local function refresh()
	if not enabled then
		return
	end
	local merged = table.clone(saved)
	for key, value in pending do
		merged[key] = value
	end
	local nextValues = GameRules.resolveSettings(merged, touch)
	local before = resolved
	resolved = nextValues
	for key, value in nextValues do
		if before[key] ~= value then
			changedEvent:Fire(key, value)
		end
	end
end

local function onAttribute()
	saved = readSaved()
	for key, value in pending do
		if saved[key] == value then
			pending[key] = nil -- the server confirmed it
		end
	end
	refresh()
end

if enabled then
	player:GetAttributeChangedSignal("Settings"):Connect(onAttribute)
	onAttribute()
end

function Settings.get(key: string): any
	assert(GameRules.SETTINGS[key], `unknown setting "{key}"`)
	return resolved[key]
end

-- Changes a setting (applies locally at once, sends the wish to the server after a short
-- pause). Invalid values are ignored.
function Settings.set(key: string, value: any)
	if not enabled or not GameRules.isValidSetting(key, value) then
		return
	end
	pending[key] = value
	refresh()
	local token = (sendToken[key] or 0) + 1
	sendToken[key] = token
	task.delay(SEND_DELAY, function()
		if sendToken[key] == token and pending[key] ~= nil then
			Net.event("SetSetting"):FireServer(key, pending[key])
		end
	end)
end

-- Calls fn(value) now and after every change of `key`.
function Settings.observe(key: string, fn: (any) -> ()): RBXScriptConnection
	local connection = Settings.changed:Connect(function(changedKey: string, value: any)
		if changedKey == key then
			fn(value)
		end
	end)
	task.spawn(fn, Settings.get(key))
	return connection
end

function Settings.lowGraphics(): boolean
	return resolved.graphics == "Low"
end

function Settings.cameraShake(): boolean
	return resolved.cameraShake == true
end

function Settings.screenFlashes(): boolean
	return resolved.screenFlashes == true
end

function Settings.skipEggAnimation(): boolean
	return resolved.skipEggAnimation == true
end

-- 0..1 for the sound group "music" or "effects" (0 when muted).
function Settings.volume(group: string): number
	local muted = resolved[`{group}Muted`]
	local percent = resolved[`{group}Volume`]
	assert(type(percent) == "number", `unknown volume group "{group}"`)
	return if muted then 0 else percent / 100
end

return Settings
