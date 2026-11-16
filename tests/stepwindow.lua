-- The step window: the addon's face. The suite loads the code modules by
-- hand per scenario -- the way the step model and follow mode suites do --
-- into a namespace that holds the scenario's own synthetic quests and
-- Path, and the frames come from the widget fake the options and menu
-- suites use, grown by the tick boxes, the drag band, and the reward
-- hovers the window adds. The assertions read the window the way a player
-- does: the texts it shows, the state of its tick boxes, its buttons, and
-- the saved data its drag writes. Quest mutations are counted on fakes,
-- because the window must never accept, hand in, or abandon a quest.

local messages = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) table.insert(messages, message) end }
SlashCmdList = {}

-- Widget fake: every frame the addon builds records its size, its points,
-- its scripts, its text, and its children, so the suite can assert on the
-- window the way a player reads it. Everything the client creates starts
-- out shown; only an explicit Hide takes a widget off the screen.
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
-- continent 7 and 200 on continent 8, both 1000 by 1000 yards -- so the
-- embedded HereBeDragons can turn map points into world yards.
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

-- The tooltip fake: the window hovers the rewards through the game
-- tooltip, so the suite counts which hovers reached it.
local hovered = { items = {}, spells = 0, shown = 0, hidden = 0 }
GameTooltip = {
  SetOwner = function() end,
  SetItemRef = function(_, link) table.insert(hovered.items, link) end,
  SetSpellByID = function(_, id)
    if id == 71 then hovered.spells = hovered.spells + 1 end
  end,
  Show = function() hovered.shown = hovered.shown + 1 end,
  Hide = function() hovered.hidden = hovered.hidden + 1 end,
}

-- The quest mutations the window must never offer (user story 67): each
-- forbidden call counts, and the end of the suite demands zeros.
local forbidden = { accept = 0, abandon = 0, handin = 0 }
AcceptQuest = function() forbidden.accept = forbidden.accept + 1 end
AbandonQuest = function() forbidden.abandon = forbidden.abandon + 1 end
CompleteQuest = function() forbidden.handin = forbidden.handin + 1 end

-- TomTom and QuestieDB are later tickets; sentinels fail the suite the
-- moment anything reaches for them.
TomTom = setmetatable({}, {
  __index = function() error('the step window must not call TomTom') end,
})
LibQuestieDB = {
  Quest = { Get = function() error('the step window must not call QuestieDB') end },
  Npc = { Get = function() error('the step window must not call QuestieDB') end },
}

-- Setters the window uses; each one records what the player would see, and
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
-- player enters the world and the window appears.
local function loadWindow(quests, pathLine, tables, savedDB, savedCharacter)
  EfficientQuestsDB = savedDB or {}
  EfficientQuestsCharacter = savedCharacter or {}
  frames = {}
  logEntries, objectives, completeFlag = {}, {}, {}
  onQuest, flaggedCompleted, completedIDs = {}, {}, {}
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
  loadFile('RoutePlanner.lua')
  loadFile('StepModel.lua')
  loadFile('FollowMode.lua')
  loadFile('Menu.lua')
  loadFile('StepWindow.lua')
  fire('PLAYER_LOGIN')
  fire('PLAYER_ENTERING_WORLD')
  assert(type(EfficientQuests.StepWindow) == 'table',
    'the addon must offer the step window after the player enters the world')
  return EfficientQuests.StepWindow
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

-- The window frame itself, by the name the module gives it.
local function windowFrame()
  for _, frame in ipairs(frames) do
    if frame.name == 'EfficientQuestsStepWindow' then return frame end
  end
  return nil
end

-- A walk over everything the window shows, the way a player's eye travels
-- it. A hidden frame hides its children with it, so the walk skips whole
-- hidden subtrees.
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

-- The row that shows this text: a Button whose own label field says it, so
-- the suite can read the row's tick box and click the row.
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

