-- Interpret registered guides as independent pieces of advice, not routes.
local EQ = EfficientQuests
local classes = {warrior=true, paladin=true, hunter=true, rogue=true, priest=true,
  shaman=true, mage=true, warlock=true, druid=true}
local races = {human=true, dwarf=true, ['night elf']=true, gnome=true, orc=true,
  undead=true, tauren=true, troll=true, skyborne=true}
local professions = {mining=true, skinning=true, herbalism=true, enchanting=true,
  engineering=true, blacksmithing=true, cooking=true, fishing=true, tailoring=true,
  leatherworking=true, alchemy=true, ['first aid']=true}

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

local function readable(line)
  line = line:gsub('^%s*%[G[^%]]+%]%s*', '')
  line = line:gsub('%s+[Aa]t%s*%[TAR%d+%]', ' ')
  line = line:gsub('at%s*%[TAR%d+%]', ' ')
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
  -- Pure guide instructions and progression are not advice. Lines containing
  -- route-relative language are omitted when their meaning cannot stand alone.
  if s:find('next step', 1, true) or s:find('next two steps', 1, true)
      or s:find('previous step', 1, true) or s:find('previously', 1, true)
      or s:find('die and', 1, true) or s:find('rezz', 1, true)
      or s:find('each time you do', 1, true) or s:find('sell grey', 1, true)
      or s:find('sell gray', 1, true) or s:find('sell it all', 1, true)
      or s:find('this guide', 1, true) or s:find('keep an eye', 1, true)
      or s:find('keep group', 1, true) or s:find('keep skinning', 1, true) then return false end
  -- Suppress sentences that disclose common narrative outcomes. This is a
  -- conservative screen, not proof that unrestricted guide prose is safe.
  for _, phrase in ipairs({' is murdered', ' was murdered', ' is killed',
      ' was killed', ' is secretly ', ' turns out ', ' is revealed',
      ' betrays ', ' betrayed ', ' dies', ' death of ', ' true identity'}) do
    if s:find(phrase, 1, true) then return false end
  end
  local plain = s:gsub('%b[]', ''):gsub('^%s+', '')
  if plain:match('^accept[%s:%.]') or plain:match('^turn%s*in[%s:%.]')
      or plain:match('^do%s*[:]') or plain:match('^run to')
      or plain:match('^follow the') or plain:match('^learn your level')
      or plain:match('^put them') then return false end
  return s:find('buy', 1, true) or s:find('%f[%a]keep%f[%A]')
      or s:find('save', 1, true) or s:find('sell', 1, true)
      or s:find('stock up', 1, true) or s:find('flight path', 1, true)
      or s:find('flightpath', 1, true) or s:find('flight master', 1, true)
      or s:find('needed for', 1, true) or s:find('quest items', 1, true)
      or (s:find('[qc', 1, true) and (s:find('while ', 1, true)
          or s:find('before ', 1, true) or s:find('use ', 1, true)))
end

-- A line can mix a route instruction with a separate practical sentence.
-- Split only at sentence punctuation, never at decimal points or tags.
local function usefulExcerpt(line)
  local pieces, start, insideTag = {}, 1, false
  for i = 1, #line do
    local char = line:sub(i, i)
    if char == '[' then insideTag = true elseif char == ']' then insideTag = false end
    local after = line:sub(i + 1, i + 1)
    local prefix = line:sub(start, i):lower():gsub('%b[]', '')
    local emphasis = char == '!' and prefix:match('^%s*keep!+$')
    if not insideTag and not emphasis and (char == '.' or char == '!' or char == '?')
        and (not after:match('%d') or not line:sub(i - 1, i - 1):match('%d')) then
      pieces[#pieces + 1] = line:sub(start, i)
      start = i + 1
    end
  end
  if start <= #line then pieces[#pieces + 1] = line:sub(start) end
  for index, piece in ipairs(pieces) do
    if useful(piece) then
      local _, itemCount = piece:gsub('%[CI%d+', '')
      if itemCount > 1 then return nil end
      local following = trim((pieces[index + 1] or ''):lower():gsub('%b[]', ''))
      -- A following condition may qualify this sentence; without understanding
      -- the relationship, withholding the advice is safer than losing it.
      if following:match('^if%s') or following:match('^unless%s')
          or following:match('^only if%s') or following:find('you need', 1, true)
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
  if s:find('flight path', 1, true) or s:find('flightpath', 1, true)
      or s:find('flight master', 1, true) then return 'flight' end
  if item or s:match('keep[%s!]+%d') or s:match('save[%s!]+%d') then return 'supply' end
  if s:find('[qc', 1, true) then return 'technique' end
  return nil
end

function EQ.ExtractGuide(packageName, context)
  context = context or {}
  local result = {}
  for chapterIndex, args in ipairs(EQ.guides[packageName] or {}) do
    local source, author = args[1], args[2]
    if type(source) == 'string' then
      local title = source:match('%[N%s*([^%]]+)%]')
      local scope = source:match('%[GA%s+([^%]]+)%]') or ''
      local chapterAllowed, chapterUnknown = conditions(scope, context)
      local location, lineIndex = nil, 0
      if chapterAllowed then
        for line in (source .. '\n'):gmatch('(.-)\r?\n') do
          lineIndex = lineIndex + 1
          local x, y, zone = line:match('%[G%s*(%d+%.?%d*)%s*,%s*(%d+%.?%d*)%s*([^%]]*)%]')
          local lineAllowed, lineUnknown = true, {}
          for condition in line:gmatch('%[A%s+([^%]]+)%]') do
            local ok, unknown = conditions(condition, context)
            if not ok then lineAllowed = false end
            addUnknown(lineUnknown, unknown)
          end
          if lineAllowed and x and zone and trim(zone) ~= '' then
            zone = zone:gsub('^%s*,%s*%d+%.?%d*%s*', '')
            location = {x=tonumber(x), y=tonumber(y), zone=trim(zone),
              conditions=lineUnknown}
          end
          local excerpt = lineAllowed and usefulExcerpt(line)
          if excerpt then
            local text = readable(excerpt)
            if text ~= '' then
              local item, quantity = excerpt:match('%[CI(%d+)%s*,%s*(%d+)')
              local quest = excerpt:match('%[QC(%d+)')
              local unknown = {}
              addUnknown(unknown, chapterUnknown)
              addUnknown(unknown, lineUnknown)
              if not x and location then addUnknown(unknown, location.conditions) end
              local loc
              if location then loc = {x=location.x, y=location.y, zone=location.zone,
                coordinateSystem='guide-percent', zoneSource='guide-name', inherited=not x} end
              result[#result + 1] = {
                id=packageName .. ':' .. chapterIndex .. ':' .. lineIndex,
                package=packageName, sourceAuthor=author, chapter=title,
                sourceText=excerpt, text=text, questID=tonumber(quest),
                association=quest and 'quest' or 'zone',
                itemID=tonumber(item), quantity=tonumber(quantity),
                kind=adviceKind(excerpt, item),
                location=loc, conditions=unknown, uncertain=#unknown > 0,
                sourceOrder=#result + 1,
              }
            end
          end
        end
      end
    end
  end
  return result
end
