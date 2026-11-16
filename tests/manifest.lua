-- Packaging checks for the shipped addon. The game client reads the manifest
-- to learn the dependency requirements and the load order, so these
-- assertions read the manifest text and the files it ships. This is the same
-- surface an installer receives, and no game services are needed.

local function readAll(path)
  local text = ''
  for line in io.lines(path) do text = text .. line .. '\n' end
  return text
end

local function readFileList(text)
  local files = {}
  for line in text:gmatch('[^\n]+') do
    if line:match('%.lua$') then table.insert(files, line) end
  end
  return files
end

local function splitNames(value)
  local names = {}
  for name in (value or ''):gmatch('[^,]+') do
    names[name:match('^%s*(.-)%s*$')] = true
  end
  return names
end

local function standaloneMention(text, name)
  local lowered, at = text:lower(), 1
  while true do
    local from, to = lowered:find(name, at, true)
    if not from then return false end
    local before = from > 1 and lowered:sub(from - 1, from - 1) or ''
    local after = to < #lowered and lowered:sub(to + 1, to + 1) or ''
    local function partOfLongerName(char) return char ~= '' and char:find('^[%w_]$') ~= nil end
    if not partOfLongerName(before) and not partOfLongerName(after) then return true end
    at = to + 1
  end
end

local manifestText = readAll('dist/EfficientQuests/EfficientQuests.toc')

local fields = {}
for line in manifestText:gmatch('[^\n]+') do
  local field, value = line:match('^##%s*(%a+):%s*(.-)%s*$')
  if field then fields[field:lower()] = value end
end

assert(fields['interface'] == '16001', 'the addon targets the Forever client: the interface number must be 16001')
assert(fields['version'] == '0.3.0', 'the manifest must declare version 0.3.0')
print('ok - manifest declares interface 16001 and version 0.3.0')

local required = splitNames(fields['dependencies'] or fields['requireddeps'])
local optional = splitNames(fields['optionaldeps'])
assert(not next(required), 'the addon must work on a plain setup: no addon may be required')
for _, addon in ipairs({'FlareUI', 'TomTom', 'QuestieDB'}) do
  assert(optional[addon] and not required[addon], addon .. ' must be an optional dependency')
end
print('ok - FlareUI, TomTom, and QuestieDB are optional and nothing is required')

local saved = splitNames(fields['savedvariables'])
local savedPerCharacter = splitNames(fields['savedvariablespercharacter'])
assert(saved['EfficientQuestsDB'] and not savedPerCharacter['EfficientQuestsDB'],
  'EfficientQuestsDB must be the account-wide store and only that')
assert(savedPerCharacter['EfficientQuestsCharacter'] and not saved['EfficientQuestsCharacter'],
  'EfficientQuestsCharacter must be the per-character store and only that')
print('ok - the account-wide and per-character saved stores are declared')

local files = readFileList(manifestText)
local listed = {}
for index, file in ipairs(files) do listed[file] = index end

for _, file in ipairs(files) do
  assert(not file:find('\\', 1, true),
    'manifest paths must use forward slashes, which the offline loader also reads: ' .. file)
  assert(not file:find('Pins', 1, true), 'no pins file may ship in the addon folder: ' .. file)
end
assert(not io.open('dist/EfficientQuests/Libs/HereBeDragons/HereBeDragons-Pins-2.0.lua'),
  'the pins library draws on maps and must not sit in the addon folder unlisted')
print('ok - no pins file is listed or shipped')

assert(listed['Libs/LibStub/LibStub.lua'], 'LibStub must be embedded and loaded')
assert(listed['Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua'], 'CallbackHandler-1.0 must be embedded and loaded')
assert(listed['Libs/LibStub/LibStub.lua'] < listed['Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua'],
  'CallbackHandler-1.0 registers through LibStub, so LibStub must load first')
assert(listed['Libs/HereBeDragons/HereBeDragons-2.0.lua'], 'HereBeDragons 2.0 must be embedded and loaded')
assert(listed['Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua'] < listed['Libs/HereBeDragons/HereBeDragons-2.0.lua'],
  'HereBeDragons needs CallbackHandler-1.0, so CallbackHandler must load first')
print('ok - the three libraries are embedded in dependency order')

assert(listed['Core.lua'], 'the entry point must load')
assert(listed['Libs/HereBeDragons/HereBeDragons-2.0.lua'] < listed['Core.lua'],
  'the libraries must load before the addon code')
assert(not listed['Interface.lua'],
  'the old window module is a frozen reference and must stay out of the load order')
print('ok - the entry point loads after the libraries and the reference window stays unloaded')

for _, addon in ipairs({'Guidelime', 'Questie'}) do
  assert(not required[addon] and not optional[addon],
    addon .. ' must not be declared in the manifest')
end
print('ok - Guidelime and Questie are not declared')

local shipped = {{path = 'dist/EfficientQuests/EfficientQuests.toc', text = manifestText}}
for _, file in ipairs(files) do
  local path = 'dist/EfficientQuests/' .. file
  table.insert(shipped, {path = path, text = readAll(path)})
end
for _, entry in ipairs(shipped) do
  for _, name in ipairs({'guidelime', 'questie'}) do
    assert(not standaloneMention(entry.text, name),
      entry.path .. ' must not mention ' .. name ..
      ' as its own word, only inside longer names such as LibQuestieDB')
  end
end
print('ok - shipped files mention Guidelime and Questie only inside longer names')