-- The check box that carries this label, for the Follow toggle of the
-- title bar.
local function checkByLabel(root, label)
  local found
  local function walk(node)
    for _, child in ipairs(node.children or {}) do
      if child.shown and not found and child.kind == 'CheckButton' then
        for _, field in ipairs(child.children or {}) do
          if field.kind == 'FontString' and field.text == label then found = child end
        end
      end
      walk(child)
    end
  end
  walk(root)
  return found
end

-- The tick box of one row.
local function tickOf(row)
  for _, child in ipairs(row.children or {}) do
    if child.kind == 'CheckButton' then return child end
  end
  return nil
end

-- A click the way the client delivers it, with the button named.
local function click(button, which)
  local handler = button.scripts.OnClick
  if handler then handler(button, which or 'LeftButton') end
end

-- One world for most of the suite: two quests of the Path -- Wolf pelts
-- with its rewards and Bone chips -- and one quest behind a level gate.
-- A fresh character stands on the pick-up of the first.
local BASE = {
  [201] = quest { id = 201, name = 'Wolf pelts', level = 6, reqLevel = 5,
    start = { 100, 72, 30 }, finish = { 100, 30, 70 },
    giver = 'Deathstalker Rane', ender = 'Deathstalker Rane',
    giverNpc = 900, enderNpc = 900,
    objectives = { { 100, 40, 50 } },
    targets = { { 'Winter Wolf', { 910 }, {}, 7 } },
    tipPickup = 'Moves around the open field.',
    tipHandIn = 'Moves around the open field.',
    rewardItems = { 60, 61 }, rewardChoices = { 62 }, spell = 71 },
  [202] = quest { id = 202, name = 'Bone chips', level = 6, reqLevel = 5,
    start = { 100, 60, 60 }, finish = { 100, 60, 60 },
    giver = 'Quartermaster Zigris', ender = 'Quartermaster Zigris',
    giverNpc = 901, enderNpc = 901,
    targets = { { 'Mottled boar', { 911 }, {}, 3 } } },
  [203] = quest { id = 203, name = 'After the gate', level = 8, reqLevel = 7,
    start = { 100, 50, 50 }, finish = { 100, 50, 50 } },
}
local BASE_PATH = 'a201.5 d201.5 t201.5 a202.5 d202.5 t202.5 a203.8 d203.8 t203.8'
local BASE_TABLES = {
  npcWhere = { [900] = 'By the tower north of the mill.' },
  itemNames = { [60] = 'Layered Tunic', [61] = 'Dwarven Leather Pants' },
}

-- The window appears when the player enters the world, and the player
-- reads one step at a time: the headline, the goal lines, the place text,
-- the rewards, and the next few steps of the route.
player.level = 6
local stepWindow = loadWindow(BASE, BASE_PATH, BASE_TABLES)
assert(stepWindow.IsShown() == true, 'the window must be on the screen after login')
local win = windowFrame()
assert(win ~= nil, 'the window frame must exist')
local texts = textsOf(win)
assert(texts['Efficient Quests'], 'the title bar must name the addon')
assert(texts['Pick up Wolf pelts'],
  'the window must show the headline of the current step')
assert(texts['Talk to Deathstalker Rane'],
  'the pick-up step must list its Talk to line')
assert(texts['By the tower north of the mill.'],
  'the place note of the giver must show under the Talk to line')
assert(texts['Moves around the open field.'],
  'the tip of a giver who moves must show under the Talk to line')
assert(texts['Accept Wolf pelts'], 'the pick-up step must list its Accept line')
assert(texts['Northfield, north-east'],
  'the window must say where the step happens, in plain words')
assert(texts['Step 1 / 7'],
  'the window must say the place in the route, saw ' .. tostring(texts['Step 1 / 7']))
assert(texts['Rewards'], 'the rewards must sit under their own label')
assert(texts['Layered Tunic'] and texts['Dwarven Leather Pants'],
  'the reward items must list by name')
assert(texts['Item 62'],
  'a reward choice the data knows by id only must list in plain words')
assert(texts['Spell 71'], 'the spell a quest teaches must list too')
assert(texts['Next steps'], 'the next steps must sit under their own label')
assert(texts['Do Wolf pelts'] and texts['Hand in Wolf pelts']
    and texts['Pick up Bone chips'],
  'the next few steps must list under the current step')
