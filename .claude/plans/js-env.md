# Plan: js-env

## Problem

`build.sh` fails with 404 when fetching `streams/init.lua` from
`lua-atmos/f-streams` because that repo had no version tag, and
all modules shared a single `$VERSION` (v0.5).

## Solution

1. Created `v0.2` tag on `lua-atmos/f-streams` (at main HEAD)
2. Changed module lists to per-entry versioning (4 fields:
   name, repo, version, path)
3. Kept `VERSION="v0.5"` for the HTML JS comment header

## Status

- [x] Create v0.2 tag on f-streams
- [x] Update build.sh with per-entry versions
- [x] Fix $VERSION reference in generate_html
- [ ] Test build
