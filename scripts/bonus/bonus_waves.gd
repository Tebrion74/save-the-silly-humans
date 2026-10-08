class_name BonusWaves
extends RefCounted
## Build 016: the bonus stage's scripted Galaga-style flight paths.
##
## Paths are Catmull-Rom splines through points in FIELD coordinates: (0,0) is
## the top-left of the playfield, (1,1) the bottom-right; points outside 0..1
## are off the field (sheep fly in from / out to the edges). Each wave is one
## pattern flown by a "train" of sheep BONUS_SPACING apart; "pair" patterns
## alternate sheep between the path and its mirror image.
##   swoop   U-shaped dive in from the top-left, out the top-right
##   scurve  low entry from the left, S-bend up and out the right
##   zigzag  zig-zags down the field from the top
##   loop    in from the left, a full loop in the middle, out the right
##   cross   two trains crossing on the diagonals (mirrored pair)
##   dive    straight down the middle, then peels off to both sides (pair)
##   orbit   up from the bottom, circles the middle, out the top
##   eight   two mirrored loop-the-loops (pair)
## Later bonus stages flip the waves left/right on even repeats and shuffle the
## order a little, so they don't feel identical (plus they're faster/bigger).

const PATTERNS := {
	"swoop": [Vector2(-0.08, 0.05), Vector2(0.12, 0.25), Vector2(0.3, 0.62), Vector2(0.5, 0.8), Vector2(0.7, 0.62), Vector2(0.86, 0.3), Vector2(1.08, 0.08)],
	"scurve": [Vector2(-0.08, 0.82), Vector2(0.2, 0.8), Vector2(0.4, 0.62), Vector2(0.5, 0.45), Vector2(0.62, 0.28), Vector2(0.82, 0.2), Vector2(1.08, 0.22)],
	"zigzag": [Vector2(0.12, -0.1), Vector2(0.15, 0.08), Vector2(0.82, 0.25), Vector2(0.18, 0.45), Vector2(0.82, 0.65), Vector2(0.3, 0.85), Vector2(0.2, 1.12)],
	"loop": [Vector2(-0.08, 0.3), Vector2(0.2, 0.32), Vector2(0.42, 0.42), Vector2(0.52, 0.66), Vector2(0.4, 0.84), Vector2(0.27, 0.66), Vector2(0.36, 0.44), Vector2(0.6, 0.36), Vector2(0.82, 0.5), Vector2(1.08, 0.62)],
	"cross": [Vector2(-0.08, -0.08), Vector2(0.15, 0.15), Vector2(0.4, 0.42), Vector2(0.6, 0.6), Vector2(0.85, 0.86), Vector2(1.08, 1.1)],
	"dive": [Vector2(0.46, -0.12), Vector2(0.46, 0.15), Vector2(0.44, 0.5), Vector2(0.35, 0.74), Vector2(0.2, 0.72), Vector2(0.08, 0.5), Vector2(-0.1, 0.36)],
	"orbit": [Vector2(0.3, 1.12), Vector2(0.32, 0.8), Vector2(0.45, 0.66), Vector2(0.66, 0.6), Vector2(0.74, 0.42), Vector2(0.6, 0.24), Vector2(0.4, 0.26), Vector2(0.3, 0.42), Vector2(0.42, 0.56), Vector2(0.62, 0.3), Vector2(0.7, -0.12)],
	"eight": [Vector2(-0.08, 0.55), Vector2(0.15, 0.5), Vector2(0.3, 0.3), Vector2(0.42, 0.16), Vector2(0.48, 0.34), Vector2(0.36, 0.5), Vector2(0.3, 0.7), Vector2(0.4, 0.86), Vector2(0.5, 0.7), Vector2(0.46, 0.45), Vector2(0.52, 0.2), Vector2(0.62, -0.1)],
}
## pattern, pair (alternate sheep on the mirrored path)
const WAVES := [
	["swoop", false],
	["scurve", true],
	["zigzag", false],
	["loop", false],
	["cross", true],
	["dive", true],
	["orbit", false],
	["eight", true],
]


## The wave plan for bonus stage `repeat` (1-based): [{pattern, pair, mirror}].
static func plan(repeat: int) -> Array:
	var out: Array = []
	var order := range(WAVES.size())
	if repeat >= 2:
		# keep the easy opener; rotate the middle waves a little each repeat
		var mid := order.slice(1, order.size() - 1)
		var k := (repeat - 1) % mid.size()
		mid = mid.slice(k) + mid.slice(0, k)
		order = [0] + mid + [order[order.size() - 1]]
	for wi in order:
		var w: Array = WAVES[wi]
		out.append({"pattern": w[0], "pair": w[1], "mirror": repeat % 2 == 0})
	return out


## Sampled world-space polyline for a pattern in `field` (optionally mirrored
## left/right), ~10 px apart.
static func sample(pattern: String, field: Rect2, mirror: bool) -> PackedVector2Array:
	var pts: Array = PATTERNS[pattern]
	var ctrl: Array[Vector2] = []
	for p in pts:
		var v: Vector2 = p
		if mirror:
			v.x = 1.0 - v.x
		ctrl.append(field.position + v * field.size)
	var out := PackedVector2Array()
	var n := ctrl.size()
	for i in n - 1:
		var p0: Vector2 = ctrl[maxi(i - 1, 0)]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[i + 1]
		var p3: Vector2 = ctrl[mini(i + 2, n - 1)]
		var steps := maxi(int(p1.distance_to(p2) / 10.0), 2)
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(ctrl[n - 1])
	return out


static func length_of(poly: PackedVector2Array) -> float:
	var l := 0.0
	for i in range(1, poly.size()):
		l += poly[i - 1].distance_to(poly[i])
	return l
