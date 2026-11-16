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
- [x] HUD unten: grauer Knopf „Auto-Sammeln: AUS“ direkt über `Pizza 0/2`.
- [x] Mit AUS über Beläge laufen → nichts wird eingesammelt (Anklicken geht weiterhin).
- [ ] Knopf drücken → wird grün, „Auto-Sammeln: AN“, hüpft kurz. Im Explorer: `Players.<Name>` hat Attribut `AutoCollect = true`.
- [x] Mit AN über einen Belag laufen (ca. 4 Studs Radius) → Belag verschwindet, erscheint auf der Pizza in der Hand, HUD `Pizza 1/2`. Beläge daneben (> 4 Studs) bleiben liegen.
- [x] Zweiten Belag aufsammeln → Pizza `2/2` (rot), Meldung „Pizza voll! Ab zum Ofen.“ erscheint **einmal** sofort.
- [ ] Mit voller Pizza weiter über Beläge laufen → Beläge bleiben liegen, Meldung höchstens alle ~3 s (kein Dauer-Spam).
- [ ] Knopf erneut drücken → AUS (grau), Auto-Sammeln stoppt.
- [ ] Mit Belägen in die Ofen-Zone laufen → **Animation**: eine Pizza fliegt vom Spieler in die glühende Ofenöffnung und schrumpft, danach fliegen mehrere goldene Münzen vom Ofen hoch zur Münzanzeige; Münzanzeige hüpft, „+X Münzen“. Beläge auf der Pizza in der Hand sind danach weg.
- [ ] Ofen außerhalb des Bildschirms (Kamera wegdrehen) → Münzen starten aus der Bildschirmmitte, keine Fehler.
- [x] Nach Reset (Esc → Reset Character) bleibt der Schalter-Zustand erhalten.
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

## #8 Welt 2 Bauernhof und Barriere freischalten

Vorbereitung: Zum schnellen Testen in `src/shared/GameConfig.luau` vorübergehend `unlockPrice = 15` für `Farm` setzen (**nicht committen**, danach zurück auf 1500) oder ein paar Runden sammeln/verkaufen. Bei Testpreis 15 steht im Folgenden „15“ statt „1.500“.

**Welt und Barriere** (Play, 1 Spieler):

- [ ] Hinter dem Pizzeria-Garten (Richtung −Z, hinter der Belag-Fläche) liegt eine zweite Fläche „Bauernhof“ (sandfarben) mit eigener Belag-Fläche, Ofen, Ei-Sockel mit „Bauernhof-Ei“ und 60 Belägen in neuen Farben (Zwiebel lila, Paprika grün, Mais gelb, Schinken rosa).
- [ ] Zwischen den Welten steht eine rote Kraftfeld-Wand über die ganze Breite; davor schwebt „🔒 Bauernhof / 1.500 Münzen“.
- [ ] Gegen die Wand laufen → man kommt nicht durch, auch nicht durch Springen oder an den Rändern.
- [ ] Nahe der Wand (< ca. 22 Studs) erscheint unten ein großer Knopf „🔓 Bauernhof freischalten / 1.500 Münzen“: grau bei zu wenig Münzen, grün bei genug. Weggehen → Knopf verschwindet.
- [ ] Knopf mit zu wenig Münzen → Meldung „Nicht genug Münzen!“, Münzen unverändert.
- [ ] Knopf mit genug Münzen → Münzen −1.500, Meldung „Neue Welt freigeschaltet!“, Wand wird für mich unsichtbar, Preisschild weg, Knopf weg, man läuft durch.
- [ ] Im Bauernhof Beläge sammeln (Klick und Auto-Sammeln) und am Bauernhof-Ofen verkaufen → Werte 4/8/12/20 Münzen.
- [ ] Output ohne Fehler (rot) beim Start und beim Freischalten.

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

