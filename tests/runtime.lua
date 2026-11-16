-- The entry point of the addon: the addon table exists right after load,
-- and on login the addon either starts quietly on the Forever client or
-- says once, clearly, that it supports the Forever client only and runs
-- nothing. No optional addon is provided: the addon must stand alone.
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
-- libraries to load, and the position questions come later, with the
-- quest state reader.
C_Map = { GetMapInfo = function() return nil end, GetMapChildrenInfo = function() return nil end }

-- The addon table exists as soon as the files are loaded, before any
-- event fires, so the later modules have a namespace to hang off.
dofile('tests/addon.lua')()
assert(type(EfficientQuests) == 'table', 'the entry point must create the addon table')
print('ok - the addon table exists right after load')
assert(handlers.OnEvent, 'addon must listen for login')

-- Another client flavor identifies itself with a project id of its own.
-- The game hands over the empty saved tables, the way it does for every
-- addon, and the addon must leave them empty and speak only once.
WOW_PROJECT_ID, WOW_PROJECT_CAMELOT = 1, 5
EfficientQuestsDB, EfficientQuestsCharacter = {}, {}
handlers.OnEvent(nil, 'PLAYER_LOGIN')
assert(#messages == 1 and messages[1]:find('Forever client only', 1, true),
  'a player on another flavor must get exactly one clear message about Forever only')
assert(next(EfficientQuestsDB) == nil and next(EfficientQuestsCharacter) == nil,
  'the addon must not write any saved data on a client it does not support')
print('ok - another client flavor gets one message and no setup at all')

-- The Forever client identifies itself with the Camelot project id. The
-- same session then starts silently, the way a supported player expects
-- it, with the saved-data defaults in place.
WOW_PROJECT_ID = 5
messages = {}
handlers.OnEvent(nil, 'PLAYER_LOGIN')
assert(#messages == 0, 'the Forever client must start without a warning')
assert(EfficientQuestsDB ~= nil and EfficientQuestsDB.waypoints == true,
  'the Forever client must start with the saved-data defaults applied')
print('ok - the Forever client starts silently with the defaults applied')
