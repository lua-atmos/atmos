package = "atmos"
version = "0.3-3"
source = {
   url = "git+https://github.com/lua-atmos/atmos",
   branch = "v0.3",
}
description = {
   summary = [[
    Structured Event-Driven Concurrency for Lua
   ]],
   detailed = [[
    Atmos is a programming library for Lua that reconciles *Structured
    Concurrency*, *Event-Driven Programming*, and
    *Functional Streams*, extending classical structured programming
    with three main functionalities:

    - Structured Deterministic Concurrency:
        - A `task` primitive with deterministic scheduling provides predictable
          behavior and safe abortion.
        - Structured primitives compose concurrent tasks with lexical scope (e.g.,
          `watching`, `every`, `par_or`).
        - A `tasks` container primitive holds attached tasks and control their
          lifecycle.
    - Event Signaling Mechanisms:
        - An `await` primitive suspends a task and wait for events.
        - An `emit` primitive signal events and awake awaiting tasks.
    - Functional Streams (à la ReactiveX):
        - Functional combinators for lazy (infinite) lists.
        - Interoperability with tasks & events:
            tasks and events as streams, and
            streams as events.
        - Safe finalization of stateful (task-based) streams.

    Atmos is inspired by synchronous programming languages like Céu
    and Esterel.
   ]],
   homepage = "https://github.com/lua-atmos/atmos",
   license = "MIT",
}
dependencies = {
   "lua ~> 5.4",
   "f-streams ~> 0.2",
}
build = {
   type = "builtin",
   modules = {
      ["atmos.init"] = "atmos/init.lua",
      ["atmos.run"] = "atmos/run.lua",
      ["atmos.util"] = "atmos/util.lua",
      ["atmos.streams"] = "atmos/streams.lua",
      ["atmos.env.clock.init"] = "atmos/env/clock/init.lua",
      ["atmos.env.clock.exs.hello"] = "atmos/env/clock/exs/hello.lua",
      ["atmos.env.sdl.init"] = "atmos/env/sdl/init.lua",
      ["atmos.env.sdl.exs.click-drag-cancel"] = "atmos/env/sdl/exs/click-drag-cancel.lua",
      ["atmos.env.socket.init"] = "atmos/env/socket/init.lua",
      ["atmos.env.socket.exs.cli-srv"] = "atmos/env/socket/exs/cli-srv.lua",
      ["atmos.env.iup.init"] = "atmos/env/iup/init.lua",
      ["atmos.env.iup.exs.button-counter"] = "atmos/env/iup/exs/button-counter.lua",
   },
}
