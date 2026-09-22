class_name SfxManager
extends Node
## Procedural sound bank — the octogram-arcade SfxManager pattern (cue names in,
## round-robin voice pool out) with every stream SYNTHESIZED in code instead of
## preloaded WAVs, per spec law "original_assets: ... procedural SFX (owned,
## in-house generated)". No audio files ship; the whole score is deterministic
## PCM built once at _ready.
##
## The 8 cues:
##   step   squelch-step — soft noise blip while gliding fast
##   chomp  eating any bug
##   wrong  wrong-letter buzz
##   word   word-complete arpeggio + confetti pop
##   gold   gold-bug sparkle
##   salt   salt-death crunch (slug or bug)
##   over   game-over low drone
##   title  title-screen sting
##
## Pool: Feel.SFX_POOL_SIZE AudioStreamPlayers round-robin, so overlapping cues
## never cut each other off. Mute is a hard gate on play() and also silences
## anything mid-voice.

const POOL_SIZE := Feel.SFX_POOL_SIZE
const MIX_RATE := Feel.SFX_MIX_RATE
const CUES := ["step", "chomp", "wrong", "word", "gold", "salt", "over", "title"]

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _muted := false


func _ready() -> void:
	for cue in CUES:
		_streams[cue] = _synthesize(cue)
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "SfxVoice%d" % i
		player.volume_db = linear_to_db(Feel.MASTER_VOLUME)
		add_child(player)
		_pool.append(player)


## Play a cue by name. False when muted, unknown, or not in the tree yet.
func play(cue: String) -> bool:
	if _muted or not _streams.has(cue) or _pool.is_empty():
		return false
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stop()
	player.stream = _streams[cue]
	player.play()
	return true


func cue_names() -> Array:
	return CUES.duplicate()


func has_stream(cue: String) -> bool:
	return _streams.has(cue) and _streams[cue] != null


## Mute/unmute; muting also silences anything currently playing.
func set_muted(muted: bool) -> void:
	_muted = muted
	if _muted:
		for player in _pool:
			player.stop()


func is_muted() -> bool:
	return _muted


func playing_voices() -> int:
	var n := 0
	for player in _pool:
		if player.playing:
			n += 1
	return n


# ---------------------------------------------------------------- synthesis --

static func _synthesize(cue: String) -> AudioStreamWAV:
	var s := {}
	match cue:
		"step":
			s = _step()
		"chomp":
			s = _chomp()
		"wrong":
			s = _wrong()
		"word":
			s = _word()
		"gold":
			s = _gold()
		"salt":
			s = _salt()
		"over":
			s = _over()
		"title":
			s = _title()
	return _bake(s.samples, s.peak)


## Deterministic noise: same numbers every boot, so tests and replays are
## reproducible and the "generated in-house" provenance is provable.
static func _noise(seed_val: int, n: int) -> PackedFloat32Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = r.randf_range(-1.0, 1.0)
	return out


## One sine/tri/square partial swept f0 -> f1 over n samples.
static func _partial(n: int, f0: float, f1: float, shape := "sine") -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(maxi(n - 1, 1))
		var f := lerpf(f0, f1, t)
		phase += TAU * f / float(MIX_RATE)
		var v := 0.0
		match shape:
			"sine":
				v = sin(phase)
			"tri":
				v = 2.0 / PI * asin(sin(phase))
			"square":
				v = signf(sin(phase))
			"saw":
				v = 2.0 * fposmod(phase / TAU, 1.0) - 1.0
		out[i] = v
	return out


