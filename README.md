# Vanilla Rating Buster

Displays per-spec gear ratings, equipped upgrade deltas (`+Δ` / `-Δ`), live stat-cap warnings, and set-break warnings directly in item tooltips for Turtle WoW (1.12).

Fork of [ZephZae/VanillaRatingBuster](https://github.com/ZephZae/VanillaRatingBuster) (originally by Kylosandrax), rebuilt to use **BetterCharacterStats** (`BCSItemScan` + `BCS` API) instead of a separate BonusScanner addon.

## Required and Optional Client Mods

| Client Mod | Needed? | Used For |
|---|---|---|
| **ClassicAPI** | Optional | `GameTooltip:GetItem()` and `C_Item.GetItemInfoInstant()` for fast item-type resolution across tooltips; gracefully falls back to stock 1.12 `GetItemInfo` when absent |
| **Nampower** | Optional | `UNIT_INVENTORY_CHANGED_GUID` (player-filtered) for cache invalidation without 40-man raid event floods |

Required companion addon:
- **BetterCharacterStats:** Provides `BCSItemScan` (stat parsing + per-slot equipped cache), `BCS.EnchantStats` (hidden enchants like Facetted Crystal Scope), `BCS:GetStatCapStatus()` (Cap-Aware warnings), and `BCS:RegisterCallback()` (unified cache invalidation).

Optional companion addon:
- **BetterCharacterPanel:** Displays total VRB spec scores in Character/Inspect model hover tooltips, `/bcp inspect`, and `/bcp lastinspect` via `VRB:GetUnitSpecScores(unit)`.

## Features

- **Per-Spec Tooltip Ratings (All 9 Classes):** Shows weighted Effective Power (`EP`) / Effective Health (`EH`) scores for your class specs (omitting `0`-score specs) across bags, equipped gear, bank, merchant, buyback, auction house, loot, loot rolls, quests, tradeskill, craft, mail, chat links (`ItemRefTooltip`), and comparison tooltips (`ShoppingTooltip1`/`2`).
- **Smart Equipped Comparison (`+Δ` / `-Δ`):** Compares hovered items against your currently equipped slot (green upgrades, red downgrades). Handles rings, trinkets, 2H vs MH+OH, class-aware 1H dual-wield (`WARRIOR`/`ROGUE`/`HUNTER` vs caster/Paladin/Druid main-hand), thrown weapons, and optional ignoring of equipped enchants (`/vrb enchant`).
- **Zero-Duplication Baseline Cache:** Reuses `BCSItemScan:GetEquippedSlotStats()` directly from BetterCharacterStats (avoiding duplicate hidden-tooltip scans), synchronized automatically via `BCS:RegisterCallback("GEAR_UPDATED")` / `"ITEMSCAN_UPDATED"`.
- **Cap-Aware Tooltip Warnings (via BCS):** When enabled (`/vrb cap`), checks live level-63 boss caps from `BCS:GetStatCapStatus()` and flags items whose Melee Hit, Ranged Hit, Spell Hit, or Defense is already capped.
- **Set-Break Warnings:** When enabled (`/vrb setwarn`), warns on tooltip comparison if replacing the equipped slot would break an active 2+ piece set bonus.
- **Options UI, Custom Weights & Import/Export (`/vrb`):** Movable GUI (`VRBOptionsFrame`) to toggle features, filter visible specs, edit/reset per-stat weights (`SavedVariables: VanillaRatingBusterDB`), and share weight presets via `/vrb export` and `/vrb import`.

### Supported Classes & Specs

| Class | Specs |
|---|---|
| Druid | `DruidFeralDPS-EP`, `DruidTank-EP`, `DruidThreat-EP`, `DruidResto-EP` |
| Hunter | `HunterMM-EP`, `HunterBM-EP`, `HunterSurv-EP` |
| Mage | `MageArcane-EP`, `MageFire-EP`, `MageFrost-EP` |
| Paladin | `PaladinProtEH`, `PaladinRetDPS`, `PaladinHEP` |
| Priest | `PriestHEP_2M`, `PriestHEP_15M`, `PriestHEP_TIG`, `PriestShadowDPS_2M`, `PriestShadowDPS_9M` |
| Rogue | `RogueDagger-EP`, `RogueCombat-EP`, `RogueSub-EP` |
| Shaman | `ShamanElemental-EP`, `ShamanElementalFire-EP`, `ShamanHEP`, `ShamanEnhance-EP`, `ShamanEnhanceTank-EP` |
| Warlock | `WarlockAffliction-EP`, `WarlockSMRuin-EP`, `WarlockDemo-EP`, `WarlockFire-EP` |
| Warrior | `WarriorThreat-EP`, `WarriorMitigation-EP`, `WarriorFury-EP` |

## Commands

| Command | Description |
|---|---|
| `/vrb` or `/vrb ui` | Opens/closes the options & custom stat-weight editor window |
| `/vrb help` | Prints current settings and command list |
| `/vrb toggle` | Toggles VanillaRatingBuster on/off |
| `/vrb compare` | Toggles `(+Δ / -Δ)` equipped-slot comparison |
| `/vrb shift` | Toggles Shift-key-only tooltip display |
| `/vrb enchant` | Toggles ignoring enchants on equipped baseline items |
| `/vrb cap` | Toggles BCS Cap-Aware tooltip warnings |
| `/vrb setwarn` | Toggles Set-Break warnings on equipped comparisons |
| `/vrb spec [n\|name]` | Lists or toggles visible specs for your class |
| `/vrb weight <spec> <stat> <val\|reset>` | Overrides or resets a custom stat weight |
| `/vrb export <spec>` | Prints a shareable `VRB1:<spec>:STAT=VAL,...` weight string |
| `/vrb import <str>` | Imports a `VRB1:` weight string into the matching spec |
| `/vrb reset` | Resets all settings, hidden specs, and custom weights |

## What Was Added & Improved vs Upstream

| Area | Upstream | This Fork |
|---|---|---|
| Dependency | Required a modified standalone `BonusScanner` addon | Uses `BetterCharacterStats` (`BCSItemScan` stateless `ScanTooltip` + zero-duplication `GetEquippedSlotStats` + `BCS.EnchantStats`) |
| Equipment Filtering | `scoredItemTypes` never ran, used localized globals instead of raw `INVTYPE_*` enums, missed `INVTYPE_RANGEDRIGHT` / `INVTYPE_THROWN`, and let `equipLoc == ""` consumables through | Properly filters equipment only, supports bows/guns/crossbows/wands/thrown, and excludes consumables/quest items |
| Tooltip Hooks & `ShoppingTooltip` | `OnShow` child frame missed late tooltip lines; `SetInventoryItem`/`SetBagItem` return values lost; `ShoppingTooltip` double-counted ClassicAPI diff lines or popped stale tooltips | Direct multi-return-preserving hooks across all item tooltips, clean `SetHyperlinkCompareItem` handling, and safe composition with BetterCharacterPanel |
| Equipped Comparison & Smart Warnings | Score-only, no comparison, no cap/set awareness | Equipped `(+Δ/-Δ)` comparison with class-aware 1H dual-wield check, 2H vs MH+OH, enchant exclusion, BCS Cap-Aware warnings, and Set-Break warnings |
| Configuration & Cross-Addon API | Hardcoded weights only | SavedVariables (`VanillaRatingBusterDB`), `/vrb` CLI + GUI weight editor, Import/Export strings, and `VRB:GetUnitSpecScores(unit)` for BetterCharacterPanel |

## Credits

Original addon by Kylosandrax, continued by ZephZae. `BCSItemScan` engine ported from BonusScanner by Crowley. Community stat weights sourced from Vanilla/Turtle WoW theorycrafting spreadsheets.
