-- The Follow mode controller: the module that listens for the quest the
-- player picks in the quest log -- through the client's super tracking
-- when it is there, through its manual pick hook otherwise -- and serves
-- the step of that quest through the step model. The suite loads the code
-- modules by hand per scenario, the way the step model suite does, into a
-- namespace that holds the scenario's own synthetic quests and Path, so
-- every part of the follow state gets a controlled world. The shared-seam
-- part at the end loads the whole addon through the copied data.

-- The game services, in the shape the addon uses them: frames, the quest
-- log, the character sheet, and the super tracking service whose event
-- says the player picked another quest in the log.
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
C_Map = {
  GetMapInfo = function(id)
    if not MAPS[id] then return nil end
    return { name = 'Testland ' .. id, mapType = 3, parentMapID = 0 }
  end,
  GetMapChildrenInfo = function() return nil end,
  GetWorldPosFromMapPos = function(id, point) return MAPS[id] and MAPS[id].instance, point end,
  GetMapWorldSize = function() return 1000, 1000 end,
  GetBestMapForUnit = function() return 100 end,
}

-- The character sheet: an undead mage of the Horde, at a level each
-- scenario picks.
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

-- The super tracking service: the quest the player picked in the log is
-- the tracked one, and SUPER_TRACKING_CHANGED says the pick moved. A
-- scenario picks a quest by setting the tracked id and firing the event,
-- the way the client does. Setting the service itself to nil answers the
-- clients that have no super tracking at all.
local superTracked = nil
C_SuperTrack = { GetSuperTrackedQuestID = function() return superTracked end }
local function pickInLog(questID)
  superTracked = questID
  fire('SUPER_TRACKING_CHANGED')
end

-- QuestieDB must never be called; this sentinel fails the suite the moment
-- anything reaches for it.
LibQuestieDB = {
  Quest = { Get = function() error('the follow mode controller must not call QuestieDB') end },
  Npc = { Get = function() error('the follow mode controller must not call QuestieDB') end },
}

