-- The slash commands of Efficient Quests: /eq and /efficientquests, the
-- short and the long spelling of one handler (user story 52). A bare
-- command toggles the step window; a plain word behind it picks the one
-- thing the player asks for -- the options panel, the status, or this
-- list. The commands drive only the surfaces the earlier modules expose;
-- they own no state and no window of their own.

local EQ = EfficientQuests

-- One chat line to the player, the voice every module of the addon uses.
local function say(text)
    DEFAULT_CHAT_FRAME:AddMessage(text)
end

-- The word behind the command, lowercased and trimmed: "/eq Status " asks
-- for "status", and an empty rest is the bare command.
local function firstWord(message)
    return (message or ""):lower():match("^%s*(%S*)")
end

-- A bare command flips the step window: what is hidden comes up, what is
-- shown goes away (user story 51 opens the window this way too).
local function toggleWindow()
    if EQ.StepWindow.IsShown() then
        EQ.StepWindow.Hide()
    else
        EQ.StepWindow.Show()
    end
end

-- The version of the manifest, the way the client hands it over. The
-- fallback constant mirrors the manifest's Version field for a client
-- without the service, so a status report never lacks the fact.
local FALLBACK_VERSION = "0.3.0"

local function addonVersion()
    if type(GetAddOnMetadata) == "function" then
        local value = GetAddOnMetadata("EfficientQuests", "Version")
        if type(value) == "string" and value ~= "" then return value end
    end
    return FALLBACK_VERSION
end

-- FlareUI is loaded when its global table is there or its tracker frame
-- is: the frame is the part the look adapter reads, and either one says
-- the addon came up.
local function flareUIPresent()
    return type(_G.FlareUI) == "table" or _G.FlareUI_ObjectiveTracker ~= nil
end

local function tomtomPresent()
    return type(_G.TomTom) == "table"
end

-- A usable QuestieDB passes the same contract test the fallback applies
-- at load time (see QuestieFallback.lua): the global, the contract call,
-- and the two entities the lookups read. Anything less is an absent or
-- incompatible QuestieDB, and the status says so.
local function questieUsable()
    local lib = _G.LibQuestieDB
    if type(lib) ~= "table" then return false end
    if type(lib.RequireContract) ~= "function" then return false end
    local called, agreed = pcall(lib.RequireContract, 1)
    if not called or not agreed then return false end
    for _, entity in ipairs({ "Quest", "Npc" }) do
        if type(lib[entity]) ~= "table" or type(lib[entity].Get) ~= "function" then
            return false
        end
    end
    return true
end

-- The status (user story 68): three lines a report can be written from --
-- the version, one word per optional addon, and the data snapshot.
local function status()
    local function word(present)
        if present then return "found" end
        return "missing"
    end
    say("Efficient Quests: version " .. addonVersion())
    say("Efficient Quests: FlareUI " .. word(flareUIPresent())
        .. ", TomTom " .. word(tomtomPresent())
        .. ", QuestieDB " .. word(questieUsable()))
    say("Efficient Quests: data snapshot " .. EQ.GetDataSnapshot())
end

-- The help: the whole command list in plain words, five short lines.
local function help()
    say("Efficient Quests commands:")
    say("/eq - toggle the step window")
    say("/eq options - open the options panel")
    say("/eq status - show the version, the data snapshot, and the optional addons")
    say("/eq help - list these commands")
end

local function handle(message)
    local word = firstWord(message)
    if word == "" then
        toggleWindow()
    elseif word == "options" or word == "config" then
        EQ.Options.Open()
    elseif word == "status" then
        status()
    elseif word == "help" then
        help()
    else
        say("Efficient Quests: unknown command '" .. word
            .. "'. Type /eq help for the commands.")
    end
end

-- The client binds the chat text through the SLASH_ globals and calls the
-- handler of the matching SlashCmdList entry; both spellings share one
-- handler, so they can never drift apart.
SLASH_EQ1 = "/eq"
SLASH_EFFICIENTQUESTS1 = "/efficientquests"
SlashCmdList.EQ = handle
SlashCmdList.EFFICIENTQUESTS = handle
