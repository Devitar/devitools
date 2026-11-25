# Forever buff coverage checklist

Class spell inventory last reviewed: 2026-11-21. This is a working inventory, not a claim that every persistent buff has been found. IDs identify spells in the client; runtime availability, rank recognition, and aura behavior require separate confirmation. A checked box means it is included in Devitools, not that all its behavior has been tested in game.

## Evidence and method

- [Forever client spell exports](https://github.com/wowsims/gamedata/tree/main/spells) publish class spell cards generated from client tables, including spell effects and raw tooltips. The repository tracks builds and hotfixes; check its `state.json` for the specific snapshot before treating any later review as current.
- [Forever 1.60.1.69876 spell and talent extract](https://github.com/MAF2414/wow-forever-talents) provides a separately audited beta snapshot. Records alone do not prove a spell is currently learnable.
- [Forever group-buff families](https://github.com/EllesmereGaming/EllesmereUI/blob/main/EllesmereUI_BuffPresets.lua) and [client-data spell observations](https://github.com/gunba/wow-forever-sim/blob/forever/docs/weekly_review.md) provide cross-checks, not in-game verification by this project.
- Check the learned spell separately from the aura applied to the player. Record ranks, shared auras, form/stance APIs, target or pet requirements, duration, and exclusivity before implementing. For each available test character: confirm unlearned, learned/missing, active, expiring, toggle off, reload, and alternatives where applicable.

## Current coverage and candidates

| Class | Spell or family (base cast IDs) | Status and outstanding checks |
| --- | --- | --- |
| Druid | Mark/Gift of the Wild (1126, 21849); Thorns (467); Omen of Clarity (16864) | [x] Included. Verify all learned ranks and group-version auras. |
| Druid | Bear (5487), Dire Bear (9634), Cat (768), Aquatic (1066), Travel (783), Moonkin (24858) | [x] Optional preferred forms, off by default; any selected active form satisfies the reminder. Verify each form and the shapeshift API in game. |
| Hunter | Aspects: Monkey (13163), Hawk (13165), Cheetah (5118), Beast (13161), Pack (13159), Wild (20043) | [x] Included as alternatives. Verify all ranks and active aura behavior in game. |
| Hunter | Trueshot Aura (1299346) | [x] Included; Forever's first rank is listed in the [client spellbook extract](https://questing.wiki/wow-forever/spells/hunter/). Verify learned-rank and aura behavior in game. |
| Mage | Arcane Intellect/Brilliance (1459, 23028); armor spells (168, 7302, 6117) | [x] Included. Verify ranks and group auras. |
| Mage | Dampen/Amplify Magic (604, 1008) | [x] Included as alternatives; check exclusivity and rank behavior. Amplify is recorded in the [client ability review](https://github.com/wowsims/forever/issues/31). |
| Paladin | Blessings (19740, 19742, 20217, 1038, 19977) | [x] Included as alternatives. Greater Might/Kings/Wisdom aura IDs are 25782, 25898, 25918; confirm all current Forever blessings, availability, and rank/group handling. Sanctuary (20911) was removed pending evidence it is learnable in Forever. |
| Paladin | Auras (465, 7294, 19746, 19876, 19888, 19891); Righteous Fury (25780) | [x] Auras share one reminder; Righteous Fury is optional and off by default. Verify ranks and aura detection in game. Seals are intentionally not tracked. |
| Priest | Fortitude/Prayer (1243, 21562); Spirit/Prayer (14752, 27681); Shadow Protection/Prayer (976, 27683); Inner Fire (588) | [x] Included. Verify ranks, group-version aura names, and spell availability. |
| Priest | Shadowform (15473) | [x] Included. Client spell ID is [documented here](https://github.com/gunba/wow-forever-sim/blob/forever/docs/weekly_review.md); verify player aura and whether reminders are wanted while intentionally out of form. |
| Rogue | Poisons and stealth | [x] Optional per-hand poison reminders use the weapon imbue category; verify the category and expiration in game. Stealth remains untracked because it is situational. |
| Shaman | Lightning Shield (324) and Water Shield (408510) | [x] Included as mutually exclusive alternatives. Verify talent availability, ranks and aura detection in game. |
| Shaman | Weapon imbues | [x] Optional per-hand weapon imbue reminders use the weapon imbue category; verify in game. |
| Warlock | Demon Skin/Armor (687, 706); Detect Invisibility (132); Unending Breath (5697) | [x] Included. Demon Armor ranks 706, 1086, 11733, 11734, 11735 share a name; verify aura identity and other spell ranks. |
| Warlock | Soul Link (cast 19028; player aura 25228) | [x] Included. Verify aura and pet-dependent behavior in game. [Reported historical spell/aura distinction](https://www.getmangos.eu/forums/topic/1270-playerbot-archive/page/51/) is not Forever runtime proof. |
| Warlock | Demonic Sacrifice (cast 18788; auras 18789–18792) | [x] Included as one toggle; any of the four auras satisfies it. [Forever client-data observations](https://github.com/squirtwow/ForeverEnhancedCooldownManager/blob/main/Spells.lua) identify the four aura IDs. Confirm each aura and expiration in game. |
| Warlock | Firestone / Spellstone | [x] Optional main-hand imbue reminder. Blizzard says both stones apply weapon imbues alongside oils; verify the reported enchant type and expiration in game. |
| Warrior | Battle Shout (6673) | [x] Included. Verify ranks and whether a five-minute warning is appropriate for a short-duration shout. |
| Warrior | Battle (2457), Defensive (71), Berserker (2458) stances | [x] Optional preferred stances, off by default; any selected active stance satisfies the reminder. Verify the shapeshift API in game. |
| Warrior | Other shouts | [ ] Commanding Shout (403215) appears in the client but has no confirmed Forever source; see the [client-data review](https://foreverdb.net/es/spell/403215). Demoralizing and Challenging Shout affect enemies and are not persistent self buffs. |
| All | Well Fed (19705 and other same-named auras) | [x] Included, off by default. Verify different food effects and localization; food effects with different names may be missed. |
| All | Cozy Sleeping Bag Well-Rested (aura 429959) | [x] Included, off by default. The user confirmed the active aura ID in game; expiration behavior still needs separate verification. |
| All | Sharpening stones, weightstones and oils | [x] Optional per-hand temporary coating reminders, independent of class imbues; verify in game. |

### Demonic Sacrifice effects

Forever's [client spell data](https://bindonforever.com/spell/18788) describes a two-hour effect with these alternatives:

| Sacrificed demon | Effect |
| --- | --- |
| Imp | 15% increased Shadow damage |
| Voidwalker | Restores 2% of total mana every four seconds |
| Succubus or Incubus | 15% increased Fire damage |
| Felhunter | Restores 3% of total health every four seconds |

The addon recognizes aura IDs 18789, 18790, 18791, and 18792 as alternatives for the castable spell 18788. Their individual in-game behavior and expiration still need verification. The client tooltip says summoning a demon normally cancels the effect, although talents can change that interaction.

## Known implementation gaps

- Learned-spell detection indexes known player spellbook entries by localized name, so higher ranks with the same name as the configured spell can be recognized without a fixed rank list. Verify this in game for each family; ranks with different names or spells omitted from the visible player spellbook may require explicit mappings. Same-named unrelated spells may also need disambiguation.
- The addon compares localized aura names. Different aura names for a group spell, different IDs with the same name, and secret aura data can affect results. Reminder scanning is paused in combat; other restricted situations still need testing.
- Most individual buff settings are shared across characters; the tool's enabled state, manually tracked buffs, and the Demon Skin preference are per character. Different characters may want different choices for other reminders.
- This checklist does not establish exhaustiveness or imply that combat cooldowns, temporary effects, pet buffs, weapon enchants, and stances all belong in a persistent self-buff reminder.
