-- Global hook called by guide plugins. The first argument is the plugin's
-- addon name and the registry key; each further call appends one chapter.
local guides = {}
EfficientQuests = { guides = guides }
local function registerGuide(packageName, ...)
    if type(packageName) ~= "string" or packageName == "" then return end
    if not guides[packageName] then guides[packageName] = {} end
    table.insert(guides[packageName], {...})
end
_G.EfficientQuests_RegisterGuide = registerGuide

local function guideTitle(key)
    local addons = _G.C_AddOns
    if addons and type(addons.GetAddOnMetadata) == "function" then
        local title = addons.GetAddOnMetadata(key, "Title")
        if type(title) == "string" and title ~= "" then return title end
    end
    return key
end

local function guideList()
    local list = {}
    for key, chapters in pairs(guides) do
        table.insert(list, {
            key = key,
            name = guideTitle(key),
            author = chapters[1] and chapters[1][2] or nil,
            chapters = #chapters,
        })
    end
    table.sort(list, function(a, b) return a.key < b.key end)
    return list
end
EfficientQuests.GetGuideList = guideList

-- Guide plugins declare this manifest field so the core can find them at
-- login. The reserved X-EfficientQuests-API marker is emitted by the builder
-- for a future contract change and is never read at runtime.
local GUIDE_MARKER = "X-EfficientQuests-Guide"

local function addonList()
    local addons = _G.C_AddOns
    if not addons
        or type(addons.GetNumAddOns) ~= "function"
        or type(addons.GetAddOnInfo) ~= "function"
        or type(addons.GetAddOnMetadata) ~= "function" then
        return nil
    end
    return addons
end

local loginWarnings = {}

local function reconcileGuides()
    local warnings = {}
    local addons = addonList()
    if not addons then return warnings end
    local declared = {}
    for index = 1, addons.GetNumAddOns() do
        local name = addons.GetAddOnInfo(index)
        if type(name) == "string" and addons.GetAddOnMetadata(name, GUIDE_MARKER) then
            declared[name] = true
            if not guides[name] then
                table.insert(warnings, name .. " did not register. Check that the guide plugin is enabled.")
            end
        end
    end
    for key in pairs(guides) do
        if not declared[key] then
            table.insert(warnings, key .. " registered without declaring " .. GUIDE_MARKER
                .. ". Reinstall the guide plugin from a current release.")
        end
    end
    table.sort(warnings)
    return warnings
end
EfficientQuests.GetGuideWarnings = function() return loginWarnings end

local function status()
    if not _G.LibQuestieDB then
        return "QuestieDB is missing. Install and enable the QuestieDB addon."
    end
    if not next(guides) then
        local warnings = EfficientQuests.GetGuideWarnings()
        if #warnings > 0 then return table.concat(warnings, " ") end
        return "No guide plugin is registered. Install one from github.com/micfre/efficient-quests/releases."
    end
    local _, problem = EfficientQuests.GetProvider()
    if problem then
        return "QuestieDB is incompatible. Update or reinstall a supported QuestieDB provider."
    end
    local warnings = EfficientQuests.GetGuideWarnings()
    if #warnings > 0 then
        return table.concat(warnings, " ")
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
events:RegisterEvent("QUEST_ACCEPTED")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUEST_WATCH_UPDATE")
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
        loginWarnings = reconcileGuides()
    elseif event == "QUEST_ACCEPTED" and type(questID) == "number" then
        if EfficientQuests.ForgetConsumption then EfficientQuests.ForgetConsumption(questID) end
    elseif event == "QUEST_LOG_UPDATE" or event == "QUEST_WATCH_UPDATE" then
        if EfficientQuests.ObserveConsumption then EfficientQuests.ObserveConsumption() end
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
