-- The step window of Efficient Quests. It is the addon's face: a flat,
-- draggable window that shows one step at a time -- the headline, the goal
-- lines with their tick boxes and counts, the tips, the place text, the
-- "hunts in one area" block, the reward names with their hover tooltips,
-- and the next few steps of the route. The Back and Next buttons page
-- through the route, the "Step 3 / 15" line says the place in it, and the
-- "Current step" button -- or any change of the world, which replans the
-- route -- brings the window back to the step it stands on.
--
-- The step on screen. The window walks the route of the route planner and
-- stands on the first entry that is not done yet: a pick-up is done when
-- the quest sits in the log or is finished for good, a work step when the
-- log says every goal is done, a hand-in when the quest is handed in, and
-- a level-up step when the player has reached its level. Everything below
-- that entry counts as the next steps. The step model builds the step;
-- this module only renders it. A right-click on the step, or on a listed
-- next step, skips that quest into the character's skip list, and the
-- route replans around it at once.
--
-- Follow mode. The "Follow" tick in the title bar turns the Follow mode
-- controller on and off. While the mode is on and a quest is picked, the
-- window shows the step of that quest instead of the route's step, the
-- place line says "Following", and a click on the step headline returns
-- to the route (user story 30): the pick clears, the mode itself stays
-- on -- the tick is the only control that turns it off -- and a later
-- pick in the log follows again. With the mode on but nothing picked,
-- the window shows the route again, the way the Follow mode controller
-- documents its state.
--
-- The look. Flat by default: a dark plate with a thin bronze edge, the
-- look the shared look module gives every window of the addon. The
-- FlareUI look is the look adapter's work (ticket #36); this module
-- never reads the FlareUI global. The window keeps its own width, drags
-- by its background unless the saved data locks it, and remembers its
-- place in the account-wide saved table. Scale and opacity come from the
-- same table and land on the window on every refresh.
--
-- The window holds no quest action of its own: it never accepts, hands
-- in, or abandons a quest (user story 67). The skip list is the only list
-- it writes, by the player's right-click, which is the player's choice.
--
-- The public surface, for the later tickets:
--
--   Show()     bring the window back on the screen; the /eq command
--              (ticket #42) calls this. The window also shows on its own
--              every time the player enters the world.
--   Hide()     the same as the X control of the title bar.
--   IsShown()  whether the window is on the screen right now.
--   GetCurrentStep()  the step on screen, in the step model's shape, so
--              its point and points are the waypoint candidates of the
--              TomTom bridge (ticket #39): the follow step while one is
--              served, else the step of the route place on screen; nil
--              while the window is hidden or nothing stands on it.
--   GetCurrentPosition()  two numbers, at and total: the route place on
--              screen, the numbers behind "Step 3 / 15"; nil, nil in
--              Follow mode, while hidden, or with no route.
--   RegisterCallback(owner, "WindowChanged", fn)  the CallbackHandler
--              subscription. WindowChanged fires with one payload table,
--              { shown, step, at, total }, whenever the window's content
--              or visibility may have moved: after the first build, on
--              every refresh a quest state change or a follow change
--              asked for, on hide, and on show. The payload carries the
--              same state the queries answer, so the TomTom bridge can
--              set its waypoint from the step and take the waypoint down
--              when shown turns false.

local EQ = EfficientQuests
local look = EfficientQuests.look
local reader = EfficientQuests.questState
local planner = EfficientQuests.routePlanner
local model = EfficientQuests.stepModel
local follow = EfficientQuests.followMode
local store = EfficientQuests.characterStore

local window = {}
EfficientQuests.StepWindow = window

window.callbacks = LibStub("CallbackHandler-1.0"):New(window,
    "RegisterCallback", "UnregisterCallback", "UnregisterAllCallbacks")

-- The layout steps of the body; the palette and the backdrop are the
-- look module's. One row of the body is one line of text.
local WIDTH = 280
local HEADER, LINE, HEADLINE, PLACE, GAP, BAND, PAD = 36, 18, 20, 16, 6, 26, 12
-- How many steps list below the one on screen.
local NEXT_STEPS = 3

local frame          -- the window frame, built on first show
local stepHeadline   -- the headline; the step's own click surface
local placeText      -- the place line under the headline
local stepBlock      -- the rows of the step's goal lines
local huntsBlock     -- the rows of the "hunts in one area" block
local rewardsBlock   -- the rows of the rewards
local nextBlock      -- the rows of the next steps
local pagerLine      -- "Step 3 / 15", or "Following"
local backButton, nextButton, currentButton
local followCheck

local pool, usedRows = {}, {}
local lastRoute -- the route table of the last render, by identity
local page      -- the paged place while the player pages; nil at home
local served = { step = nil, at = nil, total = nil }
local counts = { lines = 0, hunts = 0, rewards = 0, next = 0 }

-- Whether one route entry is done, by the quest state reader's answers.
local function entryDone(entry)
    if entry.kind == "levelup" then
        return (reader.GetPlayer().level or 1) >= entry.level
    end
    local logEntry = reader.GetQuest(entry.questID)
    if entry.kind == "pickup" then
        return logEntry ~= nil or reader.IsCompleted(entry.questID)
    end
    if entry.kind == "do" then
        return logEntry ~= nil and logEntry.complete == true
    end
    return logEntry == nil and reader.IsCompleted(entry.questID)
end

-- The first place of the route that is not done yet: where the window
-- stands. Zero when every entry is done.
local function currentPosition(route)
    for at, entry in ipairs(route) do
        if not entryDone(entry) then return at end
    end
    return 0
end

-- The words of one route entry: the step model's headline, or plain words
-- when the model knows no step for it.
local function wordsOf(entry)
    if entry.kind == "levelup" then
        return "Level up to " .. entry.level
    end
    local step = model.GetStep(entry)
    if step and type(step.headline) == "string" then return step.headline end
    return "Quest " .. entry.questID
end

local function notify()
    window.callbacks:Fire("WindowChanged", {
        shown = frame ~= nil and frame:IsShown() == true,
        step = served.step, at = served.at, total = served.total,
    })
end

-- Scale and opacity come from the account-wide saved table and land on
-- the window on every refresh, so a change in the options panel reaches
-- the window with the next change of the world.
local function applySettings()
    if type(EfficientQuestsDB) ~= "table" then return end
    if type(EfficientQuestsDB.scale) == "number" then
        frame:SetScale(EfficientQuestsDB.scale)
    end
    if type(EfficientQuestsDB.opacity) == "number" then
        frame:SetAlpha(EfficientQuestsDB.opacity)
    end
end

-- One row of the body: a tick box, the words, and the count column. The
-- rows come out of the pool and go back into it hidden, the way the menu
-- treats its quest rows, and they move between the blocks as the step
-- changes shape.
local function newRow()
    local row = CreateFrame("Button", nil, stepBlock)
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
    row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.count:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.count:SetJustifyH("RIGHT")
    return row
end

local function takeRow(parent, at)
    local row = table.remove(pool) or newRow()
    row:SetParent(parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((at - 1) * LINE))
    row:Show()
    table.insert(usedRows, row)
    return row
end

-- Release the rows of the earlier refresh back into the pool, with their
-- scripts cleared so a pooled row never keeps a click of its old life.
local function releaseRows()
    for _, row in ipairs(usedRows) do
        row:Hide()
        row:SetScript("OnClick", nil)
        row:SetScript("OnEnter", nil)
        row:SetScript("OnLeave", nil)
        table.insert(pool, row)
    end
    usedRows = {}
end

-- One goal line: a tick box that fills itself from the quest state, the
-- words, and the count column. A tip or a hint line carries no tick box.
local function setLineRow(row, line)
    row.tick:SetShown(line.kind ~= "note" and line.kind ~= "info")
    row.tick:SetChecked(line.done == true)
    row.text:SetPoint("LEFT", row, "LEFT", 24, 0)
    row.text:SetTextColor(1, 1, 1, 1)
    row.text:SetText(line.text)
    row.count:SetText(line.count or "")
end

-- One section label, in the muted bronze of the addon's windows.
local function setLabelRow(row, text)
    row.tick:SetShown(false)
    row.count:SetText("")
    row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.text:SetTextColor(look.ACCENT[1], look.ACCENT[2], look.ACCENT[3], 1)
    row.text:SetText(text)
end

-- One reward row: the name in the gold of a link, and the hover that
-- opens the game tooltip on the item or the spell. A reward the data
-- knows by id only lists in plain words.
local function setRewardRow(row, kind, id, name)
    row.tick:SetShown(false)
    row.count:SetText("")
    row.text:SetPoint("LEFT", row, "LEFT", 12, 0)
    row.text:SetTextColor(1, 0.82, 0.2, 1)
    row.text:SetText(name)
    row.rewardKind, row.rewardID = kind, id
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.rewardKind == "spell" then
            GameTooltip:SetSpellByID(self.rewardID)
        else
            GameTooltip:SetItemRef("item:" .. self.rewardID)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- One next-step row: the words of the step, and the right-click that
-- skips its quest off the route.
local function setNextRow(row, entry, words)
    row.tick:SetShown(false)
    row.count:SetText("")
    row.text:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.text:SetTextColor(1, 1, 1, 1)
    row.text:SetText(words)
    if entry.kind ~= "levelup" then
        row:SetScript("OnClick", function(_, mouseButton)
            if mouseButton ~= "RightButton" then return end
            store.skip(entry.questID)
            window.refresh()
        end)
    end
end

-- One member of the "hunts in one area" block: its quest name with its
-- yards in the count column, its place under it, and its own goal lines
-- with their counts and ticks.
local function renderHunt(parent, at, hunt)
    local rows = 0
    local row = takeRow(parent, at + rows)
    rows = rows + 1
    row.tick:SetShown(true)
    row.tick:SetChecked(hunt.lines[1].done == true)
    row.text:SetPoint("LEFT", row, "LEFT", 12, 0)
    row.text:SetTextColor(1, 1, 1, 1)
    row.text:SetText(hunt.lines[1].text)
    row.count:SetText(hunt.yards .. " yards")
    if hunt.place then
        row = takeRow(parent, at + rows)
        rows = rows + 1
        row.tick:SetShown(false)
        row.count:SetText("")
        row.text:SetPoint("LEFT", row, "LEFT", 28, 0)
        row.text:SetTextColor(1, 1, 1, 1)
        row.text:SetText(hunt.place)
    end
    for index = 2, #hunt.lines do
        row = takeRow(parent, at + rows)
        rows = rows + 1
        setLineRow(row, hunt.lines[index])
    end
    return rows
end

-- The step itself: the headline words, the place line, the goal lines,
-- the hunts block, and the rewards. A step the model knows nothing for
-- still renders, in plain words.
local function renderStep(step, words)
    stepHeadline.text:SetText(words)
    placeText:SetText((step and step.place) or "")
    counts.lines = 0
    if step then
        for _, line in ipairs(step.lines) do
            counts.lines = counts.lines + 1
            setLineRow(takeRow(stepBlock, counts.lines), line)
        end
    else
        counts.lines = 1
        setLineRow(takeRow(stepBlock, 1), {
            kind = "info", done = false,
            text = "Every step of the route is done.",
        })
    end
    counts.hunts = 0
    if step and step.hunts then
        counts.hunts = counts.hunts + 1
        setLabelRow(takeRow(huntsBlock, counts.hunts), "Also in this area")
        for _, hunt in ipairs(step.hunts) do
            counts.hunts = counts.hunts + renderHunt(huntsBlock,
                counts.hunts + 1, hunt)
        end
    end
    counts.rewards = 0
    if step and step.rewards then
        local rewards = step.rewards
        counts.rewards = counts.rewards + 1
        setLabelRow(takeRow(rewardsBlock, counts.rewards), "Rewards")
        local function rewardRow(kind, id, name)
            counts.rewards = counts.rewards + 1
            setRewardRow(takeRow(rewardsBlock, counts.rewards),
                kind, id, name)
        end
        for _, item in ipairs(rewards.items or {}) do
            rewardRow("item", item.id, item.name or ("Item " .. item.id))
        end
        for _, item in ipairs(rewards.choices or {}) do
            rewardRow("item", item.id, item.name or ("Item " .. item.id))
        end
        if rewards.spell then
            rewardRow("spell", rewards.spell, "Spell " .. rewards.spell)
        end
    end
end

-- The blocks stack from the headline down; the window is as tall as its
-- content, and a block with nothing in it takes no space.
local function layout()
    stepBlock:SetHeight(counts.lines * LINE)
    huntsBlock:SetHeight(counts.hunts * LINE)
    rewardsBlock:SetHeight(counts.rewards * LINE)
    nextBlock:SetHeight(counts.next * LINE)
    if counts.hunts > 0 then huntsBlock:Show() else huntsBlock:Hide() end
    if counts.rewards > 0 then rewardsBlock:Show() else rewardsBlock:Hide() end
    if counts.next > 0 then nextBlock:Show() else nextBlock:Hide() end
    local height = HEADER + HEADLINE + PLACE + counts.lines * LINE
        + (counts.hunts > 0 and counts.hunts * LINE + GAP or 0)
        + (counts.rewards > 0 and counts.rewards * LINE + GAP or 0)
        + (counts.next > 0 and counts.next * LINE + GAP or 0)
        + BAND + PAD
    frame:SetHeight(height)
end

--- Bring the window in line with the world: the route, the follow state,
--- the saved settings. Called on show, on every quest state change, on
--- every follow change, and after every skip.
function window.refresh()
    if not frame then return end
    if not frame:IsShown() then
        served.step, served.at, served.total = nil, nil, nil
        notify()
        return
    end
    applySettings()
    local route = planner.GetRoute()
    if route ~= lastRoute then
        lastRoute = route
        page = nil
    end
    local state = follow.GetFollowState()
    releaseRows()
    if state.active and state.step then
        -- The followed step replaces the route's step, and the paging
        -- controls leave the screen.
        followCheck:SetChecked(true)
        pagerLine:SetText("Following")
        backButton:Hide()
        nextButton:Hide()
        currentButton:Hide()
        renderStep(state.step, state.step.headline)
        counts.next = 0
        served.step, served.at, served.total = state.step, nil, nil
    else
        followCheck:SetChecked(state.active)
        local total = #route
        local at = page or currentPosition(route)
        pagerLine:SetText(string.format("Step %d / %d", at, total))
        backButton:Show()
        nextButton:Show()
        if page then currentButton:Show() else currentButton:Hide() end
        local entry = route[at]
        local step = entry and model.GetStep(entry) or nil
        renderStep(step, (step and step.headline)
            or (entry and wordsOf(entry))
            or "The route is clear")
        served.step, served.at, served.total = step, at, total
        counts.next = 0
        for index = at + 1, math.min(at + NEXT_STEPS, total) do
            if counts.next == 0 then
                counts.next = counts.next + 1
                setLabelRow(takeRow(nextBlock, counts.next), "Next steps")
            end
            counts.next = counts.next + 1
            setNextRow(takeRow(nextBlock, counts.next), route[index],
                wordsOf(route[index]))
        end
    end
    layout()
    notify()
end

-- The paging walk: one place at a time, inside the route, and the way
-- home is the Current step button.
local function movePage(delta)
    if not served.total or served.total < 1 then return end
    local at = (page or served.at or 1) + delta
    if at < 1 then at = 1 end
    if at > served.total then at = served.total end
    page = at
    window.refresh()
end

local function build()
    frame = CreateFrame("Frame", "EfficientQuestsStepWindow", UIParent)
    frame:SetWidth(WIDTH)
    look.applyBackdrop(frame)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    -- The drag: the lock of the saved data stops it, and a finished drag
    -- writes the new place back, as the top-left offset of the screen.
    -- A drag stop that never started -- nothing moves a locked window --
    -- writes nothing.
    frame:SetScript("OnDragStart", function(self)
        if type(EfficientQuestsDB) == "table" and EfficientQuestsDB.locked then
            return
        end
        self.dragging = true
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        if not self.dragging then return end
        self.dragging = false
        self:StopMovingOrSizing()
        local x = self:GetLeft()
        local y = self:GetTop() - GetScreenHeight()
        EfficientQuestsDB.window = {
            point = "TOPLEFT", relativePoint = "TOPLEFT", x = x, y = y,
        }
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
    end)

    -- The saved place wins; a window without one sits in the middle.
    local saved = type(EfficientQuestsDB) == "table"
        and type(EfficientQuestsDB.window) == "table"
        and EfficientQuestsDB.window or nil
    if saved then
        frame:SetPoint(saved.point, UIParent, saved.relativePoint,
            saved.x, saved.y)
    else
        frame:SetPoint("CENTER")
    end

    -- The title band: the name, the Follow toggle, the menu, and the way
    -- off the screen.
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
    title:SetJustifyH("LEFT")
    title:SetText("Efficient Quests")

    local hide = CreateFrame("Button", nil, frame)
    hide:SetSize(20, 20)
    hide:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
    local hideLabel = hide:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hideLabel:SetAllPoints(hide)
    hideLabel:SetText("X")
    hide:SetScript("OnClick", function() window.Hide() end)

    local menu = CreateFrame("Button", nil, frame)
    menu:SetSize(44, 20)
    menu:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -8)
    local menuLabel = menu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    menuLabel:SetAllPoints(menu)
    menuLabel:SetText("Menu")
    menu:SetScript("OnClick", function() EQ.Menu.Open(frame) end)

    followCheck = CreateFrame("CheckButton", nil, frame)
    followCheck:SetSize(22, 22)
    followCheck:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -88, -7)
    local followLabel = followCheck:CreateFontString(nil, "OVERLAY",
        "GameFontHighlightSmall")
    followLabel:SetPoint("RIGHT", followCheck, "LEFT", -4, 0)
    followLabel:SetText("Follow")
    followCheck:SetChecked(false)
    followCheck:SetScript("OnClick", function(self)
        follow.SetFollowMode(self:GetChecked() == true)
    end)

    -- The headline doubles as the step's own click surface: in Follow
    -- mode a click returns to the route (user story 30), and a
    -- right-click skips the quest of the step (user story 23).
    stepHeadline = CreateFrame("Button", nil, frame)
    stepHeadline:SetSize(WIDTH - 16, HEADLINE)
    stepHeadline:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -HEADER)
    local headlineText = stepHeadline:CreateFontString(nil, "OVERLAY",
        "GameFontHighlight")
    headlineText:SetAllPoints(stepHeadline)
    headlineText:SetJustifyH("LEFT")
    stepHeadline.text = headlineText
    stepHeadline:SetScript("OnClick", function(_, mouseButton)
        local step = served.step
        if mouseButton == "RightButton" then
            if step and step.questID then
                store.skip(step.questID)
                window.refresh()
            end
            return
        end
        local state = follow.GetFollowState()
        if state.active and state.questID then
            follow.ReturnToRoute()
        end
    end)

    placeText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    placeText:SetPoint("TOPLEFT", stepHeadline, "BOTTOMLEFT", 0, -2)
    placeText:SetJustifyH("LEFT")
    placeText:SetTextColor(look.ACCENT[1], look.ACCENT[2], look.ACCENT[3], 1)
    placeText:SetText("")

    stepBlock = CreateFrame("Frame", nil, frame)
    stepBlock:SetWidth(WIDTH - 24)
    stepBlock:SetPoint("TOPLEFT", placeText, "BOTTOMLEFT", 0, -4)
    huntsBlock = CreateFrame("Frame", nil, frame)
    huntsBlock:SetWidth(WIDTH - 24)
    huntsBlock:SetPoint("TOPLEFT", stepBlock, "BOTTOMLEFT", 0, -GAP)
    rewardsBlock = CreateFrame("Frame", nil, frame)
    rewardsBlock:SetWidth(WIDTH - 24)
    rewardsBlock:SetPoint("TOPLEFT", huntsBlock, "BOTTOMLEFT", 0, -GAP)
    nextBlock = CreateFrame("Frame", nil, frame)
    nextBlock:SetWidth(WIDTH - 24)
    nextBlock:SetPoint("TOPLEFT", rewardsBlock, "BOTTOMLEFT", 0, -GAP)

    -- The paging band at the bottom: Back, the place line, the way home,
    -- and Next.
    local pageBand = CreateFrame("Frame", nil, frame)
    pageBand:SetSize(WIDTH - 16, BAND)
    pageBand:SetPoint("TOPLEFT", nextBlock, "BOTTOMLEFT", 0, -GAP)
    backButton = CreateFrame("Button", nil, pageBand)
    backButton:SetSize(44, 20)
    backButton:SetPoint("BOTTOMLEFT", pageBand, "BOTTOMLEFT", 0, 2)
    local backLabel = backButton:CreateFontString(nil, "OVERLAY",
        "GameFontHighlightSmall")
    backLabel:SetAllPoints(backButton)
    backLabel:SetText("Back")
    backButton:SetScript("OnClick", function() movePage(-1) end)
    currentButton = CreateFrame("Button", nil, pageBand)
    currentButton:SetSize(90, 20)
    currentButton:SetPoint("BOTTOMLEFT", pageBand, "BOTTOMLEFT", 50, 2)
    local currentLabel = currentButton:CreateFontString(nil, "OVERLAY",
        "GameFontHighlightSmall")
    currentLabel:SetAllPoints(currentButton)
    currentLabel:SetText("Current step")
    currentButton:SetScript("OnClick", function()
        page = nil
        window.refresh()
    end)
    nextButton = CreateFrame("Button", nil, pageBand)
    nextButton:SetSize(44, 20)
    nextButton:SetPoint("BOTTOMRIGHT", pageBand, "BOTTOMRIGHT", 0, 2)
    local nextLabel = nextButton:CreateFontString(nil, "OVERLAY",
        "GameFontHighlightSmall")
    nextLabel:SetAllPoints(nextButton)
    nextLabel:SetText("Next")
    nextButton:SetScript("OnClick", function() movePage(1) end)
    pagerLine = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pagerLine:SetPoint("TOP", pageBand, "TOP", 8, 0)
    pagerLine:SetText("")
