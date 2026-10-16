class_name AttractMode
extends Control
## Build 028: arcade ATTRACT MODE for the title screen.
##
## When the title is idle for IDLE_SECONDS, it cycles through these pages
## (PAGE_SECONDS each):
##   TITLE (the normal title with PRESS START; this overlay is hidden)
##   -> MEET THE VILLAINS (3 pages, all 10 bosses: sprite, name, title, level slot)
##   -> SCORE TABLE (2 pages, Pac-Man / Galaga "character & points" rows)
##   -> HIGH SCORE (only when one is saved)
## Arcade transitions: a venetian-blind shutter between pages, rows that pop
## in one by one, and blinking "PRESS START".
## The title screen owns input: any input calls stop(). Point values are
## read from the game's own constants, so the table never drifts from the
## code.

const IDLE_SECONDS := 10.0
const PAGE_SECONDS := 7.0
const SHUTTER := 0.45            ## seconds for the blinds to close (then open)
const ROW_EVERY := 0.32          ## a score-table row pops in every 0.32 s
## Point values / tints read from these scripts' constants at runtime (load,
## not preload, so this file never forces them to compile early).
const LC_PATH := "res://scripts/level_controller.gd"
const HUMAN_PATH := "res://scripts/humans/human.gd"

static func _const(path: String, key: String) -> Variant:
	var sc: Script = load(path)
	return sc.get_script_constant_map().get(key) if sc != null else null

static func _pts(key: String) -> int:
	return int(_const(LC_PATH, key))

## Every boss: [name, title, after level, sheet, frame w]
static func bosses() -> Array:
	return [
		[LevelConfig.BOSS_NAME, LevelConfig.BOSS_TITLE, LevelConfig.BOSS_AFTER_LEVEL, "res://assets/boss/judeau_96.png", 96],
		[LevelConfig.BOSS2_NAME, LevelConfig.BOSS2_TITLE, LevelConfig.BOSS2_AFTER_LEVEL, "res://assets/boss2/huval_96.png", 96],
		[LevelConfig.BOSS3_NAME, LevelConfig.BOSS3_TITLE, LevelConfig.BOSS3_AFTER_LEVEL, "res://assets/boss3/kush_96.png", 96],
		[LevelConfig.BOSS4_NAME, LevelConfig.BOSS4_TITLE, LevelConfig.BOSS4_AFTER_LEVEL, "res://assets/boss4/shlaus_96.png", 96],
		[LevelConfig.BOSS5_NAME, LevelConfig.BOSS5_TITLE, LevelConfig.BOSS5_AFTER_LEVEL, "res://assets/boss5/gill_96.png", 96],
		[LevelConfig.BOSS6_NAME, LevelConfig.BOSS6_TITLE, LevelConfig.BOSS6_AFTER_LEVEL, "res://assets/boss6/nancy_96.png", 96],
		[LevelConfig.BOSS7_NAME, LevelConfig.BOSS7_TITLE, LevelConfig.BOSS7_AFTER_LEVEL, "res://assets/boss7/rogan_96.png", 96],
		[LevelConfig.BOSS8_NAME, LevelConfig.BOSS8_TITLE, LevelConfig.BOSS8_AFTER_LEVEL, "res://assets/boss8/violentsky_96.png", 96],
		[LevelConfig.BOSS9_NAME, LevelConfig.BOSS9_TITLE, LevelConfig.BOSS9_AFTER_LEVEL, "res://assets/boss9/puddin_128.png", 128],
		[LevelConfig.BOSS10_NAME, LevelConfig.BOSS10_TITLE, LevelConfig.BOSS10_AFTER_LEVEL, "res://assets/boss10/rump_96.png", 96],
	]

## Villain pages: which bosses go on which page
const VILLAIN_PAGES := [[0, 1, 2, 3], [4, 5, 6], [7, 8, 9]]

