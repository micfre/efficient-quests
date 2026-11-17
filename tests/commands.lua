-- The commands: /eq and /efficientquests, the player's way into the addon.
-- The suite loads the addon through the shared seam as on the Forever
-- client, types the commands the way the player does, and asserts on what
-- the player sees: the step window on or off the screen, the options panel
-- open, and the chat lines the status and the help write. The optional
-- addons are planted as fakes for the found half of the status and stay
-- away for the missing half.
local messages = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) table.insert(messages, message) end }
SlashCmdList = {}

-- Widget fake: the one the options, menu, and step window suites use,
-- grown by everything the step window builds, because the toggle command
-- brings the real window up on the real data. Everything the client
-- creates starts out shown; only an explicit Hide takes a widget off the
-- screen.
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

-- The map fake of the step window suite: two synthetic maps the world
-- position questions can answer, while the real copied data names maps
-- the fake never heard of -- those must fall back to plain place texts,
-- the way missing data always does in this addon.
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

-- The character sheet: an undead mage of the Horde, the start the real
-- Path data carries, with an empty quest log.
local player = { level = 6, raceName = 'Undead', raceID = 5,
  className = 'Mage', classID = 8, faction = 'Horde' }
UnitLevel = function() return player.level end
UnitRace = function() return player.raceName, player.raceName, player.raceID end
UnitClass = function() return player.className, player.className, player.classID end
UnitFactionGroup = function() return player.faction end

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

local world = nil
UnitPosition = function()
  if not world then return nil end
  return world.y, world.x, 50, world.instance
end
local inInstance = false
IsInInstance = function() return inInstance end

GameTooltip = {
  SetOwner = function() end,
  SetItemRef = function() end,
  SetSpellByID = function() end,
  Show = function() end,
  Hide = function() end,
}

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
function Widget:SetNormalAtlas(atlas) self.normalAtlas = atlas end
function Widget:SetPushedAtlas(atlas) self.pushedAtlas = atlas end
function Widget:SetMinMaxValues(low, high) self.minValue, self.maxValue = low, high end
function Widget:SetValue(value) self.value = value end
function Widget:GetValue() return self.value end
function Widget:SetValueStep(step) self.valueStep = step end
function Widget:SetObeyStepOnDrag(obey) self.obeyStepOnDrag = obey end
function Widget:SetOrientation(orientation) self.orientation = orientation end
function Widget:SetEnabled(enabled) self.enabled = enabled end
function Widget:SetMovable(movable) self.movable = movable end
function Widget:SetClampedToScreen(v) self.clampedToScreen = v end
function Widget:RegisterForDrag(button) self.dragButton = button end
function Widget:EnableMouse(v) self.mouseEnabled = v end
function Widget:StartMoving() self.dragging = true end
function Widget:StopMovingOrSizing() self.dragging = false end
function Widget:GetLeft() return self.left end
function Widget:GetTop() return self.top end

-- The manifest fields the way the game exposes them: the client answers
-- from the manifest text it read, so the fake answers from the same text
-- the shared loader reads.
local tocFields = {}
for line in io.lines('dist/EfficientQuests/EfficientQuests.toc') do
  local field, value = line:match('^##%s*(%a+):%s*(.-)%s*$')
  if field then tocFields[field:lower()] = value end
end
function GetAddOnMetadata(addon, field)
  assert(addon == 'EfficientQuests', 'the addon must ask for its own manifest, not ' .. addon)
  return tocFields[field:lower()]
end

-- Deliver a game event the way the client does: only the frames that
-- registered for it hear it.
local function fire(event, ...)
  for _, frame in ipairs(frames) do
    if frame.events and frame.events[event] and frame.scripts.OnEvent then
      frame.scripts.OnEvent(frame, event, ...)
    end
  end
end

-- The player is at the loading screen moment: login applies the saved-data
-- defaults, the world has not appeared yet, and the window is not built.
EfficientQuestsDB, EfficientQuestsCharacter = {}, {}
dofile('tests/addon.lua')()
fire('PLAYER_LOGIN')

-- Type a chat line the way the client delivers it: the command word is
-- matched against every registered SLASH_ name -- the client lowercases
-- it -- and the handler of the entry that claims it receives the rest.
local function runSlash(text)
  local command, rest = text:match('^(/%S+)%s*(.-)%s*$')
  assert(command, 'the suite types whole commands: ' .. text)
  command = command:lower()
  for key, handler in pairs(SlashCmdList) do
    for index = 1, 100 do
      local name = 'SLASH_' .. key .. index
      local value = rawget(_G, name)
      if value == nil then break end
      if type(value) == 'string' and value:lower() == command then
        return handler(rest)
      end
    end
  end
  error('no slash command is registered for ' .. command)
end

local function says(fragment)
  for _, message in ipairs(messages) do
    if message:find(fragment, 1, true) then return true end
  end
  return false
end

-- Both spellings must be registered with the client, the short one and
-- the long one, and both must run the same handler: each command, typed
-- alone, toggles the step window -- the hidden window comes up, the shown
-- window goes away.
assert(SLASH_EQ1 == '/eq', 'the short command /eq must be registered')
assert(SLASH_EFFICIENTQUESTS1 == '/efficientquests',
  'the long command /efficientquests must be registered')
assert(type(SlashCmdList.EQ) == 'function' and type(SlashCmdList.EFFICIENTQUESTS) == 'function',
  'both slash commands must hand the client a handler')
