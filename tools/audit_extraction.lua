-- Offline extraction audit: run the addon's guide extraction over locally
-- installed guide packages and report coverage and safety findings.
--
-- Usage (lua 5.1, from the repository root):
--   lua tools/audit_extraction.lua <package-dir> [<package-dir> ...] [--json]
--
-- Each package directory must contain a .toc file listing its guide files,
-- matching the layout of the installed third-party packages. Two guide file
-- shapes are read: source packages whose files call
-- `Guidelime.registerGuide([[...]], "author")` and built plugin folders whose
-- Guides.lua calls `EfficientQuests_RegisterGuide("Plugin", [[...]], "author")`.
-- The author argument is optional in both shapes. The tool only reads those
-- files; it never writes them and never copies their content into the
-- repository. Printed excerpts are for local review by the operator and are
-- not committed.
--
-- Without --json the tool prints the human report described above. With
-- --json it prints one machine-readable JSON document instead (packages,
-- counts, and findings) and exits 0 when every package was audited, 2 when a
-- package could not be read, and 1 on a usage error. The builder
-- (tools/build_guide.py) consumes this mode as its extraction gate.

DEFAULT_CHAT_FRAME = {AddMessage = function() end}
SlashCmdList = {}
function CreateFrame() return {RegisterEvent = function() end, SetScript = function() end} end
for line in io.lines('dist/EfficientQuests/EfficientQuests.toc') do
  if line:match('%.lua$') then assert(loadfile('dist/EfficientQuests/' .. line))('EfficientQuests', {}) end
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

-- Machine mode: --json replaces the human report with one JSON document.
local jsonMode = false
local function emit(...)
  if not jsonMode then print(...) end
end

local function collectFiles(dir)
  -- Most packages, including every built plugin, name the TOC after the
  -- directory; io.open settles those without a shell. The listing fallback
  -- covers packages such as Bethink, whose TOC name differs.
  local package = dir:match('([^/\\]+)$')
  local tocName = package and package .. '.toc' or nil
  if tocName then
    local probe = io.open(dir .. '/' .. tocName, 'r')
    if probe then probe:close() else tocName = nil end
  end
  if not tocName then
    local pipe = io.popen('ls "' .. dir .. '"')
    for name in pipe:lines() do
      if name:match('%.toc$') and not tocName then tocName = name end
    end
    pipe:close()
  end
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

-- Registration calls appear in two shapes: source packages call
-- Guidelime.registerGuide([[body]], "author") and built plugins call
-- EfficientQuests_RegisterGuide("Plugin", [[body]], "author"). Each pattern
-- below carries the capture group of the body and, when it accepts one, of
-- the author.
local callPatterns = {
  {'Guidelime%.registerGuide%s*%(%s*%[%[(.-)%]%]%s*,%s*"([^"]*)"%s*%)', 1, 2},
  {'EfficientQuests_RegisterGuide%s*%(%s*"(.-)"%s*,%s*%[%[(.-)%]%]%s*,%s*"([^"]*)"%s*%)', 2, 3},
  {'Guidelime%.registerGuide%s*%(%s*%[%[(.-)%]%]%s*%)', 1},
  {'EfficientQuests_RegisterGuide%s*%(%s*"(.-)"%s*,%s*%[%[(.-)%]%]%s*%)', 2},
}