## Score-table rows: [icon, label, points text]. Icons are drawn in _icon().
static func score_rows(page: int) -> Array:
	if page == 0:
		return [
			["human", "SILLY HUMAN SAVED", str(_pts("POINTS_RESCUE"))],
			["possessed_saved", "POSSESSED SAVED", str(_pts("POINTS_RESCUE"))],
			["possessed", "POSSESSED WHIPPED", str(_pts("POINTS_POSSESSED"))],
			["sheep", "KILLER SHEEP", str(_pts("POINTS_SHEEP"))],
			["karen", "KAREN", str(LevelConfig.POINTS_KAREN)],
			["cantifa", "CANTIFA DRIVEN OFF", str(LevelConfig.POINTS_CANTIFA)],
			["chest", "HIDDEN TREASURE", str(LevelConfig.SECRET_SCORE)],
			["flag", "LEVEL CLEAR", "%d +%d/SURVIVOR" % [_pts("CLEAR_BONUS_FLAT"), _pts("CLEAR_BONUS_PER_SURVIVOR")]],
		]
	if page == 2:   # build 030 cameos
		return [
			["cam_zuckerbot", "ZUCKERBOT HIT", str(LevelConfig.POINTS_CAMEO_HIT)],
			["cam_zuckerbot", "ZUCKERBOT UNPLUGGED", str(LevelConfig.POINTS_ZUCKERBOT)],
			["crate", "BOMB CRATE DEFUSED", str(LevelConfig.POINTS_DEFUSE)],
			["cam_tusk", "STARLINK STRIKE", "%d / SHEEP" % _pts("POINTS_SHEEP")],
			["cam_altmann", "CHATBOT ZAP", "%d OR OOPS" % _pts("POINTS_SHEEP")],
			["cam_bozos", "DELIVERY CRATE", "LOOT OR BOOM"],
		]
	return [
		["invincible", "STAR COMBO", "%d x2 x2 x2..." % LevelConfig.STAR_COMBO_BASE],
		["powerup", "POWER-UPS", "POWER, NOT POINTS"],
		["bonus", "BONUS SHEEP", str(LevelConfig.BONUS_POINTS_PER_HIT)],
		["bonus2", "WAVE / PERFECT", "%d / %d" % [LevelConfig.BONUS_WAVE_PERFECT, LevelConfig.BONUS_PERFECT_BONUS]],
		["robo", "PROGRAMMED/MICRO", "%d / %d" % [LevelConfig.POINTS_ROBO, LevelConfig.POINTS_MICRO]],
		["ufo", "UFO / DRONE", "%d / %d" % [LevelConfig.BOSS7_UFO_POINTS, LevelConfig.BOSS8_DRONE_POINTS]],
		["fan", "RALLY FAN", str(LevelConfig.BOSS10_CROWD_POINTS)],
		["heart", "BOSS HEART", "%d - %d" % [LevelConfig.BOSS_POINTS_PER_HEART, LevelConfig.BOSS10_POINTS_PER_HEART]],
		["crown", "BOSS DEFEATED", "%d - %d" % [LevelConfig.BOSS_DEFEAT_BONUS, LevelConfig.BOSS10_DEFEAT_BONUS]],
	]

## Page list for one cycle. "title" = overlay hidden (the real title shows).
func pages() -> Array:
	var p: Array = ["title", "villains0", "villains1", "villains2", "cameos", "score0", "score1", "score2"]
	if high_score() > 0 or not table().is_empty():
		p.append("hiscore")
	return p

var active := false
var page := "title"
var _i := 0
var _page_t := 0.0
var _t := 0.0
var _shut := -1.0               ## >= 0 while the shutter runs (0..2*SHUTTER)
var _next_i := 0
var _tex := {}
var _human: SpriteFrames
var _sheep: SpriteFrames
var _karen: SpriteFrames
var _font: Font
var _possessed_col := Color(0.85, 0.25, 1.0)
## Tests / screenshots: stay on the shown page (rows still pop in).
var hold := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	name = "AttractMode"


func _ready() -> void:
	_font = PixelFont.get_font()
	_human = load("res://assets/spriteframes/human_frames.tres")
	_sheep = load("res://assets/spriteframes/sheep_frames.tres")
	_karen = load("res://assets/spriteframes/karen_frames.tres")
	var pc: Variant = _const(HUMAN_PATH, "POSSESSED_MODULATE")
	if pc is Color:
		_possessed_col = pc


func high_score() -> int:
	var gp := get_node_or_null("/root/GameProgress")
	return int(gp.high_score) if gp != null and "high_score" in gp else 0


## Start the cycle (from the title page, so the first change is a transition).
func start() -> void:
	active = true
	_i = 0
	page = "title"
	_page_t = 0.0
	_shut = -1.0
	visible = false
	_go_next()


## Any input: back to the plain title, at once (no transition).
func stop() -> void:
	active = false
	hold = false
	page = "title"
	_shut = -1.0
	_page_t = 0.0
	visible = false


## Tests / screenshots: jump straight to a page.
func show_page(p: String, freeze := true) -> void:
	active = true
	hold = freeze
	var ps := pages()
	_i = maxi(ps.find(p), 0)
	page = ps[_i]
	_page_t = 0.0
	_shut = -1.0
	visible = page != "title"
	queue_redraw()


