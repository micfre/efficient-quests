-- The route planner: the port of the Trailwright Path walker. The suite
-- loads the addon once through the shared seam with the real copied data,
-- then loads the code modules by hand per scenario -- the way the data
-- store suite does -- into a namespace that holds the scenario's own
-- synthetic quests and Path, so every filter stage, the join point, the
-- near hand-in rule, the "Level up to N" step, and the replan wiring each
-- get a controlled world.

-- The game services, in the shape the addon uses them. The map fake knows
-- two synthetic maps -- 100 on continent 7 and 200 on continent 8, both
-- 1000 by 1000 yards -- so the embedded HereBeDragons can turn map points
-- into world yards and the distance rules have real numbers to work with.
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
CreateVector2D = function(x, y)
  return { GetXY = function() return y * 1000, x * 1000 end }
end
local function fire(event, ...)
  for _, frame in ipairs(frames) do
    if frame.events[event] and frame.scripts.OnEvent then
      frame.scripts.OnEvent(frame, event, ...)
    end
  end
end

DEFAULT_CHAT_FRAME = { AddMessage = function() end }
SlashCmdList = {}
IsLoggedIn = function() return false end
WOW_PROJECT_ID, WOW_PROJECT_CAMELOT = 5, 5
Enum = { UIMapType = { Zone = 3, Continent = 2 } }
securecallfunction = function(fn, ...) return fn(...) end
local timers = {}
C_Timer = { After = function(delay, fn) table.insert(timers, fn) end }

local MAPS = { [100] = { instance = 7 }, [200] = { instance = 8 } }
-- The addon and the libraries call these with a dot, so the map id is the
-- first argument.
C_Map = {
  GetMapInfo = function(id)
    if not MAPS[id] then return nil end
    return { name = 'Testland ' .. id, mapType = 3, parentMapID = 0 }
  end,
  GetMapChildrenInfo = function() return nil end,
  -- The client answers the instance and the point itself; the point the
  -- library asks for is the centre (0.5, 0.5), whose world place is
  -- (500, 500) through the CreateVector2D fake above.
  GetWorldPosFromMapPos = function(id, point) return MAPS[id] and MAPS[id].instance, point end,
  GetMapWorldSize = function() return 1000, 1000 end,
  GetBestMapForUnit = function() return 100 end,
}

-- The character sheet: an undead mage, the Horde, at a level each scenario
-- picks. The suite moves the player by writing the sheet and firing the
-- game events the client would fire.
local player = { level = 6, raceName = 'Undead', raceID = 5,
  className = 'Mage', classID = 8, faction = 'Horde' }
UnitLevel = function() return player.level end
UnitRace = function() return player.raceName, player.raceName, player.raceID end
UnitClass = function() return player.className, player.className, player.classID end
UnitFactionGroup = function() return player.faction end

-- The quest log: an ordered list of entries, the objectives per quest, and
-- the completion flags the client would answer.
local logEntries, objectives, completeFlag = {}, {}, {}
local onQuest, flaggedCompleted, completedIDs = {}, {}, {}
C_QuestLog = {
  GetNumQuestLogEntries = function() return #logEntries end,
  GetInfo = function(index) return logEntries[index] end,
  GetQuestObjectives = function(questID) return objectives[questID] end,
  IsComplete = function(questID) return completeFlag[questID] end,
  IsOnQuest = function(questID) return onQuest[questID] end,
  IsQuestFlaggedCompleted = function(questID) return flaggedCompleted[questID] end,
  GetAllCompletedQuestIDs = function() return completedIDs end,
}

-- The world position of the player, in yards: nil until a scenario places
-- the player somewhere.
local world = nil
UnitPosition = function()
  if not world then return nil end
  return world.y, world.x, 50, world.instance
end
IsInInstance = function() return false end

-- QuestieDB must never be called; this sentinel fails the suite the moment
-- anything reaches for it.
LibQuestieDB = {
  Quest = { Get = function() error('the planner must not call QuestieDB') end },
  Npc = { Get = function() error('the planner must not call QuestieDB') end },
}

-- Quest facts in the generated 38-field layout, at the positions the
-- planner reads: 1 name, 2 level, 3 required level, 4 race mask, 5 class
-- mask, 9 the hand-in point { map, x%, y% }. A mask of 0 means every race
-- or every class.
local function quest(t)
  return {
    t.name or ('Quest ' .. t.id),
    t.level or 1, t.reqLevel or t.level or 1,
    t.races or 0, t.classes or 0,
    0, 0, nil, t.finish, nil,
  }