assert(not texts['Do Bone chips'],
  'only the next three steps list, not the whole route')
assert(not texts['Level up to 7'],
  'the level-up marker is four places ahead and must stay off the list')
print('ok - the window shows one step with its lines, place, rewards, and next steps')

-- The tick boxes: a goal line carries one, the notes carry none, and the
-- tick fills itself from the quest state as the player works.
local talk = rowOfText(win, 'Talk to Deathstalker Rane')
assert(talk ~= nil, 'the Talk to line must sit on a row of its own')
local talkTick = tickOf(talk)
assert(talkTick ~= nil and talkTick.shown and talkTick.checked == false,
  'a goal line must carry a tick box, empty while the goal is open')
local tip = rowOfText(win, 'Moves around the open field.')
assert(tickOf(tip) ~= nil and not tickOf(tip).shown,
  'a tip line carries no tick box')

-- The counts and the ticks move with the quest log: the step the window
-- stands on moves from the pick-up to the work once the quest is taken,
-- and to the hand-in once every goal is done.
takeQuest(201, 'Wolf pelts', {
  { text = 'Winter Wolf slain: 3/7', numFulfilled = 3, numRequired = 7, finished = false },
})
texts = textsOf(win)
assert(texts['Do Wolf pelts'] and texts['Step 1 / 6'],
  'a taken quest must move the window to its work step')
assert(texts['Winter Wolf slain'] and texts['3 of 7'],
  'the live goal must list its words and its count')
local goal = rowOfText(win, 'Winter Wolf slain')
assert(tickOf(goal).checked == false, 'an open goal must keep its tick empty')
finishQuest(201)
texts = textsOf(win)
assert(texts['Hand in Wolf pelts'] and texts['Step 2 / 6'],
  'a finished quest must move the window to its hand-in step')
local turnin = rowOfText(win, 'Turn in Wolf pelts')
assert(turnin ~= nil and tickOf(turnin).checked == true,
  'the hand-in line must tick once every goal of the quest is done')
print('ok - the tick boxes and counts follow the quest log')

-- Paging: the Back and Next buttons walk the route, the place line counts
-- the paged step, and the way back to the current step is one button away.
player.level = 6
stepWindow = loadWindow(BASE, BASE_PATH, BASE_TABLES)
win = windowFrame()
click(rowOfText(win, 'Next'))
texts = textsOf(win)
assert(texts['Do Wolf pelts'] and texts['Step 2 / 7'],
  'Next must page to the step behind the current one')
assert(texts['Winter Wolf'] and texts['0 of 7'],
  'a paged work step the player has not taken lists its goals from the data')
assert(texts['Current step'], 'a paged window must offer the way back')
click(rowOfText(win, 'Next'))
assert(textsOf(win)['Step 3 / 7'], 'Next must page one step further')
click(rowOfText(win, 'Back'))
assert(textsOf(win)['Step 2 / 7'], 'Back must page one step back')
click(rowOfText(win, 'Current step'))
texts = textsOf(win)
assert(texts['Pick up Wolf pelts'] and texts['Step 1 / 7'],
  'the Current step button must return the window to the current step')
assert(not texts['Current step'],
  'on the current step the way back must leave the screen')

-- The level-up entry renders as its step, both on the paging walk and in
-- the next-steps list.
click(rowOfText(win, 'Next'))
click(rowOfText(win, 'Next'))
click(rowOfText(win, 'Next'))
click(rowOfText(win, 'Next'))
texts = textsOf(win)
assert(texts['Step 5 / 7'], 'four Next clicks must reach the fifth place')
assert(texts['Level up to 7'],
  'the level-up entry must render as its step in the next-steps list')
click(rowOfText(win, 'Next'))
click(rowOfText(win, 'Next'))
texts = textsOf(win)
assert(texts['Step 7 / 7'] and texts['Level up to 7'],
  'the level-up step must be reachable as the step on screen')
assert(texts['Kill mobs around here until level 7'],
  'the level-up step must list its own line')