func _go_next() -> void:
	_next_i = (_i + 1) % pages().size()
	_shut = 0.0
	visible = true


func _process(delta: float) -> void:
	if not active:
		return
	_t += delta
	if _shut >= 0.0:
		_shut += delta
		if _shut >= SHUTTER and _i != _next_i:
			_i = _next_i
			page = pages()[_i]
			_page_t = 0.0
		if _shut >= SHUTTER * 2.0:
			_shut = -1.0
			visible = page != "title"
	else:
		_page_t += delta
		if _page_t >= PAGE_SECONDS and not hold:
			_go_next()
	queue_redraw()


# ------------------------------------------------------------------ drawing

func _text(s: String, pos: Vector2, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	# chunky drop shadow so it reads on a phone
	draw_string(_font, pos + Vector2(size / 10.0 * 1.5, size / 10.0 * 1.5), s, align, width, size, Color(0, 0, 0, 0.85))
	draw_string(_font, pos, s, align, width, size, col)


func _center(s: String, y: float, size: int, col: Color) -> void:
	_text(s, Vector2(0, y), size, col, HORIZONTAL_ALIGNMENT_CENTER, 1280.0)


func _sheet(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path)
	return _tex[path]


func _draw() -> void:
	var title_under := page == "title"
	if not title_under:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.02, 0.07, 1.0))
		_draw_scanlines()
		if page == "cameos":
			_draw_cameos()
		elif page.begins_with("villains"):
			_draw_villains(int(page.right(1)))
		elif page.begins_with("score"):
			_draw_score(int(page.right(1)))
		elif page == "hiscore":
			_draw_hiscore()
		if fmod(_t, 1.0) < 0.62:
			_center("PRESS START", 690, 30, Color(1.0, 0.85, 0.2))
	if _shut >= 0.0:
		# venetian blinds: bars grow to cover the screen, then shrink away
		var k := _shut / SHUTTER if _shut < SHUTTER else 2.0 - _shut / SHUTTER
		k = clampf(k, 0.0, 1.0)
		var bars := 12
		var bh := 720.0 / bars
		for b in bars:
			var h := bh * k
			draw_rect(Rect2(0, b * bh + (bh - h) * 0.5, 1280, h), Color(0.0, 0.0, 0.0))
			if k > 0.05 and k < 0.95:
				draw_rect(Rect2(0, b * bh + (bh - h) * 0.5, 1280, 3), Color(1.0, 0.5, 0.15, 0.8))


func _draw_scanlines() -> void:
	for y in range(0, 720, 4):
		draw_rect(Rect2(0, y, 1280, 1), Color(1, 1, 1, 0.025))
	# twinkling arcade stars
	for i in 40:
		var sx := fmod(i * 233.0 + 17.0, 1280.0)
		var sy := fmod(i * 131.0 + 41.0, 720.0)
		var a := 0.25 + 0.25 * sin(_t * 3.0 + i)
		draw_rect(Rect2(sx, sy, 3, 3), Color(0.7, 0.8, 1.0, a))


func _header(s: String, col: Color) -> void:
	_center(s, 78, 50, col)
	var w := PixelFont.text_width(s, 5)
	draw_rect(Rect2(640 - w * 0.5, 92, w, 4), col.darkened(0.3))


