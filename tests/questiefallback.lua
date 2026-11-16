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
