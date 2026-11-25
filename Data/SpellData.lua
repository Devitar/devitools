local _, ns = ...

ns.SpellData = { wellFed = 19705, wellRested = 429959 }

-- Each class contains a list of buff families. The spells array lists castable
-- spell IDs that share one reminder, such as mutually exclusive Demon Skin and
-- Demon Armor. A single-spell family still uses a spells array so the reminder
-- can process every family the same way.
--
-- The first enabled, known spell supplies the reminder's name; an active aura
-- from any spell in the family satisfies it, even if that spell is disabled.
-- Optional auraIDs list additional aura spell IDs that satisfy the family but
-- are not castable choices, such as Soul Link's separate player aura. They do
-- not create settings toggles. Ranks with the same localized name are matched
-- through the player's spellbook rather than listed as separate choices.
-- Situational utility families have utility = true; their reminders default
-- off, while an explicitly saved choice always takes precedence.
-- Form families are opt-in: any selected active form satisfies the reminder.
ns.SpellData.classBuffs = {
    DRUID = {
        { spells = { 1126, 21849 } }, -- Mark / Gift of the Wild
        { spells = { 16864 } }, -- Omen of Clarity
        { spells = { 467 } }, -- Thorns
        { spells = { 5487, 9634, 768, 1066, 783, 24858 }, utility = true, form = true }, -- Druid forms
    },
    HUNTER = {
        { spells = { 13163, 13165, 5118, 13161, 13159, 20043 } }, -- Mutually exclusive aspects
        { spells = { 1299346 } }, -- Trueshot Aura, first Forever rank
    },
    MAGE = {
        { spells = { 1459, 23028 } }, -- Arcane Intellect / Brilliance
        { spells = { 168, 7302, 6117 } }, -- armor spells
        { spells = { 604, 1008 } }, -- Dampen / Amplify Magic
    },
    PRIEST = {
        { spells = { 1243, 21562 } }, -- Fortitude / Prayer of Fortitude
        { spells = { 14752, 27681 } }, -- Divine Spirit / Prayer of Spirit
        { spells = { 976, 27683 } }, -- Shadow Protection
        { spells = { 588 } }, -- Inner Fire
        { spells = { 15473 } }, -- Shadowform
    },
    WARLOCK = {
        { spells = { 687, 706 } }, -- Demon Skin / Demon Armor
        { spells = { 132 }, utility = true }, -- Detect Invisibility
        { spells = { 5697 }, utility = true }, -- Unending Breath
        { spells = { 19028 }, auraIDs = { 25228 } }, -- Soul Link: learned spell and player aura
        { spells = { 18788 }, auraIDs = { 18789, 18790, 18791, 18792 } }, -- Demonic Sacrifice: one aura per demon
    },
    WARRIOR = {
        { spells = { 6673 } }, -- Battle Shout
        { spells = { 2457, 71, 2458 }, utility = true, form = true }, -- Stances
    },
    PALADIN = {
        { spells = { 19740, 19742, 20217, 1038, 19977 }, auraIDs = { 25782, 25898, 25918 } }, -- Blessings
        { spells = { 465, 7294, 19746, 19876, 19888, 19891 } }, -- Auras
        { spells = { 25780 }, utility = true }, -- Righteous Fury
    },
    SHAMAN = { { spells = { 324, 408510 } } }, -- Mutually exclusive elemental shields
}
