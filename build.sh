#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
JS_DIR="$DIR/atmos/env/js"
OUT_DIR="$DIR"

# --- Helpers ---

generate_html () {
    local title="$1" js_files="$2" out="$3"

    local js_code=""
    for f in $js_files; do
        js_code+="$(cat "$f")"$'\n'
    done

    cat > "$out" <<ENDHTML
<!DOCTYPE html>
<html>
<head><title>$title</title></head>
<body>
    <pre id="output"></pre>
    <span id="status"></span>

    <script type="module">
$js_code
    </script>
</body>
</html>
ENDHTML
    echo "  wrote $out"
}

# --- Generate HTML files ---

echo "Generating HTML files..."

generate_html \
    "Lua" \
    "$JS_DIR/run.js $JS_DIR/lua.js" \
    "$OUT_DIR/lua.html"

generate_html \
    "lua-atmos" \
    "$JS_DIR/run.js $JS_DIR/lua-atmos.js" \
    "$OUT_DIR/lua-atmos.html"

generate_html \
    "Atmos" \
    "$JS_DIR/run.js $JS_DIR/atmos.js" \
    "$OUT_DIR/atmos.html"

echo "Done."
