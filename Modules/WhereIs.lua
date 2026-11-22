local addonName, ns = ...
local options = ns.WhereIsOptions
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

local function message(text, important)
    if important or options.Get("chatMessages") then
        print("|cff66ccffDevitools:|r " .. text)
    end
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
        message("Please search outside combat.", true)
        return
    end
    local faction = UnitFactionGroup("player")
    local factionCode = faction == "Alliance" and "A" or faction == "Horde" and "H"
    if not factionCode then
        message("Your faction is not available yet. Please try again.", true)
        return
    end
    local mapID = C_Map.GetBestMapForUnit("player")
    local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then
        message("Your current map position is unavailable here.", true)
        return
    end
    local continent, playerWorld = C_Map.GetWorldPosFromMapPos(mapID, position)
    if not continent or not playerWorld then
        message("Your world position is unavailable here.", true)
        return
    end
    local px, py = playerWorld:GetXY()
    local playerZone = zoneMap(mapID)
    local inZone, elsewhere
    for _, npc in ipairs(ns.ServiceNPCs[category.key] or {}) do
        if npc.faction:find(factionCode, 1, true) and (options.Get("allowClassic") or npc.source ~= "Classic") then
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
    local result = inZone or (options.Get("searchOtherZones") and elsewhere)
    if not result then
        if not options.Get("searchOtherZones") then
            message("No known " .. category.label .. " was found in this zone.", true)
        else
            message("No known " .. category.label .. " was found on your current continent.", true)
        end
        return
    end
    local npc = result.npc
    local info = C_Map.GetMapInfo(npc.map)
    local zoneName = info and info.name or ("map " .. npc.map)
    if not inZone then
        message("No known " .. category.label .. " in this zone. The nearest known one is in " .. zoneName .. ".", true)
    end
    if not C_Map.CanSetUserWaypointOnMap(npc.map) then
        message("Cannot place a map pin in " .. zoneName .. ".", true)
        return
    end
    local point = UiMapPoint.CreateFromCoordinates(npc.map, npc.x, npc.y)
    if not C_Map.SetUserWaypoint(point) then
        message("Could not place the map pin. Please try again outside combat.", true)
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
        message("Walking route module did not load; the map pin is still set.", true)
    end
    if npc.source == "Classic" then
        message("This location comes from Classic data and has not been verified in Forever.", true)
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
    if options.Get("showSource") and type(saved.source) == "string" then
        tooltip:AddLine("Location source: " .. saved.source, 1, 1, 1)
    end
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
-- UIPanelButtonTemplate changes its artwork in OnMouseDown/OnMouseUp. A drag
-- can consume the mouse-up, leaving that artwork pressed even after
-- SetButtonState("NORMAL"). Do not press the artwork for right-click drags.
local templateMouseDown = button:GetScript("OnMouseDown")
local templateMouseUp = button:GetScript("OnMouseUp")
button:SetScript("OnMouseDown", function(self, mouseButton)
    if mouseButton ~= "RightButton" and templateMouseDown then
        templateMouseDown(self, mouseButton)
    end
end)
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
    if not InCombatLockdown() and not options.Get("lockButton") then
        self:StartMoving()
    end
