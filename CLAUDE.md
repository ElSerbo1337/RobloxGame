# RobloxGame

Roblox-Spiel, entwickelt mit **Rojo**: Der Code lebt als `.luau`-Dateien in `src/` und wird per Rojo live in Roblox Studio synchronisiert. Git (dieses Repo) ist die Quelle der Wahrheit, nicht die `.rbxl`-Datei.

Kommunikation mit dem User auf **Deutsch**. Code, Bezeichner und Commit-Messages auf Englisch.

## Struktur

| Ordner        | Landet in Studio unter                       | Zweck                        |
| ------------- | -------------------------------------------- | ---------------------------- |
| `src/server`  | `ServerScriptService.Server`                 | Server-Logik (`*.server.luau`) |
| `src/client`  | `StarterPlayer.StarterPlayerScripts.Client`  | Client-Logik (`*.client.luau`) |
| `src/shared`  | `ReplicatedStorage.Shared`                   | ModuleScripts für beide Seiten |

Mapping steht in `default.project.json`. Neue Top-Level-Services (z. B. `StarterGui`, `Workspace`-Modelle) dort eintragen.

Dateinamen-Konventionen (Rojo): `Foo.server.luau` = Script, `Foo.client.luau` = LocalScript, `Foo.luau` = ModuleScript, `init.*.luau` = der Ordner selbst wird zu diesem Script.

## Architektur: Spielregeln vs. Roblox-Schicht

- **Spielregeln** (`src/shared/GameRules.luau`, `src/shared/ToppingField.luau`, `src/shared/SaveData.luau`): reines Luau **ohne Roblox-API** (kein `game`, `Instance`, `script`, kein `require` anderer Module). Arbeiten auf einem `PlayerState` (reine Tabelle); jede Aktion liefert `{ ok, reason?, state }` und verändert den alten Stand nicht. Zeit (`now`) und Zufall (`random: () -> number`) werden als Parameter übergeben, die Konfiguration per `GameRules.new(config)`.
- **Speichern** (`src/shared/SaveData.luau` + `src/server/SaveService.luau`): Neue PlayerState-Felder nur in `rules.newPlayerState()` ergänzen – alte Spielstände bekommen sie beim Laden automatisch. Nur wenn ein bestehendes Feld seine Form/Bedeutung ändert: `STATE_VERSION` in `GameRules` erhöhen und einen Migrationsschritt in `SaveData` (mit Test) ergänzen. Schlägt das Laden fehl, wird für diesen Spieler nie gespeichert.
- **Zentrale Konfiguration** (`src/shared/GameConfig.luau`): alle Balancing-Zahlen, reine Daten. Neue Welten/Beläge nur hier ergänzen.
- **Feature-Schalter** (`GameConfig.features` + `src/shared/Features.luau`, #73): ein Boolean pro Feature des MEGA UPDATE. Neues Feature: Id dort eintragen (Default `true`), dann `local features = Features.new(GameConfig.features)`; Client baut UI nur bei `features.enabled("id")`, Server-Handler werden mit `features.guard("id", handler)` umhüllt. Unbekannte Ids werfen einen Fehler.
- **Roblox-Schicht** (`src/server/*`, `src/client/*`): Server-Dienste rufen ausschließlich die Spielregeln auf (`PlayerStates.set` nur mit Regel-Ergebnissen) und replizieren den Stand als Player-Attribute. Client sendet nur Wünsche über RemoteEvents aus `src/shared/Net.luau`.

## Tests (Lune)

- Ausführen: `lune run test` (Runner in `.lune/test.luau`, Lune via `rokit install`).
- Konvention: Specs liegen als `tests/**/*.spec.luau`, nutzen `tests/TestKit.luau` (`describe`/`it`/`expect`, `sequenceRandom` für deterministischen Zufall) und `require` mit relativen Pfaden (`../src/shared/GameRules`).
- Getestet wird nur die Spielregeln-Naht (Aktion auf Stand anwenden → Ergebnis prüfen). Regel-Tests nutzen `tests/fixtures/TestConfig.luau`, damit Balancing-Änderungen sie nicht brechen; `tests/GameConfig.spec.luau` prüft die echte Konfiguration.
- Roblox-Schicht wird manuell in Studio getestet (Checkliste in `docs/pc-todo.md`).
- Cloud-Hinweis: Rokit erreicht dort die GitHub-API nicht und `selene` kann den Roblox-API-Dump nicht laden (`setup.rbxcdn.com` gesperrt). Tools dann direkt aus den GitHub-Release-ZIPs holen und Selene mit einer temporären Std (Basis `luau` + Roblox-Globals als `any`) laufen lassen.

## Regeln

- Sprache: **Luau**, mit `--!strict` wo sinnvoll.
- Nie dem Client vertrauen: Spielrelevante Logik (Währung, Schaden, Inventar) läuft auf dem Server; Client sendet nur Wünsche über RemoteEvents, Server validiert.
- Formatierung: `stylua src`, Linting: `selene src` (Tools via `rokit install`).
- Assets, Terrain und gebaute Maps leben in Studio; wenn sie versioniert werden sollen, als `.rbxm` explizit in `assets/` ablegen und in `.gitignore` freigeben.
- Arbeiten in einem Cloud-Container: Roblox Studio ist dort nicht verfügbar. Änderungen werden gepusht, der User zieht sie (`git pull`) auf seinem PC und testet in Studio.

## Arbeitsweise: Cloud bereitet vor, lokal wird ausgeführt

- **Cloud-Sitzung** (User nicht am PC): baut Code, Maps, UI und 3D-Modelle (Blender headless via `pip install bpy`, Export nach `assets/`), rendert Vorschaubilder, pusht alles nach `main`. Was nur in Studio geht, kommt als Checkliste in `docs/pc-todo.md`.
- **Lokale Sitzung** (Claude-Desktop-App auf dem Windows-PC/Laptop mit Roblox Studio): Wenn der User „sync“ schreibt:
  1. `git pull`, dann `rokit install` (falls Rokit fehlt: `setup.ps1` ausführen).
  2. `rojo serve` im Hintergrund starten.
  3. `docs/pc-todo.md` abarbeiten. Wenn Bildschirmsteuerung (computer use) verfügbar ist: Studio öffnen, Plugins → Rojo → Connect, Play drücken, Output lesen, Screenshots machen. Sonst dem User die Klicks Schritt für Schritt nennen.
  4. Gefundene Fehler beheben, erledigte Punkte aus `docs/pc-todo.md` streichen, committen und pushen.
  5. Dem User kurz berichten (mit Screenshots, falls vorhanden).

## Agent skills

### Issue tracker

Issues und Specs leben als GitHub Issues in `ElSerbo1337/RobloxGame`. See `docs/agents/issue-tracker.md`.

### Triage labels

Die fünf Standard-Labels (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### UI-Stil

Gemeinsamer Stil für alle UIs und den 3D-Look: `docs/ui-style.md` (umgesetzt in `src/client/UiKit.luau`).

### Domain docs

Single-context: ein `GLOSSARY.md` + `docs/adr/` im Repo-Root. See `docs/agents/domain.md`.
