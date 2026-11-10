# Install Efficient Quests

Efficient Quests is experimental. The offline tests use simulated game APIs. They do not show that the addon works in a Forever client. They also do not show that the addon matches FlareUI on screen.

## Before you start

An addon is a folder that adds features to the game interface. The `AddOns` folder is inside the `Interface` folder of the Forever installation. Use the `AddOns` folder of the Forever client, not the folder of another Warcraft client.

You need these items:

- The Efficient Quests addon. It is a zip file on the [releases page](https://github.com/micfre/efficient-quests/releases).
- One or more guide plugins. Each guide plugin is a zip file on the same releases page. A guide plugin is a small addon that holds the text of one guide.
- The Forever version of [QuestieDB](https://www.curseforge.com/wow/addons/questiedb/files/all).

You do not need Python or any other tool. You do not need Guidelime or Questie. FlareUI is optional.

The first release ships the guide from Bethink. The TUG guide is not on the releases page yet. Its author has not given distribution permission. The [buildbook](buildbook.md) explains how a maintainer builds guide plugins locally.

## Install

1. Close the game.
2. Install QuestieDB for Forever in the `Interface/AddOns` folder.
3. Download the Efficient Quests zip and the zip of each guide that you want, from the releases page.
4. Open each zip. Copy its folder into the same `AddOns` folder. For example, copy the `EfficientQuests` folder and the `EfficientQuests_Bethink` folder.
5. Start the game. In the addon list, enable Efficient Quests, QuestieDB, and each guide plugin.
6. Log in on a character. Type `/eq status` in chat. The command must report `Ready.`

Each guide must sit in the `AddOns` folder as its own folder. Do not put one guide folder inside another addon folder. The game loads addons only from folders directly inside `AddOns`.

## Choose a guide

To open the settings, type `/eq` in chat or select **Settings** in the hint window. In the Guide category, select one of the installed guides. The list shows the name, the author, and the number of chapters of each guide.

If exactly one guide is installed, the addon selects it for you. If several guides are installed and none is chosen, the panel asks you to pick one. Hints never mix several guides. Your choice is stored for each character.

To remove a guide, close the game and delete the folder of that guide from `AddOns`. If the deleted guide was the chosen one, the addon falls back to the same rule. The only remaining guide is selected, or the panel asks you to pick one. The status output names the change.

To update a guide, delete the old guide folder and copy the folder from the new zip into `AddOns`. The addon itself updates the same way. Your guide choice and your other settings survive both updates.

## Choose the display

In the Display category, select Standalone or FlareUI. You can change the width of the standalone window. You can also change the space below the FlareUI tracker. You can drag the standalone window to another position on the screen. When the FlareUI tracker is in use, the window follows the tracker. If FlareUI or its tracker is not available, the addon uses the standalone window and remembers your FlareUI choice.

The default view shows up to three hints. To see the source of a hint and more detail, select the hint. To see more hints, select **More**. To hide a hint for the current character, select **Dismiss**. To restore the hidden hints, open the Dismissed category and select **Restore dismissed hints**.

## Troubleshoot

Type `/eq status` in chat. The command reports the first setup problem that it finds. If the setup is complete, it reports `Ready.`

- If the status says that QuestieDB is missing, install and enable the Forever QuestieDB addon.
- If the status says that QuestieDB is incompatible, update or reinstall QuestieDB.
- If the status says that no guide plugin is registered, install one from the [releases page](https://github.com/micfre/efficient-quests/releases).
- If the status names a guide and says that it did not register, enable that guide plugin in the addon list. A disabled plugin does not register.
- If the status says that a guide registered without declaring the guide marker, reinstall that guide plugin from a current release. The plugin folder is damaged or comes from an unknown source.
- If the settings panel says that your chosen guide is no longer registered, the addon removed the choice. Choose another guide in the Guide category.

If no hint is relevant, the addon hides the hint body. The settings remain available through `/eq`. This is not a setup error. The status command reports `Ready.` in this case.

## Test the repository

The [test guide](../tests/README.md) lists the offline commands. It also explains the extraction audit. The extraction audit is a review aid. It reads a guide package and reports what the addon extracts and what it withholds. The [release validation record](validation.md) lists the required checks in the game client and records the offline coverage. When you do those checks, record the exact Forever build and the FlareUI version.
