// lua.js — bare Lua runner (no atmos)

(async () => {
    const code = getCode();
    if (!code) return;

    status.textContent = 'Loading...';
    const lua = await createEngine();

    status.textContent = 'Running...';
    try {
        await lua.doString(code);
        status.textContent = 'Done.';
    } catch (e) {
        output.textContent += 'ERROR: ' + e.message + '\n';
        status.textContent = 'Error.';
    }
})();
