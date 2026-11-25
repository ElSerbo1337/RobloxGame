# UI-Stil

Gemeinsamer Stil für alle Oberflächen des Pizza Topping Simulators (HUD, Menüs, Ei-Vorschau, Tutorial, alles Künftige). Umgesetzt in `src/client/UiKit.luau` – neue UI nutzt dessen Konstanten und Helfer statt eigener Werte.

## Grundidee

Bunt, rund, freundlich, gut lesbar – wie eine Pizzeria-Speisekarte im Cartoon-Stil. Alles muss auf dem Handy mit dem Daumen bedienbar sein.

## Farben

| Name (`UiKit.*`) | RGB | Wofür |
| --- | --- | --- |
| `CREAM` | 255, 248, 230 | Hintergrund von Panels und Anzeigen, Text auf farbigen Knöpfen |
| `DARK` | 60, 35, 20 | Text, Ränder (Stroke) – nie reines Schwarz |
| `COIN` | 255, 200, 40 | Münzen, Preise, Belohnungen |
| `GEM` | 60, 230, 255 | Gems |
| `GREEN` | 110, 200, 90 | Bestätigen, Kaufen, „AN“ |
| `RED` | 230, 70, 50 | Fehler, „voll“, Löschen, Schließen |
| `ORANGE` | 240, 130, 60 | Haupt-Knöpfe im HUD (z. B. „Pets“) |
| `GREY` | 190, 180, 170 | Aus / gesperrt / nicht leistbar |

Seltenheiten haben eigene Farben in `GameConfig.rarities` (`UiKit.rarityColor`).

## Schrift

- Immer `Enum.Font.FredokaOne` (`UiKit.FONT`), `TextScaled = true`.
- Text auf farbigen Flächen: `CREAM` mit dunklem Text-Rand (`UIStroke` Contextual, 2 px, `DARK`).
- Text auf `CREAM`: `DARK`.
- Kurz, in der Sprache des Spielers (Deutsch oder Englisch, siehe „Texte und Sprachen“). Deutsch: Zahlen mit Tausenderpunkt (`1.500`), Prozent mit Komma (`0,5 %`); Englisch: `1,500`, `0.5%`.

## Texte und Sprachen (#65, #67)

Jeder Spieler sieht das Spiel in seiner Sprache: Deutsch für deutschsprachige Roblox-Konten (Locale `de-*`), Englisch für alle anderen. Kein Text steht mehr fest im UI-Code.

- **Textsammlung:** `src/shared/Texts.luau` (rein, ohne Roblox-API, in Lune getestet). `Texts.strings` ordnet jedem Schlüssel `{ de = "…", en = "…" }` zu. Platzhalter heißen `{name}` und müssen in beiden Sprachen gleich sein.
- **Im Client:** `src/client/Lang.luau` liest die Sprache einmal beim Beitreten (`Players.LocalPlayer.LocaleId` = im Roblox-Menü gewählte Spielsprache, sonst `LocalizationService.RobloxLocaleId`, sonst `SystemLocaleId`); wechselt der Spieler die Sprache während des Spiels, erscheint der Hinweis „Sprache geändert – zum Übernehmen neu beitreten.“ in der neuen Sprache und liefert:
  - `Lang.t(schlüssel, { name = wert })` – fertiger Text, z. B. `Lang.t("notify.sold", { amount = Lang.shortNumber(1500) })` → „+1.500 Münzen“ / „+1,500 coins“.
  - `Lang.shortNumber(n)` – Kurzzahl: Deutsch „1.234“, „1,5 Mio“, „2 Mrd“, „3 Bio“; Englisch „1,234“, „1.5M“, „2B“, „3T“ (`UiKit.shortNumber` ist dasselbe).
  - `Lang.integer(n)` – ganze Zahl ohne Kurzform („2.500.000“ / „2,500,000“).
  - `Lang.language` – `"de"` oder `"en"`, falls etwas anderes als Text sprachabhängig ist.
