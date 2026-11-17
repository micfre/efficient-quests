-- The look adapter: the module that copies the backdrop, the colors, and
-- the fonts of the FlareUI tracker onto the step window when FlareUI is
-- loaded, docks the window below the tracker, and leaves the flat look
-- alone otherwise. The suite loads the code modules by hand per scenario
-- -- the way the step window suite does -- with the widget fake grown by
-- the frame methods the adapter reads: named frames register in _G the
-- way the client registers them, frames answer their object type and
-- their children, scroll frames carry a scroll child, and font strings
-- carry a font. The FlareUI fake is the tracker frame the notes describe:
-- a backdrop-styled holder with a header title and a scroll of lines. The
-- assertions read the window the way a player sees it: its backdrop, its
-- colors, its fonts, its place on the screen, its width, and its drag.

local messages = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) table.insert(messages, message) end }
SlashCmdList = {}

-- Widget fake: every frame the addon builds records its size, its points,
-- its scripts, its text, and its children, the way the options, menu, and
-- step window fakes do. Named frames also register themselves in _G,
-- because the adapter finds the step window and the tracker by their
-- global names, the way the client offers them.
local Widget = {}
Widget.__index = Widget

local frames = {}

local function widget(kind, name, parent)
  local self = setmetatable({
    kind = kind or 'Frame', name = name, parent = parent,
    children = {}, scripts = {}, points = {}, shown = true,
  }, Widget)
  -- In the client only font strings carry a font; frames never answer
  -- GetFont, so the adapter can tell them apart by asking.
  if kind == 'FontString' then
    function self:GetFont() return self.fontPath, self.fontSize, self.fontFlags end
    function self:SetFont(path, size, flags)
      self.fontPath, self.fontSize, self.fontFlags = path, size, flags
    end
  end
  if parent and parent.children then table.insert(parent.children, self) end
  if name then _G[name] = self end
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

-- The map fake of the step window suite: two synthetic maps so the
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

-- The character sheet: an undead mage of the Horde, at the level the
-- scenarios need.
local player = { level = 6, raceName = 'Undead', raceID = 5,
  className = 'Mage', classID = 8, faction = 'Horde' }
UnitLevel = function() return player.level end
UnitRace = function() return player.raceName, player.raceName, player.raceID end
UnitClass = function() return player.className, player.className, player.classID end
UnitFactionGroup = function() return player.faction end

-- The quest log: an ordered list of entries, the objectives per quest,
-- and the completion flags the client would answer.
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

-- The world position of the player, in yards: nil until a scenario
-- places the player somewhere.
local world = nil
UnitPosition = function()
  if not world then return nil end
  return world.y, world.x, 50, world.instance
end
local inInstance = false
IsInInstance = function() return inInstance end

-- The tooltip fake, for the reward hovers the window builds.
local hovered = { items = {}, spells = 0 }
GameTooltip = {
  SetOwner = function() end,
  SetItemRef = function(_, link) table.insert(hovered.items, link) end,
  SetSpellByID = function(_, id) hovered.spells = hovered.spells + 1 end,
  Show = function() end,
  Hide = function() end,
}

-- TomTom and QuestieDB are other tickets; sentinels fail the suite the
-- moment anything reaches for them.
TomTom = setmetatable({}, {
  __index = function() error('the look adapter must not call TomTom') end,
})
LibQuestieDB = {
  Quest = { Get = function() error('the look adapter must not call QuestieDB') end },
  Npc = { Get = function() error('the look adapter must not call QuestieDB') end },
}

