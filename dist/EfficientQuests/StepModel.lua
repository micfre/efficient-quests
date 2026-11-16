-- The step model. It turns a route entry of the route planner into a
-- step -- plain data, no frames -- and the step window (#35) renders it.
-- It computes which goals are done from the quest state reader, adds the
-- tips and the place text from the data store, exposes the reward hover
-- data, and builds the "hunts in one area" block from the other kill
-- goals near the player.
--
-- The step table, for the window (#35):
--
--   kind     "pickup", "do", "turnin", or "levelup": the kind of the
--            route entry, kept for the window's colouring
--   questID  the quest id; a level-up step carries none
--   level    the level to reach (level-up steps only)
--   own      true when the route entry is the player's own work
--   near     true for a hand-in that came first for being close
--   headline the words of the step: "Pick up <quest>", "Do <quest>",
--            "Hand in <quest>", "Go to <quest>" -- a work step the data
--            knows no goals for: go to the place; the work happens
--            there -- or "Level up to <N>"
--   lines    the goal lines (below)
--   place    where the step happens, in plain words: "<zone>,
--            <direction>" or "the middle of <zone>"; nil when the data
--            knows no zone for the point
--   point    the place as { uiMapID, x, y } in percent, the first one
--            the data knows; nil when it knows none
--   points   every candidate place as { uiMapID, x, y } in percent; the
--            waypoint bridge picks the nearest of them
--   rewards  the hover data for the window: { items = { { id, name } },
--            choices = { { id, name } }, spell = id }, one entry per
--            reward the data knows (name nil when the data lacks it);
--            nil when the quest pays nothing the data knows
--   hunts    the "hunts in one area" block, work steps only: an array of
--            { questID, name, yards, place, point, lines }, one entry
--            per other kill goal within 700 yards of the player, in
--            route order, at most three; nil inside an instance, where
--            the reader knows no player position, and when no other
--            work stands that close
--
-- The goal lines, in order:
--
--   { kind, done, text, count, have, need, npc, item }
--
--   kind     "talk" (the giver or the ender), "note" (a tip or a place
--            note under a talk line), "accept", "turnin", "quest" (the
--            name line of a work step), "objective" (one goal), or
--            "info" (a plain hint)
--   done     the tick: true when the quest state says the line is over
--   text     the words of the line; a count the game baked into an
--            objective text is stripped, because the count column below
--            carries it
--   count    "3 of 7" for a countable goal, nil otherwise
--   have, need  the raw counts behind the count column
--   npc      the npc id the line is about, for hover
--   item     the item id a collect goal wants, for hover
--
-- The queries:
--
--   GetStep(entry)  the step of one route entry, in the shape the header
--                   of the route planner documents. The hunts block is
--                   built against the route the planner answers right
--                   now; an entry from an older route still finds its
--                   place on it by kind and quest id. A work or hand-in
--                   entry of a quest the data knows no facts for gets
--                   its step from the live log alone.
--   GetStepForQuest(questID)  the step of one quest, for the Follow
--                   mode controller (#34): the quest the player picked.
--                   A quest in the log gets its work step, or its
--                   hand-in step once every goal is done -- never a
--                   pick-up step, so a quest just accepted never counts
--                   as a pick-up; a log quest the data knows no facts
--                   for gets its step from the live log alone. A quest
--                   the player does not have gets its pick-up step. A
--                   quest handed in, or one that is neither in the log
--                   nor in the data, answers nil.

local _, ns = ...
local reader = EfficientQuests.questState
local planner = EfficientQuests.routePlanner
local geo = EfficientQuests.geo

local model = {}
EfficientQuests.stepModel = model

-- The distance limit of the "hunts in one area" block, in true world
-- yards (Trailwright's GROUP_YARDS), and how many steps the block holds
-- at most, counting the step itself (Trailwright's group cap of four).
local HUNTS_YARDS = 700
local HUNTS_MAX = 4

-- The name of an objective target at index i of the quest's data targets:
-- the target's own name, else the npc or object name from the tables. A
-- quest without data facts answers nothing.
local function targetName(q, index)
    local targets = q and q[26]
    local t = targets and targets[index]
    if type(t) ~= "table" then return nil end
    if t[1] then return t[1] end
    if t[2] and t[2][1] then
        local name = reader.NpcName(t[2][1])
        if name then return name end
    end
    if t[3] and t[3][1] and type(ns.objNames) == "table" then
        return ns.objNames[t[3][1]]
    end
    return nil
end

-- One objective line from a live objective of the quest log.
local function logGoal(q, name, index, objective)
    local need = (objective.numRequired and objective.numRequired > 0)
        and objective.numRequired or 1
    local have = objective.finished and need
        or math.min(objective.numFulfilled or 0, need)
    local text = type(objective.text) == "string" and objective.text or ""
    -- The count column carries the numbers, so a count the game baked
    -- into the text comes out of the words.
    text = text:gsub("[%s:]-%d+%s*/%s*%d+%s*$", "")
    if not text:find("%a") then
        text = targetName(q, index) or name
    end
    local t = q and q[26] and q[26][index]
    return {
        kind = "objective",
        done = objective.finished == true or have >= need,
        text = text,
        count = need > 1 and string.format("%d of %d", have, need) or nil,
        have = have, need = need,
        npc = t and t[2] and t[2][1] or nil,
        item = t and t[5] or nil,
    }
end

-- The goal lines of one quest's work: the live objectives of the log when
-- the quest is taken and the log reports them, else the data targets with
-- their counts. Answers whether any goal line came out. A quest without
-- data facts answers its live objectives or nothing.
local function goalLines(q, entry, name, lines)
    local counted = false
    if entry and type(entry.objectives) == "table" then
        for index, objective in ipairs(entry.objectives) do
            lines[#lines + 1] = logGoal(q, name, index, objective)
            counted = true
        end
    end
    if counted then return true end
    if type(q) ~= "table" or type(q[26]) ~= "table" then return false end
    for index, t in ipairs(q[26]) do
        local need = (t[4] and t[4] > 0) and t[4] or 1
        local done = (entry and entry.complete) or false
        lines[#lines + 1] = {
            kind = "objective",
            done = done,
            text = t[1] or targetName(q, index) or name,
            count = need > 1 and string.format("%d of %d", done and need or 0, need) or nil,
            have = done and need or 0, need = need,
            npc = t[2] and t[2][1] or nil,
            item = t[5] or nil,
        }
        counted = true
    end
    return counted
end

-- The words of a compass direction for a point in percent: the west-east
-- axis of the map is the x percent, the north-south axis the y percent.
-- A point near the centre of both axes is the middle.
local function directionOf(x, y)
    local northSouth = y < 37.5 and "north" or (y > 62.5 and "south" or "")
    local westEast = x < 37.5 and "west" or (x > 62.5 and "east" or "")
    if northSouth ~= "" and westEast ~= "" then
        return northSouth .. "-" .. westEast
    end
    if northSouth ~= "" then return northSouth end
    if westEast ~= "" then return westEast end
    return "middle"
end

-- The place of a point in plain words: the zone of the data and the
-- direction of the point inside it. No map layer, and no place text for a
-- zone the data does not name.
local function placeOf(point)
    if type(point) ~= "table" or type(ns.maps) ~= "table" then return nil end
    local zone = ns.maps[point[1]]
    if type(zone) ~= "string" then return nil end
    local direction = directionOf(point[2], point[3])
    if direction == "middle" then return "the middle of " .. zone end
    return zone .. ", " .. direction
end

-- The candidate places of a quest's work: its own objective points when
-- the data has them, else the first known spawn of every open target --
-- the npc position through the reader's lookup seam first, then the
-- object spawn table. A finished objective closes its target's spawn.
local function workPoints(q, logEntry)
    local points = {}
    if type(q[10]) == "table" then
        for _, spot in ipairs(q[10]) do points[#points + 1] = spot end
        return points
    end
    if type(q[26]) ~= "table" then return points end
    for index, t in ipairs(q[26]) do
        local objective = logEntry and type(logEntry.objectives) == "table"
            and logEntry.objectives[index]
        if not (objective and objective.finished) then
            local npc = t[2] and t[2][1]
            local spot = npc and reader.NpcPosition(npc) or nil
            if not spot and t[3] and t[3][1] and type(ns.objSpawns) == "table" then
                local flat = ns.objSpawns[t[3][1]]
                if type(flat) == "table" and type(flat[1]) == "number"
                    and type(flat[2]) == "number" and type(flat[3]) == "number" then
                    spot = { flat[1], flat[2], flat[3] }
                end
            end
            if spot then points[#points + 1] = spot end
        end
    end
    return points
end

-- The reward hover data of a quest: the fixed items, the choose-one items,
-- and the spell it teaches, each by id and -- when the data knows it -- by
-- name. Nil when the data knows no reward at all; the tooltips themselves
-- are the window's work (#35).
local function rewardsOf(q)
    if type(q[33]) ~= "table" and type(q[34]) ~= "table" and not q[36] then
        return nil
    end
    local function entries(list)
        local out = {}
        for _, id in ipairs(type(list) == "table" and list or {}) do
            local name = type(ns.itemNames) == "table" and ns.itemNames[id] or nil
            out[#out + 1] = { id = id,
                name = type(name) == "string" and name or nil }
        end
        return out
    end
    return {
        items = entries(q[33]),
        choices = entries(q[34]),
        spell = q[36],
    }
end

-- The Talk to line of a pick-up or hand-in step, with the place note and
-- the tip of the data under it. A giver or ender with no npc of its own
-- -- an object or an item -- gets a Click line. The notes come last, so
-- they sit under the line they explain.
local function addTalk(lines, who, npcID, tip)
    if not who then return end
    local verb = npcID and "Talk to " or "Click "
    lines[#lines + 1] = { kind = "talk", done = false,
        text = verb .. who, npc = npcID }
    if npcID and type(ns.npcWhere) == "table" and ns.npcWhere[npcID] then
        lines[#lines + 1] = { kind = "note", done = false,
            text = ns.npcWhere[npcID] }
    end
    if tip then
        lines[#lines + 1] = { kind = "note", done = false, text = tip }
    end
end

-- The "hunts in one area" block of a work step: the kill goals of the
-- later work entries whose place stands within HUNTS_YARDS of the player,
-- in route order, at most HUNTS_MAX - 1 of them, each with its own goal
-- lines and counts. The reader answers no player position inside an
-- instance, so the block stays away there.
local function huntsOf(questID)
    local here = reader.GetPlayerWorld()
    if not here then return nil end
    local route = planner.GetRoute()
    local at = 0
    for index, entry in ipairs(route) do
        if entry.kind == "do" and entry.questID == questID then
            at = index
            break
        end
    end
    if at == 0 then return nil end
    local hunts = {}
    for index = at + 1, #route do
        if #hunts >= HUNTS_MAX - 1 then break end
        local entry = route[index]
        if entry.kind == "do" then
            local q = ns.quests[entry.questID]
            if q then
                local logEntry = reader.GetQuest(entry.questID)
                local points = workPoints(q, logEntry)
                if #points == 0 and (q[9] or q[8]) then
                    points = { q[9] or q[8] }
                end
                local place = points[1] and geo.worldOf(points[1])
                if place and geo.sameContinent(place, here) then
                    local distance = geo.yards(here, place)
                    if distance <= HUNTS_YARDS then
                        local name = reader.QuestName(entry.questID) or q[1]
                        local lines = {
                            { kind = "quest",
                                done = (logEntry and logEntry.complete) or false,
                                text = name },
                        }
                        goalLines(q, logEntry, name, lines)
                        hunts[#hunts + 1] = {
                            questID = entry.questID, name = name,
                            yards = math.floor(distance + 0.5),
                            place = placeOf(points[1]), point = points[1],
                            lines = lines,
                        }
                    end
                end
            end
        end
    end
    if #hunts == 0 then return nil end
    return hunts
end

-- The step of a quest the data store knows no facts for, built from the
-- live log alone (story 20): the title from the log through the reader's
-- QuestName, the goals from the live objectives, and no place, no
-- rewards, and no waypoint candidates -- the data knows none.
local function logStep(entry, logEntry)
    local name = reader.QuestName(entry.questID) or ("Quest " .. entry.questID)
    if entry.kind == "turnin" then
        return {
            kind = "turnin", questID = entry.questID,
            own = entry.own, near = entry.near,
            headline = "Hand in " .. name,
            lines = {
                { kind = "turnin", done = logEntry.complete == true,
                    text = "Turn in " .. name },
            },
            point = nil, points = {},
        }
    end
    local lines = {
        { kind = "quest", done = logEntry.complete == true, text = name },
    }
    local hasGoals = goalLines(nil, logEntry, name, lines)
    if not hasGoals then
        lines[#lines + 1] = {
            kind = "info", done = false,
            text = "See the quest log for what to do.",
        }
    end
    return {
        kind = "do", questID = entry.questID, own = entry.own,
        headline = hasGoals and ("Do " .. name) or ("Go to " .. name),
        lines = lines,
        point = nil, points = {},
    }
end

--- The step of one route entry, in the shape the header of this module
--- documents.
function model.GetStep(entry)
    if entry.kind == "levelup" then
        return {
            kind = "levelup", level = entry.level,
            headline = "Level up to " .. entry.level,
            lines = {
                { kind = "objective", done = false,
                    text = "Kill mobs around here until level " .. entry.level },
                { kind = "note", done = false,
                    text = "The next quests of the route need a higher level than yours." },
            },
        }
    end
    local q = ns.quests[entry.questID]
    if not q then
        -- A quest the data knows no facts for: only the log can still
        -- serve it -- the own work of story 20. Everything else, above
        -- all a pick-up, has nothing to show.
        local logEntry = reader.GetQuest(entry.questID)
        if logEntry and (entry.kind == "do" or entry.kind == "turnin") then
            return logStep(entry, logEntry)
        end
        return nil
    end
    local name = reader.QuestName(entry.questID) or q[1]
    local rewards = rewardsOf(q)
    if entry.kind == "pickup" then
        local lines = {}
        addTalk(lines, q[19], q[27], q[30])
        lines[#lines + 1] = { kind = "accept", done = false, text = "Accept " .. name }
        return {
            kind = "pickup", questID = entry.questID,
            headline = "Pick up " .. name, lines = lines,
            place = placeOf(q[8]),
            point = q[8], points = q[8] and { q[8] } or {},
            rewards = rewards,
        }
    end
    if entry.kind == "turnin" then
        local logEntry = reader.GetQuest(entry.questID)
        local lines = {}
        addTalk(lines, q[20], q[28], q[31])
        lines[#lines + 1] = { kind = "turnin",
            done = (logEntry and logEntry.complete) or false,
            text = "Turn in " .. name }
        local point = q[9] or q[8]
        return {
            kind = "turnin", questID = entry.questID,
            own = entry.own, near = entry.near,
            headline = "Hand in " .. name, lines = lines,
            place = placeOf(point),
            point = point, points = point and { point } or {},
            rewards = rewards,
        }
    end
    -- The work step: its places come from the objectives, or -- when the
    -- data knows no place for the work, the bring-it-yourself quests --
    -- from the hand-in or the start point, the way the route counts a
    -- work step with no known place.
    local logEntry = reader.GetQuest(entry.questID)
    local points = workPoints(q, logEntry)
    if #points == 0 and (q[9] or q[8]) then
        points = { q[9] or q[8] }
    end
    local lines = {
        { kind = "quest", done = (logEntry and logEntry.complete) or false, text = name },
    }
    local hasGoals = goalLines(q, logEntry, name, lines)
    local headline
    if hasGoals then
        headline = "Do " .. name
    else
        headline = "Go to " .. name
        lines[#lines + 1] = {
            kind = "info", done = false,
            text = "See the quest log for what to do.",
        }
    end
    return {
        kind = "do", questID = entry.questID, own = entry.own,
        headline = headline, lines = lines,
        place = placeOf(points[1]),
        point = points[1], points = points,
        rewards = rewards,
        hunts = huntsOf(entry.questID),
    }
end

--- The step of one quest, for the Follow mode controller (#34), in the
--- shape the header of this module documents: a quest in the log never
--- gets a pick-up step -- the data serves it, or the live log does when
--- the data knows no facts for it -- and a quest handed in or unknown
--- answers nil.
function model.GetStepForQuest(questID)
    local logEntry = reader.GetQuest(questID)
    if logEntry then
        local kind = logEntry.complete and "turnin" or "do"
        return model.GetStep({ kind = kind, questID = questID })
    end
    if not ns.quests[questID] then return nil end
    if reader.IsCompleted(questID) then return nil end
    return model.GetStep({ kind = "pickup", questID = questID })
end
