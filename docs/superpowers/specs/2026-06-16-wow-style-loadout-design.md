# WoW-style Loadout, Weapon Speed & Dual-Wield — Design

Date: 2026-06-16

## Overview

Expand the hero loadout from four equipment slots to a full World-of-Warcraft-style
slot set, rearranged into two columns flanking the live character preview with the
weapons and a 6-slot skill row along the bottom. Add weapon **attack speed** so
weapons can be fast or slow, enable **dual-wielding** one-handed weapons (a second
attack on its own timer at reduced damage), and unify the two starting heroes into a
single Default Delver whose role is decided entirely by what it wields.

## Goals

- Loadout screen looks like a WoW character pane (Layout A: columns flanking the hero).
- A full slot set exists in data and UI now, even though most slots have no items yet.
- Empty slots are visible (with silhouette icons) to create anticipation.
- Weapons have a speed; fast vs. slow is a feel/pacing choice, not a power choice.
- Dual-wielding two one-handed weapons works, with the off-hand at 50% damage.
- The two starting heroes are the same Default Delver, differing only by equipped gear.

## Non-Goals (out of scope for this work)

- Authoring a large library of new items for every slot (we add a handful; most slots
  stay empty placeholders).
- Functional active/learned skills beyond the weapon-driven auto-attack (skill slots
  2–6 are placeholders).
- Saving loadouts to disk (still session-only, as today).
- Changing enemy combat (enemies keep their template attack interval).
- Item rarity, set bonuses, sockets, enchants.
- Armor / flat damage mitigation and on-hit proc effects (poison, etc.) — the weapon
  tuning is designed to anticipate them, but they are built later.
- Acquisition: enemy item drops, and a shop for skills/heroes. (Heroes/skills are
  seeded directly for now.)

## Slot Model

### Equip positions

`GearDefinition.Slot` becomes the full set of **equip positions**:

```
HEAD, NECK, SHOULDER, BACK, CHEST, WRIST, HANDS, WAIST, LEGS, FEET,
RING_1, RING_2, TRINKET_1, TRINKET_2, MAIN_HAND, OFF_HAND
```

Layout A places them as:

- Left column (top→bottom): Head, Neck, Shoulder, Back, Chest, Wrist, Hands
- Right column: Waist, Legs, Feet, Ring 1, Ring 2, Trinket 1, Trinket 2
- Bottom weapon row: Main Hand, Off Hand
- Bottom skill row: 6 skill slots

### Gear category vs. position

Because rings and trinkets come in pairs, gear carries a **category** that can map to
more than one position:

- A ring item has category `RING` and may be equipped into `RING_1` or `RING_2`.
- A trinket has category `TRINKET` → `TRINKET_1` / `TRINKET_2`.
- Every other category maps to exactly one position (e.g. `HEAD` → `HEAD`).
- Weapons: a main-hand-capable weapon has category `MAIN_HAND`; a one-handed weapon
  is also accepted in `OFF_HAND` (dual-wield). A shield's category is `OFF_HAND`.

A helper `accepted_positions(gear) -> Array[Slot]` encapsulates this mapping and is used
by drop routing and the "drop anywhere → obvious slot" feature. When a category maps to
two positions, "drop anywhere" fills the first empty one (or swaps position 1 if both
are full).

### Loadout storage

Hero loadout changes from "an array searched by slot" to a **position-keyed map**
(`{Slot: GearDefinition}`) on the hero, so two rings (or two weapons) coexist.
`PlayerRoster.equipped_item(hero_index, position)` reads the map.
Combat reads the same map when computing stats.

## Data Changes

`GearDefinition`:

- Replace the 4-value `Slot` enum with the 16-position enum above.
- Add `slot_category` concept (either a new field, or derive positions from `slot` +
  `weapon_type`). Implementation detail for the plan; behavior is `accepted_positions`.
- Add `@export var attack_speed: float` (seconds per swing; meaningful for weapons,
  0/ignored otherwise).
- Keep `attack_bonus`, `health_bonus`; weapons use `attack_bonus` as their per-swing
  damage contribution.

`HeroTemplate`:

- `starting_gear` stays a list of `GearDefinition`, but the roster builds the
  position-keyed loadout from it. `base_attack_interval` is retained as the **unarmed
  fallback** interval.

## Combat Changes

In `CombatState.setup_combat` (hero branch) and `CombatEntity`:

- **Attack interval** for a hero = main-hand weapon's `attack_speed`. If no main-hand
  weapon, use the template's `base_attack_interval` (unarmed).
- **Attack power** = `base_attack` + attack bonuses from all **non-weapon** gear +
  the **main-hand** weapon's `attack_bonus`. (Off-hand weapon's bonus is NOT added here,
  to avoid double-counting; it powers the off-hand swing instead.)
- **Main-hand swing damage** = `attack_power + random(skill.min, skill.max)`, as today.
- **Dual-wield**: if `OFF_HAND` holds a one-handed weapon, the entity gets a second
  attack timer at the off-hand weapon's `attack_speed`. Off-hand swing damage =
  `floor(0.5 * (base_non_weapon_attack + off_weapon.attack_bonus + random(skill)))`.
  The off-hand uses the same attack skill (so the delivery/animation match).
- Shields and two-handers/bows in the off-hand do not create a second attack.

