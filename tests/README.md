# Offline tests

Run these commands from the repository root. You need Lua 5.1 and Python 3.9 or later. If you have no Lua interpreter, Docker can run the Lua parts, including the extraction audit that the builder tests start. The commands use the interpreter name `lua5.1`; use your Lua 5.1 interpreter's own name if it differs.

```sh
lua5.1 tests/runtime.lua
lua5.1 tests/guide.lua
lua5.1 tests/hints.lua
lua5.1 tests/lifecycle.lua
lua5.1 tests/ui.lua
lua5.1 tests/manifest.lua
python3 -m unittest discover -s tests -p 'test_*.py'
```

The Lua tests load the addon files and simulate the game, QuestieDB, and FlareUI. Each suite except `tests/manifest.lua` loads the addon through the shared `tests/addon.lua` loader, which runs the files in the TOC's order, and every suite remains individually runnable. The manifest suite instead reads the shipped manifest text and the files the manifest lists. It checks the declared version and dependencies, and it rejects leftover mentions of removed addons. They cover guide extraction, setup status, player context, local relevance and ranking, supply and consumption observations, flight-path observations, and interface actions. The Python tests exercise the guide plugin builder. The builder tests use synthetic guide packages in a temporary folder. No third-party guide text is committed.

## Extraction audit

`tools/audit_extraction.lua` is a review aid for guide packages. It never writes the package. It reads two shapes of guide file: source packages that call `Guidelime.registerGuide`, and built plugin folders that call `EfficientQuests_RegisterGuide`. The author argument is optional in both shapes. Run it from the repository root:

```sh
lua5.1 tools/audit_extraction.lua "/path/to/Interface/AddOns/GuideLime_TUGs_Forever" [--json]
```

It registers every guide that the `.toc` file of the package lists. It reports safety findings, coverage counts, and candidate lines that produced no advice. With `--json` it prints one machine-readable document instead of the human report. The document holds the counts, the findings by severity, and the per-context record counts. It exits 0 when it audited every package, 2 when it could not read one, and 1 on a usage error.

The builder uses `--json` as a build gate over each plugin it built. The build fails when the audit extracts no advice record, or when it reports a safety finding. A safety finding is any severity except WATCH. The build warns when the audit withheld more than half of the candidate advice lines, and it writes the counts, the findings, and the gate result into `<plugin>/extraction-audit.json` inside the plugin folder. See [docs/tug-extraction-audit.md](../docs/tug-extraction-audit.md) for the reviewed results and the known withheld categories.

These tests run without the game. They do not establish compatibility with a Forever build or visual fidelity at a particular interface scale. The [MVP specification](../docs/specs/efficient-quests-mvp.md) lists the separate in-client checks.
