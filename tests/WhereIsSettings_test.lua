-- Run with a Lua 5.1-compatible interpreter from the project root.
local frames, events = {}, {}
local methods = {}
methods.__index = function(_, name) return methods[name] or function() end end
function methods:RegisterEvent(event) events[event] = self end
function methods:SetScript(event, fn) self[event] = fn end
function methods:CreateFontString() return setmetatable({}, methods) end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:Show() self.visible = true end
function methods:Hide() self.visible = false end
CreateFrame = function(kind, name)
    local result = setmetatable({ kind = kind, name = name }, methods)
    frames[#frames + 1] = result
    return result
end
UIParent, GameTooltip = {}, { HookScript = function() end }
C_Map = { HasUserWaypoint = function() return false end }
local page
local ns = { Settings = { RegisterPage = function() page = CreateFrame("Frame"); return page end }, ServiceNPCs = {} }
assert(loadfile("Modules/WhereIs.lua"))("Devitools", ns)
local toggle, button
for _, frame in ipairs(frames) do
    if frame.kind == "CheckButton" then toggle = frame end
    if frame.name == "DevitoolsWhereIsButton" then button = frame end
end
-- The settings canvas may already be shown when its OnShow handler is assigned.
DevitoolsDB, DevitoolsCharacterDB = nil, nil
events.ADDON_LOADED.OnEvent(events.ADDON_LOADED, "ADDON_LOADED", "Devitools")
assert(button.visible and toggle.checked == true and DevitoolsDB.whereIsEnabled == true,
    "fresh install must show the enabled tool as checked without relying on OnShow")
toggle.checked = false
toggle.OnClick(toggle)
assert(not button.visible and toggle.checked == false and DevitoolsDB.whereIsEnabled == false,
    "the first click must disable the tool")
toggle.checked = true
toggle.OnClick(toggle)
assert(button.visible and toggle.checked == true and DevitoolsDB.whereIsEnabled == true,
    "the next click must re-enable the tool")
DevitoolsDB.whereIsEnabled = false
page.OnShow(page)
assert(toggle.checked == false, "opening the settings page must refresh the saved state")
events.ADDON_LOADED.OnEvent(events.ADDON_LOADED, "ADDON_LOADED", "Devitools")
assert(not button.visible and toggle.checked == false and DevitoolsDB.whereIsEnabled == false,
    "a saved disabled setting must stay disabled on load")
io.write("WhereIsSettings tests passed\n")
