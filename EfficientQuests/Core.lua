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
        local addons = C_AddOns
        if addons and addons.GetAddOnInfo and addons.GetAddOnInfo("GuideLime_TUGs_Forever") then
            local marker = addons.GetAddOnMetadata and addons.GetAddOnMetadata("GuideLime_TUGs_Forever", "X-EfficientQuests-Adaptation")
            if marker ~= "1" then
                return "TUG guide needs adaptation. Run or reapply the guide adaptation tool."
            end
            return "TUG guide did not register. Check that it is enabled and reapply the adaptation if needed."
        end
        return "No compatible guide is registered. Install and adapt the supported TUG guide."
    end
    local _, problem = EfficientQuests.GetProvider()
    if problem then
        return "QuestieDB is incompatible. Update or reinstall a supported QuestieDB provider."
    end
    return "Ready."
end
EfficientQuests.GetSetupStatus = status

local function showStatus(message)
    if message ~= "status" and EfficientQuests.ShowSettings then
        EfficientQuests.ShowSettings()
    else
        DEFAULT_CHAT_FRAME:AddMessage("Efficient Quests: " .. status())
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("QUEST_TURNED_IN")
events:SetScript("OnEvent", function(_, event, questID)
    if event == "PLAYER_LOGIN" then
        EfficientQuestsCharacter = EfficientQuestsCharacter or {}
        SLASH_EFFICIENTQUESTS1 = "/eq"
        SlashCmdList.EFFICIENTQUESTS = showStatus
    elseif event == "QUEST_TURNED_IN" and type(questID) == "number" and questID > 0 then
        EfficientQuestsCharacter = EfficientQuestsCharacter or {}
        EfficientQuestsCharacter.turnedIn = EfficientQuestsCharacter.turnedIn or {}
        EfficientQuestsCharacter.turnedIn[questID] = true
    end
end)