-- Setters the addon uses; each one records what the player would see, and
-- the getters answer with the same values.
function Widget:SetSize(width, height) self.width, self.height = width, height end
function Widget:SetWidth(width) self.width = width end
function Widget:SetHeight(height) self.height = height end
function Widget:GetWidth() return self.width end
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
function Widget:GetBackdropColor() return unpack(self.backdropColor or {}) end
function Widget:SetBackdropBorderColor(r, g, b, a) self.backdropBorderColor = { r, g, b, a } end
function Widget:GetBackdropBorderColor() return unpack(self.backdropBorderColor or {}) end
function Widget:SetTexture(path) self.texture = path end
function Widget:SetAtlas(atlas) self.atlas = atlas end
function Widget:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
function Widget:SetText(text) self.text = text end
function Widget:GetText() return self.text end
function Widget:SetJustifyH(justify) self.justifyH = justify end
function Widget:SetJustifyV(justify) self.justifyV = justify end
function Widget:SetFontObject(font) self.fontObject = font end
function Widget:SetTextColor(r, g, b, a) self.textColor = { r, g, b, a } end
function Widget:GetTextColor() return unpack(self.textColor or {}) end
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
function Widget:GetObjectType() return self.kind end
-- The client's GetChildren answers every child as its own return value,
-- so the addon can write { frame:GetChildren() } for the list.
function Widget:GetChildren() return unpack(self.children) end
function Widget:SetScrollChild(child) self.scrollChild = child end
function Widget:GetScrollChild() return self.scrollChild end

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
-- model reads.
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
-- order, with the look adapter last, after the step window it restyles.
-- The saved tables start fresh; a scenario may stand an optional addon
-- into the world before the addon loads -- the way OptionalDeps loads
-- FlareUI first; the world comes up the way the game brings it, and the
-- window appears when the player enters the world.
local function loadLook(quests, pathLine, savedDB, beforeLoad)
  EfficientQuestsDB = savedDB or {}
  EfficientQuestsCharacter = {}
  frames = {}
  _G.EfficientQuestsStepWindow = nil
  _G.FlareUI_ObjectiveTracker = nil
  logEntries, objectives, completeFlag = {}, {}, {}
  onQuest, flaggedCompleted, completedIDs = {}, {}, {}
  if beforeLoad then beforeLoad() end
  local namespace = {
    quests = quests,
    pathData = { version = 't', starts = { undead = pathLine } },
    maps = { [100] = 'Northfield', [200] = 'Southmoor' },
    DungeonGuides = { [1] = { stops = {} } },
  }
  local function loadFile(path)
    assert(loadfile('dist/EfficientQuests/' .. path))('EfficientQuests', namespace)
  end
  loadFile('Core.lua')
  loadFile('QuestState.lua')
  loadFile('CharacterStore.lua')
  loadFile('DataStore.lua')
  loadFile('Geo.lua')
  loadFile('OptionalAddons.lua')
  loadFile('RoutePlanner.lua')
  loadFile('StepModel.lua')
  loadFile('FollowMode.lua')
  loadFile('Look.lua')
  loadFile('Menu.lua')
  loadFile('StepWindow.lua')
  loadFile('LookAdapter.lua')
  fire('PLAYER_LOGIN')
  fire('PLAYER_ENTERING_WORLD')
  return EfficientQuests.lookAdapter
end

-- The delayed work of a frame runs through the fake timer, so the suite
-- decides when the next frame comes.
local function runTimers()
  while #timers > 0 do
    local pending = timers
    timers = {}
    for _, fn in ipairs(pending) do fn() end
  end
end

-- A quest log change the way the client delivers it: the log knows the
-- quest and QUEST_ACCEPTED told the reader. A frame later the window has
-- refreshed -- and the look adapter with it.
local function touchLog()
  table.insert(logEntries, { questID = 201, title = 'Wolf pelts',
    level = player.level, isHeader = false })
  objectives[201] = { { text = 'Winter Wolf slain: 3/7',
    numFulfilled = 3, numRequired = 7, finished = false } }
  fire('QUEST_ACCEPTED', 201)
  runTimers()
end

-- The step window frame, by its global name.
local function windowFrame() return _G.EfficientQuestsStepWindow end

-- The font string that shows this text, wherever in the window it sits.
local function fontOfText(root, text)
  local found
  local function walk(node)
    for _, child in ipairs(node.children or {}) do
      if child.shown and child.kind == 'FontString' and child.text == text then
        found = child
      end
      walk(child)
    end
  end
  walk(root)
  return found
end

