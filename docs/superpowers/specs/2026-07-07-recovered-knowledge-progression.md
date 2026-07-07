# Delvers — The Long Tutorial: Progression as Recovered Knowledge

Date: 2026-07-07 (owner design document — the unifying philosophy)

## Core philosophy

> The entire game is rebuilding the knowledge of a lost guild.
> No sudden unlocks of complicated systems: every layer is recovered
> naturally, so the whole game is one long tutorial. Steady discovery,
> never information overload.

## The phases

**Phase 1 — Survival.** Almost nothing: simple equipment, simple
masteries, basic tactics (Nearest Target; heal below 50%; attack
current target). No complexity.

**Phase 2 — Tactical Thinking.** The player recovers battlefield
doctrine: Guard the Line, Protect the Healer, Finish the Wounded,
Focus Boss, Spread Venom. Predefined behaviours — not programming,
doctrine.

**Phase 3 — Guild Engineering.** The Scratch editor is discovered.
Crucially: **Scratch is not a different system** — it builds the exact
same behaviour trees the tactics already use, visually:
`IF enemy count > 4 THEN Thunderclap`, `IF health < 30% THEN Shield
Wall`. A natural extension of tactics, not a replacement.

**Phase 4 — The Engineer.** Much later, Python-like scripting — which
**compiles into exactly the same internal behaviour tree** as Scratch
and Tactics. More expressiveness for advanced players; completely
optional.

## The bridge: "View Code"

Scratch has a button that shows the generated Python. The player
slowly realizes: *"Wait... Scratch is just writing Python."* The
transition feels natural instead of intimidating.

## The language is loot

The scripting language itself is recovered like everything else:

- **Engineer's Notebook I** → `nearest_enemy()`, `self.health`,
  `target.health`
- **Engineer's Notebook II** → `party.members`, `sort()`, `filter()`
- **Field Mathematics** → `count()`, `average()`, `distance()`

The player isn't learning Python. They're recovering the engineering
manuals of the old Guild. Player and Guild grow together.

## The design pillar

**Programming never makes a player objectively stronger than built-in
tactics.** It provides flexibility, optimization, personality — not
raw power. One shared behaviour engine under three interfaces:
Tactics, Scratch, Python. The whole game is completable with Mastery,
Guild Techniques, and built-in Tactics alone.

## Why it fits

Recipes are recovered knowledge. Affixes are recovered knowledge.
Guild Techniques are recovered knowledge. Mastery is personal
knowledge. The scripting language is recovered knowledge. Few games
make learning their systems part of the world's fiction — recovering
an Engineer's Notebook is uncovering a civilization that knew more
than you.

---

## Implementation status

- **2026-07-07 (Phase 2 v1)**: tactics became **Battlefield
  Doctrines** — recovered knowledge, not free options. Fresh guilds
  know only Nearest Foe; doctrines drop as tomes from thematic
  teachers (warriors: Guard the Line; archers: Finish the Wounded;
  spiders: Spread the Venom; bosses: Focus Order), shelve in the
  Library, and unlock their tactic on banking. Veteran saves keep
  everything they've used.
- **Deferred**: Phase 3 (Scratch over the shared behaviour tree),
  Phase 4 (Python + View Code bridge), Engineer's Notebooks as the
  language's loot tables, formalizing the tactic scorer into the
  shared behaviour-tree engine all three interfaces compile to.
