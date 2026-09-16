extends CanvasLayer
## Écran de chargement affiché avant de rejoindre une map. S'ajoute comme
## enfant direct de root (frère de la scène courante) donc survit au
## change_scene_to_file qui suit.
##
## Deux usages :
## - start(target_scene) : jeu solo/local, faux chargement de "duration"
##   secondes puis changement de scène direct.
## - start_target_scene_after_connect(target_scene) + mark_connected() :
##   utilisé quand une vraie connexion réseau tourne en parallèle (ex.
##   salon Co-op Donjon) — le changement de scène n'a lieu qu'une fois LES
##   DEUX conditions réunies (barre finie ET connexion confirmée), pour ne
##   jamais couper l'écran de chargement avant que ce soit vraiment prêt.

@export var duration: float = 10.0

@onready var _bar: ProgressBar = $Control/Panel/ProgressBar
@onready var _label: Label = $Control/Panel/StatusLabel

var _target_scene: String = ""
var _await_connect: bool = false
var _timer_done: bool = false
var _connected: bool = false

const TIPS: Array[String] = [
	"Astuce : réanimez vos alliés à terre avant qu'il ne soit trop tard.",
	"Astuce : nettoyez chaque salle avant de foncer vers le boss.",
	"Astuce : le boss final laisse tomber la clé du portail de sortie.",
	"Astuce : fouillez les coffres, ils contiennent de l'équipement utile.",
	"Astuce : jouez en groupe, le donjon est bien plus dangereux seul.",
]

func start(target_scene: String) -> void:
	_await_connect = false
	_target_scene = target_scene
	_begin_bar()

func start_target_scene_after_connect(target_scene: String) -> void:
	_await_connect = true
	_target_scene = target_scene
	_begin_bar()

func mark_connected() -> void:
	_connected = true
	_maybe_finish()

func _begin_bar() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _label:
		_label.text = TIPS[randi() % TIPS.size()]
	if _bar:
		_bar.value = 0.0
		var tween := create_tween()
		tween.tween_property(_bar, "value", 100.0, duration)
		tween.tween_callback(_on_timer_done)
	else:
		_on_timer_done()

func _on_timer_done() -> void:
	_timer_done = true
	_maybe_finish()

func _maybe_finish() -> void:
	if not _timer_done:
		return
	if _await_connect and not _connected:
		return
	get_tree().change_scene_to_file(_target_scene)
	queue_free()
