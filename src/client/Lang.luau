--!strict
-- The player's language on this client (#67): read once from the Roblox account locale
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

local Texts = require(ReplicatedStorage.Shared.Texts)

local function readLanguage(): Texts.Language
	if RunService:IsStudio() then
		local override = Workspace:GetAttribute("Language")
		if override == "de" or override == "en" then
			return override
		end
	end
	local locale = LocalizationService.RobloxLocaleId
	if locale == nil or locale == "" then
		locale = LocalizationService.SystemLocaleId
	end
	return Texts.languageFor(locale)
end

local Lang = {}

Lang.language = readLanguage()

-- Text for `key` with its {placeholders} filled from `params`.
function Lang.t(key: string, params: Texts.Params?): string
	return Texts.format(Lang.language, key, params)
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
