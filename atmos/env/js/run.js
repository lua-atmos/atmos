// run.js — shared utilities for all three tiers
// Never used standalone; concatenated with a tier file by build.sh

import { LuaFactory } from
    'https://cdn.jsdelivr.net/npm/wasmoon@1.16.0/+esm';

const GITHUB_RAW = 'https://raw.githubusercontent.com';
// TODO: pin to a release tag instead of main
const BRANCH = 'main';

const RUNTIME_MODULES = [
    { name: 'streams',        repo: 'lua-atmos/f-streams', path: 'streams/init.lua' },
    { name: 'atmos',          repo: 'lua-atmos/atmos',     path: 'atmos/init.lua' },
    { name: 'atmos.util',     repo: 'lua-atmos/atmos',     path: 'atmos/util.lua' },
    { name: 'atmos.run',      repo: 'lua-atmos/atmos',     path: 'atmos/run.lua' },
    { name: 'atmos.streams',  repo: 'lua-atmos/atmos',     path: 'atmos/streams.lua' },
    { name: 'atmos.x',        repo: 'lua-atmos/atmos',     path: 'atmos/x.lua' },
    { name: 'atmos.env.js',   repo: 'lua-atmos/atmos',     path: 'atmos/env/js/init.lua' },
];

const COMPILER_MODULES = [
    { name: 'atmos.lang.global',   repo: 'atmos-lang/atmos', path: 'src/global.lua' },
    { name: 'atmos.lang.aux',      repo: 'atmos-lang/atmos', path: 'src/aux.lua' },
    { name: 'atmos.lang.lexer',    repo: 'atmos-lang/atmos', path: 'src/lexer.lua' },
    { name: 'atmos.lang.parser',   repo: 'atmos-lang/atmos', path: 'src/parser.lua' },
    { name: 'atmos.lang.prim',     repo: 'atmos-lang/atmos', path: 'src/prim.lua' },
    { name: 'atmos.lang.coder',    repo: 'atmos-lang/atmos', path: 'src/coder.lua' },
    { name: 'atmos.lang.tosource', repo: 'atmos-lang/atmos', path: 'src/tosource.lua' },
    { name: 'atmos.lang.exec',     repo: 'atmos-lang/atmos', path: 'src/exec.lua' },
    { name: 'atmos.lang.run',      repo: 'atmos-lang/atmos', path: 'src/run.lua' },
];

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

async function preloadModule (lua, name, src) {
    lua.global.set('_mod_name_', name);
    lua.global.set('_mod_src_', src);
    await lua.doString(
        'package.preload[_mod_name_]'
        + ' = assert(load(_mod_src_,'
        + ' "@" .. _mod_name_))'
    );
}

async function fetchModules (lua, modules) {
    const entries = await Promise.all(
        modules.map(async ({ name, repo, path }) => {
            const url = `${GITHUB_RAW}/${repo}/${BRANCH}/${path}`;
            const res = await fetch(url);
            if (!res.ok)
                throw new Error(`fetch ${name}: ${res.status}`);
            return { name, src: await res.text() };
        })
    );
    for (const { name, src } of entries)
        await preloadModule(lua, name, src);
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
