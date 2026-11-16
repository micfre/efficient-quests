-- Interpret registered guides as independent pieces of advice, not routes.
local EQ = EfficientQuests
local classes = {warrior=true, paladin=true, hunter=true, rogue=true, priest=true,
  shaman=true, mage=true, warlock=true, druid=true}
local races = {human=true, dwarf=true, ['night elf']=true, gnome=true, orc=true,
  undead=true, tauren=true, troll=true, skyborne=true}
local professions = {mining=true, skinning=true, herbalism=true, enchanting=true,
  engineering=true, blacksmithing=true, cooking=true, fishing=true, tailoring=true,
  leatherworking=true, alchemy=true, ['first aid']=true}

-- Travel-opportunity wording shared by the usefulness screen and the kind
-- classifier; both must recognize the same phrases.
local travelWords = {'flight path', 'flightpath', 'flight master', 'flight point',
  'gryphon point', 'wind rider point'}

local function trim(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end
local function compare(left, operator, right)
  if operator == '<' then return left < right end
  if operator == '>' then return left > right end
  if operator == '<=' then return left <= right end
  if operator == '>=' then return left >= right end
  if operator == '=' then return left == right end
end
local function conditions(value, context)
  local allowed, specified, unknown = {}, {}, {}
  for part in value:gmatch('[^,]+') do
    part = trim(part)
    local key = part:lower()
    if key == 'nightelf' then key = 'night elf' end
    local kind = (key == 'alliance' or key == 'horde') and 'faction'
      or classes[key] and 'class' or races[key] and 'race'
    if kind then
      specified[kind] = true
      allowed[kind] = allowed[kind] or {}
      allowed[kind][key] = true
    elseif professions[key] then
      if type(context.professions) ~= 'table' or context.professions[key] == nil then
        unknown[#unknown + 1] = part
      elseif not context.professions[key] then return false, unknown end
    elseif key:match('^it%d+[<>=]+%d+$') then
      local id, operator, limit = key:match('^it(%d+)([<>=]+)(%d+)$')
      local ok, count = false, nil
      if type(context.countCarried) == 'function' then
        ok, count = pcall(context.countCarried, tonumber(id))
      end
      if not ok or type(count) ~= 'number' then unknown[#unknown + 1] = part
      else
        local matched = compare(count, operator, tonumber(limit))
        if matched == nil then unknown[#unknown + 1] = part
        elseif not matched then return false, unknown end
      end
    elseif part ~= '' then
      unknown[#unknown + 1] = part
    end
  end
  for kind in pairs(specified) do
    local actual = context[kind]
    if not actual then unknown[#unknown + 1] = kind .. ' unknown'
    else
      local key = actual:lower()
      if key == 'nightelf' then key = 'night elf' end
      if not allowed[kind][key] then return false, unknown end
    end
  end
  return true, unknown
end

local function addUnknown(to, from)
  for _, item in ipairs(from) do to[#to + 1] = item end
end

-- A preposition such as "for" can introduce a run of quest tags ("for [QC1],
-- [QC2] and [QC3]"). Replacing that whole run with a standalone reference
-- keeps the shortened text readable instead of leaving dangling punctuation.
local function resolveQuestLists(line)
  local out, position, scan = {}, 1, 1
  while true do
    local start, finish = line:find('%f[%a]for%f[%A]', scan)
    if not start then break end
    local whitespace = line:match('^%s*', finish + 1) or ''
    local tagStart = finish + 1 + #whitespace
    local count, cursor = 0, tagStart
    if line:match('^%[QC%d+', tagStart) then
      while true do
        local tag = line:match('^%[QC%d+[^%]]*%]', cursor)
        if not tag then break end
        count = count + 1
        cursor = cursor + #tag
        local separator = line:match('^[%s,]*and[%s,]*', cursor)
          or line:match('^[%s,]*', cursor) or ''
        if not line:match('^%[QC%d+', cursor + #separator) then break end
        cursor = cursor + #separator
      end
    end
    if count > 0 then
      out[#out + 1] = line:sub(position, start - 1)
      out[#out + 1] = count == 1 and 'for this quest' or 'for these quests'
      position, scan = cursor, cursor
    else
      scan = finish + 1
    end
  end
  out[#out + 1] = line:sub(position)
  return table.concat(out)
end

local function readable(line)
  line = resolveQuestLists(line)
  -- A run of tags before any prose marks the step's position and conditions;
  -- it is not prose. Drop coordinate zones and bare item counts there so
  -- they cannot leak into the start of the visible text.
  local prefix, position = '', 1
  while true do
    local whitespace, tag = line:sub(position):match('^(%s*)(%[[^%]]+%])')
    if not tag then break end
    prefix = prefix .. whitespace
    local zone = tag:match('^%[G%s*%d+%.?%d*%s*,%s*%d+%.?%d*%s*[^%]]*%]$')
    local nameless = tag:match('^%[CI%d+,%s*%d+%]$')
    local flightPoint = tag:match('^%[P%s+')
    if not zone and not nameless and not flightPoint then prefix = prefix .. tag end
    position = position + #whitespace + #tag
  end
  line = prefix .. line:sub(position)
  line = line:gsub('^%s*%[G[^%]]+%]%s*', '')
  line = line:gsub('%s+[Aa]t%s*%[TAR%d+%]', ' ')
  line = line:gsub('at%s*%[TAR%d+%]', ' ')
  line = line:gsub('%[CI%d+,%s*(%d+)([%a][^%]]*)%]', '%1 %2 ')
  line = line:gsub('%[CI%d+,%s*(%d+)%s+([^%]]+)%]', '%1 %2 ')
  line = line:gsub('%[CI%d+,%s*(%d+)%]', '%1 item ')
  line = line:gsub('%[G%s*%d+%.?%d*%s*,%s*%d+%.?%d*%s*,%s*%d+%.?%d*%s*([^%]]+)%]', '%1')
  line = line:gsub('%[G%s*%d+%.?%d*%s*,%s*%d+%.?%d*%s*([^%]]+)%]', '%1')
  line = line:gsub('%[G[^%]]+%]', '')
  line = line:gsub('%[TAR%d+%]', '')
  line = line:gsub('%[[^%]]+%]', '')
  line = line:gsub('%s+', ' ')
  return trim(line)
end

local function useful(line)
  local s = line:lower()
  -- General equipment and profession progression are not quest preparation.
  -- An explicit quest reference can establish a narrower practical purpose.
  if not s:find('%[qc%d+') and not s:find('%f[%a]quest%f[%A]') then
    if s:find('skinning knife', 1, true) or s:find('mining pick', 1, true)
        or s:find('weapon', 1, true) or s:find('training', 1, true)
        or s:find('profession', 1, true) then return false end
  end
  -- Explanations introduced by causal prose can carry story outcomes; without
  -- semantic analysis we cannot safely separate the practical advice from it.
  if s:find('%f[%a]because%f[%A]') then
    local plain = s:gsub('%b[]', ''):gsub('%s+', ' ')
    local questQuantity = line:find('%[QC%d+')
        and plain:match('because the quest requires [%w%s%-]+ for[%.!%s]*$')
    if not questQuantity and not s:match('because they depend on each other[%.!%s]*$') then
      return false
    end
  end
  -- Pure guide instructions and progression are not advice. Lines containing
  -- route-relative language are omitted when their meaning cannot stand alone.
  if s:find('next step', 1, true) or s:find('next two steps', 1, true)
      or s:find('previous step', 1, true) or s:find('previously', 1, true)
      or s:find('die and', 1, true) or s:find('rezz', 1, true)
      or s:find('each time you do', 1, true) or s:find('sell grey', 1, true)
      or s:find('sell gray', 1, true) or s:find('sell it all', 1, true)
      or s:find('this guide', 1, true) or s:find('keep an eye', 1, true)
      or s:find('last chance', 1, true) or s:find('more chances', 1, true)
      or s:find('keep group', 1, true) or s:find('keep skinning', 1, true) then return false end
  -- Suppress sentences that disclose common narrative outcomes. This is a
  -- conservative screen, not proof that unrestricted guide prose is safe.
  for _, phrase in ipairs({' is murdered', ' was murdered', ' is killed',
      ' was killed', ' is secretly ', ' turns out ', ' is revealed',
      ' betrays ', ' betrayed ', ' poisoned ', ' assassinates ', ' assassinated ',
      ' dies', ' death of ', ' true identity'}) do
    if s:find(phrase, 1, true) then return false end
  end
  local plain = s:gsub('%b[]', ''):gsub('^%s+', '')
  if plain:match('^accept[%s:%.]') or plain:match('^turn%s*in[%s:%.]')
      or plain:match('^do%s*[:]') or plain:match('^run to')
      or plain:match('^follow the') or plain:match('^learn your level')
      or plain:match('^put them') then return false end
  -- Practical wording is prose, not tag metadata, and a retention "keep"
  -- takes an object: a bare "keep" before punctuation is a fortress name.
  local words = s:gsub('%b[]', '')
  local travel = false
  for _, phrase in ipairs(travelWords) do
    if words:find(phrase, 1, true) then travel = true; break end
  end
  return words:find('buy', 1, true) or words:find('%f[%a]keep[!%s]')
      or words:find('save', 1, true) or words:find('sell', 1, true)
      or words:find('stock up', 1, true) or travel
      or words:find('needed for', 1, true) or words:find('quest items', 1, true)
      or (words:find('escort quest', 1, true) and words:find('group', 1, true)
          and words:find('turn', 1, true))
      or (s:find('[qc', 1, true) and (words:find('while ', 1, true)
          or words:find('before ', 1, true) or words:find('use ', 1, true)))
end

-- Some quest directives have a self-contained practical note in parentheses.
-- Recognize only the camera technique whose action and condition are clear;
-- arbitrary parenthetical prose can contain spoilers or route instructions.
local function cameraLootNote(line)
  if not line:find('%[QC%d+') then return nil end
  local plain = line:gsub('%b[]', '')
  local note = plain:match('^%s*[Dd]o%s*:%s*%((.-)%)%s*$')
  if not note then return nil end
  local normalized = note:lower():gsub('%f[%a]the%f[%A]%s*', '')
      :gsub('%f[%a]proper%f[%A]%s*', ''):gsub('%f[%a]a%f[%A]%s*', '')
      :gsub('%f[%a]with%f[%A]', 'using'):gsub('[%.!%s]+$', ''):gsub('%s+', ' ')
  if normalized == 'you can loot it from outside using camera angle' then return trim(note) end
end

-- A bare objective directive can still carry the guide's knowledge of what
-- its quests require. Keep that requirement without adopting the directive.
local function directiveRequirement(line)
  local bare = trim((line:gsub('%[[^%]]+%]', '')):gsub('%s+', ' '))
  if bare:lower() ~= 'do:' and bare:lower() ~= 'do' then return nil end
  local _, itemCount = line:gsub('%[CI%d+', '')
  if itemCount ~= 1 then return nil end
  local id, quantity, name = line:match('%[CI(%d+)%s*,%s*(%d+)%s+([^%]]+)%]')
  if not name then return nil end
  local quests, seen = {}, {}
  for questID in line:gmatch('%[QC(%d+)') do
    local numeric = tonumber(questID)
    if not seen[numeric] then quests[#quests + 1] = numeric; seen[numeric] = true end
  end
  if #quests == 0 then return nil end
  return {itemID=tonumber(id), quantity=tonumber(quantity), name=trim(name), quests=quests}
end

-- A line can mix a route instruction with a separate practical sentence.
-- Split only at sentence punctuation, never at decimal points or tags.
local function usefulExcerpt(line)
  if cameraLootNote(line) then return trim(line) end
  local requirement = directiveRequirement(line)
  if requirement then return trim(line), nil, requirement end
  local pieces, start, insideTag = {}, 1, false
  for i = 1, #line do
    local char = line:sub(i, i)
    if char == '[' then insideTag = true elseif char == ']' then insideTag = false end
    local after = line:sub(i + 1, i + 1)
    -- The sentence-so-far is only needed to test a "keep!" emphasis, so it
    -- is built only then: computing it for every character copies a growing
    -- string per character and turns each line quadratic.
    local emphasis = char == '!' and line:sub(start, i):lower():gsub('%b[]', ''):match('^%s*keep!+$')
    if not insideTag and not emphasis and (char == '.' or char == '!' or char == '?')
        and (not after:match('%d') or not line:sub(i - 1, i - 1):match('%d')) then
      pieces[#pieces + 1] = line:sub(start, i)
      start = i + 1
    end
  end
  if start <= #line then pieces[#pieces + 1] = line:sub(start) end
  for index, piece in ipairs(pieces) do
    local bare = trim(piece:gsub('%b[]', '')):lower()
    local followingPiece = pieces[index + 1] or ''
    local nextBare = trim(followingPiece:gsub('%b[]', '')):lower()
    -- Keep a quest-item encounter and its adjacent preparation together.
    local encounter = bare:gsub('questitem', 'quest item')
    if encounter:find('quest item', 1, true) and encounter:find('spawn', 1, true)
        and nextBare:find('health', 1, true)
        and useful(piece .. ' [QC1]') and useful(followingPiece .. ' [QC1]') then
      return trim(piece) .. ' ' .. trim(followingPiece)
    end
    if bare:match('^use%s') and not piece:find('%[QC%d+')
        and not piece:find('%[H%]') and not bare:find('hearthstone', 1, true) then
      local inferred, seen = {}, {}
      for id in followingPiece:gmatch('%[QC(%d+)') do
        id = tonumber(id)
        if not seen[id] then inferred[#inferred + 1] = id; seen[id] = true end
      end
      if #inferred > 0 and useful(piece .. ' [QC' .. inferred[1] .. ']') then
        return trim(piece), inferred
      end
    end
    if useful(piece) then
      local _, itemCount = piece:gsub('%[CI%d+', '')
      if itemCount > 1 then return nil end
      local following = trim((pieces[index + 1] or ''):lower():gsub('%b[]', ''))
      -- Preserve a conditional multi-item list when its second sentence
      -- explicitly states a total and another quantity.
      if bare:find('buy', 1, true) and bare:find('if ', 1, true)
          and following:find('you need', 1, true) and following:find('total', 1, true)
          and following:match('%d+') and useful(following .. ' buy') then
        return trim(piece) .. ' ' .. trim(pieces[index + 1])
      end
      -- Preserve an adjacent ordered-purchase condition without depending on
      -- particular item names or the guide author's exact phrasing.
      if bare:find('buy', 1, true) and following:match('^for the items')
          and following:find('in this order', 1, true) and useful(pieces[index + 1])
          and (following:find('depend', 1, true) or following:find('rely', 1, true))
          and (following:find('skip', 1, true) or following:find('dont buy', 1, true)
              or following:find('do not buy', 1, true)) then
        return trim(piece) .. ' ' .. trim(pieces[index + 1])
      end
      -- A following condition may qualify this sentence; without understanding
      -- the relationship, withholding the advice is safer than losing it.
      if following:match('^if%s') or following:match('^unless%s')
          or following:match('^only if%s') or following:find('you need', 1, true)
          or following:match('^for the items') or following:find('in this order', 1, true)
          then return nil end
      local previous = index > 1 and trim(pieces[index - 1]) or ''
      local lower = trim(previous:lower():gsub('%b[]', ''))
      if lower:match('^if%s') or lower:match('^unless%s') then
        if lower:find('next step', 1, true) or lower:find('previous step', 1, true)
            or lower:find('is secretly', 1, true) or lower:find('is murdered', 1, true)
            or lower:find(' dies', 1, true) then return nil end
        return previous .. ' ' .. trim(piece)
      end
      return trim(piece)
    end
  end
end

local function adviceKind(excerpt, item)
  local s = excerpt:lower()
  for _, phrase in ipairs(travelWords) do
    if s:find(phrase, 1, true) then return 'flight' end
  end
  if item or s:match('keep[%s!]+%d') or s:match('save[%s!]+%d') then return 'supply' end
  if s:find('escort quest', 1, true) and s:find('group', 1, true) and s:find('turn', 1, true) then return 'technique' end
  if s:gsub('questitem', 'quest item'):find('quest item', 1, true) and s:find('spawn', 1, true) then return 'technique' end
  if s:find('[qc', 1, true) then return 'technique' end
  return nil
end

-- LE/SK tags describe the guide step's learning target, not quest completion.
-- Parsing is context-independent and cached per chapter source; only the
-- known-ness of a target is read live, so it is applied separately without
-- mutating the cached states.
local function learningStates(line)
  local states = {}
  for tag, body in line:gmatch('%[(LE)%s+([^%]]+)%]') do
    local spell, rank, suffix = body:match('^SP(%d+)%s+(%d+)(%-?)$')
    if spell then
      states[#states + 1] = {kind='spell', id=tonumber(spell), rank=tonumber(rank), suffix=suffix}
    else
      local name, target, ending = body:match('^(.-)%s+(%d+)(%-?)$')
      states[#states + 1] = {kind='skill-cap', name=name or body,
        rank=tonumber(target), suffix=ending}
    end
  end
  for body in line:gmatch('%[SK%s+([^%]]+)%]') do
    local name, target, ending = body:match('^(.-)%s+(%d+)(%-?)$')
    states[#states + 1] = {kind='skill', name=name or body, rank=tonumber(target), suffix=ending}
  end
  return states
end

-- The live part of learning states: which targets this character already
-- has. Copied states keep the cache pristine for the next refresh.
local function applyLearningContext(states, context)
  local copied = false
  for i, state in ipairs(states) do
    local known
    if state.kind == 'spell' then
      if type(context.isSpellKnown) == 'function' then
        local ok, value = pcall(context.isSpellKnown, state.id)
        if ok and type(value) == 'boolean' then known = value end
      end
    elseif state.kind == 'skill' then
      local key = string.lower(state.name)
      local skillRank = context.skillRanks and context.skillRanks[key]
      if type(skillRank) == 'number' and state.rank then
        known = skillRank >= state.rank
      elseif state.rank == 1 and context.professions and context.professions[key] then
        known = true
      end
    end
    if known ~= nil then
      local copy = {}
      for field, value in pairs(state) do copy[field] = value end
      copy.known = known
      if not copied then
        copied = true
        states = { unpack(states) }
      end
      states[i] = copy
    end
  end
  return states
end

-- A guide can state outright that the purchased items are consumed by the
-- referenced quest ("Buy [CI42,3 Apples] for [QC201]; all 3 Apples are
-- consumed by that quest."). Guide.lua owns this prose format: it is
-- parsed once here into an explicit record so no later stage re-derives
-- serialized text to compare against it.
local function consumptionAssertion(excerpt)
  local normalized = excerpt:gsub('%s+', ' ')
  local leading = normalized:match('^%s*%[G[^%]]+%]%s*')
  if leading then normalized = normalized:sub(#leading + 1) end
  normalized = normalized:gsub('[%.!]%s*$', '')
  local itemID, quantity, name, questID, statedQuantity, statedName =
    normalized:match('^[Bb]uy%s+%[CI(%d+)%s*,%s*(%d+)%s+([^%]]+)%]%s+for%s+%[QC(%d+)%]%s*;%s*all%s+(%d+)%s+([^;]+)%s+are%s+consumed%s+by%s+that%s+quest%s*$')
  if not itemID then return nil end
  return {itemID=tonumber(itemID), quantity=tonumber(quantity), itemName=trim(name),
    questID=tonumber(questID), statedQuantity=tonumber(statedQuantity),
    statedItemName=trim(statedName)}
end

-- One context-independent parse per chapter source, cached by the source
-- string itself: guide text is immutable once registered, so the same string
-- is always the same parse. Only three things depend on the live context and
-- stay outside the cache: [A ...]/[GA ...] condition evaluation, learning
-- known-ness, and record assembly. The cache trades a few MB of live parse
-- data for not re-parsing thousands of lines on every interface refresh.
local parseCache = {}
local EMPTY = {}

local function parseChapter(source)
  local cached = parseCache[source]
  if cached then return cached end
  local title = source:match('%[N%s*([^%]]+)%]')
  local scope = source:match('%[GA%s+([^%]]+)%]') or ''
  local steps = {}
  local lineIndex = 0
  for line in (source .. '\n'):gmatch('(.-)\r?\n') do
    lineIndex = lineIndex + 1
    local x, y, zone = line:match('%[G%s*(%d+%.?%d*)%s*,%s*(%d+%.?%d*)%s*([^%]]*)%]')
    if x and zone and trim(zone) ~= '' then
      zone = trim(zone:gsub('^%s*,%s*%d+%.?%d*%s*', ''))
    else
      x = nil
    end
    local aTags
    for condition in line:gmatch('%[A%s+([^%]]+)%]') do
      aTags = aTags or {}
      aTags[#aTags + 1] = condition
    end
    local excerpt, inferred, requirement = usefulExcerpt(line)
    local learning = excerpt and learningStates(line) or {}
    -- General class/profession progression is outside the quest-focused
    -- view. Keep explicitly quest-related learning advice available.
    if excerpt and #learning > 0 and not excerpt:find('%[QC%d+')
        and not excerpt:lower():find('quest', 1, true) then excerpt = nil end
    local text, kind, quests, quest, item, quantity, itemName, consumption, association
    if excerpt then
      text = cameraLootNote(excerpt) or readable(excerpt)
      if requirement then
        text = requirement.quantity .. ' ' .. requirement.name
          .. ' needed for '
          .. (#requirement.quests == 1 and 'this quest' or 'these quests') .. '.'
      end
      if text ~= '' then
        item, quantity = excerpt:match('%[CI(%d+)%s*,%s*(%d+)')
        local itemTag = excerpt:match('%[CI([^%]]+)%]')
        itemName = itemTag and itemTag:match('^%d+%s*,%s*%d+%s*(.*)$')
        if itemName then itemName = trim(itemName) end
        if itemName == '' or itemName == '-' then itemName = nil end
        local seen = {}
        quests = {}
        for id in excerpt:gmatch('%[QC(%d+)') do
          local numeric = tonumber(id)
          if not seen[numeric] then quests[#quests + 1] = numeric; seen[numeric] = true end
        end
        quest = #quests == 1 and quests[1] or nil
        kind = requirement and 'supply'
          or (inferred and 'technique' or adviceKind(excerpt, item))
        -- A named flight point tag on the line identifies the travel
        -- opportunity; keep the name with advice whose prose omits it.
        if kind == 'flight' then
          local point = line:match('%[P%s+([^%]]*%S)%]')
          if point and not text:lower():find(point:lower(), 1, true) then
            text = point .. ': ' .. text
          end
        end
        consumption = consumptionAssertion(excerpt)
        if text == '' then text = nil end
        association = quest and 'quest' or (#quests > 1 and 'quests' or 'zone')
      end
    end
    -- A step matters later only as a position marker or as advice; lines
    -- that are neither cannot change any later record.
    if x or text then
      steps[#steps + 1] = {
        lineIndex=lineIndex, x=tonumber(x), y=tonumber(y), zone=zone,
        aTags=aTags, excerpt=excerpt, text=text, kind=kind,
        quests=quests, quest=quest, inferred=inferred,
        requirement=requirement, learning=learning,
        itemID=tonumber(item), quantity=tonumber(quantity), itemName=itemName,
        consumption=consumption,
        association=association,
      }
    end
  end
  cached = { title=title, scope=scope, steps=steps }
  parseCache[source] = cached
  return cached
end

function EQ.ExtractGuide(packageName, context)
  context = context or {}
  local result = {}
  for chapterIndex, args in ipairs(EQ.guides[packageName] or {}) do
    local source, author = args[1], args[2]
    if type(source) == 'string' then
      local parse = parseChapter(source)
      local chapterAllowed, chapterUnknown = conditions(parse.scope, context)
      if chapterAllowed then
        local locationStep, locationUnknown
        for _, step in ipairs(parse.steps) do
          local lineAllowed, lineUnknown = true, EMPTY
          if step.aTags then
            lineUnknown = {}
            for _, condition in ipairs(step.aTags) do
              local ok, unknown = conditions(condition, context)
              if not ok then lineAllowed = false end
              addUnknown(lineUnknown, unknown)
            end
          end
          if step.zone and lineAllowed then
            locationStep, locationUnknown = step, lineUnknown
          end
          if lineAllowed and step.text then
            local learning = applyLearningContext(step.learning, context)
            local unknown = {}
            addUnknown(unknown, chapterUnknown)
            addUnknown(unknown, lineUnknown)
            if not step.x and locationStep then addUnknown(unknown, locationUnknown) end
            for _, state in ipairs(learning) do
              if state.known == nil then unknown[#unknown + 1] = 'learning state unknown' end
            end
            if #step.quests > 1 then unknown[#unknown + 1] = 'multiple quest references' end
            if step.requirement then unknown[#unknown + 1] = 'requirement from an objective directive' end
            if step.inferred then unknown[#unknown + 1] = 'quest reference inferred from following sentence' end
            local loc
            if locationStep then loc = {x=locationStep.x, y=locationStep.y, zone=locationStep.zone,
              coordinateSystem='guide-percent', zoneSource='guide-name', inherited=not step.x} end
            result[#result + 1] = {
              id=packageName .. ':' .. chapterIndex .. ':' .. step.lineIndex,
              package=packageName, sourceAuthor=author, chapter=parse.title,
              sourceText=step.excerpt, text=step.text, questID=step.quest, questIDs=step.quests,
              inferredQuestIDs=step.inferred,
              association=step.association,
              itemID=step.itemID, quantity=step.quantity,
              itemSourceName=step.itemName,
              kind=step.kind,
              learningState=learning,
              consumption=step.consumption,
              location=loc, conditions=unknown, uncertain=#unknown > 0,
              sourceOrder=#result + 1,
            }
          end
        end
      end
    end
  end
  return result
end
