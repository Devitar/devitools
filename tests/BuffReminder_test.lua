-- Run with a Lua 5.1-compatible interpreter from the project root.
local frames, events = {}, {}
local reminderFrame, settingsButton, openedSettings
local methods = {}
methods.__index = function(_, key)
    return methods[key] or function() end
end
function methods:SetScript(event, fn) self[event] = fn end
function methods:HookScript(event, fn) self[event] = fn end
function methods:RegisterEvent(event) events[event] = self end
function methods:RegisterForDrag(button) self.dragButton = button end
function methods:StartMoving() self.startedMoving = true end
function methods:CreateFontString()
    return setmetatable({ parent = self }, methods)
end
function methods:SetText(text)
    self.text = text
    if self.parent and self.parent.kind == "CheckButton" then self.parent.label = text end
end
function methods:GetText() return self.text or "" end
function methods:SetPoint(point, ...)
    if point == "TOPLEFT" then self.top = select(2, ...) end
end
function methods:SetHeight(value) self.height = value end
function methods:GetStringHeight()
    return type(self.text) == "string" and self.text:find("Firestone", 1, true) and 32 or 14
end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:IsShown() return true end
function methods:IsVisible() return true end
CreateFrame = function(kind, name, parent)
    local frame = setmetatable({ kind = kind, parent = parent }, methods)
    frames[#frames + 1] = frame
    if name == "DevitoolsReminderFrame" then reminderFrame = frame end
    if name == "DevitoolsBuffSettingsButton" then settingsButton = frame end
    return frame
end
UIParent, ChatFontNormal = {}, {}
UnitClass = function() return "Warlock", "WARLOCK" end
UnitIsDeadOrGhost = function() return false end
InCombatLockdown = function() return false end
local tooltipText, tooltipHidden
GameTooltip = {
    SetOwner = function() end,
    SetText = function() end,
    AddLine = function(_, text) tooltipText = text end,
    Show = function() tooltipHidden = false end,
    Hide = function() tooltipHidden = true end,
}
local activeName
C_UnitAuras = { GetAuraDataByIndex = function(_, index)
    if index == 1 and activeName then return { name = activeName, expirationTime = 0, spellId = 1 } end
end }
local currentMenu
MenuUtil = { CreateContextMenu = function(owner, build)
    currentMenu = { buttons = {} }
    function currentMenu:CreateTitle() end
    function currentMenu:CreateButton(label, callback) self.buttons[label] = callback end
    build(owner, currentMenu)
end }
C_Spell = { GetSpellName = function(id)
    return ({ [132] = "Detect Invisibility", [5697] = "Unending Breath", [706] = "Demon Armor", [19028] = "Soul Link" })[id]
end }
local ns = { Settings = { RegisterPage = function() return CreateFrame("Frame") end,
    Open = function(label) openedSettings = label end } }
ns.WeaponEnchants = { AppendReminders = function(settings, _, reminders)
    if settings.testLong then
        reminders[#reminders + 1] = "Main-hand Firestone/Spellstone (missing)"
        reminders[#reminders + 1] = "Next reminder (missing)"
    end
end }
assert(loadfile("Modules/TrackedBuffs.lua"))("Devitools", ns)
assert(loadfile("Data/SpellData.lua"))("Devitools", ns)
assert(loadfile("Modules/BuffReminder.lua"))("Devitools", ns)
DevitoolsDB = { buffs = { [132] = true } }
DevitoolsCharacterDB = {}
events.ADDON_LOADED.OnEvent(events.ADDON_LOADED, "ADDON_LOADED", "Devitools")
assert(DevitoolsDB.wellFed == false and DevitoolsDB.wellRested == false,
    "Well Fed and Well-Rested must default off")
assert(reminderFrame.dragButton == "RightButton", "reminder frame must use right-drag")
assert(settingsButton and settingsButton.dragButton == "RightButton", "settings button must allow right-dragging the window")
settingsButton.OnClick(settingsButton)
assert(openedSettings == "Buff Reminder", "the cog should open the Buff Reminder settings page")
settingsButton.OnEnter(settingsButton)
assert(tooltipText:find("choose which reminders", 1, true), "the cog should explain its purpose")
reminderFrame.OnEnter(reminderFrame)
assert(tooltipText:find("Right%-drag"), "unlocked tooltip should explain how to move the window")
reminderFrame.OnDragStart(reminderFrame)
assert(reminderFrame.startedMoving, "the unlocked reminder window should move")
reminderFrame.startedMoving = false
DevitoolsDB.locked = true
reminderFrame.OnDragStart(reminderFrame)
assert(not reminderFrame.startedMoving, "the locked reminder window must not move")
reminderFrame.OnEnter(reminderFrame)
assert(tooltipText:find("locked"), "locked tooltip should explain how to unlock")
reminderFrame.OnLeave(reminderFrame)
assert(tooltipHidden, "leaving the reminder window should hide the tooltip")
DevitoolsDB.locked = false
for _, frame in ipairs(frames) do
    if frame.kind == "Frame" and rawget(frame, "parent") and frame.parent.kind == "ScrollFrame" and rawget(frame, "OnShow") then
        frame.OnShow(frame)
    end
end
local byLabel, mainHands = {}, {}
for _, frame in ipairs(frames) do
    if rawget(frame, "label") then
        byLabel[frame.label] = frame
        if frame.label == "Main hand" then mainHands[#mainHands + 1] = frame end
    end
end
assert(byLabel["Detect Invisibility"].checked == true, "an explicitly enabled utility buff must remain enabled")
assert(byLabel["Unending Breath"].checked == false, "an unset utility buff must default off")
assert(byLabel["Demon Armor"].checked == true, "regular buffs must continue to default on")
assert(not rawget(mainHands[1], "checked") and not rawget(byLabel["Off hand"], "checked"), "weapon coating reminders must default off")
mainHands[1].checked = true
mainHands[1].OnClick(mainHands[1])
assert(DevitoolsDB.weaponMainHand == true and not DevitoolsDB.weaponOffHand, "weapon hand preferences must be independent")
assert(#mainHands == 2 and not rawget(mainHands[2], "checked"), "warlock stone reminder must default off separately")
mainHands[2].checked = true
mainHands[2].OnClick(mainHands[2])
assert(DevitoolsDB.weaponImbueMainHand == true, "warlock stone reminder must save its own setting")
DevitoolsDB.testLong, DevitoolsDB.wellFed, DevitoolsDB.wellRested = true, false, false
mainHands[1].OnClick(mainHands[1])
assert(reminderFrame.rows[1].top == -24 and reminderFrame.rows[2].top == -59,
    "a wrapped reminder must move the following row down by its measured height")
assert(reminderFrame.height >= 85, "the reminder window must grow to contain wrapped rows")
DevitoolsDB.testLong = false
local addButton
for _, frame in ipairs(frames) do
    if frame.kind == "Button" and rawget(frame, "text") == "Track active buff" then addButton = frame end
end
activeName = "Demon Armor"
addButton.OnClick(addButton)
assert(not currentMenu.buttons[activeName], "class buffs already covered by settings must be excluded")
activeName = "Well Fed"
addButton.OnClick(addButton)
assert(not currentMenu.buttons[activeName], "built-in food buffs must be excluded")
activeName = "Elixir of the Mongoose"
addButton.OnClick(addButton)
assert(currentMenu.buttons[activeName], "an active buff should be offered for tracking")
currentMenu.buttons[activeName]()
assert(#DevitoolsCharacterDB.trackedBuffs == 1 and DevitoolsCharacterDB.trackedBuffs[1].name == "Elixir of the Mongoose", "adding a consumable should save it per character")
addButton.OnClick(addButton)
assert(not currentMenu.buttons[activeName], "already manually tracked buffs must be excluded")
local remove, trackedBox
for _, frame in ipairs(frames) do
    if frame.kind == "Button" and rawget(frame, "text") == "Remove" then remove = frame end
    if frame.kind == "CheckButton" and rawget(frame, "label") == activeName then trackedBox = frame end
end
trackedBox.checked = false
trackedBox.OnClick(trackedBox)
assert(DevitoolsCharacterDB.trackedBuffs[1].enabled == false, "a tracked buff should be toggleable")
remove.OnClick(remove)
assert(#DevitoolsCharacterDB.trackedBuffs == 0, "removing a consumable should remove its saved reminder")
DevitoolsDB.buffs[132] = nil
for _, frame in ipairs(frames) do
    if frame.kind == "Frame" and rawget(frame, "parent") and frame.parent.kind == "ScrollFrame" and rawget(frame, "OnShow") then
        frame.OnShow(frame)
    end
end
assert(byLabel["Detect Invisibility"].checked == false, "unset Detect Invisibility must default off")
local breath = byLabel["Unending Breath"]
breath.checked = true
breath.OnClick(breath)
assert(DevitoolsDB.buffs[5697] == true, "enabling a utility buff must save the choice")
DevitoolsDB.trackedBuffs = { { name = "Elixir", enabled = false } }
DevitoolsCharacterDB = {}
events.ADDON_LOADED.OnEvent(events.ADDON_LOADED, "ADDON_LOADED", "Devitools")
local main = DevitoolsCharacterDB
assert(main.trackedBuffs[1].name == "Elixir" and main.trackedBuffs[1].enabled == false, "old shared settings should migrate")
main.trackedBuffs[1].enabled = true
DevitoolsCharacterDB = {}
events.ADDON_LOADED.OnEvent(events.ADDON_LOADED, "ADDON_LOADED", "Devitools")
assert(DevitoolsCharacterDB.trackedBuffs[1].enabled == false, "each character must receive an independent copy")
table.remove(DevitoolsCharacterDB.trackedBuffs, 1)
assert(#main.trackedBuffs == 1 and main.trackedBuffs[1].enabled, "removing an alt's buff must not change the main's")
DevitoolsDB.wellFed, DevitoolsDB.wellRested = true, true
events.ADDON_LOADED.OnEvent(events.ADDON_LOADED, "ADDON_LOADED", "Devitools")
assert(DevitoolsDB.wellFed and DevitoolsDB.wellRested, "existing enabled choices must be preserved")
io.write("BuffReminder tests passed\n")
