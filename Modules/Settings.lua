local _, ns = ...

local panel = CreateFrame("Frame")
local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 20, -20)
title:SetText("Devitools")
local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
description:SetText("Choose a tool from the list to configure it.")

local category = Settings.RegisterCanvasLayoutCategory(panel, "Devitools")
Settings.RegisterAddOnCategory(category)

ns.Settings = {}
function ns.Settings.RegisterPage(label)
    local page = CreateFrame("Frame")
    local subcategory = Settings.RegisterCanvasLayoutSubcategory(category, page, label)
    Settings.RegisterAddOnCategory(subcategory)
    return page
end
function ns.Settings.Open()
    Settings.OpenToCategory(category:GetID())
end
