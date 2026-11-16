# PC-Todo

Aufgaben, die nur auf einem Rechner mit Roblox Studio erledigt werden können. Die lokale Claude-Sitzung arbeitet diese Liste bei „sync“ ab und streicht erledigte Punkte.

- [x] Rojo-Verbindung testen: Play drücken, im Output müssen `[RobloxGame] Server gestartet` und `[RobloxGame] Client gestartet` stehen.
- [x] Baseplate per File → Publish to Roblox veröffentlichen (falls noch nicht geschehen). _(16.11.2026: neue Experience „Pizza Topping Simulator“, privat)_

## #2 Kern-Schleife: Belag einsammeln und am Ofen verkaufen

Vorher: `rokit install` (installiert jetzt auch Lune) und `lune run test` → muss `18 passed, 0 failed` melden.

Studio: Rojo verbinden, dann **Play** (1 Spieler):

- [x] Output ohne rote Fehler; `[RobloxGame] Server gestartet` / `Client gestartet` erscheinen. _(nur erwartete `[Save]`/DataStore-Warnungen, solange API-Zugriff aus ist – siehe #3)_
- [x] Im Workspace gibt es `World1_PizzeriaGarden` mit Wiese, hellerer Sammelfläche, Spawn (gelb), Ofen mit Schild „Ofen – hier verkaufen“ und oranger Verkaufszone davor.
- [x] Unter `World1_PizzeriaGarden.Toppings` liegen genau **60** Beläge (rot = Salami, beige = Pilz, weiß = Mozzarella; Salami am häufigsten, Mozzarella selten). _(2 Läufe: 25/31/4 und 37/20/3 Salami/Pilz/Mozzarella – erster Lauf Zufall)_
- [x] Falls die Baseplate-Vorlage einen eigenen `SpawnLocation` mitten im Feld hat: diesen löschen und Place speichern/publishen, damit man am gelben Spawn startet.
- [x] Spielfigur hält eine Pizza in der Hand, **flach** liegend. Falls sie hochkant/verdreht/im Arm steckt: `GRIP` in `src/server/PizzaVisual.luau` anpassen.
- [x] Hotbar (Backpack) ist ausgeblendet, die Pizza lässt sich nicht weglegen.
- [x] HUD: oben Münzen-Anzeige `0`, unten `Pizza 0/2` mit Balken.
- [x] Belag in der Nähe (< 10 Studs) anklicken → verschwindet, erscheint klein auf der Pizza, HUD `Pizza 1/2`.
- [x] Belag weit weg anklicken (ca. 15–40 Studs) → bleibt liegen, Meldung „Zu weit weg!“.
- [x] Bei `Pizza 2/2` (Balken rot, „VOLL“) dritten Belag anklicken → bleibt liegen, Meldung „Pizza voll! Ab zum Ofen.“. _(Meldung kommt max. alle 3 s)_
- [x] Eingesammelter Belag erscheint nach ca. 5 s an einer anderen Stelle neu (Anzahl bleibt 60). _(Anzahl bleibt 60)_
- [x] In die orange Ofen-Zone laufen → Pizza leer, Münzen steigen um die Belagwerte (Salami 1, Pilz 2, Mozzarella 5), Meldung „+X Münzen“, Münzanzeige hüpft kurz. _(Salami/Pilz geprüft. Auffällig: Kamera wird in der Zone vom Ofen nach vorn an den Kopf gedrückt)_
- [x] Nach Tod/Reset (Esc → Reset Character) hat die Figur wieder die Pizza mit den gleichen Belägen.

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

- [x] Place veröffentlichen: **File → Publish to Roblox** (falls noch nicht geschehen).
- [x] **Home → Game Settings → Security → „Enable Studio Access to API Services“** einschalten, **Save**.

Test (1 Spieler, Rojo verbunden):

- [x] **Play**: Output ohne `[Save]`-Warnungen. (Eine Warnung `Laden für … fehlgeschlagen` / `StudioAccessToApisNotAllowed` heißt: API-Zugriff ist noch aus – oben einschalten.)
- [x] Ein paar Beläge sammeln und verkaufen, Münzstand merken (z. B. 12), eine Pizza mit 1 Belag halten. **Stop**. _(3 Münzen, Pizza 2/2)_
- [x] Erneut **Play**: Münzen zeigen denselben Stand, Pizza-Füllstand im HUD ist wie vorher (`Pizza 1/2`). _(Münzen, Pizza und Tutorial-Schritt erhalten)_
- [ ] Mit **Test → Clients and Servers** (1 Spieler) den Client-Fenster schließen (Spieler verlässt), danach neu starten → Münzen erhalten (Speichern beim Verlassen).
- [ ] Optional periodisch: Play, Münzen verdienen, > 2 Minuten warten, dann Studio-Prozess hart beenden (Task-Manager) → beim nächsten Play ist mindestens der Stand von vor 2 Minuten da.

Fehlerfall „Laden fehlgeschlagen überschreibt nichts“:

- [ ] Stand mit Münzen > 0 speichern (Play/Stop). Dann „Enable Studio Access to API Services“ **aus**schalten, Play: Warnung `[Save] Laden … fehlgeschlagen, es wird nicht gespeichert`, Münzen 0, ein paar Münzen verdienen, Stop.
- [ ] API-Zugriff wieder **ein**schalten, Play: der **alte** Münzstand ist wieder da (nicht 0, nicht der Stand aus dem Fehler-Lauf).

## #4 Auto-Sammeln und Pizza-HUD

Vorher: `lune run test` → alle grün (inkl. `tests/AutoCollect.spec.luau`).

Studio: Rojo verbinden, dann **Play** (1 Spieler):

- [ ] Output ohne rote Fehler.
- [x] HUD unten: grauer Knopf „Auto-Sammeln: AUS“ direkt über `Pizza 0/2`.
- [x] Mit AUS über Beläge laufen → nichts wird eingesammelt (Anklicken geht weiterhin).
- [ ] Knopf drücken → wird grün, „Auto-Sammeln: AN“, hüpft kurz. Im Explorer: `Players.<Name>` hat Attribut `AutoCollect = true`.
- [x] Mit AN über einen Belag laufen (ca. 4 Studs Radius) → Belag verschwindet, erscheint auf der Pizza in der Hand, HUD `Pizza 1/2`. Beläge daneben (> 4 Studs) bleiben liegen.
- [x] Zweiten Belag aufsammeln → Pizza `2/2` (rot), Meldung „Pizza voll! Ab zum Ofen.“ erscheint **einmal** sofort.
- [ ] Mit voller Pizza weiter über Beläge laufen → Beläge bleiben liegen, Meldung höchstens alle ~3 s (kein Dauer-Spam).
- [ ] Knopf erneut drücken → AUS (grau), Auto-Sammeln stoppt.
- [x] Mit Belägen in die Ofen-Zone laufen → **Animation**: eine Pizza fliegt vom Spieler in die glühende Ofenöffnung und schrumpft, danach fliegen mehrere goldene Münzen vom Ofen hoch zur Münzanzeige; Münzanzeige hüpft, „+X Münzen“. Beläge auf der Pizza in der Hand sind danach weg.
- [ ] Ofen außerhalb des Bildschirms (Kamera wegdrehen) → Münzen starten aus der Bildschirmmitte, keine Fehler.
- [x] Nach Reset (Esc → Reset Character) bleibt der Schalter-Zustand erhalten.
- [x] Gespeichert: Schalter AN, Play beenden, neu starten → wieder AN. **Erst testbar, wenn #3 (Spielerstand speichern) umgesetzt ist** – der Schalter ist Teil des Spielerstands (`autoCollect`).

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

- [x] Output ohne rote Fehler.
- [x] Links hinten vom Spawn (bei x = -60, z = 72, außerhalb der Sammelfläche) steht ein Holz-Stand mit rot-weißer Markise, Schild „Pizza-Shop – Upgrades“ (seit #12; vorher „Münz-Tresen“) und grüner Zone davor. Im HUD gibt es **keinen** Shop-Knopf. _(16.11. noch mit altem Schild „Münz-Tresen“ getestet)_
- [x] In die grüne Zone laufen → Shop-Menü öffnet sich (kurzes Aufploppen) mit 3 Karten: Pizza-Platz, Reichweite, Magnet. Jede zeigt Name, Beschreibung, „Stufe 0 von N“, Wirkung `jetzt → nächste` (z. B. `2 Beläge → 3 Beläge`, `10 Studs → 14 Studs`, `aus → 12 Studs`) und einen Kaufknopf mit Preis (25 / 40 / 600 Münzen).
- [x] Aus der Zone laufen → Menü schließt. Wieder rein → öffnet erneut. Mit „X“ schließen, in der Zone stehen bleiben → bleibt zu, bis man raus- und wieder reinläuft.
- [x] Mit 0 Münzen „25 Münzen“ drücken → Knopf ist grau, rote Meldung „Nicht genug Münzen!“, Münzen und Stufe unverändert.
- [x] Genug Münzen: Pizza-Platz kaufen → grüne Meldung „Gekauft: Pizza-Platz!“, Münzen sinken um den Preis, Karte zeigt „Stufe 1 von 3“, `3 Beläge → 4 Beläge`, HUD unten `Pizza 0/3`.
- [x] Pizza-Platz bis Stufe 3 kaufen (2 → 3 → 4 → 6) → HUD `Pizza x/6`, Karte zeigt grauen Knopf „Im größeren Shop erhältlich“ (nächste Stufe 8 Beläge, nicht kaufbar).
- [ ] Reichweite kaufen → Beläge lassen sich aus ca. 14 Studs Entfernung anklicken (vorher „Zu weit weg!“). Bis Stufe 3 (22 Studs), danach „Im größeren Shop erhältlich“.
- [x] Magnet Stufe 1 kaufen, Auto-Sammeln AN → Beläge im Umkreis von ca. 12 Studs (statt 4) fliegen sichtbar zur Spielfigur und landen auf der Pizza. Danach „Im größeren Shop erhältlich“. _(6 Beläge sofort geholt; Flug selbst nicht beobachtet)_
- [ ] Ohne Magnet, Auto-Sammeln AN: auch normale Auto-Sammel-Beläge fliegen kurz zur Figur (kein hässlicher Rest-Belag in der Welt, unter `World1_PizzeriaGarden` bleibt kein `PulledTopping` übrig).
- [x] Mit zu wenig Münzen ist der Preisknopf grau; nach einem Verkauf am Ofen zurück in den Shop → Knopf ist grün, sobald genug Geld da ist.
- [ ] Gespeichert (#3): Upgrades kaufen, Play beenden, neu starten → Stufen, Pizza-Platz und Münzen sind erhalten.

**Mehrspieler** (2 Spieler): A kauft ein Upgrade → nur A's Stufen/Münzen ändern sich, B's Menü bleibt unverändert.

**Handy** (Device-Emulator, iPhone SE quer + Tablet):

- [ ] Menü passt komplett auf den Bildschirm, Text lesbar, Kaufknöpfe und „X“ mit dem Finger gut antippbar (Antippen kauft, kein Maus-Hover nötig).
- [ ] Bei vielen Karten/kleinem Bildschirm lässt sich die Liste mit dem Finger scrollen.
- [ ] Joystick bleibt bedienbar, man kann aus der Zone laufen, um das Menü zu schließen.

## #8 Welt 2 Bauernhof und Barriere freischalten

Vorbereitung: Zum schnellen Testen in `src/shared/GameConfig.luau` vorübergehend `unlockPrice = 15` für `Farm` setzen (**nicht committen**, danach zurück auf 1500) oder ein paar Runden sammeln/verkaufen. Bei Testpreis 15 steht im Folgenden „15“ statt „1.500“.

**Welt und Barriere** (Play, 1 Spieler):

- [x] Hinter dem Pizzeria-Garten (Richtung −Z, hinter der Belag-Fläche) liegt eine zweite Fläche „Bauernhof“ (sandfarben) mit eigener Belag-Fläche, Ofen, Ei-Sockel mit „Bauernhof-Ei“ und 60 Belägen in neuen Farben (Zwiebel lila, Paprika grün, Mais gelb, Schinken rosa).
- [x] Zwischen den Welten steht eine rote Kraftfeld-Wand über die ganze Breite; davor schwebt „🔒 Bauernhof / 1.500 Münzen“.
- [x] Gegen die Wand laufen → man kommt nicht durch, auch nicht durch Springen oder an den Rändern.
- [x] Nahe der Wand (< ca. 22 Studs) erscheint unten ein großer Knopf „🔓 Bauernhof freischalten / 1.500 Münzen“: grau bei zu wenig Münzen, grün bei genug. Weggehen → Knopf verschwindet. _(grün geprüft; grau bei zu wenig Münzen nicht geprüft)_
- [ ] Knopf mit zu wenig Münzen → Meldung „Nicht genug Münzen!“, Münzen unverändert.
- [x] Knopf mit genug Münzen → Münzen −1.500, Meldung „Neue Welt freigeschaltet!“, Wand wird für mich unsichtbar, Preisschild weg, Knopf weg, man läuft durch.
- [x] Im Bauernhof Beläge sammeln (Klick und Auto-Sammeln) und am Bauernhof-Ofen verkaufen → Werte 4/8/12/20 Münzen. _(4 Beläge → +60, Klick-Sammeln dort nicht einzeln geprüft)_
- [x] Output ohne Fehler (rot) beim Start und beim Freischalten.

**Speichern** (braucht API-Zugriff wie bei #3):

- [ ] Nach dem Freischalten Stop → Play: Wand ist sofort offen, Münzen stimmen.

**Mehrspieler** (Test → Clients and Servers → 2 Spieler):

- [ ] A schaltet frei, B nicht: A läuft durch, B prallt weiterhin ab und sieht die Wand weiter.
- [ ] Server-Schutz: Bei B im Client-Fenster per Explorer `Workspace.World2_Farm.Barrier` → `CanCollide` aus und durchlaufen → B wird innerhalb ~0,5 s vor die Wand zurückgesetzt, Meldung „Diese Welt ist noch gesperrt!“.
- [ ] B kann Bauernhof-Beläge auch aus der Ferne nicht einsammeln (Server lehnt mit „WorldLocked“ ab, nichts landet auf der Pizza).

**Handy** (Device-Emulator, iPhone SE quer + Tablet):

- [ ] Freischalt-Knopf ist groß, gut lesbar, mit dem Daumen antippbar und verdeckt weder Joystick noch Sprung-Knopf noch die Pizza-Leiste.
- [ ] Antippen kauft (kein Maus-Hover nötig).

## #6 Eier und Pets: öffnen, ausrüsten, Bonus

Vorher: `lune run test` → alle grün (u. a. `tests/Pets.spec.luau`).

Vorbereitung: Zum schnellen Testen in `src/shared/GameConfig.luau` vorübergehend `price = 1` beim `GardenEgg` setzen (**nicht committen**, danach zurück auf 25) oder ein paar Runden sammeln/verkaufen.

Studio: Rojo verbinden, dann **Play** (1 Spieler):

- [x] Output ohne rote Fehler. Im Workspace gibt es `Eggs` (mit `GardenEgg` und `FarmEgg`) und `Pets`.
- [x] Links neben dem Spawn (x = −30, zwischen Spawn und Shop-Stand) steht auf einem Sockel ein cremefarbenes Ei mit orangen Punkten, nicht im Boden versunken und nicht schwebend.
- [x] Hinlaufen (< 20 Studs) → über dem Ei schwebt die Vorschau „Garten-Ei“ mit 6 Zeilen: Teig-Hamster (grau, 50 %, +10 %), Basilikum-Hase (grün, 28 %, +15 %), Tomaten-Katze (blau, 15 %, +25 %), Käse-Maus (lila, 5,5 %, +40 %), Oliven-Eule (orange, 1 %, +75 %), Pizza-Drache (pink, 0,5 %, +150 %) und darunter der grüne Knopf „1 öffnen – 25 Münzen“. Weggehen → Vorschau verschwindet.
- [ ] Vorschau ist lesbar, nicht abgeschnitten und verdeckt das Ei nicht komplett (ggf. `StudsOffsetWorldSpace`/`WIDTH` in `src/client/EggPreview.luau` anpassen). _(16.11.: lesbar, überdeckt aber von nah die Münzanzeige oben)_
- [ ] Mit weniger als 25 Münzen „1 öffnen“ antippen → Knopf wird kurz rot „Zu wenig Münzen!“, Münzen unverändert, kein Pet.
- [x] Mit genug Münzen „1 öffnen“ → Münzen sinken um 25; Animation: Ei wackelt immer stärker, knackt (⚡), weißer Blitz, Pet-Karte springt heraus (Name, Seltenheit in Farbe, „+X % Münzen“). Antippen oder 3 s warten schließt sie.
- [x] Schnell mehrfach tippen öffnet nicht mehrere Eier gleichzeitig (Sperre ca. 2,5 s).
- [x] Links mittig großer runder Knopf „Pets“ → Menü „Meine Pets“ mit Karten (Farbe = Seltenheit, Name, Bonus, Knopf „Ausrüsten“). Ohne Pets: „Noch keine Pets – öffne ein Ei!“.
- [x] Karte antippen → Pet ausgerüstet (Karte rückt nach vorn, „Ablegen“), Kopfzeile „Ausgerüstet 1/3 · Münz-Bonus +X %“. Neben dem Spieler erscheint eine farbige Kugel mit Augen und Namensschild.
- [x] 4 Pets öffnen, 3 ausrüsten → das 4. lässt sich nicht ausrüsten, Meldung „Alle Pet-Plätze belegt – erst ein Pet ablegen!“. Eins ablegen → Kugel verschwindet, das 4. lässt sich nun ausrüsten.
- [ ] Ausgerüstete Pets laufen in einer Reihe hinter dem Spieler her, hüpfen beim Laufen, schweben im Stand leicht, stehen auf dem Boden (nicht im Boden / nicht in der Luft), auch an Rampen/Kanten. Kein Ruckeln, Spieler kollidiert nicht mit ihnen. _(16.11.: Pets standen am Ofen auf dem Ofendach bzw. halb in der Ofenwand)_
- [x] Verkaufswert: z. B. mit Teig-Hamster (+10 %) und Tomaten-Katze (+25 %) ergibt eine Pizza aus Pilz + Mozzarella (7) → 7 × 1,35 = 9,45 → **9** Münzen. Ohne ausgerüstete Pets wieder 7. _(Pilz mit +60 % → 3 Münzen)_
- [x] Nach Reset (Esc → Reset Character) folgen die Pets der neuen Figur weiter.
- [ ] Rejoin (Speichern aktiv wie bei #3): Pets und Ausrüstung sind noch da.
- [ ] Bauernhof-Ei (Welt 2, auf dem Ei-Sockel aus #8): Ohne Freischaltung → „1 öffnen“ wird abgelehnt (Server meldet `WorldLocked`, keine Münzen weg). Nach Freischaltung öffnen klappt, die Bauernhof-Pets erscheinen.

**Mehrspieler** (Test → Clients and Servers → 2 Spieler):

- [ ] Spieler B sieht die Pets von Spieler A hinter A herlaufen (und umgekehrt), flüssig.
- [ ] Verlässt A das Spiel, verschwinden seine Pets bei B.

**Handy** (Device-Emulator, iPhone SE quer + Tablet):

- [ ] „Pets“-Knopf ist groß, mit dem Daumen gut antippbar, verdeckt nicht den Joystick.
- [ ] „1 öffnen“ in der Ei-Vorschau lässt sich antippen (BillboardGui in PlayerGui, `Active`). Falls Antippen nicht ankommt: melden – dann kommt der Knopf als ScreenGui unten ins HUD.
- [ ] Pet-Menü passt auf den Bildschirm (Schließen-„X“ erreichbar), Karten gut antippbar, Liste scrollt per Wischen.
- [ ] Pet-Karte nach dem Öffnen ist komplett sichtbar; Antippen schließt sie.

## #9 Teleport-Portale zwischen freigeschalteten Welten

Vorher: `lune run test` → alle grün (u. a. `tests/Portals.spec.luau`).

Vorbereitung: Für den Bauernhof 1.500 Münzen nötig – z. B. vorübergehend `unlockPrice` von `Farm` in `src/shared/GameConfig.luau` auf `1` setzen (**nicht committen**).

Studio: Rojo verbinden, dann **Play** (1 Spieler):

- [x] Output ohne rote Fehler. Im Workspace gibt es den Ordner `Portals` mit je einem `Portal_<WeltId>` pro Welt aus der Config (aktuell `Portal_PizzeriaGarden`, `Portal_Farm`, ggf. weitere aus #10).
- [x] Welt 1: Rechts vom Ofen (ca. x = 65, z = 70) steht ein lila leuchtender Ring mit hellblauer Fläche, Funkeln und Schild „🌀 Teleport“. Steht auf dem Boden, nicht im Ofen / in der Belag-Fläche.
- [x] In den Ring laufen → Menü „🌀 Teleport“ in der Bildschirmmitte: „📍 Pizzeria-Garten (du bist hier)“ (orange, nicht anwählbar), darunter „🔒 Bauernhof – 1.500 Münzen“ grau (und weitere gesperrte Welten grau mit Preis).
- [x] Grauen Eintrag antippen → nichts passiert (kein Teleport).
- [ ] Aus dem Ring laufen → Menü schließt. „X“ schließt es ebenfalls.
- [x] Bauernhof an der Barriere freischalten, zurück in den Portal-Ring → „2. Bauernhof“ ist jetzt lila und anwählbar. (Steht man beim Freischalten im Ring, aktualisiert sich das Menü sofort.)
- [x] „Bauernhof“ antippen → Figur steht sofort vor dem Bauernhof-Portal (Blick Richtung Welt), Menü zu, es öffnet sich nicht gleich wieder. _(mit „Eisberge“ getestet)_
- [ ] Im Bauernhof-Portal steht „📍 Bauernhof (du bist hier)“; „Pizzeria-Garten“ antippen → zurück in Welt 1 vor dem Portal.
- [x] Ankunftspunkt ist frei (nicht in Ofen, Ei oder Barriere), man fällt nicht durch den Boden.
- [x] Im HUD gibt es **keinen** Teleport-Knopf.

**Server-Schutz** (Command Bar im Client-Fenster bzw. Executor nicht nötig):

- [ ] Im Client-Fenster (nicht im Portal) in der Command Bar: `game.ReplicatedStorage.Remotes.Teleport:FireServer("Farm")` → nichts passiert (nur aus einem Portal heraus).
- [x] Im Portal stehend, Bauernhof gesperrt: `game.ReplicatedStorage.Remotes.Teleport:FireServer("Farm")` → kein Teleport, Meldung „Diese Welt ist noch gesperrt!“. _(kein Teleport; Meldung nicht gesehen, Menü überdeckt evtl. die Meldungszeile)_

**Mehrspieler** (Test → Clients and Servers → 2 Spieler):

- [ ] A hat den Bauernhof, B nicht: Bei A ist „Bauernhof“ anwählbar, bei B grau. Teleport von A beeinflusst B nicht (B's Menü bleibt unverändert).

**Handy** (Device-Emulator, iPhone SE quer + Tablet):

- [ ] Menü passt auf den Bildschirm, „X“ erreichbar, Einträge groß und mit dem Daumen antippbar, Liste scrollt per Wischen.
- [ ] Antippen teleportiert (kein Maus-Hover nötig).

## #7 Pet-Verwaltung: Beste ausrüsten, Löschen, Inventargrenze

Vorher: `lune run test` → alle grün (neue Fälle in `tests/Pets.spec.luau`: `equipBest`, `deletePet`, `inventory limit`).

Vorbereitung: Zum schnellen Testen in `src/shared/GameConfig.luau` vorübergehend `price = 1` beim `GardenEgg` und `inventory.start = 5` setzen (**nicht committen**, danach zurück auf 25 bzw. 50).

Studio: Rojo verbinden, dann **Play** (1 Spieler):

- [x] Output ohne rote Fehler.
- [x] Pet-Menü öffnen: Kopfzeile zeigt „Ausgerüstet X/3 · Inventar Y/5 · Bonus +Z %“ (mit echtem Wert: Y/50). Darunter zwei große Knöpfe „Beste ausrüsten“ (grün) und „Löschen“ (rot), die Pet-Liste darunter ist nicht verdeckt.
- [ ] Ohne Pets „Beste ausrüsten“ antippen → Kopfzeile kurz rot „Noch keine Pets – öffne ein Ei!“.
- [x] Mehrere Pets öffnen (verschiedene Seltenheiten), nur schwache ausrüsten → „Beste ausrüsten“ → die 3 Pets mit dem höchsten Bonus sind ausgerüstet (Karten vorn, „Ablegen“), Münz-Bonus in der Kopfzeile passt (Summe der 3 Boni). Die Pet-Kugeln neben dem Spieler wechseln entsprechend.
- [ ] „Beste ausrüsten“ erneut antippen, wenn schon die besten ausgerüstet sind → nichts ändert sich (keine Pets verschwinden/erscheinen).
- [x] „Löschen“ antippen → Knopf wird dunkel „Fertig“, Titel „Pet zum Löschen antippen“, „Beste ausrüsten“ ist ausgeblendet, alle Karten zeigen roten „Löschen“-Streifen.
- [x] Im Löschen-Modus eine Karte antippen → Dialog „<Name> (+X %) wirklich löschen?“ mit großen Knöpfen „Löschen“ / „Behalten“. „Behalten“ → nichts passiert.
- [x] „Löschen“ im Dialog → Pet verschwindet aus der Liste, Inventar-Zahl sinkt um 1.
- [x] Ein **ausgerüstetes** Pet löschen → Dialog erwähnt „Es wird dabei abgelegt.“; nach dem Löschen verschwindet seine Kugel neben dem Spieler, „Ausgerüstet“ und Bonus sinken.
- [x] „Fertig“ bzw. Menü schließen (X oder „Pets“-Knopf) beendet den Löschen-Modus; beim nächsten Öffnen normale Ansicht.
- [ ] Inventar füllen (5/5 mit Testwert) → Kopfzeile rot. Am Ei „1 öffnen“ → Knopf wird kurz rot „Inventar voll!“, oben erscheint Meldung „Pet-Inventar voll! Lösche erst ein Pet.“, **keine Münzen abgezogen**, keine Animation.
- [ ] Ein Pet löschen → Ei lässt sich wieder öffnen.
- [ ] Rejoin (Speichern aktiv): gelöschte Pets bleiben weg, Ausrüstung nach „Beste ausrüsten“ bleibt erhalten.

**Mehrspieler** (2 Spieler): Löscht A ein ausgerüstetes Pet, verschwindet dessen Kugel auch bei B.

**Handy** (Device-Emulator, iPhone SE quer + Tablet):

- [ ] Pet-Menü (jetzt 560 hoch) passt komplett auf den Bildschirm, „X“, „Beste ausrüsten“ und „Löschen“ sind mit dem Daumen gut antippbar.
- [ ] Bestätigungsdialog passt, beide Knöpfe gut antippbar; Antippen außerhalb des Dialogs löst keine Karte darunter aus.
- [ ] Wischen in der Liste im Löschen-Modus öffnet nicht versehentlich den Dialog.

## #10 Welten 3–4 (Strand, Eisberge) und Shop 2

Vorher: `lune run test` → alle grün (u. a. `GameConfig` „world 3/4“ und „shop 2“).

Tipp für schnelles Testen: In `src/shared/GameConfig.luau` vorübergehend `Mozzarella.value = 50000` setzen (Rojo synchronisiert live), damit 1.500 + 15.000 + 150.000 Münzen schnell zusammenkommen. **Danach zurücksetzen, nicht committen.**

Studio: Rojo verbinden, dann **Play** (1 Spieler):

- [x] Output ohne rote Fehler. Im Workspace gibt es `World3_Beach` und `World4_Icebergs` (hinter dem Bauernhof entlang −Z), in `Portals` zusätzlich `Portal_Beach` und `Portal_Icebergs`.
- [ ] Strand: Sand-Boden, türkise Barriere mit Schild „🔒 Strand – 15.000 Münzen“ am Ende des Bauernhofs. Eisberge: Schnee-Boden, blaue Barriere „🔒 Eisberge – 150.000 Münzen“ am Ende des Strands.
- [x] Mit zu wenig Münzen an der Strand-Barriere freischalten → „Nicht genug Münzen!“, Barriere bleibt. Eisberge vor dem Strand freischalten geht nicht („Erst die vorige Welt freischalten!“). _(geprüft: Server setzt aus gesperrtem Strand zurück, „Diese Welt ist noch gesperrt!“)_
- [x] Strand freischalten → Barriere lokal durchlässig, Münzen −15.000. Danach Eisberge (−150.000).
- [ ] Strand-Beläge: Thunfisch (rotbraun), Garnele (orange), Ananas (gelb), ca. 60 Stück; Eisberge: Gefrorene Erbsen (grün, glasig), Lachs (lachsfarben), Eisberg-Salat (hellgrün, glasig). Keine pinken Neon-Scheiben (= fehlende Optik).
- [ ] Einsammeln und am Ofen der jeweiligen Welt verkaufen funktioniert; Werte: Thunfisch 25, Garnele 45, Ananas 65, Erbsen 100, Lachs 180, Eisberg-Salat 260 (× Pet-Bonus).
- [ ] Ei-Sockel jeder Welt: Strand-Ei (1.500 Münzen) bzw. Eis-Ei (12.000 Münzen) mit Vorschau (6 Pets, 0,5 % Mythisch). Öffnen gibt ein Pet der Welt (z. B. Sand-Krabbe +40 %, Eis-Pinguin +80 %); es folgt nach dem Ausrüsten.
- [x] Portal-Menü listet „Strand“ und „Eisberge“; nach dem Freischalten anwählbar, Teleport landet vor dem Portal der Welt.
- [ ] **Shop 2** in den Eisbergen links vom Ei (ca. x = −72, z = −528): sichtbar größer als der Shop in Welt 1 (ca. 1,5×), Schild „Großer Pizza-Shop – Upgrades“, steht frei (nicht im Ei-Sockel, nicht in der Belag-Fläche).
- [x] In die grüne Zone laufen → Menü zeigt Pizza-Platz „Stufe x von 8“, kaufbar bis 12 (danach „Im größeren Shop erhältlich“), Reichweite bis Stufe 6 (dann „MAX“), Magnet bis Stufe 3 („MAX“). _(Karte zeigt „Stufe x von 6“ = Shop-Maximum, nicht „von 8“; Pizza bis 12 + „Im größeren Shop erhältlich“ geprüft)_
- [ ] Zurück in Welt 1 im kleinen Shop: Pizza-Platz über 6 bzw. Magnet über Stufe 1 weiterhin nicht kaufbar („Im größeren Shop erhältlich“ bzw. bereits höhere Stufe angezeigt, kein Kauf).

**Server-Schutz**:

- [ ] Ohne Eisberge freigeschaltet (Command Bar im Client-Fenster): `game.ReplicatedStorage.Remotes.BuyUpgrade:FireServer("World4Shop", "PizzaSpace")` → nichts passiert, Münzen unverändert.

**Mehrspieler** (2 Spieler):

- [ ] A hat Strand freigeschaltet, B nicht: B kommt nicht durch die Strand-Barriere (wird zurückgesetzt), A schon.

**Handy** (Device-Emulator, iPhone SE quer + Tablet):

- [ ] Freischalt-Knöpfe für Strand/Eisberge und das Menü von Shop 2 sind groß, lesbar und per Antippen bedienbar; die längeren Namen („Gefrorene Erbsen“, „Großer Pizza-Shop“) werden nicht abgeschnitten.

## #17 Tutorial für neue Spieler

Vorher: `lune run test` → alle grün (u. a. `tests/Tutorial.spec.luau` und `GameConfig` „tutorial“).

Wichtig: Wer schon **vor** diesem Ticket gespeichert hat, gilt als erfahrener Spieler und sieht das Tutorial **nicht** (Migration v2 → v3). Zum Testen als neuer Spieler den eigenen Spielstand löschen – **nicht im Play-Modus** (sonst schreibt der Leave-Save ihn zurück), sondern im Bearbeitungsmodus (API-Zugriff an, siehe #3) in die Command Bar:
`game:GetService("DataStoreService"):GetDataStore("PlayerState"):RemoveAsync("player_" .. game:GetService("StudioService"):GetUserId())`
Danach **Play** → frischer Spieler mit Tutorial. (Für die Schritte ohne Speichern geht auch: API-Zugriff aus → man startet immer frisch.)

Studio: Rojo verbinden, dann **Play** als neuer Spieler (1 Spieler):

- [x] Output ohne rote Fehler. Unter den Münzen erscheint eine Karte „Tutorial – Schritt 1/4“: „Sammle 2 Beläge ein (0/2) …“.
- [ ] Ein gelber, wippender Pfeil ▼ steht über dem **nächsten** Belag, eine gelbe Linie führt von den Füßen dorthin. Beim Laufen springt der Pfeil zum jeweils nächsten Belag (nie zu einem Gem-Belag).
- [x] 1 Belag einsammeln → „(1/2)“. Zweiten Belag einsammeln (per Antippen **oder** Auto-Sammeln) → Karte springt mit kleinem Pop auf „Schritt 2/4: … verkaufe deine Pizza!“, Pfeil steht über der Ofen-Zone.
- [x] In die Ofen-Zone laufen und verkaufen → „Schritt 3/4: Kauf im Shop dein erstes Upgrade!“, Pfeil über der grünen Shop-Zone in Welt 1.
- [ ] Mit zu wenig Münzen kaufen → „Nicht genug Münzen!“, Schritt bleibt 3/4. Weiter sammeln/verkaufen, dann Pizza-Platz kaufen (25 Münzen) → „Schritt 4/4: Öffne am Ei dein erstes Pet!“, Pfeil über dem Ei-Sockel in Welt 1.
- [x] Ei öffnen (25 Münzen) → Karte zeigt „Tutorial geschafft!“ und verschwindet nach ca. 4 s; Pfeil und Linie sind weg.
- [x] **Stop**, erneut **Play** → kein Tutorial mehr (gespeichert).
- [x] Mittendrin speichern: Neuer Spieler, bis Schritt 3 spielen, **Stop**, **Play** → Tutorial macht bei Schritt 3/4 weiter. _(am 16.11. Schritt 3/4 nach Stop/Play erhalten)_
- [ ] Reihenfolge: In Schritt 1 schon im Shop kaufen oder ein Ei öffnen (Münzen per Command Bar geben) → Tutorial bleibt bei Schritt 1.
- [ ] Nach dem Sterben/Respawn (z. B. Character resetten) zeigt die Linie weiterhin vom Spieler zum Ziel.

**Erfahrener Spieler**: Mit einem Spielstand von vor diesem Ticket (oder einem fertigen Tutorial) **Play** → keine Tutorial-Karte, kein Pfeil.

**Handy** (Device-Emulator, iPhone SE quer + Tablet):

- [ ] Die Tutorial-Karte ist komplett sichtbar, Text lesbar und nicht abgeschnitten; sie überdeckt weder Münzanzeige noch Meldungen („Pizza voll!“) noch den Auto-Sammeln-Knopf.
- [ ] Die Karte blockiert keine Eingaben: Beläge, die hinter der Karte liegen, lassen sich antippen; Kamera-Wischen über der Karte funktioniert.
- [ ] Pfeil und Linie sind auf dem kleinen Bildschirm gut zu erkennen.

## #12 Gems und Gem-Tresen

Vorher: `lune run test` → alle grün (u. a. `tests/Gems.spec.luau` und `GameConfig gems`).

Tipp für schnelles Testen: In `src/shared/GameConfig.luau` vorübergehend `gems.toppingChance = 0.2`, `gems.playtimeSeconds = 30` und `gems.playtimeGems = 500` setzen (Rojo synchronisiert live; Server neu starten). Dann liegen viele Gem-Beläge herum und alle 30 s gibt es 500 Gems. **Danach zurücksetzen, nicht committen.**

Studio: Rojo verbinden, dann **Play** (1 Spieler):

- [x] Output ohne rote Fehler. Oben in der Mitte stehen **zwei** Anzeigen nebeneinander: links Münzen (gelbe Münze), rechts Gems (türkiser Diamant, Start 0).
- [x] Gem-Beläge: zwischen den Belag-Scheiben liegen selten (normal ca. 1 von 150 Spawns, mit Tipp oben oft) **leuchtende türkise Diamanten** mit Glitzern, je nach Wert (1–3) etwas größer.
- [ ] Gem-Belag antippen (in Reichweite) → verschwindet, Toast „+n Gems!“ (türkis), Gem-Anzeige springt hoch; die Pizza bleibt unverändert. Funktioniert auch mit **voller** Pizza.
- [ ] Mit Auto-Sammeln drüberlaufen sammelt Gem-Beläge ebenfalls ein (auch mit voller Pizza); normale Beläge bleiben dann liegen.
- [x] Spielzeit: nach 15 Min. (mit Tipp: 30 s) Toast „+1 Gem fürs Spielen!“ und die Anzeige steigt. Nach Rejoin zählt die angefangene Zeit weiter (wird mitgespeichert). _(Toast „+500 Gem fürs Spielen!“ mit Testwert; Rejoin nicht geprüft)_
- [x] Shop in Welt 1 (Schild jetzt „Pizza-Shop – Upgrades“): Menü hat die Abschnitte **„Münz-Tresen“** (gelb) und darunter **„Gem-Tresen“** (türkis) mit Pet-Plätze, Inventar, Laufgeschwindigkeit, 3 Eier auf einmal. Gem-Preise stehen als „50 Gems“ usw. auf türkisen Knöpfen (grau, wenn zu wenig Gems).
- [ ] Mit zu wenig Gems kaufen → „Nicht genug Gems!“, nichts ändert sich. Münzen werden für Gem-Upgrades **nie** abgezogen.
- [ ] **Pet-Plätze**: 3 → 4 (50 Gems) → 5 (150 Gems), dann „Im größeren Shop erhältlich“. Im Pet-Menü lassen sich danach 4 bzw. 5 Pets ausrüsten, alle folgen.
- [ ] **Inventar**: 50 → 75 (30 Gems) → 100 (100 Gems); Pet-Menü zeigt die neue Grenze, Eier lassen sich wieder öffnen, wenn das Inventar vorher voll war.
- [ ] **Laufgeschwindigkeit**: 16 → 19 → 22; man läuft sichtbar schneller, auch nach Respawn (Reset) und nach Rejoin.
- [x] **3 Eier auf einmal** (150 Gems): an jeder Ei-Vorschau erscheint neben „1 öffnen – 25“ ein gelber Knopf „3 öffnen – 75“. Antippen → 3× Preis weg, Animation zeigt **3 Pet-Karten nebeneinander**, alle 3 Pets im Pet-Menü.
- [ ] „3 öffnen“ mit zu wenig Münzen → Knopf zeigt kurz „Zu wenig Münzen!“; mit nur 1–2 freien Inventarplätzen → „Inventar voll!“, nichts wird abgezogen.
- [ ] Shop 2 (Eisberge): Gem-Tresen verkauft Pet-Plätze bis 7 (400/1.000 Gems), Inventar und Tempo bis Stufe 4.

**Server-Schutz** (Command Bar im Client-Fenster):

- [x] Ohne „3 Eier auf einmal“ gekauft, neben einem Ei: `game.ReplicatedStorage.Remotes.OpenEgg:FireServer("GardenEgg", 3)` → nichts wird geöffnet, Münzen unverändert. Mit `…:FireServer("GardenEgg", 5)` ebenso. _(mit 5 geprüft)_
- [x] `game.ReplicatedStorage.Remotes.BuyUpgrade:FireServer("World1Shop", "PetSlots")` außerhalb der Shop-Zone → nichts passiert.

**Mehrspieler** (2 Spieler):

- [ ] Ein Gem-Belag kann nur von einem Spieler genommen werden; der andere sieht ihn verschwinden. Gems und Gem-Upgrades sind pro Spieler.

**Handy** (Device-Emulator, iPhone SE quer + Tablet):

- [ ] Münz- und Gem-Anzeige passen nebeneinander, ohne die Roblox-Knöpfe oben zu überdecken.
- [ ] „1 öffnen“ und „3 öffnen“ sind nebeneinander groß genug zum Antippen, der Text ist lesbar.
- [ ] Die 3 Pet-Karten passen auf den Bildschirm (ggf. verkleinert); Antippen schließt.
- [ ] Gem-Tresen im Shop-Menü scrollt per Wischen, Kaufknöpfe sind gut antippbar.

## #15 Look-Pass Welt 1 und Sounds

Vorher: `git pull`, `lune run test` → alle grün. Vorschau der Modelle: `assets/previews/*.png` (Übersicht: `assets/previews/Overview.png`).

Ohne die folgenden Import-Schritte läuft alles weiter mit den bisherigen Teilen (farbige Scheiben, Ofen-Kasten); Bäume, Büsche, Wege, Blumen, Licht und Wolken sind schon ohne Import da.

**1. Licht (einmalig, wird im Place gespeichert):**

- [ ] Explorer → **Lighting** auswählen → Properties → **Technology = Future**. (Kann kein Skript setzen.) Alles andere (ClockTime, Atmosphere, Bloom, Farbkorrektur, SunRays, Wolken) setzt das Spiel selbst beim Start (`src/client/WorldAmbience.luau`, Werte in `src/shared/WorldLooks.luau`). _(16.11.: Eigenschaft „Technology“ gibt es in dieser Studio-Version nicht mehr – per Skript gesperrt, im Eigenschaften-Fenster nicht auffindbar)_

**2. 3D-Modelle importieren** (Dateien in `assets/models/`, im Repo-Ordner):

- [x] Im Explorer unter **ReplicatedStorage** einen **Folder** `GameAssets` anlegen, darin einen **Folder** `Models` (Rechtsklick → Insert Object → Folder, umbenennen). Rojo lässt diese Ordner in Ruhe.
- [x] Für **jede** dieser 7 Dateien: **Home → Import 3D** (bzw. File → Import 3D) → Datei wählen → im Import-Fenster: *Rig Type* = **No Rig**, *Insert Using Scene Position* = aus, sonst Standard → **Import**.
  | Datei | Name im Explorer (exakt) | enthaltene Teile |
  | --- | --- | --- |
  | `Salami.fbx` | `Salami` | Meat, Fat |
  | `Mushroom.fbx` | `Mushroom` | Cap, Stem |
  | `Mozzarella.fbx` | `Mozzarella` | Cheese, Basil |
  | `Pizza.fbx` | `Pizza` | Dough, Crust, Sauce, Melt |
  | `PizzaOven.fbx` | `PizzaOven` | Stone, Dome, Arch, Mouth, Glow, Chimney |
  | `Tree.fbx` | `Tree` | Wood, Leaves, LeavesLight |
  | `Bush.fbx` | `Bush` | Leaves, Berry |
- [x] Das importierte Modell erscheint im Workspace. Es per Drag & Drop nach **ReplicatedStorage → GameAssets → Models** ziehen und exakt wie in der Tabelle benennen (es muss ein **Model** mit **MeshParts** sein; heißen die Teile z. B. `Meat.001`, ist das in Ordnung). Größe, Farbe und Position sind egal – das Spiel skaliert und färbt nach den Teilnamen.
- [x] Place speichern und **File → Publish to Roblox** (die hochgeladenen Meshes gehören zum Place).

**3. Sounds** (IDs in `src/client/Sounds.luau`, starten leer = stumm):

Aus der Cloud-Sitzung ließ sich keine Roblox-Asset-ID prüfen (roblox.com gesperrt), deshalb sind die IDs noch leer. In Studio: **View → Toolbox → Creator Store → Audio**, Creator-Filter **Roblox** (diese Sounds bleiben öffentlich), anhören, Rechtsklick → **Copy Asset ID**, als Zahl in `Sounds.luau` eintragen:

- [ ] `Collect` – kurzer „Plopp“ (Suche: *pop*, *plop*, *bubble pop*), < 0,5 s.
- [ ] `Sell` – Kasse/Münzen (Suche: *cash register*, *coins*, *purchase*).
- [ ] `Gem` – Glitzern/Chime (Suche: *sparkle*, *chime*, *magic*).
- [ ] `EggCrack` – Ei/Schale knackt (Suche: *egg crack*, *crack*, *shell*).
- [ ] `PhoneRing` – altes Telefonklingeln (Suche: *phone ring*, *telephone*); wird erst mit #13 (Lieferdienst) abgespielt.
- [ ] `Music_PizzeriaGarden` – fröhliche, leichte Hintergrundmusik zum Loopen (Suche: *happy*, *cheerful*, *ukulele*, *italian*), Lautstärke ist schon leise (0,25).
- [ ] Eingetragene IDs hier mit Namen notieren, committen (`Add sound IDs (#15)`), pushen.

**4. Test** (Rojo verbunden, **Play**, 1 Spieler):

- [x] Output ohne rote Fehler.
- [ ] Look: warmes Nachmittagslicht mit weichen Schatten, leichter Dunst am Horizont, Wolken am Himmel, kräftige Farben, Neon-Glut leuchtet leicht (Bloom). Nichts ist überstrahlt.
- [x] Welt 1: Bäume links/rechts und hinter dem Spawn, Büsche mit Blumen, sandiger Weg vor Ofen/Spawn/Ei/Shop/Portal, ein Weg-Stück zum Sammelfeld. Nichts davon steht im Sammelfeld, im Weg zum Ofen, Shop, Ei oder Portal.
- [x] Beläge sind die Modelle: Salami-Scheibe mit Fettaugen, kleiner Pilz, Mozzarella-Kugeln mit Basilikum. Anklicken/Antippen, Auto-Sammeln und Magnet-Flug funktionieren wie vorher (das Modell fliegt mit).
- [x] Pizza in der Hand ist das Pizza-Modell (Rand, Soße, Käse), gesammelte Beläge erscheinen klein darauf. Liegt sie schief/verdreht: `GRIP` in `src/server/PizzaVisual.luau` prüfen.
- [x] Ofen ist der runde Kuppelofen mit glühender Öffnung **zur Verkaufszone hin**. Zeigt die Öffnung woanders hin: in `src/shared/ModelLibrary.luau` bei `YAW.PizzaOven` 90/180/270 eintragen. Schild „Ofen – hier verkaufen“ steht über dem Schornstein. Verkaufsanimation: Pizza (Modell) fliegt in die Ofenöffnung. _(Öffnung zeigte nach hinten → `YAW.PizzaOven = 180` gesetzt, danach richtig)_
- [x] Shop-Stand: Pizza-Modell liegt auf der Theke.
- [ ] Sounds (sobald IDs eingetragen): Plopp beim Sammeln (nicht beim Beitreten), Kasse beim Verkaufen, Glitzern bei Gems, Knacken in der Ei-Animation, Musik läuft in Schleife.
- [x] Welt 2 und weitere: Ofen dort ist ebenfalls der Kuppelofen.

**Handy** (Device-Emulator):

- [ ] Bildrate bleibt flüssig (60 Modell-Beläge pro Welt, Bäume). Falls es ruckelt: im Emulator mit niedriger Grafikqualität prüfen und hier notieren.
- [ ] Beläge (jetzt Modelle) lassen sich weiterhin gut antippen.

## #11 Welten 5–7 (Vulkan, Süßigkeitenland, Weltraum) und Shop 3

Vorher: `lune run test` → alle grün (u. a. `GameConfig` „world 5/6/7“, „shop 3“ und „balancing“).

Tipp für schnelles Testen: In `src/shared/GameConfig.luau` vorübergehend `Mozzarella.value = 50000000` setzen (Rojo synchronisiert live), damit die Barrieren (1,5 Mio / 15 Mio / 150 Mio) und Shop 3 (bis 1,2 Mrd) schnell bezahlbar sind. **Danach zurücksetzen, nicht committen.**

Studio: Rojo verbinden, dann **Play** (1 Spieler):

- [ ] Output ohne rote Fehler. Im Workspace gibt es `World5_Volcano`, `World6_CandyLand` und `World7_Space` (hinter den Eisbergen entlang −Z, Welt 7 bei ca. z = −1.200), in `Portals` zusätzlich `Portal_Volcano`, `Portal_CandyLand` und `Portal_Space`.
- [ ] Vulkan: dunkler Basalt-Boden, orange Barriere „🔒 Vulkan – 1.500.000 Münzen“ am Ende der Eisberge. Süßigkeitenland: rosa Boden, lila Barriere „🔒 Süßigkeitenland – 15.000.000 Münzen“. Weltraum: grauer Schiefer-Boden, mintgrüne Barriere „🔒 Weltraum – 150.000.000 Münzen“. Schilder lesbar.
- [ ] Reihenfolge: Süßigkeitenland vor dem Vulkan freischalten geht nicht („Erst die vorige Welt freischalten!“); mit zu wenig Münzen → „Nicht genug Münzen!“.
- [ ] Nacheinander freischalten → Barriere jeweils lokal durchlässig, Münzen sinken um den Preis.
- [ ] Beläge (je ca. 60): Vulkan Chili (rot), Peperoni (rot-orange), Jalapeño (grün); Süßigkeitenland Schoko-Stücke (braun), Gummibärchen (pink, glasig), Marshmallow (weiß-rosa); Weltraum Mond-Käse (hellgelb), Sternen-Oliven (lila, leuchtend), Alien-Pilz (grün, leuchtend). Keine pinken Neon-Scheiben (= fehlende Optik).
- [ ] Einsammeln und am Ofen der Welt verkaufen; Werte ohne Pets: Chili 500, Peperoni 850, Jalapeño 1.250, Schoko 2.400, Gummibärchen 4.100, Marshmallow 6.000, Mond-Käse 11.500, Sternen-Oliven 20.000, Alien-Pilz 29.000.
- [ ] Ei-Sockel: Vulkan-Ei (100.000), Süßigkeiten-Ei (800.000), Weltraum-Ei (6.400.000) mit Vorschau (6 Pets, 0,5 % Mythisch: Lava-Titan, Karamell-Greif, Galaxie-Drache). Öffnen gibt ein Pet der Welt, es folgt nach dem Ausrüsten.
- [ ] HUD: Große Beträge erscheinen kurz („1,5 Mio“, „1,2 Mrd“) und passen in die Münzanzeige; Toasts „+… Münzen“ ebenso.
- [ ] Portal-Menü listet alle 7 Welten (scrollbar), gesperrte grau mit Preis; nach dem Freischalten anwählbar, Teleport landet vor dem Portal der Welt.
- [ ] **Shop 3** im Weltraum links vom Ei (ca. x = −72, z = −1.128): doppelt so groß wie der Shop in Welt 1, Schild „Riesiger Pizza-Shop – Upgrades“, steht frei (nicht im Ei-Sockel, nicht in der Belag-Fläche, nicht über dem Weltrand).
- [ ] Menü von Shop 3: Pizza-Platz bis 20 (Stufe 8 von 8, dann „MAX“), Reichweite bis Stufe 8 (45 Studs), Magnet bis Stufe 5 (40 Studs); Gem-Tresen: Pet-Plätze bis 8, Inventar bis 300, Tempo bis 32, 3 Eier auf einmal, alle drei Tränke.
- [ ] Im Shop 2 (Eisberge) sind Pizza 15/20, Reichweite 7/8 und Magnet 4/5 als „Im größeren Shop erhältlich“ markiert.
- [ ] Magnet Stufe 5 (40 Studs) und Pizza 20: Auto-Sammeln zieht spürbar viele Beläge an, Hand-Pizza zeigt 20 Beläge ohne Ruckeln.

**Server-Schutz**:

- [ ] Ohne Weltraum freigeschaltet (Command Bar im Client-Fenster): `game.ReplicatedStorage.Remotes.BuyUpgrade:FireServer("World7Shop", "PizzaSpace")` → nichts passiert, Münzen unverändert.

**Mehrspieler** (2 Spieler):

- [ ] A hat den Vulkan freigeschaltet, B nicht: B kommt nicht durch die Vulkan-Barriere (wird zurückgesetzt), A schon.

**Handy** (Device-Emulator, iPhone SE quer + Tablet):

- [ ] Freischalt-Knöpfe „… freischalten – 150.000.000 Münzen“ sind groß, lesbar (nicht abgeschnitten) und per Antippen bedienbar.
- [ ] Shop-3-Menü: Kaufknöpfe mit langen Preisen („1.200.000.000 Münzen“) lesbar und gut antippbar; Liste scrollt per Wischen.
- [ ] Portal-Menü mit 7 Einträgen scrollt per Wischen, alle Zeilen gut antippbar.

## #13 Tränke: Münzen, Glück, Speed

Vorher: `lune run test` → alle grün (u. a. `tests/Potions.spec.luau` und `GameConfig potions`).

Tipp für schnelles Testen: In `src/shared/GameConfig.luau` vorübergehend `durationSeconds = 30` bei allen drei Tränken und den Gem-Tipp aus #12 (`gems.playtimeSeconds = 30`, `gems.playtimeGems = 500`) setzen (Server neu starten). **Danach zurücksetzen, nicht committen.**

Studio: Rojo verbinden, dann **Play** (1 Spieler):

- [ ] Output ohne rote Fehler. Links unter dem runden „Pets“-Knopf steht ein runder lila Knopf **„Tränke“**; rechts ist noch keine Trank-Anzeige zu sehen.
- [ ] Shop in Welt 1: Unter den Gem-Upgrades kommt der Abschnitt **„Gem-Tresen: Tränke (je 10 Min.)“** mit Münz-Trank (25 Gems), Glücks-Trank (30) und Speed-Trank (15), jeweils mit „Im Inventar: 0“. Mit zu wenig Gems: grauer Knopf, Antippen → „Nicht genug Gems!“, nichts ändert sich.
- [ ] Trank kaufen → Gems sinken um den Preis, Status „Gekauft: Münz-Trank! – im Trank-Menü trinken“, „Im Inventar“ steigt. Zweimal kaufen → 2.
- [ ] „Tränke“-Knopf → Menü „Meine Tränke“ mit 3 Karten (💰/🍀/⚡), Anzahl im Inventar, grüner Knopf „Trinken“ (grau, wenn 0). „X“ und erneutes Tippen auf „Tränke“ schließen.
- [ ] **Münz-Trank** trinken → Toast „Münz-Trank wirkt 10 Minuten!“, rechts erscheint „💰 Münzen ×2  10:00“ und zählt sekündlich herunter. Pizza verkaufen → doppelte Münzen (mit Pets: Belagwert × Pet-Bonus × 2).
- [ ] Gleichen Trank nochmal trinken → Restzeit **verlängert** sich um 10 Min. (z. B. 9:30 → 19:30), sie startet nicht neu.
- [ ] **Speed-Trank** → man läuft sichtbar schneller (Tempo × 1,5, also 16 → 24, mit Tempo-Upgrade 19 → 28,5). Gilt auch nach Respawn (Reset). Nach Ablauf wieder normales Tempo.
- [ ] **Glücks-Trank** → in jeder Ei-Vorschau steht „🍀 Glück!“ hinter dem Ei-Namen, die Chancen sind grün und seltene Pets höher (Garten-Ei: Pizza-Drache 0,5 % → ca. 1,2 %, Teig-Hamster 50 % → ca. 41 %). Nach Ablauf wieder die normalen Werte.
- [ ] Ablauf: Wenn die Zeit um ist, verschwindet die Anzeige rechts, Toast „… ist abgelaufen.“, die Wirkung endet (Verkaufswert/Tempo/Chancen wieder normal).
- [ ] Mehrere Tränke gleichzeitig: alle drei trinken → drei Anzeigen rechts untereinander, jede mit eigener Zeit.
- [ ] Speichern: Tränke im Inventar und laufende Restzeit bleiben nach Rejoin erhalten. Während man offline ist, läuft die Zeit **nicht** weiter (so gewollt).
- [ ] Server-Schutz (optional, Command Bar im Client): `game.ReplicatedStorage.Remotes.DrinkPotion:FireServer("Coins")` ohne Trank im Inventar → nichts passiert außer Meldung; `BuyPotion:FireServer("World1Shop", "Coins")` **außerhalb** des Shops → nichts passiert.

**Handy** (Device-Emulator, iPhone SE quer + Tablet):

- [ ] „Tränke“-Knopf ist groß, gut antippbar, überdeckt weder den „Pets“-Knopf noch den Joystick.
- [ ] Trank-Menü passt auf den Bildschirm; „Trinken“-Knöpfe groß und per Antippen bedienbar.
- [ ] Trank-Anzeigen rechts sind lesbar und liegen nicht über dem Sprung-Knopf (unten rechts).
- [ ] Shop-Menü: Trank-Kaufknöpfe lesbar und antippbar, Liste scrollt per Wischen bis zu den Tränken.

## Beobachtungen aus dem Studio-Test (16.11.2026, nicht behoben)

- [ ] UI-Überlappungen: Tutorial-Karte überdeckt Meldungen („+40 Münzen“) und die Ei-Vorschau; Shop-Menü überdeckt die Münz-/Gem-Anzeige; im Teleport-Menü wird der unterste Eintrag halb von der Pizza-Leiste verdeckt; der Freischalt-Knopf an der Barriere liegt genau auf dem Auto-Sammeln-Knopf.
- [ ] Kamera: In Ofen-, Shop- und Ei-Nähe wird die Kamera an den Kopf gedrückt (Stationen stehen hinter der Startkamera, +Z).
- [ ] Pets stellen sich am Ofen aufs Dach bzw. stecken halb in der Wand.
- [ ] Sounds (#15 Schritt 3) noch offen: IDs müssen in Studio angehört und ausgewählt werden.
