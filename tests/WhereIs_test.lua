-- Run with a Lua 5.1-compatible interpreter from the project root.
local messages, waypoint = {}, nil
local faction, currentMap, allowPin, setPin = "Alliance", 1, true, true
local locatorButton, openedMenu
local tooltipLines, tooltipHook = {}, nil
local pinFunction = function() end
WaypointLocationPinMixin = { CopySlashCommandToClipboard = pinFunction }
DevitoolsCharacterDB = {}
GameTooltip = {
    HookScript = function(_, _, callback) tooltipHook = callback end,
    GetOwner = function(self) return self.owner end,
    AddLine = function(_, text) table.insert(tooltipLines, text) end,
    Show = function() end,
}
local function vector(x, y)
    return { GetXY = function() return x, y end }
end
CreateVector2D = vector
UIParent = {}
Enum = { UIMapType = { Micro = 5 } }
InCombatLockdown = function() return false end
UnitFactionGroup = function() return faction end
UnitClass = function() return "Warlock", "WARLOCK" end
print = function(text) table.insert(messages, text) end
C_Map = {
    GetBestMapForUnit = function() return currentMap end,
    GetUserWaypoint = function()
        if waypoint then return { uiMapID = waypoint.map, position = vector(waypoint.x, waypoint.y) } end
    end,
    GetPlayerMapPosition = function() return vector(0, 0) end,
    GetWorldPosFromMapPos = function(map, point)
        if map == 99 then return 2, point end
        return 1, point
    end,
    GetMapInfo = function(map)
        return { name = "Zone " .. map, mapType = 3, parentMapID = 0 }
    end,
    CanSetUserWaypointOnMap = function() return allowPin end,
    SetUserWaypoint = function(point)
        if setPin then waypoint = point end
        return setPin
    end,
}
UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { map = map, x = x, y = y } end }
local frame = {}
frame.__index = function(self, name)
    if name == "SetScript" then
        return function(_, event, handler) self[event] = handler end
    end
    return function() end
end
CreateFrame = function(_, name)
    local result = setmetatable({}, frame)
    if name == "DevitoolsWhereIsButton" then locatorButton = result end
    return result
end
local function createMenu()
    local menu = { buttons = {} }
    function menu:CreateTitle() end
    function menu:CreateButton(label, callback)
        local item = createMenu()
        item.callback = callback
        self.buttons[label] = item
        return item
    end
    return menu
end
MenuUtil = { CreateContextMenu = function(owner, builder)
    openedMenu = createMenu()
    builder(owner, openedMenu)
end }
local ns = { ServiceNPCs = {
    innkeeper = {
        { name = "Enemy", faction = "H", map = 1, x = 0.01, y = 0 },
        { name = "Same zone", faction = "A", map = 1, x = 0.5, y = 0 },
        { name = "Other zone", faction = "AH", map = 2, x = 0.1, y = 0 },
        { name = "Other continent", faction = "A", map = 99, x = 0.01, y = 0 },
    },
    flight = {},
} }
assert(loadfile("Modules/WhereIs.lua"))("Devitools", ns)
locatorButton.OnClick(locatorButton)
assert(openedMenu.buttons["Warlock Trainer"], "menu must select the player's class trainer")
for _, name in ipairs({ "Repair Vendor", "Banker", "Auctioneer", "Stable Master", "Reagent Vendor" }) do
    assert(openedMenu.buttons[name], "menu missing " .. name)
end
local professionMenu = openedMenu.buttons["Profession Trainer"]
for _, name in ipairs({ "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Herbalism", "Leatherworking", "Mining", "Skinning", "Tailoring", "Cooking", "First Aid", "Fishing" }) do
    assert(professionMenu.buttons[name], "profession menu missing " .. name)
end
ns.ServiceNPCs.trainer_class_warlock = { { name = "Warlock trainer", faction = "A", map = 1, x = 0.2, y = 0 } }
ns.ServiceNPCs.trainer_profession_fishing = { { name = "Fishing trainer", faction = "A", map = 1, x = 0.3, y = 0 } }
openedMenu.buttons["Warlock Trainer"].callback()
assert(waypoint and messages[#messages]:find("Warlock trainer", 1, true), "class menu must search the player's class")
openedMenu.buttons["Profession Trainer"].buttons["Fishing"].callback()
assert(waypoint and messages[#messages]:find("Fishing trainer", 1, true), "profession menu must search the selected profession")
messages, waypoint = {}, nil
local find = ns.WhereIs.FindNearest
local category = { key = "innkeeper", label = "Innkeeper" }
find(category)
assert(waypoint and waypoint.map == 1, "must prefer a friendly result in the current zone")
assert(messages[#messages]:find("Same zone", 1, true), "must report the selected NPC")
GameTooltip.owner = { CopySlashCommandToClipboard = pinFunction }
tooltipHook(GameTooltip)
assert(tooltipLines[2] == "Same zone" and tooltipLines[3] == "Innkeeper - Zone 1", "matching map pin tooltip should show the NPC and service")
tooltipLines = {}
waypoint = { map = 1, x = 0.7, y = 0 }
tooltipHook(GameTooltip)
assert(#tooltipLines == 0, "replaced waypoint must not show stale details")
waypoint = { map = 1, x = 0.5, y = 0 }
GameTooltip.owner = {}
tooltipHook(GameTooltip)
assert(#tooltipLines == 0, "other tooltips must not show waypoint details")
currentMap, messages, waypoint = 3, {}, nil
find(category)
assert(waypoint and waypoint.map == 2, "must find closest same-continent result when outside the zone")
assert(messages[1]:find("No known", 1, true) and messages[1]:find("Zone 2", 1, true), "must report cross-zone fallback")
faction, currentMap, messages, waypoint = "Horde", 1, {}, nil
find(category)
assert(waypoint and waypoint.map == 1 and messages[#messages]:find("Enemy", 1, true), "must honor the player's faction")
faction, currentMap, allowPin, messages, waypoint = "Alliance", 1, false, {}, nil
find(category)
assert(not waypoint and messages[#messages]:find("Cannot place", 1, true), "must report unsupported waypoint maps")
allowPin, setPin, messages = true, false, {}
find(category)
assert(not waypoint and messages[#messages]:find("Could not place", 1, true), "must report failed waypoint placement")
currentMap, messages = nil, {}
find(category)
assert(messages[#messages]:find("position is unavailable", 1, true), "must report unavailable player position")
-- Regression: the Grom'gol innkeeper must be in the shipped faction data.
local actualData = {}
assert(loadfile("Data/ServiceNPCs.lua"))("Devitools", actualData)
for _, key in ipairs({ "repair", "banker", "auctioneer", "stablemaster", "reagent", "trainer_class_warlock", "trainer_profession_alchemy", "trainer_profession_fishing" }) do
    assert(actualData.ServiceNPCs[key] and #actualData.ServiceNPCs[key] > 0, "missing service data for " .. key)
end
local thulbek
for _, npc in ipairs(actualData.ServiceNPCs.innkeeper) do
    if npc.id == 5814 then thulbek = npc end
end
assert(thulbek and thulbek.faction == "H" and thulbek.map == 1434, "Grom'gol innkeeper must be present for Horde")
assert(math.abs(thulbek.x - 0.315) < 0.01 and math.abs(thulbek.y - 0.298) < 0.01, "Grom'gol coordinates must be nearby")

io.write("WhereIs tests passed\n")
