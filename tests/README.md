# Offline tests

Run these commands from the repository root. You need Lua 5.1 and luacheck. If your machine has neither, Docker can run the same commands. The commands use the interpreter name `lua5.1`. Use the name of your own Lua 5.1 interpreter if it differs.

```sh
lua5.1 tests/runtime.lua
lua5.1 tests/saveddata.lua
lua5.1 tests/queststate.lua
lua5.1 tests/characterstore.lua
lua5.1 tests/datastore.lua
lua5.1 tests/options.lua
lua5.1 tests/manifest.lua
luacheck dist/EfficientQuests
```

The Lua tests load the addon files and simulate the game services. Each suite loads the addon through the shared `tests/addon.lua` loader, which runs the files in the TOC's order, starting with the embedded libraries, and hands every file the same private namespace, the way the game does. Every suite remains individually runnable. The `runtime` suite covers the entry point: the addon table, the saved-data setup on login, and the one message that a player on another client flavor gets, because the addon supports the Forever client only. The `saveddata` suite covers the two saved tables: the defaults after a fresh login, the split between the account-wide table and the per-character table, and the promise that keys from the old plugin era are left alone instead of being migrated. The `queststate` suite covers the quest state reader: the level, the race, the class, and the faction of the player, the quest log with its objective counts, the completed quests, the player position through the embedded HereBeDragons, and the change callbacks that fire when a quest is accepted, progresses, completes, is handed in, or is abandoned, and when the player levels up. The `characterstore` suite covers the three stores of one character: the skip list with its skip and restore actions, the abandoned quests, and the Follow mode switch. It also checks that a quest taken again leaves the abandoned list, and that two characters keep their state apart. The `datastore` suite covers the copied Trailwright tables: the loader stays quiet when they are well formed, it reports exactly one clear message for a missing or a malformed table, the addon keeps running without the guides that need the broken table, and the data snapshot identity is there for the status command. The `options` suite covers the options panel: the window opens through `Options.Open`, shows the saved values for the waypoint toggle, the window lock, the scale, and the opacity, writes every change straight into the account-wide table, and registers itself neither with the client's options windows nor with FlareUI. The `manifest` suite reads the shipped manifest text and the files the manifest lists. It checks the interface number, the version, the optional dependencies, the saved variables, and the embedded libraries, the order of the data files and the data store, and it rejects the pins files and leftover mentions of removed addons.

Luacheck checks the addon code in `dist/EfficientQuests` for accidental global variables. The configuration is `.luacheckrc` at the repository root. It names the game services that the addon can use as globals. A global that the list does not name fails the check. The embedded libraries under `dist/EfficientQuests/Libs` and the generated data tables (`QuestData.lua`, `PathData.lua`, `DungeonGuides.lua`) are verbatim copies of third-party code and data, so luacheck skips them.

The Docker commands:

```sh
docker run --rm -v "$PWD:/w" -w /w nickblah/lua:5.1 lua tests/runtime.lua
docker run --rm -v "$PWD:/w" -w /w nickblah/lua:5.1 lua tests/saveddata.lua
docker run --rm -v "$PWD:/w" -w /w nickblah/lua:5.1 lua tests/queststate.lua
docker run --rm -v "$PWD:/w" -w /w nickblah/lua:5.1 lua tests/characterstore.lua
docker run --rm -v "$PWD:/w" -w /w nickblah/lua:5.1 lua tests/datastore.lua
docker run --rm -v "$PWD:/w" -w /w nickblah/lua:5.1 lua tests/options.lua
docker run --rm -v "$PWD:/w" -w /w nickblah/lua:5.1 lua tests/manifest.lua
docker run --rm -v "$PWD:/w" -w /w pipelinecomponents/luacheck luacheck dist/EfficientQuests
```

The CI workflow runs the same Docker commands.

These tests run without the game. They do not show that the addon works in a Forever client, and they do not show how the window looks. The [validation record](../docs/validation.md) tracks the in-client and visual checks.
