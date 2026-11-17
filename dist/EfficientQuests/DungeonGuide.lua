-- The dungeon guide of Efficient Quests. While the player is inside a
-- dungeon that the data store knows, this module takes over the display
-- from the step window and its window (see DungeonGuideWindow.lua) shows
-- the dungeon's stops in order. This module owns the logic: it resolves
-- which dungeon the player stands in, keeps the run state -- the kills of
-- this visit -- and answers which stop is done and which is current. A
-- stop is done when its boss dies -- seen through the game's boss events
-- or the player's target --, when its quest is complete, or when the
-- player marks it by hand. When the player leaves the dungeon, the step
-- window comes back with the leveling route.
--
-- The port. The behavior is a port of the dungeon guide of Trailwright
-- (see THIRD_PARTY.md): the stops-based guide without maps. The boss
-- order, the approach, and the mechanics texts live in the generated
-- DungeonGuides table the data store checks; the texts are Trailwright's
-- own words, written for the Classic versions of these dungeons -- the
-- Forever client may differ.
--
-- How a dungeon is resolved. The game hides the player's position inside
-- an instance, but GetInstanceInfo still names the instance and gives its
-- id. Most guides are kept under that id. Dungeons whose wings share one
-- instance id -- Scarlet Monastery, Stratholme, Blackrock Spire, Dire
-- Maul -- never tell the client which wing the player is in, so the guide
-- for the player's level is the pick, the way Trailwright picks it.
-- Dungeons the generated table keeps under one of its own ids -- WoW
-- Forever's own, whose instance ids are not known -- are found by the
-- name the game gives, matched against the names list of every guide.
--
-- The display handoff. The step window shows itself whenever the player
-- enters the world, so this module never fights it inside one event
-- dispatch: the change of the dungeon lands on the next frame, after
-- every other listener of the same world event has settled, the way the
-- step window waits a frame for the route planner. On start, the step
-- window leaves the screen only when it was on it, and exactly that
-- hiding is undone on exit -- a step window the player had closed stays
-- closed.
--
-- The public surface, for the later tickets:
--
--   IsActive()        whether the guide runs right now: the player is
--                     inside a dungeon the data knows.
--   GetActiveGuide()  the running guide, { key = the key the guide is
--                     kept under in the generated table, guide = that
--                     table }, or nil outside. The key is an instance
--                     id, a wing id, or a named id. The window asks this
--                     on every refresh.
--   MarkStop(npcID, how)  the hand mark (user story 60): "done" marks
--                     the stop done, "undo" clears the mark again.
--   StopDone(stop)    whether one stop of the running guide is done: the
--                     window's tick asks, and so does the hand mark.
--   CurrentIndex(stops)  the first stop still to do, or nil when every
--                     stop is done: the window's open stop asks.
--   RegisterCallback(owner, "GuideChanged", fn)  the CallbackHandler
--                     subscription. GuideChanged fires with one payload
--                     table, { active, key, guide }, whenever the guide
--                     starts, stops, or a stop's done state moves.

local _, ns = ...
local reader = EfficientQuests.questState
local stepWindow = EfficientQuests.StepWindow
local window = EfficientQuests.dungeonGuideWindow

local self = {}
EfficientQuests.dungeonGuide = self

self.callbacks = LibStub("CallbackHandler-1.0"):New(self,
    "RegisterCallback", "UnregisterCallback", "UnregisterAllCallbacks")

local GUIDES = type(ns.DungeonGuides) == "table" and ns.DungeonGuides or {}

local function dungeonName(key)
    return EfficientQuests.DungeonName(key, GUIDES[key])
end

-- Dungeons whose wings share one instance id. The game never says which
-- wing the player is in, so the wing for the player's level is the pick.
local WINGS = {
    [189] = { 1891, 1892, 1893, 1894 }, [329] = { 3291, 3292 },
    [229] = { 2291, 2292 }, [429] = { 4291, 4292, 4293 },
}
-- The level each wing becomes the pick. Stratholme's sides are the same
-- level, and the later wings of the others sit behind their own level
-- gates, so the first wing is the pick until its level says otherwise.
local WING_FROM = { [1891] = 0, [1892] = 35, [1893] = 38, [1894] = 41,
    [3291] = 0, [3292] = 1000, [2291] = 0, [2292] = 1000,
    [4291] = 0, [4292] = 1000, [4293] = 1000 }

-- A dungeon back after longer than this is a new run: dungeons reset.
local RUN_HOURS = 2

