-- The Follow mode controller. While Follow mode is on, it listens for the
-- quest the player picks in the quest log and serves the step of that
-- quest through the step model, so the step window (#35) follows the
-- player's interest instead of the route. The Follow mode switch itself
-- lives in the character store, so the choice of one character survives
-- its next login; the picked quest is session state and is not saved.
--
-- How a pick is seen. The client marks the quest the player picks in the
-- log as the super-tracked one, so this module watches the client's
-- SUPER_TRACKING_CHANGED event and asks C_SuperTrack for the tracked
-- quest when the client has the service. A client without super
-- tracking -- and the window (#35) and the tests -- drives the same
-- road by hand through SetFollowTarget. A quest the player just
-- accepted never counts as a pick-up step: the step model promises
-- that a quest in the log gets its work step or its hand-in step,
-- never a pick-up step, and this module relies on that promise instead
-- of repeating it.
--
-- The state and the actions, for the step window (#35):
--
--   GetFollowState()  the state the window polls:
--
--       { active = bool,   Follow mode is on
--         questID = id,    the picked quest, nil while none is picked
--         step = step }    the step of the picked quest in the shape the
--                          step model documents, computed fresh on the
--                          call so the counts and ticks move with the
--                          quest log; nil without a pick, and nil when
--                          the model knows no step -- a quest handed in
--                          or missing from the data -- in which case the
--                          window shows the route again
--
--   SetFollowMode(on)  turns Follow mode on or off and keeps the choice
--                       in the character store. Turning it on adopts the
--                       quest the client tracks right now, if any;
--                       turning it off clears the pick. This switch --
--                       the title-bar toggle of the window (story 27) --
--                       is the only control that turns the mode off.
--   SetFollowTarget(questID)  the pick itself, by hand. Nil clears the
--                       pick. A pick while Follow mode is off is
--                       ignored, so no step is ever served while the
--                       mode is off.
--   ReturnToRoute()    the click on the step (user story 30): it clears
--                       the pick, so the window returns to the route,
--                       but leaves Follow mode itself on. Turning the
--                       mode off is the toggle's work alone, so a later
--                       pick in the log follows again without another
--                       click on the toggle.
--
--   RegisterCallback(owner, "FollowChanged", fn)  the
--   CallbackHandler-1.0 subscription. FollowChanged fires with the same
--   table GetFollowState answers whenever the served state may have
--   moved: a pick, a mode change, the return to the route, and every
--   quest state change of the world while a quest is picked -- its
--   counts, its completion, and its hand-in. The hand-in of the picked
--   quest ends the following: the pick clears, Follow mode itself stays
--   on, and the payload answers active = true, questID = nil, step =
--   nil, which means "the window returns to the route" for the tickets
--   that observe it.

local reader = EfficientQuests.questState
local store = EfficientQuests.characterStore
local model = EfficientQuests.stepModel

local follow = {}
EfficientQuests.followMode = follow

follow.callbacks = LibStub("CallbackHandler-1.0"):New(follow,
    "RegisterCallback", "UnregisterCallback", "UnregisterAllCallbacks")

-- The picked quest: the quest the player picked in the log while Follow
-- mode is on. Session state, not saved.
local picked

-- The quest the client super-tracks right now: the quest the player
-- picked in the log. Zero and nil mean no pick, and a client without
-- the service answers no pick at all.
local function trackedQuest()
    if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        local id = C_SuperTrack.GetSuperTrackedQuestID()
        if type(id) == "number" and id > 0 then return id end
    end
    return nil
end

-- The Follow mode state as one fresh table.
local function stateOf()
    local active = store.isFollowMode()
    return {
        active = active,
        questID = picked,
        step = (active and picked) and model.GetStepForQuest(picked) or nil,
    }
end

-- Tell the subscribers the served state may have moved.
local function changed()
    follow.callbacks:Fire("FollowChanged", stateOf())
end

--- The Follow mode state the window polls: { active, questID, step },
--- in the shape the header of this module documents.
function follow.GetFollowState()
    return stateOf()
end

--- The pick itself: the quest the player picked in the log. The client's
--- super tracking calls this on SUPER_TRACKING_CHANGED; a client without
--- super tracking -- and the window (#35) and the tests -- call it by
--- hand. Nil clears the pick. A pick while Follow mode is off is ignored,
--- so no step is ever served while the mode is off.
function follow.SetFollowTarget(questID)
    if not store.isFollowMode() then return end
    if questID == picked then return end
    picked = questID
    changed()
end

--- Turn Follow mode on or off. The choice sits in the character store,
--- so it survives the next login of the same character. Turning it on
--- adopts the quest the client tracks right now, if any; turning it off
--- clears the pick.
function follow.SetFollowMode(on)
    store.setFollowMode(on)
    if store.isFollowMode() then
        picked = trackedQuest()
    else
        picked = nil
    end
    changed()
end

--- The click on the step (user story 30): the return to the route. It
--- clears the pick -- the window shows the route again -- but leaves
--- Follow mode itself on: the title-bar toggle (story 27) is the only
--- control that turns the mode off and keeps that choice, so a later
--- pick in the log follows again without another click on the toggle.
function follow.ReturnToRoute()
    picked = nil
    changed()
end

-- The client marks the quest the player picks in the log as the
-- super-tracked one, so this frame is the pick signal. The registration
-- is guarded: a client without the event must not fail on load.
local events = CreateFrame("Frame")
pcall(events.RegisterEvent, events, "SUPER_TRACKING_CHANGED")
events:SetScript("OnEvent", function(_, event)
    if event ~= "SUPER_TRACKING_CHANGED" then return end
    follow.SetFollowTarget(trackedQuest())
end)

-- The quest state moves the served step: while a quest is picked, every
-- quest state change re-serves and notifies, so the window never shows
-- an old step. The hand-in of the picked quest ends the following: the
-- pick clears, Follow mode itself stays on, and the notification tells
-- the window to return to the route until the player picks again.
local watches = {}
for _, name in ipairs(reader.CHANGE_CALLBACKS) do
    reader.RegisterCallback(watches, name, function(what, payload)
        if not picked then return end
        if what == "QuestHandedIn" and payload.questID == picked then
            picked = nil
        end
        changed()
    end)
end
