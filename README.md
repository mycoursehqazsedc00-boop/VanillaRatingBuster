# Vanilla Rating Buster

Shows a per-spec gear rating in item tooltips, based on community-defined stat weights, for Turtle WoW (1.12). Hover any piece of equipment and see how much it's worth to your class and spec — higher is better, `0` means the item doesn't matter for that spec and isn't shown at all.

This is a fork of [VanillaRatingBuster](https://github.com/ZephZae/VanillaRatingBuster) (originally by Kylosandrax, continued by ZephZae), updated to depend on [BetterCharacterStats](https://github.com/mycoursehqazsedc00-boop/BetterCharacterStats) instead of a separate BonusScanner addon, plus two real bugs fixed along the way.

## Required and optional client mods

| Client mod | Needed? | Used for |
|---|---|---|
| **ClassicAPI** | Optional | `GameTooltip:GetItem()`, used to confirm the hovered tooltip is actually equippable gear before showing a rating. Not confirmed native to 1.12 — ClassicAPI's own documentation lists it among the functions it backports, so this is guarded and falls back to the original always-show-a-score behavior if it's unavailable |

Nothing else in this addon, or in the `BCSItemScan` module it now depends on, uses ClassicAPI, Nampower, or any other client mod — the stat parsing itself is pure tooltip-text pattern matching, same as the original.

## Features

- **A rating line per relevant spec**, added directly to the item's own tooltip, for every spec of your own class. Specs that get nothing from the item (rating `0`) are omitted rather than cluttering the tooltip.
- **Threshold-aware weights.** Some stats are weighted differently before and after a soft cap — for example, hit rating might be weighted heavily until you're close to hit-capped, then weighted near zero past that point, since extra hit rating beyond the cap is wasted. This compares against your *current total equipped gear*, not just the hovered item, so the rating reflects what the item is actually worth to you right now.
- **Covers all 9 classes**, each with multiple specs:

  | Class | Specs |
  |---|---|
  | Druid | `DruidFeralDPS-EP`, `DruidTank-EP`, `DruidThreat-EP`, `DruidResto-EP` |
  | Hunter | `HunterMM-EP`, `HunterBM-EP`, `HunterSurv-EP` |
  | Mage | `MageArcane-EP`, `MageFire-EP`, `MageFrost-EP` |
  | Paladin | `PaladinProtEH`, `PaladinRetDPS`, `PaladinHEP` |
  | Priest | `PriestHEP_2M`, `PriestHEP_15M`, `PriestHEP_TIG`, `PriestShadowDPS_2M`, `PriestShadowDPS_9M` |
  | Rogue | `RogueDagger-EP`, `RogueCombat-EP`, `RogueSub-EP` |
  | Shaman | `ShamanHEP`, `ShamanMelee` |
  | Warlock | `WarlockAffliction-EP`, `WarlockSMRuin-EP`, `WarlockDemo-EP`, `WarlockFire-EP` |
  | Warrior | `WarriorThreat-EP`, `WarriorMitigation-EP`, `WarriorFury-EP` |

  (`EP` = Effective Power / Effective Points, the usual theorycrafting term for a stat-weighted score. `EH` = Effective Health.)
- **Reads base item stats, bonus enchants, and set bonuses** — not just the item's innate stats, but anything an enchant or socket adds, and partial/full tier-set bonuses, all folded into the same score.
- **Only scores actual equipment.** Weapons, armor, jewelry, held off-hand items, and relics get a rating; consumables, quest items, and anything else do not, even if their tooltip happens to contain stat-like text.

## What changed in this fork

| | Original | This fork |
|---|---|---|
| Dependency | Required a separate `BonusScanner` addon folder (itself a modified copy, since upstream BonusScanner only scans "bonus" armor and ignores an item's base armor value, which tanking ratings need) | Depends on `BetterCharacterStats` instead. Its tooltip-parsing engine is ported in as `BCSItemScan`, keeping the same armor fix, so nothing is lost by dropping BonusScanner |
| Item-type filtering | `scoredItemTypes` and `VRBCheckItemType` existed but were never called from anywhere — every tooltip with any recognizable stat text got a rating, including consumables and quest items whose flavor text happened to look like a stat line | Wired up for real. Also: `scoredItemTypes` compared `GetItemInfo`'s raw equip-location enum (e.g. `"INVTYPE_HEAD"`) against *localized display labels* (`"Head"`) — these never matched, so this filter, unused as it was, would have rejected every item the moment anyone turned it on. Fixed to compare the raw enum directly. This also exposed a second gap: only `INVTYPE_RANGED` (Bows) was listed; `INVTYPE_RANGEDRIGHT` (Wands, Guns, and Crossbows on this pre-2.4.3 client) was missing entirely and is now included |
| `GetItemInfo` unpacking | An off-by-one meant the code that reads an item's equip-location was actually reading its stack count instead | Fixed |

### How the dependency swap works

`BCSItemScan` (inside BetterCharacterStats) is a line-for-line port of BonusScanner's parsing engine — verified byte-for-byte identical output against the original across test items covering generic stats, passive percentages, composite school+damage-type patterns, list-expansion effects (All Stats, All Resistances), set bonuses, and weapon oils. It also tracks a running total of your own equipped gear (`BCSItemScan.bonuses`), refreshed automatically when your gear changes, which is what the threshold-based weights compare against.

### Status

Tested with a full simulated hover-to-score flow (equip gear → hover an item → confirm the exact rating shown), not a live client. The item-type fix was specifically verified to both let real equipment through and correctly reject a non-equipment item with coincidentally stat-like tooltip text. The no-ClassicAPI fallback path was also verified: without it, scoring still works exactly as the original did, just without the equipment-type filter.

## FAQ

**How does it calculate a rating?**
It scans the item's tooltip (base stats, enchants, set bonuses included) via `BCSItemScan`, then multiplies each recognized stat by your class/spec's weight for that stat and sums the result.

**What about stats with weight changes at a certain cap (e.g. Hit)?**
These are defined as `{ threshold, before_weight, after_weight }` — for example `["TOHIT"] = { 8, 100, 1.811 }` means hit rating is worth 100 per point until your current total hit reaches 8, then worth only 1.811 per point after that.

**Why doesn't it always show a rating?**
If the computed rating is `0`, it's left off the tooltip entirely — e.g. a pure Healing Power item won't show a line under a tanking spec.

**My class/spec isn't weighted the way I'd expect.**
Weights are community-sourced and necessarily approximate; see each class's weight file for the specific numbers in use.

## Credits

Original addon by Kylosandrax, continued by ZephZae. BonusScanner's scanning engine (now ported as `BCSItemScan`) originally by Crowley (`crowley@headshot.de`). Class weight tables sourced from various community theorycrafting threads and spreadsheets (Nostalrius forums, Lurker Lounge, and others) — see each `weights/*.lua` file for stat-level attribution. Check the upstream repository for its license before redistributing.
