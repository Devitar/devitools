local addonName, ns = ...
local spells = ns.SpellData
local buffs = spells.classBuffs
local utilitySpells = {}
for _, families in pairs(buffs) do
    for _, family in ipairs(families) do
        if family.utility then
            for _, id in ipairs(family.spells) do
                utilitySpells[id] = true
            end
        end
    end
end

local defaults = { wellFed = false, wellRested = false, enabled = true, locked = false, refresh = 300 }
local db
local characterDB
local spellbookReady = false
local frame = CreateFrame("Frame", "DevitoolsReminderFrame", UIParent, "BackdropTemplate")
frame:SetSize(240, 40)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("RightButton")
frame:SetClampedToScreen(true)
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.title:SetPoint("TOP", -10, -9)
frame.title:SetText("Devitools: Buff reminders")
frame.rows = {}
frame:Hide()

-- Restricted game values cannot safely be compared or used as table keys.
local function safe(value)
    return not issecretvalue or not issecretvalue(value)
end

local function spellName(id)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(id)
    end
end

-- Rank IDs can change across builds. Index learned player spellbook entries by
-- localized name, then match the configured base spell to any learned rank.
-- IsSpellKnown filters out future and off-spec spellbook entries.
local learnedNames = {}
local function refreshSpellbook()
    learnedNames = {}
    if
        not C_SpellBook
        or not C_SpellBook.GetNumSpellBookSkillLines
        or not C_SpellBook.GetSpellBookSkillLineInfo
        or not C_SpellBook.GetSpellBookItemInfo
        or not C_SpellBook.GetSpellBookItemName
        or not C_SpellBook.IsSpellKnown
        or not Enum
        or not Enum.SpellBookSpellBank
    then
        return
    end
    local bank = Enum.SpellBookSpellBank.Player
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if info and info.itemIndexOffset and info.numSpellBookItems then
            for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
                if item and item.spellID and C_SpellBook.IsSpellKnown(item.spellID) then
                    local name = C_SpellBook.GetSpellBookItemName(slot, bank)
                    if name and safe(name) then
                        learnedNames[name] = true
                    end
                end
            end
        end
    end
end

local function known(id)
    if not C_SpellBook or not C_SpellBook.IsSpellKnown then
        return false
    end
    if C_SpellBook.IsSpellKnown(id) then
        return true
    end
    local name = spellName(id)
    return name and safe(name) and learnedNames[name] == true or false
end
-- Demon Skin's preference is per character because learning Demon Armor can
-- change it for one warlock without changing another character's choice.
local function buffEnabled(id)
    if id == 687 and characterDB.demonSkinEnabled ~= nil then
        return characterDB.demonSkinEnabled
    end
    if db.buffs[id] ~= nil then
        return db.buffs[id] ~= false
    end
    return not utilitySpells[id]
end

local function setBuffEnabled(id, enabled)
    if id == 687 then
        characterDB.demonSkinEnabled = enabled
    else
        db.buffs[id] = enabled
    end
end

-- Disable Demon Skin only the first time this character has Demon Armor;
-- a later manual choice to enable Demon Skin is preserved across reloads.
local function checkDemonArmor()
    local _, class = UnitClass("player")
    if class ~= "WARLOCK" then
        return
    end
    local hasArmor = known(706)
    if hasArmor and not characterDB.hasSeenDemonArmor then
        characterDB.demonSkinEnabled = false
        characterDB.hasSeenDemonArmor = true
    end
