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
- **A living, vast world (in progress).** The look-and-feel push toward a Stardew-
  bustling, lived-in world. Threads, by impact: **(a)** depth/parallax — a background
  layer, a drifting foreground forest canopy, and the Great Tree looming on the wilds'
  horizon; **(b)** thick forests — a dense deepwood thicket tier with underbrush,
  dappled light + mist, short winding sightlines; **(c)** **living cities** — a moving
  crowd, animals, market bustle, chimney smoke; **(d)** ground detail — kill the flat
  tinted plane with scattered tufts/flowers/pebbles/path-blending.
  - ✅ **Living cities, PR1 (done)** — cosmetic **townsfolk** crowds
    (`scripts/townsfolk.gd` + `townsfolk_crowd.gd`, reusing the NPC walk sheet, no new
    art) and **chimney smoke** on the hearth buildings, reading against the existing
    night window-glow. Cleeve's Landing now bustles. `tools/validate_townlife.gd`.
  - ✅ **Living cities, PR2 (done)** — **animals** (`scripts/critter.gd`): pecking
    **chickens** by the camp farm, a friendly street **dog**, and a **flock of plaza
    birds that flush** — flee and take wing — when you run through them. Bespoke
    pixelforge art (`tools/gen_critters.py`). `tools/validate_critters.gd`.

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
4. ~~**Season layer** over TimeManager — the calendar that reframes the whole loop.~~
   ✅ **Done** — a derived calendar (season / day-of-season / year) in `TimeManager`,
   **seasonal crops** (`CropData.seasons`, planting gated + out-of-season pause), a
   per-season **world tint** in `day_night.gd`, a date HUD, and **SeasonManager** with
   season + festival banners (four festivals authored). `tools/validate_seasons.gd`.

---

## Pillar 8 — Look & feel / polish (the first-15-minutes pass)

The depth is landing; now make it *feel* finished. These are the highest-leverage
look-and-feel swings — most are felt by a first-time player in the opening minutes,
and none depends on another landing first. Rough priority:

1. ~~**Music & ambience** — the single biggest feel gap.~~ ✅ **Done** —
   `MusicManager` crossfades looping themes per zone (camp/town/wild/cursed/finale)
   and swaps day↔night ambience beds; `audioforge.py` bakes four themes + four beds
   as seamless loops (still all-ours, no samples). `tools/validate_music.gd`.
2. ~~**Dialogue portraits** — conversations are text-only.~~ ✅ **Done** — speaker
   busts beside the lines (`dialogue.gd` portrait slot), a neutral + happy expression
   per NPC swapped on loved/liked gifts and in heart events; baked by
   `gen_portraits.py` on the grounded palette, resolved by id convention.
   `tools/validate_portraits.gd`.
3. ~~**Options menu** — volume sliders, key rebinding, fullscreen/vsync, assist
   toggles.~~ ✅ **Done** — `SettingsManager` (persisted to `user://settings.cfg`) +
   a tabbed `settings_panel` (Audio / Display / Controls) reachable from the title
   screen and the player-menu footer; sliders drive the mixer buses, a screen-shake
   toggle for accessibility, keyboard rebinding. `tools/validate_settings.gd`.
4. ~~**Weather + environmental particles** — rain, fog, leaves, fireflies.~~ ✅ **Done**
   — `WeatherManager` rolls a deterministic season-weighted sky per day; `WeatherFX`
   paints rain/snow/fog + fireflies/leaves as code-built particles (outdoor-gated);
   day_night dims for overcast and rain auto-waters crops. `tools/validate_weather.gd`.
5. **Post-processing pass** — a full-screen shader for subtle vignette + per-biome
   colour grading + a touch of bloom on embers/magic/blight.
6. **Arrival title cards + UI motion** — a brief "Cleeve's Landing — Hollenmark" card
   over the fade; tween menu/banner opens through `UITheme`.
7. **A light cutscene/camera system** — pan + letterbox + focus for story beats.

### Experience & QoL (the "this feels shippable" layer)

- **First-15-minutes onboarding** — contextual prompts the first time you farm/fight/
  recruit. Juries feel the opening hardest.
- **Inventory QoL** — sort, stack-split, shift-to-storage, a trash/drop slot.
- **A Codex / almanac tab** — discovered crops, fish, monsters, people; the
  completionist tail, as a `player_menu` tab.
- **Boss health bar HUD** + status-effect icons on the HUD — combat readability.

### Now-open threads to pull next (in priority order)

- **The Elkar opening / tutorial** (Pillar 4 + onboarding) — *in progress.*
  - ✅ **PR A (done)** — the **prologue** (`prologue.tscn`): a new game opens at the
    wilds' edge where **Elkar** gives a diegetic last lesson (footwork / blade / roll /
    the land), the two wolves are the `ch1` "defeat 2 foes" beat, then an exit carries
    you to Cleeve's Landing. `tools/validate_prologue.gd`.
  - ✅ **PR B (done)** — the **camp is now a secret**: `settlement_camp` is
    undiscovered, found by **trekking a hidden trail** that the tavern contact
    **Sorrel** reveals in Cleeve's Landing; **Elder Maelon recruits** you into the
    Children of Tera (ch2 → ch3_children → ch4 awakening). The open road stays sealed
    until discovery (new `require_flag` gating on explore/transition zones), and
    `continue_game` now reloads your last location. `tools/validate_recruitment.gd`.
- **A Codex / almanac tab** (Pillar 8 QoL) — discovered crops/fish/monsters/people as
  a `player_menu` tab; the completionist hook.
- **Camp construction round 3** (Pillar 1) — visible camp tiers: swap props in
  `settlement.tscn` by upgrade level so the camp *looks* like it grew; a kitchen/forge
  building gating cook/smith roles.
- **Festivals with content** (Pillar 5) — the banner days exist; give one an actual
  event (a gathering, a stall, a minigame) so the calendar has a payoff.
- **More heart-events & a romance track** (Pillar 2) — 6/8/10-heart beats; let
  Wrenna's Glade thread feed a Story chapter.
- **Boss polish & a second boss** (Pillar 3) — a dedicated boss health bar (HUD),
  bespoke Colossus art, and a second pattern (a ranged/summon phase).

Pick the pillar that excites *you* most; conviction reads on screen. The **Elkar
opening** is now in: the prologue (PR A) makes the father a present mentor who teaches
you and then goes missing, and the secret-camp slice (PR B) turns the Children of Tera
into an order you uncover by trekking a hidden trail and are recruited into — the
tone-setting first fifteen minutes now play start to finish.
