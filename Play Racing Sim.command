#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/godot/build/macos/Racing Sim.app"
if [[ ! -d "$APP" ]]; then
  echo 'Build the Mac app first: bash godot/packaging/build-macos.sh'
  read -r -p 'Press Return to close.'
  exit 1
fi
exec /usr/bin/open "$APP" --args "$@"
