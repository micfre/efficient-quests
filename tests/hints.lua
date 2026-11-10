-- Exercise real registration, extraction, client context and provider together.
DEFAULT_CHAT_FRAME = {AddMessage=function() end}
SlashCmdList = {}
function CreateFrame() return {RegisterEvent=function() end, SetScript=function() end} end
for line in io.lines('EfficientQuests/EfficientQuests.toc') do
  if line:match('%.lua$') then assert(loadfile('EfficientQuests/' .. line))('EfficientQuests', {}) end
end
local entity = {Get = function() end}
LibQuestieDB = {RequireContract=function(n) return n == 1 end,
 Quest={Get=function(id, key) if key == 'questLevel' then return ({[101]=10, [102]=12, [103]=8})[id] end end},
 Npc=entity, Item=entity, Object=entity}
UnitFactionGroup = function() return 'Alliance' end
UnitLevel = function() return 10 end
C_Map = {GetBestMapForUnit=function() return 1 end,
 GetMapInfo=function(id) return ({[1]={mapID=1,name='Elwynn Forest',mapType=3,parentMapID=100}, [2]={mapID=2,name='Duskwood',mapType=3,parentMapID=100}, [3]={mapID=3,name='Goldshire',mapType=4,parentMapID=1}, [100]={mapID=100,name='Eastern Kingdoms',mapType=2,parentMapID=0}})[id] end,
 GetMapChildrenInfo=function() return {{mapID=1,name='Elwynn Forest',mapType=3,parentMapID=100},{mapID=2,name='Duskwood',mapType=3,parentMapID=100},{mapID=3,name='Goldshire',mapType=4,parentMapID=1}} end,
 GetPlayerMapPosition=function() return {GetXY=function() return 0.4, 0.5 end} end}
Enum = {UIMapType={Zone=3}}
local focus = 101
C_SuperTrack = {GetSuperTrackedQuestID=function() return focus end}
C_QuestLog = {GetNumQuestLogEntries=function() return 1, 1 end,
 GetInfo=function() return {isHeader=true, isCollapsed=true} end,
 IsOnQuest=function(id) return id == 102 end}
EfficientQuests_RegisterGuide('TUG', [[
[GA Alliance]
[N Elwynn Forest]
[G40,50 Elwynn Forest] Use a torch for [QC101].
[G40,50 Elwynn Forest] Use a net for [QC102].
[G40,50 Elwynn Forest] Buy [CI333,1 Apple].
[G40,50 Duskwood] Use a hammer for [QC101].
]], 'Author')
local hints = EfficientQuests.GetHints('TUG')
assert(#hints == 3, 'known remote advice is excluded')
assert(hints[1].questID == 101 and hints[1].relevance == 'focused quest', 'local focus ranks first')
assert(hints[2].questID == 102 and hints[2].relevance == 'accepted quest', 'unwatched quest hidden by header ranks second')
assert(hints[3].association == 'zone' and hints[3].relevance == 'zone tip', 'unassociated local advice is identified')
print('ok - focus and accepted quests are ranked only after local relevance')
focus = nil
C_QuestLog.IsOnQuest = function() return false end
EfficientQuests_RegisterGuide('Levels', [[
[GA Alliance]
[N Elwynn Forest]
[G40,50 Elwynn Forest] Use a net for [QC102].
[G40,50 Elwynn Forest] Use a torch for [QC103].
[G40,50 Elwynn Forest] Use a net for [QC102].
]], 'Author')
hints = EfficientQuests.GetHints('Levels')
assert(#hints == 2, 'repeated identical requirements are not duplicated')
assert(hints[1].questID == 102 and hints[2].questID == 103, 'equally distant levels retain stable source order')
C_Map.GetPlayerMapPosition = function() return {GetXY=function() return 0.401, 0.499 end} end
local moved = EfficientQuests.GetHints('Levels')
assert(moved[1].id == hints[1].id and moved[2].id == hints[2].id, 'small movement does not shuffle hints')
print('ok - duplicate advice, symmetric level proximity and stable movement')
EfficientQuests_RegisterGuide('Unknown', [[
[N Unknown]
Use a net for [QC103].
]], 'Author')
hints = EfficientQuests.GetHints('Unknown')
assert(#hints == 0, 'a quest association alone does not establish local usefulness')
print('ok - unlocated quest advice does not imply local usefulness')
EfficientQuests_RegisterGuide('Unaccepted', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] Use a torch for [QC103].
]], 'Author')
hints = EfficientQuests.GetHints('Unaccepted')
assert(hints[1].relevance == 'quest preparation', 'unaccepted associated advice is not mislabeled as an unassociated zone tip')
print('ok - unaccepted linked advice retains its association')

