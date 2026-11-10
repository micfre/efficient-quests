# Efficient Quests

Efficient Quests is an experimental addon for World of Warcraft: Forever. An addon adds features to the game interface.

The addon shows practical quest and travel tips. It does not choose your next quest. The first version targets Forever 1.60.1. It needs the QuestieDB addon, which you install separately. Guide plugins are separate addon folders that you download from the [releases page](https://github.com/micfre/efficient-quests/releases). FlareUI is optional. Guidelime and Questie are not needed.

The addon has offline tests. Nobody verified its behavior or appearance in the Forever client. It is not a validated release.

## Documents

- [Installation guide](docs/installation.md): how to install the addon, QuestieDB, and guide plugins from the releases page.
- [Maintainer buildbook](docs/buildbook.md): how a maintainer builds guide plugins and release zips, with the license gate.
- [MVP specification](docs/specs/efficient-quests-mvp.md): the intended behavior of the first version. Issue [#15](https://github.com/micfre/efficient-quests/issues/15) supersedes it. MVP means minimum viable product, the smallest version that is useful.
- [Release validation record](docs/validation.md): what the offline tests cover, and the in-client and visual checks that remain.
- [Local relevance notes](docs/local-relevance-evidence.md): how the addon ties advice to the location of the player.
- [Consumption notes](docs/consumption-evidence.md): supply requirements and flight-path observations.
- [Extraction audit](docs/tug-extraction-audit.md): the historical extraction review of the TUG and Bethink guide packages.
- [Contribution guide](CONTRIBUTING.md): how to run the tests.
