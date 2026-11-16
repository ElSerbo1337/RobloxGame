# One-time setup for RobloxGame on Windows.
# Run in PowerShell:
#   irm https://raw.githubusercontent.com/ElSerbo1337/RobloxGame/main/setup.ps1 | iex
# Optional other target folder: set $env:ROBLOXGAME_DIR before running.

$ErrorActionPreference = "Stop"
$RepoUrl = "https://github.com/ElSerbo1337/RobloxGame.git"
$Target = if ($env:ROBLOXGAME_DIR) { $env:ROBLOXGAME_DIR } else { "G:\Claude\Roblox Game" }

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [Environment]::GetEnvironmentVariable("Path", "User") + ";" +
                "$env:USERPROFILE\.rokit\bin"
}

# 1. Git
Step "Git pruefen"
Refresh-Path
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Git wird installiert (winget)..."
    winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements
    Refresh-Path
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git konnte nicht installiert werden. Bitte manuell installieren: https://git-scm.com/download/win"
    }
}
Write-Host "OK: $(git --version)"

# 2. Rokit
Step "Rokit pruefen"
if (-not (Get-Command rokit -ErrorAction SilentlyContinue)) {
    Write-Host "Rokit wird heruntergeladen..."
    $release = Invoke-RestMethod "https://api.github.com/repos/rojo-rbx/rokit/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -like "*windows-x86_64*.zip" } | Select-Object -First 1
    if (-not $asset) { throw "Kein Windows-Download fuer Rokit gefunden." }
    $tmp = Join-Path $env:TEMP "rokit-setup"
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $tmp | Out-Null
    $zip = Join-Path $tmp $asset.name
    Invoke-WebRequest $asset.browser_download_url -OutFile $zip
    Expand-Archive $zip -DestinationPath $tmp
    $exe = Get-ChildItem $tmp -Recurse -Filter rokit.exe | Select-Object -First 1
    & $exe.FullName self-install
    Refresh-Path
}
Write-Host "OK: $(rokit --version)"

# 3. Repository
Step "Projekt nach '$Target' holen"
if (Test-Path (Join-Path $Target ".git")) {
    Write-Host "Projekt existiert schon, hole neueste Aenderungen..."
    git -C $Target pull
} elseif ((Test-Path $Target) -and (Get-ChildItem $Target -Force | Select-Object -First 1)) {
    throw "Der Ordner '$Target' ist nicht leer und kein Git-Projekt. Bitte leeren oder einen anderen Ordner waehlen."
} else {
    New-Item -ItemType Directory -Path (Split-Path $Target) -Force | Out-Null
    git clone $RepoUrl $Target
}

# 4. Tools + Studio plugin
Set-Location $Target
Step "Werkzeuge installieren (rojo, stylua, selene)"
Write-Host "Falls Rokit fragt, ob du den Tools vertraust: mit 'y' bestaetigen."
rokit install
Refresh-Path

Step "Rojo-Plugin fuer Roblox Studio installieren"
rojo plugin install

Step "Fertig!"
Write-Host @"
Naechste Schritte:
  1. Roblox Studio neu starten (damit das Rojo-Plugin erscheint)
  2. Neue Baseplate erstellen -> File -> Publish to Roblox
  3. In diesem Ordner: rojo serve
  4. In Studio: Plugins -> Rojo -> Connect, dann Play
"@ -ForegroundColor Green
