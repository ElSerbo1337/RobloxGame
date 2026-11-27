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
	["hud.friendsBonus"] = {
		de = "👥 {count} Freunde: +{percent} % Münzen",
		en = "👥 {count} friends: +{percent}% coins",
	},
	["hud.friendsBonusOne"] = { de = "👥 1 Freund: +{percent} % Münzen", en = "👥 1 friend: +{percent}% coins" },
	["hud.autoCollectOn"] = { de = "Auto-Sammeln: AN", en = "Auto-Collect: ON" },
	["hud.autoCollectOff"] = { de = "Auto-Sammeln: AUS", en = "Auto-Collect: OFF" },

	-- World intro (#79): camera flight on the first visit of a world.
	["intro.newWorld"] = { de = "Neue Welt!", en = "New world!" },
	["intro.newToppings"] = { de = "Neue Beläge", en = "New toppings" },
	["intro.skipTouch"] = { de = "Tippen zum Überspringen", en = "Tap to skip" },
	["intro.skipMouse"] = { de = "Klicken zum Überspringen", en = "Click to skip" },

	-- Admin panel (#74, only for GameConfig.admin.userIds). admin.action.<id> and
	-- admin.param.<name> for every entry of AdminActions (tests check both exist).
	["admin.title"] = { de = "🛠️ Admin-Panel", en = "🛠️ Admin Panel" },
	["admin.open"] = { de = "🛠️", en = "🛠️" },
	["admin.run"] = { de = "Los", en = "Run" },
	["admin.confirm"] = { de = "Sicher?", en = "Sure?" },
	["admin.hint"] = {
		de = "Nur für dich sichtbar. F2 öffnet/schließt.",
		en = "Only visible to you. F2 opens/closes.",
	},
	["admin.done"] = { de = "✓ {action}", en = "✓ {action}" },
	["admin.failed"] = { de = "✗ {action}: {reason}", en = "✗ {action}: {reason}" },
	["admin.action.addCoins"] = { de = "Münzen geben", en = "Give coins" },
	["admin.action.addGems"] = { de = "Gems geben", en = "Give gems" },
	["admin.action.givePet"] = { de = "Pet geben", en = "Give pet" },
	["admin.action.givePotion"] = { de = "Tränke geben", en = "Give potions" },
	["admin.action.setRebirths"] = { de = "Rebirths setzen", en = "Set rebirths" },
	["admin.action.unlockWorld"] = { de = "Welten freischalten (bis)", en = "Unlock worlds (up to)" },
	["admin.action.setUpgrade"] = { de = "Upgrade-Stufe setzen", en = "Set upgrade level" },
	["admin.action.finishTutorial"] = { de = "Tutorial beenden", en = "Finish tutorial" },
	["admin.action.skipDays"] = { de = "Tage vorspulen (7 = Woche)", en = "Skip days (7 = week)" },
	["admin.action.setCalendarDay"] = {
		de = "Kalendertag heute abholbar (30 = Pet)",
		en = "Calendar day claimable today (30 = pet)",
	},
	["admin.action.giveGoldenToppings"] = { de = "Goldene Beläge auf die Pizza", en = "Golden toppings on pizza" },
	["admin.action.setGoldenChance"] = { de = "Gold-Chance testen (%, 0 = aus)", en = "Test gold chance (%, 0 = off)" },
	["admin.action.resetHints"] = {
		de = "Alle Hinweise wieder zeigen (Rejoin)",
		en = "Show all hints again (rejoin)",
	},
	["admin.action.resetWhatsNew"] = {
		de = "„Was ist neu“ wieder zeigen (Rejoin)",
		en = 'Show "What\'s new" again (rejoin)',
	},
	["admin.action.giveSecretPet"] = { de = "Geheim-Pet geben", en = "Give Secret pet" },
	["admin.action.setSecretChance"] = {
		de = "Geheim-Chance testen (%, 0 = aus)",
		en = "Test Secret chance (%, 0 = off)",
	},
	["admin.action.resetWorldIntros"] = {
		de = "Welt-Intros wieder zeigen",
		en = "Show world intros again",
	},
	["admin.action.givePetVariant"] = { de = "Pet mit Variante geben", en = "Give pet with variant" },
	["admin.action.setShinyChance"] = {
		de = "Shiny-Chance testen (%, 0 = aus)",
		en = "Test shiny chance (%, 0 = off)",
	},
	["admin.action.setPetLevel"] = { de = "Pet-Level setzen", en = "Set pet level" },
	["admin.action.givePetXp"] = {
		de = "Pet-XP geben (ausgerüstete, Minuten Spielzeit)",
		en = "Give pet XP (equipped, minutes of play)",
	},
	["admin.action.resetCodes"] = { de = "Codes zurücksetzen", en = "Reset codes" },
	["admin.action.resetWheelSpins"] = {
		de = "Gratis-Drehungen zurücksetzen",
		en = "Reset free spins",
	},
	["admin.action.spawnMerchant"] = {
		de = "Händler jetzt erscheinen lassen",
		en = "Make the merchant appear now",
	},
	-- Travelling merchant (#107)
	["merchant.title"] = { de = "🐪 Reisender Händler", en = "🐪 Travelling merchant" },
	["merchant.sign"] = { de = "🐪 Reisender Händler", en = "🐪 Travelling merchant" },
	["merchant.prompt"] = { de = "Handeln", en = "Trade" },
	["merchant.soon"] = {
		de = "🐪 Der reisende Händler kommt in {minutes} Min. auf die Spawn-Insel!",
		en = "🐪 The travelling merchant arrives on the spawn island in {minutes} min!",
	},
	["merchant.arrived"] = {
		de = "🐪 Der reisende Händler ist da! Nur 10 Minuten auf der Spawn-Insel.",
		en = "🐪 The travelling merchant is here! Only 10 minutes on the spawn island.",
	},
	["merchant.left"] = { de = "Noch {time}", en = "{time} left" },
	["merchant.away"] = { de = "Der Händler ist weitergezogen.", en = "The merchant has moved on." },
	["merchant.potion"] = { de = "{potion} – halber Preis!", en = "{potion} – half price!" },
	["merchant.egg"] = {
		de = "{egg} – {factor}x Geheim-Chance",
		en = "{egg} – {factor}x Secret chance",
	},
	["merchant.pet"] = { de = "Exklusiv: {pet}", en = "Exclusive: {pet}" },
	["merchant.stock"] = { de = "Noch {left}/{limit}", en = "{left}/{limit} left" },
	["merchant.buy"] = { de = "Kaufen", en = "Buy" },
	["merchant.soldOut"] = { de = "Ausverkauft", en = "Sold out" },
	["merchant.bought"] = { de = "Gekauft: {item}", en = "Bought: {item}" },
	["merchant.fail.MerchantAway"] = { de = "Der Händler ist schon weg.", en = "The merchant is gone." },
	["merchant.fail.NotOffered"] = { de = "Gibt es gerade nicht.", en = "Not on offer right now." },
	["merchant.fail.SoldOut"] = { de = "Für diesen Besuch ausverkauft.", en = "Sold out for this visit." },
	["merchant.fail.NotEnoughGems"] = { de = "Nicht genug Gems.", en = "Not enough gems." },
	["merchant.fail.InventoryFull"] = { de = "Inventar voll.", en = "Inventory full." },
	["merchant.fail.Busy"] = { de = "Einen Moment …", en = "One moment …" },
	["admin.action.completeQuest"] = { de = "Quest abschließen", en = "Complete quest" },
	["admin.action.rerollQuests"] = { de = "Quests neu würfeln", en = "Reroll quests" },
	["admin.action.completePetIndex"] = { de = "Pet-Index einer Welt füllen", en = "Fill a world's pet index" },
	["admin.action.simulateFriends"] = {
		de = "Freunde-Anzahl simulieren (0 = echt)",
		en = "Simulate friend count (0 = real)",
	},
	["admin.action.resetProgress"] = { de = "Spielstand zurücksetzen", en = "Reset progress" },
	["admin.param.amount"] = { de = "Menge", en = "Amount" },
	["admin.param.count"] = { de = "Anzahl", en = "Count" },
	["admin.param.pet"] = { de = "Pet", en = "Pet" },
	["admin.param.potion"] = { de = "Trank", en = "Potion" },
	["admin.param.world"] = { de = "Welt", en = "World" },
	["admin.param.upgrade"] = { de = "Upgrade", en = "Upgrade" },
	["admin.param.level"] = { de = "Stufe", en = "Level" },
	["admin.param.days"] = { de = "Tage", en = "Days" },
	["admin.param.day"] = { de = "Tag", en = "Day" },
	["admin.param.topping"] = { de = "Belag", en = "Topping" },
	["admin.param.friends"] = { de = "Freunde", en = "Friends" },
	["admin.param.percent"] = { de = "Prozent", en = "Percent" },
	["admin.param.variant"] = { de = "Variante", en = "Variant" },
	["admin.param.shiny"] = { de = "Shiny", en = "Shiny" },
	["admin.param.minutes"] = { de = "Minuten", en = "Minutes" },
	["admin.param.petLevel"] = { de = "Pet-Level", en = "Pet level" },
	["admin.param.allPets"] = { de = "Alle Pets (sonst ausgerüstete)", en = "All pets (else equipped)" },
	["admin.param.period"] = { de = "Art", en = "Type" },
	["admin.param.quest"] = { de = "Quest (Nr.)", en = "Quest (no.)" },
	["admin.choice.Daily"] = { de = "Täglich", en = "Daily" },
	["admin.choice.Weekly"] = { de = "Wöchentlich", en = "Weekly" },
	["admin.choice.no"] = { de = "Nein", en = "No" },
	["admin.choice.yes"] = { de = "Ja", en = "Yes" },

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
	-- Feature hints (#113)
	["hint.merge"] = { de = "5 gleiche Pets? Verschmelzen!", en = "5 equal pets? Merge them!" },
	["hint.quests"] = { de = "Neu! Quests mit Belohnungen", en = "New! Quests with rewards" },
	["hint.wheel"] = { de = "Gratis-Drehung bereit!", en = "Free spin ready!" },
	["hint.index"] = { de = "Neu! Sammle alle Pets", en = "New! Collect every pet" },
	["hint.settings"] = { de = "Einstellungen und Codes", en = "Settings and codes" },
	-- Side bar (#75)
	["side.calendar"] = { de = "Kalender", en = "Calendar" },
	["side.worlds"] = { de = "Welten", en = "Worlds" },
	["side.quests"] = { de = "Quests", en = "Quests" },
	["side.index"] = { de = "Index", en = "Index" },
	["side.more"] = { de = "Mehr", en = "More" },
	["side.moreTitle"] = { de = "Mehr Menüs", en = "More menus" },

	-- Messages (toasts); notify.<Kind> matches the Notify kinds the server sends
	-- Shown in the newly chosen language when the player switches languages in the menu.
	["notify.languageChanged"] = {
		de = "Sprache geändert – zum Übernehmen neu beitreten.",
		en = "Language changed – rejoin to apply it.",
	},
	["notify.PizzaFull"] = { de = "Pizza voll! Ab zum Ofen.", en = "Pizza full! Off to the oven." },
	["notify.OutOfRange"] = { de = "Zu weit weg!", en = "Too far away!" },
	["notify.NotEnoughCoins"] = { de = "Nicht genug Münzen!", en = "Not enough coins!" },
	["notify.WorldLocked"] = { de = "Diese Welt ist noch gesperrt!", en = "This world is still locked!" },
	["notify.PreviousWorldLocked"] = {
		de = "Erst die vorige Welt freischalten!",
		en = "Unlock the previous world first!",
	},
	["notify.NotEnoughRebirths"] = { de = "Dafür brauchst du mehr Rebirths!", en = "You need more rebirths for that!" },
	-- Event islands (#77, prepared for event updates)
	["notify.EventClosed"] = { de = "Dieses Event läuft gerade nicht!", en = "This event is not running right now!" },
	["notify.NotEnoughEventCurrency"] = {
		de = "Nicht genug Event-Währung!",
		en = "Not enough event currency!",
	},
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
	-- Golden toppings (#94)
	["notify.soldGolden"] = {
		de = "+{amount} Münzen (✨ {count}× golden)",
		en = "+{amount} coins (✨ {count}× golden)",
	},
	["notify.goldenTopping"] = {
		de = "✨ Goldener Belag: {topping}! 10-facher Wert",
		en = "✨ Golden topping: {topping}! 10x value",
	},
	["notify.gems"] = { de = "+{amount} Gems!", en = "+{amount} gems!" },
	["notify.deliveredCoins"] = { de = "Geliefert! +{amount} Münzen", en = "Delivered! +{amount} coins" },
	["notify.deliveredGems"] = { de = "Geliefert! +{amount} Gems", en = "Delivered! +{amount} gems" },
	["notify.deliveredPotion"] = { de = "Geliefert! +{amount}× {potion}", en = "Delivered! +{amount}× {potion}" },
	["notify.potionExpired"] = { de = "{potion} ist abgelaufen.", en = "{potion} has run out." },
	["notify.potionDrunk"] = { de = "{potion} wirkt 10 Minuten!", en = "{potion} works for 10 minutes!" },
	-- Shop menu (#69)
	["shop.title"] = { de = "Shop", en = "Shop" },
	["shop.coinCounter"] = { de = "Münz-Tresen", en = "Coin counter" },
	["shop.gemCounter"] = { de = "Gem-Tresen", en = "Gem counter" },
	["shop.potionCounter"] = { de = "Gem-Tresen: Tränke (je 10 Min.)", en = "Gem counter: potions (10 min each)" },
	["shop.level"] = { de = "Stufe {level} / {max}", en = "Level {level} / {max}" },
	["shop.priceCoins"] = { de = "{price} Münzen", en = "{price} coins" },
	["shop.priceGems"] = { de = "{price} Gems", en = "{price} gems" },
	["shop.levelLimit"] = { de = "Weitere Stufen im größeren Shop", en = "More levels in the bigger shop" },
	["shop.max"] = { de = "MAX", en = "MAX" },
	["shop.minutes"] = { de = "{minutes} Minuten", en = "{minutes} minutes" },
	["shop.owned"] = { de = "Im Inventar: {count}", en = "Owned: {count}" },
	["shop.bought"] = { de = "Gekauft: {item}!", en = "Bought: {item}!" },
	["shop.boughtPotion"] = {
		de = "Gekauft: {item}! – im Trank-Menü trinken",
		en = "Bought: {item}! – drink it in the potion menu",
	},
	["shop.failed"] = { de = "Kauf nicht möglich.", en = "Can't buy that." },
	["shop.ShopLevelLimit"] = {
		de = "Diese Stufe gibt es nur im größeren Shop.",
		en = "This level is only in the bigger shop.",
	},
	["shop.MaxLevel"] = { de = "Schon auf höchster Stufe!", en = "Already at the highest level!" },
	["shop.effectToppings"] = { de = "{value} Beläge", en = "{value} toppings" },
	["shop.effectStuds"] = { de = "{value} Studs", en = "{value} studs" },
	["shop.effectPets"] = { de = "{value} Pets", en = "{value} pets" },
	["shop.effectSlots"] = { de = "{value} Plätze", en = "{value} slots" },
	["shop.effectSpeed"] = { de = "Tempo {value}", en = "Speed {value}" },
	["shop.effectOn"] = { de = "an", en = "on" },
	["shop.effectOff"] = { de = "aus", en = "off" },
	["shop.effectGoldChance"] = { de = "{value} % Gold-Chance", en = "{value}% gold chance" },

	-- Pet menu (#69)
	["pets.title"] = { de = "Meine Pets", en = "My pets" },
	["pets.deleteTitle"] = { de = "Pet zum Löschen antippen", en = "Tap a pet to delete it" },
	["pets.equipBest"] = { de = "Beste ausrüsten", en = "Equip best" },
	["pets.delete"] = { de = "Löschen", en = "Delete" },
	["pets.done"] = { de = "Fertig", en = "Done" },
	["pets.keep"] = { de = "Behalten", en = "Keep" },
	["pets.equip"] = { de = "Ausrüsten", en = "Equip" },
	["pets.unequip"] = { de = "Ablegen", en = "Unequip" },
	["pets.empty"] = { de = "Noch keine Pets – öffne ein Ei!", en = "No pets yet – open an egg!" },
	["pets.confirmDelete"] = { de = "{pet} ({bonus}) wirklich löschen?", en = "Really delete {pet} ({bonus})?" },
	["pets.confirmDeleteEquipped"] = {
		de = "{pet} ({bonus}) wirklich löschen? Es wird dabei abgelegt.",
		en = "Really delete {pet} ({bonus})? It will be unequipped.",
	},
	["pets.summary"] = {
		de = "Ausgerüstet {equipped}/{slots}  ·  Inventar {count}/{inventory}  ·  Bonus {bonus}",
		en = "Equipped {equipped}/{slots}  ·  Inventory {count}/{inventory}  ·  Bonus {bonus}",
	},
	["pets.slotsFull"] = {
		de = "Alle Pet-Plätze belegt – erst ein Pet ablegen!",
		en = "All pet slots taken – unequip a pet first!",
	},
	-- Pet variants and Shiny (#80). pets.variant.<id> for GameConfig.petVariants.order.
	["pets.variant.Normal"] = { de = "Normal", en = "Normal" },
	["pets.variant.Gold"] = { de = "Gold", en = "Gold" },
	["pets.variant.Rainbow"] = { de = "Regenbogen", en = "Rainbow" },
	-- Pet names with variant/shiny: {pet} = the pet's name.
	["pets.name.Gold"] = { de = "Gold-{pet}", en = "Golden {pet}" },
	["pets.name.Rainbow"] = { de = "Regenbogen-{pet}", en = "Rainbow {pet}" },
	["pets.name.shiny"] = { de = "✨ {pet}", en = "✨ {pet}" },
	["pets.shiny"] = { de = "✨ Shiny", en = "✨ Shiny" },
	-- Merge button on the pet card: pets.merge.<target variant>.
	["pets.merge.Gold"] = { de = "Vergolden ({have}/{need})", en = "Make gold ({have}/{need})" },
	["pets.merge.Rainbow"] = { de = "Regenbogen ({have}/{need})", en = "Rainbow ({have}/{need})" },
	["pets.merged"] = { de = "{pet} entstanden! {bonus}", en = "{pet} created! {bonus}" },
	["notify.NotEnoughPets"] = { de = "Dafür brauchst du mehr gleiche Pets!", en = "You need more equal pets!" },
	["notify.MaxVariant"] = { de = "Stärker geht es nicht!", en = "It can't get any stronger!" },
	-- Pet levels (#90): badge on the pet card, toast on a level up.
	["pets.level"] = { de = "Lv. {level}", en = "Lv. {level}" },
	["pets.levelMax"] = { de = "Lv. {level} MAX", en = "Lv. {level} MAX" },
	["pets.mergedLevel"] = {
		de = "{pet} entstanden! {bonus} · Lv. {level}",
		en = "{pet} created! {bonus} · Lv. {level}",
	},
	["notify.petLevelUp"] = { de = "⬆ {pet} ist jetzt Level {level}!", en = "⬆ {pet} is now level {level}!" },
	["notify.petLevelMax"] = {
		de = "⭐ {pet} hat Level {level} erreicht – Maximum!",
		en = "⭐ {pet} reached level {level} – the maximum!",
	},
	["notify.InvalidLevel"] = { de = "Dieses Level gibt es nicht.", en = "That level doesn't exist." },
	-- Pet management (#91): selection mode, lock, teams, rename, detail card, auto-delete.
	["pets.selectTitle"] = { de = "Pets zum Löschen auswählen", en = "Select pets to delete" },
	["pets.select"] = { de = "Auswählen", en = "Select" },
	["pets.selected"] = { de = "✓ Gewählt", en = "✓ Selected" },
	["pets.lockedShort"] = { de = "🔒 Gesperrt", en = "🔒 Locked" },
	["pets.deleteSelected"] = { de = "🗑 Löschen ({count})", en = "🗑 Delete ({count})" },
	["pets.confirmDeleteOne"] = { de = "1 Pet wirklich löschen?", en = "Really delete 1 pet?" },
	["pets.confirmDeleteMany"] = { de = "{count} Pets wirklich löschen?", en = "Really delete {count} pets?" },
	["pets.lock"] = { de = "🔒 Sperren", en = "🔒 Lock" },
	["pets.unlock"] = { de = "🔓 Entsperren", en = "🔓 Unlock" },
	["pets.team.name"] = { de = "Team {n} ({count})", en = "Team {n} ({count})" },
	["pets.team.empty"] = { de = "Team {n} +", en = "Team {n} +" },
	["pets.team.saveTo"] = { de = "💾 Team {n}", en = "💾 Team {n}" },
	["pets.team.save"] = { de = "💾 Speichern", en = "💾 Save" },
	["pets.team.cancel"] = { de = "Abbrechen", en = "Cancel" },
	["pets.rename.placeholder"] = { de = "Neuer Name (max. {max})", en = "New name (max. {max})" },
	["pets.rename.ok"] = { de = "✏ Name", en = "✏ Name" },
	["pets.rename.sent"] = { de = "Name wird geprüft …", en = "Checking the name …" },
	["pets.detail.level"] = { de = "Lv. {level} · {xp}/{need} XP", en = "Lv. {level} · {xp}/{need} XP" },
	["pets.detail.world"] = { de = "Welt: {world}", en = "World: {world}" },
	["pets.detail.noWorld"] = { de = "Besonderes Pet", en = "Special pet" },
	["pets.detail.found"] = { de = "Gefunden am {date}", en = "Found on {date}" },
	["pets.detail.foundUnknown"] = { de = "unbekannt", en = "unknown" },
	["pets.detail.count"] = { de = "Du hast {count}× {pet}", en = "You have {count}× {pet}" },
	["egg.autoDeleteHint"] = {
		de = "Pet antippen = Seltenheit beim Schlüpfen löschen 🗑",
		en = "Tap a pet = delete that rarity when hatching 🗑",
	},
	["egg.autoDeleted"] = { de = "🗑 Auto-gelöscht", en = "🗑 Auto-deleted" },
	["notify.PetLocked"] = { de = "Gesperrte Pets kann man nicht löschen!", en = "Locked pets can't be deleted!" },
	["notify.IndexWorldComplete"] = {
		de = "📖 Index komplett: {world}! +{percent} % Münzen",
		en = "📖 Index complete: {world}! +{percent}% coins",
	},
	["notify.IndexComplete"] = { de = "Schon alle gefunden.", en = "All found already." },
	["notify.EmptyTeam"] = {
		de = "Dieses Team ist leer – erst speichern!",
		en = "This team is empty – save it first!",
	},
	["notify.InvalidName"] = {
		de = "Dieser Name geht nicht (zu lang oder ungültige Zeichen).",
		en = "That name doesn't work (too long or invalid characters).",
	},
	["notify.FilterFailed"] = {
		de = "Name konnte nicht geprüft werden – versuch es gleich nochmal.",
		en = "Couldn't check the name – try again in a moment.",
	},

	-- Egg panel, egg animation and pet card (#69)
	["egg.luck"] = { de = "{egg} 🍀 Glück!", en = "{egg} 🍀 Luck!" },
	-- Effective chances (#93): title with the icons of potions raising a chance, Shiny row.
	["egg.boosted"] = { de = "{egg} {icons} aktiv!", en = "{egg} {icons} active!" },
	["egg.shinyName"] = { de = "✨ Shiny", en = "✨ Shiny" },
	["egg.shinyEvery"] = { de = "je Pet", en = "per pet" },
	-- Secret pets (#81): hidden row in the egg preview, hatch card and global banner.
	["egg.secretName"] = { de = "??? (Geheim)", en = "??? (Secret)" },
	["egg.secretOdds"] = { de = "1 : {odds}", en = "1 in {odds}" },
	["egg.secretHatched"] = { de = "🤫 GEHEIM!", en = "🤫 SECRET!" },
	-- Shiny pets (#80): hatch card title.
	["egg.shinyHatched"] = { de = "✨ SHINY!", en = "✨ SHINY!" },
	-- Juice (#110): big coloured number when a pizza is sold.
	["juice.saleNumber"] = { de = "+{amount}", en = "+{amount}" },
	["announce.secret"] = {
		de = "🌟 {player} hat {pet} geschlüpft! (Geheim)",
		en = "🌟 {player} hatched {pet}! (Secret)",
	},
	["egg.openOne"] = { de = "1 öffnen – {price}", en = "Open 1 – {price}" },
	["egg.openOneCoins"] = { de = "1 öffnen – {price} Münzen", en = "Open 1 – {price} coins" },
	["egg.openThree"] = { de = "3 öffnen – {price}", en = "Open 3 – {price}" },
	["egg.notEnoughCoins"] = { de = "Zu wenig Münzen!", en = "Not enough coins!" },
	["egg.inventoryFull"] = { de = "Inventar voll!", en = "Inventory full!" },
	["egg.bonus"] = { de = "{bonus} Münzen", en = "{bonus} coins" },
	["egg.tapToClose"] = { de = "Tippen zum Schließen", en = "Tap to close" },

	-- Tutorial card (#69); tutorial.<StepId> matches the steps in GameConfig
	["tutorial.step"] = { de = "Tutorial – Schritt {number}/{total}", en = "Tutorial – step {number}/{total}" },
	["tutorial.CollectToppings"] = {
		de = "Sammle {goal} Beläge ein ({progress}/{goal}) – tippe sie an oder lauf mit Auto-Sammeln drüber!",
		en = "Collect {goal} toppings ({progress}/{goal}) – tap them or walk over them with Auto-Collect!",
	},
	["tutorial.SellPizza"] = {
		de = "Lauf in die Zone am Ofen und verkaufe deine Pizza!",
		en = "Walk into the zone at the oven and sell your pizza!",
	},
	["tutorial.BuyUpgrade"] = {
		de = "Kauf im Shop dein erstes Upgrade! Zu wenig Münzen? Sammeln und verkaufen.",
		en = "Buy your first upgrade in the shop! Not enough coins? Collect and sell.",
	},
	["tutorial.OpenEgg"] = {
		de = "Öffne am Ei dein erstes Pet! Pets bringen mehr Münzen.",
		en = "Open your first pet at the egg! Pets bring more coins.",
	},
	["tutorial.doneTitle"] = { de = "Tutorial geschafft!", en = "Tutorial complete!" },
	["tutorial.doneBody"] = {
		de = "Viel Spaß beim Pizza-Belegen! Neue Welten warten hinter den Barrieren.",
		en = "Have fun topping pizzas! New worlds await behind the barriers.",
	},
	-- Shared
	["common.notNow"] = { de = "Geht gerade nicht.", en = "Not possible right now." },

	-- Rewards (gifts, calendar)
	["reward.gems"] = { de = "{amount} Gems", en = "{amount} gems" },
	["reward.potionOne"] = { de = "1 Trank", en = "1 potion" },
	["reward.potionMany"] = { de = "{count} Tränke", en = "{count} potions" },
	["reward.pet"] = { de = "Pet", en = "Pet" },

	-- Potion menu
	["potions.title"] = { de = "Meine Tränke", en = "My potions" },
	["potions.hint"] = {
		de = "Gleiche Art nochmal trinken verlängert die Zeit.",
		en = "Drinking the same kind again adds more time.",
	},
	["potions.drink"] = { de = "Trinken", en = "Drink" },
	["potions.owned"] = { de = "Im Inventar: {count}", en = "Owned: {count}" },
	["potions.running"] = { de = "Läuft: {time}", en = "Active: {time}" },
	["potions.effectCoins"] = { de = "Münzen ×2", en = "Coins ×2" },
	["potions.effectLuck"] = { de = "Glück", en = "Luck" },
	["potions.effectSpeed"] = { de = "Speed", en = "Speed" },
	["potions.effectShiny"] = { de = "Shiny ×2", en = "Shiny ×2" },
	["potions.effectGold"] = { de = "Gold ×2", en = "Gold ×2" },
	["potions.effectMega"] = { de = "Mega 💰🍀⚡", en = "Mega 💰🍀⚡" },
	["potions.coveredBy"] = { de = "Aktiv durch {potion}", en = "Active via {potion}" },
	["potions.FeatureOff"] = {
		de = "Dieser Trank ist gerade nicht verfügbar.",
		en = "This potion is not available right now.",
	},
	["potions.drunk"] = { de = "{potion} getrunken!", en = "{potion} drunk!" },
	["potions.expired"] = { de = "{potion} ist abgelaufen.", en = "{potion} has run out." },
	["potions.NoPotion"] = {
		de = "Davon hast du keinen Trank – kauf einen im Gem-Tresen!",
		en = "You have none of these – buy one at the gem counter!",
	},
	["potions.UnknownPotion"] = { de = "Diesen Trank gibt es nicht.", en = "This potion does not exist." },

	-- Gift menu
	["gifts.title"] = { de = "Geschenke", en = "Gifts" },
	["gifts.calendar"] = { de = "📅 Kalender", en = "📅 Calendar" },
	["gifts.minutes"] = { de = "{minutes} Min", en = "{minutes} min" },
	["gifts.claim"] = { de = "Abholen", en = "Claim" },
	["gifts.hint"] = {
		de = "Spiel jeden Tag – jedes Geschenk einmal pro Tag.",
		en = "Play every day – each gift once per day.",
	},
	["gifts.claimed"] = { de = "Geschenk! +{rewards}", en = "Gift! +{rewards}" },
	["gifts.GiftNotReady"] = {
		de = "Noch nicht – spiel noch ein bisschen weiter!",
		en = "Not yet – keep playing a little longer!",
	},
	["gifts.GiftClaimed"] = {
		de = "Dieses Geschenk hast du heute schon abgeholt.",
		en = "You already claimed this gift today.",
	},
	["gifts.UnknownGift"] = { de = "Dieses Geschenk gibt es nicht.", en = "This gift does not exist." },

	-- Lucky wheel (#98)
	["side.wheel"] = { de = "Glücksrad", en = "Lucky wheel" },
	["side.wheelFree"] = { de = "Gratis!", en = "Free!" },
	["wheel.title"] = { de = "🎡 Glücksrad", en = "🎡 Lucky wheel" },
	["wheel.spinFree"] = { de = "Gratis drehen!", en = "Spin for free!" },
	["wheel.spinFreeCount"] = { de = "Gratis drehen! ({count})", en = "Spin for free! ({count})" },
	["wheel.spinPaid"] = { de = "Drehen: {price}", en = "Spin: {price}" },
	["wheel.spinning"] = { de = "Dreht…", en = "Spinning…" },
	["wheel.bonusIn"] = {
		de = "Noch {time} spielen: 1 Gratis-Drehung mehr",
		en = "Play {time} more: 1 more free spin",
	},
	["wheel.freeLeft"] = { de = "Gratis-Drehungen heute: {left}/{total}", en = "Free spins today: {left}/{total}" },
	["wheel.noFreeLeft"] = { de = "Morgen gibt's wieder eine gratis.", en = "Another free spin tomorrow." },
	["wheel.jackpot"] = { de = "JACKPOT!", en = "JACKPOT!" },
	["wheel.won"] = { de = "Gewonnen: +{rewards}", en = "You won: +{rewards}" },
	["wheel.chance"] = { de = "{percent} %", en = "{percent}%" },
	["wheel.coinsMinutes"] = { de = "{minutes} Min Münzen", en = "{minutes} min of coins" },
	["wheel.NoFreeSpin"] = {
		de = "Keine Gratis-Drehung mehr – nochmal für Gems?",
		en = "No free spin left – spin again for gems?",
	},
	["wheel.NotEnoughGems"] = { de = "Nicht genug Gems!", en = "Not enough gems!" },
	["wheel.Busy"] = { de = "Das Rad dreht noch.", en = "The wheel is still spinning." },
	["sign.wheel"] = { de = "🎡 Glücksrad", en = "🎡 Lucky wheel" },
	["sign.wheelPrompt"] = { de = "Drehen", en = "Spin" },
	["sign.wheelCoins"] = { de = "🪙 {minutes} Min", en = "🪙 {minutes} min" },
	["sign.wheelGems"] = { de = "💎 {amount}", en = "💎 {amount}" },
	["sign.wheelPotions"] = { de = "🧪 {amount}", en = "🧪 {amount}" },
	["sign.wheelJackpot"] = { de = "⭐ JACKPOT", en = "⭐ JACKPOT" },
	["reward.coins"] = { de = "{amount} Münzen", en = "{amount} coins" },

	-- Login calendar
	-- Quests (#97): menu, quest kinds (goal = formatted amount), rule refusals.
	["quests.title"] = { de = "📜 Quests", en = "📜 Quests" },
	-- Pet index and topping index (#95)
	["index.title"] = { de = "📖 Index", en = "📖 Index" },
	["index.tabPets"] = { de = "🐾 Pets", en = "🐾 Pets" },
	["index.tabToppings"] = { de = "🍕 Beläge", en = "🍕 Toppings" },
	["index.found"] = { de = "{found}/{total} gefunden", en = "{found}/{total} found" },
	["index.bonusTotal"] = { de = "Index-Bonus: +{percent} % Münzen", en = "Index bonus: +{percent}% coins" },
	["index.worldPage"] = { de = "Welt {number}: {world}", en = "World {number}: {world}" },
	["index.worldComplete"] = { de = "✅ Komplett: +{percent} % Münzen", en = "✅ Complete: +{percent}% coins" },
	["index.worldReward"] = { de = "Alle finden: +{percent} % Münzen", en = "Find all: +{percent}% coins" },
	["index.stars"] = { de = "⭐ {found}/{total}", en = "⭐ {found}/{total}" },
	["index.petsHint"] = {
		de = "Sterne für Gold, Regenbogen und Shiny (ohne Belohnung)",
		en = "Stars for Gold, Rainbow and Shiny (no reward)",
	},
	["index.toppingsHint"] = {
		de = "Sammle jeden Belag normal und golden",
		en = "Collect every topping normal and golden",
	},
	["index.unknown"] = { de = "???", en = "???" },
	["index.normal"] = { de = "Normal", en = "Normal" },
	["index.golden"] = { de = "✨ Gold", en = "✨ Golden" },
	["index.previous"] = { de = "◀", en = "◀" },
	["index.next"] = { de = "▶", en = "▶" },
	["quests.hint"] = {
		de = "Schaff alle 3 Tagesquests für die Bonus-Truhe!",
		en = "Finish all 3 daily quests for the bonus chest!",
	},
	["quests.daily"] = { de = "Täglich – neu in {time}", en = "Daily – new in {time}" },
	["quests.weekly"] = { de = "Wöchentlich – neu in {time}", en = "Weekly – new in {time}" },
	["quests.timeDays"] = { de = "{days} T {hours} h", en = "{days} d {hours} h" },
	["quests.timeHours"] = { de = "{hours} h {minutes} min", en = "{hours} h {minutes} min" },
	["quests.timeMinutes"] = { de = "{minutes} min", en = "{minutes} min" },
	["quests.claim"] = { de = "Abholen", en = "Claim" },
	["quests.open"] = { de = "Öffnen", en = "Open" },
	["quests.rerollFree"] = { de = "🎲 Gratis", en = "🎲 Free" },
	["quests.reroll"] = { de = "🎲 {gems} 💎", en = "🎲 {gems} 💎" },
	["quests.bonus"] = { de = "🎁 Bonus-Truhe: {rewards}", en = "🎁 Bonus chest: {rewards}" },
	["quests.streak"] = {
		de = "🔥 Serie {days}/{goal} Tage: {rewards}",
		en = "🔥 Streak {days}/{goal} days: {rewards}",
	},
	["quests.done"] = { de = "Quest geschafft! Hol dir die Belohnung.", en = "Quest done! Claim your reward." },
	["quests.claimed"] = { de = "+{rewards}", en = "+{rewards}" },
	["quests.streakClaimed"] = { de = "Serien-Truhe! +{rewards}", en = "Streak chest! +{rewards}" },
	["quests.rerolled"] = { de = "Neue Quest gewürfelt!", en = "New quest rolled!" },
	["quests.QuestNotDone"] = { de = "Diese Quest ist noch nicht geschafft.", en = "This quest is not done yet." },
	["quests.QuestClaimed"] = { de = "Schon abgeholt.", en = "Already claimed." },
	["quests.QuestsExpired"] = { de = "Neue Quests sind da!", en = "New quests are here!" },
	["quests.QuestDone"] = {
		de = "Geschaffte Quests kann man nicht tauschen.",
		en = "Finished quests cannot be swapped.",
	},
	["quests.BonusNotReady"] = { de = "Erst alle Tagesquests schaffen.", en = "Finish all daily quests first." },
	["quests.BonusClaimed"] = { de = "Die Bonus-Truhe ist schon offen.", en = "The bonus chest is already open." },
	["quests.NoOtherQuest"] = { de = "Gerade keine andere Quest da.", en = "No other quest right now." },
	["quests.NotEnoughGems"] = { de = "Nicht genug Gems.", en = "Not enough gems." },
	["quests.kind.CollectToppings"] = { de = "Sammle {goal} Beläge", en = "Collect {goal} toppings" },
	["quests.kind.SellPizzas"] = { de = "Verkaufe {goal} Pizzen", en = "Sell {goal} pizzas" },
	["quests.kind.OpenEggs"] = { de = "Öffne {goal} Eier", en = "Open {goal} eggs" },
	["quests.kind.Deliveries"] = { de = "Liefere {goal} Bestellungen aus", en = "Deliver {goal} orders" },
	["quests.kind.EarnCoins"] = { de = "Verdiene {goal} Münzen", en = "Earn {goal} coins" },
	["quests.kind.PlayMinutes"] = { de = "Spiele {goal} Minuten", en = "Play for {goal} minutes" },
	["quests.kind.MergePets"] = { de = "Verschmelze {goal}× Pets", en = "Merge pets {goal}×" },
	["quests.kind.GoldenToppings"] = { de = "Finde {goal} goldene Beläge", en = "Find {goal} golden toppings" },
	["quests.kind.SpinWheel"] = { de = "Drehe {goal}× am Glücksrad", en = "Spin the lucky wheel {goal}×" },
	["quests.kind.OpenChest"] = { de = "Öffne {goal} geheime Truhe(n)", en = "Open {goal} hidden chest(s)" },
	["quests.kind.UnlockWorld"] = { de = "Schalte eine neue Welt frei", en = "Unlock a new world" },
	["calendar.title"] = { de = "Login-Kalender", en = "Login calendar" },
	["calendar.day"] = { de = "Tag {day}", en = "Day {day}" },
	["calendar.dayBig"] = { de = "⭐ Tag {day}", en = "⭐ Day {day}" },
	["calendar.petIn"] = {
		de = "Komm morgen wieder! Noch {days} Tage bis {pet}.",
		en = "Come back tomorrow! {days} days to go until {pet}.",
	},
	["calendar.petTomorrow"] = {
		de = "Komm morgen wieder: dann wartet {pet} auf dich!",
		en = "Come back tomorrow: {pet} is waiting for you!",
	},
	["calendar.today"] = { de = "Heute", en = "Today" },
	["calendar.claim"] = { de = "Abholen", en = "Claim" },
	["calendar.tomorrow"] = { de = "Morgen wieder", en = "Back tomorrow" },
	["calendar.ready"] = { de = "Tag {day}: hol dir deine Belohnung!", en = "Day {day}: claim your reward!" },
	["calendar.comeBack"] = {
		de = "Komm morgen wieder – jeden Tag in Folge wird es besser!",
		en = "Come back tomorrow – every day in a row gets better!",
	},
	["calendar.claimed"] = { de = "Tag {day}! +{rewards}", en = "Day {day}! +{rewards}" },
	["calendar.LoginClaimed"] = {
		de = "Heute schon abgeholt – morgen gibt es den nächsten Tag!",
		en = "Already claimed today – the next day comes tomorrow!",
	},

	-- Rebirth menu and celebration
	["rebirth.title"] = { de = "Rebirth", en = "Rebirth" },
	["rebirth.none"] = { de = "Noch kein Rebirth", en = "No rebirth yet" },
	["rebirth.count"] = { de = "Rebirths: {count}", en = "Rebirths: {count}" },
	["rebirth.multiplier"] = { de = "Münzen {now}  →  {next}", en = "Coins {now}  →  {next}" },
	["rebirth.price"] = { de = "Preis: {price} Münzen", en = "Price: {price} coins" },
	["rebirth.progress"] = { de = "{percent} %", en = "{percent}%" },
	["rebirth.info"] = {
		de = "Weg: Münzen, Münz-Upgrades, Welten, Pizza, Auftrag.\nBleibt: Pets, Gems, Gem-Upgrades, Tränke (auch laufende).",
		en = "Lost: coins, coin upgrades, worlds, pizza, order.\nKept: pets, gems, gem upgrades, potions (running ones too).",
	},
	-- Worlds the next rebirth opens (#77); {worlds} = world names, comma-separated.
	["rebirth.opensWorlds"] = { de = "🌍 Öffnet: {worlds}", en = "🌍 Opens: {worlds}" },
	["rebirth.nextTier"] = {
		de = "Öffnet keine neue Welt. Nächste ab {count} Rebirths: {worlds}",
		en = "Opens no new world. Next from {count} rebirths: {worlds}",
	},
	["rebirth.allWorlds"] = { de = "🌍 Alle Welten sind erreichbar.", en = "🌍 Every world is within reach." },
	["rebirth.button"] = { de = "Rebirth!", en = "Rebirth!" },
	["rebirth.yes"] = { de = "Ja, Rebirth!", en = "Yes, rebirth!" },
	["rebirth.no"] = { de = "Nein", en = "No" },
	["rebirth.confirm"] = {
		de = "Rebirth {number} für {price} Münzen?\nDanach: Münzen {multiplier}, Start in Welt 1.",
		en = "Rebirth {number} for {price} coins?\nAfter that: coins {multiplier}, start in world 1.",
	},
	["rebirth.celebration"] = {
		de = "Rebirth {number}! {multiplier} Münzen",
		en = "Rebirth {number}! {multiplier} coins",
	},

	-- Portal menu
	["portal.title"] = { de = "🌀 Teleport", en = "🌀 Teleport" },
	["portal.lockedRebirths"] = {
		de = "🔒 {world} – {condition}\n{price} Münzen",
		en = "🔒 {world} – {condition}\n{price} coins",
	},
	["portal.locked"] = { de = "🔒 {world} – {price} Münzen", en = "🔒 {world} – {price} coins" },
	["portal.here"] = { de = "📍 {world} (du bist hier)", en = "📍 {world} (you are here)" },
	-- Opened from the side bar outside a portal (#75): the list is for viewing only.
	["portal.preview"] = { de = "Zum Reisen in ein Portal stellen", en = "Step into a portal to travel" },

	-- World menu with cards (#78)
	["worldMenu.title"] = { de = "🌍 Welten", en = "🌍 Worlds" },
	["worldMenu.count"] = { de = "{open}/{total} offen", en = "{open}/{total} unlocked" },
	["worldMenu.travel"] = { de = "Reisen", en = "Travel" },
	["worldMenu.here"] = { de = "📍 Du bist hier", en = "📍 You are here" },
	["worldMenu.open"] = { de = "✅ Offen", en = "✅ Unlocked" },
	["worldMenu.canUnlock"] = { de = "Am Tor freischalten", en = "Unlock at the gate" },
	["worldMenu.price"] = { de = "{price} Münzen", en = "{price} coins" },
	["worldMenu.missing"] = { de = "Es fehlt:", en = "Missing:" },
	["worldMenu.missingPrevious"] = { de = "Erst {world}", en = "First {world}" },
	["worldMenu.missingRebirthsOne"] = { de = "{count} Rebirth", en = "{count} rebirth" },
	["worldMenu.missingRebirthsMany"] = { de = "{count} Rebirths", en = "{count} rebirths" },
	["worldMenu.missingCoins"] = { de = "{amount} Münzen", en = "{amount} coins" },

	-- Phone, delivery order and order card
	["delivery.ring"] = { de = "📞 RING!", en = "📞 RING!" },
	["delivery.newOrder"] = { de = "📞 Neuer Auftrag!", en = "📞 New order!" },
	["delivery.phoneTitle"] = { de = "📞 Telefon", en = "📞 Phone" },
	["delivery.noCall"] = {
		de = "Gerade kein Anruf. Nach einer Pause klingelt es wieder, aber nie während eines Auftrags.",
		en = "No call right now. It rings again after a break, but never during an order.",
	},
	["delivery.callsOffTitle"] = { de = "📵 Anrufe sind aus", en = "📵 Calls are off" },
	["delivery.callsOffBody"] = {
		de = "Das Telefon klingelt nicht mehr. Hier kannst du Anrufe wieder einschalten.",
		en = "The phone no longer rings. You can turn calls back on here.",
	},
	["delivery.callsOff"] = { de = "📵 Keine Anrufe mehr", en = "📵 No more calls" },
	["delivery.callsOn"] = { de = "📞 Anrufe einschalten", en = "📞 Turn calls on" },
	["delivery.accept"] = { de = "Annehmen", en = "Accept" },
	["delivery.decline"] = { de = "Ablehnen", en = "Decline" },
	["delivery.maxReward"] = { de = "Belohnung: bis zu {reward}", en = "Reward: up to {reward}" },
	["delivery.timeLimit"] = {
		de = "Zeit: {time} – je schneller, desto mehr!",
		en = "Time: {time} – the faster, the more!",
	},
	["delivery.rewardGems"] = { de = "💎 {amount} Gems", en = "💎 {amount} gems" },
	["delivery.rewardPotion"] = { de = "🧪 {amount}× {potion}", en = "🧪 {amount}× {potion}" },
	["delivery.rewardCoins"] = { de = "💰 {amount} Münzen", en = "💰 {amount} coins" },
	["delivery.potion"] = { de = "Trank", en = "Potion" },
	["delivery.cardHeader"] = { de = "🧾 Auftrag  ⏱ {time}", en = "🧾 Order  ⏱ {time}" },
	["delivery.ringing"] = { de = "📞 Das Telefon klingelt!", en = "📞 The phone is ringing!" },
	["delivery.ringingHint"] = { de = "Lauf zum Telefon und geh ran.", en = "Run to the phone and answer it." },
	["delivery.allThere"] = { de = "Fertig! Ab zum 🚚 Lieferwagen.", en = "Done! Off to the 🚚 delivery van." },
	["delivery.hurry"] = { de = "Schnell = mehr Belohnung!", en = "Fast = more reward!" },

	-- 3D signs built by the server (#71); the server sets key + args on the label
	["sign.oven"] = { de = "Ofen – hier verkaufen", en = "Oven – sell here" },
	["sign.ovenWorld"] = { de = "Ofen ({world}) – hier verkaufen", en = "Oven ({world}) – sell here" },
	["sign.sell"] = { de = "VERKAUFEN", en = "SELL" },
	["sign.shop"] = { de = "SHOP", en = "SHOP" },
	["sign.shopUpgrades"] = { de = "{shop} – Upgrades", en = "{shop} – Upgrades" },
	["sign.gate"] = { de = "🔒 {world}\n{price} Münzen", en = "🔒 {world}\n{price} coins" },
	["sign.gateRebirths"] = {
		de = "🔒 {world}\n{condition}\n{price} Münzen",
		en = "🔒 {world}\n{condition}\n{price} coins",
	},
	["sign.name"] = { de = "{name}", en = "{name}" },
	["sign.egg"] = { de = "{egg}\n💰 {price}", en = "{egg}\n💰 {price}" },
	["sign.eggSoon"] = { de = "Bald: neues Ei!", en = "Coming soon: new egg!" },
	["sign.portal"] = { de = "🌀 Teleport", en = "🌀 Teleport" },
	["sign.phone"] = { de = "📞 Telefon – Aufträge", en = "📞 Phone – Orders" },
	["sign.van"] = { de = "🚚 Lieferwagen – Bestellung abgeben", en = "🚚 Delivery van – hand in order" },
	["sign.orderTicket"] = { de = "🧾 Bestellung", en = "🧾 Order" },

	-- Leaderboard panels (titles by board id from GameConfig.leaderboards)
	["board.Playtime"] = { de = "⏱ Spielzeit", en = "⏱ Playtime" },
	["board.CoinsEarned"] = { de = "💰 Münzen verdient", en = "💰 Coins earned" },
	["board.Rebirths"] = { de = "🔁 Rebirths", en = "🔁 Rebirths" },
	["board.EggsOpened"] = { de = "🥚 Eier geöffnet", en = "🥚 Eggs opened" },
	["board.ToppingsCollected"] = { de = "🍕 Beläge gesammelt", en = "🍕 Toppings collected" },
	["board.colRank"] = { de = "Platz", en = "Rank" },
	["board.colPlayer"] = { de = "Spieler", en = "Player" },
	["board.colEggs"] = { de = "Eier", en = "Eggs" },
	["board.colToppings"] = { de = "Beläge", en = "Toppings" },
	["board.weeklyHint"] = {
		de = "👑 Top 3 der Woche werden Wochen-Champion!",
		en = "👑 This week's top 3 become Weekly Champion!",
	},
	["board.fallbackTitle"] = { de = "Bestenliste", en = "Leaderboard" },
	["board.loading"] = { de = "Bestenliste lädt …", en = "Leaderboard loading …" },
	["board.loadingTitled"] = { de = "{title}\nBestenliste lädt …", en = "{title}\nLeaderboard loading …" },
	-- Spawn marketplace (#106): update board, "What's new" window, Christmas countdown.
	["whatsNew.title"] = { de = "⭐ Neu im Update! ⭐", en = "⭐ New in this update! ⭐" },
	["whatsNew.subtitle"] = { de = "MEGA UPDATE 🌊🌴☁️", en = "MEGA UPDATE 🌊🌴☁️" },
	["whatsNew.list"] = {
		de = "🌍 15 Welten mit Rebirth-Stufen\n✨ Gold-, Regenbogen- und Shiny-Pets\n📜 Tägliche und wöchentliche Quests\n🎡 Glücksrad mit Gratis-Drehs\n📅 30-Tage-Login-Kalender\n🛒 Reisender Händler\n🏆 Neue Bestenlisten, Abzeichen und Titel\n🌦️ Wetter und Tag-Nacht-Wechsel",
		en = "🌍 15 worlds with rebirth tiers\n✨ Gold, Rainbow and Shiny pets\n📜 Daily and weekly quests\n🎡 Lucky wheel with free spins\n📅 30-day login calendar\n🛒 Travelling merchant\n🏆 New leaderboards, badges and titles\n🌦️ Weather and day-night cycle",
	},
	["whatsNew.ok"] = { de = "Los geht's!", en = "Let's go!" },
	["whatsNew.prompt"] = { de = "Lesen", en = "Read" },
	["whatsNew.board"] = { de = "Neu im Update!", en = "New in this update!" },
	["countdown.title"] = { de = "Bald: Weihnachten 🎅", en = "Coming soon: Christmas 🎅" },
	["countdown.days"] = {
		de = "🎄 Weihnachts-Event startet in {days} Tagen",
		en = "🎄 Christmas event starts in {days} days",
	},
	["countdown.tomorrow"] = {
		de = "🎄 Weihnachts-Event startet morgen!",
		en = "🎄 Christmas event starts tomorrow!",
	},
	["board.empty"] = { de = "Noch keine Einträge", en = "No entries yet" },
	["board.number"] = { de = "{value}", en = "{value}" },
	["board.minutes"] = { de = "{minutes} Min.", en = "{minutes} min" },
	["board.hours"] = { de = "{hours} Std. {minutes} Min.", en = "{hours} h {minutes} min" },
	-- Settings menu (#76)
	["side.settings"] = { de = "Optionen", en = "Settings" },
	["settings.title"] = { de = "⚙️ Einstellungen", en = "⚙️ Settings" },
	["settings.sectionSound"] = { de = "🔊 Sound", en = "🔊 Sound" },
	["settings.sectionDisplay"] = { de = "🖥️ Grafik & Kamera", en = "🖥️ Graphics & camera" },
	["settings.sectionGame"] = { de = "🥚 Spiel", en = "🥚 Gameplay" },
	["settings.sectionCodes"] = { de = "🎟️ Codes", en = "🎟️ Codes" },
	["settings.musicVolume"] = { de = "Musik", en = "Music" },
	["settings.effectsVolume"] = { de = "Effekte", en = "Effects" },
	["settings.percent"] = { de = "{value} %", en = "{value}%" },
	["settings.graphics"] = { de = "Grafik", en = "Graphics" },
	["settings.graphicsHigh"] = { de = "Hoch", en = "High" },
	["settings.graphicsLow"] = { de = "Niedrig", en = "Low" },
	["settings.cameraShake"] = { de = "Kamera-Wackeln", en = "Camera shake" },
	["settings.screenFlashes"] = { de = "Bildschirm-Blitze", en = "Screen flashes" },
	["settings.skipEggAnimation"] = { de = "Ei-Animation überspringen", en = "Skip egg animation" },
	["settings.on"] = { de = "AN", en = "ON" },
	["settings.off"] = { de = "AUS", en = "OFF" },
	["codes.placeholder"] = { de = "Code eingeben", en = "Enter code" },
	["codes.redeem"] = { de = "Einlösen", en = "Redeem" },
	["codes.checking"] = { de = "Wird geprüft …", en = "Checking …" },
	["codes.empty"] = { de = "Bitte einen Code eingeben.", en = "Please enter a code." },
	["codes.unavailable"] = { de = "Codes gibt es bald!", en = "Codes are coming soon!" },
	["codes.redeemed"] = { de = "Eingelöst: {rewards}", en = "Redeemed: {rewards}" },
	["codes.Unknown"] = { de = "Diesen Code gibt es nicht.", en = "This code does not exist." },
	["codes.AlreadyUsed"] = { de = "Diesen Code hast du schon benutzt.", en = "You already used this code." },
	["codes.Expired"] = { de = "Dieser Code ist abgelaufen.", en = "This code has expired." },
	["codes.TooManyTries"] = {
		de = "Zu viele Versuche – warte kurz.",
		en = "Too many tries – wait a moment.",
	},
	-- Loading screen (#111, src/first/LoadingScreen.client.luau, tips in LoadingTips).
	["loading.title"] = { de = "Pizza Topping Simulator", en = "Pizza Topping Simulator" },
	["loading.subtitle"] = { de = "🍕 MEGA UPDATE 🍕", en = "🍕 MEGA UPDATE 🍕" },
	["loading.tipLabel"] = { de = "💡 Tipp", en = "💡 Tip" },
	["loading.loading"] = { de = "Lädt …", en = "Loading …" },
	["loading.skip"] = { de = "Tippen zum Überspringen", en = "Tap to skip" },
	["loading.tip.merge"] = {
		de = "5 gleiche Pets verschmelzen zu einem goldenen – 5 goldene zu einem Regenbogen-Pet!",
		en = "Merge 5 equal pets into a golden one – and 5 golden ones into a rainbow pet!",
	},
	["loading.tip.shiny"] = {
		de = "Manchmal schlüpft ein Shiny-Pet: Es glitzert und ist stärker als normal.",
		en = "Sometimes a shiny pet hatches: it sparkles and is stronger than usual.",
	},
	["loading.tip.secret"] = {
		de = "Jede Welt hat ein Geheim-Pet. Wer eins findet, wird allen Servern gezeigt!",
		en = "Every world hides a Secret pet. Hatch one and every server hears about it!",
	},
	["loading.tip.quests"] = {
		de = "Erledige tägliche und wöchentliche Quests für Gems und Bonus-Truhen.",
		en = "Finish daily and weekly quests for gems and bonus chests.",
	},
	["loading.tip.wheel"] = {
		de = "Dreh jeden Tag gratis am Glücksrad auf der Spawn-Insel!",
		en = "Spin the lucky wheel on the spawn island for free every day!",
	},
	["loading.tip.codes"] = {
		de = "Codes löst du in den Optionen ⚙️ ein – halte Ausschau nach neuen!",
		en = "Redeem codes in the options ⚙️ – keep an eye out for new ones!",
	},
	["loading.tip.index"] = {
		de = "Im Index 📖 siehst du, welche Pets und Beläge du schon gefunden hast.",
		en = "The index 📖 shows which pets and toppings you have already found.",
	},
	["loading.tip.petLevels"] = {
		de = "Pets sammeln mit dir Erfahrung und werden mit jedem Level stärker.",
		en = "Pets gain experience with you and get stronger with every level.",
	},
	["loading.tip.potions"] = {
		de = "Neue Tränke: Shiny-, Gold- und Mega-Trank erhöhen dein Glück beim Ausbrüten.",
		en = "New potions: Shiny, Gold and Mega potions boost your luck when hatching.",
	},
	["loading.tip.golden"] = {
		de = "Goldene Beläge sind viel mehr wert – sammle sie, bevor sie jemand anderes holt!",
		en = "Golden toppings are worth much more – grab them before someone else does!",
	},
	["loading.tip.calendar"] = {
		de = "Komm jeden Tag wieder: Der 30-Tage-Kalender hat große Belohnungen.",
		en = "Come back every day: the 30-day calendar has big rewards.",
	},
	["loading.tip.worlds"] = {
		de = "{count} Welten warten auf dich – schaffst du es bis {world}?",
		en = "{count} worlds are waiting for you – can you make it to {world}?",
	},
	["loading.tip.rebirth"] = {
		de = "Ein Rebirth setzt dich zurück, gibt dir aber dauerhaft mehr Münzen.",
		en = "A rebirth resets you, but gives you more coins for good.",
	},
	-- Lifetime stats, badges, profile and titles (#103)
	["badge.Welcome.name"] = { de = "Willkommen!", en = "Welcome!" },
	["badge.Welcome.desc"] = {
		de = "Betritt zum ersten Mal Pizza Topping Simulator.",
		en = "Join Pizza Topping Simulator for the first time.",
	},
	["badge.Coins1K.name"] = { de = "Erste Münzen", en = "First Coins" },
	["badge.Coins1K.desc"] = { de = "Verdiene insgesamt 1.000 Münzen.", en = "Earn 1,000 coins in total." },
	["badge.Coins1M.name"] = { de = "Münz-Millionär", en = "Coin Millionaire" },
	["badge.Coins1M.desc"] = { de = "Verdiene insgesamt 1 Million Münzen.", en = "Earn 1 million coins in total." },
	["badge.Coins1B.name"] = { de = "Münz-Milliardär", en = "Coin Billionaire" },
	["badge.Coins1B.desc"] = { de = "Verdiene insgesamt 1 Milliarde Münzen.", en = "Earn 1 billion coins in total." },
	["badge.Coins1T.name"] = { de = "Pizza-Imperium", en = "Pizza Empire" },
	["badge.Coins1T.desc"] = { de = "Verdiene insgesamt 1 Billion Münzen.", en = "Earn 1 trillion coins in total." },
	["badge.Toppings100.name"] = { de = "Belag-Anfänger", en = "Topping Rookie" },
	["badge.Toppings100.desc"] = { de = "Sammle 100 Beläge.", en = "Collect 100 toppings." },
	["badge.Toppings10K.name"] = { de = "Belag-Jäger", en = "Topping Hunter" },
	["badge.Toppings10K.desc"] = { de = "Sammle 10.000 Beläge.", en = "Collect 10,000 toppings." },
	["badge.Toppings1M.name"] = { de = "Belag-Meister", en = "Topping Master" },
	["badge.Toppings1M.desc"] = { de = "Sammle 1 Million Beläge.", en = "Collect 1 million toppings." },
	["badge.Eggs10.name"] = { de = "Eier-Neuling", en = "Egg Rookie" },
	["badge.Eggs10.desc"] = { de = "Öffne 10 Eier.", en = "Open 10 eggs." },
	["badge.Eggs100.name"] = { de = "Eier-Fan", en = "Egg Fan" },
	["badge.Eggs100.desc"] = { de = "Öffne 100 Eier.", en = "Open 100 eggs." },
	["badge.Eggs1K.name"] = { de = "Eier-Profi", en = "Egg Pro" },
	["badge.Eggs1K.desc"] = { de = "Öffne 1.000 Eier.", en = "Open 1,000 eggs." },
	["badge.Eggs10K.name"] = { de = "Eier-Legende", en = "Egg Legend" },
	["badge.Eggs10K.desc"] = { de = "Öffne 10.000 Eier.", en = "Open 10,000 eggs." },
	["badge.FirstLegendary.name"] = { de = "Erstes Legendär", en = "First Legendary" },
	["badge.FirstLegendary.desc"] = { de = "Finde dein erstes legendäres Pet.", en = "Find your first Legendary pet." },
	["badge.FirstMythic.name"] = { de = "Erstes Mythisch", en = "First Mythic" },
	["badge.FirstMythic.desc"] = { de = "Finde dein erstes mythisches Pet.", en = "Find your first Mythic pet." },
	["badge.FirstShiny.name"] = { de = "Erstes Shiny", en = "First Shiny" },
	["badge.FirstShiny.desc"] = { de = "Finde dein erstes Shiny-Pet.", en = "Find your first Shiny pet." },
	["badge.FirstSecret.name"] = { de = "Erstes Geheim", en = "First Secret" },
	["badge.FirstSecret.desc"] = { de = "Finde dein erstes geheimes Pet.", en = "Find your first Secret pet." },
	["title.Newbie"] = { de = "Pizza-Neuling", en = "Pizza Rookie" },
	["title.Newbie.how"] = { de = "Start", en = "Start" },
	["title.Collector"] = { de = "Belag-Sammler", en = "Topping Collector" },
	["title.Collector.how"] = { de = "Welt 3 erreichen", en = "Reach world 3" },
	["title.OvenPro"] = { de = "Ofen-Profi", en = "Oven Pro" },
	["title.OvenPro.how"] = { de = "Welt 5 erreichen", en = "Reach world 5" },
	["title.Chef"] = { de = "Pizza-Chef", en = "Pizza Chef" },
	["title.Chef.how"] = { de = "1. Rebirth", en = "1st rebirth" },
	["title.MasterChef"] = { de = "Meisterkoch", en = "Master Chef" },
	["title.MasterChef.how"] = { de = "Welt 10 erreichen", en = "Reach world 10" },
	["title.Legend"] = { de = "Pizza-Legende", en = "Pizza Legend" },
	["title.Legend.how"] = { de = "Welt 15 erreichen", en = "Reach world 15" },
	["title.PizzaGod"] = { de = "Pizza-Gott", en = "Pizza God" },
	["title.PizzaGod.how"] = { de = "10 Rebirths", en = "10 rebirths" },
	["title.WeeklyChampion"] = { de = "Wochen-Champion", en = "Weekly Champion" },
	["title.WeeklyChampion.how"] = { de = "Top 3 einer Wochen-Bestenliste", en = "Top 3 of a weekly leaderboard" },
	["side.profile"] = { de = "Profil", en = "Profile" },
	["profile.title"] = { de = "👤 Profil", en = "👤 Profile" },
	["profile.titleOf"] = { de = "👤 {name}", en = "👤 {name}" },
	["profile.tab.stats"] = { de = "Statistiken", en = "Stats" },
	["profile.tab.badges"] = { de = "Badges", en = "Badges" },
	["profile.tab.titles"] = { de = "Titel", en = "Titles" },
	["profile.stat.coinsEarned"] = { de = "💰 Münzen verdient", en = "💰 Coins earned" },
	["profile.stat.toppingsCollected"] = { de = "🍅 Beläge gesammelt", en = "🍅 Toppings collected" },
	["profile.stat.eggsOpened"] = { de = "🥚 Eier geöffnet", en = "🥚 Eggs opened" },
	["profile.stat.playtime"] = { de = "⏱ Spielzeit", en = "⏱ Play time" },
	["profile.stat.rebirths"] = { de = "🔁 Rebirths", en = "🔁 Rebirths" },
	["profile.stat.highestWorld"] = { de = "🌍 Höchste Welt", en = "🌍 Highest world" },
	["profile.stat.petIndex"] = { de = "📖 Pet-Index", en = "📖 Pet index" },
	["profile.stat.toppingIndex"] = { de = "📖 Belag-Index", en = "📖 Topping index" },
	["profile.playtime"] = { de = "{hours} Std {minutes} Min", en = "{hours} h {minutes} min" },
	["profile.badgeCount"] = { de = "{count}/{total} Badges", en = "{count}/{total} badges" },
	["profile.locked"] = { de = "🔒 {how}", en = "🔒 {how}" },
	["profile.choose"] = { de = "Wählen", en = "Choose" },
	["profile.chosen"] = { de = "✓ Gewählt", en = "✓ Chosen" },
	["profile.auto"] = { de = "Automatisch", en = "Automatic" },
	["profile.readOnly"] = { de = "Nur ansehen", en = "View only" },
	["profile.viewPrompt"] = { de = "Profil ansehen", en = "View profile" },
	["profile.loading"] = { de = "Profil lädt …", en = "Profile loading …" },
	["titleTag.rebirths"] = { de = "🔁 {count}", en = "🔁 {count}" },
	["notify.badgeEarned"] = { de = "🏅 Badge erhalten: {badge}", en = "🏅 Badge earned: {badge}" },
	["notify.TitleLocked"] = {
		de = "Diesen Titel hast du noch nicht freigeschaltet.",
		en = "You have not unlocked this title yet.",
	},
	["admin.action.addStat"] = { de = "Lebenszeit-Zähler erhöhen", en = "Raise a lifetime counter" },
	["admin.action.giveWeeklyChampion"] = { de = "Titel Wochen-Champion geben", en = "Give Weekly Champion title" },
	["admin.param.stat"] = { de = "Zähler", en = "Counter" },
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

-- Arguments of a sign text (#71), sent as JSON by the server: a string is used as is, a
-- number becomes a short number, `{ integer = n }` a whole number with separators and
-- `{ key = "...", args = {...} }` another text in the same language and `{ de = "...",
-- en = "..." }` a name from GameConfig (Texts.nameArg, #68) in the player's language.
export type SignArg = string | number | { integer: number } | { key: string, args: SignArgs? } | Entry
export type SignArgs = { [string]: SignArg }

-- A GameConfig entry with a German name and its English one (#68).
export type Named = { displayName: string, displayNameEn: string?, description: string?, descriptionEn: string? }

-- Name of a GameConfig entry (pet, topping, world, egg, potion, upgrade, shop, rarity).
function Texts.name(language: Language, entry: Named): string
	return if language == "en" and entry.displayNameEn then entry.displayNameEn else entry.displayName
end

-- Description of a potion or upgrade ("" if it has none).
function Texts.description(language: Language, entry: Named): string
	if language == "en" and entry.descriptionEn then
		return entry.descriptionEn
	end
	return entry.description or ""
end

-- A GameConfig name as a sign argument, so every player reads it in their language.
function Texts.nameArg(entry: Named): Entry
	return { de = entry.displayName, en = entry.displayNameEn or entry.displayName }
end

-- Sign text for `key` in `language` with its arguments formatted for that language.
function Texts.render(language: Language, key: string, args: SignArgs?): string
	if args == nil then
		return Texts.format(language, key)
	end
	local params: Params = {}
	for name, value in args do
		if type(value) == "number" then
			params[name] = Texts.shortNumber(language, value)
		elseif type(value) == "table" then
			local arg = value :: any
			if type(arg.integer) == "number" then
				params[name] = Texts.integer(language, arg.integer)
			elseif type(arg.key) == "string" then
				params[name] = Texts.render(language, arg.key, arg.args)
			elseif type(arg.de) == "string" then
				params[name] = if language == "en" and type(arg.en) == "string" then arg.en else arg.de
			end
		else
			params[name] = tostring(value)
		end
	end
	return Texts.format(language, key, params)
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

-- Share 0..1 as a percent number with at most one decimal (rounded), without the sign:
-- 0.012 -> "1,2" / "1.2", 0.02 -> "2". The sign comes from the text ("{value} %").
function Texts.percent(language: Language, share: number): string
	local text = string.format("%.1f", math.round(share * 1000) / 10)
	return (string.gsub(string.gsub(text, "%.0$", ""), "%.", SEPARATORS[language].decimal))
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
