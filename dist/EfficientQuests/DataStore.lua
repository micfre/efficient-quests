-- The data store of Efficient Quests. The three generated Trailwright
-- tables -- the quest data, the Path, and the dungeon guide stops -- load
-- before this file (see the manifest) into the addon's private namespace,
-- where the later modules read them. This module checks the shape of each
-- table at load time, reports one clear message per broken table, and
-- keeps the addon running without the guides that need that table. It
-- also exposes the data snapshot identity that the status command shows.

local _, ns = ...

-- The snapshot identity of the copied data: the one-time Trailwright
-- snapshot, with both of its version numbers (see THIRD_PARTY.md), the
-- Path version from the data itself, and the date of the copy. The quest
-- data and the dungeon guides carry no version of their own.
local SNAPSHOT_SOURCE = "Trailwright 0.1.81-beta (1.51.0)"
local COPY_DATE = "2026-11-16"

function EfficientQuests.GetDataSnapshot()
    local pathVersion = "?"
    if type(ns.pathData) == "table" and type(ns.pathData.version) == "string" then
        pathVersion = ns.pathData.version
    end
    return SNAPSHOT_SOURCE .. ", path data v" .. pathVersion .. ", copied " .. COPY_DATE
end

-- The display names of the dungeons, in our own words -- the same words
-- the dungeon window titles itself with and the menu lists. Wings that
-- the guide finds by name carry theirs in their names list; the key
-- stands in for anything still unknown. This is the one place that
-- holds them.
local DUNGEON_NAMES = {
    [389] = "Ragefire Chasm", [43] = "Wailing Caverns", [48] = "Blackfathom Deeps",
    [33] = "Shadowfang Keep", [47] = "Razorfen Kraul", [36] = "The Deadmines",
    [90] = "Gnomeregan", [129] = "Razorfen Downs", [70] = "Uldaman",
    [349] = "Maraudon", [209] = "Zul'Farrak", [109] = "The Sunken Temple",
    [34] = "The Stockade", [289] = "Scholomance", [230] = "Blackrock Depths",
    [1891] = "Scarlet Monastery: Graveyard", [1892] = "Scarlet Monastery: Library",
    [1893] = "Scarlet Monastery: Armory", [1894] = "Scarlet Monastery: Cathedral",
    [3291] = "Stratholme: Main Gate", [3292] = "Stratholme: Service Gate",
    [2291] = "Lower Blackrock Spire", [2292] = "Upper Blackrock Spire",
    [4291] = "Dire Maul: East", [4292] = "Dire Maul: West", [4293] = "Dire Maul: North",
    [2999] = "Ruins of Lordaeron",
}

--- The display name of a dungeon key: our own words first, then the
--- guide's own names list, its short key, and the key itself. The
--- dungeon guide and the menu ask this one place.
function EfficientQuests.DungeonName(key, guide)
    if DUNGEON_NAMES[key] then return DUNGEON_NAMES[key] end
    if type(guide) == "table" then
        if type(guide.names) == "table" and type(guide.names[1]) == "string" then
            return guide.names[1]
        end
        if type(guide.key) == "string" then return guide.key end
    end
    return tostring(key)
end

-- What the loader watches over: where each table lives in the namespace,
-- how to name it in a message, and what stops working without it. The
-- three tables are the three data topics the Trailwright snapshot holds.
local TABLES = {
    {
        key = "quests", label = "quest data", effect = "Quest steps stay plain.",
        -- The quests table maps quest ids to entries whose first field is
        -- the quest name. Every entry must be such a table, and at least
        -- one quest must be present.
        wellFormed = function(quests)
            if next(quests) == nil then return false end
            for _, quest in pairs(quests) do
                if type(quest) ~= "table" or type(quest[1]) ~= "string" then return false end
            end
            return true
        end,
    },
    {
        key = "pathData", label = "Path", effect = "The leveling route cannot be built.",
        -- The Path data carries its own version and one event line per
        -- start area, both strings.
        wellFormed = function(pathData)
            if type(pathData.version) ~= "string" then return false end
            if type(pathData.starts) ~= "table" then return false end
            for _, line in pairs(pathData.starts) do
                if type(line) ~= "string" then return false end
            end
            return true
        end,
    },
    {
        key = "DungeonGuides", label = "dungeon guide", effect = "Dungeon guides will not appear.",
        -- Every guide needs its stop list, and every stop a kind and a
        -- name; that is the shape the dungeon guide reads.
        wellFormed = function(guides)
            if next(guides) == nil then return false end
            for _, guide in pairs(guides) do
                if type(guide) ~= "table" or type(guide.stops) ~= "table" then return false end
                for _, stop in ipairs(guide.stops) do
                    if type(stop) ~= "table" or type(stop.name) ~= "string"
                        or type(stop.kind) ~= "string" then return false end
                end
            end
            return true
        end,
    },
}

