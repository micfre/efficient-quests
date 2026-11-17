# Install Efficient Quests

Efficient Quests is one addon folder. The repository ships the built addon at `dist/EfficientQuests`. The folder holds the code, the embedded libraries, the quest data, and the dungeon guide text. You download nothing else.

There are no plugins, no releases page, and no extra downloads. The addon does not need guide files or helper addons.

The dungeon guide text is written for the Classic versions of the dungeons. The Forever client can differ.

## Install the addon

1. Find the `Interface/AddOns` folder of your Forever client installation.
2. Copy the folder `dist/EfficientQuests` from this repository into that folder.
3. Make sure that the copied folder sits at `Interface/AddOns/EfficientQuests`. Keep the folder name `EfficientQuests`, because the game finds the addon by that name.
4. Start the game and turn on Efficient Quests in the addon list.
5. Log in on a character and type `/eq`.

To update the addon, replace the old folder with the new copy of `dist/EfficientQuests`.

## The optional addons

FlareUI, TomTom, and QuestieDB are optional. The addon works without them. Install each one the same way if you want it: copy its own folder into `Interface/AddOns`.

## Forever only

The addon runs on the Forever client only. On another client it prints one message and does not run. See the [readme](../README.md).
