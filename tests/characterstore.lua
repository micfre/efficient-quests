-- The character stores: the skip list, the abandoned quests, and the
-- Follow mode switch. The addon loads through the shared seam as on the
-- Forever client, and the suite drives the store actions and reads both
-- the answers and the per-character saved table that the game hands back.
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

-- A login loads the addon files again, so the addon table and the store
-- on it are new every time. Each scenario takes the store it gets back.
local function login()
  dofile('tests/addon.lua')()
  assert(handlers.OnEvent, 'addon must listen for login')
  handlers.OnEvent(nil, 'PLAYER_LOGIN')
  assert(type(EfficientQuests.characterStore) == 'table',
    'the addon must offer the character store after a login')
  return EfficientQuests.characterStore
end

local store = login()

-- A right-click skip lands in the per-character saved table, the list
-- query shows every skipped quest id in a steady order, and a restore
-- takes the quest back out.
store.skip(40)
store.skip(25)
assert(EfficientQuestsCharacter.skipped[25] == true and EfficientQuestsCharacter.skipped[40] == true,
  'a skip must land in the per-character saved table')
assert(store.isSkipped(25) == true and store.isSkipped(40) == true,
  'a skipped quest must answer as skipped')
assert(store.isSkipped(77) == false,
  'a quest that was never skipped must answer as not skipped')
local ids = store.list()
assert(#ids == 2 and ids[1] == 25 and ids[2] == 40,
  'the list query must return the skipped quest ids in rising order')
store.restore(25)
assert(store.isSkipped(25) == false and EfficientQuestsCharacter.skipped[25] == nil,
  'a restore must take the quest out of the saved table')
ids = store.list()
assert(#ids == 1 and ids[1] == 40,
  'a restored quest must have left the list')
print('ok - a skipped quest is stored, listed, and restored by hand')

-- An abandoned quest stays out of the route, and a quest that the player
-- takes again leaves the abandoned list. The quest state reader reports
-- both moments; this suite plays the reader and calls the same handlers.
store.recordAbandoned(31)
assert(EfficientQuestsCharacter.abandoned[31] == true,
  'a reported abandon must land in the per-character saved table')
assert(store.isAbandoned(31) == true,
  'an abandoned quest must answer as abandoned')
assert(store.isAbandoned(12) == false,
  'a quest that was never abandoned must answer as not abandoned')
store.clearAbandoned(31)
assert(EfficientQuestsCharacter.abandoned[31] == nil,
  'the re-accept path must take the quest out of the saved table')
assert(store.isAbandoned(31) == false,
  'a quest taken again must answer as not abandoned')
print('ok - an abandoned quest is recorded and a re-accept clears it')

-- The skip list belongs to one character. A second character starts with
-- its own empty stores, and neither character sees the skips of the
-- other.
local firstCharacter = EfficientQuestsCharacter
assert(store.isSkipped(40) == true, 'the first character keeps its skip')
EfficientQuestsCharacter = {}
store = login()
assert(store.isSkipped(40) == false,
  'a new character must not inherit the skip of another character')
assert(store.isAbandoned(31) == false,
  'a new character must not inherit the abandons of another character')
store.skip(25)
assert(firstCharacter.skipped[40] == true and firstCharacter.skipped[25] == nil,
  'a skip of the second character must not reach the first saved table')
assert(EfficientQuestsCharacter.skipped[25] == true and EfficientQuestsCharacter.skipped[40] == nil,
  'the skip of the second character must land in its own saved table')
print('ok - two characters keep their skip lists apart')

-- Follow mode is a switch of one character. The switch lands in the
-- saved table, so it survives the next login of that character.
assert(store.isFollowMode() == false,
  'Follow mode must answer as off after a fresh login')
store.setFollowMode(true)
assert(store.isFollowMode() == true,
  'Follow mode must answer as on after the switch')
assert(EfficientQuestsCharacter.followMode == true,
  'the Follow mode switch must land in the per-character saved table')
store = login()
assert(store.isFollowMode() == true,
  'a saved Follow mode must survive a login')
store.setFollowMode(false)
assert(store.isFollowMode() == false and EfficientQuestsCharacter.followMode == false,
  'turning Follow mode off must land in the saved table too')
print('ok - the Follow mode switch is stored and survives a login')
