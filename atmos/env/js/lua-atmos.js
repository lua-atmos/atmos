// lua-atmos.js — Lua code running under atmos runtime

(async () => {
    const code = getCode();
    if (!code) return;

    status.textContent = 'Loading...';
    const lua = await createEngine();
    await preloadModules(lua);
    lua.global.set('JS_now', () => Date.now());

    let interval;
    lua.global.set('JS_close', () => clearInterval(interval));

    status.textContent = 'Running...';
    try {
        await lua.doString(
            'JS_env = require("atmos.env.js")\n'
            + 'start(function()\n'
            + code + '\n'
            + 'JS_done = true\n'
            + 'end)'
        );
        interval = startLoop(lua);
    } catch (e) {
        output.textContent += 'ERROR: ' + e.message + '\n';
        status.textContent = 'Error.';
    }
})();
