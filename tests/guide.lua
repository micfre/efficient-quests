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