end

--- Bring the window back on the screen. The /eq command (ticket #42)
--- calls this; the window also shows on its own whenever the player
--- enters the world.
function window.Show()
    if not frame then build() end
    frame:Show()
    window.refresh()
end

--- Take the window off the screen, the same as the X control.
function window.Hide()
    if frame then frame:Hide() end
    served.step, served.at, served.total = nil, nil, nil
    notify()
end

--- Whether the window is on the screen right now.
function window.IsShown()
    return frame ~= nil and frame:IsShown() == true
end

--- The step on screen, in the step model's shape -- its point and points
--- are the waypoint candidates of the TomTom bridge (ticket #39). Nil
--- while the window is hidden or nothing stands on it.
function window.GetCurrentStep()
    return served.step
end

--- The route place on screen: two numbers, at and total, the numbers
--- behind "Step 3 / 15". Nil, nil in Follow mode, while hidden, or with
--- no route.
function window.GetCurrentPosition()
    return served.at, served.total
end

-- The world comes up after login: the saved tables are in place from
-- PLAYER_LOGIN, and PLAYER_ENTERING_WORLD is the moment the player first
-- sees the screen. The window appears there, shown every session; hiding
-- it is the player's own choice, and the /eq command (ticket #42) brings
-- it back through Show.
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then window.Show() end
end)

-- Every quest state change moves the counts, the ticks, or the route
-- itself. The refresh waits for the next frame, because the listeners of
-- one change all hear it in one dispatch: the route planner marks its
-- route stale in its own ear of the same event, and the window must not
-- render before that mark lands, or it would ask the planner for the
-- route of half a breath ago. A frame later the world has settled, and
-- one refresh serves every change of one log update.
local watches = {}
for _, name in ipairs({ "QuestAccepted", "QuestProgressed", "QuestCompleted",
    "QuestHandedIn", "QuestAbandoned", "PlayerLevelUp" }) do
    reader.RegisterCallback(watches, name, function()
        C_Timer.After(0, function() window.refresh() end)
    end)
end

-- A pick in the log, a mode change, or the return to the route: the
-- Follow mode controller tells the window, and the window re-renders.
local followWatches = {}
follow.RegisterCallback(followWatches, "FollowChanged", function()
    window.refresh()
end)
