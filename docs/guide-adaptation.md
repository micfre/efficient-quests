# Adapt the TUG Forever guide

The adaptation tool changes a local copy of the Forever guide from TUG. It changes the loading metadata of the guide and adds registration files. It does not change the prose or the tags of the guide. The guide loads only the files that its addon manifest lists. The addon manifest is the `.toc` file.

Before you start, install Efficient Quests and the TUG Forever guide. The [installation guide](installation.md) lists the steps and the requirements. Close the game before you run the tool.

1. Open a terminal in the root folder of the repository.
2. Replace the example path with the path to the installed guide folder, then run these commands:

   ```sh
   python3 tools/adapt_guide.py adapt "/path/to/Interface/AddOns/GuideLime_TUGs_Forever"
   python3 tools/adapt_guide.py check "/path/to/Interface/AddOns/GuideLime_TUGs_Forever"
   ```

The tool needs Python 3.9 or later. It supports only the package folder named `GuideLime_TUGs_Forever`. It does not download the guide. You can run `adapt` more than one time. If `check` reports a missing or changed adaptation, run `adapt` again.

After you update the guide, run `check` again. The command compares the loading files and the listed guide files with the recorded checksums. A checksum is a value that shows whether a file changed. If a file is different, run `adapt` and then run `check` again.

The adapted guide requires Efficient Quests. Guidelime is still optional. If Guidelime is enabled, the adapter also passes the guide registration to Guidelime. The offline tests did not verify loading or coexistence in the Forever client.
