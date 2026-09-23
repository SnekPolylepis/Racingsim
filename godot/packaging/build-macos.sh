#!/bin/bash
# Run from any directory. GODOT_BIN may point to another 4.6.2 editor.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$ROOT/tools/Godot.app/Contents/MacOS/Godot}"
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'Run this packaging script on macOS.' >&2
  exit 1
fi
if [[ ! -x "$GODOT_BIN" || ! -f "$ROOT/tools/macos.zip" ]]; then
  echo 'Install Godot 4.6.2 and its Mac template: python3 godot/packaging/fetch-macos.py' >&2
  echo 'See godot/docs/MACOS.md for manual installation without Python.' >&2
  exit 1
fi
if [[ "$("$GODOT_BIN" --headless --version)" != 4.6.2.stable.* ]]; then
  echo 'This project requires Godot 4.6.2 stable.' >&2
  exit 1
fi
mkdir -p "$ROOT/build/macos"
"$GODOT_BIN" --headless --path "$ROOT" --import
"$GODOT_BIN" --headless --path "$ROOT" --export-release macOS "$ROOT/build/macos/Racing Sim.app"
for notice in GODOT-LICENSE.txt GODOT-THIRD-PARTY-NOTICES.txt CC0-1.0.txt RAJDHANI-OFL.txt; do
  cp "$ROOT/build/$notice" "$ROOT/build/macos/$notice"
done
cp "$ROOT/THIRD-PARTY.md" "$ROOT/build/macos/THIRD-PARTY.md"
cp "$ROOT/packaging/PLAY-MACOS.txt" "$ROOT/build/macos/PLAY.txt"
/usr/bin/codesign --verify --deep --strict "$ROOT/build/macos/Racing Sim.app"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$ROOT/build/macos" "$ROOT/build/RacingSim-macOS.zip"
echo "Built $ROOT/build/macos/Racing Sim.app"
echo "Packaged $ROOT/build/RacingSim-macOS.zip"
