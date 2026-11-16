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
- Unten links liegt auf dem Handy der Joystick, unten rechts der Sprung-Knopf: dort keine Knöpfe.

## HUD-Aufteilung (aus der Spec)

| Bereich | Inhalt |
| --- | --- |
| oben Mitte | Münzen (links der Mitte) und Gems (rechts der Mitte); kurze Meldungen darunter |
| links Mitte | runde Knöpfe: Pets, darunter Tränke (später Rebirth) |
| unten Mitte | Pizza-Füllstand, darüber der Auto-Sammeln-Schalter |
| rechts | aktive Tränke (ab oberem Drittel, je Trank eine Pille mit Restzeit `m:ss`) und aktiver Auftrag mit Timer |

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
