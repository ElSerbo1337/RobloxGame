# Balancing: Spielzeit pro Welt (#41)

Ziel aus Spec #19: Welt 1–2 je ca. 10–15 Minuten, Welt 3–5 je ca. 20–25 Minuten, Welt 6–7 je ca. 30–35 Minuten. Welt 7 läuft bis zum ersten Rebirth. Nach dem ersten Rebirth soll ein Durchlauf durch Welt 1–7 etwa halb so lang sein. Gesteuert wird das nur über Freischalt-, Shop-, Ei- und Rebirth-Preise. Die Belagwerte sind unverändert.

## Wie gerechnet wird

`lune run balance [Läufe]` (Skript `.lune/balance.luau`, Modell `tools/BalanceSim.luau`) schickt einen Modellspieler mit den **echten Spielregeln** (`GameRules`) und der echten `GameConfig` durch Welt 1–7, macht den Rebirth und spielt danach bis zum nächsten bezahlbaren Rebirth weiter. Gemessen wird die Spielzeit von der Freischaltung einer Welt bis zur Freischaltung der nächsten. In der letzten erreichbaren Welt zählt die Zeit bis der (nächste) Rebirth bezahlbar ist. Welten, die mehr Rebirths verlangen als der Spieler hat (#43), betritt der Modellspieler in diesem Durchlauf nicht (in der Tabelle „–“). Weil Ei-Ziehungen Glück sind, wird mit 51 verschiedenen Zufallsfolgen gerechnet. Angegeben ist jeweils der Median.

Die Konfigurations-Tests (`tests/GameConfig.spec.luau`, Block „GameConfig balancing“) rechnen dasselbe Modell mit 9 Läufen und prüfen die Zielbänder mit etwas Spielraum.

## Ergebnis (Median aus 51 Läufen, Minuten Spielzeit)

| Welt | ab Rebirths | ohne Rebirth | nach 1. Rebirth |
| ---- | ----------: | -----------: | --------------: |
| 1 Pizzeria-Garten | 0 | 15.1 | 0.1 |
| 2 Bauernhof | 0 | 13.4 | 0.2 |
| 3 Strand | 0 | 19.8 | 0.2 |
| 4 Eisberge | 0 | 17.7 | 0.4 |
| 5 Vulkan | 0 | 25.3 | 2.5 |
| 6 Süßigkeitenland | 0 | 38.5 | 8.6 |
| 7 Weltraum (bis Rebirth) | 0 | 33.7 | 31.1 |
| **Gesamt** | | **169.9** | **42.1** |

Pet-Multiplikator beim ersten Rebirth im Median: ×361.

**Nach dem Rebirth** ist ein Durchlauf etwa **ein Viertel** so lang (42 statt 170 Minuten), nicht genau die Hälfte. Pets bleiben beim Rebirth erhalten. Mit Weltraum-Pets (×300 und mehr) dauern Welt 1–5 zusammen nur noch etwa 3 Minuten, egal welche Preise dort stehen. Die Länge des zweiten Durchlaufs hängt deshalb fast nur an Welt 6–7 und am Preisfaktor des zweiten Rebirths:

| Preisfaktor pro Rebirth | Durchlauf nach 1. Rebirth | Anteil vom ersten |
| ---: | ---: | ---: |
| ×2 (bisher, #35) | 43 Min | 28 % |
| **×3 (gewählt)** | **52 Min** | **34 %** |
| ×4 | 56 Min | 36 % |
| ×5 | 65 Min | 42 % |
| ×6 | ca. 73 Min | ca. 50 % |

(31 Läufe, gleiche übrige Preise.) Genau „halb so lang“ ginge nur mit Faktor ×6. Dann kostete aber jeder weitere Rebirth das Sechsfache, während der Multiplikator nur um +0,5 steigt. Ab dem dritten Rebirth würde ein Durchlauf schnell mehrere Stunden dauern. ×3 ist der Kompromiss: deutlich kürzerer zweiter Durchlauf und moderat steigende spätere Rebirths. Wer näher an „halb so lang“ will, erhöht `rebirth.priceFactor`. Alles andere bleibt gleich.

## Geänderte Preise

| Was | vorher | jetzt |
| --- | ---: | ---: |
| Freischaltung Bauernhof | 1.500 | 120 (#50, vorher 170) |
| Freischaltung Strand | 15.000 | 2.000 |
| Freischaltung Eisberge | 150.000 | 42.000 |
| Freischaltung Vulkan | 1.500.000 | 310.000 |
| Freischaltung Süßigkeitenland | 15 Mio | 23 Mio |
| Freischaltung Weltraum | 150 Mio | 460 Mio |
| Erster Rebirth | 250 Mio | 3,9 Mrd (#50, vorher 4,9 Mrd) |
| Preisfaktor pro Rebirth | ×2 | ×3 |
| Shop 1 Pizza-Platz Stufe 2 / 3 | 120 / 500 | 50 / 200 |
| Shop 1 Reichweite Stufe 1–3 | 40 / 200 / 800 | 30 / 100 / 400 |
| Shop 1 Magnet Stufe 1 | 600 | 300 |
| Shop 3 Pizza-Platz Stufe 7 / 8 | 400 Mio / 1,2 Mrd | 600 Mio / 1,8 Mrd |
| Shop 3 Reichweite Stufe 7 / 8 | 250 / 700 Mio | 400 Mio / 1,2 Mrd |
| Shop 3 Magnet Stufe 4 / 5 | 300 / 900 Mio | 500 Mio / 1,5 Mrd |

Unverändert: erstes Pizza-Platz-Upgrade 12 (#23), alle Ei-Preise (Garten-Ei 25, sonst ×8 pro Welt, zweites Ei ×5), Shop 2, Gem-Preise, Tränke, Belagwerte, Pet-Boni.

Warum so: Shop 1 war für das Einkommen in Welt 1 viel zu teuer. Allein der Pizza-Platz 4 → 6 für 500 dauerte etwa 35 Minuten. Die frühen Freischaltpreise sinken deshalb stark. Ab Welt 5 wächst das Einkommen schneller als die alten Preise (Belag ×4,8 und Pets ×2 pro Welt, dazu mehr Eier), deshalb steigen die späten Preise. Shop 3 liegt unter dem Rebirth-Preis und wird auf dem Weg dorthin gekauft.

## Annahmen des Modellspielers

- **Einkommen:** genau die Einkommens-Schätzung `rules.incomePerMinute`, also durchschnittlicher Belagwert der höchsten Welt × Pizza-Platz × 2 Runden pro Minute × Münz-Multiplikator (Pets, Rebirth). Dazu kommt der Münz-Trank (×2), solange er läuft. Kein Laufweg zum Tor, keine Pausen.
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
| Basis (2 Runden/Min) | 15 / 13 / 20 / 18 / 25 / 39 / 34 | 169.9 | 42.1 |
| 1,5 Runden/Min | 17 / 18 / 34 / 24 / 36 / 49 / 43 | 220.9 | 58.8 |
| 3 Runden/Min | 14 / 10 / 10 / 12 / 16 / 23 / 26 | 115.7 | 29.7 |
| 30 Min pro Tag | 15 / 13 / 19 / 14 / 19 / 31 / 32 | 150.2 | 38.3 |
| Ei-Amortisation 5 Min | 15 / 19 / 41 / 20 / 32 / 47 / 38 | 211.5 | 50.8 |
| Ei-Amortisation 20 Min | 18 / 15 / 15 / 20 / 21 / 32 / 29 | 155.6 | 39.3 |

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

Danach weiter so, 2–3 neue Welten pro Rebirth. Der Rebirth-Preisfaktor bleibt ×3.

**Neue Welten anhängen:**

1. Welt am Ende von `GameConfig.worlds` ergänzen (Belag-Spawns, Eier, Farbe wie die anderen Welten) und `requiredRebirths` nach der Tabelle setzen, z. B. Welt 8–10 `requiredRebirths = 1`. Die Zahl darf von Welt zu Welt nur gleich bleiben oder steigen (Konfigurations-Test).
2. Den Münzpreis an der Einkommens-Stufe davor ausrichten: Ab Rebirth 1 kommt der Spieler mit ×1,5 Münzen und seinen Pets aus Welt 7 in die neue Welt. Als Startwert etwa das 10- bis 20-fache der vorigen Welt nehmen.
3. `lune run balance` ausführen. Die Simulation spielt im ersten Durchlauf nur bis zur letzten Welt ohne Rebirth-Bedingung und macht dort den Rebirth. Im zweiten Durchlauf kauft sie alle Welten, die 1 Rebirth erlaubt, und misst die Zeit bis zum zweiten Rebirth. Welten hinter mehr Rebirths stehen mit „–“ in der Tabelle.
4. Preise anpassen, bis jede neue Welt im zweiten Durchlauf etwa 30–40 Minuten dauert und der zweite Rebirth erst danach bezahlbar ist. Liegt der zweite Rebirth zu früh, hebt `rebirth.startPrice` (bzw. der Faktor) mit den neuen Welten mit. Welten für 2 und mehr Rebirths misst die Simulation heute nicht. Dafür müsste `tools/BalanceSim.luau` um weitere Durchläufe erweitert werden.
5. Tabelle hier ersetzen, Zielbänder in `tests/GameConfig.spec.luau` ergänzen, `lune run test`.

`tests/BalanceSim.spec.luau` prüft mit einer angehängten Testwelt hinter 1 Rebirth, dass die Simulation die Bedingung beachtet.

## Neu rechnen

Nach Preisänderungen `lune run balance` ausführen, die Tabelle hier ersetzen und `lune run test` laufen lassen. Die Konfigurations-Tests schlagen an, wenn eine Welt deutlich aus ihrem Zielband fällt.
