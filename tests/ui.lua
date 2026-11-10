-- Drive the addon UI with simulated game widgets and real guide/context/provider inputs.
local frames, widgets = {}, {}
UIParent = {}
SlashCmdList = {}
DEFAULT_CHAT_FRAME = {AddMessage=function() end}
local Widget = {}
function Widget:RegisterEvent(event) self.events[event] = true end
function Widget:SetScript(name, handler) self.scripts[name] = handler end
function Widget:SetText(text) self.text = text; if self.fontString then self.fontString.text = text end end
function Widget:GetText() return self.text end
function Widget:IsVisible() return self.shown ~= false end
function Widget:GetObjectType() return self.kind end
function Widget:GetFont() return unpack(self.font or {'default-font', 12, ''}) end
function Widget:SetFont(face, size, flags) self.font = {face, size, flags} end
function Widget:GetTextColor() return unpack(self.color or {1,1,1,1}) end
function Widget:GetFontString()
  if not self.fontString then self.fontString = self:CreateFontString(); self.fontString.text = self.text end
  return self.fontString
end
function Widget:GetWidth() return self.width end
function Widget:GetHeight() return self.height end
function Widget:GetTop() return self.top end
function Widget:GetBottom() return self.bottom end
function Widget:GetEffectiveScale() return self.scale or 1 end
function Widget:GetChildren() return unpack(self.children or {}) end
function Widget:GetRegions() return unpack(self.regions or {}) end
function Widget:GetBackdrop() return self.backdrop end
function Widget:GetBackdropColor() return 1,1,1,0.6 end
function Widget:GetBackdropBorderColor() return 0.6,0.5,0.3,1 end
function Widget:Show() self.shown = true end
function Widget:Hide() self.shown = false end
function Widget:IsShown() return self.shown end
function Widget:GetStringHeight() return math.ceil(#(self.text or '') / 25) * 14 end
function Widget:GetFontString() return self end
function Widget:SetScrollChild(child) self.child = child end
function Widget:EnableMouseWheel() end
function Widget:SetVerticalScroll(value) self.scroll = value end
function Widget:GetVerticalScroll() return self.scroll or 0 end
function Widget:CreateFontString(name)
  local child = setmetatable({scripts={},events={},shown=true}, {__index=Widget})
  self.regions = self.regions or {}; table.insert(self.regions, child)
  child.kind = "FontString"
  if name then widgets[name] = child; _G[name] = child end
  return child
end
function Widget:CreateTexture() return setmetatable({scripts={},events={},shown=true}, {__index=Widget}) end
for _, name in ipairs({'SetAllPoints','SetColorTexture','SetJustifyH','SetJustifyV','SetWordWrap','SetMovable','EnableMouse','RegisterForDrag','StartMoving','StopMovingOrSizing','SetClampedToScreen','SetFrameStrata','SetBackdrop','SetBackdropColor','SetNormalFontObject','SetHighlightFontObject','SetScale'}) do Widget[name] = function() end end
function Widget:SetTextColor(...) self.color = {...} end
function Widget:SetPoint(...) self.point = {...} end
function Widget:GetPoint() return unpack(self.point or {}) end
function Widget:ClearAllPoints() self.point = nil end
function Widget:SetSize(w,h) self.width, self.height = w,h end
function Widget:SetWidth(w) self.width = w end
function Widget:SetHeight(h) self.height = h end
function Widget:SetBackdrop(value) self.backdrop = value end
function Widget:SetBackdropBorderColor(...) self.border = {...} end
UIParent = setmetatable({width=1000,height=800,shown=true,children={}}, {__index=Widget})

function CreateFrame(kind, name, parent)
  local frame = setmetatable({kind=kind,parent=parent,scripts={},events={},shown=true}, {__index=Widget})
  frames[#frames+1] = frame
  if parent and parent.children then table.insert(parent.children, frame) end
  if name then widgets[name] = frame; _G[name] = frame end
  return frame
end
local function event(name, ...)
  for _, frame in ipairs(frames) do if frame.events[name] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, name, ...) end end
end
local function click(name)
  local frame = assert(widgets[name], 'missing widget '..name)
  assert(frame.shown ~= false and frame.scripts.OnClick, 'widget cannot be clicked: '..name)
  frame.scripts.OnClick(frame)
end
dofile('tests/addon.lua')()
local entity = {Get=function() end}
LibQuestieDB = {RequireContract=function(n) return n == 1 end,
  Quest=entity, Npc=entity, Item=entity, Object=entity}
UnitFactionGroup=function() return 'Alliance' end
C_Map={GetBestMapForUnit=function() return 1 end, GetMapInfo=function() return {name='Elwynn Forest'} end}
C_QuestLog={GetNumQuestLogEntries=function() return 0, 0 end, IsOnQuest=function() return false end}
EfficientQuests_RegisterGuide('TUG', [[
[GA Alliance]
[N Elwynn Forest]
[G40,50 Elwynn Forest] Buy [CI11,1 Apple].
[G40,50 Elwynn Forest] Buy [CI12,1 Bread].
[G40,50 Elwynn Forest] Buy [CI13,1 Water].
[G40,50 Elwynn Forest] Buy [CI14,1 Candle].
]], 'Author')
event('PLAYER_LOGIN')
event('PLAYER_ENTERING_WORLD')
assert(widgets.EfficientQuestsWindow:IsShown(), 'standalone hint window appears with useful advice')
assert(widgets.EfficientQuestsHint1.text:find('Apple',1,true), 'first hint is visible')
assert(widgets.EfficientQuestsHint3:IsShown() and not widgets.EfficientQuestsHint4, 'compact view shows at most three hints')
click('EfficientQuestsMore')
assert(widgets.EfficientQuestsHint1.text:find('Candle',1,true), 'more advice is deliberately paged into view')
click('EfficientQuestsMore')
assert(widgets.EfficientQuestsHint1.text:find('Apple',1,true), 'the player can return to the first page')
click('EfficientQuestsHint1')
assert(widgets.EfficientQuestsDetail1.text:find('Author',1,true), 'expanded advice shows source attribution')
click('EfficientQuestsDismiss1')
assert(not widgets.EfficientQuestsHint1.text:find('Apple',1,true), 'dismissed hint disappears')
click('EfficientQuestsDismiss1')
assert(not widgets.EfficientQuestsHint1.text:find('Bread',1,true), 'second dismissed hint disappears')
SlashCmdList.EFFICIENTQUESTS('')
assert(widgets.EfficientQuestsSettings:IsShown(), 'settings open without FlareUI')
click('EfficientQuestsCategoryDismissed')
assert(widgets.EfficientQuestsDismissedLabel1.text:find('Apple',1,true),
  'the dismissed-hints view names each dismissed hint')
assert(widgets.EfficientQuestsDismissedLabel2.text:find('Bread',1,true),
  'every dismissed hint has its own restore control')
click('EfficientQuestsRestoreHint1')
assert(widgets.EfficientQuestsHint1.text:find('Apple',1,true), 'restoring one hint returns it immediately')
assert(not widgets.EfficientQuestsHint1.text:find('Bread',1,true)
  and not widgets.EfficientQuestsHint2.text:find('Bread',1,true),
  'restoring one hint leaves the other dismissal intact')
click('EfficientQuestsRestore')
assert(widgets.EfficientQuestsHint2.text:find('Bread',1,true),
  'restore all returns every remaining dismissed hint')
print('ok - compact standalone hints, deliberate expansion, per-hint dismissal and restore')
LibQuestieDB = nil
event('PLAYER_ENTERING_WORLD')
assert(widgets.EfficientQuestsStatus.text:find('QuestieDB',1,true), 'provider failure is visible')
assert(not widgets.EfficientQuestsBody:IsShown(), 'setup failure does not show stale hints')
print('ok - missing provider is distinct from an empty hint body')
local openedQuest, openedMap, openedItem
QuestMapFrame_OpenToQuestDetails=function(id) openedQuest=id end
WorldMapFrame={SetMapID=function(_,id) openedMap=id end, Show=function() end}
local tooltipOwner, tooltipVisible
GameTooltip={SetOwner=function(_,owner) tooltipOwner=owner end,
 IsOwned=function(_,owner) return tooltipOwner == owner end,
 SetHyperlink=function(_,item) openedItem=item end, Show=function() tooltipVisible=true end,
 Hide=function() tooltipVisible=false end}
LibQuestieDB = {RequireContract=function(n) return n == 1 end,
  Quest=entity, Npc=entity, Object=entity,
  Item={Get=function(id, field) if id == 11 and field == 'name' then return 'Apple' end end}}
EfficientQuests_RegisterGuide('Links', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] Use a torch before approaching for [QC77].
[G40,50 Elwynn Forest] Buy [CI11,1 Apple].
[G40,50 Elwynn Forest] Buy [CI12,1 Bread].
]], 'Author')
EfficientQuestsCharacter.guide = 'Links'
event('QUEST_LOG_UPDATE')
click('EfficientQuestsHint1')
click('EfficientQuestsQuest1')
click('EfficientQuestsMap1')
assert(openedQuest == 77 and openedMap == 1, 'quest and location controls open existing game interfaces')
click('EfficientQuestsHint2')
click('EfficientQuestsItem2')
assert(openedItem == 'item:11', 'provider-verified item opens an existing tooltip')
assert(tooltipVisible and widgets.EfficientQuestsItem2.scripts.OnLeave, 'item tooltip has leave handling')
widgets.EfficientQuestsItem2.scripts.OnLeave(widgets.EfficientQuestsItem2)
assert(not tooltipVisible, 'item tooltip hides when the pointer leaves')
click('EfficientQuestsItem2')
GameTooltip:SetOwner({})
widgets.EfficientQuestsItem2.scripts.OnLeave(widgets.EfficientQuestsItem2)
assert(tooltipVisible, 'leaving must not hide a tooltip now owned by another widget')
click('EfficientQuestsItem2')
click('EfficientQuestsHint2')
assert(not tooltipVisible, 'item tooltip hides when its details close')
click('EfficientQuestsHint3')
assert(not widgets.EfficientQuestsItem3:IsShown(), 'unverified guide item must not produce an item link')
print('ok - quest, map and verified item links use existing interfaces')