-- Quest facts in the generated 38-field layout, at the positions the step
-- model reads (see the step model suite's builder for the full list).
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

-- The embedded libraries load once, before every scenario, the way the
-- game loads them before the addon.
assert(loadfile('dist/EfficientQuests/Libs/LibStub/LibStub.lua'))()
assert(loadfile('dist/EfficientQuests/Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua'))()
assert(loadfile('dist/EfficientQuests/Libs/HereBeDragons/HereBeDragons-2.0.lua'))()

-- One controlled scenario: the code modules load by hand, in manifest
-- order, into a namespace whose data tables are the scenario's own. The
-- saved table is the one the previous login of the same character left --
-- a fresh character hands an empty table -- so the per-character state
-- survives a reload the way it survives a relog.
local function loadFollow(quests, pathLine, saved)
  EfficientQuestsCharacter = saved or {}
  frames = {}
  logEntries, objectives, completeFlag = {}, {}, {}
  onQuest, flaggedCompleted, completedIDs = {}, {}, {}
  local namespace = {
    quests = quests,
    pathData = { version = 't', starts = { undead = pathLine } },
    maps = { [100] = 'Northfield', [200] = 'Southmoor' },
    DungeonGuides = { [1] = { stops = {} } },
    npcNames = {}, npcWhere = {}, npcSpawns = {}, objSpawns = {}, itemNames = {},
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
  loadFile('FollowMode.lua')
  for _, frame in ipairs(frames) do
    if frame.events['PLAYER_LOGIN'] and frame.scripts.OnEvent then
      frame.scripts.OnEvent(frame, 'PLAYER_LOGIN')
    end
  end
  assert(type(EfficientQuests.followMode) == 'table',
    'the addon must offer the follow mode controller after a login')
  return EfficientQuests.followMode
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

-- The recorder for the FollowChanged callback: one entry per
-- notification, in order.
local heard = {}
local function listenFollow(follow)
  heard = {}
  follow.RegisterCallback({}, 'FollowChanged', function(name, payload)
    assert(name == 'FollowChanged',
      'a subscriber must hear the callback name first, then the payload')
    table.insert(heard, payload)
  end)
end

local function lineOf(step, kind)
  for _, line in ipairs(step.lines) do
    if line.kind == kind then return line end
  end
  return nil
end

-- One world for the whole suite: two quests of the Path -- Skinning
-- knives at 181 and Bone chips at 182 -- and one quest the Path never
-- does, Off the path at 191.
local quests = {
  [181] = quest { id = 181, name = 'Skinning knives', level = 6, reqLevel = 5,
    start = { 100, 40, 40 }, finish = { 100, 40, 40 },
    giver = 'Deathstalker Rane', giverNpc = 900, ender = 'Deathstalker Rane', enderNpc = 900,
    targets = { { 'Winter Wolf', { 910 }, {}, 7 } } },
  [182] = quest { id = 182, name = 'Bone chips', level = 6, reqLevel = 5,
    start = { 100, 60, 60 }, finish = { 100, 60, 60 },
    giver = 'Quartermaster Zigris', giverNpc = 901, ender = 'Quartermaster Zigris', enderNpc = 901 },
  [191] = quest { id = 191, name = 'Off the path', level = 6, reqLevel = 5,
    start = { 100, 70, 30 }, finish = { 100, 70, 30 },
    giver = 'Innkeeper Renee', giverNpc = 902, ender = 'Innkeeper Renee', enderNpc = 902,
    targets = { { 'Raven', { 911 }, {}, 3 } } },
}
player.level = 6

-- Follow mode is off for a fresh character: nothing is followed and
-- nothing is served, even with a quest tracked in the log.
local follow = loadFollow(quests, 'a181.5 d181.5 t181.5 a182.5 d182.5 t182.5')
listenFollow(follow)
takeQuest(181, 'Skinning knives', {
  { text = 'Winter Wolf slain: 3/7', numFulfilled = 3, numRequired = 7, finished = false },
})
superTracked = 181
local state = follow.GetFollowState()
assert(state.active == false and state.questID == nil and state.step == nil,
  'a fresh character does not follow: the state must be all empty, saw '
    .. tostring(state.active) .. '/' .. tostring(state.questID) .. '/' .. tostring(state.step))
assert(EfficientQuests.characterStore.isFollowMode() == false,
  'the follow mode switch of the character store must be off for a fresh character')
assert(#heard == 0, 'a quiet world must not notify anybody')
print('ok - follow mode is off for a fresh character and serves nothing')

-- Turning Follow mode on and off: the switch sits in the per-character
-- saved table, so it survives the same character's next login -- a reload
-- of the world with the same saved table -- while another character, with
-- its own table, starts without it. The pick itself is session state: a
-- reload starts without one, and each change notifies the listener.
superTracked = nil
local saved = {}
follow = loadFollow(quests, 'a181.5 d181.5 t181.5 a182.5 d182.5 t182.5', saved)
listenFollow(follow)
follow.SetFollowMode(true)
state = follow.GetFollowState()
assert(state.active == true and state.questID == nil and state.step == nil,
  'follow mode on without a pick must serve nothing yet')
assert(saved.followMode == true,
  'the switch must sit in the per-character saved table')
assert(#heard == 1 and heard[1].active == true and heard[1].questID == nil,
  'turning follow mode on must notify once, with the fresh state')
follow.SetFollowMode(false)
assert(follow.GetFollowState().active == false and saved.followMode == false,
  'turning follow mode off must reach the store as well')
assert(#heard == 2 and heard[2].active == false,
  'turning follow mode off must notify too')

follow.SetFollowMode(true)
follow = loadFollow(quests, 'a181.5 d181.5 t181.5 a182.5 d182.5 t182.5', saved)
state = follow.GetFollowState()
assert(state.active == true and state.questID == nil and state.step == nil,
  'the switch must survive the next login of the same character, without a pick')
follow = loadFollow(quests, 'a181.5 d181.5 t181.5 a182.5 d182.5 t182.5')
assert(follow.GetFollowState().active == false,
  'another character, with its own saved table, starts without follow mode')
print('ok - the follow mode switch persists per character')

-- A pick in the quest log: the player ticks a quest, the client marks it
-- super-tracked, SUPER_TRACKING_CHANGED tells the world, and Follow mode
-- serves the step of that quest through the step model. Turning the mode
-- on adopts the quest tracked at that moment. The served step follows
-- the quest log live, and unticking the quest clears the pick while the
-- mode stays on.
follow = loadFollow(quests, 'a181.5 d181.5 t181.5 a182.5 d182.5 t182.5')
listenFollow(follow)
takeQuest(181, 'Skinning knives', {
  { text = 'Winter Wolf slain: 3/7', numFulfilled = 3, numRequired = 7, finished = false },
})
superTracked = 181
follow.SetFollowMode(true)
state = follow.GetFollowState()
assert(state.active == true and state.questID == 181 and state.step ~= nil
    and state.step.kind == 'do' and state.step.headline == 'Do Skinning knives',
  'turning follow mode on must adopt the quest the client tracks right now')
assert(lineOf(state.step, 'objective').count == '3 of 7',
  'the served step must carry the live counts of the picked quest')
assert(#heard == 1 and heard[1].questID == 181 and heard[1].step ~= nil,
  'the adoption must notify once, with the served state')

-- The player picks another quest in the log, one not taken yet.
pickInLog(182)
state = follow.GetFollowState()
assert(state.questID == 182 and state.step.kind == 'pickup'
    and state.step.headline == 'Pick up Bone chips',
  'a pick in the log must serve the step of the picked quest')
assert(#heard == 2 and heard[2].questID == 182,
  'a pick must notify')

-- Back to the first quest: every goal done turns the served step into
-- the hand-in, because the state is computed fresh on every call.
pickInLog(181)
finishQuest(181)
state = follow.GetFollowState()
assert(state.step.kind == 'turnin' and state.step.headline == 'Hand in Skinning knives'
    and lineOf(state.step, 'turnin').done,
  'the served step must follow the quest log live: complete means hand in')

-- Unticking the quest in the log clears the pick; the mode stays on.
-- The quest state changes above notified as well, so the count of the
-- entries has grown past the picks; the last entry is the cleared pick.
pickInLog(nil)
state = follow.GetFollowState()
assert(state.active == true and state.questID == nil and state.step == nil,
  'unticking the quest must clear the pick while follow mode stays on')
assert(heard[#heard].questID == nil and heard[#heard].step == nil,
  'the cleared pick must notify')
print('ok - a pick in the quest log serves that quest and its step')

-- A quest that is not on the route: the player picks their own errand,
-- one the Path never does, and Follow mode serves a step of its own for
-- it, built from the quest log and the data alone. The route planner
-- lists such a quest as the player's own work; the follow step needs no
-- route and carries neither the own nor the near mark, and the quest
-- keeps its step until the player hands it in.
follow = loadFollow(quests, 'a181.5 d181.5 t181.5 a182.5 d182.5 t182.5')
listenFollow(follow)
takeQuest(191, 'Off the path', {
  { text = 'Raven slain: 1/3', numFulfilled = 1, numRequired = 3, finished = false },
})
follow.SetFollowMode(true)
pickInLog(191)
state = follow.GetFollowState()
assert(state.questID == 191 and state.step ~= nil and state.step.kind == 'do'
    and state.step.headline == 'Do Off the path',
  'a quest that is not on the route must get a step of its own')
assert(state.step.own ~= true and state.step.near ~= true,
  'the follow step of an off-route quest is neither own route work nor a near hand-in')
assert(lineOf(state.step, 'objective').count == '1 of 3',
  'the off-route step lists the live counts of the quest')
finishQuest(191)
state = follow.GetFollowState()
assert(state.step.kind == 'turnin' and state.step.headline == 'Hand in Off the path',
  'the off-route quest keeps its own step until the player hands it in')
print('ok - an off-route quest gets a step of its own until the hand-in')

-- The just-accepted rule: a quest the player just accepted never counts
-- as a pick-up step (user story 31). The player picks a quest they do
-- not have yet -- its pick-up step -- then takes the quest, and the
-- served step becomes the work step. The step model guarantees this for
-- every quest in the log; the controller relies on that promise, and
-- this asserts it through the follow state.
follow = loadFollow(quests, 'a181.5 d181.5 t181.5 a182.5 d182.5 t182.5')
listenFollow(follow)
superTracked = nil
follow.SetFollowMode(true)
pickInLog(182)
state = follow.GetFollowState()
assert(state.step.kind == 'pickup' and state.step.headline == 'Pick up Bone chips',
  'a quest the player does not have must serve its pick-up step first')
takeQuest(182, 'Bone chips')
state = follow.GetFollowState()
assert(state.step.kind == 'do' and state.step.headline == 'Do Bone chips',
  'a quest just accepted must serve its work step, never a pick-up step')
assert(lineOf(state.step, 'objective') ~= nil,
  'the work step of the just-accepted quest lists its goals')
print('ok - a quest just accepted never counts as a pick-up step')

-- The hand-in ends the follow step. While a quest is picked, every quest
-- state change of the world re-serves and notifies, so the window never
-- shows an old step; the hand-in of the picked quest clears the pick.
-- Follow mode itself stays on, and the notification answers no quest and
-- no step, which means "the window returns to the route" for the tickets
-- that observe it.
follow = loadFollow(quests, 'a181.5 d181.5 t181.5 a182.5 d182.5 t182.5')
listenFollow(follow)
takeQuest(181, 'Skinning knives', {
  { text = 'Winter Wolf slain: 3/7', numFulfilled = 3, numRequired = 7, finished = false },
})
superTracked = nil
follow.SetFollowMode(true)
pickInLog(181)
heard = {} -- the mode change and the pick notified already

-- A progress of the picked quest notifies with the fresh counts.
objectives[181] = {
  { text = 'Winter Wolf slain: 4/7', numFulfilled = 4, numRequired = 7, finished = false },
}
fire('QUEST_LOG_UPDATE')
assert(#heard == 1 and heard[1].questID == 181 and heard[1].step ~= nil
    and lineOf(heard[1].step, 'objective').count == '4 of 7',
  'a progress of the picked quest must notify with the fresh state')

-- The completion of the picked quest notifies; the served step becomes
-- the hand-in step.
finishQuest(181)
assert(#heard >= 2 and heard[#heard].step ~= nil
    and heard[#heard].step.kind == 'turnin',
  'the completion of the picked quest must notify with the hand-in step')

-- The hand-in clears the pick and notifies the end of the following.
fire('QUEST_TURNED_IN', 181)
state = follow.GetFollowState()
assert(state.active == true and state.questID == nil and state.step == nil,
  'the hand-in of the picked quest must clear the pick while the mode stays on')
assert(heard[#heard].active == true and heard[#heard].questID == nil
    and heard[#heard].step == nil,
  'the hand-in must notify the state that returns the window to the route')

-- With no pick, a quest state change notifies nobody.
fire('QUEST_TURNED_IN', 555)
assert(heard[#heard].questID == nil,
  'a quest state change with no pick must not serve anything')
print('ok - the hand-in of the picked quest ends the follow step')

-- The return to the route: a click on the step (user story 30) clears
-- the pick and returns the window to the route, but leaves Follow mode
-- itself on. The title-bar toggle of story 27 is the one control that
-- turns the mode off and keeps that choice in the saved table, so a
-- later pick in the log follows again without another click.
follow = loadFollow(quests, 'a181.5 d181.5 t181.5 a182.5 d182.5 t182.5')
listenFollow(follow)
takeQuest(181, 'Skinning knives', {
  { text = 'Winter Wolf slain: 3/7', numFulfilled = 3, numRequired = 7, finished = false },
})
superTracked = nil
follow.SetFollowMode(true)
pickInLog(181)
assert(follow.GetFollowState().step ~= nil,
  'the scenario must serve a step before the return')
follow.ReturnToRoute()
state = follow.GetFollowState()
assert(state.active == true and state.questID == nil and state.step == nil,
  'the return must clear the pick while Follow mode stays on')
assert(EfficientQuestsCharacter.followMode == true,
  'the return must not turn the switch off in the saved table; only the toggle does')
assert(heard[#heard].active == true and heard[#heard].step == nil,
  'the return must notify with the state after it')
pickInLog(182)
state = follow.GetFollowState()
assert(state.active == true and state.questID == 182 and state.step ~= nil,
  'after the return, a later pick in the log must follow again')
print('ok - a click on the step returns to the route and the mode stays on')

-- A client without super tracking: the service itself is missing, and
-- the controller loads all the same and follows the manual pick hook --
-- the road the window (#35) and the tests drive. A pick while Follow
-- mode is off is ignored.
C_SuperTrack = nil
follow = loadFollow(quests, 'a181.5 d181.5 t181.5 a182.5 d182.5 t182.5')
listenFollow(follow)
takeQuest(191, 'Off the path')
superTracked = nil
follow.SetFollowMode(true)
state = follow.GetFollowState()
assert(state.active == true and state.questID == nil,
  'turning the mode on without super tracking adopts nothing')
follow.SetFollowTarget(191)
state = follow.GetFollowState()
assert(state.questID == 191 and state.step ~= nil and state.step.kind == 'do'
    and state.step.headline == 'Do Off the path',
  'the manual pick hook must serve the step of the picked quest')
assert(#heard == 2 and heard[2].questID == 191 and heard[2].step ~= nil,
  'the manual pick must notify')
follow.SetFollowMode(false)
follow.SetFollowTarget(191)
state = follow.GetFollowState()
assert(state.active == false and state.questID == nil,
  'a pick while follow mode is off must be ignored')
C_SuperTrack = { GetSuperTrackedQuestID = function() return superTracked end }
print('ok - without super tracking, the manual pick hook drives the following')

-- The real copied data through the shared seam: the whole addon loads
-- the way the game loads it, in manifest order, and the follow mode
-- controller is there with its whole surface. The copied bounty on
-- Garrick Padfoot (quest id 6) serves its pick-up step, and its hand-in
-- ends the following, all on the real tables.
dofile('tests/addon.lua')()
follow = EfficientQuests.followMode
assert(type(follow) == 'table' and type(follow.GetFollowState) == 'function'
    and type(follow.SetFollowMode) == 'function'
    and type(follow.SetFollowTarget) == 'function'
    and type(follow.ReturnToRoute) == 'function'
    and type(follow.RegisterCallback) == 'function',
  'the addon must offer the follow mode controller with its whole surface after load')
fire('PLAYER_LOGIN')
listenFollow(follow)
follow.SetFollowMode(true)
follow.SetFollowTarget(6)
state = follow.GetFollowState()
assert(state.active == true and state.questID == 6 and state.step ~= nil
    and state.step.kind == 'pickup'
    and state.step.headline == 'Pick up Bounty on Garrick Padfoot',
  'the real data must serve the pick-up step of the bounty quest')
fire('QUEST_TURNED_IN', 6)
state = follow.GetFollowState()
assert(state.active == true and state.questID == nil and state.step == nil,
  'the hand-in of the followed quest must end the following on the real data too')
assert(heard[#heard].questID == nil,
  'the hand-in must notify through the whole addon as well')
print('ok - the real data follows a picked quest through the whole addon')

print('all follow mode tests passed')
