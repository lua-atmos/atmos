import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { resolve, dirname } from 'node:path';
import puppeteer from 'puppeteer';

const __dirname = dirname(fileURLToPath(import.meta.url));
const HTML_DIR = resolve(__dirname, '..');

const TIERS = ['lua.html', 'lua-atmos.html', 'atmos.html'];
const LOADING = ['Loading...', 'Running...', 'Compiling...'];
const TIMEOUT = 30_000;
const POLL = 100;

function fileUrl (name, code) {
    const abs = resolve(HTML_DIR, name);
    const hash = Buffer.from(code).toString('base64');
    return 'file://' + abs + '#' + hash;
}

async function waitStatus (page) {
    const t0 = Date.now();
    while (Date.now() - t0 < TIMEOUT) {
        const txt = await page.$eval(
            '#status', el => el.textContent
        );
        if (!LOADING.includes(txt)) return txt;
        await new Promise(r => setTimeout(r, POLL));
    }
    throw new Error('timeout waiting for status');
}

async function run () {
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--allow-file-access-from-files'],
    });

    let failed = false;

    for (const tier of TIERS) {
        // Happy path
        const page1 = await browser.newPage();
        const url1 = fileUrl(tier, 'print("hello")');
        await page1.goto(url1, {
            waitUntil: 'domcontentloaded',
        });
        const st1 = await waitStatus(page1);
        const out1 = await page1.$eval(
            '#output', el => el.textContent
        );
        try {
            assert.equal(st1, 'Done.',
                tier + ' happy: status');
            assert.equal(out1, 'hello\n',
                tier + ' happy: output');
            console.log('PASS', tier, 'happy');
        } catch (e) {
            console.error('FAIL', tier, 'happy:', e.message);
            failed = true;
        }
        await page1.close();

        // Error path
        const page2 = await browser.newPage();
        const url2 = fileUrl(tier, 'invalid!!!lua');
        await page2.goto(url2, {
            waitUntil: 'domcontentloaded',
        });
        const st2 = await waitStatus(page2);
        const out2 = await page2.$eval(
            '#output', el => el.textContent
        );
        try {
            assert.equal(st2, 'Error.',
                tier + ' error: status');
            assert.ok(out2.includes('ERROR'),
                tier + ' error: output contains ERROR');
            console.log('PASS', tier, 'error');
        } catch (e) {
            console.error('FAIL', tier, 'error:', e.message);
            failed = true;
        }
        await page2.close();
    }

    await browser.close();
    if (failed) process.exit(1);
}

run();
