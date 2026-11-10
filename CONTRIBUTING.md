# Contributing

The work is planned in [issue #15](https://github.com/micfre/efficient-quests/issues/15): guide plugins built offline by maintainers replaced the old in-place adaptation flow. The [MVP specification](docs/specs/efficient-quests-mvp.md) is the superseded background for the first version. Changes must preserve player choice, clearly distinguish uncertain information, and support both same-faction and shared quests.

Discuss substantial changes in an issue before implementation. For pull requests, describe the player-facing change and how it was validated, including the Forever client build for any in-game checks.

The [test guide](tests/README.md) lists the offline commands: six Lua suites, the bridge suite, and the Python suites for the builder and the release tool. The tests use three seams. The builder and the release tool run as commands over synthetic fixture packages. The Lua suites load the addon headless, with substituted game services. The bridge suite builds a fixture guide with the real builder and loads the generated plugin next to the real core addon. Run the full set before you send a pull request. The CI workflow runs the same set, plus a release dry-run that proves the license gate. See the [maintainer buildbook](docs/buildbook.md) for the build and release process.

The local `prior_art/` directory contains third-party reference material and is excluded from version control. Do not copy reference code, assets, or guide text into this project without checking the applicable permissions. Use the synthetic fixtures in `tests/fixtures/` instead. QuestieDB and supported guides are installed separately.
