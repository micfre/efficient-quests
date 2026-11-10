# Addon behavioral tests

Run from the repository root with Lua 5.1 installed:

```sh
lua5.1 tests/runtime.lua
```

The test loads the same files as the addon TOC and supplies minimal game APIs.
Extend this boundary with simulated client, provider and tracker inputs and
assert player-visible hints and interactions. These offline tests do not prove
compatibility with a particular Forever build or UI scale.

Guide registration and extraction scenarios run at the same addon boundary:

```sh
lua5.1 tests/guide.lua
```

`lua5.1 tests/guide.lua` exercises extraction from registered guide chapters.
`lua5.1 tests/hints.lua` exercises the composed guide, provider, client-context,
and relevance path, including focus, acceptance, remote advice and uncertainty.
`lua5.1 tests/lifecycle.lua` exercises supply, quest and flight observations
through registered guide advice and simulated client and provider data.
