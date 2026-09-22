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

