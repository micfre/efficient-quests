# Maintainer buildbook

This page explains how a maintainer turns a Guidelime-compatible guide package into an Efficient Quests guide plugin, and how a release is built. Players do not run any of this. Players install ready-made folders from the [releases page](https://github.com/micfre/efficient-quests/releases). See the [installation guide](installation.md) for the player flow.

Run every command in this book from the root of the repository. The build needs Python 3.9 or later. The extraction audit inside every build needs a Lua 5.1 interpreter (`lua5.1` or `lua` on the PATH) or Docker.

## The license check

A guide plugin is a copy of the guide text of its author. Shipping that copy in a release is redistribution. The license of the source package decides whether a release is allowed to contain the plugin.

- The Bethink package is GPLv3. Its plugin bundles the package license file. The plugin is effectively GPLv3. The release ships it.
- The TUG package carries no license statement. Without a statement, the package is all rights reserved. Its plugin must not ship. The permission request is tracked in the issue tracker.

The decision lives in the catalog as the `distribute` flag of each guide. The flag gates distribution only. A guide without redistribution permission still builds locally for development and tests. A local build never depends on the flag.

Before you add a guide to the catalog, read the license of its package. If the license allows redistribution, set `distribute` to `true`. If it does not, or the package states no license, set `distribute` to `false` and open an issue that tracks the permission.

## The catalog

The catalog is the file `tools/catalog.json`. It lists every supported guide. It is the supported-guide list, the collision guard, and the release build list. Each entry holds these fields:

| Field | Meaning |
| --- | --- |
| `source_package` | The name of the source package directory, for example `Guidelime_Bethink`. |
| `plugin` | The derived plugin name, for example `EfficientQuests_Bethink`. |
| `license` | A short license status string for humans. The build prints it. |
| `distribute` | The distribution flag. `true` means the release zips the plugin. `false` means the release builds it for the log and ships no zip. |
| `build_suffix` | A suffix appended to the source version, for example `-eq1`. It tells rebuilds of the same source apart. |

The plugin name is derived from the source name by a fixed rule. Strip the leading `Guidelime` prefix. Either capitalization matches. Delete the remaining underscores. Prefix `EfficientQuests_`. For example, `GuideLime_TUGs_Forever` becomes `EfficientQuests_TUGsForever`, and `Guidelime_Bethink` becomes `EfficientQuests_Bethink`. A source name that derives an empty tail is rejected.

Two source packages must never derive the same plugin name. The loader rejects the collision. To validate the catalog without a build, run:

```sh
python3 tools/build_guide.py --check-catalog
```

The command fails when a field is missing, when a plugin name breaks the naming rule, or when two entries collide. It also fails when the catalog lists no guides.

## Build a guide plugin

The builder reads a source package and writes a ready-to-zip plugin folder. It never changes the source package. One build of the Bethink guide from a local copy under `prior_art/`:

```sh
python3 tools/build_guide.py prior_art/Guidelime_Bethink --date 2026-11-10
```

Options:

- `--output DIR` sets the output directory. The default is `dist`, which Git ignores.
- `--catalog FILE` sets the catalog file. The default is `tools/catalog.json`.
- `--date YYYY-MM-DD` pins the build date. Pin the date for reproducible output.

The source package must appear in the catalog. The build fails when it does not.

The builder writes `dist/<plugin>/` with these files:

- `<plugin>.toc`, the generated manifest.
- `Guides.lua`, one file that replays every registration call of the source package verbatim as `EfficientQuests_RegisterGuide("<plugin>", <text>, <author>)`. The text and the author are copied byte for byte. The builder never interprets guide markup.
- The license file of the package, unchanged, when the package root holds one (LICENSE, LICENCE, COPYING, with or without `.txt`, any capitalization).
- `extraction-audit.json`, the per-guide audit report described below.

The generated manifest declares `Dependencies: EfficientQuests`. This is load-order critical. The registration hook of the core addon must exist before `Guides.lua` runs. The manifest also declares:

- `Title`, the display name. The builder copies the `Title` field of the source package verbatim. When the source declares no title, the plugin name is used and its underscores become spaces.
- `Version`, the source package version plus the `build_suffix` of the catalog entry.
- `X-EfficientQuests-Guide: 1`, the marker the core reads at login.
- `X-EfficientQuests-API: 1`, a reserved marker for a future contract change. The addon emits it and never reads it.
- Provenance fields: `X-EfficientQuests-Source-Name`, `X-EfficientQuests-Source-Version`, `X-EfficientQuests-Source-Checksum`, and `X-EfficientQuests-Build-Date`.

The source checksum is a sha256 over each TOC-listed file's name and digest, then the TOC itself, in TOC order. It identifies the exact source state of a build.

With `--date` pinned, a rebuild of the same source is byte-identical. The same is true for the release zips. To prove a reproduction, run the build twice and compare the checksums of the output.

The build fails when the package TOC lists no files, lists a file outside the package, contains no registration calls, or declares no version. A failed gate leaves no plugin folder behind.

The extraction audit needs Lua 5.1. The builder prefers `lua5.1`, then `lua`, both from the PATH. With neither, it runs the audit under Docker with the image `nickblah/lua:5.1`. Set the environment variable `EQ_AUDIT_LUA` to force one interpreter command, or `EQ_LUA_IMAGE` to use a different Docker image. The bridge script `tests/bridge.sh` picks its Lua by the same convention.

## Gates

Every build runs the extraction audit (`tools/audit_extraction.lua`) over the plugin it just built. The audit loads the guide text through the real extraction of the addon, for ten character contexts. The gate reads the machine report of the audit in `--json` mode.

The build fails when:

- The audit extracts no advice record from any character context.
- The audit reports a finding whose severity is not advisory. WATCH is the only advisory severity. Every other severity fails the build. The severities ROUTE, SPOILER, DANGLING, TAGS, QUANTITY, NAME, QUEST, and ERROR mean that route or narrative prose, malformed text, unstripped markup, or a lost quantity, item name, or quest link reached the visible text. A severity that a future audit adds also fails the build. The screen never lets an unknown problem pass. WATCH stays advisory. It flags phrases that need human eyes but are often mechanical.

The build warns when the audit withheld more than half of the candidate advice lines. The reviewed corpora withheld 18 percent (TUG) and 44 percent (Bethink) of their candidate lines. A majority withheld signals a guide that the extraction mostly cannot read.

On a passed gate, the builder writes the counts, the findings, and the gate result to `extraction-audit.json` inside the plugin folder. The same numbers go to the build log. On a failed gate, the plugin folder is deleted and the build exits with status 1.

For a human review of a package, run the audit directly. See the [extraction audit page](tug-extraction-audit.md) for the method and the reviewed results. That page is the historical evidence. The per-guide report regenerates on every build.

## Release

The release tool zips the core addon and every guide whose `distribute` flag is on. One release from local source packages under `prior_art/`:

```sh
python3 tools/release.py --sources prior_art --date 2026-11-10
```

Options:

- `--sources DIR` is required. It names the directory that holds the source packages. The repository does not contain them. Locally this is the Git-ignored `prior_art/` directory.
- `--output DIR` sets the output directory. The default is `dist`.
- `--catalog FILE` and `--date YYYY-MM-DD` work as in the builder.

The run works in this order:

1. The tool validates the catalog and looks for the source package of every distributable guide. When one is missing, the release fails before it writes anything. A release that silently ships less than the catalog promises is worse than an error.
2. The tool builds every catalog guide with the real builder, gates included. A distributable guide that fails its gate fails the release. A held-back guide that fails its gate only prints a warning. It never ships, so it never blocks.
3. The tool removes every `EfficientQuests*.zip` that an earlier run left in the output root. After a run, the zips present are exactly the ones the current catalog distributes. A flag flip cannot leave the zip of the previous release behind.
4. The tool zips the core addon and each distributable plugin folder, report and license file inside.

What ships today: the core addon zip and the Bethink plugin zip. What is held back: the TUG plugin. It is built for the log, and the release produces no zip for it. When the author grants permission, set `distribute` to `true` in the catalog, and the next release ships it.

Zip entries carry a fixed timestamp and permissions, and files are added in sorted order. A rerun with the same `--date` produces byte-identical zips.

Publish the zips as a GitHub release. The version of the core zip comes from the `## Version:` field of `dist/EfficientQuests/EfficientQuests.toc`, the single version source. The version of a guide zip mirrors the source package version plus the build suffix.

## CI

The workflow `.github/workflows/ci.yml` runs on every push and pull request. It runs:

- The six Lua suites in Docker (`tests/runtime.lua`, `tests/guide.lua`, `tests/hints.lua`, `tests/lifecycle.lua`, `tests/ui.lua`, `tests/manifest.lua`).
- The bridge suite (`sh tests/bridge.sh`). It builds a synthetic fixture guide with the real builder and loads the generated plugin next to the real core addon.
- The Python tests (`python3 -m unittest discover -s tests -p 'test_*.py'`), which cover the builder and the release tool.
- A release dry-run with the synthetic packages in `tests/fixtures` and the catalog `tests/fixtures/release-catalog.json`. The dry-run asserts the license gate: the flagged fixture guide ships as a zip, the unflagged fixture guide is built for the log and gets no zip, and exactly two zips exist. The workflow prints every extraction audit report into the log, shipped or held back.

The real guide packages never run in CI. They are third-party content under licenses that do not allow us to publish them. For this reason, `prior_art/` is excluded from version control, and CI only ever sees synthetic fixtures. A real release is always a step for the maintainer on a machine that holds the source packages.
