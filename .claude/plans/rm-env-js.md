# Plan: rm-env-js

Remove `atmos/env/js/` from the lua-atmos monorepo, since the
standalone repo `lua-atmos/env-js` now subsumes it.

## Comparison

The external repo (`lua-atmos/env-js`) has all local files plus:
- `.github/workflows/test.yml` (its own CI)
- `.gitignore`, `LICENSE`

### Divergences (external is ahead)
- **run.js**: external added `src` attribute fetching for
  `<script>` tags; local only reads inline `textContent`
- **build.sh**: external uses `src` URL attributes in HTML
  (no curl/tmp); local inlines module content via curl.
  Also, external points `atmos.env.js` to `lua-atmos/env-js`
  instead of `lua-atmos/atmos` monorepo path
- **test/test.mjs**: minor rename (`fileUrl` → `pageUrl`),
  arg order swap
- **README.md**: different title

**Verdict**: external repo subsumes local. Safe to remove.

## Steps

### 1. Delete `atmos/env/js/` directory
- `git rm -r atmos/env/js/`

### 2. Update `README.md`
- Remove directory tree entry (lines 174-175):
  ```
  │   └── js/
  │       └── init.lua
  ```
- Update environments list (lines 209-211):
  replace local link with external repo link + note

### 3. Update `.github/workflows/test.yml`
- Remove `build` job (lines 25-32)
- Remove `js-test` job (lines 34-49)

## Progress
- [x] Step 1 — delete directory (13 files)
- [x] Step 2 — update README.md
- [x] Step 3 — update CI workflow
