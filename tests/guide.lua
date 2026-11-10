-- Exercise guide registration through the addon boundary, with a synthetic guide.
DEFAULT_CHAT_FRAME = {AddMessage = function() end}
SlashCmdList = {}
function CreateFrame() return {RegisterEvent = function() end, SetScript = function() end} end
dofile('tests/addon.lua')()
EfficientQuests_RegisterGuide('TUG', [[
[GA Alliance]
[N 6-9 Elwynn Forest]
[G43.8,65.8 Elwynn Forest] Accept [QA62].
Buy [CI123,5 Apples] before leaving.
Turn in [QT62].
]], 'TUG author')
local advice = EfficientQuests.ExtractGuide('TUG', {faction='Alliance', class='Mage', race='Human'})
assert(#advice == 1, 'route-only instructions should not become tips')
assert(advice[1].text:find('Apples', 1, true), 'practical supply advice is retained')
assert(advice[1].itemID == 123 and advice[1].quantity == 5, 'known item and quantity survive extraction')
assert(advice[1].location.zone == 'Elwynn Forest', 'chapter-local location is inherited')
assert(advice[1].association == 'zone', 'unlinked preparation is a zone tip')
assert(advice[1].sourceAuthor == 'TUG author', 'guide attribution is available')
print('ok - registered guide produces useful zone advice without route instructions')
EfficientQuests_RegisterGuide('TUG', [[
[GA Horde]
[N Other chapter]
[G44,44 Elwynn Forest] Buy [CI99,1 Forbidden] for later.
]], 'TUG author')
EfficientQuests_RegisterGuide('TUG', [[
[GA Alliance]
[N Later chapter]
[G20,30 Elwynn Forest] [A Warrior] Keep [CI42,3 Rations].
[A Mage] Save [CI43,2 Powder] for [QC77].
[A Mining,IT2901<1] Buy [CI2901,1 Pick].
Kill ten wolves for [QC78].
]], 'TUG author')
advice = EfficientQuests.ExtractGuide('TUG', {faction='Alliance', class='Mage', race='Human'})
assert(#advice == 3, 'opposite factions, classes and bare objectives are excluded across chapters')
assert(advice[2].questID == 77 and advice[2].association == 'quest', 'explicit quest link is preserved')
assert(advice[3].uncertain and #advice[3].conditions > 0, 'unsupported conditions remain uncertain')
local uncertain = EfficientQuests.ExtractGuide('TUG', {class='Mage'})
assert(#uncertain > 0 and uncertain[1].uncertain, 'missing faction must not be treated as known')
print('ok - chapter and step applicability, explicit association and uncertainty')
EfficientQuests_RegisterGuide('Flight', [[
[GA Alliance]
[N Elwynn Forest]
Get the flightpath at [G55.5,47.8 Ironforge].
Repair your gear and sell grey items.
]], 'TUG author')
local travel = EfficientQuests.ExtractGuide('Flight', {faction='Alliance'})
assert(#travel == 1 and travel[1].text:find('Ironforge', 1, true), 'flight reminder retains its destination without unrelated vending')
print('ok - travel advice retains destination')
-- Synthetic examples exercise observed guide formats without copying guide text.
EfficientQuests_RegisterGuide('References', [[
[GA Alliance]
[N 24-25 Duskwood]
[G77.12,44.17Duskwood] Learn the [P] flight path at the village.
Keep the blue tokens. Then travel east for two later route steps.
[A Nightelf] Buy [CI1,1 Seed].
[A Mining,IT2901<1] [OC] [G47.49,41.56 Elwynn Forest] [CI2901,1] Buy a pick from a local merchant; retain it.
]], 'reference')
local reference = EfficientQuests.ExtractGuide('References', {
 faction='Alliance', race='Human', professions={mining=true}, countCarried=function(id) return 0 end
})
assert(#reference == 3, 'synthetic guide examples preserve useful advice and exclude another race')
assert(reference[2].text == 'Keep the blue tokens.', 'mixed route advice keeps the useful standalone sentence')
assert(not reference[2].sourceText:find('route steps', 1, true), 'source excerpt omits unrelated route context')
assert(reference[3].itemID == 2901 and not reference[3].uncertain, 'known profession and possession conditions are evaluated')
local owned = EfficientQuests.ExtractGuide('References', {
 faction='Alliance', race='Human', professions={mining=true}, countCarried=function(id) return 1 end
})
assert(#owned == 2, 'an item-possession condition that fails excludes the advice')
print('ok - representative guide conditions and standalone mixed advice')
EfficientQuests_RegisterGuide('Comparison', [[
[N Conditions]
[A IT42>=2] [G30,40,5 Elwynn Forest] Keep [CI42,2 Rations].
]], 'reference')
local comparisons = EfficientQuests.ExtractGuide('Comparison', {countCarried=function() return 2 end})
assert(#comparisons == 1 and not comparisons[1].uncertain, 'known comparison is evaluated')
assert(comparisons[1].location.zone == 'Elwynn Forest', 'coordinate radius is not part of the zone name')
print('ok - numeric conditions and coordinate radius')
EfficientQuests_RegisterGuide('RestrictedLocation', [[
[N Example]
[A Warrior] [G10,20 Elwynn Forest] Visit the trainer.
Buy [CI200,1 Bread].
]], 'reference')
local localAdvice = EfficientQuests.ExtractGuide('RestrictedLocation', {class='Mage'})
assert(#localAdvice == 1 and localAdvice[1].location == nil, 'an inapplicable step cannot supply inherited coordinates')
print('ok - restricted steps do not supply locations')
EfficientQuests_RegisterGuide('Meaning', [[
[N Example]
[G5,6 Thousand Needles] KEEP!!!!! 10 Turtle Meat for a future quest.
If the vendor has stock. Buy a Bronzetube.
Keep 5 Apples; the king is murdered by the advisor.
Buy 3 Bread. The princess is secretly the villain.
]], 'reference')
local meaning = EfficientQuests.ExtractGuide('Meaning', {})
assert(#meaning == 3, 'spoiler-bearing sentences should be excluded from advice and excerpts')
assert(meaning[1].text:find('10 Turtle Meat', 1, true), 'emphasis must not remove required quantity')
assert(meaning[2].text:find('If the vendor has stock', 1, true), 'separate condition is preserved with the advice')
assert(not meaning[3].sourceText:find('princess', 1, true), 'source excerpt omits narrative outcome')
print('ok - quantities, separate conditions and spoiler-bearing excerpts')
assert(travel[1].kind == 'flight', 'flight reminders are identified as travel opportunities')
assert(reference[3].kind == 'supply', 'an identified item provides a supply candidate')
assert(meaning[1].kind == 'supply', 'a stated minimum is preserved as a supply candidate')
print('ok - conservative advice classifications')
EfficientQuests_RegisterGuide('TrailingCondition', [[
[N Example]
Buy 2 Rations. Only if you have not collected them already.
]], 'reference')
local trailing = EfficientQuests.ExtractGuide('TrailingCondition', {})
assert(#trailing == 0 or trailing[1].text:find('Only if', 1, true), 'a trailing condition is not silently discarded')
print('ok - trailing conditions remain visible or suppress the advice')
EfficientQuests_RegisterGuide('Audit', [[
[N 24-25 Duskwood]
[G78,48.3Duskwood] Buy: [CI4371,1 Copper Flask]
Buy: [CI2251,6 Yellow Seeds]
Later in this guide, purchase the remaining supplies.
Buy these if they are missing: 1 Copper Flask. Yellow Seeds (you need 6 total) and 8 Blue Petals.
Follow the corridor to its next turn.
]], 'reference')
local audit = EfficientQuests.ExtractGuide('Audit', {})
assert(#audit == 3, 'reviewed shopping advice remains while route prose is withheld')
assert(audit[1].text:find('1 Copper Flask', 1, true), 'stated single item quantity remains in hint')
assert(audit[2].text:find('6 Yellow Seeds', 1, true), 'stated multi-item quantity remains in hint')
assert(audit[3].text:find('if they are missing', 1, true) and audit[3].text:find('8 Blue Petals', 1, true), 'conditional list is complete')
print('ok - reviewed TUG shopping excerpts preserve quantities and avoid route fragments')
EfficientQuests_RegisterGuide('HordeAudit', [[
[N 32 Gnomeregan]
If available, buy [CI2842,1 Iron Coin] and [CI1206,1 Blue Bead].
Find a group for the dungeon.
Keep skinning for extra money.
[G1,2 The Barrens] Buy: [CI2321,4 Linen Thread]at [TAR3485]
]], 'reference')
local hordeAudit = EfficientQuests.ExtractGuide('HordeAudit', {})
assert(#hordeAudit == 1, 'unrelated training, dungeon routing and ambiguous multiple items are withheld')
assert(hordeAudit[1].text == 'Buy: 4 Linen Thread', 'missing target metadata must not leave dangling wording')
print('ok - reviewed Horde examples avoid ambiguous and unrelated instructions')
EfficientQuests_RegisterGuide('Techniques', [[
[N Feralas]
[G40.93,25.55 Feralas] Use the small device on the creatures before defeating them for [QC7003].
Gather the herbs while collecting feathers for [QC4402], [QC97279], and [QC789].
Kill ten wolves for [QC78].
[LE SP21562 1] Use the quest codex before entering the shrine for [QC77].
]], 'reference')
local techniques = EfficientQuests.ExtractGuide('Techniques', {})
assert(#techniques == 3, 'practical quest techniques are retained and bare objectives excluded')
assert(techniques[1].questID == 7003 and techniques[1].kind == 'technique', 'specific technique retains its explicit quest association')
assert(techniques[2].questID == nil and techniques[2].association == 'quests' and #techniques[2].questIDs == 3, 'multiple quest references must not collapse to one')
assert(techniques[2].uncertain, 'shared prose must not imply the exact association for each quest is known')
assert(techniques[3].learningState[1].id == 21562 and techniques[3].learningState[1].known == nil and techniques[3].uncertain, 'unknown learning state is preserved')
local knownTechniques = EfficientQuests.ExtractGuide('Techniques', {isSpellKnown=function(id) return id == 21562 end})
assert(knownTechniques[3].learningState[1].known == true, 'positive learning observation is preserved')
assert(knownTechniques[3].questID == 77, 'a learning marker does not imply quest completion')
print('ok - quest techniques, multiple references and learning-state uncertainty')
EfficientQuests_RegisterGuide('Training', [[
[N Tanaris]
[A Priest] [LE SP21562 1] Buy and use a training manual from a vendor.
]], 'reference')
assert(#EfficientQuests.ExtractGuide('Training', {class='Priest'}) == 0, 'general class training must not become a questing tip')
print('ok - unrelated class training is excluded')
EfficientQuests_RegisterGuide('TUGConditions', [[
[N Tanaris]
[G1,2 Tanaris] For the escort quest, wait for all group members to turn in before starting the follow-up!
Buy one blue seed, two red seeds, and three green seeds. For the items: buy in this order; if the first item is unavailable, skip the others because they depend on each other.
]], 'reference')
local tugConditions = EfficientQuests.ExtractGuide('TUGConditions', {})
assert(#tugConditions == 2, 'quest mechanic and ordered multi-item advice survive')
assert(tugConditions[1].kind == 'technique' and tugConditions[1].association == 'zone', 'unlinked mechanic stays an unassociated zone tip')
assert(tugConditions[1].text:find('group members to turn in', 1, true), 'group turn-in condition stays visible')
assert(tugConditions[2].text:find('skip the others', 1, true), 'ordering condition remains visible')
assert(tugConditions[2].text:find('blue seed', 1, true) and tugConditions[2].text:find('green seeds', 1, true), 'all ordered items remain visible')
print('ok - TUG escort mechanics and conditional buying order')
EfficientQuests_RegisterGuide('CrossSentence', [[
[N Un'Goro Crater]
[G79.65,49.83 Un'Goro Crater] Use the beacon to call a creature. Defeat that creature for [QC4292].
]], 'reference')
local cross = EfficientQuests.ExtractGuide('CrossSentence', {})
assert(#cross == 1 and cross[1].kind == 'technique', 'a nearby practical technique remains available')
assert(cross[1].questID == nil and cross[1].association == 'zone', 'cross-sentence references are not presented as confirmed associations')
assert(cross[1].inferredQuestIDs[1] == 4292 and cross[1].uncertain, 'cross-sentence evidence remains explicitly inferred')
assert(not cross[1].sourceText:find('Defeat', 1, true), 'excerpt omits unrelated outcome prose')
print('ok - tentative cross-sentence association stays distinct from source fact')
EfficientQuests_RegisterGuide('CrossRoute', [[
[N Example]
[G2,3 Example] Use your [H] Hearthstone. Defeat ten enemies for [QC7].
]], 'reference')
assert(#EfficientQuests.ExtractGuide('CrossRoute', {}) == 0, 'route travel is not promoted to quest technique by adjacency')
print('ok - tentative association excludes route travel')
EfficientQuests_RegisterGuide('StoryOrdering', [[
[N Tanaris]
[G1,2 Tanaris] Buy one blue seed, two red seeds, and three green seeds. For the items: buy in this order; the king is murdered.
]], 'reference')
assert(#EfficientQuests.ExtractGuide('StoryOrdering', {}) == 0, 'ordered advice must not reintroduce narrative outcomes')
print('ok - ordered advice does not bypass narrative screening')
EfficientQuests_RegisterGuide('EncounterMechanic', [[
[N Hillsbrad]
[G1,2 Hillsbrad Foothills] Use the quest item to spawn an enemy. Start at full health and use your defensive skill.
]], 'reference')
local encounter = EfficientQuests.ExtractGuide('EncounterMechanic', {})
assert(#encounter == 1 and encounter[1].association == 'zone', 'TUG encounter preparation survives without invented quest association')
assert(encounter[1].text:find('full health', 1, true) and encounter[1].text:find('spawn an enemy', 1, true), 'encounter and precaution remain together')
print('ok - practical encounter details remain available as uncertain zone advice')
EfficientQuests_RegisterGuide('CompactItem', [[
[N Shopping List]
Buy [CI2592,300Blue Cloth]
]], 'reference')
local compactItem = EfficientQuests.ExtractGuide('CompactItem', {})
assert(#compactItem == 1 and compactItem[1].itemID == 2592 and compactItem[1].quantity == 300, 'TUG compact item tags retain identifier and quantity')
assert(compactItem[1].text:find('300 Blue Cloth', 1, true), 'TUG compact item tags retain a useful item name')
print('ok - TUG compact item tags do not discard the name')
EfficientQuests_RegisterGuide('TUGRoutePressure', [[
[N Desolace]
[G1,2 Desolace] You will have more chances to buy supplies.
This is the last chance to buy the missing papers.
]], 'reference')
assert(#EfficientQuests.ExtractGuide('TUGRoutePressure', {}) == 0, 'route-relative shopping pressure must not become stand-alone advice')
print('ok - TUG route-relative shopping pressure is excluded')
EfficientQuests_RegisterGuide('TUGMismatch', [[
[N Shopping List]
Buy [CI2725,1 Imaginary Page Ten]
]], 'reference')
local mismatch = EfficientQuests.ExtractGuide('TUGMismatch', {})
assert(mismatch[1].itemID == 2725 and mismatch[1].itemSourceName == 'Imaginary Page Ten', 'provider can compare the source label with its identifier')
print('ok - conflicting guide identifiers can be checked against their source labels')

EfficientQuests_RegisterGuide('UnrelatedShopping', [[
[N Greenfield]
[G1,2 Greenfield] Buy a skinning knife from the merchant.
[G1,2 Greenfield] Buy a new weapon for your class.
[G1,2 Greenfield] Buy [CI42,3 Apples] for [QC101].
]], 'synthetic')
local relevantShopping = EfficientQuests.ExtractGuide('UnrelatedShopping', {})
assert(#relevantShopping == 1 and relevantShopping[1].questID == 101,
  'unrelated profession and class equipment must not crowd out quest preparation')
print('ok - unrelated class and profession purchases are withheld')

EfficientQuests_RegisterGuide('NarrativeReason', [[
[N Greenfield]
[G1,2 Greenfield] Buy [CI42,3 Apples] because the advisor poisoned the king.
]], 'synthetic')
assert(#EfficientQuests.ExtractGuide('NarrativeReason', {}) == 0,
  'unsupported narrative explanations must not be displayed as advice or source context')
print('ok - narrative causal explanation is withheld')

EfficientQuests_RegisterGuide('QuestTagLists', [[
[N Greenfield]
[G1,2 Greenfield] Buy [CI42,3 Apples] for [QC101], [QC102], and [QC103].
[G1,2 Greenfield] Defeat the bandit leader for [QC104], then return to the camp before dark.
[G1,2 Greenfield] Collect eight reagents for [QC105] before leaving the grove.
[G1,2 Greenfield] Buy [CI42,5 Apples] for [QC101].
[G1,2 Greenfield] Collect a token and a badge for [QC106] and [QC107] before leaving the hall.
[G1,2 Greenfield] Buy a lantern for the mine shaft.
]], 'synthetic')
local lists = EfficientQuests.ExtractGuide('QuestTagLists', {})
assert(#lists == 6, 'quest-tag lists with practical verbs remain available')
assert(not lists[1].text:find('for ,', 1, true) and not lists[1].text:find('for  ', 1, true),
  'a quest-tag list must not leave dangling punctuation')
assert(lists[1].text:find('for these quests', 1, true), 'multiple quest tags resolve to a plural reference')
assert(#lists[1].questIDs == 3 and lists[1].association == 'quests', 'tag list quests are all retained')
assert(lists[2].text:find('for this quest, then return', 1, true),
  'a single tag followed by more prose keeps its punctuation')
assert(lists[3].text:find('for this quest before leaving', 1, true),
  'a single tag followed by a condition keeps its meaning')
assert(lists[4].text == 'Buy 5 Apples for this quest.',
  'a trailing single quest tag keeps its established wording')
assert(lists[5].text:find('for these quests before leaving', 1, true),
  'two tags joined by and resolve to a plural reference')
assert(lists[6].text == 'Buy a lantern for the mine shaft.',
  'an ordinary use of for is preserved verbatim')
print('ok - quest-tag lists render as standalone references')

EfficientQuests_RegisterGuide('PrefixTags', [[
[N Greenfield]
[A Mage] [G30.09,71.52 Greenfield] [CI2901,1] Buy a pick from the merchant; keep it in your bags.
[A Mage] [G25.81,75.55 Greenfield] [V] Buy a usable early wand at the auction house.
[A Mage] [G43.85,43.89 Greenfield] [CI4470,1] Buy one Simple Wood from the merchant for your first campfire kit.
[G70.95,72.51 Greenfield] Buy a pick from the merchant.
]], 'synthetic')
local prefixed = EfficientQuests.ExtractGuide('PrefixTags', {class='Mage'})
assert(#prefixed == 4, 'advice with prefixed position tags remains available')
assert(prefixed[1].text == 'Buy a pick from the merchant; keep it in your bags.',
  'a coordinate tag after condition tags is a position marker, not prose')
assert(prefixed[1].itemID == 2901 and prefixed[1].quantity == 1,
  'dropping the marker rendering keeps the item identity')
assert(prefixed[2].text == 'Buy a usable early wand at the auction house.',
  'a zone name from a position marker must not start the visible text')
assert(prefixed[3].text == 'Buy one Simple Wood from the merchant for your first campfire kit.',
  'a nameless item tag before the prose must not render as a bare count')
print('ok - position-marker tags do not leak into visible advice')

EfficientQuests_RegisterGuide('FlightPoints', [[
[N Greenfield]
[A Druid,Night Elf] [G58.38,94.01 Greenfield] [P Rut'theran Village] Take the regular gryphon point before boarding the boat.
[A Druid,Night Elf] [G36.33,45.09 Greenfield] [P Auberdine] Take the gryphon point on arrival.
[G70.95,72.51 Greenfield] [P Stormwind] Collect the gryphon point if you don't already have it.
[G51.50,30.34 Greenfield] [P The Crossroads] Take the wind rider point on arrival.
[G55.50,47.74 Greenfield] Learn the flight path at the mountain outpost.
]], 'synthetic')
local points = EfficientQuests.ExtractGuide('FlightPoints', {class='Druid', race='Night Elf'})
assert(#points == 5, 'gryphon and wind rider advice is available alongside flight paths')
for _, point in ipairs(points) do
  assert(point.kind == 'flight', 'gryphon and wind rider points are travel opportunities')
end
assert(points[1].text:find("Rut'theran Village", 1, true),
  'a named flight point tag keeps its name in the visible text')
assert(points[2].text:find('Auberdine', 1, true) and points[2].text:find('gryphon point', 1, true),
  'the flight point name and action stay together')
assert(points[3].text:find('if you don', 1, true),
  "the guide's own conditional wording is preserved")
assert(points[4].text:find('The Crossroads', 1, true) and points[4].text:find('wind rider', 1, true),
  'horde flight points use their own wording')
assert(not points[5].text:find('%['), 'existing flight path advice is unchanged')
print('ok - gryphon and wind rider points become named travel advice')

EfficientQuests_RegisterGuide('DirectiveItems', [[
[N Greenfield]
Do: [QC201-][QC202-][QC203][CI501,7 Spider Silk]
[O]Do: [QC204][CI501,7 Spider Silk]
Do: [QC205][CI501,7 Spider Silk][CI502,4 Turtle Meat]
Do: [QC206]
Now get [CI501,7 Spider Silk].
]], 'synthetic')
local directives = EfficientQuests.ExtractGuide('DirectiveItems', {})
assert(#directives == 2, 'only item-bearing objective directives carry extractable knowledge')
assert(directives[1].kind == 'supply' and directives[1].itemID == 501 and directives[1].quantity == 7,
  'the directive item and quantity become a supply requirement')
assert(directives[1].text == '7 Spider Silk needed for these quests.',
  'the requirement is stated without adopting the route directive')
assert(#directives[1].questIDs == 3 and directives[1].association == 'quests'
  and directives[1].uncertain, 'directive requirements stay quest-linked and uncertain')
assert(directives[2].text == '7 Spider Silk needed for this quest.',
  'a single directive quest reference uses the established singular wording')
print('ok - item-bearing objective directives preserve their requirement')

EfficientQuests_RegisterGuide('FlightPointWording', [[
[N Greenfield]
[G65.5,24.3 Greenfield] [P Northgate Keep] Ride south into the valley, then follow the road east to Northgate Keep. Collect its flight point before entering the keep.
[G1,2 Greenfield] Repair your gear at the smith.
]], 'synthetic')
local flightWording = EfficientQuests.ExtractGuide('FlightPointWording', {})
assert(#flightWording == 1, 'flight point wording is recognized as travel advice')
assert(flightWording[1].kind == 'flight', 'collecting a flight point is a travel opportunity')
assert(flightWording[1].text:find('Collect its flight point', 1, true),
  'the flight point sentence is the advice, not the riding directions')
assert(not flightWording[1].text:find('Ride south', 1, true),
  'a fortress name must not mistake route riding for retention advice')
assert(flightWording[1].text:find('Northgate Keep', 1, true),
  'the named flight point stays visible with its advice')
print('ok - flight point wording and fortress names are distinguished')

-- A guide plugin registers under its own addon name as the registry key, one
-- call per chapter, and the list metadata serves the settings page through
-- the addon-list service.
local plugin = 'EfficientQuests_ExampleGuide'
EfficientQuests_RegisterGuide(plugin, [[
[N Greenfield 1-5]
[G1,2 Greenfield] Buy [CI42,3 Apples].
]], 'Example Author')
EfficientQuests_RegisterGuide(plugin, [[
[N Greenfield 5-9]
[G2,3 Greenfield] Buy [CI43,2 Bread].
]], 'Example Author')
C_AddOns = { GetAddOnMetadata = function(name, field)
  if name == plugin and field == 'Title' then return 'Example Guide' end
end }
local list = EfficientQuests.GetGuideList()
local pluginEntry, auditEntry
for _, entry in ipairs(list) do
  if entry.key == plugin then pluginEntry = entry end
  if entry.key == 'Audit' then auditEntry = entry end
end
assert(pluginEntry, 'a guide registered under a plugin addon name must be listed')
assert(pluginEntry.name == 'Example Guide', 'the display name comes from the plugin manifest title')
assert(pluginEntry.author == 'Example Author', 'the author comes from the first registered chapter')
assert(pluginEntry.chapters == 2 and #EfficientQuests.guides[plugin] == 2,
  'each registration call must append one chapter under the plugin addon name')
assert(auditEntry, 'every registered guide stays listed')
assert(auditEntry.name == 'Audit', 'a guide without manifest metadata falls back to its key')
assert(auditEntry.author == 'reference' and auditEntry.chapters == 1,
  'list metadata matches the registered tuple')
for index = 2, #list do
  assert(list[index - 1].key < list[index].key, 'the guide list is sorted by key')
end
print('ok - plugin guide list metadata and chapter append')
