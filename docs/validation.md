# Release validation record

This record reports what was verified offline for the MVP and what a person with the game client still needs to check. It follows the validation requirements in the [MVP specification](specs/efficient-quests-mvp.md).

Status: **offline verification complete; in-client and visual checks not performed.** The MVP is not a validated release until the checklists below are executed and their results recorded.

- Offline results at: commit `8cf66ab` (tip of `integration/efficient-quests-mvp`), on 2026-11-10. This record was written on branch `ticket/10-release-validation` from that commit.
- Offline result: all five Lua behavioral suites and both Python adaptation tests pass (103 Lua checks, 2 Python tests).
- Nothing in this record was checked against a running Forever client, a real QuestieDB installation, a real guide installation, or FlareUI on screen. Sections "In-client checks" and "Visual checks" are checklists, not results.

## What earlier rounds left open

Each implementation round recorded which checks it could not perform. Consolidated, they are:

- The runtime scaffold (#2), adaptation tool (#3), and provider adapter (#4) were never loaded by an actual Forever build. Loading, provider capabilities, and coexistence with genuine Guidelime are unverified in a client.
- Extraction (#5, #11) is a heuristic filter. It was audited against the full installed TUG 1.28 and Bethink 1.0.5 corpora with zero safety findings, but coverage of arbitrary prose is not claimed, and withheld categories remain (see the [extraction audit](tug-extraction-audit.md)).
- Ranking (#6, #12): actual Forever map hierarchy and area names, `GetQuestsOnMap` and `ReadyForTurnIn` behavior, `GetMapWorldSize` values used for distance banding, QuestieDB spawn-conversion placement, and movement polling need a client.
- Supplies and lifecycle (#7, #13): actual bank and taxi semantics, and the real quest-log objective field shapes, were checked offline against documentation only. Turn-in survival and flight classification partly rest on guide wording.
- The standalone window (#8): exact layout, links, and visual fidelity need a client.
- FlareUI integration (#9): actual tracker behavior and visual fidelity are unverified in-game.
- Documentation (#14) identifies client and visual validation as unperformed; this record is that tracked validation work (#10).

## Offline verification

### Commands and results

The host has no Lua interpreter, so the Lua suites ran in Docker with Lua 5.1.5 (image `nickblah/lua:5.1`). On a host with Lua installed, the equivalent commands are the `lua5.1` forms in the [test guide](../tests/README.md).

From the worktree root, in this round:

```sh
docker run --rm -v /tmp/opencode/eq-wt-10:/w -w /w nickblah/lua:5.1 lua tests/runtime.lua
docker run --rm -v /tmp/opencode/eq-wt-10:/w -w /w nickblah/lua:5.1 lua tests/guide.lua
docker run --rm -v /tmp/opencode/eq-wt-10:/w -w /w nickblah/lua:5.1 lua tests/hints.lua
docker run --rm -v /tmp/opencode/eq-wt-10:/w -w /w nickblah/lua:5.1 lua tests/lifecycle.lua
docker run --rm -v /tmp/opencode/eq-wt-10:/w -w /w nickblah/lua:5.1 lua tests/ui.lua
python3 -m unittest discover -s tests -p 'test_*.py'
```

Results (every command exited 0, no failures):

| Command | Result |
| --- | --- |
| `tests/runtime.lua` | 11 checks passed. Setup status without optional addons, context collection, native focus, collapsed-log uncertainty, unadapted-guide status, turn-in versus abandonment, professions. |
| `tests/guide.lua` | 28 checks passed. Registration, chapter applicability, associations, uncertainty, route and spoiler screening, reviewed TUG formats, flight and technique extraction. |
| `tests/hints.lua` | 28 checks passed. Local relevance tiers, focus and acceptance ranking, marker and turn-in proximity, symmetric levels, restrictions, stability, timing. |
| `tests/lifecycle.lua` | 26 checks passed. Acquire/keep wording, bank freshness, consumption observation, turn-in, flight observations, aggregation and deduplication. |
| `tests/ui.lua` | 10 checks passed. Compact view, paging, links, dismissal and restore, empty state, display settings, simulated Flare tracker geometry and fallback. |
| Python `test_adapt_guide.py` | 2 tests passed (Python 3.12.3). Repeatable adaptation and update detection. |

The extraction audit (`tools/audit_extraction.lua`) was **not** rerun in this round: it reads an installed third-party guide package, and no package is committed to the repository. The recorded results — TUG 1.28: 903 advice records, zero safety findings, 23 of 127 candidate lines withheld; Bethink 1.0.5: 2144 records, zero safety findings, 362 of 828 withheld — come from the #11 audit round and were reproduced there; see the [extraction audit](tug-extraction-audit.md), including its correction note. Each audit-driven fix is covered by a synthetic regression in `tests/guide.lua` or `tests/hints.lua`, and those suites are what passed above.

### Acceptance-table traceability

Every scenario row in the specification's acceptance table maps to offline evidence below. "Offline" means the observable behavior is exercised at the addon boundary with substituted client, provider, and tracker interfaces. "Partial" means only part of the expected behavior is exercised offline; the note says exactly which part. Suite labels are the `ok - ...` check names the suites print.

| Scenario | Offline evidence | Coverage |
| --- | --- | --- |
| Accepts quests out of order or skips guide steps | `hints`: "unaccepted linked advice retains its association"; `guide`: "chapter and step applicability, explicit association and uncertainty". The addon keeps no guide-step state; hints derive from the quest log and context only. | Offline |
| Revisits a zone; advice from any eligible chapter | `guide`: "chapter and step applicability..." (three registered chapters all contribute) | Offline |
| Focus changes through native/Flare focus controls | `hints`: "focus and accepted quests are ranked only after local relevance"; `runtime`: context test asserts `focusedQuestID` from the supertrack API. The addon calls no focus-setting API (verified by code inspection: only `C_SuperTrack.GetSuperTrackedQuestID` is read). | Partial — FlareUI's focus control actually setting the native supertrack is client behavior; see IC-9. |
| Opens details, watches a quest, or pins a tracker row | Structural only: the addon reads focus solely from `C_SuperTrack.GetSuperTrackedQuestID` and never treats watch, selection, or pin state as a focus signal (the quest-watch event only triggers a refresh). No offline test drives these client actions. | Partial — see IC-10. |
| Accepted quest is not watched | `hints`: "unwatched quest hidden by header ranks second" (quest hidden behind a collapsed header still ranks by acceptance) | Offline |
| Alliance-only, Horde-only, shared fixtures | `guide`: faction chapters excluded for the opposite faction, missing faction uncertain; `hints`: "provider race restrictions retain shared quests" | Offline |
| Known class/race restriction fails | `guide`: class, race, profession and possession conditions excluded when failed; `hints`: "class and large race masks respect character restrictions" | Offline |
| Useful prose has no reliable quest association | `guide`: unlinked preparation is a zone tip; `hints`: "unassociated local advice is identified" | Offline |
| Future or remote quest needs supplies sold locally | `hints`: "local preparation for a remote focused quest" | Offline |
| Remote focus has no locally useful advice | `hints`: "known remote advice is excluded" (remote advice for the focused quest does not fill the view) | Offline |
| Ranking candidates differ at each priority | `hints`: focus first, accepted second; "current map quest start proximity"; "proximity and focus take precedence over lower ranking signals"; "active and ready phases do not reuse obsolete locations"; "provider turn-in spawns give ready quests a local distance signal" | Partial — no differential test isolates giver-before-target or accepted-before-giver precedence with both signals present; that order exists only in the comparator. See IC-7. |
| Player moves slightly within a distance band | `hints`: "small movement does not shuffle hints"; `ui`: "moving between distance bands refreshes visible hints" (the complement) | Offline |
| Quest levels equally far above and below | `hints`: "equally distant levels retain stable source order" | Offline |
| Coordinates or metadata are missing | `hints`: "unlocated quest advice does not imply local usefulness", "unmapped name mismatch remains uncertain", "unclassified waypoints do not establish turn-in proximity", missing ZoneDB bridge; `runtime`: collapsed-log uncertainty | Offline |
| Fewer supplies than the known minimum | `lifecycle`: "missing carried supplies", "supply shortage includes minimum..." | Offline |
| Already carries the minimum | `lifecycle`: "carried supplies are retained" (keep wording, no repurchase) | Offline |
| Inventory rises above or falls below the minimum | `lifecycle`: the acquire/keep/retrieve sequence across inventory states; "inventory wording preserves available-now ranking" | Offline |
| Bank ownership reliable, unavailable, or stale | `lifecycle`: "bank contents are used only while freshly available" (unknown until slot change; not asserted after close) | Offline (simulated bank events) |
| Same requirement appears repeatedly | `lifecycle`: "duplicate minimums consolidate"; `hints`: "repeated identical requirements are not duplicated" | Offline |
| Separate consumable requirements confirmed | `lifecycle`: "explicit independent consumptions sum with breakdown and recalculate" | Offline — the aggregation fixtures are synthetic; the TUG audit found no qualifying pair in the guide's listed files. |
| Independent consumption unconfirmed | `lifecycle`: "different quest requirements are not added without evidence" | Offline |
| Collection objective finishes before turn-in | `lifecycle`: "collecting quest items is not consumption", "ready-for-turn-in does not remove retention advice" | Offline |
| Quest turned in or supplies consumed as intended | `lifecycle`: "actual turn-in removes fulfilled quest requirement", "intended consumption is observed before turn-in", "consumption observations recalculate combined minima" | Offline |
| Quest disappears because it was abandoned | `lifecycle`: "leaving the log does not invent completion"; `runtime`: "observed turn-in is distinct from abandonment" | Offline |
| Flight path confirmed learned | `lifecycle`: "positive flight discovery persists...", "named flight points follow the same learned/unknown wording", "flight identity can come from the guide location tag" | Offline |
| Flight-path history incomplete | `lifecycle`: conditional wording, "unreachable nodes do not change learned history", "partial place-name matches remain unknown" | Offline |
| New session restores character state | In-session: dismissal/restore (`ui`) and observed turn-ins, flights, and preferences persist in saved state while the session runs; the per-character saved-variables key is declared in the TOC. | Partial — logout/login reload and per-character scoping need the client; see IC-19, IC-20. |
| Advice contains route references or story outcomes | `guide`: route-pressure, cross-route, story-ordering, narrative-reason, meaning and excerpt checks; `hints`: "narrative outcome variants are withheld" | Offline — the screen is heuristic; the corpus audit is the broader evidence. |
| More than three relevant hints | `ui`: "compact view shows at most three hints", deliberate paging | Offline |
| Hint or supporting link activated | `ui`: "quest, map and verified item links use existing interfaces", expansion | Offline |
| Hint dismissed and later restored | `ui`: dismissal and restore without corrupting other hints | Offline (character scoping as above) |
| No tips match | `ui`: "valid empty results hide advice and keep settings available" | Offline |
| Guide/provider missing or incompatible | `runtime`: missing provider, missing guide, unadapted guide, incompatible provider statuses; `ui`: "missing provider is distinct from an empty hint body" | Offline |
| Guide updates replace its adaptation | Python: "check detects updated guide and reapplication" | Offline |
| Genuine Guidelime optionally present | Python: the adapted TOC keeps `OptionalDeps: Guidelime` and the registration files dual-dispatch to both addons (adapter source, `tools/adapt_guide.py`) | Partial — actual coexistence in a client is untested; see IC-4. |
| Integrated tracker changes width, font, color, height, position | `ui`: "Flare tracker geometry and backdrop", "tracker appearance and width changes are followed", font follow, "tracker scaling is reflected in the integrated width" | Offline (simulated tracker) |
| Integrated tracker hides or collapses | `ui`: "tracker visibility, placement, resize and fallback recovery" | Offline (simulated) |
| Space below tracker insufficient | `ui`: "insufficient space below places the window above" | Offline (simulated); on-screen clamping at real screen edges is structural (`SetClampedToScreen`), see V-2. |
| Flare tracker unavailable and later returns | `ui`: fallback "without changing preference", "integration resumes when the tracker returns" | Offline (simulated) |
| FlareUI is not installed | `runtime`: the addon loads with no optional addons at all; `ui`: settings open without FlareUI | Offline |

### Offline gaps, precisely

- Rows "focus changes through native/Flare focus controls" and "opens details, watches, or pins" are the only rows whose offline evidence is partly or wholly structural. The addon never writes focus and never reads watch or pin state as focus; that is verified by code inspection, not by a behavioral test, because the remaining question (what the client and FlareUI do to the supertrack signal) cannot be answered offline.
- The ranking-precedence row has no differential test for giver-before-target or accepted-before-giver ordering with both signals competing. The order is implemented in one comparator and each signal is tested separately.
- The new-session row verifies persistence only within a session and the per-character saved-variables declaration. It does not verify a real reload, relogin, or a second character.
- The Guidelime-coexistence row verifies the adaptation output only. Load order, duplicate dispatch, and namespace behavior with a genuine Guidelime need a client.
- All "Offline (simulated ...)" rows substitute a fake tracker, bank, or map hierarchy. They verify the addon's logic, not the real interfaces' behavior or appearance.
- The aggregation row's fixtures are synthetic. No supported-guide instance of the explicit-consumption format is known.

## In-client checks

**None of these checks were performed.** There is no Forever client in this environment. Each check below is written so a person with the client can execute it and record the result. Record the build information once in IC-1 and reference it. Expected observations state what the addon should do; if an observation differs, that is a finding, not a failure of the checklist.

An asterisk (*) marks values to fill in when the check is performed.

### IC-1. Record the exact build

Record, before any other check:

- Game version from the title screen: \*
- `/run print(GetBuildInfo())` — version, build, date, interface version: \*
- `/dump select(4, GetBuildInfo())` — interface version alone: \* (if the command errors on this client, record the interface version shown in the addon list instead)
- QuestieDB addon version (addon list or its TOC): \*
- TUG guide package version (its TOC): \*
- FlareUI version, if installed: \*
- Efficient Quests version (its TOC; expect 0.1.0): \*

Expected: the interface version is recorded, not just the displayed game version. The specification's reference starting point is interface 16001; a displayed version of 1.60.1 alone does not establish API compatibility.

### IC-2. Load with only the required dependencies

Steps: install Efficient Quests, QuestieDB, and the TUG guide, and adapt the guide with the local tool (see the [installation guide](installation.md)). Do **not** install Guidelime, Questie, or FlareUI. Enable only those three addons. Log in on a character in a low-level questing zone with the guide adapted for it.

Expected: no Lua errors on login. `/eq status` reports `Ready.` Relevant hints appear in a compact standalone window. The guide package loads only the files its own TOC lists.

Result: \*

### IC-3. QuestieDB contract and capabilities

Steps: with QuestieDB enabled and ready, check the observable capability paths:

1. A hint for an item whose tag ID and name match QuestieDB shows an **Item** button when expanded, and the tooltip shows the item. An item whose guide ID and name disagree shows no item link and stays conditional.
2. Advice for a quest your race or class cannot take does not appear; shared quests appear for both factions (check one Alliance and one Horde character).
3. With a quest ready to hand in, its advice ranks by turn-in distance (see IC-8).

Then disable QuestieDB, reload, and run `/eq status`.

Expected: with QuestieDB present, the above behaviors hold and status is `Ready.` With it disabled, status says QuestieDB is missing, the hint body is hidden, and settings still open. With an unsupported QuestieDB version (if available), status reports it as incompatible.

Result: \*

### IC-4. Genuine Guidelime coexistence

Steps: install and enable the real Guidelime alongside the adapted guide, Efficient Quests, and QuestieDB. Reload. Open Guidelime's guide list and Efficient Quests' settings (Guide category).

Expected: no Lua errors and no load cycle. The guide appears once in Guidelime's own list and is selectable in Efficient Quests. Both addons receive the guide's registration exactly once (no duplicated guides in either list). The addon list shows the guide's dependency changed to Efficient Quests with Guidelime optional.

Result: \*

### IC-5. Guide loading without Guidelime present

(Covered together with IC-2; record here if you installed Guidelime for IC-4 first.) Disable Guidelime, keep the adapted guide, reload.

Expected: the guide still registers with Efficient Quests; `/eq status` stays `Ready.`

Result: \*

### IC-6. Quest IDs and phases

Steps: find advice linked to (a) a quest you have not accepted, (b) an accepted quest with unfinished objectives, and (c) a quest ready to hand in. For each, expand the hint and click **Quest**.

Expected: the quest link opens the correct quest in the game's quest log for all three. Technique advice for a quest disappears when its objectives are finished (phase "ready") while supply retention advice stays through hand-in. A quest dropped from the log without a turn-in does not gain completion history: its advice remains, and after a real turn-in it is removed.

Result: \*

### IC-7. Ranking precedence, in client

Steps: stand in a zone with several hinted quests. Vary, one at a time: which quest is supertracked, which quests are accepted, your distance to a quest giver, your distance to an objective, and the levels of nearby quests (use `/run print(C_SuperTrack.GetSuperTrackedQuestID())` to confirm focus).

Expected: focused-quest advice ranks first; accepted-quest advice next; then advice ordered by distance to the quest's current-phase location (start if unaccepted, objective if active, turn-in if ready); then level proximity. Small movement (a few steps) does not reorder hints; moving a substantial distance (hundreds of yards) does.

Result: \*

### IC-8. Turn-in coordinates from QuestieDB

Steps: make a quest ready to hand in whose turn-in NPC or object is in your current zone. Compare the addon's implied location (which advice ranks as near/far) with the quest's turn-in marker on the map.

Expected: ready-quest advice ranks by the real turn-in location. A finisher in another zone produces no distance ordering, not a wrong one. Verify with at least two ready quests, one near and one far.

Result: \*

### IC-9. Focus through the game and FlareUI

Steps: focus a quest the game's own way (for example, clicking it in the quest log so it becomes supertracked). Then, with FlareUI installed, use FlareUI's focus action on another quest.

Expected: both paths change which advice ranks first with the "focused quest" relevance label, because FlareUI's focus action drives the same native supertrack signal. Efficient Quests itself never changes the supertracked quest: before and after clicking hints, paging, dismissing, and opening settings, `/run print(C_SuperTrack.GetSuperTrackedQuestID())` is unchanged.

Result: \*

### IC-10. Details, watch, and pin do not redefine focus

Steps: with a quest focused, (a) open another quest's details in the log, (b) watch or unwatch quests, and (c) pin or unpin a row in FlareUI's tracker (its non-focus control, if separate). After each action, check the supertracked quest and the hint order.

Expected: none of these actions changes which quest the addon treats as focused, and the supertrack value changes only when you use a focus control.

Result: \*

### IC-11. Inventory semantics

Steps: find supply advice with a known item and minimum. Buy items until you reach, then exceed, the minimum; then consume or sell below it.

Expected: below the minimum the hint says to acquire and names the shortage and the total minimum; at or above it, the hint says to keep at least the minimum and not sell or discard. Counts update as your bags change without relogging.

Result: \*

### IC-12. Bank semantics

Steps: leave some of the required items in the bank. Open the bank window and wait for its contents to load.

Expected: while the bank window is open and its contents have been seen, the hint distinguishes retrieval from buying ("Retrieve N ..."). Before the contents load, and after the bank window closes, the hint does not claim knowledge of bank contents. The hint's carried figure comes from `GetItemCount(item)` (bags only); the bank figure is the total-including-bank count minus carried, read only while the bank contents are fresh.

Result: \*

### IC-13. Intended consumption

Steps: accept a quest whose guide-linked supply is consumed by its objective (an item-objective quest). Use the items on the objective and watch the carried count fall as the objective progresses.

Expected: when the objective progresses and the carried count falls together, that quest's requirement is removed or recalculated. Selling items without objective progress does not remove it. Reaccepting a repeatable quest restores the requirement.

Result: \*

### IC-14. Coordinates and zone matching

Steps: travel between a zone the guide names for an advice line, a different zone-level zone, and a subzone of the current zone.

Expected: advice for the current zone (or its parent/child maps) appears; advice for a separate zone does not. A named subzone resolves through the client's map hierarchy. The **Map** button opens the world map on the current zone when the advice zone matches it. Missing coordinates never produce distance ordering.

Result: \*

### IC-15. Movement polling and band stability

Steps: stand near a quest giver or objective, take a few steps, and watch hint order; then travel a few hundred yards and watch again.

Expected: small movements leave the order stable; crossing real distance bands (roughly 250 yards) refreshes the order within about half a second. No constant refreshing while standing still.

Result: \*

### IC-16. Taxi observations

Steps: find "get the flight path" advice for a point in your current zone. Open a flight master's taxi map in that zone.

Expected: with unknown history, the advice says "(if you have not already learned it)". When the taxi map shows the named node as known or reachable on the current map, the acquisition reminder is suppressed and stays suppressed after the map closes. An unreachable or absent node does not change the wording. Learning a new path while the map is open is observed without reopening.

Result: \*

### IC-17. Flight suppression scope

Steps: confirm suppression only for the exact named path on the current map: a similarly named place ("X Outpost" versus "X") or a different named location in the same sentence does not suppress the reminder; travel advice that merely uses a known path is not suppressed.

Result: \*

### IC-18. Setup status states in client

Steps: try each broken setup once: uninstall QuestieDB; install the guide without running the adaptation tool; restore the guide's original TOC after adaptation (simulating an update, with that guide still selected); disable the selected guide addon and reload.

Expected: `/eq status` reports each case distinctly (missing provider, needs adaptation, did not register) and never presents a setup problem as "no relevant tips". The valid empty state (body hidden, settings accessible, no status message) stays distinct. After re-running the adaptation tool's `check` and `adapt`, status returns to `Ready.`

Result: \*

### IC-19. Persistence across sessions

Steps: dismiss one hint, learn one flight path, turn in one quest, set the display mode and spacing, and drag the standalone window. Then `/reload`, then log out and back in.

Expected: after both reload and relogin, the dismissal, the flight observation, the turn-in history, and the display preferences are restored for that character.

Result: \*

### IC-20. Character scoping

Steps: on the same account, log into a second character.

Expected: the second character starts with its own dismissals, flight observations, and display preferences; the first character's state is untouched when you return to it.

Result: \*

### IC-21. Flare presentation in client

Steps: with FlareUI installed and display mode set to FlareUI, verify in a live session: the hint window anchors below the tracker and matches its width; the configured spacing changes the gap; collapsing or hiding the tracker (manually and through its automatic behavior) hides the hints; moving the tracker low enough forces hints above it; disabling FlareUI or its tracker falls back to the standalone window and resumes integration when it returns; dragging while integrated does not move the window or overwrite the standalone position.

Result: \*

## Visual checks

**None of these checks were performed.** They compare pixels on a screen; no screen was available. Each is written for a person with the client. Record the UI scale and tracker placement for every observation; IC-1 records the build.

### V-1. Integrated window versus FlareUI tracker

Steps: at each relevant UI scale (at minimum: the lowest, the default, and the highest your client allows), with display mode FlareUI, place the tracker in its default position and compare the hint window directly against the tracker above it.

Expected: matching effective width, fonts and text sizes, text colors, backdrop, and border styling, including after the tracker's width, font, or color settings change. Nothing overlaps or clips at any scale.

Record per scale: scale \*, width matches (yes/no), fonts (yes/no), colors (yes/no), issues \*.

### V-2. Tracker placements and screen bounds

Steps: move the FlareUI tracker to each corner it supports and towards the bottom edge of the screen, at the default UI scale.

Expected: hints stay fully on screen in every placement, above the tracker when there is no room below, and never overlap other interface elements you use.

Record per placement: placement \*, on screen (yes/no), issues \*.

### V-3. Settings panel versus FlareUI's panel

Steps: open Efficient Quests' settings and FlareUI's own settings panel side by side.

Expected: category navigation on the left, controls in the main area, and short explanatory text, styled consistently with FlareUI's panel so the two feel like one family. Every setting works: guide selection, display mode, width, tracker spacing, and restoring dismissed hints.

Result: \*

### V-4. No unsolicited attention

Steps: play a normal session (at least one full questing loop: accept, buy supplies, travel, complete, turn in) with the window visible in both standalone and integrated modes.

Expected: no sounds, no flashing, no popups, no automatic hint rotation, and no automatic scrolling. Hints change only when the underlying state changes. Expansion, paging, and scrolling happen only from your clicks and wheel.

Result: \*

### V-5. Standalone appearance

Steps: with FlareUI disabled, check the standalone window: at most three hints, long hints grow instead of clipping, the body hides with no relevant hints while settings stay reachable, and the compact view stays readable at each UI scale.

Result: \*

## Known limits

These limits stand regardless of the checklist results:

- Extraction is heuristic. Withheld categories and known examples needing review are listed in the [extraction audit](tug-extraction-audit.md). No support for arbitrary guides is claimed.
- Independent-consumption aggregation has no known instance in the supported guide; its tests are synthetic.
- Turn-in survival and the flight acquisition-versus-travel distinction partly rest on guide wording, not on gameplay observation.
- QuestieDB does not make guide prose reliable. Item identity mismatches (TUG's shopping list has at least one) stay conditional rather than linked.
- The offline suites substitute the client, provider, and FlareUI. Passing them does not establish native compatibility or visual fidelity, which is what the checklists above are for.
