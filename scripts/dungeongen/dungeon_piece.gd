@tool
extends Node3D
class_name DungeonPiece
## Racine d'un bloc de donjon (couloir, salle, cul-de-sac, etc.) construit
## à la main dans l'éditeur avec tes propres assets.
##
## Convention à respecter pour qu'un bloc soit utilisable par le
## générateur (dungeon_generator.gd) :
##  1. La géométrie/déco du bloc peut être n'importe quoi (boîtes,
##     modèles importés, mix) — le générateur ne regarde que les
##     MeshInstance3D pour calculer l'encombrement (anti-chevauchement).
##  2. Chaque porte/ouverture doit avoir un Marker3D enfant (direct ou
##     imbriqué, peu importe) dont le NOM COMMENCE PAR "Door" (ex:
##     "Door1", "DoorNord", "Door_A"...). Oriente le marker pour que sa
##     flèche BLEUE (+Z local) pointe VERS L'EXTÉRIEUR de la salle à
##     travers l'ouverture — c'est ce point + cette direction que le
##     générateur utilise pour recoller deux blocs porte contre porte.
##  3. "category" ci-dessous doit correspondre au rôle du bloc dans le
##     donjon (utilisé pour piocher dans le bon pool de la config).

@export_enum("entrance", "corridor", "room", "junction", "dead_end", "boss") var category: String = "corridor"

## Renvoie tous les Marker3D de porte trouvés sous ce nœud (récursif),
## triés par nom pour un ordre stable entre deux appels.
func get_doors() -> Array[Marker3D]:
	var doors: Array[Marker3D] = []
	_collect_doors(self, doors)
	doors.sort_custom(func(a: Marker3D, b: Marker3D) -> bool: return a.name < b.name)
	return doors

func _collect_doors(node: Node, out: Array[Marker3D]) -> void:
	for child in node.get_children():
		if child is Marker3D and String(child.name).begins_with("Door"):
			out.append(child)
		_collect_doors(child, out)
