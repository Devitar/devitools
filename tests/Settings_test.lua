local methods = {}
function methods:SetPoint() end
function methods:SetText(text) self.text = text end
function methods:CreateFontString() return setmetatable({}, { __index = methods }) end
CreateFrame = function() return setmetatable({}, { __index = methods }) end
local opened, root, registered, subcategories = nil, nil, {}, {}
Settings = {
    RegisterCanvasLayoutCategory = function(panel, name)
        root = { panel = panel, name = name, GetID = function() return 42 end }
        return root
    end,
    RegisterCanvasLayoutSubcategory = function(parent, page, name)
        local category = { parent = parent, page = page, name = name }
        subcategories[#subcategories + 1] = category
        return category
    end,
    RegisterAddOnCategory = function(category) registered[#registered + 1] = category end,
    OpenToCategory = function(id) opened = id end,
}
local ns = {}
assert(loadfile("Modules/Settings.lua"))("Devitools", ns)
local buffs = ns.Settings.RegisterPage("Buff Reminder")
local finder = ns.Settings.RegisterPage("Where is...")
assert(root.name == "Devitools" and registered[1] == root, "root settings category must be registered")
assert(subcategories[1].parent == root and subcategories[1].page == buffs and subcategories[1].name == "Buff Reminder")
assert(subcategories[2].parent == root and subcategories[2].page == finder and subcategories[2].name == "Where is...")
assert(registered[2] == subcategories[1] and registered[3] == subcategories[2], "tool categories must be registered")
ns.Settings.Open()
assert(opened == 42, "settings should open the registered category")
io.write("Settings tests passed\n")
