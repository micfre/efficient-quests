-- The dungeon guide: the guide that takes over the window inside a
-- dungeon the data knows. The suite loads the code modules by hand per
-- scenario -- the way the step window suite does -- into a namespace
-- whose dungeon guides and quests are the scenario's own, and the frames
-- come from the widget fake the options, menu, and step window suites
-- use. The assertions read the guide the way a player does: the texts it
-- shows, the state of its tick boxes, and the step window it hands the
-- display to and takes it back from. Boss deaths arrive as game events;
-- quest completions as the quest state reader's answers.

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

-- The map fake of the step window suite: one synthetic map -- 100 on
-- continent 7, 1000 by 1000 yards -- so the embedded HereBeDragons loads.
local MAPS = { [100] = { instance = 7 } }
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
local player = { level = 16, raceName = 'Undead', raceID = 5,
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

-- The instance the player stands in: nil in the open world. While inside,
-- GetInstanceInfo answers the way the client does -- the name first, the
-- instance id eighth -- and the game's own answer for a wing (Scarlet
-- Monastery) is the shared id, never the wing.
local instance = nil
IsInInstance = function() return instance ~= nil end
GetInstanceInfo = function()
  if not instance then return nil end
  return instance.name, 'party', 1, 'Normal', 5, 0, false, instance.id
end


-- The instance the player stands in, entered and left the way the game
-- tells it: a loading screen, then PLAYER_ENTERING_WORLD.
local function enterInstance(name, id)
  instance = { name = name, id = id }
  fire('PLAYER_ENTERING_WORLD')
end
local function leaveInstance()
  instance = nil
  fire('PLAYER_ENTERING_WORLD')
end

-- The target of the player: dead or not, and the creature behind it. The
-- guide marks a stop done when the player targets its dead boss.
local target = nil
UnitIsDead = function(unit)
  if unit == 'target' and target then return target.dead end
  return false
end
UnitGUID = function(unit)
  if unit == 'target' and target then return target.guid end
  return nil
end
local function guidOf(npc)
  return 'Creature-0-2087-0-26-' .. npc .. '-0000AABB'
end