func _draw_villains(pg: int) -> void:
	_header("MEET THE VILLAINS", Color(1.0, 0.35, 0.3))
	var list: Array = VILLAIN_PAGES[pg]
	var all := bosses()
	var n := list.size()
	var slot_w := 1280.0 / n
	for j in n:
		var b: Array = all[list[j]]
		var appear := 0.35 + j * 0.45
		if _page_t < appear:
			continue
		var cx := slot_w * (j + 0.5)
		var fw: int = b[4]
		var frame := int(_t * 3.0) % 2       # idle frames 0-1
		var tex := _sheet(b[3])
		var sc := 2.0 if n == 4 or fw == 96 else 1.7
		if n == 4:
			sc = 2.0
		var dw := fw * sc
		var dh := 112.0 * sc
		var pop := clampf((_page_t - appear) / 0.25, 0.0, 1.0)
		var top := 140.0 + (1.0 - pop) * 40.0
		draw_texture_rect_region(tex, Rect2(cx - dw * 0.5, top, dw, dh), Rect2(frame * fw, 0, fw, 112), Color(1, 1, 1, pop))
		var y := top + dh + 40.0
		var final_boss: bool = list[j] == 9
		_text("BOSS %d" % (list[j] + 1) if not final_boss else "FINAL BOSS", Vector2(cx - slot_w * 0.5, y), 20, Color(1.0, 0.55, 0.2) if not final_boss else Color(1.0, 0.25, 0.25), HORIZONTAL_ALIGNMENT_CENTER, slot_w)
		_wrap(String(b[0]), cx, slot_w, y + 36.0, 30, Color(1.0, 0.86, 0.2))
		var ty := y + 36.0 + 36.0 * _lines(String(b[0]), slot_w, 30) + 2.0
		ty = _wrap(String(b[1]), cx, slot_w, ty, 20, Color(0.85, 0.9, 1.0))
		_text("AFTER LEVEL %d" % int(b[2]), Vector2(cx - slot_w * 0.5, ty + 10.0), 20, Color(0.55, 1.0, 0.5), HORIZONTAL_ALIGNMENT_CENTER, slot_w)
	if pg == 2 and _page_t > 2.0:
		_center("CAN YOU SAVE THE SILLY HUMANS?", 640, 20, Color(1.0, 0.6, 0.9))


func _lines(s: String, w: float, size: int) -> int:
	return _split(s, w, size).size()


func _split(s: String, w: float, size: int) -> Array:
	var out: Array = []
	var cur := ""
	for word in s.split(" "):
		var t := word if cur == "" else cur + " " + word
		if PixelFont.text_width(t, size / 10) > w - 16.0 and cur != "":
			out.append(cur)
			cur = word
		else:
			cur = t
	if cur != "":
		out.append(cur)
	return out


## Centred word-wrapped text; returns the y after the last line.
func _wrap(s: String, cx: float, w: float, y: float, size: int, col: Color) -> float:
	for line in _split(s, w, size):
		_text(line, Vector2(cx - w * 0.5, y), size, col, HORIZONTAL_ALIGNMENT_CENTER, w)
		y += size * 1.2
	return y


func _draw_score(pg: int) -> void:
	_header("SCORE TABLE", Color(0.35, 0.85, 1.0))
	_center(["- THE RANCH -", "- SPECIALS AND BOSSES -", "- SURPRISE CAMEOS -"][pg], 132, 20, Color(0.85, 0.9, 1.0))
	var rows := score_rows(pg)
	for r in rows.size():
		if _page_t < 0.3 + r * ROW_EVERY:
			continue
		var y := 146.0 + r * 56.0
		var row: Array = rows[r]
		_icon(String(row[0]), Vector2(250, y + 26))
		_text(String(row[1]), Vector2(320, y + 38), 30, Color(1.0, 0.86, 0.2) if r % 2 == 0 else Color(1.0, 0.6, 0.85))
		# dotted leader
		var lw := PixelFont.text_width(String(row[1]), 3)
		var pts := String(row[2])
		var pw := PixelFont.text_width(pts, 3)
		var x0 := 320.0 + lw + 12.0
		var x1 := 1180.0 - pw - 12.0
		var x := x0
		while x < x1:
			draw_rect(Rect2(x, y + 32, 4, 4), Color(0.5, 0.5, 0.6))
			x += 14.0
		_text(pts, Vector2(1180.0 - pw, y + 38), 30, Color.WHITE)


func _frame_of(sf: SpriteFrames, anim: String) -> Texture2D:
	if sf == null or not sf.has_animation(anim):
		return null
	return sf.get_frame_texture(anim, int(_t * 4.0) % maxi(sf.get_frame_count(anim), 1))


func _sprite(tex: Texture2D, c: Vector2, sc: float, mod := Color.WHITE, cap := 56.0) -> void:
	if tex == null:
		return
	# fit the row: at most 48 px tall (sc is the upper bound)
	var sz := tex.get_size()
	var k := minf(sc, cap / maxf(sz.y, 1.0))
	var s := sz * k
	draw_texture_rect(tex, Rect2(c - s * 0.5, s), false, mod)


