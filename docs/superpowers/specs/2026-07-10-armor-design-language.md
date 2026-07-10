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

## v5 — THE GARMENT CONSTRUCTION ENGINE (synthesis, 2026-07-10)

Stop thinking "generate a jacket"; think **"generate wearable
construction."** The reference's gold standard: every visible
feature answers "how was this garment built?"

### The compiler framing
Input is a garment SPEC, not a request:
    Leather Jacket { volume: 0.8, panels: 8, collar: tall,
      shoulders: layered=4, buckles: 9, sleeves: rolled_left,
      bracers: plated, edge_wear: medium }
Output: rigged mesh, weights, materials, hide lists, metadata.
**Procedural loot follows**: items STORE the spec, not the mesh —
every leather chest actually unique, compiled on demand.

### What v5 derives (vs v4's inflated shell + seams)
TEN independent construction pieces, each with own thickness, bevel,
edge wear, material ID, color region:
  Collar / Front-Left / Front-Right / Back / Shoulder-Yoke-L /
  Shoulder-Yoke-R / Sleeve-L / Sleeve-R / Waist-Belt / Hardware.

### Reference lessons Claude under-weighted (per critique)
- Hardware as STRUCTURE: 15-20 clasps in a rhythm, not 6.
- Shoulders = layered leather FLANGES (overlapping scales), widening
  the silhouette without reading as plate.
- Bracers are SEPARATE objects (own thickness/material), not sleeves.
- Waist COMPRESSION: wider above the belt, flared below.
- Exaggerate for stylization: seams deeper than reality, edges
  thicker, panels prouder — readable at thirty meters.
- Asymmetry menu for generation: rolled sleeve L/R, shoulder patch
  L/R, knife sheath, extra buckle, torn hem, repaired elbow.

### The grammar scales
Same body-derivation pipeline, different construction grammar per
material: leather = stitched/folded/strapped/layered; plate =
overlapping plates/rivets/hinges; cloth = folds/hems/embroidery/
hanging fabric. Once it compiles jackets it compiles robes, cloaks,
gambesons, brigandines, tabards — a foundational content engine,
not an asset pipeline.

## The capstone synthesis (2026-07-10, end of session)

### The spec is the item — as LOOT ARCHITECTURE
Items store construction specs, not meshes:
  material, construction{panels, yokes, collar, belt},
  hardware{buckles, straps, rivets}, wear{scratches, repairs, dirt},
  style{rolled_sleeve, asymmetry}, palette{primary, trim}.

### Construction knowledge is the crafting economy
This EXTENDS the founding pillar (monsters drop resources and
knowledge) into geometry:
- Salvaging a coat yields COMPONENTS: brass buckles ×6, a shoulder
  pattern, a tailored collar, reinforced stitching.
- Crafting inherits construction across items: the new Ranger's Coat
  takes this one's collar, that one's buckles, a third's shoulders.
- Elite enemies drop **Master Tailor Patterns** ("Layered Shoulder
  Construction") — permanent construction knowledge, usable in every
  later garment. Far more memorable than a stat stick.

### The practicality rule (never violate)
"Can this still generate 10,000 items quickly?" Blender per-drop is
too slow. Architecture:
1. OFFLINE (Blender, the engine): generate a LIBRARY of modular
   pieces — panels, collars, sleeves, yokes, flanges, hardware.
2. RUNTIME (Godot): assemble + recolor pre-generated modules
   instantly per spec. Near-full variety, zero per-drop cost.

### The principle, named
**Construction first, appearance second.** Once construction is
believable, style/color/rarity/material build on top. The
distinctive claim: "every piece of equipment is procedurally
constructed from wearable components that actually fit the character
it was made for."
