# ADR 0001: Standalone addon with the Trailwright engine

Status: accepted (2026-11-16).

## Context

The current Efficient Quests addon reads guides in the Guidelime format and extracts hints from them. It gives the player no route. It needs a separate guide plugin for each guide, and it depends on helper addons that it adapted. This design is hard to install and hard to keep correct.

Trailwright is a free addon under GPL-3.0-or-later. Its engine does what this project wants. It walks the Path, a fixed order of quests from level 1 to level 60, and builds the route from the quest state of the character. Its dungeon guide shows the stops of a dungeon in order. The engine carries generated data tables. The tools that generate them are not in the local copy of the reference material, so the data cannot be regenerated.

The full specification is `docs/specs/efficient-quests-standalone.md`. The terms are defined in `GLOSSARY.md`.

## Decision

Efficient Quests becomes one standalone addon with a built-in quest engine. The player installs one addon folder and needs no guide files and no helper addons.

The quest engine is a one-time port of the Trailwright engine. The port comes from a one-time snapshot of Trailwright. The snapshot has two version numbers: 0.1.81-beta in its manifest and 1.51.0 in its README. The credits file records both. The whole project stays under GPL-3.0-or-later.

Trailwright itself is never installed and is never needed. There are no ongoing merges from Trailwright.

## Consequences

- One addon folder is enough. The installation is simple, and the addon has no required dependencies.
- This project owns the ported code. Fixes to ported code are made in this repository, because upstream changes do not flow in.
- The data tables are copied as they are. A refresh of the data from a newer Trailwright version is separate, later work.
- The GPL rules apply. Every copied source needs an entry in the credits file with its license, its version, and the date of the copy.
- The old plugin design is superseded. Its documents stay in the Git history and under the `pre-trailwright` tag.
