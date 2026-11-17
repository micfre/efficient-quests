-- The shared look of the addon's own windows. Every window the addon
-- builds itself -- the step window, the options panel, the menu, and the
-- dungeon window -- wears the same flat look: a dark plate with a thin
-- bronze edge, the muted bronze of section labels, and the colors that
-- tell notes, warnings, and done work apart. This module is the one
-- place that holds the palette and the backdrop, so the windows cannot
-- drift apart. Window sizes and layouts stay with each window.

local look = {}
EfficientQuests.look = look

-- The FlareUI palette cues, as the options panel uses them: the bronze
-- border, the muted bronze of accents, and the near-black of the plates.
look.BORDER = { 0.65, 0.49, 0.27 }
look.ACCENT = { 0.61, 0.48, 0.29 }
look.PLATE = { 0.08, 0.08, 0.09 }
-- The reading colors of the body lines: plain words, warnings, and done
-- work.
look.NOTE = { 0.85, 0.85, 0.85 }
look.WARN = { 1.00, 0.70, 0.40 }
look.DONE = { 0.45, 0.85, 0.45 }

--- A flat dark plate with a thin bronze edge on one window: background
--- and border come from one white texture each, colored by
--- SetBackdropColor and SetBackdropBorderColor.
function look.applyBackdrop(target)
    target:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    target:SetBackdropColor(look.PLATE[1], look.PLATE[2], look.PLATE[3], 0.95)
    target:SetBackdropBorderColor(look.BORDER[1], look.BORDER[2], look.BORDER[3], 1)
end
