# Plan: js-puppeteer

## Goal

Add Puppeteer-based CI tests that verify the three HTML tiers
(`lua.html`, `lua-atmos.html`, `atmos.html`) actually run Lua
code correctly in a headless Chrome browser.

## Context

- The HTML files are self-contained: they import wasmoon from
  CDN and embed Lua modules as `<script type="text/lua">` tags
- Code is passed via the URL hash as base64
- `#output` (`<pre>`) captures print() output
- `#status` (`<span>`) shows lifecycle: Loading/Running/Done/Error
- `lua-atmos.html` and `atmos.html` use an event loop
  (`startLoop`) that sets `JS_done = true` when finished
- CI already has a `build` job that runs `build.sh` and checks
  HTML is up to date

## Approach

Use Puppeteer with a **local HTTP server** (not `file://`) to
avoid browser sandbox issues with non-standard paths. The CI
runner uses standard paths so `file://` would work, but a tiny
`http-server` is more portable and avoids the CDN ES module
import issue that `file://` can trigger.

## Files to create/modify

### 1. `atmos/env/js/test/test.mjs`

Single test script using Puppeteer (no test framework needed —
just assert + process.exit(1) on failure).

```
- spin up a static HTTP server on atmos/env/js/ (use `sirv`
  or Node's built-in http + fs)
- for each tier, open the HTML with a test program in the hash
- wait for #status to settle (not "Loading..."/"Running..."
  /"Compiling...")
- assert #status === "Done." and #output matches expected
- exit 0 on success, 1 on failure
```

**Test cases:**

| Tier           | Input (Lua/Atmos)                 | Expected output |
|----------------|-----------------------------------|-----------------|
| `lua.html`     | `print("hello")`                  | `hello\n`       |
| `lua-atmos.html` | `print("hello")`               | `hello\n`       |
| `atmos.html`   | `print("hello")`                  | `hello\n`       |

Notes:
- `lua-atmos` and `atmos` wrap user code in `start()`, so
  they go through the event loop before setting JS_done
- The event loop ticks at 16ms; use a generous timeout
  (e.g. 30s) for CI cold starts (wasmoon WASM download)
- Use Node's built-in `http` module + `fs` to serve files
  (no extra deps beyond puppeteer)

### 2. `atmos/env/js/test/package.json`

Minimal package.json for the test directory:

```json
{
    "private": true,
    "type": "module",
    "devDependencies": {
        "puppeteer": "^24.0.0"
    },
    "scripts": {
        "test": "node test.mjs"
    }
}
```

### 3. `.github/workflows/test.yml`

Add a new job `js-test` alongside existing `test` and `build`:

```yaml
js-test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with:
        node-version: 22
    - name: Install dependencies
      run: cd atmos/env/js/test && npm ci
    - name: Run Puppeteer tests
      run: cd atmos/env/js/test && npm test
```

Puppeteer on CI:
- `puppeteer` npm package downloads its own Chromium
- Ubuntu runners have the required shared libs
- If not, add `npx puppeteer browsers install chrome`
  or install deps with `npx puppeteer install --with-deps`

## Implementation order

1. Create `atmos/env/js/test/package.json`
2. Create `atmos/env/js/test/test.mjs`
3. Update `.github/workflows/test.yml` with `js-test` job
4. Test locally: `cd atmos/env/js/test && npm install && npm test`
5. Commit, push, verify CI

## Status

- [ ] Create test/package.json
- [ ] Create test/test.mjs
- [ ] Update CI workflow
- [ ] Test locally
- [ ] Commit & push
