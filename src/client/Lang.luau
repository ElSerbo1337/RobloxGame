--!strict
-- The player's language on this client (#67): read once at join from the experience
-- language chosen in the Roblox menu (Player.LocaleId), else the Roblox account locale
-- (German locales → "de", everything else → "en"); texts and numbers come from
-- src/shared/Texts.luau.
--
-- Studio test: set a string attribute `Language` ("de" or "en") on Workspace before
-- pressing Play; it is only honoured in Studio. Alternatively Test → Player Emulator →
-- Locale changes the Roblox locale.

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Texts = require(ReplicatedStorage.Shared.Texts)

local function readLanguage(): Texts.Language
	if RunService:IsStudio() then
		local override = Workspace:GetAttribute("Language")
		if override == "de" or override == "en" then
			return override
		end
	end
	-- The experience language the player picks in the Roblox menu (Player.LocaleId), then
	-- the Roblox app language, then the device language.
	local player = Players.LocalPlayer
	local locale = if player then player.LocaleId else nil
	if locale == nil or locale == "" then
		locale = LocalizationService.RobloxLocaleId
	end
	if locale == nil or locale == "" then
		locale = LocalizationService.SystemLocaleId
	end
	return Texts.languageFor(locale)
end

local Lang = {}

Lang.language = readLanguage()

-- Calls `callback(newLanguage)` when the player switches to another language while
-- playing. The UI is built in the language read at join, so callers only tell the player
-- to rejoin (Lang.language stays as it is).
function Lang.onLanguageChanged(callback: (Texts.Language) -> ())
	local last = Lang.language
	local function check()
		local now = readLanguage()
		if now ~= last then
			last = now
			callback(now)
		end
	end
	local player = Players.LocalPlayer
	if player then
		player:GetPropertyChangedSignal("LocaleId"):Connect(check)
	end
	LocalizationService:GetPropertyChangedSignal("RobloxLocaleId"):Connect(check)
end

-- Text for `key` with its {placeholders} filled from `params`.
function Lang.t(key: string, params: Texts.Params?): string
	return Texts.format(Lang.language, key, params)
end

-- Sign text (#71): `args` as stored by the server (see Texts.render).
function Lang.render(key: string, args: Texts.SignArgs?): string
	return Texts.render(Lang.language, key, args)
end

-- Name of a GameConfig entry (pet, topping, world, egg, potion, upgrade, shop, rarity, #68).
function Lang.name(entry: Texts.Named): string
	return Texts.name(Lang.language, entry)
end

-- Name of the world or event island with this id (the id itself if there is none).
function Lang.worldName(worldId: string): string
	for _, world in GameConfig.worlds do
		if world.id == worldId then
			return Lang.name(world)
		end
	end
	for _, world in GameConfig.eventWorlds do
		if world.id == worldId then
			return Lang.name(world)
		end
	end
	return worldId
end

-- Description of a potion or upgrade.
function Lang.description(entry: Texts.Named): string
	return Texts.description(Lang.language, entry)
end

-- "1,5 Mio" / "1.5M" (whole numbers below a million).
function Lang.shortNumber(value: number): string
	return Texts.shortNumber(Lang.language, value)
end

-- "1.234.567" / "1,234,567".
function Lang.integer(value: number): string
	return Texts.integer(Lang.language, value)
end

-- Roblox must not machine-translate our texts on top (#65): every ScreenGui in PlayerGui
-- and every BillboardGui/SurfaceGui in Workspace gets AutoLocalize = false (it covers
-- all their descendants).
function Lang.stopAutoTranslate()
	local function apply(instance: Instance)
		if instance:IsA("LayerCollector") then
			instance.AutoLocalize = false
		end
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, container in { playerGui, Workspace } do
		container.DescendantAdded:Connect(apply)
		for _, instance in container:GetDescendants() do
			apply(instance)
		end
	end
end

return Lang
