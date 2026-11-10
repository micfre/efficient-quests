# TUG extraction audit

This audit checks examples from a locally installed TUG Forever package. It does not establish that every guide sentence is safe or that the addon works in the game client. Keep the guide in its local installation; do not commit its files.

1. Run `lua5.1 tests/guide.lua` from the repository root. These behavioral tests cover selected Alliance and Horde examples, item quantities, route pressure, conditions, a group escort, and a practical encounter warning.
2. Inspect the installed package's TOC and review only files it actually lists. Use `rg -n -i 'buy|keep|save|quest|flight.?path|use |next step|last chance' /path/to/GuideLime_TUGs_Forever/TUGs` to find candidates, then check each result against the TOC. This search is a review aid, not a complete inventory of practical advice or spoilers.
3. For each sample, register its chapter through `EfficientQuests_RegisterGuide`, supply representative character context, and inspect the output from `EfficientQuests.ExtractGuide`. Compare the original line and visible text: quantities, conditions, zone, attribution, and uncertainty must survive; unrelated route directions and story outcomes must not appear. Exercise both matching and nonmatching faction/class conditions. Add a short behavioral regression example when a concrete error is found.
4. Repeat for other classes, races, zones, and guide updates. Record the package version, exact source file and line, context, result, and whether the sample was emitted, withheld, or misrepresented. Review the expanded source excerpt as well as compact text. Verify actual game behavior separately using the exact Forever build.

Known examples requiring continued review:

- `TUGs/Leveling ShoppingList.lua` contains compact `[CI2592,300Wool Cloth]` and mismatched page identifiers: page 10 reuses ID 2725, also used for page 1. The extractor retains the tag's source name, but provider validation of the ID/name pair remains necessary.
- `TUGs/Horde/41-43 Part.lua` contains an ordered shopping instruction spread across two sentences. Its wording is retained for this specific reviewed pattern, but the meaning of its numbered item references is not inferred. Other multi-item or cross-sentence conditions may be withheld.
- `TUGs/Horde/22-24 Hillsbrad Foothills.lua` describes a quest-item encounter and a preparation precaution in separate sentences. The reviewed case remains a zone tip; no quest association is fabricated.
- `TUGs/Horde/36-39 Desolace.lua` and `TUGs/Horde/43-45 Part.lua` contain route-relative claims about shopping chances. These are withheld rather than presented as deadlines.
- The extractor uses conservative text patterns and a limited narrative screen. Unreviewed phrasing may still be missed, lose important context, or expose a story outcome. An adjacent quest tag is only a tentative inference, not a confirmed association.
