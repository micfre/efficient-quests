-- Interpret source item tags only after the provider confirms their identity.
local function verifiedItem(advice, provider)
    if type(advice.itemID) ~= "number" or type(advice.itemSourceName) ~= "string" then return nil end
    local name = provider.Item.Get(advice.itemID, "name")
    if type(name) ~= "string" or name == "" then return nil end
    if string.lower(name) ~= string.lower(advice.itemSourceName) then return nil end
    return name
end

local function qualify(advice, message)
    advice.uncertain = true
    advice.conditions = advice.conditions or {}
    table.insert(advice.conditions, message)
end

local function supplies(advice, context, provider)
    local name = verifiedItem(advice, provider)
    if not name then
        if advice.itemID then qualify(advice, "Guide item identity is not confirmed.") end
        return
    end
    advice.verifiedItemID = advice.itemID
    local needed = advice.quantity
    if type(needed) ~= "number" or needed <= 0 or needed ~= math.floor(needed) then return end
    local carried = context.countCarried(advice.itemID)
    if type(carried) ~= "number" or carried < 0 then return end
    local shortage = math.max(0, needed - carried)
    local text = advice.text
    if advice.questID then text = text:gsub("%s+for%s*%.%s*$", " for this quest.") end
    local bank = context.countBank and context.countBank(advice.itemID)
    if type(bank) ~= "number" or bank < 0 then bank = nil end
    -- Replace only a simple leading purchase directive; keep all qualifying
    -- guide words and conditions following its quantity and item name.
    local prefix = text:match("^[Bb]uy:?%s+%d+%s+")
    if prefix then
        local action
        if shortage == 0 then action = "Keep at least " .. needed .. " "
        elseif bank and bank >= shortage then action = "Retrieve " .. shortage .. " "
        elseif bank and bank > 0 then action = "Retrieve " .. bank .. " and acquire " .. (shortage - bank) .. " more "
        else action = "Acquire " .. shortage .. " more " end
        text = action .. text:sub(#prefix + 1)
        if bank and bank > 0 and shortage > 0 then text = text .. " (from your bank where available)" end
    elseif shortage == 0 then
        text = text .. " If applicable, keep at least " .. needed .. "; do not sell or discard them."
    else
        text = text .. " You carry " .. carried .. "; if applicable, acquire at least " .. shortage .. " more."
    end
    if shortage == 0 and prefix then
        text = text .. " Do not sell or discard them."
    elseif shortage > 0 and prefix then
        text = text .. " If applicable, keep at least " .. needed .. " in total."
    end
    advice.text = text
end

-- Persist only explicit positive observations, scoped to the current character.
function EfficientQuests.ObserveTaxiNodes()
    if not C_TaxiMap or not C_TaxiMap.GetAllTaxiNodes or not C_Map or not C_Map.GetBestMapForUnit
        or not Enum or not Enum.FlightPathState then return end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end
    local nodes = C_TaxiMap.GetAllTaxiNodes(mapID)
    if type(nodes) ~= "table" then return end
    for _, node in ipairs(nodes) do
        if type(node.nodeID) == "number" and type(node.name) == "string" and node.name ~= ""
            and type(node.state) == "number"
            and ((type(Enum.FlightPathState.Current) == "number" and node.state == Enum.FlightPathState.Current)
                or (type(Enum.FlightPathState.Reachable) == "number" and node.state == Enum.FlightPathState.Reachable)) then
            EfficientQuestsCharacter = EfficientQuestsCharacter or {}
            EfficientQuestsCharacter.flightPaths = EfficientQuestsCharacter.flightPaths or {}
            EfficientQuestsCharacter.flightPaths[node.nodeID] = {name=node.name, mapID=mapID}
        end
    end
end

local function knownFlight(advice, context)
    local paths = EfficientQuestsCharacter and EfficientQuestsCharacter.flightPaths
    if not paths or not context.zoneID then return false end
    local text, matches = string.lower(advice.text), 0
    for _, node in pairs(paths) do
        if node.mapID == context.zoneID and type(node.name) == "string" then
            local name = string.lower(node.name)
            local startAt, endAt = string.find(text, name, 1, true)
            if startAt and (startAt == 1 or not text:sub(startAt - 1, startAt - 1):match("[%w]"))
                and (endAt == #text or not text:sub(endAt + 1, endAt + 1):match("[%w]")) then
                matches = matches + 1
            end
        end
    end
    return matches == 1
end

local function obsoleteOnTurnIn(advice, questID)
    local source = string.lower(advice.sourceText or advice.text or "")
    if source:find("after", 1, true) or source:find("next quest", 1, true)
        or source:find("follow-up", 1, true) or source:find("follow up", 1, true)
        or source:find("turn in", 1, true) or source:find("turn-in", 1, true)
        or source:find("hand in", 1, true) then return false end
    if advice.kind == "technique" then return true end
    if advice.kind == "supply" then
        return source:find("for%s*%[qc%s*" .. questID .. "[%],]") ~= nil
    end
    return false
end

function EfficientQuests.ApplyLifecycle(advice, context, provider)
    local ids = advice.eligibleQuestIDs or advice.questIDs or {}
    if #ids > 0 then
        local remaining = {}
        for _, id in ipairs(ids) do
            -- A repeatable or reaccepted quest takes precedence over history.
            if not (context.completedQuestIDs[id] and context.isAccepted(id) == false
                and obsoleteOnTurnIn(advice, id)) then
                remaining[#remaining + 1] = id
            end
        end
        if #remaining == 0 then return false end
        advice.eligibleQuestIDs = remaining
        if #remaining < #ids then qualify(advice, "Some associated quests are complete.") end
    end
    if advice.kind == "technique" and advice.questID and context.quests[advice.questID]
        and context.quests[advice.questID].phase == "ready" then
        local text = string.lower(advice.text)
        if not text:find("turn in", 1, true) and not text:find("turn-in", 1, true)
            and not text:find("hand in", 1, true) and not text:find("after", 1, true)
            and not text:find("completion", 1, true) then return false end
    end
    if advice.kind == "supply" then supplies(advice, context, provider) end
    if advice.kind == "flight" then
        local text = string.lower(advice.text)
        local acquisition = text:find("%f[%a]get%f[%A]") or text:find("%f[%a]learn%f[%A]")
            or text:find("%f[%a]grab%f[%A]") or text:find("pick up", 1, true)
            or text:find("%f[%a]acquire%f[%A]")
        if acquisition then
            if knownFlight(advice, context) then return false end
            advice.text = advice.text .. " (if you have not already learned it)"
        end
    end
    return true
end
