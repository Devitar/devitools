local _, ns = ...
local overlay, canvas
local lines = {}

local function clear()
	for _, line in ipairs(lines) do
		line:Hide()
	end
end

-- Clip to the displayed map's rectangle before drawing on its canvas.
local function clip(x1, y1, x2, y2)
	local dx, dy = x2 - x1, y2 - y1
	local lo, hi = 0, 1
	for _, edge in ipairs({ { -dx, x1 }, { dx, 1 - x1 }, { -dy, y1 }, { dy, 1 - y1 } }) do
		local p, q = edge[1], edge[2]
		if p == 0 then
			if q < 0 then
				return
			end
		else
			local t = q / p
			if p < 0 then
				lo = math.max(lo, t)
			else
				hi = math.min(hi, t)
			end
			if lo > hi then
				return
			end
		end
	end
	return x1 + lo * dx, y1 + lo * dy, x1 + hi * dx, y1 + hi * dy
end

local function draw(continent, points)
	local map = WorldMapFrame
	if not map or not map:IsShown() or not points or not map.GetCanvas or not map.GetMapID then
		clear()
		return
	end
	local mapID, currentCanvas = map:GetMapID(), map:GetCanvas()
	if not mapID or not currentCanvas then
		clear()
		return
	end
	local width, height = currentCanvas:GetWidth(), currentCanvas:GetHeight()
	if not width or not height or width <= 0 or height <= 0 then
		clear()
		return
	end
	local openMap = type(OpenMapAPI) == "table" and OpenMapAPI
	local stitched = openMap and type(openMap.IsStitched) == "function" and openMap.IsStitched()
		and type(openMap.CanvasFromWorldPos) == "function"
	local project
	if stitched then
		project = function(point)
			return openMap.CanvasFromWorldPos(continent, point.x, point.y)
		end
	else
		local c1, topLeft = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 0))
		local c2, bottomRight = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(1, 1))
		if c1 ~= continent or c2 ~= continent or not topLeft or not bottomRight then
			clear()
			return
		end
		local north, west = topLeft:GetXY()
		local south, east = bottomRight:GetXY()
		if not north or not west or not south or not east or north == south or west == east then
			clear()
			return
		end
		project = function(point)
			return (point.y - west) / (east - west), (point.x - north) / (south - north)
		end
	end
	if canvas ~= currentCanvas then
		if overlay then
			overlay:Hide()
		end
		canvas, lines = currentCanvas, {}
		overlay = CreateFrame("Frame", nil, canvas)
		overlay:SetAllPoints(canvas)
		overlay:EnableMouse(false)
	end
	local level = canvas:GetFrameLevel() + 5
	if stitched and type(openMap.ArtTopLevel) == "function" then
		local top = openMap.ArtTopLevel()
		if type(top) == "number" then
			level = math.max(level, top + 1)
		end
	end
	if overlay:GetFrameLevel() ~= level then
		overlay:SetFrameLevel(level)
	end
	overlay:Show()
	local scale = map.GetCanvasScale and map:GetCanvasScale() or 1
	if not scale or scale <= 0 then
		scale = 1
	end
	local used = 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local x1, y1 = project(a)
		local x2, y2 = project(b)
		if x1 and y1 and x2 and y2 and not stitched then
			x1, y1, x2, y2 = clip(x1, y1, x2, y2)
		end
		if x1 and y1 and x2 and y2 and (x1 ~= x2 or y1 ~= y2) then
			used = used + 1
			local line = lines[used]
			if not line then
				line = overlay:CreateLine(nil, "OVERLAY")
				line:SetColorTexture(0.15, 0.85, 1, 0.95)
				lines[used] = line
			end
			line:SetThickness(3 / scale)
			line:SetStartPoint("TOPLEFT", overlay, x1 * width, -y1 * height)
			line:SetEndPoint("TOPLEFT", overlay, x2 * width, -y2 * height)
			line:Show()
		end
	end
	for i = used + 1, #lines do
		lines[i]:Hide()
	end
end

ns.WorldRouteMap = { Draw = draw, Clear = clear }
