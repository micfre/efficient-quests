-- The options panel: the small window of our own that holds the waypoint
-- toggle, the window lock, the scale, and the opacity. The suite loads the
-- addon through the shared seam as on the Forever client, opens the panel
-- the way the step window and the /eq command will later, and asserts on
-- what the player sees and on the saved table the panel writes. The panel
-- must also stay unregistered: neither the client's own options nor the
-- FlareUI panel may hear from it.
local messages = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) table.insert(messages, message) end }
SlashCmdList = {}

-- Widget fake: every frame the addon builds records its size, its points,
-- its scripts, its text, and its children, so the suite can assert on the
-- window the way a player reads it. The fake grows with the panel.
local Widget = {}
Widget.__index = Widget

local frames = {}

local function widget(kind, name, parent)
  local self = setmetatable({
    kind = kind, name = name, parent = parent,
    children = {}, scripts = {}, points = {}, shown = false,
  }, Widget)
  if parent and parent.children then table.insert(parent.children, self) end
  table.insert(frames, self)
  return self
end

function CreateFrame(kind, name, parent)
  return widget(kind or 'Frame', name, parent)
end

function CreateVector2D() return {} end
function IsLoggedIn() return false end
C_Map = { GetMapInfo = function() return nil end, GetMapChildrenInfo = function() return nil end }
WOW_PROJECT_ID, WOW_PROJECT_CAMELOT = 5, 5
UIParent = {}

-- Registration spies: the options panel is a window of our own, so both
-- the client's options windows and the FlareUI panel must never hear from
-- it. Both Blizzard registration surfaces count their calls, and any
-- reach at all into the FlareUI global counts, because FlareUI keeps its
-- settings registry to itself: there is no honest way in, and the panel
-- must not look for one.
local blizzardRegistrations = 0
function InterfaceOptions_AddCategory() blizzardRegistrations = blizzardRegistrations + 1 end
Settings = { RegisterAddOnCategory = function() blizzardRegistrations = blizzardRegistrations + 1 end }
local flareTouches = 0
FlareUI = setmetatable({}, {
  __index = function() flareTouches = flareTouches + 1 return nil end,
  __newindex = function() flareTouches = flareTouches + 1 end,
})

function Widget:SetSize(width, height) self.width, self.height = width, height end
function Widget:SetWidth(width) self.width = width end
function Widget:SetHeight(height) self.height = height end
function Widget:SetPoint(...) table.insert(self.points, {...}) end
function Widget:ClearAllPoints() self.points = {} end
function Widget:SetAllPoints(target) self.points = { {'ALLPOINTS', target} } end
function Widget:Show() self.shown = true end
function Widget:Hide() self.shown = false end
function Widget:IsShown() return self.shown end
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

-- Setters the panel uses; each one records what the player would see, and
-- the getters answer with the same values.
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
function Widget:SetChecked(checked) self.checked = checked end
function Widget:GetChecked() return self.checked end
function Widget:SetCheckedTexture(texture) self.checkedTexture = texture end
function Widget:SetNormalTexture(texture) self.normalTexture = texture end
function Widget:SetNormalAtlas(atlas) self.normalAtlas = atlas end
function Widget:SetPushedAtlas(atlas) self.pushedAtlas = atlas end
function Widget:SetMinMaxValues(low, high) self.minValue, self.maxValue = low, high end
function Widget:SetValue(value) self.value = value end
function Widget:GetValue() return self.value end
function Widget:SetValueStep(step) self.valueStep = step end
function Widget:SetObeyStepOnDrag(obey) self.obeyStepOnDrag = obey end
function Widget:SetOrientation(orientation) self.orientation = orientation end
function Widget:SetAlpha(alpha) self.alpha = alpha end
function Widget:SetScale(scale) self.scale = scale end
function Widget:SetFrameStrata(strata) self.strata = strata end

-- The saved tables are fresh, the way the game hands them over on a first
-- login. The suite fires PLAYER_LOGIN itself once the addon files are in.
local function login()
  EfficientQuestsDB, EfficientQuestsCharacter = {}, {}
  dofile('tests/addon.lua')()
  for _, frame in ipairs(frames) do
    if frame.events and frame.events.PLAYER_LOGIN and frame.scripts.OnEvent then
      frame.scripts.OnEvent(frame, 'PLAYER_LOGIN')
    end
  end
end
login()

-- The step window and the /eq command open the panel through this one
-- function, so it must exist, build the window on first call, and leave
-- the window open on the screen.
local panel = EfficientQuests.Options.Open()
assert(type(panel) == 'table' and panel.kind == 'Frame',
  'Options.Open must build the options window and return it')
assert(panel:IsShown(), 'Options.Open must leave the options window open')
print('ok - Options.Open builds and shows the options window')

-- The player reads the panel by its row labels and each row's control, so
-- the suite finds a row by the text it shows and then the control on it.
local function walk(frame, visit)
  for _, child in ipairs(frame.children or {}) do
    visit(child)
    walk(child, visit)
  end
end

local function rowByLabel(label)
  local found
  walk(panel, function(child)
    if child.kind == 'FontString' and child.text == label and not found then
      found = child.parent
    end
  end)
  return found
end

local function control(row, kind)
  for _, child in ipairs(row.children) do
    if child.kind == kind then return child end
  end
end

local function showsText(row, text)
  for _, child in ipairs(row.children) do
    if child.kind == 'FontString' and child.text == text then return true end
  end
  return false
end

