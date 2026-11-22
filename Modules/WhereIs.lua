local addonName, ns = ...
local categories = {
    { key = "innkeeper", label = "Innkeeper" },
    { key = "flight", label = "Flight Master" },
    { key = "repair", label = "Repair Vendor" },
    { key = "banker", label = "Banker" },
    { key = "auctioneer", label = "Auctioneer" },
    { key = "stablemaster", label = "Stable Master" },
    { key = "reagent", label = "Reagent Vendor" },
}
local professions = {
    { key = "alchemy", label = "Alchemy" },
    { key = "blacksmithing", label = "Blacksmithing" },
    { key = "enchanting", label = "Enchanting" },
    { key = "engineering", label = "Engineering" },
    { key = "herbalism", label = "Herbalism" },
    { key = "leatherworking", label = "Leatherworking" },
    { key = "mining", label = "Mining" },
    { key = "skinning", label = "Skinning" },
    { key = "tailoring", label = "Tailoring" },
    { key = "cooking", label = "Cooking" },
    { key = "firstaid", label = "First Aid" },
    { key = "fishing", label = "Fishing" },
}

local function message(text)
    print("|cff66ccffDevitools:|r " .. text)
end

local function isEnabled()
    return type(DevitoolsDB) ~= "table" or DevitoolsDB.whereIsEnabled ~= false
end

-- A micro map can sit inside a zone. Stop at the zone rather than comparing
-- percentages or considering an entire continent to be one zone.
local function zoneMap(mapID)
    local current = mapID
    for _ = 1, 10 do
        local info = C_Map.GetMapInfo(current)
        if not info then return current end
        if info.mapType ~= Enum.UIMapType.Micro or not info.parentMapID or info.parentMapID == 0 then
            return current
        end
        current = info.parentMapID
    end
    return current
end

local function findNearest(category)
    if not isEnabled() then return end
    if InCombatLockdown() then
        message("Please search outside combat.")
        return
    end
    local faction = UnitFactionGroup("player")
    local factionCode = faction == "Alliance" and "A" or faction == "Horde" and "H"
    if not factionCode then
        message("Your faction is not available yet. Please try again.")
        return
    end
    local mapID = C_Map.GetBestMapForUnit("player")
    local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then
        message("Your current map position is unavailable here.")
        return
    end
    local continent, playerWorld = C_Map.GetWorldPosFromMapPos(mapID, position)
    if not continent or not playerWorld then
        message("Your world position is unavailable here.")
        return
    end
    local px, py = playerWorld:GetXY()
    local playerZone = zoneMap(mapID)
    local inZone, elsewhere
    for _, npc in ipairs(ns.ServiceNPCs[category.key] or {}) do
        if npc.faction:find(factionCode, 1, true) then
            local worldID, world = C_Map.GetWorldPosFromMapPos(npc.map, CreateVector2D(npc.x, npc.y))
            if worldID == continent and world then
                local x, y = world:GetXY()
                local distance = (px - x) ^ 2 + (py - y) ^ 2
                local sameZone = zoneMap(npc.map) == playerZone
                local candidate = { npc = npc, distance = distance }
                if sameZone and (not inZone or distance < inZone.distance) then
                    inZone = candidate
                elseif not sameZone and (not elsewhere or distance < elsewhere.distance) then
                    elsewhere = candidate
                end
            end
        end
    end
    local result = inZone or elsewhere
    if not result then
        message("No known " .. category.label .. " was found on your current continent.")
        return
    end
    local npc = result.npc
    local info = C_Map.GetMapInfo(npc.map)
    local zoneName = info and info.name or ("map " .. npc.map)
    if not inZone then
        message("No known " .. category.label .. " in this zone. The nearest known one is in " .. zoneName .. ".")
    end
    if not C_Map.CanSetUserWaypointOnMap(npc.map) then
        message("Cannot place a map pin in " .. zoneName .. ".")
        return
    end
    local point = UiMapPoint.CreateFromCoordinates(npc.map, npc.x, npc.y)
    if not C_Map.SetUserWaypoint(point) then
        message("Could not place the map pin. Please try again outside combat.")
        return
    end
    if type(DevitoolsCharacterDB) == "table" then
        DevitoolsCharacterDB.whereIsWaypoint = {
            map = npc.map, x = npc.x, y = npc.y,
            name = npc.name, service = category.label, zone = zoneName, source = npc.source,
        }
    end
    message("Pinned " .. npc.name .. " in " .. zoneName .. ". Calculating walking route...")
    if ns.WalkingRoute then
        ns.WalkingRoute.Start(npc.map, npc.x, npc.y)
    else
        message("Walking route module did not load; the map pin is still set.")
    end
    if npc.source == "Classic" then
        message("This location comes from Classic data and has not been verified in Forever.")
    end
