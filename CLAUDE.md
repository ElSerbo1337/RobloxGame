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

### Domain docs

Single-context: ein `GLOSSARY.md` + `docs/adr/` im Repo-Root. See `docs/agents/domain.md`.
