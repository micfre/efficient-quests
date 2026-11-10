-- Rank only after local applicability has been evaluated. Guide and provider
-- coordinate systems are not interchangeable with a client UI map ID.

-- Named local-evidence classes; a bare boolean or magic string hides which
-- claim the code is making. CONFIRMED: the client's own map data places the
-- advice's named zone on the player's map (or an exact chapter-title match).
-- REMOTE: the map data places that zone elsewhere, so the advice is
-- excluded. QUEST_SUPPORTED: the advice has no location of its own, but
-- current-phase quest activity on this map supports it. UNRESOLVED: no
-- usable evidence; the advice stays uncertain and ranks last.
local Locality = {
    CONFIRMED = "confirmed",
    REMOTE = "remote",
    QUEST_SUPPORTED = "quest-supported",
    UNRESOLVED = "unresolved",
}

local function localStatus(advice, context)
    local zoneName = context.zoneName
    if not zoneName or zoneName == "" then return Locality.UNRESOLVED end
    if advice.location and advice.location.zone then
        local name = string.lower(advice.location.zone)
        if name == string.lower(zoneName) then return Locality.CONFIRMED end
        -- A different name can be a subzone or alias. Only compare maps when
        -- the client's own hierarchy identifies a unique matching map.
        if not C_Map or not C_Map.GetMapInfo or not C_Map.GetMapChildrenInfo then
            return Locality.UNRESOLVED
        end
        local ancestors, id, root = {}, context.zoneID, nil
        for _ = 1, 20 do
            local info = id and C_Map.GetMapInfo(id)
            if not info or ancestors[id] then break end
            ancestors[id], root = true, id
            if not info.parentMapID or info.parentMapID == 0 then break end
            id = info.parentMapID
        end
        if not root then return Locality.UNRESOLVED end
        local maps = C_Map.GetMapChildrenInfo(root, nil, true)
        if type(maps) ~= "table" then return Locality.UNRESOLVED end
        local match
        for _, info in ipairs(maps) do
            if type(info.name) == "string" and string.lower(info.name) == name then
                if match and match.mapID ~= info.mapID then return Locality.UNRESOLVED end
                match = info
            end
        end
        if not match or not match.mapID then return Locality.UNRESOLVED end
        if ancestors[match.mapID] then return Locality.CONFIRMED end
        id = match.mapID
        local seen = {}
        for _ = 1, 20 do
            if id == context.zoneID then return Locality.CONFIRMED end
            if not id or seen[id] then break end
            seen[id] = true
            local info = C_Map.GetMapInfo(id)
            id = info and info.parentMapID
        end
        -- Separate zone-level maps are distinct; unrelated submaps are not
        -- sufficient evidence to declare an opportunity remote.
        local current = C_Map.GetMapInfo(context.zoneID)
        local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone
        if zoneType and current and current.mapType == zoneType and match.mapType == zoneType then
            return Locality.REMOTE
        end
        return Locality.UNRESOLVED
    end
    -- An exact chapter-title match confirms locality. A title that merely
    -- contains the zone name ("6-9 Elwynn Forest") is an inference about
    -- the chapter's setting, not a confirmed source fact, so it stays
    -- unresolved and uncertain.
    if advice.chapter and string.lower(advice.chapter) == string.lower(zoneName) then
        return Locality.CONFIRMED
    end
    return Locality.UNRESOLVED
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

-- QuestieDB spawn coordinates are percentages keyed by AreaID, a different
-- frame from client UiMapIDs. The provider's ZoneDB support data bridges the
-- two; a spawn is compared to the player only when that bridge lands it on
-- the player's own map. Compatibility entries for retired maps are therefore
-- never treated as evidence, because the player's current map always exists.
local bridgeCache = {source=nil, map=nil}
local function decodeSupportMap(source, field)
    local value = source[field]
    if type(value) == "table" then
        local copy = {}
        for areaId, uiMapId in pairs(value) do copy[areaId] = uiMapId end
        return copy
    end
    if type(value) == "string" and loadstring then
        local chunk = loadstring(value)
        if chunk then
            local ok, result = pcall(chunk)
            if ok and type(result) == "table" then return result end
        end
    end
    return nil
end

local function uiMapByArea(provider)
    local zoneData = nil
    if type(provider.Support) == "table" and type(provider.Support.Get) == "function" then
        local ok, data = pcall(provider.Support.Get, "ZoneDB")
        if ok and type(data) == "table" then zoneData = data end
    end
    local source = type(zoneData) == "table" and type(zoneData.private) == "table"
        and zoneData.private or nil
    if bridgeCache.source == source then return bridgeCache.map end
    local map = source and decodeSupportMap(source, "areaIdToUiMapId")
    local override = source and decodeSupportMap(source, "areaIdToUiMapIdOverride")
    if map and override then
        for areaId, uiMapId in pairs(override) do map[areaId] = uiMapId end
    end
    bridgeCache.source, bridgeCache.map = source, map
    return map
