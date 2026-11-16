-- The geo helper: the one place that walks the addon's point triples
-- through the embedded HereBeDragons. A point is { uiMapID, x, y } in
-- percent -- the shape of the generated data and of the step model's
-- candidate places -- and the helper turns one into a world position
-- { x, y, instance } in yards, measures the true yards between two world
-- positions, and says whether two of them sit on the same continent. It
-- also names the fields of a point, so new code reads words instead of
-- indexes.
--
-- The world walk is cached per point, with weak keys: the generated data
-- keeps its own points alive, and a point built on the fly -- a spawn a
-- later module picks out of a flat table -- passes away with its step
-- instead of piling up here. The data never moves, so one walk is the
-- truth for the life of a point.

local geo = {}
EfficientQuests.geo = geo

local HBD = LibStub("HereBeDragons-2.0")

--- The map id of a point triple.
function geo.uiMapID(point)
    return point[1]
end

--- The x coordinate of a point triple, in percent.
function geo.x(point)
    return point[2]
end

--- The y coordinate of a point triple, in percent.
function geo.y(point)
    return point[3]
end

-- The world position of a point, cached. False marks a point the maps
-- cannot place, so the walk runs once for those too.
local worldCache = setmetatable({}, { __mode = "k" })

--- The world position of a point as { x, y, instance } in yards, or nil
--- when the maps know the place no better than that.
function geo.worldOf(point)
    if worldCache[point] == nil then
        local x, y, instance = HBD:GetWorldCoordinatesFromZone(
            point[2] / 100, point[3] / 100, point[1])
        worldCache[point] = x and { x, y, instance } or false
    end
    return worldCache[point] or nil
end

--- Whether two world positions sit on the same continent.
function geo.sameContinent(a, b)
    return a[3] == b[3]
end

--- The distance between two world positions, in true yards.
function geo.yards(a, b)
    local dx, dy = a[1] - b[1], a[2] - b[2]
    return math.sqrt(dx * dx + dy * dy)
end
