class_name Bug
extends Node2D
## bug_letter (green): wanders with random heading changes, flees directly
## away from the slug inside Feel.BUG_FLEE_RADIUS, bounces off the play-area
## bounds, and pops (scale up + fade) when the slug gets within EAT_RADIUS.
## It respawns elsewhere after a beat.
##
## Every bug carries a letter under its wing (shown in a small outlined label).
## Respawned bugs ask the WordEngine for their letter — the spawn-bias law
## (60% next needed letter / 40% random A-Z) lives there. ~8% of respawns come
## up GOLD instead: bug_gold art, faster flee, and a wildcard "?" that counts
## as any letter when the Word is being spelled in order.

signal eaten(bug: Bug)
signal respawned(bug: Bug)
signal salted(bug: Bug)

enum State { WANDER, FLEE, POPPED }

var state: int = State.WANDER
var slug: Node2D = null
var bounds := Rect2()                 # zero-size = no clamping (tests)
var rng := RandomNumberGenerator.new()
var word_engine: WordEngine = null    # letter source; null = plain random A-Z

var letter := ""                      # "" = not dealt yet
var is_gold := false

var _dir := Vector2.RIGHT
var _wander_timer := 0.0
var _sprite: Sprite2D = null
var _letter_label: Label = null
var _base_scale := Vector2.ONE


func _ready() -> void:
	_sprite = $Sprite
	_sprite.texture = Art.tex("bug_green")
	_base_scale = Vector2.ONE * Feel.BUG_SPRITE_SCALE
	_sprite.scale = _base_scale
	_make_letter_label()
	roll_letter()  # first spawn: green, but already biased toward the Word
	_wander_timer = rng.randf_range(Feel.BUG_WANDER_TIME_MIN, Feel.BUG_WANDER_TIME_MAX)
	_pop_in()


func _physics_process(delta: float) -> void:
	if state == State.POPPED:
		return
	var vel := Vector2.ZERO
	if slug != null and is_instance_valid(slug):
		var to_slug := slug.global_position - global_position
		if to_slug.length() <= Feel.BUG_FLEE_RADIUS:
			state = State.FLEE
			vel = flee_direction(global_position, slug.global_position) * flee_speed()
		else:
			state = State.WANDER
	if state == State.WANDER:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_dir = pick_wander_direction(rng)
			_wander_timer = rng.randf_range(Feel.BUG_WANDER_TIME_MIN, Feel.BUG_WANDER_TIME_MAX)
		vel = _dir * Feel.BUG_WANDER_SPEED
	global_position += vel * delta
	_stay_in_bounds()
	_maybe_eat()


func is_active() -> bool:
	return state != State.POPPED


# -------------------------------------------------------------- pure math --

## Directly away from the threat.
static func flee_direction(from: Vector2, threat: Vector2) -> Vector2:
	var away := from - threat
	if away.length() < 0.001:
		return Vector2.RIGHT
	return away.normalized()


## Slug-within-EAT_RADIUS eats the bug (inclusive at the boundary).
static func in_eat_range(dist: float) -> bool:
	return dist <= Feel.EAT_RADIUS


static func pick_wander_direction(r: RandomNumberGenerator) -> Vector2:
	return Vector2.from_angle(r.randf_range(0.0, TAU))


## Gold bugs flee faster (Feel.GOLD_BUG_FLEE_MULT) — they are worth more.
func flee_speed() -> float:
	return Feel.BUG_FLEE_SPEED * (Feel.GOLD_BUG_FLEE_MULT if is_gold else 1.0)


# --------------------------------------------------------------- the letter --

## First-spawn deal: bias law only, never gold (gold is a respawn treat).
func roll_letter() -> void:
	is_gold = false
	if word_engine != null:
		letter = word_engine.roll_spawn_letter(rng)
	else:
		letter = WordEngine.random_letter(rng)
	_refresh_letter()


## Respawn deal: the 8% gold roll first, then the letter law.
func roll_respawn() -> void:
	is_gold = rng.randf() < Feel.GOLD_BUG_CHANCE
	if is_gold:
		letter = WordEngine.WILDCARD
	elif word_engine != null:
		letter = word_engine.roll_spawn_letter(rng)
	else:
		letter = WordEngine.random_letter(rng)
	_refresh_letter()


