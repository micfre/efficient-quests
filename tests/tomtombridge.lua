-- The TomTom bridge: one waypoint for the current step. The suite loads
-- the code modules by hand per scenario -- the way the step window suite
-- does -- into a namespace that holds the scenario's own synthetic quests
-- and Path, and the frames come from the widget fake the options and step
-- window suites use, grown by the slider setters the options panel adds.
-- TomTom itself is a fake that records every add and remove the addon
-- makes and holds one foreign waypoint of the player's own. The
-- assertions read the record, the way a player reads the map, and demand
-- that the foreign waypoint survives everything the bridge does.

local messages = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) table.insert(messages, message) end }
SlashCmdList = {}

-- Widget fake: every frame the addon builds records its size, its points,
-- its scripts, its text, and its children, so the suite can assert on the
-- windows the way a player reads them. Everything the client creates
-- starts out shown; only an explicit Hide takes a widget off the screen.
local Widget = {}
Widget.__index = Widget

local frames = {}

local function widget(kind, name, parent)
  local self = setmetatable({
    kind = kind or 'Frame', name = name, parent = parent,
    children = {}, scripts = {}, points = {}, shown = true,
  }, Widget)
  if parent and parent.children then table.insert(parent.children, self) end
  table.insert(frames, self)
  return self
end

function CreateFrame(kind, name, parent)
  return widget(kind, name, parent)
end

function CreateVector2D(x, y)
  return { GetXY = function() return y * 1000, x * 1000 end }
end
function IsLoggedIn() return false end
WOW_PROJECT_ID, WOW_PROJECT_CAMELOT = 5, 5
UIParent = {}
GetScreenHeight = function() return 768 end
Enum = { UIMapType = { Zone = 3, Continent = 2 } }
securecallfunction = function(fn, ...) return fn(...) end
local timers = {}
C_Timer = { After = function(delay, fn) table.insert(timers, fn) end }

-- The map fake of the step model suite: two synthetic maps -- 100 on
-- continent 7 and 200 on continent 8, both 1000 by 1000 yards with both
-- axes mirrored, so a point at x and y percent sits at (100 - x) and
-- (100 - y) times ten yards -- the shape the embedded HereBeDragons
-- turns map points into world yards with.
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

-- The character sheet: an undead mage of the Horde.
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

-- QuestieDB is another addon's ticket; a sentinel fails the suite the
-- moment anything reaches for it.
LibQuestieDB = {
  Quest = { Get = function() error('the bridge must not call QuestieDB') end },
  Npc = { Get = function() error('the bridge must not call QuestieDB') end },
}

-- Setters the addon uses; each one records what the player would see, and
-- the getters answer with the same values.
function Widget:SetSize(width, height) self.width, self.height = width, height end
function Widget:SetWidth(width) self.width = width end
function Widget:SetHeight(height) self.height = height end
function Widget:SetPoint(...) table.insert(self.points, {...}) end
function Widget:ClearAllPoints() self.points = {} end
function Widget:SetAllPoints(target) self.points = { {'ALLPOINTS', target} } end
function Widget:Show() self.shown = true end
function Widget:Hide() self.shown = false end
function Widget:IsShown() return self.shown end
function Widget:SetShown(shown) self.shown = shown end
function Widget:SetScript(name, handler) self.scripts[name] = handler end
function Widget:GetScript(name) return self.scripts[name] end
function Widget:RegisterEvent(name) self.events = self.events or {}; self.events[name] = true end
function Widget:UnregisterAllEvents() self.events = {} end
function Widget:CreateFontString(name, layer, template)
  local field = widget('FontString', name, self)
  field.template = template
  return field
end
function Widget:CreateTexture(name, layer)
  return widget('Texture', name, self)
end
function Widget:SetParent(parent)
  if self.parent and self.parent.children then
    for at, child in ipairs(self.parent.children) do
      if child == self then table.remove(self.parent.children, at) break end
    end
  end
  self.parent = parent
  if parent and parent.children then table.insert(parent.children, self) end
