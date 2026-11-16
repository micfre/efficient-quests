# Glossary

This glossary defines the domain terms of the Efficient Quests addon. The specification is `docs/specs/efficient-quests-standalone.md`. Use these terms in issues, proposals, hypotheses, and tests.

- Addon: a program that extends the game interface.
- Data store: the module that holds the quest data, the Path, and the dungeon guide text.
- Dungeon guide: the guide that shows the stops of a dungeon in order when the player enters a dungeon that the addon knows.
- Follow mode: the mode in which the window shows the step of the quest that the player picked in the quest log.
- Goal: one line inside a step, such as "Talk to an NPC" or "Kill 7 boars".
- Hunts block: the block inside a step that groups the other kill goals near the player. The distance limit is about 700 yards.
- Leveling guide: the guide that shows one step at a time from the Path.
- Look adapter: the module that copies the backdrop, the colors, and the fonts of the FlareUI tracker when FlareUI is loaded. Without FlareUI, it gives the window a flat look.
- Near hand-in first: the rule that puts a finished quest at the front of the route while its hand-in point is close to the player.
- Own quest: a quest in the log that the Path itself does not do. It stays on the route until the player hands it in.
- Path: the fixed order of quests from level 1 to level 60 that the addon uses as its default route.
- Quest state reader: the module that reads the quest log, the completed quests, the objective counts, the level, the race, the class, and the faction. It is the only module that talks to the quest functions of the game.
- QuestieDB fallback: the fallback in which the quest state reader asks QuestieDB for the name and the coordinates of a quest or an NPC that the data store lacks. It never replaces data that the store already has.
- Route: the ordered list of steps that the player follows.
- Route entry: one item of the route. The step model turns it into a step.
- Route planner: the module that builds the route from the data store and the quest state. It is a port of the Path walker of Trailwright.
- Skip list: the quests that the player chose to leave out. It belongs to one character.
- Step: one unit of the leveling guide, such as "Pick up a quest" or "Hand in a quest".
- Step model: the module that turns a route entry into a step with a headline, goal lines, tips, and a place text.
- Stop: one item in a dungeon guide, such as a boss, a rare enemy, a quest spot, or an event.
- TomTom bridge: the module that sets one TomTom waypoint for the current step when TomTom is loaded and the step has known coordinates.
- Waypoint: a marked place that the TomTom addon points to.
