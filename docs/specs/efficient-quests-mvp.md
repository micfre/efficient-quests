# Efficient Quests — MVP specification

Status: product decisions agreed; addon-level test boundary confirmed.

## Problem Statement

Players questing in World of Warcraft: Forever want to enjoy the narrative and choose their own activities without repeatedly discovering that they sold a useful item, missed a flight path, passed a convenient supplier, or could have combined errands in the same area.

Guidelime-compatible guides contain valuable preparation, travel, and quest-mechanics advice. That advice is embedded in sequential routes alongside quest acceptance, objective, turn-in, and speed-leveling instructions. Following a prescribed route is a poor fit for a player who accepts quests freely, revisits zones, follows storylines, and uses an existing quest log or tracker.

The player needs the practical knowledge of an experienced companion: timely hints that improve pacing and reduce unnecessary backtracking while leaving decisions about what to do next to the player.

## Solution

Build Efficient Quests, a World of Warcraft addon initially targeting the Forever client version 1.60.1 and its build variants. It reads an installed, compatible guide and presents a compact set of practical hints relevant to the player's current zone, focused quest, and accepted quests.

The MVP uses TUG's Forever guide as its supported guide source and requires the separately published QuestieDB addon for maintained quest and world metadata. Full Questie and Guidelime are optional. A local compatibility tool adapts the supported guide package's loading and registration so that the player can use it without those optional addons. Bethink's guide is an additional compatibility reference and test source; its inclusion as prior art does not expand the MVP's release-support promise beyond TUG.

Hints include supplies to acquire or retain, useful flight paths, nearby preparation opportunities, convenient combined activities, and practical quest techniques. A hint without a reliable quest association can still appear as a clearly identified zone tip. Advice is filtered for the player's applicability and ranked without adopting the guide's route or speedrunning priorities.

The default view shows at most three concise hints. The player can expand explanations and source context, open existing game UI through appropriate links, dismiss individual hints, and restore dismissed hints. The window operates independently or integrates with FlareUI's quest tracker. Efficient Quests' own settings panel follows the design of FlareUI's settings panel.

## User Stories

