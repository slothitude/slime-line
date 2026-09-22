extends SceneTree
## Milestone 3 replay — the whole journey through the real scenes:
##   title (tap to slither) -> game -> eat/spell TWO words -> salt death
##   -> THE GARDEN REMEMBERS -> tap RETRY (full reset, RUN 2) -> title.
## Gate: every beat lands, no errors.
##   godot --headless --fixed-fps 60 --path . --script res://tests/m3_replay.gd
##
## --fixed-fps 60 note (applies to all three replays): the replays steer once
## per physics frame, so wall-clock frame pacing perturbs them — a slow frame
## makes the engine catch up with several physics steps between steering
## updates. M3's heavier first frame (the SfxManager synthesizing its 8 cues)
## shifted every run into a slightly worse chase. Pinned pacing makes the runs
## deterministic and byte-identical to the M2-era simulation (verified against
## a pristine M2 code copy), so the same invocation is used for m1/m2 replays.
##
## Scenario scripting (same spirit as m1/m2 replays): global + engine RNGs are
## pinned, the word is re-dealt to a mid-band 4-letter word, initial bug
## letters re-rolled once through the REAL bias law, and the salt clock is HELD
## during the scripted spell phase (a crystal arriving mid-script would make
## the word-count gate a coin flip). The salt then kills for real: a crystal is
## spawned through main's own spawner on the slug's position and the touch
## sweep does the rest. Persistence is pointed at a throwaway save so the
## player's real best is never touched.

const DT := 1.0 / 60.0
const SPELL_MAX_SEC := 50.0
const MIN_WORDS := 2
const MIN_EATS := 6
const SCRIPT_SEED := 20260922
const PURSUE_SCORE_MAX := 250.0
const TEST_SAVE := "m3_replay_tmp.save"

