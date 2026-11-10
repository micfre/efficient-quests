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
assert(uncertain.text:find('for this quest', 1, true) and not uncertain.text:find('for .', 1, true), 'unverified item advice keeps a readable quest association')
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
-- A collapsed quest-log header must not hide the phase of a known quest ID.
C_QuestLog.GetNumQuestLogEntries = function() return 1,1 end
C_QuestLog.GetInfo = function() return {isHeader=true,isCollapsed=true} end
assert(#EfficientQuests.GetHints('Technique') == 0,
 'ready quest behind a collapsed header must not retain obsolete objective technique')
assert(hint(), 'a ready hidden quest still retains its supplies')
C_QuestLog.GetInfo = function() if accepted then return {questID=101,level=10} end end
print('ok - collapsed quest headers do not hide ready quest phase')
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
carried, bank = 2, 0
ready, accepted = false, true
LibQuestieDB.Item.Get = function(id,key) if id == 42 and key == 'name' then return 'Apples' end end
assert(hint().text:find('5', 1, true), 'acquire advice states the total minimum as well as shortage')
EfficientQuests_RegisterGuide('Quantities', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] Buy [CI42,3 Apples] for [QC101].
[G40,50 Elwynn Forest] Buy [CI42,5 Apples] for [QC101].
]], 'Author')
local quantities = EfficientQuests.GetHints('Quantities')
assert(#quantities == 1 and quantities[1].quantity == 5 and #quantities[1].sources == 2,
 'repeated same requirement uses its maximum and preserves both sources')
print('ok - supply shortage includes minimum and duplicate minimums consolidate')
EfficientQuests_RegisterGuide('Followup', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] After finishing [QC101], buy [CI42,5 Apples] for the next quest.
]], 'Author')
accepted = false
assert(#EfficientQuests.GetHints('Followup') == 1, 'follow-up preparation survives completion of its referenced quest')
print('ok - completed quest follow-up preparation remains')
EfficientQuests_RegisterGuide('FlightUse', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] Use the flightpath at Stormwind if traveling to the city.
]], 'Author')
local use = EfficientQuests.GetHints('FlightUse')
assert(#use == 1, 'learned flight paths must not suppress travel opportunities')
assert(not use[1].text:find('if you have not already learned',1,true), 'travel advice is not an acquisition reminder')
print('ok - known flight travel is not suppressed')
accepted = true
EfficientQuests_RegisterGuide('IndependentUnknown', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] Buy [CI42,3 Apples] for [QC101].
[G40,50 Elwynn Forest] Buy [CI42,5 Apples] for [QC102].
]], 'Author')
local separate = EfficientQuests.GetHints('IndependentUnknown')
assert(#separate == 2, 'different quests must not be combined without consumption evidence')
assert(separate[1].quantity == 3 and separate[2].quantity == 5, 'unconfirmed requirements are not speculatively added')
print('ok - different quest requirements are not added without evidence')
EfficientQuests_RegisterGuide('TravelGet', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] Use the flightpath at Stormwind to get to Redridge.
]], 'Author')
local travelGet = EfficientQuests.GetHints('TravelGet')
assert(#travelGet == 1 and not travelGet[1].text:find('if you have not already learned', 1, true),
 'travel instructions containing get must not become acquisition reminders')
print('ok - travel using get is not treated as learning a path')
EfficientQuests_RegisterGuide('DifferentFlight', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] Get the flightpath at Redridge after passing Stormwind.
]], 'Author')
local different = EfficientQuests.GetHints('DifferentFlight')
assert(#different == 1 and different[1].text:find('if you have not already learned', 1, true),
 'a different known location in the text must not suppress an unknown flight path')
print('ok - incidental known locations do not establish flight path identity')
EfficientQuests_RegisterGuide('SimilarFlight', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] Get the flightpath at Stormwind Outpost.
]], 'Author')
local similar = EfficientQuests.GetHints('SimilarFlight')
assert(#similar == 1 and similar[1].text:find('if you have not already learned', 1, true),
 'a longer place name is not the known path with a shorter prefix')
