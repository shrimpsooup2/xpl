#!/usr/bin/env bash
# Puts the website together: site/ plus the logo, the icon and the font
# from assets/, into _site/ (or the folder given). The GitHub Pages workflow
# (.github/workflows/pages.yml) runs it; to look at it locally:
#
#   tools/build_site.sh && python3 -m http.server -d _site
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/_site}"

rm -rf "$OUT"
mkdir -p "$OUT/assets"
cp -R "$ROOT/site/." "$OUT/"
cp "$ROOT/assets/ui/logo.png" "$ROOT/assets/ui/icon.png" \
	"$ROOT/assets/fonts/LiberationSans-Regular.ttf" "$ROOT/assets/fonts/LICENSE-LiberationSans.txt" \
	"$OUT/assets/"
# Keeps Godot from importing the copies when the project is open.
touch "$OUT/.gdignore"
echo "built $OUT"
