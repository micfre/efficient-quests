-- The step model: the module that turns a route entry into a step -- a
-- headline, goal lines with ticks and counts, tips, a place text, reward
-- hover data, and the "hunts in one area" block -- and answers the step
-- of one quest id for the Follow mode controller. The suite loads the
-- addon once through the shared seam with the real copied data, then
-- loads the code modules by hand per scenario -- the way the route
-- planner suite does -- into a namespace that holds the scenario's own
-- synthetic quests, Path, and name tables, so every part of the step
-- gets a controlled world.

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
local inInstance = false
IsInInstance = function() return inInstance end

-- QuestieDB must never be called; this sentinel fails the suite the moment
-- anything reaches for it.
LibQuestieDB = {
  Quest = { Get = function() error('the step model must not call QuestieDB') end },
  Npc = { Get = function() error('the step model must not call QuestieDB') end },
}

-- Quest facts in the generated 38-field layout, at the positions the step
-- model reads: 1 name, 8 the start point { map, x%, y% }, 9 the hand-in
-- point, 10 the objective points, 19 the giver name, 20 the ender name,
-- 26 the targets { { name, { npc ids }, { object ids }, count, item id } },
-- 27 the giver npc, 28 the ender npc, 30 the tip at the pick-up, 31 the
-- tip at the hand-in, 33 the reward items, 34 the reward choices, 36 the
-- spell it teaches.
local function quest(t)
  local q = { t.name or ('Quest ' .. t.id), t.level or 1, t.reqLevel or 1, 0, 0, 0, 0 }
  q[8], q[9], q[10] = t.start, t.finish, t.objectives
  q[19], q[20] = t.giver, t.ender
  q[26] = t.targets
  q[27], q[28] = t.giverNpc, t.enderNpc
  q[30], q[31] = t.tipPickup, t.tipHandIn
  q[33], q[34], q[36] = t.rewardItems, t.rewardChoices, t.spell
  return q
end

-- The embedded libraries load once, before every scenario: the game loads
-- them before the addon too, and their LibStub must be a global the hand
-- loads below can call. The real copied data joins them in the last part
-- of this suite.
assert(loadfile('dist/EfficientQuests/Libs/LibStub/LibStub.lua'))()
assert(loadfile('dist/EfficientQuests/Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua'))()
assert(loadfile('dist/EfficientQuests/Libs/HereBeDragons/HereBeDragons-2.0.lua'))()

-- One controlled scenario: the code modules load by hand, in manifest
-- order, into a namespace whose data tables are the scenario's own. The
-- game starts a fresh character and hands the saved tables over on login.
-- The tables part holds the extra name tables (npcNames, npcWhere,
-- npcSpawns, objSpawns, itemNames) the data store lookups and the place
-- text read.
local function loadModel(quests, pathLine, tables)
  EfficientQuestsCharacter = {}
  frames = {}
  logEntries, objectives, completeFlag = {}, {}, {}
  onQuest, flaggedCompleted, completedIDs = {}, {}, {}
  tables = tables or {}
  local namespace = {
    quests = quests,
    pathData = { version = "t", starts = { undead = pathLine } },
    maps = { [100] = 'Northfield', [200] = 'Southmoor' },
    DungeonGuides = { [1] = { stops = {} } },
    npcNames = tables.npcNames or {},
    npcWhere = tables.npcWhere or {},
    npcSpawns = tables.npcSpawns or {},
    objSpawns = tables.objSpawns or {},
    itemNames = tables.itemNames or {},
  }
  local function loadFile(path)
    assert(loadfile('dist/EfficientQuests/' .. path))('EfficientQuests', namespace)
  end
  loadFile('Core.lua')
  loadFile('QuestState.lua')
  loadFile('CharacterStore.lua')
  loadFile('DataStore.lua')
  loadFile('RoutePlanner.lua')
  loadFile('StepModel.lua')
  for _, frame in ipairs(frames) do
    if frame.events['PLAYER_LOGIN'] and frame.scripts.OnEvent then
      frame.scripts.OnEvent(frame, 'PLAYER_LOGIN')
    end
  end
  assert(type(EfficientQuests.stepModel) == 'table',
    'the addon must offer the step model after a login')
  return EfficientQuests.stepModel, EfficientQuests.routePlanner
