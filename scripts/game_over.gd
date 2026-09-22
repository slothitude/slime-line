class_name GameOver
extends CanvasLayer
## The end of a run (spec run.lives = 1): "THE GARDEN REMEMBERS", the score,
## the best, and a tap-anywhere RETRY. Owns the in-run mute toggle too — the
## only moments a dead slug can be bothered with settings.
##
## Display-only: setup() fills the labels, retry_pressed is the one output.

signal retry_pressed

var sfx: SfxManager = null
var run_state: RunState = null

var _dim: ColorRect
var _score_label: Label
var _best_label: Label
var _run_label: Label
var _hint: Label
var _sound_button: Button


func _ready() -> void:
	layer = Feel.GAME_OVER_LAYER
	_dim = ColorRect.new()
	_dim.color = Feel.GAME_OVER_DIM
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP  # a dead slug hears nothing
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.add_child(center)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var title := _make_label(Feel.GAME_OVER_TITLE_SIZE, Feel.GAME_OVER_TITLE_COLOR, 12)
	title.text = Feel.GAME_OVER_TITLE
	box.add_child(title)

	_score_label = _make_label(Feel.GAME_OVER_STAT_SIZE, Feel.GAME_OVER_TITLE_COLOR, 8)
	box.add_child(_score_label)
	_best_label = _make_label(Feel.GAME_OVER_STAT_SIZE, Feel.GAME_OVER_ACCENT_COLOR, 8)
	box.add_child(_best_label)
	_run_label = _make_label(Feel.GAME_OVER_STAT_SIZE, Feel.GAME_OVER_TITLE_COLOR, 8)
	box.add_child(_run_label)

	_hint = _make_label(Feel.GAME_OVER_STAT_SIZE, Feel.GAME_OVER_ACCENT_COLOR, 10)
	_hint.text = Feel.GAME_OVER_HINT
	box.add_child(_hint)
	var pulse := create_tween().set_loops()
	pulse.tween_property(_hint, "modulate:a", 0.25, Feel.GAME_OVER_PULSE_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(_hint, "modulate:a", 1.0, Feel.GAME_OVER_PULSE_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_sound_button = Button.new()
	_sound_button.text = "SOUND ON"
	_sound_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_sound_button.pressed.connect(_on_sound_pressed)
	box.add_child(_sound_button)


## Fill the story of the run that just ended.
func setup(score: int, best: int, run_number: int) -> void:
	_score_label.text = "SCORE %d" % score
	_best_label.text = Feel.BEST_LABEL_FORMAT % best
	_run_label.text = Feel.RUN_LABEL_FORMAT % run_number
	_refresh_sound_text()


## Any tap that is not on the sound button restarts the garden.
func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		retry_pressed.emit()
	elif event is InputEventMouseButton and event.pressed:
		retry_pressed.emit()


func _on_sound_pressed() -> void:
	var muted := not run_state.muted if run_state != null else true
	run_state.set_muted(muted)
	if sfx != null:
		sfx.set_muted(muted)
	_refresh_sound_text()


func _refresh_sound_text() -> void:
	var muted := run_state.muted if run_state != null else false
	_sound_button.text = "SOUND OFF" if muted else "SOUND ON"


func _make_label(size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = Feel.HUD_OUTLINE_COLOR
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
