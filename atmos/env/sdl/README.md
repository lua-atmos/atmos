# atmos.env.sdl

A simple `clock` environment for [lua-atmos](../../).

# Run

```
lua5.4 <lua-path>/atmos/env/sdl/exs/click-drag-cancel.lua
```

Requires font [DejaVuSans.ttf][1] in the current directory.

[1]: https://github.com/lua-atmos/atmos/blob/v0.1/atmos/env/sdl/exs/DejaVuSans.ttf

# Events

- `clock`
- `'sdl.step (ms)'`
- `'sdl.draw'`
- `SDL.event.*`
