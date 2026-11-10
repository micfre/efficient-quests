-- Bridge suite (seam 3): a synthetic fixture package is built by the real
-- guide plugin builder (tests/bridge.sh runs the build), and the generated
-- plugin folder is loaded here next to the real core the way the game would
-- load it: the plugin's own manifest drives which files run, in order. Every
-- assertion goes through the addon's public globals; no internal function is
-- inspected. Run from the repository root:
--   lua5.1 tests/bridge.lua dist/bridge-test/EfficientQuests_FixtureOne

local pluginDir = arg and arg[1] or ''
pluginDir = pluginDir:gsub('/$', '')
local plugin = pluginDir:match('([^/]+)$')
assert(plugin and plugin ~= '', 'usage: lua tests/bridge.lua <built-plugin-dir>')

-- Game-service substitution: the same minimal set the other suites use. The
-- plugin registers through the real hook before login, as a dependency of
-- the core would.
local messages, handlers = {}, {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) table.insert(messages, message) end }
SlashCmdList = {}
function CreateFrame()
  return {
    RegisterEvent = function() end,
    SetScript = function(_, name, handler) handlers[name] = handler end,
  }
end

dofile('tests/addon.lua')()
assert(handlers.OnEvent, 'the core must listen for login')

-- Load the generated plugin the way the game would: read its manifest, then
-- run the listed Lua files in order with the addon name as the chunk
-- argument (the same convention as the shared core loader).
local function readManifest(dir)
  local fields, files = {}, {}
  for line in io.lines(dir .. '/' .. plugin .. '.toc') do
    line = line:gsub('\r$', '')
    local field, value = line:match('^##%s*([A-Za-z-]+)%s*:%s*(.-)%s*$')
    if field then fields[field:lower()] = value
    elseif not line:match('^#') and line:match('%S') and line:match('%.lua$') then
      files[#files + 1] = line:match('^%s*(.-)%s*$')
    end
  end
  return fields, files
end

local manifest, files = readManifest(pluginDir)
assert(#files > 0, 'the plugin manifest must list the files the game loads')
assert((manifest['dependencies'] or ''):find('EfficientQuests', 1, true),
  'the plugin must depend on the core so it loads after it')
assert(manifest['x-efficientquests-guide'] == '1',
  'the core finds guide plugins at login through this manifest marker')
for _, file in ipairs(files) do
  assert(loadfile(pluginDir .. '/' .. file))(plugin, {})
end
print('ok - the built plugin loads its own manifest file list after the core')

-- Provider and context substitution, so the plugin's advice can be ranked.
local entity = { Get = function() end }
LibQuestieDB = { RequireContract = function(version) return version == 1 end,
  Quest = entity, Npc = entity, Item = entity, Object = entity }
UnitFactionGroup = function() return 'Alliance' end
C_Map = { GetBestMapForUnit = function() return 12 end,
  GetMapInfo = function() return { name = 'Elwynn Forest' } end }
C_QuestLog = { GetNumQuestLogEntries = function() return 0, 0 end,
  IsOnQuest = function() return false end }

-- The addon-list service answers from the plugin's own generated manifest,
-- so the reconciliation and the display name use what the builder emitted.
C_AddOns = {
  GetNumAddOns = function() return 1 end,
  GetAddOnInfo = function(index) return index == 1 and plugin or nil end,
  GetAddOnMetadata = function(name, field)
    if name ~= plugin then return nil end
    if field == 'X-EfficientQuests-Guide' then return manifest['x-efficientquests-guide'] end
    if field == 'Title' then return manifest['title'] end
  end,
}

local function status()
  messages = {}
  SlashCmdList.EFFICIENTQUESTS('status')
  return table.concat(messages, ' ')
end

handlers.OnEvent(nil, 'PLAYER_LOGIN')
local warnings = EfficientQuests.GetGuideWarnings()
assert(#warnings == 0, 'a plugin that declares the marker and registers must not warn: '
  .. table.concat(warnings, ' '))
assert(status() == 'Efficient Quests: Ready.',
  'a registered and declared plugin with a working provider must report ready, got: ' .. status())
print('ok - the built plugin reconciles at login and reports ready')

-- The settings guide list is filled by the real registration hook alone.
local list = EfficientQuests.GetGuideList()
assert(#list == 1, 'exactly the built plugin must be listed, got ' .. #list)
assert(list[1].key == plugin, 'the list key must be the plugin addon name')
assert(list[1].name == 'EfficientQuests FixtureOne',
  'the display name must come from the manifest title the builder emitted')
assert(list[1].author == 'Fixture Author', 'the first chapter author must surface')
assert(list[1].chapters == 2, 'both chapters must be counted, got ' .. list[1].chapters)
print('ok - the built plugin surfaces in the settings guide list')

local hints = EfficientQuests.GetHints(plugin)
assert(#hints > 0, 'the built plugin must supply hints')
local function hintWith(word)
  for _, hint in ipairs(hints) do
    if hint.text and hint.text:find(word, 1, true) then return hint end
  end
end
local apple = assert(hintWith('Apple'), 'the first chapter advice must surface in hints')
assert(apple.sourceText == '[G40,50 Elwynn Forest] Buy [CI11,1 Apple] before you leave the town.',
  'the replayed guide text must stay verbatim through extraction')
assert(apple.package == plugin and apple.id:find('^' .. plugin .. ':', 1),
  'advice ids must be namespaced by the plugin addon name')
assert(apple.chapter == 'Elwynn Forest' and apple.sourceAuthor == 'Fixture Author',
  'advice must keep its chapter and author')
assert(hintWith('Bread'), 'the other first-chapter advice must surface')
assert(hintWith('Candle'), 'the author-less second chapter must surface')
print('ok - the built plugin supplies verbatim advice through GetHints')

-- A plugin folder that lost its marker must be named by the status, not
-- reported ready; the same real registration is kept throughout.
C_AddOns.GetAddOnMetadata = function() return nil end
handlers.OnEvent(nil, 'PLAYER_LOGIN')
warnings = EfficientQuests.GetGuideWarnings()
assert(#warnings == 1 and warnings[1]:find(plugin, 1, true)
  and warnings[1]:find('without declaring', 1, true),
  'a registered plugin without the marker must warn by name')
local broken = status()
assert(broken:find(plugin, 1, true) and not broken:find('Ready', 1, true),
  'the reconciliation warning must reach the status output')
print('ok - a plugin that stops declaring the marker is named in the status')
