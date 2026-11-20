--!strict
-- All UI texts in German and English, plus number formatting per language (#65, #67).
-- Pure Luau without Roblox API (tested with Lune). The client picks the language once
-- (src/client/Lang.luau) and asks here for formatted texts.
--
-- New text: add a key below with `de` and `en`. Placeholders are written `{name}` and
-- must be the same in both languages (tests/Texts.spec.luau checks this). Numbers are
-- formatted by the caller (Lang.shortNumber) before they go in as a placeholder value.

export type Language = "de" | "en"
export type Entry = { de: string, en: string }
export type Params = { [string]: any }

local Texts = {}

Texts.strings = {
	-- HUD
	["hud.pizza"] = { de = "Pizza {count}/{capacity}", en = "Pizza {count}/{capacity}" },
	["hud.pizzaFull"] = { de = "Pizza VOLL {count}/{capacity}", en = "Pizza FULL {count}/{capacity}" },
	["hud.autoCollectOn"] = { de = "Auto-Sammeln: AN", en = "Auto-Collect: ON" },
	["hud.autoCollectOff"] = { de = "Auto-Sammeln: AUS", en = "Auto-Collect: OFF" },

	-- Unlock button at a world barrier
	["unlock.open"] = {
		de = "🔓 {world} freischalten\n{price} Münzen",
		en = "🔓 Unlock {world}\n{price} coins",
	},
	["unlock.locked"] = {
		de = "🔒 {world}: {condition}\n{price} Münzen",
		en = "🔒 {world}: {condition}\n{price} coins",
	},
	["unlock.rebirthsOne"] = { de = "Ab {count} Rebirth", en = "From {count} rebirth" },
	["unlock.rebirthsMany"] = { de = "Ab {count} Rebirths", en = "From {count} rebirths" },

	-- Side buttons (left HUD column)
	["side.pets"] = { de = "Pets", en = "Pets" },
	["side.potions"] = { de = "Tränke", en = "Potions" },
	["side.gifts"] = { de = "Geschenke", en = "Gifts" },
	["side.rebirth"] = { de = "Rebirth", en = "Rebirth" },
	["side.giftsReady"] = { de = "Abholen!", en = "Claim!" },
	["side.giftsTomorrow"] = { de = "Morgen", en = "Tomorrow" },
	["side.giftsNote"] = { de = "Neu! Geschenke fürs Spielen", en = "New! Gifts for playing" },
	["side.rebirthNote"] = { de = "Neu! Mehr Münzen", en = "New! More coins" },

	-- Messages (toasts); notify.<Kind> matches the Notify kinds the server sends
	["notify.PizzaFull"] = { de = "Pizza voll! Ab zum Ofen.", en = "Pizza full! Off to the oven." },
	["notify.OutOfRange"] = { de = "Zu weit weg!", en = "Too far away!" },
	["notify.NotEnoughCoins"] = { de = "Nicht genug Münzen!", en = "Not enough coins!" },
	["notify.WorldLocked"] = { de = "Diese Welt ist noch gesperrt!", en = "This world is still locked!" },
	["notify.PreviousWorldLocked"] = {
		de = "Erst die vorige Welt freischalten!",
		en = "Unlock the previous world first!",
	},
	["notify.NotEnoughRebirths"] = { de = "Dafür brauchst du mehr Rebirths!", en = "You need more rebirths for that!" },
	["notify.WorldUnlocked"] = { de = "Neue Welt freigeschaltet!", en = "New world unlocked!" },
	["notify.InventoryFull"] = {
		de = "Pet-Inventar voll! Lösche erst ein Pet.",
		en = "Pet inventory full! Delete a pet first.",
	},
	["notify.NotEnoughGems"] = { de = "Nicht genug Gems!", en = "Not enough gems!" },
	["notify.PhoneRinging"] = { de = "📞 Das Telefon klingelt!", en = "📞 The phone is ringing!" },
	["notify.OrderAccepted"] = {
		de = "Auftrag angenommen! Beläge sammeln, dann zum 🚚.",
		en = "Order accepted! Collect the toppings, then go to the 🚚.",
	},
	["notify.OrderDeclined"] = { de = "Auftrag abgelehnt.", en = "Order declined." },
	["notify.OrderExpired"] = { de = "Zeit um – der Auftrag ist verfallen.", en = "Time's up – the order expired." },
	["notify.WrongToppings"] = {
		de = "Falsche Beläge! Überzählige am Ofen verkaufen.",
		en = "Wrong toppings! Sell the extra ones at the oven.",
	},
	["notify.NoOrder"] = { de = "Kein Auftrag – geh ans Telefon!", en = "No order – answer the phone!" },
	["notify.PhoneCallsOff"] = {
		de = "📵 Keine Anrufe mehr. Am Telefon wieder einschalten.",
		en = "📵 No more calls. Turn them back on at the phone.",
	},
	["notify.PhoneCallsOn"] = { de = "📞 Anrufe sind wieder an.", en = "📞 Calls are back on." },
	["notify.sold"] = { de = "+{amount} Münzen", en = "+{amount} coins" },
	["notify.gems"] = { de = "+{amount} Gems!", en = "+{amount} gems!" },
	["notify.deliveredCoins"] = { de = "Geliefert! +{amount} Münzen", en = "Delivered! +{amount} coins" },
	["notify.deliveredGems"] = { de = "Geliefert! +{amount} Gems", en = "Delivered! +{amount} gems" },
	["notify.deliveredPotion"] = { de = "Geliefert! +{amount}× {potion}", en = "Delivered! +{amount}× {potion}" },
	["notify.potionExpired"] = { de = "{potion} ist abgelaufen.", en = "{potion} has run out." },
	["notify.potionDrunk"] = { de = "{potion} wirkt 10 Minuten!", en = "{potion} works for 10 minutes!" },
} :: { [string]: Entry }

-- Locale id ("de-de", "en-us", ...) → language: every German locale is German, all else English.
function Texts.languageFor(localeId: string?): Language
	if type(localeId) == "string" then
		local prefix = string.lower(string.match(localeId, "^%a+") or "")
		if prefix == "de" then
			return "de"
		end
	end
	return "en"
end

-- Names of the {placeholders} in a text, each once.
function Texts.placeholders(text: string): { string }
	local names: { string } = {}
	for name in string.gmatch(text, "{(%w+)}") do
		if not table.find(names, name) then
			table.insert(names, name)
		end
	end
	return names
end

-- Text for `key` in `language` with its placeholders filled; unknown keys come back as
-- the key itself (visible in game, so a missing text is noticed), unknown placeholders stay.
function Texts.format(language: Language, key: string, params: Params?): string
	local entry = Texts.strings[key]
	if entry == nil then
		return key
	end
	local text = if language == "de" then entry.de else entry.en
	if params == nil then
		return text
	end
	return (
		string.gsub(text, "{(%w+)}", function(name: string): string?
			local value = params[name]
			return if value == nil then nil else tostring(value)
		end)
	)
end

local SEPARATORS = {
	de = { thousands = ".", decimal = ",", units = { { 1e12, " Bio" }, { 1e9, " Mrd" }, { 1e6, " Mio" } } },
	en = { thousands = ",", decimal = ".", units = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" } } },
}

-- Whole number with thousands separators: "1.234.567" / "1,234,567".
function Texts.integer(language: Language, value: number): string
	local separator = SEPARATORS[language].thousands
	local text = tostring(math.floor(value))
	local grouped = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1" .. separator)))
	if string.sub(grouped, 1, 1) == separator then
		grouped = string.sub(grouped, 2)
	end
	return grouped
end

-- Short number for small labels: up to 999.999 as a whole number, then one decimal
-- (cut, not rounded): German "1,5 Mio", "12 Mrd", "3,4 Bio"; English "1.5M", "12B", "3.4T".
function Texts.shortNumber(language: Language, value: number): string
	local format = SEPARATORS[language]
	for _, unit in format.units do
		if value >= unit[1] then
			local scaled = value / unit[1]
			local text = if scaled >= 100
				then tostring(math.floor(scaled))
				else string.format("%.1f", math.floor(scaled * 10) / 10)
			text = string.gsub(string.gsub(text, "%.0$", ""), "%.", format.decimal)
			return text .. unit[2]
		end
	end
	return Texts.integer(language, value)
end

return Texts
