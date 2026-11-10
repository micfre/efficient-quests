# Offline tests

Run these commands from the repository root. You need Lua 5.1 and Python 3.9 or later. If you have no Lua interpreter, Docker can run the Lua parts, including the extraction audit that the builder tests start. The commands use the interpreter name `lua5.1`; use your Lua 5.1 interpreter's own name if it differs.

```sh
lua5.1 tests/runtime.lua
lua5.1 tests/guide.lua
lua5.1 tests/hints.lua
lua5.1 tests/lifecycle.lua
lua5.1 tests/ui.lua
lua5.1 tests/manifest.lua
sh tests/bridge.sh
python3 -m unittest discover -s tests -p 'test_*.py'
```

The Lua tests load the addon files and simulate the game, QuestieDB, and FlareUI. Each suite except `tests/manifest.lua` loads the addon through the shared `tests/addon.lua` loader, which runs the files in the TOC's order, and every suite remains individually runnable. The manifest suite instead reads the shipped manifest text and the files the manifest lists. It checks the declared version and dependencies, and it rejects leftover mentions of removed addons. They cover guide extraction, setup status, player context, local relevance and ranking, supply and consumption observations, flight-path observations, and interface actions. The Python tests exercise the guide plugin builder and the release tool. The builder tests use synthetic guide packages in a temporary folder. No third-party guide text is committed.

The bridge suite connects the builder to the addon. The command `sh tests/bridge.sh` builds the synthetic fixture package in `tests/fixtures/GuideLime_Fixture_One` with the real builder and its own test catalog. The suite then loads the generated plugin folder next to the addon, in the order that the plugin manifest lists, and it asserts the plugin's guides through the addon's public interfaces. The script runs the build with Python on the host. It then runs the Lua suite with `lua5.1`, then `lua`, both from the PATH. When neither interpreter is installed, it runs the suite in the Docker image `nickblah/lua:5.1`. The environment variables `EQ_AUDIT_LUA` (an interpreter command) and `EQ_LUA_IMAGE` (a Docker image) override these choices. The builder follows the same convention. The Docker image has no Python, so the build always runs on the host. The build output stays under `tests/bridge-test/`, which Git ignores.

## Release dry-run

`tools/release.py` builds a release. It zips the core addon and every catalog guide whose distribution flag is on. Each shipped guide zip holds the built plugin folder with its `extraction-audit.json` report and its license file inside. A guide whose flag is off is built for the log but gets no zip. The command needs the directory that holds the source packages. The repository does not contain them. One run from the repository root:

```sh
python3 tools/release.py --sources prior_art --date 2026-11-10
```

The release fails before it writes anything when a distributable source package is missing or a guide fails its build gate. Zips land in `dist/`, which Git ignores. The same `--date` gives the same zips byte for byte.

The CI workflow runs a dry-run of the release with the synthetic packages in `tests/fixtures` and the catalog `tests/fixtures/release-catalog.json`. The dry-run proves the license gate: the flagged fixture guide is zipped, and the unflagged fixture guide is built but produces no zip. The workflow prints the audit reports into the log. Real guide packages are private, so a real release is a step for the maintainer on a machine that has them.

## Extraction audit

`tools/audit_extraction.lua` is a review aid for guide packages. It never writes the package. It reads two shapes of guide file: source packages that call `Guidelime.registerGuide`, and built plugin folders that call `EfficientQuests_RegisterGuide`. The author argument is optional in both shapes. Run it from the repository root:

```sh
lua5.1 tools/audit_extraction.lua "/path/to/Interface/AddOns/GuideLime_TUGs_Forever" [--json]
```

It registers every guide that the `.toc` file of the package lists. It reports safety findings, coverage counts, and candidate lines that produced no advice. With `--json` it prints one machine-readable document instead of the human report. The document holds the counts, the findings by severity, and the per-context record counts. It exits 0 when it audited every package, 2 when it could read no package, and 1 on a usage error.

The builder uses `--json` as a build gate over each plugin it built. The build fails when the audit extracts no advice record, or when it reports a finding with a severity other than WATCH. WATCH is the only advisory severity. The screen fails closed: a severity that the builder does not know also fails the build. The build warns when the audit withheld more than half of the candidate advice lines, and it writes the counts, the findings, and the gate result into `<plugin>/extraction-audit.json` inside the plugin folder. See [docs/tug-extraction-audit.md](../docs/tug-extraction-audit.md) for the reviewed results and the known withheld categories.

These tests run without the game. They do not establish compatibility with a Forever build or visual fidelity at a particular interface scale. The [MVP specification](../docs/specs/efficient-quests-mvp.md) lists the separate in-client checks.
