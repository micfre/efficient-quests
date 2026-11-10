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
