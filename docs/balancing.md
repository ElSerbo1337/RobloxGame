# Balancing: Spielzeit pro Welt (#41, neu eingestellt in #57)

> **Stand #77 (MEGA UPDATE, vorläufig):** Welt 5–6 brauchen jetzt 1 Rebirth, Welt 7 braucht 2 (Rebirth-Stufen der 15 Welten: 1–4: 0, 5–6: 1, 7–8: 2, 9–10: 3, 11–12: 5, 13–14: 7, 15: 10). Damit Welt 1–7 spielbar bleiben, kostet der erste Rebirth vorläufig 150.000 (≈ 28 Min in Welt 4, erster Durchlauf ≈ 64 Min) und jeder weitere ×60 (zweiter Durchlauf Welt 1–6 ≈ 47 Min). Rebirth-Preise: 150.000 · 9 Mio · 540 Mio. Alles Weitere unten beschreibt den Stand vor #77; der Feinschliff für 15 Welten (~40 h) kommt in #108.

Ziel aus Spec #56: Welt 1 ≈ 6, 2 ≈ 9, 3 ≈ 12, 4 ≈ 16, 5 ≈ 20, 6 ≈ 25 Minuten, Welt 7 bis zum ersten Rebirth ≈ 32 Minuten, zusammen ≈ 120 Minuten. Nach einem Rebirth soll Welt 1 etwa 3 Minuten dauern und der zweite Durchlauf bis zum nächsten Rebirth etwa 40–50 Minuten dauern (#58, vorher: etwa so lang wie der erste). Gesteuert wird über Freischalt-, Münz-Shop-, Ei- und Rebirth-Preise. Gem-Preise, Gem-Einkommen, Pet-Plätze und Belagwerte sind unverändert.

## Wie gerechnet wird

