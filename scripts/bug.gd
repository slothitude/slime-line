class_name Bug
extends Node2D
## bug_letter (green): wanders with random heading changes, flees directly
## away from the slug inside Feel.BUG_FLEE_RADIUS, bounces off the play-area
## bounds, and pops (scale up + fade) when the slug gets within EAT_RADIUS.
## It respawns elsewhere after a beat. Letters arrive in milestone 2.

signal eaten(bug: Bug)
signal respawned(bug: Bug)

enum State { WANDER, FLEE, POPPED }

var state: int = State.WANDER
var slug: Node2D = null
var bounds := Rect2()                 # zero-size = no clamping (tests)
var rng := RandomNumberGenerator.new()

var _dir := Vector2.RIGHT
var _wander_timer := 0.0
var _sprite: Sprite2D = null
var _base_scale := Vector2.ONE


func _ready() -> void:
	_sprite = $Sprite
	_sprite.texture = Art.tex("bug_green")
	_base_scale = Vector2.ONE * Feel.BUG_SPRITE_SCALE
	_sprite.scale = _base_scale
	_wander_timer = rng.randf_range(Feel.BUG_WANDER_TIME_MIN, Feel.BUG_WANDER_TIME_MAX)


func _physics_process(delta: float) -> void:
	if state == State.POPPED:
		return
	var vel := Vector2.ZERO
	if slug != null and is_instance_valid(slug):
		var to_slug := slug.global_position - global_position
		if to_slug.length() <= Feel.BUG_FLEE_RADIUS:
			state = State.FLEE
			vel = flee_direction(global_position, slug.global_position) * Feel.BUG_FLEE_SPEED
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


func _pop() -> void:
	state = State.POPPED
	eaten.emit(self)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_sprite, "scale", _base_scale * Feel.BUG_POP_SCALE, Feel.BUG_POP_SEC)
	tw.tween_property(_sprite, "modulate:a", 0.0, Feel.BUG_POP_SEC)
	tw.chain().tween_callback(func() -> void: _sprite.visible = false)
	get_tree().create_timer(Feel.BUG_RESPAWN_DELAY_SEC).timeout.connect(_respawn)


func _respawn() -> void:
	global_position = _pick_respawn_position()
	_sprite.visible = true
	_sprite.scale = _base_scale
	_sprite.modulate.a = 1.0
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
