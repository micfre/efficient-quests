-- The menu of Efficient Quests. It is a small window that opens beside the
-- step window: the step window calls Menu.Open with itself as the anchor,
-- and the menu's top left goes to the anchor's top right. Without an anchor
-- -- when no window is on the screen yet -- the menu sits at a fixed spot:
-- the same top-left corner of the screen that the saved data holds as the
-- window's default spot. The menu lists the quests this character has
-- skipped, each with a restore action, the dungeons the data store knows,
-- and a link that opens the options panel.
local EQ = EfficientQuests

-- The FlareUI palette cues, as the options panel uses them: the bronze
-- border and the near-black of the plates.
local BORDER = { 0.65, 0.49, 0.27 }
local PLATE = { 0.08, 0.08, 0.09 }
local WIDTH = 260

local menu

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
end

EQ.Menu = {}

-- The one entry point into the menu. The step window hands itself as the
-- anchor; anything else can call without one. Open builds the window on
-- first use, puts it beside the anchor or at the fixed spot, and leaves it
-- open on the screen.
function EQ.Menu.Open(anchor)
  if not menu then build() end
  menu:ClearAllPoints()
  if anchor then
    menu:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 10, 0)
  else
    menu:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -120)
  end
  menu:Show()
  return menu
end
