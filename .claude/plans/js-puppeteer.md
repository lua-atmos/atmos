# Plan: js-puppeteer

## Context

The three HTML tiers (`lua.html`, `lua-atmos.html`, `atmos.html`)
are the main user-facing artifacts for running Lua/atmos code in
the browser. Currently there are no automated tests verifying
they actually work. This plan adds Puppeteer-based CI tests that
open each HTML file in headless Chrome and assert correct output.

## Approach

- **No HTTP server** — open HTML files via `file://` protocol
- **Plain assert** — no test framework, just `assert` +
  `process.exit(1)` (matches Lua test style)
- **Puppeteer flag** `--allow-file-access-from-files` to allow
  the CDN ES module import from `file://` pages
- **Error test** — also test invalid code → status "Error."

## Files to create/modify

### 1. `atmos/env/js/test/package.json` (new)

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

### 2. `atmos/env/js/test/test.mjs` (new)

```
- Launch Puppeteer with --allow-file-access-from-files
- Resolve absolute file:// path to each HTML
- For each tier:
    - Happy path: pass btoa('print("hello")') in hash
    - Wait for #status !== "Loading..."/"Running..."/"Compiling..."
      (poll every 100ms, timeout 30s)
    - Assert #status === "Done." and #output === "hello\n"
    - Error path: pass btoa('invalid!!!lua') in hash
    - Assert #status === "Error."
- Close browser, exit 0 on success / 1 on failure
```

Test cases:

| Tier             | Input (base64'd)      | Expected status | Expected output |
|------------------|-----------------------|-----------------|-----------------|
| lua.html         | `print("hello")`      | "Done."         | "hello\n"       |
| lua-atmos.html   | `print("hello")`      | "Done."         | "hello\n"       |
| atmos.html       | `print("hello")`      | "Done."         | "hello\n"       |
| lua.html         | `invalid!!!lua`       | "Error."        | (contains ERROR) |
| lua-atmos.html   | `invalid!!!lua`       | "Error."        | (contains ERROR) |
| atmos.html       | `invalid!!!lua`       | "Error."        | (contains ERROR) |

Notes:
- lua-atmos.html wraps code in `start(function() <code>
  JS_done=true end)` — raw Lua works
- atmos.html wraps code in `(func (...) { <code> })(...)` then
  compiles — `print("hello")` is valid atmos-lang
- For error test on atmos.html, the invalid syntax should fail
  at the compilation step

### 3. `.github/workflows/test.yml` (modify)

Add `js-test` job (independent, parallel with existing jobs):

```yaml
js-test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with:
        node-version: 22
    - name: Cache Puppeteer browsers
      uses: actions/cache@v4
      with:
        path: ~/.cache/puppeteer
        key: puppeteer-${{ runner.os }}-${{ hashFiles('atmos/env/js/test/package.json') }}
    - name: Install dependencies
      run: cd atmos/env/js/test && npm ci
    - name: Run Puppeteer tests
      run: cd atmos/env/js/test && npm test
```

## Implementation order

1. Create `atmos/env/js/test/package.json`
2. Create `atmos/env/js/test/test.mjs`
3. Add `js-test` job to `.github/workflows/test.yml`
4. Local testing (user runs manually)
5. Commit & push (after user approval)

## Verification

1. `cd atmos/env/js/test && npm install && npm test`
2. All 6 test cases should pass (3 happy + 3 error)
3. CI should show green for the new `js-test` job

## Status

- [x] Create test/package.json
- [x] Create test/test.mjs
- [x] Update CI workflow
- [x] Test locally — all 6/6 pass
- [ ] Commit & push

## Bonus fix

- [x] Fixed bug in `atmos/env/js/atmos.js:33`:
  `JS_loadstring` → `atm_loadstring` (function was
  never defined, test caught it)
- [x] Rebuilt `atmos.html` via `build.sh`