end
function Widget:SetBackdrop(backdrop) self.backdrop = backdrop end
function Widget:GetBackdrop() return self.backdrop end
function Widget:SetBackdropColor(r, g, b, a) self.backdropColor = { r, g, b, a } end
function Widget:SetBackdropBorderColor(r, g, b, a) self.backdropBorderColor = { r, g, b, a } end
function Widget:SetTexture(path) self.texture = path end
function Widget:SetAtlas(atlas) self.atlas = atlas end
function Widget:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
function Widget:SetText(text) self.text = text end
function Widget:GetText() return self.text end
function Widget:SetJustifyH(justify) self.justifyH = justify end
function Widget:SetJustifyV(justify) self.justifyV = justify end
function Widget:SetFontObject(font) self.fontObject = font end
function Widget:SetTextColor(r, g, b, a) self.textColor = { r, g, b, a } end
function Widget:SetAlpha(alpha) self.alpha = alpha end
function Widget:SetScale(scale) self.scale = scale end
function Widget:SetFrameStrata(strata) self.strata = strata end
function Widget:SetChecked(checked) self.checked = checked end
function Widget:GetChecked() return self.checked end
function Widget:SetCheckedTexture(texture) self.checkedTexture = texture end
function Widget:SetEnabled(enabled) self.enabled = enabled end
function Widget:SetMovable(movable) self.movable = movable end
function Widget:SetClampedToScreen(v) self.clampedToScreen = v end
function Widget:RegisterForDrag(button) self.dragButton = button end
function Widget:EnableMouse(v) self.mouseEnabled = v end
function Widget:StartMoving() self.dragging = true end
function Widget:StopMovingOrSizing() self.dragging = false end
function Widget:GetLeft() return self.left end
function Widget:GetTop() return self.top end
-- The options panel rows add the atlas and slider setters.
function Widget:SetNormalTexture(texture) self.normalTexture = texture end
function Widget:SetNormalAtlas(atlas) self.normalAtlas = atlas end
function Widget:SetPushedAtlas(atlas) self.pushedAtlas = atlas end
function Widget:SetMinMaxValues(low, high) self.minValue, self.maxValue = low, high end
function Widget:SetValue(value) self.value = value end
function Widget:GetValue() return self.value end
function Widget:SetValueStep(step) self.valueStep = step end
function Widget:SetObeyStepOnDrag(obey) self.obeyStepOnDrag = obey end
function Widget:SetOrientation(orientation) self.orientation = orientation end

-- Deliver a game event the way the client does: only the frames that
-- registered for it hear it.
local function fire(event, ...)
  for _, frame in ipairs(frames) do
    if frame.events and frame.events[event] and frame.scripts.OnEvent then
      frame.scripts.OnEvent(frame, event, ...)
    end
  end
end

-- The embedded libraries load once, before every scenario, the way the
-- game loads them before the addon.
assert(loadfile('dist/EfficientQuests/Libs/LibStub/LibStub.lua'))()
assert(loadfile('dist/EfficientQuests/Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua'))()
assert(loadfile('dist/EfficientQuests/Libs/HereBeDragons/HereBeDragons-2.0.lua'))()

-- The TomTom fake: the surface the bridge may call -- AddWaypoint,
-- RemoveWaypoint, and the IsCrazyArrowEmpty mark of the real TomTom (the
-- TomTom README names it as the loaded test) -- and nothing else. Every
-- add and remove lands in one ordered record, and the set of live
-- waypoints answers lookups. One foreign waypoint of the player's own
-- sits in the set from the start; it must survive every operation.
local added, removed, calls, live = {}, {}, {}, {}

local function freshTomTom()
  added, removed, calls, live = {}, {}, {}, {}
  local fake = {
    IsCrazyArrowEmpty = function() return true end,
    AddWaypoint = function(_, map, x, y, opts)
      local uid = { map, x, y, title = opts and opts.title, from = opts and opts.from }
      live[uid] = true
      table.insert(added, { map = map, x = x, y = y, opts = opts, uid = uid })
      table.insert(calls, { 'add', uid })
      return uid
    end,
    RemoveWaypoint = function(_, uid)
      live[uid] = nil
      table.insert(removed, uid)
      table.insert(calls, { 'remove', uid })
    end,
  }
  local foreign = { 100, 0.5, 0.5, title = 'Player marker', from = 'Player' }
  live[foreign] = true
  fake.foreign = foreign
  -- Anything outside the documented surface -- a clear-all, a remove by
  -- title, a query -- errors the moment the bridge touches it.
  return setmetatable(fake, {
    __index = function(_, key)
      error('the bridge must not touch TomTom.' .. tostring(key))
    end,
  })
