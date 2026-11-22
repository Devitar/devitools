-- Run with a Lua 5.1-compatible interpreter from the project root.
local methods = {}
methods.__index = function(_, key) return methods[key] or function() end end
local labels
function methods:CreateFontString() return setmetatable({}, methods) end
function methods:SetText(text) labels[text] = true end
CreateFrame = function() return setmetatable({}, methods) end
UIParent, ChatFontNormal = {}, {}
C_Spell = { GetSpellName = function() end }
local scenarios = {
    WARLOCK = "Firestone / Spellstone (off by default)",
    ROGUE = "Rogue poisons (off by default)",
    SHAMAN = "Shaman weapon imbues (off by default)",
    WARRIOR = false, MAGE = false, PRIEST = false, DRUID = false,
    PALADIN = false, HUNTER = false,
}
local headings = { "Firestone / Spellstone (off by default)", "Rogue poisons (off by default)", "Shaman weapon imbues (off by default)" }
for class, expected in pairs(scenarios) do
    labels = {}
    UnitClass = function() return class, class end
    local ns = { Settings = { RegisterPage = function() return CreateFrame("Frame") end } }
    assert(loadfile("Data/SpellData.lua"))("Devitools", ns)
    assert(loadfile("Modules/BuffReminder.lua"))("Devitools", ns)
    for _, heading in ipairs(headings) do
        assert(not labels[heading] or heading == expected, class .. " must not see another class's weapon settings")
    end
    if expected then assert(labels[expected], class .. " should see its weapon settings") end
    assert(labels["Temporary weapon coatings (off by default)"], class .. " should still see general coating settings")
end
io.write("ClassWeaponSettings tests passed\n")
