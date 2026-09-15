## ArkaniteCard — Resource décrivant une carte Arkanite.
## Placez ce fichier dans res://scripts/arkanite_card.gd
##
## Chaque Arkanite existe en tant que fichier .tres séparé (voir
## res://data/arkanites/*.tres), ce qui permet d'ajouter de nouvelles
## cartes plus tard sans modifier le code.
extends Resource
class_name ArkaniteCard

enum Family { EVEIL, MAITRISE, INVOCATION }

@export var id: String = ""                     ## identifiant unique stable, ex: "eveil_etude"
@export var display_name: String = ""            ## "Arkanite de l'Étude"
@export var family: Family = Family.EVEIL
@export var hero_id: String = ""                 ## "" si non liée à un héros (cas des Arkanites d'Éveil)
@export var image_path: String = ""              ## res://assets/arkanite/xxx.png
@export var effect_text: String = ""             ## "+50% XP pendant 1h"
@export var flavor_text: String = ""             ## citation en italique
@export var is_equipable: bool = false           ## true pour Maîtrise/Invocation, false pour Éveil (consommable)
@export var unlock_level: int = 1                ## niveau requis pour l'équiper (ignoré pour les consommables)
@export var fragments_required: int = 8          ## fragments à collecter pour posséder cette Arkanite (Maîtrise/Invocation uniquement)
@export var unlock_cost: int = 150               ## coût en Éclats pour finaliser le déblocage une fois les fragments complétés

## Effets numériques optionnels : uniquement utilisés par les Arkanites de
## Maîtrise pour moduler une stat existante. Le nom du champ correspond
## exactement à un champ @export de player_3d.gd (ex: "aeris_speed").
@export var stat_field: String = ""
@export var stat_delta: float = 0.0

## Uniquement pour les Arkanites d'Invocation : identifiant du sort
## additionnel débloqué, à relier plus tard dans arena_3d.gd.
@export var unlocked_spell_id: String = ""


func family_label() -> String:
	match family:
		Family.MAITRISE:
			return "MAÎTRISE"
		Family.INVOCATION:
			return "INVOCATION"
		_:
			return "ÉVEIL"


func family_accent_color() -> Color:
	match family:
		Family.MAITRISE:
			return Color("4fae7d")
		Family.INVOCATION:
			return Color("c0392b")
		_:
			return Color("c9a24d")
