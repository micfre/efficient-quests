-- Standalone presentation. This module does not require FlareUI.
local EQ = EfficientQuests
local L = {
  title='Efficient Quests', settings='Settings', more='More', first='First',
  quest='Quest', item='Item', map='Map',
  dismiss='Dismiss', restore='Restore all dismissed hints', restoreHint='Restore',
  guide='Guide',
  display='Display', dismissed='Dismissed', standalone='Standalone',
  integrated='FlareUI', spacing='Tracker spacing', width='Window width',
  noGuide='Install a guide plugin.',
  missing='Install and enable QuestieDB.',
  incompatible='Update or reinstall a compatible QuestieDB.',
  unavailable='This guide is no longer registered. Choose another in Settings.',
  explain='Choose which advice to see and how the window fits your screen.',
  none='No dismissed hints.', restored='Dismissed hints are available again.',
  source='Source', conditions='Conditions', uncertain='Some details are uncertain.',
}
local frame, body, scroll, status, more, settings, settingsNote, guideButton, modeButton, widthLabel, spacingLabel
local background, title
local scrollRange = 0
local widthLess, widthMore, spacingLess, spacingMore, restore
local rows, shownHints, page = {}, {}, 0
local expanded, currentCategory = {}, 'guide'
local dismissedRows, dismissedEntries = {}, {}
local itemTooltipOwner

-- The character's saved variables: dismissals and display preferences
-- scoped to this character by the TOC's SavedVariablesPerCharacter key.
local function savedCharacterData()
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
  local data = savedCharacterData()
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
    itemTooltipOwner = owner
  end
end
local function closeItemTooltip(owner)
  if not itemTooltipOwner or (owner and owner ~= itemTooltipOwner) then return end
  if GameTooltip and GameTooltip.Hide and
      (not GameTooltip.IsOwned or GameTooltip:IsOwned(itemTooltipOwner)) then
    GameTooltip:Hide()
  end
  itemTooltipOwner = nil
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
    savedCharacterData().dismissed[hint.id] = true
    EQ.RefreshInterface()
  end)
  row.quest = button(body, 'EfficientQuestsQuest'..index, L.quest, 52, 20, function()
    local hint = shownHints[index]; if hint then openQuest(hint) end
  end)
  row.item = button(body, 'EfficientQuestsItem'..index, L.item, 48, 20, function(self)
    local hint = shownHints[index]; if hint then openItem(hint, self) end
  end)
  row.item:SetScript('OnLeave', closeItemTooltip)
  row.map = button(body, 'EfficientQuestsMap'..index, L.map, 48, 20, function()
    local hint = shownHints[index]; if hint then openMap(hint) end
  end)
  rows[index] = row
  return row
end

local function showOrHide(widget, visible)
  if visible then widget:Show() else widget:Hide() end
end

-- One restore control per dismissed hint, so recovering one hint never
-- wipes the character's other dismissals.
local function makeDismissedRow(index)
  local row = {}
  row.label = text(settings, 'EfficientQuestsDismissedLabel'..index)
  row.label:SetWidth(290)
  row.restore = button(settings, 'EfficientQuestsRestoreHint'..index, L.restoreHint, 66, 22, function()
    if row.hintID then
      savedCharacterData().dismissed[row.hintID] = nil
      EQ.RefreshInterface()
    end
  end)
  dismissedRows[index] = row
  return row
end

