class_name PixelFont
extends RefCounted
## Build 012: chunky Genesis/Mega Drive style bitmap font, drawn by hand (7x7
## glyphs, 2-px strokes) and baked at runtime into a FontFile with a dark 1-px
## outline and a drop shadow. Uppercase only — lowercase renders as uppercase.
## Glyph fill is white, so LabelSettings.font_color tints it (yellow labels,
## white numbers) while the outline/shadow stay dark.
## Use font sizes that are multiples of CELL (10): 20 = 2x, 30 = 3x, 40 = 4x.

const CELL := 10        ## fixed_size: 1 glyph px = font_size / CELL screen px
const ADVANCE := 9      ## glyph 7 + gap 2 (outlines merge between letters)
const SPACE_ADVANCE := 6
const ASCENT := 8
const DESCENT := 2
## Characters not in the table are mapped here before lookup.
const ALIASES := {"—": "-", "–": "-", "×": "x", "•": "·", "\"": "'"}

const GLYPHS := {
	"A": [".#####.", "##...##", "##...##", "#######", "##...##", "##...##", "##...##"],
	"B": ["######.", "##...##", "##...##", "######.", "##...##", "##...##", "######."],
	"C": [".#####.", "##...##", "##.....", "##.....", "##.....", "##...##", ".#####."],
	"D": ["#####..", "##..##.", "##...##", "##...##", "##...##", "##..##.", "#####.."],
	"E": ["#######", "##.....", "##.....", "######.", "##.....", "##.....", "#######"],
	"F": ["#######", "##.....", "##.....", "######.", "##.....", "##.....", "##....."],
	"G": [".#####.", "##...##", "##.....", "##.####", "##...##", "##...##", ".######"],
	"H": ["##...##", "##...##", "##...##", "#######", "##...##", "##...##", "##...##"],
	"I": [".#####.", "..###..", "..###..", "..###..", "..###..", "..###..", ".#####."],
	"J": ["....###", ".....##", ".....##", ".....##", "##...##", "##...##", ".#####."],
	"K": ["##...##", "##..##.", "##.##..", "####...", "##.##..", "##..##.", "##...##"],
	"L": ["##.....", "##.....", "##.....", "##.....", "##.....", "##.....", "#######"],
	"M": ["##...##", "###.###", "#######", "##.#.##", "##...##", "##...##", "##...##"],
	"N": ["##...##", "###..##", "####.##", "##.####", "##..###", "##...##", "##...##"],
	"O": [".#####.", "##...##", "##...##", "##...##", "##...##", "##...##", ".#####."],
	"P": ["######.", "##...##", "##...##", "######.", "##.....", "##.....", "##....."],
	"Q": [".#####.", "##...##", "##...##", "##...##", "##.#.##", "##..##.", ".###.##"],
	"R": ["######.", "##...##", "##...##", "######.", "##.##..", "##..##.", "##...##"],
	"S": [".#####.", "##...##", "##.....", ".#####.", ".....##", "##...##", ".#####."],
	"T": ["#######", "..###..", "..###..", "..###..", "..###..", "..###..", "..###.."],
	"U": ["##...##", "##...##", "##...##", "##...##", "##...##", "##...##", ".#####."],
	"V": ["##...##", "##...##", "##...##", "##...##", ".##.##.", "..###..", "...#..."],
	"W": ["##...##", "##...##", "##...##", "##.#.##", "#######", "###.###", "##...##"],
	"X": ["##...##", "##...##", ".##.##.", "..###..", ".##.##.", "##...##", "##...##"],
	"Y": ["##...##", "##...##", ".##.##.", "..###..", "..###..", "..###..", "..###.."],
	"Z": ["#######", "....##.", "...##..", "..##...", ".##....", "##.....", "#######"],
	"0": [".#####.", "##...##", "##..###", "##.#.##", "###..##", "##...##", ".#####."],
	"1": ["..###..", ".####..", "..###..", "..###..", "..###..", "..###..", ".#####."],
	"2": [".#####.", "##...##", ".....##", "..####.", ".##....", "##.....", "#######"],
	"3": [".#####.", "##...##", ".....##", "..####.", ".....##", "##...##", ".#####."],
	"4": ["...###.", "..####.", ".##.##.", "##..##.", "#######", "....##.", "....##."],
	"5": ["#######", "##.....", "######.", ".....##", ".....##", "##...##", ".#####."],
	"6": [".#####.", "##.....", "##.....", "######.", "##...##", "##...##", ".#####."],
	"7": ["#######", "##...##", "....##.", "...##..", "..##...", "..##...", "..##..."],
	"8": [".#####.", "##...##", "##...##", ".#####.", "##...##", "##...##", ".#####."],
	"9": [".#####.", "##...##", "##...##", ".######", ".....##", ".....##", ".#####."],
	":": [".......", "..##...", "..##...", ".......", "..##...", "..##...", "......."],
	"/": [".....##", "....##.", "...##..", "..##...", ".##....", "##.....", "......."],
	"+": [".......", "..##...", "..##...", "######.", "..##...", "..##...", "......."],
	"-": [".......", ".......", ".......", "######.", ".......", ".......", "......."],
	".": [".......", ".......", ".......", ".......", ".......", "..##...", "..##..."],
	",": [".......", ".......", ".......", ".......", "..##...", "..##...", ".##...."],
	"!": ["..##...", "..##...", "..##...", "..##...", "..##...", ".......", "..##..."],
	"?": [".#####.", "##...##", "....##.", "...##..", "...##..", ".......", "...##.."],
	"'": ["..##...", "..##...", ".##....", ".......", ".......", ".......", "......."],
	"(": ["...##..", "..##...", ".##....", ".##....", ".##....", "..##...", "...##.."],
	")": [".##....", "..##...", "...##..", "...##..", "...##..", "..##...", ".##...."],
	"x": [".......", ".......", "##...##", ".##.##.", "..###..", ".##.##.", "##...##"],
	"%": ["##...##", "##..##.", "...##..", "..##...", ".##....", "##..##.", "#...##."],
	"#": [".##.##.", "#######", ".##.##.", ".##.##.", ".##.##.", "#######", ".##.##."],
	"<": ["....##.", "...##..", "..##...", ".##....", "..##...", "...##..", "....##."],
	">": [".##....", "..##...", "...##..", "....##.", "...##..", "..##...", ".##...."],
	"=": [".......", ".......", "######.", ".......", "######.", ".......", "......."],
	"·": [".......", ".......", ".......", "..##...", "..##...", ".......", "......."],
	"©": [".#####.", "#.....#", "#.###.#", "#.#...#", "#.###.#", "#.....#", ".#####."],
}