var _eats := 0
var _target: Bug = null
var _target_since := 0.0
var _best_score := INF
var _play_area := Rect2(0, 0, 540, 960)
var _need_at := ""
var _prog_at := 0
var _t := 0.0
var _last_target_pos := Vector2.ZERO
var _have_last_pos := false


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	# Headless DisplayServer reports a dummy window; pin the root to the design
	# canvas so the journey runs on the real portrait play area.
	root.size = Vector2i(540, 960)
	seed(SCRIPT_SEED)
	_wipe_test_save()

	# ------------------------------------------------------------- 1. title --
	var title: Node2D = (load(Feel.TITLE_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(title)
	current_scene = title
	await process_frame
	await process_frame
	var logo: Sprite2D = title.get_node("Logo")
	var slug_on_title: Slug = title._slug
	var title_pos := slug_on_title.global_position
	for i in 30:
		await physics_frame
	var drifted := slug_on_title.global_position.distance_to(title_pos) > 3.0
	print("REPLAY: title up — logo=%s slug_drift=%s" % [logo != null, drifted])
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	tap.position = Vector2(270.0, 700.0)
	title._unhandled_input(tap)  # the real tap-to-start handler
	var main := await _wait_for_main()
	if main == null:
		print("REPLAY FAIL: tap to slither never opened the garden")
		quit(1)
		return
	print("REPLAY: garden open — t=0 run=%d" % main.run_state.next_run_number())

	# ------------------------------------------------- 2. spell two words --
	main.run_state.save_path = "user://" + TEST_SAVE
	main.run_state.load_state()
	var engine: WordEngine = main.engine
	engine.rng.seed = SCRIPT_SEED
	for guard in 40:
		if engine.new_word().length() == 4:
			break
	for b in get_nodes_in_group("bugs"):
		b.roll_letter()
	main._salt_cooldown = 1e9  # scenario scripting: the salt waits out the script
	print("REPLAY: target word %s (salt held)" % engine.target)

	var slug: Slug = main.get_node("Slug")
	for b in get_nodes_in_group("bugs"):
		b.eaten.connect(func(bug: Bug) -> void:
			_eats += 1
			print("REPLAY eat t=%.1f: letter='%s' gold=%s need_was='%s' prog_was=%d -> prog=%d score=%d" % [
				_t, bug.letter, bug.is_gold, _need_at, _prog_at, engine.progress, engine.score]))

	slug.feed_touch_begin(0.0, 0.0)
	var frames := 0
	var trail_gaps := 0
	while _t < SPELL_MAX_SEC and engine.words_completed < MIN_WORDS:
		_need_at = engine.next_letter()
		_prog_at = engine.progress
		var dir := _steer(_t, slug, engine)
		slug.feed_touch_move(dir.x * Feel.TOUCH_DRAG_RANGE_PX, dir.y * Feel.TOUCH_DRAG_RANGE_PX)
		await physics_frame
		_t += DT
		frames += 1
		if slug.trail != null and _t > 0.5 and slug.trail.point_count() == 0:
			trail_gaps += 1
	slug.feed_touch_end()
	print("REPLAY: spelled %d word(s), %d eats, mult %.1f, score %d in %.1fs (frames=%d gaps=%d)" % [
		engine.words_completed, _eats, engine.chain_mult, engine.score, _t, frames, trail_gaps])

	# ------------------------------------------------------- 3. salt death --
	if main.is_dead():
		print("REPLAY FAIL: the slug died before the scripted salt beat")
		quit(1)
		return
	var score_at_death: int = engine.score
	var mult_at_death: float = engine.chain_mult
	main.spawn_salt_at(slug.global_position)
	var died := false
	for i in int(2.0 / DT):
		await physics_frame
		if main.is_dead():
			died = true
			break
	print("REPLAY: salt death — dead=%s score=%d best=%d runs=%d" % [
		died, engine.score, main.run_state.best, main.run_state.runs_finished])

	# -------------------------------------------------- 4. the garden remembers --
	var overlay_ok: bool = died and main.game_over != null \
		and main.game_over._score_label.text == "SCORE %d" % score_at_death \
		and main.game_over._best_label.text == Feel.BEST_LABEL_FORMAT % score_at_death \
		and main.game_over._run_label.text == Feel.RUN_LABEL_FORMAT % 1 \
		and engine.chain_mult == 1.0
	print("REPLAY: overlay — %s | %s | %s (chain reset to %.1f)" % [
		main.game_over._score_label.text if main.game_over != null else "?",
		main.game_over._best_label.text if main.game_over != null else "?",
		main.game_over._run_label.text if main.game_over != null else "?",
		engine.chain_mult])

	# ---------------------------------------------------------- 5. tap RETRY --
	var retry_tap := InputEventScreenTouch.new()
	retry_tap.pressed = true
	retry_tap.position = Vector2(270.0, 480.0)
	main.game_over._on_dim_input(retry_tap)  # the real tap-anywhere handler
	var retry := await _wait_for_main(main)
	if retry == null:
		print("REPLAY FAIL: retry never rebuilt the garden")
		quit(1)
		return
	for i in 4:
		await process_frame
	retry.run_state.save_path = "user://" + TEST_SAVE  # read the same throwaway
	retry.run_state.load_state()                       # state the death wrote
	var retry_ok: bool = retry != main and not retry.is_dead() \
		and retry.engine.score == 0 and retry.engine.chain_mult == 1.0 \
		and retry.engine.progress == 0 and retry.salt_count() == 0 \
		and retry.run_state.best == score_at_death \
		and retry.run_state.next_run_number() == 2
	print("REPLAY: retry — fresh run=%d best=%d score=%d salts=%d" % [
		retry.run_state.next_run_number(), retry.run_state.best,
		retry.engine.score, retry.salt_count()])

	# ------------------------------------------------------------ 6. title --
	current_scene = retry
	var err := change_scene_to_file(Feel.TITLE_SCENE_PATH)
	var back := await _wait_for_title()
	print("REPLAY: back to title — %s (err=%d)" % [back != null, err])

	var ok := true
	if not drifted:
		print("REPLAY FAIL: the title slug never drifted")
		ok = false
	if engine.words_completed < MIN_WORDS:
		print("REPLAY FAIL: expected >= %d words, got %d" % [MIN_WORDS, engine.words_completed])
		ok = false
	if _eats < MIN_EATS:
		print("REPLAY FAIL: expected >= %d eats, got %d" % [MIN_EATS, _eats])
		ok = false
	if trail_gaps != 0:
		print("REPLAY FAIL: trail vanished %d time(s) after t>0.5" % trail_gaps)
		ok = false
	if not died:
		print("REPLAY FAIL: salt never killed the slug")
		ok = false
	if not overlay_ok:
		print("REPLAY FAIL: game-over overlay did not tell the story")
		ok = false
	if not retry_ok:
		print("REPLAY FAIL: retry was not a full reset on RUN 2")
		ok = false
	if back == null:
		print("REPLAY FAIL: never made it back to the title")
		ok = false
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


# ------------------------------------------------------------- journey glue --

## The garden opens deferred (change_scene); wait for whichever Main shows up.
func _wait_for_main(old: Node = null) -> Node2D:
	for i in int(5.0 / DT):
		await process_frame
		var candidate := current_scene
		if candidate is Node2D and candidate != old and candidate.has_method("spawn_salt_at"):
			return candidate
		for child in root.get_children():
			if child is Node2D and child != old and child.has_method("spawn_salt_at"):
				return child
	return null


func _wait_for_title() -> Node2D:
	for i in int(5.0 / DT):
		await process_frame
		if current_scene != null and current_scene.has_method("start_game"):
			return current_scene
	return null


func _wipe_test_save() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(TEST_SAVE):
		dir.remove(TEST_SAVE)


# ------------------------------------------- the m2 spell-run steering brain --
## Spell-run: commit to the most catchable bug that carries what the Word
## needs next (distance + corner distance), lead the target's measured
## velocity, graze the nearest bug when a pursuit gets expensive — the 60/40
## respawn bias refreshes the field. (Proven across the m2 replay's 10/10.)

func _steer(t: float, slug: Slug, engine: WordEngine) -> Vector2:
	if _target == null or not is_instance_valid(_target) or not _target.is_active() \
			or not _bug_still_needed(_target, engine):
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
	else:
		var better := _best_useful_bug(slug, engine, _target, 0.75)
		if better != null:
			_target = better
			_best_score = INF
			_have_last_pos = false
			aim = _target.global_position
		elif t - _target_since > 3.0:
			_target = null
			return _steer(t, slug, engine)
	return (aim + vel * 0.35 - slug.global_position).normalized()


func _bug_still_needed(bug: Bug, engine: WordEngine) -> bool:
	if bug.is_gold:
		return true
	return engine.is_needed(bug.letter)


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
			if b.is_gold or b.letter != need:
				continue
			var s := _catch_score(slug, b)
			if s < best_score and s < cur_score:
				best_score = s
				best = b
	return best


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
