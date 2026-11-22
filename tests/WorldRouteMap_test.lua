-- Run with a Lua 5.1-compatible interpreter from the project root.
local lines, overlay = {}, nil
local canvas = { GetWidth = function() return 100 end, GetHeight = function() return 200 end,
    GetFrameLevel = function() return 1 end }
local shown, scale, currentMap = true, 1, 1
WorldMapFrame = { IsShown = function() return shown end, GetMapID = function() return currentMap end,
    GetCanvas = function() return canvas end, GetCanvasScale = function() return scale end }
local function point(x, y) return { GetXY = function() return x, y end } end
CreateVector2D = point
C_Map = { GetWorldPosFromMapPos = function(map, position)
    if map ~= 1 then return 2 end
    local x, y = position:GetXY()
    return 1, point(100 - x * 100, 200 - y * 200)
end }
CreateFrame = function()
    overlay = { level = 0, SetAllPoints = function() end, SetFrameLevel = function(self, n) self.level = n end,
        GetFrameLevel = function(self) return self.level end, EnableMouse = function() end,
        Show = function() end, Hide = function() end, CreateLine = function()
            local line = { shown = false }
            function line:Hide() self.shown = false end
            function line:Show() self.shown = true end
            function line:SetColorTexture() end
            function line:SetThickness(n) self.thickness = n end
            function line:SetStartPoint(_, _, x, y) self.x1, self.y1 = x, y end
            function line:SetEndPoint(_, _, x, y) self.x2, self.y2 = x, y end
            lines[#lines + 1] = line
            return line
        end }
    return overlay
end
local ns = {}
assert(loadfile("Modules/WorldRouteMap.lua"))("Devitools", ns)
local route = { { x = 50, y = 300 }, { x = 50, y = 100 }, { x = 50, y = -100 } }
ns.WorldRouteMap.Draw(1, route)
assert(#lines == 2 and lines[1].shown and lines[2].shown, "route should draw on the map")
assert(lines[1].x1 == 0 and lines[1].x2 == 50 and lines[1].y1 == -100, "route must clip to the map's left edge")
assert(lines[2].x1 == 50 and lines[2].x2 == 100, "route must clip to the map's right edge")
scale = 2
ns.WorldRouteMap.Draw(1, route)
assert(lines[1].thickness == 1.5, "line width should account for map zoom")
OpenMapAPI = { IsStitched = function() return true end, ArtTopLevel = function() return 500 end,
    CanvasFromWorldPos = function(_, x, y) return (200 - y) / 200, (100 - x) / 100 end }
ns.WorldRouteMap.Draw(1, route)
assert(overlay.level == 501, "the route must draw above stitched map art")
assert(lines[1].x1 == -50 and lines[2].x2 == 150, "stitched routes may extend beyond the host zone")
OpenMapAPI = nil
currentMap = 2
ns.WorldRouteMap.Draw(1, route)
assert(not lines[1].shown and not lines[2].shown, "another continent should hide the route")
currentMap = 1
ns.WorldRouteMap.Draw(1, route)
ns.WorldRouteMap.Clear()
assert(not lines[1].shown and not lines[2].shown, "clearing the route should hide all lines")
io.write("WorldRouteMap tests passed\n")
