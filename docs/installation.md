# Install Efficient Quests

Efficient Quests is experimental. The offline tests use simulated game APIs. They do not show that the addon works in a Forever client. They also do not show that the addon matches FlareUI on screen.

## Before you start

An addon is a folder that adds features to the game interface. The `AddOns` folder is inside the `Interface` folder of the Forever installation. Use the `AddOns` folder of the Forever client, not the folder of another Warcraft client.

You need these items:

- The Efficient Quests repository. It contains the addon and the adaptation tool.
- The Forever version of [QuestieDB](https://www.curseforge.com/wow/addons/questiedb/files/all).
- The Forever version of [the TUG guide](https://www.curseforge.com/wow/addons/guidelime_tugs/files/all). Its folder is named `GuideLime_TUGs_Forever`.
- Python 3.9 or later, on the computer that holds the guide folder.

The adaptation tool changes the loading files of the installed guide. It does not download the guide. It does not change the prose of the guide. Questie, Guidelime, and FlareUI are optional.

## Install and adapt

1. Close the game.
2. Copy the `EfficientQuests` folder from the repository into the `Interface/AddOns` folder of Forever.
3. Install QuestieDB for Forever in the same `AddOns` folder.
4. Install the TUG Forever guide in the same `AddOns` folder.
5. Make sure that `EfficientQuests/EfficientQuests.toc` and `GuideLime_TUGs_Forever/GuideLime_TUGs_Forever.toc` are directly inside their addon folders.
6. Make a backup of the installed `GuideLime_TUGs_Forever` folder.
7. Open a terminal in the root folder of the Efficient Quests repository.
8. Replace the example path with the full path to the installed guide folder, then run these commands:

   ```sh
   python3 tools/adapt_guide.py adapt "/path/to/Interface/AddOns/GuideLime_TUGs_Forever"
   python3 tools/adapt_guide.py check "/path/to/Interface/AddOns/GuideLime_TUGs_Forever"
   ```

9. Start the game. In the addon list, enable Efficient Quests, QuestieDB, and the TUG guide.
10. Enter the game and type `/eq status` in chat. The command shows the setup status.

On Windows, use your Python 3 command in place of `python3` if necessary. If the path contains spaces, keep the quotes. When the local adaptation matches the recorded files, the second command reports `Guide adaptation is current.` That result does not show that the client is compatible.

The tool adds registration files and changes the loading metadata of the guide. The adapted guide depends on Efficient Quests. If Guidelime is enabled, the adapted guide also registers with Guidelime. The [adaptation guide](guide-adaptation.md) describes the update checks and the limits.

## Choose the display

To open the settings, type `/eq` in chat or select **Settings** in the hint window. In the Guide category, select the installed guide. Efficient Quests uses one guide package at a time.

In the Display category, select Standalone or FlareUI. You can change the width of the standalone window. You can also change the space below the FlareUI tracker. You can drag the standalone window to another position on the screen. When the FlareUI tracker is in use, the window follows the tracker. If FlareUI or its tracker is not available, the addon uses the standalone window and remembers your FlareUI choice.

The default view shows up to three hints. To see the source of a hint and more detail, select the hint. To see more hints, select **More**. To hide a hint for the current character, select **Dismiss**. To restore the hidden hints, open the Dismissed category and select **Restore dismissed hints**.

## Update or troubleshoot

After a guide update, close the game and run the `check` command from the install steps. If the command reports a missing or changed adaptation, run `adapt` and then run `check` again. A guide update can replace the local adaptation. The tool checks the recorded files. It does not check the gameplay claims of the guide.

If `/eq status` reports a missing provider, make sure that the Forever QuestieDB addon is installed and enabled. If it reports an incompatible provider, update or reinstall QuestieDB. If it reports that the guide is missing or did not register, make sure that the TUG guide is installed and enabled. If needed, run the adaptation commands again.

If no hint is relevant, the addon hides the hint body. The settings remain available through `/eq`. This is not a setup error.

## Test the repository

The [test guide](../tests/README.md) lists the offline commands. It also explains the extraction audit. The extraction audit is a review aid. It reads an installed guide package and reports what the addon extracts and what it withholds. The [release validation record](validation.md) lists the required checks in the game client and records the offline coverage. When you do those checks, record the exact Forever build and the FlareUI version.
