# Local relevance and location evidence

The addon ranks advice only after some evidence ties the advice to the current location of the player. The evidence has three strengths. The addon never presents the weaker strengths as confirmed local utility.

1. Confirmed advice zone. The guide names a zone for the advice. The map hierarchy of the client (`C_Map.GetMapInfo` and `GetMapChildrenInfo`) matches that name to the current map of the player, or to an ancestor or a descendant of that map. An exact match with the chapter title also confirms the zone. For example, the title `[N Elwynn Forest]` confirms the zone when the player stands in Elwynn Forest. A title that only contains the zone name, such as `[N 6-9 Elwynn Forest]`, is an inference about the setting of the chapter. It is not a confirmed source fact, and it stays unresolved. If the name matches a separate zone-level map, the zone is remote and the addon excludes the advice. If the hierarchy cannot resolve the name, the zone stays uncertain. This happens for an unmapped subzone, or when the hierarchy API is not available. The advice can then stay visible with an uncertainty marker, and it ranks last. The addon never calls it local.
2. Quest-activity support. Advice that has no location of its own can have support from the current quest activity on the map of the player. This support is one of these items: a client quest marker for an unaccepted start, a client quest marker for an unfinished objective, or, for a quest that is ready to hand in, a turn-in location from the provider (see below). This tier is separate and weaker. It always carries a visible condition. The condition reads "Quest activity is local; the advice location is not confirmed." or "The quest turn-in is in this zone; the advice location is not confirmed."
3. No local evidence. Advice that has no location and no supporting quest activity is withheld from the compact view. The addon does not guess that it is local.

The tiers never override the fixed ranking order of the specification. That order is: native focused quest, accepted quest, distance to the relevant quest giver or start, distance to the relevant quest target, and closeness to the level of the player or the applicable level range. Focus and acceptance always win. The tiers only order candidates that are equal at one location priority. At the same distance signal (including both unknown), a confirmed advice zone ranks above quest-activity support. Quest-activity support ranks above unresolved locality.

## Location frames

Three coordinate frames exist. The addon never interchanges them.

- Guide coordinates are percentages inside a zone that the guide names.
- Client positions and quest points of interest are percentages of a UiMapID. The addon converts them to yards with `C_Map.GetMapWorldSize` for the distance bands. Each band is 250 yards.
- QuestieDB spawn coordinates are percentages that use an AreaID as the key. An AreaID is a different frame from a UiMapID.

The ZoneDB support data of the provider connects AreaIDs to UiMapIDs. It is `LibQuestieDB.Support.Get("ZoneDB").private.areaIdToUiMapId`, together with its override. Both ship as Lua source strings. The addon compares a spawn of the provider with the player only when the connection places the spawn exactly on the current map of the player. The addon never uses the mapping as an allowlist of maps. The Forever map data of QuestieDB keeps some entries only for the instance routing of consumers. Also, the current map of the player always exists by definition. If the connection is not available, the distances of the provider stay unknown.

## Ready-for-turn-in signals

The addon reads the quest phase first from the phase-specific signal of the client. It uses `C_QuestLog.ReadyForTurnIn` when that function answers. It uses `C_QuestLog.IsComplete` only as a fallback. If neither function answers, the phase is unknown.

We checked the Forever shape of `QuestPOIMapInfo` against the Forever UI API documentation. The shape is `questID`, `mapID`, `x`, `y`, `isQuestStart`, `inProgress`, and `numObjectives`. It has no flag that is specific to turn-ins. The function `C_QuestLog.GetNextWaypoint` cannot tell an objective waypoint from a turn-in waypoint. So the addon uses client points of interest only for unaccepted starts and active objectives. It never uses them for turn-ins.

The turn-in distance for a ready quest comes from QuestieDB. It uses the NPCs or game objects in the `finishedBy` field of the quest, their `spawns`, and the AreaID connection above. This distance takes the priority slot of the giver or start, because the finisher is the relevant giver for the current phase. Finisher spawns in any other zone give no distance. The addon does not use an inflated or invented distance.

## Opportunity timing

The "available now" tie break comes after the five priorities. It accepts only one kind of text: a direct acquisition instruction that ends in "now". The verb must be `buy`, `get`, or `stock up on`. The instruction must be a single clause with no `if` or `unless` qualifier. The tie break never reads "for now" as availability. The addon reads timing from the original wording of the guide, not from rewritten supply text. It also requires confirmed local advice.

In the supported TUG guide, the sentences "Buy at the auction house now," and "Get all pages out now," continue past their clause. They stay excluded. The occurrences of "for now" give a temporal scope, not availability. All other prose has unknown timing. The stable source order breaks the remaining ties.

## Limits

The offline tests are synthetic. This document does not verify the items below. They remain for the in-client checks that the specification lists:

- The real map hierarchy and area names of Forever.
- The behavior of `GetQuestsOnMap` and `ReadyForTurnIn` on a real build.
- The `GetMapWorldSize` values that the distance bands use.
- The placement accuracy of the Forever spawn conversions of QuestieDB. Its own data is already in Forever frames. The `EraToForever` helpers apply only to points that the consumer owns and that use Era coordinates. The addon never applies them to reads from the provider.

The interface keeps movement stable with 250-yard bands and a refresh threshold of 25 yards. The real polling behavior needs a client to verify.
