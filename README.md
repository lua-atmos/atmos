# lua-atmos (v0.1)

`lua-atmos` is a [synchronous programming][1] library for [Lua][2] that reconciles
*[Structured Concurrency][3]* with *[Event-Driven Programming][4]* in order to
extend classical structured programming with two main functionalities:

- Structured Deterministic Concurrency:
    - A set of structured primitives to lexically compose concurrent tasks
      (e.g., `spawn`, `par_or`, `toggle`).
    - A synchronous and deterministic scheduling policy, which provides
      predictable behavior and safe abortion of tasks.
    - A container primitive to hold dynamic tasks, which automatically releases
      them as they terminate.
- Event Signaling Mechanisms:
    - An `await` primitive to suspend a task and wait for events.
    - An `emit` primitive to signal events and awake awaiting tasks.

`lua-atmos` is inspired by [Ceu][5], which is inpired by [Esterel][6].

**TODO**

[1]: https://www.lua.org/
[2]: https://fsantanna.github.io/sc.html
[3]: https://en.wikipedia.org/wiki/Structured_concurrency
[4]: https://en.wikipedia.org/wiki/Event-driven_programming
[5]: https://www.ceu-lang.org/
[6]: https://en.wikipedia.org/wiki/Esterel