-- The running state. The run -- the kills of this visit -- survives the
-- exit for the reset time, so a quick return to the same dungeon resumes
-- where the player stood. `inside` is the key of the running guide, nil
-- outside a dungeon.
local inside
local run = nil
local hidRoute = false

-- A written guide for a dungeon by the name the game gives it: WoW
-- Forever's own dungeons, whose instance ids the generated table does not
-- know. The name matches with its leading "the" and its punctuation off,
-- the way Trailwright matches it.
local namedFor = {}
local function bare(text)
    return (text:lower():gsub("^the ", ""):gsub("[^%a%d]", ""))
end
local function namedGuide(name)
    if type(name) ~= "string" then return nil end
    local wanted = bare(name)
    for key, dungeon in pairs(GUIDES) do
        for _, known in ipairs(type(dungeon.names) == "table" and dungeon.names or {}) do
            if type(known) == "string" and bare(known) == wanted then return key end
        end
    end
    return nil
end

-- The guide key of the dungeon the player stands in, or nil in the open
-- world and in a dungeon the data does not know.
local function resolveInstance()
    if not (IsInInstance and IsInInstance()) then return nil end
    if not GetInstanceInfo then return nil end
    local name, _, _, _, _, _, _, id = GetInstanceInfo()
    if type(id) ~= "number" then return nil end
    local wings = WINGS[id]
    if wings then
        local level = reader.GetLevel() or 1
        local pick = wings[1]
        for _, wing in ipairs(wings) do
            if level >= (WING_FROM[wing] or 0) then pick = wing end
        end
        return GUIDES[pick] and pick or nil
    end
    if GUIDES[id] then return id end
    namedFor[id] = namedFor[id] or namedGuide(name)
    return namedFor[id]
end

local function notify()
    self.callbacks:Fire("GuideChanged", {
        active = inside ~= nil, key = inside, guide = inside and GUIDES[inside] or nil,
    })
end

-- Is this stop done? The shape follows the stops table's own contract:
-- doneBy names the npc whose death completes the stop -- the event stop
-- of a ritual completes when the ritual's boss dies --, quest the quest
-- whose completion -- or whose follow-up in the log -- does.
local function stopDone(stop)
    if run.killed[stop.doneBy or stop.npc] then return true end
    if type(stop.quest) == "number" then
        if reader.IsCompleted(stop.quest) then return true end
        if type(stop.follow) == "number"
            and (reader.IsOnQuest(stop.follow) or reader.IsCompleted(stop.follow)) then
            return true
        end
    end
    return false
end

--- Whether one stop of the running guide is done: the window's tick asks,
--- and so does the hand mark.
function self.StopDone(stop)
    return stopDone(stop)
end

-- Index of the first stop still to do. Optional stops the player went
-- past -- a later stop is done -- do not count.
local function currentIndex(stops)
    local lastDone = 0
    for at, stop in ipairs(stops) do
        if stopDone(stop) then lastDone = at end
    end
    for at, stop in ipairs(stops) do
        local passed = stop.optional and at < lastDone
        if not stopDone(stop) and not passed then return at end
    end
    return nil
end

--- The first stop still to do, or nil when every stop is done: the
--- window's open stop asks.
function self.CurrentIndex(stops)
    return currentIndex(stops)
end

--------------------------------------------------------------------------------
-- Boss deaths
--------------------------------------------------------------------------------

-- Does a death count for this stop: the stop's own npc, or one it names
-- in also; its name, or one of its encounter names.
local function matches(stop, npc, name)
    if type(npc) == "number" then
        if stop.npc == npc then return true end
        for _, other in ipairs(type(stop.also) == "table" and stop.also or {}) do
            if other == npc then return true end
        end
    end
    if type(name) == "string" and type(stop.name) == "string" then
        local lowered = name:lower()
        if stop.name:lower() == lowered then return true end
        for _, other in ipairs(type(stop.names) == "table" and stop.names or {}) do
            if type(other) == "string" and other:lower() == lowered then return true end
        end
    end
    return false
end

-- A creature died: every stop of the running guide it counts for is done.
local function killed(npc, name)
    if not inside then return end
    local dungeon = GUIDES[inside]
    if type(dungeon) ~= "table" then return end
    local moved = false
    for _, stop in ipairs(dungeon.stops or {}) do
        if matches(stop, npc, name) then
            run.seen = time()
            if not run.killed[stop.npc] then
                run.killed[stop.npc] = true
                moved = true
            end
        end
    end
    if moved then
        window.refresh()
        notify()
    end
end

-- The creature id of a unit guid, or nil for anything not a creature or
-- a vehicle.
local function creatureID(guid)
    if type(guid) ~= "string" then return nil end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
    return tonumber(id)
