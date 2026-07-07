# Delvers — Mastery, Identity and Training

Date: 2026-07-06 (owner design document)

## Core philosophy

> **Equipment determines your current role.**
> **Mastery determines how good you are at that role.**
> **The Guild determines how you customize that role.**

No fixed classes. Garrick becomes a legendary swordsman because he has
fought with swords for dozens of expeditions — not because he spawned
as a Warrior. Wren is the Guild's greatest archer because she has
practiced archery — not because she is locked to bows.

## Discipline mastery

The currently equipped gear determines which discipline trains
(Sword, Shield, Bow, Restoration, Elemental Magic, Polearms, Daggers,
...). Ten expeditions with a bow raise Bow mastery; twenty with
Restoration gear raise Restoration while Bow gradually rusts.

## Rusty, not forgotten

Every discipline stores **current mastery** and **highest mastery
ever**. UI: `Bow ★★☆☆☆` — two current stars, hollow gold stars for
dormant experience. Retraining a rusty discipline is much faster than
learning from zero: a legendary swordsman who hasn't held a sword in
years is rusty, not a novice.

## Mastery unlocks techniques, not numbers

Mastery grants competence: Sword — ★ Slash, ★★ Cleave, ★★★ Weapon
Familiarity (slight attack speed), ★★★★ Hamstring, ★★★★★ Whirlwind.
Bow: Shoot → Volley → Piercing Shot → Rain of Arrows. Restoration:
progressively stronger healing and utility. The excitement of mastery
is new techniques, not bigger damage.

## Guild customization

Mastery techniques are **core** (known automatically). Separately the
Guild unlocks **Technique Slots** (meta progression) for customizing
any mastered discipline — two master Guardians can play completely
differently.

## Character identity

    Garrick
    Sword        ★★★★★
    Shield       ★★★★☆
    Bow          ★☆☆
    Restoration  ★

His history is visible without a biography. Preparing an expedition
should feel like *"I'll take Garrick on this delve"*, not *"I'll
equip a random hero with a sword"*. Retraining Wren into a healer is
a meaningful Guild management decision, not an equipment swap.

## Design goals

Preserve the classless philosophy; give every delver identity; reward
long-term investment; make retraining meaningful without punishment;
encourage a roster of specialists; make the Guild an organization that
develops expertise; keep progression about learning techniques, not
numerical scaling. Mastery is personal knowledge — the Archives hold
the world's, the Forge holds the craft's, each delver holds their own.

---

## Implementation status

- **2026-07-06 (v1)**: four disciplines (Sword, Shield, Bow,
  Restoration) trained by worn gear / slotted healing; XP per cleared
  room (+boss bonus); five stars on cumulative thresholds; rust decays
  current XP when a delve trains other things (highest-ever stays);
  relearning below highest gains triple XP; mastery tracks auto-grant
  core techniques and passives in combat (no slot cost); star-ups
  announced in the spoils toast; current/dormant/empty star rows in
  the loadout; veteran saves seed active disciplines at two stars.
- **Deferred**: more disciplines (magic, polearms, daggers as content
  arrives), per-discipline five-deep unique technique lists (Rain of
  Arrows, Taunt...), guild Technique Slot expansion tied to mastery,
  mastery view in a dedicated roster/guild screen.
