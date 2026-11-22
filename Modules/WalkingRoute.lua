local _, ns = ...
local router = ns.CollisionRouter
local route = { points = nil, target = nil, generation = 0, elapsed = 0, lastPlan = 0, reported = false }
local frame = CreateFrame("Frame", nil, Minimap)
frame:SetAllPoints(Minimap)
frame:SetFrameLevel(Minimap:GetFrameLevel() + 5)
local lines = {}
local arrivalDistanceSquared = 3 ^ 2

local function clearLines()
	for _, line in ipairs(lines) do
		line:Hide()
	end
	if ns.WorldRouteMap then
		ns.WorldRouteMap.Clear()
	end
end

local function message(text)
	print("|cff66ccffDevitools:|r " .. text)
end

local function playerPosition()
	local map = C_Map.GetBestMapForUnit("player")
	local pos = map and C_Map.GetPlayerMapPosition(map, "player")
	if not pos then
		return
	end
	local continent, point = C_Map.GetWorldPosFromMapPos(map, pos)
	if not point then
		return
	end
	local x, y = point:GetXY()
	return continent, x, y
end

local function sameWaypoint(target)
	local current = C_Map.GetUserWaypoint()
	if not current or current.uiMapID ~= target.map or not current.position then
		return false
	end
	local x, y = current.position.x, current.position.y
	return x and y and math.abs(x - target.x) < 0.00001 and math.abs(y - target.y) < 0.00001
end

local function stop()
	route.generation = route.generation + 1
	if route.job and router then
		router.Cancel(route.job)
		route.job = nil
	end
	route.target, route.points, route.planning = nil, nil, false
	clearLines()
end

local function arrive()
	local target = route.target
	local matches = target and sameWaypoint(target)
	stop()
	if matches then
		C_Map.ClearUserWaypoint()
		local saved = type(DevitoolsCharacterDB) == "table" and DevitoolsCharacterDB.whereIsWaypoint
		if type(saved) == "table" and saved.map == target.map and saved.x == target.x and saved.y == target.y then
			DevitoolsCharacterDB.whereIsWaypoint = nil
		end
		message("Destination reached; map pin cleared.")
	end
end

local function plan()
	local target = route.target
	if not target or route.planning then
		return
	end
	if InCombatLockdown() then
		if not route.reported then
			message("Walking route will be calculated after combat.")
			route.reported = true
		end
		return
	end
	local continent, x, y = playerPosition()
	if not continent or not x or not y then
		if not route.reported then
			message("Walking route unavailable: your world position could not be determined.")
			route.reported = true
		end
		return
	end
	local targetContinent, dest = C_Map.GetWorldPosFromMapPos(target.map, CreateVector2D(target.x, target.y))
	if not dest or continent ~= targetContinent then
		route.points = nil
		clearLines()
		if not route.reported then
			message("Walking route unavailable across these maps; the map pin is still set.")
			route.reported = true
		end
		return
	end
	local dx, dy = dest:GetXY()
	if not dx or not dy then
		return
	end
	local distanceSquared = (dx - x) ^ 2 + (dy - y) ^ 2
	if distanceSquared <= arrivalDistanceSquared then
		arrive()
		return
	end
	if not router or not router.Available(continent) then
		if not route.reported then
			message("Walking map unavailable for this continent; the map pin is still set.")
			route.reported = true
		end
		return
	end
	route.planning = true
	route.lastPlan = GetTime()
	route.lastX, route.lastY = x, y
	local generation = route.generation
	route.job = router.Find(continent, { x = x, y = y }, { x = dx, y = dy }, function(points)
		if generation ~= route.generation or route.target ~= target then
			return
		end
		route.planning, route.job = false, nil
		if InCombatLockdown() or not sameWaypoint(target) then
			return
		end
		if not points or #points < 2 then
			route.points = nil
			clearLines()
			if not route.reported then
				message("No walking route available for this destination; the map pin is still set.")
				route.reported = true
			end
			return
		end
		route.points, route.continent, route.reported, route.direct = points, continent, false, false
		if not route.announced then
			message("Walking route ready; follow the cyan line on your minimap.")
			route.announced = true
		end
	end, { profile = UnitFactionGroup("player") })
end

-- Clip a segment to the round minimap so it cannot draw over the surrounding UI.
local function clip(ax, ay, bx, by, radius)
	local dx, dy = bx - ax, by - ay
	local a = dx * dx + dy * dy
	if a == 0 then
		return
	end
	local b = 2 * (ax * dx + ay * dy)
	local c = ax * ax + ay * ay - radius * radius
	local discriminant = b * b - 4 * a * c
	if discriminant < 0 then
		return
	end
	local root = math.sqrt(discriminant)
	local lo = math.max(0, (-b - root) / (2 * a))
	local hi = math.min(1, (-b + root) / (2 * a))
	if lo >= hi then
		return
	end
	return ax + dx * lo, ay + dy * lo, ax + dx * hi, ay + dy * hi
end