func _icon(k: String, c: Vector2) -> void:
	if k.begins_with("cam_"):   # build 030: cameo head
		var t := _sheet(String(Cameo.ROSTER[k.substr(4)]["sheet"]))
		draw_texture_rect_region(t, Rect2(c - Vector2(30, 34), Vector2(60, 60)), Rect2(18, 4, 60, 60))
		return
	if k == "crate":
		draw_rect(Rect2(c.x - 22, c.y - 18, 44, 36), Color(0.1, 0.06, 0.04))
		draw_rect(Rect2(c.x - 20, c.y - 16, 40, 32), Color(1.0, 0.35, 0.25) if fmod(_t, 0.6) < 0.3 else Color(0.78, 0.55, 0.28))
		draw_rect(Rect2(c.x - 3, c.y - 16, 6, 32), Color(0.9, 0.82, 0.6))
		return
	match k:
		"human":
			_sprite(_frame_of(_human, "down"), c, 2.0)
		"possessed_saved":
			_sprite(_frame_of(_human, "down"), c, 2.0, _possessed_col)
			draw_circle(c + Vector2(20, -18), 9, Color(0.4, 1.0, 0.4))
			draw_rect(Rect2(c.x + 15, c.y - 19, 10, 3), Color.WHITE)
			draw_rect(Rect2(c.x + 18.5, c.y - 23, 3, 10), Color.WHITE)
		"possessed":
			_sprite(_frame_of(_human, "down"), c, 2.0, _possessed_col)
		"sheep":
			_sprite(_frame_of(_sheep, "down"), c + Vector2(0, -4), 3.0, Color.WHITE, 72.0)
		"karen":
			_sprite(_frame_of(_karen, "down"), c, 2.0)
		"cantifa":
			var t := _sheet("res://assets/characters/cantifa_32.png")
			var f := int(_t * 4.0) % 4
			draw_texture_rect_region(t, Rect2(c - Vector2(32, 36), Vector2(64, 64)), Rect2(f * 64, 0, 64, 64))
		"chest":
			var o := c - Vector2(22, 18)
			draw_rect(Rect2(o + Vector2(0, 16), Vector2(44, 24)), Color(0.45, 0.25, 0.1))
			draw_rect(Rect2(o + Vector2(0, 4), Vector2(44, 14)), Color(0.58, 0.33, 0.13))
			draw_rect(Rect2(o + Vector2(0, 16), Vector2(44, 4)), Color(0.95, 0.75, 0.25))
			draw_rect(Rect2(o + Vector2(18, 14), Vector2(8, 10)), Color(1, 0.88, 0.35))
			if fmod(_t, 1.2) < 0.3:
				draw_rect(Rect2(o + Vector2(36, 0), Vector2(4, 4)), Color.WHITE)
		"flag":
			draw_rect(Rect2(c.x - 14, c.y - 24, 4, 46), Color(0.9, 0.9, 0.9))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-10, -24), c + Vector2(20, -14), c + Vector2(-10, -4)]), Color(0.4, 1.0, 0.4))
		"invincible":
			PowerUp.draw_icon(self, "invincible", c, 3.4)
		"powerup":
			var ks := ["fire_whip", "long_whip", "shockwave", "health", "armor"]
			PowerUp.draw_icon(self, ks[int(_t * 1.5) % ks.size()], c, 3.4)
		"bonus2":
			for q in 3:
				_sprite(_frame_of(_sheep, "right"), c + Vector2(-20 + q * 20, -8 + sin(_t * 6.0 + q) * 4.0), 1.8, Color.WHITE, 40.0)
		"bonus":
			_sprite(_frame_of(_sheep, "right"), c + Vector2(0, -4 + sin(_t * 6.0) * 4.0), 3.0, Color.WHITE, 72.0)
		"robo":
			var rt := _sheet("res://assets/boss2/robo_sheep_32.png")
			draw_texture_rect_region(rt, Rect2(c - Vector2(30, 34), Vector2(60, 60)), Rect2((int(_t * 6.0) % 6) * 64, 0, 64, 64))
		"ufo":
			draw_circle(c + Vector2(0, -6), 10, Color(0.6, 0.95, 1.0, 0.8))
			draw_rect(Rect2(c.x - 26, c.y - 2, 52, 10), Color(0.6, 0.62, 0.7))
			for i in 4:
				draw_rect(Rect2(c.x - 21 + i * 13, c.y + 1, 4, 4), Color(1, 0.9, 0.3) if (int(_t * 6.0) + i) % 2 == 0 else Color(1, 0.3, 0.3))
		"fan":
			_sprite(_frame_of(_human, "down"), c, 2.0)
			draw_rect(Rect2(c.x - 11, c.y - 34, 22, 8), Color(0.85, 0.12, 0.15))
			draw_rect(Rect2(c.x - 2, c.y - 28, 16, 4), Color(0.85, 0.12, 0.15))
		"heart":
			var hs := [".##.##.", "#######", "#######", ".#####.", "..###..", "...#..."]
			for y in hs.size():
				for x in 7:
					if hs[y][x] == "#":
						draw_rect(Rect2(c + Vector2((x - 3.5) * 5, (y - 3) * 5), Vector2(5, 5)), Color(0.95, 0.15, 0.2))
		"crown":
			var t2 := _sheet("res://assets/boss10/rump_96.png")
			draw_texture_rect_region(t2, Rect2(c - Vector2(24, 40), Vector2(48, 56)), Rect2(0, 0, 96, 112))


