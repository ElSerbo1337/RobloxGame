# Balancing: 15 Welten, ~40 Stunden (#108)

Stand nach dem MEGA UPDATE (Spec #72, Ticket #108). Ziele:

- **~40 h aktives Spielen bis Welt 15**, ein **Rebirth alle ~45–90 Minuten**.
- Rebirth-Stufen (`requiredRebirths`): Welt 1–4: 0, 5–6: 1, 7–8: 2, 9–10: 3, 11–12: 5, 13–14: 7, 15: 10.
- **Schneller Einstieg:** Welt-1-Beläge doppelt so viel wert (2 / 4 / 10), erstes Pizza-Platz-Upgrade 15 Münzen → nach ~3 Runden.
- **Gem-Wirtschaft:** ~20–40 Gems pro Stunde aus regulären Quellen, dazu Quests (~45 am Tag).

Alles gemessen mit `lune run balance` (Modell `tools/BalanceSim.luau`, echte `GameRules` und `GameConfig`) und geprüft in `tests/BalanceSim.spec.luau`.

## Ergebnis (Median aus 21 Läufen, 60 Minuten Spielzeit pro Tag)

| Welt | ab Rebirths | erreicht nach (h) | Rebirths dann | Zeit bis zur nächsten Welt (Min) |
| ---- | ----------: | ----------------: | ------------: | -------------------------------: |
| 1 Pizzeria-Garten | 0 | 0,0 | 0 | 5 |
| 2 Bauernhof | 0 | 0,1 | 0 | 8 |
| 3 Strand | 0 | 0,2 | 0 | 16 |
| 4 Eisberge | 0 | 0,5 | 0 | 88 |
| 5 Vulkan | 1 | 2,0 | 1 | 119 |
| 6 Süßigkeitenland | 1 | 4,0 | 3 | 130 |
| 7 Weltraum | 2 | 6,2 | 5 | 150 |
| 8 Atlantis | 2 | 8,7 | 7 | 163 |
| 9 Dschungel-Tempel | 3 | 11,3 | 9 | 194 |
| 10 Wüsten-Pyramiden | 3 | 14,8 | 12 | 233 |
| 11 Spukschloss | 5 | 18,7 | 15 | 262 |
| 12 Dino-Urzeit | 5 | 23,1 | 18 | 281 |
| 13 Kristallhöhle | 7 | 27,7 | 21 | 301 |
| 14 Wolkenstadt | 7 | 32,7 | 25 | 373 |
| 15 Pizza-Paradies | 10 | **39,0** | **30** | – |

„Zeit bis zur nächsten Welt“ enthält alle Rebirths dazwischen (nach jedem Rebirth werden die Welten neu gekauft; die alten gehen dank Pets und Rebirth-Bonus schnell).

### Rebirth-Zeitpunkte

Typischer Lauf (der Lauf mit der mittleren Gesamtzeit), Stunden Spielzeit beim Rebirth:

| Rebirth | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
| --- | -: | -: | -: | -: | -: | -: | -: | -: | -: | -: |
| nach (h) | 1,4 | 2,6 | 3,3 | 4,3 | 5,0 | 6,1 | 6,8 | 7,7 | 8,7 | 9,8 |
| **Rebirth** | **11** | **12** | **13** | **14** | **15** | **16** | **17** | **18** | **19** | **20** |
| nach (h) | 10,8 | 12,1 | 13,4 | 14,6 | 16,0 | 17,6 | 19,2 | 20,8 | 22,6 | 24,4 |
| **Rebirth** | **21** | **22** | **23** | **24** | **25** | **26** | **27** | **28** | **29** | **30** |
| nach (h) | 26,3 | 27,8 | 28,9 | 30,0 | 31,5 | 33,2 | 34,8 | 35,7 | 36,6 | 37,7 |

Ein Durchlauf (Rebirth zu Rebirth) dauert im Median 70 Minuten, die meisten 45–100 Minuten (je nach Glück bei Eiern und beim Verschmelzen). Der erste Durchlauf bis zum ersten Rebirth (Welt 1–4) dauert ~80 Minuten. Die Rebirth-Stufen bremsen nur am Anfang (Welt 5–8); danach bestimmen die Münzpreise, wann eine Welt kommt, und der Spieler hat mehr Rebirths als die Stufe verlangt (Welt 15: 30 statt 10).

### Gems pro Tag (60-Minuten-Tag, Median über die ganze Kampagne)

| Quelle | Gems pro Tag | Art |
| --- | ---: | --- |
| Gem-Beläge (1 von 600, 1–3 Gems) | 7 | regulär |
| Lieferaufträge (7 % Gems, 3–10) | 7 | regulär |
| Spielzeit-Geschenke (3 / 4 / – / – / 4 / 5) | 16 | regulär |
| 30-Tage-Kalender (250 Gems in 30 Tagen) | 8 | regulär |
| **Reguläre Quellen** | **38** | Ziel 20–40 pro Stunde |
| Glücksrad (2 Gratis-Drehungen) | 10 | täglich |
| Geheime Truhen (5 × 5 Gems, ab Welt 3) | 16 | täglich |
| Tagesquests (3 × 8 Gems oder Trank, Bonus 20, Serie 100/7) | 46 | täglich |
| Wochenquests (3 × 30 pro Woche) | 13 | täglich im Schnitt |
| **Zusammen** | **~123** | |

Wer länger als 60 Minuten am Tag spielt, bekommt pro Stunde weniger (Kalender, Rad, Truhen und Quests gibt es einmal am Tag). Über die ~40 Tage der Kampagne kommen so ~4.800 Gems zusammen. Die Pet-Plätze 4–11 kosten zusammen 4.460 Gems, ein Spieler, der seine Gems zuerst in Pet-Plätze steckt, hat den letzten Platz (Welt-15-Shop) also ungefähr bei Welt 15.

## Wie die Zahlen gebaut sind

**Rebirth:** Preis = 300.000 × 2^Rebirths (×2 pro Rebirth), Bonus +25 % Münzen pro Rebirth (vorher +50 %). Preise: 1. 300.000 · 2. 600.000 · 5. 9,6 Mio · 10. 307 Mio · 20. 314 Mrd · 30. 322 Bio.

**Welten:** Für jede Welt ab 5 ist ein Durchlauf geplant, in dem sie zum ersten Mal gekauft wird. Ihr Preis liegt bei etwa 0,8 × dem Rebirth-Preis dieses Durchlaufs (Welt 5: 0,25 ×). Damit ist sie teurer als der Rebirth im Durchlauf davor (der Spieler macht dort lieber den Rebirth) und billiger als der Rebirth im geplanten Durchlauf (dort kauft er zuerst die Welt). `tests/GameConfig.spec.luau` prüft genau das.

**Belagwerte:** Pro Welt so gesetzt, dass der Spieler im geplanten Durchlauf etwa die Hälfte der Zeit in der Welt davor für den Freischaltpreis farmt und dann in der neuen Welt bis zum Rebirth. Daraus ergibt sich der Schritt von Welt zu Welt: früh ×1,5–2,5 (ein bis zwei Rebirths dazwischen, Pets wachsen noch schnell), spät ×5–17 (drei bis vier Rebirths). Eier kosten im gleichen Verhältnis wie die Beläge ihrer Welt. Die Münz-Upgrades von Shop 3 (Welt 7) sind entsprechend billiger geworden.

| Welt | ab Rebirths | geplanter Durchlauf | Freischaltung | Ø Belag | Ei(er) | bestes Pet |
| --- | -: | -: | -: | -: | -: | -: |
| 1 Pizzeria-Garten | 0 | 0 | 0 | 3,4 | 25 / 130 | +55 % |
| 2 Bauernhof | 0 | 0 | 75 | 7,8 | 48 / 240 | +69 % |
| 3 Strand | 0 | 0 | 690 | 37 | 500 / 2.500 | +86 % |
| 4 Eisberge | 0 | 0 | 12.000 | 148 | 3.700 / 19.000 | +107 % |
| 5 Vulkan | 1 | 1 | 150.000 | 372 | 10.000 / 52.000 | +134 % |
| 6 Süßigkeitenland | 1 | 3 | 1,9 Mio | 594 | 14.000 / 71.000 | +168 % |
| 7 Weltraum | 2 | 5 | 7,7 Mio | 911 | 21.000 / 110.000 | +210 % |
| 8 Atlantis | 2 | 7 | 31 Mio | 1.855 | 110.000 | +262 % |
| 9 Dschungel-Tempel | 3 | 9 | 120 Mio | 6.150 | 350.000 | +328 % |
| 10 Wüsten-Pyramiden | 3 | 12 | 980 Mio | 46.700 | 14 Mio | +410 % |
| 11 Spukschloss | 5 | 15 | 7,9 Mrd | 387.500 | 130 Mio | +512 % |
| 12 Dino-Urzeit | 5 | 18 | 63 Mrd | 2 Mio | 660 Mio | +640 % |
| 13 Kristallhöhle | 7 | 21 | 500 Mrd | 9,8 Mio | 2,8 Mrd | +800 % |
| 14 Wolkenstadt | 7 | 25 | 8,1 Bio | 170 Mio | 49 Mrd | +1000 % |
| 15 Pizza-Paradies | 10 | 30 | 260 Bio | 615 Mio | 180 Mrd | +1250 % |

**Pets:** Die flache Kurve aus #57 (+75 … +500 %, danach +140 % pro Welt) ist ersetzt durch **+55 % in Welt 1 und ×1,25 pro Welt bis +1250 % in Welt 15**. Früher sprang der Pet-Multiplikator in den ersten Stunden von ×1,6 auf ×35 und wuchs danach kaum noch; dann waren frühe Durchläufe 15–30 Minuten kurz und späte zu lang. Jetzt wächst er gleichmäßig (Ende der Kampagne ~×45). Alle Pets einer Welt im gleichen Verhältnis, Geheim-Pets bleiben beim Doppelten des besten Pets ihrer Welt. Unverändert: Gold ×2,5 (5 Pets), Regenbogen ×6 (5 Gold), Shiny ×1,5, Pet-Level +2 % pro Stufe, Index-Bonus **+4 % pro kompletter Welt** (Spec 3–5 %, +60 % mit allen 15). Kalender-Fuchs (Tag 30) jetzt +500 % (vorher +150 %, das war um Tag 30 schwächer als jedes Ei-Pet), Händler-Kamel bleibt +200 %.

**Pet-Plätze und Inventar:** Grund-Inventar 50 → **75** (+50 %), alle Inventar-Stufen ×1,5 (110 / 150 / 225 / 300 / 450) plus drei neue Stufen 600 / 750 / 900 (2.200 / 3.000 / 4.000 Gems). Pet-Plätze bis 8 billiger (40 / 120 / 250 / 450 / 700 statt 50 / 150 / 400 / 1.000 / 2.500) plus drei neue Stufen: 9 Plätze (750 Gems, Shop Welt 10), 10 (950, Welt 12), 11 (1.200, Welt 15). Pizza-Platz bleibt bei 20: mehr Beläge passen nicht in dieselbe Rundenzeit.

### Geänderte Zahlen (#108)

| Was | vorher | jetzt |
| --- | ---: | ---: |
| Welt-1-Beläge (Salami / Pilz / Mozzarella) | 1 / 2 / 5 | 2 / 4 / 10 |
| Erstes Pizza-Platz-Upgrade | 12 | 15 |
| Freischaltung Bauernhof | 26 | 75 |
| Freischaltung Welt 5–15 | 35.000 … 40 Bio | 150.000 … 260 Bio (Tabelle oben) |
| Beläge, Eier Welt 5–15 | ×4,8 pro Welt | Tabelle oben |
| Erster Rebirth / Faktor / Bonus | 150.000 / ×60 / +50 % | 300.000 / ×2 / +25 % |
| Shop 3: Pizza-Platz 7–8, Reichweite 7–8, Magnet 4–5 | 16 / 40 Mio, 12 / 28 Mio, 14 / 34 Mio | 1,2 / 2,9 Mio, 870.000 / 2 Mio, 1 / 2,5 Mio |
| Gem-Beläge | 1 von 150 | 1 von 600 |
| Lieferung: Gewichte Münzen / Gems / Trank | 65 / 20 / 15 | 73 / 7 / 20 |
| Spielzeit-Geschenke (Gems pro Tag) | 26 | 16 |
| 30-Tage-Kalender (Gems in 30 Tagen) | 384 | 250 |
| Geheime Truhe | 10 Gems | 5 Gems |
| Shiny- / Gold- / Mega-Trank | 40 / 40 / 120 | 35 / 35 / 90 (Händler: 45) |

Unverändert: Glücksrad (Spec), Quests (8 Gems oder Trank, Bonus 20 + Trank, Serie 100 + Mega-Trank, Woche 30), Codes, Händler-Ei (60) und -Pet (750), Münz-/Glücks-/Speed-Trank, Gold-Glück, Laufgeschwindigkeit, 3 Eier auf einmal, Eisberge- und Strand-Preise, Garten-Ei 25 (Tutorial).

Große Zahlen: Kurzformen gibt es jetzt bis „Brd“/„Qa“ (10^15) und „Trio“/„Qi“ (10^18), denn späte Rebirths kosten mehrere hundert Billionen.

## Annahmen des Modellspielers

- **Einkommen:** `rules.incomePerMinute` (Durchschnittsbelag der höchsten Welt × Pizza-Platz × 2 Runden pro Minute × Münz-Multiplikator) × goldene Beläge (1 % × 10) × Münz-Trank. Verkauft und geliefert wird in der höchsten freigeschalteten Welt, ohne Laufwege und Pausen.
- **Tag:** 60 Minuten Spielzeit pro deutschem Tag. Kalender beim Start, Geschenke sobald bereit, die zwei Gratis-Drehungen am Glücksrad, jede geheime Truhe der freigeschalteten Welten einmal am Tag. Quests werden nicht gespielt: ihre erwarteten Gems (alle erledigt, `BalanceSim.questGemsPerDay`) kommen nach der halben Tages-Spielzeit.
- **Lieferaufträge:** jeder Anruf angenommen und nach 60 Sekunden geliefert; die bestellten Beläge werden nicht verkauft.
- **Gems:** zuerst Pet-Plätze, sonst Münz-Tränke. Alle Tränke werden sofort getrunken.
- **Münzen:** nächste Welt sobald bezahlbar, Pizza-Platz, Eier der höchsten Welt, wenn sie sich in 10 Minuten bezahlt machen (dann „Beste ausrüsten“, bei vollem Inventar das schwächste nicht ausgerüstete Pet löschen), Reichweite/Magnet für höchstens 5 Minuten Einkommen.
- **Pets:** ausgerüstete Pets steigen im Level, 5 gleiche werden zu Gold/Regenbogen verschmolzen, wenn der Pet-Multiplikator dabei nicht sinkt. Shiny- und Geheim-Pets bleiben weg (Glückstreffer).
- **Rebirth:** sobald bezahlbar, außer die nächste erlaubte Welt kostet höchstens so viel wie der Rebirth – dann zuerst die Welt.

## Wie empfindlich das Ergebnis ist

Gleiche Preise, ein Parameter des Modellspielers geändert (Median aus 9 Läufen, `lune run balance 9 v`):

| Variante | Welt 15 nach (h) | Rebirths |
| -------- | ---------------: | -------: |
| Basis (2 Runden/Min) | 39,0 | 30 |
| 1,5 Runden/Min | 54,8 | 30 |
| 3 Runden/Min | 24,4 | 30 |
| 30 Min pro Tag | 32,2 | 30 |
| Ei-Amortisation 5 Min | 56,2 | 30 |
| Ei-Amortisation 20 Min | 29,0 | 30 |

Am stärksten wirken das Rundentempo und wie viel der Spieler in Eier steckt. Die Zahl der Rebirths bleibt gleich, weil die Freischaltpreise an den Rebirth-Preisen hängen; schnellere Spieler machen nur kürzere Durchläufe. Die Zeiten sollten in Studio mit der Stoppuhr nachgemessen werden (Checkliste #108 in `docs/pc-todo.md`).

## Neu rechnen

1. Zahlen in `src/shared/GameConfig.luau` ändern.
2. `lune run balance [Läufe] [v]` ausführen (Standard 15 Läufe, `v` = auch die Varianten-Tabelle), Tabellen hier ersetzen.
3. `lune run test`: `tests/BalanceSim.spec.luau` prüft mit 5 Läufen 34–46 h bis Welt 15, 25–35 Rebirths, Durchläufe im Median 45–90 Minuten (80 % in 35–120), den ersten Rebirth in Welt 4 nach 45–100 Minuten, Welt 1–3 schnell, nie eine Welt vor ihrer Rebirth-Stufe, 20–40 reguläre Gems pro Stunde und ~45 Quest-Gems am Tag. `tests/GameConfig.spec.luau` prüft Preisreihenfolge, Rebirth-Plan und Pet-Kurve.

Faustregeln: Ein Durchlauf in Welt k zu lang → Beläge (und Eier) der Welt k-1 und k etwas teurer machen. Welt 15 zu früh/spät → Läufe insgesamt kürzer/länger (alle Werte ab Welt 5 gemeinsam skalieren) oder den geplanten Durchlauf einer späten Welt (Freischaltpreis = 0,8 × 300.000 × 2^Durchlauf) verschieben.

## Geschichte

- #41/#57/#58: 7 Welten, ~2 h bis zum ersten Rebirth, flache Pet-Kurve, Rebirth-Faktor ×1,5.
- #43: Welten hinter Rebirths (`requiredRebirths`).
- #77: Rebirth-Stufen der 15 Welten, vorläufig erster Rebirth 150.000 und Faktor ×60.
- #108: dieses Balancing für 15 Welten.
