-- The menu of Efficient Quests. It is a small window that opens beside the
-- step window: the step window calls Menu.Open with itself as the anchor,
-- and the menu's top left goes to the anchor's top right. Without an anchor
-- -- when no window is on the screen yet -- the menu sits at a fixed spot:
-- the same top-left corner of the screen that the saved data holds as the
-- window's default spot. The menu lists the quests this character has
-- skipped, each with a restore action, the dungeons the data store knows,
-- and a link that opens the options panel.
local _, ns = ...
local EQ = EfficientQuests

-- The FlareUI palette cues, as the options panel uses them: the bronze
-- border, the muted bronze of the section labels, and the near-black of
-- the plates.
local BORDER = { 0.65, 0.49, 0.27 }
local ACCENT = { 0.61, 0.48, 0.29 }
local PLATE = { 0.08, 0.08, 0.09 }
local WIDTH = 260
-- The layout runs in fixed steps: a title band, one line per section
-- label, one line per list row, and air at the bottom.
local HEADER, SECTION, ROW, PAD = 34, 20, 16, 14

local menu
local questBlock -- holds the rows of the moment under the section label
local pool = {} -- quest rows from earlier refreshes, hidden and reusable
local usedRows = {} -- the quest rows on screen right now
local emptyLine -- the plain sentence for an empty list, reused
local dungeonRows = {} -- one row per known dungeon, built once

-- The names of the dungeons, in our own words from the guide texts. The
-- generated guide table carries a short key and a level range per dungeon
-- but no display name; wings that the guide finds by name carry theirs in
-- their names list, and the key stands in for anything still unknown.
local DUNGEON_NAMES = {
  [389] = "Ragefire Chasm", [43] = "Wailing Caverns", [48] = "Blackfathom Deeps",
  [33] = "Shadowfang Keep", [47] = "Razorfen Kraul", [36] = "The Deadmines",
  [90] = "Gnomeregan", [129] = "Razorfen Downs", [70] = "Uldaman",
  [349] = "Maraudon", [209] = "Zul'Farrak", [109] = "The Sunken Temple",
  [34] = "The Stockade", [289] = "Scholomance", [230] = "Blackrock Depths",
  [1891] = "Scarlet Monastery: Graveyard", [1892] = "Scarlet Monastery: Library",
  [1893] = "Scarlet Monastery: Armory", [1894] = "Scarlet Monastery: Cathedral",
  [3291] = "Stratholme: Main Gate", [3292] = "Stratholme: Service Gate",
  [2291] = "Lower Blackrock Spire", [2292] = "Upper Blackrock Spire",
  [4291] = "Dire Maul: East", [4292] = "Dire Maul: West", [4293] = "Dire Maul: North",
  [2999] = "Ruins of Lordaeron",
}

-- The line the player reads for one dungeon: its name and its level
-- range, as the place text of the steps joins its facts with a dot.
local function dungeonLabel(instanceId, guide)
  local name = DUNGEON_NAMES[instanceId]
    or (type(guide.names) == "table" and type(guide.names[1]) == "string" and guide.names[1])
    or (type(guide.key) == "string" and guide.key)
    or tostring(instanceId)
  if type(guide.levels) == "string" then
    return name .. " · " .. guide.levels
  end
  return name
end

-- The name of a quest, from the generated quest table of the namespace.
-- When the data store reported the table broken, or a quest id is not in
-- it, the id itself stands in, so the menu still opens without an error.
local function questName(questId)
  local quest = type(ns.quests) == "table" and ns.quests[questId] or nil
  if type(quest) == "table" and type(quest[1]) == "string" then
    return quest[1]
  end
  return "Quest " .. questId
end

-- A flat dark plate with a thin bronze edge, the look the options panel
-- gives the addon's windows.
local function applyBackdrop(frame)
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, tileSize = 0, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  frame:SetBackdropColor(PLATE[1], PLATE[2], PLATE[3], 0.95)
  frame:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], 1)
end

local function sectionLabel(text, below)
  local label = menu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -6)
  label:SetJustifyH("LEFT")
  label:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
  label:SetText(text)
  return label
end

-- The known dungeons in the order a player meets them: by the level their
-- guide starts at, and by instance id where those agree.
local function knownDungeons()
  local ids = {}
  for instanceId, guide in pairs(ns.DungeonGuides) do
    table.insert(ids, { id = instanceId, guide = guide })
  end
  local function startsAt(entry)
    local level = type(entry.guide.levels) == "string"
      and tonumber(entry.guide.levels:match("^%d+")) or nil
    return level or math.huge
  end
  table.sort(ids, function(a, b)
    local mine, theirs = startsAt(a), startsAt(b)
    if mine ~= theirs then return mine < theirs end
    return a.id < b.id
  end)
  return ids
