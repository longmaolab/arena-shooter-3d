#!/usr/bin/env bash
# Post-export hook: inject a cache-bust shim into docs/index.html so a new
# build's index.pck/index.wasm always defeats browser HTTP cache.
#
# Godot's bundled loader fetches "index.pck" / "index.wasm" by hard-coded
# URLs and the asset filenames don't change between builds, so once a
# browser has cached them under those URLs it will keep serving the stale
# bytes after every redeploy. We bake a unique hash from index.pck into
# the page and patch fetch() before engine.js loads to append `?v=<hash>`
# to all same-origin .pck/.wasm/.js requests.

set -e
cd "$(dirname "$0")/.."

PCK="docs/index.pck"
HTML="docs/index.html"
[ -f "$PCK" ] || { echo "no $PCK; run export first" >&2; exit 1; }

BUILD_ID=$(shasum -a 256 "$PCK" | cut -c1-16)
SHIM="<script>(function(){var B='${BUILD_ID}';var _f=window.fetch;window.fetch=function(u,o){if(typeof u==='string'){try{var x=new URL(u,location.href);if(x.origin===location.origin&&/\\\\.(pck|wasm|js)$/.test(x.pathname)){x.searchParams.set('v',B);u=x.toString();}}catch(_){}}return _f(u,o);};})();</script>"

# Idempotent: if a shim block exists, replace it.
python3 - "$HTML" "$SHIM" <<'PYEOF'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1])
shim = sys.argv[2]
src = p.read_text(encoding="utf-8")
# Strip any previous shim block (matches the start "var B='..." up to first </script>).
src = re.sub(r'<script>\(function\(\)\{var B=[^<]*</script>\n?', '', src)
# Insert the new shim right before the bundled engine script.
needle = '<script src="index.js"></script>'
if needle in src:
    src = src.replace(needle, shim + "\n\t\t" + needle)
else:
    print("WARN: could not find bundled engine script tag, shim not injected", file=sys.stderr)
    sys.exit(2)
p.write_text(src, encoding="utf-8")
print(f"injected cache-bust shim, BUILD_ID prefix")
PYEOF

echo "BUILD_ID=$BUILD_ID"