- [ ] Output ohne rote Fehler. Im Workspace gibt es `Eggs` (mit `GardenEgg` und `FarmEgg`) und `Pets`.
- [ ] Links neben dem Spawn (x = −30, zwischen Spawn und Shop-Stand) steht auf einem Sockel ein cremefarbenes Ei mit orangen Punkten, nicht im Boden versunken und nicht schwebend.
- [ ] Hinlaufen (< 20 Studs) → über dem Ei schwebt die Vorschau „Garten-Ei“ mit 6 Zeilen: Teig-Hamster (grau, 50 %, +10 %), Basilikum-Hase (grün, 28 %, +15 %), Tomaten-Katze (blau, 15 %, +25 %), Käse-Maus (lila, 5,5 %, +40 %), Oliven-Eule (orange, 1 %, +75 %), Pizza-Drache (pink, 0,5 %, +150 %) und darunter der grüne Knopf „1 öffnen – 25 Münzen“. Weggehen → Vorschau verschwindet.
- [ ] Vorschau ist lesbar, nicht abgeschnitten und verdeckt das Ei nicht komplett (ggf. `StudsOffsetWorldSpace`/`WIDTH` in `src/client/EggPreview.luau` anpassen).
- [ ] Mit weniger als 25 Münzen „1 öffnen“ antippen → Knopf wird kurz rot „Zu wenig Münzen!“, Münzen unverändert, kein Pet.
- [ ] Mit genug Münzen „1 öffnen“ → Münzen sinken um 25; Animation: Ei wackelt immer stärker, knackt (⚡), weißer Blitz, Pet-Karte springt heraus (Name, Seltenheit in Farbe, „+X % Münzen“). Antippen oder 3 s warten schließt sie.
- [ ] Schnell mehrfach tippen öffnet nicht mehrere Eier gleichzeitig (Sperre ca. 2,5 s).
- [ ] Links mittig großer runder Knopf „Pets“ → Menü „Meine Pets“ mit Karten (Farbe = Seltenheit, Name, Bonus, Knopf „Ausrüsten“). Ohne Pets: „Noch keine Pets – öffne ein Ei!“.
- [ ] Karte antippen → Pet ausgerüstet (Karte rückt nach vorn, „Ablegen“), Kopfzeile „Ausgerüstet 1/3 · Münz-Bonus +X %“. Neben dem Spieler erscheint eine farbige Kugel mit Augen und Namensschild.
- [ ] 4 Pets öffnen, 3 ausrüsten → das 4. lässt sich nicht ausrüsten, Meldung „Alle Pet-Plätze belegt – erst ein Pet ablegen!“. Eins ablegen → Kugel verschwindet, das 4. lässt sich nun ausrüsten.
- [ ] Ausgerüstete Pets laufen in einer Reihe hinter dem Spieler her, hüpfen beim Laufen, schweben im Stand leicht, stehen auf dem Boden (nicht im Boden / nicht in der Luft), auch an Rampen/Kanten. Kein Ruckeln, Spieler kollidiert nicht mit ihnen.
- [ ] Verkaufswert: z. B. mit Teig-Hamster (+10 %) und Tomaten-Katze (+25 %) ergibt eine Pizza aus Pilz + Mozzarella (7) → 7 × 1,35 = 9,45 → **9** Münzen. Ohne ausgerüstete Pets wieder 7.
- [ ] Nach Reset (Esc → Reset Character) folgen die Pets der neuen Figur weiter.
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

