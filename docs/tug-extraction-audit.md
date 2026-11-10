# TUG extraction audit

This audit checks a locally installed guide package against the addon's extraction. It does not establish that every guide sentence is safe, that arbitrary guides are supported, or that the addon works in the game client. Keep installed packages in their local installation; do not commit their files or prose.

## Offline corpus audit

`tools/audit_extraction.lua` registers every guide a package's TOC lists, runs `EfficientQuests.ExtractGuide` over it for ten character contexts (both factions, several classes and profession states), and reports:

- safety findings: route-relative phrases, the narrative screen's phrases, dangling or malformed text, unstripped tags, and lost quantities, item names, or quest links in the visible text;
- coverage counts: records by kind and association, per-context counts, and candidate lines that produced no advice.

Run it against the installed packages (read-only; it prints excerpts for local review only):

```sh
lua5.1 tools/audit_extraction.lua /path/to/GuideLime_TUGs_Forever [/path/to/Guidelime_Bethink]
```

Results at the reviewed corpus state (TUG package version 1.28, Bethink package version 1.0.5):

- TUG (80 files, 6748 lines): 903 advice records across all contexts (253 flight, 557 supply, 28 technique, 65 unclassified), zero safety findings, 23 of 127 candidate lines withheld.
- Bethink (63 files, 8590 lines): 1907 advice records (275 flight, 68 supply, 673 technique, 1128 unclassified), zero safety findings, 362 of 828 candidate lines withheld; two informational watch entries for the phrase "revealed" used mechanically (parasites revealed by a quest item), reviewed and accepted as non-narrative.

The audit drove these extraction fixes, each covered by synthetic behavioral tests in `tests/guide.lua`:

- quest-tag lists ("... for [QC1], [QC2] and [QC3]") resolve to "for this quest"/"for these quests" instead of dangling punctuation such as "for , and .";
- coordinate and bare-item tags placed before a step's prose are treated as position markers and no longer leak zone names or bare counts into hint text;
- gryphon point, wind rider point, and flight point phrasing is recognized as travel advice, with the named flight point tag naming the advice;
- a retention "keep" must take an object, so fortress names like "Nethergarde Keep" no longer satisfy the trigger and displace a line's real advice;
- a bare objective directive carrying exactly one identified item quantity ("Do: [QC...][CI...]") keeps its requirement as uncertain supply advice.

## Withheld material requiring continued review

The remaining withheld candidate lines fall into these categories; none is extracted, so none can mislead, but each is a known coverage limit:

- Profession and class equipment purchases (skinning knives, mining picks, weapons, wands, class training) — excluded by design as progression, not quest preparation. Hunter ammunition and class-restricted vendor items with full item identity are extracted.
- Route-relative shopping pressure ("last chance", "more chances", "put them on your bank for now") and multi-sentence shopping paragraphs whose practical part is bound to the route's timing.
- Ambiguous multiple item tags on one line without a quest reference; the extractor cannot state which quantity belongs to which purpose.
- Objective collections that restate a quest objective ("Kill boars to get: [CI...]" or dungeon "collect twenty X during the clear" lines), which are route directives rather than preparation. A single-item quantity tied to explicit quest tags is kept (see above); collections without that association stay withheld.
- Rare-spawn and opportunity watches ("keep an eye out for ...") and grouping instructions ("start looking for a group").
- Quest-log management prose ("accept X; keep it for the next zone") whose pronouns cannot stand alone and whose item cannot be resolved without provider reward data.
- Unreviewed phrasings may still be missed or lose context. The narrative screen is a conservative heuristic; an adjacent quest tag remains a tentative inference, not a confirmed association.

## Manual review method

1. Run the Lua suites in `tests/README.md`; they cover the reviewed examples as synthetic behavioral regressions.
2. Run the corpus audit above and inspect every finding and a sample of each kind and association for both matching and nonmatching faction/class contexts.
3. For each new package version, repeat and compare the withheld list. Add a short synthetic regression when a concrete error is found; never commit the guide's prose.
4. Verify actual game behavior separately using the exact Forever build; the audit does not load a client.

## Known examples requiring continued review

- `TUGs/Leveling ShoppingList.lua` contains compact `[CI2592,300Wool Cloth]` and mismatched page identifiers: page 10 reuses ID 2725, also used for page 1. The extractor retains the tag's source name, but provider validation of the ID/name pair remains necessary.
- `TUGs/Horde/41-43 Part.lua` contains an ordered shopping instruction spread across two sentences. Its wording is retained for this specific reviewed pattern, but the meaning of its numbered item references is not inferred.
- `TUGs/Alliance/24-25 Duskwood.lua` contains a conditional shopping list split after the Bronze Tube; the reviewed wording now retains its six Spider Legs and eight Murloc Fin together under the same condition.
- `TUGs/Alliance/6-11 Teldrassil.lua` states a seven Small Spider Leg requirement in bare objective directives; the requirement is now kept as uncertain supply advice without adopting the directive.
- `TUGs/Alliance/6-9 Elwynn Forest.lua` contains a vendor line with a duplicated purchase sentence; its wording is redundant but preserves the quantity. Cosmetic deduplication remains unimplemented.
- `Guidelime_Bethink/guides/A-42-44_Badlands.lua` pairs a flight point with riding directions; the flight point sentence is now the advice and the riding directions are withheld.
