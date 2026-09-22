class_name Feel
## SLIME LINE — every feel number lives here.
## Spec law "constants_not_magic": no tuned number anywhere else in the project.
## Milestone 1 (SLUG CORE) uses movement + trail + bugs; milestone 2 adds the
## letters + words + scoring block; milestone 3 fills the salt/run/sfx/title
## block. Everything matches spec/jam_spec.json.

# ----------------------------------------------------------------- movement --
const GLIDE_ACCEL := 320.0            # spec systems.movement.glide_accel
const DRAG := 0.90                    # spec systems.movement.drag (per 1/60s frame, coasting)
const MAX_SPEED := 240.0              # spec systems.movement.max_speed
const SLUG_BOUNDS_MARGIN_PX := 36.0   # px kept clear of the screen edges; must
                                      # stay small enough that a bug cornered at
                                      # its own bounds (BUG_RADIUS inset, diagonal
                                      # ~25px) stays inside EAT_RADIUS
const SLUG_BODY_RADIUS := 22.0        # physics circle + antenna anchor
const SLUG_SPRITE_SCALE := 0.09       # 628x767 art -> ~57x69 px

# -------------------------------------------------------------------- trail --
const TRAIL_POINTS_MAX := 90          # spec systems.trail.points_max
const TRAIL_FADE := 6.0               # spec systems.trail.fade_seconds
const TRAIL_WIDTH := 26.0             # spec systems.trail.width
const TRAIL_GLOW := true              # spec systems.trail.glow
const TRAIL_MIN_SEGMENT_PX := 6.0     # min slug travel before a new point
const TRAIL_GLOW_WIDTH_SCALE := 1.9   # glow ribbon width = width * this
const TRAIL_GLOW_ALPHA := 0.35
const TRAIL_MIN_WIDTH_FACTOR := 0.06  # tail never fully vanishes in width
const TRAIL_COLOR := Color(0.55, 0.95, 0.65, 1.0)
const TRAIL_GLOW_COLOR := Color(0.45, 1.0, 0.6)

# --------------------------------------------------------------------- bugs --
const BUG_FLEE_RADIUS := 120.0        # spec: flee when slug within 120px
const BUG_WANDER_SPEED := 60.0        # px/s
const BUG_FLEE_SPEED := 160.0         # px/s
const EAT_RADIUS := 34.0              # slug-within-this pops the bug
const BUG_COUNT_TARGET := 8           # spec: keep 6-9 active at once
const BUG_COUNT_MIN := 6
const BUG_COUNT_MAX := 9
const BUG_WANDER_TIME_MIN := 0.6      # s held per wander heading
const BUG_WANDER_TIME_MAX := 1.6
const BUG_SPRITE_SCALE := 0.062       # ~623x639 art -> ~39 px
const BUG_RADIUS := 18.0              # half-size used for bounds bounce
const BUG_POP_SCALE := 1.7            # pop tween scale-up factor
const BUG_POP_SEC := 0.18             # pop tween duration
const BUG_RESPAWN_DELAY_SEC := 1.2    # "respawn elsewhere after a beat"
const BUG_RESPAWN_MIN_DIST_PX := 160.0  # keep respawns away from the slug
const BUG_RESPAWN_TRY_N := 12

# -------------------------------------------------------------------- juice --
const SQUASH_MAX := 0.18              # stretch along velocity at full speed
const SQUASH_MIN := -0.12             # squash across velocity at full speed
const SQUASH_LERP_SPEED := 10.0
const FACING_LERP_SPEED := 8.0
const ANTENNA_WOBBLE_SEC := 0.35      # per swing of the wobble tween
const ANTENNA_BASE_OFFSET_PX := Vector2(15.0, 5.0)
const ANTENNA_TIP_SPREAD_PX := Vector2(13.0, 4.0)
const ANTENNA_WOBBLE_SWING_PX := 5.0
const ANTENNA_LINE_WIDTH := 2.0
const ANTENNA_TIP_RADIUS := 2.5
const ANTENNA_COLOR := Color(0.32, 0.55, 0.28)
const GARDEN_TILE_SCALE := 0.5        # garden tile drawn at half native size
const GARDEN_FALLBACK_COLOR := Color(0.10, 0.22, 0.12)
const DEBUG_COLOR := Color(0.9, 1.0, 0.9)

