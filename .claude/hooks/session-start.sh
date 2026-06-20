#!/bin/bash
# SessionStart hook: make the Godot 4.6 headless validation suite runnable in
# Claude Code on the web. Downloads + caches the engine and imports the project so
# `bash tools/run_checks.sh` works in-session. Synchronous (the session waits) so a
# validator run never races the install. Web-only; locally you use your own Godot.
set -euo pipefail

# Only the remote (web) environment needs this; a local dev has Godot already.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
	exit 0
fi

GODOT_DIR="$HOME/.cache/teramor-godot"
GODOT_BIN="$GODOT_DIR/Godot_v4.6-stable_linux.x86_64"
GODOT_URL="https://github.com/godotengine/godot/releases/download/4.6-stable/Godot_v4.6-stable_linux.x86_64.zip"

mkdir -p "$GODOT_DIR"

# Download once; the cache (and the imported .godot/ below) ride the container
# snapshot taken after this hook, so later sessions start warm.
if [ ! -x "$GODOT_BIN" ]; then
	echo "[session-start] downloading Godot 4.6 headless..." >&2
	if curl -fsSL -o "$GODOT_DIR/godot.zip" "$GODOT_URL"; then
		unzip -oq "$GODOT_DIR/godot.zip" -d "$GODOT_DIR"
		chmod +x "$GODOT_BIN"
		rm -f "$GODOT_DIR/godot.zip"
	else
		echo "[session-start] WARNING: Godot download failed (network policy?); validation suite unavailable this session." >&2
		exit 0
	fi
fi

# Expose to the session as $GODOT and as `godot` on PATH.
ln -sf "$GODOT_BIN" "$GODOT_DIR/godot"
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
	echo "export GODOT=\"$GODOT_BIN\"" >> "$CLAUDE_ENV_FILE"
	echo "export PATH=\"$GODOT_DIR:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

# Import the project so resources resolve for the validators (idempotent).
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -f "$CLAUDE_PROJECT_DIR/project.godot" ]; then
	"$GODOT_BIN" --headless --path "$CLAUDE_PROJECT_DIR" --import >/dev/null 2>&1 || true
fi

echo "[session-start] Godot ready at $GODOT_BIN — run: bash tools/run_checks.sh" >&2