EfficientQuests_RegisterGuide('Subzone', [[
[N Elwynn Forest]
[G40,50 Goldshire] Buy [CI222,1 Candle].
]], 'Author')
hints = EfficientQuests.GetHints('Subzone')
assert(#hints == 1, 'advice in a local child map must not be discarded')
print('ok - local subzone names are retained')
C_Map.GetMapWorldSize = function() return 1000, 1000 end
C_QuestLog.GetQuestsOnMap = function() return {
 {questID=102,mapID=1,x=0.9,y=0.5,isQuestStart=true,inProgress=false,numObjectives=0},
 {questID=103,mapID=1,x=0.41,y=0.5,isQuestStart=true,inProgress=false,numObjectives=0},
} end
hints = EfficientQuests.GetHints('Unknown')
assert(#hints == 1 and hints[1].questID == 103 and hints[1].uncertain,
  'an unlocated quest tip may appear when a current-phase quest marker is local, while its own location stays uncertain')
print('ok - current-phase local markers support unlocated quest advice with uncertainty')
hints = EfficientQuests.GetHints('Levels')
assert(hints[1].questID == 103, 'nearby available quest start ranks above remote quest start')
print('ok - current map quest start proximity')
C_QuestLog.IsOnQuest = function(id) return id == 102 or id == 103 end
C_QuestLog.IsComplete = function() return false end
C_QuestLog.GetQuestsOnMap = function() return {
 {questID=102,mapID=1,x=0.41,y=0.5,isQuestStart=true,inProgress=false,numObjectives=0},
 {questID=102,mapID=1,x=0.9,y=0.5,isQuestStart=false,inProgress=true,numObjectives=1},
 {questID=103,mapID=1,x=0.41,y=0.5,isQuestStart=false,inProgress=true,numObjectives=1},
} end
hints = EfficientQuests.GetHints('Levels')
assert(hints[1].questID == 103, 'active quests use objective POIs and ignore their original start')
C_QuestLog.IsComplete = function(id) return id == 102 end
hints = EfficientQuests.GetHints('Levels')
assert(hints[1].questID == 103, 'ready quests must not use obsolete objective POIs')
C_QuestLog.IsComplete = function(id) return id == 103 end
hints = EfficientQuests.GetHints('Unknown')
assert(#hints == 0, 'an obsolete objective marker must not locate unplaced ready-quest advice')
C_QuestLog.IsComplete = function(id) return id == 102 end
print('ok - active and ready phases do not reuse obsolete locations')
C_Map.GetMapChildrenInfo = nil
EfficientQuests_RegisterGuide('UnknownSubzone', [[
[N Elwynn Forest]
[G42,50 Northshire] Buy [CI224,1 Candle].
]], 'Author')
hints = EfficientQuests.GetHints('UnknownSubzone')
assert(#hints == 1 and hints[1].uncertain, 'unmapped subzones must not be treated as remote')
print('ok - unmapped name mismatch remains uncertain')
C_Map.GetMapChildrenInfo = function() return {{mapID=1,name='Elwynn Forest',mapType=3,parentMapID=100},{mapID=2,name='Duskwood',mapType=3,parentMapID=100},{mapID=3,name='Goldshire',mapType=4,parentMapID=1}} end
C_QuestLog.IsOnQuest = function(id) return id == 101 end
focus = 101
EfficientQuests_RegisterGuide('Supplier', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] Buy [CI333,1 Apple] for [QC101].
[G40,50 Duskwood] Use a hammer for [QC101].
]], 'Author')
hints = EfficientQuests.GetHints('Supplier')
assert(#hints == 1 and hints[1].itemID == 333 and hints[1].relevance == 'focused quest', 'local supplier remains relevant for remote focused quest')
print('ok - local preparation for a remote focused quest')
focus = nil
C_QuestLog.IsOnQuest = function() return false end
EfficientQuests_RegisterGuide('Sources', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] Buy [CI334,1 Candle].
[G40,50 Elwynn Forest] Buy [CI334,1 Candle].
[G70,50 Elwynn Forest] Buy [CI334,1 Candle].
]], 'Author')
hints = EfficientQuests.GetHints('Sources')
assert(#hints == 2, 'same advice at distinct supplier locations remains distinct')
assert(hints[1].sources and #hints[1].sources == 2, 'deduplication retains each original source')
print('ok - deduplication preserves original sources and different locations')
LibQuestieDB.Quest.Get = function(id, key) if key == 'questLevel' then return ({[102]=10, [103]=20})[id] end end
C_QuestLog.IsOnQuest = function() return false end
C_QuestLog.GetQuestsOnMap = function() return {
 {questID=102,mapID=1,x=0.9,y=0.5,isQuestStart=true,inProgress=false,numObjectives=0},
 {questID=103,mapID=1,x=0.41,y=0.5,isQuestStart=true,inProgress=false,numObjectives=0},
} end
hints = EfficientQuests.GetHints('Levels')
assert(hints[1].questID == 103, 'start proximity precedes level proximity')
focus = 102
hints = EfficientQuests.GetHints('Levels')
assert(hints[1].questID == 102, 'focused quest precedes start proximity')
print('ok - proximity and focus take precedence over lower ranking signals')
focus = nil
UnitRace = function() return 'Human', 'Human', 1 end
UnitClass = function() return 'Warrior', 'WARRIOR', 1 end
LibQuestieDB.RequireContract = function(n) return n <= 4 end
LibQuestieDB.Enum = {raceMaskById={[1]=1}, classKeys={WARRIOR=1}}
LibQuestieDB.Quest.Get = function(id, key)
  if key == 'requiredRaces' then return ({[101]=2,[102]=1,[103]=3})[id] end
  if key == 'requiredClasses' then return 0 end
  return 10
end
EfficientQuests_RegisterGuide('Restrictions', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] Use a torch for [QC101].
[G40,50 Elwynn Forest] Use a net for [QC102].
[G40,50 Elwynn Forest] Use a rope for [QC103].
]], 'Author')
hints = EfficientQuests.GetHints('Restrictions')
assert(#hints == 2 and hints[1].questID ~= 101 and hints[2].questID ~= 101
  and hints[1].questID ~= hints[2].questID,
 'exclude race-restricted advice while keeping applicable and shared quests')