- **Neuer Text:** Schlüssel in `Texts.strings` ergänzen (Gruppe als Präfix: `hud.`, `side.`, `unlock.`, `notify.`; neue Bildschirme bekommen ein eigenes Präfix, z. B. `shop.`, `pets.`, `tutorial.`, `sign.`), beide Sprachen ausfüllen, im UI `Lang.t` benutzen. `lune run test` prüft, dass jeder Schlüssel beide Sprachen und dieselben Platzhalter hat. Zahlen erst formatieren (`Lang.shortNumber`/`Lang.integer`), dann als Platzhalter einsetzen. Einzahl/Mehrzahl: zwei Schlüssel (z. B. `unlock.rebirthsOne`/`unlock.rebirthsMany`). Unbekannte Schlüssel erscheinen als Schlüsselname im Spiel – so fällt ein fehlender Text auf.
- **Server-Meldungen:** Der Server schickt nur Notify-Arten (`"NotEnoughCoins"`); der Client zeigt `notify.<Art>`. Neue Notify-Art: Schlüssel `notify.<Art>` anlegen und die Art in `MESSAGE_KINDS` in `src/client/Hud.luau` eintragen.
- **Keine Roblox-Autoübersetzung:** `UiKit.autoScale` setzt `AutoLocalize = false`; zusätzlich setzt `Lang.stopAutoTranslate` (beim Start) es für jede ScreenGui in PlayerGui und jede Billboard-/SurfaceGui im Workspace. Im Creator Hub die automatische Übersetzung ebenfalls ausschalten.
- **In Studio testen:** Vor **Play** im Explorer `Workspace` wählen → Properties → Attributes → **+** → Name `Language`, Typ `string`, Wert `en` (oder `de`). Gilt nur in Studio; zum Schluss wieder löschen. Alternativ **Test → Player Emulator → Locale** (z. B. `en-us`/`de-de`) einstellen, wenn kein Attribut gesetzt ist.
- **3D-Schilder (#71):** Vom Server gebaute Schild-Texte nie direkt mit `label.Text = …` setzen, sondern `SignText.set(label, "sign.…", args)` (`src/server/SignText.luau`): setzt die Attribute `TextKey`/`TextArgs` (JSON) und den Tag `SignText`, `Text` ist die deutsche Fassung. `src/client/SignTexts.luau` füllt jedes so markierte Label (auch später hinzugefügte und geänderte) per `Lang.render`. Argumente (`Texts.render`): Text bleibt wie er ist, Zahl → `shortNumber`, `{ integer = n }` → ganze Zahl, `{ key = "…", args = {…} }` → weiterer Text in derselben Sprache. Bestenlisten-Titel: `board.<id>` je Board aus `GameConfig.leaderboards`.
- **Namen aus `GameConfig` (#68):** Jeder Eintrag mit `displayName` (Pets, Beläge, Welten, Eier, Tränke, Upgrades, Shops, Seltenheiten) hat `displayNameEn`, Tränke und Upgrades zusätzlich `descriptionEn` – exakt wie in `docs/translations-names.md` (`tests/Names.spec.luau` prüft das). Im UI nie `entry.displayName` zeigen, sondern `Lang.name(entry)`, `Lang.description(entry)` bzw. `Lang.worldName(worldId)`. Auf Schildern und Server-Billboards den Namen als Argument `Texts.nameArg(entry)` an `SignText.set` geben (Pet-Namensschild: `"sign.name"`). Regeln und Spielstände bleiben bei Ids. Neuer Eintrag: Englisch in Namensliste und Config ergänzen.

## Formen

- Ecken: `UICorner` 18 px für Knöpfe, 14–24 px für Panels; die Kacheln der Seitenleiste haben 24 % ihrer Größe als Rundung (siehe „Seitenleiste“).
- Rand: `UIStroke` 3 px in `DARK` um jeden Knopf und jedes Panel.
- Keine Bilder-Assets nötig: Icons sind Live-3D-Ansichten (`ViewportFrame`), Emojis oder einfache Kreise in Akzentfarbe.
- Münze und Gem überall über `UiKit.coinIcon(parent, größe)` / `UiKit.gemIcon(parent, größe)` (#49): Goldmünze mit Rand und eingeprägter Pizza-Ecke, facettierter türkiser Diamant mit Glanzlicht – nur GUI-Elemente, keine eigenen Kreise/Quadrate mehr.

## Größen und Touch

- Alles, was man drückt, ist mindestens **60 px** hoch (`UiKit.MIN_TOUCH`), Standard-Knopf 260 × 64, Seitenleisten-Kacheln 60–84 px (Handy 64 px), Schließen-Knopf 72 × 72.
- Knöpfe reagieren auf **`Activated`** (Maus und Touch), nie auf `MouseButton1Click`.
- Jede ScreenGui bekommt `UiKit.autoScale` (skaliert 0,7–1,4 je nach Bildschirm).
- Unten links liegt auf dem Handy der Joystick, unten rechts der Sprung-Knopf: dort keine Knöpfe (Zonen `joystick`/`jump` im HUD-Raster).

## HUD-Raster

Wo etwas auf dem Bildschirm liegt, steht **an einer Stelle**: `src/shared/HudLayout.luau` (reine Daten, in Lune getestet: `tests/HudLayout.spec.luau` prüft auf sechs Bildschirmgrößen vom kleinen Handy bis 4K, dass sich nichts überlappt, nichts aus dem Bild ragt und kein Knopf im Joystick-/Sprung-Bereich liegt). UIs setzen **keine eigenen Positionen**, sondern nutzen die UiKit-Helfer:

| Zone (`HudLayout.zones`) | Inhalt | Helfer |
| --- | --- | --- |
| `coins`, `gems` | oben Mitte: Münzen links, Gems rechts der Mitte (Höhe 12–72), knapp unter dem Bildschirmrand: eigene Ebene `Currency` mit `ScreenInsets = DeviceSafeInsets` (ignoriert den Platz der Roblox-Leiste, hält Notches frei) | `UiKit.place` |
| `pizzaBar` | Pizza-Balken direkt unter Münzen und Gems (80–128, 260 breit), in derselben Ebene `Currency` (#75) | `UiKit.place` |
| `toast` | Meldungen darunter (136–176), 380 breit | `UiKit.place` |
| `tutorialCard` | links oben unter dem Roblox-Menü, nie breiter als der Platz links der Münzen | `UiKit.place` |
| `sideBar` | Seitenleiste links (#75, siehe „Seitenleiste“): ab 30 % der Höhe (unter dem Roblox-Chat oben links); mit Touch (Tablet) bis über den Joystick, ohne Touch (PC, `sideBarMouse`) bis zum unteren Rand. Kleine Bildschirme (Handy): `sideBarSmall` von unter der Tutorial-Karte bis direkt über den Joystick (`joystickSmall`, 180 hoch) | `SideBar.register{…}` |
| `autoCollect` | unten Mitte: Auto-Sammeln | `UiKit.place` |
| `unlockButton` | Freischalt-Knopf rechts neben Auto-Sammeln, endet vor dem Sprung-Knopf | `UiKit.place` |
| `rightColumn` | rechts ab Höhe 84 bis über den Sprung-Knopf, zwei Stapel (#75): **oben** aktive Boni (`LayoutOrder` 1, z. B. Freunde, Wetter) und der Auftrag (2) über `UiKit.rightColumn()`; **unten** (über dem Sprung-Knopf, wächst nach oben) die laufenden Tränke über `UiKit.potionColumn()`. Versteckte Teile nehmen keinen Platz. Brauchen beide mehr Platz als da ist, schrumpfen sie (`HudLayout.fitStacks`): die Tränke behalten ihre Größe bis zur halben Spalte, der obere Stapel bekommt den Rest – sie überlappen sich nie | `UiKit.rightColumn()`, `UiKit.potionColumn()` |
| `eggPreview` | Ei-Vorschau-Panel rechts an der Stelle der rechten Spalte (die solange ausgeblendet ist, `UiKit.setRightColumnHidden`): unter der Top-Leiste, nie unter dem Gem-Zähler, bis über den Sprung-Knopf, höchstens 360 breit; Pet-Liste scrollt | `UiKit.placePanel(gui, panel, "eggPreview", größe, minHöhe, Ausrichtung)` |
| `menuArea` | Menüs: unter Währungen, Pizza-Balken und Meldungen (ab 184), mit Abstand über Auto-Sammeln | `UiKit.placeMenu(gui, panel, größe, minHöhe?)` |
| Kleiner Bildschirm | Kurze Seite des Viewports unter 500 px (`HudLayout.isSmallScreen`, #55): `menuArea` füllt fast den ganzen Bildschirm (8 px Rand, unter der Roblox-Top-Leiste); Menüs werden nie unter 0,85 skaliert (`MENU_MIN_SCALE`), was nicht passt, scrollt; der Shop zeigt mindestens einen Abschnittskopf plus eine ganze Karte; das Ei-Panel beginnt neben dem Gem-Zähler und ist 300 statt 360 breit | `UiKit.placeMenu`/`UiKit.placePanel` (automatisch) |
| `joystick`, `jump` | Freihalte-Bereiche des Handys (unten links 260 × 220, unten rechts 180 × 220): dort keine Knöpfe | – |

Koordinaten sind virtuelle Pixel nach `UiKit.autoScale`, unterhalb der Roblox-Leiste.

**Menüs** werden für ihre Wunschgröße gebaut. `UiKit.placeMenu` setzt sie mittig in die Menü-Zone; ist dort zu wenig Platz, wird ein Menü mit Scroll-Liste zuerst niedriger (bis `minHöhe`, z. B. Kopf + eine Zeile) und erst danach verkleinert, alle anderen nur verkleinert (`HudLayout.fitMenu`). Danach füllt das Panel seinen Halter: weiter `panel.Visible` und `UiKit.pop(panel)` benutzen.

**Nur ein Menü gleichzeitig (#53):** Jedes Menü meldet sich mit `UiKit.registerMenu(id, schließen)` an (`schließen` = derselbe Weg wie sein „X“, auch auf einem schon geschlossenen Menü harmlos) und ruft beim Öffnen `UiKit.menuOpened(id)` auf. Dann schließen sich alle anderen offenen Menüs, als hätte man sie selbst geschlossen (Logik: `src/shared/MenuSwitch.luau`, getestet). Angemeldet: `shop`, `portal`, `pets`, `potions`, `gifts`, `rebirth`, `calendar`, `phone`, `eggPreview`, `more` (Mehr-Fenster der Seitenleiste), `settings`. Zonen-Menüs (Shop, Portal, Ei-Vorschau) gehen danach erst wieder auf, wenn man die Zone verlässt und neu betritt. Neue Menüs melden sich genauso an.

**Neue HUD-Teile:** zuerst eine Zone in `HudLayout` ergänzen, den Test um das Teil erweitern, dann über UiKit platzieren. Neue Menüs brauchen keine Zone: sie tragen sich in die Seitenleiste ein.

## Seitenleiste (#75)

Alle Menüs öffnet man über glänzende Kacheln in der Seitenleiste links (`src/client/SideBar.luau`, Reihenfolge/Überlauf/rote Punkte rein in `src/shared/SideBarModel.luau`, Plätze in `HudLayout.sideBarGrid` – beides in Lune getestet).

**Ein Menü eintragen (eine Zeile):**

```lua
local SideBar = require(script.Parent.SideBar)

local button = SideBar.register({
	id = "quests",                 -- eindeutig, nicht "more"
	order = 70,                    -- Platz: kleiner = weiter oben/links
	text = Lang.t("side.quests"),  -- Beschriftung unter dem Icon
	color = UiKit.GREEN,           -- Kachelfarbe
	icon = { model = "Pizza", shape = "quest" }, -- 3D-Modell, sonst Ersatzform
	open = toggleQuestMenu,        -- beim Tippen (auch aus dem Mehr-Fenster)
})
SideBar.setBadge("quests", true)   -- roter Punkt an/aus („hat Neues“), geht auch vor register
SideBar.setCaption("quests", "2/3") -- Beschriftung ändern, nil = wieder `text`
```

`open` schaltet das Menü um (offen → zu, zu → auf) und ruft beim Öffnen wie jedes Menü `UiKit.menuOpened(id)` auf. `register` liefert den Knopf der Kachel (z. B. für einen „Neu!“-Hinweis mit `UiKit.placeSideNote`). Vergeben (`order`): `pets` 10, `potions` 20, `gifts` 30, `calendar` 40, `rebirth` 50, `worlds` 60, `settings` 200 (#76); neue Menüs nehmen freie Zahlen (Vorschlag: Quests 70, Glücksrad 80, Index 90, Profil 100, Einstellungen 200).

**Rote Punkte:** Ein Menü meldet „hat Neues“ mit `SideBar.setBadge(id, true)` und nimmt ihn zurück, sobald es nichts mehr gibt (nicht beim bloßen Öffnen). Heute: Geschenk abholbereit, Kalender-Belohnung offen, Verschmelzen möglich (`pets`, #80: `GameRules.canMergeAny` auf den replizierten Pets). Geplant: Quest fertig, Gratis-Dreh. Liegt eine Kachel im Mehr-Fenster, bekommt „Mehr“ den Punkt.

**Aussehen einer Kachel:** abgerundetes Quadrat (Rundung 24 %) in der Kachelfarbe (20 % aufgehellt), senkrechter Verlauf hell → 68 % dunkler, 4 px `DARK`-Rand, weicher weißer Glanz über der oberen Hälfte, darin ein leicht schräges (10°), sanft hin- und herschwenkendes **Live-3D-Icon** (`src/client/TileIcon.luau`: `ViewportFrame` mit dem Modell aus `ModelLibrary`, fehlt es, eine einfache Ersatzform aus Teilen – `pet`, `potion`, `gift`, `calendar`, `rebirth`, `portal`, `gear`, `wheel`, `quest`, `star`, `more`; neue Formen in `TileIcon.SHAPES`), unten die Beschriftung in `CREAM` mit dunklem Text-Rand. Drücken federt (0,88 → 1 mit Back-Easing), Maus darüber vergrößert leicht. Roter Punkt: Kreis oben rechts (30 % der Kachel), `RED` mit `DARK`-Rand und Glanzpunkt, pulsiert. Oben links ist Platz für eine Zahl (z. B. Rebirths in `COIN`).

**Plätze:** PC und Tablet: eine Spalte, senkrecht mittig; Kacheln 84 px, bei vielen Menüs bis 60 px kleiner, erst dann weitere Spalten (höchstens 3). Handy: zwei Spalten mit 64-px-Kacheln, Zeile für Zeile, der Block sitzt direkt über dem Joystick. Passen nicht alle Kacheln, wird der letzte Platz zu **„Mehr“** (⋯) und öffnet ein Fenster mit den übrigen Kacheln (kleinstes Handy 950 × 450: 3 Kacheln + Mehr; übliches Handy 1100 × 520: alle 6).

**Schalter:** `GameConfig.features.sideBar = false` → schlichte runde Knöpfe mit Text an denselben Plätzen, keine 3D-Icons, keine roten Punkte (falls die Viewports auf schwachen Handys ruckeln).

Kein Shop- und kein Teleport-Knopf im HUD – Shops und Portale betritt man in der Welt. Die Kachel „Welten“ zeigt die Weltenliste nur zum Anschauen; reisen kann man weiter nur im Portal.

## Welten-Menü (#78)

Portal und Kachel „Welten“ zeigen jede Welt aus `GameConfig.worlds` als Karte (`src/client/PortalMenu.luau`, 3 pro Reihe, scrollt; Schalter `features.worldMenu`, aus = alte Liste). Karte: Nummer oben links in Weltfarbe, darunter eine kleine schwenkende 3D-Insel (`TileIcon.buildModel`; Farben und Wahrzeichen rein aus `src/shared/WorldPreview.luau`: Insel-Thema, sonst Weltfarbe + Ersatzform), Name, Status. Gesperrt: Vorschau abgedunkelt, 🔒, „Es fehlt:“ mit den Einträgen aus `rules.portalMenu(state)[i].missing` (`PreviousWorld`, `Rebirths`, `Coins`, jeweils der fehlende Rest); alles erfüllt: grün „Am Tor freischalten“ + Preis. Neue Welten brauchen keinen Menü-Code, nur ihren Config-Eintrag (für das Wahrzeichen ein `landmark` im Thema).

## Einstellungen (#76)

Kachel ⚙️ „Optionen“ (`settings`, order 200) öffnet `src/client/SettingsMenu.luau`: Musik und Effekte (Regler 0–100 % + 🔊/🔇), Grafik Hoch/Niedrig, Kamera-Wackeln, Bildschirm-Blitze, Ei-Animation überspringen, Codes-Feld (nur bei `features.codes`). Schalter: `features.settings` (aus = keine Kachel, alles auf Standard).

- **Welche Einstellungen es gibt:** `GameRules.SETTINGS` (rein, getestet in `tests/Settings.spec.luau`): `musicVolume`, `effectsVolume` (ganze Zahl 0–100), `musicMuted`, `effectsMuted`, `cameraShake`, `screenFlashes`, `skipEggAnimation` (Boolean), `graphics` (`"High"`/`"Low"`, Touch-Geräte ohne Tastatur starten auf `"Low"`). Gespeichert wird nur, was der Spieler geändert hat (`state.settings`, bleibt beim Rebirth); der Server prüft jeden Wert (`rules.setSetting`, RemoteEvent `SetSetting`, Attribut `Settings`).
- **Client-API** (`src/client/Settings.luau`) – jedes Modul fragt nur hier:

```lua
local Settings = require(script.Parent.Settings)

Settings.get("musicVolume")          -- aktueller Wert (mit Standard), unbekannter Schlüssel wirft
Settings.set("graphics", "Low")      -- nur das Menü: sofort lokal, kurz danach an den Server
Settings.changed:Connect(function(key, value) end) -- nach jeder Änderung (auch vom Server)
Settings.observe("graphics", function(value) end)   -- sofort und nach jeder Änderung dieses Schlüssels
Settings.lowGraphics()      -- true bei „Niedrig“
Settings.cameraShake()      -- false: nie die Kamera wackeln lassen
Settings.screenFlashes()    -- false: keine weißen/farbigen Vollbild-Blitze
Settings.skipEggAnimation() -- true: geschlüpfte Pets sofort zeigen
Settings.volume("music")    -- 0..1 inkl. Stumm ("music" | "effects")
```

- **Pflicht für spätere Tickets:** Kamera-Wackeln (Juice, Mythic/Secret) nur bei `Settings.cameraShake()`, Bildschirm-Tönung/Blitze/Lichtstrahlen bei seltenen Pets nur bei `Settings.screenFlashes()`, längere Ei-Animationen (Secret) überspringen bei `Settings.skipEggAnimation()`.
- **Grafik Niedrig** (`src/client/GraphicsQuality.luau`, automatisch, nur lokal): jeder `ParticleEmitter` im Workspace (auch später erzeugte) bekommt 30 % seiner `Rate` (`GraphicsQuality.PARTICLE_FACTOR`), `Sparkles`/`Fire`/`Smoke` gehen aus. Verzichtbare Deko mit dem CollectionService-Tag **`GraphicsDetail`** (`GraphicsQuality.DETAIL_TAG`) markieren: auf „Niedrig“ unsichtbar (Teile `LocalTransparencyModifier = 1`, Effekte und Lichter darin aus). Eigene Mengen (z. B. Glitzer-Teilchen, Glühwürmchen) mit `GraphicsQuality.particleFactor()` multiplizieren und mit `Settings.observe("graphics", …)` nachziehen.
- **Lautstärke:** `src/client/Sounds.luau` legt jeden Sound in die SoundGroup `Music` (geloopte Einträge) oder `Effects`; deren Lautstärke folgt den Einstellungen. Neue Sounds einfach in `SOUNDS` eintragen.
- **Codes-Feld:** sendet nur `RedeemCode(code)` (getrimmt, höchstens 32 Zeichen). #99 baut die Regeln und antwortet mit `CodeResult(ok, reason?, rewards?)`; das Feld zeigt dann `codes.redeemed` bzw. `codes.<reason>` (fehlt der Text: „Geht gerade nicht.“). Kommt 5 s keine Antwort, steht dort „Codes gibt es bald!“.
- **Neue Einstellung:** Eintrag in `GameRules.SETTINGS` + Test, Text `settings.<key>` (de+en), Zeile in `SettingsMenu` (`switchRow(key)` für AN/AUS), dann überall `Settings.get(key)`.

## Bewegung und Rückmeldung

- Änderung einer Zahl oder Tipp auf einen Knopf: kurzes „Hüpfen“ mit `UiKit.pop` (Back-Easing, 0,25 s).
- Menüs öffnen mit Pop, schließen sofort.
- Meldungen (Toast) oben unter den Währungen, ca. 2 s sichtbar, Fehler in `RED`, Belohnungen in `COIN`/`GEM`.
- Kamera-Wackeln und Vollbild-Blitze nur, wenn die Einstellungen es erlauben (`Settings.cameraShake()`, `Settings.screenFlashes()`, siehe „Einstellungen“).
- Jede wichtige Aktion hat einen Sound (siehe `src/client/Sounds.luau`): Sammeln, Verkaufen, Gem, Ei knacken, Telefon.

## 3D-Look (Welten und Modelle)

- Low-Poly mit flachen Flächen, kräftige, warme Farben, keine Texturen.
- Modelle entstehen mit `tools/blender/build_models.py` (Vorschau-Renders in `assets/previews/`). Jedes Modell besteht aus Teilen mit genau einer Farbe; der Teilname bestimmt Farbe und Material (`PALETTE` in `src/shared/ModelLibrary.luau`).
- Licht, Atmosphäre, Post-Processing und Musik pro Welt: `src/shared/WorldLooks.luau`.
- Pets entstehen mit `tools/blender/build_pets.py` (Chibi-Stil: großer Kopf, große glänzende Augen, rosa Wangen; Vorschau in `assets/previews/pets/`). Bei Pets steht die Farbe im Teilnamen (`Pet_F2D49B`, optional `_Neon`/`_Glass`/`_Metal`).
- Pet-Bilder in der UI sind 3D-Ansichten der importierten Modelle (`src/client/PetIcon.luau`, ViewportFrame) – kein Bild-Upload nötig; ohne Import bleibt der Punkt in Seltenheitsfarbe.
- Beläge der Welten 2–7 entstehen mit `tools/blender/build_toppings.py` (#18, Stil der Salami aus #24: flach, dunklerer Rand, Vorschau und Prüfbilder pro Welt in `assets/previews/toppings/`). Teilnamen wie bei Pets (`Top_F59AAA`, optional `_Neon`/`_Glass`); ohne Import bleiben farbige Scheiben.
- Münze und Gem in 3D entstehen mit `tools/blender/build_currency.py` (#49, Vorschau `assets/previews/Currency.png`): `Coin` für die Verkaufs-Animation, `Gem` für Feld-Gems; ohne Import goldene Scheibe bzw. Neon-Würfel.
- Eier und Ei-Stand entstehen mit `tools/blender/build_eggs.py` (Vorschau in `assets/previews/eggs/`). Farben und Muster jedes Eis stehen in `GameConfig.eggs[…].look` (das Skript liest sie dort); Teilnamen wie bei Pets (`Egg_FFF3DC`, optional `_Neon`/`_Metal`). `fancy = true` ergibt die auffälligere Variante für ein zweites Ei pro Welt. Der Stand-Ring (`StandTrim`) wird im Spiel in der Akzentfarbe des Eis eingefärbt.
- **Fliegende Inseln (#27):** Jede Welt ist eine schwebende Insel in einer Kette entlang −Z (Spawn-Insel → Brücke → Welt 1 → Brücke → Welt 2 …, alle auf gleicher Höhe, 40 Studs Brücke). Geometrie als reine Daten in `src/shared/IslandPlan.luau` (getestet), Zahlen und Farben in `GameConfig.islands`, gebaut von `src/server/IslandBuilder.luau`.
  - Umriss: abgerundet und unregelmäßig (Superellipse mit leichtem Wackeln), an den Brücken gerade. Darunter eine Felskante aus nach unten schmaler werdenden Felsringen in drei Felstönen.
  - Rand: niedrige Hecke (bzw. weltpassender Rand) plus unsichtbare Wand (24 Studs); wer doch fällt, landet am Spawn der aktuellen Welt.
  - Material: **SmoothPlastic** in satten Farben; Neon nur für Leuchtendes (Tore, Lava), Glas für Wasser. Keine Texturen.
  - Plattenwege: quadratische Platten in zwei hellen Sandtönen, leicht verdreht; Hauptweg 12 Studs breit von Brücke zu Feld, Platten-Pads vor jeder Station.
  - Deko: große runde Bäume (`RoundTree`) am Rand, Büsche und Blumenbeete, ein Teich mit Bach und Wasserfall über die Felskante, erhöhte Terrassen mit Stufen hinten.
  - Gemeinsamer Grundriss (`GameConfig.islands.layout`): Brücke kommt vorne an, Hauptweg, Stationen links (Portal, Shop, zwei Ei-Plätze) und rechts (Ofen, Telefon, Lieferwagen) mit Front zum Weg – so bleibt die Kamera beim Benutzen über dem Weg. Dahinter das Belagfeld, hinten Terrassen mit Wahrzeichen und die Brücke zur nächsten Insel.
  - Gesperrte Welten: leuchtendes Tor in Weltfarbe am Brückenkopf mit Preisschild.
  - Vorschau: `lune run export-islands` und `python tools/blender/render_islands.py build/islands.json` → `assets/previews/islands/` (Gesamtansichten und Spielerperspektive, exakt die geplante Geometrie).
  - Weltthemen (`GameConfig.islands.themes`, #31, #32): pro Welt Farben, Rand, Wahrzeichen (hinten links), Deko-Modelle und die Brücke **in** die Welt – Garten (Hecke, Riesenpizza, Hängebrücke), Bauernhof (Zaun, Windmühle, Hängebrücke), Strand (Felsbrocken, Leuchtturm, Holzsteg), Eisberge (Eisblöcke, Eisgipfel, Eisbrücke), Vulkan (Basaltsäulen, Stufenvulkan mit Lavakrater, Basaltbrücke), Süßigkeitenland (Zuckerguss mit Pfefferminz und Gummidrops, Schichttorte, Zuckerstangen-Brücke), Weltraum (Mondbasis-Paneele, Rakete auf Startrampe und schwebender Planet, Leuchtbrücke). Fehlt ein Deko-Modell in Studio, baut `WorldDeco` Ersatzteile.
  - Leuchten sparsam: Jedes Neon-Teil mit Rolle `Glow` bekommt ein PointLight (Range 10); pro Insel höchstens 6, pro Brücke höchstens 4 (Test). Weiteres Neon nur als kleine Spitzen ohne Licht. Der Vulkan bleibt hell (heller Ascheboden, Lava nur als Akzent, #24).

## Pet-Varianten (#80)

- **Namen** immer über `UiKit.petName(petId, variant, shiny)` („Gold-Katze“, „✨ Regenbogen-Katze“ / „Golden Cat“), **Bonus** immer der effektive (`bonus` im Attribut `Pets`, Server rechnet `GameRules.petBonus`).
- **Look:** Gold = goldener Rahmen (`255,200,40`), Regenbogen = Rahmen mit Regenbogen-Verlauf, Shiny = ✨ in der Ecke / goldener Kartenrahmen beim Schlüpfen. Folgende Pets: Gold/Regenbogen leuchten (PointLight `VariantGlow`, Regenbogen wechselt die Farbe in `PetFollow`), Shiny funkelt (ParticleEmitter `ShinySparkles`).
- **Einstellungen:** Zusammenflug-Animation entfällt bei „Ei-Animation überspringen“, goldener Blitz (Verschmelzen und Shiny-Schlüpfen) nur bei `Settings.screenFlashes()`.