1. As a questing player, I want practical advice for the zone I am visiting, so that I can avoid preventable return trips.
2. As a questing player, I want to choose my own next quest, so that I can enjoy the story at my preferred pace.
3. As a questing player, I want my existing quest log and tracker to remain my source of quest progress, so that Efficient Quests adds useful context without duplicating that interface.
4. As a player with several accepted quests, I want preparation advice across my quest log, so that I can organize supplies and errands before leaving a hub.
5. As a player focusing a quest in the game or FlareUI, I want its associated hints to receive the highest priority, so that the advice follows my expressed interest.
6. As a player opening quest details, I want that action to remain distinct from focusing a quest, so that browsing the log does not unexpectedly change hint priority.
7. As a player with watched and unwatched quests, I want accepted quests considered regardless of tracker visibility, so that useful advice is not limited to watched quests.
8. As a player using FlareUI's pinning controls, I want hint focus to follow native quest focus, so that a tracker-specific pin does not silently redefine my focus.
9. As a player accepting quests out of guide order, I want advice to remain useful, so that I do not have to synchronize with a sequential guide step.
10. As a player skipping guide steps, I want relevant tips to remain available, so that the addon supports my choices.
11. As a player revisiting a zone, I want applicable advice from earlier and later guide chapters, so that a selected chapter does not hide useful information.
12. As a player who has not accepted a nearby quest, I want conditional preparation tips, so that I can retain or obtain supplies before they become inconvenient to acquire.
13. As a player with a remote quest, I want local suppliers and preparation opportunities considered, so that I can prepare where I am now.
14. As a player with a remote focused quest, I want displayed hints to remain useful in my current zone, so that focus does not crowd out local advice with distant instructions.
15. As an Alliance player, I want Alliance-only and shared quests retained, so that relevant shared content remains visible.
16. As a Horde player, I want Horde-only and shared quests retained, so that relevant shared content remains visible.
17. As a player of either faction, I want opposite-faction-only advice excluded, so that the addon does not suggest inaccessible faction content.
18. As a player with class, race, or other known restrictions, I want applicable restrictions respected, so that advice matches my character.
19. As a player with quests above and below my level, I want level proximity considered symmetrically, so that neither higher nor lower quests are automatically favored by direction alone.
20. As a player near several opportunities, I want proximity considered in the agreed priority order, so that nearby preparation and objectives are easier to notice.
21. As a moving player, I want small position changes to leave hint order stable, so that the compact window is readable.
22. As a player reading a hint with incomplete location data, I want uncertainty preserved, so that missing coordinates are not presented as precise distance information.
23. As a player reading unassociated advice, I want it labeled as a zone tip, so that I can distinguish general guidance from a confirmed quest association.
24. As a player reading a quest-associated hint, I want to see why it is relevant, so that I can judge whether to act on it.
25. As a player short of a required supply, I want to see the item and known minimum quantity, so that I can acquire enough before traveling.
26. As a player who already carries the required supplies, I want a reminder to keep at least the minimum quantity, so that I do not accidentally sell or discard them.
27. As a player with supplies in the bank, I want reliable bank information distinguished from carried supplies, so that I can retrieve what I need before leaving.
28. As a player whose inventory changes, I want acquire and keep wording to update, so that the advice reflects my current supplies.
29. As a player seeing the same supply mentioned repeatedly, I want duplicate requirements consolidated, so that I am not encouraged to stockpile unnecessarily.
30. As a player with separate quests consuming the same item, I want confirmed independent requirements combined, so that I retain enough for all relevant uses.
31. As a player reading a combined supply minimum, I want its explanation available, so that I can understand how the quantity was calculated.
32. As a player who has finished collecting quest items, I want retention advice to persist until the items are no longer needed, so that completing an objective does not cause an early sell-off.
33. As a player who turns in a quest, I want obsolete supply requirements removed and remaining requirements recalculated, so that I do not keep unnecessary items indefinitely.
34. As a player reading an item tip without a reliable identifier or quantity, I want useful conditional advice retained, so that incomplete metadata does not erase the guide's practical knowledge.
35. As a player approaching a useful flight master, I want a reminder when the path may still need learning, so that I can improve future travel.
36. As a player who has confirmed learning a flight path, I want its acquisition reminder suppressed, so that the addon avoids redundant advice.
37. As a player with an unknown flight-path history, I want conditional wording, so that the addon does not claim I have never learned a path merely because it lacks evidence.
38. As a player returning after another login, I want confirmed discoveries remembered for my character, so that known information is not lost between sessions.
39. As a player with completed objectives, I want useful turn-in and follow-up preparation advice retained, so that the next useful context is still available.
40. As a player abandoning a quest, I want abandonment distinguished from turn-in, so that the addon does not invent completion history.
41. As a narrative-focused player, I want practical requirements disclosed without plot outcomes, so that preparation does not spoil the story.
42. As a player reading extracted guide prose, I want references to sequential steps removed or resolved, so that the advice makes sense outside the author's route.
43. As a player reading a shortened hint, I want quantities and important conditions preserved, so that brevity does not change the meaning.
44. As a player interested in a hint's origin, I want guide attribution and a relevant original excerpt, so that I can assess the source.
45. As a questing player, I want only a small number of hints visible by default, so that advice stays compact.
46. As a player wanting more context, I want to expand hints and additional advice, so that useful detail remains available on demand.
47. As a player concentrating on gameplay, I want no automatic rotation, unsolicited scrolling, sounds, flashing, or popups, so that hints do not compete for attention.
48. As a player needing quest details, I want a quest link to open the existing quest interface, so that I can inspect the quest without a duplicate log.
49. As a player needing item or location details, I want appropriate tooltips and map links, so that I can inspect supporting information.
50. As a player who no longer wants a particular hint, I want character-specific dismissal, so that repeated advice stays under my control.
51. As a player who dismissed a hint accidentally, I want a restore control, so that I can recover it.
52. As a player with nothing useful to display, I want the hint body hidden, so that an empty panel does not consume screen space.
53. As a player with an installation problem, I want it distinguished from an absence of relevant tips, so that I know when setup needs attention.
54. As a player choosing a guide, I want one installed package selected at a time, so that contradictory authors are not merged automatically.
55. As a player installing the MVP, I want QuestieDB and a supported guide to be sufficient, so that I do not have to run another guide engine or quest-helper UI.
56. As a player updating a guide, I want compatibility-patch status detected, so that I know when adaptation needs to be reapplied.
57. As a player also using Guidelime, I want the guide adaptation to preserve its operation, so that Efficient Quests can coexist with my existing setup.
58. As a player updating QuestieDB, I want compatibility checked clearly, so that an unsupported provider version does not produce misleading advice.
59. As a player using standalone mode, I want a compact independent hint window, so that I can use Efficient Quests with my preferred quest tracker.
60. As a FlareUI player, I want hints anchored below its quest tracker with configurable spacing, so that the display fits my existing layout.
61. As a FlareUI player, I want matching width, colors, typography, and styling, so that the integrated window feels consistent with the tracker.
62. As a FlareUI player collapsing or hiding the tracker, I want integrated hints to follow its visibility, so that my layout controls remain predictable.
63. As a FlareUI player with insufficient space below the tracker, I want hints placed above it, so that they remain on-screen.
64. As a player whose FlareUI tracker is unavailable, I want a standalone fallback that remembers my integration preference, so that advice remains usable and integration can resume later.
65. As a player configuring Efficient Quests, I want settings modeled after FlareUI's settings panel, so that its navigation, controls, explanations, and styling feel familiar.
66. As a player configuring standalone mode, I want settings available without FlareUI installed, so that the visual reference does not become a dependency.
67. As an English-speaking player, I want English guide content and addon text supported initially, so that the MVP has a clear language-support promise.
68. As a future user of another locale, I want identifier-based matching and localization-ready addon text, so that later language support does not require redesigning the core behavior.
69. As a player following a profession-related quest, I want directly relevant profession preparation included, so that useful quest advice is not excluded merely because it mentions a profession.
70. As a questing player, I want full profession shopping and training progression excluded from the compact view, so that it remains focused on questing and travel.

