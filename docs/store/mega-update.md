# Spielseite zum MEGA UPDATE (#115)

Für den Creator Hub: Creator Hub → Experience → **Configure → Basic Info** (Titel, Beschreibung) und **Places → Thumbnails** bzw. **Icon**. Deutsch ist die Hauptsprache, Englisch kommt als Übersetzung dazu (Creator Hub → **Localization** → Englisch → Experience Information). Grenzen bei Roblox: Titel höchstens 50 Zeichen, Beschreibung höchstens 1000 Zeichen. Beide Fassungen unten passen in diese Grenzen.

Die Texte nennen bewusst **keine Balancing-Zahlen** (Preise, Chancen, Boni), weil die sich mit #108 noch ändern. Robux, Gamepässe und „gratis Robux“ kommen nicht vor.

## Bilder (`docs/store/mega/`)

| Datei | Größe | Inhalt |
| -- | -- | -- |
| `Icon.png` | 512 × 512 | Geheim-Pet Pizza-Zeus auf goldener Bühne, links ein Gold-Pet, rechts ein Regenbogen-Pet, Glitzer, Banner „MEGA UPDATE“ (gilt für beide Sprachen) |
| `Thumbnail1_Pets_de.png` / `_en` | 1920 × 1080 | Pizza-Zeus in der Mitte, Gold- und Regenbogen-Varianten, Geheim-Pets, Atlantis-Ei und Götter-Ei, viel Glitzer |
| `Thumbnail2_Atlantis_de.png` / `_en` | 1920 × 1080 | Versunkener Tempel von Atlantis, Atlantis-Pets davor, aufsteigende Blasen |
| `Thumbnail3_PizzaParadise_de.png` / `_en` | 1920 × 1080 | Goldene Pizza-Statue im Pizza-Paradies, Götter-Pets, Münzen und Pizzastücke in der Luft |
| `Thumbnail4_WheelQuests_de.png` / `_en` | 1920 × 1080 | Glücksrad mit allen Feldern, Quest-Tafel mit Fortschrittsbalken |

Reihenfolge der Thumbnails wie oben. Die deutschen Bilder sind die Hauptbilder. Die englischen kommen unter Localization → Englisch → Thumbnails hoch.

Neu rendern: `lune run export-islands build/islands.json`, dann `python tools/blender/render_mega.py` (oder einzelne Szenen: `icon pets atlantis paradise wheel`, `--preview` für einen schnellen Blick). Jede Szene wird nur einmal gerendert, die beiden Sprachen unterscheiden sich nur im Text.

Die alten Bilder aus #61 (`docs/store/Icon.png`, `Thumbnail1–3`) bleiben liegen, falls das Update zurückgenommen wird.

---

## Deutsch

### Titel

```text
🍕 Pizza Topping Simulator [MEGA UPDATE]
```

### Beschreibung

```text
🎉 MEGA UPDATE! 8 neue Welten, Geheim-Pets, Glücksrad und Quests!

Sammle Beläge, backe riesige Pizzen und verkaufe sie für Münzen. Schalte neue Inseln frei und werde der beste Pizzabäcker!

✨ NEU im MEGA UPDATE:
🌊 8 neue Welten – von Atlantis bis zum goldenen Pizza-Paradies (jetzt 15 Welten!)
🤫 Geheim-Pets – super selten und mit Heiligenschein
🌈 Gold-, Regenbogen- und Shiny-Pets – verschmelze gleiche Pets zu Glitzer-Pets
⭐ Pet-Level – deine Pets werden mit dir stärker
🎡 Glücksrad – jeden Tag gratis drehen
📜 Tages- und Wochen-Quests mit Belohnungen
🗝️ Geheime Truhen in versteckten Ecken
🛒 Reisender Händler mit besonderen Angeboten
🌦️ Tag und Nacht, Wetter wie Käseregen und Blasen-Sturm
🏆 Neue Bestenlisten, Abzeichen und Titel

🍕 So spielst du:
1️⃣ Beläge auf dem Feld einsammeln
2️⃣ Pizza im Ofen backen und verkaufen
3️⃣ Eier öffnen und Pets sammeln
4️⃣ Neue Welten freischalten und Rebirth machen

👍 Gefällt dir das Spiel? Gib ein Like und speichere es als Favorit!
```

---

## English

### Title

```text
🍕 Pizza Topping Simulator [MEGA UPDATE]
```

### Description

```text
🎉 MEGA UPDATE! 8 new worlds, Secret pets, a Lucky Wheel and quests!

Collect tasty toppings, bake huge pizzas and sell them for coins. Unlock new islands and become the best pizza chef!

✨ NEW in the MEGA UPDATE:
🌊 8 new worlds – from Atlantis to the golden Pizza Paradise (15 worlds now!)
🤫 Secret pets – super rare and with a halo
🌈 Gold, Rainbow and Shiny pets – merge equal pets into sparkling variants
⭐ Pet levels – your pets grow stronger with you
🎡 Lucky Wheel – free spins every day
📜 Daily and weekly quests with rewards
🗝️ Secret chests in hidden corners
🛒 Traveling merchant with special offers
🌦️ Day and night, weather like Cheese Rain and Bubble Storm
🏆 New leaderboards, badges and titles

🍕 How to play:
1️⃣ Collect toppings on the field
2️⃣ Bake your pizza in the oven and sell it
3️⃣ Open eggs and collect pets
4️⃣ Unlock new worlds and rebirth

👍 Like the game? Give it a thumbs up and add it to your favorites!
```
