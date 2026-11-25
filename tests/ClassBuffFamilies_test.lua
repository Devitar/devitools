-- Run with a Lua 5.1-compatible interpreter from the project root.
local frames, events, labels, reminder, currentClass, knownSpells, aura, formID
local methods = {}
methods.__index = function(_, key) return methods[key] or function() end end
function methods:SetScript(key, fn) self[key] = fn end
function methods:HookScript(key, fn) self[key] = fn end
function methods:RegisterEvent(event) events[event] = self end
function methods:CreateFontString() return setmetatable({ parent = self }, methods) end
function methods:SetText(value)
    self.text = value
    if self.parent and self.parent.kind == "CheckButton" then labels[value] = self.parent end
end
function methods:GetText() return rawget(self, "text") or "" end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:Show() self.visible = true end
function methods:Hide() self.visible = false end
function methods:IsShown() return true end
function methods:IsVisible() return true end
function methods:GetStringHeight() return 14 end
CreateFrame = function(kind, name, parent)
    local frame = setmetatable({ kind = kind, parent = parent }, methods)
    frames[#frames + 1] = frame
    if name == "DevitoolsReminderFrame" then reminder = frame end
    return frame
end
UIParent, ChatFontNormal, GameTooltip = {}, {}, setmetatable({}, methods)
UnitClass = function() return currentClass, currentClass end
UnitIsDeadOrGhost = function() return false end
InCombatLockdown = function() return false end
GetTime = function() return 0 end
GetShapeshiftForm = function() return formID and 1 or 0 end
GetShapeshiftFormInfo = function() return nil, true, true, formID end
local names = {
    [13163] = "Monkey", [13165] = "Hawk", [1299346] = "Trueshot Aura",
    [465] = "Devotion Aura", [19746] = "Concentration Aura", [19740] = "Might", [25780] = "Righteous Fury",
    [324] = "Lightning Shield", [408510] = "Water Shield", [24858] = "Moonkin Form", [768] = "Cat Form",
    [2457] = "Battle Stance", [71] = "Defensive Stance", [6673] = "Battle Shout",
}
C_Spell = { GetSpellName = function(id) return names[id] or ("Spell " .. id) end }
C_SpellBook = { IsSpellKnown = function(id) return knownSpells[id] == true end }
C_UnitAuras = { GetAuraDataByIndex = function(_, index)
    if index == 1 then return aura end
end }
local function start(class, learned)
    frames, events, labels, currentClass, knownSpells, aura, formID = {}, {}, {}, class, learned, nil, nil
    DevitoolsDB, DevitoolsCharacterDB = {}, {}
    local ns = { Settings = { RegisterPage = function() return CreateFrame("Frame") end } }
    assert(loadfile("Data/SpellData.lua"))("Devitools", ns)
    assert(loadfile("Modules/BuffReminder.lua"))("Devitools", ns)
    events.ADDON_LOADED.OnEvent(events.ADDON_LOADED, "ADDON_LOADED", "Devitools")
    for _, frame in ipairs(frames) do
        if frame.kind == "Frame" and rawget(frame, "parent") and frame.parent.kind == "ScrollFrame" and rawget(frame, "OnShow") then
            frame.OnShow(frame)
        end
    end
    return ns
end
local function update()
    events.UNIT_AURA.OnEvent(events.UNIT_AURA, "UNIT_AURA", "player")
end
start("HUNTER", { [13163] = true, [13165] = true })
assert(reminder.visible, "a hunter without an aspect should be reminded")
labels.Hawk.checked = false
labels.Hawk.OnClick(labels.Hawk)
aura = { name = "Hawk", spellId = 13165, expirationTime = 0 }
update()
assert(not reminder.visible, "any active aspect must satisfy the family")
start("HUNTER", { [1299346] = true })
assert(reminder.visible and reminder.rows[1].text:find("Trueshot Aura", 1, true), "a learned Trueshot Aura must be reminded")
start("SHAMAN", { [324] = true, [408510] = true })
aura = { name = "Water Shield", spellId = 408510, expirationTime = 1000 }
update()
assert(not reminder.visible, "Water Shield must satisfy the Lightning Shield family")
start("PALADIN", { [465] = true, [19746] = true, [25780] = true })
aura = { name = "Concentration Aura", spellId = 19746, expirationTime = 0 }
update()
assert(not reminder.visible, "Concentration Aura must satisfy the aura family, not create a blessing reminder")
assert(not labels["Righteous Fury"].checked, "Righteous Fury must default off")
labels["Righteous Fury"].checked = true
labels["Righteous Fury"].OnClick(labels["Righteous Fury"])
assert(reminder.visible and reminder.rows[1].text:find("Righteous Fury", 1, true), "enabled Righteous Fury must be reminded")
start("DRUID", { [24858] = true, [768] = true })
assert(not labels["Moonkin Form"].checked and not reminder.visible, "form reminders must default off")
labels["Moonkin Form"].checked = true
labels["Moonkin Form"].OnClick(labels["Moonkin Form"])
formID = 768
update()
assert(reminder.visible, "an unselected form must not satisfy the preferred form")
formID = 24858
update()
assert(not reminder.visible, "the shapeshift API must recognize the selected form")
start("DRUID", { [5487] = true, [9634] = true })
labels["Spell 5487"].checked = true
labels["Spell 5487"].OnClick(labels["Spell 5487"])
formID = 9634
update()
assert(not reminder.visible, "Dire Bear Form must satisfy an enabled Bear Form preference")
start("WARRIOR", { [2457] = true, [71] = true })
assert(not labels["Battle Stance"].checked and not reminder.visible, "stance reminders must default off")
labels["Battle Stance"].checked = true
labels["Battle Stance"].OnClick(labels["Battle Stance"])
formID = 71
update()
assert(reminder.visible, "an unselected stance must not satisfy the reminder")
labels["Defensive Stance"].checked = true
labels["Defensive Stance"].OnClick(labels["Defensive Stance"])
update()
assert(not reminder.visible, "any selected active stance must satisfy the reminder")
print("Class buff family tests passed")
