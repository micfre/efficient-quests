-- Behavioral checks through guide registration, game state and displayed hints.
DEFAULT_CHAT_FRAME = {AddMessage=function() end}
SlashCmdList = {}
local eventHandler
function CreateFrame() return {RegisterEvent=function() end, SetScript=function(_, _, h) eventHandler=h end} end
for line in io.lines('EfficientQuests/EfficientQuests.toc') do
  if line:match('%.lua$') then assert(loadfile('EfficientQuests/' .. line))('EfficientQuests', {}) end
end
eventHandler(nil, 'PLAYER_LOGIN')
local carried, bank = 2, 0
GetItemCount=function(id, includeBank) assert(id == 42); return carried + (includeBank and bank or 0) end
UnitFactionGroup=function() return 'Alliance' end
UnitLevel=function() return 10 end
C_Map={GetBestMapForUnit=function() return 1 end, GetMapInfo=function() return {name='Elwynn Forest'} end}
local accepted, ready = true, false
C_QuestLog={GetNumQuestLogEntries=function() if accepted then return 1,1 else return 0,0 end end,
 GetInfo=function() if accepted then return {questID=101,level=10} end end, IsOnQuest=function() return accepted end,
 IsComplete=function() return ready end}
local entity={Get=function() end}
LibQuestieDB={RequireContract=function(n) return n==1 end,
 Quest={Get=function(id, key) if key=='questLevel' then return 10 end end},
 Item={Get=function(id,key) if id == 42 and key == 'name' then return 'Apples' end end}, Npc=entity, Object=entity}
EfficientQuests_RegisterGuide('Supplies', [[
[GA Alliance]
[N Elwynn Forest]
[G40,50 Elwynn Forest] Buy [CI42,5 Apples] for [QC101].
]], 'Author')
local function hint() local hints=EfficientQuests.GetHints('Supplies'); return hints[1] end
assert(hint().text:lower():find('acquire', 1, true), 'short supplies should say to acquire')
assert(hint().text:find('3', 1, true), 'display carried shortage')
print('ok - missing carried supplies')
carried = 5
assert(hint().text:lower():find('keep at least 5', 1, true), 'enough carried items should be kept')
assert(not hint().text:lower():find('buy', 1, true), 'already owned supplies should not instruct another purchase')
print('ok - carried supplies are retained')
carried, bank = 2, 3
eventHandler(nil, 'BANKFRAME_OPENED')
assert(not hint().text:lower():find('retrieve', 1, true), 'bank state is unknown until updated')
eventHandler(nil, 'PLAYERBANKSLOTS_CHANGED')
assert(hint().text:lower():find('retrieve 3', 1, true), 'current bank contents should prompt retrieval')
eventHandler(nil, 'BANKFRAME_CLOSED')
assert(not hint().text:lower():find('retrieve', 1, true), 'closed bank contents are not asserted as fresh')
print('ok - bank contents are used only while freshly available')
ready = true
assert(hint() and hint().text:lower():find('acquire', 1, true), 'ready-for-turn-in does not remove retention advice')
ready, accepted = false, false
assert(hint(), 'leaving the log does not invent completion')
eventHandler(nil, 'QUEST_TURNED_IN', 101)
assert(not hint(), 'actual turn-in removes fulfilled quest requirement')
accepted, carried = true, 5
assert(hint() and hint().text:lower():find('keep', 1, true), 'a repeatable quest accepted again overrides completion history')
print('ok - turn-in is distinct from ready and abandonment')
LibQuestieDB.Item.Get = function() return 'Different Item' end
local uncertain = hint()
assert(uncertain and not uncertain.verifiedItemID and uncertain.uncertain, 'mismatched source item ID must remain unverified')
assert(not uncertain.text:lower():find('acquire 3',1,true), 'mismatched item should not receive an invented inventory calculation')
print('ok - mismatched guide item identities stay conditional')
EfficientQuests_RegisterGuide('Flights', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] Get the flightpath at Stormwind.
]], 'Author')
local function flight() local hints=EfficientQuests.GetHints('Flights'); return hints[1] end
assert(flight() and flight().text:find('if you have not already learned',1,true), 'unknown flight history must be conditional')
Enum = {FlightPathState={Current=0, Reachable=1, Unreachable=2}}
C_TaxiMap = {GetAllTaxiNodes=function() return {{nodeID=17, name='Stormwind',state=0}} end}
eventHandler(nil, 'TAXIMAP_OPENED')
assert(not flight(), 'positively observed named flight path suppresses its reminder')
eventHandler(nil, 'TAXIMAP_CLOSED')
assert(not flight(), 'observed path is retained after the taxi map closes')
print('ok - positive flight discovery persists and unknown history stays conditional')
EfficientQuests_RegisterGuide('Technique', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] Use a torch before killing enemies for [QC101].
]], 'Author')
ready = false
assert(#EfficientQuests.GetHints('Technique') == 1, 'active quest retains objective technique')
ready = true
assert(#EfficientQuests.GetHints('Technique') == 0, 'completed objective should not keep its technique')
assert(hint(), 'supply retention persists through ready-for-turn-in')
print('ok - obsolete objective technique is removed while supplies remain')
EfficientQuests_RegisterGuide('UnknownFlight', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] Get the flightpath at Redridge.
]], 'Author')
C_TaxiMap.GetAllTaxiNodes = function() return {{nodeID=18,name='Redridge',state=2}} end
eventHandler(nil, 'TAXIMAP_OPENED')
local unresolved = EfficientQuests.GetHints('UnknownFlight')
assert(#unresolved == 1 and unresolved[1].text:find('if you have not already learned', 1, true),
 'unreachable is not proof the flight path is known or unknown')
print('ok - unreachable nodes do not change learned history')