## Implementation Decisions

### Runtime and dependency contract

- The product is a Lua addon for the Forever client, initially version 1.60.1 and its build variants, with interface version 16001 as the reference starting point. The displayed game version alone does not establish API compatibility.
- Require the separately installable QuestieDB provider and one supported guide package. Users can obtain QuestieDB independently through common addon managers, including CurseForge.
- Keep full Questie, Guidelime, and FlareUI optional. Standalone behavior and the settings panel must work without them.
- Use QuestieDB's documented public entity, metadata, and compatibility-contract APIs through a contained provider adapter. Do not depend on Questie's internal database modules merely because the reference Guidelime integration does so.
- Detect absence, unsupported provider contracts, and unavailable capabilities before relying on them. Surface actionable setup status without inventing fallback data.
- Query live player state through compatible client APIs. QuestieDB enriches facts; it does not replace the current quest log, bags, focus, or observed flight-path state.
- Verify Forever API behavior against current documentation and the actual client build. Project-ID checks copied from older references require validation; the supplied references disagree about Forever's relationship to Retail project IDs.

### Responsibilities and data flow

- Keep guide ingestion, player-context collection, QuestieDB access, hint derivation/ranking, persistent character preferences, and presentation as explicit responsibilities. These describe responsibilities rather than a mandatory module count or file layout.
- The overall flow is: registered guide content plus current character context and provider facts produce an ordered set of explainable hints; the UI renders that result and sends explicit player interactions back to the addon.
- Maintain one addon-level behavioral test boundary around this composition. Client, provider, and Flare integrations are substitutable inputs at that boundary, avoiding separate test contracts for every internal helper.
- A derived hint needs enough information to preserve source identity, source text, applicability, zone context, association type, reliable quest/item references when available, known quantities and conditions, relevant locations, uncertainty, lifecycle state, and stable dismissal identity.
- Keep source facts, inferred associations, and player observations distinguishable. A useful inference must not be presented as a confirmed source or API fact.
- Persist character-specific dismissals and positive flight-path observations. Restore controls must be available for dismissed hints.

### Guide loading and extraction

