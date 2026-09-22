class_name Vignette
extends CanvasLayer
## Low-spec warning vignette: when the salt field runs hot (Feel.SALT_WARN_COUNT
## crystals or more) a red frame pulses at the screen edges. Pure display:
## set_level(0..1) drives it, nothing else.

var _root: Control
var _bars: Array[ColorRect] = []
var _level := 0.0
var _phase := 0.0


func _ready() -> void:
	layer = 15
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.modulate.a = 0.0
	add_child(_root)
	var t := Feel.VIGNETTE_THICKNESS_PX
	for def in [
		# [anchors, offsets] — top, bottom, left, right frame bars
		[Control.PRESET_TOP_WIDE, Vector2(0.0, 0.0)],
		[Control.PRESET_BOTTOM_WIDE, Vector2(0.0, -t)],
		[Control.PRESET_LEFT_WIDE, Vector2(0.0, 0.0)],
		[Control.PRESET_RIGHT_WIDE, Vector2(0.0, -t)],
	]:
		var bar := ColorRect.new()
		bar.color = Feel.VIGNETTE_COLOR
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(def[0])
		match def[0]:
			Control.PRESET_TOP_WIDE:
				bar.offset_bottom = t
			Control.PRESET_BOTTOM_WIDE:
				bar.offset_top = -t
			Control.PRESET_LEFT_WIDE:
				bar.offset_right = t
			Control.PRESET_RIGHT_WIDE:
				bar.offset_left = -t
		_root.add_child(bar)
		_bars.append(bar)


## 0 = dark, 1 = full warning pulse.
func set_level(level: float) -> void:
	_level = clampf(level, 0.0, 1.0)


func level() -> float:
	return _level


func frame_alpha() -> float:
	## What _process drives the bars to — exposed so the battery can assert the
	## ramp without waiting on a pulse phase.
	return _level * Feel.VIGNETTE_MAX_ALPHA


func _process(delta: float) -> void:
	_phase += delta * TAU / Feel.VIGNETTE_PULSE_SEC
	var pulse := 0.5 + 0.5 * sin(_phase)
	_root.modulate.a = _level * Feel.VIGNETTE_MAX_ALPHA * (0.55 + 0.45 * pulse)
