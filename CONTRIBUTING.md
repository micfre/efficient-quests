# Contributing

Discuss substantial changes in an issue before implementation. For pull requests, describe the player-facing change and how you tested it. Include the Forever client build for any in-game checks.

## Run the tests

The [test guide](tests/README.md) explains the offline commands. Two Lua suites load the addon headless, with substituted game services. Luacheck checks the addon code for accidental global variables. Run all three commands from the repository root before you send a pull request:

```sh
lua5.1 tests/runtime.lua
lua5.1 tests/manifest.lua
luacheck dist/EfficientQuests
```

If your machine has no Lua 5.1 interpreter and no luacheck, run the same commands in Docker:

```sh
docker run --rm -v "$PWD:/w" -w /w nickblah/lua:5.1 lua tests/runtime.lua
docker run --rm -v "$PWD:/w" -w /w nickblah/lua:5.1 lua tests/manifest.lua
docker run --rm -v "$PWD:/w" -w /w pipelinecomponents/luacheck luacheck dist/EfficientQuests
```

The CI workflow runs the same Docker commands.

## Copied work

This project is GPL-3.0-or-later. See [LICENSE](LICENSE). Do not copy reference code, assets, or data into this project unless two things are true: the source has a license that works with the GPL, and the copy gets an entry in [THIRD_PARTY.md](THIRD_PARTY.md). Record the source, the license, the version, and the date of the copy. The local `prior_art/` directory holds third-party reference material. Git does not track it.

## Documents

The readme and the installation guide are short stubs until the documentation rewrite. The plan for the standalone addon is in the [standalone specification](docs/specs/efficient-quests-standalone.md).