- TUG is the supported MVP guide. Bethink supplies an additional compatibility fixture, including richer character, profession, item-possession, and learning-state conditions. Universal compatibility with arbitrary Guidelime guides is not an MVP promise.
- Provide a local adaptation tool for the installed guide package. It adjusts loading metadata and registration plumbing while preserving the guide's prose and tags. Make the adaptation repeatable and detect when an update has replaced the adapted metadata or registration.
- The guide must register without requiring the actual Guidelime addon. Defining a similarly named Lua global alone does not satisfy the unmodified package's hard addon dependency.
- Preserve optional coexistence with genuine Guidelime when it is installed. Avoid conflicting addon identities and circular loading dependencies.
- Read the selected package's registered, loadable guide content. Do not silently add unlisted source files merely because they exist in the guide's directory.
- Consider all applicable chapters in the selected package; ignore sequential next-chapter instructions as an ordering authority. Preserve chapter-local coordinate and applicability context during parsing.
- Extract preparation, retention, flight-path, travel-opportunity, quest-technique, and related practical advice. Mere accept, complete, and turn-in directives are not sufficient value to become hints on their own.
- Retain useful unassociated prose as zone-relevant advice, marking uncertain quest associations clearly. Use known or cautiously inferred guide context without manufacturing a precise quest link or location.
- Shorten advice so it stands alone. Remove or resolve references such as “next two steps” and route-only prescriptions while preserving quantities, conditions, and the practical meaning.
- Preserve attribution and a relevant original excerpt in expanded details. Excerpts should not introduce unrelated route material or reveal narrative outcomes excluded from ordinary hints.
- Distinguish the addon interpreting a guide from verifying the guide's underlying gameplay claims. QuestieDB can validate/enrich identifiers and metadata, but does not make arbitrary prose reliable automatically.

### Applicability and zone relevance

- Faction applicability has three classes: Alliance-only, Horde-only, and shared. Retain the player's faction and shared content; exclude only the opposite faction's exclusive content. A missing faction tag is not proof of opposite-faction exclusivity.
- Apply reliable class, race, and other supported restrictions at the correct guide or step scope. Keep unknown conditions explicit rather than silently declaring them satisfied.
- A tip is zone-relevant when the advice is useful where the player currently is. Supplies for a remote accepted quest can be relevant at a local vendor; a remote quest's focus alone does not make distant instructions locally useful.
- Permit conditional preparation for nearby unaccepted quests and future requirements. A requirement not yet unlocked can still justify local preparation; phrase that relationship conditionally.
- Level proximity is symmetric: a similar-level quest above the player and one equally far below have the same level-distance signal. Being higher or lower alone is not a reason to discard a useful hint.
- Remove known inapplicable, duplicate, and obsolete advice before ranking. Finishing a collection objective does not by itself obsolete a retention reminder.
- Preserve practical spoilers such as required supplies. Exclude narrative outcomes and future plot developments; future quest names appear only when needed to explain preparation.

### Ranking and stability

- Preserve this priority order: native focused quest, accepted quest, distance to relevant quest giver/start, distance to relevant quest target, and proximity to the player's level or applicable level range.
- Native focus means the game's supertracked quest, also used by FlareUI's focus action. Watching a quest, opening its details, and pinning it in FlareUI are distinct states. Efficient Quests observes focus and does not change it automatically.
- Consider accepted quests throughout the log, including unwatched quests. Tracker order and a guide's current step are not ranking authorities.
- Apply location signals to the quest's current phase: starts for unaccepted quests, unfinished objectives for active quests, and turn-in locations for quests ready to hand in. Do not elevate a now-irrelevant original giver simply because the quest was accepted there.
- Compare meaningful distance bands within each distance priority before finer numerical tie-breaking. Small movement should not reshuffle the compact view continually. Exact band boundaries and movement tolerance are implementation tuning values, not additional user-facing routing decisions.
- Use available reliable locations and keep missing distances unknown. Never turn missing data into zero distance or fabricated precision; provide deterministic fallback ordering.
- After the five primary priorities, prefer a useful opportunity available now over advice for later, then use stable source order. Remaining ties must be deterministic.
- Deduplicate without losing separate requirements or source context. Apply faction and other restrictions before collapsing apparently similar advice.
- Straight-line or provider-derived proximity is a relevance signal, not a promise of walking time, path reachability, or an optimized travel route.

