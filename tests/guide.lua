-- Exercise guide registration through the addon boundary, with a synthetic guide.
DEFAULT_CHAT_FRAME = {AddMessage = function() end}
SlashCmdList = {}
function CreateFrame() return {RegisterEvent = function() end, SetScript = function() end} end
for line in io.lines('EfficientQuests/EfficientQuests.toc') do
  if line:match('%.lua$') then assert(loadfile('EfficientQuests/' .. line))('EfficientQuests', {}) end
end
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
-- Short excerpts of the supplied TUG and Bethink compatibility references.
EfficientQuests_RegisterGuide('References', [[
[GA Alliance]
[N 24-25 Duskwood]
[G77.12,44.17Duskwood] Get the [P] flightpath at: [G77.12,44.17Duskwood]
KEEP YOUR Gooey Spider Legs.Whilst grinding east for the spider and wolf quests do the next 2steps
[A Nightelf] Buy [CI1,1 Seed].
[A Mining,IT2901<1] [OC] [G47.49,41.56 Elwynn Forest] [CI2901,1] Buy a Mining Pick from Brother Danil; keep it in your bags.
]], 'reference')
local reference = EfficientQuests.ExtractGuide('References', {
 faction='Alliance', race='Human', professions={mining=true}, countCarried=function(id) return 0 end
})
assert(#reference == 3, 'real guide snippets preserve useful advice and exclude another race')
assert(reference[2].text == 'KEEP YOUR Gooey Spider Legs.', 'mixed route advice keeps the useful standalone sentence')
assert(not reference[2].sourceText:find('2steps', 1, true), 'source excerpt omits unrelated route context')
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
[G78,48.3Duskwood] Buy: [CI4371,1 Bronze Tube]
Buy: [CI2251,6 Gooey Spider Leg]
If you did not get one yet that is fine, we will finish parts here now. At the end of this guide you will buy one from the ah.
Buy at the auction house now, if you did not get them yet: 1 Bronze tube. Gooey Spider Legs (you need 6 total) and 8 Murloc Fin.
Go further into Uldaman whilst keeping left, then turn right.
]], 'reference')
local audit = EfficientQuests.ExtractGuide('Audit', {})
assert(#audit == 2, 'ambiguous multi-item and route prose is withheld rather than misrepresented')
assert(audit[1].text:find('1 Bronze Tube', 1, true), 'stated single item quantity remains in hint')
assert(audit[2].text:find('6 Gooey Spider Leg', 1, true), 'stated multi-item quantity remains in hint')
print('ok - reviewed TUG shopping excerpts preserve quantities and avoid route fragments')
EfficientQuests_RegisterGuide('HordeAudit', [[
[N 32 Gnomeregan]
If its available on the auction house, buy: [CI2842,1 Silver Bar] [CI1206,1 Moss Agate]
Start looking for a Shadowfang Keep group.
I suggest to keep skinning to make some gold on the side though.
[G1,2 The Barrens] Buy: [CI2321,4 Coarse Thread]at [TAR3485]
]], 'reference')
local hordeAudit = EfficientQuests.ExtractGuide('HordeAudit', {})
assert(#hordeAudit == 1, 'unrelated training, dungeon routing and ambiguous multiple items are withheld')
assert(hordeAudit[1].text == 'Buy: 4 Coarse Thread', 'missing target metadata must not leave dangling wording')
print('ok - reviewed Horde examples avoid ambiguous and unrelated instructions')
EfficientQuests_RegisterGuide('Techniques', [[
[N Feralas]
[G40.93,25.55 Feralas] Use Zorbin's Ultra-Shrinker on the coastal giants before killing them; collect fifteen Miniaturization Residues for [QC7003].
Gather cactus apples while collecting tails for [QC4402], [QC97279], and [QC789].
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
[A Priest] [LE SP21562 1] Buy and use Codex: Prayer of Fortitude at the Auction House if available.
]], 'reference')
assert(#EfficientQuests.ExtractGuide('Training', {class='Priest'}) == 0, 'general class training must not become a questing tip')
print('ok - unrelated class training is excluded')
EfficientQuests_RegisterGuide('TUGConditions', [[
[N Tanaris]
[G1,2 Tanaris] Escort quest inv,if youre in a group, dont accept the follow before everyone has turned in!
Buy your missing Stranglethorn Pages as well as Frost Oil, Gyrochronatom and Patterned Bronze Bracers. For the Items: IN THIS ORDER AS WELL, If you cant get Item 1 do not buy item 2 and 3, they rely on each other as pre quests.
]], 'reference')
local tugConditions = EfficientQuests.ExtractGuide('TUGConditions', {})
assert(#tugConditions == 1, 'quest mechanic survives; ordered multi-item instruction is not truncated')
assert(tugConditions[1].kind == 'technique' and tugConditions[1].association == 'zone', 'unlinked mechanic stays an unassociated zone tip')
assert(tugConditions[1].text:find('everyone has turned in', 1, true), 'group turn-in condition stays visible')
print('ok - TUG escort mechanics and conditional buying order')
EfficientQuests_RegisterGuide('CrossSentence', [[
[N Un'Goro Crater]
[G79.65,49.83 Un'Goro Crater] Use the Preserved Threshadon Meat and Pheromone Mixture at the summoning site. Defeat the summoned creature for [QC4292].
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
