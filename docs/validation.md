# Release validation record

This record reports what we verified offline for the MVP. It also lists what a person with the game client must still check. MVP means minimum viable product, the smallest version that is useful. The record follows the validation requirements in the [MVP specification](specs/efficient-quests-mvp.md).

Status: offline verification is complete. In-client checks and visual checks are not done. The MVP is not a validated release until someone runs the checklists below and records the results.

- Offline results are at commit `8cf66ab`, the tip of `integration/efficient-quests-mvp`, on 2026-11-10. We wrote this record on branch `ticket/10-release-validation` from that commit.
- Offline result: all five Lua behavioral suites and both Python adaptation tests pass. In total, 103 Lua checks and 2 Python tests pass.
- Nobody checked anything in this record against a running Forever client, a real QuestieDB installation, a real guide installation, or FlareUI on screen. The sections "In-client checks" and "Visual checks" are checklists. They are not results.

## Fix-round update

The branch `fix/code-review-round` holds the fixes for the code-review findings of 2026-11-10. After the behavioral fixes, we verified everything offline again. All five Lua suites and both Python tests pass. In total, 110 Lua checks and 2 Python tests pass. These changes affect this record:

- The gap in the ranking precedence, described below, is closed. The `hints` suite now has differential tests. In each test, two candidates differ at two priorities at the same time, and the higher priority must win. The tests cover these pairs: focused over accepted, accepted over giver distance, giver over target distance, target over level, and the locality tiers at an equal distance signal. We also corrected the comparator to the fixed precedence of the specification. Focus and acceptance now outrank the tiers of local evidence. The tiers only order candidates that are equal at a location priority. Two tests from the #12 round had put a tier above focus. They now assert the order of the specification.
- A chapter title confirms locality only when it equals the zone name exactly. A title that only contains the zone name is unresolved and uncertain.
- Taxi-node observations keep the raw state from the client. A state that the enum of the client names as unlearned is explicit negative evidence. See the [consumption evidence note](consumption-evidence.md). The check IC-16 below reflects this.
- The dismissed category of the settings restores dismissed hints one at a time. Restoring all of them stays as a secondary action.

## Plugin flow update

The tickets #16 through #23 of [spec #15](https://github.com/micfre/efficient-quests/issues/15) replaced the in-place adaptation flow. Guides now ship as plugin folders that maintainers build offline. The core addon reconciles the addons that declare the guide marker against the guides that registered, offers guide selection in the settings, and reports the new setup states. The old adaptation tool and its checksum manifest are deleted.

After the change, we verified everything offline again from the worktree of ticket #24. The six Lua suites, the bridge suite, and the Python suites pass. In total, 131 Lua checks and 30 Python tests pass. The commands and the results are in the next section. The CI workflow runs the same set on every push and pull request, plus a release dry-run over synthetic fixtures that proves the license gate.

- The guide plugins are built by `tools/build_guide.py` and released by `tools/release.py`. The Python tests drive both tools as commands over synthetic fixture packages. This is the builder-artifact seam.
- The sixth Lua suite, `tests/manifest.lua`, reads the shipped manifest text and the files it lists. It pins version 0.2.0 and the QuestieDB requirement, and it rejects leftover mentions of Guidelime and Questie.
- The bridge suite is the new seam at the top of the stack. It builds a synthetic fixture guide with the real builder and loads the generated plugin next to the real core addon in the headless harness. It asserts registration through the real hook, the settings guide list, the hints, and the login reconciliation.
- The in-client checks below are updated to the plugin flow. IC-1 expects version 0.2.0.

## What earlier rounds left open

Each implementation round recorded the checks that it was unable to do. In total, these checks are open:

