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

## #3 Spielerstand speichern

Vorher: `lune run test` → alle grün (inkl. `tests/SaveData.spec.luau`).

Einmalig einrichten (ohne das funktioniert in Studio kein DataStore):

- [ ] Place veröffentlichen: **File → Publish to Roblox** (falls noch nicht geschehen).
- [ ] **Home → Game Settings → Security → „Enable Studio Access to API Services“** einschalten, **Save**.

Test (1 Spieler, Rojo verbunden):

- [ ] **Play**: Output ohne `[Save]`-Warnungen. (Eine Warnung `Laden für … fehlgeschlagen` / `StudioAccessToApisNotAllowed` heißt: API-Zugriff ist noch aus – oben einschalten.)
- [ ] Ein paar Beläge sammeln und verkaufen, Münzstand merken (z. B. 12), eine Pizza mit 1 Belag halten. **Stop**.
- [ ] Erneut **Play**: Münzen zeigen denselben Stand, Pizza-Füllstand im HUD ist wie vorher (`Pizza 1/2`).
- [ ] Mit **Test → Clients and Servers** (1 Spieler) den Client-Fenster schließen (Spieler verlässt), danach neu starten → Münzen erhalten (Speichern beim Verlassen).
- [ ] Optional periodisch: Play, Münzen verdienen, > 2 Minuten warten, dann Studio-Prozess hart beenden (Task-Manager) → beim nächsten Play ist mindestens der Stand von vor 2 Minuten da.

Fehlerfall „Laden fehlgeschlagen überschreibt nichts“:

- [ ] Stand mit Münzen > 0 speichern (Play/Stop). Dann „Enable Studio Access to API Services“ **aus**schalten, Play: Warnung `[Save] Laden … fehlgeschlagen, es wird nicht gespeichert`, Münzen 0, ein paar Münzen verdienen, Stop.
- [ ] API-Zugriff wieder **ein**schalten, Play: der **alte** Münzstand ist wieder da (nicht 0, nicht der Stand aus dem Fehler-Lauf).

## #4 Auto-Sammeln und Pizza-HUD

Vorher: `lune run test` → alle grün (inkl. `tests/AutoCollect.spec.luau`).

Studio: Rojo verbinden, dann **Play** (1 Spieler):

- [ ] Output ohne rote Fehler.
- [ ] HUD unten: grauer Knopf „Auto-Sammeln: AUS“ direkt über `Pizza 0/2`.
- [ ] Mit AUS über Beläge laufen → nichts wird eingesammelt (Anklicken geht weiterhin).
- [ ] Knopf drücken → wird grün, „Auto-Sammeln: AN“, hüpft kurz. Im Explorer: `Players.<Name>` hat Attribut `AutoCollect = true`.
- [ ] Mit AN über einen Belag laufen (ca. 4 Studs Radius) → Belag verschwindet, erscheint auf der Pizza in der Hand, HUD `Pizza 1/2`. Beläge daneben (> 4 Studs) bleiben liegen.
- [ ] Zweiten Belag aufsammeln → Pizza `2/2` (rot), Meldung „Pizza voll! Ab zum Ofen.“ erscheint **einmal** sofort.
- [ ] Mit voller Pizza weiter über Beläge laufen → Beläge bleiben liegen, Meldung höchstens alle ~3 s (kein Dauer-Spam).
- [ ] Knopf erneut drücken → AUS (grau), Auto-Sammeln stoppt.
- [ ] Mit Belägen in die Ofen-Zone laufen → **Animation**: eine Pizza fliegt vom Spieler in die glühende Ofenöffnung und schrumpft, danach fliegen mehrere goldene Münzen vom Ofen hoch zur Münzanzeige; Münzanzeige hüpft, „+X Münzen“. Beläge auf der Pizza in der Hand sind danach weg.
- [ ] Ofen außerhalb des Bildschirms (Kamera wegdrehen) → Münzen starten aus der Bildschirmmitte, keine Fehler.
- [ ] Nach Reset (Esc → Reset Character) bleibt der Schalter-Zustand erhalten.
- [ ] Gespeichert: Schalter AN, Play beenden, neu starten → wieder AN. **Erst testbar, wenn #3 (Spielerstand speichern) umgesetzt ist** – der Schalter ist Teil des Spielerstands (`autoCollect`).

**Mehrspieler** (Test → Clients and Servers → 2 Spieler):

- [ ] A hat Auto-Sammeln AN, B AUS: A sammelt beim Drüberlaufen, B nicht; B sieht die Beläge bei A verschwinden.
- [ ] Beide laufen gleichzeitig über denselben Belag → nur einer bekommt ihn.
- [ ] Verkaufs-Animation sieht nur der Spieler, der verkauft.

