-- The quest state reader: the only module that talks to the quest
-- functions of the game. This suite loads the addon through the shared
-- seam with the quest log, the player, the position, and the timer
-- services faked, then reads the state through the reader's public
-- questions and listens to its change callbacks.

-- The game services, in the shape the reader uses them. Each suite keeps
-- its own copy of this fake world and drives it by hand.
local frames = {}
local function CreateFrameFake()
  local frame = { events = {}, scripts = {} }
  function frame:RegisterEvent(event) frame.events[event] = true end
  function frame:UnregisterEvent(event) frame.events[event] = nil end
  function frame:UnregisterAllEvents() frame.events = {} end
  function frame:SetScript(name, handler) frame.scripts[name] = handler end
  table.insert(frames, frame)
  return frame
end
CreateFrame = CreateFrameFake
-- An event reaches exactly the frames that registered for it, the way the
-- game delivers events, so library frames and addon frames stay separate.
local function fire(event, ...)
  for _, frame in ipairs(frames) do
    if frame.events[event] and frame.scripts.OnEvent then
      frame.scripts.OnEvent(frame, event, ...)
    end
  end
end

DEFAULT_CHAT_FRAME = { AddMessage = function() end }
SlashCmdList = {}
CreateVector2D = function() return {} end
IsLoggedIn = function() return false end
WOW_PROJECT_ID, WOW_PROJECT_CAMELOT = 5, 5
Enum = { UIMapType = { Micro = 4 } }
securecallfunction = function(fn, ...) return fn(...) end
local timers = {}
C_Timer = { After = function(delay, fn) table.insert(timers, fn) end }

-- The character sheet: level, race, class, faction.
local player = {
  level = 7, raceName = 'Undead', raceID = 5,
  className = 'Mage', classID = 8, faction = 'Horde',
}
UnitLevel = function() return player.level end
UnitRace = function() return player.raceName, player.raceName, player.raceID end
UnitClass = function() return player.className, player.className, player.classID end
UnitFactionGroup = function() return player.faction end

-- The quest log: an ordered list of entries, the objectives per quest,
-- and the completion flags the client would answer.
local logEntries = {}
local objectives = {}
local completeFlag = {}
local onQuest = {}
local flaggedCompleted = {}
local completedIDs = { 12, 34 }
C_QuestLog = {
  GetNumQuestLogEntries = function() return #logEntries end,
  GetInfo = function(index) return logEntries[index] end,
  GetQuestObjectives = function(questID) return objectives[questID] end,
  IsComplete = function(questID) return completeFlag[questID] end,
  IsOnQuest = function(questID) return onQuest[questID] end,
  IsQuestFlaggedCompleted = function(questID) return flaggedCompleted[questID] end,
  GetAllCompletedQuestIDs = function() return completedIDs end,
}

-- The position: UnitPosition answers y, x, height, instance.
local world = { x = 1500.25, y = 2000.5, instance = 1 }
local inInstance = false
UnitPosition = function()
  if not world then return nil end
  return world.y, world.x, 50.75, world.instance
end
IsInInstance = function() return inInstance end
local bestMap = 1429
C_Map = {
  GetMapInfo = function() return nil end,
  GetMapChildrenInfo = function() return nil end,
  GetBestMapForUnit = function() return bestMap end,
}

-- QuestieDB must never be called by the reader; these sentinels fail the
-- suite the moment anything reaches for them.
LibQuestieDB = {
  Quest = { Get = function() error('the reader must not call QuestieDB') end },
  Npc = { Get = function() error('the reader must not call QuestieDB') end },
}

dofile('tests/addon.lua')()
local reader = EfficientQuests.questState
assert(type(reader) == 'table', 'the addon must expose the quest state reader after load')
print('ok - the quest state reader exists right after load')

-- The reader answers the character facts of the player as the game
-- reports them: the level, the race, the class, and the faction.
local facts = reader.GetPlayer()
assert(facts.level == 7, 'the reader must report the level of the player')
assert(facts.race == 'Undead' and facts.raceID == 5,
  'the reader must report the race of the player by name and id')
assert(facts.class == 'Mage' and facts.classID == 8,
  'the reader must report the class of the player by name and id')