print('ok - partial place-name matches remain unknown')
EfficientQuests_RegisterGuide('TimedSupplies', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] Buy [CI42,3 Apples] later.
[G40,50 Elwynn Forest] Buy [CI42,5 Apples] now.
]], 'Author')
local timed = EfficientQuests.GetHints('TimedSupplies')
assert(#timed == 2 and timed[1].text:find('now', 1, true), 'current opportunity remains first after inventory wording changes')
print('ok - inventory wording preserves available-now ranking')
-- Distinct explicit consumptions are guide assertions, not inferred from quest IDs.
local active = {[201]=true,[202]=true}
C_QuestLog.IsOnQuest = function(id) return active[id] == true end
C_QuestLog.GetNumQuestLogEntries = function() return 2,2 end
C_QuestLog.GetInfo = function(index) return ({ {questID=201,level=10}, {questID=202,level=10} })[index] end
carried, bank = 2, 0
EfficientQuests_RegisterGuide('IndependentExplicit', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] Buy [CI42,3 Apples] for [QC201]; all 3 Apples are consumed by that quest.
[G40,50 Elwynn Forest] Buy [CI42,5 Apples] for [QC202]; all 5 Apples are consumed by that quest.
]], 'Author')
local combined = EfficientQuests.GetHints('IndependentExplicit')
assert(#combined == 1 and combined[1].quantity == 8, 'explicit independent consumptions combine')
assert(combined[1].text:find('8',1,true) and combined[1].text:find('6',1,true), 'combined hint reports total and carried shortage')
assert(combined[1].uncertain and combined[1].text:find('if the guide',1,true), 'source claims remain conditional instead of verified gameplay facts')
local explanation = table.concat(combined[1].conditions, ' ')
assert(explanation:find('201',1,true) and explanation:find('202',1,true) and explanation:find('3',1,true) and explanation:find('5',1,true), 'explanation attributes each guide-stated use')
active[201] = false
C_QuestLog.GetNumQuestLogEntries = function() return 1,1 end
C_QuestLog.GetInfo = function() return {questID=202,level=10} end
eventHandler(nil, 'QUEST_TURNED_IN', 201)
local remaining = EfficientQuests.GetHints('IndependentExplicit')
assert(#remaining == 1 and remaining[1].quantity == 5, 'turn-in recalculates remaining independent minimum')
print('ok - explicit independent consumptions sum with breakdown and recalculate')
active[201] = true
C_QuestLog.GetNumQuestLogEntries = function() return 2,2 end
C_QuestLog.GetInfo = function(index) return ({ {questID=201,level=10}, {questID=202,level=10} })[index] end
EfficientQuests_RegisterGuide('ConditionalConsumption', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] Buy [CI42,3 Apples] for [QC201]; only if it is winter; all 3 Apples are consumed by that quest.
[G40,50 Elwynn Forest] Buy [CI42,5 Apples] for [QC202]; all 5 Apples are consumed by that quest.
]], 'Author')
local conditional = EfficientQuests.GetHints('ConditionalConsumption')
assert(#conditional == 2, 'conditions in guide prose must not disappear in aggregation')
print('ok - unparsed guide conditions prevent aggregation')
EfficientQuests_RegisterGuide('RepeatedConsumption', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] Buy [CI42,2 Apples] for [QC201]; all 2 Apples are consumed by that quest.
[G40,50 Elwynn Forest] Buy [CI42,3 Apples] for [QC201]; all 3 Apples are consumed by that quest.
[G40,50 Elwynn Forest] Buy [CI42,5 Apples] for [QC202]; all 5 Apples are consumed by that quest.
]], 'Author')
local repeated = EfficientQuests.GetHints('RepeatedConsumption')
assert(#repeated == 1 and repeated[1].quantity == 8 and #repeated[1].sources == 3,
 'repeated mentions of one quest contribute only its largest stated minimum')
LibQuestieDB.Item.Get = function() return 'Other item' end
local unverified = EfficientQuests.GetHints('IndependentExplicit')
assert(#unverified == 2, 'unverified item identity prevents aggregation')
print('ok - repeated and unverified requirements do not inflate totals')
LibQuestieDB.Item.Get = function(id,key) if id == 42 and key == 'name' then return 'Apples' end end
EfficientQuests_RegisterGuide('DistinctSuppliers', [[
[N Elwynn Forest]
[G40,50 Elwynn Forest] Buy [CI42,3 Apples] for [QC201]; all 3 Apples are consumed by that quest.
[G60,50 Elwynn Forest] Buy [CI42,5 Apples] for [QC202]; all 5 Apples are consumed by that quest.
]], 'Author')
local suppliers = EfficientQuests.GetHints('DistinctSuppliers')
assert(#suppliers == 2, 'different source locations must not collapse to one opportunity')
print('ok - distinct locations remain distinct opportunities')
