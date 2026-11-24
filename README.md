# Devitools

Devitools is a suite of quality-of-life tools for World of Warcraft: Forever (interface 16001). Its tools help you track buffs, find nearby services, and make space in your bags.

## Installation and settings

Copy the `Devitools` folder into the Forever client's `Interface/AddOns` directory, restart the game or reload the UI, and enable Devitools in the addon list.

Type `/dvt` or open **Game Menu > Options > AddOns > Devitools** to access settings. Expand Devitools in the sidebar to find each tool's settings page and enable switch. Disabling Where is hides its buttons and route; an existing map pin is kept.

## Buff Reminder

Buff Reminder shows a movable list of supported self buffs that are missing or have five minutes or less remaining by default. It can also track Well Fed and the Cozy Sleeping Bag's Well-Rested buff; both reminders are off by default. Only class spells your character knows are suggested. The list hides when everything is covered, while dead, and during combat; it updates again after combat.

In settings, you can toggle each supported class spell, Well Fed, and Well-Rested, enable or disable Buff Reminder, set the expiration warning time, lock the reminder window, or reset its position. Situational utility buffs such as Detect Invisibility and Unending Breath appear separately and default off; previously saved choices are kept. Right-drag the reminder window to move it while unlocked, or click its cogwheel to open Buff Reminder settings. Most settings are shared across your characters; manually tracked buffs and the Demon Skin preference are per character. Demon Skin turns off when that warlock first learns Demon Armor; you can turn it back on manually.

Optional main-hand and off-hand coating reminders track temporary weapon coatings such as sharpening stones, weightstones, and oils. Rogues can separately track poisons, warlocks can track Firestone or Spellstone on their main hand, and shamans can track weapon imbues. These reminders are off by default and use the same expiration warning time as buffs. Any active effect of the selected kind satisfies its reminder; it does not select a particular poison, stone, or imbue. Coatings and class imbues are checked independently, and permanent weapon enchants do not satisfy either reminder.

Related alternatives, such as mage armors and paladin blessings, share a reminder: any listed active alternative satisfies the group, and the reminder appears if at least one learned alternative is enabled. This avoids asking for mutually exclusive buffs at the same time.

To track an elixir or another active player buff, open the Buff Reminder settings, scroll to **Manually tracked buffs**, and choose **Track active buff**. Buffs already covered by another reminder are excluded from the picker. Each selected buff can be toggled or removed there. Manually tracked entries match the buff's displayed name, use the same expiration threshold, and are saved separately for each character; select only effects you want to maintain.

Well-Rested tracks the sleeping bag XP aura when present, missing, or nearing expiration; any number of stacks counts as active. The reminder works even if someone else provides the sleeping bag.

The initial spell list covers common self buffs for druids, mages, priests, warlocks, warriors, paladins, and shamans. This is a starting list, not a complete catalog of every buff, and Forever-specific spell or aura changes may require adjustments after in-game testing. Reminders are informational and do not cast spells or check for food in your bags. See [BUFF_COVERAGE.md](BUFF_COVERAGE.md) for the class-by-class inventory, sources, and outstanding verification.

## Bag Cleaner

Use **Make space** above an open bag window to find low vendor-value items when you need bag space. Enter the number of slots to free and click **Find**, then hover over the scrollable results for their tooltips. The limit reflects total equipped bag capacity, including slots that are already empty. Items are ranked by their total vendor value, including their quantity. Locked and quest items, Hearthstones, Soul Shards, ammunition, and conjured items are excluded. Add or remove exact item names in Bag Cleaner settings to protect more items on that character; names are matched without regard to capitalization. Conjured status is read from the localized item tooltip; if an item's details cannot be read, it is omitted until a later search. Vendor price does not reflect auction value or personal usefulness, so review the results carefully.

Click the cogwheel in the Bag Cleaner window to open its settings. There you can set the default number of slots to free and optionally show only poor-quality items or exclude items with no vendor value. Both filters are off by default and shared across characters; the custom exclusion list is per character.

Right-click a suggested item to **Ignore Suggestion** for the current results or **Add to Exclude List** for that character. The next eligible item replaces it when one is available. Ignored suggestions can return when you search again; excluded item names remain protected until removed in settings.

Click an item to confirm its deletion, or choose **Delete all results...** to review and confirm each item in the same movable window. Deleting an item removes the full quantity in its bag slot; the confirmation warns when that quantity is greater than one. The queue includes all results, including those further down the scrollable list, and can be cancelled at any time. The game may ask for additional confirmation for certain items. The cleaner checks each slot again before deleting and stops if its contents change. Deletion is unavailable during combat, and the cursor must be empty. The Bag Cleaner settings page can hide its button.

## Where is...

Click the **Where is...** button to find an innkeeper, flight master, repair vendor, banker, auctioneer, stable master, reagent vendor, your class trainer, or a trainer for a selected profession. The tool searches recorded NPC locations accessible to your faction, prioritizes the current zone, and places a map pin. By default, if none are known in the current zone, it announces the closest known location on the same continent in chat and pins it. Hover over a Devitools-placed map pin to see the NPC name, service, and zone. The tool identifies Classic-derived locations that have not been verified in Forever. Use **Clear pin** beneath it to remove the current user map pin. Right-drag the button to move it; its position is saved per character. Searches work outside combat and replace your current user waypoint.

