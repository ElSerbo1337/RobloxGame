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
- Kurz und auf Deutsch, Zahlen mit Tausenderpunkt (`1.500`), Prozent mit Komma (`0,5 %`).

## Formen

- Ecken: `UICorner` 18 px für Knöpfe, 14–24 px für Panels; Seiten-Knöpfe im HUD sind **Kreise** (`UiKit.roundButton`).
- Rand: `UIStroke` 3 px in `DARK` um jeden Knopf und jedes Panel.
- Keine Bilder-Assets nötig: Icons sind Emojis oder einfache Kreise in Akzentfarbe.

## Größen und Touch

- Alles, was man drückt, ist mindestens **60 px** hoch (`UiKit.MIN_TOUCH`), Standard-Knopf 260 × 64, runde HUD-Knöpfe 96 px, Schließen-Knopf 72 × 72.
- Knöpfe reagieren auf **`Activated`** (Maus und Touch), nie auf `MouseButton1Click`.
- Jede ScreenGui bekommt `UiKit.autoScale` (skaliert 0,7–1,4 je nach Bildschirm).
- Unten links liegt auf dem Handy der Joystick, unten rechts der Sprung-Knopf: dort keine Knöpfe (Zonen `joystick`/`jump` im HUD-Raster).

## HUD-Raster

Wo etwas auf dem Bildschirm liegt, steht **an einer Stelle**: `src/shared/HudLayout.luau` (reine Daten, in Lune getestet: `tests/HudLayout.spec.luau` prüft auf sechs Bildschirmgrößen vom kleinen Handy bis 4K, dass sich nichts überlappt, nichts aus dem Bild ragt und kein Knopf im Joystick-/Sprung-Bereich liegt). UIs setzen **keine eigenen Positionen**, sondern nutzen die UiKit-Helfer:

| Zone (`HudLayout.zones`) | Inhalt | Helfer |
| --- | --- | --- |
| `coins`, `gems` | oben Mitte: Münzen links, Gems rechts der Mitte (Höhe 12–72) | `UiKit.place` |
| `toast` | Meldungen direkt darunter (84–124), 380 breit | `UiKit.place` |
| `tutorialCard` | links oben unter dem Roblox-Menü, nie breiter als der Platz links der Münzen | `UiKit.place` |
| `sideArea` | links: runde Knöpfe in festen Plätzen `pets`, `potions`, `gifts`, `rebirth` (je 96 px); Spalte für Spalte von oben, endet über dem Joystick | `UiKit.sideButton(slot, text, farbe)` |
| `pizzaBar`, `autoCollect` | unten Mitte: Pizza-Balken, Auto-Sammeln darüber | `UiKit.place` |
| `unlockButton` | Freischalt-Knopf rechts neben dem Pizza-Balken, endet vor dem Sprung-Knopf | `UiKit.place` |
| `rightColumn` | rechts ab Höhe der Meldungen: aktive Tränke (`LayoutOrder` 1), darunter der Auftrag (2); versteckte Teile nehmen keinen Platz, zu hohe Stapel schrumpfen bis über den Sprung-Knopf | `UiKit.rightColumn()` |
| `menuArea` | Menüs: unter Währungen und Meldungen (ab 132), mit Abstand über dem Pizza-Balken | `UiKit.placeMenu(gui, panel, größe, minHöhe?)` |
| `joystick`, `jump` | Freihalte-Bereiche des Handys (unten links 260 × 220, unten rechts 180 × 220): dort keine Knöpfe | – |

Koordinaten sind virtuelle Pixel nach `UiKit.autoScale`, unterhalb der Roblox-Leiste.

**Menüs** werden für ihre Wunschgröße gebaut. `UiKit.placeMenu` setzt sie mittig in die Menü-Zone; ist dort zu wenig Platz, wird ein Menü mit Scroll-Liste zuerst niedriger (bis `minHöhe`, z. B. Kopf + eine Zeile) und erst danach verkleinert, alle anderen nur verkleinert (`HudLayout.fitMenu`). Danach füllt das Panel seinen Halter: weiter `panel.Visible` und `UiKit.pop(panel)` benutzen.

**Neue HUD-Teile:** zuerst eine Zone (oder einen Platz in `SIDE_SLOTS`) in `HudLayout` ergänzen, den Test um das Teil erweitern, dann über UiKit platzieren.

Kein Shop- und kein Teleport-Knopf im HUD – Shops und Portale betritt man in der Welt.

## Bewegung und Rückmeldung

- Änderung einer Zahl oder Tipp auf einen Knopf: kurzes „Hüpfen“ mit `UiKit.pop` (Back-Easing, 0,25 s).
- Menüs öffnen mit Pop, schließen sofort.
- Meldungen (Toast) oben unter den Währungen, ca. 2 s sichtbar, Fehler in `RED`, Belohnungen in `COIN`/`GEM`.
- Jede wichtige Aktion hat einen Sound (siehe `src/client/Sounds.luau`): Sammeln, Verkaufen, Gem, Ei knacken, Telefon.

## 3D-Look (Welten und Modelle)

- Low-Poly mit flachen Flächen, kräftige, warme Farben, keine Texturen.
- Modelle entstehen mit `tools/blender/build_models.py` (Vorschau-Renders in `assets/previews/`). Jedes Modell besteht aus Teilen mit genau einer Farbe; der Teilname bestimmt Farbe und Material (`PALETTE` in `src/shared/ModelLibrary.luau`).
- Licht, Atmosphäre, Post-Processing und Musik pro Welt: `src/shared/WorldLooks.luau`.
- Pets entstehen mit `tools/blender/build_pets.py` (Chibi-Stil: großer Kopf, große glänzende Augen, rosa Wangen; Vorschau in `assets/previews/pets/`). Bei Pets steht die Farbe im Teilnamen (`Pet_F2D49B`, optional `_Neon`/`_Glass`/`_Metal`).
- Pet-Bilder in der UI sind 3D-Ansichten der importierten Modelle (`src/client/PetIcon.luau`, ViewportFrame) – kein Bild-Upload nötig; ohne Import bleibt der Punkt in Seltenheitsfarbe.
- Deko der Welten 2–7 (Daten in `src/server/WorldDeco.luau`, `SPECS`): Weg vor den Stationen, große Teile an den Rändern, kleine Akzente, ein Wahrzeichen hinten links.
