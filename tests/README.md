# Addon behavioral tests

Run from the repository root with Lua 5.1 installed:

```sh
lua5.1 tests/runtime.lua
```

The test loads the same files as the addon TOC and supplies minimal game APIs.
Extend this boundary with simulated client, provider and tracker inputs and
assert player-visible hints and interactions. These offline tests do not prove
compatibility with a particular Forever build or UI scale.
