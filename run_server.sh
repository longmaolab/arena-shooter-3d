#!/usr/bin/env bash
# Run the dedicated game server (headless Godot, no window, no player).
# Listens on ws://localhost:7777
# Use cloudflared in another terminal to expose it publicly.

set -e
cd "$(dirname "$0")"

# Find Godot.app in common locations.
if [ -n "$GODOT_BIN" ] && [ -x "$GODOT_BIN" ]; then
  : # use env var as-is
else
  CANDIDATES=(
    "/Applications/Godot.app/Contents/MacOS/Godot"
    "$HOME/Applications/Godot.app/Contents/MacOS/Godot"
    "$HOME/Downloads/Godot.app/Contents/MacOS/Godot"
    "$HOME/Desktop/Godot.app/Contents/MacOS/Godot"
  )
  GODOT_BIN=""
  for c in "${CANDIDATES[@]}"; do
    if [ -x "$c" ]; then
      GODOT_BIN="$c"
      break
    fi
  done
  # Fallback: spotlight search.
  if [ -z "$GODOT_BIN" ]; then
    APP=$(mdfind "kMDItemFSName == 'Godot.app'" 2>/dev/null | head -1)
    if [ -n "$APP" ] && [ -x "$APP/Contents/MacOS/Godot" ]; then
      GODOT_BIN="$APP/Contents/MacOS/Godot"
    fi
  fi
fi

if [ -z "$GODOT_BIN" ] || [ ! -x "$GODOT_BIN" ]; then
  echo "❌ Godot not found"
  echo "   Set GODOT_BIN env var, e.g.:"
  echo "   GODOT_BIN=/path/to/Godot.app/Contents/MacOS/Godot ./run_server.sh"
  exit 1
fi

echo "→ Starting headless game server on port 7777..."
echo "   (Godot: $GODOT_BIN)"
echo "   (Ctrl+C to stop)"
echo ""
"$GODOT_BIN" --headless --path . -- --server
