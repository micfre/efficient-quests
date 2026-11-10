-- Standalone presentation. This module does not require FlareUI.
local EQ = EfficientQuests
local L = {
  title='Efficient Quests', settings='Settings', more='More', first='First',
  quest='Quest', item='Item', map='Map',
  dismiss='Dismiss', restore='Restore dismissed hints', guide='Guide',
  display='Display', dismissed='Dismissed', standalone='Standalone',
  integrated='FlareUI', spacing='Tracker spacing', width='Window width',
  noGuide='Install and adapt a supported guide.',
  missing='Install and enable QuestieDB.',
  incompatible='Update or reinstall a compatible QuestieDB.',
  unavailable='This guide is not registered. Reapply its adaptation.',
  explain='Choose which advice to see and how the window fits your screen.',
  none='No dismissed hints.', restored='Dismissed hints are available again.',
  source='Source', conditions='Conditions', uncertain='Some details are uncertain.',
}
local frame, body, status, more, settings, settingsNote, guideButton, modeButton, widthLabel, spacingLabel
local widthLess, widthMore, spacingLess, spacingMore, restore
local rows, shownHints, page = {}, {}, 0
local expanded, currentCategory = {}, 'guide'

local function character()
  EfficientQuestsCharacter = EfficientQuestsCharacter or {}
  local data = EfficientQuestsCharacter
  data.dismissed = data.dismissed or {}
  data.display = data.display or {}
  if type(data.display.width) ~= 'number' then data.display.width = 340 end
  if type(data.display.spacing) ~= 'number' then data.display.spacing = 8 end
  if data.display.mode ~= 'flare' then data.display.mode = 'standalone' end
  return data
end

