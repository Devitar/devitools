local _, ns = ...

-- Each candidate represents one entire bag slot, ranked by its stack's vendor value.
local candidates, queue, queueIsBulk = {}, nil, false
local reserve = {}
local scanPending = false
local desired = 5
local panel = CreateFrame("Frame", "DevitoolsBagCleanerFrame", UIParent, "BackdropTemplate")
panel:SetSize(360, 360)
panel:SetPoint("CENTER")
panel:SetFrameStrata("DIALOG")
panel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
})
panel:EnableMouse(true)
panel:SetMovable(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
panel:Hide()

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -18)
title:SetText("Bag Cleaner")
local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -5, -5)
local settingsButton = CreateFrame("Button", "DevitoolsBagCleanerSettingsButton", panel)
settingsButton:SetSize(20, 20)
settingsButton:SetPoint("RIGHT", close, "LEFT", -2, 0)
settingsButton:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
settingsButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
settingsButton:RegisterForClicks("LeftButtonUp")
settingsButton:SetScript("OnClick", function()
    panel:Hide()
    ns.Settings.Open("Bag Cleaner")
end)
settingsButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Bag Cleaner settings")
    GameTooltip:AddLine("Click to change filters and excluded items.", 1, 1, 1, true)
    GameTooltip:Show()
end)
settingsButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
local prompt = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
prompt:SetPoint("TOPLEFT", 20, -52)
prompt:SetText("Bag slots to free:")
local input = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
input:SetSize(42, 24)
input:SetPoint("LEFT", prompt, "RIGHT", 12, 0)
input:SetAutoFocus(false)
input:SetNumeric(true)
input:SetMaxLetters(4)
input:SetText("5")
local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("TOPLEFT", 20, -87)
status:SetWidth(320)
status:SetJustifyH("LEFT")
local scan = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
scan:SetSize(75, 24)
scan:SetPoint("LEFT", input, "RIGHT", 10, 0)
scan:SetText("Find")
local bulk = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
bulk:SetSize(180, 24)
bulk:SetPoint("BOTTOM", 0, 18)
bulk:SetText("Delete all results...")
local instructions = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
instructions:SetPoint("BOTTOM", bulk, "TOP", 0, 4)
instructions:SetJustifyH("CENTER")
instructions:SetText("Select an item above\n-or-")
local buttons = {}
local resultsScroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
resultsScroll:SetPoint("TOPLEFT", 20, -112)
resultsScroll:SetPoint("BOTTOMRIGHT", -35, 85)
local resultsContent = CreateFrame("Frame", nil, resultsScroll)
resultsContent:SetSize(300, 1)
resultsScroll:SetScrollChild(resultsContent)
local refresh, scanBags, queueDialog, beginQueue, updateExclusions
local function message(text)
    print("|cff66ccffDevitools:|r " .. text)