local scales = {
	outdoor = { 466.6667, 400, 333.3333, 266.6667, 200, 133.3333 },
	indoor = { 300, 240, 180, 120, 80, 50 },
}

-- Rejoin the nearest route segment from the current player position, and omit
-- the part already travelled. Direct guidance always starts at the player.
local function remainingPoints(x, y)
	local points = route.points
	if route.direct then
		return { { x = x, y = y }, points[#points] }, 0
	end
	local best, bestIndex, bestX, bestY
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local dx, dy = b.x - a.x, b.y - a.y
		local length = dx * dx + dy * dy
		local t = length > 0 and math.max(0, math.min(1, ((x - a.x) * dx + (y - a.y) * dy) / length)) or 0
		local nx, ny = a.x + t * dx, a.y + t * dy
		local distance = (x - nx) ^ 2 + (y - ny) ^ 2
		if not best or distance < best then
			best, bestIndex, bestX, bestY = distance, i, nx, ny
		end
	end
	local result = { { x = x, y = y }, { x = bestX, y = bestY } }
	for i = bestIndex + 1, #points do
		result[#result + 1] = points[i]
	end
	return result, best
end

local function draw(continent, px, py)
	if not route.points or continent ~= route.continent then
		clearLines()
		return
	end
	local width = Minimap:GetWidth()
	if not width or width <= 0 then
		clearLines()
		return
	end
	local size = scales[IsIndoors() and "indoor" or "outdoor"][Minimap:GetZoom() + 1] or 266.6667
	local factor, radius = width / size, width / 2 - 3
	local angle = GetCVar("rotateMinimap") == "1" and -(GetPlayerFacing() or 0) or 0
	local cosine, sine = math.cos(angle), math.sin(angle)
	local function pixels(point)
		local east, north = -(point.y - py), point.x - px
		return (east * cosine - north * sine) * factor, (east * sine + north * cosine) * factor
	end
	local used = 0
	local points = remainingPoints(px, py)
	for i = 1, #points - 1 do
		local ax, ay = pixels(points[i])
		local bx, by = pixels(points[i + 1])
		local x1, y1, x2, y2 = clip(ax, ay, bx, by, radius)
		if x1 then
			used = used + 1
			local line = lines[used]
			if not line then
				line = frame:CreateLine(nil, "OVERLAY")
				line:SetColorTexture(0.15, 0.85, 1, 0.95)
				line:SetThickness(3)
				lines[used] = line
			end
			line:SetStartPoint("CENTER", frame, x1, y1)
			line:SetEndPoint("CENTER", frame, x2, y2)
			line:Show()
		end
	end
	for i = used + 1, #lines do
		lines[i]:Hide()
	end
end

local function distanceToRoute(x, y)
	local best
	for i = 1, #route.points - 1 do
		local a, b = route.points[i], route.points[i + 1]
		local dx, dy = b.x - a.x, b.y - a.y
		local length = dx * dx + dy * dy
		local t = length > 0 and math.max(0, math.min(1, ((x - a.x) * dx + (y - a.y) * dy) / length)) or 0
		local d = (x - a.x - t * dx) ^ 2 + (y - a.y - t * dy) ^ 2
		if not best or d < best then
			best = d
		end
	end
	return best
end

frame:SetScript("OnUpdate", function(_, elapsed)
	if not route.target then
		return
	end
	route.elapsed = route.elapsed + elapsed
	if route.elapsed < 0.1 then
		return
	end
	route.elapsed = 0
	if InCombatLockdown() then
		clearLines()
		return
	end
	if not sameWaypoint(route.target) then
		stop()
		return
	end
	local continent, x, y = playerPosition()
	if not continent or not x or not y then
		clearLines()
		return
	end
	local targetContinent, targetPos =
		C_Map.GetWorldPosFromMapPos(route.target.map, CreateVector2D(route.target.x, route.target.y))
	if targetPos and targetContinent == continent then
		local dx, dy = targetPos:GetXY()
		if dx and dy and (dx - x) ^ 2 + (dy - y) ^ 2 <= arrivalDistanceSquared then
			arrive()
			return
		end
	end
	if route.points then
		draw(continent, x, y)
		if ns.WorldRouteMap then
			ns.WorldRouteMap.Draw(continent, remainingPoints(x, y))
		end
		local deviation = distanceToRoute(x, y)
		if deviation and deviation > 2500 and GetTime() - route.lastPlan >= 10 then
			plan()
		end
	elseif
		not route.planning
		and GetTime() - route.lastPlan >= 10
		and (not route.lastX or (x - route.lastX) ^ 2 + (y - route.lastY) ^ 2 > 2500)
	then
		plan()
	end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("USER_WAYPOINT_UPDATED")
events:SetScript("OnEvent", function()
	if route.target and not sameWaypoint(route.target) then
		stop()
	end
end)

ns.WalkingRoute = {}
function ns.WalkingRoute.Start(map, x, y)
	stop()
	route.target = { map = map, x = x, y = y }
	route.reported = false
	route.announced = false
	plan()
end
function ns.WalkingRoute.Stop()
	stop()
end
