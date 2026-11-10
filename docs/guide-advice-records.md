# Guide advice records

The function `EfficientQuests.ExtractGuide(packageName, context)` reads the registered chapters of one package. It returns candidate advice in source order. Later steps use these candidates for relevance, lifecycle, and presentation. A candidate is not a verified gameplay fact. It is also not always a visible hint.

## Fields of a record

Each record has these fields: a stable source `id`, `package`, `sourceAuthor`, `chapter`, the selected `sourceText`, a shortened `text`, and `sourceOrder`. A record can also have a `kind`, which is `supply`, `flight`, or `technique`.

The fields `itemID` and `quantity` exist only when an item tag gives them. An item tag does not show a retention requirement. It also does not show independent consumption.

The field `itemSourceName` is the optional item label in the same tag. It is guide text. The provider did not verify it. The shopping list of TUG has IDs and names that do not agree. For example, the page 10 entry reuses the ID of page 1. Downstream code must not assume that the ID and the label of a tag name the same item. Before the code links or combines requirements, it must check the ID and the label against the facts of the provider. If the code cannot do this check, it must keep the uncertainty.

## Association

The field `association` is `zone`, `quest`, or `quests`.

- One explicit quest reference gives a `questID` and a `questIDs` list of one element.
- Many quest references give `questIDs` and no `questID`. The field `uncertain` stays true, because the prose does not show which part applies to which quest.
- No quest reference gives an empty list. The extraction does not invent an association.

A preposition can introduce a run of quest tags. The visible text then reads "for this quest" or "for these quests", and it keeps the punctuation around it. This way, removing the tags does not leave wording that points at nothing. The extraction keeps an ordinary use of the same preposition as it is.

The field `inferredQuestIDs` can appear on a standalone technique. It records a possible link between the technique and the quest references in the next sentence of the source. These IDs are not confirmed associations. The record stays a zone tip, has no `questID`, and is marked uncertain. A consumer must not present this inference as a fact of the guide or of the provider.

## Location and conditions

The field `location` can have these values: `x`, `y`, `zone`, `coordinateSystem = "guide-percent"`, `zoneSource = "guide-name"`, and an `inherited` flag. Do not compare its zone name and its coordinates (0 to 100) directly with a numeric client map ID or with a position (0 to 1) of the client. First use a reliable mapping. The field `conditions` lists restrictions that the extraction does not support or did not observe. The field `uncertain` marks candidates that need a qualification.

## Tags before the prose

A tag that comes before the prose of a step is a position marker. Its coordinate zone and its bare item count do not appear in `text`. An item tag still gives `itemID` and `quantity`.

A tag that names a flight point identifies travel advice. If the prose of the step does not name the point, `text` names it.

A bare objective directive can carry exactly one identified item quantity. It then becomes `supply` advice that states this requirement. The extraction marks it uncertain and adds the condition `requirement from an objective directive`. The extraction withholds directives that do not have this shape.

Retention wording must have an object. A fortress name in the prose, or a point name in a tag, does not satisfy this rule.

## Learning state

The field `learningState` holds the learning markers of the guide. Each marker has the form `{kind, id or name, rank, suffix, known}`. The field `known` exists only when a positive or negative observation supports it. A marker describes the learning target of the guide step. It does not show that a linked quest is complete. The context can supply `isSpellKnown(id)` and `skillRanks` for observations. If an observation is not available, the value stays unknown.

## Withheld prose

The extraction withholds some ambiguous prose on purpose. Its screening of narrative text is a heuristic. It does not show that any source material is free of spoilers. To extend the coverage, use reviewed examples and tests. If the extraction cannot resolve an association, a condition, or a location, it must keep the uncertainty.

The script `tools/audit_extraction.lua` runs the extraction over installed packages. It reports safety findings and withheld candidates. The file `docs/tug-extraction-audit.md` records the results for the reviewed corpus and the known categories of withheld prose.
