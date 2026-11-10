-- Rank only after local applicability has been evaluated. Guide and provider
-- coordinate systems are not interchangeable with a client UI map ID.
local function localStatus(advice, context)
    local zoneName = context.zoneName
    if not zoneName or zoneName == "" then return nil end
    zoneName = string.lower(zoneName)
    if advice.location and advice.location.zone then
        return string.lower(advice.location.zone) == zoneName
    end
    if advice.chapter and string.find(string.lower(advice.chapter), zoneName, 1, true) then
        return true
    end
    return nil
end

local function questLevel(provider, id, context)
    local quest = context.quests[id]
    if quest and type(quest.level) == "number" and quest.level > 0 then return quest.level end
    local value = provider.Quest.Get(id, "questLevel")
    if type(value) == "number" and value > 0 then return value end
end

local function prepare(advice, context, provider, localEvidence)
    local focused, accepted, levelDistance = false, false, nil
    for _, id in ipairs(advice.questIDs or {}) do
        if id == context.focusedQuestID then focused = true end
        if context.isAccepted(id) then accepted = true end
        local level = questLevel(provider, id, context)
        if level and context.level then
            local distance = math.abs(level - context.level)
            if not levelDistance or distance < levelDistance then levelDistance = distance end
        end
    end
    -- An unknown location is not evidence that a focused quest is locally useful.
    local localFocus = focused and localEvidence == true
    advice.relevance = localFocus and "focused quest" or (accepted and "accepted quest"
        or (advice.association ~= "zone" and "quest preparation" or "zone tip"))
    if localEvidence == nil then advice.uncertain = true end
    advice._ranking = {focused=localFocus, accepted=accepted and localEvidence == true, levelDistance=levelDistance}
    return advice
end

local function before(a, b)
    local x, y = a._ranking, b._ranking
    if x.focused ~= y.focused then return x.focused end
    if x.accepted ~= y.accepted then return x.accepted end
    if x.levelDistance ~= y.levelDistance then
        if x.levelDistance == nil then return false end
        if y.levelDistance == nil then return true end
        return x.levelDistance < y.levelDistance
    end
    if a.sourceOrder ~= b.sourceOrder then return a.sourceOrder < b.sourceOrder end
    return a.id < b.id
end

local function duplicateKey(advice)
    local ids = {}
    for _, id in ipairs(advice.questIDs or {}) do ids[#ids + 1] = tostring(id) end
    table.sort(ids)
    return table.concat({string.lower(advice.text), table.concat(ids, ","),
        table.concat(advice.conditions or {}, "|"), advice.location and advice.location.zone or ""}, "\31")
end

-- Returns ordered advice and, when setup is incomplete, a status code. The
-- package is explicit so independent authors are never silently merged.
function EfficientQuests.GetHints(packageName)
    local provider, problem = EfficientQuests.GetProvider()
    if not provider then return {}, problem end
    if not packageName or not EfficientQuests.guides[packageName] then return {}, "guide" end
    local context = EfficientQuests.GetContext()
    local candidates = EfficientQuests.ExtractGuide(packageName, context)
    local output, seen = {}, {}
    for _, advice in ipairs(candidates) do
        local locality = localStatus(advice, context)
        if locality ~= false then
            local key = duplicateKey(advice)
            if not seen[key] then
                seen[key] = true
                output[#output + 1] = prepare(advice, context, provider, locality)
            end
        end
    end
    table.sort(output, before)
    for _, advice in ipairs(output) do advice._ranking = nil end
    return output
end