func table() -> Array:
	var gp := get_node_or_null("/root/GameProgress")
	return gp.hs_table if gp != null and "hs_table" in gp else []


func _draw_hiscore() -> void:
	_header("HIGH SCORES", Color(1.0, 0.86, 0.2))
	var t := table()
	if t.is_empty():
		# pre-028 saves: only the single best score exists
		var s := "%08d" % high_score()
		_center(s, 330, 80, Color(1.0, 1.0, 1.0) * (0.8 + 0.2 * sin(_t * 5.0)))
		_center("BEST RANCHER ON THIS DEVICE", 400, 30, Color(0.55, 1.0, 0.5))
		return
	_text("RANK", Vector2(250, 150), 20, Color(0.6, 0.85, 1.0))
	_text("NAME", Vector2(400, 150), 20, Color(0.6, 0.85, 1.0))
	_text("SCORE", Vector2(560, 150), 20, Color(0.6, 0.85, 1.0))
	_text("LEVEL", Vector2(910, 150), 20, Color(0.6, 0.85, 1.0))
	var cols := [Color(1.0, 0.86, 0.2), Color(0.85, 0.9, 1.0), Color(1.0, 0.6, 0.35)]
	for i in t.size():
		if _page_t < 0.2 + i * 0.18:
			continue
		var e: Dictionary = t[i]
		var y := 196.0 + i * 46.0
		var col: Color = cols[i] if i < 3 else Color(0.55, 1.0, 0.5) if i % 2 == 0 else Color(1.0, 0.6, 0.85)
		var rk: String = ["1ST", "2ND", "3RD"][i] if i < 3 else "%dTH" % (i + 1)
		_text(rk, Vector2(250, y), 30, col)
		_text(String(e.get("i", "...")), Vector2(400, y), 30, col)
		_text("%08d" % int(e.get("s", 0)), Vector2(560, y), 30, col)
		_text("ALL CLEAR" if bool(e.get("c", false)) and int(e.get("l", 0)) <= LevelConfig.BOSS10_AFTER_LEVEL + 1 else "L%d" % int(e.get("l", 1)), Vector2(910, y), 30, col)


## Build 030: SURPRISE CAMEOS lineup (all four, with their role).
func _draw_cameos() -> void:
	_header("SURPRISE CAMEOS", Color(1.0, 0.8, 0.25))
	var n := Cameo.ORDER.size()
	var slot_w := 1280.0 / n
	for j in n:
		var id: String = Cameo.ORDER[j]
		var info: Dictionary = Cameo.ROSTER[id]
		var appear := 0.35 + j * 0.45
		if _page_t < appear:
			continue
		var cx := slot_w * (j + 0.5)
		var pop := clampf((_page_t - appear) / 0.25, 0.0, 1.0)
		var top := 140.0 + (1.0 - pop) * 40.0
		var frame := int(_t * 3.0) % 2
		draw_texture_rect_region(_sheet(String(info["sheet"])), Rect2(cx - 96.0, top, 192.0, 224.0), Rect2(frame * 96, 0, 96, 112), Color(1, 1, 1, pop))
		var y := top + 224.0 + 40.0
		var role: String = info["role"]
		var rc: Color = {"ally": Color(0.45, 1.0, 0.45), "foe": Color(1.0, 0.35, 0.3), "wild": Color(1.0, 0.85, 0.25)}[role]
		_text({"ally": "ALLY", "foe": "FOE", "wild": "WILD CARD"}[role], Vector2(cx - slot_w * 0.5, y), 20, rc, HORIZONTAL_ALIGNMENT_CENTER, slot_w)
		var ty := _wrap(String(info["name"]), cx, slot_w, y + 36.0, 30, Color(1.0, 0.86, 0.2))
		_wrap(String(info["title"]), cx, slot_w, ty + 2.0, 20, Color(0.85, 0.9, 1.0))
	if _page_t > 2.2:
		_center("THEY DROP IN AT RANDOM. HELP OR HINDRANCE?", 640, 20, Color(1.0, 0.6, 0.9))