end

local function build()
  menu = CreateFrame("Frame", "EfficientQuestsMenu", UIParent)
  menu:SetSize(WIDTH, 200)
  applyBackdrop(menu)
  -- Above the step window, the way a menu the player asked for belongs.
  menu:SetFrameStrata("HIGH")

  local title = menu:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOPLEFT", menu, "TOPLEFT", 12, -8)
  title:SetJustifyH("LEFT")
  title:SetText("Efficient Quests")

  local questsLabel = sectionLabel("Skipped quests", title)
  questBlock = CreateFrame("Frame", nil, menu)
  questBlock:SetPoint("TOPLEFT", questsLabel, "BOTTOMLEFT", 0, -4)
  questBlock:SetWidth(WIDTH - 24)

  -- The dungeon rows hang under the quest block, so they follow wherever
  -- the skipped-quest list ends. A broken dungeon guide table leaves the
  -- section out; the data store has said its message already.
  if type(ns.DungeonGuides) == "table" then
    local dungeonsLabel = sectionLabel("Dungeon guides", questBlock)
    local block = CreateFrame("Frame", nil, menu)
    block:SetPoint("TOPLEFT", dungeonsLabel, "BOTTOMLEFT", 0, -4)
    block:SetWidth(WIDTH - 24)
    local anchor = block
    for at, entry in ipairs(knownDungeons()) do
      local row = CreateFrame("Frame", nil, block)
      row:SetSize(WIDTH - 24, ROW)
      if at == 1 then
        row:SetPoint("TOPLEFT", block, "TOPLEFT", 0, 0)
      else
        row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 0)
      end
      local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      label:SetPoint("LEFT", row, "LEFT", 0, 0)
      label:SetJustifyH("LEFT")
      label:SetText(dungeonLabel(entry.id, entry.guide))
      anchor = row
      dungeonRows[at] = row
    end
  end
end

-- The window is as tall as its content: the bands and rows stack up to
-- the bottom padding.
local function layout()
  local height = HEADER + SECTION + math.max(#usedRows, 1) * ROW
  if #dungeonRows > 0 then
    height = height + SECTION + #dungeonRows * ROW
  end
  menu:SetSize(WIDTH, height + PAD)
end

-- One row of the skipped-quest list: the quest's name on the left, its
-- restore action on the right, and one click anywhere on the row restores
-- the quest. Rows come out of the pool and go back into it hidden.
local function takeRow(at)
  local row = table.remove(pool) or CreateFrame("Button", nil, questBlock)
  row:SetSize(WIDTH - 24, ROW)
  row:SetPoint("TOPLEFT", questBlock, "TOPLEFT", 0, -((at - 1) * ROW))
  if not row.name then
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.name:SetJustifyH("LEFT")
    row.restore = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.restore:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.restore:SetJustifyH("RIGHT")
    -- The gold of a link, the way the client marks words the player can
    -- act on.
    row.restore:SetTextColor(1, 0.82, 0.2, 1)
    row.restore:SetText("Restore")
  end
  return row
end

-- Bring the skipped-quest list in line with the store. The rows of the
-- earlier refresh hide and go back into the pool; the block then holds
-- either one row per skipped quest or the plain sentence that nothing is
-- skipped.
local function refreshQuests()
  for _, row in ipairs(usedRows) do
    row:Hide()
    table.insert(pool, row)
  end
  usedRows = {}
  if emptyLine then emptyLine:Hide() end
  local ids = EfficientQuests.characterStore.list()
  for at, questId in ipairs(ids) do
    local row = takeRow(at)
    row.name:SetText(questName(questId))
    row:SetScript("OnClick", function()
      EfficientQuests.characterStore.restore(questId)
      refreshQuests()
    end)
    row:Show()
    table.insert(usedRows, row)
  end
  if #usedRows == 0 then
    if not emptyLine then
      emptyLine = questBlock:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      emptyLine:SetPoint("TOPLEFT", questBlock, "TOPLEFT", 0, 0)
      emptyLine:SetJustifyH("LEFT")
      emptyLine:SetText("You have not skipped any quests.")
    end
    emptyLine:Show()
  end
  questBlock:SetHeight(math.max(#usedRows, 1) * ROW)
end

EQ.Menu = {}

-- The one entry point into the menu. The step window hands itself as the
-- anchor; anything else can call without one. Open builds the window on
-- first use, puts it beside the anchor or at the fixed spot, and leaves it
-- open on the screen.
function EQ.Menu.Open(anchor)
  if not menu then build() end
  refreshQuests()
  layout()
  menu:ClearAllPoints()
  if anchor then
    menu:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 10, 0)
  else
    menu:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -120)
  end
  menu:Show()
  return menu
end
