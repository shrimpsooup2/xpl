#!/usr/bin/env bash
# Runs the headless movement tests.
#
# Uses $GODOT if set, then `godot` on PATH, otherwise downloads the pinned
# Linux build into .tools/ (Linux x86_64 only).
set -euo pipefail

GODOT_VERSION="4.7.2"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -z "${GODOT:-}" ]]; then
	if command -v godot >/dev/null 2>&1; then
		GODOT="godot"
	else
		GODOT="$ROOT/.tools/Godot_v${GODOT_VERSION}-stable_linux.x86_64"
		if [[ ! -x "$GODOT" ]]; then
			mkdir -p "$ROOT/.tools"
			url="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
			echo "Downloading Godot ${GODOT_VERSION}..."
			curl -sSL -o "$ROOT/.tools/godot.zip" "$url"
			unzip -o -q "$ROOT/.tools/godot.zip" -d "$ROOT/.tools"
			rm "$ROOT/.tools/godot.zip"
			chmod +x "$GODOT"
		fi
	fi
fi

cd "$ROOT"
# Import first so class_name scripts are registered.
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
log="$(mktemp)"
set +e
"$GODOT" --headless --path . --fixed-fps 60 --script res://tests/run_tests.gd 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
set -e
if grep -qE "SCRIPT ERROR|Parse Error|ERROR:" "$log"; then
	echo "Engine errors were printed during the run (see above)."
	status=1
fi
rm -f "$log"
exit "$status"
