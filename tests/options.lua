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
