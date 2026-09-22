extends SceneTree
## Milestone 2 replay — a scripted 20s spell-run through the real main scene:
## the slug hunts bugs carrying the NEXT NEEDED LETTER, eats its way through
## the target word, and completes at least one word.
## Gate: >= 1 word completed, several eats, no trail gaps, no errors.
##   godot --headless --path . --script res://tests/m2_replay.gd
##
## Scenario scripting (for reproducibility, same spirit as m1_replay's fixed
## drag path): the global + engine RNGs are pinned and the target word is
## re-dealt to a mid-band 4-letter word (spec band is 3-5). Initial bug letters
## are re-rolled once through the REAL bias law. Everything else — pursuits,
## the 60/40 spawn bias on respawns, in-order spelling, scoring, HUD, trail —
## runs exactly as in play. Unscripted 5-letter words are winnable but sit at
## the edge of the 20s window (a cornered bug takes ~3-5s to pin and catch),
## so a random-length word made the gate a coin flip rather than a test.

const DT := 1.0 / 60.0
const DURATION_SEC := 20.0
const MIN_EATS := 5
const MIN_WORDS := 1
const SCRIPT_SEED := 20260922
const PURSUE_SCORE_MAX := 250.0  # beyond this, grazing to refresh the field
                                 # (60% respawn toward the needed letter) beats
                                 # a long, slow pursuit

var _eats := 0
var _words := 0
var _target: Bug = null
var _target_since := 0.0
var _best_score := INF
var _play_area := Rect2(0, 0, 540, 960)   # the design canvas (root is pinned)
var _need_at := ""      # need-letter snapshot each frame, for eat tracing
var _prog_at := 0
var _t := 0.0
var _last_target_pos := Vector2.ZERO
var _have_last_pos := false


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	# Headless DisplayServer reports a 960x960 dummy window; pin the root to the
	# design canvas so the replay exercises the real portrait play area.
	root.size = Vector2i(540, 960)
	seed(SCRIPT_SEED)  # main's random spawn points become reproducible
	var main: Node2D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var slug: Slug = main.get_node("Slug")
	var engine: WordEngine = main.engine

	# Pin the word deal: re-roll until a 4-letter word shows up (mid-band of the
	# spec's 3-5 range), then re-roll the initial field's letters once through
	# the real spawn-bias law so they match the pinned word.
	engine.rng.seed = SCRIPT_SEED
	for guard in 40:
		if engine.new_word().length() == 4:
			break
	for b in get_nodes_in_group("bugs"):
		b.roll_letter()
	print("REPLAY: target word %s" % engine.target)

	for b in get_nodes_in_group("bugs"):
		b.eaten.connect(func(bug: Bug) -> void:
			_eats += 1
			print("REPLAY eat t=%.1f: letter='%s' gold=%s need_was='%s' prog_was=%d -> prog=%d score=%d" % [
				_t, bug.letter, bug.is_gold, _need_at, _prog_at, engine.progress, engine.score]))

	slug.feed_touch_begin(0.0, 0.0)
	var t := 0.0
	var frames := 0
	var trail_gaps := 0
	var max_points := 0
	while t < DURATION_SEC:
		_need_at = engine.next_letter()
		_prog_at = engine.progress
		_t = t
		var dir := _steer(t, slug, engine)
		slug.feed_touch_move(dir.x * Feel.TOUCH_DRAG_RANGE_PX, dir.y * Feel.TOUCH_DRAG_RANGE_PX)
		await physics_frame
		t += DT
		frames += 1
		_words = engine.words_completed
		if slug.trail != null:
			max_points = maxi(max_points, slug.trail.point_count())
			if t > 0.5 and slug.trail.point_count() == 0:
				trail_gaps += 1
	slug.feed_touch_end()

	print(("REPLAY: frames=%d eats=%d words_completed=%d mult=%.1f score=%d " \
		+ "trail_gaps=%d max_trail_points=%d slug_end=%s") % [
			frames, _eats, _words, engine.chain_mult, engine.score,
			trail_gaps, max_points, slug.global_position])
	var ok := true
	if _words < MIN_WORDS:
		print("REPLAY FAIL: expected >= %d word(s) completed, got %d" % [MIN_WORDS, _words])
		ok = false
	if _eats < MIN_EATS:
		print("REPLAY FAIL: expected >= %d eats, got %d" % [MIN_EATS, _eats])
		ok = false
	if trail_gaps != 0:
		print("REPLAY FAIL: trail vanished %d time(s) after t>0.5" % trail_gaps)
		ok = false
	if frames < int(DURATION_SEC / DT * 0.5):  # sanity: the loop really advanced
		print("REPLAY FAIL: only %d frames advanced" % frames)
		ok = false
	if engine.score <= 0:
		print("REPLAY FAIL: score never moved")
		ok = false
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


