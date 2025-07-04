package = "atmos"
version = "0.1-1"
source = {
   url = "git+https://github.com/lua-atmos/atmos",
   branch = "v0.1",
}
description = {
   summary = [[
    Atmos is a programming library for Lua that reconciles Structured
    Concurrency with Event-Driven Programming
   ]],
   detailed = [[
    Atmos is a programming library for Lua that reconciles *Structured
    Concurrency* with *Event-Driven Programming*, extending classical
    structured programming with two main functionalities:

    - Structured Deterministic Concurrency:
        - The `task` primitive with deterministic scheduling provides
          predictable behavior and safe abortion.
        - Structured primitives compose concurrent tasks with lexical scope
          (e.g., `watching`, `every`, `par_or`).
        - The `tasks` container primitive holds attached tasks and control
          their lifecycle.
    - Event Signaling Mechanisms:
        - The `await` primitive suspends a task and wait for events.
        - The `emit` primitive signal events and awake awaiting tasks.

    Atmos is inspired by synchronous programming languages like Ceu and
    Esterel.
   ]],
   homepage = "https://github.com/lua-atmos/atmos",
   license = "MIT",
}
dependencies = {
   "lua ~> 5.4",
}
build = {
   type = "builtin",
   modules = {
      ["atmos.init"] = "atmos/init.lua",
      ["atmos.run"] = "atmos/run.lua",
      ["atmos.util"] = "atmos/util.lua",
      ["atmos.env.clock.init"] = "atmos/env/clock/init.lua",
      ["atmos.env.clock.exs.hello"] = "atmos/env/clock/exs/hello.lua",
      ["atmos.env.sdl.init"] = "atmos/env/sdl/init.lua",
   },
}
