class_name Camcorder
extends Node2D
## Build 014: the big boxy 1980s VHS shoulder camcorder the rancher carries
## while the MSM Cam is equipped. Procedural pixel art (1 art pixel = 1 px,
## like the 64x64 character frames), drawn over the rancher sprite and
## oriented with his 4-way body animation: profile for left/right, lens-on
## for down, battery-pack side for up. The red tally light blinks while
## filming, with a small blinking REC tag above his head.

const OUT := Color(0.06, 0.03, 0.08)
const BODY_D := Color(0.2, 0.2, 0.23)
const BODY := Color(0.36, 0.36, 0.4)
const BODY_L := Color(0.56, 0.56, 0.6)
const BODY_XL := Color(0.74, 0.74, 0.78)
const BLACK := Color(0.1, 0.1, 0.12)
const GLASS := Color(0.22, 0.4, 0.72)
const GLASS_L := Color(0.7, 0.88, 1.0)
const RED := Color(1.0, 0.13, 0.1)
const RED_DIM := Color(0.38, 0.06, 0.06)
const STRIPE_1 := Color(0.92, 0.2, 0.18)
const STRIPE_2 := Color(1.0, 0.56, 0.1)
const STRIPE_3 := Color(1.0, 0.86, 0.2)
const SKIN := Color(0.96, 0.76, 0.6)
const LED_ON := Color(0.35, 1.0, 0.35)
const LED_OFF := Color(0.12, 0.25, 0.12)

var _t := 0.0
var _parts: Array = []
var _mirror := false
## Vertical nudge so the camera sits on the shoulder (face stays visible above).
var _dy := 0


func _ready() -> void:
	name = "Camcorder"
	z_index = 1


func _cam() -> Node:
	return get_parent().get_node_or_null("MsmCam") if get_parent() != null else null


func _process(delta: float) -> void:
	_t += delta
	var c := _cam()
	var show: bool = c != null and c.is_equipped()
	if visible != show:
		visible = show
	if show:
		queue_redraw()


func _view() -> String:
	var spr := get_parent().get_node_or_null("Sprite") as AnimatedSprite2D
	return String(spr.animation) if spr != null else "right"


func _r(x: int, y: int, w: int, h: int, col: Color, outline := true) -> void:
	_parts.append([x, y + _dy, w, h, col, outline])


func _flush() -> void:
	for p in _parts:
		if p[5]:
			var rx: int = p[0]
			if _mirror:
				rx = -(int(p[0]) + int(p[2]))
			draw_rect(Rect2(rx - 1, int(p[1]) - 1, int(p[2]) + 2, int(p[3]) + 2), OUT)
	for p in _parts:
		var rx: int = p[0]
		if _mirror:
			rx = -(int(p[0]) + int(p[2]))
		draw_rect(Rect2(rx, p[1], p[2], p[3]), p[4])
	_parts.clear()


func _tally() -> Color:
	var c := _cam()
	if c == null or c.is_dead():
		return RED_DIM
	if c.filming:
		return RED if fmod(_t, 0.7) < 0.42 else RED_DIM
	return RED_DIM


func _draw() -> void:
	var c := _cam()
	if c == null:
		return
	var view := _view()
	_mirror = view == "left"
	# SWING: the camcorder lunges toward the aim with a whoosh arc.
	var swinging: bool = c.swing_t >= 0.0
	if swinging:
		var k: float = clampf(c.swing_t / c.SWING_ANIM, 0.0, 1.0)
		var lunge: float = sin(k * PI)
		var sd: Vector2 = c.swing_dir
		var rot := sd.x * 0.5 * lunge
		draw_set_transform(sd * 14.0 * lunge + Vector2(0, -18) - Vector2(0, -18).rotated(rot), rot, Vector2.ONE)
	_dy = 4 if view == "left" or view == "right" else 3
	match view:
		"down":
			_draw_front()
		"up":
			_draw_back(c)
		_:
			_draw_side()
	if swinging:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_swing_arc(c)
	if c.filming:
		_draw_rec_tag(view)


## Profile, lens to the right (mirrored for "left").
func _draw_side() -> void:
	# shoulder pad + operator's hand on the grip
	_r(-7, -11, 10, 2, BLACK)
	# rear battery pack
	_r(-17, -22, 4, 10, BLACK)
	# carry handle with posts and the shotgun mic
	_r(-9, -29, 16, 2, BODY_D)
	_r(-9, -27, 2, 3, BODY_D)
	_r(5, -27, 2, 3, BODY_D)
	_r(7, -30, 6, 2, BLACK)
	# main body
	_r(-13, -24, 24, 13, BODY)
	# lens barrel + hood
	_r(11, -22, 6, 9, BLACK)
	_r(17, -23, 3, 11, BODY_D)
	# eyepiece (viewfinder) toward the face
	_r(-6, -27, 8, 3, BODY_D)
	_flush()
	# details (no outline)
	_r(-13, -24, 24, 1, BODY_L, false)            # top highlight
	_r(-13, -12, 24, 1, BODY_D, false)            # bottom shade
	_r(-11, -22, 12, 6, BODY_L, false)            # cassette door
	_r(-10, -21, 10, 1, BODY_XL, false)
	_r(-10, -18, 10, 1, BODY_D, false)
	_r(-13, -15, 24, 1, STRIPE_1, false)          # 80s stripes
	_r(-13, -14, 24, 1, STRIPE_2, false)
	_r(-13, -13, 24, 1, STRIPE_3, false)
	_r(3, -22, 6, 2, BODY_XL, false)              # brand plate
	_r(12, -21, 4, 1, BODY, false)                # lens ring
	_r(12, -16, 4, 1, BODY, false)
	_r(19, -21, 1, 7, GLASS, false)               # front glass sliver
	_r(19, -20, 1, 2, GLASS_L, false)
	_r(-16, -20, 2, 1, LED_OFF, false)
	_r(-8, -26, 2, 1, BLACK, false)               # eyecup
	_r(8, -26, 2, 2, _tally(), false)             # tally light
	_r(4, -11, 4, 2, SKIN, false)                 # fingers on the grip
	_flush()


