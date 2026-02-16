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
        lua.global.set('_atm_src_', wrapped);
        lua.global.set('_atm_file_', 'input.atm');

        status.textContent = 'Running...';
        await lua.doString(
            'require("atmos.env.js")\n'
            + 'local f, err = '
            + 'atm_loadstring(_atm_src_, _atm_file_)\n'
            + 'if not f then error(err) end\n'
            + 'start(function()\n'
            + '    f()\n'
            + '    _atm_done_ = true\n'
            + 'end)'
        );
        interval = startLoop(lua);
    } catch (e) {
        output.textContent += 'ERROR: ' + e.message + '\n';
        status.textContent = 'Error.';
    }
})();
