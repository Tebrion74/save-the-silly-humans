class_name Sfx
extends RefCounted
## Build 014: tiny procedural sound effects. Build 015b: every game sound is
## generated here (whip, grab, saves, hits, pickups, cam, boss, stingers, UI).
## Music is the only audio file (assets/audio, made by tools/gen_music.py).

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
		# ---------------------------------------------------- build 015b game-wide
		"crack":     # whip crack: a hard click into a bright, fast-decaying hiss
			var n := int(rate * 0.16)
			var prev := 0.0
			for i in n:
				var u := float(i) / rate
				var w := rng.randf_range(-1.0, 1.0)
				var hp := w - prev
				prev = w
				var click := (1.0 if i % 9 < 4 else -1.0) * 0.6 if i < 90 else 0.0
				s.append((hp * 0.7 + click) * exp(-u * 38.0))
		"crack_fire":   # crack + a low fwoosh
			var n := int(rate * 0.3)
			var prev := 0.0
			var lp := 0.0
			for i in n:
				var u := float(i) / rate
				var w := rng.randf_range(-1.0, 1.0)
				lp = lerpf(lp, w, 0.12)
				var hp := w - prev
				prev = w
				s.append(hp * 0.55 * exp(-u * 40.0) + lp * 1.6 * sin(minf(u / 0.3, 1.0) * PI) * 0.6)
		"shock":     # shockwave boom
			var n := int(rate * 0.42)
			var ph := 0.0
			var lp := 0.0
			for i in n:
				var u := float(i) / n
				ph += TAU * lerpf(110.0, 38.0, u) / rate
				lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.15)
				s.append((sin(ph) * 0.75 + lp * 0.6) * pow(1.0 - u, 2.0))
		"grab":      # rising zip as the lash latches
			var n := int(rate * 0.13)
			var ph := 0.0
			for i in n:
				var u := float(i) / n
				ph += lerpf(280.0, 1100.0, u) / rate
				s.append((1.0 if fmod(ph, 1.0) < 0.3 else -1.0) * 0.22 * (1.0 - u * 0.6))
		"shot":      # whip-shot zap
			var n := int(rate * 0.16)
			var ph := 0.0
			for i in n:
				var u := float(i) / n
				ph += lerpf(1400.0, 260.0, u) / rate
				s.append((1.0 if fmod(ph, 1.0) < 0.5 else -1.0) * 0.2 * (1.0 - u))
		"explode":   # sheep / possessed pop: crunchy low noise + thump
			var n := int(rate * 0.45)
			var ph := 0.0
			var lp := 0.0
			for i in n:
				var u := float(i) / n
				ph += TAU * lerpf(140.0, 45.0, u) / rate
				lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.35 - 0.25 * u)
				var crush := floorf(lp * 6.0) / 6.0
				s.append((crush * 0.8 + sin(ph) * 0.5) * pow(1.0 - u, 1.8))
		"save":      # human reaches the safe zone: bright two-note chime
			s = _notes([[784.0, 0.07], [1047.0, 0.16]], 0.22, 0.25)
		"save_possessed":   # possessed saved: little arpeggio
			s = _notes([[523.0, 0.05], [659.0, 0.05], [784.0, 0.05], [1047.0, 0.16]], 0.2, 0.25)
		"hurt":      # rancher loses a heart
			s = _notes([[420.0, 0.05], [300.0, 0.06], [180.0, 0.12]], 0.3, 0.5)
		"possessed":    # a human turns: eerie falling warble
			var n := int(rate * 0.4)
			var ph := 0.0
			for i in n:
				var u := float(i) / n
				ph += (lerpf(520.0, 220.0, u) + sin(u * 60.0) * 30.0) / rate
				s.append((1.0 if fmod(ph, 1.0) < 0.5 else -1.0) * 0.14 * (1.0 - u))
		"karen":     # Karen forms: angry buzz
			var n := int(rate * 0.45)
			var ph := 0.0
			for i in n:
				var u := float(i) / n
				ph += (130.0 + sin(u * 70.0) * 18.0) / rate
				s.append((fmod(ph, 1.0) * 2.0 - 1.0) * 0.22 * (1.0 - u * 0.7))
		"pickup":    # power-up collected
			s = _notes([[988.0, 0.05], [1319.0, 0.05], [1568.0, 0.12]], 0.2, 0.25)
		"rec_start":    # camcorder REC: double beep
			s = _notes([[1568.0, 0.05], [0.0, 0.03], [1568.0, 0.07]], 0.13, 0.5)
		"rec_stop":
			s = _notes([[1175.0, 0.08]], 0.11, 0.5)
		"rec_tick":     # soft tick every second while recording
			s = _notes([[2093.0, 0.018]], 0.07, 0.5)
		"swing":     # camcorder swing: low whoosh + thump
			var n := int(rate * 0.24)
			var lp := 0.0
			var ph := 0.0
			for i in n:
				var u := float(i) / n
				lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.05 + 0.1 * u)
				ph += TAU * 90.0 / rate
				var thump := sin(ph) * 0.7 * maxf(0.0, (u - 0.55) / 0.45) * pow(1.0 - u, 0.5) * 2.0
				s.append(lp * 2.2 * sin(u * PI) * 0.5 + thump * 0.5)
		"no_battery":
			s = _notes([[220.0, 0.1], [0.0, 0.04], [165.0, 0.16]], 0.18, 0.5)
		"viral":     # filmed Karen goes viral
			s = _notes([[659.0, 0.05], [784.0, 0.05], [988.0, 0.05], [1319.0, 0.05], [1568.0, 0.2]], 0.18, 0.25)
		"click":     # UI click
			s = _notes([[1250.0, 0.018], [820.0, 0.025]], 0.16, 0.5)
		"start":     # START / NEXT LEVEL
			s = _notes([[523.0, 0.05], [784.0, 0.05], [1047.0, 0.12]], 0.18, 0.5)
		"swap":      # weapon swap
			s = _notes([[660.0, 0.03], [990.0, 0.045]], 0.12, 0.25)
		"win":       # round won stinger
			s = _notes([[523.0, 0.11], [659.0, 0.11], [784.0, 0.11], [1047.0, 0.26], [0.0, 0.05], [988.0, 0.1], [1047.0, 0.5]], 0.2, 0.5)
		"lose":      # game over stinger
			s = _notes([[392.0, 0.2], [330.0, 0.2], [262.0, 0.2], [0.0, 0.05], [196.0, 0.6]], 0.2, 0.5)
		"shield":    # boss PHOTO OP shimmer
			s = _notes([[1568.0, 0.03], [2093.0, 0.03], [1568.0, 0.03], [2093.0, 0.03], [1760.0, 0.03], [2349.0, 0.06]], 0.1, 0.5)
		"contact":   # rancher bumps into the boss
			s = _notes([[300.0, 0.04], [150.0, 0.1]], 0.3, 0.5)
		# ---------------------------------------------------- build 016
		"pop":       # bonus / micro sheep pop: short bright noise burst + blip
			var n := int(rate * 0.16)
			var ph := 0.0
			var lp := 0.0
			for i in n:
				var u := float(i) / n
				ph += TAU * lerpf(900.0, 300.0, u) / rate
				lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.5)
				s.append((sin(ph) * 0.5 + lp * 0.5) * pow(1.0 - u, 2.2))
		"perfect":   # a whole wave popped: quick rising sparkle
			s = _notes([[784.0, 0.04], [988.0, 0.04], [1175.0, 0.04], [1568.0, 0.04], [1976.0, 0.12]], 0.18, 0.25)
		"tally":     # tally count tick
			s = _notes([[1760.0, 0.02]], 0.1, 0.5)
		"clicker":   # presentation clicker: tiny double click
			s = _notes([[2600.0, 0.008], [0.0, 0.03], [2200.0, 0.01]], 0.25, 0.5)
		"spawn_glitch":   # digital glitch: random square blips
			for k in 9:
				var f := rng.randf_range(300.0, 2400.0)
				var nn := int(rate * rng.randf_range(0.012, 0.03))
				for i in nn:
					s.append((1.0 if fmod(float(i) * f / rate, 1.0) < 0.5 else -1.0) * 0.16 * (1.0 - float(k) / 12.0))
		"split":     # programmed sheep splits: metallic crunch + three blips
			var n := int(rate * 0.12)
			var lp := 0.0
			for i in n:
				var u := float(i) / n
				lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.6)
				s.append(floorf(lp * 4.0) / 4.0 * 0.6 * (1.0 - u))
			s.append_array(_notes([[1320.0, 0.03], [1760.0, 0.03], [2350.0, 0.04]], 0.15, 0.25))
		"update":    # SYSTEM UPDATE: rising sweep + chime
			var n := int(rate * 0.35)
			var ph := 0.0
			for i in n:
				var u := float(i) / n
				ph += lerpf(200.0, 1400.0, u * u) / rate
				s.append((1.0 if fmod(ph, 1.0) < 0.5 else -1.0) * 0.16 * (1.0 - u * 0.4))
			s.append_array(_notes([[1568.0, 0.06], [2093.0, 0.12]], 0.16, 0.5))
		"ray":       # lecture ray: buzzy falling zap
			var n := int(rate * 0.32)
			var ph := 0.0
			for i in n:
				var u := float(i) / n
				ph += (lerpf(1800.0, 500.0, u) + sin(u * 90.0) * 120.0) / rate
				s.append((fmod(ph, 1.0) * 2.0 - 1.0) * 0.2 * (1.0 - u))
		"rifle":     # Cantifa shot: short crack + low thud
			var n := int(rate * 0.09)
			for i in n:
				var u := float(i) / n
				var env := (1.0 - u) * (1.0 - u)
				s.append((rng.randf() * 2.0 - 1.0) * 0.45 * env)
			s.append_array(_notes([[140.0, 0.05], [90.0, 0.06]], 0.28, 0.3))
		"stagger":   # whip on a Cantifa: dull bonk
			s = _notes([[220.0, 0.05], [140.0, 0.08]], 0.28, 0.35)
		"flee":      # driven off: falling two-note scurry
			s = _notes([[660.0, 0.06], [440.0, 0.06], [300.0, 0.1]], 0.2, 0.4)
		"teleport":  # glitchy warble
			var n := int(rate * 0.22)
			var ph := 0.0
			for i in n:
				var u := float(i) / n
				ph += (600.0 + 500.0 * sin(u * 50.0)) / rate
				s.append((1.0 if fmod(ph, 1.0) < 0.5 else -1.0) * 0.14 * (1.0 - u))
		_:
			s = _notes([[880.0, 0.05]])
	var w := _wav(s, rate)
	_cache[sound_name] = w
	return w