end
local function update()
    if not db or not db.enabled or InCombatLockdown() or UnitIsDeadOrGhost("player") then
        frame:Hide()
        return
    end

    -- A numeric value is seconds remaining; true means the aura is present
    -- but has no readable expiration. Keep the longest of same-named auras.
    local active = {}
    local restedDuration
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then
        frame:Hide()
        return
    end
    for i = 1, 255 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not safe(aura) then
            frame:Hide()
            return
        end
        if not aura then
            break
        end
        if safe(aura.name) and aura.name then
            local remaining
            if safe(aura.expirationTime) and aura.expirationTime and aura.expirationTime > 0 then
                remaining = aura.expirationTime - GetTime()
            end
            -- Match the sleeping bag aura by ID, not the similarly named
            -- Well Rested legacy perk.
            if safe(aura.spellId) and aura.spellId == spells.wellRested then
                restedDuration = remaining or true
            end
            local previous = active[aura.name]
            if not previous or previous ~= true and (not remaining or remaining > previous) then
                active[aura.name] = remaining or true
            end
        end
    end

    local reminders = {}
    local _, class = UnitClass("player")
    for _, family in ipairs(buffs[class] or {}) do
        local wanted, best
        for _, id in ipairs(family.spells) do
            local name = spellName(id)
            if name and safe(name) then
                if not wanted and buffEnabled(id) and known(id) then
                    wanted = name
                end
                local duration = active[name]
                if duration == true then
                    best = true
                elseif duration and best ~= true and (not best or duration > best) then
                    best = duration
                end
            end
        end
        for _, id in ipairs(family.auraIDs or {}) do
            local name = spellName(id)
            local duration = name and safe(name) and active[name]
            if duration == true then
                best = true
            elseif duration and best ~= true and (not best or duration > best) then
                best = duration
            end
        end
        if wanted and best ~= true and (not best or best <= db.refresh) then
            table.insert(
                reminders,
                (best and "|cffffff00" or "|cffff3333") .. wanted .. (best and " (expiring)|r" or " (missing)|r")
            )
        end
    end
    if db.wellFed then
        local foodName = spellName(spells.wellFed) or "Well Fed"
        local duration = safe(foodName) and active[foodName]
        if duration ~= true and (not duration or duration <= db.refresh) then
            table.insert(
                reminders,
                (duration and "|cffffff00" or "|cffff3333")
                    .. foodName
                    .. (duration and " (expiring)|r" or " (missing)|r")
            )
        end
    end

    if db.wellRested and restedDuration ~= true and (not restedDuration or restedDuration <= db.refresh) then
        local name = spellName(spells.wellRested) or "Well-Rested"
        if safe(name) then
            table.insert(
                reminders,
                (restedDuration and "|cffffff00" or "|cffff3333")
                    .. name
                    .. (restedDuration and " (expiring)|r" or " (missing)|r")
            )
        end
    end

    if ns.WeaponEnchants then
        ns.WeaponEnchants.AppendReminders(db, db.refresh, reminders)
    end
    if ns.TrackedBuffs then
        ns.TrackedBuffs.Append(characterDB.trackedBuffs, active, db.refresh, reminders)
    end

    if #reminders == 0 then
        frame:Hide()
        return
    end
    local offset = 24
    for i, text in ipairs(reminders) do
        if not frame.rows[i] then
            local row = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row:SetWidth(212)
            row:SetJustifyH("LEFT")
            row:SetWordWrap(true)
            frame.rows[i] = row
        end
        local row = frame.rows[i]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 14, -offset)
        row:SetText(text)
        row:Show()
        local height = row:GetStringHeight()
        if not safe(height) or type(height) ~= "number" then
            height = 0
        end
        offset = offset + math.max(18, math.ceil(height) + 3)
    end
    for i = #reminders + 1, #frame.rows do
        frame.rows[i]:Hide()
    end
    frame:SetHeight(offset + 8)
    frame:Show()
end

local function startMoving()
    if db and not db.locked and not InCombatLockdown() then
        frame:StartMoving()
    end
end
local function stopMoving()
    frame:StopMovingOrSizing()
    local point, _, relativePoint, x, y = frame:GetPoint()
    db.position = { point, relativePoint, x, y }
end
frame:SetScript("OnDragStart", startMoving)
frame:SetScript("OnDragStop", stopMoving)
frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Buff reminders")
    if db and db.locked then
        GameTooltip:AddLine("Window locked. Unlock it in Buff Reminder settings to move it.", 1, 1, 1, true)
    else
        GameTooltip:AddLine("Right-drag to move. You can lock the window in Buff Reminder settings.", 1, 1, 1, true)
    end
    GameTooltip:Show()
end)
frame:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local settingsButton = CreateFrame("Button", "DevitoolsBuffSettingsButton", frame)
settingsButton:SetSize(20, 20)
settingsButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -5)
settingsButton:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
settingsButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
settingsButton:RegisterForClicks("LeftButtonUp")
settingsButton:RegisterForDrag("RightButton")
settingsButton:SetScript("OnDragStart", startMoving)
settingsButton:SetScript("OnDragStop", stopMoving)
settingsButton:SetScript("OnClick", function()
    ns.Settings.Open("Buff Reminder")
end)
settingsButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Buff Reminder settings")
    GameTooltip:AddLine("Click to choose which reminders to show.", 1, 1, 1, true)
    GameTooltip:Show()
