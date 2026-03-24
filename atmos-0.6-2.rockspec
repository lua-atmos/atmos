package = "atmos"
version = "0.6-1"
source = {
   url = "git+https://github.com/lua-atmos/atmos",
   branch = "v0.6",
}
description = {
   summary = [[
    Structured Event-Driven Concurrency for Lua
   ]],
   detailed = [[
    Atmos is a programming library for Lua that reconciles Structured
    Concurrency and Event-Driven Programming, extending classical
    structured programming with two main functionalities:

    - Structured Deterministic Concurrency:
        - A `task` primitive with deterministic scheduling provides predictable
          behavior and safe abortion.
        - Structured primitives compose concurrent tasks with lexical scope (e.g.,
          `watching`, `every`, `par_or`).
        - A `tasks` container primitive holds attached tasks and control their
          lifecycle.
    - Event Signaling Mechanisms:
        - An `await` primitive suspends a task and wait for events.
        - An `emit` primitive signals events and awake awaiting tasks.

    Atmos is inspired by synchronous programming languages like Céu
    and Esterel.
   ]],
   homepage = "https://github.com/lua-atmos/atmos",
   license = "MIT",
}
dependencies = {
   "lua >= 5.4",
   "f-streams ~> 0.2",
}
build = {
   type = "builtin",
   modules = {
      ["atmos.init"] = "atmos/init.lua",
      ["atmos.run"] = "atmos/run.lua",
      ["atmos.util"] = "atmos/util.lua",
      ["atmos.x"] = "atmos/x.lua",
      ["atmos.streams"] = "atmos/streams.lua",
      ["atmos.env.clock.init"] = "atmos/env/clock/init.lua",
      ["atmos.env.clock.exs.hello"] = "atmos/env/clock/exs/hello.lua",
   },
}