-- A selected guide that is no longer registered says so and points the
-- player at the settings instead of naming any external tool.
EfficientQuests.guides.Links = nil
event('QUEST_LOG_UPDATE')
assert(widgets.EfficientQuestsStatus:IsShown(), 'a removed selected guide must show the status line')
assert(widgets.EfficientQuestsStatus.text:find('no longer registered', 1, true),
  'the removed-guide status must say the guide is gone')
assert(widgets.EfficientQuestsStatus.text:find('Settings', 1, true),
  'the removed-guide status must point at where another guide can be chosen')
print('ok - removed selected guide names the problem')

EfficientQuests_RegisterGuide('Long', '[N Elwynn Forest]\n[G40,50 Elwynn Forest] Buy [CI11,1 Apple] ' .. string.rep('for later use ', 90), 'Author')
EfficientQuestsCharacter.guide = 'Long'
event('QUEST_LOG_UPDATE')
assert(widgets.EfficientQuestsHint1.height > 36, 'long advice grows rather than clipping in its button')
click('EfficientQuestsHint1')
local scroll = assert(widgets.EfficientQuestsScroll, 'long explanations need a deliberate scroll control')
assert(scroll.scripts.OnMouseWheel, 'long explanations support mouse-wheel navigation')
scroll.scripts.OnMouseWheel(scroll, -1)
assert(scroll:GetVerticalScroll() > 0, 'player can reach the rest of a long explanation')
print('ok - long source details remain reachable through deliberate scrolling')
EfficientQuests_RegisterGuide('Empty', '[N Elwynn Forest]\nAccept [QA77].', 'Author')
EfficientQuestsCharacter.guide = 'Empty'
event('QUEST_LOG_UPDATE')
assert(not widgets.EfficientQuestsBody:IsShown(), 'valid empty results hide the hint body')
assert(not widgets.EfficientQuestsStatus:IsShown(), 'valid empty results are not a setup failure')
assert(widgets.EfficientQuestsOpenSettings:IsShown(), 'settings remain accessible when no hint matches')
print('ok - valid empty results hide advice and keep settings available')
click('EfficientQuestsCategoryDisplay')
local previousWidth = EfficientQuestsCharacter.display.width
click('EfficientQuestsWidthMore')
assert(EfficientQuestsCharacter.display.width == previousWidth + 20, 'standalone width preference is saved')
click('EfficientQuestsMode')
assert(EfficientQuestsCharacter.display.mode == 'flare' and widgets.EfficientQuestsWindow:IsShown(), 'integration preference is remembered while standalone remains available')
print('ok - display choices persist with a standalone fallback')

