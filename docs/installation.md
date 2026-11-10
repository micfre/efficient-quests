# Install Efficient Quests

Efficient Quests is experimental. The offline tests use simulated game APIs. They do not establish that the addon works in a Forever client or matches FlareUI on screen.

## Before you start

An addon is a folder that adds features to the game interface. The `AddOns` folder is inside the Forever installation's `Interface` folder. Use the `AddOns` folder for the Forever client, not another Warcraft client.

You need these items:

- The Efficient Quests repository, which contains the addon and adaptation tool.
- The Forever version of [QuestieDB](https://www.curseforge.com/wow/addons/questiedb/files/all).
- The Forever version of [TUG's guide](https://www.curseforge.com/wow/addons/guidelime_tugs/files/all), named `GuideLime_TUGs_Forever`.
- Python 3.9 or later on the computer that holds the guide folder.

The adaptation tool changes the installed guide's loading files. It does not download the guide or change its prose. Questie, Guidelime, and FlareUI are optional.

## Install and adapt

1. Close the game.
2. Copy the repository's `EfficientQuests` folder into the Forever `Interface/AddOns` folder.
3. Install QuestieDB for Forever in the same `AddOns` folder.
4. Install TUG's Forever guide in the same `AddOns` folder.
5. Make sure that `EfficientQuests/EfficientQuests.toc` and `GuideLime_TUGs_Forever/GuideLime_TUGs_Forever.toc` are directly inside their addon folders.
6. Back up the installed `GuideLime_TUGs_Forever` folder.
7. Open a terminal in the Efficient Quests repository root.
8. Replace the example path with the full path to the installed guide folder, then run:

   ```sh
   python3 tools/adapt_guide.py adapt "/path/to/Interface/AddOns/GuideLime_TUGs_Forever"
   python3 tools/adapt_guide.py check "/path/to/Interface/AddOns/GuideLime_TUGs_Forever"
   ```

9. Start the game and enable Efficient Quests, QuestieDB, and the TUG guide in the addon list.
10. Enter the game and type `/eq status` in chat to see the setup status.

On Windows, use your Python 3 command in place of `python3` if necessary. Keep the quotes if the path contains spaces. The second command reports `Guide adaptation is current.` when the local adaptation matches the recorded files. That result does not establish client compatibility.

The tool adds registration files and changes the guide's loading metadata. The adapted guide depends on Efficient Quests. If Guidelime is enabled, the adapted guide also registers with Guidelime. The [adaptation guide](guide-adaptation.md) describes update checks and limits.

## Choose the display

Type `/eq` in chat or select **Settings** in the hint window. In the Guide category, select the installed guide. Efficient Quests uses one guide package at a time.

In the Display category, select Standalone or FlareUI. You can change the standalone window width and the space below the FlareUI tracker. If FlareUI or its tracker is unavailable, the addon uses the standalone window and remembers the FlareUI choice.

The default view shows up to three hints. Select a hint for its source and more detail. Select **More** to see additional hints. Select **Dismiss** to hide a hint for the current character. In the Dismissed category, select **Restore dismissed hints** to restore them.

## Update or troubleshoot

After a guide update, close the game and run the `check` command above. If the command reports a missing or changed adaptation, run `adapt` and then `check` again. A guide update can replace the local adaptation. The tool checks the recorded files, not the guide's gameplay claims.

If `/eq status` reports a missing provider, make sure that the Forever QuestieDB addon is installed and enabled. If it reports an incompatible provider, update or reinstall QuestieDB. If the guide is missing or did not register, make sure that the TUG guide is installed and enabled. Run the adaptation commands again if needed.

If there are no relevant hints, the hint body is hidden. Settings remain available through `/eq`. This is different from a setup error.

## Test the repository

The [test guide](../tests/README.md) lists the offline commands. The [MVP specification](specs/efficient-quests-mvp.md) lists the required checks in the game client. Record the exact Forever build and the FlareUI version when you perform those checks.