## Spell-run: commit to the most catchable bug that carries what the Word
## needs next. Catchability = distance + CORNER distance (a fleeing bug is
## pinned where two walls meet; mid-field bugs must be herded to a corner
## first, which is where the seconds go). Aim is led along the target's
## measured velocity to cut off wall-sliders. A useful bug is pursued only
## while it is cheap; past PURSUE_SCORE_MAX the slug grazes the nearest bug
## instead, which refreshes the field (60% of respawns roll the needed
## letter). Switch targets only when another useful bug scores < 75% of the
## current one (hysteresis — frame-by-frame nearest-switching thrashed in
## m1), or immediately when the target dies or the needed letter changes.
func _steer(t: float, slug: Slug, engine: WordEngine) -> Vector2:
	if _target == null or not is_instance_valid(_target) or not _target.is_active() \
			or not _bug_still_needed(_target, engine):
		# Acquire: a cheap useful bug is pursued; otherwise graze the nearest
		# bug — a graze is never wasted, because its respawn rolls 60% toward
		# the needed letter and refreshes a stale field faster than a long,
		# slow slog across it (this is the deadlock breaker).
		var useful := _best_useful_bug(slug, engine, null, 1.0)
		if useful != null and _catch_score(slug, useful) <= PURSUE_SCORE_MAX:
			_target = useful
		else:
			_target = _nearest_bug(slug, null)
		_target_since = t
		_best_score = INF
		_have_last_pos = false
	if _target == null:
		return Vector2.ZERO
	var aim := _target.global_position
	var vel := Vector2.ZERO
	if _have_last_pos:
		vel = (_target.global_position - _last_target_pos) / DT
	_last_target_pos = _target.global_position
	_have_last_pos = true
	var score := _catch_score(slug, _target)
	if score < _best_score - 2.0:
		_best_score = score
		_target_since = t
	else:  # opportunistically re-aim if something USEFUL became much cheaper
		var better := _best_useful_bug(slug, engine, _target, 0.75)
		if better != null:
			_target = better
			_best_score = INF
			_have_last_pos = false
			aim = _target.global_position
		elif t - _target_since > 3.0:  # stuck: re-acquire
			_target = null
			return _steer(t, slug, engine)
	# lead the moving target by ~0.35s of its measured velocity
	return (aim + vel * 0.35 - slug.global_position).normalized()


## The needed letter can change mid-pursuit (we ate it, or a wildcard did) —
## a bug that no longer carries anything useful is dropped immediately.
func _bug_still_needed(bug: Bug, engine: WordEngine) -> bool:
	if bug.is_gold:
		return true
	return engine.is_needed(bug.letter)


## See _steer(): distance plus corner distance.
func _catch_score(slug: Slug, bug: Bug) -> float:
	var area := _play_area
	var corner := 0.0
	if area.size != Vector2.ZERO:
		corner = INF
		for c in [
			area.position, Vector2(area.end.x, area.position.y),
			area.end, Vector2(area.position.x, area.end.y)]:
			corner = minf(corner, bug.global_position.distance_to(c))
	return bug.global_position.distance_to(slug.global_position) + corner


func _best_useful_bug(slug: Slug, engine: WordEngine, exclude: Bug, factor: float) -> Bug:
	var need := engine.next_letter()
	var best: Bug = null
	var best_score := INF
	var cur_score := _best_score * factor
	for b in get_nodes_in_group("bugs"):
		if b is Bug and b.is_active() and b != exclude:
			# gold flees at 224 px/s (nearly slug speed) — never pursue it;
			# a gold that blunders into the pursuit is caught for free anyway
			if not b.is_gold and b.letter != need:
				continue
			if b.is_gold:
				continue
			var s := _catch_score(slug, b)
			if s < best_score and s < cur_score:
				best_score = s
				best = b
	return best


## Nearest active bug of any letter — the graze target for field refresh.
func _nearest_bug(slug: Slug, exclude: Bug) -> Bug:
	var best: Bug = null
	var d := INF
	for b in get_nodes_in_group("bugs"):
		if b is Bug and b.is_active() and b != exclude:
			var dd: float = b.global_position.distance_to(slug.global_position)
			if dd < d:
				d = dd
				best = b
	return best
