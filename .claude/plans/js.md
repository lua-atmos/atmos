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
| Completion detection | Impl B | **`_atm_done_` pattern** — works with start() |
| Emit guard | Impl B | **JS-side** — needed for async setInterval |
| DOM events | Plan | **Phase 2** — `meta` + `M.event()` |

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
No intermediate `M.env` wrapper.

Changes from Impl A: adds `_js_close_()` in `close()`.
Changes from Impl B: Lua owns delta via `M.tick()`/`js_now()`, no `_atm_js_env_` global.
`_js_close_()` is called unconditionally — the JS host always provides it.

The web repo should then use this module directly (fetched from GitHub
like all other atmos modules), and its JS driver becomes:

```javascript
lua.global.set('js_now', () => Date.now());
lua.global.set('_js_close_', () => { clearInterval(interval); cleanup(); });

await lua.doString(`
    local js = require("atmos.env.js")
    start(function()
        <user_code>
        _atm_done_ = true
    end)
`);

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

## `env/run.js` — the JS runtime

The JS runtime is the **entry point and orchestrator** for running
atmos programs in the browser.  It lives at `env/run.js` in this repo.

### User workflow

```
1. User writes:    hello.lua
2. User opens:     lua-atmos.html?lua=hello.lua
3. Browser loads:  env/run.js  (via <script>)
4. run.js does everything else automatically
```

The user never writes JS.  The `.lua` file is the only input.

### What `run.js` does (in order)

```
 1. Parse ?lua= URL parameter → get path to user's .lua file
 2. Load wasmoon (Lua 5.4 VM in Wasm)
 3. Create engine: factory.createEngine()
 4. Load atmos modules into the VM filesystem
    (atmos/init.lua, atmos/env/js/init.lua, etc.)
 5. Set JS globals into the VM:
      lua.global.set('js_now',    () => Date.now())
      lua.global.set('_js_close_', () => { clearInterval(interval); cleanup() })
 6. Fetch the user's .lua file (from ?lua= path)
 7. Execute via doString:
      require("atmos.env.js")
      start(function()
          <user code>
          _atm_done_ = true
      end)
 8. Start the tick loop:
      let emitting = false
      const interval = setInterval(() => {
          if (emitting) return
          emitting = true
          try {
              lua.doString('require("atmos.env.js").tick()')
              if (lua.global.get('_atm_done_')) {
                  clearInterval(interval)
                  lua.doString('stop()')
              }
          } finally {
              emitting = false
          }
      }, 16)
```

### `lua-atmos.html`

A minimal generic runner page.  One HTML serves any `.lua` file:

```html
<!DOCTYPE html>
<html>
<head><title>lua-atmos</title></head>
<body>
  <pre id="output"></pre>
  <script src="env/run.js" type="module"></script>
</body>
</html>
```

The `<pre id="output">` is the default text output target.  Phase 2
adds `<canvas>` for graphical apps.

### Console output

The runtime overrides Lua's `print()` to append to `#output`:

```javascript
lua.global.set('print', (...args) => {
    const line = args.join('\t') + '\n';
    document.getElementById('output').textContent += line;
});
```

### Error handling

If the `.lua` file fails to fetch or the Lua code errors,
the runtime displays the error in `#output`:

```javascript
try {
    await lua.doString(code);
} catch (e) {
    document.getElementById('output').textContent += 'Error: ' + e.message;
}
```

### Loading atmos modules

The atmos source files need to be available to `require()` inside the
VM.  Wasmoon provides a virtual filesystem (Emscripten FS).  The
runtime mounts the needed modules before executing user code:

```javascript
// Mount atmos core + js env into the VM's virtual FS
await factory.mountFile('atmos/init.lua',        atmosSource);
await factory.mountFile('atmos/env/js/init.lua',  jsEnvSource);
// ... other modules as needed
```

These sources can be fetched from GitHub (raw URLs) or bundled.

---

## File structure

The JS environment follows the same `atmos/env/` hierarchy as all
other environments, plus the runtime and HTML runner at the top level:

```
env/
└── run.js                 -- JS runtime (the workhorse)

lua-atmos.html             -- generic HTML runner

atmos/env/js/
├── README.md              -- env docs (like pico/README.md)
├── init.lua               -- the canonical Lua module
└── exs/                   -- examples
    └── ...
```

This extends the existing layout:

```
atmos/env/
├── clock/  init.lua  README.md  exs/
├── sdl/    init.lua  README.md  exs/
├── pico/   init.lua  README.md  exs/
├── socket/ init.lua  README.md  exs/
├── iup/    init.lua  README.md  exs/
└── js/     init.lua  README.md  exs/    ← new

env/
└── run.js                                ← new (JS runtime)

lua-atmos.html                            ← new (HTML runner)
```

The module is loaded the standard way: `require "atmos.env.js"`.
The `atmos-lang/web` repo can either use `env/run.js` directly
or adapt it — this repo is the single source of truth.

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
2. Create `env/run.js` — the JS runtime (boot wasmoon, tick loop, output)
3. Create `lua-atmos.html` — generic HTML runner (`?lua=` param)
4. Create `atmos/env/js/README.md`
5. Update `atmos/env/README.md` — add JS to the environment table
6. Update `README.md` — add JS to the Environments section
7. Test: `lua-atmos.html?lua=hello.lua` runs and prints output

### Phase 2 — DOM events
1. Add PICO-style `__atmos` metamethod and `M.event(e)` to `init.lua`
2. Keep `M.tick()` for clock only (called from `requestAnimationFrame`)
3. Document the JS-side wiring for each DOM event type
4. Add an example (`atmos/env/js/exs/`) mirroring PICO patterns

### Phase 3 — Canvas / draw
1. Add `'draw'` event emission from JS RAF loop
2. Expose canvas 2D context to Lua (or provide a Lua drawing API)
3. Example: simple animation loop with `every('draw', ...)`
