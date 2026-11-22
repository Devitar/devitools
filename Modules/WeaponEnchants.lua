local _, ns = ...

local hands = {
    { slot = 16, weaponSlot = 0, key = "weaponMainHand", imbueKey = "weaponImbueMainHand", label = "Main-hand" },
    { slot = 17, weaponSlot = 1, key = "weaponOffHand", imbueKey = "weaponImbueOffHand", label = "Off-hand" },
}
local imbueLabels = { ROGUE = "poison", WARLOCK = "Firestone/Spellstone", SHAMAN = "weapon imbue" }
local weaponLocations = {
    INVTYPE_WEAPON = true,
    INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_2HWEAPON = true,
}

local function readable(value)
    return not issecretvalue or not issecretvalue(value)
end

local function hasWeapon(slot)
    local item = GetInventoryItemID("player", slot)
    if not readable(item) or not item then return false end
    local _, _, _, equipLocation, _, classID = C_Item.GetItemInfoInstant(item)
    return readable(equipLocation) and readable(classID) and classID == 2 and weaponLocations[equipLocation] == true
end

local function appendReminders(settings, threshold, reminders)
    if not C_Item or type(C_Item.GetWeaponEnchantInfo) ~= "function"
        or type(C_Item.GetItemInfoInstant) ~= "function" or type(GetInventoryItemID) ~= "function" then
        return
    end
    local _, class = UnitClass("player")
    local imbueLabel = imbueLabels[class]
    for _, hand in ipairs(hands) do
        local checkImbue = imbueLabel and settings[hand.imbueKey] and (class ~= "WARLOCK" or hand.slot == 16)
        if (settings[hand.key] or checkImbue) and hasWeapon(hand.slot) then
            local enchants = C_Item.GetWeaponEnchantInfo(hand.weaponSlot)
            -- An unavailable or restricted result is unknown, not a missing coating.
            if readable(enchants) and type(enchants) == "table" then
                local checks = {
                    { enabled = settings[hand.key], enchantType = 2, label = hand.label .. " coating" },
                    { enabled = checkImbue, enchantType = 3, label = hand.label .. " " .. (imbueLabel or "imbue") },
                }
                for _, check in ipairs(checks) do
                    if check.enabled then
                        local active, remaining, unknown = false, nil, false
                        for _, enchant in ipairs(enchants) do
                            if not readable(enchant) or type(enchant) ~= "table"
                                or not readable(enchant.enchantType) or not readable(enchant.hasEnchant) then
                                unknown = true
                            elseif enchant.enchantType == check.enchantType and enchant.hasEnchant then
                                active = true
                                if readable(enchant.timeLeft) and type(enchant.timeLeft) == "number" and enchant.timeLeft > 0 then
                                    local seconds = enchant.timeLeft / 1000
                                    if not remaining or seconds > remaining then
                                        remaining = seconds
                                    end
                                else
                                    unknown = true
                                end
                            end
                        end
                        if not unknown and (not active or remaining and remaining <= threshold) then
                            local color = active and "|cffffff00" or "|cffff3333"
                            reminders[#reminders + 1] = color .. check.label .. (active and " (expiring)|r" or " (missing)|r")
                        end
                    end
                end
            end
        end
    end
end

ns.WeaponEnchants = { AppendReminders = appendReminders }
