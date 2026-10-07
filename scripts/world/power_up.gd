class_name PowerUp
extends Node2D
## Build 013: a power-up pickup lying on the ground. Walk over it to collect
## (no new controls). Bobs, blinks for its last 3 s and vanishes after
## LevelConfig.PICKUP_LIFETIME (PICKUP_LIFETIME_RARE for the cam / batteries).
## The static helpers draw the pixel icons that the HUD reuses.
## Build 014: + MSM CAM and BATTERY pickups, + "whip" icon (weapon slot).

signal collected(kind: String, pickup: Node2D)

const TYPES := ["health", "long_whip", "strong_throw", "shockwave", "fire_whip", "whip_shot", "msm_cam", "battery"]
const NAMES := {
	"health": "HEALTH",
	"long_whip": "LONG WHIP",
	"strong_throw": "STRONG THROW",
	"shockwave": "SHOCKWAVE",
	"fire_whip": "FIRE WHIP",
	"whip_shot": "WHIP SHOT",
	"msm_cam": "MSM CAM",
	"battery": "BATTERY",
	"whip": "WHIP",
}
const PLATE := {
	"health": Color(0.85, 0.12, 0.2),
	"long_whip": Color(0.55, 0.33, 0.12),
	"strong_throw": Color(0.12, 0.45, 0.85),
	"shockwave": Color(0.45, 0.2, 0.8),
	"fire_whip": Color(0.95, 0.42, 0.05),
	"whip_shot": Color(0.1, 0.6, 0.45),
	"msm_cam": Color(0.2, 0.2, 0.24),
	"battery": Color(0.18, 0.6, 0.22),
	"whip": Color(0.6, 0.38, 0.16),
}
## 9x9 icons: '#' = light colour, 'o' = accent, '.' = empty.
const ICONS := {
	"health": [
		".........",
		".##...##.",
		"####.####",
		"#########",
		"#########",
		".#######.",
		"..#####..",
		"...###...",
		"....#....",
	],
	"long_whip": [
		".........",
		"..#...#..",
		".##...##.",
		"#########",
		"#########",
		".##...##.",
		"..#...#..",
		".........",
		".........",
	],
	"strong_throw": [
		"....#####",
		".....####",
		"....#####",
		"...###.##",
		"..###...#",
		".###.....",
		"###......",
		"##.......",
		".........",
	],
	"shockwave": [
		"..#####..",
		".#.....#.",
		"#..ooo..#",
		"#.o...o.#",
		"#.o.#.o.#",
		"#.o...o.#",
		"#..ooo..#",
		".#.....#.",
		"..#####..",
	],
	"fire_whip": [
		"....#....",
		"...##....",
		"...###.#.",
		"..####.#.",
		".###o###.",
		".##ooo##.",
		"###ooo###",
		".##ooo##.",
		"..#####..",
	],
	"msm_cam": [
		"o.#####..",
		"..#...#..",
		"#######..",
		"#######.#",
		"##.##..##",
		"#######.#",
		"#######..",
		"..#..#...",
		".........",
	],
	"battery": [
		"...###...",
		"..#####..",
		"..#ooo#..",
		"..#ooo#..",
		"..#####..",
		"..#ooo#..",
		"..#ooo#..",
		"..#####..",
		".........",
	],
	"whip": [
		"..####...",
		".#....#..",
		"#..oo..#.",
		"#.o..o.#.",
		"#.o.o..#.",
		"#..o...#.",
		".#....#..",
		"..####.oo",
		".......oo",
	],
	"whip_shot": [
		"....#....",
		"....#....",
		"..#.o.#..",
		"...ooo...",
		"##ooooo##",
		"...ooo...",
		"..#.o.#..",
		"....#....",
		"....#....",
	],
}
const ACCENT := {
	"shockwave": Color(1.0, 0.95, 0.5),
	"fire_whip": Color(1.0, 0.92, 0.3),
	"whip_shot": Color(1.0, 1.0, 0.6),
	"msm_cam": Color(1.0, 0.2, 0.15),
	"battery": Color(0.95, 1.0, 0.45),
	"whip": Color(0.95, 0.8, 0.45),
}

@export var kind: String = "health"
var age: float = 0.0
var lifetime: float = LevelConfig.PICKUP_LIFETIME
var _taken := false


static func display_name(k: String) -> String:
	return NAMES.get(k, k.to_upper())


## Draw a plate + pixel icon centred at `c`. `px` = screen pixels per icon pixel.
static func draw_icon(ci: CanvasItem, k: String, c: Vector2, px: float, alpha := 1.0) -> void:
	var r := px * 7.0
	var plate: Color = PLATE.get(k, Color(0.4, 0.4, 0.4))
	ci.draw_circle(c + Vector2(px, px), r + px, Color(0, 0, 0.05, 0.45 * alpha))
	ci.draw_circle(c, r + px, Color(0.06, 0.03, 0.08, alpha))
	ci.draw_circle(c, r, Color(plate.r, plate.g, plate.b, alpha))
	ci.draw_circle(c - Vector2(px * 2, px * 2), r * 0.45, Color(1, 1, 1, 0.18 * alpha))
	var rows: Array = ICONS.get(k, [])
	var light := Color(1, 1, 1, alpha)
	var acc: Color = ACCENT.get(k, light)
	acc.a = alpha
	var o := c - Vector2(4.5, 4.5) * px
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == ".":
				continue
			ci.draw_rect(Rect2(o + Vector2(x, y) * px, Vector2(px, px)), acc if ch == "o" else light)


func _ready() -> void:
	add_to_group("powerups")
	z_index = 3
	if kind == "msm_cam" or kind == "battery":
		lifetime = LevelConfig.PICKUP_LIFETIME_RARE


func _process(delta: float) -> void:
	if _taken:
		return
	age += delta
	if age >= lifetime:
		queue_free()
		return
	queue_redraw()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	if "_dead" in player and player._dead:
		return
	if player.global_position.distance_to(global_position) <= LevelConfig.PICKUP_RADIUS:
		collect()


func collect() -> void:
	if _taken:
		return
	_taken = true
	collected.emit(kind, self)
	queue_free()


func _draw() -> void:
	var left := lifetime - age
	if left < 3.0 and fmod(age, 0.25) < 0.1:
		return
	var bob := sin(age * 4.0) * 3.0
	draw_set_transform(Vector2.ZERO)
	# ground shadow
	var pts := PackedVector2Array()
	for i in 16:
		var a := float(i) / 16.0 * TAU
		pts.append(Vector2(cos(a) * 12.0, 8.0 + sin(a) * 4.0))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.3))
	# glow pulse
	var glow := 0.25 + 0.15 * sin(age * 6.0)
	draw_circle(Vector2(0, -10 + bob), 20.0, Color(1, 1, 0.8, glow * 0.5))
	draw_icon(self, kind, Vector2(0, -10 + bob), 2.0)
