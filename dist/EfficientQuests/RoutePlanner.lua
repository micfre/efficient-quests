-- The route planner: a port of the Path walker of Trailwright. It builds
-- the route -- the ordered list of route entries -- from the data store's
-- quest facts and Path and from the quest state reader's answers.
--
-- The route entry shape, for the step model (#33) and the step window
-- (#35):
--
--   { kind = "pickup", questID = number }   take the quest
--   { kind = "do", questID = number }       do its objectives
--   { kind = "turnin", questID = number }   hand it in
--   { kind = "turnin", questID = number, near = true }
--       a finished quest whose hand-in point stood within 300 yards of
--       the player on the same continent: these come first, nearest
--       first, whatever the order of the Path
--   { kind = "do" or "turnin", questID = number, own = true }
--       a quest from the log that the Path itself does not do; it stays
--       on the route until the player hands it in, also when the data
--       store knows no facts for it (story 20): the step model then
--       builds its step from the live log
--   { kind = "levelup", level = number }
--       the "Level up to N" step: always the last entry, present when the
--       next quests of the Path need a higher level than the player has
--
-- GetRoute() answers the ordered array. The planner rebuilds it when the
-- quest state reader reports a change -- a quest accepted, progressed,
-- completed, handed in, or abandoned, or a level up -- and when the skip
-- list or the abandoned quests of the character changed, which no
-- callback reports. Between changes the same table comes back.
--
-- The walk joins the Path where it is at the level of the player minus
-- two levels and applies the filters of the specification in order:
-- finished quests first, then the quests the race or class cannot take,
-- the grey quests, the abandoned quests, and the skip list. The quests
-- the race, class, or colour bar only gate the pick-up of a quest the
-- player does not have: a quest in the log keeps its steps, because the
-- player cannot undo taking it.
--
-- This module also wires the abandon detection: the QuestAbandoned
-- callback of the reader records the abandon in the character store, and
-- QuestAccepted clears it again when the player retakes the quest.

local _, ns = ...
local reader = EfficientQuests.questState
local store = EfficientQuests.characterStore
local geo = EfficientQuests.geo
local fields = EfficientQuests.questFields

local planner = {}
EfficientQuests.routePlanner = planner

-- The next quest of the Path may be baked up to this many levels above
-- the player, and the walk joins the Path where it is at the level of the
-- player minus this many levels (Trailwright's AHEAD and BEHIND).
local AHEAD, BEHIND = 2, 2
-- Route entries handed out at a time (Trailwright's WINDOW).
local WINDOW = 90
-- A finished quest whose hand-in is within this many yards of the player,
-- on the same continent, comes first (Trailwright's HERE_YARDS).
local HERE_YARDS = 300

-- The start area of a character, by race: the key of its Path line. A
-- Skyborne picks its own Path by faction; an unknown race falls back to
-- the faction's common start (Trailwright's StartKey).
local RACE_START = { Scourge = "undead", Undead = "undead", Orc = "orc", Troll = "orc",
    Tauren = "tauren", Human = "human", Dwarf = "dwarf", Gnome = "dwarf", NightElf = "nelf" }
local RACE_ID_START = { [5] = "undead", [2] = "orc", [8] = "orc", [6] = "tauren",
    [1] = "human", [3] = "dwarf", [7] = "dwarf", [4] = "nelf" }

local function startKey(player)
    local key = (player.raceID and RACE_ID_START[player.raceID])
        or (player.race and RACE_START[player.race])
    if key then return key end
    if player.race == "Skyborne" then
        return player.faction == "Alliance" and "skyborne_a" or "skyborne_h"
    end
    return player.faction == "Alliance" and "human" or "orc"
end

-- The events of one Path line, parsed once per line: { letter, questID,
-- level }. The letters are the grammar of the generated data: "a" pick
-- up, "d" do, "t" hand in, "g<N>" level up to N.
local parsedLines = {}
local function pathEvents(line)
    if parsedLines[line] then return parsedLines[line] end
    local list = {}
    for kind, id, level in line:gmatch("(%a)(%d+)%.(%d+)") do
        list[#list + 1] = { kind, tonumber(id), tonumber(level) }
    end
    parsedLines[line] = list
    return list
end

-- A bit test over the race and class masks of the generated quest facts.
-- A mask of nil or 0 means the quest is open to everyone.
local function maskAllows(mask, bit)
    if not mask or mask == 0 or not bit then return true end
    return math.floor(mask / bit) % 2 == 1
end

-- The race bit of a race id follows the generated data: ids up to 26 take
-- 2 ^ (id - 1), the Skyborne races take the bits past 2 ^ 31.
local function raceBit(raceID)
    if not raceID then return nil end
    if raceID == 95 then return 2 ^ 32 end
    if raceID == 96 then return 2 ^ 33 end
    if raceID >= 1 and raceID <= 26 then return 2 ^ (raceID - 1) end
    return nil
end

-- How many levels below the player a quest is still worth taking: the
-- grey band of the client (Trailwright's TrivialRange). Under level 6
-- nothing is grey; up to level 40 the band grows slowly, above that in
-- steps of five.
local function trivialRange(level)
    if level <= 5 then return 99 end
    if level <= 39 then return 5 + math.floor(level / 10) - 1 end
    return math.floor(level / 5)
end

-- The build of the route: near hand-ins first, then the Path from where
-- it meets the level of the player, then the quests of the log that the
-- Path itself does not place.
local function build()
    local route = {}
    -- Before login the game has not handed the saved tables over, so no
    -- character exists whose route this would be.
    if type(EfficientQuestsCharacter) ~= "table" then return route end
    local quests = ns.quests or {}
    local starts = (ns.pathData and ns.pathData.starts) or {}
    local player = reader.GetPlayer()
    local level = player.level or 1
    local log = reader.GetLog()
    local list = pathEvents(starts[startKey(player)] or "")
    local carried = {} -- quests the route already carries in full
    local emitted = {} -- kind ":" id of every entry, to keep each step single
    local taken = {} -- quests this walk picks up along the way
    local doing = {} -- quests whose objectives the walk has a step for
    local gate = nil -- the level of the "Level up to N" the walk stopped at

    -- Finished quests in the log whose hand-in stands within HERE_YARDS of
    -- the player come first, nearest first, whatever the order of the
    -- Path: the route must not send the player away and back. Only the
    -- hand-ins move; the walk then skips these quests.
    local here = reader.GetPlayerWorld()
    if here then
        local near = {}
        for id, entry in pairs(log) do
            if entry.complete and not store.isSkipped(id) and not store.isAbandoned(id) then
                local q = quests[id]
                local finish = q and q[fields.finishPoint]
                local spot = finish and geo.worldOf(finish)
                local distance = spot and geo.sameContinent(spot, here)
                    and geo.yards(here, spot)
                if distance and distance <= HERE_YARDS then near[#near + 1] = { id, distance } end
            end
        end
        table.sort(near, function(a, b) return a[2] < b[2] end)
        for _, n in ipairs(near) do
            carried[n[1]] = true
            emitted["t:" .. n[1]] = true
            route[#route + 1] = { kind = "turnin", questID = n[1], near = true }
        end
    end

    -- Where the walk joins the Path: the first event at the level of the
    -- player minus BEHIND. Levels gained off the Path never move the join
    -- point past the quests of the player's own level.
    local first = #list + 1
    for index, event in ipairs(list) do
        if event[3] >= level - BEHIND then first = index break end
    end

    for index = first, #list do
        if #route >= WINDOW then break end
        local event = list[index]
        local kind, id, at = event[1], event[2], event[3]
        if kind == "g" then
            -- A baked-in gate: the Path itself says to level up here.
            if level < id then
                gate = id
                break
            end
        elseif kind ~= "b" then
            local q = quests[id]
            local have = log[id] ~= nil or taken[id] ~= nil
            -- The filters, in the order of the specification. The race,
            -- class, and colour bars gate only the pick-up of a quest the
            -- player does not have.
            if q and not carried[id] and not reader.IsCompleted(id)
                and not store.isAbandoned(id) and not store.isSkipped(id) then
                local barred = not have and not (maskAllows(q[4], raceBit(player.raceID))
                    and maskAllows(q[5], player.classID and 2 ^ (player.classID - 1)))
                local grey = not have and (level - q[2] > trivialRange(level)
                    or (at < level and q[2] <= level - 5))
                local ahead = not have and (at > level + AHEAD or q[3] > level)
                if not barred and not grey then
                    if ahead then
                        -- The next quests are for a higher level: the gate
                        -- closes the route here instead of skipping ahead.
                        gate = math.max(q[3], at - AHEAD)
                        break
                    elseif kind == "a" and not have then
                        taken[id] = true
                        emitted["a:" .. id] = true
                        route[#route + 1] = { kind = "pickup", questID = id }
                    elseif have then
                        local entry = log[id]
                        if kind == "d" and not emitted["d:" .. id] then
                            doing[id] = true
                            emitted["d:" .. id] = true
                            route[#route + 1] = { kind = "do", questID = id }
                        elseif kind == "t" and not emitted["t:" .. id]
                            and not (entry and not entry.complete
                                and (entry.need or 0) > (entry.done or 0) and not doing[id]) then
                            -- A hand-in with objectives still open and no
                            -- step to do them: the game will not take it
                            -- yet.
                            emitted["t:" .. id] = true
                            route[#route + 1] = { kind = "turnin", questID = id }
                        end
                    end
                end
            end
        end
    end

    -- Quests in the log that the walk did not place: the Path either does
    -- them before the join point or not at all. They stay on the route
    -- until the player hands them in, at the end and marked as the own
    -- work of the player -- also the ones the data store knows no facts
    -- for (story 20): what the log holds, the route keeps.
    local own = {}
    for id in pairs(log) do
        if not carried[id] and not emitted["a:" .. id]
            and not emitted["d:" .. id] and not emitted["t:" .. id]
            and not store.isSkipped(id) and not store.isAbandoned(id) then
            own[#own + 1] = id
        end
    end
    table.sort(own)
    for _, id in ipairs(own) do
        if not log[id].complete then
            emitted["d:" .. id] = true
            route[#route + 1] = { kind = "do", questID = id, own = true }
        end
        emitted["t:" .. id] = true
        route[#route + 1] = { kind = "turnin", questID = id, own = true }
    end

    -- The gate closes the route: the step model and the window show it as
    -- the "Level up to N" step, the last of the route.
    if gate and level < gate then
        route[#route + 1] = { kind = "levelup", level = gate }
    end
    return route
end

-- The route of the last build, and what makes it stale: a change callback
-- of the reader, or a write into the character stores that no callback
-- reports.
local route, stale, storeMark = nil, true, nil

local function storeFingerprint()
    local saved = EfficientQuestsCharacter
    if type(saved) ~= "table" then return "" end
    local marks = {}
    for id in pairs(saved.skipped or {}) do marks[#marks + 1] = "s" .. id end
    for id in pairs(saved.abandoned or {}) do marks[#marks + 1] = "a" .. id end
    table.sort(marks)
    return table.concat(marks, ",")
end

--- The route: the ordered array of route entries in the shape the header
--- of this module documents. Ask again after a change; between changes
--- the same table comes back.
function planner.GetRoute()
    local mark = storeFingerprint()
    if route == nil or stale or mark ~= storeMark then
        route = build()
        storeMark = mark
        stale = false
    end
    return route
end

-- Every change callback of the reader replans the route. The replan
-- listener and the wiring below each own their subscription, because the
-- callback handler keys its registry by owner.
local replans = {}
for _, callback in ipairs(reader.CHANGE_CALLBACKS) do
    reader.RegisterCallback(replans, callback, function() stale = true end)
end

-- The pending abandon detection of ticket #31: the reader reports a quest
-- that left the log without a hand-in, once its moment of grace is over,
-- and the character store records the abandon. Taking the quest again
-- clears the record, so the quest returns to the route. The character
-- stores read the saved tables the game hands over on login, so the
-- wiring waits for that moment; quest events never come before it.
local abandonWiring = {}
local wiringFrame = CreateFrame("Frame")
wiringFrame:RegisterEvent("PLAYER_LOGIN")
wiringFrame:SetScript("OnEvent", function()
    reader.RegisterCallback(abandonWiring, "QuestAbandoned", function(_, payload)
        if payload and payload.questID then store.recordAbandoned(payload.questID) end
    end)
    reader.RegisterCallback(abandonWiring, "QuestAccepted", function(_, payload)
        if payload and payload.questID then store.clearAbandoned(payload.questID) end
    end)
end)
