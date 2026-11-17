-- The look adapter of Efficient Quests. It is the only module that reads
-- the look of FlareUI: when FlareUI is present -- the optional-addons
-- module answers that -- it reads the backdrop, the colors, and the fonts
-- off the live FlareUI tracker frame, restyles the step window with them,
-- and docks the window below the tracker. The window never copies the
-- tracker's width; it keeps its own. Without FlareUI, the window keeps
-- the flat look the step window builds and drags by the lock option of
-- the saved data. If the tracker frame is missing or has an unexpected
-- shape -- no backdrop, the wrong frame type, no scroll of lines -- the
-- adapter falls back to the flat look without an error, because the look
-- must never break the window (user story 44).
--
-- Dragging while docked: the tracker owns the place, so drags stay off
-- for as long as the window is docked, the same word the lock option
-- gives -- a locked window never moves, and a docked one moves with the
-- tracker. The lock option keeps its meaning in the flat look: an
-- unlocked flat window drags, a locked one stays.
--
-- The adapter hears the window's own changed signal and re-applies the
-- look on every refresh, so a reload, a FlareUI that loads late, and the
-- rows the window takes fresh from its pool all keep the tracker's look.
-- It reads and sets only the public frame API of the window; the window's
-- own logic stays untouched.

local EQ = EfficientQuests
local window = EQ.StepWindow
local addons = EQ.optionalAddons

local adapter = {}
EQ.lookAdapter = adapter

-- The global names: the tracker frame FlareUI builds, and the step window
-- frame the client registers under its name. The gap of air between the
-- docked window and the tracker is the dock's own. The name in the
-- window's title band tells the title's text apart from the lines.
local TRACKER_NAME = "FlareUI_ObjectiveTracker"
local WINDOW_NAME = "EfficientQuestsStepWindow"
local ADDON_NAME = "Efficient Quests"
local DOCK_GAP = 10

local docked = false
-- The window's own flat look, captured before the first dock: the
-- backdrop with its colors and the fonts of every text, so the flat look
-- can come back whole when the tracker leaves.
local captured = false
local ownBackdrop, ownBackdropColor, ownBackdropBorderColor
local ownFonts = setmetatable({}, { __mode = "k" })

-- The step window frame, by the global name the client gives it. The
-- window builds itself on first show, so the lookup runs on every apply.
local function stepFrame()
    return _G[WINDOW_NAME]
end

-- The tracker's scroll frame: the one whose scroll child holds the
-- tracker's lines of tracked quests.
local function trackerScroll(tracker)
    if not tracker.GetChildren then return nil end
    for _, child in ipairs({ tracker:GetChildren() }) do
        if child.GetObjectType and child:GetObjectType() == "ScrollFrame" then
            return child
        end
    end
    return nil
end

-- The live tracker frame, or nil when FlareUI is away or the frame has an
-- unexpected shape. Every read is guarded, because the look must never
-- break the window.
local function liveTracker()
    local tracker = _G[TRACKER_NAME]
    if type(tracker) ~= "table" and type(tracker) ~= "userdata" then
        return nil
    end
    if not tracker.GetObjectType or tracker:GetObjectType() ~= "Frame" then
        return nil
    end
    if not tracker.GetChildren or not tracker.GetWidth then return nil end
    local width = tracker:GetWidth()
    if type(width) ~= "number" or width <= 0 then return nil end
    if not trackerScroll(tracker) then return nil end
    if not tracker.GetBackdrop then return nil end
    local backdrop = tracker:GetBackdrop()
    if type(backdrop) ~= "table" or type(backdrop.bgFile) ~= "string" then
        return nil
    end
    return tracker
end

-- The fonts of the tracker: the header's title font, and the font of its
-- first line -- a heading, then lines under it, the way the player reads
-- the tracker. A tracker without lines falls back to its header font.
local function trackerFonts(tracker)
    local heading, content
    for _, child in ipairs({ tracker:GetChildren() }) do
        if type(child.title) == "table" and child.title.GetFont then
            heading = child.title
        end
    end
    local scroll = trackerScroll(tracker)
    local container = scroll and scroll.GetScrollChild
        and scroll:GetScrollChild() or nil
    if container and container.GetChildren then
        for _, line in ipairs({ container:GetChildren() }) do
            if type(line.text) == "table" and line.text.GetFont
                and (not line.IsShown or line:IsShown()) then
                content = line.text
                break
            end
        end
    end
    return heading, content or heading
end

-- One text of the window takes a font of the tracker. The text's own font
-- is captured once, so the flat look can be restored; the words and their
-- colors stay the window's, because its colors tell goals, labels, and
-- rewards apart.
local function applyFont(target, source)
    if not target or not target.SetFont or not target.GetFont then return end
    if ownFonts[target] == nil then
        ownFonts[target] = { target:GetFont() }
    end
    if not (source and source.GetFont) then return end
    local path, size, flags = source:GetFont()
    if type(path) == "string" and type(size) == "number" then
        target:SetFont(path, size, flags or "")
    end