end

-- The turn-in location of a ready quest: the provider's finisher spawns.
local function turnInBand(provider, context, questID, uiMapByAreaId, width, height)
    local finishers = provider.Quest.Get(questID, "finishedBy")
    if type(finishers) ~= "table" then return nil end
    local best
    local function scan(ids, entity)
        if type(ids) ~= "table" or type(entity) ~= "table" or type(entity.Get) ~= "function" then return end
        for _, id in pairs(ids) do
            if type(id) == "number" then
                local spawns = entity.Get(id, "spawns")
                if type(spawns) == "table" then
                    for areaId, points in pairs(spawns) do
                        if uiMapByAreaId[areaId] == context.zoneID and type(points) == "table" then
                            for _, point in ipairs(points) do
                                local x = type(point) == "table" and tonumber(point[1]) or nil
                                local y = type(point) == "table" and tonumber(point[2]) or nil
                                if x and y and x >= 0 and x <= 100 and y >= 0 and y <= 100 then
                                    local dx = (x / 100 - context.position.x) * width
                                    local dy = (y / 100 - context.position.y) * height
                                    local band = math.floor(math.sqrt(dx * dx + dy * dy) / 250)
                                    if not best or band < best then best = band end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    scan(finishers[1], provider.Npc)
    scan(finishers[2], provider.Object)
    return best
end

-- Distances to the quest's current-phase location: client map POIs for
-- unaccepted starts and active objectives, provider finisher spawns for
-- quests ready to hand in. Bands are 250-yard steps on the player's map.
local function mapBands(context, provider, questIDs)
    local result = {}
    if not context.zoneID or not context.position or not C_Map or not C_Map.GetMapWorldSize then return result end
    local width, height = C_Map.GetMapWorldSize(context.zoneID)
    if type(width) ~= "number" or type(height) ~= "number" or width <= 0 or height <= 0 then return result end
    if C_QuestLog and C_QuestLog.GetQuestsOnMap then
        local points = C_QuestLog.GetQuestsOnMap(context.zoneID)
        if type(points) == "table" then
            for _, point in ipairs(points) do
                if point.mapID == context.zoneID and type(point.questID) == "number"
                    and type(point.x) == "number" and point.x >= 0 and point.x <= 1
                    and type(point.y) == "number" and point.y >= 0 and point.y <= 1 then
                    local accepted = context.isAccepted(point.questID)
                    local phase = context.questPhase(point.questID)
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
                        result[point.questID] = result[point.questID] or {via="marker"}
                        local previous = result[point.questID][kind]
                        if not previous or band < previous then result[point.questID][kind] = band end
                    end
                end
            end
        end
    end
    local uiMapByAreaId = uiMapByArea(provider)
    if uiMapByAreaId then
        for questID in pairs(questIDs or {}) do
            if context.questPhase(questID) == "ready" then
                local band = turnInBand(provider, context, questID, uiMapByAreaId, width, height)
                if band then
                    result[questID] = result[questID] or {via="turnin"}
                    local previous = result[questID].giver
                    if not previous or band < previous then result[questID].giver = band end
                    if result[questID].via ~= "marker" then result[questID].via = "turnin" end
                end
            end
        end
    end
    return result
end

