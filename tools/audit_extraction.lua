-- Offline extraction audit: run the addon's guide extraction over locally
-- installed guide packages and report coverage and safety findings.
--
-- Usage (lua 5.1, from the repository root):
--   lua tools/audit_extraction.lua <package-dir> [<package-dir> ...]
--
-- Each package directory must contain a .toc file listing its guide files,
-- matching the layout of the installed third-party packages. The tool only
-- reads those files; it never writes them and never copies their content into
-- the repository. Printed excerpts are for local review by the operator and
-- are not committed.

DEFAULT_CHAT_FRAME = {AddMessage = function() end}
SlashCmdList = {}
function CreateFrame() return {RegisterEvent = function() end, SetScript = function() end} end
for line in io.lines('EfficientQuests/EfficientQuests.toc') do
  if line:match('%.lua$') then assert(loadfile('EfficientQuests/' .. line))('EfficientQuests', {}) end
end

local contexts = {
  {name='alliance mage', faction='Alliance', class='Mage', race='Human'},
  {name='alliance druid', faction='Alliance', class='Druid', race='Night Elf',
    professions={herbalism=true}, countCarried=function() return 0 end,
    isSpellKnown=function() return false end, skillRanks={}},
  {name='alliance hunter', faction='Alliance', class='Hunter', race='Dwarf'},
  {name='alliance paladin', faction='Alliance', class='Paladin', race='Human',
    professions={}, countCarried=function() return 0 end},
  {name='horde warrior', faction='Horde', class='Warrior', race='Orc',
    professions={mining=true}, countCarried=function() return 0 end},
  {name='alliance warrior', faction='Alliance', class='Warrior', race='Human'},
  {name='alliance warlock', faction='Alliance', class='Warlock', race='Gnome'},
  {name='horde warlock', faction='Horde', class='Warlock', race='Undead'},
  {name='horde shaman', faction='Horde', class='Shaman', race='Tauren',
    professions={}, countCarried=function() return 0 end},
  {name='horde hunter', faction='Horde', class='Hunter', race='Troll'},
}

local routePhrases = {'next step', 'previous step', 'this guide', 'last chance',
  'more chances', 'each time you do', 'keep an eye', 'later in this guide',
  'die and rezz'}
-- Mirrors the narrative screen used by the addon's extraction. Findings here
-- mean the addon displayed prose its own screen was meant to withhold.
local spoilerPhrases = {' is murdered', ' was murdered', ' is killed', ' was killed',
  ' is secretly ', ' turns out ', ' is revealed', ' betrays ', ' betrayed ',
  ' poisoned ', ' assassinates ', ' assassinated ', ' dies', ' death of ',
  ' true identity'}
-- Broader phrases that need human eyes but are often mechanical, not narrative.
local watchPhrases = {' revealed', ' discover', ' secretly ', ' betrayal',
  ' disguised ', ' in disguise', ' actually the', ' plot', ' villain',
  ' twist', ' corrupted by', ' mind control', ' possessed by'}

