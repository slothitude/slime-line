extends Node2D
## SLIME LINE — the garden. Milestone 3 completes the loop: glide, trail,
## letter-bugs, the target word, scoring, and now the SALT — crystals spawn
## faster as your score climbs, kill the slug on touch (one life: the run
## ends, the chain resets, the best persists, tap RETRY for RUN N+1) and kill
## any bug they touch (the strategic use: herd a bug into the salt).
##
## The WordEngine owns every spelling rule; main wires it to the world — bugs
## ask it for letters, eats pay through it, the HUD mirrors it, and the
## SfxManager sings over all of it.

const SHOW_DEBUG := false

var _area := Rect2()
var _bugs: Array[Bug] = []
var _salts: Array[Salt] = []
var _debug_frames := 0
var engine: WordEngine = WordEngine.new()
var hud: WordHud = null
var run_state := RunState.new()
var sfx: SfxManager = null
var game_over: GameOver = null
var vignette: Vignette = null

var _dead := false
var _salt_cooldown := Feel.SALT_SPAWN_GRACE_SEC   # calm garden, then the salt comes
var _salt_rng := RandomNumberGenerator.new()
var _step_cooldown := 0.0

@onready var slug: Slug = $Slug
@onready var bugs_node: Node2D = $Bugs
@onready var debug_label: Label = $Debug


func _ready() -> void:
	_area = Rect2(Vector2.ZERO, get_viewport_rect().size)
	_setup_background()
	# Raw area: Slug.clamp_to_bounds applies SLUG_BOUNDS_MARGIN_PX itself, and
	# double-growing would open an untouchable dead zone at every wall.
	slug.bounds = _area
	engine.new_word()
	run_state.load_state()
	sfx = SfxManager.new()
	add_child(sfx)
	sfx.set_muted(run_state.muted)
	vignette = Vignette.new()
	add_child(vignette)
	hud = WordHud.new()
	add_child(hud)
	hud.set_word(engine.target)
	hud.set_score(engine.score)
	hud.set_mult(engine.chain_mult)
	hud.set_bugs(engine.bugs_eaten)
	hud.set_run(run_state.next_run_number())
	for i in Feel.BUG_COUNT_TARGET:
		_spawn_bug(i)
	_salt_rng.randomize()
	debug_label.visible = SHOW_DEBUG


func _process(delta: float) -> void:
	var active := _count_active_bugs()
	# Spec: keep 6-9 bugs active at once — top up if a burst of eats dips us.
	if active < Feel.BUG_COUNT_MIN and _bugs.size() < Feel.BUG_COUNT_MAX:
		_spawn_bug(_bugs.size())
	if not _dead:
		_update_salt(delta)
		_update_threat_feel(delta)
	if SHOW_DEBUG:
		_debug_frames += 1
		if _debug_frames % Feel.DEBUG_SAMPLE_EVERY_N_FRAMES == 0:
			debug_label.text = "speed %d px/s   trail %d pts   bugs %d   salt %d   word %s" % [
				int(slug.velocity.length()), slug.trail.point_count(), active,
				_salts.size(), engine.word_display()]


func _count_active_bugs() -> int:
	var active := 0
	for b in _bugs:
		if is_instance_valid(b) and b.is_active():
			active += 1
	return active


func _spawn_bug(index: int) -> void:
	var scene: PackedScene = load("res://scenes/bug.tscn")
	var bug: Bug = scene.instantiate()
	bug.slug = slug
	bug.bounds = _area
	bug.rng.seed = 1000 + index * 7919
	bug.word_engine = engine
	bug.global_position = _random_point(_area)
	bug.eaten.connect(_on_bug_eaten)
	bug.salted.connect(_on_bug_salted)
	bug.add_to_group("bugs")
	bugs_node.add_child(bug)
	_bugs.append(bug)


func _random_point(rect: Rect2) -> Vector2:
	return Vector2(
		randf_range(rect.position.x, rect.end.x),
		randf_range(rect.position.y, rect.end.y))


## The whole spelling law, from the world's side: the bug pops, the engine
## rules on its letter, the HUD mirrors the engine and plays the juice.
func _on_bug_eaten(bug: Bug) -> void:
	var slot := engine.progress          # the slot this eat is about to fill
	var mult_before := engine.chain_mult
	var score_before := engine.score
	var res := engine.eat(bug.letter, bug.is_gold)
	hud.set_score(engine.score)
	hud.set_bugs(engine.bugs_eaten)
	hud.set_mult(engine.chain_mult)
	hud.set_word(engine.target)
	hud.set_progress(engine.progress)
	match res.result:
		WordEngine.EatResult.ADVANCED:
			hud.fly_letter(bug.global_position, bug.letter, slot)
			sfx.play("gold" if bug.is_gold else "chomp")
		WordEngine.EatResult.COMPLETED:
			hud.fly_letter(bug.global_position, bug.letter, slot)
			hud.confetti()
			sfx.play("word")
		WordEngine.EatResult.WRONG:
			hud.shake_word()
			sfx.play("wrong")
	hud.fly_score(bug.global_position, engine.score - score_before, bug.is_gold)
	if engine.chain_mult > mult_before:
		hud.pulse_mult()


func _on_bug_salted(_bug: Bug) -> void:
	sfx.play("salt")


# --------------------------------------------------------------------- salt --