end

-- Restyle every text of the window: the title band carries the tracker's
-- header font -- found by the addon's own name it shows -- and every
-- other text the tracker's line font.
local function applyFonts(frame, heading, content)
    local function walk(node)
        for _, child in ipairs({ node:GetChildren() }) do
            if child.GetFont and child.SetFont then
                local isTitle = child.GetText and child:GetText() == ADDON_NAME
                applyFont(child, isTitle and heading or content)
            elseif child.GetChildren then
                walk(child)
            end
        end
    end
    walk(frame)
end

-- Copy the tracker's backdrop with its colors onto the window.
local function copyBackdrop(frame, tracker)
    frame:SetBackdrop(tracker:GetBackdrop())
    if tracker.GetBackdropColor and frame.SetBackdropColor then
        frame:SetBackdropColor(tracker:GetBackdropColor())
    end
    if tracker.GetBackdropBorderColor and frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(tracker:GetBackdropBorderColor())
    end
end

-- Remember the window's own flat look before the first dock.
local function captureFlat(frame)
    if captured then return end
    captured = true
    if frame.GetBackdrop then ownBackdrop = frame:GetBackdrop() end
    if frame.GetBackdropColor then
        ownBackdropColor = { frame:GetBackdropColor() }
    end
    if frame.GetBackdropBorderColor then
        ownBackdropBorderColor = { frame:GetBackdropBorderColor() }
    end
end

-- Bring the flat look back: the window's own backdrop, its own fonts, and
-- the place the saved data holds -- the same place the step window builds
-- itself on.
local function restoreFlat(frame)
    if ownBackdrop and frame.SetBackdrop then frame:SetBackdrop(ownBackdrop) end
    if ownBackdropColor and #ownBackdropColor == 4 and frame.SetBackdropColor then
        frame:SetBackdropColor(unpack(ownBackdropColor))
    end
    if ownBackdropBorderColor and #ownBackdropBorderColor == 4
        and frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(unpack(ownBackdropBorderColor))
    end
    for target, font in pairs(ownFonts) do
        if type(font[1]) == "string" and target.SetFont then
            target:SetFont(font[1], font[2], font[3] or "")
        end
    end
    if not (frame.ClearAllPoints and frame.SetPoint) then return end
    frame:ClearAllPoints()
    local saved = type(EfficientQuestsDB) == "table"
        and type(EfficientQuestsDB.window) == "table"
        and EfficientQuestsDB.window or nil
    if saved then
        frame:SetPoint(saved.point, UIParent, saved.relativePoint,
            saved.x, saved.y)
    else
        frame:SetPoint("CENTER")
    end
end

-- While the window is docked, the tracker owns its place, so the drag
-- stays off. The wrap passes every drag through while the window is not
-- docked, so the flat look keeps the lock option's behavior.
local function wrapDrag(frame)
    if frame.eqDockWrapped then return end
    frame.eqDockWrapped = true
    local startDrag = frame.GetScript and frame:GetScript("OnDragStart")
    local stopDrag = frame.GetScript and frame:GetScript("OnDragStop")
    if type(startDrag) == "function" then
        frame:SetScript("OnDragStart", function(self, button)
            if docked then return end
            return startDrag(self, button)
        end)
    end
    if type(stopDrag) == "function" then
        frame:SetScript("OnDragStop", function(self, button)
            if docked then return end
            return stopDrag(self, button)
        end)
    end
end

-- Dock the window below the tracker: the window's top left goes to the
-- tracker's bottom left, with a gap of air between. The width never
-- enters it -- the window keeps its own.
local function dock(frame, tracker)
    if not (frame.ClearAllPoints and frame.SetPoint) then return end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", tracker, "BOTTOMLEFT", 0, -DOCK_GAP)
end

-- Bring the window in line with the live tracker, or leave and restore
-- the flat look. Whether FlareUI is there at all is the optional-addons
-- module's question; the tracker's shape is this adapter's own look.
local function applyLook()
    local frame = stepFrame()
    if not frame then return end
    wrapDrag(frame)
    local tracker = addons.FlareUI() and liveTracker() or nil
    if not tracker then
        if docked then
            docked = false
            restoreFlat(frame)
        end
        return
    end
    if not docked then
        captureFlat(frame)
        docked = true
    end
    if frame.SetBackdrop then copyBackdrop(frame, tracker) end
    applyFonts(frame, trackerFonts(tracker))
    dock(frame, tracker)
end

-- The look must never break the window: whatever goes wrong inside the
-- apply, the window keeps the look it had and the game keeps running.
local function apply()
    pcall(applyLook)
end

-- The window tells its listeners whenever its content or visibility may
-- have moved -- after the first build, on every refresh, on hide, and on
-- show. The adapter hears it and re-applies the look, so the look stays
-- consistent across reloads and late loads.
local owner = {}
window.RegisterCallback(owner, "WindowChanged", apply)
