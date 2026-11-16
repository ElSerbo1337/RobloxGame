# RobloxGame

Roblox-Spiel, Code-Verwaltung mit [Rojo](https://rojo.space) + Git.

## Einmalige Einrichtung (Windows-PC)

1. **Git** installieren: https://git-scm.com/download/win
2. **Rokit** (Tool-Manager) installieren: https://github.com/rojo-rbx/rokit – Installer aus den Releases ausführen, Terminal neu öffnen.
3. Repo in den Projektordner klonen (PowerShell):
   ```powershell
   cd "G:\Claude"
   git clone https://github.com/ElSerbo1337/RobloxGame.git "Roblox Game"
   cd "G:\Claude\Roblox Game"
   rokit install
   ```
   (Falls `G:\Claude\Roblox Game` schon existiert und leer ist: vorher löschen oder `git clone ... .` darin ausführen.)
4. **Rojo-Plugin** für Studio installieren: `rojo plugin install`
5. Empfohlen: **VS Code** mit den Erweiterungen *Rojo*, *Luau Language Server*, *StyLua*, *Selene*.

## Täglicher Ablauf

1. Neueste Änderungen holen:
   ```powershell
   git pull
   ```
2. Rojo-Server starten:
   ```powershell
   rojo serve
   ```
3. Roblox Studio öffnen → Place öffnen → Plugins-Tab → **Rojo** → **Connect**. Ab jetzt werden Änderungen in `src/` live in Studio übernommen.
4. Im Studio testen (Play). Eigene Änderungen am Code committen und pushen:
   ```powershell
   git add -A
   git commit -m "Beschreibung"
   git push
   ```

## Struktur

- `src/server` → ServerScriptService
- `src/client` → StarterPlayerScripts
- `src/shared` → ReplicatedStorage
- `docs/` → Entscheidungen (ADRs) und Agent-Konfiguration
- `.claude/skills/` → Skills für Claude Code (aus mattpocock/skills)

## Arbeiten mit Claude

Claude arbeitet direkt in diesem Repo (auch aus der Cloud/vom Handy). Nützliche Befehle:

- `/grill-me` – Idee/Plan durchlöchern lassen, bis alles geklärt ist
- `/to-spec` – Gespräch als Spec (GitHub Issue) festhalten
- `/to-tickets` – Spec in einzelne Tickets zerlegen
- `/implement` – Tickets umsetzen
- `/ask-matt` – fragen, welcher Skill gerade passt
