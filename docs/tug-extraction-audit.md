# TUG extraction audit

This audit checks a locally installed guide package against the extraction of the addon. It does not show that every guide sentence is safe. It does not show that arbitrary guides are supported. It does not show that the addon works in the game client. Keep installed packages in their local installation. Do not commit their files or their prose.

## Offline corpus audit

The script `tools/audit_extraction.lua` registers every guide that the TOC of a package lists. It runs `EfficientQuests.ExtractGuide` over each guide for ten character contexts. The contexts cover both factions, several classes, and several profession states. The script reports two kinds of result:

- Safety findings. These are route-relative phrases, phrases that the narrative screen catches, text that is dangling or malformed, tags that the extraction did not strip, and quantities, item names, or quest links that are lost from the visible text.
- Coverage counts. These are the records by kind and by association, the counts for each context, and the candidate lines that produced no advice.

The script only reads the installed packages. It prints excerpts for local review only. To run it, use this command:

```sh
lua5.1 tools/audit_extraction.lua /path/to/GuideLime_TUGs_Forever [/path/to/Guidelime_Bethink]
```

These are the results at the reviewed corpus state (TUG package version 1.28, Bethink package version 1.0.5):

- TUG has 80 files and 6748 lines. It produced 903 advice records across all contexts: 253 flight, 557 supply, 28 technique, and 65 unclassified. It had zero safety findings. The extraction withheld 23 of 127 candidate lines.
- Bethink has 63 files and 8590 lines. It produced 2144 advice records: 275 flight, 68 supply, 673 technique, and 1128 unclassified. It had zero safety findings. The extraction withheld 362 of 828 candidate lines. It also had two informational watch entries for the phrase "revealed" used in a mechanical sense (parasites that a quest item reveals). We reviewed them and accepted them as not narrative.

The audit led to these fixes in the extraction. Synthetic behavioral tests in `tests/guide.lua` cover each fix.

- A list of quest tags, such as "... for [QC1], [QC2] and [QC3]", now resolves to "for this quest" or "for these quests". Before the fix, it left dangling punctuation such as "for , and .".
- A coordinate tag or a bare item tag before the prose of a step is now a position marker. It no longer leaks zone names or bare counts into the hint text.
- The extraction now recognizes the wording for a gryphon point, a wind rider point, and a flight point as travel advice. The named flight point tag names the advice.
- A retention "keep" must now take an object. A fortress name such as "Nethergarde Keep" no longer satisfies the trigger and no longer displaces the real advice of a line.
- A bare objective directive that carries exactly one identified item quantity ("Do: [QC...][CI...]") now keeps its requirement as uncertain supply advice.

## Withheld material that needs more review

The remaining withheld candidate lines fall into the categories below. The extraction takes nothing from these lines, so they cannot mislead. Each category is a known limit of coverage.

- Purchases of profession equipment and class equipment. Examples are skinning knives, mining picks, weapons, wands, and class training. We exclude them on purpose, because they are progression and not quest preparation. The extraction does take hunter ammunition and class-restricted vendor items that have a full item identity.
- Shopping pressure that depends on the route. Examples are "last chance", "more chances", and "put them on your bank for now". Also included are shopping paragraphs of several sentences, where the practical part depends on the timing of the route.
- Lines with several item tags and no quest reference. The extractor cannot say which quantity belongs to which purpose.
- Collections of objectives that restate a quest objective. Examples are "Kill boars to get: [CI...]" and dungeon lines such as "collect twenty X during the clear". These are route directives, not preparation. The extraction keeps a single-item quantity that explicit quest tags tie to the quest (see above). It withholds collections that have no such tie.
- Watches for rare spawns and other opportunities ("keep an eye out for ...") and instructions to form a group ("start looking for a group").
- Prose about quest-log management ("accept X; keep it for the next zone"). Its pronouns cannot stand alone. Its item also cannot be resolved without reward data from the provider.
- Phrasings that nobody reviewed. The extraction can still miss them or lose their context. The narrative screen is a conservative heuristic. A quest tag next to a line is a tentative inference. It is not a confirmed association.

## Manual review method

1. Run the Lua suites that `tests/README.md` lists. They cover the reviewed examples as synthetic behavioral regression tests.
2. Run the corpus audit above. Inspect every finding. Also inspect a sample of each kind and each association, for matching and non-matching faction and class contexts.
3. For each new package version, repeat the audit and compare the list of withheld lines. When you find a concrete error, add a short synthetic regression test. Never commit the prose of the guide.
4. Verify the real game behavior separately, with the exact Forever build. The audit does not load a client.

## Known examples that need more review

- `TUGs/Leveling ShoppingList.lua` contains the compact tag `[CI2592,300Wool Cloth]`. It also has page identifiers that do not match: page 10 reuses ID 2725, which page 1 also uses. The extractor keeps the source name of the tag. The provider must still validate the pair of ID and name.
- `TUGs/Horde/41-43 Part.lua` contains an ordered shopping instruction that spans two sentences. The extraction keeps its wording for this one reviewed pattern. It does not infer the meaning of the numbered item references.
- `TUGs/Alliance/24-25 Duskwood.lua` contains a conditional shopping list that splits after the Bronze Tube. The reviewed wording now keeps the six Spider Legs and the eight Murloc Fin together under the same condition.
- `TUGs/Alliance/6-11 Teldrassil.lua` states a requirement of seven Small Spider Leg in bare objective directives. The extraction now keeps the requirement as uncertain supply advice. It does not adopt the directive.
- `TUGs/Alliance/6-9 Elwynn Forest.lua` contains a vendor line with a duplicated purchase sentence. The wording is redundant, but it keeps the quantity. We have not implemented removal of the duplicate, which is only cosmetic.
- `Guidelime_Bethink/guides/A-42-44_Badlands.lua` pairs a flight point with riding directions. The sentence about the flight point is now the advice. The extraction withholds the riding directions.
