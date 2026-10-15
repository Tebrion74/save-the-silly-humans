extends "res://scripts/boss/shlaus_level.gd"
## Build 027: shared base for the final two boss levels (Puddin, Rump).
## Same rules and damage as Shlaus Kwobb; the finale hazards hurt through
## tech_hit_player(); shake_camera() jiggles the rancher's camera.

var tech_hits_taken := 0
var tech_hits: Dictionary = {}
var _shake_t := 0.0
var _shake_amp := 0.0
var _shake_rng := RandomNumberGenerator.new()


func tech_hit_player(kind: String, from_pos: Vector2) -> bool:
	var popup: String = {"tank": "FLATTENED!", "judo": "THROWN!", "icicle": "BRRR!", "golf": "FORE!",
		"wall": "WALLED!", "crowd": "HUGGED!"}.get(kind, "OUCH!")
	if poutine_hit_player(from_pos, 1, popup):
		tech_hits_taken += 1
		tech_hits[kind] = int(tech_hits.get(kind, 0)) + 1
		return true
	return false


func shake_camera(seconds: float, amp: float) -> void:
	_shake_t = maxf(_shake_t, seconds)
	_shake_amp = maxf(_shake_amp, amp)


func _process(delta: float) -> void:
	super(delta)
	var cam := get_node_or_null("Entities/Player/Camera2D") as Camera2D
	if cam == null:
		return
	if _shake_t > 0.0:
		_shake_t = maxf(_shake_t - delta, 0.0)
		var a := _shake_amp * minf(_shake_t / 0.3, 1.0)
		cam.offset = Vector2(_shake_rng.randf_range(-a, a), _shake_rng.randf_range(-a, a))
		if _shake_t <= 0.0:
			_shake_amp = 0.0
			cam.offset = Vector2.ZERO


func _on_boss_down_extra() -> void:
	super()
	for g in ["hazard027", "quake", "crowd", "wall_drop"]:
		for n in get_tree().get_nodes_in_group(g):
			if is_instance_valid(n):
				n.queue_free()
	var p := get_node_or_null("Entities/Player")
	if p != null and "invert_time" in p:
		p.invert_time = 0.0