end

-- Blizzard's waypoint stores coordinates only. Add details to its map tooltip
-- while the current waypoint still matches the one this tool placed.
GameTooltip:HookScript("OnShow", function(tooltip)
    local owner = tooltip:GetOwner()
    local pinMixin = WaypointLocationPinMixin
    if not owner or not pinMixin or type(pinMixin.CopySlashCommandToClipboard) ~= "function"
        or owner.CopySlashCommandToClipboard ~= pinMixin.CopySlashCommandToClipboard then
        return
    end
    local saved = type(DevitoolsCharacterDB) == "table" and DevitoolsCharacterDB.whereIsWaypoint
    local current = C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
    if type(saved) ~= "table" or not current or not current.position
        or current.uiMapID ~= saved.map or type(saved.x) ~= "number" or type(saved.y) ~= "number"
        or type(saved.name) ~= "string" or type(saved.service) ~= "string" or type(saved.zone) ~= "string" then
        return
    end
    local x, y = current.position.x, current.position.y
    if not x or not y or math.abs(x - saved.x) > 0.00001 or math.abs(y - saved.y) > 0.00001 then
        return
    end
    tooltip:AddLine(" ")
    tooltip:AddLine(saved.name, 1, 0.82, 0)
    tooltip:AddLine(saved.service .. " - " .. saved.zone, 1, 1, 1)
    if saved.source == "Classic" then
        tooltip:AddLine("Classic location; not verified in Forever", 1, 0.82, 0, true)
    end
    tooltip:Show()
end)
local button = CreateFrame("Button", "DevitoolsWhereIsButton", UIParent, "UIPanelButtonTemplate")
button:SetSize(110, 26)
button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 25, -250)
button:SetText("Where is...")
button:SetClampedToScreen(true)
button:SetMovable(true)
button:RegisterForDrag("RightButton")
-- This controls Blizzard's single user waypoint, regardless of who placed it.
local clearButton = CreateFrame("Button", "DevitoolsClearWaypointButton", UIParent, "UIPanelButtonTemplate")
clearButton:SetSize(110, 24)
clearButton:SetPoint("TOP", button, "BOTTOM", 0, -3)
clearButton:SetText("Clear pin")
clearButton:Hide()
local function updateClearButton()
    if isEnabled() and C_Map.HasUserWaypoint() then
        clearButton:Show()
    else
        clearButton:Hide()
    end
end
clearButton:SetScript("OnClick", function()
    if ns.WalkingRoute then
        ns.WalkingRoute.Stop()
    end
    C_Map.ClearUserWaypoint()
    if type(DevitoolsCharacterDB) == "table" then
        DevitoolsCharacterDB.whereIsWaypoint = nil
    end
    updateClearButton()
end)
local waypointEvents = CreateFrame("Frame")
waypointEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
waypointEvents:RegisterEvent("USER_WAYPOINT_UPDATED")
local function resumeSavedRoute()
    if not isEnabled() or not ns.WalkingRoute then return end
    local saved = type(DevitoolsCharacterDB) == "table" and DevitoolsCharacterDB.whereIsWaypoint
    local current = C_Map.GetUserWaypoint()
    local position = current and current.position
    if type(saved) == "table" and type(saved.map) == "number" and type(saved.x) == "number"
        and type(saved.y) == "number" and current and current.uiMapID == saved.map and position
        and type(position.x) == "number" and type(position.y) == "number"
        and math.abs(position.x - saved.x) < 0.00001 and math.abs(position.y - saved.y) < 0.00001 then
        ns.WalkingRoute.Start(saved.map, saved.x, saved.y)
    end
