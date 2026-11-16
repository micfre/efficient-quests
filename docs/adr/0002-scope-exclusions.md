# ADR 0002: Scope exclusions

Status: accepted (2026-11-16).

## Context

Trailwright ships many parts that sit outside quest guidance. It draws on the world map and the minimap, plans travel, guides professions, tracks the auction and gold, shares routes with a party, marks enemies, counts statistics, shows a 3D model and an experience bar, and automates quest acceptance and hand-in.

Players asked for a guide that tells them the next useful thing to do. The all-in-one addons bring many parts that the player does not want. The specification therefore draws a narrow scope. The full specification is `docs/specs/efficient-quests-standalone.md`, section "Out of Scope".

## Decision

The addon leaves out these parts of Trailwright:

- Everything that draws on the world map or the minimap. This includes map actions, spawn dots, dungeon map windows, the world map overlay, and the square minimap.
- Travel planning and the Shortest Path engine.
- The professions guide and profession leveling.
- Auction features, including the shopping list, price tips, and the auction panel.
- Gold tracking, farming guides, and favor features.
- Party features, including shared routes and quest sharing.
- Marking and the marking wheel.
- Statistics.
- The 3D model and the experience bar in the main window.
- Automation: auto accept, auto turn-in, errand steps, spell rank changes on action bars, and the completion chime.

The addon itself does not draw on the map or the minimap and does not ship its own arrow. It always names the place of a step in text. Two optional addons cover what the addon itself leaves out:

- TomTom is the optional waypoint bridge. When TomTom is loaded and the current step has known coordinates, the TomTom bridge sets one waypoint for the step. Without TomTom, the addon still works and shows text only.
- QuestieDB is the optional data fallback. When the data store lacks a quest or an NPC and QuestieDB is loaded, the quest state reader asks QuestieDB for the name and the coordinates. The fallback never replaces data that the store already has.

## Consequences

- The window stays small, and the addon stays information only. It never accepts, hands in, or abandons a quest for the player.
- The addon has no required dependencies. It works on a simple setup with no optional addon.
- A player who wants a marker on the map must install TomTom. A player who wants more complete data can install QuestieDB.
- The exclusion list guards future work. A proposal that adds an excluded part conflicts with this record and needs a review of this decision.
