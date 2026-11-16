-- Luacheck configuration for the addon code in dist/EfficientQuests. The
-- addon runs inside the game client, and the client provides the services
-- below as global variables. A global that this list does not name is an
-- accident: luacheck reports it and the build fails. When new addon code
-- uses a further game service, add its name to the list on purpose.
std = "lua51"

globals = {
  -- The addon namespace and its two saved-data tables.
  "EfficientQuests",
  "EfficientQuestsDB",
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
  "C_QuestLog",
  "C_Timer",
  "UnitLevel",
  "UnitRace",
  "UnitClass",
  "UnitFactionGroup",
  "IsInInstance",
  "GetQuestsCompleted",
  "WOW_PROJECT_ID",
  "WOW_PROJECT_CAMELOT",
  -- The library manager of the embedded libraries.
  "LibStub",
}

exclude_files = {
  -- The embedded libraries are verbatim copies of third-party code; see
  -- THIRD_PARTY.md for their sources and licenses. Nobody restyles a
  -- reference, so luacheck does not check them. The test suites still
  -- load every one of them, so a broken file cannot slip in unnoticed.
  "dist/EfficientQuests/Libs/LibStub/LibStub.lua",
  "dist/EfficientQuests/Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua",
  "dist/EfficientQuests/Libs/HereBeDragons/HereBeDragons-2.0.lua",
}

files = {
  ["dist/EfficientQuests/Interface.lua"] = {
    -- The old window module stays in the folder as an unloaded reference
    -- for the new step window. Nobody restyles a reference, so its long
    -- lines are not a defect.
    max_line_length = false,
  },
}
