-- Run with a Lua 5.1-compatible interpreter from the project root.
local equipment = { [16] = 10, [17] = 11 }
local items = { [10] = "INVTYPE_WEAPON", [11] = "INVTYPE_WEAPONOFFHAND", [12] = "INVTYPE_SHIELD", [13] = "INVTYPE_2HWEAPON" }
local coats = { [0] = {}, [1] = {} }
local class = "ROGUE"
UnitClass = function() return class, class end
GetInventoryItemID = function(_, slot) return equipment[slot] end
C_Item = {
    GetItemInfoInstant = function(id) return id, nil, nil, items[id], nil, id == 12 and 4 or 2 end,
    GetWeaponEnchantInfo = function(slot) return coats[slot] end,
}
local ns = {}
assert(loadfile("Modules/WeaponEnchants.lua"))("Devitools", ns)
local settings = { weaponMainHand = true, weaponOffHand = true }
local function reminders()
    local result = {}
    ns.WeaponEnchants.AppendReminders(settings, 300, result)
    return result
end
local r = reminders()
assert(#r == 2 and r[1]:find("Main%-hand coating %(missing%)") and r[2]:find("Off%-hand coating %(missing%)"))
assert(r[1]:find("|cffff3333", 1, true), "missing coatings must be red")
coats[0] = { { hasEnchant = true, enchantType = 2, timeLeft = 299000 } }
coats[1] = { { hasEnchant = true, enchantType = 2, timeLeft = 301000 } }
r = reminders()
assert(#r == 1 and r[1]:find("Main%-hand coating %(expiring%)") and r[1]:find("|cffffff00", 1, true))
coats[0] = { { hasEnchant = true, enchantType = 1, timeLeft = 600000 }, { hasEnchant = true, enchantType = 3, timeLeft = 600000 } }
r = reminders()
assert(#r == 1 and r[1]:find("%(missing%)"), "permanent enchants and imbues must not count as coatings")
coats[0] = { { hasEnchant = true, enchantType = 3, timeLeft = 600000 }, { hasEnchant = true, enchantType = 2, timeLeft = 600000 } }
assert(#reminders() == 0, "a temporary coating can coexist with an imbue")
equipment[17] = 12
coats[0] = {}
settings.weaponMainHand = false
assert(#reminders() == 0, "shields and disabled slots must not produce reminders")
equipment[16], equipment[17] = 13, nil
settings.weaponMainHand = true
assert(#reminders() == 1, "two-handed weapons should be checked only in the main hand")
coats[0] = nil
assert(#reminders() == 0, "an unavailable API result must not report a missing coating")
coats[0] = { { hasEnchant = true, enchantType = 2 } }
assert(#reminders() == 0, "an unreadable duration must not be reported as missing or expiring")
equipment[16], equipment[17] = 10, 11
settings.weaponOffHand, settings.weaponImbueMainHand, settings.weaponImbueOffHand = false, true, true
coats[0], coats[1] = { { hasEnchant = true, enchantType = 2, timeLeft = 600000 } }, {}
r = reminders()
assert(#r == 2 and r[1]:find("Main%-hand poison %(missing%)") and r[2]:find("Off%-hand poison %(missing%)"), "coatings must not satisfy poison reminders")
coats[0] = { { hasEnchant = true, enchantType = 2, timeLeft = 600000 }, { hasEnchant = true, enchantType = 3, timeLeft = 299000 } }
r = reminders()
assert(#r == 2 and r[1]:find("Main%-hand poison %(expiring%)"), "coexisting poison must have its own expiration")
class, equipment[17], settings.weaponImbueOffHand = "WARLOCK", nil, false
coats[0] = { { hasEnchant = true, enchantType = 2, timeLeft = 600000 } }
r = reminders()
assert(#r == 1 and r[1]:find("Firestone/Spellstone %(missing%)"), "oil must not satisfy the warlock stone reminder")
coats[0][2] = { hasEnchant = true, enchantType = 3, timeLeft = 600000 }
assert(#reminders() == 0, "a stone imbue and oil must each satisfy their own reminder")
class = "SHAMAN"
coats[0] = {}
settings.weaponMainHand = false
r = reminders()
assert(#r == 1 and r[1]:find("weapon imbue %(missing%)"), "shaman weapon imbues should be supported")
io.write("WeaponEnchants tests passed\n")