end

-- Take a quest the way the game does: the log knows it, objectives come
-- with it, and QUEST_ACCEPTED told the reader.
local function takeQuest(id, title, objs)
  table.insert(logEntries, { questID = id, title = title, level = player.level, isHeader = false })
  objectives[id] = objs or { { text = 'Something done', numFulfilled = 0, numRequired = 1, finished = false } }
  fire('QUEST_ACCEPTED', id)
end

-- Fill every objective of a quest in the log: the quest is complete.
local function finishQuest(id, objs)
  objectives[id] = objs or { { text = 'Something done', numFulfilled = 1, numRequired = 1, finished = true } }
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

-- Queries over a route and a step's lines.
local function entryOf(route, kind, questID)
  for _, entry in ipairs(route) do
    if entry.kind == kind and entry.questID == questID then return entry end
  end
  return nil
end
local function lineOf(step, kind, text)
  for _, line in ipairs(step.lines) do
    if line.kind == kind and (text == nil or line.text == text) then return line end
  end
  return nil
end
local function linesOfKind(step, kind)
  local found = {}
  for _, line in ipairs(step.lines) do
    if line.kind == kind then found[#found + 1] = line end
  end
  return found
end

-- The pick-up step: the headline says "Pick up" and names the quest.
local quests = {
  [101] = quest { id = 101, name = 'Wolf pelts', level = 6, reqLevel = 5,
    start = { 100, 72, 30 }, finish = { 100, 30, 70 },
    giver = 'Deathstalker Rane', ender = 'Deathstalker Rane',
    giverNpc = 900, enderNpc = 900,
    objectives = { { 100, 40, 50 } },
    targets = { { 'Winter Wolf', { 910 }, {}, 7 } },
    tipPickup = 'Moves around the open field.' },
}
player.level = 6
local stepModel, planner = loadModel(quests, 'a101.5 d101.5 t101.5')
local route = planner.GetRoute()
assert(route[1].kind == 'pickup' and route[1].questID == 101,
  'the scenario must start with the pick-up of the wolf quest')
local step = stepModel.GetStep(route[1])
assert(step ~= nil and step.kind == 'pickup' and step.questID == 101,
  'the step must carry the kind and the quest id of its route entry')
assert(step.headline == 'Pick up Wolf pelts',
  'the headline of a pick-up step must say Pick up and name the quest, saw ' .. tostring(step.headline))
print('ok - the headline of a pick-up step says Pick up')

-- The headline of every other kind: the work step says Do, the hand-in
-- says Hand in, a work step the data knows no goals for says Go to (go to
-- the place; the work happens there), and the level-up marker says Level
-- up to N. The own and near marks of a route entry pass through.
quests = {
  [111] = quest { id = 111, name = 'Wolf pelts', level = 6, reqLevel = 5,
    start = { 100, 72, 30 }, finish = { 100, 30, 70 },
    giver = 'Deathstalker Rane', ender = 'Deathstalker Rane',
    giverNpc = 900, enderNpc = 900,
    objectives = { { 100, 40, 50 } },
    targets = { { 'Winter Wolf', { 910 }, {}, 7 } } },
  [112] = quest { id = 112, name = 'Carry the ledger', level = 6, reqLevel = 5,
    start = { 100, 30, 70 }, finish = { 100, 72, 30 },
    giver = 'Quartermaster Zigris', ender = 'Innkeeper Renee',
    giverNpc = 901, enderNpc = 902 },
  [113] = quest { id = 113, name = 'After the gate', level = 8, reqLevel = 7,
    start = { 100, 50, 50 }, finish = { 100, 50, 50 } },
}
player.level = 6
stepModel, planner = loadModel(quests,
  'a111.5 d111.5 t111.5 a112.5 d112.5 t112.5 a113.8 d113.8 t113.8')

-- The work step of a quest with goals.
takeQuest(111, 'Wolf pelts', {
  { text = 'Winter Wolf slain: 3/7', numFulfilled = 3, numRequired = 7, finished = false },
})
route = planner.GetRoute()
local work = entryOf(route, 'do', 111)
assert(work ~= nil, 'the taken quest must have a work step')
step = stepModel.GetStep(work)
assert(step.kind == 'do' and step.questID == 111,
  'the work step must carry the kind and the quest id of its route entry')
assert(step.headline == 'Do Wolf pelts',
  'the headline of a work step must say Do and name the quest, saw ' .. tostring(step.headline))

-- The hand-in step of a finished quest.
finishQuest(111)
route = planner.GetRoute()
step = stepModel.GetStep(entryOf(route, 'turnin', 111))
assert(step.kind == 'turnin' and step.questID == 111,
  'the hand-in step must carry the kind and the quest id of its route entry')
assert(step.headline == 'Hand in Wolf pelts',
  'the headline of a hand-in step must say Hand in and name the quest, saw ' .. tostring(step.headline))

-- A work step the data knows no goals for: the game reports no objectives
-- and the quest entry lists no targets, so the step just says where to go.
takeQuest(112, 'Carry the ledger', {})
route = planner.GetRoute()
step = stepModel.GetStep(entryOf(route, 'do', 112))
assert(step.kind == 'do',
  'a goal-less work step keeps the kind of its route entry')
assert(step.headline == 'Go to Carry the ledger',
  'a work step without goals must say Go to, saw ' .. tostring(step.headline))

-- The level-up step.
route = planner.GetRoute()
local marker = route[#route]
assert(marker.kind == 'levelup' and marker.level == 7,
  'the scenario must end with the level-up marker for level 7')
step = stepModel.GetStep(marker)
assert(step.kind == 'levelup' and step.level == 7,
  'the level-up step must carry the kind and the level to reach')
assert(step.headline == 'Level up to 7',
  'the headline of a level-up step must say Level up to and the level, saw ' .. tostring(step.headline))

-- The own and near marks pass through, so the window can tell the player's
-- own work and the near hand-ins apart.
quests = {
  [121] = quest { id = 121, name = 'Own errand', level = 6, reqLevel = 5,
    start = { 100, 50, 50 }, finish = { 100, 50, 50 } },
  [122] = quest { id = 122, name = 'Path work', level = 6, reqLevel = 5,
    start = { 100, 60, 50 }, finish = { 100, 60, 50 } },
}
player.level = 6
stepModel, planner = loadModel(quests, 'a122.6 d122.6 t122.6')
takeQuest(121, 'Own errand')
route = planner.GetRoute()
local ownStep = stepModel.GetStep(entryOf(route, 'do', 121))
assert(ownStep.own == true,
  'the step of an own-work entry must carry the own mark')
assert(stepModel.GetStep(entryOf(route, 'turnin', 121)).own == true,
  'the hand-in step of an own quest must carry the own mark too')
assert(stepModel.GetStep(entryOf(route, 'pickup', 122)).own == nil,
  'a step of the route itself carries no own mark')
quests = {
  [131] = quest { id = 131, name = 'Close work', level = 6, reqLevel = 5,
    finish = { 100, 45, 50 } },
  [132] = quest { id = 132, name = 'The path goes on', level = 6, reqLevel = 5 },
}
player.level = 6
stepModel, planner = loadModel(quests, 'a132.6 d132.6 t132.6')
takeQuest(131, 'Close work')
finishQuest(131)
world = { x = 500, y = 500, instance = 7 }
route = planner.GetRoute()
assert(route[1].kind == 'turnin' and route[1].questID == 131 and route[1].near == true,
  'the scenario must put the near hand-in first')
step = stepModel.GetStep(route[1])
assert(step.near == true,
  'the step of a near-first hand-in must carry the near mark')
print('ok - the headlines of every kind and the own and near marks')

-- The goal lines: the words of every line, the ticks from the quest state,
-- the counts such as "3 of 7", and the tips under the Talk to lines.
quests = {
  [141] = quest { id = 141, name = 'Cull the pack', level = 6, reqLevel = 5,
    start = { 100, 72, 30 }, finish = { 100, 72, 30 },
    giver = 'Deathstalker Rane', ender = 'Deathstalker Rane',
    giverNpc = 900, enderNpc = 900,
    targets = { { 'Winter Wolf', { 910 }, {}, 7 }, { 'Wolf collar', { 910 }, {}, 3, 555 } },
    tipPickup = 'Moves around the open field.',
    tipHandIn = 'Moves around the open field.' },
  [142] = quest { id = 142, name = 'The bounty board', level = 6, reqLevel = 5,
    start = { 100, 50, 50 }, finish = { 100, 60, 60 },
    giver = 'the bounty board', ender = 'Deathstalker Rane', enderNpc = 900 } }
player.level = 6
stepModel, planner = loadModel(quests, 'a141.5 d141.5 t141.5 a142.5 d142.5 t142.5',
  { npcNames = { [910] = 'Winter Wolf' },
    npcWhere = { [900] = 'By the tower north of the mill.' } })

-- A quest the route plans but the player has not taken yet: its work step
-- lists the goals from the data, with counts and no ticks.
step = stepModel.GetStep(entryOf(planner.GetRoute(), 'do', 141))
local questLines = linesOfKind(step, 'quest')
assert(#questLines == 1 and questLines[1].text == 'Cull the pack' and not questLines[1].done,
  'the work step must open with the name of its quest')
local goals = linesOfKind(step, 'objective')
assert(#goals == 2, 'the work step must list one line per data target')
assert(goals[1].text == 'Winter Wolf' and goals[1].count == '0 of 7'
    and goals[1].have == 0 and goals[1].need == 7 and not goals[1].done
    and goals[1].npc == 910,
  'a goal the player has not started must say its count from the data')
assert(goals[2].text == 'Wolf collar' and goals[2].count == '0 of 3'
    and goals[2].item == 555,
  'a collect goal must carry its item for the hover')

-- The pick-up step: the Talk to line for the giver, the tip that says the
-- giver moves around, the place note under it, and the Accept line. A
-- giver with no npc of its own -- an object -- gets a Click line.
step = stepModel.GetStep(entryOf(planner.GetRoute(), 'pickup', 141))
local talk = lineOf(step, 'talk')
assert(talk ~= nil and talk.text == 'Talk to Deathstalker Rane' and talk.npc == 900,
  'the pick-up step must say who to talk to and carry the giver npc')
local notes = linesOfKind(step, 'note')
assert(#notes == 2, 'the pick-up step must show the tip and the place note')
assert(notes[1].text == 'By the tower north of the mill.',
  'the place note of the giver comes from the data store')
assert(notes[2].text == 'Moves around the open field.',
  'the tip at the pick-up comes from the data store')
assert(lineOf(step, 'accept', 'Accept Cull the pack') ~= nil,
  'the pick-up step must say to accept the quest')
step = stepModel.GetStep(entryOf(planner.GetRoute(), 'pickup', 142))
talk = lineOf(step, 'talk')
assert(talk ~= nil and talk.text == 'Click the bounty board' and talk.npc == nil,
  'a quest that starts from an object must say Click, not Talk to')
assert(#linesOfKind(step, 'note') == 0,
  'a giver that does not move needs no note lines')
print('ok - talk lines carry their tips and place notes')

-- Once taken, the goals come from the live log: the counts move with it
-- and the ticks follow the finished objectives. A text the game wrote
-- without a name takes the name from the data; a count baked into the
-- text moves into the count column.
takeQuest(141, 'Cull the pack', {
  { text = 'Winter Wolf slain: 3/7', numFulfilled = 3, numRequired = 7, finished = false },
  { text = '1/1', numFulfilled = 1, numRequired = 1, finished = true },
})
step = stepModel.GetStep(entryOf(planner.GetRoute(), 'do', 141))
goals = linesOfKind(step, 'objective')
assert(goals[1].text == 'Winter Wolf slain' and goals[1].count == '3 of 7'
    and goals[1].have == 3 and goals[1].need == 7 and not goals[1].done,
  'a live goal must show its count and its tick from the quest state')
assert(goals[1].npc == 910,
  'a live goal line must carry its target npc from the data')
assert(goals[2].text == 'Wolf collar' and goals[2].count == nil and goals[2].done,
  'a finished goal must tick, and a game text without a name takes the data name')
print('ok - goal lines list their counts and tick with the quest state')

-- The hand-in step: the Talk to line for the ender with its tip and place
-- note, and the Turn in line, which ticks once the quest is complete.
finishQuest(141)
step = stepModel.GetStep(entryOf(planner.GetRoute(), 'turnin', 141))
talk = lineOf(step, 'talk')
assert(talk ~= nil and talk.text == 'Talk to Deathstalker Rane' and talk.npc == 900,
  'the hand-in step must say who to talk to and carry the ender npc')
notes = linesOfKind(step, 'note')
assert(#notes == 2 and notes[1].text == 'By the tower north of the mill.'
    and notes[2].text == 'Moves around the open field.',
  'the hand-in step must show the place note and the tip at the hand-in')
local turnin = lineOf(step, 'turnin')
assert(turnin ~= nil and turnin.text == 'Turn in Cull the pack' and turnin.done,
  'the turn-in line must tick once every goal of the quest is done')

-- A quest still open keeps its turn-in line unticked.
stepModel, planner = loadModel(quests, 'a141.5 d141.5 t141.5 a142.5 d142.5 t142.5',
  { npcNames = { [910] = 'Winter Wolf' } })
takeQuest(141, 'Cull the pack', {
  { text = 'Winter Wolf slain: 3/7', numFulfilled = 3, numRequired = 7, finished = false },
})
step = stepModel.GetStep(entryOf(planner.GetRoute(), 'turnin', 141))
assert(step ~= nil and not lineOf(step, 'turnin').done,
  'the turn-in line of a quest with open goals must stay unticked')
print('ok - the hand-in line ticks with the quest state')

-- The place text: the zone and the direction of the point, in plain words,
-- with no map layer. The step also names its point and every candidate
-- place it knows, for the waypoint bridge. A zone the data does not name
-- gets no place text.
quests = {
  [151] = quest { id = 151, name = 'Boar country', level = 6, reqLevel = 5,
    start = { 100, 72, 30 }, finish = { 200, 20, 80 },
    giver = 'Hunter Grok', giverNpc = 950, ender = 'Innkeeper Ras', enderNpc = 951,
    targets = { { 'Boar tusk', { 920 }, {}, 5 }, { 'Raven feather', {}, { 930 }, 2 } },
    rewardItems = { 60, 61 }, rewardChoices = { 62 }, spell = 71 },
  [152] = quest { id = 152, name = 'Nowhere known', level = 6, reqLevel = 5,
    start = { 300, 50, 50 }, finish = { 300, 50, 50 } },
  [153] = quest { id = 153, name = 'Plain work', level = 6, reqLevel = 5,
    start = { 100, 50, 50 }, finish = { 100, 50, 50 },
    objectives = { { 100, 80, 80 } } },
}
player.level = 6
stepModel, planner = loadModel(quests, 'a151.5 d151.5 t151.5 a152.5 d152.5 t152.5 a153.5 d153.5 t153.5',
  { npcSpawns = { [920] = { 100, 45, 10 } },
    objSpawns = { [930] = { 100, 60, 50 } },
    itemNames = { [60] = 'Layered Tunic', [61] = 'Dwarven Leather Pants' } })

step = stepModel.GetStep(entryOf(planner.GetRoute(), 'pickup', 151))
assert(step.place == 'Northfield, north-east',
  'the place of a pick-up step must name the zone and the direction, saw '
    .. tostring(step.place))
assert(step.point[1] == 100 and step.point[2] == 72 and step.point[3] == 30,
  'the point of a pick-up step is the start point of the quest')
assert(#step.points == 1, 'a pick-up step knows one place')

step = stepModel.GetStep(entryOf(planner.GetRoute(), 'do', 151))
assert(step.place == 'Northfield, north',
  'the place of a work step comes from the first known spawn of its targets')
assert(#step.points == 2 and step.points[1][2] == 45 and step.points[2][2] == 60,
  'a work step lists one place per target: the npc spawn of the first, the object spawn of the second')

step = stepModel.GetStep(entryOf(planner.GetRoute(), 'do', 153))
assert(step.place == 'Northfield, south-east',
  'a quest with its own objective points places the step by them')
assert(#step.points == 1 and step.points[1][2] == 80,
  'a quest with objective points needs no spawn lookup')

finishQuest(151)
step = stepModel.GetStep(entryOf(planner.GetRoute(), 'turnin', 151))
assert(step.place == 'Southmoor, south-west',
  'the place of a hand-in step is the hand-in point of the quest')

step = stepModel.GetStep(entryOf(planner.GetRoute(), 'pickup', 152))
assert(step.place == nil,
  'a point on a zone the data does not name gets no place text')
assert(step.point ~= nil and step.point[1] == 300,
  'the point itself is still there for the waypoint bridge')
print('ok - the place text names the zone and the direction')

-- The reward hover data: the window hovers the items and the spell by id;
-- the names come along for the window's own text. A quest that pays
-- nothing the data knows carries no rewards table.
step = stepModel.GetStep(entryOf(planner.GetRoute(), 'pickup', 151))
assert(step.rewards ~= nil and #step.rewards.items == 2
    and step.rewards.items[1].id == 60 and step.rewards.items[1].name == 'Layered Tunic'
    and step.rewards.items[2].name == 'Dwarven Leather Pants',
  'the fixed reward items come with their names from the data')
assert(#step.rewards.choices == 1 and step.rewards.choices[1].id == 62
    and step.rewards.choices[1].name == nil,
  'a reward choice the data knows by id only keeps a nil name')
assert(step.rewards.spell == 71,
  'the spell a quest teaches is part of the hover data')
assert(stepModel.GetStep(entryOf(planner.GetRoute(), 'pickup', 153)).rewards == nil,
  'a quest without known rewards carries no rewards table')
print('ok - the reward hover data lists items, choices, and the spell')

-- The "hunts in one area" block: the other kill goals of the route whose
-- work stands within 700 yards of the player, each with its own goals and
-- counts, at most three of them. The player stands at world (150, 150) on
-- continent 7; the fake maps are 1000 by 1000 yards with both axes
-- mirrored: a point at x and y percent sits at (100 - x) and (100 - y)
-- times ten yards.
quests = {
  [161] = quest { id = 161, name = 'First hunts', level = 6, reqLevel = 5,
    targets = { { 'Red boar', { 921 }, {}, 4 } } },
  [162] = quest { id = 162, name = 'Nearby hunts', level = 6, reqLevel = 5,
    objectives = { { 100, 80, 20 } }, -- about 650 yards away
    targets = { { 'Plainstrider', { 922 }, {}, 6 } } },
  [163] = quest { id = 163, name = 'Also nearby', level = 6, reqLevel = 5,
    objectives = { { 100, 60, 40 } }, -- about 515 yards away
    targets = { { 'Makrura', { 923 }, {}, 2 } } },
  [164] = quest { id = 164, name = 'Too far', level = 6, reqLevel = 5,
    objectives = { { 100, 10, 90 } }, -- about 750 yards away
    targets = { { 'Fairy dragon', { 924 }, {}, 3 } } },
  [165] = quest { id = 165, name = 'Other continent', level = 6, reqLevel = 5,
    objectives = { { 200, 80, 20 } }, -- the same spot on continent 8
    targets = { { 'Nightmare', { 925 }, {}, 3 } } },
  [166] = quest { id = 166, name = 'Crowd one', level = 6, reqLevel = 5,
    objectives = { { 100, 86, 16 } }, -- about 690 yards away
    targets = { { 'Stonetusk boar', { 926 }, {}, 3 } } },
  [167] = quest { id = 167, name = 'Crowd two', level = 6, reqLevel = 5,
    objectives = { { 100, 84, 16 } },
    targets = { { 'Mottled boar', { 927 }, {}, 3 } } },
  [168] = quest { id = 168, name = 'Crowd three', level = 6, reqLevel = 5,
    objectives = { { 100, 83, 17 } },
    targets = { { 'Elder mottled boar', { 928 }, {}, 3 } } },
}
player.level = 6
stepModel, planner = loadModel(quests,
  'a161.5 d161.5 t161.5 a162.5 d162.5 t162.5 a163.5 d163.5 t163.5'
    .. ' a164.5 d164.5 t164.5 a165.5 d165.5 t165.5'
    .. ' a166.5 d166.5 t166.5 a167.5 d167.5 t167.5 a168.5 d168.5 t168.5')
takeQuest(161, 'First hunts', {
  { text = 'Red boar slain: 1/4', numFulfilled = 1, numRequired = 4, finished = false },
})
world = { x = 150, y = 150, instance = 7 }
step = stepModel.GetStep(entryOf(planner.GetRoute(), 'do', 161))
assert(step.hunts ~= nil and #step.hunts == 3,
  'the block must hold the three nearest other kill goals, not more')
assert(step.hunts[1].questID == 162 and step.hunts[2].questID == 163
    and step.hunts[3].questID == 166,
  'the block must follow the route order and stop at three members')
assert(step.hunts[1].name == 'Nearby hunts' and step.hunts[1].yards == 652,
  'a member must carry the quest name and the true yards from the player')
local memberGoals = linesOfKind(step.hunts[1], 'objective')
assert(#memberGoals == 1 and memberGoals[1].text == 'Plainstrider'
    and memberGoals[1].count == '0 of 6' and not memberGoals[1].done,
  'a member must list its own goals with their counts')
assert(step.hunts[2].yards == 515,
  'the second member stands about 515 yards from the player')
assert(step.hunts[3].yards == 690,
  'a hunt close to the 700-yard limit still joins the block')
assert(step.hunts[1].place ~= nil,
  'a member must carry its place text')
-- The 700-yard limit keeps the far hunt and the other continent out; the
-- cap keeps the fourth nearby hunt out.
for _, hunt in ipairs(step.hunts) do
  assert(hunt.questID ~= 164 and hunt.questID ~= 165 and hunt.questID ~= 167
      and hunt.questID ~= 168,
    'a hunt beyond 700 yards or past the cap must stay out of the block')
end
-- Only work steps carry the block.
assert(stepModel.GetStep(entryOf(planner.GetRoute(), 'turnin', 161)).hunts == nil,
  'a hand-in step carries no hunts block')
-- Inside an instance the reader knows no player position, so no block.
inInstance = true
assert(stepModel.GetStep(entryOf(planner.GetRoute(), 'do', 161)).hunts == nil,
  'inside an instance the hunts block must stay away')
inInstance = false
-- No other kill goal nearby: no block at all.
world = { x = 950, y = 900, instance = 8 }
assert(stepModel.GetStep(entryOf(planner.GetRoute(), 'do', 161)).hunts == nil,
  'with no other kill goal near the player the block stays away')
world = nil
print('ok - the hunts block holds the nearby kill goals within 700 yards')

-- The step of one quest, for the Follow mode controller (#34): the quest
-- the player picks in the log. A quest in the log never gets a pick-up
-- step -- so a quest just accepted counts as work, not as a pick-up -- a
-- finished quest in the log gets its hand-in step, a quest the player does
-- not have gets its pick-up step, and a quest handed in or missing from
-- the data answers nil.
quests = {
  [171] = quest { id = 171, name = 'The picked quest', level = 6, reqLevel = 5,
    start = { 100, 40, 40 }, finish = { 100, 40, 40 },
    giver = 'Deathstalker Rane', giverNpc = 900, ender = 'Deathstalker Rane', enderNpc = 900,
    targets = { { 'Winter Wolf', { 910 }, {}, 7 } } },
  [172] = quest { id = 172, name = 'Off the path', level = 6, reqLevel = 5,
    start = { 100, 60, 60 }, finish = { 100, 60, 60 },
    giver = 'Quartermaster Zigris', giverNpc = 901, ender = 'Quartermaster Zigris', enderNpc = 901 },
}
player.level = 6
stepModel, planner = loadModel(quests, '')

-- A quest not on the route and not in the log: its pick-up step, built
-- from the data alone.
step = stepModel.GetStepForQuest(171)
assert(step ~= nil and step.kind == 'pickup' and step.questID == 171
    and step.headline == 'Pick up The picked quest',
  'the step of a quest the player does not have must be its pick-up step')
assert(step.place ~= nil and #step.lines > 0,
  'the single-quest step carries the lines and the place like a route step')

-- Just accepted: in the log with open goals -- work, never a pick-up.
takeQuest(171, 'The picked quest', {
  { text = 'Winter Wolf slain: 3/7', numFulfilled = 3, numRequired = 7, finished = false },
})
step = stepModel.GetStepForQuest(171)
assert(step.kind == 'do' and step.headline == 'Do The picked quest',
  'a quest just accepted must get its work step, not a pick-up step')
assert(step.own == nil and step.near == nil,
  'the single-quest step is neither own work nor a near hand-in')
assert(lineOf(step, 'objective').count == '3 of 7',
  'the single-quest work step lists the live counts of the quest')

-- Every goal done: the hand-in step.
finishQuest(171)
step = stepModel.GetStepForQuest(171)
assert(step.kind == 'turnin' and step.headline == 'Hand in The picked quest'
    and lineOf(step, 'turnin').done,
  'a finished quest in the log must get its hand-in step, ticked')

-- Handed in: nothing to show.
fire('QUEST_TURNED_IN', 171)
assert(stepModel.GetStepForQuest(171) == nil,
  'a quest handed in must answer nil')

-- A goal-less quest in the log: the Go to shape.
takeQuest(172, 'Off the path', {})
step = stepModel.GetStepForQuest(172)
assert(step.kind == 'do' and step.headline == 'Go to Off the path',
  'a goal-less quest in the log must get a Go to step, never a pick-up')

-- A quest the data does not know: nil.
assert(stepModel.GetStepForQuest(999) == nil,
  'a quest missing from the data must answer nil')
print('ok - the single-quest step follows the log, never a pick-up for a taken quest')

-- The real copied data through the shared seam: the whole addon loads the
-- way the game loads it, and every entry of a planned route must become a
-- well-shaped step. The values asserted below are the ones the copied
-- tables hold for these quest ids.
dofile('tests/addon.lua')()
stepModel = EfficientQuests.stepModel
planner = EfficientQuests.routePlanner
assert(type(stepModel) == 'table' and type(stepModel.GetStep) == 'function'
    and type(stepModel.GetStepForQuest) == 'function',
  'the addon must offer the step model with its queries after load')
fire('PLAYER_LOGIN')
player.level = 7
route = planner.GetRoute()
assert(#route > 0, 'the real data must plan a route for a level 7 undead')
for index, entry in ipairs(route) do
  step = stepModel.GetStep(entry)
  assert(step ~= nil, 'every route entry must become a step, entry ' .. index)
  assert(step.kind == entry.kind,
    'the step must carry the kind of its route entry, entry ' .. index)
  assert(type(step.headline) == 'string' and #step.headline > 0,
    'every step must carry a headline, entry ' .. index)
  assert(type(step.lines) == 'table' and #step.lines > 0,
    'every step must carry its lines, entry ' .. index)
  if entry.kind == 'levelup' then
    assert(step.level == entry.level and step.questID == nil,
      'the level-up step must name the level and no quest')
  else
    assert(step.questID == entry.questID,
      'the step must carry the quest id of its route entry, entry ' .. index)
  end
  for _, line in ipairs(step.lines) do
    assert(line.kind ~= nil and line.done ~= nil and type(line.text) == 'string',
      'every line must carry a kind, a tick, and words')
  end
end
local levelupSteps = 0
for _, entry in ipairs(route) do
  if entry.kind == 'levelup' then levelupSteps = levelupSteps + 1 end
end
assert(levelupSteps <= 1, 'the level-up step comes at most once, at the end')

-- The copied quest facts flow into the step: the giver of the bounty on
-- Garrick Padfoot, the place of its pick-up, and the mover tip of Jitters,
-- who walks around his area.
step = stepModel.GetStepForQuest(6)
assert(step.kind == 'pickup' and step.headline == 'Pick up Bounty on Garrick Padfoot',
  'the copied quest table must name the quest of a single-quest step')
assert(lineOf(step, 'talk', 'Talk to Deputy Willem') ~= nil,
  'the giver name must come from the copied quest facts')
assert(step.place == 'the middle of Elwynn Forest',
  'the place text must come from the copied map table, saw ' .. tostring(step.place))
assert(#step.points == 1 and step.point[1] == 1429,
  'the start point of the copied quest must become the step point')
step = stepModel.GetStepForQuest(5)
assert(step.kind == 'pickup' and step.headline == 'Pick up Jitters\' Growling Gut',
  'the step of Jitters\' quest must be its pick-up')
assert(lineOf(step, 'talk', 'Talk to Jitters') ~= nil,
  'the giver of a quest that starts from an npc gets a talk line')
assert(lineOf(step, 'note', 'Moves around this area.') ~= nil,
  'the copied tip for an NPC that moves around must show under the talk line')
print('ok - the real data builds well-shaped steps for a whole route')

print('all step model tests passed')