local function refreshSettings()
  if not settings then return end
  local data = savedCharacterData()
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
    (#dismissedEntries > 0 and 'Restore individual hints, or restore them all.' or L.none)))
  for index = 1, math.max(#dismissedRows, dismissed and #dismissedEntries or 0) do
    local row = dismissedRows[index]
    local entry = dismissed and dismissedEntries[index] or nil
    if entry then
      if not row then row = makeDismissedRow(index) end
      row.hintID = entry.id
      row.label:SetText(entry.text or '')
      row.label:SetPoint('TOPLEFT', settings, 'TOPLEFT', 160, -262 - (index - 1) * 30)
      row.restore:SetPoint('TOPLEFT', settings, 'TOPLEFT', 462, -258 - (index - 1) * 30)
      row.label:Show(); row.restore:Show()
    elseif row then
      row.hintID = nil
      row.label:Hide(); row.restore:Hide()
    end
  end
end

-- FlareUI exposes its holder as a named frame. Its scroll child follows both
-- manual and automatic minimization, including the header-only style.
local function trackerScroll(tracker)
  if not tracker.GetChildren then return nil end
  for _, child in ipairs({tracker:GetChildren()}) do
    if child.GetObjectType and child:GetObjectType() == 'ScrollFrame' then return child end
  end
end

local function trackerFor(display)
  if display.mode ~= 'flare' then return nil end
  local tracker = _G.FlareUI_ObjectiveTracker
  if not tracker or not tracker.GetWidth or not tracker.GetEffectiveScale or not trackerScroll(tracker) then return nil end
  local width = tracker:GetWidth()
  if type(width) ~= 'number' or width <= 0 then return nil end
  return tracker
end

local function effectiveWidth(tracker, fallback)
  if not tracker then return fallback end
  local scale = tracker:GetEffectiveScale()
  local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()
  if type(scale) ~= 'number' or type(parentScale) ~= 'number' or parentScale <= 0 then return fallback end
  return tracker:GetWidth() * scale / parentScale
end

local function copyTrackerAppearance(tracker)
  if not tracker then
    if frame.SetBackdrop then frame:SetBackdrop(nil) end
    if background then background:Show() end
    return
  end
  local backdrop = tracker.GetBackdrop and tracker:GetBackdrop()
  if backdrop and frame.SetBackdrop then
    frame:SetBackdrop(backdrop)
    if tracker.GetBackdropColor and frame.SetBackdropColor then frame:SetBackdropColor(tracker:GetBackdropColor()) end
    if tracker.GetBackdropBorderColor and frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(tracker:GetBackdropBorderColor()) end
    if background then background:Hide() end
  else
    if frame.SetBackdrop then frame:SetBackdrop(nil) end
    if background then background:Show() end
  end
end

local function trackerFonts(tracker)
  if not tracker or not tracker.GetChildren then return nil, nil end
  local heading, content
  for _, child in ipairs({tracker:GetChildren()}) do
    if child.title and child.title.GetFont then heading = child.title end
    if child.GetObjectType and child:GetObjectType() == 'ScrollFrame' and child.GetScrollChild then
      local container = child:GetScrollChild()
      if container and container.GetChildren then
        for _, line in ipairs({container:GetChildren()}) do
          if line.text and line.text.GetFont and (not line.IsShown or line:IsShown()) then content = line.text; break end
        end
      end
    end
  end
  return heading, content or heading
end

local originalFonts = setmetatable({}, {__mode='k'})
local function applyFont(target, source)
  if not target or not target.GetFont or not target.SetFont then return end
  if not originalFonts[target] then
    local path, size, flags = target:GetFont()
    if not path then return end
    local r, g, b, a
    if target.GetTextColor then r, g, b, a = target:GetTextColor() end
    originalFonts[target] = {path, size, flags, r, g, b, a}
  end
  local font = originalFonts[target]
  if source and source.GetFont then
    local path, size, flags = source:GetFont()
    if path and size then target:SetFont(path, size, flags or '') end
    if source.GetTextColor and target.SetTextColor then target:SetTextColor(source:GetTextColor()) end
  else
    target:SetFont(font[1], font[2], font[3] or '')
    if font[4] and target.SetTextColor then target:SetTextColor(font[4], font[5], font[6], font[7]) end
  end
end

local function applyTrackerFonts(tracker)
  local heading, content = trackerFonts(tracker)
  applyFont(title, heading)
  applyFont(status, content)
  for _, row in ipairs(rows) do
    local label = row.hint.GetFontString and row.hint:GetFontString()
    applyFont(label, content)
    applyFont(row.detail, content)
  end
end

local function trackerSignature(display)
  local tracker = trackerFor(display)
  if not tracker then return tostring(display.mode) .. ':fallback' end
  local list = trackerScroll(tracker)
  local header, content = trackerFonts(tracker)
  local function fontKey(font)
    if not font or not font.GetFont then return '' end
    local face, size, flags = font:GetFont()
    local r, g, b, a
    if font.GetTextColor then r,g,b,a = font:GetTextColor() end
    return table.concat({tostring(face), tostring(size), tostring(flags), tostring(r), tostring(g), tostring(b), tostring(a)}, ':')
  end
  local backdrop = tracker.GetBackdrop and tracker:GetBackdrop()
  local r,g,b,a, br,bg,bb,ba
  if tracker.GetBackdropColor then r,g,b,a = tracker:GetBackdropColor() end
  if tracker.GetBackdropBorderColor then br,bg,bb,ba = tracker:GetBackdropBorderColor() end
  return table.concat({tostring(tracker), tostring(tracker:GetWidth()),
    tostring(tracker.GetTop and tracker:GetTop()), tostring(tracker.GetBottom and tracker:GetBottom()),
    tostring(tracker:GetEffectiveScale()), tostring(not tracker.IsVisible or tracker:IsVisible()),
    tostring(not list or not list.IsShown or list:IsShown()), tostring(backdrop and backdrop.bgFile),
    tostring(backdrop and backdrop.edgeFile), tostring(backdrop and backdrop.edgeSize),
    tostring(r), tostring(g), tostring(b), tostring(a), tostring(br), tostring(bg), tostring(bb), tostring(ba),
    fontKey(header), fontKey(content)}, '|')
end

local function placeWindow(tracker, display)
  frame:ClearAllPoints()
  if not tracker then
    local p = display.position
    if p and p.point and p.relativePoint and type(p.x) == 'number' and type(p.y) == 'number' then
      frame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
    else
      frame:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT', -30, -180)
    end
    frame:Show()
    return
  end
  local scale = tracker:GetEffectiveScale()
  local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()
  local bottom = tracker.GetBottom and tracker:GetBottom()
  local height = frame.GetHeight and frame:GetHeight()
  local above = type(bottom) == 'number' and type(height) == 'number' and type(scale) == 'number'
    and type(parentScale) == 'number' and parentScale > 0 and bottom * scale / parentScale < height + display.spacing
  if above then frame:SetPoint('BOTTOMLEFT', tracker, 'TOPLEFT', 0, display.spacing)
  else frame:SetPoint('TOPLEFT', tracker, 'BOTTOMLEFT', 0, -display.spacing) end
  local visible = not tracker.IsVisible or tracker:IsVisible()
  local list = trackerScroll(tracker)
  if list and list.IsShown and not list:IsShown() then visible = false end
  showOrHide(frame, visible)
end

function EQ.RefreshInterface()
  if not frame then return end
  closeItemTooltip()
  local data = savedCharacterData()
  local tracker = trackerFor(data.display)
  local width = effectiveWidth(tracker, data.display.width)
  frame:SetWidth(width)
  copyTrackerAppearance(tracker)
  local guide = selectedGuide()
  local hints, problem = EQ.GetHints(guide)
  hints = hints or {}
  local available = {}
  for _, hint in ipairs(hints) do
    if hint.id and not data.dismissed[hint.id] then available[#available + 1] = hint end
  end
  dismissedEntries = {}
  for _, hint in ipairs(hints) do
    if hint.id and data.dismissed[hint.id] then dismissedEntries[#dismissedEntries + 1] = hint end
  end
  local statusText
  if problem == 'missing' then statusText = L.missing
  elseif problem == 'incompatible' then statusText = L.incompatible
  elseif problem == 'guide' then
    if guide and not EQ.guides[guide] then statusText = L.unavailable
    else statusText = EQ.GetSetupStatus and EQ.GetSetupStatus() or L.noGuide end
  end
  status:SetWidth(math.max(1, width - 16))
  status:SetText(statusText or '')
  showOrHide(status, statusText ~= nil)
  showOrHide(body, #available > 0 and not statusText)
  showOrHide(scroll, #available > 0 and not statusText)
  local lastPage = math.max(0, math.ceil(#available / 3) - 1)
  page = math.min(page, lastPage)
  local count = math.min(3, #available - page * 3)
  shownHints = {}
  local y = -3
  for i=1,count do
    local hint, row = available[page * 3 + i], rows[i] or makeRow(i)
    local _, contentFont = trackerFonts(tracker)
    applyFont(row.hint.GetFontString and row.hint:GetFontString(), contentFont)
    applyFont(row.detail, contentFont)
    shownHints[i] = hint
    row.hint:ClearAllPoints(); row.hint:SetPoint('TOPLEFT', body, 'TOPLEFT', 0, y)
    local hintWidth = math.max(120, width - 92)
    row.hint:SetWidth(hintWidth); row.hint:SetText(hint.text or '')
    local hintFont = row.hint:GetFontString()
    if hintFont then
      hintFont:SetWidth(hintWidth - 16)
      hintFont:SetWordWrap(true)
      hintFont:SetJustifyH('LEFT')
    end
    local hintHeight = math.max(36, (hintFont and hintFont:GetStringHeight() or 0) + 12)
    row.hint:SetHeight(hintHeight)
    row.dismiss:ClearAllPoints(); row.dismiss:SetPoint('TOPRIGHT', body, 'TOPRIGHT', 0, y)
    row.hint:Show(); row.dismiss:Show()
    y = y - hintHeight - 2
    local open = expanded[hint.id] == true
    row.detail:SetText(open and details(hint) or '')
    row.detail:ClearAllPoints(); row.detail:SetPoint('TOPLEFT', body, 'TOPLEFT', 4, y)
    row.detail:SetWidth(width - 20)
    showOrHide(row.detail, open)
    local detailHeight = open and math.max(32, row.detail:GetStringHeight() or 0) or 0
    row.detail:SetHeight(math.max(1, detailHeight))
    row.quest:ClearAllPoints(); row.quest:SetPoint('TOPLEFT', body, 'TOPLEFT', 4, y - detailHeight - 3)
    row.item:ClearAllPoints(); row.item:SetPoint('LEFT', row.quest, 'RIGHT', 3, 0)
    row.map:ClearAllPoints(); row.map:SetPoint('LEFT', row.item, 'RIGHT', 3, 0)
    showOrHide(row.quest, open and hint.questID ~= nil and QuestMapFrame_OpenToQuestDetails ~= nil)
    showOrHide(row.item, open and hint.verifiedItemID ~= nil and GameTooltip ~= nil)
    local context = EQ.GetContext()
    local localMap = hint.location and context.zoneID and context.zoneName and hint.location.zone and
      hint.location.zone:lower() == context.zoneName:lower() and WorldMapFrame and WorldMapFrame.SetMapID
    showOrHide(row.map, open and localMap)
    if open then y = y - detailHeight - 27 end
  end
  for i=count+1,#rows do
    local row = rows[i]
    for _, widget in pairs(row) do widget:Hide() end
  end
  more:SetText(page == lastPage and page > 0 and L.first or L.more)
  showOrHide(more, #available > 3)
  local contentHeight = math.max(1, -y)
  local viewportHeight = math.min(400, contentHeight)
  body:SetWidth(width - 16); body:SetHeight(contentHeight)
  scroll:SetSize(width - 16, viewportHeight)
  scrollRange = math.max(0, contentHeight - viewportHeight)
  if scroll:GetVerticalScroll() > scrollRange then scroll:SetVerticalScroll(scrollRange) end
  frame:SetHeight(46 + (statusText and 28 or (#available > 0 and viewportHeight or 0)))
  applyTrackerFonts(tracker)
  placeWindow(tracker, data.display)
  refreshSettings()
end

function EQ.ShowSettings()
  if not settings then return end
  if settings:IsShown() then settings:Hide() else refreshSettings(); settings:Show() end
end

local function build()
  if frame then return end
  frame = CreateFrame('Frame', 'EfficientQuestsWindow', UIParent, 'BackdropTemplate')
  local position = savedCharacterData().display.position
  if position and position.point and position.relativePoint and type(position.x) == 'number' and type(position.y) == 'number' then
    frame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
  else
    frame:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT', -30, -180)
  end
  frame:SetSize(340, 46); frame:SetMovable(true); frame:EnableMouse(true)
  frame:RegisterForDrag('LeftButton'); frame:SetClampedToScreen(true)
  local dragging = false
  frame:SetScript('OnDragStart', function(self)
    if not trackerFor(savedCharacterData().display) then dragging = true; self:StartMoving() end
  end)
  frame:SetScript('OnHide', function() closeItemTooltip() end)
  frame:SetScript('OnDragStop', function(self)
    if not dragging then return end
    dragging = false
    self:StopMovingOrSizing()
    if trackerFor(savedCharacterData().display) then return end
    local point, _, relativePoint, x, y = self:GetPoint()
    savedCharacterData().display.position = {point=point, relativePoint=relativePoint, x=x, y=y}
  end)
  background = frame:CreateTexture(nil, 'BACKGROUND')
  background:SetAllPoints(frame); background:SetColorTexture(0.06, 0.06, 0.08, 0.88)
  title = text(frame, nil, 'GameFontNormal'); title:SetPoint('TOPLEFT', frame, 'TOPLEFT', 8, -8); title:SetText(L.title)
  local configure = button(frame, 'EfficientQuestsOpenSettings', L.settings, 68, 22, EQ.ShowSettings)
  configure:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -4, -4)
  more = button(frame, 'EfficientQuestsMore', L.more, 50, 22, function()
    local guide = selectedGuide()
    local hints = EQ.GetHints(guide) or {}
    local count = 0
    for _, hint in ipairs(hints) do if hint.id and not savedCharacterData().dismissed[hint.id] then count = count + 1 end end
    page = (page + 1) % math.max(1, math.ceil(count / 3))
    EQ.RefreshInterface()
  end)
  more:SetPoint('RIGHT', configure, 'LEFT', -4, 0)
  status = text(frame, 'EfficientQuestsStatus'); status:SetPoint('TOPLEFT', frame, 'TOPLEFT', 8, -32); status:SetWidth(320)
  scroll = CreateFrame('ScrollFrame', 'EfficientQuestsScroll', frame)
  scroll:SetPoint('TOPLEFT', frame, 'TOPLEFT', 8, -32)
  scroll:SetSize(324, 1); scroll:EnableMouseWheel(true)
  scroll:SetScript('OnMouseWheel', function(self, delta)
    self:SetVerticalScroll(math.max(0, math.min(scrollRange, self:GetVerticalScroll() - delta * 40)))
  end)
  body = CreateFrame('Frame', 'EfficientQuestsBody', scroll)
  body:SetSize(324, 1); scroll:SetScrollChild(body)

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
    local data = savedCharacterData(); local current = selectedGuide(); local nextIndex = 1
    for i, name in ipairs(names) do if name == current then nextIndex = i % #names + 1; break end end
    data.guide = names[nextIndex]; page = 0; EQ.RefreshInterface()
  end)
  guideButton:SetPoint('TOPLEFT', settings, 'TOPLEFT', 160, -82)
  modeButton = button(settings, 'EfficientQuestsMode', '', 170, 25, function()
    local display = savedCharacterData().display
    display.mode = display.mode == 'flare' and 'standalone' or 'flare'; EQ.RefreshInterface()
  end)
  modeButton:SetPoint('TOPLEFT', settings, 'TOPLEFT', 160, -115)
  widthLabel = text(settings, nil); widthLabel:SetPoint('TOPLEFT', settings, 'TOPLEFT', 160, -152)
  widthLess = button(settings, 'EfficientQuestsWidthLess', '−', 26, 22, function()
    local d=savedCharacterData().display; d.width=math.max(240, d.width-20); EQ.RefreshInterface()
  end); widthLess:SetPoint('TOPLEFT', settings, 'TOPLEFT', 320, -148)
  widthMore = button(settings, 'EfficientQuestsWidthMore', '+', 26, 22, function()
    local d=savedCharacterData().display; d.width=math.min(600, d.width+20); EQ.RefreshInterface()
  end); widthMore:SetPoint('LEFT', widthLess, 'RIGHT', 4, 0)
  spacingLabel = text(settings, nil); spacingLabel:SetPoint('TOPLEFT', settings, 'TOPLEFT', 160, -185)
  spacingLess = button(settings, 'EfficientQuestsSpacingLess', '−', 26, 22, function()
    local d=savedCharacterData().display; d.spacing=math.max(0, d.spacing-2); EQ.RefreshInterface()
  end); spacingLess:SetPoint('TOPLEFT', settings, 'TOPLEFT', 320, -181)
  spacingMore = button(settings, 'EfficientQuestsSpacingMore', '+', 26, 22, function()
    local d=savedCharacterData().display; d.spacing=math.min(100, d.spacing+2); EQ.RefreshInterface()
  end); spacingMore:SetPoint('LEFT', spacingLess, 'RIGHT', 4, 0)
  restore = button(settings, 'EfficientQuestsRestore', L.restore, 200, 25, function()
    savedCharacterData().dismissed = {}; EQ.RefreshInterface(); settingsNote:SetText(L.restored)
  end); restore:SetPoint('TOPLEFT', settings, 'TOPLEFT', 160, -225)
  settings:Hide()
end

if UIParent then
  local events = CreateFrame('Frame')
  for _, event in ipairs({'PLAYER_LOGIN', 'PLAYER_ENTERING_WORLD', 'BAG_UPDATE_DELAYED',
    'QUEST_LOG_UPDATE', 'QUEST_TURNED_IN', 'SUPER_TRACKED_QUEST_CHANGED',
    'ZONE_CHANGED_NEW_AREA', 'TAXIMAP_OPENED', 'TAXIMAP_CLOSED',
    'TAXI_NODE_STATUS_CHANGED', 'BANKFRAME_OPENED', 'BANKFRAME_CLOSED', 'PLAYERBANKSLOTS_CHANGED', 'ADDON_LOADED'}) do
    pcall(events.RegisterEvent, events, event)
  end
  events:SetScript('OnEvent', function(_, event)
    if event == 'PLAYER_LOGIN' and UIParent then build() end
    if frame then EQ.RefreshInterface() end
  end)
  local sinceUpdate, lastTrackerSignature, lastPosition = 0, nil, nil
  -- Polling is required because the client does not emit an event whenever the
  -- player crosses a quest-distance band. Ignore small movement to avoid
  -- repeatedly rebuilding the display while the player is standing nearby.
  local function playerMoved()
    if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then return false end
    local map = C_Map.GetBestMapForUnit('player')
    local position = map and C_Map.GetPlayerMapPosition(map, 'player')
    if not position or not position.GetXY then return false end
    local x, y = position:GetXY()
    if type(x) ~= 'number' or type(y) ~= 'number' then return false end
    local changed = not lastPosition or lastPosition.map ~= map
    if not changed then
      local dx, dy = x - lastPosition.x, y - lastPosition.y
      local width, height
      if C_Map.GetMapWorldSize then width, height = C_Map.GetMapWorldSize(map) end
      if type(width) == 'number' and type(height) == 'number' and width > 0 and height > 0 then
        changed = (dx * width)^2 + (dy * height)^2 >= 25^2
      else
        changed = dx * dx + dy * dy >= 0.005^2
      end
    end
    if changed then lastPosition = {map=map, x=x, y=y} end
    return changed
  end
  events:SetScript('OnUpdate', function(_, elapsed)
    if not frame then return end
    sinceUpdate = sinceUpdate + elapsed
    if sinceUpdate < 0.5 then return end
    sinceUpdate = 0
    local signature = trackerSignature(savedCharacterData().display)
    local moved = playerMoved()
    if signature ~= lastTrackerSignature or moved then
      lastTrackerSignature = signature
      EQ.RefreshInterface()
    end
  end)
end
