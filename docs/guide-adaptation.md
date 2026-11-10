# Adapt the TUG Forever guide

The adaptation tool changes a local copy of TUG's Forever guide. It changes the guide's loading metadata and adds registration files. It does not change the guide's prose or tags. The guide loads only the files listed in its addon manifest, which is the `.toc` file.

Install Efficient Quests and the TUG Forever guide first. The [installation guide](installation.md) lists the steps and requirements. Close the game before you run the tool.

From the repository root, replace the example path with the installed guide folder and run:

```sh
python3 tools/adapt_guide.py adapt "/path/to/Interface/AddOns/GuideLime_TUGs_Forever"
python3 tools/adapt_guide.py check "/path/to/Interface/AddOns/GuideLime_TUGs_Forever"
```

The tool requires Python 3.9 or later. It supports the package folder named `GuideLime_TUGs_Forever`. It does not download the guide. Run `adapt` again if `check` reports a missing or changed adaptation. You can run `adapt` more than once.

After you update the guide, run `check` again. It compares the loading files and listed guide files with the recorded checksums. A checksum is a value used to detect file changes. If a file differs, run `adapt` and then `check` again.

The adapted guide requires Efficient Quests. Guidelime remains optional. If Guidelime is enabled, the adapter also passes the guide registration to it. Actual loading and coexistence in the Forever client have not been verified by the offline tests.
