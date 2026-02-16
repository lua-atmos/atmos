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
        lua.global.set('_mod_name_', el.dataset.module);
        lua.global.set('_mod_src_', el.textContent);
        await lua.doString(
            'package.preload[_mod_name_]'
            + ' = assert(load(_mod_src_,'
            + ' "@" .. _mod_name_))'
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
                `local E = require("atmos.env.js")`
                + `\nlocal dt = ${now} - E.now`
                + `\nif dt > 0 then`
                + `\n    E.now = ${now}`
                + `\n    emit('clock', dt, ${now})`
                + `\nend`
            );
            if (lua.global.get('_atm_done_')) {
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
