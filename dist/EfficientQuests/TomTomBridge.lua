-- The TomTom bridge. It keeps one TomTom waypoint on the place of the
-- step the step window stands on, so TomTom points the player there
-- (user story 36). The window tells the bridge through its WindowChanged
-- callback -- the same payload the window's queries answer -- and the
-- bridge answers every change the same way: take its own waypoint down,
-- then set the new one, so the marker never points at an old step (user
-- story 37).
--
-- The rules the spec gives the bridge:
--
--   One waypoint, and one only. The bridge holds the uid that
--   TomTom:AddWaypoint answers and never removes any other (user story
--   39): no clear-all, no remove-by-title, only its own uid.
--
--   The nearest known target. A step can carry several candidate points;
--   the bridge picks the one closest to the player, in true world yards
--   through the embedded HereBeDragons (user story 42).
--
--   Down when the step goes. The waypoint comes off when the step ends,
--   when the player skips the quest, and when the window hides (user
--   stories 38 and 41): all of these arrive as WindowChanged, with
--   another step, no step, or shown = false.
--
--   No waypoint without a place. A step whose data knows no coordinates,
--   or a player the reader cannot place, sets nothing. The dungeon rule
--   of user story 43 is its own explicit guard: the bridge asks the
--   reader's IsInInstance question first and sets nothing inside an
--   instance, so the rule does not hang on the reader answering no
--   position there.
--
--   No display flags. The bridge passes no map, minimap, arrow, or
--   clear-distance flags, so the player's own TomTom options decide how
--   the waypoint appears and when it says the player arrived. The one
--   thing the bridge does say is persistent = false: a step waypoint
--   lives one session, because a persisted one would outlive the
--   addon's control and break the removal stories -- and without the
--   flag TomTom's "save new waypoints" setting would keep it across
--   logins.
--
--   The off switch. The account-wide waypoints option turns the bridge
--   off; the default is on (user story 40). The options panel calls
--   Apply when the player flips the toggle, so a waypoint that stands
--   comes off at once.
--
-- The public surface:
--
--   Apply()  re-read the world and the option, and set or remove the
--            waypoint as the world now stands. The options panel calls
--            this when the player flips the waypoints toggle.

local reader = EfficientQuests.questState
local window = EfficientQuests.StepWindow
local geo = EfficientQuests.geo

local bridge = {}
EfficientQuests.TomTomBridge = bridge

local uid -- the uid of our own waypoint; the only one this module removes

-- The real TomTom answers IsCrazyArrowEmpty, and the two calls the bridge
-- makes are AddWaypoint and RemoveWaypoint -- the surface the TomTom
-- README documents for addons. Anything else on the TomTom table is not
-- ours to call.
local function tomtomHere()
    return type(TomTom) == "table"
        and type(TomTom.IsCrazyArrowEmpty) == "function"
        and type(TomTom.AddWaypoint) == "function"
        and type(TomTom.RemoveWaypoint) == "function"
end

-- The waypoints option, on until the player says otherwise. The saved
-- table carries the default after login; a missing table says on.
local function waypointsOn()
    return type(EfficientQuestsDB) ~= "table"
        or EfficientQuestsDB.waypoints ~= false
end

-- A well-formed candidate point of the step model: { uiMapID, x, y } in
-- percent.
local function validPoint(point)
    return type(point) == "table" and type(geo.uiMapID(point)) == "number"
        and type(geo.x(point)) == "number" and type(geo.y(point)) == "number"
end

-- The candidate the player stands closest to, in true yards on the
-- player's own continent. A place the maps cannot place, or one on
-- another continent, is not comparable; the first candidate -- the place
-- the step itself shows -- answers when none is.
local function nearestOf(points, here)
    local best, bestYards = points[1], math.huge
    for _, point in ipairs(points) do
        if validPoint(point) then
            local place = geo.worldOf(point)
            if place and geo.sameContinent(place, here) then
                local yards = geo.yards(place, here)
                if yards < bestYards then best, bestYards = point, yards end
            end
        end
    end
    return best
end

-- Take our own waypoint down. A uid that TomTom already cleared -- the
-- player's clear-distance can remove it on arrival -- is a no-op there,
-- and a TomTom that is not loaded holds no waypoints of ours anyway.
local function removeOurs()
    if not uid then return end
    local mine = uid
    uid = nil
    if tomtomHere() then TomTom:RemoveWaypoint(mine) end
end

-- Set one waypoint for the step and keep its uid. The old one comes off
-- first: TomTom answers the uid of a waypoint that already stands at the
-- same map and title instead of moving it, so the bridge never stacks a
-- second marker beside the first.
local function placeWaypoint(point, title)
    removeOurs()
    uid = TomTom:AddWaypoint(geo.uiMapID(point), geo.x(point) / 100,
        geo.y(point) / 100, {
            title = title,
            from = "Efficient Quests",
            -- One session only: a persisted step waypoint would outlive the
            -- addon's control -- its uid is lost on relog -- and violate the
            -- spec's removal rules, and persistent = false is no display
            -- flag, so TomTom's own options still decide how the waypoint
            -- appears.
            persistent = false,
        })
end

-- Whether the standing waypoint already sits on this exact place, so a
-- refresh that changed nothing leaves the marker be.
local function samePlace(point)
    return uid ~= nil and uid[1] == point[1]
        and uid[2] == point[2] / 100 and uid[3] == point[3] / 100
end

local function sync(shown, step)
    -- The explicit dungeon guard of user story 43: inside an instance no
    -- waypoint may point anywhere, whether or not the reader can place
    -- the player. The guard stands on its own question, not on
    -- GetPlayerWorld happening to answer nil inside instances.
    if reader.IsInInstance() then
        removeOurs()
        return
    end
    if tomtomHere() and waypointsOn() and shown == true
        and type(step) == "table" and type(step.points) == "table" then
        -- No player position, no waypoint: a place the maps cannot place
        -- is not a place to point at.
        local here = reader.GetPlayerWorld()
        local point = here and nearestOf(step.points, here) or nil
        if validPoint(point) then
            if not samePlace(point) then
                placeWaypoint(point, step.headline)
            end
            return
        end
    end
    removeOurs()
end

-- Every change of the window -- a new step, the end of a step, a skip, a
-- hide, a show -- passes through WindowChanged with the state the queries
-- answer, so the one listener covers every rule above.
window.RegisterCallback(bridge, "WindowChanged", function(_, payload)
    sync(payload.shown, payload.step)
end)

--- Re-read the world and the option, and set or remove the waypoint as
--- the world now stands. The options panel calls this when the player
--- flips the waypoints toggle.
function bridge.Apply()
    sync(window.IsShown(), window.GetCurrentStep())
end
