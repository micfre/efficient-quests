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
  dofile('tests/addon.lua')()
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
local message = status()
assert(message:find('guide', 1, true), 'missing guide should be distinguished from a missing provider')
assert(message:find('github.com/micfre/efficient-quests/releases', 1, true),
  'missing guide status should point at the releases page')
print('ok - missing guide status points at the releases page')

-- With no guide registered, the setup status names a declared guide
-- plugin that failed to register instead of the generic pointer. The
-- fresh load simulates the session in which the plugin never registered.
C_AddOns = {
  GetNumAddOns = function() return 1 end,
  GetAddOnInfo = function() return 'EfficientQuests_Declared' end,
  GetAddOnMetadata = function(name, field)
    if field == 'X-EfficientQuests-Guide' then return '1' end
  end,
}
loadAddon()
local statusMessage = status()
assert(statusMessage:find('EfficientQuests_Declared', 1, true) and statusMessage:find('did not register', 1, true),
  'a declared guide that did not register should be named in the setup status')
assert(not statusMessage:find('releases', 1, true),
  'the generic releases pointer must not hide the specific broken plugin')
print('ok - unregistered declared guide is named in status')

handlers.OnEvent(nil, 'QUEST_TURNED_IN', 105)
assert(EfficientQuestsCharacter.turnedIn[105],
  'observed turn-in should be remembered in the character data')
assert(not EfficientQuestsCharacter.turnedIn[101],
  'only the quest that the event names is a turn-in')
print('ok - observed turn-in is recorded in the character data')

-- At login the core reconciles addons that declare the guide marker against
-- the guides that actually registered and exposes each mismatch as a warning.
-- Every scenario starts from a fresh load, so each session registers only the
-- guides the scenario needs.
C_AddOns = {
  GetNumAddOns = function() return 3 end,
  GetAddOnInfo = function(index)
    return ({ 'EfficientQuests_Paired', 'EfficientQuests_Silent', 'Unrelated_Tool' })[index]
  end,
  GetAddOnMetadata = function(name, field)
    if field == 'X-EfficientQuests-Guide' and name ~= 'Unrelated_Tool' then return '1' end
  end,
}
loadAddon()
EfficientQuests_RegisterGuide('EfficientQuests_Paired', '[N Paired]', 'Paired Author')
handlers.OnEvent(nil, 'PLAYER_LOGIN')
local warnings = EfficientQuests.GetGuideWarnings()
assert(#warnings == 1, 'a fully matching set apart from one missing guide must warn once')
assert(warnings[1]:find('EfficientQuests_Silent', 1, true) and warnings[1]:find('did not register', 1, true),
  'a declared guide that did not register should produce its own warning line')
print('ok - declared guide that never registers warns at login')

EfficientQuests_RegisterGuide('EfficientQuests_Rogue', '[N Rogue]', 'Rogue Author')
handlers.OnEvent(nil, 'PLAYER_LOGIN')
warnings = EfficientQuests.GetGuideWarnings()
assert(#warnings == 2, 'both mismatch kinds must produce their own warning')
local rogueWarning, silentWarning
for _, warning in ipairs(warnings) do
  if warning:find('EfficientQuests_Rogue', 1, true) then rogueWarning = warning end
  if warning:find('EfficientQuests_Silent', 1, true) then silentWarning = warning end
end
assert(silentWarning and silentWarning:find('did not register', 1, true),
  'the declared-but-unregistered warning must stay distinct')
assert(rogueWarning and rogueWarning:find('without declaring', 1, true),
  'a guide that registers without declaring the marker must warn distinctly')
print('ok - registered guide without the marker warns at login')

loadAddon()
EfficientQuests_RegisterGuide('EfficientQuests_Paired', '[N Paired again]', 'Paired Author')
C_AddOns.GetAddOnMetadata = function(name, field)
  if name == 'EfficientQuests_Paired' and field == 'X-EfficientQuests-Guide' then return '1' end
end
handlers.OnEvent(nil, 'PLAYER_LOGIN')
assert(#EfficientQuests.GetGuideWarnings() == 0,
  'a matching declared and registered set must produce no warnings')
print('ok - matching declared and registered set stays silent')

loadAddon()
EfficientQuests_RegisterGuide('EfficientQuests_Opaque', '[N Opaque]', 'Opaque Author')
C_AddOns = nil
handlers.OnEvent(nil, 'PLAYER_LOGIN')
assert(#EfficientQuests.GetGuideWarnings() == 0,
  'a missing addon-list service must not fabricate warnings')
print('ok - absent addon-list service reconciles nothing')
