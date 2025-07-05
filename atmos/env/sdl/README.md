# atmos.env.sdl

A [lua-atmos](../../) environment for [SDL][1] based on [lua-sdl2][2].

# Run

```
lua5.4 <lua-path>/atmos/env/sdl/exs/click-drag-cancel.lua
```

Requires font [DejaVuSans.ttf][3] in the current directory.

# Events

- `clock`
- `'sdl.step (ms)'`
- `'sdl.draw'`
- `SDL.event.*`

[1]: https://www.libsdl.org/
[2]: https://github.com/Tangent128/luasdl2/
[3]: https://github.com/lua-atmos/atmos/blob/v0.1/atmos/env/sdl/exs/DejaVuSans.ttf
