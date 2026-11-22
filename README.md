# Devitools

Devitools is a suite of quality-of-life tools for World of Warcraft: Forever (interface 16001). Its tools help you keep track of buffs and find nearby services; more can be added over time.

## Installation and settings

Copy the `Devitools` folder into the Forever client's `Interface/AddOns` directory, restart the game or reload the UI, and enable Devitools in the addon list.

Type `/dvt` or open **Game Menu > Options > AddOns > Devitools** to access settings. Expand Devitools in the sidebar to find each tool's settings page and enable switch. Disabling Where is hides its buttons and route; an existing map pin is kept.

## Buff Reminder

Buff Reminder shows a movable list of supported self buffs that are missing or have five minutes or less remaining by default. It also tracks Well Fed and the Cozy Sleeping Bag's Well-Rested buff; both reminders are enabled by default. Only class spells your character knows are suggested. The list hides when everything is covered, while dead, and during combat; it updates again after combat.

In settings, you can toggle each supported class spell, Well Fed, and Well-Rested, enable or disable Buff Reminder, set the expiration warning time, lock the reminder window, or reset its position. Situational utility buffs such as Detect Invisibility and Unending Breath appear separately and default off; previously saved choices are kept. Drag the reminder window to move it while unlocked. Settings are shared across your characters; spell switches are saved separately for each spell. Demon Skin is an exception: its choice is saved per character and turns off when that warlock first learns Demon Armor; you can turn it back on manually.

Related alternatives, such as mage armors and paladin blessings, share a reminder: any listed active alternative satisfies the group, and the reminder appears if at least one learned alternative is enabled. This avoids asking for mutually exclusive buffs at the same time.

Well-Rested tracks the sleeping bag XP aura when present, missing, or nearing expiration; any number of stacks counts as active. The reminder works even if someone else provides the sleeping bag.

The initial spell list covers common self buffs for druids, mages, priests, warlocks, warriors, paladins, and shamans. This is a starting list, not a complete catalog of every buff, and Forever-specific spell or aura changes may require adjustments after in-game testing. Reminders are informational and do not cast spells or check for food in your bags. See [BUFF_COVERAGE.md](BUFF_COVERAGE.md) for the class-by-class inventory, sources, and outstanding verification.

## Where is...

Click the **Where is...** button to find an innkeeper, flight master, repair vendor, banker, auctioneer, stable master, reagent vendor, your class trainer, or a trainer for a selected profession. The tool searches recorded NPC locations accessible to your faction, prioritizes the current zone, and places a map pin. If none are known in the current zone, it announces the closest known location on the same continent in chat and pins it. Hover over a Devitools-placed map pin to see the NPC name, service, and zone. The tool identifies Classic-derived locations that have not been verified in Forever. Use **Clear pin** beneath it to remove the current user map pin. Right-drag the button to move it; its position is saved per character. Searches work outside combat and replace your current user waypoint.

Where is also draws a walking route on the minimap and world map using bundled collision maps and Polestar's walking router. The pin and route clear automatically when you reach within three yards of the recorded destination, or you can clear them manually. Arrival is checked outside combat. Routes recalculate when you stray and pause during combat. The maps are based on an older Forever client build, so changed terrain, uncertain floor heights and incomplete map coverage can still cause incorrect routes. If a route cannot be found, the map pin remains available. No other navigation addon is required.
The bundled data is an incomplete snapshot, not a live listing of every NPC. Some NPCs or zones may be absent, faction access and locations can change, and NPC names are currently in English. Trainer skill levels and reagent stock are not checked, so a nearby result may not teach the rank or sell the item you need. Distances are straight-line distances, not travel routes; different continents cannot be compared. A missing player position or an unsupported map pin is reported in chat. See [Data/NPC_SOURCES.md](Data/NPC_SOURCES.md) for the data sources and licenses.

## Development

To create a CurseForge-ready archive on Windows, run from the project root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\Build.ps1
```

The script writes `build/Devitools-<version>.zip`, using the version from `Devitools.toc`. The ZIP contains the addon files at its root; for manual installation, extract them into a folder named `Devitools` inside `Interface/AddOns`. It includes files referenced by the TOC and its XML, along with the applicable license and attribution notices. Use `-OutputPath <path>` to choose a different archive location. Publish the matching source for each release as required by the included licenses.

The addon loads `Devitools.lua` (core), `Data/SpellData.lua` (spell IDs and families), `Modules/BuffReminder.lua` (the reminder tool and its settings), `Data/ServiceNPCs.lua` (locator data), and `Modules/WhereIs.lua` (the locator tool) in the order listed in the TOC. WoW passes a shared addon namespace to each file.

For linting, run `selene .` from the project directory. `selene.toml` selects `wow.yml`, a Lua 5.1 standard library extended with the WoW APIs and saved variables currently used by Devitools. Add new game globals to `wow.yml` as the addon grows; this keeps warnings for genuinely unknown names enabled. The lint configuration excludes bundled third-party files and test mocks.

Run the locator checks with a Lua 5.1-compatible interpreter: `lua tests/WhereIs_test.lua`.

Walking-route checks: `lua tests/WalkingRoute_test.lua`. The real-map smoke test `node tests/PolestarRoute_test.js` requires the `fengari` Node package; set `FENGARI_PATH` to its installation if needed. The bundled router's source, map provenance, and license are documented in `Vendor/PolestarNav/README.md`.

Devitools is distributed under GPL-3.0-or-later; see [LICENSE](LICENSE) and the notices accompanying bundled third-party material.