end
-- The race and class bits of the generated masks: race 1 human, race 5
-- undead, class 1 warrior, class 8 mage.
local HUMAN, UNDEAD, WARRIOR = 1, 16, 1

-- One controlled scenario: the code modules load by hand, in manifest
-- order, into a namespace whose data tables are the scenario's own. The
-- game starts a fresh character and hands the saved tables over on login.
local function loadPlanner(quests, pathLine)
  EfficientQuestsCharacter = {}
  frames = {}
  logEntries, objectives, completeFlag = {}, {}, {}
  onQuest, flaggedCompleted, completedIDs = {}, {}, {}
  local namespace = {
    quests = quests,
    pathData = { version = "t", starts = { undead = pathLine } },
  }
  local function loadFile(path)
    assert(loadfile('dist/EfficientQuests/' .. path))('EfficientQuests', namespace)
  end
  loadFile('Core.lua')
  loadFile('QuestState.lua')
  loadFile('CharacterStore.lua')
  loadFile('RoutePlanner.lua')
  for _, frame in ipairs(frames) do
    if frame.events['PLAYER_LOGIN'] and frame.scripts.OnEvent then
      frame.scripts.OnEvent(frame, 'PLAYER_LOGIN')
    end
  end
  assert(type(EfficientQuests.routePlanner) == 'table',
    'the addon must offer the route planner after a login')
  return EfficientQuests.routePlanner
end

-- Take a quest the way the game does: the log knows it, an objective is
-- open, and QUEST_ACCEPTED told the reader.
local function takeQuest(id, title)
  table.insert(logEntries, { questID = id, title = title, level = player.level, isHeader = false })
  objectives[id] = { { text = 'Something done', numFulfilled = 0, numRequired = 1, finished = false } }
  fire('QUEST_ACCEPTED', id)
end

-- Fill the last objective of a quest in the log: the quest is complete.
local function finishQuest(id)
  objectives[id] = { { text = 'Something done', numFulfilled = 1, numRequired = 1, finished = true } }
  completeFlag[id] = true
  fire('QUEST_LOG_UPDATE')
end

-- The delayed checks of the reader run through the fake timer, so the
-- suite decides when the moment of grace has passed.
local function runTimers()
  local pending = timers
  timers = {}
  for _, fn in ipairs(pending) do fn() end
end

-- Queries over a route: find one entry, ask for a quest's place on it.
local function entryOf(route, kind, questID)
  for _, entry in ipairs(route) do
    if entry.kind == kind and entry.questID == questID then return entry end
  end
  return nil
end
local function hasQuest(route, questID)
  for _, entry in ipairs(route) do
    if entry.questID == questID then return true end
  end
  return false
end

-- The real copied data plans a route of well-shaped entries: the shared
-- seam loads the addon with the true tables, the player is an undead mage
-- of level 7, and the route answers in the entry shape the module header
-- documents.
dofile('tests/addon.lua')()
local planner = EfficientQuests.routePlanner
assert(type(planner) == 'table' and type(planner.GetRoute) == 'function',
  'the addon must offer the route planner with its route query after load')