## Test hook: pin the variant explicitly.
func set_gold(gold: bool) -> void:
	is_gold = gold
	if gold:
		letter = WordEngine.WILDCARD
	elif letter == WordEngine.WILDCARD:
		letter = WordEngine.random_letter(rng)
	_refresh_letter()


func _refresh_letter() -> void:
	_sprite.texture = Art.tex("bug_gold" if is_gold else "bug_green")
	if _letter_label != null:
		_letter_label.text = letter
		_letter_label.label_settings.font_color = \
			Feel.GOLD_LETTER_LABEL_COLOR if is_gold else Feel.LETTER_LABEL_COLOR


func _make_letter_label() -> void:
	_letter_label = Label.new()
	var ls := LabelSettings.new()
	ls.font_size = Feel.LETTER_FONT_SIZE
	ls.font_color = Feel.LETTER_LABEL_COLOR
	ls.outline_size = Feel.LETTER_OUTLINE_SIZE
	ls.outline_color = Feel.LETTER_OUTLINE_COLOR
	_letter_label.label_settings = ls
	_letter_label.custom_minimum_size = Feel.LETTER_LABEL_BOX
	_letter_label.size = Feel.LETTER_LABEL_BOX
	_letter_label.position = Feel.LETTER_LABEL_OFFSET_PX - Feel.LETTER_LABEL_BOX * 0.5
	_letter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_letter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_letter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_letter_label)


# ----------------------------------------------------------------- behavior --

func _stay_in_bounds() -> void:
	if bounds.size == Vector2.ZERO:
		return
	var rect := bounds.grow(-Feel.BUG_RADIUS)
	var p := global_position
	var before := p
	p.x = clampf(p.x, rect.position.x, rect.end.x)
	p.y = clampf(p.y, rect.position.y, rect.end.y)
	if p.x != before.x:
		_dir.x = -_dir.x
	if p.y != before.y:
		_dir.y = -_dir.y
	global_position = p


func _maybe_eat() -> void:
	if state == State.POPPED or slug == null or not is_instance_valid(slug):
		return
	if not in_eat_range(global_position.distance_to(slug.global_position)):
		return
	_pop()


func _pop(emit_eaten := true) -> void:
	state = State.POPPED
	if emit_eaten:
		eaten.emit(self)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_sprite, "scale", _base_scale * Feel.BUG_POP_SCALE, Feel.BUG_POP_SEC)
	tw.tween_property(_sprite, "modulate:a", 0.0, Feel.BUG_POP_SEC)
	tw.tween_property(_letter_label, "modulate:a", 0.0, Feel.BUG_POP_SEC)
	tw.chain().tween_callback(func() -> void: _sprite.visible = false)
	get_tree().create_timer(Feel.BUG_RESPAWN_DELAY_SEC).timeout.connect(_respawn)


## The salt got it: pops WITHOUT the eaten signal (a salted bug is not an eaten
## bug — no letter, no points, no word progress) and respawns after the beat
## like any death. The strategic use: herd a bug into a crystal.
func salt_kill() -> void:
	if state == State.POPPED:
		return
	_pop(false)
	salted.emit(self)


## Spawn/respawn entrance: scale up from nothing with a little overshoot.
func _pop_in() -> void:
	_sprite.scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", _base_scale, Feel.BUG_POP_IN_SEC) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _respawn() -> void:
	global_position = _pick_respawn_position()
	roll_respawn()
	_sprite.visible = true
	_sprite.scale = _base_scale
	_sprite.modulate.a = 1.0
	_letter_label.modulate.a = 1.0
	_pop_in()
	_dir = pick_wander_direction(rng)
	_wander_timer = rng.randf_range(Feel.BUG_WANDER_TIME_MIN, Feel.BUG_WANDER_TIME_MAX)
	state = State.WANDER
	respawned.emit(self)


func _pick_respawn_position() -> Vector2:
	if bounds.size == Vector2.ZERO:
		return global_position
	var fallback := global_position
	for i in Feel.BUG_RESPAWN_TRY_N:
		var p := Vector2(
			rng.randf_range(bounds.position.x, bounds.end.x),
			rng.randf_range(bounds.position.y, bounds.end.y))
		fallback = p
		if slug == null or not is_instance_valid(slug):
			return p
		if p.distance_to(slug.global_position) >= Feel.BUG_RESPAWN_MIN_DIST_PX:
			return p
	return fallback