### Supplies and quest lifecycle

- With a known item and quantity, compare the required minimum against current carried supplies. Below the minimum, use acquire wording; at or above it, reinforce keeping at least the minimum and avoiding sale/discard.
- Already owning the required supplies does not suppress the useful retention reminder. Inventory changes can transition a hint between acquire and keep wording.
- Treat reliable bank information separately from carried quantities. Where appropriate, advise retrieval instead of buying again. Unavailable or stale bank information must not be asserted as current fact.
- Deduplicate repeated mentions of the same requirement. Sum quantities only when evidence establishes separate, consumable requirements that need to be satisfied together. Otherwise preserve the guide's stated minimum rather than inflating it.
- Explain combined quantities in expanded details. Unknown identifiers or quantities remain conditional zone advice without invented counts or false satisfaction claims.
- Keep a linked retention reminder through turn-in when the item is still needed. Recalculate the remaining minimum as associated requirements are fulfilled; do not reacquire items already consumed for their intended completed purpose.
- Distinguish unfinished objectives, ready-for-turn-in quests, historical completion, and abandonment. A quest disappearing from the log is not sufficient evidence that it was handed in.
- Remove obsolete objective advice when objectives finish, while preserving applicable turn-in and follow-up preparation advice.
- Unassociated retention tips remain conditional and zone-relevant until the player dismisses them or reliable applicability information changes. Guide-step progress is not a completion signal.

### Flight-path reminders

- Distinguish confirmed learned, confirmed unlearned where supported, and unknown status. A missing observation is not proof that a path is unlearned.
- Suppress acquisition reminders for paths confirmed learned. Where status is unknown, use conditional wording such as learning the path if it is not already known.
- Persist positive discoveries per character and permit dismissal. Neither a path missing from one taxi map nor an unavailable API establishes the character's complete travel history.
- Preserve the guide's distinction between a useful travel opportunity and a genuine prerequisite. Do not describe a path as mandatory unless supported by the advice and context.

### Hint window and interactions

- Show at most three concise hints in the default compact view, with additional advice and explanations available through deliberate expansion.
- Do not automatically rotate hints or scroll through advice. No sounds, flashing, or unsolicited popups.
- Communicate focused-quest, accepted-quest, and zone relevance, with uncertainty where applicable. The player should be able to understand why advice is being shown.
- Clicking a hint expands its explanation and source context. Appropriate quest, item, and location links use the existing quest UI, item tooltips, and maps.
- Provide character-specific dismissal plus a restore-dismissed-hints control.
- Hide the hint body when there is nothing relevant. Keep settings accessible, and distinguish this valid empty state from missing guides, incompatible provider versions, or guide adaptations needing reapplication.

### FlareUI integration and settings

- Offer standalone and Flare-integrated modes. The standalone window and settings remain usable without FlareUI.
- In integrated mode, prefer attachment below FlareUI's quest tracker with configurable padding/buffer. Match its effective width, colors, typography, and visual styling, following relevant layout and appearance changes.
- Follow the tracker's hidden and collapsed states, including its configured automatic behavior. Do not reveal integrated hints solely because zone advice exists while the tracker is intentionally hidden.
- If insufficient space exists below, place hints above the tracker. If no usable tracker is available, fall back to standalone while remembering the integration preference and resuming it when possible.
- Model Efficient Quests' settings panel after FlareUI's panel: category navigation on the left, setting controls in the main area, contextual explanatory text, consistent sections and control styling, and matching visual hierarchy. This is a design reference, not a requirement to install FlareUI or duplicate its entire settings framework.
- Include settings for guide selection, display mode, integration spacing, the required standalone presentation controls, and management/restoration of dismissed hints. Keep configuration copy focused on player decisions.
- Support English guide content and addon text first. Prefer identifier-based associations where possible and structure interface text for future localization.

## Testing Decisions

