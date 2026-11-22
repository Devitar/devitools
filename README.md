# Devitools

Devitools is a suite of quality-of-life tools for World of Warcraft: Forever (interface 16001). Its first tool, Buff Reminder, helps you keep track of your buffs; more tools can be added to the suite over time.

## Installation and settings

Copy the `Devitools` folder into the Forever client's `Interface/AddOns` directory, restart the game or reload the UI, and enable Devitools in the addon list.

Type `/dvt` or open **Game Menu > Options > AddOns > Devitools** to access settings.

## Buff Reminder

Buff Reminder shows a movable list of supported self buffs that are missing or have five minutes or less remaining by default. It also tracks Well Fed and the Cozy Sleeping Bag's Well-Rested buff; both reminders are enabled by default. Only class spells your character knows are suggested. The list hides when everything is covered, while dead, and during combat; it updates again after combat.

In settings, you can toggle each supported class spell, Well Fed, and Well-Rested, enable or disable Buff Reminder, set the expiration warning time, lock the reminder window, or reset its position. Drag the reminder window to move it while unlocked. Settings are shared across your characters; spell switches are saved separately for each spell. Demon Skin is an exception: its choice is saved per character and turns off when that warlock first learns Demon Armor; you can turn it back on manually.

Related alternatives, such as mage armors and paladin blessings, share a reminder: any listed active alternative satisfies the group, and the reminder appears if at least one learned alternative is enabled. This avoids asking for mutually exclusive buffs at the same time.

Well-Rested tracks the sleeping bag XP aura when present, missing, or nearing expiration; any number of stacks counts as active. The reminder works even if someone else provides the sleeping bag.

The initial spell list covers common self buffs for druids, mages, priests, warlocks, warriors, paladins, and shamans. This is a starting list, not a complete catalog of every buff, and Forever-specific spell or aura changes may require adjustments after in-game testing. Reminders are informational and do not cast spells or check for food in your bags. See [BUFF_COVERAGE.md](BUFF_COVERAGE.md) for the class-by-class inventory, sources, and outstanding verification.

## Development

The addon loads `Devitools.lua` (core), `Data/SpellData.lua` (spell IDs and families), and `Modules/BuffReminder.lua` (the reminder tool and its settings) in the order listed in the TOC. WoW passes a shared addon namespace to each file.

For linting, run `selene .` from the project directory. `selene.toml` selects `wow.yml`, a Lua 5.1 standard library extended with the WoW APIs and saved variables currently used by Devitools. Add new game globals to `wow.yml` as the addon grows; this keeps warnings for genuinely unknown names enabled.
