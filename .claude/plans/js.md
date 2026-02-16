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

This is exactly why `atmos.env.js` uses the **tick** pattern rather
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

## Two implementations — convergence needed

Two parallel sessions built two implementations of `atmos.env.js`.
They must converge into a single canonical module in this repo
(`lua-atmos/atmos`), used by the web repo (`atmos-lang/web`).

### Implementation A — `lua-atmos/atmos` (this repo)

Branch: `claude/atmos-js-environment-y5pPY`
File: `atmos/env/js/init.lua` (36 lines)

```lua
local atmos = require "atmos"

local M = {
    now = 0,
    running = false,
}

function M.open ()
    M.now = js_now()
    M.running = true
end

function M.tick ()
    local now = js_now()
    local dt = now - M.now
    if dt > 0 then
        M.now = now
        emit('clock', dt, now)
    end
end

function M.close ()
    M.running = false
end

M.env = {
    open  = M.open,
    close = M.close,
}

atmos.env(M.env)

return M
```

**Design:**
- JS host provides one global: `js_now() → number` (e.g. `Date.now()`)
- Lua owns the delta computation (`M.tick()` calls `js_now()`)
- JS calls `M.tick()` each frame via `doString` or `global.get`
- `M.running` flag lets JS know when to stop the RAF/interval loop
- No `step()` — JS drives; no `mode` — single-env only

**What's good:**
- Clean separation: Lua owns time logic, JS only provides a clock source
- `M.running` is the lifecycle signal — JS polls it
- Minimal contract (one global)

**What's missing:**
- No DOM events (`meta` / `M.event()` — proposed but not implemented)
- No `_js_close_()` callback — JS must poll `M.running` instead of being notified
- No working integration tested in a browser

### Implementation B — `atmos-lang/web`

Branch: `claude/atmos-js-binding-1pkuf`
File: `web/try/atmos/env_js.lua` (inlined in build.sh)

```lua
local atmos = require "atmos"

local M = {
    now = 0,
}

function M.close()
    if _js_close_ then
        _js_close_()
    end
end

M.env = {
    close = M.close,
}

atmos.env(M.env)

_atm_js_env_ = M

return M
```

**Design:**
- JS owns the delta computation entirely (in the `setInterval` callback)
- JS calls `emit('clock', dt, now)` via `doString` each tick
- JS also updates `_atm_js_env_.now` directly via `doString`
- `_js_close_()` is a JS→Lua callback for cleanup notification
- `_atm_done_` flag set by the `start()` wrapper for completion detection

**JS-side integration (from build.sh):**
```javascript
// Before start:
lua.global.set('_js_close_', () => { /* cleanup */ });

// Start (non-blocking):
await lua.doString(`
    _atm_js_env_ = require("atmos.env.js")
    start(function()
        <user_code>
        _atm_done_ = true
    end)
`);

// Clock driver:
let emitting = false;
const interval = setInterval(() => {
    if (emitting) return;  // guard against overlapping doString
    emitting = true;
    const now = Date.now();
    const dt = now - lastTime;
    lastTime = now;
    lua.doString(`
        _atm_js_env_.now = ${now}
        emit('clock', ${dt}, ${now})
    `);
    emitting = false;
    // Check completion:
    if (lua.global.get('_atm_done_')) {
        clearInterval(interval);
        lua.doString('stop()');
    }
}, 16);
```

**What's good:**
- Actually tested and working in the browser playground
- `_js_close_()` callback for active cleanup notification
- Concurrent-emit guard (`emitting` flag)
- Completion detection via `_atm_done_` + `stop()`

**What's missing:**
- `M.now` is updated from JS via doString — Lua doesn't own its own state
- No `M.tick()` — the delta logic is scattered in JS
- Exposes internals via globals (`_atm_js_env_`, `_atm_done_`)
- No DOM events

### Convergence plan

The canonical module should combine the best of both:

| Aspect | Source | Decision |
|--------|--------|----------|
| Delta computation | Impl A | **Lua owns it** — `M.tick()` calls `js_now()` |
| Close notification | Impl B | **`_js_close_()` callback** — active, not polling |
| Running flag | Impl A | **`M.running`** — but also call `_js_close_()` |
| Completion detection | Impl B | **`_atm_done_` pattern** — works with `start()` |
| Emit guard | Impl B | **JS-side** — needed for async `setInterval` |
| DOM events | Plan | **Phase 2** — `meta` + `M.event()` |

