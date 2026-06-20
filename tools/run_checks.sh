#!/usr/bin/env bash
#
# Runs the headless validation suite — every tools/validate_*.gd — and the content
# lint, failing if any check does not report "RESULT: PASS". This is what CI runs,
# and what you should run locally before pushing.
#
# Godot is found via $GODOT (path to the binary), else `godot` on PATH. The project
# is imported once if it hasn't been (a fresh checkout has no .godot/).
#
#   GODOT=/path/to/Godot_v4.6 bash tools/run_checks.sh
#
set -uo pipefail

GODOT="${GODOT:-godot}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
	echo "ERROR: Godot not found. Set \$GODOT to the binary or put 'godot' on PATH." >&2
	exit 2
fi

# Import once so resources resolve (fresh checkout / new assets).
if [ ! -d ".godot" ]; then
	echo "Importing project (first run)..."
	"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
fi

fail=0
ran=0
for v in tools/validate_*.gd; do
	[ -e "$v" ] || continue
	ran=$((ran + 1))
	name="$(basename "$v")"
	out="$(timeout 180 "$GODOT" --headless -s "$v" 2>&1)"
	if printf '%s\n' "$out" | grep -q "RESULT: PASS"; then
		printf 'PASS  %s\n' "$name"
	else
		printf 'FAIL  %s\n' "$name"
		# Surface why: our own FAIL lines, the RESULT, and any hard script errors.
		printf '%s\n' "$out" | grep -E "FAIL:|RESULT:|SCRIPT ERROR|Parse Error" | sed 's/^/      /' | head -25
		fail=1
	fi
done

echo "----"
if [ "$fail" -eq 0 ]; then
	echo "All $ran checks passed."
else
	echo "Some checks failed."
fi
exit $fail