end

-- The player's own waypoint must survive everything the bridge does, and
-- no bridge operation may touch anything but its own uid.
local function foreignSurvives(fake)
  assert(live[fake.foreign] == true,
    'the waypoint the player set by hand must survive every bridge operation')
  for _, uid in ipairs(removed) do
    assert(uid ~= fake.foreign,
      'the bridge must never remove a waypoint it did not set')
  end
end

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

-- One controlled scenario: the code modules load by hand, in manifest
-- order, into a namespace whose data tables are the scenario's own. The
-- saved tables are the ones the previous session of the same player left;
-- a fresh start hands empty tables. The world comes up the way the game
-- brings it: login first (the saved tables take their defaults), then the
-- player enters the world and the window appears. TomTom is the fake
-- above unless the scenario says the player runs without it.
local function loadBridge(quests, pathLine, tables, savedDB, savedCharacter, noTomTom)
  EfficientQuestsDB = savedDB or {}
  EfficientQuestsCharacter = savedCharacter or {}
  frames = {}
  logEntries, objectives, completeFlag = {}, {}, {}
  onQuest, flaggedCompleted, completedIDs = {}, {}, {}
  if noTomTom then
    TomTom = nil
  else
    TomTom = freshTomTom()
  end
  tables = tables or {}
  local namespace = {
    quests = quests,
    pathData = { version = 't', starts = { undead = pathLine } },
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
  loadFile('Geo.lua')
  loadFile('RoutePlanner.lua')
  loadFile('StepModel.lua')
  loadFile('FollowMode.lua')
  loadFile('Options.lua')
  loadFile('Menu.lua')
  loadFile('StepWindow.lua')
  loadFile('TomTomBridge.lua')
  fire('PLAYER_LOGIN')
  fire('PLAYER_ENTERING_WORLD')
  assert(type(EfficientQuests.TomTomBridge) == 'table',
    'the addon must offer the TomTom bridge after the player enters the world')
  return EfficientQuests.TomTomBridge, EfficientQuests.StepWindow, TomTom
end

-- The delayed work of a frame runs through the fake timer, so the suite
-- decides when the next frame comes. A timer may queue another; the loop
-- runs until the frame is quiet.
local function runTimers()
  while #timers > 0 do
    local pending = timers
    timers = {}
    for _, fn in ipairs(pending) do fn() end
  end
end

-- Take a quest the way the game does: the log knows it, objectives come
-- with it, and QUEST_ACCEPTED told the reader. A frame later the window
-- has heard it.
local function takeQuest(id, title, objs)
  table.insert(logEntries, { questID = id, title = title, level = player.level, isHeader = false })
  objectives[id] = objs or { { text = 'Something done', numFulfilled = 0, numRequired = 1, finished = false } }
  fire('QUEST_ACCEPTED', id)
  runTimers()
end

-- Fill every objective of a quest in the log: the quest is complete.
local function finishQuest(id, objs)
  objectives[id] = objs or { { text = 'Something done', numFulfilled = 1, numRequired = 1, finished = true } }
  completeFlag[id] = true
  fire('QUEST_LOG_UPDATE')
  runTimers()
end

-- Hand the quest in: it leaves the log and counts as finished for good.
local function handInQuest(id)
  for at, entry in ipairs(logEntries) do
    if entry.questID == id then table.remove(logEntries, at) break end
  end
  objectives[id], completeFlag[id] = nil, nil
  onQuest[id] = nil
  flaggedCompleted[id] = true
  table.insert(completedIDs, id)
  fire('QUEST_TURNED_IN', id)
  runTimers()
end

-- The window frame itself, by the name the module gives it.
local function windowFrame()
  for _, frame in ipairs(frames) do
    if frame.name == 'EfficientQuestsStepWindow' then return frame end
  end
  return nil
end

-- A walk over everything the window shows. A hidden frame hides its
-- children with it, so the walk skips whole hidden subtrees.
local function textsOf(frame)
  local seen = {}
  local function walk(node)
    for _, child in ipairs(node.children or {}) do
      if child.shown then
        if child.kind == 'FontString' and child.text then seen[child.text] = true end
        walk(child)
      end
    end
  end
  walk(frame)
  return seen
end

-- The row that shows this text: a Button whose own label field says it,
-- so the suite can click the row.
local function rowOfText(root, text)
  local found
  local function walk(node)
    for _, child in ipairs(node.children or {}) do
      if child.shown and not found and child.kind == 'Button' then
        for _, field in ipairs(child.children or {}) do
          if field.kind == 'FontString' and field.text == text then found = child end
        end
      end
      walk(child)
    end
  end
  walk(root)
  return found
end

-- A click the way the client delivers it, with the button named.
local function click(button, which)
  local handler = button.scripts.OnClick
  if handler then handler(button, which or 'LeftButton') end
end

-- One world for the first scenarios: a quest with a start, an objective
-- point, and a finish on map 100, a second quest behind it, a quest the
-- data knows no place for, and a quest with two objective spots. A fresh
-- character stands on the pick-up of the first.
local BASE = {
  [301] = quest { id = 301, name = 'Wolf pelts', level = 6, reqLevel = 5,
    start = { 100, 72, 30 }, finish = { 100, 30, 70 },
    giver = 'Deathstalker Rane', ender = 'Deathstalker Zigris',
    giverNpc = 900, enderNpc = 902,
    objectives = { { 100, 40, 50 } },
    targets = { { 'Winter Wolf', { 910 }, {}, 7 } } },
  [302] = quest { id = 302, name = 'Bone chips', level = 6, reqLevel = 5,
    start = { 100, 60, 60 }, finish = { 100, 60, 60 },
    giver = 'Quartermaster Zigris', ender = 'Quartermaster Zigris',
    giverNpc = 901, enderNpc = 901,
    targets = { { 'Mottled boar', { 911 }, {}, 3 } } },
  [303] = quest { id = 303, name = 'No place at all', level = 6, reqLevel = 5 },
  [304] = quest { id = 304, name = 'Two spots', level = 6, reqLevel = 5,
    start = { 100, 20, 80 }, finish = { 100, 20, 80 },
    objectives = { { 100, 80, 20 }, { 100, 60, 40 } },
    targets = { { 'Plainstrider', { 922 }, {}, 6 } } },
}
local BASE_PATH = 'a301.5 d301.5 t301.5 a302.5 d302.5 t302.5'
  .. ' a303.5 d303.5 t303.5 a304.5 d304.5 t304.5'

-- The player stands in the open field of map 100, in reach of everything
-- the scenarios place.
world = { x = 300, y = 600, instance = 7 }
inInstance = false
local bridge, stepWindow, tomtom = loadBridge(BASE, BASE_PATH)

-- One waypoint per step: the window comes up on the pick-up of the first
-- quest, and the bridge sets exactly one TomTom waypoint for it -- the
-- map of the step's point, the percent cut to the 0-to-1 fractions TomTom
-- takes, the headline as the title, and the addon as the setter. No
-- display flags ride along, so the TomTom options decide how the waypoint
-- appears, and it lives one session: no persistence.
assert(#added == 1,
  'the bridge must set exactly one waypoint for the step on screen, saw ' .. #added)
local first = added[1]
assert(first.map == 100 and first.x == 0.72 and first.y == 0.30,
  'the waypoint must sit at the step point as 0-to-1 fractions')
assert(first.opts.title == 'Pick up Wolf pelts',
  'the waypoint title must be the headline of the step')
assert(first.opts.from == 'Efficient Quests',
  'the waypoint must name the addon that set it')
assert(first.opts.persistent == false,
  'the waypoint must live one session, so the bridge must say persistent = false')
assert(first.opts.minimap == nil and first.opts.world == nil
    and first.opts.crazy == nil,
  'the bridge must pass no display flags; the TomTom options decide')
assert(#removed == 0, 'nothing was on the map before, so nothing comes off')
foreignSurvives(tomtom)
print('ok - one waypoint per step, no flags, one session')

-- The waypoint follows the step. The step moves from the pick-up to the
-- work once the quest is taken, and to the hand-in once every goal is
-- done: each move takes the old waypoint off first -- the record says
-- remove before add -- and sets the new one, so no step ever leaves a
-- marker behind and no place ever holds two (user story 37).
takeQuest(301, 'Wolf pelts', {
  { text = 'Winter Wolf slain: 3/7', numFulfilled = 3, numRequired = 7, finished = false },
})
assert(#added == 2 and #removed == 1,
  'a step change must take the old waypoint off and set the new one')
assert(calls[2][1] == 'remove' and calls[2][2] == added[1].uid,
  'the old waypoint must come off before the new one goes on')
assert(added[2].map == 100 and added[2].x == 0.40 and added[2].y == 0.50,
  'the work step must point at its objective place')
assert(added[2].opts.title == 'Do Wolf pelts',
  'the new waypoint must carry the headline of the new step')
finishQuest(301)
assert(#added == 3 and #removed == 2 and calls[4][1] == 'remove',
  'the finished work must replace its waypoint with the hand-in one')
assert(added[3].x == 0.30 and added[3].y == 0.70
    and added[3].opts.title == 'Hand in Wolf pelts',
  'the hand-in step must point at the finish place of the quest')
handInQuest(301)
assert(#added == 4 and #removed == 3,
  'a handed-in quest must move the waypoint to the next step')
assert(added[4].x == 0.60 and added[4].y == 0.60
    and added[4].opts.title == 'Pick up Bone chips',
  'the next step must own the waypoint now')
foreignSurvives(tomtom)
print('ok - the waypoint is replaced on every step change, old off first')

-- The window hides, and the waypoint comes with it: the X of the title
-- bar takes the window off the screen, and the bridge answers the same
-- WindowChanged -- shown = false now -- by taking its waypoint down. The
-- window comes back through Show, the way the /eq command will bring it
-- back, and the step on screen owns a waypoint again.
local win = windowFrame()
local hideButton
for _, child in ipairs(win.children) do
  if child.kind == 'Button' then
    for _, field in ipairs(child.children) do
      if field.kind == 'FontString' and field.text == 'X' then hideButton = child end
    end
  end
end
assert(hideButton ~= nil, 'the window must carry its X control')
click(hideButton)
assert(stepWindow.IsShown() == false, 'the X must hide the window')
assert(#removed == 4 and removed[4] == added[4].uid and #added == 4,
  'a hidden window must leave no waypoint standing')
foreignSurvives(tomtom)
stepWindow.Show()
assert(#added == 5 and #removed == 4,
  'the window coming back must set the waypoint of its step again')
assert(added[5].opts.title == 'Pick up Bone chips',
  'the waypoint after the show must belong to the step on screen')
print('ok - hiding the window takes the waypoint down, showing sets it again')

-- The player skips the quest of the step: a right-click on the headline
-- puts the quest in the skip list, the route replans at once, and the
-- window stands on the next step -- one the data knows no place for. No
-- new waypoint goes up, and the old one came down (user stories 23 and
-- 38).
click(rowOfText(win, 'Pick up Bone chips'), 'RightButton')
assert(textsOf(win)['Pick up No place at all'],
  'the skip must move the window to the next step of the route')
assert(#removed == 5 and removed[5] == added[5].uid and #added == 5,
  'a step the data knows no place for must not own a waypoint: the old one comes off and none goes on')
foreignSurvives(tomtom)
-- The work step of the placeless quest owns no waypoint either.
takeQuest(303, 'No place at all')
assert(#added == 5,
  'a work step without coordinates must not set a waypoint')
print('ok - the skip takes the waypoint down and a placeless step sets none')

-- The nearest known target: the work step of Two spots carries two
-- candidate places -- the field at 80/20 and the camp at 60/40 -- and the
-- bridge points at the one the player stands closest to (user story 42).
-- The player at world (300, 600) is a hundred yards from the camp and
-- about 224 from the field, so the camp answers.
handInQuest(303)
assert(added[6].opts.title == 'Pick up Two spots',
  'the scenario must reach the pick-up of Two spots')
takeQuest(304, 'Two spots')
assert(#added == 7 and #removed == 6,
  'the work step of Two spots must replace the pick-up waypoint')
assert(added[7].map == 100 and added[7].x == 0.60 and added[7].y == 0.40,
  'of several candidate places the waypoint must sit on the nearest')
-- The player crosses the field towards the other place, and the next
-- window refresh turns the waypoint around: now the field at 80/20 is
-- the nearer one.
world = { x = 250, y = 750, instance = 7 }
stepWindow.Hide()
stepWindow.Show()
assert(#added == 8 and #removed == 7,
  'a refresh after the player moved must replace the waypoint with the now-nearest place')
assert(added[8].x == 0.80 and added[8].y == 0.20,
  'the waypoint must follow the player to the now-nearest of the candidates')
foreignSurvives(tomtom)
print('ok - of several places the waypoint sits on the nearest, and follows the player')

-- Inside a dungeon the reader answers no player position, and the bridge
-- sets no waypoint at all: the step may name its place, but nothing may
-- point the player at a marker underground (user story 43). A waypoint
-- that stood while the player was outside comes off with the refresh.
inInstance = true
stepWindow.Hide()
stepWindow.Show()
assert(#removed == 8 and #added == 8,
  'inside an instance the standing waypoint must come off and none may go on')
-- Still inside: the window keeps showing its step, and still no waypoint.
stepWindow.Hide()
stepWindow.Show()
assert(#added == 8,
  'a step shown inside an instance must not own a waypoint')
assert(textsOf(windowFrame())['Do Two spots'],
  'without a waypoint the step window must still show its step')
foreignSurvives(tomtom)
-- Back under the sky: the step owns its waypoint again.
inInstance = false
stepWindow.Hide()
stepWindow.Show()
assert(#added == 9,
  'back in the open world the step must own its waypoint again')
print('ok - no waypoint inside an instance, and the step still shows')

-- The dungeon guard is explicit, not the accident of a missing position
-- (user story 43): the position service keeps answering while the
-- instance flag is set -- the shape of a client whose maps place the
-- player inside an instance -- and the bridge must still set no
-- waypoint, whatever place the step knows.
inInstance = true
world = { x = 300, y = 600, instance = 7 }
stepWindow.Hide()
stepWindow.Show()
assert(#added == 9 and #removed == 9,
  'with a position known inside an instance, the explicit dungeon guard must still keep every waypoint away')
assert(textsOf(windowFrame())['Do Two spots'],
  'the step itself must keep showing inside the instance')
foreignSurvives(tomtom)
inInstance = false
print('ok - the dungeon guard holds even with a known position')

-- The step ends, and the waypoint ends with it: the last quest of the
-- route is handed in, the window says the route is clear, and the bridge
-- holds no marker over a finished route (user story 38).
world = { x = 400, y = 500, instance = 7 }
inInstance = false
bridge, stepWindow, tomtom = loadBridge({
  [305] = quest { id = 305, name = 'Last errand', level = 6, reqLevel = 5,
    start = { 100, 40, 40 }, finish = { 100, 40, 40 },
    objectives = { { 100, 50, 50 } } },
}, 'a305.5 d305.5 t305.5')
assert(#added == 1, 'the last route must open with its pick-up waypoint')
takeQuest(305, 'Last errand')
finishQuest(305)
handInQuest(305)
assert(textsOf(windowFrame())['The route is clear'],
  'the scenario must have finished the route')
assert(#removed == 3 and #added == 3,
  'the end of the last step must take the waypoint down and set none')
foreignSurvives(tomtom)
print('ok - the end of the route leaves no waypoint standing')

-- The off option: a player who saved waypoints = false gets none, on any
-- step, while the window works as always (user story 40).
world = { x = 300, y = 600, instance = 7 }
bridge, stepWindow, tomtom = loadBridge(BASE, BASE_PATH, nil,
  { waypoints = false })
assert(#added == 0,
  'the off option must stop the bridge from setting any waypoint')
takeQuest(301, 'Wolf pelts')
assert(#added == 0,
  'the off option must keep the bridge off on every later step too')
assert(textsOf(windowFrame())['Do Wolf pelts'],
  'with the bridge off the step window must work as always')
foreignSurvives(tomtom)
print('ok - the saved off option keeps every waypoint away')

-- The options panel toggle: the player flips Waypoints off while a
-- waypoint stands, and the standing waypoint comes off at once; the
-- flip back lets the next look at the world set it again.
bridge, stepWindow, tomtom = loadBridge(BASE, BASE_PATH)
assert(#added == 1, 'the default is on, so the pick-up step owns a waypoint')
local panel = EfficientQuests.Options.Open()
local function rowByLabel(label)
  local found
  local function walk(node)
    for _, child in ipairs(node.children or {}) do
      if child.kind == 'FontString' and child.text == label and not found then
        found = child.parent
      end
      walk(child)
    end
  end
  walk(panel)
  return found
end
local function controlOf(row, kind)
  for _, child in ipairs(row.children or {}) do
    if child.kind == kind then return child end
  end
end
local toggle = controlOf(rowByLabel('Waypoints'), 'CheckButton')
assert(toggle ~= nil, 'the options panel must carry the Waypoints toggle')
-- A click on a checkbox, the way the client does it: the box flips first,
-- then its OnClick runs.
local function flip(check)
  check:SetChecked(not check:GetChecked())
  local handler = check.scripts.OnClick
  if handler then handler(check, 'LeftButton') end
end
local standing = added[1].uid
flip(toggle)
assert(EfficientQuestsDB.waypoints == false,
  'the click must turn the option off in the saved table')
assert(#removed == 1 and removed[1] == standing and #added == 1,
  'turning the option off must take the standing waypoint down at once')
foreignSurvives(tomtom)
flip(toggle)
assert(EfficientQuestsDB.waypoints == true,
  'the second click must turn the option back on')
assert(#added == 2 and #removed == 1,
  'turning the option back on must set the waypoint of the step again')
foreignSurvives(tomtom)
print('ok - the options toggle takes the standing waypoint down and sets it again')

-- Without TomTom: nothing breaks. The window shows its step, and the
-- addon leaves the absent TomTom table alone (user story 41). A fake
-- TomTom that offers only AddWaypoint -- the shape the TomTom README
-- warns about -- is not the real TomTom either, and the bridge stays
-- quiet around it.
world = { x = 300, y = 600, instance = 7 }
bridge, stepWindow = loadBridge(BASE, BASE_PATH, nil, nil, nil, true)
assert(stepWindow.IsShown() == true,
  'without TomTom the window must still come up with its step')
assert(textsOf(windowFrame())['Pick up Wolf pelts'],
  'without TomTom the step must show its text only')
takeQuest(301, 'Wolf pelts')
assert(textsOf(windowFrame())['Do Wolf pelts'],
  'without TomTom the steps must keep moving as always')
TomTom = { AddWaypoint = function()
  error('a fake TomTom is not the real one; the bridge must not call it')
end }
stepWindow.Hide()
stepWindow.Show()
assert(textsOf(windowFrame())['Do Wolf pelts'],
  'around a fake TomTom the bridge must stay quiet and the step must show')
print('ok - without the real TomTom nothing breaks and no call goes out')

-- The level-up step: it carries no place at all -- no point and no
-- candidate list -- so it owns no waypoint. The quest behind the gate
-- owns one again as soon as the level is reached.
world = { x = 300, y = 600, instance = 7 }
bridge, stepWindow, tomtom = loadBridge({
  [306] = quest { id = 306, name = 'Before the gate', level = 6, reqLevel = 5,
    start = { 100, 40, 60 }, finish = { 100, 40, 60 } },
  [307] = quest { id = 307, name = 'After the gate', level = 8, reqLevel = 7,
    start = { 100, 60, 40 }, finish = { 100, 60, 40 } },
}, 'a306.5 d306.5 t306.5 a307.8 d307.8 t307.8')
assert(#added == 1, 'the route must open with the pick-up waypoint')
-- The work step of this quest falls back to its finish place, which is
-- the pick-up place too: the marker stays exactly where it is, and no
-- remove-and-add churn hits TomTom for a step that did not move.
takeQuest(306, 'Before the gate')
assert(#added == 1 and #removed == 0,
  'a step whose place did not move must leave the standing waypoint alone')
finishQuest(306)
assert(#added == 1 and #removed == 0,
  'the hand-in on the same place must not churn the waypoint either')
handInQuest(306)
assert(textsOf(windowFrame())['Level up to 7'],
  'the scenario must stand on the level-up step')
assert(#removed == 1 and #added == 1,
  'a level-up step owns no waypoint: the old one comes off, none goes on')
player.level = 7
fire('PLAYER_LEVEL_UP', 7)
runTimers()
assert(#added == 2 and added[2].opts.title == 'Pick up After the gate',
  'past the gate the next quest must own its waypoint')
foreignSurvives(tomtom)
print('ok - a level-up step owns no waypoint, the quest behind the gate does')