local function prepare(advice, context, provider, localEvidence, distances, originalText)
    local focused, accepted, levelDistance, giverBand, targetBand = false, false, nil, nil, nil
    for _, id in ipairs(advice.eligibleQuestIDs or advice.questIDs or {}) do
        if id == context.focusedQuestID then focused = true end
        if context.isAccepted(id) then accepted = true end
        local bands = distances[id]
        if bands then
            if bands.giver and (not giverBand or bands.giver < giverBand) then giverBand = bands.giver end
            if bands.target and (not targetBand or bands.target < targetBand) then targetBand = bands.target end
        end
        local level = questLevel(provider, id, context)
        if level and context.level then
            local distance = math.abs(level - context.level)
            if not levelDistance or distance < levelDistance then levelDistance = distance end
        end
    end
    -- Spec priority order: native focused quest, accepted quest, then the
    -- location signals. Focus and acceptance are never gated by the
    -- local-evidence tier; the tier only orders candidates that tie at a
    -- location priority.
    local tier = localEvidence == Locality.CONFIRMED and 2
        or (localEvidence == Locality.QUEST_SUPPORTED and 1 or 0)
    advice.relevance = focused and "focused quest" or (accepted and "accepted quest"
        or (advice.association ~= "zone" and "quest preparation" or "zone tip"))
    if tier == 0 then advice.uncertain = true end
    local words = string.lower(originalText or advice.text or '')
    -- Only a direct unqualified acquisition instruction ending in "now"
    -- establishes timing. Other prose remains unknown; do not infer timing
    -- from acceptance alone, and never read "for now" as availability.
    local availableNow = false
    if tier == 2 and not advice.uncertain
        and not words:find(' for now[%.!]*$')
        and not words:find(' if ', 1, true) and not words:find(' unless ', 1, true) then
        for _, pattern in ipairs({
            '^buy%s+[^,;]+%s+now[%.!]*$',
            '^get%s+[^,;]+%s+now[%.!]*$',
            '^stock%s+up%s+on%s+[^,;]+%s+now[%.!]*$',
        }) do
            if words:match(pattern) then availableNow = true; break end
        end
    end
    advice._ranking = {localEvidence=tier, focused=focused,
        accepted=accepted, giverBand=giverBand, targetBand=targetBand,
        levelDistance=levelDistance, availableNow=availableNow}
    return advice
end

local function before(a, b)
    local x, y = a._ranking, b._ranking
    -- Fixed spec precedence: native focused quest, accepted quest, distance
    -- to the relevant quest giver/start, distance to the relevant quest
    -- target, proximity to level. The local-evidence tier never overrides
    -- focus or acceptance; it orders candidates that are equal at a
    -- location priority (a confirmed advice zone beats quest-activity
    -- support beats unresolved at the same distance signal).
    if x.focused ~= y.focused then return x.focused end
    if x.accepted ~= y.accepted then return x.accepted end
    for _, field in ipairs({"giverBand", "targetBand"}) do
        if x[field] ~= y[field] then
            if x[field] == nil then return false end
            if y[field] == nil then return true end
            return x[field] < y[field]
        end
        if x.localEvidence ~= y.localEvidence then return x.localEvidence > y.localEvidence end
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

