# Adapting the TUG Forever guide

Install Efficient Quests and TUG's Forever guide in the game's AddOns directory. With Python 3.9 or later installed, run:

```sh
python3 tools/adapt_guide.py adapt /path/to/AddOns/GuideLime_TUGs_Forever
python3 tools/adapt_guide.py check /path/to/AddOns/GuideLime_TUGs_Forever
```

Run these commands with the game closed, then start or reload the game. The adapter updates the guide's local TOC and adds two registration shims and a checksum manifest. Guide prose and tags are not edited. Only files listed in the guide TOC are loaded. The guide requires Efficient Quests after adaptation. Guidelime remains optional and, when enabled, receives each registration once.

After updating the guide, run `check`. If it reports a missing or changed adaptation, run `adapt` again. The check also reports changes to listed guide files; this prompts a fresh check after an update rather than assuming it is compatible. The adaptation applies to this local installation, not the author's upstream package.

The tool supports the TUG Forever package named `GuideLime_TUGs_Forever`. It does not download guides. Actual loading and coexistence must also be verified in the target game client.
