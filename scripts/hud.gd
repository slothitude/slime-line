class_name WordHud
extends CanvasLayer
## HUD v1 — the top strip: the target word as letter slots (filled/unfilled),
## score, chain multiplier, bugs eaten. Chunky outlined labels over the garden.
##
## Pure-ish display: every set_* just updates labels, so the battery can assert
## on them. The juice half (shake on a wrong letter, slot pop + letter fly on
## an advance, confetti on a completed word) is plain tweens and never blocks.

var _root: Control
var _score_label: Label
var _mult_label: Label
var _bugs_label: Label
var _run_label: Label
var _slots_shaker: Control
var _slots_box: HBoxContainer
var _slot_labels: Array[Label] = []

var _word := ""
var _progress := 0


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top"]:
		margin.add_theme_constant_override(side, int(Feel.HUD_MARGIN_PX))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(top)
	_score_label = _make_label(Feel.HUD_FONT_SIZE)
	top.add_child(_score_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)
	_mult_label = _make_label(Feel.HUD_FONT_SIZE)
	top.add_child(_mult_label)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(center)
	_slots_shaker = Control.new()
	_slots_shaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_slots_shaker)
	_slots_box = HBoxContainer.new()
	_slots_box.add_theme_constant_override("separation", int(Feel.HUD_SLOT_GAP_PX))
	_slots_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slots_shaker.add_child(_slots_box)

	var bottom := HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(bottom)
	_bugs_label = _make_label(Feel.HUD_FONT_SIZE)
	bottom.add_child(_bugs_label)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(gap)
	_run_label = _make_label(Feel.HUD_FONT_SIZE)
	bottom.add_child(_run_label)

	_rebuild_slots()
	set_score(0)
	set_mult(1.0)
	set_bugs(0)
	set_run(1)


func _make_label(font_size: int) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = font_size
	ls.font_color = Feel.HUD_TEXT_COLOR
	ls.outline_size = Feel.HUD_OUTLINE_SIZE
	ls.outline_color = Feel.HUD_OUTLINE_COLOR
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# ------------------------------------------------------------------- state --

## Deal a new word: rebuild the slot row.
func set_word(word: String) -> void:
	_word = word
	_progress = mini(_progress, word.length())
	_rebuild_slots()


## Fill the first n slots.
func set_progress(n: int) -> void:
	_progress = clampi(n, 0, _word.length())
	_refresh_slots()


func set_score(v: int) -> void:
	_score_label.text = "SCORE %d" % v


func set_mult(v: float) -> void:
	_mult_label.text = "x%.1f" % v


func set_bugs(n: int) -> void:
	_bugs_label.text = "BUGS %d" % n


func set_run(n: int) -> void:
	_run_label.text = Feel.RUN_LABEL_FORMAT % n


func word_text() -> String:
	return _word


func slot_count() -> int:
	return _slot_labels.size()


## What slot i shows right now ("A" filled or "_" empty).
func slot_letter(i: int) -> String:
	if i < 0 or i >= _slot_labels.size():
		return ""
	return _slot_labels[i].text


## Screen-space center of slot i — where a flying letter lands.
func slot_center(i: int) -> Vector2:
	if i < 0 or i >= _slot_labels.size():
		return Vector2.ZERO
	return _slot_labels[i].get_global_rect().get_center()


func _rebuild_slots() -> void:
	for l in _slot_labels:
		l.queue_free()
	_slot_labels.clear()
	for i in _word.length():
		var l := _make_slot()
		_slots_box.add_child(l)
		_slot_labels.append(l)
	_refresh_slots()


