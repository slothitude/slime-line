extends SceneTree
## Milestone 3 battery — SALT + RUN LOOP + PERSISTENCE + SFX + TITLE.
## Run headless:
##   godot --headless --path . --script res://tests/m3_tests.gd
## Done = 2x consecutive green alongside m1 (23) and m2 (22), both untouched
## (spec law "growing_battery").

const MAIN_SCENE := preload("res://scenes/main.tscn")
const TITLE_SCENE := preload("res://scenes/title.tscn")
const TEST_SAVE := "m3_tests_tmp.save"   # hermetic: never touches the real best

var passes := 0
var fails := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_wipe_test_save()

	# --- salt laws (pure statics) ---------------------------------------------
	check("salt_spawn_interval_rises_with_score",
		Salt.spawn_interval(0) == Feel.SALT_BASE_SPAWN_SEC
			and Salt.spawn_interval(5000) == Feel.SALT_MIN_SPAWN_SEC
			and Salt.spawn_interval(250) < Salt.spawn_interval(100)
			and Salt.spawn_interval(-50) == Feel.SALT_BASE_SPAWN_SEC,
		"i0=%f i250=%f i100=%f imax=%f" % [Salt.spawn_interval(0),
			Salt.spawn_interval(250), Salt.spawn_interval(100), Salt.spawn_interval(5000)])
	check("salt_kill_range_touch_cases",
		Salt.in_kill_range(Feel.SALT_RADIUS + Feel.SLUG_BODY_RADIUS, Feel.SLUG_BODY_RADIUS)
			and not Salt.in_kill_range(
				Feel.SALT_RADIUS + Feel.SLUG_BODY_RADIUS + 0.01, Feel.SLUG_BODY_RADIUS)
			and Salt.in_kill_range(Feel.SALT_RADIUS + Feel.BUG_RADIUS, Feel.BUG_RADIUS)
			and not Salt.in_kill_range(
				Feel.SALT_RADIUS + Feel.BUG_RADIUS + 1.0, Feel.BUG_RADIUS),
		"slug@edge=%s beyond=%s bug@edge=%s bug-far=%s" % [
			Salt.in_kill_range(Feel.SALT_RADIUS + Feel.SLUG_BODY_RADIUS, Feel.SLUG_BODY_RADIUS),
			Salt.in_kill_range(Feel.SALT_RADIUS + Feel.SLUG_BODY_RADIUS + 0.01, Feel.SLUG_BODY_RADIUS),
			Salt.in_kill_range(Feel.SALT_RADIUS + Feel.BUG_RADIUS, Feel.BUG_RADIUS),
			Salt.in_kill_range(Feel.SALT_RADIUS + Feel.BUG_RADIUS + 1.0, Feel.BUG_RADIUS)])
	check("salt_shiver_strength_ramps_inside_radius",
		Salt.shiver_strength(Feel.SALT_SHIVER_RADIUS) == 0.0
			and Salt.shiver_strength(Feel.SALT_SHIVER_RADIUS * 2.0) == 0.0
			and Salt.shiver_strength(0.0) == 1.0
			and Salt.shiver_strength(Feel.SALT_SHIVER_RADIUS * 0.5) > 0.4,
		"edge=%f far=%f zero=%f half=%f" % [
			Salt.shiver_strength(Feel.SALT_SHIVER_RADIUS),
			Salt.shiver_strength(Feel.SALT_SHIVER_RADIUS * 2.0),
			Salt.shiver_strength(0.0),
			Salt.shiver_strength(Feel.SALT_SHIVER_RADIUS * 0.5)])

	# --- persistence: best never drops, runs tick, mute sticks ------------------
	var rs := RunState.new()
	rs.save_path = "user://" + TEST_SAVE
	rs.load_state()
	var best_after_300 := rs.finish_run(300)
	var best_after_120 := rs.finish_run(120)
	check("run_state_best_never_drops_and_runs_tick",
		best_after_300 == 300 and best_after_120 == 300 and rs.best == 300
			and rs.runs_finished == 2 and rs.next_run_number() == 3,
		"b300=%d b120=%d best=%d runs=%d next=%d" % [best_after_300, best_after_120,
			rs.best, rs.runs_finished, rs.next_run_number()])

	# --- sfx: 8 procedural cues + mute round trip --------------------------------
	var sfx := SfxManager.new()
	root.add_child(sfx)
	await process_frame
	var all_streams := true
	for cue in sfx.cue_names():
		if not sfx.has_stream(cue):
			all_streams = false
	check("sfx_manager_synthesizes_8_cues",
		sfx.cue_names().size() == 8 and all_streams and not sfx.play("nope"),
		"cues=%d streams_ok=%s" % [sfx.cue_names().size(), all_streams])

	sfx.set_muted(true)
	var muted_ok := sfx.is_muted() and not sfx.play("chomp") and sfx.playing_voices() == 0
	sfx.set_muted(false)
	check("sfx_mute_round_trip_gates_play_and_silences",
		muted_ok and not sfx.is_muted() and sfx.play("chomp") and sfx.play("word"),
		"muted=%s unmuted_play=%s" % [muted_ok, sfx.play("chomp")])
	sfx.free()

	# --- the real scene: salt clock scales with score -----------------------------
	seed(20260922)
	var main: Node2D = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.run_state.save_path = "user://" + TEST_SAVE
	_wipe_test_save()  # hermetic: the pure RunState test above wrote to it too
	main.run_state.load_state()
	main._salt_rng.seed = 20260922
	check("main_boots_clean_garden_no_salt_and_run_label",
		not main.is_dead() and main.salt_count() == 0
			and main.engine.score == 0 and main.engine.chain_mult == 1.0,
		"dead=%s salts=%d" % [main.is_dead(), main.salt_count()])
	main.hud.set_run(main.run_state.next_run_number())

	await process_frame
	main.engine.words_completed = 1  # the salt clock waits for a first word
	main._salt_cooldown = 0.01
	for i in 30:  # wait out the spawn frame, then read the reset clock
		await process_frame
		if main.salt_count() == 1:
			break
	var cooldown_after: float = main._salt_cooldown
	check("main_salt_clock_spawns_and_uses_score_interval",
		main.salt_count() == 1
			and absf(cooldown_after - Salt.spawn_interval(main.engine.score)) < 0.08,
		"salts=%d cooldown=%f expect=%f" % [main.salt_count(), cooldown_after,
			Salt.spawn_interval(main.engine.score)])

	main.engine.score = 5000  # a runaway score must pin the interval at the floor
	main._salt_cooldown = 0.01
	for i in 30:
		await process_frame
		if main.salt_count() == 2:
			break
	check("main_salt_interval_floors_at_high_score",
		main.salt_count() == 2
			and absf(main._salt_cooldown - Feel.SALT_MIN_SPAWN_SEC) < 0.08,
		"salts=%d cooldown=%f" % [main.salt_count(), main._salt_cooldown])

	# --- salt kills a bug (not eaten: no signal, no word progress) ----------------
	# Detach the slug from every bug first: with bug.slug == null nothing can be
	# EATEN by accident while the field wanders, so the only death on offer is
	# the salt's.
	for b in main._bugs:
		b.slug = null
	main.slug.global_position = Vector2(60.0, 900.0)
	await physics_frame
	var victim: Bug = main._bugs[0]
	var salted_bugs: Array[Bug] = []
	var eaten_bugs: Array[Bug] = []
	victim.salted.connect(func(b: Bug) -> void: salted_bugs.append(b))
	victim.eaten.connect(func(b: Bug) -> void: eaten_bugs.append(b))
	var bugs_eaten_before: int = main.engine.bugs_eaten
	victim.global_position = main._salts[0].global_position
	for i in 3:
		await process_frame
	check("salt_kills_bug_without_paying",
		victim.state == Bug.State.POPPED and salted_bugs.size() == 1
			and eaten_bugs.is_empty() and main.engine.bugs_eaten == bugs_eaten_before
			and main.engine.progress == 0,
		"state=%d salted=%d eaten=%d bugs_eaten=%d->%d" % [victim.state,
			salted_bugs.size(), eaten_bugs.size(), bugs_eaten_before, main.engine.bugs_eaten])

	# --- salt kills the slug: chain resets, best persists, overlay rises ----------
	main.engine.chain_mult = 2.5
	main.engine.score = 4242
	main.spawn_salt_at(main.slug.global_position)
	for i in 3:
		await process_frame
	check("salt_touch_kills_slug_and_resets_chain_not_best",
		main.is_dead() and main.engine.chain_mult == 1.0
			and main.engine.score == 4242 and main.run_state.best == 4242
			and main.run_state.runs_finished == 1
			and not main.slug.is_physics_processing(),
		"dead=%s mult=%f score=%d best=%d runs=%d physics=%s" % [main.is_dead(),
			main.engine.chain_mult, main.engine.score, main.run_state.best,
			main.run_state.runs_finished, main.slug.is_physics_processing()])
	check("game_over_overlay_tells_the_gardens_story",
		main.game_over != null
			and main.game_over._score_label.text == "SCORE 4242"
			and main.game_over._best_label.text == Feel.BEST_LABEL_FORMAT % 4242
			and main.game_over._run_label.text == Feel.RUN_LABEL_FORMAT % 1
			and main.game_over._hint.text == Feel.GAME_OVER_HINT,
		"score=%s best=%s run=%s" % [main.game_over._score_label.text,
			main.game_over._best_label.text, main.game_over._run_label.text])
	main.free()

	# --- retry: a completely fresh run, RUN N+1 ------------------------------------
	var retry: Node2D = MAIN_SCENE.instantiate()
	root.add_child(retry)
	await process_frame
	await process_frame
	retry.run_state.save_path = "user://" + TEST_SAVE
	retry.run_state.load_state()
	check("retry_is_a_full_reset_on_run_two",
		not retry.is_dead() and retry.engine.score == 0
			and retry.engine.chain_mult == 1.0 and retry.engine.progress == 0
			and retry.salt_count() == 0 and retry.run_state.best == 4242
			and retry.run_state.next_run_number() == 2
			and retry.run_state.runs_finished == 1,
		"dead=%s score=%d mult=%f prog=%d salts=%d best=%d next=%d" % [
			retry.is_dead(), retry.engine.score, retry.engine.chain_mult,
			retry.engine.progress, retry.salt_count(), retry.run_state.best,
			retry.run_state.next_run_number()])
	retry.hud.set_run(retry.run_state.next_run_number())
	check("hud_shows_run_counter_and_juice_plays",
		retry.hud._run_label.text == Feel.RUN_LABEL_FORMAT % 2
			and retry.run_state.muted == false,
		"run=%s muted=%s" % [retry.hud._run_label.text, retry.run_state.muted])
	retry.hud.fly_score(Vector2(100.0, 100.0), 250, true)
	retry.hud.pulse_mult()
	for i in 3:
		await process_frame
	retry.free()

	# --- title: the first scene, with the logo and the stamp ------------------------
	check("title_scene_is_main",
		ProjectSettings.get_setting("application/run/main_scene") == Feel.TITLE_SCENE_PATH,
		"main_scene=%s" % ProjectSettings.get_setting("application/run/main_scene"))
	var title: Node2D = TITLE_SCENE.instantiate()
	root.add_child(title)
	await process_frame
	await process_frame
	var logo: Sprite2D = title.get_node("Logo")
	var has_stamp := false
	for child in title.get_children():
		if child is CanvasLayer:
			for sub in child.get_children():
				if sub is Control:
					for sub2 in sub.get_children():
						if sub2 is Label and sub2.text == Feel.TITLE_VERSION_STAMP:
							has_stamp = true
	check("title_boots_with_logo_drifting_slug_and_stamp",
		logo != null and logo.texture != null
			and title._slug != null and is_instance_valid(title._slug)
			and has_stamp and title.sfx != null and title.sfx.has_stream("title"),
		"logo=%s slug=%s stamp=%s" % [logo != null, title._slug != null, has_stamp])
	title.free()

	# --- the export gate's flag: the word list must ship ----------------------------
	var preset := FileAccess.open("res://export_presets.cfg", FileAccess.READ)
	var preset_text := preset.get_as_text() if preset != null else ""
	var filter_ok := false
	for line in preset_text.split("\n"):
		if line.begins_with("include_filter=") and ".txt" in line:
			filter_ok = true
	check("export_include_filter_ships_word_list",
		filter_ok and FileAccess.file_exists("res://data/word_list.txt"),
		"filter=%s wordlist=%s" % [filter_ok, FileAccess.file_exists("res://data/word_list.txt")])

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


func _wipe_test_save() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(TEST_SAVE):
		dir.remove(TEST_SAVE)
