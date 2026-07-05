# Delvers Storytelling — Archaeology, Not Narration

Date: 2026-07-05 (owner design document)

## The problem

The systems answer *what do I do?* — they don't yet answer *why am I
doing it?* Delvers lacks purpose, not content. A traditional RPG intro
("Greetings, hero...") would be weaker than what Delvers could become.

## The principle

> **Don't tell the player the lore. Make them recover it.**
> Delvers doesn't need a storyteller. It needs **archaeology**.

Recipes are recovered knowledge. Crafting is rediscovering lost
techniques. The camp is being rebuilt. The player gathers materials
from a world that clearly existed before they arrived — the lore
should work exactly the same way.

## The camp is the protagonist

The opening: tiny fire, one exhausted delver, a few logs, ruined sign,
empty surroundings. No explanation. The player immediately asks *"why
is it so abandoned?"* — that question is the beginning of lore.

**Environmental progression**: the camp slowly rebuilds and the player
*sees* it, never gets told. Early: broken cart, collapsed watchtower,
abandoned forge. Later: forge repaired, merchant wagon, training
dummy, library. Eventually: children, animals, a smith at work, flags
flying.

## Not saving the world — rebuilding a guild

Delvers is about **rebuilding an adventurers' guild**. The opening
journal: *Guild Ledger — Members: 1. Treasury: empty. Known
Techniques: Iron Sword.* No narrator; the player understands
everything.

## Lore through discoveries

Tomes carry provenance AND fragments of story:

- *Spider Venom Treatise* — "Recovered from the remains of the Black
  Hollow expedition."
- *Royal Slime Alchemy Notes* — "The royal jelly resisted every known
  solvent except fire." (Someone studied the Slime King before.)
- *Hunter's Journal* — "We lost three scouts to the spiders before
  discovering the venom could be tempered into steel." (There were
  previous expeditions. They failed. You benefit.)

Enemies tell stories the same way: nobody explains the crowned Slime
King — until you find research notes that observe "slimes possess
hierarchy."

## Every dungeon is a failed expedition

You're not the first guild — you're the latest. A skeleton beside
*Expedition Log #17*: "Food ran out three days ago. We can hear
something moving below..." Not a cutscene. The dungeon has history.

## The camp museum

Eventually the camp gets a **library** — not for gameplay, for
*memory*. Every tome on shelves, boss trophies displayed, maps pinned.
The player walks through the history they've uncovered.

## Maps as progression

Dungeons unlock by *finding old maps*, not by being told: *Weathered
Map Fragment — "Marked only with the symbol of a spider."* → Spider
Nest unlocked. Lore and progression in one mechanic.

## The opening (eventual)

No cinematic, no narration. Fade in: tiny fire, rain, one lone delver
sharpening his sword. The camera pans across broken wagons, empty
tents, a fallen banner. You click Enter. Over the next twenty hours
the player discovers why the camp was abandoned and turns it back
into a thriving guild.

---

## Implementation status

- **2026-07-05 (slice 1)**: tome lore lines on every recipe/affix;
  the Black Hollow **Expedition Logs** (four fragments recovered in
  order across delves — the previous guild's fall, ending with why
  the camp stands abandoned); the **Library** tab at camp shelving
  every recovered tome with its lore and every expedition log in
  full; ruined camp set-dressing (broken cart, fallen banner) with
  the first restoration beats (the banner rises once the Slime King
  falls; an anvil appears as the forge's knowledge grows).
- **Deferred**: Guild Ledger opening journal, rain/sharpening menu
  tableau, map-fragment dungeon unlocks, boss trophies and pinned
  maps in the library, merchant/dummy/children/animals restoration
  beats, per-dungeon skeleton-and-journal set pieces.