local function duplicateKey(advice, originalText)
    local ids = {}
    for _, id in ipairs(advice.questIDs or {}) do ids[#ids + 1] = tostring(id) end
    table.sort(ids)
    local text = string.lower(advice.text)
    local quantity = tostring(advice.quantity or "")
    -- Repeated, verified purchases with otherwise identical wording describe
    -- one stated minimum. Do not combine different quests or conditions.
    if advice.kind == "supply" and advice.verifiedItemID and originalText then
        local normalized, count = string.lower(originalText):gsub("^buy:?%s+%d+%s+", "buy <minimum> ", 1)
        if count == 1 then text, quantity = normalized, "minimum" end
    end
    return table.concat({text, table.concat(ids, ","),
        table.concat(advice.conditions or {}, "|"), advice.location and advice.location.zone or "",
        tostring(advice.itemID or ""), quantity,
        tostring(advice.location and advice.location.x or ""),
        tostring(advice.location and advice.location.y or ""),
        advice.location and advice.location.coordinateSystem or ""}, "\31")
end

-- A separate quest and a matching item do not prove consumption. Recognize
-- only a direct, quantified source assertion about that exact quest's use,
-- parsed by the guide reader into an explicit record: the same verified
-- item, the same stated quantity repeated in the assertion, the same single
-- quest, and no unparsed conditions.
local function consumptionEvidence(advice, context)
    local record = advice.consumption
    if advice.kind ~= 'supply' or not advice.verifiedItemID or type(record) ~= 'table'
        or type(advice.itemSourceName) ~= 'string' or type(record.itemName) ~= 'string'
        or record.itemID ~= advice.verifiedItemID or record.questID ~= advice.questID
        or record.quantity ~= advice.quantity or record.statedQuantity ~= record.quantity
        or string.lower(record.itemName) ~= string.lower(advice.itemSourceName)
        or string.lower(record.statedItemName or '') ~= string.lower(record.itemName)
        or not advice._ranking.localEvidence
        or context.isAccepted(advice.questID) ~= true then return false end
    for _, condition in ipairs(advice.conditions or {}) do
        if condition ~= 'Quest restrictions may be incomplete.' then return false end
    end
    return true
end

local function aggregateConsumptions(output, context, provider, distances)
    local groups = {}
    for _, advice in ipairs(output) do
        if consumptionEvidence(advice, context) and advice.location and advice.location.zone then
            local key = table.concat({tostring(advice.verifiedItemID), string.lower(advice.location.zone),
                tostring(advice.location.x or ''), tostring(advice.location.y or ''),
                tostring(advice.location.coordinateSystem or '')}, '\31')
            groups[key] = groups[key] or {}
            table.insert(groups[key], advice)
        end
    end
    local removed = {}
    for _, group in pairs(groups) do
        local byQuest, ids = {}, {}
        for _, advice in ipairs(group) do
            local old = byQuest[advice.questID]
            if not old then
                ids[#ids + 1] = advice.questID
                byQuest[advice.questID] = advice
            elseif advice.quantity > old.quantity then
                byQuest[advice.questID] = advice
            end
        end
        if #ids > 1 then
            table.sort(ids)
            local lead, total, parts, sources = group[1], 0, {}, {}
            for _, id in ipairs(ids) do
                local requirement = byQuest[id]
                total = total + requirement.quantity
                parts[#parts + 1] = requirement.quantity .. ' for quest #' .. id
            end
            for _, advice in ipairs(group) do
                for _, source in ipairs(advice.sources or {}) do sources[#sources + 1] = source end
                if advice ~= lead then removed[advice] = true end
            end
            lead.questID, lead.questIDs, lead.eligibleQuestIDs = nil, ids, ids
            lead.association, lead.quantity, lead.sources = 'quests', total, sources
            lead.conditions = lead.conditions or {}
            lead.conditions[#lead.conditions + 1] = 'Guide states separate consumptions: ' .. table.concat(parts, '; ') .. '.'
            lead.text = 'Buy ' .. total .. ' ' .. lead.itemSourceName
            EfficientQuests.ApplyLifecycle(lead, context, provider)
            lead.uncertain = true
            lead.text = lead.text .. ' (if the guide’s stated uses apply)'
            prepare(lead, context, provider, Locality.CONFIRMED, distances, lead.text)
        end
    end
    local result = {}
    for _, advice in ipairs(output) do if not removed[advice] then result[#result + 1] = advice end end
    return result
end

-- Returns ordered advice and, when setup is incomplete, a status code. The
-- package is explicit so independent authors are never silently merged.
function EfficientQuests.GetHints(packageName)
    local provider, problem = EfficientQuests.GetProvider()
    if not provider then return {}, problem end
    if not packageName or not EfficientQuests.guides[packageName] then return {}, "guide" end
    local context = EfficientQuests.GetContext()
    local candidates = EfficientQuests.ExtractGuide(packageName, context)
    local referencedQuests = {}
    for _, advice in ipairs(candidates) do
        for _, id in ipairs(advice.questIDs or {}) do referencedQuests[id] = true end
    end
    local distances = mapBands(context, provider, referencedQuests)
    local output, seen = {}, {}
    for _, advice in ipairs(candidates) do
        local locality = localStatus(advice, context)
        local originalText = advice.text
        -- Neither a quest association nor focus alone supplies a location.
        -- A current-phase marker or provider turn-in on this map establishes
        -- local quest activity, but does not establish where the unlocated
        -- advice itself applies.
        local unlocated = locality == Locality.UNRESOLVED and not (advice.location and advice.location.zone)
        local eligible = eligibleQuests(advice, context, provider)
        if unlocated and eligible then
            for _, id in ipairs(advice.eligibleQuestIDs or advice.questIDs or {}) do
                local support = distances[id]
                if support then
                    locality, unlocated = Locality.QUEST_SUPPORTED, false
                    advice.uncertain = true
                    advice.conditions = advice.conditions or {}
                    table.insert(advice.conditions, support.via == "turnin"
                        and 'The quest turn-in is in this zone; the advice location is not confirmed.'
                        or 'Quest activity is local; the advice location is not confirmed.')
                    break
                end
            end
        end
        if locality ~= Locality.REMOTE and not unlocated and eligible
            and EfficientQuests.ApplyLifecycle(advice, context, provider) then
            local key = duplicateKey(advice, originalText)
            local source = {id=advice.id, chapter=advice.chapter, sourceText=advice.sourceText,
                sourceAuthor=advice.sourceAuthor, location=advice.location}
            if not seen[key] then
                advice.sources = {source}
                seen[key] = advice
                output[#output + 1] = prepare(advice, context, provider, locality, distances, originalText)
            else
                local prior = seen[key]
                table.insert(prior.sources, source)
                if advice.verifiedItemID and prior.verifiedItemID and type(advice.quantity) == "number"
                    and type(prior.quantity) == "number" and advice.quantity > prior.quantity then
                    prior.quantity, prior.text = advice.quantity, advice.text
                end
            end
        end
    end
    output = aggregateConsumptions(output, context, provider, distances)
    table.sort(output, before)
    for _, advice in ipairs(output) do advice._ranking = nil end
    return output
end