`lune run balance [Läufe]` (Skript `.lune/balance.luau`, Modell `tools/BalanceSim.luau`) schickt einen Modellspieler mit den **echten Spielregeln** (`GameRules`) und der echten `GameConfig` durch Welt 1–7, macht den Rebirth und spielt danach bis zum nächsten bezahlbaren Rebirth weiter. Gemessen wird die Spielzeit von der Freischaltung einer Welt bis zur Freischaltung der nächsten. In der letzten erreichbaren Welt zählt die Zeit bis der (nächste) Rebirth bezahlbar ist. Welten, die mehr Rebirths verlangen als der Spieler hat (#43), betritt der Modellspieler in diesem Durchlauf nicht (in der Tabelle „–“). Weil Ei-Ziehungen Glück sind, wird mit 51 verschiedenen Zufallsfolgen gerechnet. Angegeben ist jeweils der Median.

`tests/BalanceSim.spec.luau` (Block „flat pet curve (#57)“) rechnet dasselbe Modell mit 9 Läufen und prüft: jede Welt im ersten Durchlauf zwischen 50 % und 150 % ihres Ziels, gesamt 100–140 Minuten, zweiter Durchlauf 38–52 Minuten (#58).

## Pet-Kurve (#57)

Jedes Pet zählt überall voll (kein Deckel mehr, der Deckel aus #51 ist entfernt). Das beste Pet jeder Welt (beide Eier) folgt einer flachen Kurve. Alle anderen Pets der Welt wurden im selben Verhältnis verkleinert (auf 0,01 gerundet), die Seltenheits-Reihenfolge und das Verhältnis zweites Ei / erstes Ei (≈ ×1,5) bleiben. `tests/GameConfig.spec.luau` prüft die Kurve mit 10 % Toleranz.

| Welt | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
| ---- | -: | -: | -: | -: | -: | -: | -: |
| bestes Pet vorher | +225 % | +450 % | +900 % | +1800 % | +4050 % | +9000 % | +18000 % |
| **bestes Pet jetzt** | **+75 %** | **+110 %** | **+160 %** | **+230 %** | **+320 %** | **+400 %** | **+500 %** |
| bestes Pet im ersten Ei | +50 % | +73 % | +107 % | +153 % | +213 % | +267 % | +333 % |

Spielstände speichern nur Pet-IDs, die Boni kommen aus der Config: keine Migration.

## Ergebnis (Median aus 51 Läufen, Minuten Spielzeit)

| Welt | Ziel | ohne Rebirth | nach 1. Rebirth |
| ---- | ---: | -----------: | --------------: |
| 1 Pizzeria-Garten | 6 | 5.1 | 0.5 |
| 2 Bauernhof | 9 | 9.7 | 1.1 |
| 3 Strand | 12 | 12.8 | 2.0 |
| 4 Eisberge | 16 | 17.1 | 2.9 |
| 5 Vulkan | 20 | 19.5 | 4.0 |
| 6 Süßigkeitenland | 25 | 22.2 | 9.9 |
| 7 Weltraum (bis Rebirth) | 32 | 31.3 | 24.2 |
| **Gesamt** | **120** | **118.2** | **45.2** |

Pet-Multiplikator beim ersten Rebirth im Median: ×7,0 (vorher ×361).

**Nach dem Rebirth** startet der Spieler mit ×7 Pets und ×1,5 Rebirth-Bonus, also etwa ×10 Münzen gegenüber dem ersten Start. Welt 1–6 dauern zusammen nur noch etwa 20 Minuten. In #57 stieg der Rebirth-Preisfaktor auf ×14, damit der zweite Durchlauf so lang ist wie der erste, aber dann farmte man etwa 92 Minuten in Welt 7. Seit #58 ist der **Rebirth-Preisfaktor ×1,5**: Der zweite Durchlauf dauert 45,2 Minuten (Welt 1–6 ≈ 21, Welt 7 bis zum zweiten Rebirth ≈ 24).

Rebirth-Preise: 1. 74 Mio · 2. 111 Mio · 3. 166,5 Mio · 4. 249,75 Mio. Jeder Rebirth kostet mehr als der vorige (Faktor > 1, Konfigurations-Test).

Gemessen (#58, zweiter Durchlauf in Minuten): mit 21 Läufen Faktor 1,01 → 42,2 · 1,5 → 45,7 · 2 → 48,5 · 3 → 55,6; mit 51 Läufen 1,5 → 45,2 · 2 → 48,5. Die in #58 vermutete Größenordnung ×3–×5 ergibt 56–69 Minuten und ist damit zu lang. Den dritten Durchlauf misst die Simulation nicht.

**Welt 1 nach dem Rebirth: Ziel ≈ 3 Minuten wird nicht erreicht (0,5 Min).** Welt 1 hängt nur an Münzpreisen, und die behaltenen Pets plus Rebirth-Bonus machen das Einkommen dort etwa 10-mal so hoch. Mit den erlaubten Stellschrauben geht das nicht: Auch ohne Rebirth-Bonus (`multiplierPerRebirth = 0`) bliebe ×7 von den Pets. Ein 3-Minuten-Welt-1 bräuchte eine Regel, die frühe Welten nach dem Rebirth bremst (z. B. Pets, die erst ab ihrer Welt voll zählen), und genau das sollte wegfallen. Der Test prüft deshalb nur, dass Welt 1 nach dem Rebirth schneller ist.

## Geänderte Preise (#57)

| Was | vorher | jetzt |
| --- | ---: | ---: |
| Freischaltung Bauernhof | 120 | 26 |
| Freischaltung Strand | 2.000 | 690 |
| Freischaltung Eisberge | 42.000 | 12.000 |
| Freischaltung Vulkan | 310.000 | 35.000 |
| Freischaltung Süßigkeitenland | 23 Mio | 900.000 |
| Freischaltung Weltraum | 460 Mio | 12 Mio |
| Erster Rebirth | 3,9 Mrd | 74 Mio |
| Preisfaktor pro Rebirth | ×3 | ×1,5 (#58, in #57 ×14) |
| Eier Welt 1–7 (erstes / zweites Ei) | 25/125, 200/1.000, 1.500/7.500, 12.000/60.000, 100.000/500.000, 800.000/4 Mio, 6,4 Mio/32 Mio | 25/130, 48/240, 500/2.500, 3.700/19.000, 20.000/100.000, 82.000/410.000, 390.000/2 Mio |
| Pizza-Platz Stufe 2–8 | 50, 200 · 5.000, 15.000, 40.000 · 600 Mio, 1,8 Mrd | 26, 48 · 1.600, 4.500, 11.000 · 16 Mio, 40 Mio |
| Reichweite Stufe 1–8 | 30, 100, 400 · 8.000, 25.000, 60.000 · 400 Mio, 1,2 Mrd | 25, 26, 110 · 2.500, 7.300, 15.000 · 12 Mio, 28 Mio |
| Magnet Stufe 1–5 | 300 · 30.000, 100.000 · 500 Mio, 1,5 Mrd | 77 · 8.700, 20.000 · 14 Mio, 34 Mio |

(„·“ trennt Shop 1, 2 und 3.) Unverändert: erstes Pizza-Platz-Upgrade 12 und Garten-Ei 25 (Tutorial, #23), Gem-Preise und Gem-Einkommen, Pet-Plätze, Tränke, Belagwerte, Rebirth-Bonus +50 %.

Eingestellt wurde mit einer Hilfsrechnung: ein Faktor pro Welt, alle Münzpreise dazwischen log-linear angepasst (Reihenfolge bleibt), zweites Ei = 5 × erstes Ei, dann mit dem Simulator iteriert und die Freischaltpreise von Bauernhof, Vulkan, Süßigkeitenland und Weltraum von Hand nachgestellt. Welt 1 ist sehr empfindlich: Bauernhof 28 statt 26 macht aus 5 Minuten 8, weil das Starteinkommen klein ist. Eine Bauernhof-Schranke über etwa 30 Münzen passt nicht zu 6 Minuten (mit 60 Münzen dauert Welt 1 etwa 11 Minuten, auch wenn Shop 1 billiger wird).

## Annahmen des Modellspielers

- **Einkommen:** genau die Einkommens-Schätzung `rules.incomePerMinute`, also durchschnittlicher Belagwert der höchsten Welt × Pizza-Platz × 2 Runden pro Minute × Münz-Multiplikator (Pets, Rebirth). Verkauft und geliefert wird immer in der höchsten freigeschalteten Welt. Dazu kommt der Münz-Trank (×2), solange er läuft. Kein Laufweg zum Tor, keine Pausen.
- **Spielweise:** 60 Minuten Spielzeit pro Tag. Zu Beginn jedes Tages wird der Login-Kalender abgeholt, die Spielzeit-Geschenke sobald sie bereit sind. Das Tutorial gilt als erledigt.
- **Lieferaufträge:** Jeder Anruf wird angenommen und nach 60 Sekunden geliefert (2/3 der Zeit übrig, also +33 % Tempo-Bonus). Belohnung über die echten Regeln (Münzen, Gems oder Tränke). Die bestellten Beläge werden nicht verkauft, ihr Verkaufswert wird vom Einkommen abgezogen.
- **Gems:** aus Gem-Belägen (1 von 150 Belägen, 1–3 Gems) auf dieselbe Belagzahl wie das Einkommen, dazu Aufträge, Geschenke und Kalender. Gems gehen zuerst in Pet-Plätze. Wenn der erreichbare Shop keinen weiteren Platz verkauft, werden Münz-Tränke gekauft.
- **Tränke:** werden sofort getrunken. Der Glücks-Trank wirkt über die echten Regeln auf Eier, der Speed-Trank hat im Modell keine Wirkung.
- **Münzen,** in dieser Reihenfolge:
  1. Nächste Welt, sobald bezahlbar.
  2. Pizza-Platz, sobald bezahlbar (alle Shops, auch Shop 3).
  3. Eier nur aus der höchsten Welt, wenn sich das Ei rechnerisch in höchstens 10 Minuten bezahlt macht. Gerechnet wird mit dem erwarteten Bonus-Gewinn gegenüber dem schwächsten ausgerüsteten Pet. Danach „Beste ausrüsten“, bei vollem Inventar wird das schwächste nicht ausgerüstete Pet gelöscht.
  4. Reichweite und Magnet, wenn sie höchstens 5 Minuten Einkommen kosten (im Modell ohne Einkommenswirkung).
- **Rebirth:** sofort, wenn bezahlbar und alle Welten gekauft sind, die die bisherigen Rebirths erlauben. Der zweite Durchlauf endet, sobald der zweite Rebirth bezahlbar ist.

## Wie empfindlich das Ergebnis ist

Gleiche Preise, ein Parameter des Modellspielers geändert (Median aus 51 Läufen):

| Variante | Welt 1–7 je Welt (Min) | Gesamt ohne Rebirth | Gesamt nach 1. Rebirth |
| -------- | ---------------- | ------------------: | ---------------------: |
| Basis (2 Runden/Min) | 5 / 10 / 13 / 17 / 20 / 22 / 31 | 118.2 | 45.2 |
| 1,5 Runden/Min | 7 / 11 / 17 / 22 / 26 / 38 / 40 | 159.0 | 65.1 |
| 3 Runden/Min | 4 / 8 / 10 / 9 / 9 / 16 / 26 | 84.5 | 31.8 |
| 30 Min pro Tag | 5 / 10 / 13 / 16 / 15 / 20 / 28 | 106.3 | 41.1 |
| Ei-Amortisation 5 Min | 5 / 10 / 15 / 18 / 22 / 39 / 40 | 156.2 | 51.9 |
| Ei-Amortisation 20 Min | 5 / 12 / 10 / 16 / 14 / 21 / 32 | 109.5 | 33.9 |

Am stärksten wirken das Rundentempo und wie viel der Spieler in Eier steckt. Bei kleiner Pizza (Welt 1) sind 2 Runden pro Minute eher vorsichtig gerechnet, echte Spieler sind dort vermutlich schneller. Spieler mit kurzen Tagen kommen pro Spielminute schneller voran, weil die ersten Geschenke des Tages früh kommen. Die Zeiten sollten deshalb in Studio mit der Stoppuhr nachgemessen werden (Checkliste #41 in `docs/pc-todo.md`).

## Geschenke und Login-Kalender (#50)

Spielzeit-Geschenke und Login-Kalender geben feste Mengen Gems und Tränke, keine Münzen mehr. Die Belohnung hängt nicht von Welt, Pets oder Rebirths ab. Lieferaufträge sind unverändert (ihre Münzen hängen an den gelieferten Belägen).

| Quelle | Belohnungen | Gems |
| --- | --- | ---: |
| Geschenke (5 / 10 / 15 / 25 / 40 / 60 Min) | 3 Gems / 5 Gems / 1 Trank / 1 Trank / 8 Gems / 10 Gems + 1 Trank | 26 pro Tag |
| Kalender (Tag 1–7) | 5 Gems / 10 Gems / 1 Trank / 1 Trank / 20 Gems / 2 Tränke / 50 Gems + 3 Tränke | 85 pro Woche, ca. 12 pro Tag |
| **Zusammen** bei 60 Minuten pro Tag | | **ca. 38 pro Stunde** |

Vorher waren es 30 + ca. 11 Gems pro Tag, das Ziel von 20–40 Gems pro Stunde bleibt also grob eingehalten (ein Konfigurations-Test prüft Geschenke + durchschnittlichen Kalendertag auf 20–40). Gem-Beläge und Lieferaufträge kommen dazu. Wer kürzer als 60 Minuten spielt, bekommt pro Spielminute mehr, weil die ersten Geschenke früh kommen.

Die Münzen der beiden alten Münz-Geschenke und der zwei Münz-Kalendertage waren etwa 10 % des Einkommens eines 60-Minuten-Tages. Zum Ausgleich sinken der Preis für den Bauernhof (170 → 120) und der erste Rebirth (4,9 → 3,9 Mrd).

## Welten hinter Rebirths (#43)

Jede Welt in `GameConfig.worlds` kann neben `unlockPrice` ein Feld `requiredRebirths` haben (Standard 0). Die Regel „Welt freischalten“ lehnt mit dem Grund `NotEnoughRebirths` ab, solange der Spieler weniger Rebirths hat. Barrieren-Tor, Freischalt-Knopf und Portal-Menü zeigen dann „Ab X Rebirths“ über dem Preis. Welt 1–7 brauchen 0 Rebirths, am heutigen Spiel ändert sich nichts (ein Konfigurations-Test prüft das).

Geplanter Ausbau (noch nicht gebaut):

| Rebirths | erreichbar bis |
| ---: | --- |
| 0 | Welt 7 |
| 1 | Welt 10 |
| 2 | Welt 12 |
| 3 | Welt 14 |

Danach weiter so, 2–3 neue Welten pro Rebirth. Der Rebirth-Preisfaktor ist heute ×1,5 (#58) und muss mit den neuen Welten neu gemessen werden.

**Neue Welten anhängen:**

1. Welt am Ende von `GameConfig.worlds` ergänzen (Belag-Spawns, Eier, Farbe wie die anderen Welten) und `requiredRebirths` nach der Tabelle setzen, z. B. Welt 8–10 `requiredRebirths = 1`. Die Zahl darf von Welt zu Welt nur gleich bleiben oder steigen (Konfigurations-Test).
2. Den Münzpreis an der Einkommens-Stufe davor ausrichten: Ab Rebirth 1 kommt der Spieler mit ×1,5 Münzen und seinen Pets aus Welt 7 in die neue Welt. Als Startwert etwa das 10- bis 20-fache der vorigen Welt nehmen.
3. `lune run balance` ausführen. Die Simulation spielt im ersten Durchlauf nur bis zur letzten Welt ohne Rebirth-Bedingung und macht dort den Rebirth. Im zweiten Durchlauf kauft sie alle Welten, die 1 Rebirth erlaubt, und misst die Zeit bis zum zweiten Rebirth. Welten hinter mehr Rebirths stehen mit „–“ in der Tabelle.
4. Preise anpassen, bis jede neue Welt im zweiten Durchlauf etwa 30–40 Minuten dauert und der zweite Rebirth erst danach bezahlbar ist. Liegt der zweite Rebirth zu früh, hebt `rebirth.startPrice` (bzw. der Faktor) mit den neuen Welten mit. Welten für 2 und mehr Rebirths misst die Simulation heute nicht. Dafür müsste `tools/BalanceSim.luau` um weitere Durchläufe erweitert werden.
5. Tabelle hier ersetzen, Zielbänder in `tests/BalanceSim.spec.luau` ergänzen, `lune run test`.

`tests/BalanceSim.spec.luau` prüft mit einer angehängten Testwelt hinter 1 Rebirth, dass die Simulation die Bedingung beachtet.

## Neu rechnen

Nach Preisänderungen `lune run balance` ausführen, die Tabelle hier ersetzen und `lune run test` laufen lassen. Die Simulator-Tests (`tests/BalanceSim.spec.luau`) schlagen an, wenn eine Welt deutlich aus ihrem Zielband fällt.