JS env uses `start` (not `loop`) because:
- `loop()` calls `env.step()` in a blocking while-loop — cannot block the browser
- `start()` is for single-env with `mode=nil` — it opens the env, spawns the task, returns
- JS drives the tick loop externally via `setInterval`

Converged `atmos/env/js/init.lua`:

```lua
local atmos = require "atmos"

local M = {
    now = 0,
    running = false,
}

-- js_now() must be set by the JS host before calling start().
-- It returns the current time in milliseconds (e.g., Date.now()).

function M.open ()
    M.now = js_now()
    M.running = true
end

function M.tick ()
    local now = js_now()
    local dt = now - M.now
    if dt > 0 then
        M.now = now
        emit('clock', dt, now)
    end
end

function M.close ()
    M.running = false
    _js_close_()
end

atmos.env(M)

return M
```

Follows the same pattern as PICO: `M` is the env table passed
directly to `atmos.env(M)`, with `open`/`close` as methods on `M`.
No intermediate `M.env` wrapper.  No `step` — JS drives ticks
externally.

Changes from Impl A: adds `_js_close_()` in `close()`.
Changes from Impl B: Lua owns delta via `M.tick()`/`js_now()`, no `_atm_js_env_` global.
`_js_close_()` is called unconditionally — the JS host always provides it.

The JS host setup:

```javascript
lua.global.set('js_now', () => Date.now());
lua.global.set('_js_close_', () => {
    clearInterval(interval);
});

await lua.doString(
    'require("atmos.env.js")\n'
    + 'start(function()\n'
    + '    <user_code>\n'
    + '    _atm_done_ = true\n'
    + 'end)'
);

// JS drives the tick loop
let emitting = false;
const interval = setInterval(() => {
    if (emitting) return;
    emitting = true;
    try {
        lua.doString('require("atmos.env.js").tick()');
        if (lua.global.get('_atm_done_')) {
            clearInterval(interval);
            lua.doString('stop()');
        }
    } finally {
        emitting = false;
    }
}, 16);
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
        require("atmos.env.js").event{ tag='key', key='${ev.key}' }
    `);
});

