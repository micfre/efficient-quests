-- The optional addons of Efficient Quests: FlareUI, TomTom, and QuestieDB,
-- the three the manifest names as OptionalDeps. This module is the one
-- place that asks whether one of them is present, and it asks the
-- strictest question a consumer can act on -- a global alone says nothing,
-- because a broken or an incompatible copy answers the same global name:
--
--   FlareUI()   its global table or its tracker frame: either one says the
--               addon came up. The look adapter reads the tracker frame;
--               the status command reports the verdict.
--   TomTom()    the TomTom table when it answers the calls the waypoint
--               bridge makes -- IsCrazyArrowEmpty, AddWaypoint, and
--               RemoveWaypoint, the surface the TomTom README documents
--               for addons -- or nil.
--   QuestieDB() the LibQuestieDB table when it passes the contract test
--               the fallback is written against -- the contract call and
--               the two entities the lookups read -- or nil.
--
-- Every check runs live, so an addon that loads late is seen the moment it
-- is there, and no other module reads these globals itself.

local addons = {}
EfficientQuests.optionalAddons = addons

--- Whether FlareUI is present: its global table or its tracker frame.
function addons.FlareUI()
    return type(_G.FlareUI) == "table" or _G.FlareUI_ObjectiveTracker ~= nil
end

--- The TomTom table when it answers the calls the bridge makes, else nil.
function addons.TomTom()
    local tomtom = _G.TomTom
    if type(tomtom) ~= "table" then return nil end
    if type(tomtom.IsCrazyArrowEmpty) ~= "function" then return nil end
    if type(tomtom.AddWaypoint) ~= "function" then return nil end
    if type(tomtom.RemoveWaypoint) ~= "function" then return nil end
    return tomtom
end

--- The QuestieDB library when it passes the contract test the fallback
--- applies, else nil.
function addons.QuestieDB()
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
