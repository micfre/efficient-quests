-- Rank only after local applicability has been evaluated. Guide and provider
-- coordinate systems are not interchangeable with a client UI map ID.
local function localStatus(advice, context)
    local zoneName = context.zoneName
    if not zoneName or zoneName == "" then return nil end
    if advice.location and advice.location.zone then
        local name = string.lower(advice.location.zone)
        if name == string.lower(zoneName) then return true end
        -- A different name can be a subzone or alias. Only compare maps when
        -- the client's own hierarchy identifies a unique matching map.
        if not C_Map or not C_Map.GetMapInfo or not C_Map.GetMapChildrenInfo then return nil end
        local ancestors, id, root = {}, context.zoneID, nil
        for _ = 1, 20 do
            local info = id and C_Map.GetMapInfo(id)
            if not info or ancestors[id] then break end
            ancestors[id], root = true, id
            if not info.parentMapID or info.parentMapID == 0 then break end
            id = info.parentMapID
        end
        if not root then return nil end
        local maps = C_Map.GetMapChildrenInfo(root, nil, true)
        if type(maps) ~= "table" then return nil end
        local match
        for _, info in ipairs(maps) do
            if type(info.name) == "string" and string.lower(info.name) == name then
                if match and match.mapID ~= info.mapID then return nil end
                match = info
            end
        end
        if not match or not match.mapID then return nil end
        if ancestors[match.mapID] then return true end
        id = match.mapID
        local seen = {}
        for _ = 1, 20 do
            if id == context.zoneID then return true end
            if not id or seen[id] then break end
            seen[id] = true
            local info = C_Map.GetMapInfo(id)
            id = info and info.parentMapID
        end
        -- Separate zone-level maps are distinct; unrelated submaps are not
        -- sufficient evidence to declare an opportunity remote.
        local current = C_Map.GetMapInfo(context.zoneID)
        local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone
        if zoneType and current and current.mapType == zoneType and match.mapType == zoneType then return false end
        return nil
    end
    if advice.chapter and string.find(string.lower(advice.chapter), string.lower(zoneName), 1, true) then
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

local function hasContract(provider, version)
    local ok, supported = pcall(provider.RequireContract, version)
    return ok and supported == true
end

local function allows(mask, characterBit)
    if type(mask) ~= "number" or mask < 0 then return nil end
    if mask == 0 then return true end
    if type(characterBit) ~= "number" or characterBit <= 0 then return nil end
    return math.floor(mask / characterBit) % 2 == 1
end

