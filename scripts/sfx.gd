class_name Sfx
extends RefCounted
## Build 014: tiny procedural sound effects (the game ships no audio files).

static var _swap: AudioStreamWAV = null


## Two-tone camcorder "bip-bip" for a battery swap.
static func swap_beep() -> AudioStreamWAV:
	if _swap != null:
		return _swap
	var rate := 22050
	var data := PackedByteArray()
	var tones := [[1320.0, 0.07], [0.0, 0.03], [1760.0, 0.09]]
	for t in tones:
		var f: float = t[0]
		var n := int(rate * float(t[1]))
		for i in n:
			var v := 0.0
			if f > 0.0:
				var env := minf(1.0, minf(i / 60.0, (n - i) / 200.0))
				v = (1.0 if fmod(float(i) * f / rate, 1.0) < 0.5 else -1.0) * 0.35 * env
			var s := int(clampf(v, -1.0, 1.0) * 32767.0)
			data.append(s & 0xFF)
			data.append((s >> 8) & 0xFF)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	_swap = w
	return w


# ---------------------------------------------------------------- build 015 boss
## Procedural boss-fight sounds (cached). All 16-bit mono, 22.05 kHz.
static var _cache: Dictionary = {}


static func _wav(samples: PackedFloat32Array, rate: int = 22050) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var s := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


## Square-wave notes: [[freq, seconds], ...] (freq 0 = rest).
static func _notes(notes: Array, vol: float = 0.3, duty: float = 0.5) -> PackedFloat32Array:
	var rate := 22050
	var out := PackedFloat32Array()
	for t in notes:
		var f: float = t[0]
		var n := int(rate * float(t[1]))
		for i in n:
			var v := 0.0
			if f > 0.0:
				var env := minf(1.0, minf(i / 60.0, (n - i) / 300.0))
				v = (1.0 if fmod(float(i) * f / rate, 1.0) < duty else -1.0) * vol * env
			out.append(v)
	return out


static func get_sound(sound_name: String) -> AudioStreamWAV:
	if _cache.has(sound_name):
		return _cache[sound_name]
	var rate := 22050
	var s := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 15
	match sound_name:
		"throw":     # airy whoosh: filtered noise with a rising-then-falling envelope
			var n := int(rate * 0.22)
			var lp := 0.0
			for i in n:
				var u := float(i) / n
				lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.08 + 0.25 * u)
				s.append(lp * sin(u * PI) * 0.9)
		"splat":     # wet low thud: pitch-dropping sine + noise burst
			var n := int(rate * 0.26)
			var ph := 0.0
			var lp := 0.0
			for i in n:
				var u := float(i) / n
				ph += TAU * lerpf(180.0, 60.0, u) / rate
				lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.3)
				s.append((sin(ph) * 0.55 + lp * 0.45) * pow(1.0 - u, 1.6))
		"boss_hit":  # comic "bonk" (two falling square blips)
			s = _notes([[660.0, 0.05], [440.0, 0.07], [0.0, 0.01], [330.0, 0.08]], 0.28, 0.25)
		"windup":    # tiny rising tell
			s = _notes([[520.0, 0.04], [700.0, 0.04], [940.0, 0.05]], 0.12, 0.5)
		"pose":      # camera shutter chirp
			s = _notes([[1800.0, 0.02], [0.0, 0.02], [2400.0, 0.03]], 0.14, 0.5)
		"defeat":    # sad descending trombone-ish run
			s = _notes([[392.0, 0.16], [370.0, 0.16], [349.0, 0.16], [262.0, 0.5]], 0.22, 0.4)
		"fanfare":   # victory jingle
			s = _notes([[523.0, 0.1], [659.0, 0.1], [784.0, 0.1], [1047.0, 0.28], [0.0, 0.05], [784.0, 0.1], [1047.0, 0.4]], 0.2, 0.5)
		_:
			s = _notes([[880.0, 0.05]])
	var w := _wav(s, rate)
	_cache[sound_name] = w
	return w


## One-shot sound on `parent` (frees itself). Silently does nothing headless.
static func play(parent: Node, sound_name: String, volume_db: float = -10.0, pitch: float = 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := AudioStreamPlayer.new()
	p.stream = get_sound(sound_name)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
