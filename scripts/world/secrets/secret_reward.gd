class_name SecretReward
extends Node2D
## Build 024: the treasure inside an opened chamber. Walk over it (any input
## method) to claim; claimed once per run (GameProgress.claim_secret).

signal taken(kind: String)

const RADIUS := 30.0
var kind := "score"
var spec: Dictionary = {}
var t := 0.0
var _done := false


func _ready() -> void:
	add_to_group("secret_rewards")
	z_index = 4


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	if _done:
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null or ("_dead" in p and p._dead):
		return
	if p.global_position.distance_to(global_position) <= RADIUS:
		claim()


func claim() -> void:
	if _done:
		return
	var gp := get_node_or_null("/root/GameProgress")
	if gp != null and gp.has_method("claim_secret") and not gp.claim_secret(String(spec.get("id", ""))):
		queue_free()
		return
	_done = true
	var lc := get_tree().get_first_node_in_group("level_controller")
	if lc != null and lc.has_method("grant_secret_reward"):
		lc.grant_secret_reward(kind, global_position)
	taken.emit(kind)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.6, 1.6), 0.15)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


func _draw() -> void:
	var bob := sin(t * 3.0) * 2.0
	# glow
	draw_circle(Vector2(0, 2), 18.0 + sin(t * 4.0) * 2.0, Color(1, 0.85, 0.3, 0.18))
	if kind == "score" or kind == "heart":
		# little treasure chest
		var o := Vector2(-11, -12 + bob)
		draw_rect(Rect2(o + Vector2(0, 8), Vector2(22, 12)), Color(0.45, 0.25, 0.1))
		draw_rect(Rect2(o + Vector2(0, 2), Vector2(22, 7)), Color(0.58, 0.33, 0.13))
		draw_rect(Rect2(o + Vector2(0, 8), Vector2(22, 2)), Color(0.95, 0.75, 0.25))
		draw_rect(Rect2(o + Vector2(9, 7), Vector2(4, 5)), Color(1, 0.88, 0.35))
		if kind == "heart":
			var hc := Color(1, 0.25, 0.35)
			draw_circle(o + Vector2(8, -4), 3.5, hc)
			draw_circle(o + Vector2(14, -4), 3.5, hc)
			draw_colored_polygon(PackedVector2Array([o + Vector2(4.8, -3), o + Vector2(17.2, -3), o + Vector2(11, 3)]), hc)
		else:
			for k in 3:
				draw_circle(o + Vector2(6 + k * 5, 0), 3.0, Color(1, 0.85, 0.2))
	else:
		PowerUp.draw_icon(self, kind, Vector2(0, -8 + bob), 2.0)
	# sparkle
	var s := fmod(t, 1.2) / 1.2
	draw_line(Vector2(12, -20) + Vector2(-4, 0) * s, Vector2(12, -20) + Vector2(4, 0) * s, Color(1, 1, 0.8, 1 - s), 1.5)
	draw_line(Vector2(12, -24) + Vector2(0, 4) * (1 - s), Vector2(12, -16) - Vector2(0, 4) * (1 - s), Color(1, 1, 0.8, 1 - s), 1.5)
