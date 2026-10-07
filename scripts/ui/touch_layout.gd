class_name TouchLayout
extends RefCounted
## Build 014: geometry of the touch controls, computed from the viewport size
## (shared by touch_controls.gd, the HUD and tests).
##
##   top-left     : weapon exchange wedge (tap = next weapon)
##   top-right    : SECONDARY action wedge (GRAB / SWING)
##   bottom-right : PRIMARY action wedge (WHIP / REC)
##   bottom-left  : fixed joystick (unchanged since build 011)
##
## Each wedge is a quadrilateral filling a screen corner: two sides lie on the
## screen edges, the inner side is cut by a diagonal at WEDGE_ANGLE_DEG (30)
## from horizontal, so each wedge is much wider than it is tall. Sizes scale
## with `unit()` = the 720-px-equivalent short side (min(height, width*9/16)),
## so 19.5:9, 16:9 and 4:3 viewports all get thumb-sized wedges that never
## reach the joystick or each other.
##
## Why PRIMARY is bottom-right: in landscape the right thumb rests near the
## bottom-right corner, so the most-used, held action (crack / hold REC) sits
## there; the secondary action is a short reach up the edge.

const JOY_CENTER_FROM_BOTTOM_LEFT := Vector2(170.0, 170.0)


static func unit(s: Vector2) -> float:
	return minf(s.y, s.x * 720.0 / 1280.0)


static func wedge_dims(s: Vector2) -> Vector3:
	var u := unit(s)
	var h := u * LevelConfig.WEDGE_HEIGHT_FRAC
	var inner := u * LevelConfig.WEDGE_INNER_FRAC
	return Vector3(h, inner, LevelConfig.wedge_outer_width(h, inner))


static func swap_dims(s: Vector2) -> Vector3:
	var u := unit(s)
	var h := u * LevelConfig.SWAP_WEDGE_HEIGHT_FRAC
	var inner := u * LevelConfig.SWAP_WEDGE_INNER_FRAC
	return Vector3(h, inner, LevelConfig.wedge_outer_width(h, inner))


## Bottom-right corner (PRIMARY).
static func primary_poly(s: Vector2) -> PackedVector2Array:
	var d := wedge_dims(s)
	return PackedVector2Array([
		Vector2(s.x - d.z, s.y), Vector2(s.x - d.y, s.y - d.x), Vector2(s.x, s.y - d.x), Vector2(s.x, s.y)])


## Top-right corner (SECONDARY).
static func secondary_poly(s: Vector2) -> PackedVector2Array:
	var d := wedge_dims(s)
	return PackedVector2Array([
		Vector2(s.x - d.z, 0.0), Vector2(s.x, 0.0), Vector2(s.x, d.x), Vector2(s.x - d.y, d.x)])


## Top-left corner (weapon exchange).
static func swap_poly(s: Vector2) -> PackedVector2Array:
	var d := swap_dims(s)
	return PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(d.z, 0.0), Vector2(d.y, d.x), Vector2(0.0, d.x)])


static func joy_center(s: Vector2) -> Vector2:
	return Vector2(JOY_CENTER_FROM_BOTTOM_LEFT.x, s.y - JOY_CENTER_FROM_BOTTOM_LEFT.y)


## Point-in-polygon on the polygon grown by `slop` px (edge touches count).
static func hit(poly: PackedVector2Array, pos: Vector2, slop: float = LevelConfig.WEDGE_TOUCH_SLOP) -> bool:
	if poly.size() < 3:
		return false
	if slop > 0.0:
		var grown := Geometry2D.offset_polygon(poly, slop, Geometry2D.JOIN_MITER)
		if not grown.is_empty():
			return Geometry2D.is_point_in_polygon(pos, grown[0])
	return Geometry2D.is_point_in_polygon(pos, poly)


static func centroid(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in poly:
		c += p
	return c / maxf(poly.size(), 1)


## Where the label/icon of a wedge goes: between its centroid and its corner.
static func label_anchor(poly: PackedVector2Array, corner: Vector2) -> Vector2:
	return centroid(poly).lerp(corner, 0.18)


## HUD on touch: left stats start below the weapon wedge; right stats end left
## of the secondary wedge.
static func hud_left_top(s: Vector2) -> float:
	return swap_dims(s).x + 10.0


static func hud_right_margin(s: Vector2) -> float:
	return wedge_dims(s).z + 16.0


static func rect_of(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r