fire('PLAYER_LOGIN')
local route = planner.GetRoute()
assert(#route > 0, 'the real data must plan a route for a level 7 undead')
local kinds = { pickup = true, ['do'] = true, turnin = true, levelup = true }
local seen, sawLevelUp = {}, false
for index, entry in ipairs(route) do
  assert(kinds[entry.kind], 'a route entry must carry a known kind, saw ' .. tostring(entry.kind))
  assert(not sawLevelUp, 'the level-up marker must be the last entry of the route')
  if entry.kind == 'levelup' then
    sawLevelUp = true
    assert(type(entry.level) == 'number', 'the level-up marker must name the level to reach')
  else
    assert(type(entry.questID) == 'number',
      'a quest entry must carry the quest id, entry ' .. index)
    local key = entry.kind .. ':' .. entry.questID
    assert(not seen[key], 'a quest must not take the same step twice: ' .. key)
    seen[key] = true
  end
end
print('ok - the real data plans a route of well-shaped entries')

-- The join point by level: the Path starts where it is at the player's
-- level, so the quests of the levels long past stay out and the quests of
-- the player's own level lead the route.
local quests = {
  [101] = quest { id = 101, name = 'Rite of the young', level = 2, reqLevel = 1 },
  [102] = quest { id = 102, name = 'The joined path', level = 5, reqLevel = 4 },
  [103] = quest { id = 103, name = 'The road on', level = 6, reqLevel = 5 },
}
player.level = 6
planner = loadPlanner(quests, 'a101.1 d101.1 t101.2 a102.4 d102.4 t102.5 a103.6 d103.6 t103.6')
route = planner.GetRoute()
assert(not hasQuest(route, 101),
  'the quests of the levels long past the player must stay off the route')
assert(entryOf(route, 'pickup', 102) and entryOf(route, 'do', 102) and entryOf(route, 'turnin', 102),
  'the quest of the level where the route joined must be on it in full')
assert(entryOf(route, 'pickup', 103),
  'the quests after the join point must be on the route too')
assert(route[1].kind == 'pickup' and route[1].questID == 102,
  'the route must start where the Path meets the level of the player')
print('ok - the route joins the Path at the level of the player')

-- The first filter: a quest the player finished for good leaves the route.
-- QUEST_TURNED_IN is the game's own report of the hand-in.
fire('QUEST_TURNED_IN', 102)
route = planner.GetRoute()
assert(not hasQuest(route, 102),
  'a handed-in quest must leave the route at the finished stage')
assert(entryOf(route, 'pickup', 103),
  'a finished quest must not take the later quests with it')
print('ok - a finished quest leaves the route')

-- The second filter: a quest the player's race or class cannot take
-- leaves the route; a quest open to the player stays.
quests = {
  [111] = quest { id = 111, name = 'Only for humans', level = 6, reqLevel = 5, races = HUMAN },
  [112] = quest { id = 112, name = 'Only for warriors', level = 6, reqLevel = 5, classes = WARRIOR },
  [113] = quest { id = 113, name = 'For the undead', level = 6, reqLevel = 5, races = UNDEAD },
  [114] = quest { id = 114, name = 'For everyone', level = 6, reqLevel = 5 },
}
planner = loadPlanner(quests, 'a111.6 a112.6 a113.6 a114.6')
route = planner.GetRoute()
assert(not hasQuest(route, 111),
  'a quest of another race must leave the route at the race stage')
assert(not hasQuest(route, 112),
  'a quest of another class must leave the route at the class stage')
assert(entryOf(route, 'pickup', 113) and entryOf(route, 'pickup', 114),
  'quests the race and class can take must stay on the route')
print('ok - a quest the race or class cannot take leaves the route')

-- The third filter: a grey quest leaves the route. At level 12 the grey
-- band starts six levels below the player, so a level 6 quest on a level
-- 11 step of the Path is grey and a level 11 quest is not.
quests = {
  [211] = quest { id = 211, name = 'Old errand', level = 6, reqLevel = 5 },
  [212] = quest { id = 212, name = 'Fresh work', level = 11, reqLevel = 10 },
}
player.level = 12
planner = loadPlanner(quests, 'a211.11 d211.11 t211.11 a212.11 d212.12 t212.12')
route = planner.GetRoute()
assert(not hasQuest(route, 211), 'a grey quest must leave the route at the grey stage')
assert(entryOf(route, 'pickup', 212) and entryOf(route, 'turnin', 212),
  'a quest inside the colour band must stay on the route')
print('ok - a grey quest leaves the route')

-- The fourth filter: an abandoned quest leaves the route until the player
-- takes it again. The store holds the record; the wiring test at the end
-- drives it through the reader's own callbacks.
quests = { [301] = quest { id = 301, name = 'Given up', level = 6, reqLevel = 5 } }
player.level = 6
planner = loadPlanner(quests, 'a301.6 d301.6 t301.7')
EfficientQuests.characterStore.recordAbandoned(301)
route = planner.GetRoute()
assert(not hasQuest(route, 301),
  'an abandoned quest must leave the route at the abandoned stage')
EfficientQuests.characterStore.clearAbandoned(301)
route = planner.GetRoute()
assert(entryOf(route, 'pickup', 301),
  'a quest taken again must return to the route')
print('ok - an abandoned quest leaves the route and a retake returns it')

-- The fifth filter: the skip list of the character leaves a quest out, and
-- a restore by hand returns it. No callback reports a skip, so the route
-- must notice the change on its own.
quests = { [401] = quest { id = 401, name = 'Skipped work', level = 6, reqLevel = 5 } }
player.level = 6
planner = loadPlanner(quests, 'a401.6 d401.6 t401.7')
assert(entryOf(planner.GetRoute(), 'pickup', 401), 'the quest starts on the route')
EfficientQuests.characterStore.skip(401)
assert(not hasQuest(planner.GetRoute(), 401),
  'a skipped quest must leave the route at the skip stage')
EfficientQuests.characterStore.restore(401)
assert(entryOf(planner.GetRoute(), 'pickup', 401),
  'a restored quest must return to the route')
print('ok - a skipped quest leaves the route and a restore returns it')

-- Near hand-in first: finished quests in the log whose hand-in point
-- stands within 300 yards of the player come before everything, nearest
-- first, whatever the order of the Path. A hand-in on another continent
-- and one too far away stay where the route would put them.
-- The player stands at world (700, 500) on continent 7; one percent of a
-- synthetic map is ten yards.
quests = {
  [501] = quest { id = 501, name = 'Close work', level = 6, reqLevel = 5,
    finish = { 100, 40, 50 } }, -- 100 yards away
  [502] = quest { id = 502, name = 'Farther work', level = 6, reqLevel = 5,
    finish = { 100, 50, 50 } }, -- 200 yards away
  [503] = quest { id = 503, name = 'Too far', level = 6, reqLevel = 5,
    finish = { 100, 65, 50 } }, -- 350 yards away: not near
  [504] = quest { id = 504, name = 'Other continent', level = 6, reqLevel = 5,
    finish = { 200, 50, 50 } }, -- on continent 8: never near
  [505] = quest { id = 505, name = 'The path goes on', level = 6, reqLevel = 5 },
}
player.level = 6
planner = loadPlanner(quests, 'a505.6 d505.6 t505.6')
takeQuest(501, 'Close work')
takeQuest(502, 'Farther work')
takeQuest(503, 'Too far')
takeQuest(504, 'Other continent')
finishQuest(501)
finishQuest(502)
finishQuest(503)
finishQuest(504)
world = { x = 700, y = 500, instance = 7 }
route = planner.GetRoute()
assert(route[1].kind == 'turnin' and route[1].questID == 501 and route[1].near == true,
  'the finished quest with the nearest hand-in must come first')
assert(route[2].kind == 'turnin' and route[2].questID == 502 and route[2].near == true,
  'the farther near hand-in must come second')
local late = entryOf(route, 'turnin', 503)
assert(late ~= nil and late.near == nil,
  'a hand-in 350 yards away must not come first')
assert(entryOf(route, 'turnin', 504) ~= nil and entryOf(route, 'turnin', 504).near == nil,
  'a hand-in on another continent must not come first')
assert(entryOf(route, 'pickup', 505) ~= nil,
  'the near hand-ins must not take the path quests off the route')
print('ok - finished quests with a near hand-in come first, nearest first')

-- The "Level up to N" step: the next quest of the Path needs level 7 and
-- the player has 5, so the route ends with the marker instead of skipping
-- ahead. A level up replans and takes the quest in.
quests = {
  [601] = quest { id = 601, name = 'Within reach', level = 5, reqLevel = 4 },
  [602] = quest { id = 602, name = 'Too high', level = 8, reqLevel = 7 },
}
player.level = 5
planner = loadPlanner(quests, 'a601.5 d601.5 t601.5 a602.8 d602.8 t602.8')
route = planner.GetRoute()
assert(entryOf(route, 'pickup', 601) ~= nil,
  'the quest of the level of the player must stay on the route')
assert(route[#route].kind == 'levelup' and route[#route].level == 7,
  'a gate above the level of the player must end the route with a level-up marker')
fire('PLAYER_LEVEL_UP', 7)
player.level = 7
route = planner.GetRoute()
assert(entryOf(route, 'pickup', 602) ~= nil,
  'a level up must replan and take the quest that was too high')
assert(entryOf(route, 'levelup', nil) == nil and route[#route].kind ~= 'levelup',
  'the level-up marker must leave the route once the level is reached')

-- The baked-in gate of the Path data: a "g" event says to level up to its
-- level before the Path goes on.
quests = {
  [603] = quest { id = 603, name = 'Before the gate', level = 5, reqLevel = 4 },
  [604] = quest { id = 604, name = 'After the gate', level = 7, reqLevel = 7 },
}
player.level = 5
planner = loadPlanner(quests, 'a603.5 d603.5 t603.5 g7.6 a604.7 d604.7 t604.7')
route = planner.GetRoute()
assert(route[#route].kind == 'levelup' and route[#route].level == 7,
  'a gate baked into the Path must end the route with a level-up marker')
assert(not hasQuest(route, 604),
  'the quests past a gate must wait until the level is reached')
print('ok - a too-high next quest or a baked-in gate ends the route with a level-up marker')

-- Quests in the log that the Path does not do stay on the route until the
-- player hands them in: first their open work, then the hand-in, marked
-- as the own work of the player.
quests = {
  [701] = quest { id = 701, name = 'Own errand', level = 6, reqLevel = 5 },
  [702] = quest { id = 702, name = 'Path work', level = 6, reqLevel = 5 },
}
player.level = 6
planner = loadPlanner(quests, 'a702.6 d702.6 t702.6')
takeQuest(701, 'Own errand')
route = planner.GetRoute()
local ownDo, ownTurnin = entryOf(route, 'do', 701), entryOf(route, 'turnin', 701)
assert(ownDo ~= nil and ownDo.own == true and ownTurnin ~= nil and ownTurnin.own == true,
  'a quest of the log that the Path does not do must stay on the route as own work')
assert(entryOf(route, 'pickup', 702) ~= nil,
  'the own work must not take the path quests off the route')
finishQuest(701)
route = planner.GetRoute()
assert(entryOf(route, 'do', 701) == nil and entryOf(route, 'turnin', 701) ~= nil,
  'a finished own quest must keep only its hand-in on the route')
fire('QUEST_TURNED_IN', 701)
route = planner.GetRoute()
assert(not hasQuest(route, 701),
  'a handed-in own quest must leave the route')
print('ok - a log quest off the Path stays on the route until it is handed in')

-- A log quest the data store knows nothing about stays on the route too
-- (story 20): the player took it, so the route keeps its work and its
-- hand-in until the player hands it in, whatever the store knows.
quests = {
  [711] = quest { id = 711, name = 'Path work', level = 6, reqLevel = 5 },
}
player.level = 6
planner = loadPlanner(quests, 'a711.6 d711.6 t711.6')
takeQuest(712, 'Unknown errand')
route = planner.GetRoute()
local unknownDo = entryOf(route, 'do', 712)
assert(unknownDo ~= nil and unknownDo.own == true,
  'a log quest the store has no data for must stay on the route as own work')
local unknownTurnin = entryOf(route, 'turnin', 712)
assert(unknownTurnin ~= nil and unknownTurnin.own == true,
  'the unknown log quest must keep its hand-in on the route too')
assert(entryOf(route, 'pickup', 711) ~= nil,
  'the unknown own work must not take the path quests off the route')
fire('QUEST_TURNED_IN', 712)
assert(not hasQuest(planner.GetRoute(), 712),
  'a handed-in quest the store never knew must leave the route')
print('ok - a log quest unknown to the store stays on the route until the hand-in')

-- A quest the player just accepted gets no pick-up step: the accept
-- itself replans, and the route carries the work and the hand-in instead.
quests = { [801] = quest { id = 801, name = 'Just taken', level = 6, reqLevel = 5 } }
player.level = 6
planner = loadPlanner(quests, 'a801.6 d801.6 t801.6')
route = planner.GetRoute()
assert(route[1].kind == 'pickup' and route[1].questID == 801,
  'the quest starts as a pick-up step before the player takes it')
takeQuest(801, 'Just taken')
route = planner.GetRoute()
assert(entryOf(route, 'pickup', 801) == nil,
  'a quest just accepted must not get a pick-up step')
assert(entryOf(route, 'do', 801) ~= nil and entryOf(route, 'turnin', 801) ~= nil,
  'a quest just accepted must keep its work and hand-in steps')
print('ok - a quest just accepted gets no pick-up step')

-- The wiring of the abandon detection (ticket #31): the reader reports a
-- quest that left the log without a hand-in after its moment of grace,
-- the character store records the abandon, and the route drops the quest.
-- Taking the quest again clears the record, so the quest returns.
quests = { [901] = quest { id = 901, name = 'Left behind', level = 6, reqLevel = 5 } }
player.level = 6
planner = loadPlanner(quests, 'a901.6 d901.6 t901.7')
takeQuest(901, 'Left behind')
assert(entryOf(planner.GetRoute(), 'do', 901) ~= nil,
  'the taken quest starts on the route')
logEntries = {}
fire('QUEST_REMOVED', 901)
runTimers()
assert(EfficientQuests.characterStore.isAbandoned(901),
  'a quest removed without a hand-in must reach the abandoned store through the reader callback')
assert(EfficientQuestsCharacter.abandoned[901] == true,
  'the wiring must write the abandon into the per-character saved table')
assert(not hasQuest(planner.GetRoute(), 901),
  'the abandoned quest must leave the route after the callback')
takeQuest(901, 'Left behind')
assert(not EfficientQuests.characterStore.isAbandoned(901),
  'taking the quest again must clear the abandoned record through the reader callback')
assert(entryOf(planner.GetRoute(), 'do', 901) ~= nil,
  'the quest taken again must return to the route without a pick-up step')
print('ok - the abandon detection is wired and a retake clears it')

print('all route planner tests passed')
