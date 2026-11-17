# Validation record

This record states what the offline tests cover for the standalone addon and what still needs the game client. The [standalone specification](specs/efficient-quests-standalone.md) covers offline behavior. The record of the old plugin design stays in the Git history and in the `pre-trailwright` tag.

Status:

- Offline verification: done. Seventeen Lua suites and one luacheck run pass in CI on every push and pull request. The commands are in [.github/workflows/ci.yml](../.github/workflows/ci.yml).
- In-client validation: not done. Nobody has run the addon in the Forever client. The addon is not a validated release until a person runs the checklist below and records the results.

## What the offline suites cover

Every suite loads the addon headless, in the order of the manifest, with the game services replaced by simulations. The suites assert on what a player sees. That is the text of the window, the saved data, the output of the status command, and the calls to TomTom and QuestieDB. The [test guide](../tests/README.md) lists every suite in full. The coverage by behavior area:

### The engine and its data

- `datastore`: the copied Trailwright tables load. The loader reports one clear message for a missing or a malformed table. The addon keeps running without the guides that need the broken table. The data snapshot identity is there for the status command.
- `queststate`: the quest state reader reads the quest log with its objective counts and the completed quests. It reads the level, the race, the class, and the faction of the player. It reads the position through the embedded HereBeDragons. Its change callbacks fire when a quest is accepted, progresses, completes, is handed in, or is abandoned. They also fire when the player levels up.

### The route and the step

- `routeplanner`: every filter runs in order: finished quests, race and class, grey quests, abandoned quests, and the skip list. Also the join point by level, the near hand-in first rule with true yard distances, and the "Level up to N" step. Also the quests from the log that stay on the route, and the rule that a quest just accepted gets no pick-up step.
- `stepmodel`: the headline of every step kind, and the goal lines with their ticks and counts. Also the tips, the place text, and the reward hover data. Also the hunts block, with its 700-yard limit and its cap of three members. No block appears inside an instance.
- `followmode` and `characterstore`: the Follow mode switch that persists per character. Also the pick in the quest log through the client's super tracking and the manual pick hook. Also the step of a quest that is not on the route, and the end of the following at hand-in. Also the click that returns to the route. The character stores hold the skip list with its skip and restore actions, the abandoned quests, and the Follow mode state. Two characters keep their state apart.

### The window and its look

- `stepwindow`: the text of the step on screen, and the Back and Next paging with the "Step N / M" line. Also the right-click skip, the Follow toggle, hide and show, and the drag that writes the saved place. Also the lock, the scale, and the opacity. No quest action is ever offered: the addon never accepts, hands in, or abandons a quest.
- `lookadapter`: the copy of the FlareUI tracker's backdrop, colors, and fonts onto the window, the dock below the tracker, and the window's own width. Also the flat look without FlareUI, and the flat fallback without an error when the tracker frame is missing or has an unexpected shape.
- `menu` and `options`: the menu beside the window. It lists the skipped quests with restore actions, the known dungeons with their level ranges, and the link to the options. The options panel shows and writes the waypoint toggle, the window lock, the scale, and the opacity. Every change goes straight into the account-wide saved table.

### The optional addons

- `tomtombridge`: one waypoint per step, with the headline as its title and no display flags, so the TomTom options decide how it appears. The waypoint is replaced on every step change and removed when the window hides or the quest is skipped. The bridge picks the nearest of several candidate places by true yards. It sets no waypoint without coordinates and none inside an instance. The off option takes a standing waypoint down at once. A waypoint that the player set by hand survives every operation.
- `questiefallback`: QuestieDB answers only the ids that the data store lacks, and the store wins when both have the data. An absent or incompatible QuestieDB changes nothing and is never read. Every id that stays missing after the whole lookup chain ran gets one clear chat message per session.

### The dungeon guide

- `dungeonguide`: the start on entry to a dungeon that the data knows, and no start for an unknown one. The wing pick for an instance whose wings share one id, and the name-found dungeons of the Forever client. The stop list with its kinds, optional marks, approach texts, and boss mechanics. The completion of a stop by boss death, by quest completion, and by the hand mark. The quests the dungeon helps with. The display handoff that takes the step window's place inside and gives it back on exit.

### The shell

- `commands`: `/eq` and `/efficientquests` run the same handler. A bare command toggles the window. The words `options` and `config` open the panel. The word `status` prints the version, the data snapshot, and one word per optional addon. The word `help` lists the commands.
- `runtime` and `saveddata`: the entry point, the saved-data setup on login, and the one message that a player on another client flavor gets. Also the two saved tables with their defaults, and the split between the account-wide table and the per-character table. Also the rule that keys from the old plugin era stay untouched instead of being migrated.
- `manifest`: the interface number, the version, the optional dependencies, the saved variables, the embedded libraries, and the load order of the data files. It also rejects the pins library and leftover mentions of removed addons.
- luacheck checks the addon code for accidental global variables. The configuration names the game services that the addon can use as globals. Luacheck skips the verbatim copies: the embedded libraries and the generated data tables.

