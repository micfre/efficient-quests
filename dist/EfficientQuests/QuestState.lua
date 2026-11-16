-- The quest state reader.
--
-- This is the only module of the addon that talks to the quest functions
-- of the game. It reads the quest log, the completed quests, the level,
-- the race, the class, and the faction of the player, and the position of
-- the player through the embedded HereBeDragons 2.0. Other modules ask it
-- questions; they never call the quest functions themselves.
--
-- Change callbacks
--
-- Subscribe with reader.RegisterCallback(owner, name, fn), where owner is
-- your module's table, and stop with reader.UnregisterCallback(owner,
-- name) or reader.UnregisterAllCallbacks(owner) -- the
-- CallbackHandler-1.0 API, so every module keeps its own subscription.
-- The subscriber function receives the callback name, then one payload
-- table:
--
--   QuestAccepted   { questID = number, title = string|nil }
--                   the player took the quest; older clients pass the log
--                   index first, which the reader strips
--   QuestProgressed { questID = number, title = string|nil }
--                   an objective count of a quest in the log changed
--   QuestCompleted  { questID = number, title = string|nil }
--                   every objective of a quest in the log is now done; the
--                   quest is not handed in yet
--   QuestHandedIn   { questID = number, title = string|nil }
--                   the player handed the quest in
--   QuestAbandoned  { questID = number, title = string|nil }
--                   the quest left the log without a hand-in; the reader
--                   waits a moment first, because a hand-in can reach the
--                   removed event before the game marks it completed
--   PlayerLevelUp   { level = number }
--                   the player reached this level
--
-- The questID is a number and the title, when known, comes from the log.
-- The player position is never pushed: callers ask GetPlayerWorld.
--
-- Query seam for the data store and the QuestieDB fallback
--
-- The reader never calls QuestieDB and holds no quest data of its own.
-- A later module registers lookup functions, and the reader runs them in
-- registration order until one answers:
--
--   reader.RegisterLookup("questName", function(questID) ... end)
--   reader.RegisterLookup("npcName", function(npcID) ... end)
--   reader.RegisterLookup("npcPosition", function(npcID) ... end)
--       -> { uiMapID, x, y } in percent coordinates, or nil
--
-- The questions reader.QuestName(questID), reader.NpcName(npcID), and
-- reader.NpcPosition(npcID) go through that chain. The data store
-- registers first, so a later QuestieDB fallback only sees what the store
-- left unanswered. QuestName answers from the live quest log first.

local reader = {}
EfficientQuests.questState = reader

local CallbackHandler = LibStub("CallbackHandler-1.0")
local HBD = LibStub("HereBeDragons-2.0")
reader.callbacks = CallbackHandler:New(reader, "RegisterCallback",
    "UnregisterCallback", "UnregisterAllCallbacks")
local function fire(name, payload)
    reader.callbacks:Fire(name, payload)
end

-- The last-read state. The log is refreshed when the game says the quest
-- log changed; the player facts are read live, with the level announced by
-- PLAYER_LEVEL_UP kept while UnitLevel still answers the old one.
local state = {
    level = nil, levelFromEvent = nil,
    raceName = nil, raceID = nil,
    className = nil, classID = nil,
    faction = nil,
    log = {},
}

local function ReadPlayer()
    local level = (UnitLevel and UnitLevel("player")) or state.level or 1
    if state.levelFromEvent and state.levelFromEvent > level then
        level = state.levelFromEvent
    end
    state.level = level
    if UnitRace then
        local name, _, id = UnitRace("player")
        state.raceName, state.raceID = name, id
    end
    if UnitClass then
        local name, _, id = UnitClass("player")
        state.className, state.classID = name, id
    end
    if UnitFactionGroup then
        state.faction = UnitFactionGroup("player")
    end
end

--- The character facts of the player, read live:
--- { level, race, raceID, class, classID, faction }.
function reader.GetPlayer()
    ReadPlayer()
    return {
        level = state.level,
        race = state.raceName, raceID = state.raceID,
        class = state.className, classID = state.classID,
        faction = state.faction,
    }
