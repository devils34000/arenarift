extends CanvasLayer
## Écran de chargement (faux, durée fixe) affiché avant de rejoindre une
## map. S'ajoute comme enfant direct de root (frère de la scène courante)
## donc survit au change_scene_to_file qui suit.

@export var duration: float = 10.0

@onready var _bar: ProgressBar = $Control/Panel/ProgressBar
@onready var _label: Label = $Control/Panel/StatusLabel

var _target_scene: String = ""

const TIPS: Array[String] = [
	"Astuce : réanimez vos alliés à terre avant qu'il ne soit trop tard.",
	"Astuce : nettoyez chaque salle avant de foncer vers le boss.",
	"Astuce : le boss final laisse tomber la clé du portail de sortie.",
	"Astuce : fouillez les coffres, ils contiennent de l'équipement utile.",
	"Astuce : jouez en groupe, le donjon est bien plus dangereux seul.",
]

func start(target_scene: String) -> void:
	_target_scene = target_scene
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _label:
		_label.text = TIPS[randi() % TIPS.size()]
	if _bar:
		_bar.value = 0.0
		var tween := create_tween()
		tween.tween_property(_bar, "value", 100.0, duration)
		tween.tween_callback(_on_done)
	else:
		_on_done()

func _on_done() -> void:
	get_tree().change_scene_to_file(_target_scene)
	queue_free()
