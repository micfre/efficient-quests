# Offline tests

Run these commands from the repository root. You need Lua 5.1 and Python 3.9 or later. The commands use the interpreter name `lua5.1`; use your Lua 5.1 interpreter's own name if it differs.

```sh
lua5.1 tests/runtime.lua
lua5.1 tests/guide.lua
lua5.1 tests/hints.lua
lua5.1 tests/lifecycle.lua
lua5.1 tests/ui.lua
python3 -m unittest discover -s tests -p 'test_*.py'
```

The Lua tests load the addon files and simulate the game, QuestieDB, and FlareUI. Each suite loads the addon through the shared `tests/addon.lua` loader, which runs the files in the TOC's order, and every suite remains individually runnable. They cover guide extraction, setup status, player context, local relevance and ranking, supply and consumption observations, flight-path observations, and interface actions. The Python tests exercise the local guide adaptation tool.

## Extraction audit

`tools/audit_extraction.lua` is a separate review aid for a locally installed guide package; it is not part of the test suites because the packages are third-party and not committed. It only reads the package. Run it from the repository root:

```sh
lua5.1 tools/audit_extraction.lua "/path/to/Interface/AddOns/GuideLime_TUGs_Forever"
```

It registers every guide the package's `.toc` file lists and reports safety findings, coverage counts, and candidate lines that produced no advice. See [docs/tug-extraction-audit.md](../docs/tug-extraction-audit.md) for the reviewed results and the known withheld categories.

These tests run without the game. They do not establish compatibility with a Forever build or visual fidelity at a particular interface scale. The [MVP specification](../docs/specs/efficient-quests-mvp.md) lists the separate in-client checks.
