-- The character stores over the per-character saved table: the skip
-- list, the abandoned quests, and the Follow mode switch. Every function
-- reads the table that the game hands over on login, so each character
-- sees only its own data. The window and the menu call the skip actions,
-- the route planner asks the queries, and the quest state reader reports
-- the abandons and the re-accepts.

local store = {}

-- The skip list: the quests that this character leaves out. A skip stays
-- until the player restores the quest by hand.
function store.skip(questId)
    EfficientQuestsCharacter.skipped[questId] = true
end

function store.restore(questId)
    EfficientQuestsCharacter.skipped[questId] = nil
end

function store.isSkipped(questId)
    return EfficientQuestsCharacter.skipped[questId] == true
end

-- The ids of every skipped quest, in rising order, for the menu list.
function store.list()
    local ids = {}
    for questId in pairs(EfficientQuestsCharacter.skipped) do
        table.insert(ids, questId)
    end
    table.sort(ids)
    return ids
end

-- The abandoned quests. A quest that the player abandons stays out of
-- the route. When the player takes the quest again, the quest state
-- reader calls the clear, and the quest returns to the route.
function store.recordAbandoned(questId)
    EfficientQuestsCharacter.abandoned[questId] = true
end

function store.isAbandoned(questId)
    return EfficientQuestsCharacter.abandoned[questId] == true
end

function store.clearAbandoned(questId)
    EfficientQuestsCharacter.abandoned[questId] = nil
end

-- The Follow mode switch. The saved table keeps the state, so the choice
-- of one character survives its next login.
function store.isFollowMode()
    return EfficientQuestsCharacter.followMode == true
end

function store.setFollowMode(on)
    EfficientQuestsCharacter.followMode = not not on
end

EfficientQuests.characterStore = store
