#!/usr/bin/env bash
# Run the dedicated game server (headless Godot, no window, no player).
# Listens on ws://localhost:7777
# Use cloudflared in another terminal to expose it publicly.

set -e
cd "$(dirname "$0")"

PORT="${PORT:-7777}"

# ---- Free the port if a previous Godot server is still holding it ----
# Only kill processes whose command line looks like a Godot server, so we
# never take down some unrelated service that happens to bind 7777.
existing_pids=$(lsof -nP -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true)
if [ -n "$existing_pids" ]; then
  godot_pids=""
  other_pids=""
  for pid in $existing_pids; do
    cmd=$(ps -p "$pid" -o command= 2>/dev/null || true)
    if echo "$cmd" | grep -Eqi 'godot.*--server|godot.*--headless'; then
      godot_pids="$godot_pids $pid"
    else
      other_pids="$other_pids $pid (cmd: $cmd)"
    fi
  done
  if [ -n "$other_pids" ]; then
    echo "❌ Port $PORT is held by non-Godot process(es):"
    echo "   $other_pids"
    echo "   Refusing to kill. Stop them manually, or override with:"
    echo "   PORT=<other_port> ./run_server.sh"
    exit 1
  fi
  if [ -n "$godot_pids" ]; then
    echo "⚠️  Leftover Godot server PID(s):$godot_pids — killing..."
    # shellcheck disable=SC2086
    kill $godot_pids 2>/dev/null || true
    sleep 1
    remaining=$(lsof -nP -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true)
    if [ -n "$remaining" ]; then
      # shellcheck disable=SC2086
      kill -9 $remaining 2>/dev/null || true
      sleep 1
    fi
    echo "✓ Port $PORT freed."
    echo ""
  fi
fi

# ---- Find Godot.app in common locations ----
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
  if [ -z "$GODOT_BIN" ]; then
    APP=$(mdfind "kMDItemFSName == 'Godot.app'" 2>/dev/null | head -1)
    if [ -n "$APP" ] && [ -x "$APP/Contents/MacOS/Godot" ]; then
      GODOT_BIN="$APP/Contents/MacOS/Godot"
    fi
  fi
fi

if [ -z "$GODOT_BIN" ] || [ ! -x "$GODOT_BIN" ]; then
  echo "❌ Godot not found. Set GODOT_BIN env var, e.g.:"
  echo "   GODOT_BIN=/path/to/Godot.app/Contents/MacOS/Godot ./run_server.sh"
  exit 1
fi

echo "→ Starting headless game server on port $PORT..."
echo "   (Godot: $GODOT_BIN)"
echo "   (Ctrl+C to stop)"
echo ""
exec "$GODOT_BIN" --headless --path . -- --server
