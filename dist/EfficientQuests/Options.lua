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

local panel

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
end

EQ.Options = {}

-- The one entry point into the panel. The step window and the /eq command
-- call it; it builds the window on first use, refreshes what it shows from
-- the saved table, and leaves it open on the screen.
function EQ.Options.Open()
  if not panel then build() end
  panel:Show()
  return panel
end
