extends Node2D
## Milestone 1 playground (SLUG CORE): garden background, the slug at center,
## 8 wandering letter-bugs. Nothing else — letters/words/salt come later.

const SHOW_DEBUG := false

var _area := Rect2()
var _bugs: Array[Bug] = []
var _eaten_total := 0
var _debug_frames := 0

@onready var slug: Slug = $Slug
@onready var bugs_node: Node2D = $Bugs
@onready var debug_label: Label = $Debug


func _ready() -> void:
	_area = Rect2(Vector2.ZERO, get_viewport_rect().size)
	_setup_background()
	# Raw area: Slug.clamp_to_bounds applies SLUG_BOUNDS_MARGIN_PX itself, and
	# double-growing would open an untouchable dead zone at every wall.
	slug.bounds = _area
	for i in Feel.BUG_COUNT_TARGET:
		_spawn_bug(i)
	debug_label.visible = SHOW_DEBUG


func _process(_delta: float) -> void:
	var active := _count_active_bugs()
	# Spec: keep 6-9 bugs active at once — top up if a burst of eats dips us.
	if active < Feel.BUG_COUNT_MIN and _bugs.size() < Feel.BUG_COUNT_MAX:
		_spawn_bug(_bugs.size())
	if SHOW_DEBUG:
		_debug_frames += 1
		if _debug_frames % Feel.DEBUG_SAMPLE_EVERY_N_FRAMES == 0:
			debug_label.text = "speed %d px/s   trail %d pts   bugs %d   eaten %d" % [
				int(slug.velocity.length()), slug.trail.point_count(), active, _eaten_total]


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
	bug.global_position = _random_point(_area)
	bug.eaten.connect(_on_bug_eaten)
	bug.add_to_group("bugs")
	bugs_node.add_child(bug)
	_bugs.append(bug)


func _random_point(rect: Rect2) -> Vector2:
	return Vector2(
		randf_range(rect.position.x, rect.end.x),
		randf_range(rect.position.y, rect.end.y))


func _on_bug_eaten(_bug: Bug) -> void:
	_eaten_total += 1


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
