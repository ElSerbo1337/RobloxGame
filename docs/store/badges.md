# Badges für den Creator Hub (#103)

16 Badges, im Creator Hub anlegen (Creator Hub → Experience → Engagement → Badges → Create a Badge; Icon 512×512 PNG, runder Ausschnitt). Danach die Badge-ID in `src/shared/GameConfig.luau` bei `badges` als `badgeId` eintragen (statt `0`). Fehlt eine ID, wird das Badge still übersprungen und beim nächsten Beitritt nachträglich vergeben, sobald sie eingetragen ist.

Name/Beschreibung: Deutsch als Hauptsprache, Englisch als Übersetzung (Localization im Creator Hub). Gleiche Texte wie im Spiel (`badge.<id>.name/.desc` in `src/shared/Texts.luau`).

| # | Id (GameConfig) | Name de | Name en | Beschreibung de | Beschreibung en | Icon-Idee |
| -- | -- | -- | -- | -- | -- | -- |
| 1 | `Welcome` | Willkommen! | Welcome! | Betritt zum ersten Mal Pizza Topping Simulator. | Join Pizza Topping Simulator for the first time. | Lachende Pizza winkt mit Kochmütze, Konfetti |
| 2 | `Coins1K` | Erste Münzen | First Coins | Verdiene insgesamt 1.000 Münzen. | Earn 1,000 coins in total. | Eine goldene Münze mit Pizza-Prägung, Bronze-Rand |
| 3 | `Coins1M` | Münz-Millionär | Coin Millionaire | Verdiene insgesamt 1 Million Münzen. | Earn 1 million coins in total. | Münzstapel, Silber-Rand, „1M“ |
| 4 | `Coins1B` | Münz-Milliardär | Coin Billionaire | Verdiene insgesamt 1 Milliarde Münzen. | Earn 1 billion coins in total. | Schatztruhe voller Münzen, Gold-Rand |
| 5 | `Coins1T` | Pizza-Imperium | Pizza Empire | Verdiene insgesamt 1 Billion Münzen. | Earn 1 trillion coins in total. | Goldene Pizza mit Krone auf Münzberg, Regenbogen-Rand |
| 6 | `Toppings100` | Belag-Anfänger | Topping Rookie | Sammle 100 Beläge. | Collect 100 toppings. | Eine Tomatenscheibe mit Gesicht, Bronze-Rand |
| 7 | `Toppings10K` | Belag-Jäger | Topping Hunter | Sammle 10.000 Beläge. | Collect 10,000 toppings. | Salami, Pilz und Paprika im Kescher, Silber-Rand |
| 8 | `Toppings1M` | Belag-Meister | Topping Master | Sammle 1 Million Beläge. | Collect 1 million toppings. | Riesige überladene Pizza mit goldenen Belägen, Gold-Rand |
| 9 | `Eggs10` | Eier-Neuling | Egg Rookie | Öffne 10 Eier. | Open 10 eggs. | Ei mit Riss, Küken-Auge lugt heraus, Bronze-Rand |
| 10 | `Eggs100` | Eier-Fan | Egg Fan | Öffne 100 Eier. | Open 100 eggs. | Drei bunte Eier im Nest, Silber-Rand |
| 11 | `Eggs1K` | Eier-Profi | Egg Pro | Öffne 1.000 Eier. | Open 1,000 eggs. | Ei mit Sternen-Muster und Glanz, Gold-Rand |
| 12 | `Eggs10K` | Eier-Legende | Egg Legend | Öffne 10.000 Eier. | Open 10,000 eggs. | Regenbogen-Ei auf Thron, Strahlen, Regenbogen-Rand |
| 13 | `FirstLegendary` | Erstes Legendär | First Legendary | Finde dein erstes legendäres Pet. | Find your first Legendary pet. | Pet-Silhouette in Orange-Gold, Legendär-Farbe (255, 170, 30) |
| 14 | `FirstMythic` | Erstes Mythisch | First Mythic | Finde dein erstes mythisches Pet. | Find your first Mythic pet. | Drachenkopf in Mythisch-Farbe, Funken |
| 15 | `FirstShiny` | Erstes Shiny | First Shiny | Finde dein erstes Shiny-Pet. | Find your first Shiny pet. | Pet mit rosa Glitzer und Sternchen-Funkeln |
| 16 | `FirstSecret` | Erstes Geheim | First Secret | Finde dein erstes geheimes Pet. | Find your first Secret pet. | Schwarze Pet-Silhouette mit „?“ und violettem Nebel |

Einheitlicher Stil (siehe `docs/ui-style.md`): runder Rahmen in `DARK` (60, 35, 20), Hintergrund `CREAM` (255, 248, 230) oder Pizza-Orange, dicker Umriss, Comic-Look wie die Kacheln. Reihen-Ränder: Bronze → Silber → Gold → Regenbogen.
