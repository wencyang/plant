#!/bin/zsh
set -eu
project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
if [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
  exec /Applications/Godot.app/Contents/MacOS/Godot --path "$project_dir"
elif command -v godot >/dev/null 2>&1; then
  exec godot --path "$project_dir"
else
  print 'Open project.godot in Godot 4.7 or install Godot in /Applications.'
  read -r '?Press Enter to close.'
fi
