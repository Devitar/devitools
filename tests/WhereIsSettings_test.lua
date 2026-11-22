-- Run with a Lua 5.1-compatible interpreter from the project root.
local frames, events = {}, {}
local methods = {}
methods.__index = function(_, name) return methods[name] or function() end end
function methods:RegisterEvent(event) events[event] = self end
function methods:SetScript(event, fn) self[event] = fn end
function methods:CreateFontString() return setmetatable({ parent = self }, methods) end
function methods:SetText(text)
    self.text = text
    local parent = rawget(self, "parent")
    if parent and parent.kind == "CheckButton" then parent.label = text end
end
function methods:GetText() return rawget(self, "text") or "" end
function methods:HookScript(event, fn) self[event] = fn end
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
assert(loadfile("Modules/WhereIsOptions.lua"))("Devitools", ns)
assert(loadfile("Modules/WhereIs.lua"))("Devitools", ns)
local toggle, button
for _, frame in ipairs(frames) do
    if frame.kind == "CheckButton" and not toggle then toggle = frame end
    if frame.name == "DevitoolsWhereIsButton" then button = frame end
end
-- The settings canvas may already be shown when its OnShow handler is assigned.
DevitoolsDB, DevitoolsCharacterDB = nil, nil
events.ADDON_LOADED.OnEvent(events.ADDON_LOADED, "ADDON_LOADED", "Devitools")
assert(button.visible and toggle.checked == true and DevitoolsDB.whereIsEnabled == true,
    "fresh install must show the enabled tool as checked without relying on OnShow")
local byLabel, distanceInput, applyButton = {}, nil, nil
for _, frame in ipairs(frames) do
    if rawget(frame, "label") then byLabel[frame.label] = frame end
    if frame.kind == "EditBox" then distanceInput = frame end
    if frame.kind == "Button" and rawget(frame, "text") == "Apply" then applyButton = frame end
end
assert(byLabel["Show minimap route"].checked and byLabel["Show world map route"].checked, "both routes should default on")
byLabel["Show minimap route"].checked = false
byLabel["Show minimap route"].OnClick(byLabel["Show minimap route"])
assert(ns.WhereIsOptions.Get("showMinimap") == false and ns.WhereIsOptions.Get("showWorldMap") == true,
    "route visibility settings should be independent")
distanceInput:SetText("12")
applyButton.OnClick(applyButton)
assert(ns.WhereIsOptions.Get("arrivalDistance") == 12, "arrival distance should be saved")
distanceInput:SetText("0")
applyButton.OnClick(applyButton)
assert(ns.WhereIsOptions.Get("arrivalDistance") == 12, "invalid arrival distance must not overwrite the setting")
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