local function trim(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end

local function collectFiles(dir)
  local tocName
  local pipe = io.popen('ls "' .. dir .. '"')
  for name in pipe:lines() do
    if name:match('%.toc$') and not tocName then tocName = name end
  end
  pipe:close()
  if not tocName then return nil, 'no .toc in ' .. dir end
  local files = {}
  for line in io.lines(dir .. '/' .. tocName) do
    if not line:match('^##') then
      local path = line:match('%S+.*%.lua%s*$')
      if path then files[#files + 1] = trim(path) end
    end
  end
  return files, nil, tocName
end

-- Extract every registerGuide long-string call from one guide file.
local function loadGuides(path)
  local handle = io.open(path, 'r')
  if not handle then return {} end
  local content = handle:read('*a')
  handle:close()
  local guides = {}
  for body, author in content:gmatch('Guidelime%.registerGuide%s*%(%s*%[%[(.-)%]%]%s*,%s*"([^"]*)"') do
    guides[#guides + 1] = {body=body, author=author}
  end
  if #guides == 0 then
    for body in content:gmatch('Guidelime%.registerGuide%s*%(%s*%[%[(.-)%]%]%s*%)') do
      guides[#guides + 1] = {body=body, author=nil}
    end
  end
  return guides
end

local function hasAny(lower, phrases)
  for _, phrase in ipairs(phrases) do
    if lower:find(phrase, 1, true) then return phrase end
  end
end

local function isCandidate(line)
  local s = line:lower()
  if s:match('^%s*%[') and not s:find('%a') then return false end
  return s:find('buy', 1, true) or s:find('%f[%a]keep%f[%A]') or s:find('save', 1, true)
    or s:find('stock up', 1, true) or s:find('flight ?path', 1, true)
    or s:find('flight master', 1, true) or s:find('gryphon point', 1, true)
    or s:find('wind rider', 1, true) or s:find('needed for', 1, true)
    or s:find('quest items', 1, true) or s:find('%[ci%d')
    or (s:find('%[qc%d') and (s:find('while ', 1, true) or s:find('before ', 1, true)))
end

local function checkRecord(record, report, where)
  local text = record.text or ''
  local lower = text:lower()
  local phrase = hasAny(lower, routePhrases)
  if phrase then
    report[#report + 1] = {severity='ROUTE', where=where, id=record.id, detail='route phrase in text: "' .. phrase .. '"', text=text}
  end
  phrase = hasAny(lower, spoilerPhrases)
  if phrase then
    report[#report + 1] = {severity='SPOILER', where=where, id=record.id, detail='possible narrative phrase in text: "' .. phrase .. '"', text=text}
  end
  phrase = hasAny(lower, watchPhrases)
  if phrase then
    report[#report + 1] = {severity='WATCH', where=where, id=record.id, detail='review phrase in text: "' .. phrase .. '"', text=text}
  end
  if text:find(' for%s*$') or text:find('for%s+%.') or text:find('at%s*:%s*$')
      or text:find(' %.') or text:find(' ,') or text:find('  ') or text == '' then
    report[#report + 1] = {severity='DANGLING', where=where, id=record.id, detail='dangling or malformed text', text=text}
  end
  if text:find('%[') and trim(text:gsub('%b[]', '')) == trim(text) then
    report[#report + 1] = {severity='TAGS', where=where, id=record.id, detail='unstripped guide tag in text', text=text}
  end
  -- Meaning preservation: quantities from tags survive into the text or on
  -- the record itself, where downstream wording can still use them.
  for id, quantity in record.sourceText:gmatch('%[CI(%d+)%s*,%s*(%d+)') do
    local carried = tostring(record.itemID) == id and tostring(record.quantity) == quantity
    if not carried and not text:find(quantity, 1, true) then
      report[#report + 1] = {severity='QUANTITY', where=where, id=record.id,
        detail='quantity ' .. quantity .. ' for item ' .. id .. ' missing from text and record', text=text}
    end
  end
  if record.itemSourceName and record.itemSourceName ~= ''
      and not text:lower():find(record.itemSourceName:lower(), 1, true) then
    report[#report + 1] = {severity='NAME', where=where, id=record.id,
      detail='tag item name missing from text', text=text}
  end
  local count, first = 0, nil
  for id in record.sourceText:gmatch('%[QC(%d+)') do
    count = count + 1
    first = first or id
  end
  if count == 1 and record.questID ~= tonumber(first) then
    report[#report + 1] = {severity='QUEST', where=where, id=record.id, detail='single quest reference not linked', text=text}
  end
end

local function auditPackage(dir)
  local package = dir:match('([^/\\]+)$')
  local files, err, tocName = collectFiles(dir)
  if not files then print('SKIP ' .. package .. ': ' .. err) return end
  EfficientQuests.guides[package] = nil
  local totalGuides, totalLines, candidateLines = 0, 0, 0
  local candidates = {}
  for _, file in ipairs(files) do
    for _, guide in ipairs(loadGuides(dir .. '/' .. (file:gsub('\\', '/')))) do
      EfficientQuests_RegisterGuide(package, guide.body, guide.author)
      totalGuides = totalGuides + 1
      local n = 0
      for line in (guide.body .. '\n'):gmatch('(.-)\r?\n') do
        n = n + 1
        if isCandidate(line) then
          candidateLines = candidateLines + 1
          candidates[#candidates + 1] = {file=file, line=n, text=trim(line)}
        end
      end
      totalLines = totalLines + n
    end
  end
  local function locate(record)
    local source = trim(record.sourceText)
    for _, candidate in ipairs(candidates) do
      if candidate.text == source or candidate.text:find(source, 1, true) then
        return candidate.file .. ':' .. candidate.line
      end
    end
    return '?'
  end
  local report, byKind, byAssociation = {}, {}, {}
  local extractedPieces = {}
  local recordsByContext = {}
  for _, context in ipairs(contexts) do
    local ok, records = pcall(EfficientQuests.ExtractGuide, package, context)
    if not ok then
      report[#report + 1] = {severity='ERROR', where=package, id='-', detail='ExtractGuide failed: ' .. tostring(records), text=''}
      records = {}
    end
    recordsByContext[context.name] = #records
    for _, record in ipairs(records) do
      checkRecord(record, report, package .. ' ' .. locate(record))
      byKind[record.kind or '(nil)'] = (byKind[record.kind or '(nil)'] or 0) + 1
      byAssociation[record.association] = (byAssociation[record.association] or 0) + 1
      extractedPieces[#extractedPieces + 1] = trim(record.sourceText)
    end
  end
  print('== ' .. package .. ' (' .. tocName .. ', ' .. #files .. ' files, '
    .. totalGuides .. ' guides, ' .. totalLines .. ' lines)')
  local kinds = {}
  for kind in pairs(byKind) do kinds[#kinds + 1] = kind end
  table.sort(kinds)
  local parts = {}
  for _, kind in ipairs(kinds) do parts[#parts + 1] = kind .. '=' .. byKind[kind] end
  print('   advice records (all contexts): ' .. table.concat(parts, ' '))
  local assoc = {}
  for a in pairs(byAssociation) do assoc[#assoc + 1] = a end
  table.sort(assoc)
  parts = {}
  for _, a in ipairs(assoc) do parts[#parts + 1] = a .. '=' .. byAssociation[a] end
  print('   associations: ' .. table.concat(parts, ' '))
  local perContext = {}
  for _, context in ipairs(contexts) do
    perContext[#perContext + 1] = context.name .. '=' .. recordsByContext[context.name]
  end
  print('   per context: ' .. table.concat(perContext, ' '))
  local withheld = {}
  for _, candidate in ipairs(candidates) do
    local covered = false
    for _, piece in ipairs(extractedPieces) do
      if piece ~= '' and candidate.text:find(piece, 1, true) then covered = true break end
    end
    if not covered then withheld[#withheld + 1] = candidate end
  end
  table.sort(withheld, function(a, b)
    if a.file ~= b.file then return a.file < b.file end
    return a.line < b.line
  end)
  print('   candidate lines: ' .. candidateLines .. ', withheld: ' .. #withheld)
  local shown, findingCount = {}, 0
  for _, item in ipairs(report) do
    local key = item.severity .. '|' .. item.id .. '|' .. item.detail
    if not shown[key] then
      shown[key] = true
      findingCount = findingCount + 1
      print(string.format('   [%s] %s %s :: %s', item.severity, item.where, item.id, item.detail))
      if item.text ~= '' then print('       text: ' .. item.text) end
    end
  end
  if #withheld > 0 then
    print('   withheld candidate lines (file:line, for manual review):')
    for _, candidate in ipairs(withheld) do
      print('     ' .. candidate.file .. ':' .. candidate.line .. ' :: ' .. candidate.text)
    end
  end
  return {package=package, findings=findingCount, withheld=#withheld, candidates=candidateLines}
end

if #arg == 0 then
  print('usage: lua tools/audit_extraction.lua <package-dir> [<package-dir> ...]')
  return
end
local summaries = {}
for i = 1, #arg do summaries[#summaries + 1] = auditPackage(arg[i]) end
print('== summary')
for _, s in ipairs(summaries) do
  print(string.format('   %s: %d findings, %d/%d candidate lines withheld',
    s.package, s.findings, s.withheld, s.candidates))
end
