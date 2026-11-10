-- Global hook used by locally adapted guide packages. Keep this independent of
-- Guidelime so either addon can be present without replacing its namespace.
local guides = {}
EfficientQuests = { guides = guides }
local function registerGuide(packageName, ...)
    if type(packageName) ~= "string" or packageName == "" then return end
    if not guides[packageName] then guides[packageName] = {} end
    table.insert(guides[packageName], {...})
end
_G.EfficientQuests_RegisterGuide = registerGuide

local function status()
    if not _G.LibQuestieDB then
        return "QuestieDB is missing. Install and enable the QuestieDB addon."
    end
    if not next(guides) then
        return "No compatible guide is registered. Install and adapt the supported TUG guide."
    end
    return "QuestieDB compatibility and guide processing are not yet available."
end

local function showStatus()
    DEFAULT_CHAT_FRAME:AddMessage("Efficient Quests: " .. status())
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        EfficientQuestsCharacter = EfficientQuestsCharacter or {}
        SLASH_EFFICIENTQUESTS1 = "/eq"
        SlashCmdList.EFFICIENTQUESTS = showStatus
    end
end)