local tracker = CreateFrame('Frame', 'FlareUI_ObjectiveTracker', UIParent)
tracker:SetSize(250, 200); tracker.bottom=400; tracker.top=600
tracker:SetBackdrop({bgFile='tracker-background'})
tracker.children = {}
local trackerHeader = CreateFrame('Frame', nil, tracker)
trackerHeader.title = trackerHeader:CreateFontString()
trackerHeader.title:SetFont('flare-font', 17, 'OUTLINE')
trackerHeader.title:SetTextColor(0.8, 0.6, 0.3, 1)
local trackerScroll = CreateFrame('ScrollFrame', nil, tracker)
trackerScroll:Show()
event('PLAYER_ENTERING_WORLD')
local window = widgets.EfficientQuestsWindow
assert(window.width == 250 and window.point[2] == tracker and window.point[3] == 'BOTTOMLEFT', 'integrated window attaches below tracker at its width')
assert(window.backdrop and window.backdrop.bgFile == 'tracker-background', 'integrated window follows tracker backdrop')
assert(widgets.EfficientQuestsStatus:GetFont() == 'flare-font', 'integrated text matches tracker font')
EfficientQuestsCharacter.display.position = {point='CENTER',relativePoint='CENTER',x=12,y=34}
window.scripts.OnDragStart(window)
window.scripts.OnDragStop(window)
local remembered = EfficientQuestsCharacter.display.position
assert(remembered.point == 'CENTER' and remembered.relativePoint == 'CENTER' and remembered.x == 12 and remembered.y == 34,
  'drag attempts while integrated must not overwrite standalone position')