## Build 015b: start / stop the background music through the GameAudio
## autoload (no-op when it isn't there, e.g. tool scripts).
static func music(node: Node, track: String) -> void:
	if node == null or not node.is_inside_tree():
		return
	var ga := node.get_tree().root.get_node_or_null("GameAudio")
	if ga == null:
		return
	if track == "":
		ga.stop_music()
	else:
		ga.play_music(track)


## Build 015b: per-sound limits so a burst (10 poutine splats, a shockwave
## popping 6 sheep) doesn't stack into a wall of noise.
const MIN_INTERVAL_MS := 35
const MAX_VOICES := 4
static var _last_ms: Dictionary = {}
static var _voices: Dictionary = {}
## Tests: how many one-shots have actually started, by name.
static var played: Dictionary = {}


## One-shot sound (frees itself), on the "SFX" bus. Build 015b: players live
## under the GameAudio autoload when it exists, so a sound isn't cut off when
## the node that triggered it is freed or the scene changes.
static func play(parent: Node, sound_name: String, volume_db: float = -10.0, pitch: float = 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(sound_name, -100000)) < MIN_INTERVAL_MS:
		return
	if int(_voices.get(sound_name, 0)) >= MAX_VOICES:
		return
	_last_ms[sound_name] = now
	var host: Node = parent.get_tree().root.get_node_or_null("GameAudio")
	if host == null:
		host = parent
	var p := AudioStreamPlayer.new()
	p.stream = get_sound(sound_name)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(p)
	_voices[sound_name] = int(_voices.get(sound_name, 0)) + 1
	played[sound_name] = int(played.get(sound_name, 0)) + 1
	p.finished.connect(func() -> void:
		_voices[sound_name] = maxi(int(_voices.get(sound_name, 1)) - 1, 0)
		p.queue_free())
	p.play()