**Handy** (Device-Emulator, z. B. iPhone SE und ein Tablet):

- [ ] Auto-Sammeln-Knopf mit dem Finger gut antippbar, nicht vom Joystick oder Sprung-Knopf verdeckt, Text lesbar.
- [ ] Münz-Animation endet sichtbar an der Münzanzeige (auch bei kleiner Bildschirmgröße/HUD-Skalierung). Falls daneben: Zielpunkt in `src/client/SellAnimation.luau` (`flyCoins`) anpassen.


## #5 Shop 1: Münz-Tresen mit Pizza-Platz, Reichweite, Magnet

Vorher: `lune run test` → alle grün (inkl. `tests/Shop.spec.luau` und `GameConfig shops`).

Tipp für schnelles Testen: In `src/shared/GameConfig.luau` vorübergehend `Mozzarella.value = 500` setzen (Rojo synchronisiert live), damit genug Münzen da sind. **Danach zurücksetzen, nicht committen.**

Studio: Rojo verbinden, dann **Play** (1 Spieler):

- [ ] Output ohne rote Fehler.
- [ ] Links hinten vom Spawn (bei x = -60, z = 72, außerhalb der Sammelfläche) steht ein Holz-Stand mit rot-weißer Markise, Schild „Münz-Tresen – Upgrades“ und grüner Zone davor. Im HUD gibt es **keinen** Shop-Knopf.
- [ ] In die grüne Zone laufen → Shop-Menü öffnet sich (kurzes Aufploppen) mit 3 Karten: Pizza-Platz, Reichweite, Magnet. Jede zeigt Name, Beschreibung, „Stufe 0 von N“, Wirkung `jetzt → nächste` (z. B. `2 Beläge → 3 Beläge`, `10 Studs → 14 Studs`, `aus → 12 Studs`) und einen Kaufknopf mit Preis (25 / 40 / 600 Münzen).
- [ ] Aus der Zone laufen → Menü schließt. Wieder rein → öffnet erneut. Mit „X“ schließen, in der Zone stehen bleiben → bleibt zu, bis man raus- und wieder reinläuft.
- [ ] Mit 0 Münzen „25 Münzen“ drücken → Knopf ist grau, rote Meldung „Nicht genug Münzen!“, Münzen und Stufe unverändert.
- [ ] Genug Münzen: Pizza-Platz kaufen → grüne Meldung „Gekauft: Pizza-Platz!“, Münzen sinken um den Preis, Karte zeigt „Stufe 1 von 3“, `3 Beläge → 4 Beläge`, HUD unten `Pizza 0/3`.
- [ ] Pizza-Platz bis Stufe 3 kaufen (2 → 3 → 4 → 6) → HUD `Pizza x/6`, Karte zeigt grauen Knopf „Im größeren Shop erhältlich“ (nächste Stufe 8 Beläge, nicht kaufbar).
- [ ] Reichweite kaufen → Beläge lassen sich aus ca. 14 Studs Entfernung anklicken (vorher „Zu weit weg!“). Bis Stufe 3 (22 Studs), danach „Im größeren Shop erhältlich“.
- [ ] Magnet Stufe 1 kaufen, Auto-Sammeln AN → Beläge im Umkreis von ca. 12 Studs (statt 4) fliegen sichtbar zur Spielfigur und landen auf der Pizza. Danach „Im größeren Shop erhältlich“.
- [ ] Ohne Magnet, Auto-Sammeln AN: auch normale Auto-Sammel-Beläge fliegen kurz zur Figur (kein hässlicher Rest-Belag in der Welt, unter `World1_PizzeriaGarden` bleibt kein `PulledTopping` übrig).
- [ ] Mit zu wenig Münzen ist der Preisknopf grau; nach einem Verkauf am Ofen zurück in den Shop → Knopf ist grün, sobald genug Geld da ist.
- [ ] Gespeichert (#3): Upgrades kaufen, Play beenden, neu starten → Stufen, Pizza-Platz und Münzen sind erhalten.

**Mehrspieler** (2 Spieler): A kauft ein Upgrade → nur A's Stufen/Münzen ändern sich, B's Menü bleibt unverändert.

**Handy** (Device-Emulator, iPhone SE quer + Tablet):

- [ ] Menü passt komplett auf den Bildschirm, Text lesbar, Kaufknöpfe und „X“ mit dem Finger gut antippbar (Antippen kauft, kein Maus-Hover nötig).
- [ ] Bei vielen Karten/kleinem Bildschirm lässt sich die Liste mit dem Finger scrollen.
- [ ] Joystick bleibt bedienbar, man kann aus der Zone laufen, um das Menü zu schließen.
