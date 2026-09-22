extends SceneTree
## Milestone 1 battery — SLUG CORE (glide + slime trail + bugs + eating).
## Run headless:
##   godot --headless --path . --script res://tests/m1_tests.gd
## Done = 2x consecutive green (spec law "growing_battery").

const SLUG_SCENE := preload("res://scenes/slug.tscn")
const BUG_SCENE := preload("res://scenes/bug.tscn")
const DT := 1.0 / 60.0
const EPS := 1e-4
const PLAY := Rect2(0, 0, 540, 960)

var passes := 0
var fails := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	# --- glide math: accel, drag, clamp --------------------------------------
	var v := Slug.glide_velocity(Vector2.ZERO, Vector2.RIGHT, DT)
	check("glide_accel_from_rest_one_frame",
		near(v.x, Feel.GLIDE_ACCEL * DT) and v.y == 0.0, "v=%s" % v)

	v = Slug.glide_velocity(Vector2(100.0, 0.0), Vector2.ZERO, DT)
	check("glide_drag_decays_one_frame", near(v.x, 100.0 * Feel.DRAG), "v=%f" % v.x)

	v = Vector2(100.0, 0.0)
	for i in 120:
		v = Slug.glide_velocity(v, Vector2.ZERO, DT)
	check("glide_drag_coast_decays_toward_zero", v.x > 0.0 and v.x < 1.0, "v=%f" % v.x)

	v = Slug.glide_velocity(Vector2(239.0, 0.0), Vector2.RIGHT, DT)
	check("glide_clamps_to_max_speed", near(v.length(), Feel.MAX_SPEED), "v=%f" % v.length())

	v = Slug.glide_velocity(Vector2(200.0, 200.0), Vector2(1.0, 1.0), DT)
	check("glide_clamps_diagonal_too", near(v.length(), Feel.MAX_SPEED), "v=%f" % v.length())

	v = Slug.glide_velocity(Vector2(-100.0, 0.0), Vector2.RIGHT, DT)
	check("glide_brakes_against_momentum",
		near(v.x, -100.0 * Feel.DRAG + Feel.GLIDE_ACCEL * DT) and v.y == 0.0, "v=%f" % v.x)

	# --- bounds ---------------------------------------------------------------
	var p := Slug.clamp_to_bounds(Vector2(-50.0, 1000.0), PLAY, Feel.SLUG_BOUNDS_MARGIN_PX)
	check("bounds_clamps_outside_inside",
		near(p.x, Feel.SLUG_BOUNDS_MARGIN_PX) and near(p.y, PLAY.size.y - Feel.SLUG_BOUNDS_MARGIN_PX),
		"p=%s" % p)
	p = Slug.clamp_to_bounds(Vector2(270.0, 480.0), PLAY, Feel.SLUG_BOUNDS_MARGIN_PX)
	check("bounds_leaves_interior_untouched", p == Vector2(270.0, 480.0), "p=%s" % p)

	# --- trail: append, cap, age, fade, drop ----------------------------------
	var trail := SlimeTrail.new()
	trail.push_head(Vector2.ZERO)
	trail.push_head(Vector2(1.0, 0.0))  # under TRAIL_MIN_SEGMENT_PX: ignored
	check("trail_min_segment_skips_micro_moves", trail.point_count() == 1,
		"n=%d" % trail.point_count())

	for i in 5:
		trail.push_head(Vector2(20.0 * float(i + 1), 0.0))
	check("trail_appends_points_head_last",
		trail.point_count() == 6 and trail.head_position() == Vector2(100.0, 0.0),
		"n=%d head=%s" % [trail.point_count(), trail.head_position()])

	trail.update(1.0)
	check("trail_ages_advance_and_survive_partial_fade",
		near(trail.age_at(0), 1.0) and trail.point_count() == 6,
		"age=%f n=%d" % [trail.age_at(0), trail.point_count()])

	trail.update(Feel.TRAIL_FADE)
	check("trail_drops_after_full_fade", trail.point_count() == 0,
		"n=%d" % trail.point_count())

	for i in 200:
		trail.push_head(Vector2(20.0 * float(i), 0.0))
	check("trail_caps_at_points_max",
		trail.point_count() == Feel.TRAIL_POINTS_MAX
			and trail.head_position() == Vector2(3980.0, 0.0),
		"n=%d head=%s" % [trail.point_count(), trail.head_position()])
	check("trail_glow_line_is_additive_behind",
		trail._glow != null
			and trail._glow.material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD,
		"glow=%s" % trail._glow)
	trail.free()

	# --- bug: wander / flee / eat / respawn -----------------------------------
	var slug: Slug = SLUG_SCENE.instantiate()
	slug.bounds = PLAY
	root.add_child(slug)
	slug.global_position = Vector2(270.0, 480.0)
	await physics_frame

	var bug: Bug = BUG_SCENE.instantiate()
	bug.slug = null  # wander only, no slug to flee
	bug.bounds = PLAY
	bug.rng.seed = 20260922
	bug.global_position = Vector2(270.0, 300.0)
	root.add_child(bug)
	var wander_start := bug.global_position
	for i in 40:
		await physics_frame
	check("bug_wander_changes_position",
		bug.global_position.distance_to(wander_start) > 5.0,
		"moved=%f" % bug.global_position.distance_to(wander_start))

	var chaser: Slug = SLUG_SCENE.instantiate()
	chaser.bounds = PLAY
	root.add_child(chaser)
	chaser.global_position = bug.global_position + Vector2(100.0, 0.0)  # inside 120
	bug.slug = chaser
	await physics_frame
	check("bug_flee_state_engaged_within_radius", bug.state == Bug.State.FLEE,
		"state=%d" % bug.state)
	var away := (bug.global_position - chaser.global_position).normalized()
	var flee_start := bug.global_position
	for i in 30:
		await physics_frame
	var moved := bug.global_position - flee_start
	check("bug_flee_runs_away_from_slug", moved.dot(away) > 10.0,
		"moved=%s away=%s" % [moved, away])

	chaser.global_position = bug.global_position + Vector2(400.0, 0.0)  # beyond 120
	for i in 10:
		await physics_frame
	check("bug_calm_beyond_flee_radius", bug.state == Bug.State.WANDER,
		"state=%d" % bug.state)

	var eaten_bugs: Array[Bug] = []
	bug.eaten.connect(func(b: Bug) -> void: eaten_bugs.append(b))
	chaser.global_position = bug.global_position  # overlap -> eat
	for i in 3:
		await physics_frame
	check("bug_eat_pops_and_signals",
		eaten_bugs.size() == 1 and bug.state == Bug.State.POPPED and not bug.is_active(),
		"signals=%d state=%d" % [eaten_bugs.size(), bug.state])

	var eaten_at := bug.global_position
	await create_timer(Feel.BUG_RESPAWN_DELAY_SEC + 0.6).timeout
	check("bug_respawns_after_beat",
		bug.is_active() and bug.global_position.distance_to(eaten_at) > 50.0
			and PLAY.has_point(bug.global_position),
		"active=%s pos=%s" % [bug.is_active(), bug.global_position])

	check("eat_radius_boundary_case",
		Bug.in_eat_range(Feel.EAT_RADIUS) and not Bug.in_eat_range(Feel.EAT_RADIUS + 0.01),
		"at=%s beyond=%s" % [Bug.in_eat_range(Feel.EAT_RADIUS), Bug.in_eat_range(Feel.EAT_RADIUS + 0.01)])

	# --- slug integration: driven through the real touch pipeline --------------
	slug.feed_touch_begin(0.0, 0.0)
	slug.feed_touch_move(Feel.TOUCH_DRAG_RANGE_PX, 0.0)  # full-right drag
	for i in 90:
		await physics_frame
	slug.feed_touch_end()
	check("slug_glide_reaches_speed_and_stays_in_bounds",
		slug.velocity.length() <= Feel.MAX_SPEED + 1.0
			and slug.velocity.length() > Feel.MAX_SPEED * 0.5
			and PLAY.has_point(slug.global_position),
		"v=%f pos=%s" % [slug.velocity.length(), slug.global_position])
	check("slug_trail_tracks_movement", slug.trail.point_count() >= 5,
		"n=%d" % slug.trail.point_count())

	slug.free()
	chaser.free()
	bug.free()

	print("")
	print("RESULT: %d passed, %d failed" % [passes, fails])
	quit(0 if fails == 0 else 1)


func check(name: String, ok: bool, detail := "") -> void:
	if ok:
		passes += 1
		print("PASS: " + name)
	else:
		fails += 1
		print("FAIL: " + name + "  (" + detail + ")")


func near(a: float, b: float) -> bool:
	return absf(a - b) < EPS