func _make_slot() -> Label:
	var l := _make_label(Feel.HUD_SLOT_FONT_SIZE)
	l.custom_minimum_size = Vector2(30.0, 48.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.pivot_offset = l.custom_minimum_size * 0.5
	return l


func _refresh_slots() -> void:
	for i in _slot_labels.size():
		var filled := i < _progress
		_slot_labels[i].text = _word[i] if filled else Feel.HUD_SLOT_EMPTY_GLYPH
		var ls := _slot_labels[i].label_settings
		ls.font_size = Feel.HUD_SLOT_FONT_SIZE
		ls.outline_size = Feel.HUD_SLOT_OUTLINE_SIZE
		ls.font_color = Feel.HUD_SLOT_FILLED_COLOR if filled else Feel.HUD_SLOT_EMPTY_COLOR


# ------------------------------------------------------------------- juice --

## Wrong letter: the word row rattles.
func shake_word() -> void:
	if _slots_box == null:
		return
	var tw := create_tween()
	for s in Feel.WORD_SHAKE_SWINGS:
		var dir := 1.0 if s % 2 == 0 else -1.0
		tw.tween_property(_slots_box, "position:x",
			dir * Feel.WORD_SHAKE_PX, Feel.WORD_SHAKE_SWING_SEC)
	tw.tween_property(_slots_box, "position:x", 0.0, Feel.WORD_SHAKE_SWING_SEC)


## Just-filled slot pops.
func pop_slot(i: int) -> void:
	if i < 0 or i >= _slot_labels.size():
		return
	var l := _slot_labels[i]
	l.pivot_offset = l.custom_minimum_size * 0.5
	l.scale = Vector2.ONE * Feel.SLOT_POP_SCALE
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, Feel.SLOT_POP_SEC) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The eaten letter flies from the bug to the slot it just filled.
func fly_letter(from_screen: Vector2, letter: String, slot: int) -> void:
	if slot < 0 or slot >= _slot_labels.size():
		return
	var fly := _make_label(Feel.LETTER_FLY_FONT_SIZE)
	fly.text = letter
	fly.z_index = 50
	_root.add_child(fly)
	fly.position = from_screen - Vector2(12.0, 20.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(fly, "position", slot_center(slot) - Vector2(12.0, 22.0),
		Feel.LETTER_FLY_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(fly, "scale", Vector2(0.6, 0.6), Feel.LETTER_FLY_SEC)
	tw.chain().tween_callback(func() -> void:
		pop_slot(slot)
		fly.queue_free())


## Word complete: a burst of garden confetti from the word row...
func confetti() -> void:
	var origin := _slots_shaker.get_global_rect().get_center()
	for i in Feel.CONFETTI_COUNT:
		var dir := Vector2.from_angle(TAU * float(i) / float(Feel.CONFETTI_COUNT) + 0.35)
		_burst_bit(origin, dir, _confetti_speed(i, Feel.CONFETTI_SPEED, 0.6, 1.15),
			Feel.CONFETTI_SEC, i)
	# ...and the big one: a ring from screen center so the whole garden hears it
	var center := _root.get_global_rect().get_center()
	for i in Feel.CONFETTI_BIG_COUNT:
		var dir := Vector2.from_angle(
			TAU * float(i) / float(Feel.CONFETTI_BIG_COUNT) + 0.11)
		_burst_bit(center, dir, _confetti_speed(i + 3, Feel.CONFETTI_BIG_SPEED, 0.8, 1.2),
			Feel.CONFETTI_BIG_SEC, i + 1)


## Deterministic variety (no global RNG: the seeded replays reproduce the run
## from it — every draw spent here would reshuffle the world).
func _confetti_speed(i: int, base: float, lo: float, hi: float) -> float:
	var frac := float((i * 37) % 100) / 100.0
	return base * (lo + (hi - lo) * frac)


func _burst_bit(origin: Vector2, dir: Vector2, speed: float, secs: float, i: int) -> void:
	var bit := ColorRect.new()
	bit.color = Feel.CONFETTI_COLORS[i % Feel.CONFETTI_COLORS.size()]
	bit.size = Feel.CONFETTI_SIZE_PX
	bit.position = origin
	bit.rotation = float(i % 9) * 0.7
	bit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bit)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(bit, "position", origin + dir * speed,
		secs).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(bit, "modulate:a", 0.0, secs)
	tw.chain().tween_callback(bit.queue_free)


## The earned points fly off the bug and fade as they rise.
func fly_score(from_screen: Vector2, points: int, gold := false) -> void:
	var fly := _make_label(Feel.SCORE_FLY_FONT_SIZE)
	fly.text = "+%d" % points
	fly.label_settings.font_color = Feel.SCORE_FLY_GOLD_COLOR if gold else Feel.SCORE_FLY_COLOR
	fly.z_index = 50
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(fly)
	fly.position = from_screen - Vector2(20.0, 10.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(fly, "position:y", fly.position.y - Feel.SCORE_FLY_RISE_PX,
		Feel.SCORE_FLY_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(fly, "modulate:a", 0.0, Feel.SCORE_FLY_SEC)
	tw.chain().tween_callback(fly.queue_free)


## Chain went up: the multiplier badge throbs once.
func pulse_mult() -> void:
	_mult_label.pivot_offset = _mult_label.size * 0.5
	_mult_label.scale = Vector2.ONE * Feel.MULT_PULSE_SCALE
	var tw := create_tween()
	tw.tween_property(_mult_label, "scale", Vector2.ONE, Feel.MULT_PULSE_SEC) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