end

--------------------------------------------------------------------------------
-- Start, stop, and the display handoff
--------------------------------------------------------------------------------

-- Take the display from the step window: it leaves the screen only when
-- it was on it, and exactly that hiding is undone on release.
local function takeDisplay()
    if stepWindow and stepWindow.IsShown() then
        stepWindow.Hide()
        hidRoute = true
    end
    window.Show()
end

local function releaseDisplay()
    window.Hide()
    if hidRoute and stepWindow then
        stepWindow.Show()
    end
    hidRoute = false
end

local function start(key)
    if not run or run.map ~= key or (time() - (run.seen or 0)) > RUN_HOURS * 3600 then
        run = { map = key, killed = {}, seen = time() }
    else
        run.seen = time()
    end
    inside = key
    DEFAULT_CHAT_FRAME:AddMessage("Efficient Quests: dungeon guide on for "
        .. dungeonName(key)
        .. ". Right-click a stop to mark it; it moves on by itself as bosses die.")
    takeDisplay()
    window.refresh()
    notify()
end

local function stop()
    inside = nil
    releaseDisplay()
    notify()
end

-- The world says the player changed zones. The change of the dungeon
-- lands on the next frame -- the step window shows itself on the same
-- event, and this module must not fight it inside one dispatch -- and
-- many events of one crossing coalesce into one change.
local pending = false
local function check()
    if pending then return end
    pending = true
    C_Timer.After(0, function()
        pending = false
        local key = resolveInstance()
        if key == inside then
            if inside then
                run.seen = time()
                window.refresh()
            end
            return
        end
        if inside then stop() end
        if key then start(key) end
    end)
end

--- Whether the guide runs right now: the player is inside a dungeon the
--- data knows.
function self.IsActive()
    return inside ~= nil
end

--- The running guide, { key = the key the guide is kept under, guide =
--- that table }, or nil outside.
function self.GetActiveGuide()
    if not inside then return nil end
    return { key = inside, guide = GUIDES[inside] }
end

--- The hand mark (user story 60): "done" marks the stop of this npc
--- done, "undo" clears the mark again. The mark writes the kill record
--- the stop reads, so a stop that completes with another npc's death
--- marks that record, the way a right detection would have.
function self.MarkStop(npcID, how)
    if not inside or type(npcID) ~= "number" then return end
    local dungeon = GUIDES[inside]
    if type(dungeon) ~= "table" then return end
    for _, marked in ipairs(dungeon.stops or {}) do
        if marked.npc == npcID then
            if how == "done" then
                run.killed[marked.doneBy or marked.npc] = true
            elseif how == "undo" then
                run.killed[marked.doneBy or marked.npc] = nil
            end
            window.refresh()
            notify()
            return
        end
    end
end

-- Every quest state change can move a stop: a hand-in finishes its
-- quest, an accepted pick is the follow-up that completes the stop
-- before it. The refresh waits for the next frame, the way the step
-- window waits, so every listener of one change has settled first.
local watches = {}
for _, name in ipairs({ "QuestAccepted", "QuestHandedIn" }) do
    reader.RegisterCallback(watches, name, function()
        C_Timer.After(0, function()
            if inside then window.refresh() end
        end)
    end)
end

-- The world the guide watches. No COMBAT_LOG_EVENT_UNFILTERED: this
-- client forbids addons to register it, so boss deaths are seen through
-- the game's boss events and the player's target.
local events = CreateFrame("Frame")
for _, name in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
    "ENCOUNTER_END", "BOSS_KILL", "PLAYER_TARGET_CHANGED", "UNIT_HEALTH" }) do
    events:RegisterEvent(name)
end
events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        check()
        return
    end
    if not inside then return end
    if event == "ENCOUNTER_END" then
        -- The encounter id, its name, ..., and success: 1 means the boss
        -- died. A wipe marks nothing.
        local _, name, _, _, success = ...
        if success == 1 and type(name) == "string" then killed(nil, name) end
    elseif event == "BOSS_KILL" then
        local _, name = ...
        if type(name) == "string" then killed(nil, name) end
    elseif event == "PLAYER_TARGET_CHANGED"
        or (event == "UNIT_HEALTH" and ... == "target") then
        -- The player looking at a dead boss counts as its death: the
        -- group killed it and the event never reached this client.
        if UnitIsDead and UnitIsDead("target") and UnitGUID then
            local id = creatureID(UnitGUID("target"))
            if id then killed(id) end
        end
    end
end)