- The user confirmed one primary addon-level test boundary: supply guide content and simulated player state, then verify the visible hints, ranking, and interactions. Prefer this composed behavior over testing each parser or scoring helper separately.
- Tests should observe player-visible output and effects: hint content, relevance labels, order, acquire/keep wording, quantities, visibility, source details, dismissed state, and interactions with existing game UI. Avoid assertions that merely mirror internal implementation or module structure.
- Exercise the ingestion, context/provider adaptation, hint derivation/ranking, persistence, and presentation responsibilities together at that boundary. Substitute external client, QuestieDB, and FlareUI interfaces as necessary without treating every substitute as a new feature-level seam.
- There is currently no application implementation, project test harness, glossary, or ADR collection in this workspace. The supplied addon references provide behavior and guide fixtures; they are not an existing Efficient Quests test architecture to preserve.
- Use representative TUG fixtures for unassociated preparation prose, quest-associated technique advice, mixed route/tip instructions, inherited coordinates, restrictions, duplicate shopping notes, and placeholder chapters. Use Bethink fixtures to expose format assumptions, richer applicability conditions, and the same item appearing in different preparation contexts.
- Cover the following externally observable scenarios as acceptance criteria:

| Scenario | Expected behavior |
| --- | --- |
| Player accepts quests out of order or skips guide steps | Relevant tips remain available without advancing or synchronizing a guide route. |
| Player revisits a zone | Applicable advice can come from any eligible chapter of the selected package. |
| Focus changes through native/Flare focus controls | Associated advice receives highest priority; the addon does not set focus itself. |
| Player opens details, watches a quest, or pins a tracker row | These actions do not redefine the native focus signal. |
| Accepted quest is not watched | Its relevant tips remain candidates. |
| Alliance-only, Horde-only, and shared fixtures | Only opposite-faction-exclusive content is excluded; shared advice remains for both factions. |
| Known class/race restriction fails | Inapplicable advice is excluded before ranking and deduplication. |
| Useful prose has no reliable quest association | It appears as a zone tip with appropriate uncertainty. |
| A future or remote quest needs supplies sold locally | A conditional local preparation tip can appear. |
| Remote focus has no locally useful advice | It does not populate the compact view with remote route instructions. |
| Ranking candidates differ at each priority | Focus, acceptance, giver proximity, target proximity, and level proximity follow the agreed precedence. |
| Player moves slightly within a distance band | Hint order remains stable. |
| Quest levels are equally far above and below the player | Their level-proximity signals are equal. |
| Coordinates or metadata are missing | Advice stays conditional; missing values never create false proximity or false completion. |
| Player has fewer supplies than the known minimum | Show acquire wording and the known requirement. |
| Player already carries the minimum | Show keep/don't-sell wording; do not suppress the retention reminder. |
| Inventory rises above or falls below the minimum | Wording and counts update according to current state. |
| Bank ownership is reliable, unavailable, or stale | Distinguish retrieval from acquisition and avoid unsupported ownership claims. |
| Same requirement appears repeatedly | Deduplicate without increasing the minimum. |
| Separate consumable requirements are confirmed | Combine the necessary minimum and explain the breakdown. |
| Independent consumption is unconfirmed | Preserve the stated minimum without speculative addition. |
| Collection objective finishes before turn-in | Retain items still needed through hand-in. |
| Quest is turned in or its supplies are consumed as intended | Remove the fulfilled need and recalculate remaining requirements. |
| Quest disappears because it was abandoned | Do not manufacture a completed-quest record. |
| Flight path is confirmed learned | Suppress its acquisition reminder. |
| Flight-path history is incomplete | Use conditional wording; absence is not proof of being unlearned. |
| New session restores character state | Confirmed discoveries and dismissals remain correctly scoped to that character. |
| Advice contains route references or story outcomes | The extracted practical hint stands alone and does not disclose plot outcomes. |
| More than three relevant hints exist | Default view remains compact; expansion exposes additional advice deliberately. |
| Hint or supporting link is activated | Expand explanation or open the appropriate existing quest/item/map UI. |
| Hint is dismissed and later restored | It disappears and returns for the correct character without corrupting other hints. |
| No tips match | Hide the body while preserving access to settings. |
| Guide/provider is missing or incompatible | Expose setup status distinct from the valid empty state. |
| Guide updates replace its adaptation | Detect the need to reapply compatibility changes. |
| Genuine Guidelime is optionally present | Adapted registration coexists without duplicate dispatch, namespace conflicts, or load cycles. |
| Integrated tracker changes width, font, color, height, or position | Hint presentation follows the intended Flare appearance and geometry. |
| Integrated tracker hides or collapses | Hints follow that state. |
| Space below tracker is insufficient | Place hints above while respecting available screen bounds. |
| Flare tracker is unavailable and later returns | Use standalone fallback and restore the remembered integration preference. |
| FlareUI is not installed | Standalone hints and the Flare-modeled settings panel still work. |

