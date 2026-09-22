extends Node2D
## The title screen — the garden before the run. The logo over a live garden:
## a slug drifts a slow Lissajous through wandering bugs (the same Slug/Bug
## scenes, driven through the real TiltSource synthetic pipeline), TAP TO
## SLITHER pulses, the jam stamp sits at the bottom. Any tap starts the game.
##
## Owns the persisted mute toggle at the moment the player can actually read.

var run_state := RunState.new()
var sfx: SfxManager = null

var _area := Rect2()
var _slug: Slug = null
var _t := 0.0
var _started := false
var _sound_button: Button = null


func _ready() -> void:
	_area = Rect2(Vector2.ZERO, get_viewport_rect().size)
	_setup_background()
	_setup_critters()
	_setup_ui()
	run_state.load_state()
	sfx = SfxManager.new()
	add_child(sfx)
	sfx.set_muted(run_state.muted)
	sfx.play("title")


func _process(delta: float) -> void:
	# The drifting slug is fed through the REAL input pipeline (synthetic mode
	# of the same TiltSource the touch drag uses) — no special title code path.
	_t += delta
	if _slug != null and is_instance_valid(_slug):
		_slug.tilt_x.push_tilt(cos(_t * TAU / Feel.TITLE_DRIFT_TURN_SEC) * 0.55)
		_slug.tilt_y.push_tilt(sin(_t * TAU / (Feel.TITLE_DRIFT_TURN_SEC * 1.6)) * 0.55)


func _unhandled_input(event: InputEvent) -> void:
	var tapped := false
	if event is InputEventScreenTouch and event.pressed:
		tapped = true
	elif event is InputEventMouseButton and event.pressed:
		tapped = true
	if tapped:
		start_game()


func start_game() -> void:
	if _started:
		return
	_started = true
	if get_tree().change_scene_to_file(Feel.GAME_SCENE_PATH) != OK:
		# SceneTree scripts / odd boots may have no current scene to swap;
		# the garden still opens.
		var game: Node = (load(Feel.GAME_SCENE_PATH) as PackedScene).instantiate()
		get_tree().root.add_child(game)
		get_tree().current_scene = game


## The wandering field behind the logo: one real slug on a slow drift, real
## bugs scattering from it. Everything here is the game's own scenes.
func _setup_critters() -> void:
	_slug = (load("res://scenes/slug.tscn") as PackedScene).instantiate()
	_slug.bounds = _area
	_slug.set_input_mode(TiltSource.MODE_SYNTHETIC)
	_slug.global_position = _area.get_center()
	add_child(_slug)
	for i in Feel.TITLE_BUG_COUNT:
		var bug: Bug = (load("res://scenes/bug.tscn") as PackedScene).instantiate()
		bug.slug = _slug
		bug.bounds = _area
		bug.rng.seed = 77000 + i * 104729
		bug.global_position = Vector2(
			randf_range(_area.position.x + 60.0, _area.end.x - 60.0),
			randf_range(_area.position.y + 260.0, _area.end.y - 120.0))
		add_child(bug)


func _setup_ui() -> void:
	var logo := Sprite2D.new()
	logo.name = "Logo"
	logo.texture = Art.tex("title_logo")
	var tex_size := logo.texture.get_size()
	var s := Feel.TITLE_LOGO_WIDTH_PX / maxf(tex_size.x, 1.0)
	logo.scale = Vector2.ONE * s
	logo.position = Vector2(_area.get_center().x, Feel.TITLE_LOGO_Y)
	add_child(logo)
	var bob := create_tween().set_loops()
	bob.tween_property(logo, "position:y", Feel.TITLE_LOGO_Y - Feel.TITLE_LOGO_BOB_PX,
		Feel.TITLE_LOGO_BOB_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(logo, "position:y", Feel.TITLE_LOGO_Y + Feel.TITLE_LOGO_BOB_PX,
		Feel.TITLE_LOGO_BOB_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	var tap := _make_label(Feel.TITLE_TAP_SIZE, Feel.HUD_OUTLINE_SIZE)
	tap.text = Feel.TITLE_TAP_TEXT
	tap.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tap.position.y = Feel.TITLE_TAP_Y
	root.add_child(tap)
	var pulse := create_tween().set_loops()
	pulse.tween_property(tap, "modulate:a", 0.3, Feel.TITLE_PULSE_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(tap, "modulate:a", 1.0, Feel.TITLE_PULSE_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var stamp := _make_label(Feel.TITLE_STAMP_SIZE, Feel.HUD_OUTLINE_SIZE)
	stamp.text = Feel.TITLE_VERSION_STAMP
	stamp.modulate.a = 0.8
	stamp.set_anchors_preset(Control.PRESET_TOP_WIDE)
	stamp.position.y = Feel.TITLE_STAMP_Y
	root.add_child(stamp)

	_sound_button = Button.new()
	_sound_button.text = "SOUND ON"
	_sound_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_sound_button.position = Vector2(Feel.HUD_MARGIN_PX, Feel.HUD_MARGIN_PX)
	_sound_button.pressed.connect(_on_sound_pressed)
	root.add_child(_sound_button)
	_refresh_sound_text()


func _on_sound_pressed() -> void:
	run_state.set_muted(not run_state.muted)
	if sfx != null:
		sfx.set_muted(run_state.muted)
	_refresh_sound_text()


func _refresh_sound_text() -> void:
	_sound_button.text = "SOUND OFF" if run_state.muted else "SOUND ON"


func _make_label(size: int, outline: int) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = Feel.TITLE_TEXT_COLOR
	ls.outline_size = outline
	ls.outline_color = Feel.HUD_OUTLINE_COLOR
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Same tiled garden floor as the game (spec art tile_garden, fallback flat).
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
