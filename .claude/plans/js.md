# JS Environment — Design Notes

## Wasmoon

[Wasmoon](https://github.com/ceifa/wasmoon) compiles the official
**Lua 5.4 C source** to WebAssembly via Emscripten.  A TypeScript
wrapper (`LuaFactory` / `LuaEngine` / `lua.global`) provides the
JS-facing API.

Key facts:

| | |
|--|--|
| VM | Real Lua 5.4 — same bytecode, GC, stdlib as native |
| Speed | ~25× faster than Fengari (JS re-impl) for pure Lua |
| Size | 393 kB raw, 130 kB gzip |
| JS bridge | `global.set(k,v)`, `global.get(k)`, `doString(code)` |
| Async | `:await()` on JS Promises — **but cannot yield across a C-call boundary** |

### JS → Lua data bridging

Wasmoon has **two modes** for passing JS objects into Lua, controlled
by `enableProxy` (default `true`):

| Mode | How | `pairs()` | `table.*` | Live binding? |
|------|-----|-----------|-----------|---------------|
| **Proxy** (default) | JS object → userdata with `__index`/`__pairs` metamethods | yes | **no** | yes (bidirectional) |
| **Table copy** (`enableProxy: false`) | JS object → deep-copied native Lua table | yes | yes | no (one-time snapshot) |

The proxy is the default because two competing type extensions race on
priority:

- `TableTypeExtension` (priority 0) — deep-copies to native table
- `ProxyTypeExtension` (priority 3) — wraps as proxied userdata

Since 3 > 0, proxy wins.  You can opt out per value:

```javascript
import { decorate } from 'wasmoon'
lua.global.set('evt', decorate(eventObj, { proxy: false }))  // → native Lua table
```

Or globally: `factory.createEngine({ enableProxy: false })`.

**There is no public `createTable()` / `pushTable()` API.**  Table
creation is internal to `TableTypeExtension.pushValue()`.  The
`wasmoon-lua5.1` fork added a `LuaTable` proxy class, but it is not
in the main wasmoon (Lua 5.4) package.

### The C-call boundary constraint

When JS invokes a Lua callback (e.g. from `addEventListener` or
`requestAnimationFrame`), that Lua function **cannot** call
`coroutine.yield()`.  This is a fundamental Lua VM rule — yield
cannot cross C frames.

Consequence: **DOM event callbacks cannot use `await()` inside Lua.**
The only safe path is to have JS collect events and push them into Lua
synchronously via `doString` or `global.get('fn')(args)`.

This is exactly why `atmos.env.js` uses `doString` from JS rather
than registering Lua callbacks on DOM events.

### How wasmoon users typically handle DOM events

No library exists.  Three patterns appear in practice:

**Pattern A — Expose `document`, call `addEventListener` from Lua:**

```javascript
lua.global.set('document', document)   // proxied userdata
```
```lua
local btn = document:getElementById("myButton")
btn:addEventListener("click", function(event)
    print("clicked!")          -- works (synchronous)
    -- await(something)        -- FAILS: C-call boundary
end)
```

Works for fire-and-forget handlers.  Fails the moment the callback
needs to `await`, which is the common case in Atmos.

**Pattern B — JS-side helpers that call `doString`:**

```javascript
canvas.addEventListener('keydown', (ev) => {
    lua.doString(`on_key("${ev.key}")`)
})
```
```lua
function on_key(k) emit('key', k) end
```

This is the pattern `atmos.env.js` uses — the event table is built in
Lua (inside `doString`), so it is a real native table.  No proxy
issues, no C-call boundary issues.

**Pattern C — `global.get` + call retrieved function:**

```javascript
const tick = lua.global.get('tick')   // retrieve once
function frame() { tick(Date.now()); requestAnimationFrame(frame) }
```

Slightly lower overhead than `doString` per call, but arguments are
still subject to proxy rules (numbers and strings pass through
cleanly; objects become proxied userdata).

---

## Current design

### `atmos/env/js/init.lua`

```lua
local atmos = require "atmos"

local M = {
    now = 0,
}

-- JS_now() and JS_close() must be set by the JS host before start().

function M.open ()
    M.now = JS_now()
end

function M.close ()
    JS_close()
end

atmos.env(M)

return M
```

Design decisions:
- **`start`-based, not `loop`-based** — `loop()` calls `env.step()` in
  a blocking while-loop; can't block the browser.  `start()` opens the
  env, spawns the task, returns.
- **No `step()`** — `step` belongs to `loop`-based envs.  JS drives
  the clock externally.
- **JS sets `E.now` directly** — no Lua helper function needed; the JS
  `setInterval` writes `E.now` and calls `emit('clock', dt, now)` via
  `doString`.
- **`JS_xxx` globals** — two globals injected by the JS host:
  `JS_now()` (used in `open`) and `JS_close()` (used in `close`).
- **No `M.running`** — no other env has it, nothing reads it.
- Follows the PICO pattern: `M` is the env table passed directly to
  `atmos.env(M)`, with `open`/`close` as methods on `M`.

### JS-side clock driver (`run.js`)

```javascript
function startLoop (lua) {
    let emitting = false;
    const interval = setInterval(() => {
        if (emitting) return;
        emitting = true;
        try {
            const now = Date.now();
            lua.doString(
                `local E = _atm_E_`
                + `\nlocal dt = ${now} - E.now`
                + `\nif dt > 0 then`
                + `\n    E.now = ${now}`
                + `\n    emit('clock', dt, ${now})`
                + `\nend`
            );
            if (lua.global.get('_atm_done_')) {
                clearInterval(interval);
                lua.doString('stop()');
                status.textContent = 'Done.';
            }
        } finally {
            emitting = false;
        }
    }, 16);
    return interval;
}
```

JS owns the clock entirely: computes dt, sets `E.now`, emits clock.
The `emitting` guard prevents overlapping `doString` calls.
Completion detected via `_atm_done_` flag + `stop()`.

### JS host setup (e.g. `lua-atmos.js`)

```javascript
lua.global.set('JS_now', () => Date.now());

let interval;
lua.global.set('JS_close', () => clearInterval(interval));

await lua.doString(
    '_atm_E_ = require("atmos.env.js")\n'
    + 'start(function()\n'
    + code + '\n'
    + '_atm_done_ = true\n'
    + 'end)'
);
interval = startLoop(lua);
```

---

## Extending with DOM events (Phase 2)

### The pattern used by existing environments

All existing envs follow the same shape:

1. Poll for native events in `step()`
2. Wrap the event in a table with an `__atmos` metamethod
3. `emit(wrapped_event)` into the atmos task system
4. The `__atmos` metamethod implements pattern matching for `await()`

**PICO** (`atmos/env/pico/init.lua`):
```lua
local meta = {
    __atmos = function (awt, e)
        if not _is_(e.tag, awt[1]) then return false end
        if _is_(e.tag, 'key') and type(awt[2])=='string' then
            if awt[2] ~= e.key then return false end
        elseif _is_(e.tag, 'mouse.button') and type(awt[2])=='string' then
            if awt[2] ~= e.but then return false end
        end
        local f = awt[#awt]
        if type(f) == 'function' then
            if not f(e) then return false end
        end
        return true, e, e
    end
}
-- in step():
emit(setmetatable(e, meta))      -- e = { tag='key', key='a' }
```

### Reusable mapping: the PICO event taxonomy

The **PICO** environment is the closest fit for a JS/DOM mapping because:

- It uses **string tags** (`'key'`, `'mouse.button'`, `'quit'`, `'draw'`)
  rather than C enum constants (SDL)
- It uses hierarchical names matchable via `_is_()` prefix matching
  (e.g. `_is_('mouse.button', 'mouse')` → true)
- Its `__atmos` metamethod is simple and generic

DOM events map naturally to PICO's taxonomy:

| DOM event        | PICO equivalent    | Proposed tag         | Fields             |
|------------------|--------------------|----------------------|--------------------|
| `keydown`        | `{ tag='key' }`    | `'key'`              | `key`, `code`      |
| `keyup`          | —                  | `'key.up'`           | `key`, `code`      |
| `mousedown`      | `{ tag='mouse.button' }` | `'mouse.button'` | `but`, `x`, `y` |
| `mouseup`        | —                  | `'mouse.button.up'`  | `but`, `x`, `y`    |
| `mousemove`      | —                  | `'mouse.move'`       | `x`, `y`           |
| `touchstart`     | —                  | `'touch'`            | `id`, `x`, `y`     |
| `touchend`       | —                  | `'touch.up'`         | `id`, `x`, `y`     |
| `click`          | —                  | `'click'`            | `x`, `y`           |
| `resize`         | —                  | `'resize'`           | `w`, `h`           |
| `visibilitychange` | `{ tag='quit' }` | `'visibility'`      | `hidden`           |

### Implementation plan

Add a `__atmos` metamethod and an `M.event()` function to `init.lua`.
The JS host calls `M.event(tag, ...)` instead of `emit()` directly,
so that the metamethod handles pattern matching:

```lua
local meta = {
    __atmos = function (awt, e)
        if not _is_(e.tag, awt[1]) then
            return false
        elseif _is_(e.tag, 'key') and type(awt[2])=='string' then
            if awt[2] ~= e.key then return false end
        elseif _is_(e.tag, 'mouse.button') and type(awt[2])=='string' then
            if awt[2] ~= e.but then return false end
        end
        local f = awt[#awt]
        if type(f) == 'function' then
            if not f(e) then return false end
        end
        return true, e, e
    end
}

function M.event (e)
    emit(setmetatable(e, meta))
end
```

On the JS side, each DOM listener builds a plain table and calls
`M.event()`:

```javascript
canvas.addEventListener('keydown', (ev) => {
    lua.doString(`
        _atm_E_.event{ tag='key', key='${ev.key}' }
    `);
});

canvas.addEventListener('mousedown', (ev) => {
    const but = ['left','middle','right'][ev.button] or ev.button;
    lua.doString(`
        _atm_E_.event{
            tag='mouse.button', but='${but}', x=${ev.offsetX}, y=${ev.offsetY}
        }
    `);
});
```

Then in Lua user code:

```lua
local env = require "atmos.env.js"

start(function ()
    watching('quit', function ()
        every('key', function (_, e)
            print("key pressed:", e.key)
        end)
        every('mouse.button', 'left', function (_, e)
            print("left click at", e.x, e.y)
        end)
    end)
end)
```

### Draw events

For canvas-based apps, the JS host emits a `'draw'` event each frame
(matching PICO's pattern) and the Lua side renders into a
canvas-backed buffer:

```javascript
// inside the setInterval / RAF callback, after clock emit:
lua.doString('_atm_E_.event{ tag="draw" }');
```

### Lifecycle: quit

Browser "quit" is `beforeunload` or `visibilitychange`:

```javascript
window.addEventListener('beforeunload', () => {
    lua.doString('_atm_E_.event{ tag="quit" }');
});
```

---

## Relationship with PICO

The JS environment reuses PICO's event model because PICO and JS
share the same architectural position: both are **thin wrappers over
a host that provides input events and a drawing surface**.

| | PICO | JS |
|---|---|---|
| **Host** | pico-sdl (C library) | Browser (DOM + Canvas) |
| **Event source** | `pico.input.event()` returns `{tag=..., ...}` | JS `addEventListener` captures `{tag=..., ...}` |
| **Event shape** | Lua table with string `tag` field | Same — built inside Lua via `doString` |
| **Matching** | `__atmos` metamethod + `_is_(e.tag, pattern)` | Same metamethod, same `_is_()` |
| **Tags** | `'key'`, `'mouse.button'`, `'draw'`, `'quit'` | Same tags + `'key.up'`, `'mouse.move'`, `'touch'`, `'resize'` |
| **Draw cycle** | `step()` emits `'draw'` after input | JS RAF emits `'draw'` after clock |

The difference is only in **who drives**: PICO's `step()` is called
by the Lua `loop()`; JS events are pushed by the browser.  The event
tables, metamethods, and tag names are identical.

This means user code written for PICO events works unchanged on JS:

```lua
-- works on both PICO and JS
every('key', function (_, e)
    print(e.key)
end)
every('mouse.button', 'left', function (_, e)
    print(e.x, e.y)
end)
```

**What JS reuses from PICO (copy as-is):**
- The `meta` table with `__atmos` metamethod
- The `_is_()`-based tag matching logic
- The tag namespace (`'key'`, `'mouse.button'`, `'draw'`, `'quit'`)

**What JS does NOT reuse:**
- `step()` — JS has no polling loop; it's `start`-based
- Clock logic — JS sets `E.now` directly and emits clock via `doString`
- SDL-style C enums or IUP-style widget callbacks

### Why `doString` (not Lua callbacks) for DOM events

The `doString` approach is required because of wasmoon's C-call
boundary constraint: Lua callbacks invoked from JS cannot
`coroutine.yield()`, which means they cannot `await()`.

Using `doString`, the event table is built inside Lua (real `table`,
not proxy userdata), and `emit()` resumes coroutines legally since
Lua is the callee, not a callback.

---

## `build.sh` — fully static HTML generation

Mimics `atmos-lang/web/build.sh`.  Generates **three self-contained
HTML files** — one per tier.  Zero runtime fetches (except wasmoon
from CDN).  Works from `file://`.

### Three tiers

| File             | Modules inlined            | Input   | Wrapping                |
|------------------|----------------------------|---------|-------------------------|
| `lua.html`       | none (bare wasmoon)        | `.lua`  | run directly            |
| `lua-atmos.html` | atmos runtime              | `.lua`  | `start(function() … end)` + tick loop |
| `atmos.html`     | atmos runtime + compiler   | `.atm`  | compile → `f()` via `start` |

These are the canonical HTML runners.  Projects like `atmos-lang/web`
copy them as-is — they never need to generate their own.

### User workflow

```
1. bash build.sh                                    # generate all three (once)
2. User writes:  hello.lua (or hello.atm)
3. bash run.sh hello.lua                            # default: --mode=lua-atmos
   bash run.sh --mode=lua hello.lua                 # bare Lua
   bash run.sh --mode=atmos hello.atm               # Atmos language
```

No server.  No HTML editing.  The source file is the only input.

### How user code reaches the HTML — hash fragment

The user code is passed via the URL **hash fragment** as base64:

```
lua-atmos.html#cHJpbnQoImhlbGxvIik=
```

The JS inside the generated HTML reads it:

```javascript
const hash = location.hash.slice(1);
if (!hash) { status.textContent = 'No program.'; return; }
const code = atob(hash);
```

**Why hash, not query string?**
- Hash is never sent to a server (privacy)
- No practical length limit in modern browsers (Chrome/Firefox: 100K+)
- Can be updated without page reload
- Works identically from `file://` and `http://`

A shell helper generates the URL:

```bash
# run.sh --mode=lua-atmos hello.lua
#!/bin/bash
MODE="lua-atmos"
while [[ "$1" == --* ]]; do
    case "$1" in
        --mode=*) MODE="${1#--mode=}" ; shift ;;
        *)        echo "Unknown option: $1"; exit 1 ;;
    esac
done
FILE="$1"
DIR="$(cd "$(dirname "$0")" && pwd)"
HTML="$DIR/$MODE.html"

if [ ! -f "$HTML" ]; then
    echo "No such runner: $HTML"; exit 1
fi

CODE=$(base64 -w0 < "$FILE")
xdg-open "file://$HTML#$CODE" 2>/dev/null ||
open "file://$HTML#$CODE" 2>/dev/null
```

### What `build.sh` does

```
 1. Fetch Lua modules from GitHub (raw URLs, version-tagged)
 2. Inline each as <script type="text/lua" data-module="name">
 3. For each tier, concatenate the right JS files:
      lua.html       ← run.js + lua.js
      lua-atmos.html ← run.js + lua-atmos.js
      atmos.html     ← run.js + atmos.js
 4. Generate three HTML files, each with:
      - Inlined Lua module tags (none / runtime / runtime+compiler)
      - Concatenated JS inlined in <script type="module">
      - <pre id="output"> for text output
```

The JS source files are the source of truth.  `build.sh` concatenates
and inlines them — the generated HTML has no external JS dependencies
(except wasmoon from CDN).

### Module lists

```bash
# lua-atmos runtime modules
LUA_ATMOS_MODULES=(
    'streams         lua-atmos/f-streams  streams/init.lua'
    'atmos           lua-atmos/atmos      atmos/init.lua'
    'atmos.util      lua-atmos/atmos      atmos/util.lua'
    'atmos.run       lua-atmos/atmos      atmos/run.lua'
    'atmos.streams   lua-atmos/atmos      atmos/streams.lua'
    'atmos.x         lua-atmos/atmos      atmos/x.lua'
    'atmos.env.js    lua-atmos/atmos      atmos/env/js/init.lua'
)

# atmos-lang compiler modules (for atmos.html only)
ATMOS_LANG_MODULES=(
    'atmos.lang.global   atmos-lang/atmos  src/global.lua'
    'atmos.lang.aux      atmos-lang/atmos  src/aux.lua'
    'atmos.lang.lexer    atmos-lang/atmos  src/lexer.lua'
    'atmos.lang.parser   atmos-lang/atmos  src/parser.lua'
    'atmos.lang.prim     atmos-lang/atmos  src/prim.lua'
    'atmos.lang.coder    atmos-lang/atmos  src/coder.lua'
    'atmos.lang.tosource atmos-lang/atmos  src/tosource.lua'
    'atmos.lang.exec     atmos-lang/atmos  src/exec.lua'
    'atmos.lang.run      atmos-lang/atmos  src/run.lua'
)
```

### JS source files — layered

The JS runtime is split into four source files.  `build.sh`
concatenates the right combination and inlines it into each HTML.

| HTML file | JS files concatenated |
|-----------|----------------------|
| `lua.html` | `run.js` + `lua.js` |
| `lua-atmos.html` | `run.js` + `lua-atmos.js` |
| `atmos.html` | `run.js` + `atmos.js` |

The JS source files are checked in under `atmos/env/js/`.  See the
files directly for current code — `run.js`, `lua.js`, `lua-atmos.js`,
`atmos.js`.

### Generated HTML template

`build.sh` generates each HTML file from a common template.  The only
differences are: the `<title>`, which `<script type="text/lua">` tags
are present, and which JS files are concatenated into the inline
`<script type="module">`.

```html
<!DOCTYPE html>
<html>
<head><title>$TITLE</title></head>
<body>
    <pre id="output"></pre>
    <span id="status"></span>

    <!-- Lua modules inlined by build.sh (if any) -->
    $MODULE_TAGS

    <script type="module">
    $JS_CODE
    </script>
</body>
</html>
```

---

## File structure

```
build.sh                   -- generates all three HTML files
run.sh                     -- helper: opens browser with code in hash
lua.html                   -- generated (bare Lua)
lua-atmos.html             -- generated (Lua + atmos runtime)
atmos.html                 -- generated (Atmos language)

atmos/env/js/
├── init.lua               -- the canonical Lua module
├── run.js                 -- shared JS core (engine, print, preload, clock loop)
├── lua.js                 -- bare Lua tier
├── lua-atmos.js           -- Lua + atmos runtime tier
├── atmos.js               -- Atmos language tier
└── exs/                   -- examples
    └── hello.lua
```

This extends the existing layout:

```
atmos/env/
├── clock/  init.lua  exs/
├── sdl/    init.lua  exs/
├── pico/   init.lua  exs/
├── socket/ init.lua  exs/
├── iup/    init.lua  exs/
└── js/     init.lua  run.js  lua.js  lua-atmos.js  atmos.js  exs/  ← new

build.sh                      ← new (generates HTML)
run.sh                        ← new (opens browser)
```

The Lua module is loaded the standard way: `require "atmos.env.js"`.
The JS files are not loaded at runtime — `build.sh` concatenates and
inlines them into the generated HTML.

Projects like `atmos-lang/web` copy the generated HTML files directly.
They do not need their own `build.sh` — this repo is the source of
truth for the runners.

---

## This repo generates, `atmos-lang/web` copies

This repo (`lua-atmos/atmos`) is the **source of truth** for all
three HTML runners:

```
bash build.sh          # generates lua.html, lua-atmos.html, atmos.html
bash run.sh hello.lua  # opens lua-atmos.html#<base64>
bash run.sh hello.atm  # opens atmos.html#<base64>
```

`atmos-lang/web` copies the generated HTML files into its tree
(e.g. `web/try/lua-atmos.html`, `web/try/atmos.html`).  It no longer
needs its own `build.sh` for generating runners — only for
site-specific concerns (layout, navigation, etc.).

The `env/README.md` table should be updated to include JS:

| Environment        | `open` | `step` | `close` | User calls  |
|--------------------|--------|--------|---------|-------------|
| Clock              |        | yes    |         | `loop`      |
| SDL                | yes    | yes    | yes     | `loop`      |
| Pico               | yes    | yes    | yes     | `loop`      |
| Socket             |        | yes    |         | `loop`      |
| IUP                | yes    | yes    | yes     | `loop`      |
| JS / Web           | yes    |        | yes     | `start`     |

---

## Summary of phases

### Phase 1 — Clock only (done)
1. `atmos/env/js/init.lua` — canonical Lua module (`open`/`close`, `M.now`)
2. `build.sh` — generates `lua.html`, `lua-atmos.html`, `atmos.html`
3. `run.sh` — helper to open browser with code in hash fragment
4. JS owns clock: `startLoop` sets `E.now` and emits `'clock'` via `doString`

### Phase 2 — DOM events
1. Add PICO-style `__atmos` metamethod and `M.event(e)` to `init.lua`
2. JS listeners build event tables and call `M.event()` via `doString`
3. Document the JS-side wiring for each DOM event type
4. Add an example (`atmos/env/js/exs/`) mirroring PICO patterns

### Phase 3 — Canvas / draw
1. Add `'draw'` event emission from JS RAF loop (after clock)
2. Expose canvas 2D context to Lua (or provide a Lua drawing API)
3. Example: simple animation loop with `every('draw', ...)`
