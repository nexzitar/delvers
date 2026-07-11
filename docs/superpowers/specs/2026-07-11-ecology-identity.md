# Ecology, Families, and the Identity Phase

*Owner doctrine, 2026-07-11, on seeing the first architecture-kit
delve. Extends the compiled-world vision with the next milestones.*

## What the architecture proved

Combat used to look like it happened on a stage; now it happens
inside a place. Even simple walls make the player imagine unseen
space: what's around that corner? Can enemies come through that
doorway? That imagination is what good level pieces are FOR.

## The next milestone is enemy FAMILIES, not better enemies

Don't make ten monsters; make one family. Same proportions, same
equipment language, same colors - different silhouettes. A family
reads as a civilization, not a bestiary page:

- **Goblins**: Scout, Warrior, Archer, Shaman, Sapper, Chief.
- **Spiders**: Spiderlings, Venomous, Webspinner, Broodmother,
  Egg Cluster.
- **Slimes**: Green, Acid, Split, Slime Core, Slime Growth - and
  suddenly "slime rooms" become a thing.

## Ecology is evidence

Walking into the Darkwood you should not think "here's a spider";
you should think "spiders LIVE here": webs between pillars, cocoons,
egg sacs, wrapped goblin corpses, discarded molts, patrol routes.
The enemy is the least of the ecosystem; the dungeon shows the rest.

## Places with purpose

The long-term goal is not generating rooms but generating places
with purpose. Not "Room 2" but **Collapsed Guard Post**: two dead
guards, broken barricades, goblins scavenging, spiders feeding on
corpses, a side passage blocked by rubble - all from grammars, no
bespoke scripting. Ecology, architecture and encounters reinforcing
each other.

## Landmarks (add early - almost free, huge memory value)

Every dungeon gets 3-5 things players REMEMBER visually: a broken
colossus, a glowing underground tree, a dragon skeleton, a flooded
bridge, an ancient forge, a cavern-spanning web. Players don't
remember "the third corridor"; they remember "the room with the
giant tree." That is how people remember WoW dungeons.

## The identity phase

Capabilities are built; the question is now: **what makes a Delvers
dungeon unmistakably a Delvers dungeon?** The garment compiler
answered it for equipment; the architecture kit is answering it for
environments; enemy families will answer it for ecology; the audio
grammar ties it together so the player HEARS where they are before
they see it. When those converge, people stop recognizing assets
and start recognizing the world.

## Engineering read (agreed)

- Families are cheap now: the Tripo character pipeline puts every
  biped on the delvers' skeleton, so a goblin family is prompt
  variations + shared palette + silhouette-defining gear; behavior
  atoms (kite, flee-to-ally, spawn) already exist for Scout/Shaman
  roles.
- Ecology props extend the architecture kit compiler (webs, egg
  sacs, cocoons as pieces placed by pack proximity rules - spider
  packs seed webs around their home).
- Room purposes are a layout-grammar field: a room draws a role
  (guard post, hatchery, shrine, collapsed hall), and role selects
  props + pack composition + landmark eligibility.
- Landmarks: one Tripo hero piece per dungeon theme, placed by the
  layout at a designated room. Cheapest identity per token spent.