## Lens toward the viewer, on the rancher's right shoulder (screen left).
func _draw_front() -> void:
	_r(-21, -11, 9, 2, BLACK)                     # shoulder pad
	_r(-22, -30, 12, 2, BODY_D)                   # handle
	_r(-22, -28, 2, 3, BODY_D)
	_r(-12, -28, 2, 3, BODY_D)
	_r(-13, -32, 3, 3, BLACK)                     # mic (end-on)
	_r(-25, -26, 16, 15, BODY)                    # body
	_r(-10, -24, 4, 5, BODY_D)                    # eyepiece toward the face
	_flush()
	_r(-25, -26, 16, 1, BODY_L, false)
	_r(-25, -12, 16, 1, BODY_D, false)
	_r(-25, -15, 16, 1, STRIPE_1, false)
	_r(-25, -14, 16, 1, STRIPE_2, false)
	_r(-25, -13, 16, 1, STRIPE_3, false)
	_r(-12, -25, 2, 2, _tally(), false)
	_flush()
	# big round lens
	var lc := Vector2(-17.5, -19.5 + _dy)
	if _mirror:
		lc.x = -lc.x
	draw_circle(lc, 6.5, OUT)
	draw_circle(lc, 5.5, BODY_D)
	draw_circle(lc, 4.0, BLACK)
	draw_circle(lc, 2.6, GLASS)
	draw_rect(Rect2(lc + Vector2(-2, -2), Vector2(2, 2)), GLASS_L)
	# fingers under the lens
	_r(-20, -11, 5, 2, SKIN, false)
	_flush()


## Seen from behind: the battery pack with charge LEDs, on the right shoulder
## (screen right).
func _draw_back(c: Node) -> void:
	_r(12, -11, 9, 2, BLACK)                      # shoulder pad
	_r(10, -30, 12, 2, BODY_D)                    # handle
	_r(10, -28, 2, 3, BODY_D)
	_r(20, -28, 2, 3, BODY_D)
	_r(9, -26, 16, 15, BODY)                      # body
	_r(5, -24, 4, 5, BODY_D)                      # eyepiece toward the head
	_flush()
	_r(9, -26, 16, 1, BODY_L, false)
	_r(11, -24, 12, 10, BLACK, false)             # battery pack
	_r(12, -23, 10, 1, BODY_D, false)
	var lit := int(ceil(c.battery_frac() * 4.0))
	for i in 4:
		_r(12 + i * 3, -17, 2, 2, LED_ON if i < lit else LED_OFF, false)
	_r(9, -13, 16, 1, STRIPE_1, false)
	_r(9, -12, 16, 1, STRIPE_2, false)
	_r(22, -25, 2, 2, _tally(), false)            # rear tally
	_flush()


func _draw_rec_tag(view: String) -> void:
	var x := 12.0 if view != "left" else -34.0
	var p := Vector2(x, -50)
	var on := fmod(_t, 0.8) < 0.5
	draw_rect(Rect2(p + Vector2(-3, -9), Vector2(28, 13)), Color(0, 0, 0, 0.45))
	if on:
		draw_circle(p + Vector2(3, -2.5), 3.5, OUT)
		draw_circle(p + Vector2(3, -2.5), 2.6, RED)
	draw_string(PixelFont.get_font(), p + Vector2(8, 1), "REC", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.95))


func _draw_swing_arc(c: Node) -> void:
	var k: float = clampf(c.swing_t / c.SWING_ANIM, 0.0, 1.0)
	var ang: float = (c.swing_dir as Vector2).angle()
	var half := deg_to_rad(LevelConfig.SWING_HALF_ARC_DEG)
	var reach: float = c.range_px / LevelConfig.CAM_RANGE_MULT * LevelConfig.SWING_RANGE_MULT
	var o := Vector2(0, -16)
	# sweep from one side of the arc to the other, trailing a fading band
	var head := -half + 2.0 * half * smoothstep(0.0, 1.0, k * 1.3)
	var tail := maxf(-half, head - 1.1)
	var a := 1.0 - k * k
	# filled whoosh crescent (stacked so it survives the compat renderer's alpha)
	if head - tail > 0.05:
		var band := PackedVector2Array()
		var n := 14
		for i in n + 1:
			var t := ang + lerpf(tail, head, float(i) / n)
			band.append(o + Vector2.from_angle(t) * reach * 0.98)
		for i in n + 1:
			var t := ang + lerpf(head, tail, float(i) / n)
			var w := lerpf(0.5, 0.86, float(i) / n)  # thick at the head, thin at the tail
			band.append(o + Vector2.from_angle(t) * reach * w)
		draw_colored_polygon(band, Color(1.0, 1.0, 1.0, 0.22 * a))
		draw_colored_polygon(band, Color(0.85, 0.9, 1.0, 0.18 * a))
	draw_arc(o, reach * 0.98, ang + tail, ang + head, 16, Color(0.06, 0.03, 0.08, 0.5 * a), 9.0)
	draw_arc(o, reach * 0.98, ang + tail, ang + head, 16, Color(1, 1, 1, 0.95 * a), 5.0)
	draw_arc(o, reach * 0.72, ang + tail + 0.25, ang + head, 12, Color(0.8, 0.9, 1.0, 0.7 * a), 3.0)
	draw_arc(o, reach * 0.55, ang + tail + 0.5, ang + head, 10, Color(0.8, 0.9, 1.0, 0.5 * a), 2.0)