# ------------------------------------------ tilt input (scripts/tilt_source.gd) --
# Constants the verbatim gyro-squadron-45 tilt_source.gd references. Same
# pipeline, numbers re-tuned for a portrait slug instead of a plane.
const DEAD_ZONE := 0.06               # normalized input below this reads zero
const CURVE_EXPONENT := 2.0           # quadratic response, precise center
const SENSITIVITY := 1.35             # full deflection just past ~74% drag
const TILT_BLEND_GYRO := 0.15         # touch of gyroscope for responsiveness
const GRAVITY_NORM := 9.81            # m/s^2; gravity / this -> -1..1 tilt
const GYRO_NORM_SCALE := 2.0          # rad/s of gyro that counts as "full"
const OUTPUT_MAX := 1.0               # shaped output saturates here
const TOUCH_DRAG_RANGE_PX := 120.0    # finger travel equal to full deflection

# --------------------- milestone 2 (letters + words + scoring) ----------------
const WORD_LIST_PATH := "res://data/word_list.txt"  # spec spelling.word_source
const WORD_LEN_MIN := 3               # spec spelling.word_len_range
const WORD_LEN_MAX := 5
const WORD_LETTER_SPAWN_BIAS := 0.6   # spec spelling.letters_spawn_bias
const GOLD_BUG_WILDCARD := true       # spec bug_gold: any-letter wildcard
const GOLD_BUG_CHANCE := 0.08         # rare, on respawn
const GOLD_BUG_FLEE_MULT := 1.4       # "faster flee": 224 px/s vs slug 240
const SCORE_PER_BUG := 50             # spec score.per_bug
const SCORE_GOLD_BUG := 250           # spec score.gold_bug
const WORD_COMPLETE_BONUS := 500      # spec spelling.complete_bonus
const CHAIN_MULT_STEP := 0.5          # spec spelling.chain_words
const LETTER_FONT_SIZE := 22
const LETTER_LABEL_OFFSET_PX := Vector2(0.0, -30.0)
const LETTER_LABEL_BOX := Vector2(64.0, 28.0)  # centered label box above the bug
const LETTER_LABEL_COLOR := Color(0.94, 1.0, 0.92)
const GOLD_LETTER_LABEL_COLOR := Color(1.0, 0.86, 0.35)
const LETTER_OUTLINE_COLOR := Color(0.04, 0.11, 0.05)
const LETTER_OUTLINE_SIZE := 6

# HUD v1 — top strip, chunky outlined labels
const HUD_FONT_SIZE := 26
const HUD_OUTLINE_SIZE := 8
const HUD_TEXT_COLOR := Color(0.97, 1.0, 0.95)
const HUD_OUTLINE_COLOR := Color(0.03, 0.09, 0.04)
const HUD_SLOT_FONT_SIZE := 36
const HUD_SLOT_OUTLINE_SIZE := 10
const HUD_SLOT_FILLED_COLOR := Color(0.62, 1.0, 0.7)
const HUD_SLOT_EMPTY_COLOR := Color(0.55, 0.62, 0.55, 0.55)
const HUD_SLOT_GAP_PX := 8.0
const HUD_MARGIN_PX := 14.0
const HUD_STRIP_HEIGHT_PX := 118.0
const HUD_SLOT_EMPTY_GLYPH := "_"

# word juice
const WORD_SHAKE_PX := 7.0            # wrong-letter shake amplitude
const WORD_SHAKE_SWING_SEC := 0.045   # per left/right swing
const WORD_SHAKE_SWINGS := 4
const SLOT_POP_SCALE := 1.55          # just-filled slot pop
const SLOT_POP_SEC := 0.16
const LETTER_FLY_SEC := 0.34          # eaten letter flying to its HUD slot
const LETTER_FLY_FONT_SIZE := 30
const CONFETTI_COUNT := 18            # word-complete burst
const CONFETTI_SIZE_PX := Vector2(7.0, 11.0)
const CONFETTI_SPEED := 210.0
const CONFETTI_SEC := 0.6
const CONFETTI_COLORS := [
	Color(0.62, 1.0, 0.7), Color(1.0, 0.86, 0.35),
	Color(0.6, 0.9, 1.0), Color(1.0, 0.7, 0.85),
]

# ---------------- milestone 3 (salt + run loop + sfx + title + game over) -----
const SALT_RADIUS := 26.0             # kill radius of a crystal's heart
const SALT_SPRITE_SCALE := 0.13       # 388x417 art -> ~50x54 px, matches radius
const SALT_BASE_SPAWN_SEC := 6.0      # spec hazard.salt: rate rises with score
const SALT_MIN_SPAWN_SEC := 1.8
const SALT_RATE_PER_POINT := 0.004    # interval shrink per score point (500 ->
                                      # 4.0s, 1050 -> floor)
const SALT_SPAWN_GRACE_SEC := 14.0    # calm garden before the first crystal
                                      # (the clock also waits for a first
                                      # spelled word — see main._update_salt)
