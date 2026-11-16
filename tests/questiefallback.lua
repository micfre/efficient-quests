-- The QuestieDB fallback: when a quest or an NPC is not in the data
-- store, the quest state reader asks QuestieDB for the name and the
-- coordinates. The fallback never replaces data that the store already
-- has, nothing breaks without QuestieDB, and one clear message appears
-- when data stays missing after the whole chain ran.
local messages, frames = {}, {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) table.insert(messages, message) end }
SlashCmdList = {}
function CreateFrame()
  local frame = { events = {}, scripts = {} }
  function frame:RegisterEvent(event) frame.events[event] = true end
  function frame:UnregisterAllEvents() frame.events = {} end
  function frame:SetScript(name, handler) frame.scripts[name] = handler end
  table.insert(frames, frame)
  return frame
end
function CreateVector2D() return {} end
function IsLoggedIn() return false end
WOW_PROJECT_ID, WOW_PROJECT_CAMELOT = 5, 5
Enum = { UIMapType = { Micro = 4 } }
securecallfunction = function(fn, ...) return fn(...) end
C_Timer = { After = function() end }
C_Map = { GetMapInfo = function() return nil end, GetMapChildrenInfo = function() return nil end }
-- The quest log stays empty: a name question must run the lookup chain,
-- not answer from the log.
C_QuestLog = {
  GetNumQuestLogEntries = function() return 0 end,
  GetInfo = function() return nil end,
  GetQuestObjectives = function() return nil end,
  IsComplete = function() return false end,
  IsQuestFlaggedCompleted = function() return false end,
  GetAllCompletedQuestIDs = function() return {} end,
}

-- The QuestieDB fake. Each scenario plants it before the addon loads, the
-- way the game loads optional dependencies first, and every entity read
-- is counted, so the suite can prove the fallback ran only when the data
-- store had no answer.
local calls
local function plantLibQuestieDB(questNames, npcNames, npcSpawns, areaMapText, overrideText)
  calls = { questName = 0, npcName = 0, npcSpawns = 0 }
  LibQuestieDB = {
    RequireContract = function(required) return required == 1 end,
    Quest = {
      Get = function(questID, field)
        assert(field == 'name', 'the fallback must ask for the name field, not ' .. tostring(field))
        calls.questName = calls.questName + 1
        return questNames[questID]
      end,
    },
    Npc = {
      Get = function(npcID, field)
        if field == 'name' then
          calls.npcName = calls.npcName + 1
          return npcNames[npcID]
        end
        if field == 'spawns' then
          calls.npcSpawns = calls.npcSpawns + 1
          return npcSpawns[npcID]
        end
        error('the fallback must not ask the npc for the field ' .. tostring(field))
      end,
    },
    Support = {
      Get = function(name)
        assert(name == 'ZoneDB', 'the fallback must ask for ZoneDB, not ' .. tostring(name))
        return { private = {
          areaIdToUiMapId = areaMapText,
          areaIdToUiMapIdOverride = overrideText,
        } }
      end,
    },
  }
end

-- Load the addon the way the game does, with whatever QuestieDB state the
-- scenario planted: absent (nil), a working fake, or an incompatible one.
local function loadAddon()
  messages = {}
  dofile('tests/addon.lua')()
  return EfficientQuests.questState
end

-- Scenario one: the plain setup, no QuestieDB at all. The data store
-- answers the reader's questions from the copied Trailwright tables: the
-- quest name, the NPC name, and the NPC position in percent on the first
-- spawn point the data lists. The values below are the ones the copied
-- tables hold for these ids.
LibQuestieDB = nil
local reader = loadAddon()
assert(reader.QuestName(6) == 'Bounty on Garrick Padfoot',
  'the data store must answer the quest name from the copied quest table')
assert(reader.NpcName(6) == 'Kobold Vermin',
  'the data store must answer the npc name from the copied name table')
local spot = reader.NpcPosition(6)
assert(spot ~= nil and spot[1] == 1429 and spot[2] == 48.9 and spot[3] == 36.4,
  'the data store must answer the first spawn point as { uiMapID, x, y } in percent')
assert(#messages == 0,
  'a question the store answers must not produce a chat message')
print('ok - the data store answers names and positions from its own tables')

-- Scenario two: QuestieDB is loaded and agrees to its contract. The ids
-- the copied tables hold must never reach it -- the store answered first
-- -- and the ids the tables lack must come back from QuestieDB instead.
-- NPC coordinates arrive keyed by AreaID, not by the client's UiMapID,
-- so the fake ships the bridge the real addon sends: the area map as Lua
-- source text, with an override layered on top.
plantLibQuestieDB(
  { [91001] = 'A quest only QuestieDB knows' },
  { [91002] = 'A mover only QuestieDB knows' },
  { [91002] = { [14] = { { 34.5, 67.8 } }, [12] = { { 10, 20 } } } },
  'return { [12] = 1420, [14] = 1433 }',
  'return { [12] = 0 }')