print('ok - Flare tracker geometry and backdrop')
local function tick()
  for _, value in ipairs(frames) do if value.scripts.OnUpdate then value.scripts.OnUpdate(value, 1) end end
end
tracker.bottom=5; tracker.top=205
tick()
assert(window.point[1] == 'BOTTOMLEFT' and window.point[3] == 'TOPLEFT', 'insufficient space below places the window above')
trackerScroll:Hide(); tick()
assert(not window:IsShown(), 'minimizing tracker hides integrated hints')
trackerScroll:Show(); tick()
assert(window:IsShown(), 'expanding tracker restores integrated hints')
tracker:Hide(); tick()
assert(not window:IsShown(), 'hidden tracker hides integrated hints')
tracker:Show(); tracker:SetWidth(310); trackerHeader.title:SetFont('changed-font', 18, ''); tick()
assert(window:IsShown() and window.width == 310, 'tracker appearance and width changes are followed')
assert(widgets.EfficientQuestsStatus:GetFont() == 'changed-font', 'font changes are followed')
FlareUI_ObjectiveTracker = nil; tick()
assert(window:IsShown() and window.width == EfficientQuestsCharacter.display.width and EfficientQuestsCharacter.display.mode == 'flare', 'unavailable tracker falls back without changing preference')
assert(widgets.EfficientQuestsStatus:GetFont() == 'default-font', 'fallback restores standalone text styling')
window:SetPoint('CENTER', UIParent, 'CENTER', 31, 44)
window.scripts.OnDragStart(window); window.scripts.OnDragStop(window)
assert(EfficientQuestsCharacter.display.position.x == 31 and EfficientQuestsCharacter.display.position.y == 44,
  'standalone fallback dragging still updates the saved position')
FlareUI_ObjectiveTracker = tracker; tick()
assert(window.point[2] == tracker and window.width == 310, 'integration resumes when tracker returns')
print('ok - tracker visibility, placement, resize and fallback recovery')

tracker.scale = 1.5; tick()
assert(window.width == 465, 'tracker effective scale is reflected in the integrated width')
print('ok - tracker scaling is reflected in the integrated width')
FlareUI_ObjectiveTracker = nil
EfficientQuestsCharacter.display.mode = 'standalone'
local playerX = 0.2
C_Map.GetMapWorldSize = function() return 1000, 1000 end
C_Map.GetPlayerMapPosition = function() return {GetXY=function() return playerX, 0.5 end} end
C_QuestLog.IsOnQuest = function() return false end
C_QuestLog.GetQuestsOnMap = function() return {
  {questID=301,mapID=1,x=0.2,y=0.5,isQuestStart=true},
  {questID=302,mapID=1,x=0.8,y=0.5,isQuestStart=true},
} end
EfficientQuests_RegisterGuide('Moving', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] Use a torch before approaching for [QC301].
[G40,50 Elwynn Forest] Use a net before approaching for [QC302].
]], 'Author')
EfficientQuestsCharacter.guide = 'Moving'
event('QUEST_LOG_UPDATE'); tick()
assert(widgets.EfficientQuestsHint1.text:find('torch',1,true), 'nearby opportunity ranks first initially')
playerX = 0.8
tick()
assert(widgets.EfficientQuestsHint1.text:find('net',1,true), 'crossing distance bands refreshes visible order')
print('ok - moving between distance bands refreshes visible hints')
