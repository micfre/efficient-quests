-- The QuestieDB fallback.
--
-- QuestieDB is optional. When it is loaded and agrees to its contract,
-- this module appends three lookups to the quest state reader's query
-- chain: the name of a quest, the name of an NPC, and the coordinates of
-- an NPC, for the ids the data store left unanswered. The store registers
-- its own lookups first (see DataStore.lua), and the reader runs the
-- chain in registration order, so this fallback can never replace data
-- the store already has. Without a usable QuestieDB the module registers
-- nothing and the addon works on its own data alone.
--
-- Whatever the whole chain leaves unanswered gets one clear message per
-- missing id, in the shape of the data store loader's messages: one chat
-- line, and the addon keeps running. The message resolvers sit at the end
-- of each chain, so they run only after the store and the fallback both
-- came back empty, and they answer nil themselves.

local reader = EfficientQuests.questState

-- A usable QuestieDB: the global exists, it accepts the contract this
-- fallback is written against, and the two entities the lookups need
-- answer field reads. Anything else is an absent or incompatible
-- QuestieDB, and the module stays out of the way.
local function usableLib()
    local lib = _G.LibQuestieDB
    if type(lib) ~= "table" then return nil end
    if type(lib.RequireContract) ~= "function" then return nil end
    local called, agreed = pcall(lib.RequireContract, 1)
    if not called or not agreed then return nil end
    for _, entity in ipairs({ "Quest", "Npc" }) do
        if type(lib[entity]) ~= "table" or type(lib[entity].Get) ~= "function" then
            return nil
        end
    end
    return lib
end

local lib = usableLib()

-- QuestieDB keys NPC spawns by AreaID, a different frame than the
-- client's UiMapIDs, and ships the bridge between the two as Lua source
-- text inside the ZoneDB support data, with an override layered on top.
-- Decode both once per ZoneDB table: the support data does not change
-- while the game runs, and a copy keeps the override merge off the
-- provider's own tables.
local function decodeAreaMap(source, field)
    local value = source[field]
    if type(value) == "table" then
        local copy = {}
        for areaId, uiMapID in pairs(value) do copy[areaId] = uiMapID end
        return copy
    end
    if type(value) == "string" and loadstring then
        local chunk = loadstring(value)
        if chunk then
            local ran, result = pcall(chunk)
            if ran and type(result) == "table" then return result end
        end
    end
    return nil
end

local cachedZoneDB, cachedAreas
local function areaToUiMap()
    if type(lib.Support) ~= "table" or type(lib.Support.Get) ~= "function" then
        return nil
    end
    local called, zoneDB = pcall(lib.Support.Get, "ZoneDB")
    if not called or type(zoneDB) ~= "table"
        or type(zoneDB.private) ~= "table" then
        return nil
    end
    if zoneDB ~= cachedZoneDB then
        local areas = decodeAreaMap(zoneDB.private, "areaIdToUiMapId")
        local override = decodeAreaMap(zoneDB.private, "areaIdToUiMapIdOverride")
        if areas and override then
            for areaId, uiMapID in pairs(override) do areas[areaId] = uiMapID end
        end
        cachedZoneDB, cachedAreas = zoneDB, areas
    end
    return cachedAreas
end

if lib then
    reader.RegisterLookup("questName", function(questID)
        local name = lib.Quest.Get(questID, "name")
        if type(name) == "string" then return name end
        return nil
    end)

    reader.RegisterLookup("npcName", function(npcID)
        local name = lib.Npc.Get(npcID, "name")
        if type(name) == "string" then return name end
        return nil
    end)

    reader.RegisterLookup("npcPosition", function(npcID)
        local spawns = lib.Npc.Get(npcID, "spawns")
        if type(spawns) ~= "table" then return nil end
        local areas = areaToUiMap()
        if not areas then return nil end
        for areaId, points in pairs(spawns) do
            -- Map id 0 is the bridge's own "no map" fail-safe, not a
            -- place a waypoint can point to.
            local uiMapID = areas[areaId]
            if type(uiMapID) == "number" and uiMapID > 0
                and type(points) == "table" then
                local point = points[1]
                local x = type(point) == "table" and tonumber(point[1]) or nil
                local y = type(point) == "table" and tonumber(point[2]) or nil
                if x and y and x >= 0 and x <= 100 and y >= 0 and y <= 100 then
                    return { uiMapID, x, y }
                end
            end
        end
        return nil
    end)
end

-- One clear message per missing id when the whole chain -- the store,
-- then the fallback -- still leaves a question unanswered, so the player
-- knows why a step stays plain. One line per kind and id per session, in
-- the shape of the data store loader's messages; the resolvers answer
-- nil, so the chain's answer stays nil.
local MISSING = {
    questName = function(questID)
        return "Efficient Quests: no name data for quest " .. questID
            .. ". Its step stays plain."
    end,
    npcName = function(npcID)
        return "Efficient Quests: no name data for NPC " .. npcID
            .. ". Its step stays plain."
    end,
    npcPosition = function(npcID)
        return "Efficient Quests: no position data for NPC " .. npcID
            .. ". Its step stays plain."
    end,
}

local reported = {}
for kind, words in pairs(MISSING) do
    reader.RegisterLookup(kind, function(id)
        if type(id) ~= "number" then return nil end
        local key = kind .. ":" .. id
        if not reported[key] then
            reported[key] = true
            DEFAULT_CHAT_FRAME:AddMessage(words(id))
        end
        return nil
    end)
end