- Validate actual game behavior separately from simulated tests. In-client checks must record the exact Forever build and verify loading, QuestieDB contract/capabilities, quest IDs and phases, focus, inventory semantics, coordinates, taxi observations, persistence, and Flare presentation. Offline tests do not prove native client compatibility or visual fidelity.
- Visual review should compare the integrated window and settings against FlareUI at relevant UI scales and tracker placements. Confirm that no unintended sound, flash, popup, automatic rotation, or scrolling is introduced.

## Out of Scope

- Replacing the quest log, quest tracker, Guidelime, or another leveling-guide engine.
- Choosing the player's next quest, enforcing an activity sequence, advancing a guide, or issuing speedrunning skip/abandon/leave-zone prescriptions.
- Reproducing a full leveling route, route optimizer, turn-by-turn navigation system, or speedrun planner.
- Requiring full Questie, Guidelime, FlareUI, or another UI suite for core operation.
- Automatic merging of multiple guide authors and reconciliation of their conflicting routes or quantities.
- Guaranteed support for every Guidelime extension, arbitrary custom guide Lua evaluation, or every guide publisher in the MVP.
- A Bethink release-support commitment merely because it is used for compatibility reference/testing.
- Full profession leveling, general profession shopping progression, and unrelated class-training or combat instruction.
- Narrative outcomes and future plot spoilers.
- Complete independent quest/NPC/item/object database maintenance, fabricated missing coordinates, or a guarantee of instant support for newly discovered service content.
- Automatic guide downloading, guide-content redistribution, or patching the author's upstream release. The player installs the guide, and the compatibility tool adapts their local copy.
- Non-English extraction/localization coverage in the MVP, other Warcraft client families, and integrations with UI suites beyond FlareUI.
- Implementation of the addon as part of this specification-writing task.

## Further Notes

- This specification incorporates all interview decisions, including the final faction clarification, the FlareUI settings-panel requirement, the change from suppressing owned supplies to reinforcing retention, and the decision to require QuestieDB.
- The supplied TUG package hard-requires Guidelime. The supplied Bethink package hard-requires Guidelime and QuestieDB. The supplied Forever Guidelime runtime itself requires full Questie. These loader facts explain the local compatibility tool; choosing QuestieDB alone does not make the unmodified guides load independently.
- QuestieDB improves maintained factual coverage and provider compatibility. It does not resolve ambiguous prose automatically, prove every guide claim, or provide complete observed travel history. Missing and uncertain information remains part of the supported experience.
- Reference baseline checked during discovery: Questie 12.6.4 and QuestieDB 1.0.12. Dependency support should be based on the capabilities/contracts actually consumed, with targeted compatibility checks rather than an unjustified exact-version lock.
- Primary external references: [QuestieDB public API, version 1.0.12](https://github.com/Questie/QuestieDB/blob/v1.0.12/docs/api.md), [QuestieDB Forever data and compatibility notes](https://github.com/Questie/QuestieDB/blob/v1.0.12/docs/forever.md), [Questie and QuestieDB release baseline](https://github.com/Questie/Questie/releases/tag/v12.6.4%2Bv1.0.12), and [Forever quest-log API source](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua). General Warcraft API documentation was also checked through Context7; no dedicated Forever API library was found there.
- Local reference material includes TUG's Forever guide, Bethink's guide, Guidelime, Questie, and FlareUI. Inspect these as behavioral/format references; adapting a locally installed guide and calling a separately installed provider does not require copying their implementations into Efficient Quests.
- Successful MVP evaluation must demonstrate useful advice when the player deliberately deviates from the guide, including accepting several quests, acquiring supplies in advance, leaving items in the bank, completing objectives before hand-in, and returning to a zone later. A demonstration that only follows the guide's route is insufficient.
- The primary test boundary described above was explicitly confirmed by the user during specification preparation.
