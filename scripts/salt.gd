class_name Salt
extends Node2D
## The salt crystal (LORE.md: "the salt was left by something that wanted the
## words spelled wrong"). Kills the slug on touch — one life, so that is the
## run — and kills any bug it touches (the strategic use: herd a bug into it).
##
## Spawning laws live here as pure statics so the battery can drive them
## without a scene:
##   - spawn_interval(score): the spec "rate rises with score" — the seconds
##     between spawns shrink linearly with score, floored at the minimum.
##   - in_kill_range(dist, victim_radius): touch = death, inclusive.

var bounds := Rect2()                 # unused for clamping (salt never moves);
                                      # kept for spawn-point math symmetry
var _sprite: Sprite2D = null


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = Art.tex("salt_crystal")
	_sprite.scale = Vector2.ONE * Feel.SALT_SPRITE_SCALE
	add_child(_sprite)
	# pop-in entrance, then a slow menacing spin forever
	_sprite.scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector2.ONE * Feel.SALT_POP_SCALE * Feel.SALT_SPRITE_SCALE,
		Feel.SALT_POP_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sprite, "scale", Vector2.ONE * Feel.SALT_SPRITE_SCALE,
		Feel.SALT_POP_SEC * 0.6)
	var spin := create_tween().set_loops()
	spin.tween_property(_sprite, "rotation", TAU, Feel.SALT_SPIN_SEC)


## Seconds between salt spawns at this score. Rises-with-score means the
## INTERVAL falls: base at zero score, floor at SALT_MIN_SPAWN_SEC.
static func spawn_interval(score: int) -> float:
	var s := Feel.SALT_BASE_SPAWN_SEC - float(score) * Feel.SALT_RATE_PER_POINT
	return clampf(s, Feel.SALT_MIN_SPAWN_SEC, Feel.SALT_BASE_SPAWN_SEC)


## Touch = death (inclusive at the boundary). victim_radius is the slug or bug
## body radius, so a crystal kills anything whose body reaches its edge.
static func in_kill_range(dist: float, victim_radius: float) -> bool:
	return dist <= Feel.SALT_RADIUS + victim_radius


## Slug shiver strength 0..1 for the current nearest-crystal distance.
static func shiver_strength(dist: float) -> float:
	if dist >= Feel.SALT_SHIVER_RADIUS:
		return 0.0
	return 1.0 - clampf(dist / Feel.SALT_SHIVER_RADIUS, 0.0, 1.0)
