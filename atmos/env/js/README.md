# atmos.env.js

A `js` environment for [lua-atmos](../../../) running in the browser
via [wasmoon](https://github.com/nicholascash/wasmoon) (Lua 5.4 in
WebAssembly).

Unlike other environments, JS has no poll or main loop — the browser
event loop is implicit.  This environment uses `start(body)` instead
of `loop(body)`: it spawns the body and returns immediately, letting
the JS host drive events.

# Contract

The JS host must provide one global before `require "atmos.env.js"`:

| Global     | Signature       | Description                         |
|------------|-----------------|-------------------------------------|
| `js_now()` | `() -> number`  | Current time in ms (e.g. `Date.now()`) |

The Lua module provides:

| Field       | Description                                              |
|-------------|----------------------------------------------------------|
| `M.tick()`  | Call from JS to emit a clock event (reads `js_now()`)    |
| `M.now`     | Last clock time in ms                                    |
| `M.running` | `true` after `start()`, `false` after `stop()`          |

# Lifecycle

```
JS host                          Lua
───────                          ───
lua.global.set('js_now', ...)
                                 require "atmos.env.js"
                                 start(function () ... end)
                                   -> open(): M.now = js_now(), M.running = true
                                   -> spawn body, return immediately
requestAnimationFrame loop:
  env.tick()                     -> emit('clock', dt, now)
  env.tick()                     -> emit('clock', dt, now)
  ...
                                 body finishes -> stop()
                                   -> close(): M.running = false
env.running == false -> stop RAF
```

# JS-side Usage (wasmoon)

```javascript
import { LuaFactory } from
    'https://cdn.jsdelivr.net/npm/wasmoon@1.16.0/+esm';

const factory = new LuaFactory();
const lua = await factory.createEngine();

// 1. Bridge JS globals into Lua
lua.global.set('js_now', () => Date.now());
lua.global.set('print', (...args) => {
    document.getElementById('output').textContent += args.join('\t') + '\n';
});

// 2. Preload Lua modules (atmos, atmos.env.js, etc.)
//    ... (see atmos-lang/web build.sh for module loading)

// 3. Boot the environment and start user code
await lua.doString(`
    local env = require "atmos.env.js"
    start(function ()
        watching(clock{s=5}, function ()
            every(clock{s=1}, function ()
                print("Hello World!")
            end)
        end)
        stop()
    end)
`);

// 4. Drive the clock from requestAnimationFrame
function frame () {
    lua.doString('require("atmos.env.js").tick()');

    // Check if still running
    lua.doString('_js_running_ = require("atmos.env.js").running');
    if (lua.global.get('_js_running_')) {
        requestAnimationFrame(frame);
    }
}
requestAnimationFrame(frame);
```

# Run (mock JS host)

The example uses `os.clock()` to simulate `js_now()`:

```
lua5.4 <lua-path>/atmos/env/js/exs/hello.lua
```

# Events

- `clock`
