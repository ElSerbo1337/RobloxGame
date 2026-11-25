# MEGA UPDATE – Prompt-Vorlage für Ticket-Sitzungen

Wird von der stündlichen Orchestrierung (frische Sitzung pro Lauf) genutzt: `{N}` = Ticketnummer, `{TITLE}` = Tickettitel, `{EXTRA}` = Besonderheiten (z. B. was Vorgänger-Tickets bereitstellen, was bewusst NICHT gebaut wird). Sitzung starten mit `source_revision: update-1`, `permission_mode: auto`, Titel `Mega X (#N): …`, Tags `mega-update`, `mega-N`.

```text
Du arbeitest autonom an genau EINEM Ticket des MEGA UPDATE für das Roblox-Spiel "Pizza Topping Simulator" im Repo ElSerbo1337/RobloxGame. Niemand schaut zu: frag nicht nach, entscheide selbst im Sinne der Spec und halte Entscheidungen im Ticket fest. Schicke KEINE Nachrichten an andere Sitzungen.

Ticket: #{N} "{TITLE}". Spec (alle Entscheidungen): #72. Andere Sitzungen arbeiten parallel an anderen Tickets auf demselben Branch.

Vorgehen:
1. Lies CLAUDE.md (Architektur, Regeln, Tests, Feature-Schalter-Helfer `src/shared/Features.luau`) und docs/ui-style.md. Lies Spec, Ticket und die Kommentare bereits geschlossener Vorgänger-Tickets per REST (GraphQL ist gesperrt): `gh api repos/ElSerbo1337/RobloxGame/issues/72 --jq .body`, `gh api repos/ElSerbo1337/RobloxGame/issues/{N} --jq .body`, `gh api repos/ElSerbo1337/RobloxGame/issues/<n>/comments --jq '.[].body'`.
2. Arbeite auf dem Branch `update-1` (bereits ausgecheckt; vorher `git pull`). Kein Commit auf main, nie etwas publishen.
3. Tools: Lune 0.10.4 und StyLua 2.6.0 aus den GitHub-Release-ZIPs holen (Rokit geht in der Cloud nicht): `https://github.com/lune-org/lune/releases/download/v0.10.4/lune-0.10.4-linux-x86_64.zip`, `https://github.com/JohnnyMorganz/StyLua/releases/download/v2.6.0/stylua-linux-x86_64.zip`, in ein Tool-Verzeichnis außerhalb des Repos.
4. Test-first für die Spielregeln (tests/*.spec.luau, TestKit, fixtures/TestConfig). Roblox-Schicht nach den Regeln in CLAUDE.md, Server validiert alles. Feature hinter seinem Schalter in `GameConfig.features` (Id existiert meist schon). Alle neuen Texte de+en über `Texts`. Neue UI im Stil von docs/ui-style.md / UiKit (Seitenleiste aus #75: `SideBar.register`, rote Punkte per `SideBar.setBadge`, siehe docs/ui-style.md).
5. Am Ende: `lune run test` komplett grün, `stylua src tests .lune` angewendet. Kurze Studio-Prüfpunkte für dieses Ticket in docs/pc-todo.md unter "MEGA UPDATE – #{N} …" ergänzen (mit Admin-Panel statt Config-Tricks, sobald es das gibt).
6. Kleine Commits auf Englisch, dann `git fetch origin update-1 && git rebase origin/update-1`, Konflikte sauber lösen, Tests erneut grün, `git push origin update-1`. Bei Ablehnung: erneut fetch/rebase/test/push, bis es klappt.
7. Im Ticket kommentieren (Deutsch): was gebaut wurde, Entscheidungen, Commit-Hash, was in Studio zu prüfen ist. Dann Ticket schließen (`gh api -X PATCH repos/ElSerbo1337/RobloxGame/issues/{N} -f state=closed`). Was wirklich nur der User entscheiden/tun kann: Kommentar plus Label `needs-info`, Rest trotzdem fertig bauen.
Besonderheiten für dieses Ticket:
{EXTRA}
```
