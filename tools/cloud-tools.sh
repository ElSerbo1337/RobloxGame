#!/usr/bin/env bash
# Installs the pinned test/format tools (same versions as rokit.toml) for cloud sessions,
# where Rokit cannot reach the GitHub API. Idempotent; installs into $HOME/.cloud-tools/bin.
# Usage: bash tools/cloud-tools.sh && export PATH="$HOME/.cloud-tools/bin:$PATH"
set -euo pipefail
DEST="$HOME/.cloud-tools/bin"
mkdir -p "$DEST"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
if ! "$DEST/lune" --version 2>/dev/null | grep -q "0.10.4"; then
	curl -fsSL -o "$TMP/lune.zip" "https://github.com/lune-org/lune/releases/download/v0.10.4/lune-0.10.4-linux-x86_64.zip"
	unzip -oq "$TMP/lune.zip" -d "$TMP/lune"
	install -m 755 "$TMP/lune/lune" "$DEST/lune"
fi
if ! "$DEST/stylua" --version 2>/dev/null | grep -q "2.6.0"; then
	curl -fsSL -o "$TMP/stylua.zip" "https://github.com/JohnnyMorganz/StyLua/releases/download/v2.6.0/stylua-linux-x86_64.zip"
	unzip -oq "$TMP/stylua.zip" -d "$TMP/stylua"
	install -m 755 "$TMP/stylua/stylua" "$DEST/stylua"
fi
"$DEST/lune" --version
"$DEST/stylua" --version
