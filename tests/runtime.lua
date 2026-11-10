-- The addon is loaded as the game would load the TOC, with only game services
-- substituted. No optional tracker or guide engine is provided.
local messages, handlers = {}, {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) table.insert(messages, message) end }
SlashCmdList = {}
function CreateFrame()
  return {
    RegisterEvent = function() end,
    SetScript = function(_, name, handler) handlers[name] = handler end,
  }
end

local function loadAddon()
  dofile('tests/addon.lua')()
  assert(handlers.OnEvent, 'addon must listen for login')
  handlers.OnEvent(nil, 'PLAYER_LOGIN')
end
local function status()
  messages = {}
  assert(SlashCmdList.EFFICIENTQUESTS, 'settings/status command must be available')
  SlashCmdList.EFFICIENTQUESTS('status')
  return table.concat(messages, ' ')
end
loadAddon()
assert(status():find('QuestieDB', 1, true), 'missing provider should produce actionable status')
print('ok - missing provider status without optional addons')
LibQuestieDB = {}
assert(status():find('guide', 1, true), 'missing guide should be distinguished from a missing provider')
print('ok - missing guide status')
EfficientQuests_RegisterGuide('TUG', '[NExample advice]', 'TUG')
assert(not status():find('No compatible guide', 1, true), 'adapted guide should be recognized')
print('ok - adapted guide registers independently')
assert(not status():find('No relevant tips', 1, true), 'unverified dependencies must not be presented as a valid empty state')
print('ok - unverified dependencies do not look like an empty result')
assert(status():find('incompatible', 1, true), 'provider without a supported contract should be reported as incompatible')
print('ok - incompatible provider status')
local entity = { Get = function() end }
LibQuestieDB = { RequireContract = function(version) return version == 1 end,
  Quest = entity, Npc = entity, Item = entity, Object = entity }
assert(status():find('Ready', 1, true), 'valid provider should pass setup check')
C_QuestLog = {
  GetNumQuestLogEntries = function() return 3, 2 end,
  GetInfo = function(index)
    return ({ {isHeader=true}, {questID=101, title='Accepted', level=12},
      {questID=102, title='Ready', level=10} })[index]
  end,
  IsComplete = function(id) return id == 102 end,
  GetQuestObjectives = function(id) return {{text = 'Objective', finished = id == 102}} end,
  GetAllCompletedQuestIDs = function() return {99} end,
}
C_SuperTrack = { GetSuperTrackedQuestID = function() return 102 end }
UnitFactionGroup = function() return 'Alliance' end
UnitClass = function() return 'Warrior', 'WARRIOR' end
UnitRace = function() return 'Human', 'Human' end
UnitLevel = function() return 10 end
C_Map = { GetBestMapForUnit = function() return 12 end,
  GetPlayerMapPosition = function() return { GetXY = function() return 0.4, 0.5 end } end }
GetItemCount = function(id, includeBank) assert(not includeBank); return id == 42 and 3 or 0 end
local context = EfficientQuests.GetContext()
assert(context.faction == 'Alliance' and context.zoneID == 12 and context.focusedQuestID == 102)
assert(context.quests[101].phase == 'active' and context.quests[102].phase == 'ready')
assert(context.completedQuestIDs[99] and not context.completedQuestIDs[101])
assert(context.countCarried(42) == 3 and context.completeQuestLog)
print('ok - accepted quests, native focus, completion and carried inventory')
C_QuestLog.GetInfo = function(index) if index == 1 then return {isHeader=true, isCollapsed=true} end end
context = EfficientQuests.GetContext()
assert(context.completeQuestLog == false, 'collapsed quest log must be treated as incomplete')
print('ok - collapsed quest log retains uncertainty')
C_QuestLog.IsOnQuest = function(id) return id == 101 end
context = EfficientQuests.GetContext()
assert(context.isAccepted(101) == true and context.isAccepted(103) == false,
  'acceptance by ID should work even when log headers hide entries')
C_QuestLog.IsOnQuest = nil
context = EfficientQuests.GetContext()
assert(context.isAccepted(103) == nil, 'incomplete log must not imply unaccepted')
print('ok - hidden quests can be checked without treating unknown as false')
EfficientQuests.guides.TUG = nil
C_AddOns = { GetAddOnInfo = function(name) if name == 'GuideLime_TUGs_Forever' then return {name = name} end end,
 GetAddOnMetadata = function() return nil end }
assert(status():find('reapply', 1, true) and status():find('TUG', 1, true),
  'installed guide missing adaptation should give an actionable setup status')
print('ok - unadapted guide status')
handlers.OnEvent(nil, 'QUEST_TURNED_IN', 105)
context = EfficientQuests.GetContext()
assert(context.completedQuestIDs[105], 'observed turn-in should be remembered')
assert(not context.completedQuestIDs[101], 'a quest absent from the log is not a turn-in')
print('ok - observed turn-in is distinct from abandonment')
C_SkillInfo = { GetNumSkillLines = function() return 1 end,
 GetSkillLineInfo = function() return {name='Mining', rank=10, isHeader=false} end }
context = EfficientQuests.GetContext()
assert(context.professions.mining == true and context.professions.alchemy == nil,
  'known professions should be available while absent skills remain unknown')
print('ok - profession observations preserve unknowns')

-- At login the core reconciles addons that declare the guide marker against
-- the guides that actually registered and exposes each mismatch as a warning.
local function clearGuides()
  for key in pairs(EfficientQuests.guides) do EfficientQuests.guides[key] = nil end
end
clearGuides()
C_AddOns = {
  GetNumAddOns = function() return 3 end,
  GetAddOnInfo = function(index)
    return ({ 'EfficientQuests_Paired', 'EfficientQuests_Silent', 'Unrelated_Tool' })[index]
  end,
  GetAddOnMetadata = function(name, field)
    if field == 'X-EfficientQuests-Guide' and name ~= 'Unrelated_Tool' then return '1' end
  end,
}
EfficientQuests_RegisterGuide('EfficientQuests_Paired', '[N Paired]', 'Paired Author')
handlers.OnEvent(nil, 'PLAYER_LOGIN')
local warnings = EfficientQuests.GetGuideWarnings()
assert(#warnings == 1, 'a fully matching set apart from one missing guide must warn once')
assert(warnings[1]:find('EfficientQuests_Silent', 1, true) and warnings[1]:find('did not register', 1, true),
  'a declared guide that did not register should produce its own warning line')
print('ok - declared guide that never registers warns at login')