-- Filter only confirmed explicit quest associations. Unknown or missing
-- restrictions remain conditional; tentative textual links are never facts.
local function eligibleQuests(advice, context, provider)
    if not advice.questIDs or #advice.questIDs == 0 then return true end
    local eligible, uncertain = {}, false
    local enums = provider.Enum or {}
    local raceBit = hasContract(provider, 3) and enums.raceMaskById and enums.raceMaskById[context.raceID]
    local classBit = hasContract(provider, 4) and enums.classKeys and enums.classKeys[context.class]
    for _, id in ipairs(advice.questIDs) do
        local race = allows(provider.Quest.Get(id, "requiredRaces"), raceBit)
        local class = allows(provider.Quest.Get(id, "requiredClasses"), classBit)
        if race ~= false and class ~= false then
            eligible[#eligible + 1] = id
            if race == nil or class == nil then uncertain = true end
        end
    end
    if #eligible == 0 then return false end
    advice.eligibleQuestIDs = eligible
    if #eligible < #advice.questIDs then uncertain = true end
    if uncertain then
        advice.uncertain = true
        advice.conditions = advice.conditions or {}
        table.insert(advice.conditions, "Quest restrictions may be incomplete.")
    end
    return true
end

-- Client map POIs already carry their UI-map frame. QuestieDB AreaIDs do not,
-- so do not compare provider spawn coordinates to the player position here.
local function mapBands(context)
    local result = {}
    if not context.zoneID or not context.position or not C_QuestLog or not C_QuestLog.GetQuestsOnMap
        or not C_Map or not C_Map.GetMapWorldSize then return result end
    local width, height = C_Map.GetMapWorldSize(context.zoneID)
    if type(width) ~= "number" or type(height) ~= "number" or width <= 0 or height <= 0 then return result end
    local points = C_QuestLog.GetQuestsOnMap(context.zoneID)
    if type(points) ~= "table" then return result end
    for _, point in ipairs(points) do
        if point.mapID == context.zoneID and type(point.questID) == "number"
            and type(point.x) == "number" and point.x >= 0 and point.x <= 1
            and type(point.y) == "number" and point.y >= 0 and point.y <= 1 then
            local accepted = context.isAccepted(point.questID)
            local phase = context.quests[point.questID] and context.quests[point.questID].phase
            if accepted and not phase and C_QuestLog.IsComplete then
                phase = C_QuestLog.IsComplete(point.questID) and "ready" or "active"
            end
            local kind
            if accepted == false and point.isQuestStart == true then kind = "giver"
            elseif accepted == true and phase == "active" and point.isQuestStart == false
                and point.inProgress == true and type(point.numObjectives) == "number" and point.numObjectives > 0 then
                kind = "target"
            end
            if kind then
                local dx = (point.x - context.position.x) * width
                local dy = (point.y - context.position.y) * height
                local band = math.floor(math.sqrt(dx * dx + dy * dy) / 250)
                result[point.questID] = result[point.questID] or {}
                local previous = result[point.questID][kind]
                if not previous or band < previous then result[point.questID][kind] = band end
            end
        end
    end
    return result
end

local function prepare(advice, context, provider, localEvidence, distances)
    local focused, accepted, levelDistance, giverBand, targetBand = false, false, nil, nil, nil
    for _, id in ipairs(advice.eligibleQuestIDs or advice.questIDs or {}) do
        if id == context.focusedQuestID then focused = true end
        if context.isAccepted(id) then accepted = true end
        local bands = distances[id]
        if bands then
            if bands.giver and (not giverBand or bands.giver < giverBand) then giverBand = bands.giver end
            if bands.target and (not targetBand or bands.target < targetBand) then targetBand = bands.target end
        end
        -- The native next waypoint follows the quest's current phase. Only
        -- use it for a known ready quest, in the same client map frame.
        local quest = context.quests[id]
        local phase = quest and quest.phase
        if not phase and context.isAccepted(id) and C_QuestLog and C_QuestLog.IsComplete then
            if C_QuestLog.IsComplete(id) then phase = 'ready' end
        end
        if phase == 'ready' and context.zoneID and context.position and C_QuestLog
            and C_QuestLog.GetNextWaypoint and C_Map and C_Map.GetMapWorldSize then
            local map, x, y = C_QuestLog.GetNextWaypoint(id)
            local width, height = C_Map.GetMapWorldSize(context.zoneID)
            if map == context.zoneID and type(x) == 'number' and x >= 0 and x <= 1
                and type(y) == 'number' and y >= 0 and y <= 1
                and type(width) == 'number' and width > 0 and type(height) == 'number' and height > 0 then
                local dx, dy = (x - context.position.x) * width, (y - context.position.y) * height
                local band = math.floor(math.sqrt(dx * dx + dy * dy) / 250)
                if not targetBand or band < targetBand then targetBand = band end
            end
        end
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
    local words = string.lower(advice.text or '')
    -- Only a direct unqualified purchase instruction establishes timing.
    -- Other prose remains unknown; do not infer timing from acceptance alone.
    local availableNow = localEvidence == true and not advice.uncertain
        and words:match('^buy [^,;]+ now[%.!]*$') ~= nil
        and not words:find(' if ', 1, true) and not words:find(' unless ', 1, true)
    advice._ranking = {localEvidence=localEvidence == true, focused=localFocus, accepted=accepted and localEvidence == true, giverBand=giverBand, targetBand=targetBand, levelDistance=levelDistance, availableNow=availableNow}
    return advice
end

local function before(a, b)
    local x, y = a._ranking, b._ranking
    if x.localEvidence ~= y.localEvidence then return x.localEvidence end
    if x.focused ~= y.focused then return x.focused end
    if x.accepted ~= y.accepted then return x.accepted end
    for _, field in ipairs({"giverBand", "targetBand"}) do
        if x[field] ~= y[field] then
            if x[field] == nil then return false end
            if y[field] == nil then return true end
            return x[field] < y[field]
        end
    end
    if x.levelDistance ~= y.levelDistance then
        if x.levelDistance == nil then return false end
        if y.levelDistance == nil then return true end
        return x.levelDistance < y.levelDistance
    end
    if x.availableNow ~= y.availableNow then return x.availableNow end
    if a.sourceOrder ~= b.sourceOrder then return a.sourceOrder < b.sourceOrder end
    return a.id < b.id
end

local function duplicateKey(advice)
    local ids = {}
    for _, id in ipairs(advice.questIDs or {}) do ids[#ids + 1] = tostring(id) end
    table.sort(ids)
    return table.concat({string.lower(advice.text), table.concat(ids, ","),
        table.concat(advice.conditions or {}, "|"), advice.location and advice.location.zone or "",
        tostring(advice.itemID or ""), tostring(advice.quantity or ""),
        tostring(advice.location and advice.location.x or ""),
        tostring(advice.location and advice.location.y or ""),
        advice.location and advice.location.coordinateSystem or ""}, "\31")
end

-- Returns ordered advice and, when setup is incomplete, a status code. The
-- package is explicit so independent authors are never silently merged.
function EfficientQuests.GetHints(packageName)
    local provider, problem = EfficientQuests.GetProvider()
    if not provider then return {}, problem end
    if not packageName or not EfficientQuests.guides[packageName] then return {}, "guide" end
    local context = EfficientQuests.GetContext()
    local candidates = EfficientQuests.ExtractGuide(packageName, context)
    local distances = mapBands(context)
    local output, seen = {}, {}
    for _, advice in ipairs(candidates) do
        local locality = localStatus(advice, context)
        if locality ~= false and eligibleQuests(advice, context, provider) then
            local key = duplicateKey(advice)
            local source = {id=advice.id, chapter=advice.chapter, sourceText=advice.sourceText,
                sourceAuthor=advice.sourceAuthor, location=advice.location}
            if not seen[key] then
                advice.sources = {source}
                seen[key] = advice
                output[#output + 1] = prepare(advice, context, provider, locality, distances)
            else
                table.insert(seen[key].sources, source)
            end
        end
    end
    table.sort(output, before)
    for _, advice in ipairs(output) do advice._ranking = nil end
    return output
end
