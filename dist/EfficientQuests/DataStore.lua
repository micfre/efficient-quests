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
