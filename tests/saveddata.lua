-- The saved data of the addon: the defaults after a fresh login, the split
-- between the account-wide store and the per-character store, and the
-- promise that keys from the old plugin era are not migrated. The addon
-- loads through the shared seam as on the Forever client, and the suite
-- reads the two tables the game would hand back.
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
-- The Forever client identifies itself with the Camelot project id.
WOW_PROJECT_ID, WOW_PROJECT_CAMELOT = 5, 5

local function login()
  dofile('tests/addon.lua')()
  assert(handlers.OnEvent, 'addon must listen for login')
  handlers.OnEvent(nil, 'PLAYER_LOGIN')
end

-- A fresh login: the game hands over empty saved tables, and the addon
-- fills in its defaults.
login()
local account, character = EfficientQuestsDB, EfficientQuestsCharacter
assert(type(account) == 'table' and type(character) == 'table',
  'a fresh login must set up both saved tables')
assert(account.window.point == 'TOPLEFT' and account.window.relativePoint == 'TOPLEFT'
  and account.window.x == 16 and account.window.y == -120,
  'a fresh login must place the window at its default spot')
assert(account.scale == 1 and account.opacity == 1,
  'a fresh login must default scale and opacity to 1')
assert(account.locked == false, 'a fresh login must leave the window unlocked')
assert(account.waypoints == true, 'the waypoint toggle must default to on')
assert(type(character.skipped) == 'table' and next(character.skipped) == nil,
  'a fresh login must start with an empty skip list')
assert(type(character.abandoned) == 'table' and next(character.abandoned) == nil,
  'a fresh login must start with no abandoned quests')
assert(character.followMode == false, 'a fresh login must start with Follow mode off')
print('ok - a fresh login applies the saved-data defaults')

-- The account-wide store and the per-character store each hold only what
-- belongs to them, so a second character inherits the window but not the
-- route choices.
assert(character.scale == nil and character.opacity == nil and character.locked == nil
  and character.waypoints == nil and character.window == nil,
  'the window settings belong to the account-wide store alone')
assert(account.skipped == nil and account.abandoned == nil and account.followMode == nil,
  'the skip list, the abandoned quests, and Follow mode belong to the character store alone')
print('ok - window settings are account-wide and route choices are per character')

-- A saved session keeps the values of the player. Only keys that are
-- missing, or hold a value of the wrong type, fall back to their default.
EfficientQuestsDB = {
  scale = 0.75,
  opacity = 'see-through',
  window = { point = 'CENTER', relativePoint = 'CENTER', x = 0, y = 40 },
}
EfficientQuestsCharacter = {
  skipped = { [25] = true },
  followMode = true,
}
login()
account, character = EfficientQuestsDB, EfficientQuestsCharacter
assert(account.scale == 0.75, 'a saved scale must survive a login')
assert(account.window.point == 'CENTER' and account.window.x == 0 and account.window.y == 40,
  'a saved window position must survive a login')
assert(account.opacity == 1, 'a value of the wrong type must fall back to its default')
assert(account.locked == false and account.waypoints == true,
  'missing keys must still be filled in around the saved ones')
assert(character.skipped[25] == true and next(character.skipped, 25) == nil,
  'a saved skip list must survive a login unchanged')
assert(character.abandoned ~= nil and next(character.abandoned) == nil,
  'a missing skip list companion must be filled in without touching the rest')
assert(character.followMode == true, 'a saved Follow mode must survive a login')
print('ok - saved values survive a login and only broken ones fall back')

-- The old plugin era stored its own keys in the per-character table. The
-- addon does not migrate them: they stay where they are, unchanged, and
-- nothing moves into the account-wide store.
local oldTurnedIn = { [105] = true }
EfficientQuestsDB = {}
EfficientQuestsCharacter = {
  turnedIn = oldTurnedIn,
  dismissed = { [7] = true },
  display = { width = 340 },
  guide = 'EfficientQuests_Old',
}
login()
account, character = EfficientQuestsDB, EfficientQuestsCharacter
assert(character.turnedIn == oldTurnedIn and character.turnedIn[105] == true,
  'old turn-in records must be neither moved nor dropped')
assert(character.dismissed[7] == true and character.display.width == 340
  and character.guide == 'EfficientQuests_Old',
  'old plugin-era keys must be left exactly as they are')
assert(account.turnedIn == nil and account.dismissed == nil and account.display == nil
  and account.guide == nil,
  'old keys must not migrate into the account-wide store')
assert(character.skipped ~= nil and character.followMode ~= nil,
  'the new defaults still arrive beside the untouched old keys')
print('ok - old plugin-era keys are left in place without migration')
