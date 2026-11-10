# Local relevance and location evidence

Advice is ranked only after some evidence ties it to where the player currently is. That evidence has three strengths, and the weaker ones are never presented as confirmed local utility:

1. **Confirmed advice zone.** The guide names a zone for the advice and the client's own map hierarchy (`C_Map.GetMapInfo`/`GetMapChildrenInfo`) identifies that name with the player's current map or one of its ancestors or descendants. A name that matches a separate zone-level map is remote and the advice is excluded. A name the hierarchy cannot resolve (for example an unmapped subzone, or when the hierarchy API is unavailable) stays uncertain: the advice may remain visible with an uncertainty marker and ranks last, but is never called local.
2. **Quest-activity support.** Advice with no location of its own can be supported by current-phase quest activity on the player's map: a client quest marker for an unaccepted start or an unfinished objective, or — for quests ready to hand in — a provider turn-in location (below). This is a distinct, weaker tier: it always carries a visible condition ("Quest activity is local; the advice location is not confirmed." or "The quest turn-in is in this zone; the advice location is not confirmed.").
3. **No local evidence.** Unlocated advice with no supporting quest activity is withheld from the compact view rather than guessed to be local.

The tiers never override the specification's fixed ranking precedence ("native focused quest, accepted quest, distance to relevant quest giver/start, distance to relevant quest target, and proximity to the player's level or applicable level range"). Focus and acceptance win outright; the tiers order candidates that are **equal at a location priority** — at the same distance signal (including both unknown), a confirmed advice zone beats quest-activity support, which beats unresolved locality.

## Location frames

Three coordinate frames exist and are never interchanged:

- Guide coordinates are percentages inside a guide-named zone.
- Client positions and quest POIs are percentages of a UiMapID, converted to yards with `C_Map.GetMapWorldSize` for distance banding (250-yard bands).
- QuestieDB spawn coordinates are percentages keyed by **AreaID**, a different frame from UiMapIDs.

The provider's ZoneDB support data (`LibQuestieDB.Support.Get("ZoneDB").private.areaIdToUiMapId`, with its override, both shipped as Lua source strings) bridges AreaIDs to UiMapIDs. A provider spawn is compared to the player only when the bridge lands it exactly on the player's current map, so the mapping is never used as a map allowlist: QuestieDB's Forever map data retains some entries only for consumer instance-routing compatibility, and the player's current map always exists by definition. When the bridge is unavailable, provider distances simply stay unknown.

## Ready-for-turn-in signals

Quest phase comes from the client's phase-specific signal first: `C_QuestLog.ReadyForTurnIn` when it answers, with `C_QuestLog.IsComplete` only as a fallback, and unknown when neither answers. The Forever `QuestPOIMapInfo` shape (`questID`, `mapID`, `x`, `y`, `isQuestStart`, `inProgress`, `numObjectives`) was checked against the Forever UI API documentation; it carries no turn-in-specific flag, and `C_QuestLog.GetNextWaypoint` cannot distinguish an objective waypoint from a turn-in waypoint. Client POIs are therefore used only for unaccepted starts and active objectives, never for turn-ins.

Turn-in proximity for a ready quest comes from QuestieDB: the quest's `finishedBy` NPC or game-object finishers, their `spawns`, and the AreaID bridge above. It occupies the giver/start priority slot because it is the quest's relevant giver for the current phase. Finisher spawns in any other zone produce no distance rather than an inflated or fabricated one.

## Opportunity timing

The available-now tie break (after the five priorities) recognizes only a direct, unqualified acquisition instruction ending in "now" — `buy`, `get` or `stock up on` — as a single clause, with no `if`/`unless` qualifier, and never reads "for now" as availability. Timing is read from the guide's original wording, not from rewritten supply text, and requires confirmed local advice. In the supported TUG guide, occurrences such as "Buy at the auction house now," and "Get all pages out now," continue past their clause and stay excluded; "for now" occurrences are temporal scope, not availability. All other prose has unknown timing and ties are broken by stable source order.

## Limits

Offline tests are synthetic. The following are **not verified here** and remain for the in-client checks the specification lists: actual Forever map hierarchy and area names, `GetQuestsOnMap`/`ReadyForTurnIn` behavior on a real build, `GetMapWorldSize` values used for banding, and the placement accuracy of QuestieDB's Forever spawn conversions (its own data is already converted to Forever frames; the `EraToForever` helpers apply only to consumer-owned Era points and are never applied to provider reads). Movement stability is handled by 250-yard bands plus a 25-yard refresh threshold in the interface; real polling behavior needs a client.
