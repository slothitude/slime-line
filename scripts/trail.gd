class_name SlimeTrail
extends Line2D
## The glowing slime ribbon behind the slug.
##
## Points are pushed in at the head (slug position); every point carries an
## age. update(delta) advances ages; points fade out (alpha + width, driven by
## their remaining life fraction) and drop once they pass Feel.TRAIL_FADE.
##
## Pure enough to test: push_head()/update(delta) work outside the scene tree,
## so tests can fast-forward ages without a scene.
##
## Glow: a second, wider translucent additive line drawn behind the core
## ribbon (spec trail.glow = true).

var _positions := PackedVector2Array()
var _ages := PackedFloat32Array()
var _glow: Line2D
var _core_gradient: Gradient
var _glow_gradient: Gradient
var _width_curve: Curve


func _init() -> void:
	top_level = true
	width = Feel.TRAIL_WIDTH
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	_core_gradient = Gradient.new()
	gradient = _core_gradient
	_width_curve = Curve.new()
	width_curve = _width_curve
	if Feel.TRAIL_GLOW:
		_glow = Line2D.new()
		_glow.show_behind_parent = true
		_glow.width = Feel.TRAIL_WIDTH * Feel.TRAIL_GLOW_WIDTH_SCALE
		_glow.joint_mode = Line2D.LINE_JOINT_ROUND
		_glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_glow.end_cap_mode = Line2D.LINE_CAP_ROUND
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_glow.material = mat
		_glow_gradient = Gradient.new()
		_glow.gradient = _glow_gradient
		add_child(_glow)


## Record the slug's current position as the new head of the ribbon.
## Micro-moves below Feel.TRAIL_MIN_SEGMENT_PX are ignored so the line stays
## smooth, and the ribbon never holds more than Feel.TRAIL_POINTS_MAX points.
func push_head(pos: Vector2) -> void:
	if _positions.size() > 0 and pos.distance_to(_positions[_positions.size() - 1]) < Feel.TRAIL_MIN_SEGMENT_PX:
		return
	_positions.append(pos)
	_ages.append(0.0)
	while _positions.size() > Feel.TRAIL_POINTS_MAX:
		_positions.remove_at(0)
		_ages.remove_at(0)


## Advance every point's age, drop faded points, refresh the fade rendering.
func update(delta: float) -> void:
	for i in _ages.size():
		_ages[i] += delta
	while _ages.size() > 0 and _ages[0] >= Feel.TRAIL_FADE:
		_positions.remove_at(0)
		_ages.remove_at(0)
	points = _positions
	if _glow != null:
		_glow.points = _positions
	_refresh_fade()


func point_count() -> int:
	return _positions.size()


func age_at(i: int) -> float:
	return _ages[i]


## 1.0 = brand new head point, 0.0 = about to drop.
func life_at(i: int) -> float:
	return clampf(1.0 - _ages[i] / Feel.TRAIL_FADE, 0.0, 1.0)


func head_position() -> Vector2:
	return _positions[_positions.size() - 1]


func clear_trail() -> void:
	_positions = PackedVector2Array()
	_ages = PackedFloat32Array()
	points = _positions
	if _glow != null:
		_glow.points = _positions


## Rebuild gradient (alpha fade) + width curve (taper head->tail) from the
## points' current life fractions, sampled at 5 fractions along the ribbon.
func _refresh_fade() -> void:
	var n := _positions.size()
	if n == 0:
		return
	var offsets := PackedFloat32Array()
	var core_colors := PackedColorArray()
	var glow_colors := PackedColorArray()
	_width_curve.clear_points()
	var samples := 5
	if n == 1:
		samples = 2
	for s in samples:
		var off := float(s) / float(samples - 1)
		var idx := int(round(off * float(n - 1)))
		var life := life_at(idx)
		offsets.append(off)
		core_colors.append(Color(Feel.TRAIL_COLOR, life))
		glow_colors.append(Color(Feel.TRAIL_GLOW_COLOR, life * Feel.TRAIL_GLOW_ALPHA))
		_width_curve.add_point(Vector2(off, maxf(Feel.TRAIL_MIN_WIDTH_FACTOR, life)))
	_core_gradient.offsets = offsets
	_core_gradient.colors = core_colors
	if _glow != null and _glow_gradient != null:
		_glow_gradient.offsets = offsets
		_glow_gradient.colors = glow_colors
