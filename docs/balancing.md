# Balancing: Spielzeit pro Welt (#41)

Ziel aus Spec #19: Welt 1–2 je ca. 10–15 Minuten, Welt 3–5 je ca. 20–25 Minuten, Welt 6–7 je ca. 30–35 Minuten. Welt 7 läuft bis zum ersten Rebirth. Nach dem ersten Rebirth soll ein Durchlauf durch Welt 1–7 etwa halb so lang sein. Gesteuert wird das nur über Freischalt-, Shop-, Ei- und Rebirth-Preise. Die Belagwerte sind unverändert.

## Wie gerechnet wird

`lune run balance [Läufe]` (Skript `.lune/balance.luau`, Modell `tools/BalanceSim.luau`) schickt einen Modellspieler mit den **echten Spielregeln** (`GameRules`) und der echten `GameConfig` durch Welt 1–7, macht den Rebirth und spielt danach bis zum nächsten bezahlbaren Rebirth weiter. Gemessen wird die Spielzeit von der Freischaltung einer Welt bis zur Freischaltung der nächsten. In Welt 7 zählt die Zeit bis der (nächste) Rebirth bezahlbar ist. Weil Ei-Ziehungen Glück sind, wird mit 51 verschiedenen Zufallsfolgen gerechnet. Angegeben ist jeweils der Median.

Die Konfigurations-Tests (`tests/GameConfig.spec.luau`, Block „GameConfig balancing“) rechnen dasselbe Modell mit 9 Läufen und prüfen die Zielbänder mit etwas Spielraum.

## Ergebnis (Median aus 51 Läufen, Minuten Spielzeit)

| Welt | ohne Rebirth | nach 1. Rebirth |
| ---- | -----------: | --------------: |
| 1 Pizzeria-Garten | 12.8 | 0.1 |
| 2 Bauernhof | 12.3 | 0.2 |
| 3 Strand | 23.5 | 0.2 |
| 4 Eisberge | 20.5 | 0.4 |
| 5 Vulkan | 22.8 | 2.6 |
| 6 Süßigkeitenland | 34.7 | 8.8 |
| 7 Weltraum (bis Rebirth) | 35.8 | 36.8 |
| **Gesamt** | **160.8** | **51.1** |

Pet-Multiplikator beim ersten Rebirth im Median: ×331.

**Nach dem Rebirth** ist ein Durchlauf etwa **ein Drittel** so lang (51 statt 161 Minuten), nicht genau die Hälfte. Pets bleiben beim Rebirth erhalten. Mit Weltraum-Pets (×300 und mehr) dauern Welt 1–5 zusammen nur noch etwa 3 Minuten, egal welche Preise dort stehen. Die Länge des zweiten Durchlaufs hängt deshalb fast nur an Welt 6–7 und am Preisfaktor des zweiten Rebirths:

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
| Freischaltung Bauernhof | 1.500 | 170 |
| Freischaltung Strand | 15.000 | 2.000 |
| Freischaltung Eisberge | 150.000 | 42.000 |
| Freischaltung Vulkan | 1.500.000 | 310.000 |
| Freischaltung Süßigkeitenland | 15 Mio | 23 Mio |
| Freischaltung Weltraum | 150 Mio | 460 Mio |
| Erster Rebirth | 250 Mio | 4,9 Mrd |
| Preisfaktor pro Rebirth | ×2 | ×3 |
| Shop 1 Pizza-Platz Stufe 2 / 3 | 120 / 500 | 50 / 200 |
| Shop 1 Reichweite Stufe 1–3 | 40 / 200 / 800 | 30 / 100 / 400 |
| Shop 1 Magnet Stufe 1 | 600 | 300 |
| Shop 3 Pizza-Platz Stufe 7 / 8 | 400 Mio / 1,2 Mrd | 600 Mio / 1,8 Mrd |
| Shop 3 Reichweite Stufe 7 / 8 | 250 / 700 Mio | 400 Mio / 1,2 Mrd |
| Shop 3 Magnet Stufe 4 / 5 | 300 / 900 Mio | 500 Mio / 1,5 Mrd |

Unverändert: erstes Pizza-Platz-Upgrade 12 (#23), alle Ei-Preise (Garten-Ei 25, sonst ×8 pro Welt, zweites Ei ×5), Shop 2, Gem-Preise, Tränke, Belagwerte, Pet-Boni, Geschenke und Kalender.

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
- **Rebirth:** sofort, wenn bezahlbar. Der zweite Durchlauf endet, sobald der zweite Rebirth bezahlbar ist.

## Wie empfindlich das Ergebnis ist

Gleiche Preise, ein Parameter des Modellspielers geändert (Median aus 51 Läufen):

| Variante | Welt 1–7 je Welt (Min) | Gesamt ohne Rebirth | Gesamt nach 1. Rebirth |
| -------- | ---------------- | ------------------: | ---------------------: |
| Basis (2 Runden/Min) | 13 / 12 / 24 / 21 / 23 / 35 / 36 | 160.8 | 51.1 |
| 1,5 Runden/Min | 17 / 18 / 32 / 22 / 33 / 50 / 49 | 215.3 | 60.8 |
| 3 Runden/Min | 12 / 12 / 10 / 14 / 17 / 22 / 28 | 120.2 | 29.2 |
| 30 Min pro Tag | 13 / 12 / 19 / 15 / 21 / 29 / 29 | 142.2 | 38.8 |
| Ei-Amortisation 5 Min | 13 / 20 / 42 / 19 / 31 / 46 / 40 | 211.5 | 58.6 |
| Ei-Amortisation 20 Min | 14 / 12 / 18 / 18 / 21 / 32 / 32 | 145.3 | 42.0 |

Am stärksten wirken das Rundentempo und wie viel der Spieler in Eier steckt. Bei kleiner Pizza (Welt 1) sind 2 Runden pro Minute eher vorsichtig gerechnet, echte Spieler sind dort vermutlich schneller. Spieler mit kurzen Tagen kommen pro Spielminute schneller voran, weil die ersten Geschenke des Tages früh kommen. Die Zeiten sollten deshalb in Studio mit der Stoppuhr nachgemessen werden (Checkliste #41 in `docs/pc-todo.md`).

## Neu rechnen

Nach Preisänderungen `lune run balance` ausführen, die Tabelle hier ersetzen und `lune run test` laufen lassen. Die Konfigurations-Tests schlagen an, wenn eine Welt deutlich aus ihrem Zielband fällt.
