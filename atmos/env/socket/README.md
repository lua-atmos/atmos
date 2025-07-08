# atmos.env.socket

A [lua-atmos](../../../) environment for network communications based on
[luasocket][luasocket].

# Run

```
lua5.4 <lua-path>/atmos/env/socket/exs/cli-srv.lua
```

# Functions

- `xtcp ()`
- `xlisten (tcp, backlog)`
- `xaccept (srv)`
- `xconnect (tcp, addr, port)`
- `xrecv (tcp)`

# Events

- `clock`
- `'closed'`

[luasocket]:    https://lunarmodules.github.io/luasocket/
