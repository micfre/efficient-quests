# Offline tests

Run these commands from the repository root. You need Lua 5.1 and Python 3.9 or later.

```sh
lua5.1 tests/runtime.lua
lua5.1 tests/guide.lua
lua5.1 tests/hints.lua
lua5.1 tests/lifecycle.lua
lua5.1 tests/ui.lua
python3 -m unittest discover -s tests -p 'test_*.py'
```

The Lua tests load the addon files and simulate the game, QuestieDB, and FlareUI. They cover guide advice, player context, ranking, item and flight observations, and interface actions. The Python tests exercise the local guide adaptation tool.

`tools/audit_extraction.lua` is a separate review aid for a locally installed guide package; it is not part of the test suites because the packages are third-party and not committed. See `docs/tug-extraction-audit.md`.

These tests run without the game. They do not establish compatibility with a Forever build or visual fidelity at a particular interface scale. The [MVP specification](../docs/specs/efficient-quests-mvp.md) lists the separate in-client checks.