assert(facts.faction == 'Horde', 'the reader must report the faction of the player')
assert(reader.GetLevel() == 7, 'the reader must answer the level on its own')
print('ok - the reader answers the level, race, class, and faction of the player')

-- Every change callback carries its name and one payload table to each
-- subscriber. This recorder listens to all of them for the rest of the
-- suite, so each scenario below asserts on what it heard.
assert(type(reader.RegisterCallback) == 'function' and type(reader.UnregisterCallback) == 'function',
  'the reader must offer the CallbackHandler subscription API')
local seen = {}
local function listen(name)
  local owner = {}
  reader.RegisterCallback(owner, name, function(what, payload)
    assert(what == name, 'a subscriber must hear the callback name first, then the payload')
    table.insert(seen, { name = what, payload = payload })
  end)
  return owner
end
listen('QuestAccepted')
listen('QuestProgressed')
listen('QuestCompleted')
listen('QuestHandedIn')
listen('QuestAbandoned')
listen('PlayerLevelUp')

-- A later scenario needs the addon a second time, on an older client
-- shape: the libraries detect the reload and stand still, the reader
-- starts fresh, and the recorder moves over to the new reader.
local function loadAddonAgain()
  for index = #frames, 1, -1 do frames[index] = nil end
  dofile('tests/addon.lua')()
  reader = EfficientQuests.questState
  assert(type(reader) == 'table', 'the addon must expose the quest state reader after load')
  listen('QuestAccepted')
  listen('QuestProgressed')
  listen('QuestCompleted')
  listen('QuestHandedIn')
  listen('QuestAbandoned')
  listen('PlayerLevelUp')
end

-- On level up the game can still answer the old level when asked right
-- away, so the reader keeps the level the event announced, and it tells
-- its subscribers the new level.
fire('PLAYER_LEVEL_UP', 8)
assert(#seen == 1 and seen[1].name == 'PlayerLevelUp' and seen[1].payload.level == 8,
  'a level up must fire PlayerLevelUp with the new level as the payload')
assert(reader.GetLevel() == 8, 'the reader must keep the level the event announced')
player.level = 8
assert(reader.GetLevel() == 8, 'a later live read must keep the new level')
seen = {}
print('ok - a level up reaches the subscribers and the reader keeps the new level')

