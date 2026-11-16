-- The options panel of Efficient Quests. It is a small window of our own,
-- styled after the FlareUI options: a dark backdrop with a bronze border,
-- a title band, and one row per option on its own dark plate. The panel is
-- nowhere registered -- not in the client's options and not in the FlareUI
-- panel -- because it opens from the step window and the /eq command.
-- Everything it shows and changes lives in the account-wide saved table.
local EQ = EfficientQuests

-- The FlareUI palette cues: the bronze border (#A67D45), the muted bronze
-- of accents, and the near-black of the plates the option rows sit on.
local BORDER = { 0.65, 0.49, 0.27 }
local ACCENT = { 0.61, 0.48, 0.29 }
local PLATE = { 0.08, 0.08, 0.09 }
local WIDTH = 320
-- The sliders move in steps of five percent, so a saved value never picks
-- up trailing digits from a drag.
local STEP = 0.05

local function snap(value)
  return math.floor(value / STEP + 0.5) * STEP
end

local function percent(value)
  return string.format("%d%%", math.floor(value * 100 + 0.5))
end

local panel
local checks, sliders

-- A flat dark plate with a thin bronze edge, the look the FlareUI options
-- give their boxes: background and border come from one white texture each,
-- colored by SetBackdropColor and SetBackdropBorderColor.
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

local function build()
  panel = CreateFrame("Frame", "EfficientQuestsOptionsPanel", UIParent)
  panel:SetSize(WIDTH, 220)
  panel:SetPoint("CENTER")
  -- Above the step window and the chat, the way a panel the player asked
  -- for belongs.
  panel:SetFrameStrata("HIGH")
  applyBackdrop(panel)

  -- The title band, with a muted bronze rule under it the way the FlareUI
  -- options separate their header from the rows.
  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -10)
  title:SetJustifyH("LEFT")
  title:SetText("Efficient Quests Options")
  local rule = panel:CreateTexture(nil, "ARTWORK")
  rule:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.6)
  rule:SetHeight(1)
  rule:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -28)
  rule:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -28)

  -- The close button, top right in the band, the way every FlareUI window
  -- carries one.
  local close = CreateFrame("Button", nil, panel)
  close:SetSize(20, 20)
  close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
  local closeLabel = close:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  closeLabel:SetAllPoints(close)
  closeLabel:SetText("X")
  close:SetScript("OnClick", function() panel:Hide() end)  local anchor -- each row hangs below the one above it
  local function row(labelText)
    local rowFrame = CreateFrame("Frame", nil, panel)
    rowFrame:SetSize(WIDTH - 20, 30)
    if anchor then
      rowFrame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    else
      rowFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -38)
    end
    anchor = rowFrame
    -- the dark plate the row sits on, with a little air around its label
    local plate = rowFrame:CreateTexture(nil, "BACKGROUND")
    plate:SetColorTexture(PLATE[1] + 0.03, PLATE[2] + 0.03, PLATE[3] + 0.03, 0.9)
    plate:SetAllPoints(rowFrame)
    local label = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", rowFrame, "LEFT", 8, 0)
    label:SetJustifyH("LEFT")
    label:SetText(labelText)
    return rowFrame
  end

  -- A checkbox the way the FlareUI options draw theirs: Blizzard's minimal
  -- box with the gold checkmark on top, sitting at the row's right edge.
  -- The click hands the new state straight to the saved table.
  local function checkRow(labelText, apply)
    local rowFrame = row(labelText)
    local check = CreateFrame("CheckButton", nil, rowFrame)
    check:SetSize(30, 29)
    check:SetPoint("RIGHT", rowFrame, "RIGHT", -8, 0)
    check:SetNormalAtlas("checkbox-minimal")
    check:SetPushedAtlas("checkbox-minimal")
    local tick = check:CreateTexture(nil, "ARTWORK")
    tick:SetAtlas("checkmark-minimal", true)
    tick:SetPoint("CENTER")
    check:SetCheckedTexture(tick)
    check:SetScript("OnClick", function(self) apply(self:GetChecked()) end)
    return check
  end

  -- A slider with its value written out as a percentage beside it, the
  -- range rows of the FlareUI options in miniature. The value snaps to
  -- the step as it moves and lands in the saved table at once.
  local function sliderRow(labelText, low, high, apply)
    local rowFrame = row(labelText)
    local value = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    value:SetPoint("RIGHT", rowFrame, "RIGHT", -8, 0)
    value:SetJustifyH("RIGHT")
    local slider = CreateFrame("Slider", nil, rowFrame)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(110, 17)
    slider:SetPoint("RIGHT", rowFrame, "RIGHT", -58, 0)
    slider:SetMinMaxValues(low, high)
    slider:SetValueStep(STEP)
    slider:SetObeyStepOnDrag(true)
    slider:SetScript("OnValueChanged", function(_, moved)
      moved = snap(moved)
      slider:SetValue(moved)
      value:SetText(percent(moved))
      apply(moved)
    end)
    return { control = slider, value = value }
  end

  checks = {
    waypoints = checkRow("Waypoints", function(on)
      EfficientQuestsDB.waypoints = on
      -- Tell the TomTom bridge at once, so a waypoint that stands comes
      -- off the moment the player turns the option off. The guard keeps
      -- the panel working in setups that load no bridge.
      if EfficientQuests.TomTomBridge then
        EfficientQuests.TomTomBridge.Apply()
      end
    end),
    locked = checkRow("Lock window", function(on) EfficientQuestsDB.locked = on end),
  }
  sliders = {
    scale = sliderRow("Scale", 0.5, 1.5, function(v) EfficientQuestsDB.scale = v end),
    opacity = sliderRow("Opacity", 0.2, 1, function(v) EfficientQuestsDB.opacity = v end),
  }
end

-- Bring what the panel shows in line with the saved table. Open calls
-- this, so a panel that stayed built from an earlier session never shows a
-- stale value.
local function refresh()
  checks.waypoints:SetChecked(EfficientQuestsDB.waypoints)
  checks.locked:SetChecked(EfficientQuestsDB.locked)
  local scale = sliders.scale
  scale.control:SetValue(EfficientQuestsDB.scale)
  scale.value:SetText(percent(EfficientQuestsDB.scale))
  local opacity = sliders.opacity
  opacity.control:SetValue(EfficientQuestsDB.opacity)
  opacity.value:SetText(percent(EfficientQuestsDB.opacity))
end

EQ.Options = {}

-- The one entry point into the panel. The step window and the /eq command
-- call it; it builds the window on first use, refreshes what it shows from
-- the saved table, and leaves it open on the screen.
function EQ.Options.Open()
  if not panel then build() end
  refresh()
  panel:Show()
  return panel
end
