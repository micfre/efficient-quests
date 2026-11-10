# Independent supply requirements

Different quest IDs and item objectives do not, by themselves, prove that separate quantities of an item are consumed. The supported QuestieDB public objective structure records item identity and optional text/icon; it does not supply a structured quantity or a consumed-at-hand-in flag. See [QuestieDB's normalization schema](https://github.com/Questie/QuestieDB/blob/master/src/meta/normalize.lua) and its [public API](https://github.com/Questie/QuestieDB/blob/master/docs/api.md). A quest-log disappearance alone cannot reliably attribute consumption to a particular quest.

## Observed intended consumption

An inventory decrease by itself is likewise not attribution: the items may have been sold, mailed, or banked. The addon records an intended consumption only from **coincident observations** of one verified, guide-linked (quest, item) pair:

- the quest is accepted and its quest-log objectives are readable, and
- an objective identified as an item objective (`type`/`objectiveType` `"item"` in the documented `QuestObjectiveInfo` shape) reports more fulfilled items than in the previous quest-log observation, while
- the carried count of the linked item fell between those same two observations.

A sale without objective progress, progress without a fall in carried count, a finished objective alone, or a disappearance from the log never records consumption. Without an earlier baseline observation the addon makes no claim, and the advice stays conditional. Accepting a quest again clears that quest's earlier consumption observations, so a repeatable quest's fresh run regains its supply requirement. A recorded consumption removes that quest's requirement and recalculates any combined minimum, mirroring the turn-in path.

Limits: the objective field values (`type`/`objectiveType` strings, `numFulfilled`) were verified against the documented Forever `QuestObjectiveInfo` shape in offline tests only. If the client reports a different marker for item objectives, no consumption is recorded and supply advice simply remains conditional, which is the safe direction. Moving items to the bank while an item objective progresses in the same observation window could be misread as consumption; the addon does not treat bank totals as carried counts, and this coincidence has not been observed in a client.

## Guide-stated independent consumptions

The addon recognizes a deliberately narrow, explicit guide assertion that a stated quantity is consumed by its referenced quest. It combines such assertions only for separately accepted quests, provider-verified identical items and the same local source location, without unparsed conditions. The combined advice remains conditional on the guide's claim and explains each quest's stated quantity. Repeated equivalent requirements for one quest use the largest stated minimum, and an observed turn-in or observed consumption causes the remaining total to be recalculated. An item tag or a generic objective is not promoted into consumption evidence.

The supplied TUG TOC lists 80 guide files. A targeted search found no two distinct uses in those files that satisfy this explicit assertion format. Its shopping list gives 15 and 300 Silk Cloth without quest links, while a separate chapter mentions 60 silk for quest 7793; this does not establish that those amounts are distinct consumptions. A Blacksmithing example refers to several Thorium requirements, but its file is not listed in TUG's TOC and must not be loaded implicitly. The supported guide may therefore produce no aggregated requirements until a reliable, applicable evidence source is available. The test examples that exercise aggregation are synthetic.

## Flight-path observations

Flight-path observations follow the same positive-evidence rule. A learned-path reminder is suppressed only for an explicitly acquired path that is identified by either the sentence's destination phrase or — when the sentence names no destination — the advice's own guide location tag, matched exactly and uniquely against an observed taxi node on the current map. Missing or unreachable nodes are not evidence of an unlearned path. A guide location name or an incidental place name does not by itself identify a taxi node.
