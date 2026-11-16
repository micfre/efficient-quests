# Efficient Quests: standalone specification

Status: published as [issue #25](https://github.com/micfre/efficient-quests/issues/25) for review. This specification replaces the plugin-based design. It does not break the work into tickets. Ticket breakdown comes later.

Terms in this document:

- Addon: a program that extends the game interface.
- Step: one unit of the leveling guide, such as "Pick up a quest" or "Hand in a quest".
- Goal: one line inside a step, such as "Talk to an NPC" or "Kill 7 boars".
- Route: the ordered list of steps that the player follows.
- Path: the fixed order of quests from level 1 to level 60 that the addon uses as its default route.
- Stop: one item in a dungeon guide, such as a boss, a rare enemy, a quest spot, or an event.
- Skip list: the quests that the player chose to leave out.
- Follow mode: the mode in which the window shows the step of the quest that the player picked in the quest log.
- Waypoint: a marked place that the TomTom addon points to.

## Problem Statement

Players who level in World of Warcraft: Forever want a guide that tells them the next useful thing to do. They want to see what to pick up, what to do, and where to hand in. Today the player has two poor choices. The first is a guide addon that needs other addons and guide files that the player must install and keep in step. The second is a large all-in-one addon that also brings a map layer, a travel planner, an auction tool, party features, and many other parts that the player does not want.

The current Efficient Quests addon does not solve this. It reads guides in the Guidelime format and extracts hints from them. It does not give the player a route. It needs a separate guide plugin for each guide, and it depends on helper addons that it adapted. This design is hard to install and hard to keep correct.

## Solution

Efficient Quests becomes one standalone addon with a built-in quest engine. The engine is a port of the engine of the Trailwright addon, which is free software under GPL-3.0-or-later. The player installs one addon folder. Trailwright is not needed and is never installed.

The addon has two guides. The first is a leveling guide that shows one step at a time from the Path. The second is a dungeon guide that appears when the player enters a dungeon that the addon knows. Both guides show text. They do not draw on the map or the minimap.

The look matches FlareUI when FlareUI is installed. FlareUI is optional. The addon can use TomTom to point to a place when it knows the coordinates. TomTom and QuestieDB are also optional. Without them, the addon still works.

The addon leaves out the parts of Trailwright that the project does not want: anything that touches the map or the minimap, travel planning, auction features, gold tracking, party features, marking, professions, statistics, the 3D model, and the experience bar.

## User Stories

1. As a player, I want to install one addon folder, so that I do not have to install guide files or helper addons.
2. As a player, I want the addon to work without Trailwright, so that I do not need a second addon.
3. As a player, I want the addon to work without FlareUI, TomTom, and QuestieDB, so that I can use it on a simple setup.
4. As a player, I want to see one step at a time, so that I know the next thing to do.
5. As a player, I want the step headline to say Pick up, Do, Hand in, or Go to, so that I understand the kind of step at a glance.
6. As a player, I want each step to list its goals, so that I can see exactly what the step needs.
7. As a player, I want goal lines to tick themselves when I finish them, so that I do not have to track progress by hand.
8. As a player, I want kill and collect goals to show counts such as 3 of 7, so that I know how much is left.
9. As a player, I want a tip under "Talk to" lines, so that I can find an NPC who moves around.
10. As a player, I want to see the next few steps as well as the current step, so that I can plan ahead.
11. As a player, I want Back and Next buttons, so that I can look through the route.
12. As a player, I want the window to show "Step 3 / 15", so that I know my place in the route.
13. As a player who paged ahead, I want an easy way back to the current step, so that I do not lose my place.
14. As a player, I want the Path to start from my current level, so that I join the route where it fits my character.
15. As a player, I want quests that I already finished to leave the route, so that I do not repeat work.
16. As a player, I want quests that my race or class cannot take to leave the route, so that I only see quests that I can do.
17. As a player, I want grey quests to leave the route, so that I do not waste time on low rewards.
18. As a player, I want finished quests whose hand-in is near me to come first, so that I turn them in before I walk away.
19. As a player who is too low for the next quests, I want a "Level up to N" step, so that I know why no quest is shown.
20. As a player, I want quests in my log that are not on the Path to stay on the route until I hand them in, so that I do not lose work.
21. As a player, I want a quest that I abandon to stay out of the route, so that the addon respects my choice.
22. As a player, I want a quest that I pick up again myself to return to the route, so that I can undo that choice.
23. As a player, I want to skip a quest with a right-click, so that I can leave out a quest that I do not like.
24. As a player, I want to see my skipped quests in a list, so that I can bring one back.
25. As a player, I want to restore a skipped quest, so that a mistake costs me nothing.
26. As a player, I want the skip list to belong to one character, so that my other characters keep their own routes.
27. As a player, I want a Follow mode that I can turn on and off, so that I can choose between the route and my own focus.
28. As a player in Follow mode, I want the window to show the step of the quest that I pick in the quest log, so that the guide follows my interest.
29. As a player in Follow mode, I want a quest that is not on my route to get a step of its own, so that I still get help for it.
30. As a player in Follow mode, I want a click on the step to return me to the route, so that I can leave Follow mode quickly.
31. As a player, I want a quest that I just accepted not to count as a pick-up step, so that the route does not repeat what I did.
32. As a player on a kill step, I want to see the other nearby kill goals in the same block, so that I can do them together.
33. As a player, I want each of those nearby goals to show its objectives and counts, so that I can choose which to do first.
34. As a player, I want hover tooltips on quest rewards, so that I can see what an item or spell does.
35. As a player, I want the step to say where it happens in plain text, so that I can find the place without a map layer.
36. As a player who uses TomTom, I want the addon to set a waypoint for the current step when coordinates are known, so that TomTom can point me there.
37. As a player who uses TomTom, I want the waypoint to change when the step changes, so that I never follow an old marker.
38. As a player who uses TomTom, I want the addon to remove its waypoint when the step ends, so that no stale marker stays.
39. As a player who uses TomTom, I want the addon to leave my own waypoints alone, so that I do not lose them.
40. As a player who uses TomTom, I want an option to turn automatic waypoints off, so that I can use TomTom only by hand.
41. As a player without TomTom, I want the step to show its text only, so that nothing breaks.
42. As a player with a step that has several targets, I want the waypoint to use the nearest known target, so that I walk the shortest way.
43. As a player inside a dungeon, I want no waypoint, so that the addon does not point to a wrong place.
44. As a player who uses FlareUI, I want the window to look like the FlareUI tracker, so that my interface stays consistent.
45. As a player who uses FlareUI, I want the window to dock below the FlareUI tracker, so that both are easy to read together.
46. As a player who uses FlareUI, I want the window to keep its own width, so that text does not break in odd places or overflow.
47. As a player without FlareUI, I want a clean flat window that I can drag, so that I can put it where I want.
48. As a player, I want the addon to remember the position of the window, so that I do not move it each session.
49. As a player, I want to hide and show the window, so that I can clear my screen.
50. As a player, I want an options panel in the style of FlareUI, so that the options feel familiar.
51. As a player, I want to open the options from the window and from a command, so that I can reach them quickly.
52. As a player, I want the commands `/eq` and `/efficientquests`, so that I have a short and a long form.
53. As a player, I want the dungeon guide to start by itself when I enter a dungeon that it knows, so that I do not have to open it.
54. As a player in a dungeon, I want a list of stops in order, so that I know what comes next.
55. As a player in a dungeon, I want each stop to say how to approach it, so that I can prepare.
56. As a player in a dungeon, I want each boss stop to list its mechanics, so that I can avoid common failures.
57. As a player in a dungeon, I want optional stops to be marked as optional, so that I can choose to skip them.
58. As a player in a dungeon, I want a stop to be marked done when its boss dies, so that I do not have to mark it myself.
59. As a player in a dungeon, I want a stop to be marked done when its quest is complete, so that quest stops follow my real progress.
60. As a player in a dungeon, I want to mark a stop done by hand, so that I can fix a wrong detection.
61. As a player who leaves a dungeon, I want the window to return to the leveling route, so that I continue where I stopped.
62. As a player, I want the dungeon guide to name quests that the dungeon helps with, so that I can plan my group.
63. As a player with QuestieDB installed, I want the addon to use it for quests or NPCs that its own data lacks, so that I get more complete information.
64. As a player without QuestieDB, I want the addon to work with its own data, so that I need nothing else.
65. As a player, I want one clear message when data is missing for a quest, so that I know why a step is plain.
66. As a player, I want no 3D model and no experience bar in the window, so that the window stays small.
67. As a player, I want the addon to only show information, so that it never accepts, hands in, or abandons a quest for me.
68. As a maintainer, I want the addon to show its version and data snapshot, so that I can report problems with the right facts.
69. As a maintainer, I want offline tests that need no game, so that I can find errors before I test in the client.
70. As a maintainer, I want the license and the credits for copied work to be clear, so that the project follows the rules of the GPL.
71. As a maintainer, I want old code and scaffolding removed, so that the repository only holds what the addon needs.
72. As a contributor, I want plain English documents, so that I can understand the project and its decisions.
73. As a player on another client flavor, I want the addon to say that it supports Forever only, so that I know it is not meant for my client.

## Implementation Decisions

Target and packaging:

- The addon targets the Forever client. The interface number is 16001. Other client flavors are not supported.
- The folder name stays EfficientQuests. The version becomes 0.3.0.
- The release is the uncompressed addon folder, committed in the repository. There is no zip and no release workflow.
- The addon has no required dependencies. FlareUI, TomTom, and QuestieDB are optional dependencies.
- The addon embeds three small libraries: LibStub, CallbackHandler, and HereBeDragons version 2.0. It does not embed the pins library of HereBeDragons, because pins draw on maps.

Licensing:

- The whole project uses GPL-3.0-or-later. A license file and a third-party credits file are part of the repository.
- The credits file records every source of copied code and data, with its license, its version, and the date of the copy.
- Trailwright is a one-time snapshot. The credits file records both of its version numbers: 0.1.81-beta from its manifest and 1.51.0 from its README. There are no ongoing merges.
- The rule that forbids copying reference code in the contribution guide is replaced. The new rule says that copied work needs a credit entry and a compatible license.

Modules to build:

- Quest state reader. It reads the quest log, the completed quests, the objective counts, the level, the race, the class, and the faction. It also reads the position of the player through HereBeDragons. It is the only module that talks to the quest functions of the game. Other modules ask it questions.
- Data store. It holds the quest data, the Path, and the dungeon guide text. These are copied from Trailwright as generated tables, with attribution. A loader checks the shape of the tables at load time and reports a clear message if a table is missing or wrong.
- Route planner. It is a port of the Path walker. It builds the route from the data store and the quest state. It applies these filters in order: finished quests, quests that the race or class cannot take, grey quests, abandoned quests, and the skip list. It puts finished quests with a near hand-in first. It adds a "Level up to N" step when the next quests need a higher level. It keeps quests that are in the log but not on the Path until the player hands them in.
- Step model. It turns a route entry into a step with a headline, goal lines, tips, and a place text. It computes which goals are done from the quest state. It also builds the "hunts in one area" block from the other kill goals that are near the player. The distance limit for that block is about 700 yards, as in Trailwright.
- Follow mode controller. It listens for the quest that the player picks in the quest log. It asks the step model for the step of that quest. A quest that is not on the route gets its own step until the player hands it in. A quest that the player just accepted does not count as a pick-up. A click on the step returns to the route.
- Skip list. It stores skipped quests per character. It offers skip and restore actions to the window and the menu.
- Step window. It is written new, not ported. It shows the title bar, the follow toggle, the headline, the goal lines with tick boxes, the tips, the reward tooltips, the place text, and the hunts block. A right-click on a step opens the skip action. It has no 3D model, no experience bar, and no world-map action.
- Look adapter. When FlareUI is loaded, it reads the backdrop, the colors, and the fonts from the live FlareUI tracker frame, and it docks the window below that frame. It never copies the width of the tracker. Without FlareUI, it uses a flat look and the window is draggable. If the tracker frame is missing or has an unexpected shape, the adapter falls back to the flat look without an error.
- Menu. It is a small menu that opens beside the window. It lists the skipped quests, the known dungeons, and a link to the options.
- Options panel. It is a small window of our own, styled like the FlareUI options. It does not register itself in the FlareUI panel. It holds the waypoint toggle, the window lock, the scale, and the opacity.
- TomTom bridge. When TomTom is loaded and the current step has known coordinates, the bridge sets one waypoint for the step. It uses the nearest known target when a step has several. It replaces its waypoint when the step changes. It removes its waypoint when the step ends, when the player skips the quest, or when the window hides. It never sets a waypoint inside a dungeon and never touches waypoints that it did not create. It passes no map or minimap flags, so the TomTom options decide how the waypoint appears. An option turns the bridge off, and the default is on. Before the bridge is written, the current TomTom documentation must be checked with Context7.
- QuestieDB fallback. When a quest or an NPC is not in the data store and QuestieDB is loaded, the quest state reader asks QuestieDB for the name and the coordinates. The fallback never replaces data that the store already has.
- Dungeon guide. It is a port of the stops-based guide, without maps. It starts when the player enters a dungeon that the data store knows. It shows the stops in order. Each stop has a kind (boss, rare, spot, or event), an approach text, and optional mechanics. A stop is done when its boss dies, when its quest is complete, or when the player marks it by hand. Boss deaths are seen through the game boss events, the combat log, or the target of the player. When the player leaves the dungeon, the window returns to the leveling route.
- Commands. The commands `/eq` and `/efficientquests` open the window and the options and show the status. The status says which optional addons were found and which data snapshot is loaded.

Saved data:

- An account-wide table named EfficientQuestsDB holds window position, scale, opacity, lock, and the waypoint toggle.
- A per-character table named EfficientQuestsCharacter holds the skip list, the abandoned quests, and the Follow mode state.
- The addon does not migrate saved data from earlier versions. Dismissed hints and guide choices from the plugin design no longer exist.

Language:

- The addon is English only. Strings live in the code, and there is no locale layer.

Repository cleanup:

- Before any deletion, the current commit gets a tag named pre-trailwright. The uncommitted work goes to a side branch.
- On the main branch, these parts are removed: the guide plugin builder and its catalog, the release tool, the extraction audit tool, the bridge test, the fixture packages, the Python tests, the release steps of the CI workflow, and every document about guides, extraction, evidence, the buildbook, and the old specification. The agent documents stay.
- The old addon modules for hints, guide adaptation, the provider, the context, and the lifecycle are removed. The old window module stays as a reference until the new window replaces it. Then it is removed too.
- The readme, the contribution guide, the installation guide, and the validation record are rewritten in plain English.

Domain records:

- A glossary at the root of the repository defines the terms of this document. Two decision records are added. The first records the standalone addon with the Trailwright engine under the GPL. The second records the scope exclusions and the roles of TomTom and QuestieDB.

## Testing Decisions

A good test inspects behavior that a player or a maintainer can see. It does not test how the code reaches that behavior. It must keep passing when the code inside a module changes but the behavior stays the same.

The project uses one seam. The seam is the headless game simulation. A test loads the addon the way the game loads it, in the order of the manifest, with only the game services replaced. The test then fires game events, changes the simulated quest log, and calls the slash commands. It asserts on what the player sees and on what the addon stores. That means the text of the window, the state of the tick boxes, the saved data, the output of the status command, and the calls that the addon makes to TomTom and QuestieDB. FlareUI and TomTom are replaced by simple fakes in this seam.

These behaviors need tests:

- Route planning: every filter in order, the join point by level, the near hand-in first rule, the "Level up to N" step, the quests that stay while they are in the log, and the effect of the skip list and of abandoned quests.
- Step building: headlines, goal lines, completion of goals, tips, and the hunts block.
- Follow mode: picks from the quest log, the step for a quest that is not on the route, the just-accepted rule, and the return to the route.
- The window: the text that it shows with and without FlareUI, the copy of the backdrop, colors, and fonts, the docking below the tracker, the keeping of its own width, and the fallback look when the tracker frame is missing or wrong.
- The TomTom bridge: one waypoint per step, replacement, removal, the nearest target, no waypoint inside a dungeon, no waypoint without coordinates, no touching of foreign waypoints, and the off option.
- The QuestieDB fallback: used only when the store has no data.
- The dungeon guide: start on entry, stop order, completion by boss death, by quest, and by hand, and the return to the route on exit.
- Saved data: defaults, the account and character split, and the absence of any migration.
- The data loader: a clear message for a missing or malformed table.
- The manifest: the interface number, the version, the optional dependencies, and the absence of removed addons.

The existing suites are the prior art. They load the addon through a shared loader and simulate the game, FlareUI, and QuestieDB. The runtime, interface, and manifest suites show the pattern. The new suites follow it. Suites that only fit the plugin design are deleted.

The continuous integration workflow runs the Lua suites on Lua 5.1 in Docker and adds a static analysis step with luacheck, which finds accidental global variables. The Python suites, the bridge suite, and the release dry-run are removed.

Tests do not show pixels. The real look is checked in the Forever client against a written checklist in the validation record. The checklist includes screenshots, which are committed under the documents folder. The screenshot that the maintainer already made is kept.

## Out of Scope

These parts of Trailwright are not replicated:

- Everything that interacts with the world map or the minimap. This includes map actions, spawn dots, dungeon map windows, the world map overlay, and the square minimap.
- Travel planning and the Shortest Path engine.
- The professions guide and profession leveling.
- Auction features, including the shopping list, price tips, and the auction panel.
- Gold tracking, farming guides, and favor features.
- Party features, including shared routes and quest sharing.
- Marking and the marking wheel.
- Statistics.
- The 3D model and the experience bar in the main window.
- Our own arrow, the nameplate markers, and the role icons on NPC nameplates.
- Automation: auto accept, auto turn-in, errand steps, spell rank changes on action bars, and the completion chime.
- The quest item button, the target button, and their key bindings.
- The Auto planner, zone picks, the level guides, the Class tab, the Hidden tab, and the large menu window.
- Loot tracking and the loot panel.
- Other languages.
- Other client flavors.
- A data generator of our own, and any refresh of the data from newer Trailwright versions. These are later, separate work.
- The breakdown of this work into implementation tickets. That comes after this specification is accepted.

## Further Notes

- The addon is not validated in the Forever client. This specification covers offline behavior. The in-client and visual checks are tracked in the validation record.
- The Trailwright data files are generated by tools that are not in the local copy of the reference material. For this reason, the data cannot be regenerated, and the first release copies the generated tables as they are.
- The dungeon guide text of Trailwright is written for the Classic versions of the dungeons. Forever can differ. The addon must say this in its documents.
- When FlareUI is loaded, the window docks below the tracker. If the maintainer prefers a different dock position, only the look adapter changes.
- The old plugin design is superseded. Its documents stay in the Git history and in the pre-trailwright tag.
