-- Drive the addon UI with simulated game widgets and real guide/context/provider inputs.
local frames, widgets = {}, {}
UIParent = {}
SlashCmdList = {}
DEFAULT_CHAT_FRAME = {AddMessage=function() end}
local Widget = {}
function Widget:RegisterEvent(event) self.events[event] = true end
function Widget:SetScript(name, handler) self.scripts[name] = handler end
function Widget:SetText(text) self.text = text end
function Widget:GetText() return self.text end
function Widget:Show() self.shown = true end
function Widget:Hide() self.shown = false end
function Widget:IsShown() return self.shown end
function Widget:GetStringHeight() return math.ceil(#(self.text or '') / 25) * 14 end
function Widget:SetScrollChild(child) self.child = child end
function Widget:EnableMouseWheel() end
function Widget:SetVerticalScroll(value) self.scroll = value end
function Widget:GetVerticalScroll() return self.scroll or 0 end
function Widget:CreateFontString(name)
  local child = setmetatable({scripts={},events={},shown=true}, {__index=Widget})
  if name then widgets[name] = child; _G[name] = child end
  return child
end
function Widget:CreateTexture() return setmetatable({scripts={},events={},shown=true}, {__index=Widget}) end
for _, name in ipairs({'SetPoint','ClearAllPoints','SetSize','SetWidth','SetHeight','SetAllPoints','SetColorTexture','SetTextColor','SetJustifyH','SetJustifyV','SetWordWrap','SetMovable','EnableMouse','RegisterForDrag','StartMoving','StopMovingOrSizing','SetClampedToScreen','SetFrameStrata','SetBackdrop','SetBackdropColor','SetNormalFontObject','SetHighlightFontObject','SetScale'}) do Widget[name] = function() end end
function CreateFrame(kind, name, parent)
  local frame = setmetatable({kind=kind,parent=parent,scripts={},events={},shown=true}, {__index=Widget})
  frames[#frames+1] = frame
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
for line in io.lines('EfficientQuests/EfficientQuests.toc') do
  if line:match('%.lua$') then assert(loadfile('EfficientQuests/' .. line))('EfficientQuests', {}) end
end
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
SlashCmdList.EFFICIENTQUESTS('')
assert(widgets.EfficientQuestsSettings:IsShown(), 'settings open without FlareUI')
click('EfficientQuestsCategoryDismissed')
click('EfficientQuestsRestore')
assert(widgets.EfficientQuestsHint1.text:find('Apple',1,true), 'restoring dismissed hints makes them available again')
print('ok - compact standalone hints, deliberate expansion, dismissal and restore')
LibQuestieDB = nil
event('PLAYER_ENTERING_WORLD')
assert(widgets.EfficientQuestsStatus.text:find('QuestieDB',1,true), 'provider failure is visible')
assert(not widgets.EfficientQuestsBody:IsShown(), 'setup failure does not show stale hints')
print('ok - missing provider is distinct from an empty hint body')
local openedQuest, openedMap, openedItem
QuestMapFrame_OpenToQuestDetails=function(id) openedQuest=id end
WorldMapFrame={SetMapID=function(_,id) openedMap=id end, Show=function() end}
GameTooltip={SetOwner=function() end, SetHyperlink=function(_,item) openedItem=item end, Show=function() end}
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
click('EfficientQuestsHint3')
assert(not widgets.EfficientQuestsItem3:IsShown(), 'unverified guide item must not produce an item link')
print('ok - quest, map and verified item links use existing interfaces')

EfficientQuests_RegisterGuide('Long', '[N Elwynn Forest]\n[G40,50 Elwynn Forest] Buy [CI11,1 Apple] ' .. string.rep('for later use ', 90), 'Author')
EfficientQuestsCharacter.guide = 'Long'
event('QUEST_LOG_UPDATE')
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
