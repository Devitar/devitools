-- Run with a Lua 5.1-compatible interpreter from the project root.
local events, timer, frames, lines, messages = {}, {}, {}, {}, {}
local now, activeWaypoint, combat, roadAvailable = 0, nil, false, true
local playerX, playerY = 0, 0
local function point(x, y) return { GetXY = function() return x, y end } end
print = function(text) messages[#messages + 1] = text end
Minimap = { GetFrameLevel = function() return 1 end, GetWidth = function() return 140 end, GetZoom = function() return 3 end }
IsIndoors = function() return false end
GetCVar = function() return "0" end
GetPlayerFacing = function() return 0 end
GetTime = function() return now end
UnitFactionGroup = function() return "Horde" end
InCombatLockdown = function() return combat end
CreateVector2D = point
C_Timer = { After = function(_, callback) timer[#timer + 1] = callback end }
local function runTimers()
    local pending = timer
    timer = {}
    for _, callback in ipairs(pending) do callback() end
end
C_Map = {
    GetBestMapForUnit = function() return 1 end,
    GetPlayerMapPosition = function() return point(playerX, playerY) end,
    GetWorldPosFromMapPos = function(map, position) return map, position end,
    GetUserWaypoint = function() return activeWaypoint end,
    ClearUserWaypoint = function() activeWaypoint = nil end,
}
local frame = {}
frame.__index = function(self, name)
    if name == "SetScript" then return function(_, event, handler) self[event] = handler end end
    if name == "RegisterEvent" then return function(_, event) events[event] = self end end
    if name == "CreateLine" then
        return function()
            local line = { shown = false }
            function line:Hide() self.shown = false end
            function line:Show() self.shown = true end
            function line:SetColorTexture() end
            function line:SetThickness() end
            function line:SetStartPoint(anchor, relative, x, y, ...)
                assert(anchor == "CENTER" and relative and type(x) == "number" and type(y) == "number" and select("#", ...) == 0, "invalid WoW line start arguments")
                self.x1, self.y1 = x, y
            end
            function line:SetEndPoint(anchor, relative, x, y, ...)
                assert(anchor == "CENTER" and relative and type(x) == "number" and type(y) == "number" and select("#", ...) == 0, "invalid WoW line end arguments")
                self.x2, self.y2 = x, y
            end
            lines[#lines + 1] = line
            return line
        end
    end
    return function() end
end
CreateFrame = function()
    local result = setmetatable({}, frame)
    frames[#frames + 1] = result
    return result
end
local ns = { CollisionRouter = {
    Available = function() return true end,
    Cancel = function(job) job.cancelled = true end,
    Find = function(_, from, dest, callback)
        local job = {}
        timer[#timer + 1] = function()
            if not job.cancelled then
                if roadAvailable then callback({ from, dest }) else callback(nil) end
            end
        end
        return job
    end,
} }
assert(loadfile("Modules/WhereIsOptions.lua"))("Devitools", ns)
assert(loadfile("Modules/WalkingRoute.lua"))("Devitools", ns)
local route = ns.WalkingRoute
activeWaypoint = { uiMapID = 1, position = { x = 100, y = 0 } }
route.Start(1, 100, 0)
runTimers()
frames[1].OnUpdate(frames[1], 0.2)
assert(#lines > 0 and lines[1].shown, "route should draw on the minimap")
route.Stop()
assert(not lines[1].shown, "stop must hide route lines")
activeWaypoint = { uiMapID = 1, position = { x = 10, y = 0 } }
route.Start(1, 10, 0)
runTimers()
frames[1].OnUpdate(frames[1], 0.2)
assert(lines[1].shown, "a destination 10 yards away should still draw a route")
local originalEnd = lines[1].y2
playerX = 4
frames[1].OnUpdate(frames[1], 0.2)
assert(math.abs(lines[1].x1) < 0.001 and math.abs(lines[1].y1) < 0.001, "guidance should start at the player's new position")
assert(lines[1].y2 < originalEnd, "guidance should shrink as the player moves toward the destination")
playerX = 0
route.Stop()
activeWaypoint = { uiMapID = 1, position = { x = 2, y = 0 } }
DevitoolsCharacterDB = { whereIsWaypoint = { map = 1, x = 2, y = 0 } }
route.Start(1, 2, 0)
assert(not activeWaypoint and not DevitoolsCharacterDB.whereIsWaypoint, "a nearby destination must clear its pin and saved details")
assert(messages[#messages]:find("Destination reached", 1, true), "arrival should be explained")
activeWaypoint = { uiMapID = 1, position = { x = 10, y = 0 } }
route.Start(1, 10, 0)
runTimers()
playerX = 8
frames[1].OnUpdate(frames[1], 0.2)
assert(not activeWaypoint and not lines[1].shown, "arriving while moving must clear the pin and route")
playerX = 0
activeWaypoint = { uiMapID = 1, position = { x = 100, y = 0 } }
route.Start(1, 100, 0)
route.Stop()
runTimers()
frames[1].OnUpdate(frames[1], 0.2)
assert(not lines[1].shown, "a cancelled pending calculation must not draw")
route.Start(1, 100, 0)
runTimers()
activeWaypoint = { uiMapID = 1, position = { x = 200, y = 0 } }
events.USER_WAYPOINT_UPDATED.OnEvent()
frames[1].OnUpdate(frames[1], 0.2)
assert(not lines[1].shown, "replacing the waypoint must stop the old route")
assert(activeWaypoint and activeWaypoint.position.x == 200, "a replacement waypoint must not be cleared")
activeWaypoint = { uiMapID = 1, position = { x = 100, y = 0 } }
roadAvailable = false
route.Start(1, 100, 0)
runTimers()
assert(messages[#messages]:find("No walking route", 1, true), "missing routes should be reported")
assert(not lines[1].shown, "missing road data must not draw a fake route")
roadAvailable, playerX = true, 0
local worldDraws, worldClears = 0, 0
ns.WorldRouteMap = { Draw = function() worldDraws = worldDraws + 1 end, Clear = function() worldClears = worldClears + 1 end }
local opts = ns.WhereIsOptions
opts.Set("showMinimap", false)
opts.Set("showWorldMap", true)
opts.Set("autoClear", false)
activeWaypoint = { uiMapID = 1, position = { x = 100, y = 0 } }
route.Start(1, 100, 0)
runTimers()
frames[1].OnUpdate(frames[1], 0.2)
assert(not lines[1].shown and worldDraws > 0, "minimap can be hidden while world map stays visible")
opts.Set("showMinimap", true)
opts.Set("showWorldMap", false)
frames[1].OnUpdate(frames[1], 0.2)
assert(lines[1].shown and worldClears > 0, "world map can be hidden while minimap stays visible")
playerX = 99
frames[1].OnUpdate(frames[1], 0.2)
assert(activeWaypoint, "disabling arrival clearing must preserve a nearby pin")
playerX = 96
opts.Set("autoClear", true)
opts.Set("arrivalDistance", 5)
frames[1].OnUpdate(frames[1], 0.2)
assert(not activeWaypoint, "the configured arrival distance must clear the pin")
io.write("WalkingRoute tests passed\n")
