// run.js — shared utilities for all three tiers
// Never used standalone; concatenated with a tier file by build.sh

import { LuaFactory } from
    'https://cdn.jsdelivr.net/npm/wasmoon@1.16.0/+esm';

const output = document.getElementById('output');
const status = document.getElementById('status');

function getCode () {
    const hash = location.hash.slice(1);
    if (!hash) {
        status.textContent = 'No program in URL.';
        return null;
    }
    return atob(hash);
}

async function createEngine () {
    const factory = new LuaFactory();
    const lua = await factory.createEngine();
    lua.global.set('print', (...args) => {
        output.textContent += args.join('\t') + '\n';
    });
    return lua;
}

async function preloadModules (lua) {
    const tags = document.querySelectorAll(
        'script[type="text/lua"]'
    );
    for (const el of tags) {
        lua.global.set('JS_mod_name', el.dataset.module);
        lua.global.set('JS_mod_src', el.textContent);
        await lua.doString(
            'package.preload[JS_mod_name]'
            + ' = assert(load(JS_mod_src,'
            + ' "@" .. JS_mod_name))'
        );
    }
}

function startLoop (lua) {
    let emitting = false;
    const interval = setInterval(() => {
        if (emitting) return;
        emitting = true;
        try {
            const now = Date.now();
            lua.doString(
                `local E = JS_env`
                + `\nlocal dt = ${now} - E.now`
                + `\nif dt > 0 then`
                + `\n    E.now = ${now}`
                + `\n    emit('clock', dt, ${now})`
                + `\nend`
            );
            if (lua.global.get('JS_done')) {
                clearInterval(interval);
                lua.doString('stop()');
                status.textContent = 'Done.';
            }
        } finally {
            emitting = false;
        }
    }, 16);
    return interval;
}
