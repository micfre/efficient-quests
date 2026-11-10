# Efficient Quests: MVP specification

MVP means minimum viable product, the smallest version that is useful.

Status: superseded. Issue [#15](https://github.com/micfre/efficient-quests/issues/15) replaces this specification. The plugin flow that issue #15 describes shipped. The two user stories about the guide adaptation tool are removed from the list below. The rest of this document stays unchanged as the record of the MVP decisions.

## Problem Statement

Players who quest in World of Warcraft: Forever want to enjoy the story and choose their own activities. They do not want to find out, again and again, that they sold a useful item, missed a flight path, passed a convenient supplier, or that they can combine errands in the same area.

Guidelime-compatible guides contain valuable advice on preparation, travel, and quest mechanics. A guide puts this advice inside a route that has a fixed order. The same route also has instructions to accept quests, finish objectives, turn in quests, and level fast. A route that the guide prescribes is a poor fit for a player who accepts quests freely, revisits zones, follows storylines, and uses an existing quest log or tracker.

The player needs the practical knowledge of an experienced companion. The companion gives timely hints that improve pacing and reduce needless backtracking. The player still decides what to do next.

## Solution

Build Efficient Quests, a World of Warcraft addon. The first target is the Forever client version 1.60.1 and its build variants. The addon reads an installed guide that it supports. It shows a compact set of practical hints that are relevant to the current zone of the player, the focused quest, and the accepted quests.

The MVP supports the Forever guide from TUG as its guide source. It requires the QuestieDB addon, which players publish and install separately, for quest and world metadata that someone maintains. The full Questie addon and Guidelime are optional. A local compatibility tool adapts the loading and the registration of the supported guide package. With this adaptation, the player can use the guide without those optional addons. The guide from Bethink is an additional compatibility reference and a source for tests. Its use as prior art does not widen the promise of release support beyond TUG.

Hints cover these topics: supplies to acquire or keep, useful flight paths, preparation opportunities nearby, activities that fit together conveniently, and practical quest techniques. A hint that has no reliable link to a quest can still appear. It appears as a zone tip, with a clear label. The addon filters advice for the character of the player. It ranks the advice without adopting the route or the speedrunning priorities of the guide.

The default view shows at most three short hints. The player can expand explanations and the context of the source. The player can open existing game interfaces through suitable links, dismiss single hints, and restore dismissed hints. The window works on its own or together with the quest tracker of FlareUI. The own settings panel of Efficient Quests follows the design of the settings panel of FlareUI.

## User Stories

1. As a questing player, I want practical advice for the zone I am visiting, so that I can avoid return trips that I can prevent.
2. As a questing player, I want to choose my own next quest, so that I can enjoy the story at my preferred pace.
3. As a questing player, I want my existing quest log and tracker to stay my source of quest progress, so that Efficient Quests adds useful context and does not duplicate that interface.
4. As a player with several accepted quests, I want preparation advice across my quest log, so that I can organize supplies and errands before I leave a hub.
5. As a player who focuses a quest in the game or in FlareUI, I want the hints of that quest to receive the highest priority, so that the advice follows my expressed interest.
6. As a player who opens quest details, I want that action to stay separate from focusing a quest, so that browsing the log does not change the priority of hints without warning.
7. As a player with watched and unwatched quests, I want the addon to consider accepted quests whether or not the tracker shows them, so that useful advice is not limited to watched quests.
8. As a player who uses the pinning controls of FlareUI, I want the focus of hints to follow the native quest focus, so that a pin in the tracker does not silently redefine my focus.
9. As a player who accepts quests out of guide order, I want the advice to stay useful, so that I do not have to keep in step with a guide that has a fixed order.
10. As a player who skips guide steps, I want relevant tips to stay available, so that the addon supports my choices.
11. As a player who revisits a zone, I want applicable advice from earlier and later guide chapters, so that the chapter I selected does not hide useful information.
12. As a player who has not accepted a quest nearby, I want conditional preparation tips, so that I can keep or get supplies before they become hard to get.
13. As a player with a remote quest, I want the addon to consider local suppliers and local preparation opportunities, so that I can prepare where I am now.
14. As a player with a remote focused quest, I want the hints on display to stay useful in my current zone, so that focus does not fill the view with distant instructions and push out local advice.
15. As an Alliance player, I want the addon to keep Alliance-only quests and shared quests, so that relevant shared content stays visible.
16. As a Horde player, I want the addon to keep Horde-only quests and shared quests, so that relevant shared content stays visible.
17. As a player of either faction, I want the addon to exclude advice that is only for the opposite faction, so that it does not suggest content that I cannot reach.
18. As a player with restrictions of class, race, or another known kind, I want the addon to respect the restrictions that apply, so that the advice matches my character.
19. As a player with quests above and below my level, I want the addon to consider level proximity in a symmetric way, so that the direction alone does not favor higher quests or lower quests.
20. As a player near several opportunities, I want the addon to consider proximity in the agreed order of priority, so that I can notice nearby preparation and nearby objectives more easily.
21. As a player who moves, I want small changes of position to leave the order of the hints stable, so that the compact window stays readable.
22. As a player who reads a hint with incomplete location data, I want the addon to preserve the uncertainty, so that missing coordinates do not appear as precise distance information.
23. As a player who reads advice without an association, I want it labeled as a zone tip, so that I can tell general guidance from a confirmed quest association.
24. As a player who reads a hint that belongs to a quest, I want to see why the hint is relevant, so that I can decide whether to act on it.
25. As a player who is short of a required supply, I want to see the item and the known minimum quantity, so that I can get enough before I travel.
26. As a player who already carries the required supplies, I want a reminder to keep at least the minimum quantity, so that I do not sell or discard them by accident.
27. As a player with supplies in the bank, I want reliable bank information to be separate from carried supplies, so that I can retrieve what I need before I leave.
28. As a player whose inventory changes, I want the wording for acquire and keep to update, so that the advice reflects my current supplies.
29. As a player who sees the same supply mentioned many times, I want duplicate requirements to be consolidated, so that nothing pushes me to stockpile more than I need.
30. As a player with separate quests that consume the same item, I want confirmed independent requirements to be combined, so that I keep enough for all relevant uses.
31. As a player who reads a combined supply minimum, I want an explanation to be available, so that I can understand how the addon calculated the quantity.
32. As a player who finished collecting quest items, I want the retention advice to continue until I no longer need the items, so that finishing an objective does not cause me to sell them too early.
33. As a player who turns in a quest, I want the addon to remove supply requirements that are obsolete and to recalculate the remaining requirements, so that I do not keep unneeded items forever.
34. As a player who reads an item tip without a reliable identifier or quantity, I want useful conditional advice to stay, so that incomplete metadata does not erase the practical knowledge of the guide.
35. As a player who approaches a useful flight master, I want a reminder when I possibly still need to learn the path, so that I can improve my future travel.
36. As a player who confirmed that I learned a flight path, I want the addon to suppress the reminder to acquire it, so that the addon does not give advice that is redundant.
37. As a player with unknown flight-path history, I want conditional wording, so that the addon does not claim that I never learned a path only because it lacks evidence.
38. As a player who returns after another login, I want the addon to remember confirmed discoveries for my character, so that known information is not lost between sessions.
39. As a player with completed objectives, I want useful advice for turn-in and follow-up preparation to stay, so that the next useful context is still available.
40. As a player who abandons a quest, I want the addon to treat abandonment differently from turn-in, so that the addon does not invent a history of completion.
41. As a player who focuses on the narrative, I want practical requirements to be disclosed without plot outcomes, so that preparation does not spoil the story.
42. As a player who reads prose that the addon extracted from a guide, I want references to steps in a sequence to be removed or resolved, so that the advice makes sense outside the route of the author.
43. As a player who reads a shortened hint, I want quantities and important conditions to be preserved, so that brevity does not change the meaning.
44. As a player who is interested in the origin of a hint, I want attribution to the guide and a relevant original excerpt, so that I can assess the source.
45. As a questing player, I want only a small number of hints to be visible by default, so that the advice stays compact.
46. As a player who wants more context, I want to expand hints and additional advice, so that useful detail is available on demand.
47. As a player who concentrates on gameplay, I want no automatic rotation, no unsolicited scrolling, no sounds, no flashing, and no popups, so that hints do not compete for my attention.
48. As a player who needs quest details, I want a quest link to open the existing quest interface, so that I can inspect the quest without a duplicate log.
49. As a player who needs details of an item or a location, I want suitable tooltips and map links, so that I can inspect supporting information.
50. As a player who no longer wants a particular hint, I want dismissal that is specific to my character, so that I stay in control of repeated advice.
51. As a player who dismissed a hint by accident, I want a restore control, so that I can recover it.
52. As a player who has nothing useful to display, I want the hint body to be hidden, so that an empty panel does not use screen space.
53. As a player with an installation problem, I want the addon to show the problem as different from an absence of relevant tips, so that I know when the setup needs attention.
54. As a player who chooses a guide, I want one installed package to be selected at a time, so that the addon does not merge contradictory authors automatically.
55. As a player who installs the MVP, I want QuestieDB and a supported guide to be enough, so that I do not have to run another guide engine or another quest-helper interface.
58. As a player who updates QuestieDB, I want a clear compatibility check, so that an unsupported provider version does not produce misleading advice.
59. As a player in standalone mode, I want a compact and independent hint window, so that I can use Efficient Quests with the quest tracker that I prefer.
60. As a FlareUI player, I want hints anchored below its quest tracker with spacing that I can configure, so that the display fits my existing layout.
61. As a FlareUI player, I want the width, colors, typography, and styling to match, so that the integrated window looks consistent with the tracker.
62. As a FlareUI player who collapses or hides the tracker, I want the integrated hints to follow its visibility, so that my layout controls stay predictable.
63. As a FlareUI player with too little space below the tracker, I want hints placed above it, so that they stay on the screen.
64. As a player whose FlareUI tracker is not available, I want a standalone fallback that remembers my integration preference, so that the advice stays usable and the integration can resume later.
65. As a player who configures Efficient Quests, I want settings that follow the model of the settings panel of FlareUI, so that the navigation, the controls, the explanations, and the styling feel familiar.
66. As a player who configures standalone mode, I want settings to be available without FlareUI installed, so that the visual reference does not become a dependency.
67. As a player who speaks English, I want English guide content and English addon text to be supported first, so that the MVP makes a clear promise about language support.
68. As a future user of another locale, I want matching that uses identifiers and addon text that is ready for localization, so that later support for more languages does not require a redesign of the core behavior.
69. As a player who follows a quest related to a profession, I want preparation for that profession to be included when it is directly relevant, so that useful quest advice is not excluded only because it mentions a profession.
70. As a questing player, I want full profession shopping and training progression to be excluded from the compact view, so that the view stays focused on questing and travel.

## Implementation Decisions

### Runtime and dependency contract

- The product is a Lua addon for the Forever client. The first target is version 1.60.1 and its build variants. Interface version 16001 is the reference starting point. The displayed game version alone does not show that the API is compatible.
- Require the QuestieDB provider, which players can install separately, and one supported guide package. Players can get QuestieDB on their own through common addon managers, including CurseForge.
- Keep the full Questie addon, Guidelime, and FlareUI optional. Standalone behavior and the settings panel must work without them.
- Use the documented public APIs of QuestieDB for entities, metadata, and the compatibility contract. Call them through a contained provider adapter. Do not depend on the internal database modules of Questie only because the reference integration of Guidelime does so.
- Before the addon relies on a provider, detect these cases: the provider is absent, the provider contract is unsupported, or a capability is not available. Show setup status that the player can act on. Do not invent fallback data.
- Query the live state of the player through compatible client APIs. QuestieDB adds facts. It does not replace the current quest log, the bags, the focus, or the observed flight-path state.
- Verify the behavior of the Forever API against the current documentation and against the real client build. Project-ID checks that come from older references need validation. The supplied references disagree about how Forever relates to Retail project IDs.

### Responsibilities and data flow

- Keep these as separate responsibilities: guide ingestion, collection of player context, access to QuestieDB, derivation and ranking of hints, persistent preferences for each character, and presentation. These are responsibilities. They do not require a set number of modules or a set file layout.
- The overall flow is as follows. The registered guide content, the current context of the character, and the facts of the provider produce an ordered set of hints that the addon can explain. The interface renders that result. It sends the explicit interactions of the player back to the addon.
- Keep one addon-level boundary for behavioral tests around this composition. At that boundary, the client, the provider, and the Flare integration are inputs that tests can substitute. This avoids a separate test contract for every internal helper.
- A derived hint needs enough information to keep these items: the identity of the source, the source text, the applicability, the zone context, the type of association, reliable references to quests and items when they exist, known quantities and conditions, relevant locations, uncertainty, the lifecycle state, and a stable identity for dismissal.
- Keep source facts, inferred associations, and observations of the player separate. A useful inference must not appear as a confirmed fact of the source or of the API.
- Persist the dismissals of each character and the positive observations of flight paths. Controls to restore dismissed hints must be available.

### Guide loading and extraction

- TUG is the supported guide for the MVP. Bethink supplies an additional compatibility fixture. It includes richer conditions on character, profession, possession of items, and learning state. The MVP does not promise compatibility with arbitrary Guidelime guides.
- Provide a local adaptation tool for the installed guide package. The tool changes the loading metadata and the registration plumbing. It preserves the prose and the tags of the guide. Make the adaptation repeatable. Make the tool detect when an update replaced the adapted metadata or the registration.
- The guide must register without the real Guidelime addon. Defining a Lua global with a similar name does not satisfy the hard addon dependency of the unmodified package.
- Preserve optional coexistence with the real Guidelime when the player installs it. Avoid conflicts between addon identities. Avoid circular loading dependencies.
- Read the registered guide content of the selected package that the addon can load. Do not add source files that the package does not list, only because they exist in the folder of the guide.
- Consider all applicable chapters in the selected package. Ignore instructions to go to the next chapter as an authority on order. Preserve the context of coordinates and applicability inside each chapter during parsing.
- Extract advice on preparation, retention, flight paths, travel opportunities, and quest techniques, and other practical advice. Plain directives to accept, complete, and turn in are not valuable enough to become hints on their own.
- Keep useful prose that has no association as advice for the zone. Mark uncertain quest associations clearly. Use known guide context, or guide context that you infer with care. Do not make up a precise quest link or a precise location.
- Shorten advice so that it stands alone. Remove or resolve references such as "next two steps" and prescriptions that only serve the route. Preserve quantities, conditions, and the practical meaning.
- Preserve attribution and a relevant original excerpt in the expanded details. An excerpt must not bring in unrelated route material. It must not reveal narrative outcomes that ordinary hints exclude.
- Keep two things apart: the addon interprets a guide, and the addon verifies the gameplay claims that the guide makes. QuestieDB can validate and enrich identifiers and metadata. It does not make arbitrary prose reliable.

### Applicability and zone relevance

- Faction applicability has three classes: Alliance-only, Horde-only, and shared. Keep the faction of the player and the shared content. Exclude only the content that is exclusive to the opposite faction. A missing faction tag does not show that content is exclusive to the opposite faction.
- Apply reliable restrictions of class, race, and other supported kinds at the correct scope of the guide or the step. Keep unknown conditions explicit. Do not declare them satisfied without evidence.
- A tip is relevant to the zone when the advice is useful where the player is now. Supplies for an accepted quest in a remote place can be relevant at a local vendor. The focus on a remote quest does not, by itself, make distant instructions useful locally.
- Allow conditional preparation for nearby quests that the player has not accepted, and for future requirements. A requirement that is not yet unlocked can still justify local preparation. Phrase that relation as a condition.
- Level proximity is symmetric. A quest of similar level above the player and a quest equally far below the player have the same signal of level distance. Being higher or lower is not, by itself, a reason to discard a useful hint.
- Before ranking, remove advice that is known to be inapplicable, duplicate, or obsolete. Finishing a collection objective does not by itself make a retention reminder obsolete.
- Preserve practical spoilers, such as required supplies. Exclude narrative outcomes and future plot developments. Name a future quest only when the name is needed to explain the preparation.

### Ranking and stability

- Preserve this order of priority: the native focused quest, an accepted quest, the distance to the relevant quest giver or start, the distance to the relevant quest target, and the closeness to the level of the player or to the applicable range of levels.
- Native focus means the supertracked quest of the game. The focus action of FlareUI also uses it. Watching a quest, opening its details, and pinning it in FlareUI are different states. Efficient Quests observes focus. It does not change focus automatically.
- Consider accepted quests across the whole log, including quests that the tracker does not show. The order of the tracker and the current step of a guide are not authorities for ranking.
- Apply location signals to the current phase of the quest. For quests that the player has not accepted, use the start. For active quests, use the unfinished objectives. For quests that are ready to hand in, use the turn-in locations. Do not raise the rank of an original giver that no longer matters, only because the player accepted the quest there.
- Within each distance priority, compare meaningful distance bands before you break ties with finer numbers. Small movement must not reshuffle the compact view all the time. The exact boundaries of the bands and the tolerance for movement are tuning values of the implementation. They are not additional decisions about routing that the player sees.
- Use the reliable locations that are available. Keep missing distances unknown. Never turn missing data into zero distance or into precision that you made up. Provide a deterministic fallback order.
- After the five primary priorities, prefer a useful opportunity that is available now over advice for later. Then use the stable source order. Remaining ties must be deterministic.
- Deduplicate without the loss of separate requirements or of source context. Apply the restrictions of faction and other kinds before you merge advice that looks similar.
- Proximity that uses a straight line, or proximity that the provider derives, is a signal of relevance. It is not a promise about walking time, about whether a path is reachable, or about an optimized travel route.

### Supplies and quest lifecycle

- When the item and the quantity are known, compare the required minimum with the supplies that the player currently carries. Below the minimum, use wording to acquire. At or above the minimum, reinforce that the player must keep at least the minimum and must not sell or discard it.
- Owning the required supplies already does not suppress the useful reminder to keep them. Changes of inventory can move a hint between acquire wording and keep wording.
- Treat reliable bank information separately from carried quantities. Where it is suitable, advise retrieval and not a second purchase. Do not assert bank information that is unavailable or stale as a current fact.
- Deduplicate repeated mentions of the same requirement. Add quantities only when evidence shows that the requirements are separate, consumable, and must be met together. Otherwise preserve the minimum that the guide states. Do not inflate it.
- Explain combined quantities in the expanded details. Unknown identifiers or quantities stay conditional advice for the zone. Do not invent counts. Do not claim that a requirement is satisfied without evidence.
- Keep a linked retention reminder through the turn-in when the player still needs the item. As the associated requirements are fulfilled, recalculate the remaining minimum. Do not tell the player to get again the items that were consumed for their intended and completed purpose.
- Keep these states apart: unfinished objectives, ready for turn-in, historical completion, and abandonment. A quest that disappears from the log is not enough evidence that the player handed it in.
- When objectives finish, remove advice about the objectives that is obsolete. Keep the advice for turn-in and for follow-up preparation that still applies.
- Retention tips without an association stay conditional and relevant to the zone until the player dismisses them or reliable information about applicability changes. Progress through the steps of a guide is not a signal of completion.

### Flight-path reminders

- Distinguish three statuses: confirmed learned, confirmed unlearned (where the client supports this), and unknown. A missing observation does not show that a path is unlearned.
- Suppress reminders to acquire paths that are confirmed learned. Where the status is unknown, use conditional wording, such as "learn the path if you do not already know it".
- Persist positive discoveries for each character, and permit dismissal. A path that is missing from one taxi map does not establish the complete travel history of the character. An API that is not available does not establish it either.
- Preserve the distinction of the guide between a useful opportunity to travel and a real prerequisite. Do not describe a path as mandatory unless the advice and the context support this.

### Hint window and interactions

- In the default compact view, show at most three short hints. Make additional advice and explanations available through expansion that the player chooses.
- Do not rotate hints automatically. Do not scroll through advice automatically. Use no sounds, no flashing, and no popups that the player did not ask for.
- Show whether the relevance comes from the focused quest, from an accepted quest, or from the zone, and show uncertainty where it applies. The player must be able to understand why the addon shows the advice.
- A click on a hint expands its explanation and the context of its source. Suitable links for quests, items, and locations use the existing quest interface, the item tooltips, and the maps.
- Provide dismissal that is specific to the character, and a control to restore dismissed hints.
- When nothing is relevant, hide the hint body. Keep the settings accessible. Show this valid empty state as different from these cases: a missing guide, an incompatible provider version, and a guide adaptation that the player must apply again.

### FlareUI integration and settings

- Offer a standalone mode and a mode that integrates with Flare. The standalone window and the settings stay usable without FlareUI.
- In integrated mode, prefer attachment below the quest tracker of FlareUI, with padding or a buffer that the player can configure. Match its effective width, its colors, its typography, and its visual styling. Follow the changes to layout and appearance that matter.
- Follow the hidden state and the collapsed state of the tracker, including its configured automatic behavior. While the tracker is hidden on purpose, do not reveal integrated hints only because advice for the zone exists.
- If there is not enough space below the tracker, place the hints above it. If no usable tracker is available, fall back to standalone mode. Remember the preference for integration, and resume it when this is possible.
- Model the settings panel of Efficient Quests on the panel of FlareUI. It has category navigation on the left, setting controls in the main area, explanatory text in context, consistent sections and control styling, and a matching visual hierarchy. This is a design reference. It does not require the player to install FlareUI. It does not require a copy of the whole settings framework of FlareUI.
- Include settings for these items: guide selection, display mode, integration spacing, the standalone presentation controls that the mode requires, and the management and restoration of dismissed hints. Keep the text of the configuration focused on decisions of the player.
- Support English guide content and English addon text first. Where possible, prefer associations that use identifiers. Structure the interface text so that it is ready for future localization.

## Testing Decisions

- The user confirmed one primary addon-level test boundary. Tests supply guide content and simulated player state. They then verify the visible hints, the ranking, and the interactions. Prefer this composed behavior over tests of each parser or each scoring helper on its own.
- Tests observe the output and the effects that the player can see: the content of hints, the relevance labels, the order, the wording to acquire and to keep, quantities, visibility, details of the source, the dismissed state, and interactions with the existing game interface. Avoid assertions that only mirror the internal implementation or the module structure.
- At that boundary, exercise these responsibilities together: ingestion, adaptation of the context and the provider, derivation and ranking of hints, persistence, and presentation. Substitute the external interfaces of the client, QuestieDB, and FlareUI as needed. Do not treat each substitute as a new seam at the level of a feature.
- At the time of writing, this workspace had no application implementation, no project test harness, no glossary, and no collection of ADRs. The supplied addon references give behavior and guide fixtures. They are not an existing test architecture of Efficient Quests that must be preserved.
- Use representative TUG fixtures for these cases: preparation prose without an association, advice on techniques that belongs to a quest, mixed instructions for the route and for tips, inherited coordinates, restrictions, duplicate shopping notes, and chapters that are placeholders. Use Bethink fixtures to expose assumptions about format, richer conditions of applicability, and the same item in different contexts of preparation.
- Cover the scenarios below as acceptance criteria. Each scenario can be observed from outside.

| Scenario | Expected behavior |
| --- | --- |
| Player accepts quests out of order or skips guide steps | Relevant tips stay available. The addon does not advance a guide route or keep in step with it. |
| Player revisits a zone | Applicable advice can come from any eligible chapter of the selected package. |
| Focus changes through native or Flare focus controls | Associated advice receives the highest priority. The addon does not set focus itself. |
| Player opens details, watches a quest, or pins a tracker row | These actions do not redefine the native focus signal. |
| Accepted quest is not watched | Its relevant tips stay candidates. |
| Fixtures for Alliance-only, Horde-only, and shared content | The addon excludes only content that is exclusive to the opposite faction. Shared advice stays for both factions. |
| A known restriction of class or race fails | The addon excludes inapplicable advice before ranking and deduplication. |
| Useful prose has no reliable quest association | It appears as a zone tip with suitable uncertainty. |
| A future or remote quest needs supplies that a local vendor sells | A conditional tip for local preparation can appear. |
| Remote focus has no locally useful advice | The compact view does not fill with route instructions for remote places. |
| Ranking candidates differ at each priority | Focus, acceptance, proximity to the giver, proximity to the target, and proximity of level follow the agreed order. |
| Player moves slightly within a distance band | The order of hints stays stable. |
| Quest levels are equally far above and below the player | Their signals of level proximity are equal. |
| Coordinates or metadata are missing | The advice stays conditional. Missing values never create false proximity or false completion. |
| Player has fewer supplies than the known minimum | Show the wording to acquire and the known requirement. |
| Player already carries the minimum | Show the wording to keep the item and not sell it. Do not suppress the retention reminder. |
| Inventory rises above or falls below the minimum | The wording and the counts update to match the current state. |
| Bank ownership is reliable, unavailable, or stale | Separate retrieval from acquisition. Avoid claims about ownership that nothing supports. |
| The same requirement appears many times | Deduplicate it without an increase of the minimum. |
| Separate consumable requirements are confirmed | Combine the necessary minimum and explain the breakdown. |
| Independent consumption is not confirmed | Preserve the stated minimum. Do not add a speculative amount. |
| A collection objective finishes before turn-in | Keep the items that the player still needs until hand-in. |
| Quest is turned in, or its supplies are consumed as intended | Remove the need that is fulfilled and recalculate the remaining requirements. |
| Quest disappears because the player abandoned it | Do not make a record of a completed quest. |
| Flight path is confirmed learned | Suppress its reminder to acquire it. |
| Flight-path history is incomplete | Use conditional wording. Absence is not proof that the path is unlearned. |
| New session restores the state of a character | Confirmed discoveries and dismissals stay in the correct scope for that character. |
| Advice contains route references or story outcomes | The extracted practical hint stands alone and does not disclose plot outcomes. |
| More than three relevant hints exist | The default view stays compact. Expansion shows additional advice when the player chooses. |
| Hint or supporting link is activated | The addon expands the explanation, or opens the suitable existing interface for the quest, the item, or the map. |
| Hint is dismissed and later restored | It disappears and returns for the correct character. It does not damage other hints. |
| No tips match | Hide the body. Keep access to the settings. |
| Guide or provider is missing or incompatible | Show setup status that is different from the valid empty state. |
| Guide updates replace its adaptation | Detect that the player must apply the compatibility changes again. |
| Real Guidelime is optionally present | The adapted registration coexists with it. There is no duplicate dispatch, no conflict of namespaces, and no load cycle. |
| Integrated tracker changes width, font, color, height, or position | The presentation of the hints follows the intended appearance and geometry of Flare. |
| Integrated tracker hides or collapses | The hints follow that state. |
| Space below the tracker is not enough | Place the hints above the tracker and respect the available bounds of the screen. |
| Flare tracker is not available and later returns | Use the standalone fallback. Restore the remembered preference for integration. |
| FlareUI is not installed | Standalone hints and the settings panel that Flare inspired still work. |

- Validate the real game behavior separately from the simulated tests. The in-client checks must record the exact Forever build. They must verify these items: loading, the contract and the capabilities of QuestieDB, quest IDs and phases, focus, the semantics of inventory, coordinates, taxi observations, persistence, and the presentation of Flare. Offline tests do not show native compatibility or visual quality.
- A visual review compares the integrated window and the settings with FlareUI. It uses the relevant UI scales and the relevant placements of the tracker. It confirms that the addon adds no sound, flash, popup, automatic rotation, or scrolling that nobody intended.

## Out of Scope

- Replacing the quest log, the quest tracker, Guidelime, or another engine for leveling guides.
- Choosing the next quest of the player, enforcing a sequence of activities, advancing a guide, or giving speedrunning prescriptions to skip, abandon, or leave a zone.
- Reproducing a full leveling route, a route optimizer, a system of turn-by-turn navigation, or a speedrun planner.
- Requiring the full Questie addon, Guidelime, FlareUI, or another suite of interface addons for the core operation.
- Automatic merging of several guide authors, and reconciliation of their conflicting routes or quantities.
- A guarantee of support for every extension of Guidelime, for the evaluation of arbitrary custom Lua code in guides, or for every publisher of guides in the MVP.
- A commitment to release support for Bethink only because the project uses it for compatibility reference and testing.
- Full profession leveling, general progression of profession shopping, and unrelated class training or combat instruction.
- Narrative outcomes and spoilers of the future plot.
- Maintenance of a complete and independent database of quests, NPCs, items, and objects. Also out of scope: coordinates that the addon makes up for missing data, and a guarantee of instant support for newly discovered content of services.
- Automatic download of guides, redistribution of guide content, and patching of the upstream release of the author. The player installs the guide. The compatibility tool adapts the local copy of the player.
- Extraction and localization for languages other than English in the MVP, other families of Warcraft clients, and integrations with suites of interface addons other than FlareUI.
- Implementation of the addon as part of this task to write the specification.

## Further Notes

- This specification includes all decisions from the interview. These include the final clarification about faction, the requirement for the settings panel of FlareUI, the change from suppressing owned supplies to reinforcing retention, and the decision to require QuestieDB.
- The supplied TUG package hard-requires Guidelime. The supplied Bethink package hard-requires Guidelime and QuestieDB. The supplied Forever Guidelime runtime itself requires the full Questie addon. These facts about loading explain why the project needs the local compatibility tool. If you choose QuestieDB alone, the unmodified guides still do not load independently.
- QuestieDB improves the coverage of facts that someone maintains, and it improves provider compatibility. It does not resolve ambiguous prose automatically. It does not prove every claim of a guide. It does not give a complete history of observed travel. Missing and uncertain information is part of the supported experience.
- Reference baseline that we checked during discovery: Questie 12.6.4 and QuestieDB 1.0.12. Base dependency support on the capabilities and contracts that the addon actually uses. Use targeted checks of compatibility. Do not lock to an exact version without a reason.
- Primary external references: [QuestieDB public API, version 1.0.12](https://github.com/Questie/QuestieDB/blob/v1.0.12/docs/api.md), [QuestieDB Forever data and compatibility notes](https://github.com/Questie/QuestieDB/blob/v1.0.12/docs/forever.md), [Questie and QuestieDB release baseline](https://github.com/Questie/Questie/releases/tag/v12.6.4%2Bv1.0.12), and [Forever quest-log API source](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua). We also checked the general Warcraft API documentation through Context7. We found no dedicated Forever API library there.
- The local reference material includes the Forever guide from TUG, the guide from Bethink, Guidelime, Questie, and FlareUI. Inspect these as references for behavior and format. The project adapts a locally installed guide and calls a provider that the player installs separately. For this reason, the project does not need to copy their implementations into Efficient Quests.
- A successful evaluation of the MVP must show useful advice when the player deliberately deviates from the guide. The deviations include these: accepting several quests, getting supplies in advance, leaving items in the bank, completing objectives before hand-in, and returning to a zone later. A demonstration that only follows the route of the guide is not enough.
- The user explicitly confirmed the primary test boundary above during the preparation of the specification.
