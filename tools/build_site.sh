#!/usr/bin/env bash
# Puts the website together: site/ plus the logo, the icon and the font
# from assets/, into _site/ (or the folder given), with the game's version
# from project.godot stamped in. The GitHub Pages workflow
# (.github/workflows/pages.yml) runs it; to look at it locally:
#
#   tools/build_site.sh && python3 -m http.server -d _site
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/_site}"

# The version shown on the site: the game's, from project.godot (the one
# place it's set; docs/RELEASING.md).
VERSION="$(sed -n 's/^config\/version="\(.*\)"$/\1/p' "$ROOT/project.godot")"
if [[ -z "$VERSION" ]]; then
	echo "no application/config/version in project.godot" >&2
	exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT/assets"
cp -R "$ROOT/site/." "$OUT/"
sed -i.bak -e "s/data-version=\"[^\"]*\"/data-version=\"$VERSION\"/" \
	-e "s/<p class=\"version\">[^<]*<\/p>/<p class=\"version\">v$VERSION<\/p>/" "$OUT/index.html"
rm "$OUT/index.html.bak"
cp "$ROOT/assets/ui/logo.png" "$ROOT/assets/ui/icon.png" \
	"$ROOT/assets/fonts/LiberationSans-Regular.ttf" "$ROOT/assets/fonts/LICENSE-LiberationSans.txt" \
	"$OUT/assets/"
# Keeps Godot from importing the copies when the project is open.
touch "$OUT/.gdignore"
echo "built $OUT (v$VERSION)"