-- The FlareUI tracker fake, the frame the exploration notes describe: a
-- backdrop-styled holder of the tracker's own width, a header with a
-- title font, and a scroll frame whose content holds the line fonts.
local HEADER_FONT = { 'Fonts\\FRIZQT__.TTF', 15, 'OUTLINE' }
local LINE_FONT = { 'Fonts\\ARIALN.TTF', 13, '' }
local TRACKER_BACKDROP = {
  bgFile = 'Interface\\DialogFrame\\UI-DialogBox-Background-Dark',
  edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
  tile = false, tileSize = 0, edgeSize = 16,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
local function flareTracker()
  local tracker = CreateFrame('Frame', 'FlareUI_ObjectiveTracker', UIParent)
  tracker:SetWidth(250)
  tracker:SetHeight(200)
  tracker:SetBackdrop(TRACKER_BACKDROP)
  tracker:SetBackdropColor(1, 1, 1, 0.6)
  tracker:SetBackdropBorderColor(0.61, 0.49, 0.27, 1)
  local header = CreateFrame('Frame', nil, tracker)
  local title = header:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
  title:SetFont(HEADER_FONT[1], HEADER_FONT[2], HEADER_FONT[3])
  title:SetTextColor(1, 0.82, 0, 1)
  header.title = title
  local scroll = CreateFrame('ScrollFrame', nil, tracker)
  local content = CreateFrame('Frame', nil, scroll)
  scroll:SetScrollChild(content)
  local line = CreateFrame('Frame', nil, content)
  local text = line:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  text:SetFont(LINE_FONT[1], LINE_FONT[2], LINE_FONT[3])
  text:SetTextColor(0.92, 0.92, 0.92, 1)
  line.text = text
  return tracker
end

-- Whether the window sits docked under the tracker: its top left is
-- anchored to the tracker's bottom left, with a gap of air between.
local function dockedTo(win, tracker, gap)
  for _, point in ipairs(win.points) do
    if point[1] == 'TOPLEFT' and point[2] == tracker
        and point[3] == 'BOTTOMLEFT' and point[4] == 0 and point[5] == -gap then
      return true
    end
  end
  return false
end

-- One world for the suite: one quest of the Path, so the window stands
-- on a step with lines to restyle.
local BASE = {
  [201] = quest { id = 201, name = 'Wolf pelts', level = 6, reqLevel = 5,
    start = { 100, 72, 30 }, finish = { 100, 30, 70 },
    giver = 'Deathstalker Rane', ender = 'Deathstalker Rane',
    giverNpc = 900, enderNpc = 900,
    objectives = { { 100, 40, 50 } },
    targets = { { 'Winter Wolf', { 910 }, {}, 7 } } },
}
local BASE_PATH = 'a201.5 d201.5 t201.5'

-- Without FlareUI the flat look stays: the window keeps its own dark
-- plate and thin bronze edge, keeps its own width, and drags by the lock
-- option of the saved data -- the drag moves an unlocked window and
-- never a locked one.
player.level = 6
local look = loadLook(BASE, BASE_PATH)
assert(type(look) == 'table',
  'the addon must offer the look adapter after the player enters the world')
local win = windowFrame()
assert(win ~= nil and win.shown, 'the window must be on the screen')
assert(win.backdrop and win.backdrop.bgFile == 'Interface\\Buttons\\WHITE8X8'
    and win.backdrop.edgeSize == 1,
  'without FlareUI the window must keep its flat plate and thin edge')
assert(win.width == 280, 'the window must keep its own width')

win.left, win.top = 100, 700
win.scripts.OnDragStart(win, 'LeftButton')
assert(win.dragging == true, 'an unlocked flat window must drag')
win.scripts.OnDragStop(win)
assert(EfficientQuestsDB.window.x == 100 and EfficientQuestsDB.window.y == -68,
  'the drag must write the place into the saved table')

player.level = 6
loadLook(BASE, BASE_PATH, { locked = true })
win = windowFrame()
win.left, win.top = 100, 700
win.scripts.OnDragStart(win, 'LeftButton')
assert(win.dragging ~= true, 'a locked flat window must not move')
win.scripts.OnDragStop(win)
assert(EfficientQuestsDB.window.x == 16 and EfficientQuestsDB.window.y == -120,
  'a locked flat window must keep its saved place')
print('ok - without FlareUI the flat look stays and the window drags by the lock')

-- With FlareUI loaded, the window wears the tracker's look: the backdrop
-- with its colors comes off the live tracker frame, the fonts of the
-- header and the lines land on the window's texts, and the window docks
-- below the tracker. The width is the window's own, never the tracker's.
-- While docked, the tracker owns the place: drags stay off, the way a
-- locked flat window keeps its place, and the drag never writes a place
-- into the saved table.
player.level = 6
local tracker
loadLook(BASE, BASE_PATH, nil, function() tracker = flareTracker() end)
win = windowFrame()
assert(win.shown, 'the window must come up with FlareUI present')
assert(win.backdrop and win.backdrop.bgFile == TRACKER_BACKDROP.bgFile
    and win.backdrop.edgeFile == TRACKER_BACKDROP.edgeFile
    and win.backdrop.edgeSize == TRACKER_BACKDROP.edgeSize
    and win.backdrop.insets.left == 3,
  'the window must wear the backdrop of the tracker')
assert(win.backdropColor and win.backdropColor[1] == 1 and win.backdropColor[2] == 1
    and win.backdropColor[3] == 1 and win.backdropColor[4] == 0.6,
  'the window must copy the tracker\'s backdrop color')
assert(win.backdropBorderColor and win.backdropBorderColor[1] == 0.61
    and win.backdropBorderColor[2] == 0.49 and win.backdropBorderColor[3] == 0.27,
  'the window must copy the tracker\'s border color')
local titleFont = fontOfText(win, 'Efficient Quests')
assert(titleFont and titleFont.fontPath == HEADER_FONT[1]
    and titleFont.fontSize == HEADER_FONT[2]
    and titleFont.fontFlags == HEADER_FONT[3],
  'the window\'s title must carry the tracker\'s header font')
local goalFont = fontOfText(win, 'Talk to Deathstalker Rane')
assert(goalFont and goalFont.fontPath == LINE_FONT[1]
    and goalFont.fontSize == LINE_FONT[2],
  'the window\'s lines must carry the tracker\'s line font')
assert(dockedTo(win, tracker, 10),
  'the window must dock below the tracker with a gap of air between')
assert(win.width == 280 and win.width ~= tracker:GetWidth(),
  'a docked window must keep its own width, never the tracker\'s')

win.left, win.top = 100, 700
win.scripts.OnDragStart(win, 'LeftButton')
assert(win.dragging ~= true,
  'a docked window must not drag: the tracker owns the place')
win.scripts.OnDragStop(win)
assert(EfficientQuestsDB.window.x == 16 and EfficientQuestsDB.window.y == -120,
  'a docked window must leave the saved place untouched')
print('ok - with FlareUI the tracker\'s look is copied and the window docks below')

-- A broken tracker must never break the window (user story 44): a global
-- that is not a frame, a tracker without a backdrop, a tracker without
-- its scroll of lines -- each leaves the flat look on, the window keeps
-- its own place, and a refresh raises no error.
local BROKEN = {
  plain = function()
    _G.FlareUI_ObjectiveTracker = 'FlareUI went wrong'
  end,
  unshaped = function()
    local bare = CreateFrame('Frame', 'FlareUI_ObjectiveTracker', UIParent)
    bare:SetWidth(250)
    bare:SetBackdrop(TRACKER_BACKDROP)
  end,
  unbacked = function()
    local tracker = flareTracker()
    tracker:SetBackdrop(nil)
  end,
}
for name, breakIt in pairs(BROKEN) do
  player.level = 6
  loadLook(BASE, BASE_PATH, nil, breakIt)
  win = windowFrame()
  assert(win.shown, name .. ': the window must come up with a broken tracker')
  local texts = {}
  local function walk(node)
    for _, child in ipairs(node.children or {}) do
      if child.shown and child.kind == 'FontString' and child.text then
        texts[child.text] = true
      end
      walk(child)
    end
  end
  walk(win)
  assert(texts['Pick up Wolf pelts'],
    name .. ': the window must keep showing its step')
  assert(win.backdrop and win.backdrop.bgFile == 'Interface\\Buttons\\WHITE8X8',
    name .. ': a broken tracker must leave the flat plate on')
  assert(win.width == 280, name .. ': the window must keep its own width')
  local quiet = pcall(touchLog)
  assert(quiet, name .. ': a refresh must raise no error through a broken tracker')
  assert(win.backdrop.bgFile == 'Interface\\Buttons\\WHITE8X8',
    name .. ': a refresh must keep the flat look through a broken tracker')
end

-- The flat fallback keeps the drag: an unlocked window with a broken
-- tracker moves, and the drag writes the place back.
player.level = 6
loadLook(BASE, BASE_PATH, nil, BROKEN.plain)
win = windowFrame()
win.left, win.top = 100, 700
win.scripts.OnDragStart(win, 'LeftButton')
assert(win.dragging == true, 'a window with a broken tracker must still drag')
win.scripts.OnDragStop(win)
assert(EfficientQuestsDB.window.x == 100 and EfficientQuestsDB.window.y == -68,
  'the drag must write the place into the saved table')
print('ok - a broken tracker leaves the flat look, the drag, and no error')

-- The look follows the world across refreshes: a FlareUI that appears
-- after the window came up flat restyles it on the next refresh, and a
-- tracker that goes away hands the window back to the flat look, its
-- saved place, and its drag.
player.level = 6
loadLook(BASE, BASE_PATH)
win = windowFrame()
assert(win.backdrop.bgFile == 'Interface\\Buttons\\WHITE8X8',
  'the window must come up flat while FlareUI is away')
local lateTracker = flareTracker()
touchLog()
assert(win.backdrop.bgFile == TRACKER_BACKDROP.bgFile,
  'a late-loading FlareUI must restyle the window on the next refresh')
assert(dockedTo(win, lateTracker, 10),
  'a late-loading FlareUI must dock the window on the next refresh')
local lateGoal = fontOfText(win, 'Do Wolf pelts')
assert(lateGoal and lateGoal.fontSize == LINE_FONT[2],
  'the lines of the refreshed window must carry the tracker\'s font')

player.level = 6
loadLook(BASE, BASE_PATH,
  { window = { point = 'TOPLEFT', relativePoint = 'TOPLEFT', x = 200, y = -300 } },
  function() flareTracker() end)
win = windowFrame()
assert(dockedTo(win, _G.FlareUI_ObjectiveTracker, 10),
  'the window must dock while FlareUI is there')
_G.FlareUI_ObjectiveTracker = nil
touchLog()
assert(win.backdrop.bgFile == 'Interface\\Buttons\\WHITE8X8',
  'a tracker that goes away must bring the flat plate back')
local atSaved = false
for _, point in ipairs(win.points) do
  if point[1] == 'TOPLEFT' and point[2] == UIParent and point[3] == 'TOPLEFT'
      and point[4] == 200 and point[5] == -300 then atSaved = true end
end
assert(atSaved,
  'an undocked window must return to the place the saved table holds')
win.left, win.top = 100, 700
win.scripts.OnDragStart(win, 'LeftButton')
assert(win.dragging == true, 'an undocked window must drag again')
print('ok - the look follows the world across refreshes')

-- The real copied data through the shared seam, with FlareUI present:
-- the whole addon loads the way the game loads it -- the look adapter
-- last, after the step window it restyles -- and the window comes up
-- docked under the tracker with its look. The whole addon includes the
-- TomTom bridge now, so the sentinel gives way to a quiet fake here: the
-- bridge may set its one waypoint, while the hand-loaded scenarios above
-- keep the promise that the look adapter itself never calls TomTom.
TomTom = {
  IsCrazyArrowEmpty = function() return true end,
  AddWaypoint = function(_, map, x, y, opts)
    return { map, x, y, title = opts and opts.title, from = opts and opts.from }
  end,
  RemoveWaypoint = function() end,
}
frames = {}
EfficientQuestsDB, EfficientQuestsCharacter = {}, {}
local realTracker = flareTracker()
dofile('tests/addon.lua')()
player.level = 7
fire('PLAYER_LOGIN')
fire('PLAYER_ENTERING_WORLD')
win = windowFrame()
assert(win ~= nil and win.shown,
  'the real window must come up shown with FlareUI present')
assert(win.backdrop.bgFile == TRACKER_BACKDROP.bgFile,
  'the real window must wear the tracker\'s backdrop')
assert(dockedTo(win, realTracker, 10),
  'the real window must dock below the tracker')
assert(win.width == 280 and win.width ~= realTracker:GetWidth(),
  'the real window must keep its own width, never the tracker\'s')
print('ok - the real data docks under the tracker in the tracker\'s look')

print('all look adapter tests passed')