canvas.addEventListener('mousedown', (ev) => {
    const but = ['left','middle','right'][ev.button] or ev.button;
    lua.doString(`
        require("atmos.env.js").event{
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
function frame() {
    lua.doString('require("atmos.env.js").tick()');
    lua.doString('require("atmos.env.js").event{ tag="draw" }');
    if (lua.global.get('_js_running_')) {
        requestAnimationFrame(frame);
    }
}
```

### Lifecycle: quit

Browser "quit" is `beforeunload` or `visibilitychange`:

```javascript
window.addEventListener('beforeunload', () => {
    lua.doString('require("atmos.env.js").event{ tag="quit" }');
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
| **Draw cycle** | `step()` emits `'draw'` after input | JS RAF emits `'draw'` after `tick()` |

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
- `step()` — JS has no polling loop
- Clock logic — JS uses `M.tick()` driven by `setInterval`/RAF
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

#### `run.js` — shared core

```javascript
// run.js — shared utilities for all three tiers
// Never used standalone; concatenated with a tier file by build.sh

import { LuaFactory } from
    'https://cdn.jsdelivr.net/npm/wasmoon@1.16.0/+esm';

const output = document.getElementById('output');
const status = document.getElementById('status');

function getCode () {
    const hash = location.hash.slice(1);
    if (!hash) {
        status.textContent = 'No program in URL.';
        return null;
    }
    return atob(hash);
}

async function createEngine () {
    const factory = new LuaFactory();
    const lua = await factory.createEngine();
    lua.global.set('print', (...args) => {
        output.textContent += args.join('\t') + '\n';
    });
    return lua;
}

async function preloadModules (lua) {
    const tags = document.querySelectorAll(
        'script[type="text/lua"]'
    );
    for (const el of tags) {
        lua.global.set('_mod_name_', el.dataset.module);
        lua.global.set('_mod_src_', el.textContent);
        await lua.doString(
            'package.preload[_mod_name_]'
            + ' = assert(load(_mod_src_,'
            + ' "@" .. _mod_name_))'
        );
    }
}

function startTick (lua) {
    let emitting = false;
    const interval = setInterval(() => {
        if (emitting) return;
        emitting = true;
        try {
            lua.doString(
                'require("atmos.env.js").tick()'
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

#### `lua.js` — bare Lua

```javascript
// lua.js — bare Lua runner (no atmos)

(async () => {
    const code = getCode();
    if (!code) return;

    status.textContent = 'Loading...';
    const lua = await createEngine();

    status.textContent = 'Running...';
    try {
        await lua.doString(code);
        status.textContent = 'Done.';
    } catch (e) {
        output.textContent += 'ERROR: ' + e.message + '\n';
        status.textContent = 'Error.';
    }
})();
```

#### `lua-atmos.js` — Lua + atmos runtime

```javascript
// lua-atmos.js — Lua code running under atmos runtime

(async () => {
    const code = getCode();
    if (!code) return;

    status.textContent = 'Loading...';
    const lua = await createEngine();
    await preloadModules(lua);
    lua.global.set('js_now', () => Date.now());

    let interval;
    lua.global.set('_js_close_', () => clearInterval(interval));

    status.textContent = 'Running...';
    try {
        await lua.doString(
            'require("atmos.env.js")\n'
            + 'start(function()\n'
            + code + '\n'
            + '_atm_done_ = true\n'
            + 'end)'
        );
        interval = startTick(lua);
    } catch (e) {
        output.textContent += 'ERROR: ' + e.message + '\n';
        status.textContent = 'Error.';
    }
})();
```

#### `atmos.js` — Atmos language (.atm)

```javascript
// atmos.js — compile .atm source, then run under atmos runtime

(async () => {
    const code = getCode();
    if (!code) return;

    status.textContent = 'Loading...';
    const lua = await createEngine();
    await preloadModules(lua);
    lua.global.set('js_now', () => Date.now());

    let interval;
    lua.global.set('_js_close_', () => clearInterval(interval));

    status.textContent = 'Compiling...';
    try {
        await lua.doString(
            'atmos = require "atmos"\n'
            + 'X = require "atmos.x"\n'
            + 'require "atmos.lang.exec"\n'
            + 'require "atmos.lang.run"'
        );

        const wrapped =
            '(func (...) { ' + code + '\n})(...)';
        lua.global.set('_atm_src_', wrapped);
        lua.global.set('_atm_file_', 'input.atm');

        status.textContent = 'Running...';
        await lua.doString(
            'require("atmos.env.js")\n'
            + 'local f, err = '
            + 'atm_loadstring(_atm_src_, _atm_file_)\n'
            + 'if not f then error(err) end\n'
            + 'start(function()\n'
            + '    f()\n'
            + '    _atm_done_ = true\n'
            + 'end)'
        );
        interval = startTick(lua);
    } catch (e) {
        output.textContent += 'ERROR: ' + e.message + '\n';
        status.textContent = 'Error.';
    }
})();
```

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
├── run.js                 -- shared JS core (engine, print, preload, tick)
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

### Phase 1 — Clock only (current)
1. Create `atmos/env/js/init.lua` — converged canonical Lua module
2. Create `build.sh` — generates three HTML files:
   `lua.html`, `lua-atmos.html`, `atmos.html`
   (mimics `atmos-lang/web/build.sh`: fetch modules, inline, CDN wasmoon)
3. Create `run.sh` — helper to open browser with code in hash fragment
4. Test: `bash build.sh && bash run.sh hello.lua` → prints output

### Phase 2 — DOM events
1. Add PICO-style `__atmos` metamethod and `M.event(e)` to `init.lua`
2. Keep `M.tick()` for clock only (called from `requestAnimationFrame`)
3. Document the JS-side wiring for each DOM event type
4. Add an example (`atmos/env/js/exs/`) mirroring PICO patterns

### Phase 3 — Canvas / draw
1. Add `'draw'` event emission from JS RAF loop
2. Expose canvas 2D context to Lua (or provide a Lua drawing API)
3. Example: simple animation loop with `every('draw', ...)`
