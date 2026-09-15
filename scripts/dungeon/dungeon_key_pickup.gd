extends Area3D
## Clé ramassable du donjon coop. Déposée par le générateur sous un
## KeySpawnPoint3D (voir key_lock_manager.gd du plugin) avec key_id assigné
## dynamiquement. Au contact d'un combattant, débloque toutes les portes
## verrouillées partageant le même key_id (groupe "locked_door_<key_id>").

@export var key_id: String = ""

var _collected: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	rotate_y(delta * 1.6)

func _on_body_entered(body: Node3D) -> void:
	if _collected:
		return
	if not body.is_in_group("fighters"):
		return
	_collected = true
	get_tree().call_group("locked_door_%s" % key_id, "unlock")
	_play_pickup_fx()
	queue_free()

func _play_pickup_fx() -> void:
	var flash := OmniLight3D.new()
	flash.light_color = Color("ffd27a")
	flash.light_energy = 4.0
	flash.omni_range = 4.0
	get_parent().add_child(flash)
	flash.global_position = global_position
	var tween := flash.create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.5)
	tween.tween_callback(flash.queue_free)