-- strsplit the way the client offers it: the pieces of the text between
-- the separators, at most as many as asked for, the last one the rest.
function strsplit(sep, text, limit)
  local pieces = {}
  local at = 1
  while true do
    local from, to = text:find(sep, at, true)
    if not from then pieces[#pieces + 1] = text:sub(at) break end
    pieces[#pieces + 1] = text:sub(at, from - 1)
    at = to + 1
    if limit and #pieces >= limit then pieces[#pieces + 1] = text:sub(at) break end
  end
  return unpack(pieces)
end

-- The clock the run reset reads, in seconds.
local clock = 1000
time = function() return clock end

-- TomTom and QuestieDB are later tickets; sentinels fail the suite the
-- moment anything reaches for them.
TomTom = setmetatable({}, {
  __index = function() error('the dungeon guide must not call TomTom') end,
})
LibQuestieDB = {
  Quest = { Get = function() error('the dungeon guide must not call QuestieDB') end },
  Npc = { Get = function() error('the dungeon guide must not call QuestieDB') end },
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

-- The instance the player stands in, entered and left the way the game
-- tells it: a loading screen, then PLAYER_ENTERING_WORLD. The helpers sit
-- after the event delivery they use.
local function enterInstance(name, id)
  instance = { name = name, id = id }
  fire('PLAYER_ENTERING_WORLD')
end
local function leaveInstance()
  instance = nil
  fire('PLAYER_ENTERING_WORLD')
end

-- The embedded libraries load once, before every scenario, the way the
-- game loads them before the addon.
assert(loadfile('dist/EfficientQuests/Libs/LibStub/LibStub.lua'))()
assert(loadfile('dist/EfficientQuests/Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua'))()
assert(loadfile('dist/EfficientQuests/Libs/HereBeDragons/HereBeDragons-2.0.lua'))()

-- Quest facts in the generated 38-field layout, at the positions the step
-- model reads (see the step window suite's builder for the full list).
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
-- order, into a namespace whose dungeon guides and quests are the
-- scenario's own. The world comes up the way the game brings it: login
-- first, then the player enters the world in the open world, and the step
-- window appears.
local function loadAddon(guides, quests)
  EfficientQuestsDB, EfficientQuestsCharacter = {}, {}
  frames = {}
  logEntries, objectives, completeFlag = {}, {}, {}
  onQuest, flaggedCompleted, completedIDs = {}, {}, {}
  -- The scenario starts in the open world, whatever the last one left.
  instance, target, world, clock = nil, nil, nil, 1000
  local namespace = {
    quests = quests,
    pathData = { version = 't', starts = { undead = 'a201.5 d201.5 t201.5' } },
    maps = { [100] = 'Northfield' },
    DungeonGuides = guides,
    npcNames = {}, npcWhere = {}, npcSpawns = {}, objSpawns = {},
    itemNames = {},
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
  loadFile('Look.lua')
  loadFile('Menu.lua')
  loadFile('StepWindow.lua')
  loadFile('DungeonGuide.lua')
  fire('PLAYER_LOGIN')
  fire('PLAYER_ENTERING_WORLD')
  local pending = timers
  timers = {}
  for _, fn in ipairs(pending) do fn() end
  assert(type(EfficientQuests.dungeonGuide) == 'table',
    'the addon must offer the dungeon guide after load')
  return EfficientQuests
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
-- with it, and QUEST_ACCEPTED told the reader.
local function takeQuest(id, title)
  table.insert(logEntries, { questID = id, title = title, level = player.level, isHeader = false })
  objectives[id] = { { text = 'Something done', numFulfilled = 0, numRequired = 1, finished = false } }
  fire('QUEST_ACCEPTED', id)
  runTimers()
end

-- The step window frame and the dungeon guide frame, by the names the
-- modules give them.
local function frameByName(name)
  for _, frame in ipairs(frames) do
    if frame.name == name then return frame end
  end
  return nil
end

local function windowFrame()
  return frameByName('EfficientQuestsStepWindow')
end

local function guideFrame()
  return frameByName('EfficientQuestsDungeonGuide')
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

-- The scenario's own guides: a five-man under the city with one stop of
-- every kind, two wings that share one instance id, and a dungeon the
-- guide finds by name only.
local ROUTE_QUESTS = {
  [201] = quest { id = 201, name = 'Wolf pelts', level = 6, reqLevel = 5,
    start = { 100, 72, 30 }, finish = { 100, 30, 70 },
    giver = 'Deathstalker Rane', ender = 'Deathstalker Rane',
    giverNpc = 900, enderNpc = 900,
    objectives = { { 100, 40, 50 } },
    targets = { { 'Winter Wolf', { 910 }, {}, 7 } } },
}

local SYN_QUESTS = {
  [201] = ROUTE_QUESTS[201],
  [5722] = { 'The Satchel of Supplies' },
  [5724] = { 'Return the Satchel' },
  [5761] = { 'Slaying the Beast' },
}

local SYN_GUIDES = {
  [389] = {
    key = 'syn', levels = '13-18',
    intro = { 'Under the city, five players, levels 13-18.' },
    stops = {
      { npc = 11517, kind = 'boss', name = 'Oggleflint', level = 16, title = 'Trogg chieftain',
        approach = { 'Clear the trogg packs in the first caves.',
            'He waits in the round cave on the east side.' },
        mechanics = { 'Cleave hits everyone in front of him: only the tank faces him.' } },
      { npc = 11834, kind = 'spot', name = "Maur Grimtotem's corpse", optional = true,
        quest = 5722, follow = 5724,
        approach = { 'Right beside the first cave.' } },
      { npc = 11520, kind = 'boss', name = 'Taragaman the Hungerer', level = 16, title = 'Demon',
        quests = { 5761 },
        approach = { 'In the big lava cavern in the middle.' },
        mechanics = { 'Fire Nova burns everyone near him every few seconds: ranged stay back.',
            'Uppercut throws his target away: tank with your back to a wall.' } },
      { npc = 11518, kind = 'event', name = 'Searing Blade ritual', title = 'Start the ritual',
        doneBy = 11520,
        approach = { 'Talk to the cultist once the demon is dead.' } },
    },
  },
  [1891] = { key = 'winga', levels = '30-38', wing = 189,
    stops = { { npc = 3983, kind = 'boss', name = 'Graveyard Boss',
      approach = { 'In the graveyard.' } } } },
  [1892] = { key = 'wingb', levels = '33-41', wing = 189,
    stops = { { npc = 3984, kind = 'boss', name = 'Library Boss',
      approach = { 'In the library.' } } } },
  [16544] = { key = 'dal', levels = '30-33', names = { 'City of Dalaran', 'Dalaran' },
    stops = { { npc = 247126, kind = 'boss', name = 'Atrexis the Grave Knight',
      approach = { 'On the Underbelly floor.' },
      mechanics = { 'Skeletons keep rising: kill them as they come.' } } } },
}

-- Entering a dungeon the data knows starts the guide by itself: the
-- dungeon window comes up in place of the step window, the addon answers
-- the active guide, and one line in the chat frame says the guide is on.
-- An unknown dungeon starts nothing, and the step window stays.
local EQ = loadAddon(SYN_GUIDES, SYN_QUESTS)
local stepWindow = EQ.StepWindow
local guide = EQ.dungeonGuide
assert(stepWindow.IsShown() == true,
  'the step window must be on the screen while the player is outside')
enterInstance('Ragefire Chasm', 389)
runTimers()
assert(guide.IsActive() == true,
  'the guide must start on entry to a dungeon the data knows')
assert(stepWindow.IsShown() == false,
  'the dungeon guide must take over the display from the step window')
local win = guideFrame()
assert(win ~= nil and win.shown == true,
  'the dungeon window must be on the screen')
local active = guide.GetActiveGuide()
assert(active ~= nil and active.key == 389 and active.guide == SYN_GUIDES[389],
  'the active guide must answer the dungeon and its data')
assert(#messages == 1 and messages[1]:find('dungeon guide on', 1, true)
    and messages[1]:find('Ragefire Chasm', 1, true),
  'one chat line must say the guide is on, naming the dungeon')

leaveInstance()
runTimers()
assert(guide.IsActive() == false, 'leaving the dungeon must stop the guide')
assert(guideFrame().shown == false, 'the dungeon window must leave the screen')
assert(stepWindow.IsShown() == true,
  'the step window must come back with the leveling route after the dungeon')
print('ok - the guide starts on entry and stops on exit')

-- An unknown dungeon starts nothing: no window, no active guide, no
-- message, and the step window stays on the screen.
messages = {}
EQ = loadAddon(SYN_GUIDES, SYN_QUESTS)
stepWindow = EQ.StepWindow
guide = EQ.dungeonGuide
enterInstance('Somewhere Unknown', 55555)
runTimers()
assert(guide.IsActive() == false,
  'a dungeon the data does not know must not start the guide')
assert(guideFrame() == nil, 'no dungeon window may exist for an unknown dungeon')
assert(stepWindow.IsShown() == true,
  'the step window must stay on the screen inside an unknown dungeon')
assert(#messages == 0, 'an unknown dungeon must not print anything')
print('ok - an unknown dungeon starts nothing')

-- The stop list: the stops list in order, each with the verb of its kind
-- and its name, optional stops marked, and every stop row carrying an
-- empty tick box. The current stop -- the first not done -- expands with
-- its title, its approach, and its boss mechanics.
EQ = loadAddon(SYN_GUIDES, SYN_QUESTS)
guide = EQ.dungeonGuide
stepWindow = EQ.StepWindow
enterInstance('Ragefire Chasm', 389)
runTimers()
win = guideFrame()

-- The rows of the body block, in the order the player reads them.
local body = nil
for _, child in ipairs(win.children) do
  if child.name == 'EfficientQuestsDungeonGuideStops' then body = child end
end
assert(body ~= nil, 'the window must hold its stop rows in one body block')
-- The rows of the body block, in the order the player reads them. Rows
-- come out of a pool and go back into it, so the anchor offset -- not the
-- creation order -- is the truth.
local function rowsTopDown(bodyBlock)
  local rows = {}
  for _, row in ipairs(bodyBlock.children) do
    if row.shown and row.kind == 'Button' then table.insert(rows, row) end
  end
  table.sort(rows, function(a, b)
    return a.points[1][5] > b.points[1][5]
  end)
  return rows
end

local function rowTexts()
  local lines = {}
  for _, row in ipairs(rowsTopDown(body)) do
    table.insert(lines, row.text.text)
  end
  return lines
end

-- Only the stop rows: the ones that carry a tick box.
local function stopTexts()
  local lines = {}
  for _, row in ipairs(rowsTopDown(body)) do
    if tickOf(row) and tickOf(row).shown then
      table.insert(lines, row.text.text)
    end
  end
  return lines
end

texts = textsOf(win)
assert(texts['Ragefire Chasm'], 'the window must name the dungeon')
assert(texts['Levels 13-18'], 'the window must say the level range of the guide')
local stops = stopTexts()
assert(#stops == 4, 'every stop of the guide must list')
assert(stops[1] == 'Kill Oggleflint',
  'the first stop must say the verb of its kind and its name')
assert(stops[2] == "Find Maur Grimtotem's corpse (optional)",
  'the second stop must be the quest spot, marked optional')
assert(stops[3] == 'Kill Taragaman the Hungerer', 'the third stop must be the second boss')
assert(stops[4] == 'Talk to Searing Blade ritual',
  'the fourth stop must be the event, with the verb of its kind')
local oggle = rowOfText(win, 'Kill Oggleflint')
assert(tickOf(oggle) ~= nil and tickOf(oggle).shown and tickOf(oggle).checked == false,
  'every stop row must carry an empty tick box while the stop is open')

-- The current stop expands with its approach and its mechanics; the stops
-- around it list bare. The approach lines come first, the mechanics under
-- them.
EQ = loadAddon(SYN_GUIDES, SYN_QUESTS)
guide = EQ.dungeonGuide
stepWindow = EQ.StepWindow
enterInstance('Ragefire Chasm', 389)
runTimers()
win = guideFrame()
body = nil
for _, child in ipairs(win.children) do
  if child.name == 'EfficientQuestsDungeonGuideStops' then body = child end
end
lines = rowTexts()
assert(lines[2] == 'Trogg chieftain · Level 16',
  'the current stop must say its title and level under its name')
assert(lines[3] == 'Clear the trogg packs in the first caves.'
    and lines[4] == 'He waits in the round cave on the east side.',
  'the current stop must say its approach, line by line')
assert(lines[5] == 'Cleave hits everyone in front of him: only the tank faces him.',
  'the boss mechanics must list under the approach')
assert(lines[6] == "Find Maur Grimtotem's corpse (optional)",
  'the next stop must list bare while another one is current')
local mechRow = rowOfText(win, 'Cleave hits everyone in front of him: only the tank faces him.')
assert(mechRow ~= nil and tickOf(mechRow) ~= nil and not tickOf(mechRow).shown,
  'an approach or mechanics line carries no tick box')
assert(mechRow.text.textColor[1] == 1 and mechRow.text.textColor[2] == 0.7
    and mechRow.text.textColor[3] == 0.4,
  'the mechanics lines must carry the warning color')
print('ok - the stops list in order with their kind, and the current stop expands')

-- Completion by boss death: ENCOUNTER_END with success marks the stop of
-- that boss done -- the tick fills and the current stop moves on -- and a
-- failed encounter marks nothing. BOSS_KILL by name works the same, a
-- stop whose doneBy names the boss completes with it, and so does the
-- player targeting the dead boss.
EQ = loadAddon(SYN_GUIDES, SYN_QUESTS)
guide = EQ.dungeonGuide
stepWindow = EQ.StepWindow
enterInstance('Ragefire Chasm', 389)
runTimers()
win = guideFrame()

fire('ENCOUNTER_END', 0, 'Taragaman the Hungerer', 0, 0, 0)
assert(tickOf(rowOfText(win, 'Kill Taragaman the Hungerer')).checked ~= true,
  'a failed encounter must not mark its boss done')
texts = textsOf(win)
assert(texts['Clear the trogg packs in the first caves.'],
  'the current stop must stay on the first boss')

fire('ENCOUNTER_END', 0, 'Oggleflint', 0, 0, 1)
assert(tickOf(rowOfText(win, 'Kill Oggleflint')).checked == true,
  'a successful encounter must mark its boss done')
texts = textsOf(win)
assert(texts['Right beside the first cave.'],
  'the current stop must move to the quest spot after the boss dies')
assert(not texts['Clear the trogg packs in the first caves.'],
  'the approach of a done stop must leave the screen')

fire('BOSS_KILL', 0, 'Taragaman the Hungerer')
assert(tickOf(rowOfText(win, 'Kill Taragaman the Hungerer')).checked == true,
  'BOSS_KILL by name must mark its boss done')
assert(tickOf(rowOfText(win, 'Talk to Searing Blade ritual')).checked == true,
  'a stop whose doneBy names the boss must complete with the boss')

target = { dead = true, guid = guidOf(11517) }
fire('PLAYER_TARGET_CHANGED')
assert(tickOf(rowOfText(win, 'Kill Oggleflint')).checked == true,
  'targeting a dead boss must keep its stop done')
print('ok - boss deaths mark their stops done through the game events')

-- Every required stop done: the window says the run is clear, and the
-- optional stops still open are named, so "clear" hides nothing.
texts = textsOf(win)
assert(texts['Every stop is done. Leave the dungeon to go back to your route.'],
  'the window must say when every stop is done')
assert(texts['Not done (optional): Maur Grimtotem\'s corpse.'],
  'an optional stop still open must be named under the clear line')
print('ok - a finished run says so and names its optional leftovers')

-- Completion by quest: a stop whose quest is finished for good is done
-- -- flagged complete by the client on entry, or handed in mid-run --,
-- and so is one whose follow-up sits in the log.
EQ = loadAddon(SYN_GUIDES, SYN_QUESTS)
guide = EQ.dungeonGuide
stepWindow = EQ.StepWindow
flaggedCompleted[5722] = true
enterInstance('Ragefire Chasm', 389)
runTimers()
win = guideFrame()
assert(tickOf(rowOfText(win, "Find Maur Grimtotem's corpse (optional)")).checked == true,
  'a stop whose quest was finished for good must be done on entry')
texts = textsOf(win)
assert(not texts['Right beside the first cave.'],
  'a done optional stop must not expand, wherever it sits')

EQ = loadAddon(SYN_GUIDES, SYN_QUESTS)
guide = EQ.dungeonGuide
stepWindow = EQ.StepWindow
enterInstance('Ragefire Chasm', 389)
runTimers()
win = guideFrame()
takeQuest(5722, 'The Satchel of Supplies')
table.remove(logEntries)
fire('QUEST_TURNED_IN', 5722)
runTimers()
assert(tickOf(rowOfText(win, "Find Maur Grimtotem's corpse (optional)")).checked == true,
  'a quest handed in inside the dungeon must mark its stop done')

EQ = loadAddon(SYN_GUIDES, SYN_QUESTS)
guide = EQ.dungeonGuide
stepWindow = EQ.StepWindow
enterInstance('Ragefire Chasm', 389)
runTimers()
win = guideFrame()
takeQuest(5724, 'Return the Satchel')
assert(tickOf(rowOfText(win, "Find Maur Grimtotem's corpse (optional)")).checked == true,
  'a follow-up quest in the log must mark the stop done')
print('ok - quest completions mark their stops done')

-- The hand mark: a right-click on a stop row marks the stop done, a
-- second right-click clears the mark, and the public action answers the
-- same road. Every move tells the GuideChanged listeners.
EQ = loadAddon(SYN_GUIDES, SYN_QUESTS)
guide = EQ.dungeonGuide
stepWindow = EQ.StepWindow
enterInstance('Ragefire Chasm', 389)
runTimers()
win = guideFrame()
local heard = {}
local listener = {}
guide.RegisterCallback(listener, 'GuideChanged', function(name, payload)
  assert(name == 'GuideChanged',
    'a subscriber must hear the callback name first, then the payload')
  table.insert(heard, payload)
end)
local spot = rowOfText(win, "Find Maur Grimtotem's corpse (optional)")
click(spot, 'RightButton')
assert(tickOf(rowOfText(win, "Find Maur Grimtotem's corpse (optional)")).checked == true,
  'a right-click must mark a stop done by hand')
click(rowOfText(win, "Find Maur Grimtotem's corpse (optional)"), 'RightButton')
assert(tickOf(rowOfText(win, "Find Maur Grimtotem's corpse (optional)")).checked ~= true,
  'a second right-click must clear the hand mark')
guide.MarkStop(11517, 'done')
assert(tickOf(rowOfText(win, 'Kill Oggleflint')).checked == true,
  'the public mark action must mark a stop done')
assert(#heard == 3 and heard[3].active == true,
  'every hand mark must tell the GuideChanged listeners')
guide.MarkStop(11517, 'undo')
assert(tickOf(rowOfText(win, 'Kill Oggleflint')).checked ~= true,
  'the public mark action must clear a mark again')
print('ok - a right-click marks a stop done and undone by hand')

-- The display handoff gives back exactly what it took: the X of the
-- dungeon window hides its face without stopping the guide, and on exit
-- the guide puts the route window back. The step window also shows
-- itself on every world entry by its own rule, so the suite counts the
-- calls: the step window's own show, and the guide's give-back beside it.
EQ = loadAddon(SYN_GUIDES, SYN_QUESTS)
guide = EQ.dungeonGuide
stepWindow = EQ.StepWindow
enterInstance('Ragefire Chasm', 389)
runTimers()
win = guideFrame()
assert(guide.IsActive() == true and win.shown == true,
  'the guide must run and show its window over the route window')
click(rowOfText(win, 'X'))
assert(win.shown == false and guide.IsActive() == true,
  'the X must hide the dungeon window without stopping the guide')
fire('ENCOUNTER_END', 0, 'Oggleflint', 0, 0, 1)
assert(guide.IsActive() == true, 'a hidden window must not stop the guide')
local shows = 0
local realShow = stepWindow.Show
stepWindow.Show = function() shows = shows + 1 realShow() end
leaveInstance()
runTimers()
stepWindow.Show = realShow
assert(guide.IsActive() == false, 'leaving must stop the guide')
assert(shows == 2,
  'the step window\'s own world-entry show and the guide\'s give-back must both come')
assert(stepWindow.IsShown() == true,
  'the route window must be back on the screen after the dungeon')
print('ok - the display handoff restores exactly what it hid')

-- The quests the dungeon helps with: under their own label, named from
-- the quest data, in the order the stops meet them.
EQ = loadAddon(SYN_GUIDES, SYN_QUESTS)
guide = EQ.dungeonGuide
stepWindow = EQ.StepWindow
enterInstance('Ragefire Chasm', 389)
runTimers()
win = guideFrame()
texts = textsOf(win)
assert(texts['Quests here'], 'the window must label its quest list')
assert(texts['The Satchel of Supplies'] and texts['Return the Satchel']
    and texts['Slaying the Beast'],
  'every quest the dungeon helps with must list by name')
assert(not texts['Wolf pelts'],
  'a quest no stop of the dungeon asks for must stay off the list')
print('ok - the quests the dungeon helps with list under their own label')

-- Dungeons whose wings share one instance id: the game never says which
-- wing the player is in, so the guide for the player's level is the pick.
player.level = 34
EQ = loadAddon(SYN_GUIDES, SYN_QUESTS)
guide = EQ.dungeonGuide
enterInstance('Scarlet Monastery', 189)
runTimers()
assert(guide.GetActiveGuide().key == 1891,
  'at level 34 the Graveyard wing is the pick')
assert(textsOf(guideFrame())['Kill Graveyard Boss'],
  'the picked wing must show its own stops')
player.level = 36
EQ = loadAddon(SYN_GUIDES, SYN_QUESTS)
guide = EQ.dungeonGuide
enterInstance('Scarlet Monastery', 189)
runTimers()
assert(guide.GetActiveGuide().key == 1892,
  'at level 36 the Library wing is the pick')
assert(textsOf(guideFrame())['Kill Library Boss'],
  'the picked wing must show its own stops')
print('ok - a shared instance id resolves to the wing for the level')

-- A dungeon the generated table keeps under its own id -- WoW Forever's
-- own, whose instance id is not known -- is found by the name the game
-- gives the instance.
EQ = loadAddon(SYN_GUIDES, SYN_QUESTS)
guide = EQ.dungeonGuide
enterInstance('City of Dalaran', 99000)
runTimers()
assert(guide.GetActiveGuide() ~= nil and guide.GetActiveGuide().key == 16544,
  'an unknown instance id must resolve by the name the game gives')
assert(textsOf(guideFrame())['Kill Atrexis the Grave Knight'],
  'the name-found guide must show its stops')
assert(textsOf(guideFrame())['City of Dalaran'],
  'the window must name the dungeon from the guide\'s own names list')
leaveInstance()
runTimers()
assert(guide.IsActive() == false, 'leaving a name-found dungeon stops the guide')
print('ok - a dungeon the data knows only by name resolves and runs')

-- The real copied data through the shared seam: the whole addon loads the
-- way the game loads it, and the guide runs the real Ragefire Chasm. The
-- whole addon includes the TomTom bridge, so the sentinel gives way to a
-- quiet TomTom that answers the bridge's surface.
frames = {}
EfficientQuestsDB, EfficientQuestsCharacter = {}, {}
TomTom = {
  IsCrazyArrowEmpty = function() return true end,
  AddWaypoint = function() return {} end,
  RemoveWaypoint = function() end,
}
dofile('tests/addon.lua')()
fire('PLAYER_LOGIN')
player.level = 16
enterInstance('Ragefire Chasm', 389)
runTimers()
local realGuide = EfficientQuests.dungeonGuide
assert(realGuide.IsActive() == true,
  'the real data must start the guide in the real Ragefire Chasm')
assert(realGuide.GetActiveGuide().key == 389,
  'the real Ragefire Chasm must resolve by its own instance id')
win = guideFrame()
assert(win ~= nil and win.shown == true, 'the real guide window must be up')
texts = textsOf(win)
assert(texts['Kill Oggleflint'] and texts['Kill Taragaman the Hungerer']
    and texts['Kill Bazzalan'],
  'the real stops must list with the verb of their kind')
assert(texts['Quests here'],
  'the real guide must list the quests its stops help with')
fire('ENCOUNTER_END', 0, 'Taragaman the Hungerer', 0, 0, 1)
assert(tickOf(rowOfText(win, 'Kill Taragaman the Hungerer')).checked == true,
  'a real boss death must mark the real stop done')
leaveInstance()
runTimers()
assert(realGuide.IsActive() == false, 'leaving the real dungeon must stop the guide')
print('ok - the real data runs the guide end to end')

print('all dungeon guide tests passed')
