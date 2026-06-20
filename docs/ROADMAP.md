# Teramor — Depth Roadmap

> Where we're taking this, and why it can win. A living doc: edit as the game finds
> itself. Grounded in the systems that already exist (see `CLAUDE.md`) so every line
> is a next step, not a wish.

## The hook (what makes Teramor *singular*)

Most games pick a lane. Teramor's bet is the **collision of two tones that usually
live apart**: the warm, unhurried camp-and-farm sim (Stardew, Kynseed) and a
**serious, grounded fantasy with real stakes** — a dying god (Tera) whose dome
shields the world, a crown that abducts hybrids, a father who walked into the
Deepwood and didn't come back. You spend the morning watering turnips with Bram and
the afternoon reading an enemy's wind-up and rolling through the strike.

The **camp is the beating heart** that ties it together. It's home, it's the people
you're fighting *for*, and — now that you can **recruit its members** — it's a thing
that visibly *grows because of you*. That's the emotional engine. Everything below
deepens one of three pillars: **the living camp**, **the dangerous world**, and
**the cohesion** that makes judges call a game "complete."

---

## Pillar 1 — The living camp (our differentiator; lean in hardest)

The recruit loop (`CampManager`) is the seed. The award-winning version is a camp
that **grows from a few tents into a thriving settlement**, and people you *know*.

- **More roles, real depth.** Beyond farmhand/forager: **cook** (turns stash produce
  into buff meals overnight), **woodcutter/miner** (stocks crafting materials),
  **guard** (reduces night-raid risk once raids exist), **healer** (morning HP/regen).
  Each is a small `match` arm in `CampManager._on_day_changed` — the architecture is
  already built for it.
- **Camp tiers / construction.** Spend stash resources to upgrade: more plots, new
  buildings (kitchen, forge, infirmary), more tent slots → more recruits. A
  `CampManager` upgrade ledger + swapping props in `settlement.tscn` by tier. The
  camp you return to should look different at hour 20 than hour 1.
- **Member heart-events & storylines.** At heart thresholds, trigger a small authored
  scene (the dialogue/cutscene system exists). Bram's lost farm; Wrenna's elven
  secret; Mara and your father. This is where players *bond* — and what they
  screenshot. Drives `Relationships` from a number into a story.
- **Assignable, schedule-aware presence.** Recruited members already walk schedules;
  make a farmhand actually *stand in the field* by day. Seeing them work sells it.

## Pillar 2 — Relationships with teeth

- **Romance & rivalry**, gated on hearts, with commitment beats and consequences.
- **Member-given quests** ("clear the wolves off the south trail") that pay in
  affinity + camp resources — closing social → combat → camp.
- **Reactivity:** NPCs comment on your deeds, the day, the season, story progress.
  The `topics` system already supports flag/heart gating — widen it.

## Pillar 3 — Combat that rewards mastery

The telegraph→dodge→punish core is good. Make it *deep*:

- **Bosses** with multi-phase, readable patterns — the skill check the curve builds
  toward. The Cursed Wilds tiers (5–7) are the natural home; the Great Tree finale
  the capstone.
- **Elemental reactions / ability synergy.** Skills already unlock elemental
  abilities; make fire+oil, ice+shatter, etc. *combine*. Build depth, win the
  combat-design conversation.
- **Enemy variety & ecology.** The faction system already brawls ambiently — add
  species that pressure different player tools (shielded, ranged, swarm, summoner).

## Pillar 4 — Narrative & consequence

- **Branching via the Story director.** `StoryChapter` resources already chain;
  add **choices that set flags** which later chapters read — divergent beats, not
  just a line of dialogue.
- **Faction reputation** (Hollenmark / Plint / Terakin) that gates prices, quests,
  and endings. The world is already three kingdoms + a frontier — give them memory.

## Pillar 5 — Cozy breadth (the "just one more day" texture)

- **Seasons & festivals.** A season layer over `TimeManager` (crops per season,
  seasonal art tint) + authored festival days = the calendar players plan around.
- **Cooking** (recipes → buffs) and **animal husbandry** (a coop/barn as a camp
  upgrade) — both slot into the recruit/camp economy.
- **Fishing & collection depth:** a journal/museum of fish, crops, monsters — the
  completionist hook that extends the tail.

## Pillar 6 — World realization

- **Make the rumored places reachable.** Each named location now has a scene; wire
  discovery/journeys so the map's greyed goals become real destinations with
  identity and rewards.
- **Biome identity:** distinct enemies, gather nodes, weather, music per biome, so
  travel *feels* like crossing a world.

## Pillar 7 — Identity & polish (where awards are won or lost)

- **Art cohesion** on the grounded palette via `pixelforge` — the bespoke pipeline
  is itself part of the story. Hold the scale grid ruthlessly.
- **Music & ambience.** The mixer buses (Music / SFX / Ambience) are already waiting;
  per-biome ambient loops + a sparse, mournful score would lift the whole tone.
- **Game feel & accessibility:** options (volume sliders the buses expect, rebinding,
  difficulty/assist toggles), a strong first-15-minutes onboarding. Judges feel the
  first 15 minutes hardest.

---

## What "award-winning" actually rewards

Festival/award juries reward, in rough order: a **clear hook**, **cohesion** (every
system serving one vision), **polish/feel**, and an **emotional payoff**. Teramor's
risk is *breadth without depth* — many systems, none deep enough to be the reason you
remember it. **The counter-move: make the camp the unforgettable thing.** Go deep on
Pillar 1, let combat (Pillar 3) be the satisfying verb, and keep everything else in
service of "this little camp, and these people, became mine."

## Suggested near-term sequence

1. ~~**Camp depth, round 2** — cook + woodcutter roles, and a first **camp-upgrade**
   you buy with stash goods.~~ ✅ **Done** — `CampManager` cook/woodcutter roles +
   the `CampUpgrade` economy (bunkhouse/longhouse/irrigation/smokehouse) and a
   recruit cap.
2. ~~**First member heart-event** — Bram or Wrenna, at 4 hearts.~~ ✅ **Done** —
   `HeartEventManager` + Bram's and Wrenna's 4-heart events (Wrenna's turns the main
   hunt toward the Glade).
3. ~~**First real boss** in the Cursed Wilds.~~ ✅ **Done** — `BossEnemy` / the
   Withered Colossus (phases + ground slam + the Blightbane trophy).
4. **Season layer** over TimeManager — the calendar that reframes the whole loop.
   *(The next big one.)*

### Now-open threads to pull next (in priority order)

- **Seasons & festivals** (Pillar 5) — a season over `TimeManager`; seasonal crops +
  a first festival day. The calendar players plan around.
- **Camp construction round 3** (Pillar 1) — visible camp tiers: swap props in
  `settlement.tscn` by upgrade level so the camp *looks* like it grew; a kitchen/forge
  building gating cook/smith roles.
- **More heart-events & a romance track** (Pillar 2) — 6/8/10-heart beats; let
  Wrenna's Glade thread feed a Story chapter.
- **Boss polish & a second boss** (Pillar 3) — a dedicated boss health bar (HUD),
  bespoke Colossus art, and a second pattern (a ranged/summon phase).

Pick the pillar that excites *you* most; conviction reads on screen. Pillar 1's
momentum is spent for now — **seasons** is the highest-leverage next swing.