local function sortedGuides()
  local names = {}
  for name in pairs(EQ.guides) do names[#names + 1] = name end
  table.sort(names)
  return names
end

local function selectedGuide()
  local data = character()
  if data.guide then return data.guide end
  local names = sortedGuides()
  if #names > 0 then data.guide = names[1] end
  return data.guide
end

local function text(parent, name, template)
  local field = parent:CreateFontString(name, 'OVERLAY', template or 'GameFontHighlightSmall')
  field:SetJustifyH('LEFT')
  field:SetJustifyV('TOP')
  field:SetWordWrap(true)
  return field
end

local function button(parent, name, label, width, height, click)
  local b = CreateFrame('Button', name, parent, 'UIPanelButtonTemplate')
  b:SetSize(width, height)
  b:SetText(label)
  b:SetScript('OnClick', click)
  return b
end

local function details(hint)
  local lines = {hint.relevance or 'zone tip'}
  if hint.uncertain then lines[#lines + 1] = L.uncertain end
  if hint.conditions and #hint.conditions > 0 then
    lines[#lines + 1] = L.conditions .. ': ' .. table.concat(hint.conditions, ', ')
  end
  if hint.sourceAuthor or hint.chapter then
    lines[#lines + 1] = L.source .. ': ' .. (hint.sourceAuthor or '') ..
      (hint.chapter and (' — ' .. hint.chapter) or '')
  end
  if hint.sourceText then lines[#lines + 1] = hint.sourceText end
  return table.concat(lines, '\n')
end

local function openQuest(hint)
  if hint.questID and QuestMapFrame_OpenToQuestDetails then QuestMapFrame_OpenToQuestDetails(hint.questID) end
end
local function openItem(hint, owner)
  if hint.verifiedItemID and GameTooltip and GameTooltip.SetHyperlink then
    GameTooltip:SetOwner(owner, 'ANCHOR_RIGHT')
    GameTooltip:SetHyperlink('item:' .. hint.verifiedItemID)
    GameTooltip:Show()
  end
end
local function openMap(hint)
  local context = EQ.GetContext()
  if not hint.location or not context.zoneID or not context.zoneName or
      not hint.location.zone or hint.location.zone:lower() ~= context.zoneName:lower() then return end
  if WorldMapFrame and WorldMapFrame.SetMapID then
    WorldMapFrame:SetMapID(context.zoneID)
    WorldMapFrame:Show()
  end
end

local function makeRow(index)
  local row = {}
  row.hint = button(body, 'EfficientQuestsHint'..index, '', 232, 36, function()
    local hint = shownHints[index]
    if not hint then return end
    expanded[hint.id] = not expanded[hint.id]
    EQ.RefreshInterface()
  end)
  row.detail = text(body, 'EfficientQuestsDetail'..index)
  row.dismiss = button(body, 'EfficientQuestsDismiss'..index, L.dismiss, 66, 22, function()
    local hint = shownHints[index]
    if not hint then return end
    character().dismissed[hint.id] = true
    EQ.RefreshInterface()
  end)
  row.quest = button(body, 'EfficientQuestsQuest'..index, L.quest, 52, 20, function()
    local hint = shownHints[index]; if hint then openQuest(hint) end
  end)
  row.item = button(body, 'EfficientQuestsItem'..index, L.item, 48, 20, function(self)
    local hint = shownHints[index]; if hint then openItem(hint, self) end
  end)
  row.map = button(body, 'EfficientQuestsMap'..index, L.map, 48, 20, function()
    local hint = shownHints[index]; if hint then openMap(hint) end
  end)
  rows[index] = row
  return row
end

local function showOrHide(widget, visible)
  if visible then widget:Show() else widget:Hide() end
end

local function refreshSettings()
  if not settings then return end
  local data = character()
  guideButton:SetText(L.guide .. ': ' .. (selectedGuide() or 'None'))
  modeButton:SetText(L.display .. ': ' .. (data.display.mode == 'flare' and L.integrated or L.standalone))
  widthLabel:SetText(L.width .. ': ' .. data.display.width)
  spacingLabel:SetText(L.spacing .. ': ' .. data.display.spacing)
  local guide = currentCategory == 'guide'
  local display = currentCategory == 'display'
  local dismissed = currentCategory == 'dismissed'
  showOrHide(guideButton, guide)
  showOrHide(modeButton, display)
  showOrHide(widthLabel, display); showOrHide(widthLess, display); showOrHide(widthMore, display)
  showOrHide(spacingLabel, display); showOrHide(spacingLess, display); showOrHide(spacingMore, display)
  showOrHide(restore, dismissed)
  settingsNote:SetText(guide and 'Select one installed guide.' or
    (display and 'Choose the window mode, width and tracker spacing.' or
    'Restore hints dismissed by this character.'))
end

function EQ.RefreshInterface()
  if not frame then return end
  local data = character()
  frame:SetWidth(data.display.width)
  local guide = selectedGuide()
  local hints, problem = EQ.GetHints(guide)
  hints = hints or {}
  local available = {}
  for _, hint in ipairs(hints) do
    if hint.id and not data.dismissed[hint.id] then available[#available + 1] = hint end
  end
  local statusText
  if problem == 'missing' then statusText = L.missing
  elseif problem == 'incompatible' then statusText = L.incompatible
  elseif problem == 'guide' then statusText = EQ.GetSetupStatus and EQ.GetSetupStatus() or (guide and L.unavailable or L.noGuide) end
  status:SetText(statusText or '')
  showOrHide(status, statusText ~= nil)
  showOrHide(body, #available > 0 and not statusText)
  local lastPage = math.max(0, math.ceil(#available / 3) - 1)
  page = math.min(page, lastPage)
  local count = math.min(3, #available - page * 3)
  shownHints = {}
  local y = -3
  for i=1,count do
    local hint, row = available[page * 3 + i], rows[i] or makeRow(i)
    shownHints[i] = hint
    row.hint:ClearAllPoints(); row.hint:SetPoint('TOPLEFT', body, 'TOPLEFT', 0, y)
    row.hint:SetWidth(math.max(120, data.display.width - 92)); row.hint:SetText(hint.text or '')
    row.dismiss:ClearAllPoints(); row.dismiss:SetPoint('TOPRIGHT', body, 'TOPRIGHT', 0, y)
    row.hint:Show(); row.dismiss:Show()
    y = y - 38
    local open = expanded[hint.id] == true
    row.detail:SetText(open and details(hint) or '')
    row.detail:ClearAllPoints(); row.detail:SetPoint('TOPLEFT', body, 'TOPLEFT', 4, y)
    row.detail:SetWidth(data.display.width - 20)
    showOrHide(row.detail, open)
    row.quest:ClearAllPoints(); row.quest:SetPoint('TOPLEFT', body, 'TOPLEFT', 4, y - 68)
    row.item:ClearAllPoints(); row.item:SetPoint('LEFT', row.quest, 'RIGHT', 3, 0)
    row.map:ClearAllPoints(); row.map:SetPoint('LEFT', row.item, 'RIGHT', 3, 0)
    showOrHide(row.quest, open and hint.questID ~= nil and QuestMapFrame_OpenToQuestDetails ~= nil)
    showOrHide(row.item, open and hint.verifiedItemID ~= nil and GameTooltip ~= nil)
    local context = EQ.GetContext()
    local localMap = hint.location and context.zoneID and context.zoneName and hint.location.zone and
      hint.location.zone:lower() == context.zoneName:lower() and WorldMapFrame and WorldMapFrame.SetMapID
    showOrHide(row.map, open and localMap)
    if open then y = y - 92 end
  end
  for i=count+1,#rows do
    local row = rows[i]
    for _, widget in pairs(row) do widget:Hide() end
  end
  more:SetText(page == lastPage and page > 0 and L.first or L.more)
  showOrHide(more, #available > 3)
  body:SetHeight(math.max(1, -y))
  frame:SetHeight(46 + (statusText and 28 or (#available > 0 and -y or 0)))
  refreshSettings()
end

function EQ.ShowSettings()
  if not settings then return end
  if settings:IsShown() then settings:Hide() else refreshSettings(); settings:Show() end
end

local function build()
  if frame then return end
  frame = CreateFrame('Frame', 'EfficientQuestsWindow', UIParent, 'BackdropTemplate')
  local position = character().display.position
  if position and position.point and position.relativePoint and type(position.x) == 'number' and type(position.y) == 'number' then
    frame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
  else
    frame:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT', -30, -180)
  end
  frame:SetSize(340, 46); frame:SetMovable(true); frame:EnableMouse(true)
  frame:RegisterForDrag('LeftButton'); frame:SetClampedToScreen(true)
  frame:SetScript('OnDragStart', function(self) self:StartMoving() end)
  frame:SetScript('OnDragStop', function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint()
    character().display.position = {point=point, relativePoint=relativePoint, x=x, y=y}
  end)
  local background = frame:CreateTexture(nil, 'BACKGROUND')
  background:SetAllPoints(frame); background:SetColorTexture(0.06, 0.06, 0.08, 0.88)
  local title = text(frame, nil, 'GameFontNormal'); title:SetPoint('TOPLEFT', frame, 'TOPLEFT', 8, -8); title:SetText(L.title)
  local configure = button(frame, 'EfficientQuestsOpenSettings', L.settings, 68, 22, EQ.ShowSettings)
  configure:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -4, -4)
  more = button(frame, 'EfficientQuestsMore', L.more, 50, 22, function()
    local guide = selectedGuide()
    local hints = EQ.GetHints(guide) or {}
    local count = 0
    for _, hint in ipairs(hints) do if hint.id and not character().dismissed[hint.id] then count = count + 1 end end
    page = (page + 1) % math.max(1, math.ceil(count / 3))
    EQ.RefreshInterface()
  end)
  more:SetPoint('RIGHT', configure, 'LEFT', -4, 0)
  status = text(frame, 'EfficientQuestsStatus'); status:SetPoint('TOPLEFT', frame, 'TOPLEFT', 8, -32); status:SetWidth(320)
  body = CreateFrame('Frame', 'EfficientQuestsBody', frame)
  body:SetPoint('TOPLEFT', frame, 'TOPLEFT', 8, -32); body:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -8, -32)

  settings = CreateFrame('Frame', 'EfficientQuestsSettings', UIParent, 'BackdropTemplate')
  settings:SetPoint('CENTER'); settings:SetSize(540, 360); settings:SetFrameStrata('DIALOG')
  local bg = settings:CreateTexture(nil, 'BACKGROUND'); bg:SetAllPoints(settings); bg:SetColorTexture(0.07, 0.07, 0.09, 0.96)
  local heading = text(settings, nil, 'GameFontNormalLarge'); heading:SetPoint('TOPLEFT', settings, 'TOPLEFT', 14, -14); heading:SetText(L.title)
  local close = button(settings, 'EfficientQuestsCloseSettings', 'Close', 55, 22, function() settings:Hide() end)
  close:SetPoint('TOPRIGHT', settings, 'TOPRIGHT', -8, -8)
  settingsNote = text(settings, nil); settingsNote:SetPoint('TOPLEFT', settings, 'TOPLEFT', 160, -48); settingsNote:SetWidth(360)
  local function category(label, offset, id, name)
    local b = button(settings, name, label, 125, 25, function() currentCategory=id; refreshSettings() end)
    b:SetPoint('TOPLEFT', settings, 'TOPLEFT', 12, offset)
  end
  category(L.guide, -48, 'guide', 'EfficientQuestsCategoryGuide')
  category(L.display, -78, 'display', 'EfficientQuestsCategoryDisplay')
  category(L.dismissed, -108, 'dismissed', 'EfficientQuestsCategoryDismissed')
  guideButton = button(settings, 'EfficientQuestsGuide', '', 300, 25, function()
    local names = sortedGuides(); if #names == 0 then return end
    local data = character(); local current = selectedGuide(); local nextIndex = 1
    for i, name in ipairs(names) do if name == current then nextIndex = i % #names + 1; break end end
    data.guide = names[nextIndex]; EQ.RefreshInterface()
  end)
  guideButton:SetPoint('TOPLEFT', settings, 'TOPLEFT', 160, -82)
  modeButton = button(settings, 'EfficientQuestsMode', '', 170, 25, function()
    local display = character().display
    display.mode = display.mode == 'flare' and 'standalone' or 'flare'; EQ.RefreshInterface()
  end)
  modeButton:SetPoint('TOPLEFT', settings, 'TOPLEFT', 160, -115)
  widthLabel = text(settings, nil); widthLabel:SetPoint('TOPLEFT', settings, 'TOPLEFT', 160, -152)
  widthLess = button(settings, 'EfficientQuestsWidthLess', '−', 26, 22, function()
    local d=character().display; d.width=math.max(240, d.width-20); EQ.RefreshInterface()
  end); widthLess:SetPoint('TOPLEFT', settings, 'TOPLEFT', 320, -148)
  widthMore = button(settings, 'EfficientQuestsWidthMore', '+', 26, 22, function()
    local d=character().display; d.width=math.min(600, d.width+20); EQ.RefreshInterface()
  end); widthMore:SetPoint('LEFT', widthLess, 'RIGHT', 4, 0)
  spacingLabel = text(settings, nil); spacingLabel:SetPoint('TOPLEFT', settings, 'TOPLEFT', 160, -185)
  spacingLess = button(settings, 'EfficientQuestsSpacingLess', '−', 26, 22, function()
    local d=character().display; d.spacing=math.max(0, d.spacing-2); EQ.RefreshInterface()
  end); spacingLess:SetPoint('TOPLEFT', settings, 'TOPLEFT', 320, -181)
  spacingMore = button(settings, 'EfficientQuestsSpacingMore', '+', 26, 22, function()
    local d=character().display; d.spacing=math.min(100, d.spacing+2); EQ.RefreshInterface()
  end); spacingMore:SetPoint('LEFT', spacingLess, 'RIGHT', 4, 0)
  restore = button(settings, 'EfficientQuestsRestore', L.restore, 200, 25, function()
    character().dismissed = {}; EQ.RefreshInterface(); settingsNote:SetText(L.restored)
  end); restore:SetPoint('TOPLEFT', settings, 'TOPLEFT', 160, -225)
  settings:Hide()
end

if UIParent then
local events = CreateFrame('Frame')
for _, event in ipairs({'PLAYER_LOGIN', 'PLAYER_ENTERING_WORLD', 'BAG_UPDATE_DELAYED',
  'QUEST_LOG_UPDATE', 'QUEST_TURNED_IN', 'SUPER_TRACKED_QUEST_CHANGED',
  'ZONE_CHANGED_NEW_AREA', 'TAXIMAP_OPENED', 'TAXIMAP_CLOSED',
  'TAXI_NODE_STATUS_CHANGED', 'BANKFRAME_OPENED', 'BANKFRAME_CLOSED', 'PLAYERBANKSLOTS_CHANGED'}) do
  pcall(events.RegisterEvent, events, event)
end
events:SetScript('OnEvent', function(_, event)
  if event == 'PLAYER_LOGIN' and UIParent then build() end
  if frame then EQ.RefreshInterface() end
end)
end