end)
button:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self:SetButtonState("NORMAL")
    if templateMouseUp then
        templateMouseUp(self, "RightButton")
    end
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
            if options.ServiceEnabled(selected.key) then
                menu:CreateButton(selected.label, function()
                    findNearest(selected)
                end)
            end
        end
        local className, classToken = UnitClass("player")
        if className and classToken and options.ServiceEnabled("class_trainer") then
            local trainer = { key = "trainer_class_" .. classToken:lower(), label = className .. " Trainer" }
            menu:CreateButton(trainer.label, function()
                findNearest(trainer)
            end)
        end
        local professionMenu
        for _, profession in ipairs(professions) do
            if options.ServiceEnabled("profession_" .. profession.key) then
                if not professionMenu then
                    professionMenu = menu:CreateButton("Profession Trainer")
                end
                local trainer = { key = "trainer_profession_" .. profession.key, label = profession.label .. " Trainer" }
                professionMenu:CreateButton(profession.label, function()
                    findNearest(trainer)
                end)
            end
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
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(560, 1000)
    scroll:SetScrollChild(content)
    local heading = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 20, -20)
    heading:SetText("Where is...")
    local description = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    description:SetText("Find nearby services and show a walking route.")
    local controls = {}
    local function checkbox(label, x, y, getValue, setValue)
        local box = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        box:SetPoint("TOPLEFT", x, y)
        local text = box:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", box, "RIGHT", 2, 0)
        text:SetText(label)
        box:SetScript("OnClick", function(self)
            setValue(self:GetChecked() and true or false)
        end)
        controls[#controls + 1] = { box = box, get = getValue }
    end
    local function option(label, x, y, key)
        checkbox(label, x, y, function() return options.Get(key) end, function(value)
            options.Set(key, value)
        end)
    end
    local function section(label, y)
        local text = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        text:SetPoint("TOPLEFT", 20, y)
        text:SetText(label)
    end
    checkbox("Enable Where is...", 20, -72, isEnabled, setEnabled)
    section("Route display", -110)
    option("Show minimap route", 20, -130, "showMinimap")
    option("Show world map route", 280, -130, "showWorldMap")
    section("Arrival", -170)
    option("Clear pin automatically", 20, -190, "autoClear")
    local distanceLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    distanceLabel:SetPoint("TOPLEFT", 25, -230)
    distanceLabel:SetText("Arrival distance (yards, 1-100):")
    local distance = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    distance:SetSize(55, 24)
    distance:SetPoint("LEFT", distanceLabel, "RIGHT", 12, 0)
    distance:SetAutoFocus(false)
    distance:SetFontObject(ChatFontNormal)
    distance:SetTextInsets(5, 5, 0, 0)
    distance:SetMaxLetters(3)
    local distanceDisplay = distance:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
    distanceDisplay:SetPoint("LEFT", 5, 0)
    distanceDisplay:SetText(tostring(options.Get("arrivalDistance")))
    distance:SetTextColor(1, 1, 1, 0)
    distance:HookScript("OnTextChanged", function(self)
        distanceDisplay:SetText(self:GetText())
    end)
    distance:HookScript("OnEditFocusGained", function(self)
        distanceDisplay:Hide()
        self:SetTextColor(1, 1, 1, 1)
    end)
    distance:HookScript("OnEditFocusLost", function(self)
        self:SetTextColor(1, 1, 1, 0)
        distanceDisplay:SetText(self:GetText())
        distanceDisplay:Show()
    end)
    local distanceApply = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    distanceApply:SetSize(65, 24)
    distanceApply:SetPoint("LEFT", distance, "RIGHT", 10, 0)
    distanceApply:SetText("Apply")
    local distanceStatus = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    distanceStatus:SetPoint("TOPLEFT", distanceLabel, "BOTTOMLEFT", 0, -7)
    local function applyDistance()
        local value = tonumber(distance:GetText())
        if not value or value % 1 ~= 0 or value < 1 or value > 100 then
            distanceStatus:SetText("Enter a whole number from 1 to 100.")
            return
        end
        options.Set("arrivalDistance", value)
        distanceStatus:SetText("Arrival distance saved.")
        distance:ClearFocus()
    end
    distanceApply:SetScript("OnClick", applyDistance)
    distance:SetScript("OnEnterPressed", applyDistance)
    distance:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(options.Get("arrivalDistance")))
        self:ClearFocus()
    end)
    section("Button", -280)
    option("Lock button position", 20, -300, "lockButton")
    local reset = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    reset:SetSize(145, 24)
    reset:SetPoint("TOPLEFT", 280, -304)
    reset:SetText("Reset position")
    reset:SetScript("OnClick", function()
        if InCombatLockdown() then
            message("Please move the button outside combat.", true)
            return
        end
        if type(DevitoolsCharacterDB) == "table" then
            DevitoolsCharacterDB.whereIsPosition = nil
        end
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 25, -250)
    end)
    section("Search and messages", -345)
    option("Search other zones when needed", 20, -365, "searchOtherZones")
    option("Include unverified Classic locations", 20, -395, "allowClassic")
    option("Show location source in pin tooltip", 20, -425, "showSource")
    option("Show routine messages in chat", 20, -455, "chatMessages")
    local serviceTop = -510
    section("Services shown in the menu", serviceTop)
    local serviceList = {}
    for _, category in ipairs(categories) do
        serviceList[#serviceList + 1] = { key = category.key, label = category.label }
    end
    serviceList[#serviceList + 1] = { key = "class_trainer", label = "Your class trainer" }
    for _, profession in ipairs(professions) do
        serviceList[#serviceList + 1] = { key = "profession_" .. profession.key, label = profession.label .. " trainer" }
    end
    for index, item in ipairs(serviceList) do
        local key = item.key
        local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
        checkbox(item.label, 20 + column * 260, serviceTop - 25 - row * 30,
            function() return options.ServiceEnabled(key) end, function(value)
                options.SetService(key, value)
            end)
    end
    content:SetHeight(-serviceTop + 65 + math.ceil(#serviceList / 2) * 30)
    refreshToggle = function()
        for _, control in ipairs(controls) do
            control.box:SetChecked(control.get())
        end
        if not distance:HasFocus() then
            distance:SetText(tostring(options.Get("arrivalDistance")))
        end
    end
    panel:SetScript("OnShow", refreshToggle)
end

ns.WhereIs = { FindNearest = findNearest, IsEnabled = isEnabled, SetEnabled = setEnabled }