## Spawn clock: a calm grace period AND a first spelled word — the salt comes
## for those who keep taking (LORE.md) — then crystals arrive every
## Salt.spawn_interval(score) seconds, the spec's "rate rises with score",
## until the field holds SALT_MAX_COUNT. Every spawn is followed by a touch
## sweep: crystal vs slug (death) and crystal vs bugs (strategy). Crystals
## already on the field kill even before the first word — only the CLOCK waits.
func _update_salt(delta: float) -> void:
	if engine.words_completed >= 1 and _salts.size() < Feel.SALT_MAX_COUNT:
		_salt_cooldown -= delta
		if _salt_cooldown <= 0.0:
			_spawn_salt()
			_salt_cooldown = Salt.spawn_interval(engine.score)
	_check_salt_touches()


func _spawn_salt() -> void:
	var scene: PackedScene = load("res://scenes/salt.tscn")
	var salt: Salt = scene.instantiate()
	salt.global_position = _salt_spawn_point()
	salt.add_to_group("salts")
	add_child(salt)
	_salts.append(salt)


## Crystals hate a cheap kill: candidates are drawn from the wall-hugging
## band and only accepted at least SALT_SPAWN_MIN_DIST_PX from the slug; the
## farthest try wins if the dice never cooperate.
func _salt_spawn_point() -> Vector2:
	var inner := _area.grow(-Feel.SALT_EDGE_INSET_PX)
	var best := inner.get_center()
	var best_d := -1.0
	for i in Feel.SALT_SPAWN_TRY_N:
		var p := Vector2(
			_salt_rng.randf_range(inner.position.x, inner.end.x),
			_salt_rng.randf_range(inner.position.y, inner.end.y))
		var d := p.distance_to(slug.global_position)
		if d >= Feel.SALT_SPAWN_MIN_DIST_PX:
			return p
		if d > best_d:
			best_d = d
			best = p
	return best


func _check_salt_touches() -> void:
	for salt in _salts:
		if not is_instance_valid(salt):
			continue
		if not _dead and Salt.in_kill_range(
				salt.global_position.distance_to(slug.global_position),
				Feel.SLUG_BODY_RADIUS):
			_die()
		for b in _bugs:
			if is_instance_valid(b) and b.is_active() and Salt.in_kill_range(
					salt.global_position.distance_to(b.global_position),
					Feel.BUG_RADIUS):
				b.salt_kill()


func _nearest_salt_dist() -> float:
	var nearest := INF
	for salt in _salts:
		if is_instance_valid(salt):
			nearest = minf(nearest, salt.global_position.distance_to(slug.global_position))
	return nearest


## Salt makes itself felt before it kills: the slug shivers inside
## SALT_SHIVER_RADIUS, the vignette warns when the field runs hot, and a fast
## glide squelches.
func _update_threat_feel(delta: float) -> void:
	slug.shiver = Salt.shiver_strength(_nearest_salt_dist()) * Feel.SALT_SHIVER_MAX_PX
	vignette.set_level(1.0 if _salts.size() >= Feel.SALT_WARN_COUNT else 0.0)
	if slug.velocity.length() >= Feel.MAX_SPEED * Feel.SQUELCH_SPEED_FRAC:
		_step_cooldown -= delta
		if _step_cooldown <= 0.0:
			sfx.play("step")
			_step_cooldown = Feel.SQUELCH_STEP_SEC
	else:
		_step_cooldown = 0.0


# ---------------------------------------------------------------- the run ----

## One life (spec run.lives): salt touch ends the run. The chain resets — that
## is the spec law — the best persists, and the garden remembers: overlay,
## then a tap starts RUN N+1 as a completely fresh scene.
func _die() -> void:
	if _dead:
		return
	_dead = true
	engine.chain_mult = 1.0
	hud.set_mult(engine.chain_mult)
	var best := run_state.finish_run(engine.score)
	slug.shiver = 0.0
	slug.set_physics_process(false)   # the salted slug stops where it fell
	slug.modulate = Feel.SALT_DEATH_TINT
	sfx.play("salt")
	sfx.play("over")
	game_over = GameOver.new()
	game_over.sfx = sfx
	game_over.run_state = run_state
	game_over.retry_pressed.connect(_on_retry)
	add_child(game_over)
	game_over.setup(engine.score, best, run_state.runs_finished)


func _on_retry() -> void:
	# Full reset by construction: the scene rebuilds from zero (score, word,
	# multiplier, salts, trail) and reads RUN N+1 from the persisted state.
	get_tree().reload_current_scene()


func is_dead() -> bool:
	return _dead


func salt_count() -> int:
	return _salts.size()


## Test hook: the next crystal appears exactly where the battery wants it.
func spawn_salt_at(pos: Vector2) -> Salt:
	var scene: PackedScene = load("res://scenes/salt.tscn")
	var salt: Salt = scene.instantiate()
	salt.global_position = pos
	salt.add_to_group("salts")
	add_child(salt)
	_salts.append(salt)
	return salt


## Garden floor: tile_garden.png tiled at half native size, or a flat dark
## green ColorRect if the art never shows up. Never blocks.
func _setup_background() -> void:
	var spr := Sprite2D.new()
	spr.name = "Bg"
	spr.texture = Art.tex("tile_garden")
	spr.centered = false
	spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	spr.region_enabled = true
	spr.scale = Vector2.ONE * Feel.GARDEN_TILE_SCALE
	spr.region_rect = Rect2(Vector2.ZERO, _area.size / Feel.GARDEN_TILE_SCALE + Vector2.ONE * 4.0)
	add_child(spr)
	move_child(spr, 0)
