extends SceneTree
## Milestone 2 battery — LETTERS + TARGET WORD + SCORING.
## Run headless:
##   godot --headless --path . --script res://tests/m2_tests.gd
## Done = 2x consecutive green alongside a green m1 battery (spec law
## "growing_battery"). m1_tests.gd stays untouched.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const BUG_SCENE := preload("res://scenes/bug.tscn")
const SAMPLE_N := 50          # spec: bias asserted over a sample of 50 respawns

var passes := 0
var fails := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var seed_val := 20260922

	# --- word list + engine basics -------------------------------------------
	var engine := WordEngine.new()
	check("word_list_carries_common_tier",
		engine.total_lines == 26955 and engine.words.size() == 6294,
		"lines=%d play=%d" % [engine.total_lines, engine.words.size()])

	engine.rng.seed = seed_val
	var all_ok := true
	var w := ""
	for i in 40:
		w = engine.new_word()
		if w.length() < Feel.WORD_LEN_MIN or w.length() > Feel.WORD_LEN_MAX \
				or not engine.words.has(w):
			all_ok = false
			break
	check("engine_picks_list_words_3_to_5_letters", all_ok, "w=%s" % w)

	engine.target = "CAT"
	engine.progress = 2
	engine.new_word()
	check("new_word_resets_progress",
		engine.progress == 0 and engine.target.length() >= Feel.WORD_LEN_MIN,
		"progress=%d target=%s" % [engine.progress, engine.target])

	# --- spawn bias law (seeded, sample of 50) --------------------------------
	var bias_engine := WordEngine.new()
	bias_engine.rng.seed = seed_val
	bias_engine.target = "BREAD"  # 5 letters: the needed letter keeps changing
	bias_engine.progress = 0
	var needed := 0
	var valid := true
	for i in SAMPLE_N:
		var l := bias_engine.roll_spawn_letter(bias_engine.rng)
		if l.length() != 1 or l < "A" or l > "Z":
			valid = false
		if l == bias_engine.next_letter():
			needed += 1
		bias_engine.progress = (bias_engine.progress + 1) % bias_engine.target.length()
	var frac := float(needed) / float(SAMPLE_N)
	check("spawn_bias_prefers_needed_letter",
		frac >= Feel.WORD_LETTER_SPAWN_BIAS - 0.2 and frac > 0.15 and valid,
		"needed=%d/%d=%.2f valid=%s" % [needed, SAMPLE_N, frac, valid])

	var no_word := WordEngine.new()
	no_word.rng.seed = seed_val
	var rand_ok := true
	var rl := ""
	for i in SAMPLE_N:
		rl = no_word.roll_spawn_letter(no_word.rng)
		if rl.length() != 1 or rl < "A" or rl > "Z":
			rand_ok = false
	check("spawn_bias_without_word_is_uniform_az", rand_ok, "l=%s" % rl)

	# --- spelling law: advance / wrong / gold ----------------------------------
	var eng := WordEngine.new()
	eng.target = "CAT"
	var res := eng.eat("C")
	check("eat_next_letter_advances_and_scores_base",
		res.result == WordEngine.EatResult.ADVANCED and eng.progress == 1
			and res.points == Feel.SCORE_PER_BUG and eng.score == Feel.SCORE_PER_BUG,
		"res=%s prog=%d score=%d" % [res.result, eng.progress, eng.score])

	res = eng.eat("Z")  # wrong letter: base points, no advance
	check("eat_wrong_letter_scores_base_and_no_advance",
		res.result == WordEngine.EatResult.WRONG and eng.progress == 1
			and eng.score == Feel.SCORE_PER_BUG * 2,
		"res=%s prog=%d score=%d" % [res.result, eng.progress, eng.score])

	eng.target = "DOG"
	eng.progress = 0
	res = eng.eat("X", true)  # gold wildcard counts as the needed D
	check("gold_wildcard_substitutes_for_needed_letter",
		res.result == WordEngine.EatResult.ADVANCED and eng.progress == 1,
		"res=%s prog=%d" % [res.result, eng.progress])

	# --- full word cycle x2 (scripted eat sequence) ----------------------------
	var cyc := WordEngine.new()
	cyc.rng.seed = seed_val
	cyc.target = "CAT"
	var first := cyc.eat("C")
	var last := cyc.eat("A")
	last = cyc.eat("T")
	check("word_complete_pays_500_x_multiplier",
		first.result == WordEngine.EatResult.ADVANCED
			and last.result == WordEngine.EatResult.COMPLETED
			and cyc.score == Feel.SCORE_PER_BUG * 3 + Feel.WORD_COMPLETE_BONUS,
		"first=%s last=%s score=%d" % [first.result, last.result, cyc.score])
	check("word_complete_increments_chain_mult_and_deals_new_word",
		cyc.chain_mult == 1.5 and cyc.words_completed == 1
			and cyc.target != "" and cyc.target != "CAT" and cyc.progress == 0,
		"mult=%f words=%d target=%s" % [cyc.chain_mult, cyc.words_completed, cyc.target])

	# second word: lead with a gold wildcard, then spell it out
	var second := cyc.target
	cyc.eat("Q", true)
	var guard := 0
	while cyc.words_completed == 1 and guard < 16:
		cyc.eat(cyc.target[cyc.progress])
		guard += 1
	check("full_word_cycle_x2_scripted_sequence",
		cyc.words_completed == 2 and cyc.chain_mult == 2.0 and guard <= 8,
		"words=%d mult=%f guard=%d" % [cyc.words_completed, cyc.chain_mult, guard])
	var expected := Feel.SCORE_PER_BUG * 3 \
		+ Feel.WORD_COMPLETE_BONUS \
		+ Feel.SCORE_GOLD_BUG \
		+ Feel.SCORE_PER_BUG * (second.length() - 1) \
		+ int(Feel.WORD_COMPLETE_BONUS * 1.5)
	check("word_bonus_compounds_score_math",
		cyc.score == expected,
		"score=%d expected=%d" % [cyc.score, expected])

	# --- bugs carry letters -----------------------------------------------------
	var bug: Bug = BUG_SCENE.instantiate()
	bug.slug = null
	bug.rng.seed = seed_val
	bug.word_engine = WordEngine.new()
	bug.word_engine.rng.seed = seed_val
	bug.word_engine.new_word()
	root.add_child(bug)
	await process_frame
	await process_frame
	check("bug_spawns_carrying_a_letter",
		bug.letter.length() == 1 and bug.letter >= "A" and bug.letter <= "Z"
			and not bug.is_gold and bug._letter_label.text == bug.letter,
		"letter=%s gold=%s label=%s" % [bug.letter, bug.is_gold, bug._letter_label.text])

	bug.set_gold(true)
	var gold_speed := bug.flee_speed()
	check("gold_bug_variant_wildcard_texture_and_faster_flee",
		bug.is_gold and bug.letter == WordEngine.WILDCARD
			and bug._sprite.texture.resource_path.ends_with("bug_gold.png")
			and is_equal_approx(gold_speed, Feel.BUG_FLEE_SPEED * Feel.GOLD_BUG_FLEE_MULT)
			and bug._letter_label.text == WordEngine.WILDCARD,
		"gold=%s letter=%s speed=%f" % [bug.is_gold, bug.letter, gold_speed])
	bug.set_gold(false)
	check("green_bug_flee_speed_untouched",
		is_equal_approx(bug.flee_speed(), Feel.BUG_FLEE_SPEED)
			and gold_speed > Feel.BUG_FLEE_SPEED,
		"green=%f gold=%f" % [bug.flee_speed(), gold_speed])

	var gold_seen := 0
	var respawn_letters_ok := true
	for i in 300:
		bug.roll_respawn()
		if bug.is_gold:
			gold_seen += 1
			if bug.letter != WordEngine.WILDCARD:
				respawn_letters_ok = false
		elif bug.letter.length() != 1:
			respawn_letters_ok = false
	check("bug_respawn_rerolls_letter_and_rare_gold",
		respawn_letters_ok and gold_seen > 5 and gold_seen < 60,
		"golds=%d ok=%s" % [gold_seen, respawn_letters_ok])
	bug.free()

	# --- HUD reflects engine state ----------------------------------------------
	var hud := WordHud.new()
	root.add_child(hud)
	await process_frame
	hud.set_word("CAT")
	hud.set_progress(2)
	check("hud_word_slots_fill_in_order",
		hud.slot_count() == 3 and hud.slot_letter(0) == "C" and hud.slot_letter(1) == "A"
			and hud.slot_letter(2) == Feel.HUD_SLOT_EMPTY_GLYPH,
		"slots=%s%s%s" % [hud.slot_letter(0), hud.slot_letter(1), hud.slot_letter(2)])
	hud.set_progress(3)
	check("hud_word_complete_fills_all_slots",
		hud.slot_letter(2) == "T",
		"slot2=%s" % hud.slot_letter(2))
	hud.set_score(650)
	hud.set_mult(1.5)
	hud.set_bugs(7)
	check("hud_score_mult_bug_labels_update",
		hud._score_label.text == "SCORE 650" and hud._mult_label.text == "x1.5"
			and hud._bugs_label.text == "BUGS 7",
		"score=%s mult=%s bugs=%s" % [hud._score_label.text, hud._mult_label.text,
			hud._bugs_label.text])
	hud.shake_word()
	hud.pop_slot(0)
	hud.fly_letter(Vector2(100.0, 100.0), "C", 0)
	hud.confetti()
	await create_timer(0.9).timeout
	check("hud_juice_plays_without_breaking_slots",
		hud.slot_count() == 3 and hud.slot_letter(0) == "C" and hud.slot_letter(2) == "T",
		"slots=%d s0=%s s2=%s" % [hud.slot_count(), hud.slot_letter(0), hud.slot_letter(2)])
	hud.free()

	# --- the real scene wires it all together ------------------------------------
	var main: Node2D = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var wired := true
	for b in main._bugs:
		if b.word_engine != main.engine:
			wired = false
	check("main_scene_wires_engine_hud_and_bugs",
		main.engine.target != "" and main.hud.word_text() == main.engine.target
			and main.hud.slot_count() == main.engine.target.length()
			and main.hud.slot_letter(0) == Feel.HUD_SLOT_EMPTY_GLYPH
			and wired and main.engine.progress == 0,
		"target=%s hud=%s slots=%d" % [main.engine.target, main.hud.word_text(),
			main.hud.slot_count()])

	# drive one eat through the real scene path: park the slug in a quiet corner
	# and drop one bug carrying the needed letter on top of it
	main.slug.global_position = Vector2(60.0, 60.0)
	await physics_frame
	var victim: Bug = main._bugs[0]
	for b in main._bugs:
		if b != victim:
			b.global_position = Vector2(480.0, 900.0)
	victim.letter = main.engine.next_letter()
	victim.set_gold(false)
	victim.global_position = main.slug.global_position
	var score_before: int = main.engine.score
	for i in 4:
		await physics_frame
	check("main_eat_path_scores_and_fills_hud_slot",
		main.engine.score == score_before + Feel.SCORE_PER_BUG
			and main.engine.progress == 1
			and main.hud.slot_letter(0) == main.engine.target[0]
			and main.hud._score_label.text == "SCORE %d" % main.engine.score,
		"score=%d slot0=%s" % [main.engine.score, main.hud.slot_letter(0)])
	main.free()

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