end

--- The level of the player right now.
function reader.GetLevel()
    ReadPlayer()
    return state.level
end

-- One quest of the log, as the client reports it. The done and need
-- fields sum the objective counts; a finished objective counts as full.
-- The complete field adds the client's own IsComplete answer.
local function ReadEntry(questID, title, level)
    local entry = { id = questID, title = title, level = level, done = 0, need = 0 }
    entry.complete = (C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID)) or false
    local objectives = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID)
    if objectives then
        for _, objective in ipairs(objectives) do
            local need = (objective.numRequired and objective.numRequired > 0)
                and objective.numRequired or 1
            local done = objective.finished and need
                or math.min(objective.numFulfilled or 0, need)
            entry.need = entry.need + need
            entry.done = entry.done + done
        end
        entry.objectives = objectives
    end
    if entry.need > 0 and entry.done >= entry.need then entry.complete = true end
    return entry
end

-- Read the whole quest log, header rows aside, and tell the subscribers
-- what changed: every quest whose counts changed fires QuestProgressed,
-- then every quest that turned complete fires QuestCompleted.
local function ReadLog()
    local previous = state.log
    local fresh = {}
    local numEntries = C_QuestLog.GetNumQuestLogEntries
        and C_QuestLog.GetNumQuestLogEntries() or 0
    for index = 1, numEntries do
        local info = C_QuestLog.GetInfo and C_QuestLog.GetInfo(index)
        if info and not info.isHeader and info.questID and info.questID > 0 then
            fresh[info.questID] = ReadEntry(info.questID, info.title, info.level)
        end
    end
    local progressed, turnedComplete = {}, {}
    for questID, entry in pairs(fresh) do
        local old = previous[questID]
        if old then
            if old.done ~= entry.done or old.need ~= entry.need then
                table.insert(progressed, questID)
            end
            if not old.complete and entry.complete then
                table.insert(turnedComplete, questID)
            end
        end
    end
    state.log = fresh
    for _, questID in ipairs(progressed) do
        fire("QuestProgressed", { questID = questID, title = fresh[questID].title })
    end
    for _, questID in ipairs(turnedComplete) do
        fire("QuestCompleted", { questID = questID, title = fresh[questID].title })
    end
end

--- One quest of the log: { id, title, level, done, need, complete,
--- objectives }, or nil when the quest is not in the log. Treat the entry
--- as read-only; ask again after the next QUEST_LOG_UPDATE.
function reader.GetQuest(questID)
    return state.log[questID]
end

--- The whole log as one table keyed by quest id. Treat it as read-only.
function reader.GetLog()
    return state.log
end

--- Whether the quest sits in the quest log right now.
function reader.IsOnQuest(questID)
    return state.log[questID] ~= nil
end

-- The completed quests. The client list is read once, on first question,
-- and handed-in quests join it as they happen. Newer clients answer an
-- array from C_QuestLog; older ones answer a set from GetQuestsCompleted.
local completed = {}
local completedRead = false
local function EnsureCompletedRead()
    if completedRead then return end
    completedRead = true
    if C_QuestLog.GetAllCompletedQuestIDs then
        local ids = C_QuestLog.GetAllCompletedQuestIDs()
        if ids then
            for _, questID in ipairs(ids) do completed[questID] = true end
        end
    elseif GetQuestsCompleted then
        local ids = GetQuestsCompleted()
        if ids then
            for questID in pairs(ids) do completed[questID] = true end
        end
    end
end

--- Whether the player finished the quest for good: handed in, in the
--- completed list, or flagged completed by the client.
function reader.IsCompleted(questID)
    EnsureCompletedRead()
    if completed[questID] then return true end
    if C_QuestLog.IsQuestFlaggedCompleted
        and C_QuestLog.IsQuestFlaggedCompleted(questID) then
        return true
    end
    return false
end

--- How many quests the player has finished for good.
function reader.GetCompletedCount()
    EnsureCompletedRead()
    local count = 0
    for _ in pairs(completed) do count = count + 1 end
    return count
end

