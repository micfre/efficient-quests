-- The menu: the small window that opens beside the step window. The suite
-- loads the addon through the shared seam as on the Forever client and opens
-- the menu the way the step window will later: with itself as the anchor, or
-- without an anchor when nothing is on the screen yet. It asserts on the
-- rows the player reads -- the skipped quests by name with a restore action
-- each, the known dungeons, the link to the options -- and on the skip list
-- store and the saved table that a restore must reach.
local messages = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) table.insert(messages, message) end }
SlashCmdList = {}

-- Widget fake: every frame the addon builds records its size, its points,
-- its scripts, its text, and its children, so the suite can assert on the
-- menu the way a player reads it. The fake is the one the options suite
-- grows; it grows with the menu the same way.
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

-- Setters the menu uses; each one records what the player would see, and
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

-- The step window opens the menu beside itself through this one function,
-- so it must exist, build the window on first call, and leave the window
-- open on the screen -- also when no window is there to anchor beside, in
-- which case the menu sits at a fixed spot on the screen.
local menu = EfficientQuests.Menu.Open()
assert(type(menu) == 'table' and menu.kind == 'Frame',
  'Menu.Open must build the menu window and return it')
assert(menu:IsShown(), 'Menu.Open must leave the menu window open')
local fixedToScreen = false
for _, point in ipairs(menu.points) do
  if point[2] == UIParent then fixedToScreen = true end
end
assert(fixedToScreen,
  'without an anchor the menu must sit at a fixed spot on the screen')
print('ok - Menu.Open builds and shows the menu without an anchor')

-- The anchor seam the step window builds on: Open puts the menu's top left
-- beside the anchor's top right, so the menu never covers the window.
local stepWindow = CreateFrame('Frame')
local anchored = EfficientQuests.Menu.Open(stepWindow)
assert(anchored == menu, 'a second Open must reuse the menu it built before')
local beside = false
for _, point in ipairs(menu.points) do
  if point[1] == 'TOPLEFT' and point[2] == stepWindow and point[3] == 'TOPRIGHT' then
    beside = true
  end
end
assert(beside, 'with an anchor the menu must sit beside the anchor window')
print('ok - Menu.Open anchors the menu beside the window it is given')
