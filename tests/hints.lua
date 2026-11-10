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
assert(#hints == 1 and hints[1].uncertain and hints[1].relevance == 'quest preparation', 'missing location remains uncertain')
print('ok - unknown locations stay conditional without invented distance')
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
print('ok - active and ready phases do not reuse obsolete locations')
C_Map.GetMapChildrenInfo = nil
EfficientQuests_RegisterGuide('UnknownSubzone', [[
[N Elwynn Forest]
[G42,50 Northshire] Buy [CI224,1 Candle].
]], 'Author')
hints = EfficientQuests.GetHints('UnknownSubzone')
assert(#hints == 1 and hints[1].uncertain, 'unmapped subzones must not be treated as remote')
print('ok - unmapped name mismatch remains uncertain')