Where is also draws a walking route on the minimap and world map using bundled collision maps and Polestar's walking router. By default, the pin and route clear automatically when you reach within three yards of the recorded destination, or you can clear them manually. In the tool's settings, choose which map routes and services to show, control arrival clearing and its distance, lock or reset the button, restrict searches to the current zone, exclude Classic-derived locations, show location sources in the tooltip, and hide routine chat messages. Important warnings remain visible. Arrival is checked outside combat. Routes recalculate when you stray and pause during combat. The maps are based on an older Forever client build, so changed terrain, uncertain floor heights and incomplete map coverage can still cause incorrect routes. If a route cannot be found, the map pin remains available. No other navigation addon is required.
The bundled data is an incomplete snapshot, not a live listing of every NPC. Some NPCs or zones may be absent, faction access and locations can change, and NPC names are currently in English. Trainer skill levels and reagent stock are not checked, so a nearby result may not teach the rank or sell the item you need. Distances are straight-line distances, not travel routes; different continents cannot be compared. A missing player position or an unsupported map pin is reported in chat. See [Data/NPC_SOURCES.md](Data/NPC_SOURCES.md) for the data sources and licenses.

## Development

To install a separate local development copy alongside the CurseForge release, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\Install-Dev.ps1
```

The script installs `Devitools-Dev` in the Forever AddOns folder. It has its own settings and character data, appears as **Devitools (Dev)**, and uses `/dvtdev`. Run the script again after changing the source. The release and development copies can both be installed; if both are enabled, their on-screen controls and reminders can appear twice, and they share the game's map waypoint. Disable the copy you are not actively using to avoid that. Use `-AddOnsPath <path>` to choose another AddOns directory.

To create a CurseForge-ready archive on Windows, run from the project root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\Build.ps1
```

The script writes `build/Devitools-<version>.zip`, using the version from `Devitools.toc`, not a Git tag. Running it again for the same version overwrites that ZIP. The ZIP contains a single `Devitools` folder; for manual installation, extract it directly into `Interface/AddOns` so that `Devitools.toc` is inside `Interface/AddOns/Devitools`. It includes files referenced by the TOC and its XML, along with the applicable license and attribution notices. Use `-OutputPath <path>` to choose a different archive location. Publish the matching source for each release as required by the included licenses.

### Publishing a release

The commands below use `0.2.0` and `v0.2.0` as examples; replace them with the intended version and tag. They assume the release commit is on `main` and the remote is named `origin`.

1. Update `## Version:` in `Devitools.toc` to the release version. Run `selene .`, the relevant tests, and in-game checks, then prepare release notes describing the changes.
2. Review and commit the intended source changes, including the version update. Make sure every addon file used in the build is tracked so the tag contains the matching source. For example:

   ```powershell
   git status --short
   git add -A
   git diff --cached
   git commit -m "Release v0.2.0"
   git status --short
   ```

   Review the staged changes before committing; `git add -A` stages all tracked changes and non-ignored new files. Ensure the working tree has no uncommitted release changes before building.
3. Build and validate the ZIP from that commit. Substitute the version from the TOC:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\Build.ps1
   powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Build_test.ps1 -ArchivePath .\build\Devitools-0.2.0.zip
   ```

   The validation compares the archive with the current working tree. If you change any packaged file afterward, commit the changes and rebuild before tagging.
4. Create an annotated tag for the release commit, then push the branch and tag:

   ```powershell
   git tag -a v0.2.0 -m "Devitools v0.2.0"
   git push origin main
   git push origin v0.2.0
   ```

5. On [GitHub Releases](https://github.com/Devitar/devitools/releases), draft a release using the existing `v0.2.0` tag. Add the release notes and attach `build/Devitools-0.2.0.zip`, then publish it. GitHub provides source archives for the tag; keep the tagged repository publicly accessible so users can obtain the exact matching source and included license notices.
6. In the CurseForge author dashboard, open the project, choose **Files > Upload file**, and upload the same `build/Devitools-0.2.0.zip`. Select the appropriate release type and Forever game version, add the changelog, and submit it for review. The addon ZIP, not GitHub's automatically generated source archive, is the file to upload to CurseForge.

If a release must be corrected after tagging or publishing, create a new version and tag rather than changing an existing public tag. Keep the source for each distributed release available as required by its licenses.

The addon loads its core, data, tools, and bundled routing code in the order listed in `Devitools.toc`. `Modules/BuffReminder.lua`, `Modules/WhereIs.lua`, and `Modules/BagCleaner.lua` implement the main tools; `Data/SpellData.lua` and `Data/ServiceNPCs.lua` contain their spell and NPC data. WoW passes a shared addon namespace to each file.

For linting, run `selene .` from the project directory. `selene.toml` selects `wow.yml`, a Lua 5.1 standard library extended with the WoW APIs and saved variables currently used by Devitools. Add new game globals to `wow.yml` as the addon grows; this keeps warnings for genuinely unknown names enabled. The lint configuration excludes bundled third-party files, test mocks, editor type definitions, and generated build output.

Run the Bag Cleaner and locator checks with a Lua 5.1-compatible interpreter: `lua tests/BagCleaner_test.lua` and `lua tests/WhereIs_test.lua`. Additional focused tests are in `tests/`.

Walking-route checks: `lua tests/WalkingRoute_test.lua`. The real-map smoke test `node tests/PolestarRoute_test.js` requires the `fengari` Node package; set `FENGARI_PATH` to its installation if needed. The bundled router's source, map provenance, and license are documented in `Vendor/PolestarNav/README.md`.

Devitools is distributed under GPL-3.0-or-later; see [LICENSE](LICENSE) and the notices accompanying bundled third-party material.