local stepWindow = EfficientQuests.StepWindow
assert(stepWindow.IsShown() == false, 'the window starts off the screen before any command')
messages = {}
runSlash('/eq')
assert(stepWindow.IsShown() == true, 'a bare /eq must show the hidden window')
runSlash('/eq')
assert(stepWindow.IsShown() == false, 'a second bare /eq must hide the shown window')
runSlash('/efficientquests')
assert(stepWindow.IsShown() == true, 'the long spelling must show the window as well')
runSlash('/EFFICIENTQUESTS')
assert(stepWindow.IsShown() == false, 'the long spelling must hide the window as well, in any case')
assert(#messages == 0, 'the toggle stays quiet: it works through the window, not the chat')
print('ok - both commands are registered and toggle the step window')

-- "options" (and its "config" twin) opens the options panel. The step
-- window hands the same call, so the spy counts what the command reaches:
-- one call per command, and the real panel left open on the screen.
local opened = 0
local realOpen = EfficientQuests.Options.Open
EfficientQuests.Options.Open = function()
  opened = opened + 1
  return realOpen()
end
messages = {}
runSlash('/eq options')
runSlash('/eq config')
runSlash('/efficientquests options')
EfficientQuests.Options.Open = realOpen
assert(opened == 3,
  'options and config, from both spellings, must each open the panel once')
local panel = realOpen()
assert(panel.kind == 'Frame' and panel:IsShown(),
  'the options panel must be left open on the screen')
assert(#messages == 0, 'opening the options stays quiet: the panel is the answer')
print('ok - options and config open the options panel')

-- The status (user story 68): the facts a report needs, in a few chat
-- lines. Which optional addons were found -- one word each, found or
-- missing -- which data snapshot the store holds, and the version. First
-- the plain setup: no optional addon at all, the way the addon must stand
-- alone.
messages = {}
runSlash('/eq status')
assert(#messages == 3, 'the status must stay at a few lines: ' .. #messages)
assert(says('Efficient Quests: version 0.3.0'),
  'the status must name the version the manifest declares')
assert(says('Efficient Quests: FlareUI missing, TomTom missing, QuestieDB missing'),
  'with no optional addon, the status must say missing for each of them')
assert(says('Efficient Quests: data snapshot ' .. EfficientQuests.GetDataSnapshot()),
  'the status must carry the data snapshot the store reports')
print('ok - the status names version, snapshot, and all addons missing')

-- The rich setup: FlareUI, TomTom, and QuestieDB all in the world, as
-- simple fakes the way the seam replaces them. TomTom answers the calls
-- the waypoint bridge makes; QuestieDB passes its contract. The same
-- command must now say found for each, so the one word per addon is a
-- live answer, not a fixed line.
FlareUI = {}
FlareUI_ObjectiveTracker = {}
TomTom = {
  IsCrazyArrowEmpty = function() return true end,
  AddWaypoint = function() end,
  RemoveWaypoint = function() end,
}
LibQuestieDB = {
  RequireContract = function(required) return required == 1 end,
  Quest = { Get = function() end },
  Npc = { Get = function() end },
}
messages = {}
runSlash('/eq status')
assert(says('FlareUI found, TomTom found, QuestieDB found'),
  'with every optional addon present, the status must say found for each')
print('ok - the status says found for each present optional addon')

-- A TomTom without the call methods the bridge needs is as good as none:
-- the same strictest test the bridge acts on must keep the verdict at
-- missing, so the status line and the bridge can never disagree.
TomTom = {}
messages = {}
runSlash('/eq status')
assert(says('TomTom missing'),
  'a TomTom that answers no call of the bridge contract counts as missing')
print('ok - a TomTom without its call methods counts as missing')

-- An incompatible QuestieDB is as good as none: the same contract test
-- the fallback applies (see the QuestieDB fallback suite) must keep the
-- verdict at missing when the library refuses its contract.
TomTom = {
  IsCrazyArrowEmpty = function() return true end,
  AddWaypoint = function() end,
  RemoveWaypoint = function() end,
}
LibQuestieDB = {
  RequireContract = function() return false end,
  Quest = { Get = function() end },
  Npc = { Get = function() end },
}
messages = {}
runSlash('/eq status')
assert(says('FlareUI found, TomTom found, QuestieDB missing'),
  'a QuestieDB that refuses its contract counts as missing')
print('ok - an incompatible QuestieDB counts as missing')

-- A client without the metadata service still gets its facts: the version
-- falls back to the value the manifest ships, so a report never lacks it.
GetAddOnMetadata = nil
messages = {}
runSlash('/eq status')
assert(messages[1]:find('version %d+%.%d+%.%d+'),
  'without the metadata service, the status must still name a version')
GetAddOnMetadata = function(addon, field)
  assert(addon == 'EfficientQuests', 'the addon must ask for its own manifest, not ' .. addon)
  return tocFields[field:lower()]
end
print('ok - the version survives without the metadata service')

-- "help" lists the commands in plain words: every subcommand with one
-- line about what it does.
messages = {}
runSlash('/eq help')
assert(#messages == 5, 'the help must stay a short list: ' .. #messages)
assert(messages[1] == 'Efficient Quests commands:',
  'the help must open with one known headline')
assert(messages[2] == '/eq - toggle the step window',
  'the help must list the bare command with its work')
assert(messages[3] == '/eq options - open the options panel',
  'the help must list the options command')
assert(messages[4] == '/eq status - show the version, the data snapshot, and the optional addons',
  'the help must list the status command')
assert(messages[5] == '/eq help - list these commands',
  'the help must list the help command')
print('ok - help lists the commands')

-- A word the commands do not know earns one line that points at the
-- help, so a typo teaches the player the list.
messages = {}
runSlash('/eq wander')
assert(#messages == 1, 'an unknown command must cost one line, not a wall: ' .. #messages)
assert(says("unknown command 'wander'")
  and says('/eq help', 'the line must name the unknown word and point at the help'))
print('ok - an unknown command points at the help')

print('all command tests passed')
