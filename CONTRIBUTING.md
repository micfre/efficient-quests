# Contributing

The [MVP specification](docs/specs/efficient-quests-mvp.md) is the starting point for implementation. Changes should preserve player choice, clearly distinguish uncertain information, and support both same-faction and shared quests.

Discuss substantial changes in an issue before implementation. For pull requests, describe the player-facing change and how it was validated, including the Forever client build for any in-game checks.

The local `prior_art/` directory contains third-party reference material and is excluded from version control. Do not copy reference code, assets, or guide text into this project without checking the applicable permissions. QuestieDB and supported guides are intended to be installed separately.

The [test guide](tests/README.md) lists the offline test commands. The specification describes the addon-level test boundary and the separate in-client checks.
