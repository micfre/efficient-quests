# Install Efficient Quests

Efficient Quests is experimental. The offline tests use simulated game APIs. They do not show that the addon works in a Forever client. They also do not show that the addon matches FlareUI on screen.

## Before you start

An addon is a folder that adds features to the game interface. The `AddOns` folder is inside the `Interface` folder of the Forever installation. Use the `AddOns` folder of the Forever client, not the folder of another Warcraft client.

You need these items:

- The Efficient Quests repository. It contains the addon and the guide plugin builder.
- The Forever version of [QuestieDB](https://www.curseforge.com/wow/addons/questiedb/files/all).
- A source guide package that the catalog lists. The catalog is the file `tools/catalog.json`. The first packages are [the TUG guide](https://www.curseforge.com/wow/addons/guidelime_tugs/files/all) and the Bethink guide. Their folders are named `GuideLime_TUGs_Forever` and `Guidelime_Bethink`.
- Python 3.9 or later, on the computer that holds the source guide package.

The builder reads a source guide package and writes a guide plugin folder. A guide plugin is a separate addon that holds the guide text. The builder does not download the guide. It does not change the source package. It copies the guide text without changes. You do not install Guidelime for this addon.

## Install and build

1. Close the game.
2. Copy the `EfficientQuests` folder from the repository into the `Interface/AddOns` folder of Forever.
3. Install QuestieDB for Forever in the same `AddOns` folder.
4. Open a terminal in the root folder of the Efficient Quests repository.
5. Replace the example path with the full path to the source guide folder, then run this command:

   ```sh
   python3 tools/build_guide.py "/path/to/GuideLime_TUGs_Forever"
   ```

6. The command writes the plugin folder into the `dist` folder of the repository. For the TUG guide, the plugin folder is named `EfficientQuests_TUGsForever`. Copy that plugin folder into the same `AddOns` folder.
7. Start the game. In the addon list, enable Efficient Quests, QuestieDB, and the guide plugin.
8. Enter the game and type `/eq status` in chat. The command shows the setup status.

On Windows, use your Python 3 command in place of `python3` if necessary. If the path contains spaces, keep the quotes. The plugin folder depends on Efficient Quests. The plugin registers the guide text with Efficient Quests only.

The TUG guide has no distribution permission. Build it for your own computer only. Do not share or publish its plugin folder. The Bethink guide is GPLv3. The builder copies its license file into the plugin folder.

## Choose the display

To open the settings, type `/eq` in chat or select **Settings** in the hint window. In the Guide category, select the installed guide. Efficient Quests uses one guide package at a time.

In the Display category, select Standalone or FlareUI. You can change the width of the standalone window. You can also change the space below the FlareUI tracker. You can drag the standalone window to another position on the screen. When the FlareUI tracker is in use, the window follows the tracker. If FlareUI or its tracker is not available, the addon uses the standalone window and remembers your FlareUI choice.

The default view shows up to three hints. To see the source of a hint and more detail, select the hint. To see more hints, select **More**. To hide a hint for the current character, select **Dismiss**. To restore the hidden hints, open the Dismissed category and select **Restore dismissed hints**.

## Update or troubleshoot

After a guide update, run the build command again with the new source package. Then copy the new plugin folder into `AddOns` and replace the old plugin folder. The builder never changes the source package.

If `/eq status` reports a missing provider, make sure that the Forever QuestieDB addon is installed and enabled. If it reports an incompatible provider, update or reinstall QuestieDB. If it reports that the guide is missing or did not register, make sure that the guide plugin is installed and enabled. If needed, build the plugin again.

If no hint is relevant, the addon hides the hint body. The settings remain available through `/eq`. This is not a setup error.

## Test the repository

The [test guide](../tests/README.md) lists the offline commands. It also explains the extraction audit. The extraction audit is a review aid. It reads an installed guide package and reports what the addon extracts and what it withholds. The [release validation record](validation.md) lists the required checks in the game client and records the offline coverage. When you do those checks, record the exact Forever build and the FlareUI version.
