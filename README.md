# Efficient Quests

Efficient Quests is a step-by-step leveling guide for World of Warcraft: Forever. It is one standalone addon. You install one folder, and it works.

The addon has a built-in quest engine. The engine is a port of the engine of the Trailwright addon, which is free software. Trailwright itself is not needed and is never installed.

The addon ships two guides:

- The leveling guide shows one step at a time from the Path. The Path is the fixed order of quests from level 1 to level 60.
- The dungeon guide shows the stops of a dungeon in order. A stop is one item in a dungeon guide, such as a boss, a rare enemy, a quest spot, or an event. The guide starts by itself when you enter a dungeon that the addon knows.

Both guides show text. The addon does not draw on the map or the minimap.

## Install

Copy the folder `dist/EfficientQuests` from this repository into the `Interface/AddOns` folder of your Forever client. The [installation guide](docs/installation.md) gives the exact path. There are no plugins and no extra downloads.

## The optional addons

The addon has no required dependencies. Three other addons are optional:

- FlareUI gives the window its look. The window copies the backdrop, the colors, and the fonts of the FlareUI tracker and docks below it. Without FlareUI, the window has a flat look, and you can drag it.
- TomTom points the way. The addon sets one TomTom waypoint on the place of the current step when it knows the coordinates. Without TomTom, the step shows its text only.
- QuestieDB adds data. The addon asks QuestieDB for the name or the coordinates of a quest or an NPC that its own data lacks. Without QuestieDB, the addon works on its own data.

## Forever only

The addon runs on the Forever client only. The manifest declares interface number 16001 and version 0.3.0. On any other client, the addon prints one message: "Efficient Quests supports the Forever client only and will not run here."

## How to use

Type `/eq` or `/efficientquests`:

- A bare command shows or hides the step window.
- `/eq options` opens the options panel. The word `config` works the same.
- `/eq status` prints the version, the data snapshot, and one word per optional addon: found or missing.
- `/eq help` lists the commands.

The step window shows the headline of the step, the goal lines with their tick boxes and counts, the tips, and the place text. The window also lists the next steps. The Back and Next buttons page through the route, and the line "Step 3 / 15" says your place in it.

A "Follow" tick in the title bar turns on Follow mode. Follow mode is the mode in which the window shows the step of the quest that you pick in the quest log.

Right-click a step to skip its quest. The menu button in the title bar opens the menu. The menu lists your skipped quests with a restore action, the known dungeons, and a link to the options.

## License

The project is GPL-3.0-or-later. See [LICENSE](LICENSE). The file [THIRD_PARTY.md](THIRD_PARTY.md) records every source of copied code and data, with its license, its version, and the date of the copy.

## Documents

- [Installation guide](docs/installation.md)
- [Validation record](docs/validation.md)
- [Contributing guide](CONTRIBUTING.md)
- [Glossary](GLOSSARY.md)
- [Standalone specification](docs/specs/efficient-quests-standalone.md)
- [Offline test guide](tests/README.md)
