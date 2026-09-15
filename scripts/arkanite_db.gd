extends Node
## Catalogue des Arkanites, accessible partout (menu + arène) via "ArkaniteDB".
## Autoload : source unique de vérité pour la liste des cartes, utilisée à la
## fois par l'UI (onglets ARKANITES/LOADOUT) et par la logique de drop en fin
## de match (arena_3d.gd), pour éviter de dupliquer la liste des fichiers.

const ARKANITE_DATA_DIR: String = "res://data/arkanites/"
const ARKANITE_FILES: Array[String] = [
	"eveil_etude.tres",
	"eveil_sang_vif.tres",
	"eveil_fortune.tres",
	"maitrise_celerite_aeris.tres",
	"maitrise_resilience_kaithlyn.tres",
	"maitrise_ardeur_eren.tres",
	"invocation_voile_maylinh.tres",
	"invocation_garde_aeris.tres",
	"invocation_brasier_eren.tres",
]

var _cards: Array[ArkaniteCard] = []
var _by_id: Dictionary = {}
var _loaded: bool = false


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for file_name in ARKANITE_FILES:
		var card := load(ARKANITE_DATA_DIR + file_name) as ArkaniteCard
		if card != null:
			_cards.append(card)
			_by_id[card.id] = card


func get_all() -> Array[ArkaniteCard]:
	_ensure_loaded()
	return _cards


func get_by_id(card_id: String) -> ArkaniteCard:
	_ensure_loaded()
	return _by_id.get(card_id, null) as ArkaniteCard


## Arkanites équipables (Maîtrise/Invocation) utilisables par un héros donné :
## soit génériques (hero_id vide), soit spécifiques à ce héros.
func get_equipable_for_hero(hero_name: String) -> Array[ArkaniteCard]:
	_ensure_loaded()
	var result: Array[ArkaniteCard] = []
	for card in _cards:
		if card.is_equipable and (card.hero_id == "" or card.hero_id == hero_name):
			result.append(card)
	return result
