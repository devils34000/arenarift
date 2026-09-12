class_name ArenaProjectile
extends Area2D

signal hit(target: CharacterBody2D, orb: Area2D)

var velocity := Vector2.ZERO
var owner_player: CharacterBody2D
var lifetime := 1.3

func _ready() -> void:
	monitoring = true
	queue_redraw()

func _physics_process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta
	if get_parent().has_method("blocks_projectile") and get_parent().blocks_projectile(global_position):
		queue_free()
		return
	for body in get_tree().get_nodes_in_group("fighters"):
		if body != owner_player and body.global_position.distance_to(global_position) < 32.0:
			hit.emit(body, self)
			return
	if lifetime <= 0.0:
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 13.0, Color("7ee7ff", 0.25))
	draw_circle(Vector2.ZERO, 7.0, Color("e6fbff"))
