-- Interpret registered guides as independent pieces of advice, not routes.
local EQ = EfficientQuests
local classes = {warrior=true, paladin=true, hunter=true, rogue=true, priest=true,
  shaman=true, mage=true, warlock=true, druid=true}
local races = {human=true, dwarf=true, ['night elf']=true, gnome=true, orc=true,
  undead=true, tauren=true, troll=true}

local function trim(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end
local function conditions(value, context)
  local allowed, specified, unknown = {}, {}, {}
  for part in value:gmatch('[^,]+') do
    part = trim(part)
    local key = part:lower()
    local kind = (key == 'alliance' or key == 'horde') and 'faction'
      or classes[key] and 'class' or races[key] and 'race'
    if kind then
      specified[kind] = true
      allowed[kind] = allowed[kind] or {}
      allowed[kind][key] = true
    elseif part ~= '' then
      unknown[#unknown + 1] = part
    end
  end
  for kind in pairs(specified) do
    local actual = context[kind]
    if not actual then unknown[#unknown + 1] = kind .. ' unknown'
    elseif not allowed[kind][actual:lower()] then return false, unknown end
  end
  return true, unknown
end

local function addUnknown(to, from)
  for _, item in ipairs(from) do to[#to + 1] = item end
end

local function readable(line)
  line = line:gsub('%[CI%d+,%s*%d+%s+([^%]]+)%]', '%1')
  line = line:gsub('%[CI%d+,%s*%d+%]', 'item')
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
      or s:find('sell gray', 1, true) then return false end
  local plain = s:gsub('%b[]', ''):gsub('^%s+', '')
  if plain:match('^accept[%s:%.]') or plain:match('^turn%s*in[%s:%.]')
      or plain:match('^do%s*[:]') or plain:match('^run to')
      or plain:match('^follow the') or plain:match('^learn your level') then return false end
  return s:find('buy', 1, true) or s:find('keep', 1, true)
      or s:find('save', 1, true) or s:find('sell', 1, true)
      or s:find('stock up', 1, true) or s:find('flight path', 1, true)
      or s:find('flightpath', 1, true) or s:find('flight master', 1, true)
      or s:find('needed for', 1, true) or s:find('quest items', 1, true)
      or (s:find('[qc', 1, true) and (s:find('while ', 1, true)
          or s:find('before ', 1, true) or s:find('use ', 1, true)))
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
          if x and zone and trim(zone) ~= '' then
            location = {x=tonumber(x), y=tonumber(y), zone=trim(zone), inherited=false}
          end
          local lineAllowed, lineUnknown = true, {}
          for condition in line:gmatch('%[A%s+([^%]]+)%]') do
            local ok, unknown = conditions(condition, context)
            if not ok then lineAllowed = false end
            addUnknown(lineUnknown, unknown)
          end
          if lineAllowed and useful(line) then
            local text = readable(line)
            if text ~= '' then
              local item, quantity = line:match('%[CI(%d+)%s*,%s*(%d+)')
              local quest = line:match('%[QC(%d+)')
              local unknown = {}
              addUnknown(unknown, chapterUnknown)
              addUnknown(unknown, lineUnknown)
              local loc
              if location then loc = {x=location.x, y=location.y, zone=location.zone,
                inherited=not x} end
              result[#result + 1] = {
                id=packageName .. ':' .. chapterIndex .. ':' .. lineIndex,
                package=packageName, sourceAuthor=author, chapter=title,
                sourceText=trim(line), text=text, questID=tonumber(quest),
                association=quest and 'quest' or 'zone',
                itemID=tonumber(item), quantity=tonumber(quantity),
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
