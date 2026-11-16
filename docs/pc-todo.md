# PC-Todo

Aufgaben, die nur auf einem Rechner mit Roblox Studio erledigt werden können. Die lokale Claude-Sitzung arbeitet diese Liste bei „sync“ ab und streicht erledigte Punkte.

- [ ] Rojo-Verbindung testen: Play drücken, im Output müssen `[RobloxGame] Server gestartet` und `[RobloxGame] Client gestartet` stehen.
- [ ] Baseplate per File → Publish to Roblox veröffentlichen (falls noch nicht geschehen).

## #2 Kern-Schleife: Belag einsammeln und am Ofen verkaufen

Vorher: `rokit install` (installiert jetzt auch Lune) und `lune run test` → muss `18 passed, 0 failed` melden.

Studio: Rojo verbinden, dann **Play** (1 Spieler):

- [ ] Output ohne rote Fehler; `[RobloxGame] Server gestartet` / `Client gestartet` erscheinen.
- [ ] Im Workspace gibt es `World1_PizzeriaGarden` mit Wiese, hellerer Sammelfläche, Spawn (gelb), Ofen mit Schild „Ofen – hier verkaufen“ und oranger Verkaufszone davor.
- [ ] Unter `World1_PizzeriaGarden.Toppings` liegen genau **60** Beläge (rot = Salami, beige = Pilz, weiß = Mozzarella; Salami am häufigsten, Mozzarella selten).
- [ ] Falls die Baseplate-Vorlage einen eigenen `SpawnLocation` mitten im Feld hat: diesen löschen und Place speichern/publishen, damit man am gelben Spawn startet.
- [ ] Spielfigur hält eine Pizza in der Hand, **flach** liegend. Falls sie hochkant/verdreht/im Arm steckt: `GRIP` in `src/server/PizzaVisual.luau` anpassen.
- [ ] Hotbar (Backpack) ist ausgeblendet, die Pizza lässt sich nicht weglegen.
- [ ] HUD: oben Münzen-Anzeige `0`, unten `Pizza 0/2` mit Balken.
- [ ] Belag in der Nähe (< 10 Studs) anklicken → verschwindet, erscheint klein auf der Pizza, HUD `Pizza 1/2`.
- [ ] Belag weit weg anklicken (ca. 15–40 Studs) → bleibt liegen, Meldung „Zu weit weg!“.
- [ ] Bei `Pizza 2/2` (Balken rot, „VOLL“) dritten Belag anklicken → bleibt liegen, Meldung „Pizza voll! Ab zum Ofen.“.
- [ ] Eingesammelter Belag erscheint nach ca. 5 s an einer anderen Stelle neu (Anzahl bleibt 60).
- [ ] In die orange Ofen-Zone laufen → Pizza leer, Münzen steigen um die Belagwerte (Salami 1, Pilz 2, Mozzarella 5), Meldung „+X Münzen“, Münzanzeige hüpft kurz.
- [ ] Nach Tod/Reset (Esc → Reset Character) hat die Figur wieder die Pizza mit den gleichen Belägen.

**Mehrspieler** (Test → Clients and Servers → 2 Spieler):

- [ ] Beide sehen dieselben Beläge; sammelt Spieler A einen ein, verschwindet er auch bei B.
- [ ] Klicken beide gleichzeitig denselben Belag an, bekommt ihn nur einer (der andere sieht keine Gutschrift auf seiner Pizza).

**Handy** (Test → Device-Emulator, z. B. iPhone, oder echtes Handy):

- [ ] Antippen eines Belags in Reichweite sammelt ihn ein (Tippen darf etwas daneben liegen).
- [ ] HUD-Elemente sind gut lesbar, nicht abgeschnitten, nicht vom Joystick/Sprung-Knopf verdeckt.

Fehler gefunden? Beheben, `lune run test` erneut ausführen, hier abhaken, committen, pushen.