-- Extract every registration call from one guide file, in file order. A file
-- may mix shapes and author-less calls; each call is taken once.
local function loadGuides(path)
  local handle = io.open(path, 'r')
  if not handle then return {} end
  local content = handle:read('*a')
  handle:close()
  local calls = {}
  for _, pattern in ipairs(callPatterns) do
    local init = 1
    while true do
      local start, finish, one, two, three = content:find(pattern[1], init)
      if not start then break end
      local body, author
      if pattern[2] == 1 then body, author = one, two else body, author = two, three end
      -- A lazy body can run past its own closing bracket, over an author
      -- argument, and swallow the next call whole. A guide body never holds
      -- a registration call head, so reject those matches and rescan from
      -- the next position instead of trusting the first hit.
      if body:find('Guidelime%.registerGuide') or body:find('EfficientQuests_RegisterGuide') then
        init = start + 1
      else
        calls[#calls + 1] = {start = start, body = body, author = author}
        init = finish + 1
      end
    end
  end
  table.sort(calls, function(a, b) return a.start < b.start end)
  local guides = {}
  for _, call in ipairs(calls) do
    guides[#guides + 1] = {body = call.body, author = call.author}
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

-- Minimal JSON writing for the machine mode. Guide text reaches the findings
-- only through the fixed phrases of each screen, so the escaping below only
-- has to keep the document valid, not beautiful.
local jsonEscapes = {['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b',
  ['\f'] = '\\f', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t'}

local function jsonString(value)
  local escaped = tostring(value):gsub('[%c"\\]', function(ch)
    return jsonEscapes[ch] or string.format('\\u%04x', ch:byte())
  end)
  return '"' .. escaped .. '"'
end

local function jsonPairs(pairs_)
  local parts = {}
  for _, pair in ipairs(pairs_) do
    parts[#parts + 1] = jsonString(pair[1]) .. ':' .. pair[2]
  end
  return '{' .. table.concat(parts, ',') .. '}'
end

local function jsonList(values)
  return '[' .. table.concat(values, ',') .. ']'
end

local function jsonCounts(counts)
  local keys = {}
  for key in pairs(counts) do keys[#keys + 1] = key end
  table.sort(keys)
  local parts = {}
  for _, key in ipairs(keys) do
    parts[#parts + 1] = {key, string.format('%d', counts[key])}
  end
  return jsonPairs(parts)
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
  if not files then
    emit('SKIP ' .. package .. ': ' .. err)
    return {package = package, toc = tocName, error = err}
  end
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
  emit('== ' .. package .. ' (' .. tocName .. ', ' .. #files .. ' files, '
    .. totalGuides .. ' guides, ' .. totalLines .. ' lines)')
  local kinds = {}
  for kind in pairs(byKind) do kinds[#kinds + 1] = kind end
  table.sort(kinds)
  local parts = {}
  for _, kind in ipairs(kinds) do parts[#parts + 1] = kind .. '=' .. byKind[kind] end
  emit('   advice records (all contexts): ' .. table.concat(parts, ' '))
  local assoc = {}
  for a in pairs(byAssociation) do assoc[#assoc + 1] = a end
  table.sort(assoc)
  parts = {}
  for _, a in ipairs(assoc) do parts[#parts + 1] = a .. '=' .. byAssociation[a] end
  emit('   associations: ' .. table.concat(parts, ' '))
  local perContext = {}
  for _, context in ipairs(contexts) do
    perContext[#perContext + 1] = context.name .. '=' .. recordsByContext[context.name]
  end
  emit('   per context: ' .. table.concat(perContext, ' '))
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
  emit('   candidate lines: ' .. candidateLines .. ', withheld: ' .. #withheld)
  -- Findings are deduplicated the same way for the human report and the
  -- machine document: once per severity, record id, and detail.
  local shown, findings = {}, {}
  for _, item in ipairs(report) do
    local key = item.severity .. '|' .. item.id .. '|' .. item.detail
    if not shown[key] then
      shown[key] = true
      findings[#findings + 1] = item
      emit(string.format('   [%s] %s %s :: %s', item.severity, item.where, item.id, item.detail))
      if item.text ~= '' then emit('       text: ' .. item.text) end
    end
  end
  if #withheld > 0 then
    emit('   withheld candidate lines (file:line, for manual review):')
    for _, candidate in ipairs(withheld) do
      emit('     ' .. candidate.file .. ':' .. candidate.line .. ' :: ' .. candidate.text)
    end
  end
  return {package=package, toc=tocName, files=#files, guides=totalGuides,
    lines=totalLines, candidate_lines=candidateLines, withheld_lines=#withheld,
    advice_records=#extractedPieces, records_by_kind=byKind,
    associations=byAssociation, per_context=recordsByContext, findings=findings}
end

local function jsonFinding(item)
  return jsonPairs({
    {'severity', jsonString(item.severity)},
    {'where', jsonString(item.where)},
    {'id', jsonString(item.id)},
    {'detail', jsonString(item.detail)},
  })
end

local function jsonPackage(result)
  if result.error then
    return jsonPairs({
      {'package', jsonString(result.package)},
      {'error', jsonString(result.error)},
    })
  end
  local findings = {}
  for _, item in ipairs(result.findings) do findings[#findings + 1] = jsonFinding(item) end
  local bySeverity = {}
  for _, item in ipairs(result.findings) do
    bySeverity[item.severity] = (bySeverity[item.severity] or 0) + 1
  end
  return jsonPairs({
    {'package', jsonString(result.package)},
    {'toc', jsonString(result.toc)},
    {'files', string.format('%d', result.files)},
    {'guides', string.format('%d', result.guides)},
    {'lines', string.format('%d', result.lines)},
    {'candidate_lines', string.format('%d', result.candidate_lines)},
    {'withheld_lines', string.format('%d', result.withheld_lines)},
    {'advice_records', string.format('%d', result.advice_records)},
    {'records_by_kind', jsonCounts(result.records_by_kind)},
    {'associations', jsonCounts(result.associations)},
    {'per_context', jsonCounts(result.per_context)},
    {'findings', jsonList(findings)},
    {'findings_by_severity', jsonCounts(bySeverity)},
    {'error', 'null'},
  })
end

local jsonModeArgs = {}
for i = 1, #arg do
  if arg[i] == '--json' then jsonMode = true else jsonModeArgs[#jsonModeArgs + 1] = arg[i] end
end
if #jsonModeArgs == 0 then
  io.stderr:write('usage: lua tools/audit_extraction.lua <package-dir> [<package-dir> ...] [--json]\n')
  os.exit(1)
end
local summaries = {}
for i = 1, #jsonModeArgs do summaries[#summaries + 1] = auditPackage(jsonModeArgs[i]) end
if jsonMode then
  local packages = {}
  for _, s in ipairs(summaries) do packages[#packages + 1] = jsonPackage(s) end
  print(jsonPairs({{'packages', jsonList(packages)}}))
  for _, s in ipairs(summaries) do
    if s.error then os.exit(2) end
  end
  os.exit(0)
end
print('== summary')
for _, s in ipairs(summaries) do
  if s.error then
    print(string.format('   %s: skipped (%s)', s.package, s.error))
  else
    print(string.format('   %s: %d findings, %d/%d candidate lines withheld',
      s.package, #s.findings, s.withheld_lines, s.candidate_lines))
  end
end
