package = "atmos"
version = "dev-3"
source = {
   url = "git+https://github.com/lua-atmos/atmos",
   branch = "main",
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
          `watching`, `loop_on`, `par_any`).
        - A `tasks` container primitive holds attached tasks and controls their
          lifecycle.
    - Event Signaling Mechanisms:
        - An `await` primitive suspends a task and waits for events.
        - An `emit` primitive signals events and awakes awaiting tasks.

    Atmos also complements its core synchronous concurrency model with
    Functional Streams (à la ReactiveX) and Multithreading Parallelism
    (via LuaLanes):

    - Functional Streams:
        - Interoperability with tasks & events.
        - Safe finalization of stateful streams.
    - Asynchronous Parallelism:
        - A `thread` primitive offloads computations to isolated OS threads.
        - Safe abortion and finalization for threads.

    Atmos is inspired by synchronous programming languages like Céu
    and Esterel.
   ]],
   homepage = "https://github.com/lua-atmos/atmos",
   license = "MIT",
}
dependencies = {
   "lua >= 5.4",
   "f-streams",
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
