#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
JS_DIR="$DIR"
OUT_DIR="$DIR"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

VERSION="v0.5"

GITHUB_RAW="https://raw.githubusercontent.com"

# --- Module lists (name  repo  version  path) ---

LUA_ATMOS_MODULES=(
    'streams         lua-atmos/f-streams  main  streams/init.lua'
    'atmos           lua-atmos/atmos      main  atmos/init.lua'
    'atmos.util      lua-atmos/atmos      main  atmos/util.lua'
    'atmos.run       lua-atmos/atmos      main  atmos/run.lua'
    'atmos.streams   lua-atmos/atmos      main  atmos/streams.lua'
    'atmos.x         lua-atmos/atmos      main  atmos/x.lua'
    'atmos.env.js    lua-atmos/atmos      main  atmos/env/js/init.lua'
)

ATMOS_LANG_MODULES=(
    'atmos.lang.global   atmos-lang/atmos  main  src/global.lua'
    'atmos.lang.aux      atmos-lang/atmos  main  src/aux.lua'
    'atmos.lang.lexer    atmos-lang/atmos  main  src/lexer.lua'
    'atmos.lang.parser   atmos-lang/atmos  main  src/parser.lua'
    'atmos.lang.prim     atmos-lang/atmos  main  src/prim.lua'
    'atmos.lang.coder    atmos-lang/atmos  main  src/coder.lua'
    'atmos.lang.tosource atmos-lang/atmos  main  src/tosource.lua'
    'atmos.lang.exec     atmos-lang/atmos  main  src/exec.lua'
    'atmos.lang.run      atmos-lang/atmos  main  src/run.lua'
)

# --- Helpers ---

fetch_module () {
    local name="$1" repo="$2" version="$3" path="$4"
    local url="$GITHUB_RAW/$repo/$version/$path"
    local dest="$TMP/$name.lua"
    echo "  fetch $name ($repo/$path)"
    curl -fsSL "$url" -o "$dest"
}

module_tag () {
    local name="$1"
    local src="$TMP/$name.lua"
    printf '    <script type="text/lua" data-module="%s">\n' "$name"
    cat "$src"
    printf '\n    </script>\n'
}

generate_html () {
    local title="$1" module_tags="$2" js_files="$3" out="$4"

    local js_code="// lua-atmos $VERSION"$'\n'
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

$module_tags
    <script type="module">
$js_code
    </script>
</body>
</html>
ENDHTML
    echo "  wrote $out"
}

# --- Fetch modules ---

echo "Fetching lua-atmos runtime modules..."
for entry in "${LUA_ATMOS_MODULES[@]}"; do
    read -r name repo version path <<< "$entry"
    fetch_module "$name" "$repo" "$version" "$path"
done

echo "Fetching atmos-lang compiler modules..."
for entry in "${ATMOS_LANG_MODULES[@]}"; do
    read -r name repo version path <<< "$entry"
    fetch_module "$name" "$repo" "$version" "$path"
done

# --- Build module tags ---

RUNTIME_TAGS=""
for entry in "${LUA_ATMOS_MODULES[@]}"; do
    read -r name _ _ <<< "$entry"
    RUNTIME_TAGS+="$(module_tag "$name")"$'\n'
done

COMPILER_TAGS=""
for entry in "${ATMOS_LANG_MODULES[@]}"; do
    read -r name _ _ <<< "$entry"
    COMPILER_TAGS+="$(module_tag "$name")"$'\n'
done

# --- Generate HTML files ---

echo "Generating HTML files..."

generate_html \
    "Lua" \
    "" \
    "$JS_DIR/run.js $JS_DIR/lua.js" \
    "$OUT_DIR/lua.html"

generate_html \
    "lua-atmos" \
    "$RUNTIME_TAGS" \
    "$JS_DIR/run.js $JS_DIR/lua-atmos.js" \
    "$OUT_DIR/lua-atmos.html"

generate_html \
    "Atmos" \
    "${RUNTIME_TAGS}${COMPILER_TAGS}" \
    "$JS_DIR/run.js $JS_DIR/atmos.js" \
    "$OUT_DIR/atmos.html"

echo "Done."
