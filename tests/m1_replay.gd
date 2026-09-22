extends SceneTree
## Milestone 1 replay — a scripted 12s drag-path (circle + zigzag + chase)
## driven through the real main scene and the real TiltSource touch pipeline.
## Gate: no errors, several bugs eaten, trail present throughout.
##   godot --headless --path . --script res://tests/m1_replay.gd

const DT := 1.0 / 60.0
const DURATION_SEC := 12.0
const MIN_EATS := 2

var _eats := 0
var _target: Bug = null
var _target_since := 0.0
var _best_dist := INF


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	# Headless DisplayServer reports a 960x960 dummy window; pin the root to the
	# design canvas so the replay exercises the real portrait play area.
	root.size = Vector2i(540, 960)
	var main: Node2D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var slug: Slug = main.get_node("Slug")
	for b in get_nodes_in_group("bugs"):
		b.eaten.connect(func(_bug: Bug) -> void: _eats += 1)

	slug.feed_touch_begin(0.0, 0.0)
	var t := 0.0
	var frames := 0
	var trail_gaps := 0
	var max_points := 0
	while t < DURATION_SEC:
		var dir := _steer(t, slug)
		slug.feed_touch_move(dir.x * Feel.TOUCH_DRAG_RANGE_PX, dir.y * Feel.TOUCH_DRAG_RANGE_PX)
		await physics_frame
		t += DT
		frames += 1
		if slug.trail != null:
			max_points = maxi(max_points, slug.trail.point_count())
			if t > 0.5 and slug.trail.point_count() == 0:
				trail_gaps += 1
	slug.feed_touch_end()

	print("REPLAY: frames=%d eats=%d trail_gaps=%d max_trail_points=%d slug_end=%s" % [
		frames, _eats, trail_gaps, max_points, slug.global_position])
	var ok := true
	if _eats < MIN_EATS:
		print("REPLAY FAIL: expected >= %d eats, got %d" % [MIN_EATS, _eats])
		ok = false
	if trail_gaps != 0:
		print("REPLAY FAIL: trail vanished %d time(s) after t>0.5" % trail_gaps)
		ok = false
	if frames < int(DURATION_SEC / DT * 0.5):  # sanity: the loop really advanced
		print("REPLAY FAIL: only %d frames advanced" % frames)
		ok = false
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


## Phase 1 (0-2s): circle. Phase 2 (2-4s): zigzag. Phase 3 (4-12s): chase —
## commit to one bug and pursue it (re-aim only if it dies or we stop closing
## for 2.5s). The chase needs most of the window: a fleeing bug only loses
## 80 px/s of ground to the slug (240 vs 160), reacts only inside
## Feel.BUG_FLEE_RADIUS, and each eat is followed by travel to the respawned
## bug. Frame-by-frame nearest-re-aim thrashed between bugs and caught less.
func _steer(t: float, slug: Slug) -> Vector2:
	if t < 2.0:
		var a := t * TAU / 2.0
		return Vector2(cos(a), sin(a))
	if t < 4.0:
		var zig := Vector2(1.0, 0.0)
		if fmod(t, 1.4) >= 0.7:
			zig.x = -1.0
		zig.y = 0.5 if fmod(t, 2.8) < 1.4 else -0.5
		_target = null
		return zig.normalized()
	if _target == null or not is_instance_valid(_target) or not _target.is_active():
		_target = _nearest_bug(slug, null)
		_target_since = t
		_best_dist = INF
	var d := _target.global_position.distance_to(slug.global_position)
	if d < _best_dist - 2.0:
		_best_dist = d
		_target_since = t  # closing: keep the commitment
	elif t - _target_since > 2.5:
		_target = _nearest_bug(slug, _target)  # stuck: switch bugs
		_target_since = t
		_best_dist = INF
		if _target == null:
			return Vector2.ZERO
	return (_target.global_position - slug.global_position).normalized()


func _nearest_bug(slug: Slug, exclude: Bug) -> Bug:
	var best: Bug = null
	var best_d := INF
	for b in get_nodes_in_group("bugs"):
		if b is Bug and b.is_active() and b != exclude:
			var d: float = b.global_position.distance_to(slug.global_position)
			if d < best_d:
				best_d = d
				best = b
	return best