-- A change of the world replans the route, and the paged window returns to
-- the current step on its own (the documented choice).
click(rowOfText(win, 'Current step'))
click(rowOfText(win, 'Next'))
assert(textsOf(win)['Step 2 / 7'], 'the window must be paged one ahead first')
takeQuest(201, 'Wolf pelts')
texts = textsOf(win)
assert(texts['Step 1 / 6'] and texts['Do Wolf pelts'],
  'a replanned route must bring the window back to the current step')
assert(not texts['Current step'], 'back home, the way back must leave the screen')
print('ok - Back, Next, the place line, and the way back to the current step')

-- The hunts block: the other kill goals near the player list under their
-- own label, each with its yards, its place, and its own goals. The world
-- is the one the step model suite walks: the player stands at world
-- (150, 150) on continent 7, and the fake maps are 1000 by 1000 yards.
local hunts = {
  [161] = quest { id = 161, name = 'First hunts', level = 6, reqLevel = 5,
    targets = { { 'Red boar', { 921 }, {}, 4 } } },
  [162] = quest { id = 162, name = 'Nearby hunts', level = 6, reqLevel = 5,
    objectives = { { 100, 80, 20 } },
    targets = { { 'Plainstrider', { 922 }, {}, 6 } } },
  [163] = quest { id = 163, name = 'Also nearby', level = 6, reqLevel = 5,
    objectives = { { 100, 60, 40 } },
    targets = { { 'Makrura', { 923 }, {}, 2 } } },
  [164] = quest { id = 164, name = 'Too far', level = 6, reqLevel = 5,
    objectives = { { 100, 10, 90 } },
    targets = { { 'Fairy dragon', { 924 }, {}, 3 } } },
  [166] = quest { id = 166, name = 'Crowd one', level = 6, reqLevel = 5,
    objectives = { { 100, 86, 16 } },
    targets = { { 'Stonetusk boar', { 926 }, {}, 3 } } },
}
player.level = 6
stepWindow = loadWindow(hunts,
  'a161.5 d161.5 t161.5 a162.5 d162.5 t162.5 a163.5 d163.5 t163.5'
    .. ' a164.5 d164.5 t164.5 a166.5 d166.5 t166.5')
win = windowFrame()
world = { x = 150, y = 150, instance = 7 }
takeQuest(161, 'First hunts', {
  { text = 'Red boar slain: 1/4', numFulfilled = 1, numRequired = 4, finished = false },
})
texts = textsOf(win)
assert(texts['Do First hunts'], 'the scenario must stand on the work step')
assert(texts['Also in this area'],
  'the nearby kill goals must sit under their own label')
assert(texts['Nearby hunts'] and texts['652 yards'],
  'a nearby hunt must list by name with its true yards')
assert(texts['Also nearby'] and texts['515 yards'] and texts['Crowd one'],
  'every hunt within 700 yards must list, in route order')
assert(texts['Plainstrider'] and texts['0 of 6'],
  'a hunt must list its own goals with their counts')
assert(not texts['Too far'] and not texts['Fairy dragon'],
  'a hunt beyond 700 yards must stay off the block')
local huntGoal = rowOfText(win, 'Plainstrider')
assert(tickOf(huntGoal) ~= nil and tickOf(huntGoal).checked == false,
  'a hunt goal carries its own empty tick box')
print('ok - the hunts block lists the nearby kill goals')

-- The reward tooltips: a hover over a reward name opens the game tooltip
-- on that item or spell; a hover over a goal line opens nothing.
player.level = 6
stepWindow = loadWindow(BASE, BASE_PATH, BASE_TABLES)
win = windowFrame()
hovered.items, hovered.spells = {}, 0
local tunic = rowOfText(win, 'Layered Tunic')
tunic.scripts.OnEnter(tunic)
assert(#hovered.items == 1 and hovered.items[1] == 'item:60',
  'a hover over a reward item must open the tooltip on that item')
tunic.scripts.OnLeave(tunic)
local spellRow = rowOfText(win, 'Spell 71')
spellRow.scripts.OnEnter(spellRow)
assert(hovered.spells == 1,
  'a hover over the reward spell must open the tooltip on that spell')
