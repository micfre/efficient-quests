-- Entry point of Efficient Quests. This module creates the addon table,
-- checks that the client is the Forever client, and applies the defaults
-- of the two saved-data tables. The later modules -- the data store, the
-- quest state reader, the window -- hang off what is prepared here.

EfficientQuests = {}

-- Account-wide saved data (SavedVariables in the manifest): everything
-- about the window. The window keys hold its default spot until the
-- player drags the window somewhere else.
local ACCOUNT_DEFAULTS = {
    window = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 16, y = -120 },
    scale = 1,
    opacity = 1,
    locked = false,
    waypoints = true,
}

-- Per-character saved data (SavedVariablesPerCharacter in the manifest):
-- the quests this character leaves out, the quests the player abandoned,
-- and whether Follow mode is on.
local CHARACTER_DEFAULTS = {
    skipped = {},
    abandoned = {},
    followMode = false,
}

-- Fill every missing key with its default. A key whose saved value has
-- the right type keeps that value, group tables are filled one level at
-- a time, and a value of the wrong type falls back to its default.
local function applyDefaults(saved, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(saved[key]) ~= "table" then saved[key] = {} end
            applyDefaults(saved[key], value)
        elseif type(saved[key]) ~= type(value) then
            saved[key] = value
        end
    end
end

-- The Forever client identifies itself with the Camelot project id. This
-- is the same check the embedded HereBeDragons makes.
local function clientIsForever()
    return WOW_PROJECT_ID ~= nil and WOW_PROJECT_CAMELOT ~= nil
        and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event)
    if event ~= "PLAYER_LOGIN" then return end
    if not clientIsForever() then
        DEFAULT_CHAT_FRAME:AddMessage(
            "Efficient Quests supports the Forever client only and will not run here.")
        return
    end
    EfficientQuestsDB = EfficientQuestsDB or {}
    applyDefaults(EfficientQuestsDB, ACCOUNT_DEFAULTS)
    EfficientQuestsCharacter = EfficientQuestsCharacter or {}
    applyDefaults(EfficientQuestsCharacter, CHARACTER_DEFAULTS)
end)