reader = loadAddon()
assert(reader.QuestName(6) == 'Bounty on Garrick Padfoot',
  'the store must still answer the quest name it holds')
assert(reader.NpcName(6) == 'Kobold Vermin',
  'the store must still answer the npc name it holds')
assert(calls.questName == 0 and calls.npcName == 0,
  'a question the store answers must never reach QuestieDB')
assert(reader.QuestName(91001) == 'A quest only QuestieDB knows',
  'a quest the store lacks must come back from QuestieDB')
assert(calls.questName == 1, 'the fallback must ask QuestieDB exactly once')
assert(reader.NpcName(91002) == 'A mover only QuestieDB knows',
  'an npc the store lacks must come back from QuestieDB')
assert(calls.npcName == 1, 'the fallback must ask for the npc name once')
local where = reader.NpcPosition(91002)
assert(where ~= nil and where[1] == 1433 and where[2] == 34.5 and where[3] == 67.8,
  'npc coordinates must arrive as { uiMapID, x, y } in percent, with the'
    .. ' AreaID turned into the UiMapID of the bridge')
assert(calls.npcSpawns == 1, 'the fallback must ask for the spawns once')
assert(#messages == 0,
  'answers from the fallback must not produce a chat message')
print('ok - the store wins and QuestieDB answers only what the store lacks')

-- Data that stays missing after the fallback ran: QuestieDB knows the id
-- neither. The player gets one clear line per missing id -- the shape of
-- the data store loader's messages -- and never a second line for the
-- same id, no matter how often the question repeats. The answer itself
-- stays nil.
plantLibQuestieDB(
  { [91004] = nil },
  { [91005] = nil },
  { [91006] = { [14] = { { 50, 50 } } } },
  'return { }',
  nil)
reader = loadAddon()
assert(reader.QuestName(91004) == nil, 'an id nobody knows must answer nil')
assert(reader.NpcName(91005) == nil, 'an npc nobody knows must answer nil')
assert(reader.NpcPosition(91006) == nil,
  'an npc whose area the bridge does not know must answer nil')
assert(#messages == 3, 'three missing ids must produce three messages, got ' .. #messages)
assert(messages[1]:find('^Efficient Quests: no name data for quest 91004%.', 1),
  'the message must say which addon speaks and which quest lacks data: ' .. messages[1])
assert(messages[2]:find('^Efficient Quests: no name data for NPC 91005%.', 1),
  'the message must name the npc whose name is missing: ' .. messages[2])
assert(messages[3]:find('^Efficient Quests: no position data for NPC 91006%.', 1),
  'the message must name the npc whose position is missing: ' .. messages[3])
reader.QuestName(91004)
reader.NpcName(91005)
reader.NpcPosition(91006)
assert(#messages == 3,
  'a repeated question for the same missing id must not repeat the message')
reader.QuestName(91007)
assert(#messages == 4, 'a different missing id must get its own single message')
print('ok - data still missing after the fallback gets one message per id')

-- A QuestieDB that does not agree to the contract is as good as absent:
-- nothing may reach its entities -- the fake errors the moment anything
-- does -- and the addon keeps running on its own data.
plantLibQuestieDB({}, {}, {})
LibQuestieDB.RequireContract = function() return false, 'contract mismatch' end
LibQuestieDB.Quest.Get = function() error('an incompatible QuestieDB must not be read') end
LibQuestieDB.Npc.Get = function() error('an incompatible QuestieDB must not be read') end
reader = loadAddon()
assert(reader.QuestName(6) == 'Bounty on Garrick Padfoot',
  'the store must keep answering when QuestieDB refuses its contract')
assert(reader.QuestName(91001) == nil,
  'a question the store cannot answer must stay unanswered without a usable QuestieDB')
assert(reader.NpcName(91005) == nil and reader.NpcPosition(91006) == nil,
  'npc questions must stay unanswered without a usable QuestieDB')
print('ok - an incompatible QuestieDB is never read and nothing breaks')

-- Without QuestieDB at all, nothing changes and nothing breaks: the store
-- answers what it holds, the rest stays unanswered, and one message per
-- missing id still explains why.
LibQuestieDB = nil
reader = loadAddon()
assert(reader.QuestName(6) == 'Bounty on Garrick Padfoot',
  'the store must answer its own quest name without QuestieDB')
assert(reader.NpcName(6) == 'Kobold Vermin',
  'the store must answer its own npc name without QuestieDB')
local plain = reader.NpcPosition(6)
assert(plain ~= nil and plain[1] == 1429 and plain[2] == 48.9 and plain[3] == 36.4,
  'the store must answer its own npc position without QuestieDB')
assert(reader.QuestName(91001) == nil and reader.NpcName(91005) == nil,
  'questions the store cannot answer must stay nil, with no error')
assert(reader.NpcPosition(91005) == nil,
  'an npc without any position data must answer nil, with no error')
assert(#messages == 3,
  'without QuestieDB the missing ids still get one message each, got ' .. #messages)
print('ok - without QuestieDB the addon works on its own data alone')
