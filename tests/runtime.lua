-- The addon is loaded as the game would load the TOC, with only game services
-- substituted. No optional tracker or guide engine is provided.
local messages, handlers = {}, {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) table.insert(messages, message) end }
SlashCmdList = {}
function CreateFrame()
  return {
    RegisterEvent = function() end,
    SetScript = function(_, name, handler) handlers[name] = handler end,
  }
end

local function loadAddon()
  for line in io.lines('EfficientQuests/EfficientQuests.toc') do
    if line:match('%.lua$') then assert(loadfile('EfficientQuests/' .. line))('EfficientQuests', {}) end
  end
  assert(handlers.OnEvent, 'addon must listen for login')
  handlers.OnEvent(nil, 'PLAYER_LOGIN')
end
local function status()
  messages = {}
  assert(SlashCmdList.EFFICIENTQUESTS, 'settings/status command must be available')
  SlashCmdList.EFFICIENTQUESTS('status')
  return table.concat(messages, ' ')
end
loadAddon()
assert(status():find('QuestieDB', 1, true), 'missing provider should produce actionable status')
print('ok - missing provider status without optional addons')
LibQuestieDB = {}
assert(status():find('guide', 1, true), 'missing guide should be distinguished from a missing provider')
print('ok - missing guide status')
EfficientQuests_RegisterGuide('TUG', '[NExample advice]', 'TUG')
assert(not status():find('No compatible guide', 1, true), 'adapted guide should be recognized')
print('ok - adapted guide registers independently')
assert(not status():find('No relevant tips', 1, true), 'unverified dependencies must not be presented as a valid empty state')
print('ok - unverified dependencies do not look like an empty result')
