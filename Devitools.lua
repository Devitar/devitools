local _, ns = ...

-- WoW loads the modules listed after this file in Devitools.toc into this
-- shared addon namespace before dispatching login events.
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self)
    print("|cff66ccffDevitools:|r Type |cffffff00/dvt|r to open settings.")
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end)

SLASH_DEVITOOLS1 = "/dvt"
SlashCmdList.DEVITOOLS = function()
    if ns.Settings then
        ns.Settings.Open()
    end
end
