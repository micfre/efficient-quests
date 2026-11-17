-- The dungeon guide window of Efficient Quests: the window the dungeon
-- guide (see DungeonGuide.lua) shows while the player is inside a dungeon
-- the data knows. It lists the dungeon's stops in order -- every stop
-- with its kind, its name, and its optional mark -- and expands the
-- current stop with its approach text, its boss mechanics, and the quests
-- the dungeon helps with. The guide owns the run and the completion
-- answers; this module renders them and never decides them: it asks the
-- guide for the running guide, whether a stop is done, and which stop is
-- current, and the right-click mark hands the decision back to the guide.
--
-- The look. The flat dark plate with the thin bronze edge is the look
-- module's, the look every window of the addon wears. The rows come out
-- of a pool and go back into it hidden, the way the step window treats
-- its rows. Window sizes and layouts stay here.
--
-- The public surface, for the dungeon guide:
--
--   Show()     build the window on first use and leave it on the screen.
--   Hide()     take the window off the screen, the same as its X control.
--   IsShown()  whether the window is on the screen right now.
--   refresh()  bring the window in line with the run. The guide calls
--              this on start, on every kill, every mark, and every quest
--              state change while it runs. A window the player took down
--              with its X stays down: only the next start brings it back.

local look = EfficientQuests.look
local reader = EfficientQuests.questState

local window = {}
EfficientQuests.dungeonGuideWindow = window

-- The layout steps of the body; one row of the body is one line of text.
local WIDTH = 280
local HEADER, LINE, HEADLINE, PAD = 36, 18, 20, 12

-- The verb of each kind, the word that tells the player what to do there.
local VERBS = { boss = "Kill", rare = "Rare", spot = "Find", event = "Talk to" }

local frame        -- the window frame, built on first start
local titleText    -- the dungeon's name
local levelsText   -- the level range line under it
local body         -- the rows of the stop list
local pool, usedRows = {}, {}

local function newRow()
    local row = CreateFrame("Button", nil, body)
    row:SetSize(WIDTH - 24, LINE)
    row.tick = CreateFrame("CheckButton", nil, row)
    row.tick:SetSize(13, 13)
    row.tick:SetPoint("LEFT", row, "LEFT", 3, 0)
    local mark = row.tick:CreateTexture(nil, "ARTWORK")
    mark:SetAllPoints(row.tick)
    mark:SetColorTexture(1, 0.82, 0.2, 1)
    row.tick:SetCheckedTexture(mark)
    row.tick:SetEnabled(false)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row, "LEFT", 24, 0)
    row.text:SetJustifyH("LEFT")
    return row
end

local function takeRow(at)
    local row = table.remove(pool) or newRow()
    row:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -((at - 1) * LINE))
    row:Show()
    table.insert(usedRows, row)
    return row
end

-- One stop row: the verb of its kind, its name, and the optional mark.
-- The tick fills when the stop is done, and a right-click is the hand
-- mark: done on the first click, undone on the second.
local function setStopRow(row, stop)
    local guide = EfficientQuests.dungeonGuide
    row.tick:SetShown(true)
    row.tick:SetChecked(guide.StopDone(stop) == true)
    row.text:SetPoint("LEFT", row, "LEFT", 24, 0)
    row.text:SetTextColor(1, 1, 1, 1)
    local words = (VERBS[stop.kind] or "See") .. " " .. stop.name
    if stop.optional then words = words .. " (optional)" end
    row.text:SetText(words)
    row:SetScript("OnClick", function(_, mouseButton)
        if mouseButton ~= "RightButton" then return end
        guide.MarkStop(stop.npc, guide.StopDone(stop) and "undo" or "done")
    end)
end

-- One detail line under the open stop: a title or level line in the
-- muted bronze, an approach line, or a mechanics line in the warning
-- color. Detail lines carry no tick box.
local function setDetailRow(row, text, color, indent)
    row.tick:SetShown(false)
    row.text:SetPoint("LEFT", row, "LEFT", indent, 0)
    row.text:SetTextColor(color[1], color[2], color[3], 1)
    row.text:SetText(text)
end

local function releaseRows()
    for _, row in ipairs(usedRows) do
        row:Hide()
        row:SetScript("OnClick", nil)
        table.insert(pool, row)
    end
    usedRows = {}
end

-- The meta line of a stop: its title and its level, joined with a dot.
local function metaOf(stop)
    local parts = {}
    if type(stop.title) == "string" then table.insert(parts, stop.title) end
    if type(stop.level) == "number" then
        table.insert(parts, "Level " .. stop.level)
    end
    return #parts > 0 and table.concat(parts, " · ") or nil