end)
settingsButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local refreshSettings
local events = CreateFrame("Frame")
for _, event in ipairs({
    "ADDON_LOADED",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_ALIVE",
    "PLAYER_DEAD",
    "SPELLS_CHANGED",
    "UNIT_AURA",
    "PLAYER_EQUIPMENT_CHANGED",
}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" then
        if arg ~= addonName then
            return
        end
        if type(DevitoolsDB) ~= "table" then
            DevitoolsDB = {}
        end
        db = DevitoolsDB
        if type(DevitoolsCharacterDB) ~= "table" then
            DevitoolsCharacterDB = {}
        end
        characterDB = DevitoolsCharacterDB
        for key, value in pairs(defaults) do
            if db[key] == nil then
                db[key] = value
            end
        end
        if type(db.buffs) ~= "table" then
            db.buffs = {}
        end
        -- Copy the old account-wide list once per character; leave it in place
        -- until every character has had a chance to migrate its own copy.
        if type(characterDB.trackedBuffs) ~= "table" then
            characterDB.trackedBuffs = {}
            if type(db.trackedBuffs) == "table" then
                for _, entry in ipairs(db.trackedBuffs) do
                    if type(entry) == "table" and type(entry.name) == "string" then
                        table.insert(characterDB.trackedBuffs, { name = entry.name, enabled = entry.enabled ~= false })
                    end
                end
            end
        end
        if type(db.refresh) ~= "number" then
            db.refresh = defaults.refresh
        end
        if
            type(db.position) == "table"
            and type(db.position[1]) == "string"
            and type(db.position[2]) == "string"
            and type(db.position[3]) == "number"
            and type(db.position[4]) == "number"
        then
            frame:ClearAllPoints()
            frame:SetPoint(db.position[1], UIParent, db.position[2], db.position[3], db.position[4])
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        spellbookReady = true
        refreshSpellbook()
        checkDemonArmor()
    elseif event == "SPELLS_CHANGED" and spellbookReady then
        refreshSpellbook()
        checkDemonArmor()
    elseif event == "UNIT_AURA" and arg ~= "player" then
        return
    end
    update()
    if refreshSettings and (event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD") then
        refreshSettings()
    end
end)
-- Aura events detect changes, but time passing alone must also trigger a
-- refresh so an active buff can cross the expiration-warning threshold.
local elapsed = 0
events:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed >= 2 then
        elapsed = 0
        update()
    end
end)

-- Register a canvas in the game's AddOns settings so it remains accessible
-- even when reminders are hidden or disabled.
local page = ns.Settings.RegisterPage("Buff Reminder")
local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -26, 0)
local panel = CreateFrame("Frame", nil, scroll)
panel:SetSize(560, 600)
scroll:SetScrollChild(panel)
local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
heading:SetPoint("TOPLEFT", 20, -20)
heading:SetText("Buff Reminder")
local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
description:SetText("Choose which reminders to show. Changes apply immediately.")

local controls = {}
local function checkbox(label, x, y, getValue, setValue)
    local box = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    box:SetPoint("TOPLEFT", x, y)
    local text = box:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", box, "RIGHT", 2, 0)
    text:SetText(label)
    box:SetScript("OnClick", function(self)
        setValue(self:GetChecked() and true or false)
        update()
    end)
    table.insert(controls, { box = box, get = getValue })
    return box
end

checkbox("Enable reminders", 20, -72, function()
    return db.enabled
end, function(v)
    db.enabled = v
end)
checkbox("Well Fed", 20, -104, function()
    return db.wellFed
end, function(v)
    db.wellFed = v
end)
checkbox("Well-Rested", 300, -104, function()
    return db.wellRested
end, function(v)
    db.wellRested = v
end)
checkbox("Lock reminder window", 20, -136, function()
    return db.locked
end, function(v)
    db.locked = v
end)

local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
reset:SetSize(145, 24)
reset:SetPoint("TOPLEFT", 300, -140)
reset:SetText("Reset position")
reset:SetScript("OnClick", function()
    db.position = nil
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
end)

local timeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
timeLabel:SetPoint("TOPLEFT", 25, -180)
timeLabel:SetText("Warn before expiration (seconds, 0-7200):")
local timeBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
timeBox:SetSize(65, 24)
timeBox:SetPoint("LEFT", timeLabel, "RIGHT", 12, 0)
timeBox:SetAutoFocus(false)
timeBox:SetFontObject(ChatFontNormal)
timeBox:SetTextInsets(5, 5, 0, 0)
-- An unfocused WoW EditBox can fail to render its saved text. Show a separate
-- FontString until the box receives focus, and validate the input on Apply.
timeBox:SetMaxLetters(4)
local timeDisplay = timeBox:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
timeDisplay:SetPoint("LEFT", 5, 0)
timeDisplay:SetPoint("RIGHT", -5, 0)
timeDisplay:SetJustifyH("LEFT")
timeBox:SetTextColor(1, 1, 1, 0)
timeBox:HookScript("OnTextChanged", function(self)
    timeDisplay:SetText(self:GetText())
end)
timeBox:HookScript("OnEditFocusGained", function(self)
    timeDisplay:Hide()
    self:SetTextColor(1, 1, 1, 1)
end)
timeBox:HookScript("OnEditFocusLost", function(self)
    self:SetTextColor(1, 1, 1, 0)
    timeDisplay:SetText(self:GetText())
    timeDisplay:Show()
end)
timeBox:HookScript("OnShow", function(self)
    if db then
        self:SetText(tostring(db.refresh))
    end
end)
local apply = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
apply:SetSize(65, 24)
apply:SetPoint("LEFT", timeBox, "RIGHT", 10, 0)
apply:SetText("Apply")
local timeStatus = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
timeStatus:SetPoint("TOPLEFT", timeLabel, "BOTTOMLEFT", 0, -7)
local function applyTime()
    local value = tonumber(timeBox:GetText())
    if not value or value % 1 ~= 0 or value < 0 or value > 7200 then
        timeStatus:SetText("Enter a number from 0 to 7200.")
        return
    end
    db.refresh = value
    timeStatus:SetText("Warning time saved.")
    timeBox:ClearFocus()
    update()
end
apply:SetScript("OnClick", applyTime)
timeBox:SetScript("OnEnterPressed", applyTime)
timeBox:SetScript("OnEscapePressed", function(self)
    self:SetText(tostring(db.refresh))
    self:ClearFocus()
end)

local spellsHeading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
spellsHeading:SetPoint("TOPLEFT", 20, -230)
spellsHeading:SetText("Your class buffs")
local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
hint:SetPoint("TOPLEFT", spellsHeading, "BOTTOMLEFT", 0, -6)
hint:SetText("Only learned spells are reminded. Related alternatives share a reminder.")
local _, playerClass = UnitClass("player")
local count = 0
local listTop = -275
if playerClass == "WARLOCK" then
    local armorName = spellName(706) or "Demon Armor"
    local skinName = spellName(687) or "Demon Skin"
    checkbox(armorName, 20, listTop, function()
        return buffEnabled(706)
    end, function(v)
        setBuffEnabled(706, v)
    end)
    checkbox(skinName .. " (replaced by " .. armorName .. ")", 40, listTop - 30, function()
        return buffEnabled(687)
    end, function(v)
        setBuffEnabled(687, v)
    end)
    local upgradeHint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    upgradeHint:SetPoint("TOPLEFT", 70, listTop - 60)
    upgradeHint:SetText("Turns off when you learn Demon Armor; you can turn it back on.")
    listTop = listTop - 90
elseif playerClass == "MAGE" then
    local iceName = spellName(7302) or "Ice Armor"
    local frostName = spellName(168) or "Frost Armor"
    checkbox(iceName, 20, listTop, function()
        return buffEnabled(7302)
    end, function(v)
        setBuffEnabled(7302, v)
    end)
    checkbox(frostName .. " (replaced by " .. iceName .. ")", 40, listTop - 30, function()
        return buffEnabled(168)
    end, function(v)
        setBuffEnabled(168, v)
    end)
    checkbox(spellName(6117) or "Mage Armor", 300, listTop, function()
        return buffEnabled(6117)
    end, function(v)
        setBuffEnabled(6117, v)
    end)
    local armorHint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    armorHint:SetPoint("TOPLEFT", 50, listTop - 60)
    armorHint:SetText("Mage Armor is an alternative; only one armor can be active.")
    listTop = listTop - 90
