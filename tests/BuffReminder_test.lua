-- Run with a Lua 5.1-compatible interpreter from the project root.
local frames, events = {}, {}
local methods = {}
methods.__index = function(_, key)
    return methods[key] or function() end
end
function methods:SetScript(event, fn) self[event] = fn end
function methods:HookScript(event, fn) self[event] = fn end
function methods:RegisterEvent(event) events[event] = self end
function methods:CreateFontString()
    return setmetatable({ parent = self }, methods)
end
function methods:SetText(text)
    self.text = text
    if self.parent and self.parent.kind == "CheckButton" then self.parent.label = text end
end
function methods:GetText() return self.text or "" end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:IsShown() return true end
function methods:IsVisible() return true end
CreateFrame = function(kind, _, parent)
    local frame = setmetatable({ kind = kind, parent = parent }, methods)
    frames[#frames + 1] = frame
    return frame
end
UIParent, ChatFontNormal = {}, {}
UnitClass = function() return "Warlock", "WARLOCK" end
UnitIsDeadOrGhost = function() return false end
InCombatLockdown = function() return false end
C_UnitAuras = { GetAuraDataByIndex = function() end }
C_Spell = { GetSpellName = function(id)
    return ({ [132] = "Detect Invisibility", [5697] = "Unending Breath", [706] = "Demon Armor", [19028] = "Soul Link" })[id]
end }
local ns = { Settings = { RegisterPage = function() return CreateFrame("Frame") end } }
assert(loadfile("Data/SpellData.lua"))("Devitools", ns)
assert(loadfile("Modules/BuffReminder.lua"))("Devitools", ns)
DevitoolsDB = { buffs = { [132] = true } }
DevitoolsCharacterDB = {}
events.ADDON_LOADED.OnEvent(events.ADDON_LOADED, "ADDON_LOADED", "Devitools")
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
io.write("BuffReminder tests passed\n")