end

-- The quests the stops of a guide ask for, in the order the stops meet
-- them: each stop's own quest, its follow-up, and the quests it helps
-- with, each id once.
local function questsOf(stops)
    local ids, seen = {}, {}
    local function add(id)
        if type(id) == "number" and not seen[id] then
            seen[id] = true
            table.insert(ids, id)
        end
    end
    for _, stop in ipairs(stops) do
        add(stop.quest)
        add(stop.follow)
        for _, id in ipairs(type(stop.quests) == "table" and stop.quests or {}) do
            add(id)
        end
    end
    return ids
end

local function build()
    frame = CreateFrame("Frame", "EfficientQuestsDungeonGuide", UIParent)
    frame:SetWidth(WIDTH)
    look.applyBackdrop(frame)
    frame:SetClampedToScreen(true)

    local hide = CreateFrame("Button", nil, frame)
    hide:SetSize(20, 20)
    hide:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
    local hideLabel = hide:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hideLabel:SetAllPoints(hide)
    hideLabel:SetText("X")
    hide:SetScript("OnClick", function() frame:Hide() end)

    titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
    titleText:SetJustifyH("LEFT")

    levelsText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    levelsText:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -HEADER + 4)
    levelsText:SetJustifyH("LEFT")
    levelsText:SetTextColor(look.ACCENT[1], look.ACCENT[2], look.ACCENT[3], 1)

    body = CreateFrame("Frame", "EfficientQuestsDungeonGuideStops", frame)
    body:SetWidth(WIDTH - 24)
    body:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -(HEADER + HEADLINE))
end

--- Bring the window in line with the run. The guide calls this on start,
--- on every kill, every mark, and every quest state change while it runs.
--- A window the player took down with its X stays down: only the next
--- start brings it back.
function window.refresh()
    if not frame or not frame:IsShown() then return end
    local guide = EfficientQuests.dungeonGuide
    local active = guide.GetActiveGuide()
    if not active then return end
    local dungeon = active.guide
    releaseRows()
    titleText:SetText(EfficientQuests.DungeonName(active.key, dungeon))
    levelsText:SetText(type(dungeon.levels) == "string"
        and ("Levels " .. dungeon.levels) or "")
    local stops = dungeon.stops or {}
    local rows = 0
    local open = guide.CurrentIndex(stops)
    for at, stop in ipairs(stops) do
        rows = rows + 1
        setStopRow(takeRow(rows), stop)
        if at == open then
            local meta = metaOf(stop)
            if meta then
                rows = rows + 1
                setDetailRow(takeRow(rows), meta, look.ACCENT, 24)
            end
            for _, line in ipairs(type(stop.approach) == "table" and stop.approach or {}) do
                rows = rows + 1
                setDetailRow(takeRow(rows), line, look.NOTE, 24)
            end
            for _, line in ipairs(type(stop.mechanics) == "table" and stop.mechanics or {}) do
                rows = rows + 1
                setDetailRow(takeRow(rows), line, look.WARN, 24)
            end
        end
    end
    if stops[1] and not open then
        rows = rows + 1
        setDetailRow(takeRow(rows),
            "Every stop is done. Leave the dungeon to go back to your route.",
            look.DONE, 4)
        local left = {}
        for _, each in ipairs(stops) do
            if not guide.StopDone(each) then table.insert(left, each.name) end
        end
        if #left > 0 then
            rows = rows + 1
            setDetailRow(takeRow(rows),
                "Not done (optional): " .. table.concat(left, ", ") .. ".",
                look.WARN, 4)
        end
    end
    -- The quests the dungeon helps with (user story 62), named through
    -- the quest state reader's lookup chain: the data store first, a
    -- fallback later, the id itself when neither knows the name.
    local quests = questsOf(stops)
    if #quests > 0 then
        rows = rows + 1
        setDetailRow(takeRow(rows), "Quests here", look.ACCENT, 4)
        for _, questID in ipairs(quests) do
            rows = rows + 1
            setDetailRow(takeRow(rows), reader.QuestName(questID)
                or ("Quest " .. questID), look.NOTE, 20)
        end
    end
    body:SetHeight(rows * LINE)
    frame:SetHeight(HEADER + HEADLINE + rows * LINE + PAD)
end

--- Build the window on first use and leave it on the screen.
function window.Show()
    if not frame then build() end
    frame:Show()
end

--- Take the window off the screen, the same as its X control.
function window.Hide()
    if frame then frame:Hide() end
end

--- Whether the window is on the screen right now.
function window.IsShown()
    return frame ~= nil and frame:IsShown() == true
end