-- One clear message for a table the addon cannot use, saying whether it is
-- missing or malformed and what the player loses. Nothing raises: the
-- addon keeps running without the guides that need the table.
local function report(setting, state)
    DEFAULT_CHAT_FRAME:AddMessage("Efficient Quests: the " .. setting.label
        .. " table is " .. state .. ". " .. setting.effect)
end

for _, setting in ipairs(TABLES) do
    if ns[setting.key] == nil then
        report(setting, "missing")
    elseif type(ns[setting.key]) ~= "table" or not setting.wellFormed(ns[setting.key]) then
        report(setting, "malformed")
    end
end

-- The quests table is positional: the generated layout gives every quest
-- fact a fixed index, and the code reads those indexes by name through
-- this table, so a reader never meets a bare number. The name is the only
-- field the loader itself checks (see the shape note in TABLES above);
-- the rest belong to the route planner and the step model.
local QUEST_FIELDS = {
    name = 1,             -- "Wolf pelts": the quest's own name
    startPoint = 8,       -- { uiMapID, x, y } in percent: where it is picked up
    finishPoint = 9,      -- { uiMapID, x, y } in percent: where it is handed in
    objectivePoints = 10, -- the known places of the work, as point triples
    giverName = 19,       -- the name on the pick-up's Talk to line
    enderName = 20,       -- the name on the hand-in's Talk to line
    targets = 26,         -- one entry per goal: { name, { npc ids }, { object ids }, count, item id }
    giverNpc = 27,        -- the npc id of the giver, for the hover
    enderNpc = 28,        -- the npc id of the ender, for the hover
    tipPickup = 30,       -- the tip under the pick-up's Talk to line
    tipHandIn = 31,       -- the tip under the hand-in's Talk to line
    rewardItems = 33,     -- the fixed reward item ids
    rewardChoices = 34,   -- the choose-one reward item ids
    rewardSpell = 36,     -- the spell a reward teaches
}
EfficientQuests.questFields = QUEST_FIELDS

-- The store answers first on the reader's query seam: it registers one
-- lookup per kind, reading the copied tables directly, before any later
-- fallback (the QuestieDB module) appends its own -- the reader runs the
-- chain in registration order, so the store always wins. A missing or
-- malformed table answers nothing here -- the loader said its one message
-- above -- and the question falls through to the fallback instead of
-- raising. The reader itself loads first by the manifest; if even that
-- file is gone, the install is broken, and the store keeps quiet, the
-- same promise the loader makes about the tables.
local reader = EfficientQuests.questState

if reader then
    -- The quest table maps ids to entries whose first field is the name.
    reader.RegisterLookup("questName", function(questID)
        local quest = type(ns.quests) == "table" and ns.quests[questID] or nil
        if type(quest) == "table" and type(quest[1]) == "string" then
            return quest[1]
        end
        return nil
    end)

    -- The extra name table is the correction layer: it wins over the base
    -- one, the way the Trailwright code reads them.
    reader.RegisterLookup("npcName", function(npcID)
        local extra = type(ns.npcNamesExtra) == "table" and ns.npcNamesExtra[npcID] or nil
        if type(extra) == "string" then return extra end
        local base = type(ns.npcNames) == "table" and ns.npcNames[npcID] or nil
        if type(base) == "string" then return base end
        return nil
    end)

    -- The spawn table lists flat { uiMapID, x, y } triples per npc in
    -- percent; the first point is the one the Trailwright code used too.
    reader.RegisterLookup("npcPosition", function(npcID)
        local spawns = type(ns.npcSpawns) == "table" and ns.npcSpawns[npcID] or nil
        if type(spawns) == "table"
            and type(spawns[1]) == "number"
            and type(spawns[2]) == "number"
            and type(spawns[3]) == "number" then
            return { spawns[1], spawns[2], spawns[3] }
        end
        return nil
    end)
end