local accept = rowOfText(win, 'Accept Wolf pelts')
assert(accept.scripts.OnEnter == nil,
  'a goal line must offer no hover of its own')
assert(#hovered.items == 1,
  'nothing but the reward rows may open an item tooltip')
print('ok - the reward hovers open the game tooltip on the reward')

-- The skip action: a right-click on the step skips its quest, a
-- right-click on a listed next step skips that one, and the route replans
-- around both at once. No quest is ever accepted, handed in, or abandoned.
player.level = 6
stepWindow = loadWindow(BASE, BASE_PATH, BASE_TABLES)
win = windowFrame()
click(rowOfText(win, 'Pick up Wolf pelts'), 'RightButton')
assert(EfficientQuests.characterStore.isSkipped(201) == true,
  'a right-click on the step must skip its quest')
texts = textsOf(win)
assert(texts['Pick up Bone chips'] and texts['Step 1 / 4'],
  'the skipped quest must leave the route at once')
assert(not texts['Wolf pelts'], 'no step of the skipped quest may stay on screen')

stepWindow = loadWindow(BASE, BASE_PATH, BASE_TABLES)
win = windowFrame()
click(rowOfText(win, 'Pick up Bone chips'), 'RightButton')
assert(EfficientQuests.characterStore.isSkipped(202) == true,
  'a right-click on a listed next step must skip that quest')
assert(not EfficientQuests.characterStore.isSkipped(201),
  'the current step must be untouched by a skip beside it')
texts = textsOf(win)
assert(texts['Pick up Wolf pelts'] and texts['Step 1 / 4'],
  'the route must replan around the skipped next step')
assert(not texts['Do Bone chips'],
  'the steps of the skipped next quest must leave the next-steps list')
print('ok - a right-click skips the quest, on the step and on the list')

-- Follow mode: the Follow tick of the title bar turns the mode on and
-- off, the window shows the step of the picked quest while one is served,
-- a click on the step returns to the route, and the window shows the
-- route again while the mode is on but nothing is picked.
player.level = 6
stepWindow = loadWindow(BASE, BASE_PATH, BASE_TABLES)
win = windowFrame()
local followCheck = checkByLabel(win, 'Follow')
assert(followCheck ~= nil, 'the title bar must carry the Follow toggle')
assert(followCheck.checked == false, 'Follow mode starts off')
followCheck:SetChecked(true)
click(followCheck)
assert(EfficientQuests.followMode.GetFollowState().active == true,
  'a tick on the Follow toggle must turn Follow mode on')
texts = textsOf(win)
assert(texts['Pick up Wolf pelts'] and texts['Step 1 / 7'] and followCheck.checked == true,
  'with the mode on but nothing picked, the window must show the route')

EfficientQuests.followMode.SetFollowTarget(202)
texts = textsOf(win)
assert(texts['Pick up Bone chips'] and texts['Talk to Quartermaster Zigris'],
  'a pick in the log must put the step of the picked quest on screen')
assert(texts['Following'], 'the window must say that it follows')
assert(rowOfText(win, 'Back') == nil,
  'the paging buttons must leave the screen while following')
assert(not texts['Next steps'],
  'the next-steps list must leave the screen while following')
click(rowOfText(win, 'Pick up Bone chips'))
texts = textsOf(win)
assert(EfficientQuests.followMode.GetFollowState().active == false,
  'a click on the step must leave Follow mode')
assert(texts['Pick up Wolf pelts'] and texts['Step 1 / 7'],
  'the click must return the window to the route')
assert(followCheck.checked == false,
  'the Follow tick must show the mode off after the return')
print('ok - the Follow toggle, the followed step, and the click back to the route')

-- Hide and show: the X control takes the window off the screen, the show
-- entry point brings it back, and the hidden window answers no step.
local heard = {}
stepWindow.RegisterCallback({}, 'WindowChanged', function(name, payload)
  assert(name == 'WindowChanged',
    'a subscriber must hear the callback name first, then the payload')
  table.insert(heard, payload)
end)
click(rowOfText(win, 'X'))
assert(stepWindow.IsShown() == false, 'the X control must hide the window')
assert(stepWindow.GetCurrentStep() == nil,
  'a hidden window must answer no current step')
