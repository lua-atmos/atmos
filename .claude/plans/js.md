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

---

## The current binding

`atmos/env/js/init.lua` (36 lines):

```
JS host                          Lua
───────                          ───
lua.global.set('js_now', ...)
                                 require "atmos.env.js"    -- registers env
                                 start(function () ... end)
                                   open():  M.now = js_now(), M.running = true
                                   spawns body, returns immediately

requestAnimationFrame loop:
  env.tick()                     emit('clock', dt, now)
  env.tick()                     emit('clock', dt, now)
  ...
                                 body finishes → stop()
                                   close(): M.running = false
env.running == false → stop RAF
```

Contract with the JS host — one global:

| Global     | Signature      | Example             |
|------------|----------------|---------------------|
| `js_now()` | `() → number`  | `() => Date.now()`  |

Lua-side API:

| Field       | Type       | Description                                |
|-------------|------------|--------------------------------------------|
| `M.tick()`  | function   | Call from JS each frame                    |
| `M.now`     | number     | Last clock time (ms)                       |
| `M.running` | boolean    | `true` after `open()`, `false` after `close()` |

Design choices:
- **`mode = nil`** — single-env only, `start()` only (no `loop()`)
- **No `step()`** — JS drives events; tick is called externally
- **No `mode.primary/secondary`** — browser is always the sole host

---

## Extending with DOM events

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
        return true, e, e
    end
}
-- in step():
emit(setmetatable(e, meta))      -- e = { tag='key', key='a' }
```

**SDL** (`atmos/env/sdl/init.lua`):
```lua
local meta = {
    __atmos = function (awt, e)
        if e.type ~= awt[1] then return false end
        if (e.type==SDL.event.KeyDown) and type(awt[2])=='string' then
            return (awt[2] == e.name), e, e
        end
        return true, e, e
    end
}
-- in step():
emit(setmetatable(e, meta))      -- e = { type=SDL.event.KeyDown, name='a' }
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

## Preexisting mappings — what can we reuse?

| Source | Reusable? | Notes |
|--------|-----------|-------|
| **PICO `__atmos`** | **yes — direct reuse** | Tag-based matching with `_is_()`, handles key/mouse.button string filtering. Copy as-is. |
| **PICO event tags** | **yes — same names** | `'key'`, `'mouse.button'`, `'draw'`, `'quit'` are portable; add `'mouse.move'`, `'touch'`, `'resize'` for DOM. |
| **SDL `__atmos`** | no | Relies on C enum constants (`SDL.event.KeyDown`), not string tags. |
| **IUP `__atmos`** | no | Widget-centric (`self.atm`), not input-event-centric. |
| **Fengari interop** | no | Different VM entirely (Lua 5.3, JS reimpl). Has `addEventListener` from Lua, but violates the C-call boundary constraint in wasmoon. |
| **LOVE2D web ports** | no | Compile the full C++ engine to Wasm via Emscripten — not wasmoon. |
| **Existing wasmoon projects** | no | No known project provides a DOM→Lua event mapping library. |

**Conclusion:** The PICO environment's `__atmos` metamethod and tag
taxonomy is directly reusable.  The JS env should adopt PICO's
convention — string tags, `_is_()` matching, optional key/button
string filters — and extend it with DOM-specific tags (`'mouse.move'`,
`'touch'`, `'resize'`).

---

## Summary of next steps

1. Add the PICO-style `__atmos` metamethod to `atmos/env/js/init.lua`
2. Add `M.event(e)` — the JS host calls this to inject DOM events
3. Keep `M.tick()` for clock only (called from `requestAnimationFrame`)
4. Document the JS-side wiring for each DOM event type
5. Add an example (`exs/click-drag-cancel.lua`) mirroring the PICO version
