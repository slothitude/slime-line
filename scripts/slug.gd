class_name Slug
extends CharacterBody2D
## The slug: glide steering, squash-stretch, antenna wobble, slime trail.
##
## ALL steering flows through TiltSource (spec law "injectable_input"). Two
## instances run the same pure pipeline — one fed drag/tilt x, one fed y — so
## web touch-drag is the default mode and mobile device tilt needs no changes.
## Synthetic/touch feeders make it fully drivable from tests.

var tilt_x := TiltSource.new()
var tilt_y := TiltSource.new()
var bounds := Rect2()                 # zero-size = unclamped (tests)
var input_dir := Vector2.ZERO
var trail: SlimeTrail = null

var _antenna_wobble := 0.0
var _sprite: Sprite2D = null


func _init() -> void:
	# Jam default: touch-drag steers (web-first); tilt stays available.
	tilt_x.set_mode(TiltSource.MODE_TOUCH)
	tilt_y.set_mode(TiltSource.MODE_TOUCH)


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_sprite = $Sprite
	_sprite.texture = Art.tex("slug_player")
	_sprite.scale = Vector2.ONE * Feel.SLUG_SPRITE_SCALE
	var shape: CircleShape2D = $Shape.shape
	shape.radius = Feel.SLUG_BODY_RADIUS
	trail = SlimeTrail.new()
	add_child(trail)
	var wobble := create_tween().set_loops()
	wobble.tween_property(self, "_antenna_wobble", 1.0, Feel.ANTENNA_WOBBLE_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wobble.tween_property(self, "_antenna_wobble", -1.0, Feel.ANTENNA_WOBBLE_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _physics_process(delta: float) -> void:
	input_dir = read_input()
	velocity = glide_velocity(velocity, input_dir, delta)
	move_and_slide()
	position = clamp_to_bounds(position, bounds, Feel.SLUG_BOUNDS_MARGIN_PX)
	if trail != null:
		trail.push_head(global_position)
		trail.update(delta)
	_apply_juice(delta)


func _process(_delta: float) -> void:
	queue_redraw()  # antennae follow the tweened wobble


# ------------------------------------------------------------------- input --

## Final steering direction from the two tilt axes.
## The two TiltSource instances supply the raw axis readings (touch drag or
## device tilt); shaping is applied to the combined deflection MAGNITUDE and
## the DIRECTION is preserved. Shaping per-axis instead would quadratically
## suppress small correction components (0.1 -> ~0.014) and wreck aim — the
## curve was tuned for 1D plane tilt, not a 2D steering vector.
func read_input() -> Vector2:
	var raw := Vector2(tilt_x.read_raw(), tilt_y.read_raw())
	if raw.length() < 0.001:
		return Vector2.ZERO
	var shaped: float = TiltSource.shape(raw.length())
	return raw.normalized() * shaped


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			feed_touch_begin(event.position.x, event.position.y)
		else:
			feed_touch_end()
	elif event is InputEventScreenDrag:
		feed_touch_move(event.position.x, event.position.y)


func feed_touch_begin(x: float, y: float) -> void:
	tilt_x.touch_begin(x)
	tilt_y.touch_begin(y)


func feed_touch_move(x: float, y: float) -> void:
	tilt_x.touch_move(x)
	tilt_y.touch_move(y)


func feed_touch_end() -> void:
	tilt_x.touch_end()
	tilt_y.touch_end()


func set_input_mode(mode: String) -> void:
	tilt_x.set_mode(mode)
	tilt_y.set_mode(mode)


# --------------------------------------------------------------- pure math --

## One step of the glide feel: accel toward input, drag, clamp to MAX_SPEED.
## DRAG (0.90/frame) is coasting friction. Applied unconditionally while
## thrusting it would pin terminal speed at ~48 px/s (slower than a fleeing
## bug), so thrust sustains the along-input component. Two cases get friction:
## - no input: full coast decay;
## - input opposing existing momentum (v·dir < 0): the along component decays
##   too, otherwise reversing takes ~1.5s of pure arcing and the slug orbits
##   its target instead of turning.
static func glide_velocity(vel: Vector2, dir: Vector2, delta: float) -> Vector2:
	var drag := pow(Feel.DRAG, delta * 60.0)
	var v := vel
	if dir.length() < 0.01:
		v *= drag
	else:
		var d := dir.normalized()
		var along := v.dot(d)
		if along < 0.0:
			along *= drag
		var perp := (v - d * v.dot(d)) * drag
		v = d * (along + Feel.GLIDE_ACCEL * delta) + perp
	if v.length() > Feel.MAX_SPEED:
		v = v.normalized() * Feel.MAX_SPEED
	return v


## Keep the slug inside the play area with a margin. Zero-size rect = no-op.
static func clamp_to_bounds(pos: Vector2, rect: Rect2, margin: float) -> Vector2:
	if rect.size == Vector2.ZERO:
		return pos
	var inner := rect.grow(-margin)
	return Vector2(
		clampf(pos.x, inner.position.x, inner.end.x),
		clampf(pos.y, inner.position.y, inner.end.y))


# ------------------------------------------------------------------- juice --

func _apply_juice(delta: float) -> void:
	if _sprite == null:
		return
	var speed_ratio := clampf(velocity.length() / Feel.MAX_SPEED, 0.0, 1.0)
	if velocity.length() > 2.0:
		_sprite.rotation = lerp_angle(_sprite.rotation, velocity.angle(), Feel.FACING_LERP_SPEED * delta)
	var target := Vector2(
		1.0 + Feel.SQUASH_MAX * speed_ratio,
		1.0 + Feel.SQUASH_MIN * speed_ratio) * Feel.SLUG_SPRITE_SCALE
	_sprite.scale = _sprite.scale.lerp(target, Feel.SQUASH_LERP_SPEED * delta)


func _draw() -> void:
	if _sprite == null:
		return
	var rot := _sprite.rotation
	for side in [-1.0, 1.0]:
		var base := Vector2(Feel.ANTENNA_BASE_OFFSET_PX.x, side * Feel.ANTENNA_BASE_OFFSET_PX.y).rotated(rot)
		var tip := base + Vector2(
			Feel.ANTENNA_TIP_SPREAD_PX.x,
			side * (Feel.ANTENNA_TIP_SPREAD_PX.y + _antenna_wobble * Feel.ANTENNA_WOBBLE_SWING_PX)).rotated(rot)
		draw_line(base, tip, Feel.ANTENNA_COLOR, Feel.ANTENNA_LINE_WIDTH)
		draw_circle(tip, Feel.ANTENNA_TIP_RADIUS, Feel.ANTENNA_COLOR)
