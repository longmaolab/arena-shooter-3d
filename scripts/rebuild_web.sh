#!/usr/bin/env bash
# One-shot: clean caches, export Web, inject cache-bust shim.
# After running this, `git add -A && git commit && git push` to publish.
#
# Why "clean caches": Godot's CLI export reuses .godot/exported/*.gdc
# even when source changed. Skipping this step has shipped silently-stale
# pcks here before.
#
# Why "cache-bust shim": browsers cache index.pck/wasm by URL; without
# this, returning visitors don't see new builds until hard-refresh.

set -e
cd "$(dirname "$0")/.."

# Locate Godot.
if [ -n "$GODOT_BIN" ] && [ -x "$GODOT_BIN" ]; then
  :
else
  for c in \
    "/Applications/Godot.app/Contents/MacOS/Godot" \
    "$HOME/Applications/Godot.app/Contents/MacOS/Godot" \
    "$HOME/Downloads/Godot.app/Contents/MacOS/Godot" \
    "$HOME/Desktop/Godot.app/Contents/MacOS/Godot"; do
    [ -x "$c" ] && GODOT_BIN="$c" && break
  done
fi
[ -z "$GODOT_BIN" ] && { echo "Godot not found, set GODOT_BIN" >&2; exit 1; }

echo "→ clearing Godot export cache..."
rm -rf .godot/exported .godot/imported

echo "→ headless export..."
"$GODOT_BIN" --headless --path . --export-release "Web" docs/index.html

echo "→ cleaning leaked .import files..."
find docs -name "*.import" -delete

echo "→ injecting cache-bust shim..."
./scripts/post_export.sh

PCK_HASH=$(shasum -a 256 docs/index.pck | cut -c1-12)
echo ""
echo "✓ rebuild complete. pck hash: $PCK_HASH"
echo "  next: git add -A && git commit -m 'rebuild' && git push"
