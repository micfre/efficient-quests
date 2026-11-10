# Independent supply requirements

Different quest IDs and item objectives do not show, by themselves, that the quests consume separate quantities of an item. The public objective structure of the supported QuestieDB records the identity of an item and an optional text or icon. It does not give a structured quantity. It also does not give a flag that says the item is consumed at hand-in. See the [normalization schema of QuestieDB](https://github.com/Questie/QuestieDB/blob/master/src/meta/normalize.lua) and its [public API](https://github.com/Questie/QuestieDB/blob/master/docs/api.md). If an item disappears from the quest log, this alone cannot reliably show which quest consumed it.

## Observed intended consumption

A drop in the inventory also does not show attribution. The items can be sold, mailed, or banked. The addon records an intended consumption only from coincident observations of one verified (quest, item) pair that the guide links. All of these conditions must hold:

- The quest is accepted, and its quest-log objectives are readable.
- An objective that is identified as an item objective reports more fulfilled items than in the previous quest-log observation. The objective is identified by `type` or `objectiveType` with the value `"item"` in the documented `QuestObjectiveInfo` shape.
- The carried count of the linked item fell between those same two observations.

The addon never records consumption in these cases: a sale without objective progress, progress without a fall in the carried count, a finished objective alone, or a disappearance from the log. If no earlier baseline observation exists, the addon makes no claim, and the advice stays conditional.

When a player accepts a quest again, the addon clears the earlier consumption observations of that quest. A repeatable quest then regains its supply requirement for the new run. When the addon records a consumption, it removes the requirement of that quest and recalculates every combined minimum. The turn-in path works the same way.

Limits: We verified the objective field values (the strings of `type` and `objectiveType`, and `numFulfilled`) against the documented Forever `QuestObjectiveInfo` shape in offline tests only. If the client reports a different marker for item objectives, the addon records no consumption. The supply advice then stays conditional, which is the safe direction. A player can move items to the bank while an item objective progresses in the same observation window. The addon can read this as consumption. The addon does not treat bank totals as carried counts. Nobody has observed this coincidence in a client.

## Consumptions that the guide states

The addon recognizes one narrow and explicit kind of guide statement. The statement says that the quest it references consumes a stated quantity. The addon combines such statements only when all of these conditions hold:

- The quests are accepted separately.
- The provider verified that the items are identical.
- The items have the same local source location.
- The statements have no unparsed conditions.

The combined advice stays conditional on the claim of the guide. It explains the stated quantity of each quest. If one quest has repeated equivalent requirements, the addon uses the largest stated minimum. After an observed turn-in or an observed consumption, the addon recalculates the remaining total. The addon does not promote an item tag or a generic objective to consumption evidence.

The supplied TUG TOC lists 80 guide files. A targeted search found no two distinct uses in those files that satisfy this explicit statement format. The shopping list gives 15 and 300 Silk Cloth with no quest links. A separate chapter mentions 60 silk for quest 7793. This does not show that those amounts are distinct consumptions. A Blacksmithing example refers to several Thorium requirements. Its file is not in the TOC of TUG, so the addon must not load it implicitly. For this reason, the supported guide can produce no combined requirements until a reliable and applicable source of evidence exists. The test examples that exercise the combining are synthetic.

## Flight-path observations

Flight-path observations follow the rule of positive evidence. The addon suppresses a reminder about a learned path only in this case: the path was explicitly acquired, and one of these items identifies it.

- The destination phrase of the sentence identifies the path.
- If the sentence names no destination, the guide location tag of the advice identifies the path. The tag must match exactly, and it must match one observed taxi node on the current map only.

A missing node or an unreachable node is not evidence of an unlearned path. A guide location name, or a place name that appears by chance, does not identify a taxi node by itself.

Taxi-node observations keep the raw state from the client. The states `Current` and `Reachable` are positive evidence of learning, and they are sticky. Once the addon observes a node as learned, it stays learned, because a player cannot unlearn a path. Only a state that the `Enum.FlightPathState` of the client names as unlearned counts as negative evidence. The names are `unlearned`, `notlearned`, and `undiscovered`, after the addon normalizes case and separators. In that case, the acquisition reminder states its directive without the hedge "(if you have not already learned it)". The state `Unreachable` is deliberately not negative evidence, because a learned node can also be unreachable from the current master. A node with no observation is unknown.

Limits: The addon matches the enum names by meaning. We did not verify them against a running Forever build. A build can express unlearned nodes with a different state name, or only through the gray map icon. Those observations then stay unknown until the matcher learns the name, which is the safe direction. The retail `FlightPathState` enum has no unlearned value. On such clients, no assertive wording ever appears.
