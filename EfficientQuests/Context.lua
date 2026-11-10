-- Capture current client observations. A nil value means the client could not
-- supply the fact; absence from a partial quest log is never completion.
function EfficientQuests.GetContext()
    local result = { quests = {}, completedQuestIDs = {}, completeQuestLog = false }
    if UnitFactionGroup then result.faction = UnitFactionGroup("player") end
    if UnitClass then local _, token = UnitClass("player"); result.class = token end
    if UnitRace then local _, token = UnitRace("player"); result.race = token end
    if UnitLevel then result.level = UnitLevel("player") end
    if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        local id = C_SuperTrack.GetSuperTrackedQuestID()
        if id and id ~= 0 then result.focusedQuestID = id end
    end
    if C_Map and C_Map.GetBestMapForUnit then
        result.zoneID = C_Map.GetBestMapForUnit("player")
        if result.zoneID and C_Map.GetPlayerMapPosition then
            local position = C_Map.GetPlayerMapPosition(result.zoneID, "player")
            if position and position.GetXY then
                local x, y = position:GetXY()
                if x and y then result.position = { x = x, y = y } end
            end
        end
    end
    result.countCarried = function(itemID)
        if not GetItemCount or not itemID then return nil end
        return GetItemCount(itemID, false)
    end
    local saved = EfficientQuestsCharacter
    if saved and saved.turnedIn then
        for id in pairs(saved.turnedIn) do result.completedQuestIDs[id] = true end
    end
    local log = C_QuestLog
    if log and log.GetAllCompletedQuestIDs then
        local ids = log.GetAllCompletedQuestIDs()
        if ids then
            for _, id in ipairs(ids) do result.completedQuestIDs[id] = true end
            result.completedHistoryAvailable = true
        end
    end
    if log and log.GetNumQuestLogEntries and log.GetInfo then
        local shown, total = log.GetNumQuestLogEntries()
        if type(shown) == "number" then
            local count, complete = 0, true
            for index = 1, shown do
                local info = log.GetInfo(index)
                if not info then
                    complete = false
                elseif info.isHeader then
                    if info.isCollapsed then complete = false end
                elseif info.questID and info.questID ~= 0 then
                    local quest = { id = info.questID, title = info.title, level = info.level }
                    if log.IsComplete then
                        if log.IsComplete(info.questID) then quest.phase = "ready"
                        else quest.phase = "active" end
                    end
                    if log.GetQuestObjectives then quest.objectives = log.GetQuestObjectives(info.questID) end
                    result.quests[info.questID] = quest
                    count = count + 1
                else
                    complete = false
                end
            end
            if type(total) ~= "number" or count ~= total then complete = false end
            result.completeQuestLog = complete
        end
    end
    result.isAccepted = function(questID)
        if not questID then return nil end
        if result.quests[questID] then return true end
        if log and log.IsOnQuest then return log.IsOnQuest(questID) end
        if result.completeQuestLog then return false end
        return nil
    end
    return result
end
