# atmos/env/js

Browser-based runners for Lua and Atmos programs.
Source code is passed as a base64 hash in the URL fragment.

## HTML files

| File             | Input language | Runtime              |
|------------------|----------------|----------------------|
| `lua.html`       | Lua            | bare Lua             |
| `lua-atmos.html` | Lua            | lua-atmos            |
| `atmos.html`     | Atmos (`.atm`) | lua-atmos + compiler |

## Usage

Open any HTML file with a `#<base64>` fragment:

    lua.html#cHJpbnQoImhlbGxvIik=

The fragment is the base64-encoded source code.
Output goes to the `<pre id="output">` element;
status goes to `<span id="status">`.

## Generating a hash

From a source file (`.lua` or `.atm`):

    base64 -w0 < hello.lua

Or inline:

    echo -n 'print("hello")' | base64 -w0

Append the result after `#` in the URL:

    file:///path/to/lua.html#cHJpbnQoImhlbGxvIik=

## Rebuilding

    ./build.sh

Fetches all runtime and compiler modules from GitHub
and regenerates the three HTML files.