end
for _, family in ipairs(buffs[playerClass] or {}) do
    for _, id in ipairs(family.spells) do
        local shownAbove = family.utility
            or playerClass == "WARLOCK" and (id == 687 or id == 706)
            or playerClass == "MAGE" and (id == 168 or id == 7302 or id == 6117)
        if not shownAbove then
            local spellID = id
            local name = spellName(spellID) or ("Spell " .. spellID)
            count = count + 1
            local column = (count - 1) % 2
            local row = math.floor((count - 1) / 2)
            checkbox(name, 20 + column * 260, listTop - row * 30, function()
                return buffEnabled(spellID)
            end, function(v)
                setBuffEnabled(spellID, v)
            end)
        end
    end
end
local utilityIDs = {}
for _, family in ipairs(buffs[playerClass] or {}) do
    if family.utility then
        for _, id in ipairs(family.spells) do
            utilityIDs[#utilityIDs + 1] = id
        end
    end
end
local bottom = listTop - math.ceil(count / 2) * 30
if #utilityIDs > 0 then
    local utilityHeading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    utilityHeading:SetPoint("TOPLEFT", 20, bottom - 15)
    utilityHeading:SetText("Situational or utility buffs (off by default)")
    for index, id in ipairs(utilityIDs) do
        local spellID = id
        local column = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        checkbox(spellName(spellID) or ("Spell " .. spellID), 20 + column * 260, bottom - 45 - row * 30, function()
            return buffEnabled(spellID)
        end, function(v)
            setBuffEnabled(spellID, v)
        end)
    end
    bottom = bottom - 45 - math.ceil(#utilityIDs / 2) * 30
end
local weaponHeading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
weaponHeading:SetPoint("TOPLEFT", 20, bottom - 15)
weaponHeading:SetText("Temporary weapon coatings (off by default)")
local weaponHint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
weaponHint:SetPoint("TOPLEFT", weaponHeading, "BOTTOMLEFT", 0, -6)
weaponHint:SetText("Tracks sharpening stones, weightstones, oils, and other temporary coatings.")
checkbox("Main hand", 20, bottom - 60, function()
    return db.weaponMainHand
end, function(v)
    db.weaponMainHand = v
end)
checkbox("Off hand", 300, bottom - 60, function()
    return db.weaponOffHand
end, function(v)
    db.weaponOffHand = v
end)
bottom = bottom - 90
local classImbues = {
    ROGUE = {
        title = "Rogue poisons",
        hint = "Any poison on the selected weapon satisfies its reminder.",
        offHand = true,
    },
    WARLOCK = { title = "Firestone / Spellstone", hint = "Either stone imbue satisfies the main-hand reminder." },
    SHAMAN = {
        title = "Shaman weapon imbues",
        hint = "Any weapon imbue satisfies the selected hand's reminder.",
        offHand = true,
    },
}
local classImbue = classImbues[playerClass]
if classImbue then
    local imbueHeading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    imbueHeading:SetPoint("TOPLEFT", 20, bottom - 15)
    imbueHeading:SetText(classImbue.title .. " (off by default)")
    local imbueHint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    imbueHint:SetPoint("TOPLEFT", imbueHeading, "BOTTOMLEFT", 0, -6)
    imbueHint:SetText(classImbue.hint)
    checkbox("Main hand", 20, bottom - 60, function()
        return db.weaponImbueMainHand
    end, function(v)
        db.weaponImbueMainHand = v
    end)
    if classImbue.offHand then
        checkbox("Off hand", 300, bottom - 60, function()
            return db.weaponImbueOffHand
        end, function(v)
            db.weaponImbueOffHand = v
        end)
    end
    bottom = bottom - 90
end
local consumableHeading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
consumableHeading:SetPoint("TOPLEFT", 20, bottom - 15)
consumableHeading:SetText("Manually tracked buffs")
local consumableHint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
consumableHint:SetPoint("TOPLEFT", consumableHeading, "BOTTOMLEFT", 0, -6)
consumableHint:SetText("Select a buff you currently have to track it.")
local consumableAdd = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
consumableAdd:SetSize(160, 24)
consumableAdd:SetPoint("TOPLEFT", 25, bottom - 65)
consumableAdd:SetText("Track active buff")
local consumableStatus = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
consumableStatus:SetPoint("TOPLEFT", 25, bottom - 95)
local consumableRows = {}
local function renderConsumables()
    if not db then
        return
    end
    for index, entry in ipairs(characterDB.trackedBuffs) do
        local rowIndex = index
        local tracked = entry
        local row = consumableRows[index]
        if not row then
            row = {}
            row.box = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
            row.box:SetPoint("TOPLEFT", 20, bottom - 120 - (index - 1) * 30)
            row.label = row.box:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            row.label:SetPoint("LEFT", row.box, "RIGHT", 2, 0)
            row.label:SetWidth(360)
            row.label:SetJustifyH("LEFT")
            row.remove = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
            row.remove:SetSize(65, 22)
            row.remove:SetPoint("TOPLEFT", 455, bottom - 122 - (index - 1) * 30)
            row.remove:SetText("Remove")
            consumableRows[index] = row
        end
        row.label:SetText(tracked.name)
        row.box:SetChecked(tracked.enabled ~= false)
        row.box:SetScript("OnClick", function(self)
            tracked.enabled = self:GetChecked() and true or false
            update()
        end)
        row.remove:SetScript("OnClick", function()
            table.remove(characterDB.trackedBuffs, rowIndex)
            renderConsumables()
            update()
        end)
        row.box:Show()
        row.label:Show()
        row.remove:Show()
    end
    for index = #characterDB.trackedBuffs + 1, #consumableRows do
        consumableRows[index].box:Hide()
        consumableRows[index].label:Hide()
        consumableRows[index].remove:Hide()
    end
    panel:SetHeight(math.max(500, -bottom + 155 + #characterDB.trackedBuffs * 30))
end
local function addConsumable(name)
    local added, reason = ns.TrackedBuffs.Add(characterDB.trackedBuffs, name)
    if not added then
        consumableStatus:SetText(reason)
        return
    end
    consumableStatus:SetText("")
    renderConsumables()
    update()
end
consumableAdd:SetScript("OnClick", function(self)
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then
        return
    end
    local names, seen, coveredIDs, coveredNames = {}, {}, {}, {}
    local function cover(id, fallback)
        coveredIDs[id] = true
        local name = spellName(id)
        if not safe(name) then
            return
        end
        name = name or fallback
        if type(name) == "string" then
            coveredNames[name] = true
        end
    end
    cover(spells.wellFed, "Well Fed")
    cover(spells.wellRested, "Well-Rested")
    for _, family in ipairs(buffs[playerClass] or {}) do
        for _, id in ipairs(family.spells) do
            cover(id)
        end
        for _, id in ipairs(family.auraIDs or {}) do
            cover(id)
        end
    end
    for _, tracked in ipairs(characterDB.trackedBuffs) do
        if type(tracked.name) == "string" then
            coveredNames[tracked.name] = true
        end
    end
    for index = 1, 255 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
        if not safe(aura) then
            break
        end
        if not aura then
            break
        end
        local name = aura.name
        local id = aura.spellId
        if
            safe(name)
            and type(name) == "string"
            and safe(id)
            and not coveredIDs[id]
            and not coveredNames[name]
            and not seen[name]
        then
            names[#names + 1] = name
            seen[name] = true
        end
    end
    table.sort(names)
    MenuUtil.CreateContextMenu(self, function(_, menu)
        menu:CreateTitle(#names > 0 and "Choose a buff to track" or "No readable active buffs")
        for _, name in ipairs(names) do
            local selected = name
            menu:CreateButton(selected, function()
                addConsumable(selected)
            end)
        end
    end)
end)
panel:SetHeight(math.max(500, -bottom + 155))
if count == 0 and playerClass ~= "WARLOCK" and playerClass ~= "MAGE" then
    local none = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    none:SetPoint("TOPLEFT", 25, -280)
    none:SetText("No class buffs are currently configured for your class.")
end
refreshSettings = function()
    if not panel:IsShown() then
        return
    end
    for _, control in ipairs(controls) do
        control.box:SetChecked(control.get())
    end
    if timeBox:IsVisible() then
        timeBox:SetText(tostring(db.refresh))
    end
    timeStatus:SetText("")
    renderConsumables()
end
panel:SetScript("OnShow", refreshSettings)

ns.BuffReminder = {}
function ns.BuffReminder.OpenSettings()
    ns.Settings.Open("Buff Reminder")
end
