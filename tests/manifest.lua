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

local manifestText = readAll('EfficientQuests/EfficientQuests.toc')

local fields = {}
for line in manifestText:gmatch('[^\n]+') do
  local field, value = line:match('^##%s*(%a+):%s*(.-)%s*$')
  if field then fields[field:lower()] = value end
end

assert(fields['version'] == '0.2.0', 'the manifest must declare version 0.2.0')
print('ok - manifest version is 0.2.0')

local required = splitNames(fields['dependencies'] or fields['requireddeps'])
local optional = splitNames(fields['optionaldeps'])
assert(required['QuestieDB'], 'QuestieDB must be declared as a required dependency')
assert(not optional['QuestieDB'], 'QuestieDB must not stay an optional dependency')
assert(optional['FlareUI'] and not required['FlareUI'], 'FlareUI must stay an optional dependency')
print('ok - QuestieDB is required and FlareUI is optional')

for _, addon in ipairs({'Guidelime', 'Questie'}) do
  assert(not required[addon] and not optional[addon],
    addon .. ' must not be declared in the manifest')
end
print('ok - Guidelime and Questie are not declared')

local shipped = {{path = 'EfficientQuests/EfficientQuests.toc', text = manifestText}}
for _, file in ipairs(readFileList(manifestText)) do
  local path = 'EfficientQuests/' .. file
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
