# slime-line — Project Diary

*Phase-by-phase log. Entries append, never rewrite. Nothing is done until its wall is green twice.*

---
## 2026-09-22 13:19 — Milestone 0 — the brief

Humboldt Jam, Slugs n' Bugs: a tilt-glide slug leaving glowing slime, letter-bugs to chase and eat, target words for multipliers, salt to fear. Art set generated; the slug core is building.

![Milestone 0 — the brief](assets/generated/slug_player.png)

## 2026-09-22 13:28 — Lore recovered

A found document from the world (see LORE.md) and its sketch now live in this repo's diary_images. Oddworld law: the game's instructions are artifacts of its own world.

![Lore recovered](diary_images/sketch_almanac_page.png)

## 2026-09-22 13:55 — Milestone 1 — the slug core

Glide with real drag physics (the agent found the spec's raw drag capped the slug below bug-flee speed and fixed the semantics — braking on counter-input), the glowing slime ribbon with age-faded points and additive glow, bugs that wander, flee within 120px, and pop when eaten. 23/23 twice; the 12-second chase replay eats 4-6 bugs and never loses the trail.

![Milestone 1 — the slug core](assets/generated/slug_player.png)

## 2026-09-22 15:37 — Milestone 2 — letters, the target word, and the chain

WordEngine landed (seeded word deals from the 26,955-word SCOWL tier, the 60/40 needed-letter spawn law, gold wildcards, 500x-chain scoring), bugs now carry outlined letters and gold variants, and the HUD v1 shows word slots, score, multiplier and bug count. The gates caught two real things: my first chase AI dithered itself into a standstill because the graze-to-refresh fallback leaked into mid-pursuit re-aiming, and the replay proved random 5-letter words sit right at the edge of the 20-second window, so the scripted replay now pins a seeded mid-band word while every mechanic stays live. Battery: 23/23 x2 and 22/22 x2, both replays green ten-for-ten on the spell-run, import and quit-after clean.

![Milestone 2 — letters, the target word, and the chain](assets/generated/bug_green.png)

## 2026-09-22 23:51 — ROADMAP to submission

Steps: 1) M3 finish (salt hazards + run loop + title screen + audio + export) — agent resumed. 2) Fix word_list.txt in export include filter. 3) Export Web + verify on Pages. 4) Create itch page via itch_web (if not exists). 5) Butler push to slothitude/slime-line:html5. 6) Aaron publishes + submits to Humboldt jam (deadline Sept 26 1AM). 7) Devlog from diary. 8) Asset pack update. DONE: M1 M2 green (45 checks), lore + sketches + almanac page complete.


## 2026-09-23 00:20 — Milestone 3 — the salt comes for those who keep taking

The garden is now a run. Salt crystals bloom at the wall-hugging edges (their clock starts only after your first spelled word — 14s of grace — and tightens with score, 6s down to 1.8s), salt kills on touch: the slug's chain resets, a bug dies without paying, one life and THE GARDEN REMEMBERS asks you back. Best score and RUN N persist to a 3-line user:// save; a tap RETRY rebuilds the garden clean. The title screen sits over the drifting garden (logo, slow slug, five bugs), and every sound is synthesized in code — squelch steps, chomps, the wrong-buzz, a word-complete arpeggio with confetti, gold sparkle, salt crunch, the low game-over, a title sting — 8 cues through a 6-voice pool, mute persisted. Juice: score-fly numbers, multiplier throb, salt-proximity shiver, a red vignette when the field crowds with crystals, big confetti on word completion, bug pop-in.

The gates earned their keep. The first replay run died mid-spell to a salt spawned at t<1s — the grace gate was born there. Then the spell-run itself stopped reproducing: three suspects unmasked in turn (the shiver drew randf_range twice a frame, the confetti spent the global RNG, and M3's heavier first frame — 8 synthesized cues — pushed the physics engine into catch-up steps between steering updates). The RNG draws became deterministic math, and all three replays now run under --fixed-fps 60, byte-identical to a pristine M2 control copy. Export ships the 26,955-word list inside index.pck (include_filter "*.txt" — verified in the baked pck bytes), 0 ERROR lines, 39.3 MB web build. Battery: 23 + 22 + 17 checks green twice, all three replays green twice, import and quit-after clean.

![Milestone 3 — the salt comes](assets/generated/salt_crystal.png)
