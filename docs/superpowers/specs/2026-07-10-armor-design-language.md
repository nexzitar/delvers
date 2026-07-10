# Delvers — Armor Design Language

Date: 2026-07-10 (owner design critique of the first derived leather
set — the verdict: **the pipeline works, the design doesn't**)

## The core insight

Fit was never the problem (the derived chest would pass as
hand-fitted). The problem is **language**: a shell over the torso
reads as leather glued to skin, not as equipment. Real armor — even
fantasy armor — has **construction**.

## The rules

1. **Build from pieces, not shells**: overlapping panels, belts,
   buckles, straps, layers. Manufactured, not extruded.
2. **Thickness**: 5–10mm world-scale, beveled edges. Razor-thin
   edges are the single biggest tell.
3. **Break the silhouette**: armor changes your outline. Leather:
   shoulder caps, layered skirt, thick belt, raised collar, straps.
   Skin-hugging = clothing.
4. **Think in layers**, each telling a story: linen shirt → leather
   vest → cross belt → sheath → pouches → shoulder guards → bracers.
5. **Cover the torso**: leather exposes neck/forearms, not half the
   chest. A sleeveless VEST, not two breast panels.
6. **Answer "how does it stay on?"**: shoulder straps, side buckles,
   stitched seams. Never magic.

## Material shape-language (not colors — SHAPES)

- **Plate**: large continuous pieces, rivets, rounded edges, heavy
  silhouette, broad shoulders.
- **Leather**: straps, stitching, layered flaps, buckles, tool
  loops, pouches, chest harness, asymmetry (see WoW ranger
  silhouettes: shoulder cape, thick belt, layered skirt —
  recognizable instantly).
- **Cloth**: folds, belts, rope, trim, embroidery, hood.

## The Delvers fantasy

Not knights — **explorers descending into forgotten ruins**. Armor
assembled over years: repaired stitching, mismatched buckles, an
extra knife sheath, rope tied where a buckle broke, a reinforced
shoulder because that's where monsters hit. Personality before
stats — and asymmetry makes small imperfections read as intentional.

## What changes in derivation (derive v2)

Don't duplicate-and-inflate the whole torso. **Derive individual
construction pieces from the body** (fit stays perfect by
construction, reading becomes crafted):

- front leather vest panel + back panel (joined at sides, covering
  the chest)
- shoulder yoke
- hanging waist flaps (separate overlapping bands)
- belt (thick, with buckle)
- shoulder caps
- thickness via solidify 8–10mm + bevel modifier
- straps/buckles as placed primitives following the surface
- deliberate asymmetry and wear details

## Derive v4 (owner critique of the jacket, same day)

The jacket wraps, deforms, has collar/opening/silhouette — remaining
issues are ARTISTIC:

1. **Too skin-tight** (the big one): vacuum-sealed. Garments need
   volume — shoulders sit 2-3cm (visual) off the body. Differential
   inflation: more at shoulders/chest, less at waist.
2. **Everything ends at the same place**: uniform hems read
   manufactured-by-computer. Break it: one sleeve rolled, one full;
   front flap longer; one shoulder reinforced. Asymmetry = person.
3. **The torso reads as ONE object**: it should read as an assembled
   garment — front-left panel, front-right panel, back panel, collar,
   shoulder yoke, sleeves, cuffs — each visually identifiable
   (split with small offsets/edge seams).
4. **Not enough overlap**: clothing is LAYERS, not seams. Collar over
   chest flap over belt over skirt. The Blizzard rule: **nothing
   important is flush — everything sticks out** (shoulders, belts,
   collars, buckles, pouches).
5. **Later: structural wrinkles** — not sculpted detail; large folds
   at shoulder/elbow. Perfectly smooth leather reads as plastic.

## THE GARMENT GENERATOR (owner vision — the strategic payoff)

Stop asking AI to invent armor; ask Blender to DERIVE clothing by
RULES. A jacket generator: take torso → inflate 10mm differential →
split into front-L/front-R/back/collar/sleeves/cuffs → add N random
buckles, stitches, patches, one shoulder reinforcement, random collar
height / sleeve length / belt position. **Every leather chest unique;
every single one fits perfectly.** Uniqueness by construction rules,
not by generation lottery — this is the item-diversity engine for
the whole loot game (rarity tiers = rule budgets: more panels, more
hardware, louder silhouette).