## Attack + exponential release envelope over n samples.
static func _env(n: int, attack_sec: float, curve := 2.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var attack_n := int(attack_sec * float(MIX_RATE))
	for i in n:
		var t := float(i) / float(maxi(n - 1, 1))
		var a := 1.0
		if attack_n > 0 and i < attack_n:
			a = float(i) / float(attack_n)
		out[i] = a * pow(1.0 - t, curve)
	return out


static func _mix(layers: Array, gains: Array, n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for l in layers.size():
		var layer: PackedFloat32Array = layers[l]
		var gain: float = gains[l]
		for i in n:
			out[i] += layer[i] * gain
	return out


## Scale to peak amplitude (<= 1.0) and bake to a 16-bit mono AudioStreamWAV.
static func _bake(samples: PackedFloat32Array, peak: float) -> AudioStreamWAV:
	var n := samples.size()
	var top := 0.0001
	for i in n:
		top = maxf(top, absf(samples[i]))
	var norm := peak / top
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(samples[i] * norm, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


## Arpeggio helper: one partial per note, each faded in/out, laid end to end
## with overlap. notes = [[freq, seconds], ...]
static func _arp(notes: Array, shape: String, overlap := 0.35, curve := 1.6) -> PackedFloat32Array:
	var total := 0.0
	for note in notes:
		total += note[1]
	total *= 1.0 + overlap * 0.5
	var n := int(total * float(MIX_RATE))
	var out := PackedFloat32Array()
	out.resize(n)
	var cursor := 0.0
	for note in notes:
		var len_n := int(note[1] * float(MIX_RATE))
		var tone := _partial(len_n, note[0], note[0], shape)
		var env := _env(len_n, 0.008, curve)
		for i in len_n:
			var at := cursor + i
			if at >= n:
				break
			out[at] += tone[i] * env[i]
		cursor += int(float(len_n) * (1.0 - overlap * 0.5))
	return out


# ------------------------------------------------------------------- recipes --

## squelch-step: low-passed soft noise blip with a wet low sine under it.
static func _step() -> Dictionary:
	var n := int(0.09 * float(MIX_RATE))
	var raw := _noise(0x517EF, n)
	var smooth := PackedFloat32Array()
	smooth.resize(n)
	var acc := 0.0
	for i in n:  # cheap one-pole low-pass = the soft squelch
		acc += (raw[i] - acc) * 0.22
		smooth[i] = acc
	var low := _partial(n, 170.0, 110.0)
	var env := _env(n, 0.004, 3.2)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = (smooth[i] * 0.75 + low[i] * 0.45) * env[i]
	return {"samples": out, "peak": 0.5}


## chomp: fast downward square blip plus a crisp noise click on the bite.
static func _chomp() -> Dictionary:
	var n := int(0.14 * float(MIX_RATE))
	var bite := _partial(n, 540.0, 210.0, "square")
	var click := _noise(0x3B0FF, n)
	var env := _env(n, 0.002, 3.8)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var click_gate := 1.0 if i < n / 6 else 0.0
		out[i] = (bite[i] * 0.62 + click[i] * 0.5 * click_gate) * env[i]
	return {"samples": out, "peak": 0.6}


## wrong-buzz: two detuned squares beating against each other, flat and sour.
static func _wrong() -> Dictionary:
	var n := int(0.26 * float(MIX_RATE))
	var a := _partial(n, 128.0, 128.0, "square")
	var b := _partial(n, 137.0, 135.0, "square")
	var env := _env(n, 0.004, 1.4)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = (a[i] * 0.5 + b[i] * 0.5) * env[i]
	return {"samples": out, "peak": 0.45}


## word-complete: rising arpeggio, then the confetti pop.
static func _word() -> Dictionary:
	var arp := _arp([
		[523.25, 0.11], [659.25, 0.11], [783.99, 0.11], [1046.5, 0.2],
	], "tri", 0.4, 1.3)
	var n := arp.size()
	var pop_n := int(0.09 * float(MIX_RATE))
	var pop_src := _noise(0xC0FFE1, pop_n)
	var pop := PackedFloat32Array()
	pop.resize(n)
	var pop_start := n - pop_n
	for i in pop_n:
		pop[pop_start + i] = pop_src[i] * pow(1.0 - float(i) / float(pop_n), 2.5)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = arp[i] * 0.8 + pop[i] * 0.55
	return {"samples": out, "peak": 0.62}


## gold sparkle: quick shimmer run up top, tiny bell tail.
static func _gold() -> Dictionary:
	var arp := _arp([
		[1046.5, 0.05], [1318.5, 0.05], [1568.0, 0.05], [2093.0, 0.14],
	], "sine", 0.55, 2.2)
	var n := arp.size()
	var shine := _noise(0x601DE, n)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = arp[i] * 0.85 + shine[i] * 0.06
	return {"samples": out, "peak": 0.5}


## salt-death crunch: harsh falling noise + a sick downward sweep.
static func _salt() -> Dictionary:
	var n := int(0.42 * float(MIX_RATE))
	var crush := _noise(0x5A1E, n)
	var sweep := _partial(n, 320.0, 52.0, "saw")
	var env := _env(n, 0.002, 2.6)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = (crush[i] * 0.8 + sweep[i] * 0.6) * env[i]
	return {"samples": out, "peak": 0.72}


## game-over low: a long descending drone with a sad slow release.
static func _over() -> Dictionary:
	var n := int(0.95 * float(MIX_RATE))
	var drone := _partial(n, 196.0, 49.0, "sine")
	var growl := _partial(n, 98.0, 24.5, "tri")
	var env := _env(n, 0.03, 1.8)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = (drone[i] * 0.7 + growl[i] * 0.4) * env[i]
	return {"samples": out, "peak": 0.6}


## title sting: a soft rising chord that blooms and settles.
static func _title() -> Dictionary:
	var arp := _arp([
		[392.0, 0.22], [493.88, 0.22], [587.33, 0.5],
	], "sine", 0.7, 1.2)
	var n := arp.size()
	var air := _noise(0x71B1E, n)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = arp[i] * 0.9 + air[i] * 0.03
	return {"samples": out, "peak": 0.45}
