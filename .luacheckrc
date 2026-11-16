-- Luacheck configuration for the addon code in dist/EfficientQuests. The
-- addon runs inside the game client, and the client provides the services
-- below as global variables. A global that this list does not name is an
-- accident: luacheck reports it and the build fails. When new addon code
-- uses a further game service, add its name to the list on purpose.
std = "lua51"

globals = {
  -- The addon namespace and the saved data of each character.
  "EfficientQuests",
  "EfficientQuestsCharacter",
  -- The slash-command registration of the client.
  "SLASH_EFFICIENTQUESTS1",
  "SlashCmdList",
  -- Game services that the addon reads.
  "CreateFrame",
  "DEFAULT_CHAT_FRAME",
  "UIParent",
  "GameTooltip",
  "WorldMapFrame",
  "QuestMapFrame_OpenToQuestDetails",
  "C_Map",
}

files = {
  ["dist/EfficientQuests/Interface.lua"] = {
    -- The old window module stays in the folder as an unloaded reference
    -- for the new step window. Nobody restyles a reference, so its long
    -- lines are not a defect.
    max_line_length = false,
  },
}