-- The quest log: two quests with objectives, one under a zone header. A
-- plain log update must not fire any change callback by itself, because
-- nothing changed yet.
logEntries = {
  { title = 'Eastern Kingdoms', isHeader = true, isCollapsed = false },
  { questID = 83, title = 'A boar hunt', level = 5, isHeader = false },
  { questID = 84, title = 'Bring the heads', level = 5, isHeader = false },
}
objectives[83] = {
  { text = 'Boar tusks', numFulfilled = 3, numRequired = 7, finished = false },
  { text = 'Boar flanks', numFulfilled = 2, numRequired = 2, finished = true },
}
objectives[84] = {
  { text = 'Troll heads', numFulfilled = 0, numRequired = 4, finished = false },
}
fire('QUEST_LOG_UPDATE')
assert(#seen == 0, 'a log update with no change must fire no callback')
local hunt = reader.GetQuest(83)
assert(hunt ~= nil and hunt.title == 'A boar hunt' and hunt.level == 5,
  'a quest in the log must answer with its title and level')
assert(#hunt.objectives == 2 and hunt.objectives[1].text == 'Boar tusks',
  'a quest in the log must answer with its objectives')
assert(hunt.done == 5 and hunt.need == 9,
  'the entry must sum the objective counts: 3+2 of 7+2, with a finished objective full')
assert(not hunt.complete, 'a quest with an open objective is not complete')
local heads = reader.GetQuest(84)
assert(heads ~= nil and heads.done == 0 and heads.need == 4, 'the second quest must sum its counts')
assert(reader.IsOnQuest(83) and not reader.IsOnQuest(99),
  'the reader must say which quests are in the log')
assert(reader.GetQuest(99) == nil, 'a quest outside the log must answer nil')
local log = reader.GetLog()
assert(log[83] == hunt and log[84] == heads, 'the whole log must answer as one table')
local count = 0; for _ in pairs(log) do count = count + 1 end
assert(count == 2, 'the zone header must not appear as a quest')
print('ok - the reader answers the quest log with objectives and counts')

-- Objective progress: one more boar tusk. Only the quest whose counts
-- changed may fire, and the payload carries the quest and its title.
objectives[83] = {
  { text = 'Boar tusks', numFulfilled = 4, numRequired = 7, finished = false },
  { text = 'Boar flanks', numFulfilled = 2, numRequired = 2, finished = true },
}
fire('QUEST_LOG_UPDATE')
assert(#seen == 1 and seen[1].name == 'QuestProgressed'
    and seen[1].payload.questID == 83 and seen[1].payload.title == 'A boar hunt',
  'a changed objective count must fire QuestProgressed for that quest alone')
seen = {}

-- An update with no change stays silent, and a quest that was already
-- reported complete does not fire QuestCompleted twice.
fire('QUEST_LOG_UPDATE')
assert(#seen == 0, 'a log update with no change must stay silent')
seen = {}

-- The last objective fills: the quest progressed and is now complete,
-- with both callbacks in that order.
objectives[83] = {
  { text = 'Boar tusks', numFulfilled = 7, numRequired = 7, finished = false },
  { text = 'Boar flanks', numFulfilled = 2, numRequired = 2, finished = true },
}
fire('QUEST_LOG_UPDATE')
assert(#seen == 2 and seen[1].name == 'QuestProgressed' and seen[1].payload.questID == 83,
  'filling the last objective must fire QuestProgressed')
assert(seen[2].name == 'QuestCompleted' and seen[2].payload.questID == 83
    and seen[2].payload.title == 'A boar hunt',
  'a quest whose objectives are all done must fire QuestCompleted once')
assert(reader.GetQuest(83).complete == true, 'the completed quest must answer complete')
seen = {}
fire('QUEST_LOG_UPDATE')
assert(#seen == 0, 'a quest that is still complete must not fire QuestCompleted again')
seen = {}

-- The client can also mark a quest complete on its own, with the
-- objective counts untouched: that fires QuestCompleted too.
completeFlag[84] = true
fire('QUEST_LOG_UPDATE')
assert(#seen == 1 and seen[1].name == 'QuestCompleted' and seen[1].payload.questID == 84,
  'a quest the client marks complete must fire QuestCompleted')
seen = {}
print('ok - objective progress and completion reach the subscribers')

-- Taking a quest: the reader hears QUEST_ACCEPTED, re-reads the log, and
-- fires QuestAccepted with the quest and its title.
table.insert(logEntries, { questID = 90, title = 'A new errand', level = 6, isHeader = false })
objectives[90] = {
  { text = 'Errands run', numFulfilled = 0, numRequired = 1, finished = false },
}
fire('QUEST_ACCEPTED', 90)
assert(#seen == 1 and seen[1].name == 'QuestAccepted'
    and seen[1].payload.questID == 90 and seen[1].payload.title == 'A new errand',
  'taking a quest must fire QuestAccepted with the quest id and title')
assert(reader.IsOnQuest(90), 'the accepted quest must sit in the log the reader answers')
seen = {}

-- Older clients pass the log index first; the reader must take the quest
-- id from the second argument.
table.insert(logEntries, { questID = 91, title = 'An old errand', level = 6, isHeader = false })
fire('QUEST_ACCEPTED', 4, 91)
assert(#seen == 1 and seen[1].name == 'QuestAccepted' and seen[1].payload.questID == 91,
  'the reader must strip the log index of older clients')
seen = {}
print('ok - taking a quest reaches the subscribers in both argument orders')

-- Handing in: QUEST_TURNED_IN carries the quest id. The reader marks the
-- quest completed at once -- the client's own completed list can load
-- late -- takes it out of the log, and fires QuestHandedIn.
fire('QUEST_TURNED_IN', 83)
assert(#seen == 1 and seen[1].name == 'QuestHandedIn' and seen[1].payload.questID == 83,
  'handing in a quest must fire QuestHandedIn with the quest id')
assert(reader.IsCompleted(83) == true,
  'a handed-in quest must answer completed at once, before the client list loads')
assert(not reader.IsOnQuest(83), 'a handed-in quest must leave the log')
seen = {}
print('ok - handing in reaches the subscribers and marks the quest completed')

-- The completed quests: the client list, the quests the client flags on
-- its own, and the handed-in one together answer IsCompleted, and the
-- count covers them all.
flaggedCompleted[50] = true
assert(reader.IsCompleted(12) and reader.IsCompleted(34),
  'the quests of the client completed list must answer completed')
assert(reader.IsCompleted(50),
  'a quest the client flags completed must answer completed')
assert(not reader.IsCompleted(99), 'an unknown quest must not answer completed')
assert(reader.GetCompletedCount() == 3,
  'the completed count must cover the client list and the handed-in quest')
seen = {}

-- An older client has no C_QuestLog completed list and answers a plain
-- set from GetQuestsCompleted instead; the reader reads that shape too.
C_QuestLog.GetAllCompletedQuestIDs = nil
GetQuestsCompleted = function() return { [7] = true } end
loadAddonAgain()
assert(reader.IsCompleted(7), 'the legacy completed set must answer completed')
assert(not reader.IsCompleted(8), 'the legacy completed set must stay exact')
seen = {}
print('ok - the completed quests answer from the client list and the legacy set')

-- The delayed checks run through the fake timer, so the suite decides
-- when the moment of grace has passed.
local function runTimers()
  local pending = timers
  timers = {}
  for _, fn in ipairs(pending) do fn() end
end

-- A quest leaves the log without a hand-in: the reader waits a moment --
-- a hand-in can reach the removed event before the game marks the quest
-- completed -- and only then reports the quest abandoned.
logEntries = {
  { questID = 90, title = 'A new errand', level = 6, isHeader = false },
  { questID = 91, title = 'An old errand', level = 6, isHeader = false },
}
fire('QUEST_LOG_UPDATE')
seen = {}
logEntries = {
  { questID = 91, title = 'An old errand', level = 6, isHeader = false },
}
fire('QUEST_REMOVED', 90)
assert(#seen == 0,
  'the reader must not call a removal an abandonment before its moment of grace')
runTimers()
assert(#seen == 1 and seen[1].name == 'QuestAbandoned'
    and seen[1].payload.questID == 90 and seen[1].payload.title == 'A new errand',
  'a quest that leaves the log without a hand-in must fire QuestAbandoned')
seen = {}

-- A quest the game still counts as taken has not been abandoned.
onQuest[91] = true
logEntries = {}
fire('QUEST_REMOVED', 91)
runTimers()
assert(#seen == 0, 'a quest the game still counts as taken is not abandoned')
onQuest[91] = nil
seen = {}

-- A quest flagged completed by the client has been handed in, not
-- abandoned.
flaggedCompleted[92] = true
fire('QUEST_REMOVED', 92)
runTimers()
assert(#seen == 0, 'a quest flagged completed has been handed in, not abandoned')
seen = {}

-- The plain hand-in order of the game: turn-in first, then removal. No
-- abandonment may fire for it either.
logEntries = {
  { questID = 93, title = 'A plain hand-in', level = 6, isHeader = false },
}
objectives[93] = {
  { text = 'Anything', numFulfilled = 0, numRequired = 1, finished = false },
}
fire('QUEST_LOG_UPDATE')
seen = {}
fire('QUEST_TURNED_IN', 93)
logEntries = {}
fire('QUEST_REMOVED', 93)
runTimers()
assert(#seen == 1 and seen[1].name == 'QuestHandedIn' and seen[1].payload.questID == 93,
  'the hand-in must be heard once')
seen = {}
print('ok - only a true abandonment fires QuestAbandoned')

-- The position is pulled, never pushed: the caller asks, the reader
-- answers through the embedded HereBeDragons, which reads UnitPosition.
-- That service answers y before x; the reader must hand back the world
-- position as { x, y, instance }.
local here = reader.GetPlayerWorld()
assert(here ~= nil and here[1] == 1500.25 and here[2] == 2000.5 and here[3] == 1,
  'the reader must answer the player world position { x, y, instance } from HereBeDragons')

-- Inside an instance the reader answers nothing, the way Trailwright
-- did: world distances mean nothing between continents and dungeons.
inInstance = true
assert(reader.GetPlayerWorld() == nil, 'no world position inside an instance')
inInstance = false

-- A player not yet in the world has no position at all.
world = nil
assert(reader.GetPlayerWorld() == nil, 'no world position outside the world')

-- The current map of the player, straight from the map service.
assert(reader.GetPlayerMap() == 1429, 'the reader must answer the current map id')
bestMap = nil
assert(reader.GetPlayerMap() == nil, 'no map id when the map service knows none')
print('ok - the reader answers the position and the map when asked')

-- The query seam: the reader holds no data of its own. A module registers
-- lookups, the data store first and a QuestieDB fallback later, and the
-- questions run the chain until one answers. The reader itself never
-- touches QuestieDB -- the sentinels at the top of this suite fail the
-- run the moment anything does. The data store registers its own lookups
-- at load, ahead of anything planted here, so the chain tests ask for ids
-- that the copied tables do not hold; a real id would let the store
-- answer before the suite's own fakes run.
local asked = {}
reader.RegisterLookup('questName', function(questID)
  table.insert(asked, 'store:' .. questID)
  if questID == 91001 then return 'An old errand (store)' end
  return nil
end)
reader.RegisterLookup('questName', function(questID)
  table.insert(asked, 'fallback:' .. questID)
  return 'Quest ' .. questID .. ' (from QuestieDB)'
end)
logEntries = {
  { questID = 94, title = 'From the log', level = 6, isHeader = false },
}
fire('QUEST_LOG_UPDATE')
seen = {}
assert(reader.QuestName(94) == 'From the log',
  'a quest in the log must answer its name from the log first, before any lookup')
assert(#asked == 0, 'a log title must not run the lookups at all')
assert(reader.QuestName(91001) == 'An old errand (store)',
  'the data store lookup must answer the quest name')
assert(asked[#asked] == 'store:91001',
  'a lookup that answers must stop the chain: the fallback never runs')
assert(reader.QuestName(91002) == 'Quest 91002 (from QuestieDB)',
  'the later lookup must answer what the store left unanswered')
assert(asked[#asked - 1] == 'store:91002' and asked[#asked] == 'fallback:91002',
  'the chain must ask the store first, the fallback second')
asked = {}

reader.RegisterLookup('npcName', function(npcID)
  if npcID == 91003 then return 'Deputy Willem' end
  return nil
end)
assert(reader.NpcName(91003) == 'Deputy Willem', 'the npc name lookup must answer')
assert(reader.NpcName(999) == nil, 'an unknown npc must answer nil')

reader.RegisterLookup('npcPosition', function(npcID)
  if npcID == 91003 then return { 1429, 48.2, 42.9 } end
  return nil
end)
local spot = reader.NpcPosition(91003)
assert(spot ~= nil and spot[1] == 1429 and spot[2] == 48.2 and spot[3] == 42.9,
  'the npc position lookup must answer { uiMapID, x, y } in percent')
assert(reader.NpcPosition(999) == nil, 'an unknown npc position must answer nil')

local bad = pcall(reader.RegisterLookup, 'bogus', function() end)
assert(not bad, 'an unknown lookup kind must be rejected loudly')
print('ok - the query seam runs the lookups in order and stays unanswered by itself')

-- Several modules can listen to the same change at once, each under its
-- own table, and one module can stop its subscription alone.
local moduleA, moduleB = { heard = 0 }, { heard = 0 }
reader.RegisterCallback(moduleA, 'QuestAccepted', function() moduleA.heard = moduleA.heard + 1 end)
reader.RegisterCallback(moduleB, 'QuestAccepted', function() moduleB.heard = moduleB.heard + 1 end)
fire('QUEST_ACCEPTED', 95)
assert(moduleA.heard == 1 and moduleB.heard == 1,
  'every subscriber of a change must hear it, not only the last one')
reader.UnregisterCallback(moduleA, 'QuestAccepted')
fire('QUEST_ACCEPTED', 96)
assert(moduleA.heard == 1 and moduleB.heard == 2,
  'stopping one subscription must leave the others in place')
seen = {}
print('ok - every module hears the changes under its own subscription')
