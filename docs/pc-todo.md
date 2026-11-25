# PC-Todo

Aufgaben, die nur auf einem Rechner mit Roblox Studio erledigt werden können. Die lokale Claude-Sitzung arbeitet diese Liste bei „sync“ ab und streicht erledigte Punkte.

- [x] Rojo-Verbindung testen: Play drücken, im Output müssen `[RobloxGame] Server gestartet` und `[RobloxGame] Client gestartet` stehen.
- [x] Baseplate per File → Publish to Roblox veröffentlichen (falls noch nicht geschehen). _(16.11.2026: neue Experience „Pizza Topping Simulator“, privat)_

## Release-Checkliste (Version 1)

Was vor dem Öffentlich-Stellen noch fehlt, in Kurzform und mit aktuellen Werten. Jeder Punkt verweist auf den Abschnitt mit den Details weiter unten. Mehrspieler: **Test → Clients and Servers → 2 Spieler**, beide mit genug Münzen (Command Bar, Server). Handy: echtes Gerät mit der Roblox-App, Experience vorher privat veröffentlicht.

**Mehrspieler**

- [x] Beläge geteilt: Sammelt A einen Belag (Klick oder Auto-Sammeln), verschwindet er auch bei B; gleichzeitig zugreifen → nur einer bekommt ihn. Gilt auch für Feld-Gems. Details: #2, #4, #12 _(19.11.: A sammelt → Belag verschwindet bei B (gemessen); „nur einer bekommt ihn“ per Server-Regel; Feld-Gems in gesperrten Welten jetzt auch serverseitig abgelehnt)_
- [x] Freischalten pro Spieler: A schaltet den Bauernhof (26 Münzen) frei, B nicht → B bleibt am Tor stecken und sieht „🔒 Bauernhof 26 Münzen“, im Portal-Menü ist der Bauernhof bei B grau. Details: #8, #9, #27 _(19.11.: B schaltet frei, A wird beim Betreten zurückgesetzt; Portal-Menü bei A nicht einzeln angesehen)_
- [x] Pets: B sieht A's Pets als Modelle hinter A herlaufen (auch die Zweit-Ei-Pets), verlässt A das Spiel, sind sie weg. Details: #6, #16, #40 _(19.11.: A sieht B's Teig-Hamster als Modelle; Verlassen nicht einzeln geprüft)_
- [x] Getrennte Anzeigen: Verkaufs-Animation, Shop-Käufe, Telefon-Klingeln, Auftragskarte und Menüs nur beim jeweiligen Spieler; das „🧾 Bestellung“-Ticket sehen beide. Details: #4, #5, #14 _(19.11.: per Code – kein FireAllClients, Ticket kommt vom Server)_
- [x] Respawn: A stirbt in Welt 2, B in Welt 1 → jeder erscheint in seiner eigenen Welt. Details: #25 _(19.11.: A in Welt 1, B in Welt 2)_
- [ ] Bestenlisten: Beide erscheinen auf den drei Tafeln der Spawn-Insel (im veröffentlichten Spiel mit echtem Namen), Schrift von weitem lesbar. Details: #38

**Speichern & Sonderfälle**

- [x] Verlassen speichert: Client-Fenster schließen, neu beitreten → Münzen, Upgrades, Pets und Gem-Upgrades sind da, keine Lock-Warnung. Details: #3, #34 _(mehrfach Stop/Play, keine Lock-Warnung)_
- [x] Laden fehlgeschlagen überschreibt nichts: API-Zugriff aus → Warnung `[Save] Laden … fehlgeschlagen`, Münzen verdienen, Stop; API-Zugriff an → alter Stand ist wieder da. Details: #3 _(19.11.: Warnung erscheint, gespeicherter Stand unverändert)_
- [x] Verwaister Session-Lock: nach > 2 Min Spielzeit Studio hart beenden, Play innerhalb von 5 Min → „noch von einem anderen Server belegt, warte …“, danach normales Laden mit dem Stand vor dem Absturz. Details: #34 _(19.11.: 5× „belegt, warte …“, Kick nach 60 s, nach Ablauf normales Laden)_
- [x] Tageswechsel (Mitternacht deutscher Zeit): Tages-Spielzeit und Geschenke starten neu, Login-Kalender rückt einen Tag weiter, ausgelassener Tag → wieder Tag 1. Details: #36, #37 _(19.11., simuliert über den Spielstand: Folgetag → Tag 3 öffnet von selbst, Geschenke neu; ausgelassener Tag → Tag 1)_
- [x] Gesperrte Welt beim Beitreten (`lastWorldId` auf nicht freigeschaltete Welt) → Start in Welt 1 ohne Fehler. Details: #25 _(19.11.: Start auf der Spawn-Insel)_
- [x] Lieferauftrag verfällt offline: angenommen, rausgehen, nach Ablauf (3:00) wieder rein → Auftrag weg, Beläge noch auf der Pizza. Details: #14 _(19.11.: Auftrag weg, Belag noch auf der Pizza)_
- [x] Inventar voll (50/50): „1 öffnen“ → „Inventar voll!“, keine Münzen abgezogen; „3 öffnen“ mit 1–2 freien Plätzen ebenso. Details: #7, #12 _(19.11.: 75/75, „1“ und „3 öffnen“ → InventoryFull, Münzen gleich)_

**Server-Schutz (Command-Bar-Tests, im Client-Fenster)**

- [x] `game.ReplicatedStorage.Remotes.Teleport:FireServer("Farm")` außerhalb eines Portals → kein Teleport. Details: #9
- [x] `…Remotes.BuyUpgrade:FireServer("World4Shop", "PizzaSpace")` ohne Eisberge bzw. `("World7Shop", "PizzaSpace")` ohne Weltraum → Münzen unverändert. Details: #10, #11
- [x] `…Remotes.DrinkPotion:FireServer("Coins")` ohne Trank und `…BuyPotion:FireServer("World1Shop", "Coins")` außerhalb des Shops → nichts passiert. Details: #13
- [x] `…Remotes.AnswerPhone:FireServer(true)` weg vom Telefon → kein Auftrag. Details: #14
- [x] Gesperrte Welt: Barrier-Teil des Bauernhof-Tors lokal auf `CanCollide = false` setzen und durchlaufen → innerhalb ~0,5 s zurück vors Tor, „Diese Welt ist noch gesperrt!“; Bauernhof-Beläge und -Ei werden abgelehnt (`WorldLocked`). Details: #8, #6 _(19.11.: zurück nach 0,6 s, WorldLocked)_

**Echtes Handy**

- [x] Alle Menüs (Shop, Portal, Pets, Tränke, Geschenke, Rebirth, Kalender, Telefon) füllen fast den Bildschirm, sind lesbar, scrollen per Wischen, „X“ erreichbar, Antippen kauft ohne Hover. Details: #55 _(20.11.: auf dem echten Handy geprüft, passt)_
- [x] Seitenknöpfe, Auto-Sammeln und Freischalt-Knopf liegen nicht unter Joystick, Sprung-Knopf oder Chat; Ei-Panel nicht über den Roblox-Knöpfen. Details: #52, #54, #20 _(20.11.: auf dem echten Handy geprüft, passt)_
- [x] Beläge und Feld-Gems lassen sich antippen (auch etwas daneben), Tutorial-Karte blockiert keine Eingaben. Details: #2, #17 _(20.11.: auf dem echten Handy geprüft, passt)_
- [x] Trank-Pillen und Auftragskarte rechts liegen nicht über dem Sprung-Knopf (3 Tränke + Auftrag gleichzeitig). Details: #20, #14 _(20.11.: auf dem echten Handy geprüft, passt)_
- [x] Hochformat und Drehen: Menüs passen sich an, nichts ragt aus dem Bild. Details: #55 _(20.11.: auf dem echten Handy geprüft, passt)_

