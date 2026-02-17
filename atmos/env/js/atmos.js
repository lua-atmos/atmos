// atmos.js — compile .atm source, then run under atmos runtime

(async () => {
    const code = getCode();
    if (!code) return;

    status.textContent = 'Loading...';
    const lua = await createEngine();
    await preloadModules(lua);
    lua.global.set('JS_now', () => Date.now());

    let interval;
    lua.global.set('JS_close', () => clearInterval(interval));

    status.textContent = 'Compiling...';
    try {
        await lua.doString(
            'atmos = require "atmos"\n'
            + 'X = require "atmos.x"\n'
            + 'require "atmos.lang.exec"\n'
            + 'require "atmos.lang.run"'
        );

        const wrapped =
            '(func (...) { ' + code + '\n})(...)';
        lua.global.set('JS_src', wrapped);
        lua.global.set('JS_file', 'input.atm');

        status.textContent = 'Running...';
        await lua.doString(
            'JS_env = require("atmos.env.js")\n'
            + 'local f, err = '
            + 'JS_loadstring(JS_src, JS_file)\n'
            + 'if not f then error(err) end\n'
            + 'start(function()\n'
            + '    f()\n'
            + '    JS_done = true\n'
            + 'end)'
        );
        interval = startLoop(lua);
    } catch (e) {
        output.textContent += 'ERROR: ' + e.message + '\n';
        status.textContent = 'Error.';
    }
})();
