# Contributing

Discuss substantial changes in an issue before you write code. The project tracks issues in GitHub Issues for `micfre/efficient-quests`. For pull requests, describe the player-facing change and how you tested it.

## Run the offline tests

The repository has seventeen offline Lua suites and one luacheck run. The suites load the addon headless, with the game services replaced by simulations. Luacheck checks the addon code for accidental global variables.

Run every command from the repository root before you send a pull request. The commands use the interpreter name `lua5.1`. Use the name of your own Lua 5.1 interpreter if it differs:

```sh
lua5.1 tests/runtime.lua
lua5.1 tests/saveddata.lua
lua5.1 tests/queststate.lua
lua5.1 tests/characterstore.lua
lua5.1 tests/datastore.lua
lua5.1 tests/routeplanner.lua
lua5.1 tests/stepmodel.lua
lua5.1 tests/followmode.lua
lua5.1 tests/questiefallback.lua
lua5.1 tests/options.lua
lua5.1 tests/menu.lua
lua5.1 tests/stepwindow.lua
lua5.1 tests/lookadapter.lua
lua5.1 tests/tomtombridge.lua
lua5.1 tests/dungeonguide.lua
lua5.1 tests/commands.lua
lua5.1 tests/manifest.lua
luacheck dist/EfficientQuests
```

If your machine has no Lua 5.1 interpreter and no luacheck, run the same work in Docker. The CI workflow runs these Docker commands on every push and pull request:

```sh
for suite in runtime saveddata queststate characterstore datastore routeplanner stepmodel followmode questiefallback options menu stepwindow lookadapter tomtombridge dungeonguide commands manifest; do
  docker run --rm -v "$PWD:/w" -w /w nickblah/lua:5.1 lua "tests/$suite.lua"
done
docker run --rm -v "$PWD:/w" -w /w pipelinecomponents/luacheck luacheck dist/EfficientQuests
```

The [test guide](tests/README.md) explains what each suite covers.

## Copied work

This project is GPL-3.0-or-later. See [LICENSE](LICENSE). Copy reference code, assets, or data into this project only when two things are true. The source must have a license that works with the GPL. The copy must get an entry in [THIRD_PARTY.md](THIRD_PARTY.md). Record the source, the license, the version, and the date of the copy.

The local `prior_art/` directory holds third-party reference material. Git does not track it.

## Write documents in plain English

Write every Markdown file in `docs/`, and the readme and this file, in plain English: short sentences, active voice, and one idea per sentence. The rule lives in [AGENTS.md](AGENTS.md). Use the `simple-english` skill for this work.