const SALT_MAX_COUNT := 12            # the field must stay winnable
const SALT_SPAWN_MIN_DIST_PX := 220.0 # crystals never appear this close to you
const SALT_SPAWN_TRY_N := 16
const SALT_EDGE_INSET_PX := 52.0      # crystals hug the walls, never mid-path
const SALT_POP_SEC := 0.3             # pop-in tween on spawn
const SALT_POP_SCALE := 1.7
const SALT_SPIN_SEC := 11.0           # slow menacing rotation
const SALT_WARN_COUNT := 5            # vignette warning at/above this count
const SALT_SHIVER_RADIUS := 150.0     # slug shivers inside this ring
const SALT_SHIVER_MAX_PX := 3.2       # sprite jitter at zero distance
const SALT_SHIVER_DECAY_PX_SEC := 24.0  # shiver eases off when the threat leaves
const SALT_DEATH_TINT := Color(0.82, 0.93, 1.0)  # the slug goes salt-white
const RUN_LIVES := 1                  # spec run.lives
const BEST_SCORE_SAVE_PATH := "user://best_score.save"
const SAVE_FORMAT_LINES := 3          # best \n runs_finished \n muted
const MASTER_VOLUME := 0.8

# sfx (scripts/sfx_manager.gd — procedural, synthesized at load)
const SFX_POOL_SIZE := 6              # 6-voice pool
const SFX_MIX_RATE := 22050
const SQUELCH_SPEED_FRAC := 0.45      # step blips past this fraction of max
const SQUELCH_STEP_SEC := 0.27        # between steps at full speed

# score fly + mult pulse + big confetti (word juice round 2)
const SCORE_FLY_FONT_SIZE := 26
const SCORE_FLY_SEC := 0.6
const SCORE_FLY_RISE_PX := 52.0
const SCORE_FLY_COLOR := Color(0.86, 1.0, 0.82)
const SCORE_FLY_GOLD_COLOR := Color(1.0, 0.86, 0.35)
const MULT_PULSE_SCALE := 1.45
const MULT_PULSE_SEC := 0.24
const CONFETTI_BIG_COUNT := 26        # second, screen-center burst
const CONFETTI_BIG_SPEED := 360.0
const CONFETTI_BIG_SEC := 0.85

# bug pop-in (spawn + respawn entrance)
const BUG_POP_IN_SEC := 0.24

# vignette (low-spec warning when the salt count runs high)
const VIGNETTE_THICKNESS_PX := 30.0
const VIGNETTE_COLOR := Color(0.95, 0.35, 0.3)
const VIGNETTE_MAX_ALPHA := 0.34
const VIGNETTE_PULSE_SEC := 0.7

# game over overlay
const GAME_OVER_LAYER := 20
const GAME_OVER_TITLE := "THE GARDEN REMEMBERS"
const GAME_OVER_TITLE_SIZE := 34
const GAME_OVER_STAT_SIZE := 26
const GAME_OVER_HINT := "[ TAP TO RETRY ]"
const GAME_OVER_DIM := Color(0.02, 0.07, 0.03, 0.82)
const GAME_OVER_TITLE_COLOR := Color(0.95, 0.99, 0.92)
const GAME_OVER_ACCENT_COLOR := Color(0.62, 1.0, 0.7)
const GAME_OVER_PULSE_SEC := 0.85

# title screen
const TITLE_SCENE_PATH := "res://scenes/title.tscn"
const GAME_SCENE_PATH := "res://scenes/main.tscn"
const TITLE_LOGO_WIDTH_PX := 440.0
const TITLE_LOGO_Y := 330.0
const TITLE_TAP_TEXT := "TAP TO SLITHER"
const TITLE_TAP_SIZE := 30
const TITLE_TAP_Y := 660.0
const TITLE_VERSION_STAMP := "Humboldt Jam '26 · Slugs n' Bugs"
const TITLE_STAMP_SIZE := 18
const TITLE_STAMP_Y := 906.0
const TITLE_TEXT_COLOR := Color(0.95, 1.0, 0.93)
const TITLE_PULSE_SEC := 0.95
const TITLE_LOGO_BOB_PX := 9.0
const TITLE_LOGO_BOB_SEC := 2.6
const TITLE_BUG_COUNT := 5
const TITLE_DRIFT_TURN_SEC := 7.0     # Lissajous period of the drifting slug

# run HUD
const RUN_LABEL_FORMAT := "RUN %d"
const BEST_LABEL_FORMAT := "BEST %d"

# -------------------------------------------------------------------- debug --
const DEBUG_SAMPLE_EVERY_N_FRAMES := 10
