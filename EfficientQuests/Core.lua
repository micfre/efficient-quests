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
    return "Guide processing is not yet available."
end

local function showStatus()
    DEFAULT_CHAT_FRAME:AddMessage("Efficient Quests: " .. status())
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("QUEST_TURNED_IN")
events:RegisterEvent("BANKFRAME_OPENED")
events:RegisterEvent("BANKFRAME_CLOSED")
events:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
events:RegisterEvent("TAXIMAP_OPENED")
events:RegisterEvent("TAXIMAP_CLOSED")
events:RegisterEvent("TAXI_NODE_STATUS_CHANGED")
events:SetScript("OnEvent", function(_, event, questID)
    if event == "PLAYER_LOGIN" then
        EfficientQuestsCharacter = EfficientQuestsCharacter or {}
        SLASH_EFFICIENTQUESTS1 = "/eq"
        SlashCmdList.EFFICIENTQUESTS = showStatus
    elseif event == "TAXIMAP_OPENED" then
        EfficientQuests.taxiOpen = true
        if EfficientQuests.ObserveTaxiNodes then EfficientQuests.ObserveTaxiNodes() end
    elseif event == "TAXI_NODE_STATUS_CHANGED" and EfficientQuests.taxiOpen then
        if EfficientQuests.ObserveTaxiNodes then EfficientQuests.ObserveTaxiNodes() end
    elseif event == "TAXIMAP_CLOSED" then
        EfficientQuests.taxiOpen = false
    elseif event == "BANKFRAME_OPENED" then
        EfficientQuests.bankOpen = true
        EfficientQuests.bankFresh = false
    elseif event == "PLAYERBANKSLOTS_CHANGED" and EfficientQuests.bankOpen then
        EfficientQuests.bankFresh = true
    elseif event == "BANKFRAME_CLOSED" then
        EfficientQuests.bankOpen = false
        EfficientQuests.bankFresh = false
    elseif event == "QUEST_TURNED_IN" and type(questID) == "number" and questID > 0 then
        EfficientQuestsCharacter = EfficientQuestsCharacter or {}
        EfficientQuestsCharacter.turnedIn = EfficientQuestsCharacter.turnedIn or {}
        EfficientQuestsCharacter.turnedIn[questID] = true
    end
end)