`CombatEntity` grows to hold an optional off-hand weapon + its own timer; `update()`
ticks both timers. Both swings emit normal DAMAGE/DEATH events, so the theater replay
and side panels need no special handling.

### Weapon tuning (DPS-normalized)

Weapons are authored so `attack_bonus / attack_speed` (per-second contribution) is
roughly constant across weapons of the same tier. Example starter weapons:

| Weapon | Type | Speed | Attack |
|--------|------|-------|--------|
| Starter Sword | one-handed | 2.6s | ~3 |
| Fast Dagger | one-handed | 1.5s | ~2 |
| Heavy Mace | two-handed | 3.4s | ~6 |
| Starter Bow | bow | 2.8s | ~3 |

(Numbers are starting points; tuned during implementation. The point is the *mechanic*:
faster = softer/more frequent, slower = harder/less frequent, similar DPS.)

**Why normalize weapon-only DPS:** the goal is that, judged purely on auto-attacks
against an unarmored dummy, all weapons of a tier do the same DPS. The interesting
trade-offs come from *other* systems interacting with hit size and hit frequency, so
the player tailors skills to their weapon (or vice versa):

- **Armor (flat mitigation, future):** a flat reduction per hit punishes many small hits
  more than a few big ones, so against armored foes a slow/hard weapon out-damages a
  fast/soft one.
- **Skill / special attacks that scale off weapon or attack power:** land harder with a
  slow, hard-hitting weapon.
- **On-hit effects (poison and other procs, future):** trigger per swing, so a fast
  weapon racks up more procs and wins when your build leans on them.

These mitigation/proc systems are **not built in this work** (see Non-Goals); the weapon
tuning is simply designed so they slot in cleanly later. For now, normalized weapon DPS
plus weapon-driven role is the whole behavior.

## Hero Unification

- Delete `resources/heroes/ranger_delver.tres` and its `PlayerRoster` reference.
- `PlayerRoster.heroes` holds two **duplicates** of the Default Delver template, so each
  hero's loadout is independent (editing one must not affect the other).
- Hero 0 starts with sword + shield; hero 1 starts with a bow. Both named
  "Default Delver" (player can rename). Role/row remains weapon-driven via `_sync_role`.

**Why keep two heroes (for now):** the long-term plan is to start the player with a
single hero. But the upcoming combat systems — threat, cleave/AoE, heals, buffs —
are much easier to exercise with a small party, so we keep two starting heroes as a
test bed for those. Future acquisition (not in scope here): **items drop from enemies**,
while **skills and additional heroes come from a shop**. This work doesn't add any
acquisition; it just makes both starting heroes share the Default Delver base.

## UI Changes (`loadout_screen.gd`)

- Rebuild the left character panel as Layout A: name field, two slot columns flanking
  the live `SubViewport` preview, role label, a Main/Off weapon row, then a 6-slot
  skill row.
- The right side becomes a **tabbed panel**: tab 1 = **Gear** stash, tab 2 = **Skills**.
  The active tab uses the full panel height, so the gear stash has room for the larger
  item set. The Skills tab shows the known-skills catalog (sparse / "coming soon" for
  now, since the attack is weapon-driven); it becomes the source for assignable skills
  when active skills land later.
- **Skill row**: slot 1 shows the weapon-driven attack (read-only; updates on weapon
  swap). Slots 2–6 are empty "future skill" placeholders, not yet assignable.
- Empty equipment and skill slots show generated silhouette icons.
- Tooltip gains weapon speed and (for off-hand one-handers) the 50% note. When the
  hovered/relevant slot is a weapon, the tooltip shows **both hands**: the main-hand
  weapon and, if the off-hand holds something (i.e. not blocked by a two-hander/bow),
  the off-hand item too — so the player sees their full weapon setup at a glance.
- Existing drag-and-drop and click-to-carry both keep working with the new positions,
  including routing ring/trinket items to the first free of their two positions.

## Art

Generate, in the existing pixel style:

- A silhouette empty-slot icon per slot category (head, neck, shoulder, back, chest,
  wrist, hands, waist, legs, feet, ring, trinket, main-hand, off-hand).
- An empty skill-slot icon.
- A couple of new weapons to show off speed (e.g. a fast dagger and a heavy two-hander)
  with paper-doll textures + inventory icons.

## Testing

- Extend the headless logic test (`capture/auto_drop_test`-style) to cover:
  position-keyed equip/unequip, ring/trinket dual positions, dual-wield producing a
  second weapon + timer, off-hand 50% damage, weapon-speed → interval, unarmed fallback,
  and that the two heroes' loadouts are independent.
- A short headless combat check: a dual-wielder lands more swings than a two-hander over
  a fixed time, with comparable total damage (sanity for DPS normalization).
- Windowed screenshot of the new Layout A loadout for the README.

## Risks / Notes

- Changing `Slot` enum values touches existing `.tres` gear, the paper-doll
  (`theater_actor.equip_gear`), `PlayerRoster`, `combat_state`, and the loadout UI.
  All current references to `MAIN_HAND/OFF_HAND/HEAD/CHEST` stay valid names; the new
  values are additive, so the migration is mostly mechanical.
- The position-keyed loadout is the main structural change; it must be applied to roster
  queries, combat stat computation, and drop routing consistently.