- [ ] Output ohne rote Fehler. Im Workspace gibt es den Ordner `Portals` mit je einem `Portal_<WeltId>` pro Welt aus der Config (aktuell `Portal_PizzeriaGarden`, `Portal_Farm`, ggf. weitere aus #10).
- [ ] Welt 1: Rechts vom Ofen (ca. x = 65, z = 70) steht ein lila leuchtender Ring mit hellblauer Fläche, Funkeln und Schild „🌀 Teleport“. Steht auf dem Boden, nicht im Ofen / in der Belag-Fläche.
- [ ] In den Ring laufen → Menü „🌀 Teleport“ in der Bildschirmmitte: „📍 Pizzeria-Garten (du bist hier)“ (orange, nicht anwählbar), darunter „🔒 Bauernhof – 1.500 Münzen“ grau (und weitere gesperrte Welten grau mit Preis).
- [ ] Grauen Eintrag antippen → nichts passiert (kein Teleport).
- [ ] Aus dem Ring laufen → Menü schließt. „X“ schließt es ebenfalls.
- [ ] Bauernhof an der Barriere freischalten, zurück in den Portal-Ring → „2. Bauernhof“ ist jetzt lila und anwählbar. (Steht man beim Freischalten im Ring, aktualisiert sich das Menü sofort.)
- [ ] „Bauernhof“ antippen → Figur steht sofort vor dem Bauernhof-Portal (Blick Richtung Welt), Menü zu, es öffnet sich nicht gleich wieder.
- [ ] Im Bauernhof-Portal steht „📍 Bauernhof (du bist hier)“; „Pizzeria-Garten“ antippen → zurück in Welt 1 vor dem Portal.
- [ ] Ankunftspunkt ist frei (nicht in Ofen, Ei oder Barriere), man fällt nicht durch den Boden.
- [ ] Im HUD gibt es **keinen** Teleport-Knopf.

**Server-Schutz** (Command Bar im Client-Fenster bzw. Executor nicht nötig):

- [ ] Im Client-Fenster (nicht im Portal) in der Command Bar: `game.ReplicatedStorage.Remotes.Teleport:FireServer("Farm")` → nichts passiert (nur aus einem Portal heraus).
- [ ] Im Portal stehend, Bauernhof gesperrt: `game.ReplicatedStorage.Remotes.Teleport:FireServer("Farm")` → kein Teleport, Meldung „Diese Welt ist noch gesperrt!“.

**Mehrspieler** (Test → Clients and Servers → 2 Spieler):

- [ ] A hat den Bauernhof, B nicht: Bei A ist „Bauernhof“ anwählbar, bei B grau. Teleport von A beeinflusst B nicht (B's Menü bleibt unverändert).

**Handy** (Device-Emulator, iPhone SE quer + Tablet):

- [ ] Menü passt auf den Bildschirm, „X“ erreichbar, Einträge groß und mit dem Daumen antippbar, Liste scrollt per Wischen.
- [ ] Antippen teleportiert (kein Maus-Hover nötig).

## #7 Pet-Verwaltung: Beste ausrüsten, Löschen, Inventargrenze

Vorher: `lune run test` → alle grün (neue Fälle in `tests/Pets.spec.luau`: `equipBest`, `deletePet`, `inventory limit`).

Vorbereitung: Zum schnellen Testen in `src/shared/GameConfig.luau` vorübergehend `price = 1` beim `GardenEgg` und `inventory.start = 5` setzen (**nicht committen**, danach zurück auf 25 bzw. 50).

Studio: Rojo verbinden, dann **Play** (1 Spieler):

- [ ] Output ohne rote Fehler.
- [ ] Pet-Menü öffnen: Kopfzeile zeigt „Ausgerüstet X/3 · Inventar Y/5 · Bonus +Z %“ (mit echtem Wert: Y/50). Darunter zwei große Knöpfe „Beste ausrüsten“ (grün) und „Löschen“ (rot), die Pet-Liste darunter ist nicht verdeckt.
- [ ] Ohne Pets „Beste ausrüsten“ antippen → Kopfzeile kurz rot „Noch keine Pets – öffne ein Ei!“.
- [ ] Mehrere Pets öffnen (verschiedene Seltenheiten), nur schwache ausrüsten → „Beste ausrüsten“ → die 3 Pets mit dem höchsten Bonus sind ausgerüstet (Karten vorn, „Ablegen“), Münz-Bonus in der Kopfzeile passt (Summe der 3 Boni). Die Pet-Kugeln neben dem Spieler wechseln entsprechend.
- [ ] „Beste ausrüsten“ erneut antippen, wenn schon die besten ausgerüstet sind → nichts ändert sich (keine Pets verschwinden/erscheinen).
- [ ] „Löschen“ antippen → Knopf wird dunkel „Fertig“, Titel „Pet zum Löschen antippen“, „Beste ausrüsten“ ist ausgeblendet, alle Karten zeigen roten „Löschen“-Streifen.
- [ ] Im Löschen-Modus eine Karte antippen → Dialog „<Name> (+X %) wirklich löschen?“ mit großen Knöpfen „Löschen“ / „Behalten“. „Behalten“ → nichts passiert.
- [ ] „Löschen“ im Dialog → Pet verschwindet aus der Liste, Inventar-Zahl sinkt um 1.
- [ ] Ein **ausgerüstetes** Pet löschen → Dialog erwähnt „Es wird dabei abgelegt.“; nach dem Löschen verschwindet seine Kugel neben dem Spieler, „Ausgerüstet“ und Bonus sinken.
- [ ] „Fertig“ bzw. Menü schließen (X oder „Pets“-Knopf) beendet den Löschen-Modus; beim nächsten Öffnen normale Ansicht.
- [ ] Inventar füllen (5/5 mit Testwert) → Kopfzeile rot. Am Ei „1 öffnen“ → Knopf wird kurz rot „Inventar voll!“, oben erscheint Meldung „Pet-Inventar voll! Lösche erst ein Pet.“, **keine Münzen abgezogen**, keine Animation.
- [ ] Ein Pet löschen → Ei lässt sich wieder öffnen.
- [ ] Rejoin (Speichern aktiv): gelöschte Pets bleiben weg, Ausrüstung nach „Beste ausrüsten“ bleibt erhalten.

**Mehrspieler** (2 Spieler): Löscht A ein ausgerüstetes Pet, verschwindet dessen Kugel auch bei B.

**Handy** (Device-Emulator, iPhone SE quer + Tablet):

- [ ] Pet-Menü (jetzt 560 hoch) passt komplett auf den Bildschirm, „X“, „Beste ausrüsten“ und „Löschen“ sind mit dem Daumen gut antippbar.
- [ ] Bestätigungsdialog passt, beide Knöpfe gut antippbar; Antippen außerhalb des Dialogs löst keine Karte darunter aus.
- [ ] Wischen in der Liste im Löschen-Modus öffnet nicht versehentlich den Dialog.
