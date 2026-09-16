extends OmniLight3D
## Vacillement léger d'une torche pour une ambiance donjon/horreur.

@export var base_energy: float = 1.8
@export var flicker_amount: float = 0.5
@export var speed: float = 5.0

var _noise := FastNoiseLite.new()
var _t := 0.0

func _ready() -> void:
	_noise.seed = randi()
	_t = randf() * 1000.0

func _process(delta: float) -> void:
	_t += delta * speed
	light_energy = base_energy + _noise.get_noise_1d(_t) * flicker_amount