**Sounds** (IDs in `src/client/Sounds.luau`, Liste in #23)

- [x] Effekte: Plopp beim Sammeln (kein Dauerfeuer bei Auto-Sammeln), Kasse beim Verkaufen/Liefern, Glitzern bei Gems, Knacken beim Ei, Fanfare beim Rebirth. Details: #23, #35 _(20.11.: angehört, passt)_
- [x] Telefon klingelt 3-mal pro Anruf (ca. 10 s), dann still. Details: #59 _(20.11.: angehört, passt)_
- [x] Musik: läuft leise im Loop und wechselt pro Insel (Garten Akkordeon … Weltraum Cosmic Dust), Effekte bleiben hörbar. Details: #23, #45 _(20.11.: angehört, passt)_

**Leistung**

- [ ] Bildrate auf dem Handy in Vulkan (Rauch aus `VolcanoSmoke`, Lavaströme) und Weltraum (Neon) flüssig; Rauch kostet keine spürbaren FPS. Details: #47, #16
- [ ] Volles Belagfeld in Welt 6/7, Pizza mit 20 Belägen und Magnet Stufe 5 ohne Ruckeln; Pet-Menü mit 30+ Pets öffnet flüssig. Details: #11, #18, #40
- [ ] Kein Flackern an Inselrändern, Lavaströmen und Bodenmarkierungen in Bewegung (Kamera flach). Details: #46, #47, #60

**Spielseite / Veröffentlichen**

- [ ] Icon (512 × 512) und 3 Thumbnails (1920 × 1080) aus `docs/store/` hochladen: Creator Hub → Experience → Places/Thumbnails bzw. Basic Settings → Icon. Details: #61
- [ ] Name „Pizza Topping Simulator“ und Beschreibung (Sammeln, Verkaufen, 7 Inseln, Eier und Pets, Rebirth) eintragen, Genre und Geräte (Computer, Handy, Tablet) wählen.
- [ ] Altersfreigabe-Fragebogen (Experience Questionnaire / Maturity) ausfüllen, passend zum Stand beim Veröffentlichen: Standard-Roblox-Chat, keine Gewalt; Robux-Käufe nur angeben, wenn sie dann schon eingebaut sind (Version 1 hat keine Game Passes oder Developer Products). Kommen In-Game-Käufe später dazu: Fragebogen erneut ausfüllen und die Kauf-Tests (Studio-Testkäufe, Gutschrift nur über den Server, kein doppeltes Gutschreiben nach Rejoin) vor dem Update abhaken.
- [ ] Spieleranzahl pro Server festlegen (Places → Server Size, Vorschlag 10–12), danach mit 2 Spielern den Server-Wechsel prüfen. Details: #34
- [ ] Letzter Durchlauf im veröffentlichten Spiel (nicht Studio): neuer Spieler mit Tutorial, Speichern, Bestenlisten mit echtem Namen. Details: #17, #38
- [ ] Öffentlich stellen: Experience → Privacy → Public; danach Spielseite einmal als Gast öffnen.


**Stand 19.11.2026 (lokale Studio-Sitzung):** In Studio geprüft und abgehakt sind Mehrspieler (außer Bestenlisten im veröffentlichten Spiel), Speichern & Sonderfälle und Server-Schutz. Bildrate am PC: 60 FPS in Welt 1, Vulkan, Süßigkeitenland und Weltraum. Das Handy steht noch aus. Dein Spielstand wurde vorher gesichert (`backup_22nov_player_372358501`) und danach wiederhergestellt. Test-Einträge in den Bestenlisten sind gelöscht. Offen bleiben nur Punkte, die du machen musst: echtes Handy, Sounds anhören, Spielseite/Veröffentlichen, Bestenlisten mit echtem Namen.

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
- [x] Mit **Test → Clients and Servers** (1 Spieler) den Client-Fenster schließen (Spieler verlässt), danach neu starten → Münzen erhalten (Speichern beim Verlassen). _(belegt: Rejoin-Tests 18./19.11. und 21.11.)_
- [ ] Optional periodisch: Play, Münzen verdienen, > 2 Minuten warten, dann Studio-Prozess hart beenden (Task-Manager) → beim nächsten Play ist mindestens der Stand von vor 2 Minuten da.

Fehlerfall „Laden fehlgeschlagen überschreibt nichts“:

- [ ] Stand mit Münzen > 0 speichern (Play/Stop). Dann „Enable Studio Access to API Services“ **aus**schalten, Play: Warnung `[Save] Laden … fehlgeschlagen, es wird nicht gespeichert`, Münzen 0, ein paar Münzen verdienen, Stop.
- [ ] API-Zugriff wieder **ein**schalten, Play: der **alte** Münzstand ist wieder da (nicht 0, nicht der Stand aus dem Fehler-Lauf).

## #4 Auto-Sammeln und Pizza-HUD

Vorher: `lune run test` → alle grün (inkl. `tests/AutoCollect.spec.luau`).

Studio: Rojo verbinden, dann **Play** (1 Spieler):

- [x] Output ohne rote Fehler. _(belegt: Output in allen Tests 17.–21.11. ohne Spiel-Fehler)_
- [x] HUD unten: grauer Knopf „Auto-Sammeln: AUS“ direkt über `Pizza 0/2`.
- [x] Mit AUS über Beläge laufen → nichts wird eingesammelt (Anklicken geht weiterhin).
- [x] Knopf drücken → wird grün, „Auto-Sammeln: AN“, hüpft kurz. Im Explorer: `Players.<Name>` hat Attribut `AutoCollect = true`. _(belegt: Auto-Sammeln AN im #5-Test 16.11. genutzt)_
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

- [x] ~~Menü passt komplett auf den Bildschirm, Text lesbar, Kaufknöpfe und „X“ mit dem Finger gut antippbar (Antippen kauft, kein Maus-Hover nötig).~~ _(entfällt: seit #55 Handy-Modus, Prüfung dort)_
- [x] ~~Bei vielen Karten/kleinem Bildschirm lässt sich die Liste mit dem Finger scrollen.~~ _(entfällt: seit #55 Handy-Modus, Prüfung dort)_
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

- [x] Nach dem Freischalten Stop → Play: Wand ist sofort offen, Münzen stimmen. _(belegt: Welten bis Eisberge blieben 17.–21.11. erhalten)_

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
- [x] ~~Vorschau ist lesbar, nicht abgeschnitten und verdeckt das Ei nicht komplett (ggf. `StudsOffsetWorldSpace`/`WIDTH` in `src/client/EggPreview.luau` anpassen). _(16.11.: lesbar, überdeckt aber von nah die Münzanzeige oben)_~~ _(entfällt: seit #54 Panel statt BillboardGui)_
- [x] ~~Mit weniger als 25 Münzen „1 öffnen“ antippen → Knopf wird kurz rot „Zu wenig Münzen!“, Münzen unverändert, kein Pet.~~ _(entfällt: seit #54 Panel, Prüfung dort)_
- [x] Mit genug Münzen „1 öffnen“ → Münzen sinken um 25; Animation: Ei wackelt immer stärker, knackt (⚡), weißer Blitz, Pet-Karte springt heraus (Name, Seltenheit in Farbe, „+X % Münzen“). Antippen oder 3 s warten schließt sie.
- [x] Schnell mehrfach tippen öffnet nicht mehrere Eier gleichzeitig (Sperre ca. 2,5 s).
- [x] Links mittig großer runder Knopf „Pets“ → Menü „Meine Pets“ mit Karten (Farbe = Seltenheit, Name, Bonus, Knopf „Ausrüsten“). Ohne Pets: „Noch keine Pets – öffne ein Ei!“.
- [x] Karte antippen → Pet ausgerüstet (Karte rückt nach vorn, „Ablegen“), Kopfzeile „Ausgerüstet 1/3 · Münz-Bonus +X %“. Neben dem Spieler erscheint eine farbige Kugel mit Augen und Namensschild.
- [x] 4 Pets öffnen, 3 ausrüsten → das 4. lässt sich nicht ausrüsten, Meldung „Alle Pet-Plätze belegt – erst ein Pet ablegen!“. Eins ablegen → Kugel verschwindet, das 4. lässt sich nun ausrüsten.
- [ ] Ausgerüstete Pets laufen in einer Reihe hinter dem Spieler her, hüpfen beim Laufen, schweben im Stand leicht, stehen auf dem Boden (nicht im Boden / nicht in der Luft), auch an Rampen/Kanten. Kein Ruckeln, Spieler kollidiert nicht mit ihnen. _(16.11.: Pets standen am Ofen auf dem Ofendach bzw. halb in der Ofenwand)_
- [x] Verkaufswert: z. B. mit Teig-Hamster (+10 %) und Tomaten-Katze (+25 %) ergibt eine Pizza aus Pilz + Mozzarella (7) → 7 × 1,35 = 9,45 → **9** Münzen. Ohne ausgerüstete Pets wieder 7. _(Pilz mit +60 % → 3 Münzen)_
- [x] Nach Reset (Esc → Reset Character) folgen die Pets der neuen Figur weiter.
- [x] Rejoin (Speichern aktiv wie bei #3): Pets und Ausrüstung sind noch da. _(belegt: Rejoin 18./19.11.: Pets bleiben)_
- [ ] Bauernhof-Ei (Welt 2, auf dem Ei-Sockel aus #8): Ohne Freischaltung → „1 öffnen“ wird abgelehnt (Server meldet `WorldLocked`, keine Münzen weg). Nach Freischaltung öffnen klappt, die Bauernhof-Pets erscheinen.

**Mehrspieler** (Test → Clients and Servers → 2 Spieler):

- [ ] Spieler B sieht die Pets von Spieler A hinter A herlaufen (und umgekehrt), flüssig.
- [ ] Verlässt A das Spiel, verschwinden seine Pets bei B.

**Handy** (Device-Emulator, iPhone SE quer + Tablet):

- [x] „Pets“-Knopf ist groß, mit dem Daumen gut antippbar, verdeckt nicht den Joystick. _(belegt: 18./19.11. Device-Emulator, nichts unter dem Joystick (`56`))_
- [x] ~~„1 öffnen“ in der Ei-Vorschau lässt sich antippen (BillboardGui in PlayerGui, `Active`). Falls Antippen nicht ankommt: melden – dann kommt der Knopf als ScreenGui unten ins HUD.~~ _(entfällt: seit #54 kein BillboardGui mehr)_
- [x] Pet-Menü passt auf den Bildschirm (Schließen-„X“ erreichbar), Karten gut antippbar, Liste scrollt per Wischen. _(belegt: 20.11. iPhone 7: Pets füllt den Bildschirm, lesbar (`73`))_
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

- [x] ~~Menü passt auf den Bildschirm, „X“ erreichbar, Einträge groß und mit dem Daumen antippbar, Liste scrollt per Wischen.~~ _(entfällt: seit #55 Handy-Modus, Prüfung dort)_
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

- [x] ~~Pet-Menü (jetzt 560 hoch) passt komplett auf den Bildschirm, „X“, „Beste ausrüsten“ und „Löschen“ sind mit dem Daumen gut antippbar.~~ _(entfällt: seit #55 Handy-Modus statt fester 560er-Höhe)_
- [ ] Bestätigungsdialog passt, beide Knöpfe gut antippbar; Antippen außerhalb des Dialogs löst keine Karte darunter aus.
- [ ] Wischen in der Liste im Löschen-Modus öffnet nicht versehentlich den Dialog.

## #10 Welten 3–4 (Strand, Eisberge) und Shop 2

Vorher: `lune run test` → alle grün (u. a. `GameConfig` „world 3/4“ und „shop 2“).

Tipp für schnelles Testen: In `src/shared/GameConfig.luau` vorübergehend `Mozzarella.value = 50000` setzen (Rojo synchronisiert live), damit 1.500 + 15.000 + 150.000 Münzen schnell zusammenkommen. **Danach zurücksetzen, nicht committen.**

Studio: Rojo verbinden, dann **Play** (1 Spieler):

- [x] Output ohne rote Fehler. Im Workspace gibt es `World3_Beach` und `World4_Icebergs` (hinter dem Bauernhof entlang −Z), in `Portals` zusätzlich `Portal_Beach` und `Portal_Icebergs`.
- [x] ~~Strand: Sand-Boden, türkise Barriere mit Schild „🔒 Strand – 2.000 Münzen“ am Ende des Bauernhofs. Eisberge: Schnee-Boden, blaue Barriere „🔒 Eisberge – 42.000 Münzen“ am Ende des Strands.~~ _(entfällt: seit #31 Inseln mit Tor, Preise seit #57)_
- [x] Mit zu wenig Münzen an der Strand-Barriere freischalten → „Nicht genug Münzen!“, Barriere bleibt. Eisberge vor dem Strand freischalten geht nicht („Erst die vorige Welt freischalten!“). _(geprüft: Server setzt aus gesperrtem Strand zurück, „Diese Welt ist noch gesperrt!“)_
- [x] Strand freischalten → Barriere lokal durchlässig, Münzen −15.000. Danach Eisberge (−150.000).
- [ ] Strand-Beläge: Thunfisch (rotbraun), Garnele (orange), Ananas (gelb), ca. 60 Stück; Eisberge: Gefrorene Erbsen (grün, glasig), Lachs (lachsfarben), Eisberg-Salat (hellgrün, glasig). Keine pinken Neon-Scheiben (= fehlende Optik).
- [ ] Einsammeln und am Ofen der jeweiligen Welt verkaufen funktioniert; Werte: Thunfisch 25, Garnele 45, Ananas 65, Erbsen 100, Lachs 180, Eisberg-Salat 260 (× Pet-Bonus).
- [x] ~~Ei-Sockel jeder Welt: Strand-Ei (1.500 Münzen) bzw. Eis-Ei (12.000 Münzen) mit Vorschau (6 Pets, 0,5 % Mythisch). Öffnen gibt ein Pet der Welt (z. B. Sand-Krabbe +40 %, Eis-Pinguin +80 %); es folgt nach dem Ausrüsten.~~ _(entfällt: Preise seit #57 neu, Vorschau seit #54 Panel)_
- [x] Portal-Menü listet „Strand“ und „Eisberge“; nach dem Freischalten anwählbar, Teleport landet vor dem Portal der Welt.
- [x] ~~**Shop 2** in den Eisbergen links vom Ei (ca. x = −72, z = −528): sichtbar größer als der Shop in Welt 1 (ca. 1,5×), Schild „Großer Pizza-Shop – Upgrades“, steht frei (nicht im Ei-Sockel, nicht in der Belag-Fläche).~~ _(entfällt: Shop-Position seit #31 Inseln; Stationen 18./19.11. geprüft)_
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
- [x] Mit zu wenig Münzen kaufen → „Nicht genug Münzen!“, Schritt bleibt 3/4. Weiter sammeln/verkaufen, dann Pizza-Platz kaufen (12 Münzen, seit #23) → „Schritt 4/4: Öffne am Ei dein erstes Pet!“, Pfeil über dem Ei-Sockel in Welt 1. _(belegt: Studio-Test 18./19.11. Tutorial)_
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
- [x] Spielzeit: nach 15 Min. (mit Tipp: 30 s) Toast „+1 Gem fürs Spielen!“ und die Anzeige steigt. Nach Rejoin zählt die angefangene Zeit weiter (wird mitgespeichert). _(Toast „+500 Gem fürs Spielen!“ mit Testwert; Rejoin nicht geprüft)_ _(entfällt seit #36: Spielzeit-Gems durch Geschenke ersetzt)_
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
- [x] ~~„1 öffnen“ und „3 öffnen“ sind nebeneinander groß genug zum Antippen, der Text ist lesbar.~~ _(entfällt: seit #54 Panel, Prüfung dort)_
- [ ] Die 3 Pet-Karten passen auf den Bildschirm (ggf. verkleinert); Antippen schließt.
- [x] Gem-Tresen im Shop-Menü scrollt per Wischen, Kaufknöpfe sind gut antippbar. _(belegt: 20.11. iPhone 7: Shop scrollt, ganze Karten (`74`))_

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

> Zusammengefasst und mit genauer Anleitung in **#23** (unten) – IDs dort eintragen und abhaken.

- `Collect` – kurzer „Plopp“ (Suche: *pop*, *plop*, *bubble pop*), < 0,5 s.
- `Sell` – Kasse/Münzen (Suche: *cash register*, *coins*, *purchase*).
- `Gem` – Glitzern/Chime (Suche: *sparkle*, *chime*, *magic*).
- `EggCrack` – Ei/Schale knackt (Suche: *egg crack*, *crack*, *shell*).
- `PhoneRing` – altes Telefonklingeln (Suche: *phone ring*, *telephone*); wird erst mit #13 (Lieferdienst) abgespielt.
- `Music_PizzeriaGarden` – fröhliche, leichte Hintergrundmusik zum Loopen (Suche: *happy*, *cheerful*, *ukulele*, *italian*), Lautstärke ist schon leise (0,25).
- Eingetragene IDs hier mit Namen notieren, committen (`Add sound IDs (#15)`), pushen.

**4. Test** (Rojo verbunden, **Play**, 1 Spieler):

- [x] Output ohne rote Fehler.
- [x] ~~Look: warmes Nachmittagslicht mit weichen Schatten, leichter Dunst am Horizont, Wolken am Himmel, kräftige Farben, Neon-Glut leuchtet leicht (Bloom). Nichts ist überstrahlt.~~ _(entfällt: seit #45 ein Tag-Look für alle Inseln)_
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

Tipp für schnelles Testen: In `src/shared/GameConfig.luau` vorübergehend `Mozzarella.value = 50000000` setzen (Rojo synchronisiert live), damit die Barrieren (310.000 / 23 Mio / 460 Mio, seit #41) und Shop 3 (bis 1,8 Mrd) schnell bezahlbar sind. **Danach zurücksetzen, nicht committen.**

Studio: Rojo verbinden, dann **Play** (1 Spieler):

- [x] Output ohne rote Fehler. Im Workspace gibt es `World5_Volcano`, `World6_CandyLand` und `World7_Space` (hinter den Eisbergen entlang −Z, Welt 7 bei ca. z = −1.200), in `Portals` zusätzlich `Portal_Volcano`, `Portal_CandyLand` und `Portal_Space`.
- [x] ~~Vulkan: dunkler Basalt-Boden, orange Barriere „🔒 Vulkan – 310.000 Münzen“ am Ende der Eisberge. Süßigkeitenland: rosa Boden, lila Barriere „🔒 Süßigkeitenland – 23.000.000 Münzen“. Weltraum: grauer Schiefer-Boden, mintgrüne Barriere „🔒 Weltraum – 460.000.000 Münzen“. Schilder lesbar.~~ _(entfällt: seit #32 Inseln mit Toren, Preise seit #57)_
- [ ] Reihenfolge: Süßigkeitenland vor dem Vulkan freischalten geht nicht („Erst die vorige Welt freischalten!“); mit zu wenig Münzen → „Nicht genug Münzen!“.
- [x] Nacheinander freischalten → Barriere jeweils lokal durchlässig, Münzen sinken um den Preis.
- [ ] Beläge (je ca. 60): Vulkan Chili (rot), Peperoni (rot-orange), Jalapeño (grün); Süßigkeitenland Schoko-Stücke (braun), Gummibärchen (pink, glasig), Marshmallow (weiß-rosa); Weltraum Mond-Käse (hellgelb), Sternen-Oliven (lila, leuchtend), Alien-Pilz (grün, leuchtend). Keine pinken Neon-Scheiben (= fehlende Optik).
- [ ] Einsammeln und am Ofen der Welt verkaufen; Werte ohne Pets: Chili 500, Peperoni 850, Jalapeño 1.250, Schoko 2.400, Gummibärchen 4.100, Marshmallow 6.000, Mond-Käse 11.500, Sternen-Oliven 20.000, Alien-Pilz 29.000.
- [x] ~~Ei-Sockel: Vulkan-Ei (100.000), Süßigkeiten-Ei (800.000), Weltraum-Ei (6.400.000) mit Vorschau (6 Pets, 0,5 % Mythisch: Lava-Titan, Karamell-Greif, Galaxie-Drache). Öffnen gibt ein Pet der Welt, es folgt nach dem Ausrüsten.~~ _(entfällt: Preise seit #57 neu, Vorschau seit #54 Panel)_
- [x] HUD: Große Beträge erscheinen kurz („1,5 Mio“, „1,2 Mrd“) und passen in die Münzanzeige; Toasts „+… Münzen“ ebenso.
- [ ] Portal-Menü listet alle 7 Welten (scrollbar), gesperrte grau mit Preis; nach dem Freischalten anwählbar, Teleport landet vor dem Portal der Welt.
- [x] **Shop 3** im Weltraum links vom Ei (ca. x = −72, z = −1.128): doppelt so groß wie der Shop in Welt 1, Schild „Riesiger Pizza-Shop – Upgrades“, steht frei (nicht im Ei-Sockel, nicht in der Belag-Fläche, nicht über dem Weltrand). _(Schild „Riesiger Pizza-Shop“ geprüft, Größe nicht nachgemessen)_
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

- [x] Output ohne rote Fehler. Links unter dem runden „Pets“-Knopf steht ein runder lila Knopf **„Tränke“**; rechts ist noch keine Trank-Anzeige zu sehen.
- [ ] Shop in Welt 1: Unter den Gem-Upgrades kommt der Abschnitt **„Gem-Tresen: Tränke (je 10 Min.)“** mit Münz-Trank (25 Gems), Glücks-Trank (30) und Speed-Trank (15), jeweils mit „Im Inventar: 0“. Mit zu wenig Gems: grauer Knopf, Antippen → „Nicht genug Gems!“, nichts ändert sich.
- [x] Trank kaufen → Gems sinken um den Preis, Status „Gekauft: Münz-Trank! – im Trank-Menü trinken“, „Im Inventar“ steigt. Zweimal kaufen → 2.
- [x] „Tränke“-Knopf → Menü „Meine Tränke“ mit 3 Karten (💰/🍀/⚡), Anzahl im Inventar, grüner Knopf „Trinken“ (grau, wenn 0). „X“ und erneutes Tippen auf „Tränke“ schließen. _(Untertitel „Gleiche Art nochmal trinken verlängert die…“ ist abgeschnitten)_
- [ ] **Münz-Trank** trinken → Toast „Münz-Trank wirkt 10 Minuten!“, rechts erscheint „💰 Münzen ×2  10:00“ und zählt sekündlich herunter. Pizza verkaufen → doppelte Münzen (mit Pets: Belagwert × Pet-Bonus × 2).
- [ ] Gleichen Trank nochmal trinken → Restzeit **verlängert** sich um 10 Min. (z. B. 9:30 → 19:30), sie startet nicht neu.
- [ ] **Speed-Trank** → man läuft sichtbar schneller (Tempo × 1,5, also 16 → 24, mit Tempo-Upgrade 19 → 28,5). Gilt auch nach Respawn (Reset). Nach Ablauf wieder normales Tempo.
- [x] **Glücks-Trank** → in jeder Ei-Vorschau steht „🍀 Glück!“ hinter dem Ei-Namen, die Chancen sind grün und seltene Pets höher (Garten-Ei: Pizza-Drache 0,5 % → ca. 1,2 %, Teig-Hamster 50 % → ca. 41 %). Nach Ablauf wieder die normalen Werte.
- [ ] Ablauf: Wenn die Zeit um ist, verschwindet die Anzeige rechts, Toast „… ist abgelaufen.“, die Wirkung endet (Verkaufswert/Tempo/Chancen wieder normal).
- [x] Mehrere Tränke gleichzeitig: alle drei trinken → drei Anzeigen rechts untereinander, jede mit eigener Zeit.
- [x] Speichern: Tränke im Inventar und laufende Restzeit bleiben nach Rejoin erhalten. Während man offline ist, läuft die Zeit **nicht** weiter (so gewollt). _(belegt: Rejoin 18./19.11.: Speed-Trank läuft weiter)_
- [ ] Server-Schutz (optional, Command Bar im Client): `game.ReplicatedStorage.Remotes.DrinkPotion:FireServer("Coins")` ohne Trank im Inventar → nichts passiert außer Meldung; `BuyPotion:FireServer("World1Shop", "Coins")` **außerhalb** des Shops → nichts passiert.

**Handy** (Device-Emulator, iPhone SE quer + Tablet):

- [x] „Tränke“-Knopf ist groß, gut antippbar, überdeckt weder den „Pets“-Knopf noch den Joystick. _(belegt: 18./19.11. Device-Emulator (`56`))_
- [x] ~~Trank-Menü passt auf den Bildschirm; „Trinken“-Knöpfe groß und per Antippen bedienbar.~~ _(entfällt: Prüfung zusammengefasst in #55)_
- [ ] Trank-Anzeigen rechts sind lesbar und liegen nicht über dem Sprung-Knopf (unten rechts).
- [ ] Shop-Menü: Trank-Kaufknöpfe lesbar und antippbar, Liste scrollt per Wischen bis zu den Tränken.

## Beobachtungen aus dem Studio-Test (16.11.2026, nicht behoben)

- [x] ~~UI-Überlappungen: Tutorial-Karte überdeckt Meldungen („+40 Münzen“) und die Ei-Vorschau; Shop-Menü überdeckt die Münz-/Gem-Anzeige; im Teleport-Menü wird der unterste Eintrag halb von der Pizza-Leiste verdeckt; der Freischalt-Knopf an der Barriere liegt genau auf dem Auto-Sammeln-Knopf.~~ _(entfällt: überholt durch #20 HUD-Raster, #53 und #54)_
- [x] Kamera: In Ofen-, Shop- und Ei-Nähe wird die Kamera an den Kopf gedrückt (Stationen stehen hinter der Startkamera, +Z). _(belegt: 18./19.11.: Kamera an allen Stationen frei (`48`))_
- [ ] Pets stellen sich am Ofen aufs Dach bzw. stecken halb in der Wand.
- [x] Sounds (#15 Schritt 3) noch offen: IDs müssen in Studio angehört und ausgewählt werden. _(belegt: IDs seit 17.11. eingetragen (#23); Anhören siehe #23 Schritt 3)_

## #14 Lieferdienst: Telefon, Auftrag, Lieferwagen

Vorher: `lune run test` → alle grün (u. a. `tests/Delivery.spec.luau` und `GameConfig delivery`).

Tipp für schnelles Testen: In `src/shared/GameConfig.luau` vorübergehend `delivery.callIntervalSeconds = 10` und `delivery.timeLimitSeconds = 40` setzen (Server neu starten). Das Telefon klingelt erst **nach dem Tutorial** – mit einem neuen Spielstand also zuerst das Tutorial durchspielen. **Danach zurücksetzen, nicht committen.**

Studio: Rojo verbinden, dann **Play** (1 Spieler):

- [x] Output ohne rote Fehler. Im Workspace gibt es den Ordner `Delivery` mit je einem `DeliveryPhone` und `DeliveryVan` pro Welt (Welt 1: Telefon bei ca. x = 78, z = 46, Lieferwagen bei x = 78, z = 14, rechts vom Portal). Beide stehen frei: nicht im Portal, nicht in Büschen/Bäumen, nicht in der Belag-Fläche. Schilder „📞 Telefon – Aufträge“ und „🚚 Lieferwagen – Bestellung abgeben“ lesbar.
- [x] Nach dem Tutorial klingelt das Telefon sofort: Toast „📞 Das Telefon klingelt!“, über **jedem** Telefon hüpft eine rote Blase „📞 RING!“ (auch von weit weg sichtbar), rechts im HUD steht „📞 Das Telefon klingelt! – Lauf zum Telefon und geh ran.“. Klingelton alle 3 s (nur wenn die Sound-ID aus #15 eingetragen ist).
- [x] Zum Telefon laufen → Panel „📞 Neuer Auftrag!“ mit z. B. „1× Pilz / 1× Salami“, „Belohnung: bis zu …“ und „Zeit: 3:00 – je schneller, desto mehr!“. Weglaufen schließt das Panel, das Telefon klingelt weiter.
- [x] **Ablehnen** → Toast „Auftrag abgelehnt.“, Blasen weg, nach 2,5 Min. (bzw. Tipp-Wert) klingelt es wieder. _(belegt: 21.11.: nach Ablehnen klingelt es nach der Pause wieder)_
- [x] **Annehmen** → Toast „Auftrag angenommen! …“, über der Hand-Pizza schwebt „🧾 Bestellung“ (Bestell-Pizza), rechts unter den Trank-Anzeigen steht die Auftragskarte „🧾 Auftrag ⏱ 3:00“ mit den Belägen („• 0/1 Salami“), der Belohnung „wenn jetzt geliefert“ und „Schnell = mehr Belohnung!“. Der Timer zählt sekündlich herunter, unter 0:30 rot.
- [x] Bestellte Beläge sammeln → Zeilen werden grün mit „✓ 1/1“; sind alle da: „Fertig! Ab zum 🚚 Lieferwagen.“.
- [x] Falschen Belag dazu sammeln und zum Lieferwagen → Toast „Falsche Beläge! Überzählige am Ofen verkaufen.“, nichts passiert. Dann zum Ofen: **nur die überzähligen** Beläge werden verkauft, die bestellten bleiben auf der Pizza. Nur bestellte Beläge auf der Pizza → der Ofen verkauft nichts.
- [x] Richtige Pizza zum Lieferwagen (in die Zone neben dem Wagen, Seite zur Belag-Fläche) → Toast „Geliefert! +… Münzen“ (bzw. Gems / Trank), Kassen-Sound, Pizza leer, Karte und „🧾 Bestellung“ verschwinden. Münz-Belohnung ≈ 3–4,5 × Belagwert × Pet-Bonus (sofort geliefert mehr als kurz vor Ablauf). _(2× Salami → +8 Münzen)_
- [ ] Gem-Auftrag: 3–10 Gems. Trank-Auftrag: Trank landet im Trank-Menü (2 Stück, wenn in der ersten Hälfte der Zeit geliefert).
- [ ] Zeit ablaufen lassen → Toast „Zeit um – der Auftrag ist verfallen.“, Karte und Ticket weg, Beläge bleiben auf der Pizza (am Ofen verkaufbar), nach dem Abstand klingelt es wieder.
- [ ] Ohne Auftrag zum Lieferwagen → Toast „Kein Auftrag – geh ans Telefon!“.
- [ ] Fortschritt: Mit freigeschaltetem Bauernhof (Münz-Tipp aus #11) und größerer Pizza bestellt das Telefon Bauernhof-Beläge und mehr Stück (höchstens Pizza-Platz). Telefon und Lieferwagen funktionieren in **jeder** Welt gleich.
- [x] Speichern: Angenommenen Auftrag haben, rausgehen, innerhalb der Zeit wieder rein → Auftrag ist noch da, Timer läuft weiter (die Zeit läuft auch offline, Server-Uhr). Nach Ablauf wieder rein → Auftrag weg. _(belegt: Rejoin 18./19.11.: Auftrag läuft in Echtzeit weiter)_
- [ ] Server-Schutz (Command Bar im Client): `game.ReplicatedStorage.Remotes.AnswerPhone:FireServer(true)` **weg vom Telefon** → nichts passiert.

**Mehrspieler** (2 Spieler):

- [ ] Das Klingeln ist pro Spieler: Blasen und Auftragskarte sieht nur der Spieler, dessen Telefon klingelt; das „🧾 Bestellung“-Ticket über der Pizza sehen beide.

**Handy** (Device-Emulator, iPhone SE quer + Tablet):

- [x] ~~Telefon-Panel passt auf den Bildschirm, „Annehmen“/„Ablehnen“ sind groß und per Antippen bedienbar.~~ _(entfällt: Prüfung zusammengefasst in #55)_
- [ ] Auftragskarte rechts ist lesbar, überdeckt weder Trank-Anzeigen (bei 3 aktiven Tränken) noch den Sprung-Knopf unten rechts. Falls doch: `CARD_TOP` in `src/client/DeliveryMenu.luau` anpassen.

## #16 Pet-Modelle und Welt-Optik 2–7

Vorher: `git pull`, `lune run test` → alle grün. Vorschau: Pets pro Ei in `assets/previews/pets/<Ei>.png` (z. B. `GardenEgg.png`), einzeln `assets/previews/pets/<PetId>.png`; Deko pro Welt in `assets/previews/World_<Welt>.png`.

Ohne Import läuft alles weiter: Pets bleiben farbige Kugeln mit Augen, die Bilder in Ei-Vorschau/Pet-Menü bleiben farbige Punkte, die Deko der Welten 2–7 besteht aus einfachen Ersatzteilen (Kugeln/Zylinder). Wege, Licht, Atmosphäre, Lava-Pools und das Meer am Strand sind schon ohne Import da.

**1. Pet-Modelle importieren** (42 Dateien in `assets/models/pets/`):

- [x] In **ReplicatedStorage → GameAssets → Models** (aus #15) einen **Folder** `Pets` anlegen.
- [x] **Home → Import 3D** → im Dateidialog in `assets/models/pets/` **alle 42 `.fbx` auf einmal markieren** (Strg+A) → Öffnen. Im Import-Fenster: *Rig Type* = **No Rig**, *Insert Using Scene Position* = aus, sonst Standard → **Import**. (Lässt Studio nur eine Datei zu: einzeln importieren, Reihenfolge egal.) _(Dateidialog lässt kein Strg+A zu → in 5 Gruppen über das Namensfeld)_
- [x] Die importierten Modelle erscheinen im Workspace, jeweils als **Model** mit dem Dateinamen (z. B. `DoughHamster`, `PizzaDragon`) und MeshParts namens `Pet_F2D49B`, `Pet_FF7A1A_Neon` … (Endungen wie `.001` sind in Ordnung). Alle markieren und in den Ordner `Models/Pets` ziehen. **Namen nicht ändern** – sie müssen exakt den Pet-IDs entsprechen (Liste: Dateinamen in `assets/models/pets/`). Größe, Farbe, Position egal; das Spiel skaliert und färbt nach den Teilnamen.
- [x] Kontrolle in der Command Bar: `print(#game.ReplicatedStorage.GameAssets.Models.Pets:GetChildren())` → **42**.

**2. Deko-Modelle der Welten 2–7 importieren** (20 Dateien in `assets/models/`):

- [x] In **ReplicatedStorage → GameAssets → Models** einen **Folder** `Deco` anlegen.
- [x] Wie oben mit **Import 3D** (mehrere Dateien markieren) diese Dateien importieren und nach `Models/Deco` ziehen, Namen = Dateiname:
  | Welt | Dateien |
  | --- | --- |
  | Bauernhof | `Barn.fbx`, `HayBale.fbx`, `Sunflower.fbx`, `Fence.fbx` (+ `Tree` aus #15) |
  | Strand | `PalmTree.fbx`, `BeachUmbrella.fbx`, `BeachRock.fbx` |
  | Eisberge | `SnowPine.fbx`, `IceCrystal.fbx`, `Snowman.fbx` |
  | Vulkan | `LavaMountain.fbx`, `LavaRock.fbx`, `DeadTree.fbx` |
  | Süßigkeitenland | `Lollipop.fbx`, `CandyCane.fbx`, `Cupcake.fbx` |
  | Weltraum | `MoonRock.fbx`, `Planet.fbx`, `SpaceCrystal.fbx`, `Rocket.fbx` |
- [x] Kontrolle: `print(#game.ReplicatedStorage.GameAssets.Models.Deco:GetChildren())` → **20**.
- [x] Place speichern und **File → Publish to Roblox** (die Meshes gehören zum Place).

**3. Musik der Welten 2–7** (IDs in `src/client/Sounds.luau`, starten leer = stumm; aus der Cloud war roblox.com gesperrt, deshalb keine geprüften IDs). **View → Toolbox → Creator Store → Audio**, Creator-Filter **Roblox**, Kategorie Musik, anhören, Rechtsklick → **Copy Asset ID**, als Zahl eintragen, Lautstärke ist schon leise (0,25):

> Zusammengefasst und mit genauer Anleitung in **#23** (unten) – IDs dort eintragen und abhaken.

- `Music_Farm` – fröhlich-ländlich (Suche: *country*, *banjo*, *farm*, *folk*).
- `Music_Beach` – sommerlich (Suche: *tropical*, *beach*, *ukulele*, *reggae*).
- `Music_Icebergs` – ruhig-funkelnd (Suche: *winter*, *snow*, *bells*, *calm*).
- `Music_Volcano` – spannend, Trommeln (Suche: *volcano*, *drums*, *adventure*, *tribal*).
- `Music_CandyLand` – verspielt-süß (Suche: *candy*, *cute*, *bubbly*, *playful*).
- `Music_Space` – sphärisch (Suche: *space*, *synth*, *ambient*, *cosmic*).
- Eingetragene IDs hier mit Namen notieren, committen (`Add world music IDs (#16)`), pushen.

**4. Test Pets** (Rojo verbunden, **Play**, 1 Spieler; Münz-Tipp aus #11 zum schnellen Öffnen):

- [x] Output ohne rote Fehler.
- [x] Ei-Vorschau (Garten-Ei): jede Zeile zeigt links das kleine **3D-Pet** (Teig-Hamster mit Kochmütze, Basilikum-Hase, Tomaten-Katze …) statt eines Punkts. Lesbar, nichts abgeschnitten.
- [x] Ei öffnen: Die Pet-Karte zeigt das 3D-Pet vor dem Kreis in Seltenheitsfarbe.
- [ ] Pet-Menü: Jede Karte zeigt das 3D-Pet im runden Feld. Menü mit vielen Pets (z. B. 30+) öffnet ohne spürbares Ruckeln (ViewportFrames). Falls doch: hier notieren.
- [ ] Ausgerüstete Pets laufen als Modell hinter dem Spieler her, **mit dem Gesicht in Laufrichtung**, Füße knapp über dem Boden, Namensschild über dem Kopf. Zeigen sie nach hinten/zur Seite: in `src/shared/ModelLibrary.luau` `PET_YAW` (jetzt 180) auf 0/90/270 ändern. Schweben sie zu hoch/stecken im Boden: `MODEL_LIFT` in `src/server/PetService.luau` anpassen.
- [ ] Seltene Pets sind etwas größer (Mythisch ≈ 4 Studs) als gewöhnliche (≈ 2,8 Studs); nichts überdeckt die Spielfigur.
- [ ] Neon-Teile leuchten (Lava-Echse, Galaxie-Drache, Sternen-Katze), Glas ist durchsichtig (Raketen-Hund-Helm, Gummi-Wurm), Goldener Hahn glänzt.
- [ ] Je ein Pet pro Ei ansehen (Bauernhof bis Weltraum): Farben wie in den Vorschau-Renders.
- [ ] **Mehrspieler** (2 Spieler): B sieht A's Pets als Modelle hinter A herlaufen.

**5. Test Welten 2–7** (Münz-Tipp aus #11; mit dem Portal schnell wechseln):

- [x] ~~Beim Betreten jeder Welt wechseln Licht, Dunst und Musik (sobald IDs eingetragen) innerhalb ~1 s:~~ _(entfällt: seit #45 ein Licht-Look, Deko seit #31/#32 Inseln)_
  - Bauernhof: goldener Morgen, warmer Dunst. Scheune (Ecke hinten links), Heuballen, Sonnenblumen, Zäune, Bäume, Erdweg vor den Stationen.
  - Strand: helle Mittagssonne, blaue Luft. Palmen, Sonnenschirme, Felsen, Holzsteg vor den Stationen, Meer links außerhalb der Welt.
  - Eisberge: kühles bläuliches Licht, viel weißer Dunst. Verschneite Tannen, Eiskristalle (zwei große in den hinteren Ecken), Schneemänner, Eisweg.
  - Vulkan: roter Abendhimmel, rauchiger Dunst. Großer Vulkan mit Lava (hinten links), Lavafelsen, tote Bäume, leuchtende Lava-Pools.
  - Süßigkeitenland: rosa Pastell-Licht, rosa Wolken. Lollis, Zuckerstangen, Cupcakes (ein riesiger hinten links), Schoko-Weg.
  - Weltraum: Nacht mit Sternen und Mond, lila Licht, leuchtende Kristalle, Mondfelsen, Rakete (hinten links), großer Planet am Himmel. Trotz Nacht ist alles gut erkennbar (sonst `ambient`/`outdoorAmbient` in `src/shared/WorldLooks.luau` erhöhen).
- [x] Keine Deko steht in der Belag-Fläche, im Ofen, Ei, Portal, Shop (Welt 4 und 7 sind die Shops größer!), Telefon oder Lieferwagen, und nichts versperrt die Barriere zur nächsten Welt. Große Deko (Bäume, Scheune, Vulkan, Rakete) ist fest, kleine kann man durchlaufen. _(belegt: 18./19.11.: Stationen und Tore auf allen Inseln frei (`38`–`48`))_
- [x] ~~Nichts ist überstrahlt (Vulkan/Weltraum haben stärkeres Bloom); Bildrate bleibt flüssig.~~ _(entfällt: seit #45 ein Look ohne Welt-Bloom; Bildrate siehe Release-Checkliste)_
- [x] ~~Zurück in Welt 1 → wieder das warme Nachmittagslicht aus #15.~~ _(entfällt: seit #45 ein Licht-Look)_

**Handy** (Device-Emulator, iPhone SE quer + Tablet):

- [x] ~~Ei-Vorschau: 3D-Pets sind auch klein erkennbar; Pet-Menü-Karten bleiben gut antippbar (das 3D-Bild fängt keine Eingaben ab – Antippen rüstet aus/ab).~~ _(entfällt: seit #54 Panel statt BillboardGui)_
- [ ] Bildrate in Vulkan und Weltraum (Licht-Effekte) bleibt flüssig; falls nicht, hier notieren.

## #23 Schnellerer Start und Sounds vorbereiten

**1. Schnellerer Start** (Rojo verbunden, **Play**, 1 Spieler, als **neuer Spieler** – Spielstand löschen oder API-Zugriff aus, siehe #17):

- [x] Output ohne rote Fehler. _(belegt: Output in allen Tests ohne Spiel-Fehler)_
- [x] Shop in Welt 1: Pizza-Platz Stufe 1 kostet **12 Münzen** (Knopf „12 Münzen“), Stufe 2 weiterhin 120. _(belegt: 18./19.11.: Stufe 1 kostet 12 (Stufe 2 seit #57: 26))_
- [ ] Garten-Ei kostet weiterhin **25 Münzen** („1 öffnen – 25 Münzen“).
- [x] Tutorial durchspielen: 2 Beläge sammeln → verkaufen → Schritt 3/4 „Kauf im Shop dein erstes Upgrade!“. Nach **3–4 Runden** (je 2 Beläge) reicht das Geld für Pizza-Platz → Kauf klappt, Pizza fasst 3 Beläge, Tutorial springt auf „Schritt 4/4: Öffne am Ei dein erstes Pet!“, Pfeil zeigt zum Ei. _(belegt: 18./19.11.: nach 4 Runden Kauf, Schritt 4/4)_
- [x] Mit weniger als 12 Münzen kaufen → „Nicht genug Münzen!“, Schritt bleibt 3/4. _(belegt: 18./19.11.: mit 2 Münzen „Nicht genug Münzen!“, bleibt 3/4)_

**2. Sound-IDs eintragen** (wird in **A7** ausgeführt; IDs in `src/client/Sounds.luau`, starten leer = stumm). Die Suchbegriffe stehen auch im Code als `search` bei jedem Eintrag.

So geht's für jeden Schlüssel der Tabelle:

1. Studio: **View → Toolbox**, oben **Creator Store**, Kategorie **Audio** (bei Musik zusätzlich den Typ **Music**, bei Effekten **Sound Effects** wählen).
2. Suchbegriff aus der Tabelle eingeben, dann über das Filter-Symbol (Trichter) bei **Creator** „Roblox“ eintragen und bestätigen. Nur Sounds dieses Creators nehmen, die bleiben öffentlich und funktionieren in jedem Spiel.
3. Mit dem ▶-Knopf in der Liste anhören. Passt der Sound zur Beschreibung (und zur Länge), dann **Rechtsklick → Copy Asset ID**.
4. **Nicht in Studio**, sondern in der Datei `src/client/Sounds.luau` (Editor, Rojo synchronisiert) beim Schlüssel `id = ""` durch die Zahl ersetzen, z. B. `id = "1234567890"` (nur Ziffern, ohne `rbxassetid://`). In Studio geänderter Code würde von Rojo überschrieben.
5. Speichern → Rojo synchronisiert → **Play** und prüfen (siehe 3.). Zu laut/leise: `volume` im selben Eintrag anpassen.
6. Gewählten Sound (Name + ID) unten in der Tabelle in der Spalte „Gewählt“ notieren und die Zeile abhaken.

| Schlüssel | Wann | Gesucht wird | Suchbegriffe | Gewählt (Name, ID) |
| --- | --- | --- | --- | --- |
| `Collect` | Belag landet auf der Pizza | kurzer, weicher „Plopp“, **< 0,5 s** | *pop*, *plop*, *bubble pop*, *click* || Suction Pop 4 (Pro Sound Effects), 9119669065 |
| `Sell` | Verkauf am Ofen, Lieferung | Kasse / Münzen klimpern, ≈ 1 s | *cash register*, *coins*, *purchase*, *ka-ching* || Cash Register 1, 9113728625 |
| `Gem` | Gem-Belag, Gem-Belohnung | helles Glitzern / Chime | *sparkle*, *chime*, *magic*, *twinkle* || Magic Glows Soft Clusters Of Chiming Hits 1, 9116394545 |
| `EggCrack` | Ei-Animation, Schale bricht | Ei-/Schale-Knacken, kurz | *egg crack*, *crack*, *shell*, *break* || Crack Egg Crunchy 11, 9113959343 |
| `PhoneRing` | Telefon klingelt (alle 3 s) | altes Telefonklingeln, **≤ 3 s** | *phone ring*, *telephone*, *old phone*, *ringing* || Phone Ring 1920S Hand Crank Rattly Buzz 2, 9117304246 |
| `Music_PizzeriaGarden` | Welt 1 | fröhlich, leicht, loopbar | *happy*, *cheerful*, *ukulele*, *italian* || Italian Accordion (APM), 1839408249 |
| `Music_Farm` | Welt 2 | fröhlich-ländlich | *country*, *banjo*, *farm*, *folk* || Country Dew – No Banjo (APM), 9043699640 |
| `Music_Beach` | Welt 3 | sommerlich | *tropical*, *beach*, *ukulele*, *reggae* || Maui Beach (APM), 9043828544 |
| `Music_Icebergs` | Welt 4 | ruhig-funkelnd | *winter*, *snow*, *bells*, *calm* || Winter Bells (APM), 9041824482 |
| `Music_Volcano` | Welt 5 | spannend, Trommeln | *volcano*, *drums*, *adventure*, *tribal* || Jungle Drums (b) (APM), 1839999913 |
| `Music_CandyLand` | Welt 6 | verspielt-süß | *candy*, *cute*, *bubbly*, *playful* || Bright And Bubbly (APM), 1846441369 |
| `Music_Space` | Welt 7 | sphärisch | *space*, *synth*, *ambient*, *cosmic* || Cosmic Dust (APM), 1844477817 |

- [x] `Collect` eingetragen
- [x] `Sell` eingetragen
- [x] `Gem` eingetragen
- [x] `EggCrack` eingetragen
- [x] `PhoneRing` eingetragen
- [x] `Music_PizzeriaGarden` eingetragen
- [x] `Music_Farm` eingetragen
- [x] `Music_Beach` eingetragen
- [x] `Music_Icebergs` eingetragen
- [x] `Music_Volcano` eingetragen
- [x] `Music_CandyLand` eingetragen
- [x] `Music_Space` eingetragen
- [x] Commit `Add sound IDs (#23)`, pushen. _(belegt: Commit 395e70e)_

**3. Sound-Test** (nach Schritt 2, **Play**, 1 Spieler):

- [x] Output ohne Fehler wie „Failed to load sound“ (sonst ID falsch oder nicht öffentlich → anderen Sound wählen).
- [ ] Plopp beim Sammeln (nicht beim Beitreten, nicht als Dauerfeuer beim Auto-Sammeln), Kasse beim Verkaufen und Liefern, Glitzern bei Gems, Knacken in der Ei-Animation, Klingeln am Telefon.
- [ ] Musik startet in Welt 1, läuft in Schleife und wechselt beim Betreten jeder anderen Welt (auch per Portal) innerhalb ~1 s. Lautstärke ist leise im Hintergrund, Effekte bleiben gut hörbar.

## #25 Respawn in der aktuellen Welt

Vorher: `lune run test` → muss `0 failed` melden (Respawn-Tests in `tests/Respawn.spec.luau`).

Studio: Rojo verbinden, dann **Play** (1 Spieler). Für schnelles Testen Münzen per Command Bar geben (Server-Seite) oder einen Spielstand mit freigeschalteten Welten nutzen. Das Attribut `LastWorldId` am Player (Explorer → Players → Name → Attributes) zeigt die gemerkte Welt.

- [ ] Output ohne rote Fehler; Neuer Spieler: `LastWorldId` wird nach dem Start `PizzeriaGarden` (Figur steht in Welt 1).
- [ ] Zu Fuß über die (freigeschaltete) Barriere in Welt 2 laufen → `LastWorldId` = `Farm`. Zurück in Welt 1 → `PizzeriaGarden`.
- [x] Per Portal nach Welt 3 teleportieren → `LastWorldId` = `Beach` sofort nach dem Teleport.
- [x] **Tod in Welt 3** (Esc → Reset Character) → Figur erscheint in Welt 3 auf dem Weg zwischen Ei und Ofen, Blick zum Belagfeld; Pizza ist wieder in der Hand. Kein kurzes Aufblitzen/Hängenbleiben in Welt 1, das stört (ein Frame am Welt-1-Spawn ist okay). _(belegt: 18./19.11.: Tod in Welt 7 → Respawn in Welt 7)_
- [ ] Tod in Welt 1 → normaler gelber Spawn in Welt 1.
- [x] **Rejoin**: in Welt 3 stehen, Stop, erneut Play (mit API-Zugriff, damit gespeichert wird) → Start in Welt 3. _(belegt: Rejoin 18./19.11.: Start in der zuletzt besuchten Welt)_
- [ ] **Gesperrte Welt**: In der Command Bar (Server) für den Spieler `LastWorldId` im Spielstand auf eine nicht freigeschaltete Welt setzen bzw. mit einem Spielstand ohne diese Welt joinen → Start am normalen Spawn in Welt 1, keine Fehlermeldung.
- [ ] Alter Spielstand (vor #25, ohne `lastWorldId`) lädt ohne Fehler und startet in Welt 1.
- [x] Barriere-Schutz: In einer gesperrten Welt (z. B. per Command Bar hineingesetzt) wird man wie bisher zurückgesetzt und `LastWorldId` ändert sich **nicht** auf die gesperrte Welt.
- [ ] **Mehrspieler** (2 Spieler): A stirbt in Welt 2, B in Welt 1 → jeder erscheint in seiner eigenen Welt.

## #34 Session-Lock beim Speichern

Vorher: `lune run test` → alle grün (inkl. neue Lock-Tests in `tests/SaveData.spec.luau`). Studio-Zugriff auf API-Dienste muss an sein (siehe #3).

Was neu ist: Der gespeicherte Stand trägt ein Feld `lock = { serverId, time }`. Laden belegt den Stand per `UpdateAsync`, Auto-Speichern (alle 120 s) erneuert den Lock, Verlassen/Herunterfahren gibt ihn frei. Ist er von einem anderen Server frisch belegt (< 300 s), wartet das Laden (alle 5 s, max. 60 s) und kickt dann mit Hinweis. Zahlen: `GameConfig.save`.

Normalbetrieb (1 Spieler, Rojo verbunden):

- [x] **Play** mit einem alten Spielstand von vor diesem Ticket: Münzen, Pets, Tutorial-Schritt sind wie vorher, Output ohne `[Save]`-Warnungen (bestehende Spielstände laden weiter). _(belegt: 17.11.: alter Spielstand ohne `[Save]`-Warnungen)_
- [x] Münzen verdienen, **Stop**, erneut **Play**: Stand ist erhalten, **keine** Meldung `noch von einem anderen Server belegt` (Stop hat den Lock freigegeben). _(belegt: Stop/Play in allen Tests 17.–21.11. ohne Lock-Warnung)_
- [ ] Mit **Test → Clients and Servers** (1 Spieler) das Client-Fenster schließen, Server weiterlaufen lassen, dann mit **Test → Clients and Servers** neu starten: lädt sofort, ohne Warten.

Verwaister Lock (Server stirbt ohne Freigabe):

- [ ] Play, Münzen verdienen, > 2 Minuten warten (Auto-Speichern), dann Studio-Prozess **hart beenden** (Task-Manager). Studio neu öffnen, **Play** innerhalb von 5 Minuten: Output zeigt mehrmals `[Save] Spielstand von … ist noch von einem anderen Server belegt, warte …`, nach ca. 60 s wird man mit „Dein Spielstand wird gerade noch auf einem anderen Server gespeichert …“ gekickt. Es wurde **nichts** überschrieben.
- [ ] Nach Ablauf von 5 Minuten seit dem letzten Auto-Speichern erneut **Play**: Der Stand lädt (Münzen von vor dem Absturz), keine Warnung mehr.

Optional (veröffentlichtes Spiel, 2 Server): Spieler wechselt per Teleport/Neubeitritt schnell den Server → auf dem neuen Server ist der zuletzt gespielte Stand da, nie ein älterer. Im Server-Log des neuen Servers ggf. kurz `… belegt, warte …`, dann normales Laden.

Fehler gefunden? Beheben, `lune run test` erneut ausführen, hier abhaken, committen, pushen.

## #24 Salami-Modell und hellerer Vulkan

Vorher: `git pull`, `lune run test` → alle grün (u. a. `WorldLooks` „keeps the volcano readable / fiery“). Vorschau: `assets/previews/Salami.png`, auf Pizza und Boden: `assets/previews/SalamiCheck.png`, Vulkan-Deko: `assets/previews/World_Volcano.png`.

Ohne Neu-Import läuft alles weiter: Die alte Salami wird schon in den neuen Farben (weinrot, cremefarbene Fettaugen) eingefärbt, weil das Spiel nach Teilnamen färbt. Vulkan-Licht, hellerer Boden/Felsen und die zusätzlichen Lava-Akzente brauchen keinen Import.

**1. Neue Salami importieren** (`assets/models/Salami.fbx`, Teile `Casing`, `Meat`, `Fat`):

- [x] In **ReplicatedStorage → GameAssets → Models** das alte Model `Salami` löschen.
- [x] **Home → Import 3D** → `assets/models/Salami.fbx` → *Rig Type* = **No Rig**, *Insert Using Scene Position* = aus → **Import**. Das neue Model nach `GameAssets/Models` ziehen, Name exakt `Salami` (Teile dürfen `Meat.001` usw. heißen).
- [x] Place speichern und **File → Publish to Roblox**.

**2. Test** (Rojo verbunden, **Play**, 1 Spieler):

- [x] Output ohne rote Fehler. _(belegt: 17.11.: Salami neu importiert, Output ohne Fehler)_
- [ ] Welt 1: Salami ist eine flache, weinrote Scheibe mit kleinen, unregelmäßigen cremefarbenen Fettstücken und dünnem dunklem Rand – kein Fliegenpilz mehr. Auf dem grünen Boden gut zu sehen und anklickbar.
- [ ] Salami sammeln: Auf der Hand-Pizza hebt sie sich klar von Soße (hellrot) und Käse (gelb) ab.
- [x] ~~Vulkan (Münz-Tipp aus #11): warmes, orangefarbenes Licht von oben, hellerer Basalt-Boden, nur leichter orangefarbener Dunst – Stationen, Schilder, Beläge (Chili, Peperoni, Jalapeño) und Wege gut erkennbar, auch in der Ferne. Die feurige Stimmung bleibt (orange Wolken, Bloom auf der Lava).~~ _(entfällt: seit #45 ein Licht-Look, Vulkan seit #47 neu)_
- [x] ~~Lava-Akzente: 8 leuchtende Lava-Pools und 6 Lava-Risse rund um das Belagfeld, mit warmem Licht. Keiner liegt im Belagfeld, vor Ofen/Shop/Ei/Portal, bei Telefon/Lieferwagen oder im großen Vulkan (hinten links).~~ _(entfällt: seit #32 Vulkan-Insel neu gebaut)_
- [x] ~~Nichts ist überstrahlt. Falls zu hell/zu dunkel: in `src/shared/WorldLooks.luau` (Eintrag `Volcano`) `brightness` bzw. `ambient`/`outdoorAmbient` anpassen und hier notieren.~~ _(entfällt: seit #45 ein Licht-Look)_
- [x] ~~Bildrate im Vulkan bleibt flüssig (14 zusätzliche Lichter); auf dem Handy-Emulator kurz prüfen.~~ _(entfällt: seit #32/#47 neu; Bildrate siehe Release-Checkliste)_

## #22 Kamera und Welt-Störungen

Betrifft auch die Beobachtungen „Kamera“ und „Pets am Ofen“ oben. Play in Welt 1, danach mit dem Portal in eine spätere Welt.

**Kamera (Invisicam):**

- [x] Output/Explorer: `StarterPlayer.DevCameraOcclusionMode` und `Players.<Spieler>.DevCameraOcclusionMode` stehen im Play auf `Invisicam`.
- [x] Rückwärts an Ofen, Shop, Ei-Stand und Telefon heranlaufen (Station zwischen Kamera und Figur): Die Kamera bleibt auf Abstand, die Station wird halb durchsichtig statt heranzuzoomen. In Welt 1 und in mindestens einer späteren Welt prüfen (Welt 7: großer Shop). _(belegt: 18./19.11.: Kamera an allen Stationen frei (`48`))_

**Pets am Ofen:**

- [ ] Mit 3+ ausgerüsteten Pets rückwärts und seitlich an den Ofen laufen und stehen bleiben: Kein Pet steht auf dem Ofendach, auf dem Shop-Tresen oder auf dem Ei-Stand, keines steckt in einer Wand. Die Pets bleiben vor der Wand auf dem Boden.
- [ ] Auf dem normalen Weg, über Brücken/Barrieren und auf der Belag-Fläche folgen die Pets wie bisher (kein Ruckeln, kein Versinken). Beläge am Boden bremsen die Pets nicht aus.
- [ ] Falls Pets an kleinen Stufen hängen bleiben: `MAX_STEP` in `src/client/PetFollow.luau` erhöhen (jetzt 1,5).

**Namensschild und Ei-Vorschau:**

- [x] ~~Mit ausgerüsteten Pets zum Ei laufen: Die Vorschau liegt über allem, kein Pet-Namensschild verdeckt „1 öffnen“ (bzw. „3 öffnen“). Namensschilder der Pets in Ei-Nähe sind ausgeblendet und erscheinen wieder, sobald man weggeht.~~ _(entfällt: seit #54 Panel; Namensschilder am Ei ausgeblendet (#54 geprüft))_

**Ferne Schilder:**

- [ ] In Welt 1 am Spawn und am Ende Richtung Welt 2 umschauen (auch weit herausgezoomt): Keine Schilder anderer Welten (z. B. „Riesiger Pizza-Shop – Upgrades“, „Ofen (Bauernhof) …“) am Himmel oder Horizont.
- [ ] Schilder in der Nähe (Ofen, Shop, Telefon, Lieferwagen, Portal, Preisschild an der Barriere) erscheinen beim Herangehen wie bisher (ab ca. 150 Studs), Pizza-Zähler und Pet-Namen ab ca. 60 Studs.
- [ ] Preisschild einer freigeschalteten Barriere bleibt verborgen, das einer gesperrten erscheint.
- [x] Zur Ursache: Im Play (Client) in der Befehlsleiste `for _,b in workspace:GetDescendants() do if b:IsA("BillboardGui") and b.MaxDistance == 0 then print(b:GetFullName()) end end` ausführen und Treffer hier notieren (erwartet: keine). So lässt sich klären, ob ein Schild ohne `MaxDistance` die Quelle war oder die Engine `MaxDistance` nicht anwendet.

## #28 Modelle: Telefon, Lieferwagen, Portal, Shop-Stand

Vorher: `git pull`, `lune run test` → alle grün. Vorschau: `assets/previews/Telephone.png`, `DeliveryVan.png`, `PortalArch.png`, `PizzaStand.png` und alle vier nebeneinander in `assets/previews/World_Stations.png`.

Ohne Import läuft alles wie bisher mit den alten Bauteil-Platzhaltern. Mit Import liegen die Platzhalter unsichtbar unter dem Modell (Kollision, Telefon-Klingeln, Schilder und Zonen bleiben gleich).

**1. Modelle importieren** (4 Dateien in `assets/models/`):

- [x] In **ReplicatedStorage → GameAssets → Models** einen **Folder** `Stations` anlegen.
- [x] **Home → Import 3D** → `Telephone.fbx`, `DeliveryVan.fbx`, `PortalArch.fbx`, `PizzaStand.fbx` (gleiche Einstellungen wie bei #16: *Rig Type* = **No Rig**, *Insert Using Scene Position* = aus). Die Modelle in `Models/Stations` ziehen. **Namen nicht ändern** (= Dateiname ohne `.fbx`). Größe, Farbe und Position sind egal, das Spiel skaliert und färbt nach den Teilnamen.
- [x] Kontrolle in der Command Bar: `print(#game.ReplicatedStorage.GameAssets.Models.Stations:GetChildren())` → **4**.
- [x] Place speichern und **File → Publish to Roblox**.

**2. Test** (Rojo verbunden, **Play**, 1 Spieler; Münz-Tipp aus #11, mit dem Portal durch alle Welten):

- [x] Output ohne rote Fehler. _(belegt: Output in allen Tests ohne Spiel-Fehler)_
- [ ] **Telefon** (rechter Rand, neben dem Lieferwagen): altes rotes Wählscheiben-Telefon auf Holzständer, **Wählscheibe zeigt zur Belag-Fläche** (−X). Schild „📞 Telefon – Aufträge“ sitzt über dem Telefon. Klingeln: „📞 RING!“-Blase erscheint über dem Telefon, Auftrag annehmen funktioniert wie bisher.
- [x] **Lieferwagen**: weiß-roter Transporter mit großer Pizza-Box auf dem Dach, **Führerhaus zeigt nach vorne** (−Z, wie der alte Platzhalter). Steht auf dem Boden (Räder nicht im Boden, nicht schwebend). Abgeben an der Seite zur Belag-Fläche funktioniert wie bisher.
- [x] **Portal**: runder Steinbogen mit goldenem Schlussstein auf Steinsockel, die Fläche leuchtet **in der Farbe der Welt** (Garten orange, Bauernhof gelb, Strand türkis, Eisberge hellblau, Vulkan rot, Süßigkeitenland pink, Weltraum lila), Funken in heller Weltfarbe. Hineinlaufen öffnet das Portal-Menü, Ankunft vor dem Portal wie bisher.
- [ ] **Shop-Stand** (Welt 1 sowie die größeren Shops in Welt 4 und 7): Pizzeria-Stand mit rot-weißer Markise mit Bogenkante, Schild mit Pizza, kleiner Ofen und Pizza-Kartons auf der Theke. Die Pizza aus #15 liegt auf der Theke (nicht schwebend, nicht in der Theke). Shop-Menü öffnet in der grünen Zone vor der Theke wie bisher.
- [ ] Zeigt ein Modell in die falsche Richtung: in `src/shared/ModelLibrary.luau` unter `YAW` den Wert für `Telephone`/`DeliveryVan`/`PortalArch`/`PizzaStand` (jetzt 180) auf 0/90/270 ändern. Ist ein Modell zu groß/klein: Breite in `DeliveryService` (`PHONE_MODEL_WIDTH`, `VAN_MODEL_LENGTH`), `PortalService` (`ARCH_MODEL_WIDTH`) bzw. `ShopService` (`STAND_MODEL_WIDTH`) anpassen.
- [ ] Unsichtbare Platzhalter stören nicht: Man bleibt nirgends an unsichtbaren Kanten hängen, die nicht zum Modell passen (falls doch: Stelle hier notieren).
- [ ] **Handy** (Device-Emulator): Bildrate an den Stationen bleibt flüssig.

## #20 A1 HUD-Raster ohne Überlappungen

Alle Positionen kommen jetzt aus `src/shared/HudLayout.luau` (Zonen, siehe `docs/ui-style.md` → „HUD-Raster“). Auf dem PC und im Device-Emulator prüfen; falls etwas nicht passt, nur die Zahlen in `HudLayout.zones` ändern und `lune run test` laufen lassen.

**1. PC-Fenster (normale Größe):**

- [ ] Oben Mitte Münzen und Gems, Meldungen direkt darunter (z. B. zu weit weg sammeln → „Zu weit weg!“).
- [ ] Tutorial-Karte (neuer Spielstand) steht **links oben** unter dem Roblox-Menü-Knopf, verdeckt weder Meldungen noch Münzen. Text gut lesbar, nicht abgeschnitten.
- [x] ~~Am Ei stehen: Ei-Vorschau wird nicht von der Tutorial-Karte verdeckt.~~ _(entfällt: seit #54 Panel rechts)_
- [x] Links: runde Knöpfe „Pets“ und darunter „Tränke“ (unter der Tutorial-Karte, nicht darauf). Beide öffnen ihr Menü.
- [ ] Unten Mitte Pizza-Balken, darüber Auto-Sammeln.
- [ ] An eine Barriere laufen: Freischalt-Knopf erscheint **rechts neben dem Pizza-Balken**, nicht auf Auto-Sammeln. Text (Welt + Preis) lesbar, Antippen schaltet frei.
- [ ] Trank trinken: Pille rechts oben (unter Höhe der Gems). Auftrag annehmen: Auftragskarte rechts unter den Pillen; ohne Trank rutscht sie nach oben.
- [ ] Shop, Gem-Tresen, Pet-Menü, Trank-Menü, Telefon und Teleport öffnen: jedes Menü beginnt **unter** Münzen/Gems/Meldungen und endet über dem Pizza-Balken. Münzen und Gems bleiben beim Kaufen sichtbar und zählen mit; „Nicht genug Münzen!“ ist bei offenem Shop lesbar.
- [ ] Teleport-Menü: bis zum untersten Eintrag scrollen – er ist vollständig sichtbar und anklickbar.
- [ ] Pet-Menü: „Löschen“-Bestätigung erscheint mittig im Panel und ist bedienbar.

**2. Device-Emulator** (Test → Device: iPhone SE quer, ein breites Android-Handy quer, iPad):

- [ ] Kein Knopf (Pets, Tränke, Auto-Sammeln, Freischalten) liegt unter dem Joystick (unten links) oder dem Sprung-Knopf (unten rechts).
- [x] ~~Auf dem kleinen Handy sitzen „Pets“ und „Tränke“ nebeneinander (zu wenig Höhe für untereinander), auf PC/Tablet untereinander.~~ _(entfällt: seit #52 neue Seitenknopf-Zone, Prüfung dort)_
- [x] ~~Menüs passen ganz zwischen Währungen und Pizza-Balken; Shop, Pets und Teleport werden dabei zuerst niedriger (Liste scrollt), erst dann kleiner. Knöpfe darin bleiben antippbar (sonst `MIN_PANEL_HEIGHT` im Menü senken).~~ _(entfällt: seit #55 Handy-Modus (scrollt statt zu schrumpfen))_
- [ ] Trank-Pillen + Auftragskarte ragen nicht unter den Sprung-Knopf (der Stapel schrumpft bei Bedarf).
- [ ] Freischalt-Knopf ist auf dem kleinen Handy schmaler, Text aber noch lesbar.
- [ ] Output ohne Fehler (rot), auch nach Tod/Respawn (HUD bleibt an seinem Platz).

## #21 A2 Menü-Kleinigkeiten: Scroll, Trank-Untertitel, Stufen-Anzeige

Nach `git pull` und Rojo-Connect in Studio Play drücken (ein Spielstand mit genug Münzen und Gems hilft):

- [ ] Shop in Welt 1 betreten, Liste ganz nach unten scrollen, Shop verlassen, wieder betreten: Liste beginnt **oben** (erste Karte sichtbar).
- [ ] Danach den Gem-Tresen bzw. einen anderen Shop betreten: auch dort beginnt die Liste oben, nicht an der alten Scroll-Position.
- [ ] Bei offenem Shop etwas kaufen: Liste bleibt dort, wo man gerade ist (kein Sprung nach oben).
- [ ] Trank-Menü öffnen: Untertitel „Gleiche Art nochmal trinken verlängert die Zeit.“ steht **unter** dem X-Knopf, ganz lesbar, nicht abgeschnitten oder verdeckt. Meldungen nach „Trinken“ (z. B. „Davon hast du keinen Trank …“) ebenso.
- [ ] Trank-Menü: alle drei Trank-Karten passen ins Panel, unterste nicht abgeschnitten (auch im Device-Emulator, kleines Handy).
- [x] In jedem Shop (Welt 1, Gem-Tresen, Shop 2, Shop 3) zeigen die Karten „Stufe x / N“, wobei N in allen Shops für dasselbe Upgrade gleich ist (Gesamtzahl der Stufen, z. B. „Stufe 2 / 8“).
- [x] Ein Upgrade im kleinen Shop bis zu dessen Grenze kaufen: Knopf zeigt „Weitere Stufen im größeren Shop“ (grau, nicht drückbar), Text lesbar.
- [ ] Ein Upgrade ganz ausbauen: Knopf zeigt „MAX“.

## #29 Ei-Modelle und Ei-Stände

Vorher: `git pull`, `lune run test` → alle grün. Vorschau: alle Eier auf ihren Ständen in `assets/previews/eggs/Overview.png`, einzeln `assets/previews/eggs/<EiId>.png` und `EggStand.png`; `FancyDemo.png` zeigt die auffälligere Variante (Goldband, Goldperlen, leuchtendes Muster) für das zweite Ei pro Welt aus Phase C (`fancy = true` im `look` des Eis in `GameConfig`).

Ohne Import läuft alles weiter: Jedes Ei ist dann eine Kugel in seiner Weltfarbe mit drei Punkten in der Akzentfarbe (Vulkan/Weltraum leuchtend), der Stand besteht aus Sockel, Zylinder, farbigem Ring und hellem Schild.

**1. Modelle importieren** (8 Dateien in `assets/models/eggs/`):

- [x] In **ReplicatedStorage → GameAssets → Models** einen **Folder** `Eggs` anlegen.
- [x] **Home → Import 3D** → in `assets/models/eggs/` alle 8 `.fbx` markieren (oder über das Namensfeld in Gruppen) → *Rig Type* = **No Rig**, *Insert Using Scene Position* = aus → **Import**.
- [x] Die Modelle heißen wie die Dateien: `GardenEgg`, `FarmEgg`, `BeachEgg`, `IceEgg`, `VolcanoEgg`, `CandyEgg`, `SpaceEgg`, `EggStand`. MeshParts heißen `Egg_FFF3DC`, `Egg_FF7A1A_Neon` … bzw. `Stone`, `StandBody`, `StandTrim`, `StandGold`, `EggSign` (Endungen wie `.001` sind ok). Alle in `Models/Eggs` ziehen, **Namen nicht ändern**.
- [x] ~~Kontrolle in der Command Bar: `print(#game.ReplicatedStorage.GameAssets.Models.Eggs:GetChildren())` → **8**.~~ _(entfällt: seit #39 15 Ei-Modelle, Import 17.11. erledigt)_
- [x] Place speichern und **File → Publish to Roblox**.

**2. Test** (Rojo verbunden, **Play**, 1 Spieler; Münz-Tipp aus #11, mit dem Portal durch die Welten):

- [x] Output ohne rote Fehler. _(belegt: Output in allen Tests ohne Spiel-Fehler)_
- [x] In jeder Welt steht ein gestalteter Stand (Steinsockel, heller Zylinder, Ring und Goldperlen in der Akzentfarbe des Eis) mit dem Ei darauf. Das Ei steht auf dem Stand, nicht darin und nicht schwebend.
- [ ] Die 7 Eier sind auf einen Blick unterscheidbar und sehen aus wie in `Overview.png`: Garten creme mit roten Punkten, Bauernhof gelb mit braunen Streifen, Strand türkis mit Wellen, Eis hellblau mit Rauten, Vulkan dunkelbraun mit **leuchtenden** Lava-Rissen, Süßigkeiten rosa mit weißem Wirbel, Weltraum lila mit **leuchtenden** Sternen.
- [ ] Das große Muster-Element (z. B. der große Punkt/Stern) und das Schild zeigen **zum Weg hin (-Z)**. Zeigen Ei oder Schild-Brett nach hinten: in `src/shared/ModelLibrary.luau` `PET_YAW` (gilt auch für Eier) bzw. `YAW.EggStand` (jetzt 180) auf 0 ändern.
- [ ] Schild vorne am Stand: Name und Preis (z. B. „Garten-Ei / 💰 25“, „Eis-Ei / 💰 12.000“), gut lesbar, liegt genau auf dem hellen Schild-Brett des Modells. Sitzt der Text versetzt: `SIGN_OFFSET` in `src/server/EggService.luau` anpassen.
- [ ] Man läuft gegen den Stand (kollidiert), steckt aber nicht in unsichtbaren Wänden neben dem Sockel.
- [x] ~~**Unverändert:** Ei-Vorschau erscheint beim Herangehen über dem Ei (nicht im Ei, nicht vom Stand verdeckt), „1 öffnen“ / „3 öffnen“ funktionieren, Glücks-Trank-Anzeige, Abstandsprüfung („Zu weit weg!“ ab ca. 18 Studs).~~ _(entfällt: seit #54 Panel statt Vorschau über dem Ei)_
- [ ] Knack-Animation: Das wackelnde Ei hat die Farbe des geöffneten Eis (z. B. lila beim Weltraum-Ei), danach erscheinen wie bisher die Pet-Karten.
- [ ] Tutorial-Pfeil „Ei öffnen“ zeigt weiterhin auf den Ei-Stand in Welt 1.
- [x] Neon-Teile (Vulkan, Weltraum) leuchten, ohne überstrahlt zu sein. _(belegt: 20.11.: Vulkan-Ei leuchtet, Fancy-Eier matt (#48))_

**Handy** (Device-Emulator): Schild aus 10–15 Studs Entfernung lesbar; Ei-Vorschau-Knöpfe bleiben antippbar.

## #35 C2 Rebirth

Regeln: `rules.rebirthOffer` / `rules.rebirth` in `GameRules` (Tests in `tests/Rebirth.spec.luau`), Preis und Multiplikator in `GameConfig.rebirth` (erster Rebirth 250 Mio, ×2 pro Rebirth – seit #41: 4,9 Mrd, ×3 –, +0,5 Münz-Multiplikator pro Rebirth). Spielstand-Version 4: das alte Feld `rebirthMultiplier` wird zu `rebirths`. Server: `src/server/RebirthService.luau`, Client: `src/client/RebirthMenu.luau`.

Tipp für schnelles Testen: wie bei #11 vorübergehend `Mozzarella.value = 50000000` (oder `GameConfig.rebirth.startPrice = 100`). **Danach zurücksetzen, nicht committen.**

**1. Test** (Rojo verbunden, **Play**, 1 Spieler, Tutorial fertig):

- [x] Output ohne rote Fehler. Alter Spielstand lädt (Münzen, Pets, Gems wie vorher), Rebirth-Zahl 0. _(belegt: 17.11.: alter Spielstand lädt, 0 Rebirths)_
- [x] Links in der Knopf-Spalte (Platz `rebirth`, nach Pets/Tränke bzw. Geschenke) ein runder lila Knopf **„Rebirth“**. Ohne Rebirth kein Abzeichen. _(belegt: 18./19.11.: Knopf da, Abzeichen „1“ erst nach Rebirth)_
- [x] Menü öffnen: „Noch kein Rebirth“, „Münzen ×1 → ×1,5“, „Preis: 4,9 Mrd Münzen“ (seit #41), Fortschrittsbalken mit Prozent, darunter was zurückgesetzt wird und was bleibt. Menü liegt unter Münzen/Gems und über dem Pizza-Balken. X schließt.
- [ ] Zu wenig Münzen: „Rebirth!“-Knopf grau, Antippen tut nichts. Fortschrittsbalken wächst beim Verkaufen mit.
- [ ] Genug Münzen (ohne Menü offen): Knopf **pulsiert** mit Hinweis „Neu! Mehr Münzen“ rechts daneben; nach dem ersten Öffnen hört das Pulsieren auf.
- [x] Trank trinken, dann Menü öffnen: rote Warnung „Dein laufender Trank endet beim Rebirth!“, auch im Bestätigungsfenster. _(belegt: 18./19.11. echter Rebirth)_
- [x] „Rebirth!“ → Bestätigung „Rebirth 1 für 4,9 Mrd Münzen? …“ mit **Ja**/**Nein**. „Nein“ schließt nur die Bestätigung. _(belegt: 18./19.11. echter Rebirth (Preis jetzt 74 Mio))_
- [x] Vorher einen Auftrag annehmen und Beläge auf der Pizza haben, dann in Welt 3+ „Ja“: Figur steht am **Spawnpunkt von Welt 1**, Pizza leer, Auftragskarte und Trank-Pille weg, Münzen 0, Feier-Text **„Rebirth 1! ×1,5 Münzen“** mitten im Bild (verblasst nach ca. 3 s), Abzeichen „1“ am Knopf. _(belegt: 18./19.11. echter Rebirth (`53`))_
- [x] Danach: Barrieren zu Welt 2+ wieder geschlossen, Portal-Menü zeigt sie gesperrt, Shop-Upgrades (Pizza-Platz, Reichweite, Magnet) wieder auf Stufe 0. Pets (ausgerüstet), Gems, Gem-Upgrades (Pet-Plätze, Inventar, Speed, 3 Eier) und Tränke im Inventar sind noch da. _(belegt: 18./19.11.: Tore wieder zu, Pizza 0/2, Pets und Gems bleiben)_
- [ ] Verkaufen am Ofen bringt jetzt das 1,5-Fache (z. B. 2 Salami ohne Pets: 2 → 3 Münzen). Münz-Lieferauftrag zeigt eine 1,5-fach höhere Belohnung; Gem-Belohnungen unverändert. Pet-Menü zeigt weiter nur den Pet-Bonus.
- [x] Menü erneut: „Rebirths: 1“, „Münzen ×1,5 → ×2“, Preis 500 Mio. _(belegt: 20.11.: 111 Mio bei 1 Rebirth (seit #58))_
- [ ] Tod nach dem Rebirth: Respawn in Welt 1.
- [x] **Rejoin** (Stop, Play): Rebirth-Zahl, Abzeichen und Multiplikator bleiben; Start in Welt 1. _(belegt: Rejoin 18./19.11.: alles bleibt, Start in Welt 1)_
- [x] Server-Schutz (Command Bar im Client): `game.ReplicatedStorage.Remotes.Rebirth:FireServer()` mit zu wenig Münzen → nur Meldung „Nicht genug Münzen!“, nichts wird zurückgesetzt.
- [x] Sound: in `src/client/Sounds.luau` für `Rebirth` eine Fanfare suchen (Suchbegriffe dort) und die ID eintragen.

**2. Device-Emulator** (kleines Handy quer):

- [ ] Rebirth-Knopf liegt nicht unter dem Joystick; Abzeichen und Hinweis-Blase sind lesbar und verdecken keine anderen Knöpfe.
- [ ] Menü und Bestätigung passen ganz ins Bild, „Ja“/„Nein“ antippbar.

## #36 C3 Spielzeit-Geschenke

Vorher: `lune run test` → `0 failed`. Zum schnellen Testen in `src/shared/GameConfig.luau` die `gifts`-Minuten vorübergehend klein setzen (z. B. 0.5 / 1 / 1.5 / 2 / 2.5 / 3) – danach zurücksetzen. Die Spielzeit wird alle 10 s gutgeschrieben.

**Knopf und Menü** (Play, 1 Spieler, Spielstand mit beendetem Tutorial):

- [ ] Links unter „Tränke“ ein runder rosa Knopf „Geschenke“ mit Countdown bis zum nächsten Geschenk (z. B. `4:50`), Countdown läuft sekundenweise.
- [x] Beim ersten Mal pulsiert der Knopf, daneben „Neu! Geschenke fürs Spielen“. Nach dem ersten Öffnen hört das auf – auch nach Rejoin (wird gespeichert). Während des Tutorials pulsiert er noch nicht. _(belegt: 18./19.11.: pulsiert erst nach dem Tutorial (`50`))_
- [ ] Ist ein Geschenk erreicht: rotes „!“ am Knopf, Text „Abholen!“, Knopf hüpft kurz.
- [x] Menü: 6 Zeilen 5/10/15/25/40/60 Min mit Belohnung (Münzen-Betrag, 5 Gems, 1 Trank, Münzen groß, 10 Gems, 15 Gems + 1 Trank). Wartende zeigen die Restzeit, erreichte einen grünen „Abholen“-Knopf, abgeholte ein ✓.
- [x] „Abholen“ → Statuszeile „Geschenk! +…“, Gem-Sound, Münzen/Gems oben steigen bzw. Trank liegt im Trank-Menü. Nochmal tippen → „schon abgeholt“. Wartendes antippen → „Noch nicht …“.
- [x] ~~Münz-Geschenk ist in Welt 1 klein (neuer Spieler: 20 Münzen, das große 54), in höheren Welten / mit Pets / größerer Pizza deutlich mehr.~~ _(entfällt: seit #50 keine Münz-Geschenke mehr)_
- [x] ~~Menü sitzt unter Münzen/Meldungen und über dem Pizza-Balken (auch im Device-Emulator, kleines Handy: wird kleiner, Knöpfe bleiben antippbar). Auf dem kleinen Handy liegt der Knopf nicht unter dem Joystick.~~ _(entfällt: Prüfung zusammengefasst in #55)_
- [x] Es kommen keine „+1 Gem fürs Spielen!“-Meldungen mehr.

**Rejoin** (API-Zugriff an, siehe #3):

- [x] Ein paar Minuten spielen, ein Geschenk abholen, verlassen, neu beitreten: Countdown läuft an derselben Stelle weiter, abgeholtes Geschenk bleibt ✓, nicht abgeholte bleiben „Abholen“. _(belegt: Rejoin 18./19.11.: Countdown zählt weiter)_
- [ ] Alter Spielstand (vor #36) lädt ohne Fehler, Gems bleiben, Tages-Spielzeit startet bei 0.

**Tageswechsel** (optional, Mitternacht deutscher Zeit): Nach Mitternacht beginnt die Tages-Spielzeit bei 0 und alle Geschenke sind wieder offen; Output ohne Fehler.

## #37 C4 Login-Kalender

Vorher: `lune run test` → `0 failed` (inkl. `tests/LoginCalendar.spec.luau`).

**Automatisches Öffnen** (Play, 1 Spieler, API-Zugriff an, Spielstand mit beendetem Tutorial):

- [x] Beim ersten Beitreten des Tages öffnet sich das Fenster „Login-Kalender“ von selbst: 7 Kacheln „Tag 1“ … „Tag 7“ mit Belohnung (Münzen, 10 Gems, 1 Trank, Münzen, 20 Gems, 2 Tränke, 50 Gems + 3 Tränke). Die heutige Kachel ist gelb mit „Heute“ und dickem Rand.
- [x] ~~Fenster sitzt unter Münzen/Meldungen und über dem Pizza-Balken; im Device-Emulator (kleines Handy) wird es kleiner, „Abholen“ und „X“ bleiben antippbar, Texte lesbar.~~ _(entfällt: Prüfung zusammengefasst in #55)_
- [x] Stop, erneut Play am selben Tag: Das Fenster öffnet sich **nicht** noch einmal (auch wenn nicht abgeholt). _(belegt: Rejoin 18./19.11.: Kalender öffnet nicht noch einmal)_
- [x] Neuer Spieler (Spielstand löschen bzw. anderer Test-Account): Das Fenster öffnet sich erst, wenn das Tutorial beendet ist, nicht mittendrin. _(belegt: 18./19.11.: Kalender öffnet erst nach dem Tutorial)_
- [x] Geschenke-Menü hat oben einen orangen Knopf „📅 Kalender“ → öffnet den Kalender (Geschenke-Menü schließt sich). _(belegt: 20.11. (#53): nur der Kalender offen)_

**Abholen:**

- [x] ~~„Abholen“ → Statuszeile „Tag 1! +34 Münzen“ (neuer Spieler in Welt 1, ca. 5 Minuten Einkommen), Gem-Sound, Münzen oben steigen, Kachel zeigt ✓, Knopf wird grau „Morgen wieder“.~~ _(entfällt: seit #50 Tag 1 = 5 Gems, Prüfung in #50)_
- [x] ~~Mit höherer freigeschalteter Welt (oder mehr Pizza-Platz/Pets) ist der Münzbetrag auf Tag 1/Tag 4 deutlich größer.~~ _(entfällt: seit #50 keine Münzen im Kalender)_
- [ ] Graues „Morgen wieder“ antippen → nichts passiert; kein zweites Abholen möglich, auch nicht nach Rejoin.

**Mehrere Server / Rejoin:**

- [ ] Abholen, Spiel verlassen, sofort neu beitreten (anderer Server bzw. neuer Play-Lauf): Tag bleibt ✓, Abholen nicht möglich. Output ohne `[Save]`-Fehler.
- [ ] Alter Spielstand (vor #37) lädt ohne Fehler und startet bei Tag 1.

**Serie** (optional, über mehrere echte Tage oder mit vorübergehend verstellter Zeit): am Folgetag ist Tag 2 „Heute“ und Tag 1 ✓; nach einem ausgelassenen Tag wieder Tag 1; nach Tag 7 wieder Tag 1. Neuer Tag beginnt um Mitternacht deutscher Zeit; bleibt man über Mitternacht im Spiel, wird der nächste Tag nach spätestens 15 s abholbar (über „📅 Kalender“).

## #27 B1 Insel-Bauweise: Spawn-Insel und Welt 1 (Prototyp)

Vorher: `lune run test` → `0 failed` (inkl. `tests/IslandPlan.spec.luau`). Vorschau-Renders zum Vergleich: `assets/previews/islands/`.

**Einmalig in Studio:**

- [x] Falls im Workspace noch ein `Baseplate` liegt: löschen und Place speichern/publishen (der Server entfernt ihn sonst beim Start mit einer Warnung `[WorldMap] Baseplate entfernt`). Auch einen alten `SpawnLocation` aus der Vorlage löschen.
- [x] Neues Modell importieren: `assets/models/RoundTree.fbx` nach `ReplicatedStorage.GameAssets.Models` (wie in #15). Ohne Import stehen Ersatz-Bäume aus Kugeln da.

**Play (1 Spieler, neuer Spielstand):**

- [x] Output ohne rote Fehler. Start auf der **Spawn-Insel** am gelben Spawn, Blick auf den Pizza-Brunnen (Wasserspritzer) und die Brücke. _(belegt: 18./19.11.: neuer Spieler startet auf der Spawn-Insel)_
- [x] Spawn-Insel: runder, unregelmäßiger Umriss mit Felskante darunter, Hecke am Rand, Bäume, Teich mit Wasserfall, Portal-Tor links vorne, drei Tafeln „⏱ Spielzeit“, „💰 Münzen verdient“, „🔁 Rebirths“ (Inhalt seit #38: echte Bestenlisten, Text auf der Vorderseite, Richtung Brunnen). _(belegt: 17.11. (`23`); kleine Schrift siehe #38)_
- [ ] Tutorial-Karte erscheint auf der Spawn-Insel; Pfeil und Leuchtlinie zeigen zuerst auf den **Brückenkopf von Welt 1**, nach dem Überqueren der Brücke auf die Beläge.
- [x] Hängebrücke (Holzplanken, Pfosten, Seile) begehbar, leicht durchhängend, man kann nicht seitlich herunterfallen (unsichtbare Wand), springen hilft nicht. _(belegt: 18./19.11.: Brücken-Seitenwände halten)_
- [x] ~~Welt 1 als Insel wie in `World1_Overview.jpg`: Hauptweg aus Platten, links Portal, Shop, Ei-Stand mit Garten-Ei und ein zweiter Ei-Stand „Bald: neues Ei!“, rechts Ofen mit oranger Verkaufszone, Telefon, Lieferwagen. Alle Stationen zeigen mit der Front zum Weg.~~ _(entfällt: zweiter Ei-Stand seit #39 belegt; Stationen 18./19.11. geprüft)_
- [x] **Kamera:** In der Verkaufszone, am Shop, am Ei, am Telefon, am Lieferwagen und im Portal bleibt die Kamera frei (keine Wand/kein Baum zwischen Kamera und Figur). Ofen-Animation fliegt in die Ofenöffnung. _(belegt: 18./19.11.: Kamera an allen Stationen frei (`48`))_
- [x] Sammeln, Verkaufen, Shop kaufen, Ei öffnen, Lieferauftrag (Telefon → Lieferwagen) funktionieren wie vorher; Tutorial lässt sich komplett abschließen. _(belegt: 18./19.11.: Tutorial als neuer Spieler komplett)_
- [ ] Hinten in Welt 1: Terrassen mit Stufen (begehbar), Riesen-Pizza als Wahrzeichen, Teich mit Wasserfall rechts vorne. Pets laufen nicht durch die Hecke/Wand.
- [x] **Rand:** An keiner Stelle der Inseln kann man herunterfallen (Rand abgehen, gegen die Wand springen). _(belegt: 18./19.11.: 0 Abstürze an 22 Punkten pro Insel)_
- [x] **Absturz:** Mit Command Bar (Server) eine Figur unter die Insel setzen, z. B. `game.Players:GetPlayers()[1].Character:PivotTo(CFrame.new(130, -40, 0))` → sie landet sofort am Spawn der aktuellen Welt (neuer Spieler: Spawn-Insel; nach Betreten von Welt 1: Welt 1 vorne am Weg). _(belegt: 18./19.11.: Absturz unter Welt 6 → Spawn Welt 6)_
- [x] Tod (Reset Character) nach Betreten von Welt 1 → Respawn in Welt 1 am Brückenende (nicht auf der Spawn-Insel). Rejoin → Start in Welt 1. _(belegt: 18./19.11.: Tod Welt 7 → Welt 7; Rejoin → letzte Welt)_

**Welt 2–7 (alter Look an der Kette):**

- [x] ~~Hinter Welt 1 führt eine Brücke zu Welt 2; am Brückenkopf steht ein **leuchtendes Tor** in Weltfarbe mit Preisschild „🔒 Bauernhof 170 Münzen“ (seit #41). Durchlaufen geht nicht.~~ _(entfällt: seit #31/#32 alle Welten Inseln, Preis seit #57)_
- [x] ~~Vor dem Tor erscheint der Freischalt-Knopf; mit genug Münzen freischalten → Tor wird durchsichtig/passierbar, Preisschild verschwindet. Andere Spieler bleiben stecken.~~ _(entfällt: seit #31/#32 alle Welten Inseln; Mehrspieler siehe Release-Checkliste)_
- [x] ~~Welt 2–7 sind über Brücken erreichbar und spielbar wie vorher (Ofen, Ei, Shop, Portal, Telefon/Wagen, Deko). Ränder haben unsichtbare Wände, unter den Platten hängt ein Felsblock.~~ _(entfällt: seit #31/#32 alle Welten Inseln)_
- [x] ~~Portal in Welt 1 / auf der Spawn-Insel: Menü öffnet, Teleport in jede freigeschaltete Welt, Ankunft vor deren Portal; danach Tod → Respawn in dieser Welt.~~ _(entfällt: seit #31/#32 alle Welten Inseln; 18./19.11. Portal und Respawn geprüft)_
- [x] ~~Welt-Atmosphäre/Musik wechselt beim Betreten einer Insel; auf Brücken bleibt der Look der verlassenen Welt, auf der Spawn-Insel der von Welt 1.~~ _(entfällt: seit #45 ein Licht-Look, nur Musik wechselt)_
- [ ] Ferne Schilder (Tore, Shops anderer Welten) sind aus Welt 1 nicht am Himmel zu sehen (#22).

**2 Spieler + Device-Emulator (kleines Handy):**

- [ ] Beide starten auf der Spawn-Insel; einer schaltet Welt 2 frei, der andere bleibt am Tor stecken.
- [ ] Auf dem Handy: Brücke und Plattenwege gut begehbar, Freischalt-Knopf am Tor antippbar.


## #38 C5 Bestenlisten

Voraussetzung: **Game Settings → Security → „Enable Studio Access to API Services“** an (sonst schreiben/lesen die DataStores in Studio nicht; dann bleiben die Tafeln bei „Bestenliste lädt …“ und das Spiel läuft trotzdem weiter).

- [ ] Spawn-Insel: Die drei Tafeln zeigen oben den Titel („⏱ Spielzeit“, „💰 Münzen verdient“, „🔁 Rebirths“) und darunter bis zu 10 Zeilen mit Platz, Anzeigename und Wert. Platz 1–3 in Gold/Silber/Bronze. Text gut lesbar, nichts abgeschnitten (lange Namen enden mit „…“).
- [ ] Erster Start mit leeren Bestenlisten: Nach dem ersten Einlesen steht „Noch keine Einträge“ (vorher „Bestenliste lädt …“).
- [x] Ein paar Minuten spielen (Beläge verkaufen), dann Play stoppen (Verlassen schreibt die Werte) und erneut starten → spätestens nach ca. 2 Minuten steht man auf allen Tafeln, auf denen man einen Wert > 0 hat. Spielzeit z. B. „5 Min.“ bzw. „1 Std. 3 Min.“, Münzen mit Tausenderpunkt (`12.345`).
- [ ] Aktualisierung ohne Neustart: im laufenden Spiel weiterspielen; nach dem nächsten automatischen Speichern (alle 2 Minuten) und dem nächsten Einlesen (alle ca. 2 Minuten) steigen die Werte auf den Tafeln.
- [ ] „Münzen verdient“ zählt Verkauf am Ofen, Lieferauftrag mit Münz-Belohnung, Kalender- und Geschenk-Münzen. Prüfen per Command Bar (Server), z. B. vor und nach einem Verkauf: `print(require(game.ServerScriptService.Server.PlayerStates).get(game.Players:GetPlayers()[1]).totalCoinsEarned)`.
- [ ] Rebirth durchführen → Münzen auf 0, „Münzen verdient“ bleibt gleich, Rebirths-Tafel zeigt nach dem nächsten Speichern/Einlesen 1.
- [ ] DataStore-Fehler: „Enable Studio Access to API Services“ ausschalten, Play → keine roten Fehler/Abbrüche, nur gelbe Warnungen `[Bestenliste] …`; Sammeln, Verkaufen und Speichern-Warnungen wie gewohnt.
- [ ] Output: beim normalen Spielen keine Warnungen `[Bestenliste] … fehlgeschlagen`.
- [ ] 2 Spieler (Test → Clients and Servers, 2 Spieler): Beide erscheinen mit ihrem Anzeigenamen auf den Tafeln (Studio-Testspieler haben negative IDs; wenn deren Namen nicht auflösbar sind, steht „Spieler“ – im veröffentlichten Spiel echte Namen prüfen).

## #39 C6 Zweites Ei pro Welt

Jede Welt hat jetzt zwei Eier (`GameConfig.worlds[].eggs`): das bisherige und ein zweites, auffälligeres Ei (`fancy = true`: Goldband, Goldperlen, leuchtendes Muster) mit 4 neuen Pets (Selten, Episch, Legendär, Mythisch; Chancen 68 / 25 / 6 / 1 %), ca. 5× so teuer und Pets ca. 1,5× so stark wie dieselbe Seltenheit im ersten Ei. Tests: `tests/GameConfig.spec.luau` („second egg per world“) und `tests/IslandPlan.spec.luau` („egg spots in every world“).

| Welt | Zweites Ei (Id) | Preis | Pets |
| --- | --- | --- | --- |
| Pizzeria-Garten | Steinofen-Ei (`StoneOvenEgg`) | 125 | Rucola-Igel, Parmesan-Waschbär, Trüffel-Fuchs, Steinofen-Phönix |
| Bauernhof | Scheunen-Ei (`BarnEgg`) | 1.000 | Kürbis-Katze, Butter-Esel, Honig-Bär, Goldkorn-Stier |
| Strand | Muschel-Ei (`ShellEgg`) | 7.500 | Kokos-Affe, Muschel-Seepferdchen, Sardinen-Hai, Perlen-Seeschlange |
| Eisberge | Gletscher-Ei (`GlacierEgg`) | 60.000 | Minz-Rentier, Eisbecher-Eisbär, Vanille-Mammut, Sorbet-Narwal |
| Vulkan | Magma-Ei (`MagmaEgg`) | 500.000 | Pfeffer-Skorpion, Habanero-Nashorn, Curry-Tiger, Calzone-Hydra |
| Süßigkeitenland | Bonbon-Ei (`BonbonEgg`) | 4.000.000 | Donut-Dackel, Pudding-Panda, Lakritz-Panther, Torten-Pegasus |
| Weltraum | Nebula-Ei (`NebulaEgg`) | 32.000.000 | Mondkuchen-Hase, Sternfrucht-Qualle, Sternenstaub-Löwe, Galaxie-Pizza-Leviathan |

Die 28 neuen Pets haben noch keine Modelle (kommt mit C7): Sie erscheinen bis dahin als Kugel bzw. Punkt in ihrer Seltenheitsfarbe. _(Modelle seit #40, Import siehe unten.)_ Vorschau der Eier: `assets/previews/eggs/<EiId>.png` und `assets/previews/eggs/Overview.png` (vorne die ersten Eier, dahinter die zweiten).

Standorte: In Welt 1 (Insel-Look) steht das zweite Ei auf dem zweiten Ei-Platz links am Hauptweg. In Welt 2–7 (noch alter Look) steht es links neben dem ersten Ei, zwischen erstem Ei und Shop-Platz.

**1. Modelle importieren** (7 neue Dateien in `assets/models/eggs/`):

- [x] **Home → Import 3D** → `StoneOvenEgg.fbx`, `BarnEgg.fbx`, `ShellEgg.fbx`, `GlacierEgg.fbx`, `MagmaEgg.fbx`, `BonbonEgg.fbx`, `NebulaEgg.fbx` → *Rig Type* = **No Rig**, *Insert Using Scene Position* = aus → **Import**. In **ReplicatedStorage → GameAssets → Models → Eggs** ziehen, **Namen nicht ändern** (MeshParts z. B. `Egg_C9653A`, `Egg_FFD27A_Neon`, `Egg_FFC83A_Metal`).
- [x] Kontrolle in der Command Bar: `print(#game.ReplicatedStorage.GameAssets.Models.Eggs:GetChildren())` → **15** (14 Eier + `EggStand`).
- [x] Place speichern und **File → Publish to Roblox**.

**2. Test** (Rojo verbunden, **Play**, 1 Spieler; Münz-Tipp aus #11, mit dem Portal durch die Welten). Zum schnellen Testen vorübergehend `price = 1` beim `StoneOvenEgg` setzen (**nicht committen**, danach zurück auf 125).

- [x] Output ohne rote Fehler. Im Workspace unter `Eggs` stehen **14** Eier. _(belegt: 17.11.: 15 Ei-Modelle; 18./19.11. beide Stände in allen Welten)_
- [x] **Welt 1:** Zwei Ei-Stände links am Weg: vorne Garten-Ei, dahinter Steinofen-Ei (terrakotta mit leuchtenden Rissen, Goldband, Goldperlen). Schild „Steinofen-Ei / 💰 125“. Kein Stand zeigt mehr „Bald: neues Ei!“.
- [x] ~~**Welt 2–7:** In jeder Welt zwei Stände nebeneinander vor dem Belagfeld (links neben dem ersten Ei das zweite), keiner steckt im Shop, in der Deko oder im Weg. Eier wie in `Overview.png` (zweite Reihe): Scheune rot mit weißen Rauten, Muschel rosa mit Wirbel, Gletscher eisblau mit Sternen, Magma fast schwarz mit leuchtenden Lava-Wellen, Bonbon lila mit gelben Streifen, Nebula dunkelblau mit leuchtenden lila Punkten.~~ _(entfällt: seit #31/#32 Inseln; 18./19.11. beide Ei-Stände überall richtig)_
- [ ] Das zweite Ei ist sofort nach dem Freischalten der Welt nutzbar; in einer noch gesperrten Welt (per Portal nicht erreichbar) geht es nicht.
- [ ] Ei-Vorschau am zweiten Ei: 4 Pets mit Seltenheit und Chance (Selten 68 %, Episch 25 %, Legendär 6 %, Mythisch 1 %), Preis stimmt. Mit Glücks-Trank verschieben sich die Chancen wie beim ersten Ei.
- [x] Zwischen den beiden Ständen hin und her laufen: Die Vorschau wechselt zum jeweils näheren Ei, sie flackert nicht und zeigt nie zwei Vorschauen übereinander. „1 öffnen“ öffnet das Ei, vor dem man steht. _(belegt: 20.11. (#54): Panel wechselt zwischen den Eiern (`71`))_
- [ ] „1 öffnen“ und (mit gekauftem „3 Eier auf einmal“) „3 öffnen“ funktionieren, Knack-Animation in der Farbe des zweiten Eis, danach Pet-Karten mit den neuen Namen.
- [x] ~~Neue Pets im Pet-Menü: Name vollständig lesbar (auch „Galaxie-Pizza-Leviathan“), Icon als Punkt in Seltenheitsfarbe, Bonus z. B. Rucola-Igel +37,5 % (Anzeige je nach Rundung). Ausrüsten → Pet folgt als Kugel in Seltenheitsfarbe, Münzbonus beim Verkaufen wirkt.~~ _(entfällt: Boni seit #57 neu, Modelle seit #40)_
- [ ] Rejoin: Pets aus dem zweiten Ei sind nach dem Neubeitreten noch da.

**Handy** (Device-Emulator): Beide Schilder aus 10–15 Studs lesbar; die Vorschau-Knöpfe beider Eier bleiben antippbar.

## #41 C8 Late-Game-Balancing

Neue Preise für Freischaltungen, Shop 1, Shop 3 und Rebirth, abgestimmt mit einer Simulation über die echten Regeln (`lune run balance`, Modell `tools/BalanceSim.luau`). Tabelle, Annahmen und alle alten/neuen Preise: `docs/balancing.md`. Ziel: Welt 1–2 je ca. 10–15 Min, Welt 3–5 je ca. 20–25 Min, Welt 6–7 je ca. 30–35 Min. Belagwerte, Ei-Preise und das erste Upgrade (12) sind unverändert. Tests: `tests/GameConfig.spec.luau` („GameConfig balancing“).

Neue Preise: Bauernhof 170, Strand 2.000, Eisberge 42.000, Vulkan 310.000, Süßigkeitenland 23 Mio, Weltraum 460 Mio, erster Rebirth 4,9 Mrd (×3 pro weiterem Rebirth). Shop 1: Pizza-Platz 12 / 50 / 200, Reichweite 30 / 100 / 400, Magnet 300. Shop 3: Pizza-Platz 600 Mio / 1,8 Mrd, Reichweite 400 Mio / 1,2 Mrd, Magnet 500 Mio / 1,5 Mrd.

Studio: Rojo verbinden, **Play** (1 Spieler, möglichst frischer Spielstand, Tutorial normal durchspielen):

- [x] Output ohne rote Fehler. _(belegt: Output in allen Tests ohne Spiel-Fehler)_
- [x] ~~Tore und Preisschilder zeigen die neuen Preise: „🔒 Bauernhof 170 Münzen“, Strand 2.000, Eisberge 42.000, Vulkan 310.000, Süßigkeitenland 23 Mio, Weltraum 460 Mio. Das Teleport-Menü zeigt dieselben Preise bei den gesperrten Welten.~~ _(entfällt: Preise seit #57 neu)_
- [x] ~~Shop 1: Pizza-Platz kostet 12 → 50 → 200, Reichweite 30 → 100 → 400, Magnet 300. Shop 3 (Weltraum) zeigt die Preise oben.~~ _(entfällt: Preise seit #57 neu)_
- [x] ~~Rebirth-Menü: „Preis: 4,9 Mrd Münzen“; nach einem Rebirth zeigt es 14,7 Mrd für den zweiten (Test mit vorübergehend hohem Münzstand, **nicht committen**).~~ _(entfällt: seit #57/#58 74 Mio, ×1,5 je Rebirth)_
- [x] ~~**Stoppuhr Welt 1:** Ab Spielstart (Tutorial inklusive) bis zum Freischalten des Bauernhofs normal spielen, dabei Upgrades und das Garten-Ei kaufen, Lieferaufträge annehmen. Zeit notieren (Ziel ca. 10–15 Min, Simulation 13 Min). Fühlt es sich deutlich schneller an, liegt das am Rundentempo: Die Simulation rechnet mit 2 Runden pro Minute.~~ _(entfällt: Stoppuhr-Ziele seit #57 neu, Messung 20.11.)_
- [x] ~~**Stoppuhr Welt 2:** Vom Freischalten des Bauernhofs bis zum Freischalten des Strands (Ziel ca. 10–15 Min, Simulation 12 Min). Beide Zeiten in `docs/balancing.md` unter der Tabelle notieren.~~ _(entfällt: Stoppuhr-Ziele seit #57 neu, Messung 20.11.)_
- [x] ~~Geschenke und Login-Kalender geben weiterhin Münzen „ca. N Minuten Einkommen“; Beträge passen zur aktuellen Welt (unverändert, nur Kontrolle).~~ _(entfällt: seit #50 keine Münzen mehr)_

## #40 C7 28 neue Pet-Modelle

Die 28 Pets der zweiten Eier (#39) haben jetzt Modelle im Chibi-Stil (großer Kopf, glänzende Augen, rosa Wangen), gebaut mit `tools/blender/build_pets.py`. Jedes Pet zeigt sein Tier und sein Essen. Test: `tests/PetModels.spec.luau` prüft, dass jedes Pet aus `GameConfig.pets` eine FBX-Datei und ein Vorschaubild mit seiner Id hat und jedes Ei ein Vorschaublatt.

Vorschau: pro Ei `assets/previews/pets/<EiId>.png` (z. B. `StoneOvenEgg.png`, 4 Pets nebeneinander), einzeln `assets/previews/pets/<PetId>.png`.

| Ei | Pets (Id) – Erkennungsmerkmal |
| --- | --- |
| Steinofen-Ei | `RucolaHedgehog` (Rucola-Blätter als Stacheln), `ParmesanRaccoon` (Parmesan-Keil), `TruffleFox` (Teller mit Trüffel), `StoneOvenPhoenix` (Steinofen-Körper mit Glut, Flammenflügel) |
| Scheunen-Ei | `PumpkinCat` (Kürbis-Rippen, Stiel), `ButterDonkey` (Butterstück auf dem Kopf, Butterdose auf dem Rücken), `HoneyBear` (Honigtopf, Biene), `GoldGrainBull` (Goldhörner, Weizenkrone und -kragen) |
| Muschel-Ei | `CoconutMonkey` (Kokos-Helm, Kokos-Drink), `ShellSeahorse` (Jakobsmuschel), `SardineShark` (Sardinendose auf dem Kopf), `PearlSeaSerpent` (Muschel mit Perle, Perlenkette) |
| Gletscher-Ei | `MintReindeer` (minzgrün, Schokostückchen, Minzbonbon), `SundaePolarBear` (Eisbecher), `VanillaMammoth` (Vanille-Eis im Rüssel, Vanilleblüte), `SorbetNarwhal` (Sorbet-Kugeln, Eis-Stoßzahn) |
| Magma-Ei | `PepperScorpion` (Pfefferkörner-Schwanz, Chili-Stachel), `HabaneroRhino` (Habanero-Hörner), `CurryTiger` (Curry-Schüssel), `CalzoneHydra` (Calzone-Körper, Köpfe Tomate/Käse/Basilikum) |
| Bonbon-Ei | `DonutDachshund` (Donut um den Bauch), `PuddingPanda` (Pudding auf dem Kopf), `LicoricePanther` (Lakritz-Konfekt, Lakritzschnecke am Schwanz), `CakePegasus` (Tortenstück mit Kerze) |
| Nebula-Ei | `MooncakeBunny` (Mondkuchen, Mondsichel), `StarfruitJellyfish` (Sternfrucht-Scheibe, leuchtende Tentakel), `StardustLion` (Sternen-Mähne), `GalaxyPizzaLeviathan` (Galaxie-Pizza mit Pepperoni-Planeten) |

**1. Pet-Modelle importieren** (28 neue Dateien in `assets/models/pets/`, gleiche Einstellungen wie bei #16):

- [x] **Home → Import 3D** → im Dateidialog die 28 neuen `.fbx` markieren (Namen siehe Tabelle; Gruppen über das Namensfeld wie bei #16) → *Rig Type* = **No Rig**, *Insert Using Scene Position* = aus → **Import**.
- [x] Die importierten Models (Name = Pet-Id, MeshParts `Pet_9A6A44`, `Pet_FF8A2A_Neon`, `Pet_C8D0DA_Metal`, `Pet_D8F0FF_Glass` …) in **ReplicatedStorage → GameAssets → Models → Pets** ziehen. **Namen nicht ändern.** Größe, Farbe und Position egal.
- [x] Kontrolle in der Command Bar: `print(#game.ReplicatedStorage.GameAssets.Models.Pets:GetChildren())` → **70**.
- [x] Place speichern und **File → Publish to Roblox**.

**2. Test** (Rojo verbunden, **Play**, 1 Spieler; Münz-Tipp aus #11, zum schnellen Öffnen vorübergehend `price = 1` bei einem zweiten Ei setzen, **nicht committen**):

- [x] Output ohne rote Fehler. _(belegt: Output in allen Tests ohne Spiel-Fehler)_
- [x] **Ei-Vorschau** am zweiten Ei jeder Welt: alle 4 Zeilen zeigen das 3D-Pet statt eines farbigen Punkts, nichts abgeschnitten (auch die breiten: Calzone-Hydra, Galaxie-Pizza-Leviathan, Goldkorn-Stier). _(belegt: #54, 20.11.: Pet-Bilder in den Panel-Zeilen)_
- [x] **Ei öffnen**: Die Pet-Karte zeigt das 3D-Pet vor dem Kreis in Seltenheitsfarbe.
- [ ] **Pet-Menü**: Jede Karte eines neuen Pets zeigt das Modell im runden Feld.
- [ ] **Folgen**: Je ein neues Pet pro Welt ausrüsten → läuft als Modell hinter dem Spieler, **Gesicht in Laufrichtung**, steht auf dem Boden (Seeschlange, Qualle und Leviathan nicht im Boden, nicht hoch schwebend), Namensschild über dem Kopf. Mythische (Phönix, Stier, Seeschlange, Narwal, Hydra, Pegasus, Leviathan) sind etwas größer als die seltenen.
- [ ] Neon leuchtet (Ofenglut und Flammen des Phönix, Calzone-Soße, Quallen-Tentakel, Sterne des Löwen, Pepperoni-Planeten), Glas ist durchsichtig (Eisbecher, Seepferdchen-Flossen), Metall glänzt (Goldhörner und Weizen des Stiers, Sardinendose, Löffel des Pandas, Hufe des Pegasus).
- [ ] Farben wie in den Vorschaubildern; jedes Pet ist an Tier und Essen erkennbar (Tabelle oben). Was in Studio schlecht zu erkennen ist: hier notieren.
- [ ] **Mehrspieler** (2 Spieler): B sieht A's neue Pets als Modelle hinter A herlaufen.
- [ ] **Handy** (Device-Emulator): Pet-Menü mit vielen neuen Pets öffnet ohne spürbares Ruckeln.

## #43 C10 Welten mit Mindestzahl an Rebirths

Welten können neben dem Münzpreis eine Mindestzahl an Rebirths verlangen (`requiredRebirths` in `GameConfig.worlds`, Standard 0). Welt 1–7 brauchen 0. Im normalen Spiel ändert sich also nichts. Zum Testen vorübergehend eine Bedingung setzen (**nicht committen**): in `src/shared/GameConfig.luau` beim Bauernhof `requiredRebirths = 1` und beim Strand `requiredRebirths = 2` ergänzen.

- [ ] Output ohne rote Fehler.
- [ ] **Barrieren-Tor Bauernhof:** Das Schild zeigt „🔒 Bauernhof / Ab 1 Rebirth / 170 Münzen“, beim Strand „Ab 2 Rebirths“.
- [ ] **Freischalt-Knopf** am Tor (mit 0 Rebirths, genug Münzen): grau, Text „🔒 Bauernhof: Ab 1 Rebirth“ und der Preis darunter. Tippen → Hinweis „Dafür brauchst du mehr Rebirths!“, Münzen bleiben gleich, das Tor bleibt zu.
- [ ] **Portal-Menü:** Bauernhof und Strand stehen grau da mit „Ab 1 Rebirth“ bzw. „Ab 2 Rebirths“ und dem Preis in der zweiten Zeile. Text nicht abgeschnitten, auch im Device-Emulator (kleines Handy).
- [ ] Mit **1 Rebirth** (Münz-Tipp aus #11 für den Rebirth-Preis, oder in der Command Bar den Spielstand anpassen): Bauernhof-Knopf wird grün „🔓 Bauernhof freischalten“, Kaufen klappt. Strand zeigt weiter „Ab 2 Rebirths“.
- [x] Ohne die vorübergehende Änderung: Tore und Portal-Menü sehen aus wie vorher (nur Preis, kein Rebirth-Hinweis). _(belegt: 18./19.11.: Tor zeigt nur den Preis)_

## #18 Belag-Modelle der Welten 2–7

Die 19 Beläge der Welten 2–7 haben jetzt Blender-Modelle im Stil der neuen Salami (#24): flach, kräftige Farben, dunklerer Rand oder Unterseite, damit sie auf jedem Boden und auf der Pizza lesbar sind. Gebaut mit `tools/blender/build_toppings.py`. Die Teile tragen ihre Farbe im Namen wie Pets und Eier (`Top_F59AAA`, `Top_785AFF_Neon`, `Top_A8DCFF_Glass`), `ModelLibrary` färbt danach. Weltspezifische Effekte: Welt 4 frostig (Glas-Eisstückchen, Frostkappen), Welt 5 heiß (leuchtendes Fett in der Peperoni, glühende Chili-Spitze), Welt 6 Gummibärchen aus Glas, Welt 7 Neon (Sternen-Oliven, Alien-Pilz). Test: `tests/ToppingModels.spec.luau` (jeder Belag hat FBX und Vorschau, jede Welt 2–7 ein Prüfbild).

Code musste nicht geändert werden: Boden-Belag (`ToppingService`), Pizza in der Hand und Bestell-Pizza (`PizzaVisual`) rufen schon `ModelLibrary.dressDisc(disc, toppingId)` auf. **Ohne Import bleiben die farbigen Scheiben wie bisher** (Fallback).

Vorschau: `assets/previews/toppings/<BelagId>.png`, `World2.png` … `World7.png` (Beläge auf dem Belagfeld und auf der Pizza, maßstabsgetreu), `Overview.png` (alle 19).

| Welt | Beläge (Id = Dateiname) |
| --- | --- |
| 2 Bauernhof | `Onion` (rote Zwiebelscheibe), `BellPepper` (grüner und roter Paprikaring), `Corn` (Maiskörner auf Blatt), `Ham` (Schinkenscheibe mit Fettrand) |
| 3 Strand | `Tuna` (Thunfisch-Flocken), `Shrimp` (gestreifte Garnele mit Schwanzfächer), `Pineapple` (Ananasring) |
| 4 Eisberge | `FrozenPeas` (Erbsen mit Frost und Eis), `Salmon` (Lachsscheibe mit Fettstreifen), `IcebergLettuce` (Salatblätter mit Eissplittern) |
| 5 Vulkan | `Chili` (rote Chili, glühende Spitze), `Pepperoni` (3 gewölbte Scheiben mit glühendem Fett), `Jalapeno` (2 Scheiben mit Kernen) |
| 6 Süßigkeitenland | `ChocolateChips` (Schokotropfen), `GummyBears` (2 Gummibärchen aus Glas), `Marshmallow` (3 Marshmallows) |
| 7 Weltraum | `MoonCheese` (Käse-Keil mit Kratern), `StarOlives` (leuchtende Stern-Oliven), `AlienMushroom` (leuchtende Pilze mit Punkten) |

**1. Modelle importieren** (19 Dateien in `assets/models/toppings/`, gleiche Einstellungen wie bei #16):

- [x] In **ReplicatedStorage → GameAssets → Models** einen Ordner **`Toppings`** anlegen (Rechtsklick → Insert Object → Folder).
- [x] **Home → Import 3D** → im Dateidialog in `assets/models/toppings/` alle 19 `.fbx` markieren (oder in Gruppen über das Namensfeld) → *Rig Type* = **No Rig**, *Insert Using Scene Position* = aus, sonst Standard → **Import**.
- [x] Die importierten Models (Name = Belag-Id, MeshParts `Top_6E2662`, `Top_FFA040_Neon`, `Top_A8DCFF_Glass` …, Endungen wie `.001` sind in Ordnung) in den Ordner **`Models/Toppings`** ziehen. **Namen nicht ändern.** Größe, Farbe und Position egal – das Spiel skaliert und färbt nach den Teilnamen.
- [x] Kontrolle in der Command Bar: `print(#game.ReplicatedStorage.GameAssets.Models.Toppings:GetChildren())` → **19**.
- [x] Place speichern und **File → Publish to Roblox**.

**2. Test** (Rojo verbunden, **Play**, 1 Spieler; zum schnellen Hinkommen Münz-Tipp aus #11 oder Portal):

- [x] Output ohne rote Fehler. _(belegt: 17.11.: Toppings importiert, Output ohne Fehler)_
- [x] In jeder Welt 2–7 liegen auf dem Belagfeld die Modelle statt der Scheiben; jeder Belag ist von oben und aus der Spielerperspektive gut erkennbar (Vergleich mit `assets/previews/toppings/World<N>.png`). Nichts steckt im Boden oder schwebt.
- [ ] Anklicken/Antippen eines Modells sammelt den Belag ein (Klick trifft auch auf das Modell, nicht nur auf die unsichtbare Scheibe); Auto-Sammeln und Magnet ziehen das Modell mit.
- [ ] **Pizza in der Hand**: gesammelte Beläge liegen passend klein auf der Pizza, ragen nicht über den Rand, stehen nicht hoch heraus (besonders Gummibärchen, Alien-Pilz, Marshmallow, Mond-Käse).
- [ ] **Bestell-Pizza** (Lieferauftrag in Welt 2+): Beläge auf der Pizza mit Bestellzettel ebenso als Modelle; Abgabe am Lieferwagen funktioniert.
- [ ] Verkaufs-Animation am Ofen zeigt die Pizza wie gewohnt.
- [ ] Effekte: Eisstückchen in Welt 4 durchsichtig, Fett der Peperoni und Chili-Spitze in Welt 5 leuchten, Gummibärchen durchsichtig, Sternen-Oliven und Alien-Pilz-Hüte in Welt 7 leuchten.
- [ ] Ohne Import (z. B. Ordner `Toppings` kurz umbenennen): wieder farbige Scheiben, keine Fehler. Danach zurück umbenennen.
- [ ] **Handy** (Device-Emulator): volles Belagfeld in Welt 6/7 ohne spürbares Ruckeln.
- [ ] Was in Studio schlecht zu erkennen ist: hier notieren.

## #35 Korrektur: Rebirth-Knopf merkt sich „schon gesehen“

Der Rebirth-Knopf pulsierte in jeder Sitzung neu, sobald ein Rebirth leistbar war. Jetzt nutzt er das gespeicherte Hinweis-System aus #36 wie der Geschenke-Knopf: Hinweis-Id `Rebirth` in `GameConfig.hints`, beim ersten Öffnen schickt der Client `HintSeen("Rebirth")`, der Server merkt es in `seenHints` (bleibt auch nach einem Rebirth). Tests: `tests/Rebirth.spec.luau` („rebirth button hint“) und `tests/GameConfig.spec.luau`.

**Test** (Rojo verbunden, **Play**, 1 Spieler, Tutorial fertig, noch kein Rebirth; Tipp aus #35: vorübergehend `GameConfig.rebirth.startPrice = 100`, **nicht committen**):

- [ ] Genug Münzen: Rebirth-Knopf pulsiert mit „Neu! Mehr Münzen“. Menü öffnen → Pulsieren hört auf, Menü schließen → bleibt ruhig.
- [x] **Rejoin** (Stop, Play) mit weiter genug Münzen: Knopf pulsiert **nicht** mehr. _(belegt: 18./19.11.: pulsiert nicht mehr, Hinweis gespeichert)_
- [ ] Neuer Spielstand (anderer Test-Spieler oder Spielstand löschen): Knopf pulsiert wieder, bis er einmal geöffnet wurde.
- [ ] Geschenke-Knopf verhält sich unverändert (pulsiert nur bis zum ersten Öffnen).
- [x] Output ohne rote Fehler. _(belegt: Output in allen Tests ohne Spiel-Fehler)_

## Studio-Test 17.11.2026 (Phase A + C, lokale Sitzung)

Alle Modell-Importe erledigt: Salami neu, `RoundTree`, `Stations` (4), `Eggs` (15), `Toppings` (19), `Pets` (70). Baseplate gelöscht, Place gespeichert und veröffentlicht. Sound-IDs eingetragen (Effekte von *Pro Sound Effects*, Musik von *APM*, beides offizielle Roblox-Partner, `Rebirth` = Kazoo Fanfare 3, 9114898444). **Anhören konnte ich sie nicht** – bitte einmal reinhören, ob Lautstärke und Auswahl passen. Screenshots: `docs/playtest/19-…` bis `37-…`.

Getestet ohne den Spielstand zurückzusetzen (kein echter Rebirth, kein neuer Spieler). Output ohne rote Fehler, keine `[Save]`-Warnungen, kein „Failed to load sound“.

**Beobachtungen (nicht behoben):**

- **Ei-Vorschau überdeckt das HUD** (`31-ei-vorschau-ueberdeckt-hud.jpg`): Die Vorschau ist ein `BillboardGui` 6 Studs über dem Ei mit fester Pixelgröße. Im kleinen Studio-Fenster (≈ Handy-Höhe) ragt sie oben aus dem Bild; Münzen/Gems liegen über den ersten Pet-Zeilen, und Meldungen („Nicht genug Münzen!“) werden von ihr verdeckt. Steht man vor dem Shop (16 Studs vom Garten-Ei), sind Shop-Menü und Ei-Vorschau gleichzeitig offen. Vorschlag: Vorschau als HUD-Panel über `UiKit.placeMenu` (wie die anderen Menüs) oder ausblenden, solange ein Menü offen ist. Zusätzlich verschiebt das `UIScale` im `root` den Inhalt nach links oben, weil die Billboard-Größe gleich bleibt.
- **Bestenlisten-Tafeln**: funktionieren („Münzen verdient: filipocool 39.072“), aber die Schrift ist im Verhältnis zur Tafel sehr klein; die Tafeln wirken von weitem leer (`23-spawn-insel.jpg`).
- **Steinofen-Ei** wirkt fast komplett goldgelb leuchtend statt terrakotta mit Rissen (`21-eier-welt1.jpg`); Neon evtl. zu stark.
- **Alien-Pilz** (Welt 7) leuchtet sehr stark (Bloom), fast überstrahlt (`30-welt7-belaege.jpg`).
- `LastWorldId` springt nach einem Teleport per Befehlsleiste erst nach > 3 s um (per Portal sofort) – unkritisch.
- Spielstand hat Welt 5–7 noch nicht freigeschaltet; Ei-Stände und Lieferauftrag dort nicht aus der Nähe geprüft (Beläge vom Tor aus sichtbar, Barriere-Schutz setzt korrekt vors Tor zurück).

**Nicht getestet:** Mehrspieler, Device-Emulator/Handy, echter Rebirth (würde den Spielstand zurücksetzen), Rejoin-/Tageswechsel-Fälle, verwaister Session-Lock (#34, Studio hart beenden), Stoppuhr-Balancing (#41), Tutorial als neuer Spieler (#23 Teil 1, #17).

## #31 B5 Welt 2–4 als Inseln (Bauernhof, Strand, Eisberge)

Bauernhof, Strand und Eisberge sind jetzt Inseln im freigegebenen Stil von Welt 1: gleicher Grundriss (`GameConfig.islands.layout`), nur Thema, Rand, Wahrzeichen, Deko und Brücke sind weltspezifisch (`GameConfig.islands.themes`, gebaut von `src/shared/IslandPlan.luau`). Welt 5–7 bleiben im alten Look an der Kette (#32). Kein neuer Modell-Import nötig: Bäume und Deko nutzen die schon importierten Modelle aus `Models/Deco` (#16) und `RoundTree` (#27); ohne Import erscheinen Ersatzteile.

| Welt | Boden/Feld | Rand | Wahrzeichen (hinten links) | Deko | Brücke hinein |
| --- | --- | --- | --- | --- | --- |
| 2 Bauernhof | Wiese, gepflügtes Feld mit Furchen | weißer Holzzaun | Windmühle, rote Scheune auf der rechten Terrasse | Rund- und Obstbäume, Heuballen, Sonnenblumen | Holz-Hängebrücke |
| 3 Strand | Sand | runde Felsbrocken | Leuchtturm (rot-weiß, leuchtende Lampe) | Palmen, Sonnenschirme, Steine, Muscheln, türkise Lagune mit Wasserfall | Holzsteg auf Stelzen mit Handlauf |
| 4 Eisberge | Schnee, hellblaues Feld | Eisblöcke mit Schnee und Eiszacken | Eisberg-Gipfel aus Eisschollen mit Schneekappen | Schneetannen, Schneemänner, Eiskristalle, Eisteich | Eisbrücke (leicht gewölbt, Eisgeländer, Kristallsäulen) |

Vorschau: `assets/previews/islands/World2_Overview.jpg`, `World3_Overview.jpg`, `World4_Overview.jpg`, `World<N>_Landmark.jpg`, `Bridge_Beach.jpg`, `Bridge_Ice.jpg`, `Islands_Chain.jpg`. Vorher: `lune run test` → `0 failed`.

**Play (1 Spieler; Münz-Tipp aus #11 oder vorhandener Spielstand mit Welt 2–4):**

- [x] Output ohne rote Fehler.
- [x] Welt 2–4 sehen aus wie in den Vorschau-Bildern: runder Umriss mit Felskante, Rand im Welt-Stil, Wahrzeichen hinten links, Teich mit Wasserfall rechts vorne, Terrassen mit Stufen begehbar.
- [x] **Brücken:** Welt 1 → 2 Hängebrücke, Welt 2 → 3 Holzsteg, Welt 3 → 4 Eisbrücke. Alle begehbar, kein Stolpern am Übergang Brücke/Insel, seitlich nicht herunterfallen (unsichtbare Wand), Springen hilft nicht.
- [x] **Barrieren-Tore** am Brückenkopf von Welt 2, 3 und 4: leuchtend in Weltfarbe, Preisschild „🔒 Bauernhof / 170 Münzen“ usw.; Freischalt-Knopf erscheint davor; freischalten → Tor passierbar, Schild verschwindet. Mit der vorübergehenden Änderung aus #43 (`requiredRebirths`, **nicht committen**) zeigen die Tore weiter „Ab X Rebirths“.
- [x] **Stationen** in Welt 2, 3 und 4 (gleiche Plätze wie Welt 1): Ofen mit Verkaufszone (Verkaufen + Animation in die Ofenöffnung), **beide Ei-Stände** mit ihren Ei-Modellen (#39/#29, z. B. Bauernhof-Ei und Scheunen-Ei), Portal (Menü, Teleport, Ankunft vor dem Portal), Telefon und Lieferwagen (Auftrag annehmen und abgeben). In Welt 4 der **Große Pizza-Shop** am Shop-Platz links (jetzt in normaler Größe statt 1,5×, damit er nicht in den Ei-Stand ragt) – kaufen klappt.
- [x] **Belag-Modelle (#18)** auf den neuen Feldern gut erkennbar: Zwiebel/Paprika/Mais/Schinken auf dem braunen Acker, Thunfisch/Garnele/Ananas auf hellem Sand, Erbsen/Lachs/Salat auf dem hellblauen Eisfeld. Falls etwas schlecht lesbar ist: Farbe `field` im Theme notieren.
- [x] **Kamera** an jeder Station von Welt 2–4 frei (kein Baum, Zaun, Fels zwischen Kamera und Figur).
- [x] **Rand:** in Welt 2–4 nirgends herunterfallen (Rand ablaufen). Absturz per Command Bar, z. B. Welt 3: `game.Players:GetPlayers()[1].Character:PivotTo(CFrame.new(130, -40, -480))` → Respawn am Spawn der aktuellen Welt (#25). Tod (Reset) in Welt 3 → Respawn in Welt 3.
- [x] Welt-Atmosphäre/Musik wechselt beim Betreten jeder Insel (WorldLooks unverändert); ferne Schilder (Tore, Shop Welt 4) sind aus Welt 1/2 nicht am Himmel zu sehen (SignCulling).
- [x] Deko: Palmen, Schneetannen, Heuballen, Sonnenblumen, Scheune, Schneemänner stehen auf dem Boden (nicht schwebend, nicht im Boden), passende Größe. Leuchtturm-Lampe und Eiskristalle leuchten dezent (nicht überstrahlt).
- [ ] Pets laufen nicht durch Zaun/Felsen/Eisrand und nicht über die Inselkante.
- [ ] **Handy** (Device-Emulator): Welt 2–4 ohne spürbares Ruckeln (viele Rand-Teile), Freischalt-Knopf am Tor antippbar.
- [ ] Was nicht passt (Farben, Größen, Wahrzeichen): hier notieren.

## #32 B6 Welt 5–7 als Inseln (Vulkan, Süßigkeitenland, Weltraum)

Jetzt sind **alle sieben Welten Inseln** im freigegebenen Stil, mit gleichem Grundriss (`GameConfig.islands.layout`). Weltspezifisch sind nur Thema, Rand, Wahrzeichen, Deko und Brücke (`GameConfig.islands.themes`, gebaut von `src/shared/IslandPlan.luau`). Der alte Klassik-Code ist entfernt (`WorldMap.buildClassic`, `WorldDeco.decorateWorld`, `IslandPlan.classicWorld`, `GameConfig.islands.newStyle`). Alle Shops stehen jetzt in normaler Größe, auch der in Welt 7. Ein neuer Modell-Import ist nicht nötig: Die Deko nutzt die schon importierten Modelle aus `Models/Deco` (#16). Ohne Import erscheinen Ersatzteile.

| Welt | Boden/Feld | Rand | Wahrzeichen (hinten links) | Deko | Brücke hinein |
| --- | --- | --- | --- | --- | --- |
| 5 Vulkan | warmer, heller Fels, helles Aschefeld | Basaltsäulen | Stufenvulkan mit leuchtendem Krater und drei Lavaströmen | Lavafelsen, tote Bäume, Lavateich mit Lavafall, 4 Lavarisse | Basaltbrücke (Steinplatten, 3 Lavafugen, Säulen seitlich und darunter) |
| 6 Süßigkeitenland | rosa, Feld mintgrün | Zuckerguss mit Pfefferminz und Gummidrops | Schichttorte mit Guss, Kerzen, Kirsche | Lollis, Cupcakes, Zuckerstangen, Schokoladensee mit Schokofall | Zuckerstangen-Brücke (Waffelplatten, gestreifte Geländer, große Zuckerstangen an den Ecken) |
| 7 Weltraum | heller Mondboden, Feld violett | weiße Mondbasis-Paneele, kleine leuchtende Pfosten-Spitzen | Rakete auf Startrampe mit Service-Turm; Planet schwebt über der rechten Terrasse | Mondfelsen, kleine Kristalle, Sternenlicht-Teich | Leuchtbrücke (helle Metallplatten, je ein Leuchtstreifen an den Kanten, Glas-Paneele) |

Vorschau: `assets/previews/islands/World5_Overview.jpg` bis `World7_Overview.jpg`, `World<N>_Landmark.jpg`, `Bridge_Basalt.jpg`, `Bridge_Candy.jpg`, `Bridge_Light.jpg` und `Islands_FullChain.jpg` (ganze Kette). Die Weltraum-Bilder sind mit Nachthimmel gerendert. Vorher: `lune run test` → `0 failed`.

**Play (1 Spieler; Münz-Tipp aus #11 oder vorhandener Spielstand mit Welt 5–7):**

- [x] Output ohne rote Fehler.
- [x] Welt 5–7 sehen aus wie in den Vorschau-Bildern: runder Umriss mit Felskante, Rand im Welt-Stil, Wahrzeichen hinten links, Teich mit Fall rechts vorne, Terrassen mit Stufen begehbar.
- [x] **Brücken:** Welt 4 → 5 Basaltbrücke, Welt 5 → 6 Zuckerstangen-Brücke, Welt 6 → 7 Leuchtbrücke. Alle begehbar, kein Stolpern am Übergang Brücke/Insel und über die Lavafugen, seitlich nicht herunterfallen (unsichtbare Wand).
- [x] **Barrieren-Tore** am Brückenkopf von Welt 5, 6 und 7: leuchtend in Weltfarbe, Preisschild (z. B. „🔒 Vulkan / 310.000 Münzen“), Freischalt-Knopf davor; freischalten → Tor passierbar. Große Zuckerstangen und Säulen stehen nicht im Tor.
- [x] **Stationen** in Welt 5, 6 und 7 (gleiche Plätze wie Welt 1): Ofen mit Verkaufszone, **beide Ei-Stände** (Vulkan-/Magma-Ei, Süßigkeiten-/Bonbon-Ei, Weltraum-/Nebula-Ei), Portal (Menü, Teleport, Ankunft vor dem Portal), Telefon und Lieferwagen (Auftrag annehmen und abgeben). In Welt 7 der **Riesige Pizza-Shop** am Shop-Platz links, jetzt in normaler Größe (vorher 2×), kaufen klappt, ragt nicht in den Ei-Stand.
- [x] **Belag-Modelle (#18)** auf den neuen Feldern gut erkennbar: Chili/Peperoni/Jalapeño auf dem hellen Aschefeld, Schoko-Stücke/Gummibärchen/Marshmallow auf dem mintgrünen Feld, Mond-Käse/Sternen-Oliven/Alien-Pilz auf dem violetten Feld (nachts). Falls etwas schlecht lesbar ist: Farbe `field` im Theme notieren.
- [x] **Vulkan hell genug (#24):** alles gut erkennbar, Lava (Krater, Risse, Teich, Lavafugen der Brücke) leuchtet, aber nichts überstrahlt.
- [x] **Weltraum nachts:** Leuchtstreifen der Brücke, Pfosten-Spitzen am Rand, Lampen an der Startrampe und Kristalle leuchten dezent, kein Überstrahlen (Bloom). Wenn doch: notieren, welches Teil.
- [x] **Kamera** an jeder Station von Welt 5–7 frei (kein Fels, keine Zuckerstange zwischen Kamera und Figur).
- [x] **Rand:** in Welt 5–7 nirgends herunterfallen (Rand ablaufen). Absturz per Command Bar, z. B. Welt 6: `game.Players:GetPlayers()[1].Character:PivotTo(CFrame.new(130, -40, -1200))` → Respawn am Spawn der aktuellen Welt. Tod (Reset) in Welt 7 → Respawn in Welt 7.
- [x] Deko steht auf dem Boden (nicht schwebend, nicht im Boden), passende Größe: Lavafelsen, tote Bäume, Lollis, Cupcakes, Zuckerstangen, Mondfelsen, Kristalle. Nur der **Planet** schwebt absichtlich über der rechten Terrasse in Welt 7.
- [x] Welt-Atmosphäre/Musik wechselt beim Betreten jeder Insel (WorldLooks unverändert); ferne Schilder (Tore, Shop Welt 7) sind aus Welt 5/6 nicht am Himmel zu sehen (SignCulling).
- [ ] Pets laufen nicht durch Basaltsäulen, Pfefferminz oder Paneele und nicht über die Inselkante.
- [ ] **Handy** (Device-Emulator): Welt 5–7 ohne spürbares Ruckeln, Freischalt-Knopf am Tor antippbar.
- [ ] Was nicht passt (Farben, Größen, Wahrzeichen): hier notieren.

## Studio-Test 18./19.11.2026 (Phase B #33 + offene Punkte vom 17.11.)

Dein echter Spielstand wurde vorher gesichert (DataStore-Schlüssel `backup_18nov_player_372358501`) und am Ende 1:1 wiederhergestellt (76.108 Münzen, 0 Rebirths, Welten bis Eisberge, 9 Pets). Getestet wurde mit einer Kopie, in der alle Welten frei waren. Output: keine roten Spiel-Fehler, keine `[Save]`-Warnungen. Screenshots: `docs/playtest/38-…` bis `59-…`.

**#31/#32 Inseln (alle 7 Welten):** Inseln, Wahrzeichen, Rand-Stile, Teiche, beide Ei-Stände, Ofen, Shop (Welt 4/7 normale Größe), Telefon, Lieferwagen und Portal stehen überall richtig (`38`–`45`). Brücken Basalt/Zuckerstange/Leucht sehen gut aus (`46`, `47`). Die Kamera war an Ofen, Ei, Shop, Telefon, Lieferwagen und Portal in Welt 2–7 überall frei (`48`). **Rand:** An 22 Punkten pro Insel (alle 15°, außer Brückenrichtung) wurde die Figur 2 s mit Schwung nach außen geschoben, in allen 7 Welten: **0 Abstürze**. Brücken-Seitenwände halten auch. **Absturz** unter Welt 6 → zurück an den Spawn von Welt 6; **Tod** in Welt 7 → Respawn in Welt 7. Tore nach Rebirth wieder zu, „🔒 Bauernhof 170 Münzen“ (`55`). Nicht einzeln geprüft: Pets an Zäunen und Felsen, Bildrate auf dem Handy pro Welt.

**2 Spieler** (Server + 2 Clients): Beide starten auf der Spawn-Insel und sehen sich, ohne Fehler. Nicht geprüft: „einer schaltet frei, der andere bleibt stecken“, weil Test-Spieler ohne Münzen starten. Ein neu hinzugefügter Client bekommt eine neue Test-ID (-3), daher Rejoin-Tests mit deinem Konto.

**Neuer Spieler / Tutorial** (Test-Spieler, dein Stand unberührt): Schritt 1 → 2 → 3 klappt, Pizza-Platz Stufe 1 kostet 12, mit 2 Münzen „Nicht genug Münzen!“ und der Schritt bleibt 3/4. Nach **4 Runden** 13 Münzen → Kauf, Pizza 0/3, Schritt 4/4 → Ei öffnen → Tutorial fertig. **Danach** öffnet sich der Login-Kalender von selbst (vorher nicht), und der Geschenke-Hinweis pulsiert erst jetzt (`50`).

**Rejoin:** Login-Serie Tag 3 nach Mitternacht (Tag 1+2 ✓, `51`). Speed-Trank läuft weiter (9:45 → 9:14 nach ~40 s), Lieferauftrag läuft in Echtzeit weiter (2:56 → 2:17), Geschenk-Countdown zählt nur Spielzeit (3:17 → 2:53), der Kalender öffnet nicht noch einmal, Start in der zuletzt besuchten Welt (`52`).

**Echter Rebirth** (mit 5 Mrd in der Test-Kopie): Warnung „Dein laufender Trank endet beim Rebirth!“, Bestätigung, danach Welt 1, Münzen 0, Pizza 0/2, Trank und Auftrag weg, „Rebirth 1! ×1,5 Münzen“, Abzeichen „1“, Pets und Gems bleiben (`53`). Menü danach: „Rebirths: 1“, „×1,5 → ×2“, 14,7 Mrd (`54`). Nach Rejoin bleibt alles, Start in Welt 1. Der Knopf pulsiert nicht, weil er schon einmal geöffnet war (Hinweis gespeichert).

**Handy** (Device-Emulator, Samsung Galaxy A06 800×360): Seitenknöpfe nebeneinander, nichts unter Joystick oder Sprung-Knopf (`56`). Probleme siehe unten.

**Gefundene Probleme (als GitHub-Issues):**

1. **Ei-Vorschau** ragt auf niedrigen Bildschirmen oben aus dem Bild, sodass oft nur „1 öffnen“ am oberen Rand zu sehen ist (`49`). Am Shop ist sie gleichzeitig mit dem Shop-Menü offen; auf dem Handy hängt sie über den Roblox-Knöpfen (`58`). Bestätigt den Befund vom 17.11.
2. **Roblox-Chatfenster** liegt oben links über „Pets“ und „Geschenke“. Fährt man mit der Maus darüber, öffnet sich der Chat und schluckt die Klicks (`59`).
3. **Kleines Handy:** Menüs werden sehr klein, die Schrift ist kaum lesbar (`57`). Das Shop-Menü zeigt nur eine halbe Karte mit abgeschnittenem Kauf-Knopf (`58`). Pets- und Trank-Menü können gleichzeitig offen sein und überlappen sich.

**Kleinigkeiten:** Vulkan-Wahrzeichen wirkt sehr hell, fast wie eine Sandpyramide (`45`). Hinweis: Die Rebirths-Bestenliste kann kurz „1“ für dich zeigen (aus dem Test), bis dein Stand beim nächsten Spielen neu gespeichert wird.

## #45 Ein Licht-Look für alle Inseln

Alle Inseln teilen jetzt einen ruhigen Tag-Look (`src/shared/WorldLooks.luau`), beim Inselwechsel ändert sich nur die Musik.

- [x] Play, von Welt 1 über alle Brücken bis Welt 7 laufen: Himmel, Tageszeit, Helligkeit und Wolken bleiben gleich, kein Umschalten oder Aufblitzen an den Brücken. Die Musik wechselt weiterhin pro Insel.
- [x] Strand- und Eis-Insel (auch von Nachbarinseln aus gesehen): kein heller „Filter“, weißer Sand und Schnee strahlen nicht (kein Bloom-Schein).
- [x] Neon (Lava, Weltraum-Leuchtteile, Portale) leuchtet auf allen Inseln gleich stark. Leuchtet Neon gar nicht mehr, `bloom.threshold` in `WorldLooks` schrittweise senken (aktuell 2,8), solange Sand und Schnee nicht anfangen zu strahlen.
- [ ] Raus- und Reintabben ändert am Look nichts mehr.
- [x] Welt 7 (Weltraum) ist jetzt auch Tag: prüfen, ob es lesbar aussieht.

## #46 Kein Flackern an Inselrändern

Klippenblöcke einer Schicht haben jetzt gestaffelte Oberkanten und minimal versetzte Außenflächen, die oberste Klippe ragt 0,06 Studs über den Inselrand (deckt die Seitenfläche der Bodenplatte ab). Dünne Bodenschichten liegen mindestens 0,1 Studs auseinander (Feld 0,1 · Furchen/Lava-Risse 0,2 · Wegplatten 0,3 · Teich 0,4 · Bach 0,5 über dem Boden).

- [ ] Auf jeder Insel am Rand entlanglaufen und die Kamera drehen: Klippenkante und Grasrand flackern nicht mehr (kein Farbwechsel zwischen Fels-Tönen, kein Gras/Fels-Zucken an der Bodenkante).
- [ ] Aus der Ferne (z. B. von der Spawn-Insel oder einer Brücke) auf die Nachbarinseln schauen: Felsringe flackern nicht.
- [ ] Feld (Welt 1–7, Furchen auf dem Bauernhof), Wegplatten, Teich mit Bach und Lava-Risse (Vulkan) flackern auch aus der Ferne nicht.
- [ ] Optik sonst unverändert: Klippe wirkt nicht stufig, Wegplatten/Teich stehen nicht sichtbar hoch, Figuren laufen normal über Weg und Feld.

## #47 Vulkan als dunkler Basaltkegel

Das Vulkan-Wahrzeichen (Welt 5) ist jetzt ein zulaufender Kegel aus 11 dunklen Basaltscheiben (konkave Flanke, breiter Kraterrand), drei Neon-Lavaströme laufen über die Kanten bis zum Boden, die Kraterlava bleibt, aus dem Krater steigt Rauch (ParticleEmitter am unsichtbaren Teil `VolcanoSmoke`). Vorschau: `assets/previews/islands/World5_Landmark.jpg`.

- [x] Vulkan-Insel ansehen: Vulkan wirkt dunkel (Basalt), nicht mehr wie eine helle Sandpyramide; die drei Lavaströme liegen sichtbar auf den Flanken (keine Lücken oder Schweben) und reichen bis zum Boden.
- [x] Kraterlava leuchtet wie bisher, Rauch steigt langsam aus dem Krater und verweht; Rauch wirkt nicht zu dicht und kostet keine spürbaren FPS.
- [ ] Lavaströme und Kegel flackern nicht (auch nicht aus der Ferne), Felsbrocken am Fuß stehen sauber auf dem Boden, Weg/Treppe am Vulkan sind frei.
- [ ] Inselrand (#46) flackert weiterhin nicht.

## #48 Weniger Leuchten bei Fancy-Eiern und Alien-Pilz

Die Fancy-Zweit-Eier ohne `glow` haben kein Neon mehr (Muster matt, Goldband bleibt Metal); Vulkan- (`MagmaEgg`) und Weltraum-Ei (`NebulaEgg`) behalten ihr Neon. Alien-Pilz: Hut matt grün (`Top_3CC864`), nur die violetten Punkte sind Neon (`Top_B45AFF_Neon`). Vorschau: `assets/previews/eggs/FancyDemo.png`, `assets/previews/toppings/AlienMushroom.png`.

- [x] Import: `assets/models/eggs/BarnEgg.fbx`, `BonbonEgg.fbx`, `GlacierEgg.fbx`, `ShellEgg.fbx`, `StoneOvenEgg.fbx` und `assets/models/toppings/AlienMushroom.fbx` neu importieren (alte Modelle in `ReplicatedStorage.GameAssets.Models` ersetzen, gleiche Namen, Teilnamen mit Farbe/Material beibehalten).
- [x] Steinofen-Ei (Welt 1) wirkt warm und besonders, ohne grelles goldgelbes Leuchten; Goldband glänzt metallisch. Gleiches bei Scheunen-, Muschel-, Gletscher- und Bonbon-Ei.
- [x] Vulkan- und Weltraum-Eier leuchten weiterhin.
- [x] Alien-Pilz (Welt 7, Feld und Pizza): Hut matt grün, überstrahlt nicht; nur die kleinen violetten Punkte leuchten.

## #49 Neue Münze und neuer Gem

Münz- und Gem-Icon kommen jetzt aus einem gemeinsamen Baustein (`UiKit.coinIcon` / `UiKit.gemIcon`, nur GUI-Elemente mit UIGradient/UIStroke): Goldmünze mit Rand und eingeprägter Pizza-Ecke, facettierter türkiser Diamant mit Glanzlicht. In 3D: neue Modelle `Coin` (springen beim Verkauf aus dem Ofen) und `Gem` (Feld-Gems), gebaut mit `tools/blender/build_currency.py`. Vorschau: `assets/previews/Coin.png`, `Gem.png`, `Currency.png`.

- [x] Import: `assets/models/Coin.fbx` und `assets/models/Gem.fbx` nach `ReplicatedStorage.GameAssets.Models` importieren (Namen `Coin` und `Gem`, Teilnamen `CoinGold`/`CoinRim`/`CoinEmboss` bzw. `GemLight`/`GemMid`/`GemDark`/`GemShine` beibehalten).
- [x] ~~Vor dem Import: beim Verkaufen springen goldene Scheiben aus dem Ofen, Feld-Gems sind die gekippten Neon-Würfel wie bisher (nichts fehlt, keine Fehler im Output).~~ _(entfällt: Import am 20.11. erledigt)_
- [ ] HUD oben: Münze zeigt Goldrand, Pizza-Ecke mit Rand und drei Punkten; Gem ist ein Diamant mit hellen/dunklen Facetten und weißem Glanz. Beides scharf und nicht verrutscht auf PC und kleinem Handy (Device-Emulator); Zahlen stehen daneben wie vorher.
- [x] Verkaufen am Ofen: 4 3D-Münzen springen drehend aus dem Ofen und verschwinden, die fliegenden Münz-Icons zum Zähler sehen aus wie die HUD-Münze.
- [x] Nach dem Import: Verkaufs-Münzen zeigen das Blender-Modell (Pizza-Ecke auf beiden Seiten, Scheibe unsichtbar), Feld-Gems stehen aufrecht als Diamant über dem Boden, funkeln und leuchten weiter, lassen sich wie vorher einsammeln (auch per Magnet/Auto-Sammeln).

## #50 Feste Belohnungen in Geschenken und Kalender

Geschenke und Login-Kalender geben nur noch feste Gems und Tränke, keine Münzen (Geschenke: 3 Gems / 5 Gems / 1 Trank / 1 Trank / 8 Gems / 10 Gems + 1 Trank; Kalender: 5 Gems / 10 Gems / 1 Trank / 1 Trank / 20 Gems / 2 Tränke / 50 Gems + 3 Tränke). Zum Ausgleich kosten Bauernhof 120 (vorher 170) und der erste Rebirth 3,9 Mrd (vorher 4,9 Mrd). Details: `docs/balancing.md`.

- [x] Geschenke-Menü: alle sechs Zeilen zeigen „3 Gems“, „5 Gems“, „1 Trank“, „1 Trank“, „8 Gems“, „10 Gems + 1 Trank“; nirgends „Münzen“.
- [x] Geschenk abholen (5 Min): Meldung „Geschenk! +3 Gems“, Gem-Zähler +3, Münzen unverändert. Trank-Geschenk: Meldung nennt den gezogenen Trank (z. B. „1× Glücks-Trank“), er liegt im Trank-Inventar. _(belegt: 20.11.: „Geschenk! +1× Glücks-Trank“ (`70`))_
- [x] Login-Kalender: Kacheln Tag 1–7 zeigen die neuen Belohnungen (Tag 1 „5 Gems“, Tag 4 „1 Trank“); Abholen an Tag 1 gibt +5 Gems und keine Münzen. _(19.11.: Tag 1 → +5 Gems, keine Münzen)_
- [ ] Gleiche Anzeigen in Welt 1 und nach Freischalten späterer Welten bzw. mit starken Pets (Belohnung ändert sich nicht).
- [x] ~~Bauernhof-Tor zeigt 120 Münzen, Rebirth-Menü 3,9 Mrd als ersten Rebirth-Preis.~~ _(entfällt: seit #57 Bauernhof 26, Rebirth 74 Mio)_

## #51 Pet-Deckel pro Welt und Rebirth-Tempo

Entfällt: Der Pet-Deckel wurde in #57 wieder entfernt (siehe Abschnitt #57).

## #52 Seitenknöpfe unter den Chat

Die runden Seitenknöpfe (Pets, Tränke, Geschenke, Rebirth) beginnen jetzt bei halber Bildschirmhöhe und enden über dem Joystick (Zone `sideArea` in `HudLayout`). Auf niedrigen Bildschirmen ist die Zone mindestens eine Knopfreihe hoch, die Knöpfe stehen dann nebeneinander; auf hohen Bildschirmen untereinander, bei Platzmangel in weiteren Spalten.

- [x] PC: Chat öffnen (oben links), alle vier Seitenknöpfe liegen unter dem Chatfenster und reagieren auf Klicks (Pets-, Trank-, Geschenke-, Rebirth-Menü öffnen sich).
- [ ] Tutorial-Karte steht weiter oben links und überdeckt keinen Seitenknopf.
- [ ] Device-Emulator Handy (z. B. iPhone SE quer und ein großes Handy): alle vier Knöpfe sichtbar und antippbar, keiner im Joystick-Bereich, keiner über Pizza-Leiste, Auto-Sammeln oder Freischalt-Knopf; Chat geöffnet verdeckt keinen Knopf.
- [ ] Tablet/4K-Fenster: Knöpfe stehen in einer Spalte ab Bildschirmmitte, Reihenfolge Pets, Tränke, Geschenke, Rebirth.

## #53 Nur ein Menü gleichzeitig

Alle Menüs (Shop, Portal, Pets, Tränke, Geschenke, Rebirth, Login-Kalender, Telefon) melden sich bei der Menü-Verwaltung in `UiKit` an. Öffnet sich eins, schließen sich die anderen wie mit „X“.

- [x] Pets-Menü offen, dann Tränke-Knopf: Pets-Menü schließt sich, nur das Trank-Menü ist offen. Genauso Geschenke und Rebirth untereinander.
- [x] Geschenke → „📅 Kalender“: nur der Kalender ist offen.
- [x] Im Shop stehen (Shop offen), Pets-Knopf drücken: Shop schließt sich und geht nicht wieder auf, solange man im Shop steht (auch nicht beim Kaufen/Sammeln). Shop verlassen und wieder betreten: Shop öffnet sich, Pets-Menü schließt sich.
- [ ] Im Portal stehen, „X“ drücken, Münzen sammeln lassen: Portal-Menü bleibt zu. Dasselbe nach Öffnen des Pets-Menüs. Portal verlassen und wieder betreten: Portal-Menü öffnet sich.
- [ ] Pets-Menü offen, dann in den Shop bzw. ans klingelnde Telefon laufen: Pets-Menü schließt sich, Shop bzw. Telefon-Auftrag ist offen.
- [x] Output: keine Fehler beim Öffnen/Schließen.

## #54 Ei-Vorschau als Panel rechts im HUD

Die Ei-Vorschau ist kein 3D-Schild über dem Ei mehr, sondern ein Panel rechts (Zone `eggPreview`). Es öffnet sich am nächsten Ei, schließt beim Weggehen und zählt als Menü.

- [x] Ans Ei laufen: Panel rechts unter der Top-Leiste, Ei und Figur bleiben in der Mitte sichtbar, kein Schild mehr über dem Ei. Weggehen: Panel schließt.
- [x] Zwischen den zwei Eiern einer Welt hin und her: Panel zeigt jeweils das nähere Ei (Titel, Pets, Preis wechseln).
- [ ] PC mit niedrigem Fenster (z. B. 1280 × 600): Panel ragt nicht aus dem Bild, „1 öffnen“/„3 öffnen“ ganz sichtbar, die Pet-Liste scrollt statt abzuschneiden.
- [ ] Device-Emulator (kleines Handy quer, z. B. iPhone SE): Panel liegt nicht über den Roblox-Knöpfen oben und nicht über dem Sprung-Knopf, Knöpfe sind bedienbar.
- [ ] Glückstrank aktiv: Titel „🍀 Glück!“, Chancen grün. Nach dem Gem-Upgrade „3 öffnen“ sichtbar. Während der Animation reagiert der Knopf nicht; mit zu wenig Münzen erscheint „Zu wenig Münzen!“ rot am Knopf.
- [x] Pet-Bilder in den Zeilen, Pet-Namensschilder am Ei ausgeblendet.
- [ ] Trank aktiv und Auftrag läuft: am Ei sind Trank-Pillen und Auftragskarte weg, nach dem Weggehen wieder da.
- [x] Pets-Menü öffnen, während das Panel offen ist: Panel schließt und bleibt zu, solange man am Ei steht; weggehen und wieder hin: Panel öffnet, Pets-Menü schließt.
- [x] Am Shop mit Ei in der Nähe: nie Shop und Panel gleichzeitig offen.
- [x] Output: keine Fehler.

## #55 Handy-Modus für Menüs

Auf kleinen Bildschirmen (kurze Seite des Viewports unter 500 px) füllen Menüs fast den ganzen Bildschirm, werden nie unter 85 % skaliert und scrollen stattdessen (ganzes Panel scrollt, wenn es nicht passt). Der Shop zeigt mindestens einen Abschnittskopf plus eine ganze Karte. Das Ei-Panel beginnt neben dem Gem-Zähler und ist schmaler.

- [ ] Device-Emulator, kleines Handy quer (iPhone SE): Shop, Portal, Pets, Tränke, Geschenke, Rebirth, Login-Kalender und Telefon-Auftrag nacheinander öffnen. Jedes Menü füllt fast den Bildschirm, Text gut lesbar, nichts abgeschnitten; wo es nicht passt, lässt sich das Menü bzw. die Liste scrollen, „X“ bleibt erreichbar.
- [x] iPhone SE quer, Shop: mindestens eine ganze Karte mit vollem Kauf-Knopf sichtbar; kaufen klappt; Liste scrollt.
- [ ] iPhone SE quer: Pets-Menü offen, Tränke-Knopf drücken → nur das Trank-Menü offen, keine Überlappung (und umgekehrt).
- [x] iPhone SE quer, ans Ei laufen: Ei-Panel rechts neben dem Gem-Zähler, lesbar, „1 öffnen“ ganz sichtbar, nicht über dem Sprung-Knopf; Figur und Ei in der Mitte sichtbar.
- [ ] Hochformat (iPhone SE hochkant) kurz prüfen: Menüs passen in die Breite, nichts ragt aus dem Bild.
- [ ] Tablet (z. B. iPad quer): normales Layout wie bisher (Menüs unter Währungen, über dem Pizza-Balken), nichts scrollt unnötig.
- [ ] Gerät drehen bzw. im Emulator zwischen Handy und PC wechseln: Menüs passen sich an, keine Reste eines Scrollbalkens bei geschlossenem Menü.
- [x] Output: keine Fehler.

## #57 Flache Pet-Kurve, neue Preise, kein Pet-Deckel

Pets steigen pro Welt gleichmäßig (bestes Pet Welt 1: +75 %, … Welt 7: +500 %), jedes Pet zählt überall voll. Alle Münzpreise sind neu (Bauernhof 26, Strand 690, Eisberge 12.000, Vulkan 35.000, Süßigkeitenland 900.000, Weltraum 12 Mio, erster Rebirth 74 Mio, jeder weitere ×14, seit #58 ×1,5). Ziel laut Simulator: erster Rebirth nach etwa 120 Minuten. Details: `docs/balancing.md`.

- [x] Neuer Spielstand (oder Daten zurücksetzen), Welt 1 mit Stoppuhr: Tutorial → Shop-Käufe → Bauernhof-Schranke (26) in etwa 6 Minuten. Fühlt sich das Tempo richtig an? Schranken-Preis-Schild zeigt den neuen Preis.
- [ ] Weiter bis Welt 3–4 spielen: Welt 2 etwa 9, Welt 3 etwa 12 Minuten; Shop-Preise und Ei-Preise am Schild/Panel passen zur Config (z. B. Hof-Ei 48, Scheunen-Ei 240).
- [x] Pet-Menü: Karten zeigen nur den normalen Bonus (z. B. „+75 %“), kein „hier“ und kein Gold-Text mehr; Kopfzeile „Bonus +X %“ ändert sich beim Gang in eine andere Welt nicht.
- [ ] „Beste ausrüsten“ in Welt 1 mit Pets aus späteren Welten: rüstet die Pets mit dem höchsten Bonus aus (späte Pets vorn).
- [ ] Verkauf am Ofen in Welt 1 und Welt 2 mit gleichen Pets und gleicher Pizza: gleicher Multiplikator (nur der Belagwert unterscheidet sich). Lieferauftrag: HUD-Belohnung = gezahlte Münzen.
- [x] Alter Test-Spielstand mit Rebirth: lädt ohne Fehler, alle Pets da, Boni zeigen die neuen kleineren Werte (z. B. Galaxie-Pizza-Leviathan +500 %). Rebirth-Menü zeigt den neuen Preis (74 Mio, Faktor seit #58 ×1,5 je Rebirth).
- [x] Optional nach einem Rebirth: Welt 1 geht sehr schnell (Simulator: unter 1 Minute, Ziel 3 wurde nicht erreicht, siehe `docs/balancing.md`). Eindruck notieren: zu schnell?
- [x] Output: keine Fehler.

## #58 Flacherer Rebirth-Preis

Jeder weitere Rebirth kostet nur noch ×1,5 so viel wie der vorige (vorher ×14): 74 Mio · 111 Mio · 166,5 Mio · 249,75 Mio. Simulator: zweiter Durchlauf bis zum zweiten Rebirth ≈ 45 Minuten (Welt 1–6 ≈ 21, Welt 7 ≈ 24). Details: `docs/balancing.md`.

- [x] Test-Spielstand mit 1 Rebirth: Rebirth-Menü zeigt 111 Mio als Preis (mit 0 Rebirths: 74 Mio, mit 2: 166,5 Mio).
- [ ] Optional nach einem Rebirth mit Stoppuhr: Welt 1–6 in etwa 20 Minuten, danach Welt 7 bis zum zweiten Rebirth in etwa 25 Minuten. Eindruck notieren.
- [x] Output: keine Fehler.

## Studio-Test 20.11.2026 (Version 1: #45–#58)

Importiert: 5 Fancy-Eier und Alien-Pilz neu, `Coin` und `Gem` (Teilnamen wie vorgesehen). Place gespeichert und veröffentlicht. Dein Spielstand war vorher gesichert (`backup_20nov_player_372358501`) und ist am Ende 1:1 wiederhergestellt (104.346 Münzen, 0 Rebirths, Welten bis Eisberge). Output ohne Spiel-Fehler. Screenshots: `docs/playtest/60-…` bis `77-…`.

**Behoben:**

1. **#45 heller Schleier:** In `Lighting` lagen noch Bloom (Schwelle 2), Atmosphere, SunRays und DepthOfField der Studio-Vorlage, *zusätzlich* zu unseren `World…`-Effekten. Der zweite Bloom ließ Sand und Schnee strahlen. `WorldAmbience` entfernt jetzt fremde Effekte beim Start (lokal). Danach liegen nur noch `WorldAtmosphere/WorldBloom/WorldColor/WorldSunRays` und `Sky` da (`60`, `61`).
2. **#54 Ei-Panel ging am Shop nicht auf:** Der Shop-Bereich liegt ~17 Studs vom Nachbar-Ei. Das Panel öffnete schon bei 20 Studs, wurde vom Shop sofort geschlossen und blieb zu, bis man >20 Studs weg war. Jetzt öffnet das Panel erst ab 14 Studs und schließt bei 20 (`OPEN_DISTANCE` in `EggPreview`). Vom Shop zum Ei → Panel öffnet (`75`).
3. **Hinweis-Blase über dem Rebirth-Knopf:** Wenn die Seitenknöpfe in einer Reihe stehen (#52), lag „Neu! Geschenke fürs Spielen“ (und „Neu! Mehr Münzen“) auf dem Nachbar-Knopf. Neue Hilfe `UiKit.placeSideNote`: In einer Reihe sitzt die Blase über dem Knopf, in einer Spalte wie bisher rechts (`76`).

**Funktioniert:** Ein Licht-Look auf allen Inseln, Welt 7 bei Tag gut lesbar (`63`). Vulkan als dunkler Basaltkegel mit Lava und Rauch (`62`). Steinofen-/Bonbon-Ei matt, Vulkan-Ei leuchtet (`65`, `66`). Alien-Pilz matt grün (`64`). Neue Münz-/Gem-Icons, 3D-Münzen beim Verkauf, Feld-Gem als Diamant (`67`). Geschenke/Kalender nur Gems und Tränke, „Geschenk! +1× Glücks-Trank“ (`70`). Chat offen → Seitenknöpfe darunter und klickbar (`68`). Immer nur ein Menü offen, Shop bleibt nach Pets zu (`69`, `72`). Ei-Panel rechts, wechselt zwischen den Eiern, Pets schließt es (`71`). Handy (iPhone 7, 667×375): Pets füllt den Bildschirm und ist lesbar, Shop zeigt zwei ganze Karten mit vollem Kauf-Knopf (`73`, `74`). Rebirth-Menü: 111 Mio bei 1 Rebirth; nach Rebirth 2: „×2 → ×2,5“, Preis 166,5 Mio (`77`).

**Balancing (Bot mit Teleport-Runden, 2 Runden ≈ 1 Minute laut Simulator):**

- Neuer Spieler, Welt 1: 12 Münzen nach 4 Runden, Ei nach 9, **Bauernhof (26) nach 13 Runden ≈ 6,5 Min** (Simulator ≈ 6) ✓.
- Welt 2 bis Strand (690): **26 Runden ≈ 13 Min** (Simulator ≈ 9). Der Bot hat dort keine Eier geöffnet und nur Shop-1-Upgrades gekauft, echte Spieler sind eher schneller.
- Nach Rebirth 2 (Bonus nur +54 %): **Bauernhof nach 3 Runden ≈ 1,5 Min.** → **Deine Entscheidung:** Ist der Neustart nach einem Rebirth zu schnell? (Simulator-Ziel waren 3 Min.)

**Hinweise / offen:**

- Tablet (iPad 1180×820): Die Seitenknöpfe stehen in **einer Reihe** auf halber Höhe, nicht in einer Spalte wie in #52 beschrieben (ab Bildschirmmitte bis zum Joystick ist nur Platz für eine Reihe). Sieht ordentlich aus, ist aber nicht wie in der Checkliste.
- Der Rebirth-Preis wird ab 100 Mio ohne Komma gekürzt („166 Mio“ statt 166,5 Mio). Das ist so gewollt (`UiKit.shortNumber`).
- Nicht geprüft: Flackern an Inselrändern in Bewegung (auf Standbildern nichts zu sehen), Rauch-FPS, Raus-/Reintabben, Hochformat, Gerät drehen, Welt 3 mit Stoppuhr, Lieferauftrag-Belohnung = Auszahlung, „Beste ausrüsten“ mit späten Pets.

## #60 Verkaufs- und Shop-Zone als Bodenmarkierung

- [x] Ofen in **allen Welten**: kein orangener Kraftfeld-Kasten mehr, sondern flache, leicht durchsichtige orange Fläche mit hell leuchtendem Rand und Schrift „VERKAUFEN“.
- [x] Alle Shops (auch die größeren in späteren Welten): flache grüne Fläche mit leuchtendem Rand und „SHOP“, kein Kasten mehr.
- [x] Schrift ist lesbar, wenn man von vorne auf Ofen/Shop zuläuft (nicht auf dem Kopf). Falls doch: in `src/server/GroundMarker.luau` die Drehung `CFrame.Angles(0, math.pi, 0)` der `MarkerPlate` entfernen.
- [ ] Verkaufen klappt genau im markierten Bereich wie vorher (auch an den Rändern), Shop-Menü geht im selben Bereich auf und beim Verlassen zu.
- [ ] Kein Flackern zwischen Markierung und Boden/Wegplatten (Kamera flach halten, auch in Bewegung).
- [x] Figur läuft normal über die Markierung (kein Stolpern/Hochsteigen), Klicks und Kamera gehen durch.

## #59 Telefon klingelt nur kurz und lässt sich ausschalten

Vorher: `lune run test` → `540 passed, 0 failed`.

Studio: Rojo verbinden, **Play** (Tutorial fertig, sonst klingelt nichts):

- [x] Telefon klingelt nach der Ruhezeit: Klingelton nur **3-mal** (ca. 10 s), danach still. „RING!“-Blase und HUD-Karte „Das Telefon klingelt!“ bleiben, bis man annimmt/ablehnt.
- [x] Beim nächsten Anruf klingelt es wieder 3-mal.
- [x] Am Telefon: oben rechts grauer Knopf „📵 Keine Anrufe mehr“ (Titel nicht überdeckt, auch auf dem Handy-Emulator). Drücken → Meldung „Keine Anrufe mehr…“, Blase und HUD-Hinweis verschwinden, Menü zeigt „📵 Anrufe sind aus“ mit grünem „📞 Anrufe einschalten“.
- [x] Weggehen und wieder ans Telefon → „Anrufe sind aus“-Menü erscheint erneut; mehrere Minuten warten → kein Klingeln.
- [x] Mit laufendem, angenommenem Auftrag ausschalten → Auftragskarte bleibt, Lieferung klappt. _(21.11.: ausschalten jetzt jederzeit möglich, Karte bleibt; Lieferung danach nicht einzeln geprüft)_
- [x] „Anrufe einschalten“ → Menü schließt, Meldung „Anrufe sind wieder an.“, nach ca. 2 Min klingelt es wieder.
- [x] Ausgeschaltet → Rejoin (DataStore an) → Anrufe bleiben aus. Nach einem Rebirth bleiben sie ebenfalls aus.
- [x] Anderes Menü öffnen, während „Anrufe sind aus“ offen ist → Telefon-Menü schließt (#53).
- [x] Output ohne rote Fehler.

## Studio-Test 21.11.2026 (#59, #60)

Dein Spielstand war vorher gesichert (`backup_21nov_player_372358501`) und ist danach wiederhergestellt (143.422 Münzen). Für den Test lag die Anruf-Pause vorübergehend bei 20 s statt 150 s (nicht committet). Output ohne Spiel-Fehler. Screenshots: `docs/playtest/78-…` bis `84-…`.

**#60 behoben:** Die Schrift „VERKAUFEN“/„SHOP“ stand um 90° gedreht (lief vom Spieler weg, `81`). Die Platte in `GroundMarker` ist jetzt um 90° statt 180° gedreht (Breite und Tiefe getauscht, Fläche gleich). Die Schrift läuft quer und steht richtig herum, wenn man vom Weg kommt (`82`, `83`, auch Welt 4/7 `84`). Ränder leuchten, keine Kästen mehr. Verkaufen und Shop öffnen klappen wie vorher (Zonen unverändert). Nicht geprüft: Flackern in Bewegung, Verkaufen genau am Rand.

**#59:** Beim Beitreten klingelt es und ist danach still, Blase und HUD-Karte bleiben. Der nächste Anruf kam 18 s nach dem Ablehnen (Testwert 20 s). Die 3 Klingeltöne konnte ich nicht hören; laut Code (`RINGS_PER_CALL = 3`, alle 3 s, Neustart pro Anruf) stimmt es, und nach dem ersten Klingeln kam kein weiterer Ton. „📵 Keine Anrufe mehr“ sitzt oben rechts, der Titel ist frei (`78`). Ausschalten → Meldung, Blase und Hinweis weg, Menü „Anrufe sind aus“ (`79`). Weg und zurück → Menü wieder da; 45 s kein Klingeln. Pets-Knopf schließt das Telefon-Menü. Rejoin → bleibt aus. Rebirth → bleibt aus. Einschalten → „Anrufe sind wieder an.“, Klingeln nach der Pause (`80`).

**Nachtrag (deine Entscheidung: jederzeit ausschaltbar):** Am Telefon erscheint jetzt auch ohne Anruf ein Menü „📞 Telefon – Gerade kein Anruf …“ mit „📵 Keine Anrufe mehr“ (nicht während des Tutorials). Getestet: Auftrag annehmen, weg und zurück → Menü da (`85`); ausschalten → „Anrufe sind aus“, Auftragskarte läuft weiter (`86`). Nicht geprüft: der Knopf im Handy-Emulator.

## Handy: Seitenknöpfe als 2 × 2-Block, Münzen ganz oben (#62)

Auf dem echten Handy ragten die vier Seitenknöpfe in einer Reihe zur Bildschirmmitte, und Münz-/Gem-Anzeige saßen unter der Roblox-Leiste recht tief. Jetzt: auf kleinen Bildschirmen (kurze Seite < 500 px) kleinere Knöpfe (72 px) als 2 × 2-Block links direkt über dem Joystick (Pets/Tränke links, Geschenke/Rebirth rechts); Münzen und Gems in einer eigenen Ebene knapp unter dem oberen Bildschirmrand (auf allen Geräten). Vorher: `lune run test` → `541 passed, 0 failed`. Danach **File → Publish to Roblox**, dann auf dem Handy prüfen.

- [x] Handy quer: Seitenknöpfe als 2 × 2-Block links über dem Joystick, nicht über dem Joystick, gut antippbar; „Neu!“-Hinweise verdecken keinen Knopf. _(20.11.: auf dem echten Handy geprüft, passt)_
- [x] Handy quer: Münz- und Gem-Anzeige knapp unter dem oberen Rand, nicht über den Roblox-Knöpfen (links/rechts oben) und nicht in der Notch; Zahlen lesbar. _(20.11.: auf dem echten Handy geprüft, passt)_
- [x] Verkaufen: fliegende Münzen landen weiterhin an der Münzanzeige (PC und Handy). _(20.11.: auf dem echten Handy geprüft, passt)_
- [x] PC/Tablet: Seitenknöpfe wie bisher (ab halber Höhe), Münzen/Gems oben Mitte knapp unter dem Rand, nicht über Roblox-Menü oder Chat-Knopf. _(20.11.: auf dem echten Handy geprüft, passt)_
- [x] Meldungen („+X Münzen“), Tutorial-Karte und Ei-Panel überlappen die Münz-/Gem-Anzeige nicht. _(20.11.: auf dem echten Handy geprüft, passt)_

## Zählung (Aufräumen 19.11.2026)

Von 353 offenen Punkten: **52 entfallen** (überholt durch spätere Änderungen, durchgestrichen), **61 abgehakt** (durch spätere Studio-Tests belegt), **240 weiterhin offen**. Dazu kommen 35 offene Punkte in der Release-Checkliste oben.

## #61 Icon und Thumbnails für die Spielseite

Bilder liegen in `docs/store/` (neu rendern: `python tools/blender/render_store.py`, Aufruf siehe Kopf des Skripts):

| Datei | Größe | Wofür |
| --- | --- | --- |
| `Icon.png` | 512 × 512 | Spiel-Icon (Pizza-Drache mit Pizza vor dem Ofen, ohne Text) |
| `Thumbnail1_Collect.png` | 1920 × 1080 | Thumbnail 1: Sammeln und Verkaufen in Welt 1 |
| `Thumbnail2_Islands.png` | 1920 × 1080 | Thumbnail 2: Inselkette mit allen 7 Welten |
| `Thumbnail3_Pets.png` | 1920 × 1080 | Thumbnail 3: Eier und Pets, Galaxie-Drache hervorgehoben |

Hochladen (Spiel muss veröffentlicht sein):

- [ ] Studio: **Home → Game Settings → Basic Info**. Bei **Game Icon** auf das Icon-Feld klicken → `docs/store/Icon.png` wählen.
- [ ] Im selben Fenster bei **Thumbnails** die drei Thumbnails in der Reihenfolge 1 → 2 → 3 hinzufügen (Reihenfolge per Ziehen anpassen, Thumbnail 1 zuerst). **Save** drücken.
- [ ] Alternativ im Creator Hub (create.roblox.com → Creations → Spiel → Basic Info / Places-Einstellungen), falls Studio den Upload verweigert.
- [ ] Nach der Moderation (kann ein paar Minuten dauern) die Spielseite öffnen: Icon in der Spieleliste erkennbar, Thumbnails in der richtigen Reihenfolge, Titel nicht abgeschnitten.
- [ ] Wird ein Bild abgelehnt: Grund notieren und als Issue melden (dann neu rendern).

## Studio-Test 24.11.2026 (Englisch #67–#71)

Dein Spielstand war vorher gesichert (`backup_24nov_player_372358501`) und ist danach wiederhergestellt (107.344 Münzen). Das `Language`-Attribut ist wieder gelöscht. Output ohne Spiel-Fehler, `lune run test` → `561 passed, 0 failed`. Screenshots: `docs/playtest/87-…` bis `108-…`.

**Behoben:**

1. **Geschenke-Menü:** Der Untertitel „Spiel jeden Tag – …“ / „Play every day – …“ lag unter dem Kalender- und dem Schließen-Knopf (in beiden Sprachen, `91`). Er steht jetzt darunter, das Menü ist 24 px höher (`104`).
2. **Shop-Meldung:** „Bought: Speed Potion! – drink it in the potion menu“ lief in den Schließen-Knopf (`94`). Die Statuszeile endet jetzt vor dem Knopf (`105`).

**Englisch:** Kein deutscher Text gefunden in HUD, Kalender, Pets, Tränken, Geschenken, Rebirth, Shop, Ei-Panel, Pet-Karte, Portal, Telefon, Auftrag, Toasts, Schildern und Pet-Namen. Zahlen „107,344“, „900,000“, „74M“, „×1.5“; Deutsch „107.359“, „74 Mio“, „×1,5“.

**Nicht geprüft:** ~~Tutorial, Rebirth-Bestätigung und -Feier, „Delivered!“, Bestenlisten~~ (Nachtest unten), Bestenlisten-Refresh nach 2 Min., Tor mit Rebirth-Sperre, Flackern der Schilder in Bewegung, Deutsch am PC ohne Handy-Emulator nur teilweise (Handy-Ansicht und 2-Spieler-Test).

**Nachtest 24.11.2026 (Clients and Servers, 1 Spieler, `Language` = `en`):** Test-Spieler `player_-1` mit frischem Spielstand (vorher gesichert als `backup_24nov_player_-1`, am Ende zurückgeschrieben); dein Spielstand blieb unberührt (107.344). Für den Rebirth bekam der Test-Spieler 80 Mio Münzen direkt in seinen Spielstand (nur Testwert, kein Code). Attribut wieder gelöscht, Output ohne Fehler. Screenshots `109-…` bis `123-…`.

- Tutorial komplett auf Englisch: „Tutorial – step 1/4“ … „4/4“ mit allen Schritt-Texten, Ende „Tutorial complete! / Have fun topping pizzas! New worlds await behind the barriers.“, Pet-Karte „Dough Hamster / Common / +3 % coins / Tap to close“ (`109`–`113`). Hinweis: Schritt 1 heißt jetzt „Collect 2 toppings“ (`tutorial.collectToppings = 2`), nicht 10 wie in #69 notiert.
- **Behoben:** Der Login-Kalender sprang direkt beim Tutorial-Ende auf, zeitgleich mit der ersten Pet-Karte und „Tutorial complete!“. Er öffnet jetzt 5 s später (`LoginCalendarMenu`), erst sieht man Pet-Karte und Abschluss, dann den Kalender (`113`, `114`).
- Lieferauftrag: „Done! Off to the 🚚 delivery van.“, mit überzähligem Belag „Wrong toppings! Sell the extra ones at the oven.“, nach Abgabe „Delivered! +24 coins“ (`115`–`117`).
- Rebirth: „Rebirth 1 for 74M coins? After that: coins ×1.5, start in world 1.“ mit „Yes, rebirth!“/„No“, Feier „Rebirth 1! ×1.5 coins“, danach „Rebirths: 1“, „Coins ×1.5 → ×2“, „Price: 111M coins“ (`118`–`120`).
- Bestenlisten auf der Spawn-Insel: „💰 Coins earned“ (filipocool 294,426), „🔁 Rebirths“ „No entries yet“, „⏱ Playtime“ (filipocool 1 h 56 min). Test-Spieler landen wie vorgesehen nicht darauf (`121`–`123`).


## Sprache aus dem Roblox-Menü (Spielsprache)

Im veröffentlichten Spiel blieb alles Deutsch, obwohl im Roblox-Menü die Spielsprache auf Englisch (USA) stand: Das Spiel las nur die Sprache des Roblox-Kontos. Jetzt zählt zuerst die im Menü gewählte Spielsprache (`Player.LocaleId`). Beim Umstellen während des Spiels erscheint der Hinweis „Language changed – rejoin to apply it.“ (in der neuen Sprache); nach dem Neu-Beitreten ist alles in der neuen Sprache.

- [x] Veröffentlichtes Spiel: Spielsprache im Roblox-Menü auf Englisch → Hinweis erscheint → Spiel verlassen und neu beitreten → alles Englisch. _(25.11.: vom User getestet)_
- [x] Zurück auf Deutsch → Hinweis auf Deutsch → neu beitreten → alles Deutsch. _(25.11.: vom User getestet)_

## #67 Englisch 2: Sprach-Baustein, HUD und Meldungen

Neu: Textsammlung `src/shared/Texts.luau` (Deutsch/Englisch), Sprach-Helfer `src/client/Lang.luau`. Umgestellt: HUD (Pizza-Leiste, Auto-Sammeln, Münz-/Gem-Zahlen), Freischalt-Knopf an Welt-Toren, alle Meldungen (Toasts), Seiten-Knöpfe (Pets, Tränke, Geschenke, Rebirth samt „Neu!“-Hinweisen). Namen (Welten, Tränke), Menüs, Tutorial und Schilder bleiben vorerst Deutsch (#68–#71). Vorher: `lune run test` → `553 passed, 0 failed`.

Sprache umschalten: `Workspace` → Attribut `Language` (string) = `de` bzw. `en`, dann **Play** (Anleitung in `docs/ui-style.md`, „Texte und Sprachen“). Danach das Attribut wieder löschen.

**Deutsch** (Attribut `de` oder ohne Attribut bei deutschem Konto):

- [x] HUD wie vorher: „Pizza 0/…“, voll „Pizza VOLL …“, „Auto-Sammeln: AN/AUS“, Münzen „1.234“ / „1,5 Mio“. _(24.11.: Pizza 0/12, „Pizza VOLL 3/3“, „Auto-Sammeln: AN“, „107.359“)_
- [ ] Meldungen wie vorher: „+X Münzen“ beim Verkaufen, „Nicht genug Münzen!“, „Pizza voll! Ab zum Ofen.“, Telefon-Meldungen, „Geliefert! +…“.
- [x] Seiten-Knöpfe „Pets“, „Tränke“, „Geschenke“ (mit „Abholen!“/Countdown/„Morgen“), „Rebirth“; Hinweise „Neu! …“ unverändert. _(24.11.: auch „Abholen!“, Countdown, „Neu! Geschenke fürs Spielen“)_
- [ ] Am gesperrten Tor: „🔓 <Welt> freischalten / 1.234 Münzen“, mit Rebirth-Sperre „🔒 <Welt>: Ab 1 Rebirth …“.

**Englisch** (Attribut `en`):

- [x] HUD: „Pizza 0/…“, „Pizza FULL …“, „Auto-Collect: ON/OFF“, Münzen „1,234“ / „1.5M“ / „2B“; Texte passen in die Felder. _(24.11.: „Pizza FULL 12/12“, „Auto-Collect: ON“, „107,344“, Rebirth-Preis „74M“; passt, `96`)_
- [x] Meldungen: „+X coins“, „+X gems!“, „Not enough coins!“, „Pizza full! Off to the oven.“, „📞 The phone is ringing!“, „Order accepted! …“, „Delivered! +…“, Trank „… has run out.“ / „… works for 10 minutes!“. _(24.11.: „+40 coins“, „Speed Potion works for 10 minutes!“, „Order accepted! …“, „Calls are back on.“, „The phone is ringing!“ gesehen, `95`, `97`, `103`; „Not enough coins!“ und „Delivered!“ nicht ausgelöst)_
- [x] Seiten-Knöpfe „Pets“, „Potions“, „Gifts“ (mit „Claim!“/„Tomorrow“), „Rebirth“; Hinweise „New! Gifts for playing“ / „New! More coins“ lesbar, nichts abgeschnitten (auch Handy-Emulator). _(24.11.: auch Handy-Emulator Galaxy S22, `102`)_
- [x] Am gesperrten Tor: „🔓 Unlock <Welt> / 1,234 coins“, mit Rebirth-Sperre „🔒 <Welt>: From 1 rebirth …“. _(24.11.: „🔓 Unlock Candy Land / 900,000 coins“, `98`; Rebirth-Sperre gibt es bei deinem Stand nicht)_
- [x] Output ohne Fehler; im Explorer (während Play) bei `PlayerGui` → `Hud` ist `AutoLocalize` aus. _(24.11.: 0 Fehler; `AutoLocalize = false` bei allen ScreenGuis)_

## #69 Englisch 4: Menüs Teil 1 (Shop, Pets, Ei, Tutorial)

Umgestellt auf die Textsammlung (Schlüssel `shop.`, `pets.`, `egg.`, `tutorial.`): Shop-Menü, Pet-Menü (Löschen-Dialog, Beste ausrüsten), Ei-Panel, Ei-Animation mit Pet-Karte, Tutorial-Karte. Namen aus der Config (Shops, Upgrades, Tränke, Eier, Pets samt Beschreibungen) bleiben Deutsch (#68). Vorher: `lune run test` → `553 passed, 0 failed`. Sprache wie bei #67 über das `Workspace`-Attribut `Language` umschalten.

**Deutsch** (alles wie vorher):

- [ ] Shop: „Münz-Tresen“, „Gem-Tresen“, „Gem-Tresen: Tränke (je 10 Min.)“, „Stufe 1 / 5“, Preis „1.500 Münzen“ / „… Gems“, „Weitere Stufen im größeren Shop“, „MAX“, Trank „10 Minuten“ / „Im Inventar: 0“; nach Kauf „Gekauft: …!“ (Trank mit „– im Trank-Menü trinken“), Fehler „Nicht genug Münzen!“ usw.
- [x] Pets: „Meine Pets“, „Beste ausrüsten“, „Löschen“ → „Fertig“ und Titel „Pet zum Löschen antippen“, Karten „Ausrüsten“/„Ablegen“, Zeile „Ausgerüstet x/y · Inventar … · Bonus …“, Dialog „… wirklich löschen?“ mit „Löschen“/„Behalten“, leer „Noch keine Pets – öffne ein Ei!“. _(24.11.: Handy, `106`)_
- [ ] Ei: „1 öffnen – 100 Münzen“ (bzw. „1 öffnen – 100“ + „3 öffnen – 300“), mit Glücks-Trank „<Ei> 🍀 Glück!“, Fehler „Zu wenig Münzen!“/„Inventar voll!“; Pet-Karte „+25 % Münzen“, „Tippen zum Schließen“.
- [ ] Tutorial: „Tutorial – Schritt 1/4“, Schritt-Texte, am Ende „Tutorial geschafft!“.

**Englisch** (Attribut `en`, auch im Handy-Emulator prüfen – nichts abgeschnitten):

- [x] Shop: „Coin counter“, „Gem counter“, „Gem counter: potions (10 min each)“, „Level 1 / 5“, „1,500 coins“ / „… gems“, „More levels in the bigger shop“ passt in den grauen Knopf, Effekt „10 toppings → 15 toppings“, „off“/„on“, „Speed …“; Trank „10 minutes“ / „Owned: 0“; „Bought: …!“ / „… – drink it in the potion menu“, „Can't buy that.“, „Already at the highest level!“. _(24.11.: `93`; „Bought: Speed Potion! – drink it in the potion menu“ lief in den Schließen-Knopf → behoben, `94`/`105`)_
- [x] Pets: „My pets“, „Equip best“, „Delete“ → „Done“ + „Tap a pet to delete it“, Karten „Equip“/„Unequip“, Zeile „Equipped x/y · Inventory … · Bonus …“ passt in eine Zeile, Dialog „Really delete …?“ (ausgerüstet: „It will be unequipped.“) mit „Delete“/„Keep“, leer „No pets yet – open an egg!“, „All pet slots taken – unequip a pet first!“. _(24.11.: Löschen-Dialog „Really delete Lava Lizard (+14 %)? It will be unequipped.“, `89`)_
- [x] Ei: „Open 1 – 100 coins“ bzw. „Open 1 – 100“ + „Open 3 – 300“, „<Ei> 🍀 Luck!“, „Not enough coins!“/„Inventory full!“; Pet-Karte „+25 % coins“, „Tap to close“. _(24.11.: Garden Egg „Open 1 – 25“/„Open 3 – 75“, Pet-Karte „Basil Bunny / Uncommon / +5 % coins / Tap to close“, `100`, `101`)_
- [x] Tutorial: „Tutorial – step 1/4“, „Collect 10 toppings (0/10) – tap them or walk over them with Auto-Collect!“ passt in die Karte, „Walk into the zone at the oven …“, „Buy your first upgrade …“, „Open your first pet at the egg! …“, am Ende „Tutorial complete!“ / „Have fun topping pizzas! …“. _(24.11.: komplett auf Englisch, Schritt 1 sammelt jetzt 2 Beläge, `109`–`113`)_
- [ ] Output ohne Fehler.

## #70 Englisch 5: Menüs Teil 2 (Tränke, Geschenke, Kalender, Rebirth, Portal, Telefon)

Umgestellt auf die Textsammlung (Schlüssel `potions.`, `gifts.`, `calendar.`, `rebirth.`, `portal.`, `delivery.`, `reward.`, `common.`): Trank-Menü, Geschenke, Login-Kalender, Rebirth-Menü und -Feier, Portal-Menü, Telefon-Menü, Auftragskarte, Belohnungstexte (`UiKit.rewardText`). Barrieren-Hinweise waren schon seit #67 umgestellt; das Portal nutzt jetzt dieselben `unlock.rebirthsOne/Many`. Namen aus der Config (Welten, Tränke, Beläge) bleiben Deutsch (#68). Vorher: `lune run test` → `553 passed, 0 failed`. Sprache über das `Workspace`-Attribut `Language` umschalten.

**Deutsch** (alles wie vorher):

- [x] Tränke: „Meine Tränke“, „Gleiche Art nochmal trinken verlängert die Zeit.“, Karten „Im Inventar: 0“, „Trinken“, „Läuft: 9:59“; Timer oben „Münzen ×2  9:59“ / „Glück …“ / „Speed …“; „<Trank> getrunken!“, ohne Trank „Davon hast du keinen Trank – kauf einen im Gem-Tresen!“. _(24.11.: Handy)_
- [x] Geschenke: „Geschenke“, „📅 Kalender“, Zeilen „5 Min“, „Abholen“/„✓“, „Spiel jeden Tag – jedes Geschenk einmal pro Tag.“, nach Abholen „Geschenk! +10 Gems“ (bzw. „+1× <Trank>“), zu früh „Noch nicht – spiel noch ein bisschen weiter!“. _(24.11.: „Geschenk! +3 Gems“, `104`)_
- [ ] Kalender: „Login-Kalender“, Kacheln „Tag 1“ … „Tag 7“, „Heute“/„✓“, „Tag 1: hol dir deine Belohnung!“, Knopf „Abholen“ → „Morgen wieder“, „Tag 1! +…“, „Komm morgen wieder – jeden Tag in Folge wird es besser!“.
- [x] Rebirth: „Noch kein Rebirth“ / „Rebirths: 1“, „Münzen ×1  →  ×1,5“, „Preis: 1 Mio Münzen“, Balken „42 %“, „Weg: …/Bleibt: …“, Trank-Warnung, Bestätigung „Rebirth 1 für … Münzen? Danach: Münzen ×1,5, Start in Welt 1.“ mit „Ja, Rebirth!“/„Nein“; Feier „Rebirth 1! ×1,5 Münzen“. _(24.11.: Menü auf dem Handy; Bestätigung/Feier nicht ausgelöst)_
- [ ] Portal: „🌀 Teleport“, „📍 <Welt> (du bist hier)“, „🔒 <Welt> – 1.500 Münzen“, „🔒 <Welt> – Ab 1 Rebirth“ + Preis darunter.
- [ ] Telefon: Blase „📞 RING!“, „📞 Neuer Auftrag!“ mit „Belohnung: bis zu 💰 … Münzen“, „Zeit: 2:00 – je schneller, desto mehr!“, „Annehmen“/„Ablehnen“, „📵 Keine Anrufe mehr“; ohne Anruf „📞 Telefon“ + Text; Anrufe aus „📵 Anrufe sind aus“ + „📞 Anrufe einschalten“. Auftragskarte „🧾 Auftrag  ⏱ 1:59“, „Schnell = mehr Belohnung!“ → „Fertig! Ab zum 🚚 Lieferwagen.“, ohne Auftrag „📞 Das Telefon klingelt!“ / „Lauf zum Telefon und geh ran.“.

**Englisch** (Attribut `en`, auch im Handy-Emulator prüfen – nichts abgeschnitten):

- [x] Tränke: „My potions“, „Drinking the same kind again adds more time.“, „Owned: 0“, „Drink“, „Active: 9:59“, Timer „Coins ×2 …“ / „Luck …“; „<Trank> drunk!“, „<Trank> has run out.“, „You have none of these – buy one at the gem counter!“ passt in die Statuszeile. _(24.11.: `90`, `95`)_
- [x] Geschenke: „Gifts“, „📅 Calendar“, „5 min“, „Claim“, „Play every day – each gift once per day.“, „Gift! +10 gems“ / „+1 potion“, „Not yet – keep playing a little longer!“, „You already claimed this gift today.“. _(24.11.: Untertitel lag unter dem Kalender-Knopf → behoben, `91`/`104`)_
- [x] Kalender: „Login calendar“, „Day 1“ … „Day 7“, „Today“, „Day 1: claim your reward!“, „Claim“ → „Back tomorrow“, „Day 1! +…“, „Come back tomorrow – every day in a row gets better!“. _(24.11.: „Day 1! +5 gems“, „Back tomorrow“, `87`, `88`)_
- [x] Rebirth: „No rebirth yet“ / „Rebirths: 1“, „Coins ×1  →  ×1.5“ (Punkt statt Komma), „Price: 1M coins“, „42%“, „Lost: …/Kept: …“ passt in zwei Zeilen, „Careful: your active potion ends on rebirth!“, „Rebirth 1 for … coins? After that: coins ×1.5, start in world 1.“ mit „Yes, rebirth!“/„No“; Feier „Rebirth 1! ×1.5 coins“. _(24.11.: Menü + Trank-Warnung, `92`; Bestätigung/Feier nicht ausgelöst)_
- [x] Portal: „📍 <Welt> (you are here)“, „🔒 <Welt> – 1,500 coins“, „🔒 <Welt> – From 1 rebirth“. _(24.11.: `99`)_
- [x] Telefon: „📞 New order!“, „Reward: up to 💰 … coins“, „Time: 2:00 – the faster, the more!“, „Accept“/„Decline“, „📵 No more calls“, „📞 Phone“ / „No call right now. …“, „📵 Calls are off“ / „The phone no longer rings. …“ / „📞 Turn calls on“. Auftragskarte „🧾 Order  ⏱ 1:59“, „Fast = more reward!“ → „Done! Off to the 🚚 delivery van.“, „📞 The phone is ringing!“ / „Run to the phone and answer it.“. _(24.11.: Anruf, „Calls are off“ → „Turn calls on“, Auftragskarte, `103`)_
- [ ] Output ohne Fehler.

## #71 Englisch 6: 3D-Schilder in der Sprache jedes Spielers

Der Server setzt auf Schild-Texten nur noch `TextKey`/`TextArgs` (Tag `SignText`), `src/client/SignTexts.luau` zeigt sie in der Sprache des Spielers. Welt-, Ei- und Shop-Namen kommen seit #68 ebenfalls in der Sprache des Spielers.

- [ ] **Deutsch** (`Language` = `de` auf Workspace): alle Schilder genau wie vorher – Ofen („Ofen – hier verkaufen“, „Ofen (Welt) – hier verkaufen“), Boden „VERKAUFEN“/„SHOP“, „<Shop> – Upgrades“, Ei-Stände („<Ei>\n💰 1.500“, „Bald: neues Ei!“), Tor-Preisschild („🔒 Welt\nAb 3 Rebirths\n1.500.000 Münzen“), Portal „🌀 Teleport“, „📞 Telefon – Aufträge“, „🚚 Lieferwagen – Bestellung abgeben“, „🧾 Bestellung“ über der Pizza, Bestenlisten (Titel, „Bestenliste lädt …“, „Noch keine Einträge“, Werte „1.234“, „3 Std. 5 Min.“).
- [ ] **Englisch** (`Language` = `en`): „Oven – sell here“, „SELL“/„SHOP“, „Coming soon: new egg!“, „🔒 World\nFrom 3 rebirths\n1,500,000 coins“, „📞 Phone – Orders“, „🚚 Delivery van – hand in order“, „🧾 Order“, Bestenlisten „⏱ Playtime“, „💰 Coins earned“, „Leaderboard loading …“, „No entries yet“, Werte „1,234“, „3 h 5 min“.
- [ ] Schilder flackern nicht und verrutschen nicht; nach dem Bestenlisten-Refresh (2 Min.) bleiben sie englisch.
- [x] **2 Spieler, verschiedene Sprachen:** Test → Clients and Servers → 2 Players. In einem Client per Command Bar (Client-Seite) `require(game.Players.LocalPlayer.PlayerScripts.Client.Lang).language` prüfen; Player Emulator geht nur für alle gleich, daher: Client 1 Locale `de-de`, dann im Client-2-Fenster in der Command Bar `for _, l in game:GetService("CollectionService"):GetTagged("SignText") do l.Text = require(game:GetService("ReplicatedStorage").Shared.Texts).render("en", l:GetAttribute("TextKey"), l:GetAttribute("TextArgs") and game:GetService("HttpService"):JSONDecode(l:GetAttribute("TextArgs"))) end` – Client 1 sieht weiter „VERKAUFEN“, Client 2 „SELL“. Alternativ mit zwei Roblox-Konten (deutsch/englisch) in einem veröffentlichten Test-Server. _(24.11.: Der Command-Bar-Trick klappt nicht – `SignTexts` stellt jeden geänderten Text sofort zurück. Getestet mit einer vorübergehenden Studio-Zeile (`Language_<Spielername>`, nicht committet): Player1 Deutsch „Ofen – hier verkaufen“/„Teig-Hamster“, Player2 am selben Ofen „Oven – sell here“/„SELL“/„Dough Hamster“, `107`, `108`)_

## #68 Englisch 3: Namen im Spiel

Alle Namen aus `GameConfig` (Pets, Beläge, Welten, Eier, Tränke, Upgrades, Shops, Seltenheiten) erscheinen in der Sprache des Spielers (Liste: `docs/translations-names.md`).

- [ ] **Deutsch** (`Language` = `de`): alles genau wie vorher – Pet-Menü/Löschen-Frage („Teig-Hamster“), Ei-Panel und Ei-Animation (Pet + „Gewöhnlich“ …), Shop-Titel „Pizza-Shop“, Upgrade-Karten („Pizza-Platz“ + „Mehr Beläge pro Pizza“), Trank-Karten, „Pizza-Platz gekauft!“, Trank-Menü und Timer-Toasts („Münz-Trank getrunken!“), Portal („📍 Pizzeria-Garten (du bist hier)“), Tor-Knopf „🔓 Bauernhof freischalten“, Lieferauftrag („Pilz“, „Peperoni“), Geschenk-/Kalender-Belohnung „2× Glücks-Trank“, Schilder („Ofen (Bauernhof) – hier verkaufen“, „Pizza-Shop – Upgrades“, „Garten-Ei\n💰 …“, Tor-Preisschild), Namensschild über den Pets.
- [ ] **Englisch** (`Language` = `en`): „Dough Hamster“, „Common“/„Mythic“, „Garden Egg“, „Pizza Shop“, „Pizza Space“ + „More toppings per pizza“, „3 Eggs at Once“ + „Unlocks “Open 3” at every egg“, „Coin Potion drunk!“, „📍 Pizzeria Garden (you are here)“, „🔓 Unlock Farm“, Lieferauftrag „Mushroom“, „Hot Pepper“ (nicht „Pepperoni“), „2× Luck Potion“, „Oven (Farm) – sell here“, „Pizza Shop – Upgrades“, „Sweets Egg“ im Süßigkeitenland, Pet-Namensschild „Galaxy Pizza Leviathan“ passt aufs Schild. Nichts abgeschnitten (auch Handy-Emulator).
- [x] **2 Spieler, verschiedene Sprachen** (wie bei #71): jeder sieht die Pet-Namensschilder der Pets (auch die des anderen Spielers) in seiner Sprache. _(24.11.: Pet-Namensschilder beider Spieler je in der eigenen Sprache, `107`, `108`)_
- [x] Altes Spiel laden: Pets, Tränke, Upgrades unverändert (Spielstände nutzen nur Ids). Output ohne Fehler. _(24.11.: dein Spielstand lädt unverändert, 0 Fehler)_

## MEGA UPDATE – #73 Neustart-DataStore und Feature-Schalter

Spielstände liegen jetzt im DataStore `PlayerState_Mega1` (`GameConfig.save.storeName`), Bestenlisten in `Leaderboard_*_mega1`. Der alte Store `PlayerState` und die alten `_v1`-Bestenlisten werden nicht mehr gelesen und nicht verändert. Feature-Schalter: `GameConfig.features` (alle `true`).

Vorher: `lune run test` → alle grün (u. a. `tests/Features.spec.luau`, `GameConfig` „fresh start“/„switch for every feature“).

Studio (API-Zugriff an, siehe #3), Rojo verbinden, **Play**:

- [ ] Du startest als neuer Spieler: 0 Münzen, 0 Gems, keine Pets, Welt 1, Tutorial Schritt 1/4. Output ohne rote Fehler, keine `[Save]`-Warnung.
- [ ] Etwas Münzen sammeln, Stop, erneut **Play** → Fortschritt ist noch da (gespeichert im neuen Store).
- [ ] Alter Spielstand unangetastet: im Bearbeitungsmodus in die Command Bar `print(game:GetService("DataStoreService"):GetDataStore("PlayerState"):GetAsync("player_" .. game:GetService("StudioService"):GetUserId()) ~= nil)` → `true` (falls du vorher gespeichert hattest).
- [ ] Bestenlisten auf der Spawn-Insel zeigen nur neue Einträge (anfangs „Noch keine Einträge“ bzw. nur dich).
- [ ] Neu anfangen zum Testen (nur Bearbeitungsmodus, nicht im Play-Modus): `game:GetService("DataStoreService"):GetDataStore("PlayerState_Mega1"):RemoveAsync("player_" .. game:GetService("StudioService"):GetUserId())`. Fortschritt zum Testen später über das Admin-Panel (#74) statt über Config-Änderungen.

## MEGA UPDATE – #74 Admin-Panel (nur User 372358501)

Nur für `GameConfig.admin.userIds` (= 372358501): oben rechts ein kleiner dunkler 🛠️-Knopf (am PC auch **F2**) öffnet ein eigenes Fenster mit einer Zeile pro Aktion (Zahlenfeld bzw. ◀ Wert ▶, Knopf **Los**; Ergebnis als Statuszeile ✓/✗). Jede Aktion prüft der Server erneut per User-Id und Argument-Check (`src/shared/AdminActions.luau`, `src/server/AdminService.luau`). Schalter: `GameConfig.features.adminPanel`.

Vorher: `lune run test` → alle grün (u. a. `tests/AdminActions.spec.luau`).

Studio, Rojo verbinden, **Play** (eingeloggt als ElSerbo1337 / User 372358501):

- [ ] 🛠️-Knopf oben rechts sichtbar, überdeckt nichts Wichtiges (auch am Handy-Emulator); F2 öffnet/schließt; Liste scrollt, Texte passen (auch mit `Language = en`).
- [ ] **Münzen geben** 1000000 → Münzanzeige springt; **-500** zieht ab (nie unter 0). **Gems geben** 1000 → Gems-Anzeige.
- [ ] **Tutorial beenden** → Tutorial-Karte/Pfeil verschwinden; nochmal → ✗ (`TutorialDone`).
- [ ] **Upgrade-Stufe setzen** `Inventar` auf die höchste Stufe → Inventar-Anzeige im Pet-Menü wächst. Zu hohe Stufe → ✗ `InvalidArgument`.
- [ ] **Pet geben** (◀ ▶ durchblättern, Namen in deiner Sprache) ×3 → Pets im Pet-Menü, ausrüstbar. Mehr als Platz → ✗ „Inventar voll“.
- [ ] **Tränke geben** → Trank-Menü zeigt die Anzahl, trinkbar.
- [ ] **Rebirths setzen** 2 → Rebirth-Knopf/Menü zeigt 2 und den neuen Multiplikator; gesperrte Welten mit Rebirth-Bedingung gelten als erfüllt.
- [ ] **Welten freischalten (bis)** z. B. Welt 5 → Barrieren bis dahin offen, Portal-Menü zeigt sie als frei.
- [ ] **Tage vorspulen** 1 → Login-Kalender (über Geschenke → Kalender) zeigt den nächsten Tag als abholbar; Geschenke beginnen von vorn. 7 → Kalender fängt wieder bei Tag 1 an.
- [ ] **Spielstand zurücksetzen**: erster Tipp → Knopf zeigt „Sicher?“, zweiter Tipp innerhalb 3 s → alles auf Neuanfang, du stehst am Start von Welt 1, Tutorial läuft wieder. Stop + Play → bleibt zurückgesetzt.
- [ ] Output: pro Aktion `[Admin] <Name>: <aktion> ok`, keine roten Fehler.
- [ ] Fremde Spieler: **Test → Clients and Servers → 2 Players** → bei den Test-Spielern (negative User-Ids) kein 🛠️-Knopf. Optional in deren Client-Command-Bar: `game.ReplicatedStorage.Remotes.AdminRun:FireServer("addCoins", {1000})` → nichts passiert, Server-Output zeigt `[Admin] Abgelehnt: …`.
- [ ] `GameConfig.features.adminPanel = false` → kein Knopf, Aktionen werden ignoriert. Danach wieder `true`.

## MEGA UPDATE – #77 Welt-System: Rebirth-Stufen, Tränke bei Rebirth, Event-Inseln

Rebirth-Stufen der 15 Welten in `GameConfig.worlds[].requiredRebirths`: Welt 1–4: 0, 5–6: 1, 7–8: 2, 9–10: 3, 11–12: 5, 13–14: 7, 15: 10 (vorhanden sind Welt 1–7, also **Vulkan und Süßigkeitenland brauchen jetzt 1 Rebirth, Weltraum 2**). Vorläufige Rebirth-Preise bis #108: 150.000 · 9 Mio · 540 Mio. Laufende Tränke bleiben beim Rebirth, es gibt keine Gems dafür. Event-Inseln (`GameConfig.eventWorlds`) sind nur vorbereitet, in diesem Update gibt es keine. Schalter: `rebirthPreview` (Welten-Zeile im Rebirth-Menü), `eventWorlds`.

Vorher: `lune run test` → alle grün (u. a. `RebirthTiers`, `EventWorlds`, `IslandPlan15`, `Rebirth`).

Studio, Rojo verbinden, **Play** (Admin-Panel #74):

- [ ] Admin: **Münzen geben** 100000, Welt 2–4 kaufen. Barriere vor **Vulkan** zeigt „Ab 1 Rebirth“, Kauf geht nicht („Dafür brauchst du mehr Rebirths!“), Portal-Menü zeigt Vulkan/Süßigkeitenland/Weltraum gesperrt mit Rebirth-Bedingung.
- [ ] Rebirth-Menü mit 0 Rebirths: Multiplikator „×1 → ×1,5“, Preis 150K, grüne Zeile **„🌍 Öffnet: Vulkan, Süßigkeitenland“**. Mit `Language = en` englische Namen („Opens: Volcano, Candy Land“). Text passt in die Zeile (auch Handy-Emulator).
- [ ] Admin: **Tränke geben**, einen Münz-Trank trinken, **Münzen geben** 150000, Rebirth machen → Bestätigung nennt die Welten; danach läuft der Trank mit seiner Restzeit weiter (Trank-Anzeige unten), Gems unverändert.
- [ ] Nach dem 1. Rebirth: Rebirth-Menü zeigt „🌍 Öffnet: Weltraum“; Vulkan-Barriere ist mit genug Münzen kaufbar.
- [ ] Admin: **Rebirths setzen** 2 → Rebirth-Menü zeigt „🌍 Alle Welten sind erreichbar.“ (bis die neuen Welten 8–15 dazukommen; dann z. B. „Öffnet: Dschungel-Tempel, Wüsten-Pyramiden“ bzw. bei 3→4 „Öffnet keine neue Welt. Nächste ab 5 Rebirths: …“).
- [ ] Welt 1–7 normal spielbar: Beläge sammeln, verkaufen, Shops, Eier, Lieferung in jeder Welt; Output ohne rote Fehler. Keine Event-Insel sichtbar (rechts neben der Spawn-Insel ist leerer Himmel).
- [ ] `GameConfig.features.rebirthPreview = false` → Welten-Zeile im Rebirth-Menü und in der Bestätigung weg, Rest wie vorher. Danach wieder `true`.

## MEGA UPDATE – #75 Neues HUD: Seitenleiste, glänzende Kacheln, rote Punkte

Neu: Seitenleiste links mit glänzenden Kacheln und Live-3D-Icons (Pets, Tränke, Geschenke, Kalender, Rebirth, Welten), rote Punkte für „hat Neues“, Pizza-Balken oben unter Münzen/Gems, Auto-Sammeln unten Mitte, laufende Tränke unten rechts über dem Sprung-Knopf, Auftrag (und später Boni) oben rechts. Schalter: `GameConfig.features.sideBar`. Stil und API: `docs/ui-style.md` → „Seitenleiste“.

Vorher: `lune run test` → alle grün (u. a. `tests/HudLayout.spec.luau`, `tests/SideBar.spec.luau`).

Studio, Rojo verbinden, **Play** (PC-Ansicht):

- [ ] Links eine Spalte mit 6 Kacheln (Pets, Tränke, Geschenke, Kalender, Rebirth, Welten), senkrecht mittig, nicht unter dem offenen Roblox-Chat (oben links). Jede Kachel: Farbverlauf, dicker dunkler Rand, Glanz oben, leicht schräges 3D-Icon, das sanft hin- und herschwenkt, Beschriftung unten. Output ohne rote Fehler.
- [ ] 3D-Icons: Pets zeigt den Teig-Hamster und Welten den Portalbogen, wenn die Modelle importiert sind (sonst Ersatzformen: Tierkopf bzw. Steinbogen). Tränke = Flasche, Geschenke = Paket, Kalender = Tischkalender, Rebirth = leuchtende Kugel mit Ring.
- [ ] Jede Kachel öffnet ihr Menü wie vorher (zweites Tippen schließt es), Drücken federt, Maus darüber vergrößert leicht. Nur ein Menü gleichzeitig offen.
- [ ] Geschenke-Kachel: Beschriftung zählt bis zum nächsten Geschenk herunter; wenn eins bereit ist („Abholen!“) roter Punkt oben rechts, nach dem Abholen weg. Der „Neu! Geschenke fürs Spielen“-Hinweis steht rechts neben der Kachel. (Zum Beschleunigen: Admin-Panel #74, falls schon da – sonst das erste Geschenk abwarten.)
- [ ] Kalender-Kachel: als neuer Spieler (Tag 1 offen) roter Punkt; nach „Abholen“ im Kalender weg; Kalender öffnet sich weiter auch aus dem Geschenke-Menü.
- [ ] Rebirth-Kachel: Rebirth-Zahl (gelb) oben links, sobald Rebirths > 0 (Admin-Panel: Rebirths setzen); „Neu! Mehr Münzen“-Hinweis daneben, wenn ein Rebirth leistbar ist.
- [ ] Welten-Kachel irgendwo auf der Insel: Weltenliste mit „Zum Reisen in ein Portal stellen“, Knöpfe nicht drückbar. Im Portal: Liste wie gewohnt, Reisen geht. Portal-Menü mit X schließen, Kachel drücken → geht wieder auf und Reisen geht.
- [ ] Oben Mitte: Münzen, Gems, direkt darunter der Pizza-Balken (kein Überlappen mit der Roblox-Leiste), Meldungen darunter. Unten Mitte Auto-Sammeln, rechts daneben ggf. der Freischalt-Knopf.
- [ ] Trank trinken: Trank-Anzeige unten rechts (über der Sprung-Knopf-Stelle); Auftrag annehmen: Auftragskarte oben rechts. Beide gleichzeitig: keine Überlappung.
- [ ] Ei-Vorschau öffnen: rechte Spalte (Tränke + Auftrag) blendet sich aus und kommt danach wieder.

Handy (**Test → Device** z. B. iPhone SE / iPhone 14 Landscape, und ein Tablet):

- [ ] Handy: zwei Spalten mit kleineren Kacheln direkt über dem Joystick; nichts überdeckt Sprung-Knopf, Auftragskarte oder Tränke. Auf sehr kleinen Handys stehen 3 Kacheln + „Mehr“ (⋯); „Mehr“ öffnet ein Fenster mit den übrigen Kacheln, die dort ihre Menüs öffnen; roter Punkt auf „Mehr“, solange eine versteckte Kachel (z. B. Kalender) Neues hat.
- [ ] Tablet: eine Spalte über dem Joystick-Bereich, nichts im Joystick.
- [ ] Auf dem Handy flüssig (die 3D-Icons schwenken mit 20 Bildern/s). Falls es ruckelt: `GameConfig.features.sideBar = false` → schlichte runde Knöpfe an denselben Plätzen (dann ohne rote Punkte) und mir Bescheid geben.

## MEGA UPDATE – #94 Goldene Beläge und Gold-Glück-Upgrade

Jeder normale Belag hat einen Gold-Wurf; er ist für dich golden, wenn deine Gold-Chance darüber liegt (1 %, mit Gem-Upgrade **Gold-Glück** bis 2 %). Goldene Beläge glitzern (nur für den Spieler, für den sie golden sind), geben beim Verkaufen den 10-fachen Wert und glitzern auch auf der Pizza in der Hand. Schalter: `GameConfig.features.goldenToppings`. Sound `GoldenTopping` in `src/client/Sounds.luau` hat noch **keine ID** (Suchbegriffe stehen dort) – bitte eine passende „Roblox“-ID eintragen.

Vorher: `lune run test` → alle grün (u. a. `tests/GoldenToppings.spec.luau`).

Studio, Rojo verbinden, **Play** (als Admin):

- [ ] Admin-Panel → **Gold-Chance testen** 100 → praktisch alle Beläge auf dem Feld glitzern gold (Funken + warmes Licht). Einen einsammeln → Toast „✨ Goldener Belag: …! 10-facher Wert“, Sound (sobald ID eingetragen), Belag glitzert auch auf der Pizza in der Hand.
- [ ] Am Ofen verkaufen → Toast „+… Münzen (✨ N× golden)“; Betrag = 10× Wert der goldenen + normale (z. B. Welt 1 mit leerer Pizza vergleichen).
- [ ] **Gold-Chance testen** 0 → Glitzern verschwindet sofort von allen Feld-Belägen (bis auf die ~1 %, die bei dir ohnehin golden sind).
- [ ] **Goldene Beläge auf die Pizza** (Belag ◀ ▶, Anzahl 5) → Pizza in der Hand zeigt glitzernde Beläge (nur bis Pizza voll), Verkaufen gibt 10×.
- [ ] Shop (Gem-Tresen) → **Gold-Glück**: Anzeige „1 % Gold-Chance“ → nach Kauf „1,2 %“ (englisch „1.2%“); Welt-1-Shop bis Stufe 2, Welt 4 bis 4, Welt 7 bis 5 (2 %). Texte mit `Language = en` prüfen.
- [ ] **Rebirths**: mit Gold-Glück Stufe ≥ 1 einen Rebirth machen (Münzen geben) → Gold-Glück-Stufe bleibt.
- [ ] Lieferauftrag mit goldenem Belag derselben Sorte: beim Verkaufen am Ofen wird zuerst der goldene verkauft, der normale bleibt für den Auftrag.
- [ ] 2 Spieler (Test → 2 Players), einer mit Gold-Chance 100 (Admin), der andere ohne: nur beim Admin glitzert alles; was der andere einsammelt, ist für ihn normal.
- [ ] `GameConfig.features.goldenToppings = false` → kein Glitzern, Gold-Glück nicht im Shop, Admin-Aktionen weg. Danach wieder `true`.

## MEGA UPDATE – #76 Einstellungs-Menü (Lautstärke, Grafik, Kamera, Ei-Animation, Codes-Feld)

Neu: Kachel ⚙️ „Optionen“ in der Seitenleiste (ganz unten/hinten) öffnet das Einstellungs-Menü. Gespeichert pro Spieler im Spielstand (Feld `settings`). Schalter: `GameConfig.features.settings` (Codes-Feld zusätzlich `codes`). Client-API für spätere Tickets: `docs/ui-style.md` → „Einstellungen“.

Vorher: `lune run test` → alle grün (u. a. `tests/Settings.spec.luau`).

Studio, Rojo verbinden, **Play** (PC-Ansicht):

- [ ] Seitenleiste: Kachel „Optionen“ mit Zahnrad-Icon; Tippen öffnet das Menü „⚙️ Einstellungen“, zweites Tippen/X schließt es; andere Menüs schließen sich dabei. Output ohne rote Fehler.
- [ ] Musik-Regler ziehen: Musik wird sofort leiser/lauter, Prozentzahl läuft mit. 🔊-Knopf → 🔇: Musik ganz aus, Regler wird grau; Regler wieder ziehen schaltet den Ton wieder ein.
- [ ] Effekte-Regler: beim Loslassen kommt ein „Plopp“ in der neuen Lautstärke; Belag sammeln/verkaufen klingt entsprechend leiser. Stumm-Knopf schaltet alle Effekte (nicht die Musik) aus.
- [ ] Grafik „Niedrig“: Nebel/Rauch/Gischt an den Inseln und Portal-Funken deutlich weniger, Gem-Glitzer (Sparkles) aus. „Hoch“: alles wie vorher.
- [ ] „Ei-Animation überspringen“ AN, Ei öffnen (Admin-Panel: Gems/Münzen geben): Pet-Karten erscheinen sofort, ohne Wackeln und ohne weißen Blitz. AUS: Animation wie gewohnt.
- [ ] „Bildschirm-Blitze“ AUS, Ei öffnen (Überspringen AUS): Animation ohne den weißen Blitz. „Kamera-Wackeln“ ist bisher nur ein Schalter (das Wackeln kommt mit Juice/Mythic-Ticket).
- [ ] Codes-Feld: Code eintippen, „Einlösen“ (oder Enter) → „Wird geprüft …“, nach ~5 s „Codes gibt es bald!“ (die echte Code-Logik kommt mit #99). Leeres Feld → „Bitte einen Code eingeben.“
- [ ] **Speichern:** ein paar Einstellungen ändern, Play beenden, neu starten → alles wie eingestellt (Studio braucht dafür „Enable Studio Access to API Services“). Admin-Panel „Spielstand zurücksetzen“ setzt auch die Einstellungen zurück.
- [ ] Englisch (Attribut `Language` = `en` am Workspace): Menü komplett englisch („Settings“, „Music“, „Skip egg animation“ …).

Handy (**Test → Device** z. B. iPhone 14 Landscape):

- [ ] Als neuer Spieler steht Grafik auf „Niedrig“ (hervorgehoben). Auf „Hoch“ stellen → bleibt nach Rejoin „Hoch“.
- [ ] Regler lassen sich mit dem Finger ziehen, ohne dass die Liste dabei scrollt; Menü scrollt auf kleinen Handys, alle Knöpfe ≥ Daumengröße.
- [ ] Schalter `GameConfig.features.settings = false`: keine Kachel, alles auf Standard (Musik/Effekte 100 %); `codes = false`: Menü ohne Codes-Abschnitt.

## MEGA UPDATE – #106 Spawn-Insel als Marktplatz, Update-Tafel und Weihnachts-Countdown

Die Spawn-Insel hat jetzt Bänke um den Brunnen, 6 Laternen (Weg zur Brücke und neben dem Brunnen), Blumenbeete, eine Tafel „Neu im Update!“ links und ein Countdown-Schild „🎄 Weihnachts-Event startet in X Tagen“ rechts neben dem Spawn. Freigehalten (ohne Bäume/Deko) sind die Plätze für Glücksrad (#98), Händler-Stand (#107) und die zwei neuen Bestenlisten (#109): unsichtbare Anker `Workspace.SpawnIsland.Anchors.WheelAnchor`, `MerchantAnchor`, `Board4Anchor`, `Board5Anchor` (Attribut `ClearRadius`). Fenster „Was ist neu“ einmal pro Spieler. Schalter: `spawnMarketplace` (Tafel), `christmasCountdown`, `whatsNew`.

Vorher: `lune run test` → alle grün (u. a. `tests/SpawnIsland.spec.luau`, `tests/SpawnMarket.spec.luau`).

Studio, Rojo verbinden, **Play** (als Admin):

- [ ] Spawn wie gewohnt auf dem gelben Spawn-Feld, Blick zum Brunnen; Tafel und Countdown stehen links/rechts schräg davor, nichts steht im Weg (zum Brunnen, zur Brücke, zum Portal laufen).
- [ ] Tutorial-Pfeil führt weiter über die Brücke zu Welt 1; Portal auf der Spawn-Insel funktioniert (Reisen in eine freigeschaltete Welt und zurück).
- [ ] Bänke stehen außerhalb des Brunnen-Rings, Laternen leuchten, Blumen ohne Kollision; die drei Bestenlisten zeigen weiter ihre Einträge.
- [ ] Im Explorer: `SpawnIsland/Anchors` hat 4 Anker, rundherum (Radius `ClearRadius`) keine Bäume/Deko. Rad-Platz rechts hinten, Händler links hinten, Board4/Board5 links/rechts neben der mittleren Bestenliste – passt dir die Lage? Sonst `GameConfig.islands.spawnLayout.reserved` anpassen.
- [ ] Tafel: Titel „Neu im Update!“, Liste mit 8 Zeilen lesbar. Mit `Language = en` englisch. Nah ran → Prompt „Lesen“ (E) → Fenster „Was ist neu“ öffnet sich.
- [ ] Countdown zeigt heute die richtige Zahl (z. B. am 25.11. „in 23 Tagen“), englisch „Christmas event starts in 23 days“. Ab 18.12. ist das Schild weg (nur per Code-Test geprüft; am 17.12. steht „startet morgen!“).
- [ ] Neuer Spieler (Admin-Panel → **Spielstand zurücksetzen**, Rejoin): Fenster „Was ist neu“ kommt erst nach dem Tutorial und nach dem Login-Kalender (nicht darüber). „Los geht's!“ schließt es; Rejoin → kommt nicht wieder.
- [ ] Admin-Panel → **„Was ist neu“ wieder zeigen**, Rejoin → Fenster kommt nach ~3 s wieder.
- [ ] Handy (Device-Emulation): Fenster passt auf den Bildschirm (scrollt notfalls), Knöpfe gut drückbar.
- [ ] Schalter testen: `spawnMarketplace = false` → Tafel weg; `christmasCountdown = false` → Countdown-Schild weg; `whatsNew = false` → kein Fenster, kein Prompt. Danach wieder `true`.

## MEGA UPDATE – #81 Seltenheit „Geheim“, Geheim-Pets und globale Nachricht

Neue Seltenheit **Geheim** (türkis) über Mythisch: je Welt 1–7 ein Geheim-Pet (Mozzarella-Geist, Vogelscheuchen-Rabe, Schatz-Oktopus, Polarlicht-Wolf, Obsidian-Drache, Lebkuchen-Golem, Schwarzloch-Katze), eigener Wurf 1 : 20.000 pro Ei, mit Glücks-Trank 1 : 10.000. Beim Schlüpfen: Nachricht auf **allen** Servern (MessagingService, pro Server max. 5 pro Minute). Ab Legendär: Bildschirm-Färbung + Lichtstrahlen; Geheim: lange, dunkle Spannungs-Animation, „🤫 GEHEIM!“. Schalter: `secretPets` (Wurf, Admin-Aktionen), `secretAnnouncement` (Banner/Nachricht). Sound `Secret` in `src/client/Sounds.luau` hat noch **keine ID** (Suchbegriffe stehen dort).

Vorher: `lune run test` → alle grün (u. a. `tests/SecretPets.spec.luau`, `tests/SecretAnnounce.spec.luau`).

**Modelle importieren** (einmalig): `assets/models/pets/` → MozzarellaGhost, ScarecrowRaven, TreasureOctopus, AuroraWolf, ObsidianDragon, GingerbreadGolem, BlackHoleCat (`.fbx`) wie die übrigen Pets nach `ReplicatedStorage.GameAssets.Models.Pets` (Vorschau aller 7: `assets/previews/pets/SecretPets.png`). Ohne Import: türkiser Platzhalter-Ball.

Studio, Rojo verbinden, **Play** (als Admin):

- [ ] Ei-Vorschau (Welt 1, beide Eier): letzte Zeile „??? (Geheim)“ mit schwarzem „?“-Bild und „1 : 20.000“; Glücks-Trank trinken → „1 : 10.000“. Englisch: „1 in 20,000“.
- [ ] Admin-Panel → **Geheim-Pet geben** (Welt ◀ ▶) → Pet im Inventar, türkis, Bonus doppelt so hoch wie das beste Pet der Welt; ausrüsten → 3D-Modell folgt (nach Import).
- [ ] Admin-Panel → **Geheim-Chance testen** 100 → Ei öffnen: Bildschirm wird dunkel, Ei färbt sich türkis und wackelt ~3 s länger, türkiser Blitz, Lichtstrahlen drehen sich, „🤫 GEHEIM!“ über der Karte, Karte bleibt 7 s. Danach **0** → wieder normale Eier.
- [ ] „3 öffnen“ mit Geheim-Chance 100 → 3 Geheim-Karten, Effekte einmal.
- [ ] Legendär/Mythisch schlüpfen (Glücks-Trank, Admin „Pet geben“ zählt nicht – echtes Ei nötig, ggf. viele Münzen geben): Färbung in Orange/Pink + Lichtstrahlen, normale Länge. Gewöhnlich–Episch: wie bisher.
- [ ] Banner oben unter den Meldungen: „🌟 Name hat Mozzarella-Geist geschlüpft! (Geheim)“ mit Pet-Bild, läuft nach 6 s raus; nichts überdeckt Münzen/Pizza-Balken.
- [ ] **2 Server** (Test-Experience, veröffentlicht; in Studio geht MessagingService nur eingeschränkt): auf Server A mit Geheim-Chance 100 ein Ei öffnen → Banner erscheint auf Server B (Handy/zweites Konto). Im Output keine „publish failed“-Warnung.
- [ ] Drossel: auf Server A schnell 6× schlüpfen (Geheim-Chance 100) → auf A alle 6 Banner nacheinander (max. 3 in der Warteschlange), auf B höchstens 5 pro Minute; Output „throttled“ beim 6.
- [ ] ⚙️ → Bildschirm-Blitze **aus** → bei Geheim/Legendär kein Blitz, keine Färbung, keine Strahlen; die lange Geheim-Animation und „GEHEIM!“ bleiben. ⚙️ → Ei-Animation überspringen **an** → Karten sofort (auch bei Geheim keine Spannungs-Phase), Färbung/Strahlen/„GEHEIM!“ (bei Blitzen an) trotzdem.
- [ ] `GameConfig.features.secretAnnouncement = false` → kein Banner, Schlüpfen geht. `secretPets = false` → keine Geheim-Zeile in der Vorschau, Admin-Aktionen weg, kein Geheim-Wurf. Danach wieder `true`.

## MEGA UPDATE – #78 Welten-Menü mit Karten und 3D-Vorschau

Neu: Das Portal-Menü (und die Welten-Kachel der Seitenleiste) zeigt jede Welt aus `GameConfig.worlds` als Karte mit kleiner, schwenkender 3D-Insel (Farben aus dem Insel-Thema, Wahrzeichen-Modell; fehlt das Modell oder das Thema – z. B. die Welten 8–15, bis ihre Modelle kommen – eine Ersatzform in der Weltfarbe). Gesperrte Karten sind dunkel, mit 🔒 und dem, was noch fehlt („Erst Strand“, „2 Rebirths“, „5 Mio Münzen“ – jeweils der fehlende Rest, direkt aus den Regeln). Schalter: `GameConfig.features.worldMenu`.

Vorher: `lune run test` → alle grün (u. a. `tests/WorldMenu.spec.luau`).

Studio, Rojo verbinden, **Play** (Admin-Panel #74):

- [ ] Neuer Spielstand (Admin: **Fortschritt zurücksetzen**), ins Portal der Spawn-Insel laufen: Titel „🌍 Welten“, darunter „1/7 offen“; 3 Karten pro Reihe, jede mit Nummer oben links, 3D-Insel und Namen. Welt 1 zeigt „📍 Du bist hier“ bzw. „Reisen“. Output ohne rote Fehler.
- [ ] Gesperrte Karten: dunkel mit 🔒; Bauernhof „Es fehlt: … Münzen“, Strand „Erst Bauernhof“ + Münzen, Vulkan zusätzlich „1 Rebirth“, Weltraum „2 Rebirths“.
- [ ] Admin: **Münzen geben** 1500 im Portal stehend → Bauernhof-Karte wechselt sofort auf grün „Am Tor freischalten / 1.500 Münzen“. Am Tor kaufen, zurück ins Portal: Bauernhof offen mit „Reisen“, Reisen klappt.
- [ ] Admin: **Rebirths setzen** 1 → Vulkan zeigt nur noch die fehlenden Münzen (und ggf. „Erst Eisberge“), Weltraum „1 Rebirth“.
- [ ] Welten-Kachel irgendwo auf der Insel: dieselben Karten mit „Zum Reisen in ein Portal stellen“, ohne „Reisen“-Knöpfe, offene Welten mit „✅ Offen“. Admin **Münzen geben** bei offenem Menü → fehlende Münzen werden innerhalb ~1 s weniger. X schließen, Kachel erneut → geht wieder auf.
- [ ] 3D-Vorschau: mit importierten Modellen stehen Windmühle, Leuchtturm, Eisgipfel, Vulkan, Torte, Rakete bzw. Riesenpizza auf den Inseln; ohne Import eine runde Ersatzform in Weltfarbe. Schwenkt sanft, ruckelt nicht.
- [ ] Mit `Language = en`: „🌍 Worlds“, „Missing:“, „2 rebirths“, „5M coins“, „First Farm“, „Unlock at the gate“, englische Weltnamen.
- [ ] Handy (iPhone SE / iPhone 14 Landscape): Menü füllt fast den Bildschirm, Karten scrollen senkrecht bis Welt 7 (später 15), „Reisen“ gut mit dem Daumen drückbar, nichts abgeschnitten.
- [ ] `GameConfig.features.worldMenu = false` → alte Liste mit einem Knopf pro Welt wie vorher. Danach wieder `true`.
- [ ] Sobald die Welten 8–15 (#82–#89) in der Config sind: alle 15 Karten da, auch ohne importierte Modelle (Ersatzform).

## MEGA UPDATE – #79 Kamerafahrt beim ersten Betreten einer Welt

Neu: Beim ersten Betreten einer Welt (über die Brücke oder per Portal) fliegt die Kamera ca. 3,5 s im Bogen über die Insel und gleitet zurück hinter den Charakter. Dazu großer Welt-Name, „Neue Welt!“ und die in dieser Welt neuen Beläge (3D-Modell, ohne Modell farbiger Kreis mit Anfangsbuchstabe). Einmal pro Spieler und Welt (Feld `seenWorldIntros`, bleibt beim Rebirth). Nicht in der Start-Welt (Pizzeria-Garten, dort läuft das Tutorial). Dauer: `GameConfig.worldIntro.seconds`. Schalter: `GameConfig.features.worldIntro`.

Vorher: `lune run test` → alle grün (u. a. `tests/WorldIntro.spec.luau`).

Studio, Rojo verbinden, **Play** (PC-Ansicht):

- [ ] Admin-Panel: „Welten freischalten (bis)“ → Bauernhof, über die Brücke in den Bauernhof laufen: Schwarze Kino-Balken, weißer Blitz, Kamera fliegt um die Insel, „Neue Welt!“ + „Bauernhof“ groß, darunter „Neue Beläge“ mit Zwiebel, Paprika, Mais, Schinken (nacheinander aufploppend). Danach normale Kamera hinter dem Charakter, Laufen geht wieder. Output ohne rote Fehler.
- [ ] Während der Fahrt kann man nicht laufen. Klick irgendwohin (oder eine Taste) → sofort zurück zur normalen Kamera. Unten steht „Klicken zum Überspringen“.
- [ ] Zurück in den Pizzeria-Garten und wieder in den Bauernhof: **keine** zweite Fahrt. Stop, erneut Play (Rejoin): auch nach dem Respawn im Bauernhof keine Fahrt.
- [ ] Portal: Admin-Panel → bis Strand freischalten, im Portal „Strand“ wählen: Fahrt startet nach dem Teleport über dem Strand und endet hinter dem Charakter am Ankunftspunkt (nicht an der alten Stelle).
- [ ] Admin-Panel „Welt-Intros wieder zeigen“: die Fahrt der aktuellen Welt startet nach ~0,5 s erneut (zum Testen). Zweimal hintereinander → „NotSeen“.
- [ ] Einstellungen: „Kamera-Wackeln“ AN → kurzes leichtes Rütteln am Anfang; AUS → ganz ruhige Fahrt. „Bildschirm-Blitze“ AUS → kein weißer Blitz am Anfang.
- [ ] Welten 4–7 (Admin-Panel: Rebirths setzen 2, Welten freischalten bis Weltraum): jede Welt zeigt ihren Namen und die eigenen 3 neuen Beläge, die Kamera schaut auf die richtige Insel.
- [ ] Sprache Englisch: „New world!“, „Farm“, „New toppings“ mit englischen Belag-Namen, „Click to skip“.
- [ ] Handy-Ansicht (Device-Emulator): Tippen überspringt, Text „Tippen zum Überspringen“, Belag-Karten passen in eine Reihe, Welt-Name nicht abgeschnitten.
- [ ] Schalter `features.worldIntro = false`: keine Fahrt, Admin-Aktion nicht im Panel.

## MEGA UPDATE – #80 Pets verschmelzen (Gold, Regenbogen) und Shiny

5 gleiche Pets → 1 **Gold** (Bonus ×2,5), 5 gleiche Gold → 1 **Regenbogen** (×6), immer erfolgreich. **Shiny** 1 : 200 pro geschlüpftem Pet (+50 %, auch als Gold/Regenbogen), Glücks-Trank ×2. Schalter: `petMerge` (Verschmelzen, Knöpfe, roter Punkt), `shinyPets` (Wurf, Admin-Shiny-Chance). Sounds `Shiny` und `Merge` in `src/client/Sounds.luau` haben noch **keine ID** (Suchbegriffe stehen dort).

Vorher: `lune run test` → alle grün (u. a. `tests/PetVariants.spec.luau`).

Studio, Rojo verbinden, **Play** (als Admin; ggf. Admin „Upgrade-Stufe setzen“ InventorySpace/PetSlots max):

- [ ] Admin → **Pet mit Variante geben** (Pet, Variante Normal, Shiny Nein, Anzahl 5) → Pets-Kachel bekommt den **roten Punkt**; im Pet-Menü auf jeder Karte „Vergolden (5/5)“ in Gold. Mit 3 Pets: „Vergolden (3/5)“ grau, Tippen tut nichts.
- [ ] „Vergolden (5/5)“ tippen → 5 Pet-Bilder fliegen in die Mitte, goldener Blitz, große Karte „Gold-… entstanden! +… %“, Sound `Merge`. Danach: 1 Gold-Pet mit goldenem Rahmen, Bonus = 2,5 × Grundbonus, roter Punkt weg.
- [ ] Ausgerüstete mitverschmelzen: 5 gleiche, 2 davon ausrüsten → verschmelzen → das neue Gold-Pet ist ausgerüstet (folgt dir, leuchtet golden), die Zusammenfassung „Bonus“ oben stimmt.
- [ ] Admin → 5× Gold geben → „Regenbogen (5/5)“ → Regenbogen-Pet: bunter Rahmen, folgendes Pet leuchtet in wechselnden Farben, Name „Regenbogen-…“ über dem Pet; Regenbogen-Karte hat keinen Verschmelzen-Knopf.
- [ ] Admin → **Shiny-Chance testen** 100 → Ei öffnen: goldener Kartenrahmen, „✨ Name“, Seltenheit „· ✨ Shiny“, Bonus +50 %, großes „✨ SHINY!“, goldener Blitz, Karte bleibt ~5 s; folgendes Shiny-Pet funkelt. Danach **0** → wieder normal.
- [ ] Shiny + Geheim (Geheim-Chance 100 und Shiny-Chance 100) → Titel „🤫 GEHEIM!  ✨ SHINY!“.
- [ ] 1 Shiny + 4 normale gleiche verschmelzen → Ergebnis „✨ Gold-…“ (Shiny bleibt erhalten).
- [ ] **Beste ausrüsten** mit einem Regenbogen-Pet eines schwachen Pets und stärkeren normalen Pets → wählt nach echtem Bonus (Karte zeigt effektiven Bonus).
- [ ] ⚙️ Ei-Animation überspringen **an** → Verschmelzen zeigt sofort das Ergebnis (kein Zusammenflug); Bildschirm-Blitze **aus** → kein goldener Blitz (Verschmelzen und Shiny-Schlüpfen).
- [ ] Löschen-Modus: keine Verschmelzen-Knöpfe auf den Karten; Löschen-Frage nennt „Gold-…“ und den echten Bonus.
- [ ] Handy: Pet-Karten mit Knopf gut tippbar, Knopf-Text passt (auch Englisch „Make gold (5/5)“).
- [ ] Rejoin → Gold/Regenbogen/Shiny bleiben erhalten.
- [ ] `GameConfig.features.petMerge = false` → keine Knöpfe, kein roter Punkt, Server lehnt ab; vorhandene Gold-Pets behalten ihren Bonus. `shinyPets = false` → keine Shinys mehr, Admin-Shiny-Chance weg. Danach wieder `true`.
