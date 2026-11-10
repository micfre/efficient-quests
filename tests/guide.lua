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