--- The world position of the player as { x, y, instance }, read through
--- the embedded HereBeDragons 2.0, or nil inside an instance and outside
--- the world. Pulled by callers; the reader never pushes it.
function reader.GetPlayerWorld()
    if IsInInstance and IsInInstance() then return nil end
    local ok, x, y, instance = pcall(HBD.GetPlayerWorldPosition, HBD)
    if not ok or not x or not y or not instance then return nil end
    return { x, y, instance }
end

--- The map the player stands on, or nil when the map service knows none.
function reader.GetPlayerMap()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    if ok and mapID then return mapID end
    return nil
end

-- The query seam: lookup chains per kind, run in registration order
-- until one answers. The reader registers nothing itself.
local lookups = { questName = {}, npcName = {}, npcPosition = {} }

--- Register one lookup for a kind: "questName" (quest id -> name),
--- "npcName" (npc id -> name), or "npcPosition" (npc id -> { uiMapID, x,
--- y } in percent). Register the data store first; a QuestieDB fallback
--- registered later then sees only what the store left unanswered.
function reader.RegisterLookup(kind, resolver)
    if not lookups[kind] then
        error("unknown lookup kind: " .. tostring(kind), 2)
    end
    table.insert(lookups[kind], resolver)
end

local function ask(kind, id)
    for _, resolver in ipairs(lookups[kind]) do
        local value = resolver(id)
        if value ~= nil then return value end
    end
    return nil
end

--- The name of a quest: from the live quest log first, then the lookups.
function reader.QuestName(questID)
    local entry = state.log[questID]
    if entry and entry.title then return entry.title end
    return ask("questName", questID)
end

--- The name of an NPC from the lookups, or nil.
function reader.NpcName(npcID)
    return ask("npcName", npcID)
end

--- The position of an NPC from the lookups as { uiMapID, x, y } in
--- percent, or nil.
function reader.NpcPosition(npcID)
    return ask("npcPosition", npcID)
end

-- The game says what changed; the reader re-reads the part in question
-- and tells the subscribers. QUEST_LOG_UPDATE carries no payload and is
-- handled with the log reader further down.
local events = CreateFrame("Frame")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUEST_ACCEPTED")
events:RegisterEvent("QUEST_REMOVED")
events:RegisterEvent("QUEST_TURNED_IN")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LEVEL_UP" then
        local level = ...
        if type(level) == "number" then
            state.levelFromEvent = level
            state.level = level
            fire("PlayerLevelUp", { level = level })
        end
    elseif event == "QUEST_TURNED_IN" then
        local questID = ...
        if type(questID) == "number" then
            EnsureCompletedRead()
            completed[questID] = true
            local entry = state.log[questID]
            state.log[questID] = nil
            fire("QuestHandedIn", { questID = questID,
                title = entry and entry.title or nil })
        end
    elseif event == "QUEST_ACCEPTED" then
        -- Older clients pass the log index first; the quest id is second.
        local index, questID = ...
        questID = questID or index
        if type(questID) == "number" then
            ReadLog()
            local entry = state.log[questID]
            fire("QuestAccepted", { questID = questID, title = entry and entry.title or nil })
        end
    elseif event == "QUEST_REMOVED" then
        -- Handed in or abandoned? A hand-in can reach this event before
        -- the game marks the quest completed, so the reader waits a
        -- moment, then calls it an abandonment only when nothing says
        -- otherwise.
        local questID = ...
        if type(questID) == "number" then
            local entry = state.log[questID]
            local title = entry and entry.title or nil
            C_Timer.After(1.5, function()
                if completed[questID] then return end
                if C_QuestLog.IsQuestFlaggedCompleted
                    and C_QuestLog.IsQuestFlaggedCompleted(questID) then return end
                local stillOn = C_QuestLog.IsOnQuest
                    and C_QuestLog.IsOnQuest(questID)
                if stillOn then return end
                fire("QuestAbandoned", { questID = questID, title = title })
            end)
        end
    elseif event == "QUEST_LOG_UPDATE" then
        ReadLog()
    end
end)