stepWindow.Show()
assert(stepWindow.IsShown() == true, 'Show must bring the window back')
assert(stepWindow.GetCurrentStep() ~= nil,
  'the shown window must answer its step again')
assert(heard[#heard - 1].shown == false and heard[#heard].shown == true,
  'the window must tell its listeners when it hides and shows')
print('ok - the X control hides, Show brings the window back')

-- The seams the later tickets build on: the current step with its point
-- and points for the TomTom bridge (#39), the place in the route, and the
-- WindowChanged payload that carries the same state.
local current = stepWindow.GetCurrentStep()
assert(current ~= nil and current.kind == 'pickup' and current.questID == 201,
  'the current step must be the step model\'s shape')
assert(current.point ~= nil and current.point[2] == 72 and current.point[3] == 30,
  'the current step must carry its point for the waypoint bridge')
assert(type(current.points) == 'table' and #current.points == 1,
  'the current step must carry every candidate place')
local at, total = stepWindow.GetCurrentPosition()
assert(at == 1 and total == 7,
  'the place in the route must answer the numbers behind the place line')
assert(heard[#heard].step ~= nil and heard[#heard].at == 1
    and heard[#heard].total == 7,
  'the payload must carry the same state as the queries')
local notifications = #heard
takeQuest(202, 'Bone chips')
assert(#heard > notifications and heard[#heard].shown == true
    and heard[#heard].total == 6,
  'a quest state change must refresh the window and notify its listeners')
print('ok - the current-step query, the place query, and the changed signal')

-- The saved place: the window sits where the account-wide saved table
-- says, a drag writes the new place back, and the lock stops the drag.
player.level = 6
stepWindow = loadWindow(BASE, BASE_PATH, BASE_TABLES,
  { window = { point = 'TOPLEFT', relativePoint = 'TOPLEFT', x = 200, y = -300 } })
win = windowFrame()
local atSaved = false
for _, point in ipairs(win.points) do
  if point[1] == 'TOPLEFT' and point[2] == UIParent and point[3] == 'TOPLEFT'
      and point[4] == 200 and point[5] == -300 then atSaved = true end
end
assert(atSaved, 'the window must sit at the place the saved table holds')

player.level = 6
stepWindow = loadWindow(BASE, BASE_PATH, BASE_TABLES)
win = windowFrame()
win.left, win.top = 100, 700
win.scripts.OnDragStart(win, 'LeftButton')
assert(win.dragging == true, 'a drag on an unlocked window must move it')
win.scripts.OnDragStop(win)
local saved = EfficientQuestsDB.window
assert(saved.point == 'TOPLEFT' and saved.relativePoint == 'TOPLEFT'
    and saved.x == 100 and saved.y == -68,
  'the drag must write the new place into the saved table')

player.level = 6
stepWindow = loadWindow(BASE, BASE_PATH, BASE_TABLES, { locked = true })
win = windowFrame()
win.left, win.top = 100, 700
win.scripts.OnDragStart(win, 'LeftButton')
assert(win.dragging ~= true, 'a locked window must not move')
win.scripts.OnDragStop(win)
assert(EfficientQuestsDB.window.x == 16 and EfficientQuestsDB.window.y == -120,
  'a locked window must keep its saved place')

-- Scale and opacity come from the same table and land on the window.
player.level = 6
stepWindow = loadWindow(BASE, BASE_PATH, BASE_TABLES, { scale = 0.75, opacity = 0.5 })
win = windowFrame()
assert(win.scale == 0.75, 'the saved scale must land on the window')
assert(win.alpha == 0.5, 'the saved opacity must land on the window')
print('ok - the saved place, the drag, the lock, the scale, and the opacity')

-- The menu opens from the title bar, anchored beside the window.
player.level = 6
stepWindow = loadWindow(BASE, BASE_PATH, BASE_TABLES)
win = windowFrame()
local openedWith = {}
local realOpen = EfficientQuests.Menu.Open
EfficientQuests.Menu.Open = function(anchor) table.insert(openedWith, anchor) end
click(rowOfText(win, 'Menu'))
EfficientQuests.Menu.Open = realOpen
assert(#openedWith == 1 and openedWith[1] == win,
  'the Menu button must open the menu beside the window')
print('ok - the menu opens from the title bar')

-- A FlareUI global in the world must not change the window: the same
-- texts render, and nothing of the addon reaches into FlareUI (the look
-- adapter, ticket #36, owns that side).
local flareTouches = 0
FlareUI = setmetatable({}, {
  __index = function() flareTouches = flareTouches + 1 return nil end,
  __newindex = function() flareTouches = flareTouches + 1 end,
})
player.level = 6
flareTouches = 0
stepWindow = loadWindow(BASE, BASE_PATH, BASE_TABLES)
win = windowFrame()
takeQuest(201, 'Wolf pelts')
finishQuest(201)
texts = textsOf(win)
assert(texts['Hand in Wolf pelts'] and texts['Step 2 / 6'],
  'the window must render the same texts with FlareUI present')
assert(flareTouches == 0,
  'the window must not read FlareUI; the look adapter owns that side')
FlareUI = nil
print('ok - a FlareUI presence changes nothing')

-- The real copied data through the shared seam: the whole addon loads the
-- way the game loads it, and the window comes up shown, on the first step
-- of the real route. The whole addon includes the TomTom bridge now, so
-- the sentinel gives way to a quiet fake here: the bridge may look at
-- TomTom and set its one waypoint, while the scenarios above -- which
-- load no bridge -- keep the promise that the window itself never calls
-- TomTom.
TomTom = {
  IsCrazyArrowEmpty = function() return true end,
  AddWaypoint = function(_, map, x, y, opts)
    return { map, x, y, title = opts and opts.title, from = opts and opts.from }
  end,
  RemoveWaypoint = function() end,
}
frames = {}
EfficientQuestsDB, EfficientQuestsCharacter = {}, {}
dofile('tests/addon.lua')()
player.level = 7
fire('PLAYER_LOGIN')
fire('PLAYER_ENTERING_WORLD')
stepWindow = EfficientQuests.StepWindow
assert(type(stepWindow) == 'table' and type(stepWindow.Show) == 'function'
    and type(stepWindow.Hide) == 'function' and type(stepWindow.IsShown) == 'function'
    and type(stepWindow.GetCurrentStep) == 'function'
    and type(stepWindow.GetCurrentPosition) == 'function'
    and type(stepWindow.RegisterCallback) == 'function',
  'the addon must offer the step window with its whole surface after load')
assert(stepWindow.IsShown() == true,
  'the window must come up shown on the real data')
win = windowFrame()
assert(win ~= nil and win.shown, 'the window frame must be on the screen')
texts = textsOf(win)
assert(texts['Efficient Quests'], 'the real window must carry its title bar')
local stepLine
for text in pairs(texts) do
  if text:match('^Step %d+ / %d+$') then stepLine = text end
end
assert(stepLine ~= nil, 'the real window must say its place in the route')
local realStep = stepWindow.GetCurrentStep()
assert(realStep ~= nil and type(realStep.headline) == 'string'
    and type(realStep.lines) == 'table',
  'the real window must stand on a step of the real route')
assert(texts[realStep.headline],
  'the headline of the current step must be on screen')
stepWindow.Hide()
assert(stepWindow.IsShown() == false, 'Hide must work on the real window')
stepWindow.Show()
assert(stepWindow.IsShown() == true, 'Show must work on the real window')
print('ok - the real data brings the window up on the first step')

-- The window only shows information: across every scenario, click, drag,
-- and hover of this suite, no quest mutation may have been offered.
assert(forbidden.accept == 0 and forbidden.abandon == 0 and forbidden.handin == 0,
  'the window must never accept, hand in, or abandon a quest')
print('ok - no quest action was ever offered')

print('all step window tests passed')