- No Forever build ever loaded the runtime scaffold (#2), the guide loading of the first rounds (#3), or the provider adapter (#4). Nobody verified loading, provider capabilities, or coexistence with the real Guidelime in a client. The adaptation tool named in the earlier rounds is deleted. The guide plugin builder replaced it. No client has loaded a built plugin either.
- The extraction (#5, #11) is a heuristic filter. We audited it against the full installed TUG 1.28 and Bethink 1.0.5 corpora and found zero safety findings. We do not claim coverage of arbitrary prose, and some categories of prose stay withheld. See the [extraction audit](tug-extraction-audit.md).
- Ranking (#6, #12) needs a client for these items: the real Forever map hierarchy and area names, the behavior of `GetQuestsOnMap` and `ReadyForTurnIn`, the `GetMapWorldSize` values for the distance bands, the placement of the QuestieDB spawn conversions, and the movement polling.
- Supplies and lifecycle (#7, #13): We checked the real bank semantics, the taxi semantics, and the real field shapes of the quest-log objectives offline, against documentation only. The survival of a quest through turn-in, and the classification of flights, partly depend on the wording of the guide.
- The standalone window (#8) needs a client to verify its exact layout, its links, and its visual quality.
- Nobody verified the FlareUI integration (#9) in the game. This includes the real behavior of the tracker and the visual quality.
- The documentation (#14) says that nobody did the client and visual validation. This record is that tracked validation work (#10).

## Offline verification

### Commands and results

The host has no Lua interpreter. For this reason, the Lua suites ran in Docker with Lua 5.1.5 (image `nickblah/lua:5.1`). On a host that has Lua, use the `lua5.1` commands in the [test guide](../tests/README.md). The CI workflow runs the same commands.

In the plugin-flow round, we ran these commands from the root of the worktree:

```sh
docker run --rm -v "$PWD:/w" -w /w nickblah/lua:5.1 lua tests/runtime.lua
docker run --rm -v "$PWD:/w" -w /w nickblah/lua:5.1 lua tests/guide.lua
docker run --rm -v "$PWD:/w" -w /w nickblah/lua:5.1 lua tests/hints.lua
docker run --rm -v "$PWD:/w" -w /w nickblah/lua:5.1 lua tests/lifecycle.lua
docker run --rm -v "$PWD:/w" -w /w nickblah/lua:5.1 lua tests/ui.lua
docker run --rm -v "$PWD:/w" -w /w nickblah/lua:5.1 lua tests/manifest.lua
sh tests/bridge.sh
python3 -m unittest discover -s tests -p 'test_*.py'
```

Every command exited with code 0 and reported no failures:

| Command | Result |
| --- | --- |
| `tests/runtime.lua` | 17 checks passed. They cover the setup status for a missing provider, a missing guide with the pointer to the releases page, and an incompatible provider; the login reconciliation warnings for a declared guide that did not register and a registered guide without the marker; context collection, native focus, uncertainty for a collapsed log, turn-in versus abandonment, and professions. |
| `tests/guide.lua` | 29 checks passed. They cover registration, chapter applicability, associations, uncertainty, screening for routes and spoilers, the reviewed TUG formats, extraction of flights and techniques, the plugin guide list metadata with chapter append, and item-bearing objective directives. |
| `tests/hints.lua` | 34 checks passed. They cover the local relevance tiers, ranking by focus and acceptance, proximity of markers and turn-ins, symmetric levels, restrictions, stability, timing, and the differential precedence tests. |
| `tests/lifecycle.lua` | 27 checks passed. They cover acquire and keep wording, freshness of the bank, observation of consumption, turn-in, flight observations, combining, and deduplication. |
| `tests/ui.lua` | 15 checks passed. They cover the compact view, paging, links, dismissal and restore, the empty state, display settings, the simulated Flare tracker geometry, the fallback, and the guide selection rule: auto-selection of the only installed guide, an explicit choice between several, and the fallback after removal. |
| `tests/manifest.lua` | 4 checks passed. They pin the manifest version 0.2.0, the required QuestieDB dependency, the optional FlareUI dependency, and the absence of Guidelime and Questie from the manifest and the shipped files. |
| `sh tests/bridge.sh` | 5 checks passed. The built plugin loads its own manifest file list after the core, reconciles at login and reports ready, surfaces in the settings guide list, supplies verbatim advice through `GetHints`, and a plugin that stops declaring the marker is named in the status. |
| Python `test_build_guide.py` and `test_release.py` | 30 tests passed (Python 3.12.3). They cover the plugin builder and the release tool: manifest fields, the wrapper, the license copy, the catalog rules, the gate failures as exit codes, and the license gate of the release. |

The extraction audit now runs as a gate inside every guide plugin build, over the built plugin itself. Every build writes a per-guide report, `extraction-audit.json`, into the plugin folder, and the release and CI logs print it. The recorded corpus results still come from the #11 audit round, where we reproduced them. For TUG 1.28, the audit found 903 advice records, zero safety findings, and 23 of 127 candidate lines withheld. For Bethink 1.0.5, it found 2144 records, zero safety findings, and 362 of 828 lines withheld. See the [extraction audit](tug-extraction-audit.md), which includes a correction note and is kept as historical evidence. A synthetic regression test in `tests/guide.lua` or `tests/hints.lua` covers each fix that the audit drove. Those suites passed in this round.

### Acceptance-table traceability

Each scenario row in the acceptance table of the specification maps to offline evidence below. "Offline" means that a test exercises the observable behavior at the boundary of the addon, with substitute interfaces for the client, the provider, and the tracker. "Partial" means that the offline tests exercise only a part of the expected behavior. The note says which part. The suite labels are the names that follow `ok - ` in the output of the suites.

| Scenario | Offline evidence | Coverage |
| --- | --- | --- |
| Player accepts quests out of order or skips guide steps | `hints`: "unaccepted linked advice retains its association". `guide`: "chapter and step applicability, explicit association and uncertainty". The addon keeps no state of the guide step. It derives hints from the quest log and the context only. | Offline |
| Player revisits a zone, and advice comes from any eligible chapter | `guide`: "chapter and step applicability..." (three registered chapters all contribute) | Offline |
| Focus changes through native or Flare focus controls | `hints`: "focus and accepted quests are ranked only after local relevance". `runtime`: the context test asserts `focusedQuestID` from the supertrack API. The addon calls no API that sets focus. We verified this by code inspection: the addon only reads `C_SuperTrack.GetSuperTrackedQuestID`. | Partial. Whether the focus control of FlareUI sets the native supertrack is client behavior. See IC-9. |
| Player opens details, watches a quest, or pins a tracker row | Structural evidence only. The addon reads focus only from `C_SuperTrack.GetSuperTrackedQuestID`. It never treats watch state, selection state, or pin state as a focus signal. The quest-watch event only triggers a refresh. No offline test drives these client actions. | Partial. See IC-10. |
| Accepted quest is not watched | `hints`: "unwatched quest hidden by header ranks second". A quest behind a collapsed header still ranks by acceptance. | Offline |
| Alliance-only, Horde-only, and shared fixtures | `guide`: faction chapters are excluded for the opposite faction, and a missing faction is uncertain. `hints`: "provider race restrictions retain shared quests". | Offline |
| A known class or race restriction fails | `guide`: conditions of class, race, profession, and possession are excluded when they fail. `hints`: "class and large race masks respect character restrictions". | Offline |
| Useful prose has no reliable quest association | `guide`: unlinked preparation is a zone tip. `hints`: "unassociated local advice is identified". | Offline |
| A future or remote quest needs supplies that a local vendor sells | `hints`: "local preparation for a remote focused quest" | Offline |
| A remote focus has no locally useful advice | `hints`: "known remote advice is excluded". Remote advice for the focused quest does not fill the view. | Offline |
| Ranking candidates differ at each priority | `hints`: focus ranks first, and acceptance ranks second. Also "current map quest start proximity", "proximity and focus take precedence over lower ranking signals", "active and ready phases do not reuse obsolete locations", and "provider turn-in spawns give ready quests a local distance signal". The differential tests are "focused outranks accepted with both signals competing", "accepted outranks a nearer quest start", "giver proximity outranks a nearer objective", "target proximity outranks level proximity", and "locality tiers order equal distance signals". | Offline. Ranking in a real client (map hierarchy, real distances, focus behavior) still needs IC-7. |
| Player moves slightly within a distance band | `hints`: "small movement does not shuffle hints". `ui`: "moving between distance bands refreshes visible hints" (the complement). | Offline |
| Quest levels are equally far above and below | `hints`: "equally distant levels retain stable source order" | Offline |
| Coordinates or metadata are missing | `hints`: "unlocated quest advice does not imply local usefulness", "unmapped name mismatch remains uncertain", "unclassified waypoints do not establish turn-in proximity", and the missing ZoneDB bridge. `runtime`: uncertainty for a collapsed log. | Offline |
| Player has fewer supplies than the known minimum | `lifecycle`: "missing carried supplies", "supply shortage includes minimum..." | Offline |
| Player already carries the minimum | `lifecycle`: "carried supplies are retained" (keep wording, no repurchase) | Offline |
| Inventory rises above or falls below the minimum | `lifecycle`: the sequence acquire, keep, and retrieve across inventory states. Also "inventory wording preserves available-now ranking". | Offline |
| Bank ownership is reliable, unavailable, or stale | `lifecycle`: "bank contents are used only while freshly available". The bank is unknown until a slot change, and the addon makes no claim after the bank closes. | Offline (simulated bank events) |
| The same requirement appears repeatedly | `lifecycle`: "duplicate minimums consolidate". `hints`: "repeated identical requirements are not duplicated". | Offline |
| Separate consumable requirements are confirmed | `lifecycle`: "explicit independent consumptions sum with breakdown and recalculate" | Offline. The fixtures for combining are synthetic. The TUG audit found no qualifying pair in the listed files of the guide. |
| Independent consumption is not confirmed | `lifecycle`: "different quest requirements are not added without evidence" | Offline |
| A collection objective finishes before turn-in | `lifecycle`: "collecting quest items is not consumption", "ready-for-turn-in does not remove retention advice" | Offline |
| Quest is turned in, or supplies are consumed as intended | `lifecycle`: "actual turn-in removes fulfilled quest requirement", "intended consumption is observed before turn-in", "consumption observations recalculate combined minima" | Offline |
| Quest disappears because the player abandoned it | `lifecycle`: "leaving the log does not invent completion". `runtime`: "observed turn-in is distinct from abandonment". | Offline |
| Flight path is confirmed as learned | `lifecycle`: "positive flight discovery persists...", "named flight points follow the same learned/unknown wording", "flight identity can come from the guide location tag" | Offline |
| Flight-path history is incomplete | `lifecycle`: conditional wording, "unreachable nodes do not change learned history", "partial place-name matches remain unknown" | Offline |
| A new session restores character state | Within a session: dismissal and restore (`ui`), and observed turn-ins, flights, and preferences persist in the saved state while the session runs. The TOC declares the saved-variables key for each character. | Partial. The reload after logout and login, and the scoping per character, need the client. See IC-19 and IC-20. |
| Advice contains route references or story outcomes | `guide`: checks for route pressure, cross-route text, story ordering, narrative reasons, meaning, and excerpts. `hints`: "narrative outcome variants are withheld". | Offline. The screen is a heuristic. The corpus audit is the broader evidence. |
| More than three hints are relevant | `ui`: "compact view shows at most three hints", deliberate paging | Offline |
| Player activates a hint or a supporting link | `ui`: "quest, map and verified item links use existing interfaces", expansion | Offline |
| Player dismisses a hint and later restores it | `ui`: dismissal and restore without damage to other hints | Offline (scoping per character as above) |
| No tips match | `ui`: "valid empty results hide advice and keep settings available" | Offline |
| Guide or provider is missing or incompatible | `runtime`: the statuses for a missing provider, a missing guide with the pointer to the releases page, and an incompatible provider, plus the reconciliation warnings. `ui`: "missing provider is distinct from an empty hint body". | Offline |
| A guide plugin is installed, chosen, or removed | `ui`: "the only installed guide is auto-selected and listed in settings", "several guides wait for an explicit choice instead of a default", "picking a row selects that guide for this character", "a removed guide falls back to the selection rule with a note". `bridge`: "the built plugin surfaces in the settings guide list". | Offline |
| The real Guidelime is optionally present | `manifest`: Guidelime and Questie are not declared. Python builder suite: the plugin manifest declares its dependency on the core addon only, and the plugin registers only with Efficient Quests. | Partial. Nobody tested real coexistence in a client. See IC-4. |
| Integrated tracker changes width, font, color, height, or position | `ui`: "Flare tracker geometry and backdrop", "tracker appearance and width changes are followed", font follow, "tracker scaling is reflected in the integrated width" | Offline (simulated tracker) |
| Integrated tracker hides or collapses | `ui`: "tracker visibility, placement, resize and fallback recovery" | Offline (simulated) |
| Space below the tracker is not enough | `ui`: "insufficient space below places the window above" | Offline (simulated). Clamping at the real edges of the screen is structural (`SetClampedToScreen`). See V-2. |
| Flare tracker is not available and later returns | `ui`: the fallback "without changing preference" and "integration resumes when the tracker returns" | Offline (simulated) |
| FlareUI is not installed | `runtime`: the addon loads with no optional addons at all. `ui`: settings open without FlareUI. | Offline |

### Offline gaps

- Two rows have offline evidence that is partly or wholly structural: "focus changes through native or Flare focus controls" and "opens details, watches, or pins". The addon never writes focus. It never reads watch state or pin state as focus. We verified this by code inspection and not by a behavioral test. No offline test can answer the open question, which is what the client and FlareUI do to the supertrack signal.
- The row for ranking precedence had a gap: no differential test had both signals compete. The fix round above closed this gap. IC-7 still covers the map hierarchy, the distances, and the focus behavior of the client.
- The row for a new session verifies persistence only within one session. It also verifies the declaration of the saved-variables key for each character. It does not verify a real reload, a real relogin, or a second character.
- The row for coexistence with Guidelime verifies only the manifest and the registration shape offline. The core declares no Guidelime dependency, and the plugin registers only with Efficient Quests. A client must still verify that the real Guidelime loads next to the plugin without a load cycle, a duplicate registration, or a namespace conflict.
- Every row that says "Offline (simulated ...)" substitutes a fake tracker, a fake bank, or a fake map hierarchy. These rows verify the logic of the addon. They do not verify the behavior or the appearance of the real interfaces.
- The fixtures for the combining row are synthetic. We know of no instance of the explicit-consumption format in the supported guide.

## In-client checks

Nobody did these checks. This environment has no Forever client. Each check is written so that a person with the client can run it and record the result. Record the build information one time in IC-1, and refer to it in the other checks. The expected observations state what the addon must do. If an observation is different, it is a finding. It is not a failure of the checklist.

An asterisk (\*) marks a value to fill in when you do the check.

### IC-1. Record the exact build

Before any other check, record this information:

- The game version from the title screen: \*
- The output of `/run print(GetBuildInfo())`, which gives the version, the build, the date, and the interface version: \*
- The output of `/dump select(4, GetBuildInfo())`, which gives the interface version alone: \*. If the command fails on this client, record the interface version that the addon list shows.
- The version of the QuestieDB addon (addon list or its TOC): \*
- The version of each installed guide plugin (the addon list or its TOC): \*
- The version of FlareUI, if it is installed: \*
- The version of Efficient Quests (its TOC, expected value 0.2.0): \*

Expected: you record the interface version, not only the game version that the title screen shows. The reference starting point of the specification is interface 16001. The displayed version 1.60.1 alone does not show that the API is compatible.

### IC-2. Load with only the required dependencies

Steps:

1. Install Efficient Quests, QuestieDB, and a guide plugin from the releases page. See the [installation guide](installation.md).
2. Do not install Guidelime, Questie, or FlareUI.
3. Enable only those three addons.
4. Log in on a character in a low-level questing zone that the guide covers.

Expected: no Lua errors occur at login. The command `/eq status` reports `Ready.` Relevant hints appear in a compact standalone window. The guide plugin loads only the files that its own TOC lists.

Result: \*

### IC-3. QuestieDB contract and capabilities

Steps: With QuestieDB enabled and ready, check these capability paths:

1. Find a hint for an item whose tag ID and name match QuestieDB. When you expand the hint, it must show an Item button, and the tooltip must show the item. An item whose guide ID and name disagree must show no item link and must stay conditional.
2. Advice for a quest that your race or class cannot take must not appear. Shared quests must appear for both factions. Check one Alliance character and one Horde character.
3. For a quest that is ready to hand in, the advice must rank by turn-in distance. See IC-8.

Then disable QuestieDB, reload, and run `/eq status`.

Expected: With QuestieDB present, the behaviors above hold and the status is `Ready.` With QuestieDB disabled, the status says that QuestieDB is missing, the hint body is hidden, and the settings still open. With an unsupported QuestieDB version (if you have one), the status reports it as incompatible.

Result: \*

### IC-4. Coexistence with the real Guidelime

Steps:

1. Install and enable the real Guidelime with one of its own guides, next to Efficient Quests, QuestieDB, and the Efficient Quests guide plugin.
2. Reload.
3. Open the guide list of Guidelime.
4. Open the settings of Efficient Quests, category Guide.

Expected: No Lua errors occur and no load cycle occurs. The guide plugin does not appear in the list of Guidelime, because it registers only with Efficient Quests. The guide list of Efficient Quests still shows the plugin, and the hints work. The addon list shows the dependency of the guide plugin on Efficient Quests. Guidelime works with its own guide at the same time.

Result: \*

### IC-5. Guide loading without Guidelime

IC-2 covers this check. Record the result here if you installed Guidelime for IC-4 first. Disable Guidelime, keep the guide plugin, and reload.

Expected: The guide plugin still registers with Efficient Quests, and `/eq status` stays `Ready.`

Result: \*

### IC-6. Quest IDs and phases

Steps: Find advice that links to each of these quests: (a) a quest that you have not accepted, (b) an accepted quest with unfinished objectives, and (c) a quest that is ready to hand in. For each one, expand the hint and click Quest.

Expected: For all three, the quest link opens the correct quest in the quest log of the game. Technique advice for a quest disappears when its objectives are finished (phase "ready"). Supply retention advice stays until hand-in. If you drop a quest from the log without a turn-in, the quest gets no completion history. Its advice remains. After a real turn-in, the addon removes the advice.

Result: \*

### IC-7. Ranking precedence in the client

Steps: Stand in a zone that has several quests with hints. Change one of these items at a time:

- Which quest is supertracked. Use `/run print(C_SuperTrack.GetSuperTrackedQuestID())` to confirm the focus.
- Which quests are accepted.
- Your distance to a quest giver.
- Your distance to an objective.
- The levels of the nearby quests.

Expected: Advice for the focused quest ranks first. Advice for an accepted quest ranks next. Then the advice is ordered by the distance to the location of the quest in its current phase: the start if the quest is unaccepted, the objective if it is active, and the turn-in if it is ready. Then the order follows the closeness of the level. A small movement (a few steps) does not reorder the hints. A substantial movement (hundreds of yards) does.

Result: \*

### IC-8. Turn-in coordinates from QuestieDB

Steps: Make a quest ready to hand in, so that its turn-in NPC or object is in your current zone. Compare the location that the addon implies (which advice ranks as near or far) with the turn-in marker of the quest on the map. Use at least two ready quests, one near and one far.

Expected: Advice for a ready quest ranks by the real turn-in location. A finisher in another zone gives no distance order. It does not give a wrong one.

Result: \*

### IC-9. Focus through the game and through FlareUI

Steps:

1. Focus a quest in the way of the game itself. For example, click the quest in the quest log so that it becomes supertracked.
2. With FlareUI installed, use the focus action of FlareUI on another quest.

Expected: Both paths change which advice ranks first, and the advice shows the relevance label "focused quest". The reason is that the focus action of FlareUI drives the same native supertrack signal. Efficient Quests never changes the supertracked quest. Run `/run print(C_SuperTrack.GetSuperTrackedQuestID())` before and after you click hints, page, dismiss, and open the settings. The value must not change.

Result: \*

### IC-10. Details, watch, and pin do not redefine focus

Steps: Focus a quest. Then do each of these actions: (a) open the details of another quest in the log, (b) watch or unwatch quests, and (c) pin or unpin a row in the tracker of FlareUI (its non-focus control, if it is separate). After each action, check the supertracked quest and the order of the hints.

Expected: None of these actions changes which quest the addon treats as focused. The supertrack value changes only when you use a focus control.

Result: \*

### IC-11. Inventory semantics

Steps: Find supply advice that has a known item and a known minimum. Buy items until you reach the minimum, and then go above it. Then consume or sell items until you are below it.

Expected: Below the minimum, the hint says to acquire the item, and it names the shortage and the total minimum. At or above the minimum, the hint says to keep at least the minimum and not to sell or discard it. The counts update as your bags change, without a relogin.

Result: \*

### IC-12. Bank semantics

Steps: Leave some of the required items in the bank. Open the bank window and wait until its contents load.

Expected: While the bank window is open and the addon has seen its contents, the hint separates retrieval from buying ("Retrieve N ..."). Before the contents load, and after the bank window closes, the hint makes no claim about the bank contents. The carried figure of the hint comes from `GetItemCount(item)`, which counts bags only. The bank figure is the total count including the bank, minus the carried count. The addon reads it only while the bank contents are fresh.

Result: \*

### IC-13. Intended consumption

Steps: Accept a quest whose supply, as the guide links it, an item objective consumes. Use the items on the objective. Watch the carried count fall as the objective progresses.

Expected: When the objective progresses and the carried count falls together, the addon removes or recalculates the requirement of that quest. If you sell items without objective progress, the addon does not remove the requirement. If you accept a repeatable quest again, the requirement returns.

Result: \*

### IC-14. Coordinates and zone matching

Steps: Travel between these places: a zone that the guide names for an advice line, a different zone-level zone, and a subzone of the current zone.

Expected: Advice for the current zone, or for its parent or child maps, appears. Advice for a separate zone does not appear. A named subzone resolves through the map hierarchy of the client. When the advice zone matches the current zone, the Map button opens the world map on the current zone. Missing coordinates never produce a distance order.

Result: \*

### IC-15. Movement polling and band stability

Steps: Stand near a quest giver or an objective. Take a few steps and watch the order of the hints. Then travel a few hundred yards and watch the order again.

Expected: Small movements leave the order stable. When you cross a real distance band (roughly 250 yards), the order refreshes within about half a second. The hints do not refresh all the time while you stand still.

Result: \*

### IC-16. Taxi observations

Steps: Find "get the flight path" advice for a point in your current zone. Open the taxi map of a flight master in that zone. Also record the output of `/dump Enum.FlightPathState`, so that you know the state names of this build.

Expected:

- With unknown history, the advice says "(if you have not already learned it)".
- When the taxi map shows the named node as known or reachable on the current map, the addon suppresses the acquisition reminder. It stays suppressed after the map closes.
- An unreachable node, or a node that is absent, does not change the wording.
- If the `FlightPathState` enum of this build defines a state that means unlearned or undiscovered, a node in that state keeps its reminder without the conditional hedge. When you learn the path later, the reminder is suppressed.
- If the build expresses unlearned nodes in any other way, those observations stay unknown and the wording stays conditional. This is the safe direction.
- If you learn a new path while the map is open, the addon observes it without a reopen of the map.

Result: \*

### IC-17. Flight suppression scope

Steps: Make sure that the addon suppresses the reminder only for the exact named path on the current map. A place with a similar name ("X Outpost" versus "X") must not suppress the reminder. A different named location in the same sentence must not suppress it. Travel advice that only uses a known path must not be suppressed.

Result: \*

### IC-18. Setup status states in the client

Steps: Make each of these broken setups one time:

1. Uninstall QuestieDB.
2. Remove every guide plugin.
3. Disable the selected guide plugin and reload. The plugin stays installed but disabled.
4. Delete the folder of the selected guide plugin and reload.

Expected: The command `/eq status` reports each case in its own way: missing provider, no guide plugin registered with the pointer to the releases page, the named plugin that did not register, and the fallback selection after removal. The settings name the removed choice. The status never presents a setup problem as "no relevant tips". The valid empty state stays separate: the body is hidden, the settings are accessible, and no status message appears. After you restore the missing piece, the status returns to `Ready.`

Result: \*

### IC-19. Persistence across sessions

Steps: Dismiss one hint, learn one flight path, and turn in one quest. Set the display mode and the spacing, and drag the standalone window. Then run `/reload`. Then log out and log in again.

Expected: After the reload and after the relogin, the addon restores the dismissal, the flight observation, the turn-in history, and the display preferences for that character.

Result: \*

### IC-20. Character scoping

Steps: On the same account, log in with a second character.

Expected: The second character starts with its own dismissals, flight observations, and display preferences. When you return to the first character, its state is unchanged.

Result: \*

### IC-21. Flare presentation in the client

Steps: Install FlareUI and set the display mode to FlareUI. In a live session, verify each of these items:

- The hint window anchors below the tracker and matches its width.
- The configured spacing changes the gap.
- When the tracker collapses or hides, manually or through its automatic behavior, the hints hide.
- When you move the tracker low enough, the hints move above it.
- When you disable FlareUI or its tracker, the addon falls back to the standalone window. When the tracker returns, the integration resumes.
- If you drag the window while it is integrated, the window does not move, and the standalone position stays the same.

Result: \*

## Visual checks

Nobody did these checks. They compare pixels on a screen, and no screen was available. Each check is written for a person with the client. For every observation, record the UI scale and the placement of the tracker. IC-1 records the build.

### V-1. Integrated window versus the FlareUI tracker

Steps: Set the display mode to FlareUI. At each relevant UI scale, put the tracker in its default position. Compare the hint window directly with the tracker above it. Use at least the lowest scale, the default scale, and the highest scale that your client allows.

Expected: The effective width, the fonts and text sizes, the text colors, the backdrop, and the border styling match. They still match after you change the width, the font, or the color settings of the tracker. Nothing overlaps or clips at any scale.

Record for each scale: the scale \*, whether the width matches (yes or no), whether the fonts match (yes or no), whether the colors match (yes or no), and issues \*.

### V-2. Tracker placements and screen bounds

Steps: At the default UI scale, move the FlareUI tracker to each corner that it supports and toward the bottom edge of the screen.

Expected: In every placement, the hints stay fully on screen. They sit above the tracker when there is no room below. They never overlap other interface elements that you use.

Record for each placement: the placement \*, whether the hints are on screen (yes or no), and issues \*.

### V-3. Settings panel versus the FlareUI panel

Steps: Open the settings of Efficient Quests and the own settings panel of FlareUI side by side.

Expected: The category navigation is on the left, the controls are in the main area, and the explanatory text is short. The style is consistent with the panel of FlareUI, so the two panels look like one family. Every setting works: guide selection, display mode, width, tracker spacing, and restore of dismissed hints.

Result: \*

### V-4. No unsolicited attention

Steps: Play a normal session with the window visible, in both standalone mode and integrated mode. The session must include at least one full questing loop: accept a quest, buy supplies, travel, complete the quest, and turn it in.

Expected: There are no sounds, no flashing, no popups, no automatic hint rotation, and no automatic scrolling. Hints change only when the underlying state changes. Expansion, paging, and scrolling happen only when you click or use the mouse wheel.

Result: \*

### V-5. Standalone appearance

Steps: Disable FlareUI and check the standalone window. Make sure of these points: the window shows at most three hints, long hints grow and do not clip, the body hides when no hint is relevant while the settings stay reachable, and the compact view stays readable at each UI scale.

Result: \*

## Known limits

These limits stay true for any result of the checklists:

- The extraction is a heuristic. The [extraction audit](tug-extraction-audit.md) lists the withheld categories and the known examples that need review. We do not claim support for arbitrary guides.
- The supported guide has no known instance of combined independent consumption. The tests for it are synthetic.
- The survival of a quest through turn-in, and the difference between flight acquisition and flight travel, partly depend on the wording of the guide. They do not depend on observation of gameplay.
- QuestieDB does not make the prose of the guide reliable. The shopping list of TUG has at least one mismatch of item identity. Such items stay conditional and the addon does not link them.
- The offline suites substitute the client, the provider, and FlareUI. When they pass, this does not show native compatibility or visual quality. The checklists above exist to show these.
