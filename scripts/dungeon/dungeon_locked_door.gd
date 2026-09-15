extends StaticBody3D
## Porte verrouillée du donjon coop. Posée par le générateur sur le
## connecteur d'une salle marquée is_locked=true/key_id="...". Bloque le
## passage jusqu'à ce qu'une clé du même key_id soit ramassée (voir
## dungeon_key_pickup.gd), qui appelle unlock() via le groupe
## "locked_door_<key_id>".

@export var key_id: String = ""

func _ready() -> void:
	add_to_group("locked_door_%s" % key_id)

func unlock() -> void:
	collision_layer = 0
	collision_mask = 0
	var mesh := get_node_or_null("Mesh") as Node3D
	if mesh:
		var tween := create_tween()
		tween.tween_property(mesh, "position:y", mesh.position.y + 3.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_callback(queue_free)
	else:
		queue_free()