-- A fresh login has the defaults in the saved table, and the panel must
-- show exactly those: the waypoint toggle on, the window unlocked, and
-- both sliders at 1, each with its value written out as a percentage.
local waypoints = rowByLabel('Waypoints')
local lock = rowByLabel('Lock window')
local scale = rowByLabel('Scale')
local opacity = rowByLabel('Opacity')
assert(waypoints and lock and scale and opacity,
  'the panel must hold one row each for waypoints, lock, scale, and opacity')
assert(control(waypoints, 'CheckButton'):GetChecked() == true,
  'the waypoint toggle must show its default: on')
assert(control(lock, 'CheckButton'):GetChecked() == false,
  'the window lock must show its default: off')
assert(control(scale, 'Slider'):GetValue() == 1,
  'the scale slider must show its default: 1')
assert(control(opacity, 'Slider'):GetValue() == 1,
  'the opacity slider must show its default: 1')
assert(showsText(scale, '100%') and showsText(opacity, '100%'),
  'both slider rows must write their value out for the player')
print('ok - the panel shows the saved-data defaults when it opens')

-- A click on a checkbox, the way the client does it: the box flips first,
-- then its OnClick runs. Whatever the player ticks must land in the saved
-- table at once, because nothing else confirms it.
local function click(check)
  check:SetChecked(not check:GetChecked())
  local handler = check.scripts.OnClick
  if handler then handler(check, 'LeftButton') end
end

local waypointsCheck = control(rowByLabel('Waypoints'), 'CheckButton')
click(waypointsCheck)
assert(EfficientQuestsDB.waypoints == false,
  'one click on the on waypoint toggle must turn the option off in the saved table')
click(waypointsCheck)
assert(EfficientQuestsDB.waypoints == true,
  'a second click must turn the waypoint option back on')
print('ok - the waypoint toggle persists to the saved table on click')

local lockCheck = control(rowByLabel('Lock window'), 'CheckButton')
click(lockCheck)
assert(EfficientQuestsDB.locked == true,
  'one click on the off lock toggle must lock the window in the saved table')
click(lockCheck)
assert(EfficientQuestsDB.locked == false,
  'a second click must unlock the window again')
print('ok - the window lock persists to the saved table on click')

-- A drag on a slider, the way the client reports it: OnValueChanged with
-- the new position. The value must land in the saved table as it moves,
-- snapped to the step the slider promises, and the row must write the new
-- percentage out.
local function drag(slider, value)
  slider.value = value
  local handler = slider.scripts.OnValueChanged
  if handler then handler(slider, value) end
end

local scaleRow, scaleSlider = rowByLabel('Scale'), control(rowByLabel('Scale'), 'Slider')
drag(scaleSlider, 0.75)
assert(EfficientQuestsDB.scale == 0.75,
  'dragging the scale slider to 0.75 must save 0.75')
assert(showsText(scaleRow, '75%'), 'the scale row must write out the new 75%')
local opacityRow = rowByLabel('Opacity')
local opacitySlider = control(opacityRow, 'Slider')
drag(opacitySlider, 0.5)
assert(EfficientQuestsDB.opacity == 0.5,
  'dragging the opacity slider to 0.5 must save 0.5')
assert(showsText(opacityRow, '50%'), 'the opacity row must write out the new 50%')
print('ok - the sliders persist to the saved table as they move')

-- A saved session: the player changed the options earlier, and the panel
-- must show those values, not the defaults, every time it opens.
EfficientQuestsDB.waypoints = false
EfficientQuestsDB.locked = true
EfficientQuestsDB.scale = 0.75
EfficientQuestsDB.opacity = 0.5
EfficientQuests.Options.Open()
assert(control(rowByLabel('Waypoints'), 'CheckButton'):GetChecked() == false,
  'a saved off waypoint toggle must show as off')
assert(control(rowByLabel('Lock window'), 'CheckButton'):GetChecked() == true,
  'a saved on window lock must show as on')
assert(control(rowByLabel('Scale'), 'Slider'):GetValue() == 0.75,
  'a saved scale of 0.75 must show on the slider')
assert(showsText(rowByLabel('Scale'), '75%'),
  'the scale row must write out 75%')
assert(control(rowByLabel('Opacity'), 'Slider'):GetValue() == 0.5,
  'a saved opacity of 0.5 must show on the slider')
assert(showsText(rowByLabel('Opacity'), '50%'),
  'the opacity row must write out 50%')
print('ok - the panel shows saved values from the account-wide store on open')

-- After the whole session -- load, login, open, every click and drag --
-- the registration spies must still be untouched. The panel is a window
-- of our own: the client's options and the FlareUI panel never hear of it.
assert(blizzardRegistrations == 0,
  'the panel must not register with the client options windows')
assert(flareTouches == 0,
  'the panel must not reach into FlareUI or its settings registry')
print('ok - the panel registers itself nowhere')

-- A window needs a way off the screen. The header carries a close button,
-- the way the FlareUI options window does, and one click on it must hide
-- the panel; the next Open brings it back.
local closeButton
for _, child in ipairs(panel.children) do
  if child.kind == 'Button' then closeButton = child end
end
assert(closeButton, 'the panel must carry a close button in its header')
closeButton.scripts.OnClick(closeButton, 'LeftButton')
assert(not panel:IsShown(), 'a click on the close button must hide the panel')
EfficientQuests.Options.Open()
assert(panel:IsShown(), 'Open must bring the hidden panel back')
print('ok - the close button hides the panel and Open brings it back')