end
waypointEvents:SetScript("OnEvent", function(_, event)
    updateClearButton()
    if event == "PLAYER_ENTERING_WORLD" then
        resumeSavedRoute()
    end
end)
button:SetScript("OnDragStart", function(self)
    if not InCombatLockdown() then
        self:StartMoving()
    end
end)
button:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint()
    if type(DevitoolsCharacterDB) == "table" then
        DevitoolsCharacterDB.whereIsPosition = { point, relativePoint, x, y }
    end
end)
button:SetScript("OnClick", function(self)
    MenuUtil.CreateContextMenu(self, function(_, menu)
        menu:CreateTitle("Where is...")
        for _, category in ipairs(categories) do
            local selected = category
            menu:CreateButton(selected.label, function()
                findNearest(selected)
            end)
        end
        local className, classToken = UnitClass("player")
        if className and classToken then
            local trainer = { key = "trainer_class_" .. classToken:lower(), label = className .. " Trainer" }
            menu:CreateButton(trainer.label, function()
                findNearest(trainer)
            end)
        end
        local professionMenu = menu:CreateButton("Profession Trainer")
        for _, profession in ipairs(professions) do
            local trainer = { key = "trainer_profession_" .. profession.key, label = profession.label .. " Trainer" }
            professionMenu:CreateButton(profession.label, function()
                findNearest(trainer)
            end)
        end
    end)
end)
button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Where is...")
    GameTooltip:AddLine("Click to find a nearby service. Right-drag to move.", 1, 1, 1, true)
    GameTooltip:Show()
end)
button:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local refreshToggle
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, loaded)
    if loaded ~= addonName then
        return
    end
    -- Other modules may initialize the same saved-variable table first.
    if type(DevitoolsCharacterDB) ~= "table" then
        DevitoolsCharacterDB = {}
    end
    if type(DevitoolsDB) ~= "table" then
        DevitoolsDB = {}
    end
    if DevitoolsDB.whereIsEnabled == nil then
        DevitoolsDB.whereIsEnabled = true
    end
    if isEnabled() then
        button:Show()
    else
        button:Hide()
    end
    updateClearButton()
    if refreshToggle then
        refreshToggle()
    end
    local position = DevitoolsCharacterDB.whereIsPosition
    if type(position) == "table" and type(position[1]) == "string" and type(position[2]) == "string"
        and type(position[3]) == "number" and type(position[4]) == "number" then
        button:ClearAllPoints()
        button:SetPoint(position[1], UIParent, position[2], position[3], position[4])
    end
    self:UnregisterEvent("ADDON_LOADED")
end)

local function setEnabled(enabled)
    if type(DevitoolsDB) ~= "table" then
        DevitoolsDB = {}
    end
    DevitoolsDB.whereIsEnabled = enabled
    if refreshToggle then
        refreshToggle()
    end
    if enabled then
        button:Show()
        updateClearButton()
        resumeSavedRoute()
    else
        button:Hide()
        clearButton:Hide()
        if ns.WalkingRoute then
            ns.WalkingRoute.Stop()
        end
    end
end

if ns.Settings then
    local panel = ns.Settings.RegisterPage("Where is...")
    local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 20, -20)
    heading:SetText("Where is...")
    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    description:SetText("Find nearby services and show a walking route.")
    local toggle = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    toggle:SetPoint("TOPLEFT", 20, -72)
    local label = toggle:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", toggle, "RIGHT", 2, 0)
    label:SetText("Enable Where is...")
    toggle:SetScript("OnClick", function(self)
        setEnabled(self:GetChecked() and true or false)
    end)
    refreshToggle = function()
        toggle:SetChecked(isEnabled())
    end
    panel:SetScript("OnShow", refreshToggle)
end

ns.WhereIs = { FindNearest = findNearest, IsEnabled = isEnabled, SetEnabled = setEnabled }
