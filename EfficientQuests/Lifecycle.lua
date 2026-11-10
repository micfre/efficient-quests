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

local function supplyKey(questID, itemID) return questID .. "\31" .. itemID end

local function isConsumedFor(itemID, questID)
    local saved = EfficientQuestsCharacter
    if type(saved) ~= "table" or type(saved.consumedFor) ~= "table" then return false end
    if type(itemID) ~= "number" or type(questID) ~= "number" then return false end
    return saved.consumedFor[supplyKey(questID, itemID)] == true
end

local function supplies(advice, context, provider)
    if not advice.verifiedItemID then return end
    -- Remember verified quest-linked supplies so later quest-log observations
    -- can attribute this item's use to that quest.
    if advice.questID and context.isAccepted(advice.questID) == true
        and type(EfficientQuestsCharacter) == "table" then
        local saved = EfficientQuestsCharacter
        saved.trackedSupplies = saved.trackedSupplies or {}
        saved.trackedSupplies[supplyKey(advice.questID, advice.verifiedItemID)] = true
    end
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

-- An intended consumption is recorded only from coincident observations: the
-- quest's item objective progressed while the carried count fell. A sale
-- without progress, progress without a fall, or a log disappearance alone is
-- never attributed to the quest.
function EfficientQuests.ObserveConsumption()
    local saved = EfficientQuestsCharacter
    if type(saved) ~= "table" or type(saved.trackedSupplies) ~= "table" then return end
    local context = EfficientQuests.GetContext()
    for key in pairs(saved.trackedSupplies) do
        local questID, itemID = key:match("^(%d+)\31(%d+)$")
        questID, itemID = tonumber(questID), tonumber(itemID)
        local quest = questID and context.quests[questID]
        local objectives = quest and quest.objectives
        if itemID and type(objectives) == "table" then
            local itemProgress = 0
            for _, objective in ipairs(objectives) do
                if type(objective) == "table" and type(objective.numFulfilled) == "number"
                    and (objective.type == "item" or objective.objectiveType == "item") then
                    itemProgress = itemProgress + objective.numFulfilled
                end
            end
            local carried = context.countCarried and context.countCarried(itemID)
            local last = type(saved.lastSeen) == "table" and saved.lastSeen[key] or nil
            if type(last) == "table" and type(last.itemProgress) == "number"
                and type(last.carried) == "number" and type(carried) == "number"
                and itemProgress > last.itemProgress and carried < last.carried then
                saved.consumedFor = saved.consumedFor or {}
                saved.consumedFor[key] = true
            end
            if type(carried) == "number" then
                saved.lastSeen = saved.lastSeen or {}
                saved.lastSeen[key] = {itemProgress = itemProgress, carried = carried}
            end
        end
    end
end

-- Accepting a quest starts a fresh run of it; earlier consumption
-- observations no longer describe its current requirement.
function EfficientQuests.ForgetConsumption(questID)
    local saved = EfficientQuestsCharacter
    if type(saved) ~= "table" or type(questID) ~= "number" then return end
    local prefix = questID .. "\31"
    for _, field in ipairs({"consumedFor", "lastSeen", "trackedSupplies"}) do
        local records = type(saved[field]) == "table" and saved[field] or nil
        if records then
            for key in pairs(records) do
                if string.sub(key, 1, #prefix) == prefix then records[key] = nil end
            end
        end
    end
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
    -- A location mentioned elsewhere in the instruction is not the path's
    -- identity. Only compare a name immediately after its destination phrase.
    local destination = text:match('flight%s*path%s+at%s*:%s*(.+)')
        or text:match('flight%s*path%s+at%s+(.+)')
        or text:match('flight%s*path%s+in%s*:%s*(.+)')
        or text:match('flight%s*path%s+in%s+(.+)')
    if not destination then
        -- Without a named destination in the sentence, the guide's own
        -- location tag can identify the path: an exact, unique observed
        -- node name on the current map.
        local zone = advice.location and advice.location.zone
        if type(zone) ~= "string" or zone == "" then return false end
        local zoneMatches = 0
        for _, node in pairs(paths) do
            if node.mapID == context.zoneID and type(node.name) == "string"
                and string.lower(node.name) == string.lower(zone) then
                zoneMatches = zoneMatches + 1
            end
        end
        return zoneMatches == 1
    end
    for _, node in pairs(paths) do
        if node.mapID == context.zoneID and type(node.name) == "string" then
            local name = string.lower(node.name)
            local startAt, endAt = string.find(destination, name, 1, true)
            local rest = endAt and destination:sub(endAt + 1) or ''
            if startAt == 1 and (rest:match('^%s*$') or rest:match('^[%.!,]')
                or rest:match('^%s+if%s')) then
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
    if advice.kind == "supply" and not advice.verifiedItemID then
        if verifiedItem(advice, provider) then
            advice.verifiedItemID = advice.itemID
        elseif advice.itemID then
            qualify(advice, "Guide item identity is not confirmed.")
        end
    end
    local ids = advice.eligibleQuestIDs or advice.questIDs or {}
    if #ids > 0 then
        local remaining, usedAsIntended = {}, false
        for _, id in ipairs(ids) do
            local consumed = advice.kind == "supply" and advice.verifiedItemID ~= nil
                and isConsumedFor(advice.verifiedItemID, id)
            if consumed then usedAsIntended = true end
            -- A repeatable or reaccepted quest takes precedence over history.
            if not consumed and not (context.completedQuestIDs[id] and context.isAccepted(id) == false
                and obsoleteOnTurnIn(advice, id)) then
                remaining[#remaining + 1] = id
            end
        end
        if #remaining == 0 then return false end
        advice.eligibleQuestIDs = remaining
        if usedAsIntended then
            qualify(advice, "Some stated supplies were already used as intended.")
        elseif #remaining < #ids then
            qualify(advice, "Some associated quests are complete.")
        end
    end
    if advice.kind == "technique" and advice.questID
        and context.questPhase(advice.questID) == "ready" then
        local text = string.lower(advice.text)
        if not text:find("turn in", 1, true) and not text:find("turn-in", 1, true)
            and not text:find("hand in", 1, true) and not text:find("after", 1, true)
            and not text:find("completion", 1, true) then return false end
    end
    if advice.kind == "supply" then supplies(advice, context, provider) end
    if advice.kind == "flight" then
        local text = string.lower(advice.text)
        -- Only a leading acquisition directive is evidence that the guide
        -- asks the player to learn a path. "Use ... to get to ..." is travel.
        local acquisition = text:match("^%s*get%f[%A]") or text:match("^%s*learn%f[%A]")
            or text:match("^%s*grab%f[%A]") or text:match("^%s*pick%s+up%f[%A]")
            or text:match("^%s*acquire%f[%A]")
        if acquisition then
            if knownFlight(advice, context) then return false end
            advice.text = advice.text .. " (if you have not already learned it)"
        end
    end
    return true
end