end
local function formatValue(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor(copper / 100) % 100
    local remainder = copper % 100
    if gold > 0 then
        return string.format("%dg %ds %dc", gold, silver, remainder)
    end
    if silver > 0 then
        return string.format("%ds %dc", silver, remainder)
    end
    return string.format("%dc", remainder)
end
local function questItem(bag, slot)
    if not C_Container.GetContainerItemQuestInfo then
        return false
    end
    local info = C_Container.GetContainerItemQuestInfo(bag, slot)
    return info and (info.isQuestItem == true or (info.questID or 0) > 0)
end
local function exclusions()
    if type(DevitoolsCharacterDB) ~= "table" then
        DevitoolsCharacterDB = {}
    end
    if type(DevitoolsCharacterDB.bagCleanerExcluded) ~= "table" then
        DevitoolsCharacterDB.bagCleanerExcluded = {}
    end
    return DevitoolsCharacterDB.bagCleanerExcluded
end
local function normalizedName(name)
    return name and name:match("^%s*(.-)%s*$"):lower() or ""
end
local function saveExclusion(name)
    local key = normalizedName(name)
    if key == "" then return false end
    for _, excluded in ipairs(exclusions()) do
        if normalizedName(excluded) == key then return false end
    end
    local list = exclusions()
    list[#list + 1] = name:match("^%s*(.-)%s*$")
    return true
end
local function cleanerOption(key)
    return type(DevitoolsDB) == "table" and type(DevitoolsDB.bagCleanerOptions) == "table"
        and DevitoolsDB.bagCleanerOptions[key]
end
local function setCleanerOption(key, value)
    if type(DevitoolsDB) ~= "table" then
        DevitoolsDB = {}
    end
    if type(DevitoolsDB.bagCleanerOptions) ~= "table" then
        DevitoolsDB.bagCleanerOptions = {}
    end
    DevitoolsDB.bagCleanerOptions[key] = value
end
local function isExcluded(id, name, classID)
    -- Projectile class covers arrows, bullets and other ammunition without relying on translated names.
    if id == 6948 or id == 6265 or classID == 6 then
        return true
    end
    local key = normalizedName(name)
    for _, excluded in ipairs(exclusions()) do
        if normalizedName(excluded) == key then
            return true
        end
    end
    return false
end
-- Conjured status is exposed through the item tooltip, not GetItemInfo.
-- An unavailable or unreadable tooltip is treated as unknown, never safe.
local function isConjured(bag, slot)
    local label = ITEM_CONJURED
    if not label and (GetLocale() == "enUS" or GetLocale() == "enGB") then
        label = "Conjured Item"
    end
    if not label or not C_TooltipInfo or not C_TooltipInfo.GetBagItem then
        return nil
    end
    local ok, tooltip = pcall(C_TooltipInfo.GetBagItem, bag, slot)
    if not ok or not tooltip or type(tooltip.lines) ~= "table" or #tooltip.lines == 0 then
        return nil
    end
    for _, line in ipairs(tooltip.lines) do
        for _, text in ipairs({ line.leftText or "", line.rightText or "" }) do
            if issecretvalue and issecretvalue(text) then
                return nil
            end
            if type(text) == "string" and text:find(label, 1, true) then
                return true
            end
        end
    end
    return false
end
local function matches(item)
    local info = C_Container.GetContainerItemInfo(item.bag, item.slot)
    return info
        and not info.isLocked
        and info.itemID == item.id
        and info.hyperlink == item.link
        and (info.stackCount or 1) == item.count
        and not questItem(item.bag, item.slot)
        and not isExcluded(item.id, item.name, item.classID)
        and isConjured(item.bag, item.slot) == false
        and (not cleanerOption("poorOnly") or item.quality == 0)
        and (not cleanerOption("sellableOnly") or item.value > 0)
end
local function deleteOne(item)
    if InCombatLockdown() then
        message("Cannot delete items during combat.")
        return false
    end
    if CursorHasItem() or GetCursorInfo() then
        message("Clear your cursor before deleting an item.")
        return false
    end
    if not matches(item) then
        message("That bag slot changed; nothing was deleted. Search again.")
        return false
    end
    C_Container.PickupContainerItem(item.bag, item.slot)
    if not CursorHasItem() then
        message("Could not pick up the item.")
        return false
    end
    DeleteCursorItem()
    -- Some items invoke Blizzard's own confirmation, leaving the item on the cursor.
    if CursorHasItem() then
        message("Complete or cancel the game's deletion confirmation, then search again.")
        return false
    end
    return true
end

local function replaceSuggestions()
    while #candidates < desired and #reserve > 0 do
        local nextItem = table.remove(reserve, 1)
        if matches(nextItem) then
            candidates[#candidates + 1] = nextItem
        end
    end
    status:SetText(scanPending and "Some item information is loading. Click Find again for complete results."
        or ("Showing " .. #candidates .. " items, lowest total vendor value first. Right click an item to dismiss or permanently ignore a suggestion."))
    refresh()
end

local function createResultButton(i)
    local button = CreateFrame("Button", "DevitoolsBagCleanerItem" .. i, resultsContent)
    button:SetSize(40, 40)
    button:SetPoint("TOPLEFT", 3 + ((i - 1) % 5) * 59, -math.floor((i - 1) / 5) * 45)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", -2, 2)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnEnter", function(self)
        if not self.item then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetBagItem(self.item.bag, self.item.slot)
        GameTooltip:AddLine("Total vendor value: " .. formatValue(self.item.value), 1, 1, 1)
        GameTooltip:AddLine("Right-click for more options.", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function(self, mouseButton)
        if not self.item or queue then return end
        if mouseButton == "RightButton" then
            local item = self.item
            MenuUtil.CreateContextMenu(self, function(_, menu)
                menu:CreateButton("Ignore Suggestion", function()
                    for index, candidate in ipairs(candidates) do
                        if candidate == item then
                            table.remove(candidates, index)
                            replaceSuggestions()
                            return
                        end
                    end
                end)
                menu:CreateButton("Add to Exclude List", function()
                    if saveExclusion(item.name) then
                        for index = #candidates, 1, -1 do
                            if normalizedName(candidates[index].name) == normalizedName(item.name) then
                                table.remove(candidates, index)
                            end
                        end
                        for index = #reserve, 1, -1 do
                            if normalizedName(reserve[index].name) == normalizedName(item.name) then
                                table.remove(reserve, index)
                            end
                        end
                        replaceSuggestions()
                        if updateExclusions then
                            updateExclusions()
                        end
                    end
                end)
            end)
        else
            beginQueue({ self.item }, false)
        end
    end)
    return button
end
refresh = function()
    for i = #buttons + 1, #candidates do
        buttons[i] = createResultButton(i)
    end
    resultsContent:SetHeight(math.max(1, math.ceil(#candidates / 5) * 45))
    for i, button in ipairs(buttons) do
        local item = candidates[i]
        button.item = item
        if item then
            button.icon:SetTexture(item.icon)
            button.count:SetText(item.count > 1 and tostring(item.count) or "")
            button:Show()
        else
            button:Hide()
        end
    end
    if not queue and #candidates > 0 then
        bulk:Enable()
    else
        bulk:Disable()
    end
end
scanBags = function()
    queue = nil
    if queueDialog then
        queueDialog:Hide()
    end
    local totalSlots = 0
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
        totalSlots = totalSlots + (C_Container.GetContainerNumSlots(bag) or 0)
    end
    prompt:SetText("Bag slots to free (1-" .. totalSlots .. "):")
    desired = math.max(1, math.min(math.max(1, totalSlots), tonumber(input:GetText()) or 5))
    input:SetText(tostring(desired))
    resultsScroll:SetVerticalScroll(0)
    candidates = {}
    reserve = {}
    local pending = false
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and not info.isLocked and info.hyperlink and not questItem(bag, slot) then
                local name, _, quality, _, _, _, _, _, _, _, price, classID = C_Item.GetItemInfo(info.hyperlink)
                local conjured = isConjured(bag, slot)
                if not name or classID == nil or (price == nil and not info.hasNoValue) or quality == nil or conjured == nil then
                    pending = true
                elseif not conjured and not isExcluded(info.itemID, name, classID)
                    and (not cleanerOption("poorOnly") or quality == 0)
                    and (not cleanerOption("sellableOnly") or (price or 0) > 0)
                then
                    local count = info.stackCount or 1
                    candidates[#candidates + 1] = {
                        bag = bag,
                        slot = slot,
                        id = info.itemID,
                        classID = classID,
                        quality = quality,
                        name = name,
                        link = info.hyperlink,
                        count = count,
                        icon = info.iconFileID,
                        value = (price or 0) * count,
                    }
                end
            end
        end
    end
    table.sort(candidates, function(a, b)
        if a.value ~= b.value then
            return a.value < b.value
        end
        if a.bag ~= b.bag then
            return a.bag < b.bag
        end
        return a.slot < b.slot
    end)
    for index = desired + 1, #candidates do
        reserve[#reserve + 1] = candidates[index]
    end
    while #candidates > desired do
        table.remove(candidates)
    end
    scanPending = pending
    status:SetText(
        pending and "Some item information is loading. Click Find again for complete results."
            or ("Showing " .. #candidates .. " items, lowest total vendor value first. Right click an item to dismiss or permanently ignore a suggestion.")
    )
    refresh()
end
scan:SetScript("OnClick", scanBags)
input:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    scanBags()
end)
queueDialog = CreateFrame("Frame", "DevitoolsBagCleanerQueue", panel, "BackdropTemplate")
queueDialog:SetSize(340, 200)
queueDialog:SetPoint("LEFT", panel, "RIGHT", 8, 0)
queueDialog:SetFrameStrata("DIALOG")
queueDialog:SetFrameLevel(panel:GetFrameLevel() + 10)
queueDialog:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
})
queueDialog:EnableMouse(true)
queueDialog:SetMovable(true)
queueDialog:SetClampedToScreen(true)
queueDialog:RegisterForDrag("LeftButton")
queueDialog:SetScript("OnDragStart", queueDialog.StartMoving)
queueDialog:SetScript("OnDragStop", queueDialog.StopMovingOrSizing)
queueDialog:Hide()
local queueTitle = queueDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
queueTitle:SetPoint("TOP", 0, -18)
queueTitle:SetText("Permanently delete these items?")
local queueNote = queueDialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
queueNote:SetPoint("TOP", 0, -40)
queueNote:SetText("Confirm each item. Drag this window to move it.")
local queueIcon = CreateFrame("Button", nil, queueDialog)
queueIcon:SetSize(40, 40)
queueIcon:SetPoint("TOPLEFT", 30, -75)
queueIcon.texture = queueIcon:CreateTexture(nil, "ARTWORK")
queueIcon.texture:SetAllPoints()
queueIcon:SetScript("OnEnter", function(self)
    local item = queue and queue[1]
    if item and matches(item) then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetBagItem(item.bag, item.slot)
        GameTooltip:Show()
    end
end)
queueIcon:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
local queueItem = queueDialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
queueItem:SetPoint("LEFT", queueIcon, "RIGHT", 12, 0)
queueItem:SetWidth(240)
queueItem:SetJustifyH("LEFT")
local queueDelete = CreateFrame("Button", "DevitoolsBagCleanerQueueDelete", queueDialog, "UIPanelButtonTemplate")
queueDelete:SetSize(140, 24)
queueDelete:SetPoint("BOTTOMLEFT", 25, 20)
queueDelete:SetText("Delete item")
local queueCancel = CreateFrame("Button", nil, queueDialog, "UIPanelButtonTemplate")
queueCancel:SetSize(140, 24)
queueCancel:SetPoint("BOTTOMRIGHT", -25, 20)
queueCancel:SetText("Cancel")
local function showNext()
    local item = queue and queue[1]
    if not item then
        return
    end
    if item.count > 1 then
        queueNote:SetText("This deletes all " .. item.count .. " items in this stack.\nDrag this window to move it.")
    elseif queueIsBulk then
        queueNote:SetText("Confirm each item. Drag this window to move it.")
    else
        queueNote:SetText("Drag this window to move it.")
    end
    queueIcon.texture:SetTexture(item.icon)
    local itemText = item.name .. (item.count > 1 and " x" .. item.count or "")
    if queueIsBulk then
        itemText = itemText .. "\n" .. #queue .. " item(s) remaining"
    end
    queueItem:SetText(itemText)
end
queueCancel:SetScript("OnClick", function()
    queueDialog:Hide()
end)
queueDialog:SetScript("OnHide", function()
    queue = nil
    GameTooltip:Hide()
    refresh()
end)
beginQueue = function(items, isBulk)
    if #items == 0 then
        return
    end
    queueIsBulk = isBulk
    queue = {}
    for _, item in ipairs(items) do
        queue[#queue + 1] = item
    end
    queueTitle:SetText(isBulk and "Permanently delete these items?" or "Permanently delete this item?")
    queueDialog:ClearAllPoints()
    local panelRight, screenRight = panel:GetRight(), UIParent:GetRight()
    if panelRight and screenRight and screenRight - panelRight < 350 then
        queueDialog:SetPoint("RIGHT", panel, "LEFT", -8, 0)
    else
        queueDialog:SetPoint("LEFT", panel, "RIGHT", 8, 0)
    end
    showNext()
    refresh()
    queueDialog:Show()
end
bulk:SetScript("OnClick", function()
    beginQueue(candidates, true)
end)
queueDelete:SetScript("OnClick", function()
    local item = queue[1]
    if item and deleteOne(item) then
        table.remove(queue, 1)
        for i, candidate in ipairs(candidates) do
            if candidate == item then
                table.remove(candidates, i)
                break
            end
        end
        if #queue == 0 then
            queueDialog:Hide()
            status:SetText("Finished. Click Find to refresh.")
        else
            showNext()
        end
        refresh()
    elseif item then
        queueDialog:Hide()
        status:SetText("Deletion stopped. Click Find to refresh.")
        refresh()
    end
end)
panel:SetScript("OnHide", function()
    queueDialog:Hide()
end)

local open = CreateFrame("Button", "DevitoolsBagCleanerButton", UIParent, "UIPanelButtonTemplate")
open:SetSize(110, 24)
open:SetText("Make space")
open:Hide()
local anchoredTo, watched = nil, {}
local positionButton
local function watch(frame)
    if frame and not watched[frame] then
        watched[frame] = true
        frame:HookScript("OnShow", function()
            positionButton()
        end)
        frame:HookScript("OnHide", function()
            positionButton()
        end)
    end
end
positionButton = function()
    local combined = ContainerFrameCombinedBags
    watch(combined)
    watch(ContainerFrame1)
    local bagFrame = combined and combined:IsShown() and combined or nil
    local list = ContainerFrameContainer and ContainerFrameContainer.ContainerFrames
    if type(list) == "table" then
        for _, frame in ipairs(list) do
            watch(frame)
            if not bagFrame and frame:IsShown() then
                bagFrame = frame
            end
        end
    end
    if not bagFrame and ContainerFrame1 and ContainerFrame1:IsShown() then
        bagFrame = ContainerFrame1
    end
    if bagFrame and anchoredTo ~= bagFrame then
        open:SetParent(bagFrame)
        open:ClearAllPoints()
        open:SetPoint("BOTTOMRIGHT", bagFrame, "TOPRIGHT", -40, 2)
        open:SetFrameStrata("DIALOG")
        open:SetFrameLevel(bagFrame:GetFrameLevel() + 10)
        anchoredTo = bagFrame
    end
    if bagFrame and (type(DevitoolsDB) ~= "table" or DevitoolsDB.bagCleanerEnabled ~= false) then
        open:Show()
    else
        open:Hide()
    end
end
open:SetScript("OnClick", function()
    if panel:IsShown() then
        panel:Hide()
    else
        input:SetText(tostring(cleanerOption("defaultSlots") or 5))
        panel:Show()
        scanBags()
    end
end)
open:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Bag Cleaner")
    GameTooltip:AddLine("Find low vendor-value items to delete.", 1, 1, 1, true)
    GameTooltip:Show()
end)
open:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local settings = ns.Settings.RegisterPage("Bag Cleaner")
local label = settings:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
label:SetPoint("TOPLEFT", 20, -20)
label:SetText("Bag Cleaner")
local enabled = CreateFrame("CheckButton", "DevitoolsBagCleanerEnabled", settings, "UICheckButtonTemplate")
enabled:SetPoint("TOPLEFT", 20, -55)
local enabledText = enabled:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
enabledText:SetPoint("LEFT", enabled, "RIGHT", 2, 0)
enabledText:SetText("Enable Bag Cleaner")
enabled:SetScript("OnClick", function(self)
    if type(DevitoolsDB) ~= "table" then
        DevitoolsDB = {}
    end
    DevitoolsDB.bagCleanerEnabled = self:GetChecked() and true or false
    positionButton()
    if not DevitoolsDB.bagCleanerEnabled then
        panel:Hide()
    end
end)
local function filterCheckbox(name, labelText, y, key)
    local box = CreateFrame("CheckButton", name, settings, "UICheckButtonTemplate")
    box:SetPoint("TOPLEFT", 20, y)
    local text = box:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", box, "RIGHT", 2, 0)
    text:SetText(labelText)
    box:SetScript("OnClick", function(self)
        setCleanerOption(key, self:GetChecked() and true or false)
        if panel:IsShown() then
            scanBags()
        end
    end)
    return box
end
local poorOnly = filterCheckbox("DevitoolsBagCleanerPoorOnly", "Show only poor-quality items", -90, "poorOnly")
local sellableOnly = filterCheckbox("DevitoolsBagCleanerSellableOnly", "Exclude items with no vendor value", -125, "sellableOnly")
local defaultLabel = settings:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
defaultLabel:SetPoint("TOPLEFT", 25, -170)
defaultLabel:SetText("Default slots to free:")
local defaultInput = CreateFrame("EditBox", "DevitoolsBagCleanerDefaultSlots", settings, "InputBoxTemplate")
defaultInput:SetSize(45, 24)
defaultInput:SetPoint("LEFT", defaultLabel, "RIGHT", 12, 0)
defaultInput:SetAutoFocus(false)
defaultInput:SetNumeric(true)
defaultInput:SetMaxLetters(4)
defaultInput:SetFontObject(ChatFontNormal)
defaultInput:SetTextInsets(5, 5, 0, 0)
-- Mirror the Buff Reminder field: Forever can hide unfocused EditBox text.
local defaultDisplay = defaultInput:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
defaultDisplay:SetPoint("LEFT", 5, 0)
defaultDisplay:SetPoint("RIGHT", -5, 0)
defaultDisplay:SetJustifyH("LEFT")
defaultInput:SetTextColor(1, 1, 1, 0)
defaultInput:HookScript("OnTextChanged", function(self)
    defaultDisplay:SetText(self:GetText())
end)
defaultInput:HookScript("OnEditFocusGained", function(self)
    defaultDisplay:Hide()
    self:SetTextColor(1, 1, 1, 1)
end)
defaultInput:HookScript("OnEditFocusLost", function(self)
    self:SetTextColor(1, 1, 1, 0)
    defaultDisplay:SetText(self:GetText())
    defaultDisplay:Show()
end)
defaultInput:HookScript("OnShow", function(self)
    self:SetText(tostring(cleanerOption("defaultSlots") or 5))
end)
local defaultApply = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
defaultApply:SetSize(65, 24)
defaultApply:SetPoint("LEFT", defaultInput, "RIGHT", 10, 0)
defaultApply:SetText("Apply")
local function applyDefault()
    local value = math.max(1, math.min(9999, tonumber(defaultInput:GetText()) or 5))
    setCleanerOption("defaultSlots", value)
    defaultInput:SetText(tostring(value))
    defaultInput:ClearFocus()
end
defaultApply:SetScript("OnClick", applyDefault)
defaultInput:SetScript("OnEnterPressed", applyDefault)
local excludeTitle = settings:CreateFontString(nil, "ARTWORK", "GameFontNormal")
excludeTitle:SetPoint("TOPLEFT", 20, -205)
excludeTitle:SetText("Excluded items")
local explanation = settings:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
explanation:SetPoint("TOPLEFT", 20, -227)
explanation:SetText("Hearthstones, Soul Shards, ammunition and conjured items are excluded.\nAdd exact item names for this character.")
local excludeInput = CreateFrame("EditBox", nil, settings, "InputBoxTemplate")
excludeInput:SetSize(220, 24)
excludeInput:SetPoint("TOPLEFT", 25, -266)
excludeInput:SetAutoFocus(false)
local add = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
add:SetSize(65, 24)
add:SetPoint("LEFT", excludeInput, "RIGHT", 10, 0)
add:SetText("Add")
local feedback = settings:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
feedback:SetPoint("TOPLEFT", 20, -300)
local scroll = CreateFrame("ScrollFrame", nil, settings, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 20, -325)
scroll:SetPoint("BOTTOMRIGHT", -45, 20)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(330, 1)
scroll:SetScrollChild(content)
local rows = {}
updateExclusions = function()
    local list = exclusions()
    for i, name in ipairs(list) do
        local row = rows[i]
        if not row then
            local rowIndex = i
            row = CreateFrame("Frame", nil, content)
            row:SetSize(320, 28)
            row:SetPoint("TOPLEFT", 0, -(i - 1) * 30)
            row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            row.text:SetPoint("LEFT", 0, 0)
            row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.remove:SetSize(70, 22)
            row.remove:SetPoint("RIGHT")
            row.remove:SetText("Remove")
            row.remove:SetScript("OnClick", function()
                table.remove(exclusions(), rowIndex)
                updateExclusions()
                if panel:IsShown() then
                    scanBags()
                end
            end)
            rows[i] = row
        end
        row.text:SetText(name)
        row:Show()
    end
    for i = #list + 1, #rows do
        rows[i]:Hide()
    end
    content:SetHeight(math.max(1, #list * 30))
end
local function addExclusion()
    local value = excludeInput:GetText():match("^%s*(.-)%s*$")
    if value == "" then
        feedback:SetText("Enter an item name.")
        return
    end
    if not saveExclusion(value) then
        feedback:SetText("That item is already excluded.")
        return
    end
    excludeInput:SetText("")
    excludeInput:ClearFocus()
    feedback:SetText("Added " .. value .. ".")
    updateExclusions()
    if panel:IsShown() then
        scanBags()
    end
end
add:SetScript("OnClick", addExclusion)
excludeInput:SetScript("OnEnterPressed", addExclusion)
local function updateSettings()
    enabled:SetChecked(type(DevitoolsDB) ~= "table" or DevitoolsDB.bagCleanerEnabled ~= false)
    poorOnly:SetChecked(cleanerOption("poorOnly") == true)
    sellableOnly:SetChecked(cleanerOption("sellableOnly") == true)
    if not defaultInput:HasFocus() then
        defaultInput:SetText(tostring(cleanerOption("defaultSlots") or 5))
    end
    updateExclusions()
end
settings:SetScript("OnShow", updateSettings)
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function()
    positionButton()
    if type(DevitoolsDB) == "table" and DevitoolsDB.bagCleanerEnabled == false then
        open:Hide()
    end
    updateSettings()
end)
