-- The data store: the copied Trailwright tables load with the addon, the
-- loader checks their shape at load time, and the snapshot identity is
-- ready for the status command. A broken install still loads: exactly one
-- clear message per broken table, and the addon keeps running without the
-- guides that need that table.
local messages, handlers = {}, {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) table.insert(messages, message) end }
SlashCmdList = {}
function CreateFrame()
  return {
    RegisterEvent = function() end,
    UnregisterAllEvents = function() end,
    SetScript = function(_, name, handler) handlers[name] = handler end,
  }
end
function CreateVector2D() return {} end
-- The player is not in the world while the addon files load; the suite
-- fires PLAYER_LOGIN itself when a scenario needs it.
function IsLoggedIn() return false end
-- An empty world: the map service knows no maps, which is enough for the
-- libraries to load. The data tables need no game service at all.
C_Map = { GetMapInfo = function() return nil end, GetMapChildrenInfo = function() return nil end }

-- Load one addon file by hand, the way the game does, into a namespace the
-- scenario controls. A scenario leaves a data file out or breaks a table
-- in it, then loads the data store and reads what the player would see.
local function loadFile(path, namespace)
  assert(loadfile('dist/EfficientQuests/' .. path))('EfficientQuests', namespace)
end

-- The real copied tables, the way the game loads the addon: every data
-- file ran, the loader found nothing to complain about, and the snapshot
-- identity names the Trailwright snapshot and the Path version in the data.
dofile('tests/addon.lua')()
assert(#messages == 0, 'well-formed data tables must load without a message')
local snapshot = EfficientQuests.GetDataSnapshot()
assert(type(snapshot) == 'string' and snapshot:find('Trailwright', 1, true),
  'the data snapshot identity must name the Trailwright snapshot it comes from')
assert(snapshot:find('v15', 1, true),
  'the data snapshot identity must carry the Path version from the copied data')
print('ok - the copied tables load quietly and expose their snapshot identity')

-- A data file the player's install lost: the namespace never received the
-- dungeon guide stops. The loader says so once, clearly, and the addon
-- keeps running without the dungeon guides.
messages = {}
local broken = {}
loadFile('Core.lua', broken)
loadFile('QuestData.lua', broken)
loadFile('PathData.lua', broken)
-- DungeonGuides.lua never loaded: the file is missing from the install.
loadFile('DataStore.lua', broken)
assert(#messages == 1,
  'a missing table must produce exactly one message, got ' .. #messages)
assert(messages[1]:find('Efficient Quests', 1, true)
  and messages[1]:find('the dungeon guide table is missing', 1, true),
  'the message must say which addon speaks and name the missing table: '
  .. tostring(messages[1]))
assert(type(EfficientQuests.GetDataSnapshot()) == 'string',
  'the addon keeps running after a missing data table')
print('ok - a missing table gets one clear message and the addon keeps running')

-- A corrupted install wrote something that is not a table where the quest
-- data belongs. The loader calls the table malformed, once, and keeps the
-- rest of the addon alive.
messages = {}
broken = {}
loadFile('Core.lua', broken)
loadFile('QuestData.lua', broken)
loadFile('PathData.lua', broken)
loadFile('DungeonGuides.lua', broken)
broken.quests = "not a table"
loadFile('DataStore.lua', broken)
assert(#messages == 1,
  'a malformed table must produce exactly one message, got ' .. #messages)
assert(messages[1]:find('the quest data table is malformed', 1, true),
  'the message must name the malformed table clearly: ' .. tostring(messages[1]))
assert(type(EfficientQuests.GetDataSnapshot()) == 'string',
  'the addon keeps running after a malformed data table')
print('ok - a table of the wrong type gets one clear malformed message')

-- A table that is a table but not the shape the addon reads: the Path
-- without its start lists. One malformed message, and the rest works.
messages = {}
broken = {}
loadFile('Core.lua', broken)
loadFile('QuestData.lua', broken)
loadFile('PathData.lua', broken)
loadFile('DungeonGuides.lua', broken)
broken.pathData = { version = "15" }
loadFile('DataStore.lua', broken)
assert(#messages == 1, 'the Path without starts must produce exactly one message, got ' .. #messages)
assert(messages[1]:find('the Path table is malformed', 1, true),
  'the message must name the Path table as malformed: ' .. tostring(messages[1]))
print('ok - a Path table without its start lists gets one malformed message')

-- The same for the other shapes the loader knows: a dungeon guide without
-- its stop list, and a quest table with no quests in it.
local scenarios = {
    {
        what = 'a guide without stops',
        breakIt = function() broken.DungeonGuides[389] = { key = "rfc", levels = "13-18" } end,
        wanted = 'the dungeon guide table is malformed',
    },
    {
        what = 'an empty quest table',
        breakIt = function() broken.quests = {} end,
        wanted = 'the quest data table is malformed',
    },
}
for _, scenario in ipairs(scenarios) do
    messages = {}
    broken = {}
    loadFile('Core.lua', broken)
    loadFile('QuestData.lua', broken)
    loadFile('PathData.lua', broken)
    loadFile('DungeonGuides.lua', broken)
    scenario.breakIt()
    loadFile('DataStore.lua', broken)
    assert(#messages == 1,
        scenario.what .. ' must produce exactly one message, got ' .. #messages)
    assert(messages[1]:find(scenario.wanted, 1, true),
        scenario.what .. ' must get its malformed message, saw: ' .. tostring(messages[1]))
end
print('ok - guides without stops and empty quest tables get one malformed message')