print('ok - provider race restrictions retain shared quests')
LibQuestieDB.Quest.Get = function(id, key)
  if key == 'requiredRaces' then return 0 end
  if key == 'requiredClasses' then return id == 101 and 2 or 0 end
  return 10
end
hints = EfficientQuests.GetHints('Restrictions')
assert(#hints == 2 and hints[1].questID ~= 101 and hints[2].questID ~= 101,
 'known class restrictions must exclude unsuitable advice')
UnitRace = function() return 'Skyborne', 'Skyborne', 95 end
LibQuestieDB.Enum.raceMaskById[95] = 4294967296
LibQuestieDB.Quest.Get = function(id, key)
  if key == 'requiredRaces' then return id == 101 and 4294967296 or 1 end
  if key == 'requiredClasses' then return 0 end
  return 10
end
hints = EfficientQuests.GetHints('Restrictions')
assert(#hints == 1 and hints[1].questID == 101, 'race masks above 32 bits retain eligible Skyborne')
print('ok - class and large race masks respect character restrictions')

UnitRace = function() return 'Human', 'Human', 1 end
LibQuestieDB.Quest.Get = function(id, key) if key == 'questLevel' then return 10 end end
C_QuestLog.IsOnQuest = function() return true end
C_QuestLog.IsComplete = function() return true end
C_QuestLog.GetQuestsOnMap = function() return {} end
C_QuestLog.GetNextWaypoint = function(id)
  if id == 102 then return 1, 0.9, 0.5 end
  if id == 103 then return 1, 0.41, 0.5 end
end
hints = EfficientQuests.GetHints('Levels')
assert(hints[1].questID == 102, 'an unclassified waypoint must not establish turn-in proximity')
print('ok - unclassified waypoints do not establish turn-in proximity')
C_QuestLog.GetNextWaypoint = nil
C_QuestLog.IsOnQuest = function() return false end
EfficientQuests_RegisterGuide('Opportunity', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] Buy a candle later.
[G40,50 Elwynn Forest] Buy a lantern now.
]], 'Author')
hints = EfficientQuests.GetHints('Opportunity')
assert(#hints == 2 and hints[1].text:find('lantern'), 'a stated opportunity available now outranks a later opportunity')
print('ok - present opportunities precede later ones after primary priorities')
C_Map.GetMapChildrenInfo = nil
EfficientQuests_RegisterGuide('LocalFirst', [[
[N Unmapped]
[G40,50 Unknown Place] Use a torch for [QC101].
[G40,50 Elwynn Forest] Buy a candle.
]], 'Author')
focus = 101
hints = EfficientQuests.GetHints('LocalFirst')
assert(#hints == 2 and hints[1].text:find('candle'), 'known local advice precedes uncertain remote focus')
assert(hints[2].uncertain, 'unknown location remains available with uncertainty')
print('ok - known local advice precedes advice with uncertain location')
EfficientQuests_RegisterGuide('WestfallShopping', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] Buy these if they are missing: 1 Copper Flask. Yellow Seeds (you need 6 total) and 8 Blue Petals.
]], 'TUG')
hints = EfficientQuests.GetHints('WestfallShopping')
assert(#hints == 1 and hints[1].text:find('6 total', 1, true) and hints[1].text:find('8 Blue Petals', 1, true), 'shopping list preserves all quantities under the original condition')
assert(hints[1].text:find('if they are missing', 1, true), 'shopping list retains the original condition')
print('ok - TUG multi-item shopping condition and quantities remain together')
EfficientQuests_RegisterGuide('UnlocatedCrowd', [[
[N Shopping List]
Buy [CI42,1 Apple].
Buy [CI43,1 Bread].
Buy [CI44,1 Candle].
]], 'Author')
local unlocated = EfficientQuests.GetHints('UnlocatedCrowd')
assert(#unlocated == 0, 'advice with no evidence of local usefulness cannot fill the compact view')
print('ok - unlocated advice does not crowd local hints')

EfficientQuests_RegisterGuide('QuestPurpose', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] Buy [CI42,3 Apples] because the quest requires three apples for [QC101].
[G40,50 Elwynn Forest] Buy a weapon for the quest [QC102].
]], 'Synthetic')
hints = EfficientQuests.GetHints('QuestPurpose')
assert(#hints == 2, 'practical quest requirements must remain available even when they explain why')
assert(hints[1].text:find('quest requires', 1, true) or hints[2].text:find('quest requires', 1, true), 'the quantity and its quest condition remain together')
print('ok - practical quest-purpose explanations and equipment remain visible')

EfficientQuests_RegisterGuide('NarrativeOutcome', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] Buy [CI42,3 Apples] before the advisor poisoned the ruler.
[G40,50 Elwynn Forest] Keep [CI43,2 Pears] after the guard betrayed the queen.
]], 'Synthetic')
hints = EfficientQuests.GetHints('NarrativeOutcome')
assert(#hints == 0, 'narrative outcomes must not be exposed in advice or source excerpts')
print('ok - narrative outcome variants are withheld')

EfficientQuests_RegisterGuide('LootTechnique', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] Do: [QC101] (You can loot it from outside using a camera angle.)
]], 'Synthetic')
hints = EfficientQuests.GetHints('LootTechnique')
assert(#hints == 1 and hints[1].questID == 101, 'quest technique remains associated with its explicit quest')
assert(hints[1].text:find('loot', 1, true) and hints[1].text:find('camera angle', 1, true), 'camera technique is visible without a route directive')
print('ok - practical technique in a quest directive is preserved')
EfficientQuests_RegisterGuide('UnsafeLootNote', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] Do: [QC101] (You can loot it from outside using a camera angle after the mayor betrayed the town.)
]], 'Synthetic')
assert(#EfficientQuests.GetHints('UnsafeLootNote') == 0, 'unrecognized extra context is not presented as safe camera advice')
print('ok - camera technique does not admit unreviewed added prose')