## What the offline suites cannot show

The suites replace the client, FlareUI, and TomTom with simulations. They show the logic of the addon. They do not show native compatibility, and they do not show pixels. The look and the real behavior need the Forever client. The checklist below covers that.

## The in-client checklist

Nobody has done these checks. A person with the Forever client runs them and records the results. An asterisk (\*) marks a value to fill in.

### IC-1. Record the build

1. Record the game version from the title screen: \*
2. Run `/run print(GetBuildInfo())` and record the output: \*
3. Record the interface version. The reference starting point is 16001: \*
4. Record the version of each optional addon that is installed: \*
5. Record the version of Efficient Quests from its manifest. The expected value is 0.3.0: \*

### IC-2. First login

1. Install the addon. Log in on a character of low level in a starting zone.
2. Type `/eq`.

Expected: no Lua errors occur. The window shows the first step of the route. `/eq status` prints the version, the data snapshot, and one word per optional addon: found or missing. Result: \*

### IC-3. The leveling route

1. Play the route: accept a quest, do its goals, and hand it in.
2. Watch the window at each change.

Expected: the goal lines tick themselves as the objectives finish. Kill and collect goals show counts such as 3 of 7. The window moves on when the current step is done. A finished quest whose hand-in point is near comes first on the route. When the next quests need a higher level, the window shows a "Level up to N" step. Result: \*

### IC-4. Skip and restore

1. Right-click a step on the window.
2. Open the menu from the title bar.
3. Click the restore action of the skipped quest.

Expected: the right-click removes the quest from the route. The menu lists the quest by name. The restore action returns the quest to the route. Result: \*

### IC-5. Follow mode

1. Turn on the "Follow" tick in the title bar.
2. Pick a quest in the quest log.
3. Click the step headline.

Expected: the window shows the step of the picked quest. A quest that is not on the route gets its own step. The click returns the window to the route. Result: \*

### IC-6. Saved data across sessions

1. Drag the window. Change the scale and the opacity in the options panel. Skip one quest.
2. Run `/reload`. Log out and log in again.
3. Log in on a second character of the same account.

Expected: after the reload and after the relogin, the window sits where you dragged it, and the quest stays skipped. The second character starts with its own skip list, because the skip list belongs to one character. The window options stay as you set them, because they are account-wide. Result: \*

### IC-7. The look with and without FlareUI

1. Install FlareUI. Log in.
2. Turn FlareUI off. Log in again.

Expected: with FlareUI, the window matches the backdrop, the colors, and the fonts of the FlareUI tracker and sits below it. The window keeps its own width. Without FlareUI, the window has a flat look, and the lock option gates the drag. Result: \*

### IC-8. TomTom waypoints

1. Install TomTom. Log in on a questing character.
2. Watch the waypoint while the steps change.
3. Set your own waypoint by hand. Turn the waypoint option off in the options panel.

Expected: TomTom points to the place of the current step. The waypoint changes when the step changes and goes away when the step ends. Your own waypoint stays untouched. The option takes the standing waypoint down at once. No waypoint appears inside a dungeon. Result: \*

### IC-9. QuestieDB

1. Install QuestieDB. Log in.
2. Type `/eq status`. Disable QuestieDB, reload, and type `/eq status` again.

Expected: with QuestieDB, a step of a quest that its own data lacks shows the names and the coordinates that QuestieDB has. The status says found for QuestieDB. Without QuestieDB, the status says missing, and the addon works on its own data. A step with data that stays missing shows its text only. The chat shows one clear message per missing id per session. Result: \*

### IC-10. The dungeon guide

1. Enter a dungeon that the addon knows.
2. Kill a boss. Complete a dungeon quest. Mark one stop done by hand.
3. Leave the dungeon.

Expected: the guide starts by itself and shows the stops in order. The current stop shows its approach text, its boss mechanics, and the quests it helps with. A boss death marks its stop done. A completed quest marks its quest stop done. The hand mark works. On exit, the window returns to the leveling route. Result: \*

The dungeon guide text comes from the Classic versions of the dungeons. The Forever client can differ. Compare each text with what you see, and record the differences as findings.

### Screenshots

Take screenshots of the window with FlareUI and without it, of the options panel, of the menu, and of the dungeon guide. Commit them under `docs/` next to this record, and name each file in the results above. The checks are complete when the screenshots are in the repository.

### Prior-art screenshot

The file `text-on-buttons.png` in this folder is a screenshot that the maintainer made during the earlier plugin design. The project keeps it as history. It does not show the current window.

## Known limits

- The dungeon guide text is written for the Classic versions of the dungeons. The Forever client can differ.
- The offline suites replace the client, FlareUI, and TomTom with simulations. A passing suite does not show native compatibility or visual quality.
- The addon is not validated in the Forever client. This record tracks that work.
