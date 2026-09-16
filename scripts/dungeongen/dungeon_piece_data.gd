extends Resource
class_name DungeonPieceData
## Une entrée de pool : quel bloc, et sa probabilité d'être choisi par
## rapport aux autres blocs du même pool (poids relatif, pas un %).

@export var piece_scene: PackedScene
@export var spawn_weight: float = 1.0
