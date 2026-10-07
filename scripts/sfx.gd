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
