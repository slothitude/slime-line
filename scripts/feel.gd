class_name Feel
## SLIME LINE — every feel number lives here.
## Spec law "constants_not_magic": no tuned number anywhere else in the project.
## Milestone 1 (SLUG CORE) uses movement + trail + bugs; letter/word/salt/score
## consts are reserved for milestones 2-3 and match spec/jam_spec.json.

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

# --------------------- reserved: milestone 2 (letters + words + scoring) ------
const WORD_LEN_MIN := 3               # spec spelling.word_len_range
const WORD_LEN_MAX := 5
const WORD_LETTER_SPAWN_BIAS := 0.6   # spec spelling.letters_spawn_bias
const GOLD_BUG_WILDCARD := true       # spec bug_gold: any-letter wildcard
const SCORE_PER_BUG := 50             # spec score.per_bug
const SCORE_GOLD_BUG := 250           # spec score.gold_bug
const WORD_COMPLETE_BONUS := 500      # spec spelling.complete_bonus
const CHAIN_MULT_STEP := 0.5          # spec spelling.chain_words
const LETTER_FONT_SIZE := 22
const LETTER_LABEL_OFFSET_PX := Vector2(0.0, -30.0)

# ------------------------- reserved: milestone 3 (salt + run + sfx) -----------
const SALT_RADIUS := 26.0
const SALT_BASE_SPAWN_SEC := 6.0      # spec hazard.salt: rate rises with score
const SALT_MIN_SPAWN_SEC := 1.8
const RUN_LIVES := 1                  # spec run.lives
const BEST_SCORE_SAVE_PATH := "user://best_score.save"
const MASTER_VOLUME := 0.8

# -------------------------------------------------------------------- debug --
const DEBUG_SAMPLE_EVERY_N_FRAMES := 10