static var _font: FontFile = null


static func get_font() -> FontFile:
	if _font == null:
		_font = _build()
	return _font


## LabelSettings in the HUD style: pixel font, colour fill, size multiple of CELL.
static func settings(scale: int, color: Color) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = get_font()
	ls.font_size = CELL * maxi(scale, 1)
	ls.font_color = color
	return ls


## Pixel width of `text` at integer `scale`.
static func text_width(text: String, scale: int) -> float:
	var w := 0
	for c in text:
		w += SPACE_ADVANCE if c == " " else ADVANCE
	return float(w * scale)


static func _build() -> FontFile:
	var chars: Array[String] = []
	for k in GLYPHS.keys():
		chars.append(k)
	for c in "abcdefghijklmnopqrstuvwyz":
		chars.append(c)
	for k in ALIASES.keys():
		chars.append(k)
	var cw := 10  # 7 + outline 1 each side + shadow 1
	var chh := 10
	var cols := 16
	var rows := int(ceil(float(chars.size()) / cols))
	var img := Image.create(cols * cw, rows * chh, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var f := FontFile.new()
	f.fixed_size = CELL
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.generate_mipmaps = false
	f.multichannel_signed_distance_field = false
	var size := Vector2i(CELL, 0)
	f.set_cache_ascent(0, CELL, ASCENT)
	f.set_cache_descent(0, CELL, DESCENT)
	for i in chars.size():
		var c: String = chars[i]
		var src := c
		if ALIASES.has(c):
			src = ALIASES[c]
		elif not GLYPHS.has(c) and GLYPHS.has(c.to_upper()):
			src = c.to_upper()
		var bits: Array = GLYPHS.get(src, [])
		var ox := (i % cols) * cw
		var oy := (i / cols) * chh
		_bake(img, bits, ox, oy)
		var cp := c.unicode_at(0)
		f.set_glyph_advance(0, CELL, cp, Vector2(ADVANCE, 0))
		f.set_glyph_offset(0, size, cp, Vector2(-1, -ASCENT))
		f.set_glyph_size(0, size, cp, Vector2(cw, chh))
		f.set_glyph_uv_rect(0, size, cp, Rect2(ox, oy, cw, chh))
		f.set_glyph_texture_idx(0, size, cp, 0)
	var sp := 32
	f.set_glyph_advance(0, CELL, sp, Vector2(SPACE_ADVANCE, 0))
	f.set_glyph_offset(0, size, sp, Vector2.ZERO)
	f.set_glyph_size(0, size, sp, Vector2.ZERO)
	f.set_glyph_uv_rect(0, size, sp, Rect2())
	f.set_glyph_texture_idx(0, size, sp, -1)
	f.set_texture_image(0, size, 0, img)
	return f


## Glyph at (+1,+1) in its cell; outline = 8-neighbour ring; shadow = whole shape +1,+1.
static func _bake(img: Image, bits: Array, ox: int, oy: int) -> void:
	if bits.is_empty():
		return
	var fill := {}
	for y in 7:
		var row: String = bits[y]
		for x in 7:
			if row[x] == "#":
				fill[Vector2i(x + 1, y + 1)] = true
	var ring := {}
	for p in fill.keys():
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var q: Vector2i = p + Vector2i(dx, dy)
				if not fill.has(q):
					ring[q] = true
	var shadow_col := Color(0.0, 0.0, 0.05, 0.55)
	for p in ring.keys():
		_put(img, ox, oy, p, Color(0.06, 0.03, 0.08, 1.0), false)
	for p in fill.keys():
		_put(img, ox, oy, p, Color(1, 1, 1, 1), false)
	for p in fill.keys():
		_put(img, ox, oy, p + Vector2i(1, 1), shadow_col, true)
	for p in ring.keys():
		_put(img, ox, oy, p + Vector2i(1, 1), shadow_col, true)


static func _put(img: Image, ox: int, oy: int, p: Vector2i, c: Color, only_empty: bool) -> void:
	if p.x < 0 or p.y < 0 or p.x >= 10 or p.y >= 10:
		return
	var x := ox + p.x
	var y := oy + p.y
	if only_empty and img.get_pixel(x, y).a > 0.0:
		return
	img.set_pixel(x, y, c)
