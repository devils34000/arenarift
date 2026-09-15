extends Node
## Progression du joueur (niveau/XP), liée à son SteamID.
## Autoload : accessible partout via "PlayerProgress".
##
## Sauvegarde locale (user://) séparée par SteamID, pour que deux comptes
## Steam sur la même machine n'écrasent pas la progression l'un de l'autre.
## Si Steam n'est pas disponible (test hors-ligne, serveur dédié), on utilise
## un slot de sauvegarde "local" de secours.

const MAX_LEVEL: int = 50
const SAVE_DIR: String = "user://progress/"
const LOADOUT_MAX_SLOTS: int = 3
## Tous les N niveaux, un "coffre de palier" octroie directement une Arkanite
## équipable aléatoire non encore possédée (en plus des fragments de fin de
## match).
const CHEST_LEVEL_INTERVAL: int = 5

signal level_up(new_level: int)
signal xp_changed(xp: int, level: int)
## Émis quand un coffre de palier (niveau multiple de CHEST_LEVEL_INTERVAL)
## octroie une Arkanite directement.
signal arkanite_chest_opened(card_id: String)

var level: int = 1
var xp: int = 0
## Héros déjà sélectionnés (validés) dans un lobby au moins une fois : sert à
## débloquer les Arkanites liées à un héros (hero_id), maintenant que le
## choix du personnage se fait dans le lobby de partie et plus dans le menu.
var played_heroes: Array[String] = []
## Fragments accumulés par Arkanite (id -> quantité), pour les Arkanites
## équipables (Maîtrise/Invocation). Une fois le seuil "fragments_required"
## atteint, la carte bascule automatiquement dans owned_arkanites.
var arkanite_fragments: Dictionary = {}
## Arkanites équipables possédées en entier (fragments complétés, ou
## octroyées directement par un coffre de palier).
var owned_arkanites: Array[String] = []
## Arkanites équipées par héros : hero_name -> Array[String] d'ids de cartes
## (jusqu'à LOADOUT_MAX_SLOTS). Géré depuis l'onglet LOADOUT du menu.
var equipped_loadout: Dictionary = {}
var _save_path: String = ""
var _loaded: bool = false


func _ready() -> void:
	_ensure_loaded()
	level_up.connect(_on_level_up)


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var steam_manager := get_node_or_null("/root/SteamManager")
	var id_key: String = "local"
	if steam_manager != null:
		var sid: int = int(steam_manager.get("steam_id"))
		if sid != 0:
			id_key = str(sid)
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_save_path = SAVE_DIR + "progress_%s.json" % id_key
	_load()


## XP nécessaire pour passer du niveau "from_level" au suivant.
func xp_to_next_level(from_level: int) -> int:
	return 100 + from_level * 40


func get_level() -> int:
	_ensure_loaded()
	return level


func get_xp() -> int:
	_ensure_loaded()
	return xp


func add_xp(amount: int) -> void:
	_ensure_loaded()
	if amount <= 0 or level >= MAX_LEVEL:
		return
	xp += amount
	while level < MAX_LEVEL and xp >= xp_to_next_level(level):
		xp -= xp_to_next_level(level)
		level += 1
		level_up.emit(level)
	if level >= MAX_LEVEL:
		xp = 0
	_save()
	xp_changed.emit(xp, level)


## XP attribuée en fin de partie : une base pour avoir joué, un bonus de
## victoire, et un petit bonus par élimination. Retourne le montant accordé
## (affiché ensuite dans le tableau de score de fin de partie).
func award_match_xp(player_won: bool, kills: int) -> int:
	var amount: int = 40
	if player_won:
		amount += 60
	amount += maxi(0, kills) * 5
	add_xp(amount)
	return amount


## Marque un héros comme joué (choix validé dans un lobby) : débloque
## définitivement les Arkanites liées à ce héros. Sans effet si déjà marqué.
func mark_hero_played(hero_name: String) -> void:
	_ensure_loaded()
	if hero_name == "" or played_heroes.has(hero_name):
		return
	played_heroes.append(hero_name)
	_save()


func has_played_hero(hero_name: String) -> bool:
	_ensure_loaded()
	return played_heroes.has(hero_name)


# =========================================================
# ARKANITES : fragments, possession, équipement
# =========================================================

func get_arkanite_fragments(card_id: String) -> int:
	_ensure_loaded()
	return int(arkanite_fragments.get(card_id, 0))


## Une Arkanite de type Éveil (consommable) n'a pas de notion de possession
## fragmentée : seul son niveau requis (géré ailleurs) la conditionne. Pour
## les équipables (Maîtrise/Invocation), possédée = fragments complétés ou
## octroyée directement (coffre de palier).
func owns_arkanite(card: ArkaniteCard) -> bool:
	_ensure_loaded()
	if card == null:
		return false
	if not card.is_equipable:
		return true
	return owned_arkanites.has(card.id) or get_arkanite_fragments(card.id) >= card.fragments_required


## Ajoute des fragments à une Arkanite équipable ; bascule automatiquement en
## "possédée" une fois le seuil atteint. Sans effet si déjà possédée.
func add_arkanite_fragments(card_id: String, amount: int) -> void:
	_ensure_loaded()
	if amount <= 0 or card_id == "" or owned_arkanites.has(card_id):
		return
	var card := ArkaniteDB.get_by_id(card_id)
	if card == null:
		return
	var total: int = get_arkanite_fragments(card_id) + amount
	if total >= card.fragments_required:
		owned_arkanites.append(card_id)
		arkanite_fragments.erase(card_id)
	else:
		arkanite_fragments[card_id] = total
	_save()


## Octroie directement une Arkanite équipable (coffre de palier), sans passer
## par les fragments.
func grant_arkanite(card_id: String) -> void:
	_ensure_loaded()
	if card_id == "" or owned_arkanites.has(card_id):
		return
	owned_arkanites.append(card_id)
	arkanite_fragments.erase(card_id)
	_save()


## Choisit une Arkanite équipable non encore possédée, pertinente pour le
## héros joué (générique ou spécifique à ce héros), et lui attribue des
## fragments de fin de match. Retourne un résumé pour l'affichage (vide si
## le joueur possède déjà tout ce qui est pertinent pour ce héros).
func award_match_arkanite_fragments(player_won: bool, hero_name: String) -> Dictionary:
	_ensure_loaded()
	var locked: Array[ArkaniteCard] = []
	for card in ArkaniteDB.get_equipable_for_hero(hero_name):
		if not owns_arkanite(card):
			locked.append(card)
	if locked.is_empty():
		return {}
	locked.shuffle()
	var card: ArkaniteCard = locked[0]
	var amount: int = 2 + (2 if player_won else 0)
	add_arkanite_fragments(card.id, amount)
	return {
		"card_id": card.id,
		"display_name": card.display_name,
		"amount": amount,
		"fragments": get_arkanite_fragments(card.id),
		"required": card.fragments_required,
		"unlocked": owned_arkanites.has(card.id),
	}


func _on_level_up(new_level: int) -> void:
	if new_level % CHEST_LEVEL_INTERVAL != 0:
		return
	var locked: Array[ArkaniteCard] = []
	for card in ArkaniteDB.get_all():
		if card.is_equipable and not owns_arkanite(card):
			locked.append(card)
	if locked.is_empty():
		return
	locked.shuffle()
	var card: ArkaniteCard = locked[0]
	grant_arkanite(card.id)
	arkanite_chest_opened.emit(card.id)


func get_equipped_loadout(hero_name: String) -> Array[String]:
	_ensure_loaded()
	var out: Array[String] = []
	for card_id in equipped_loadout.get(hero_name, []):
		out.append(str(card_id))
	return out


func is_arkanite_equipped(hero_name: String, card_id: String) -> bool:
	return get_equipped_loadout(hero_name).has(card_id)


## Équipe une Arkanite possédée sur un héros. Retourne false si les
## LOADOUT_MAX_SLOTS emplacements sont déjà pris (et n'équipe rien).
func equip_arkanite(hero_name: String, card_id: String) -> bool:
	_ensure_loaded()
	var list := get_equipped_loadout(hero_name)
	if list.has(card_id):
		return true
	if list.size() >= LOADOUT_MAX_SLOTS:
		return false
	list.append(card_id)
	equipped_loadout[hero_name] = list
	_save()
	return true


func unequip_arkanite(hero_name: String, card_id: String) -> void:
	_ensure_loaded()
	var list := get_equipped_loadout(hero_name)
	if not list.has(card_id):
		return
	list.erase(card_id)
	equipped_loadout[hero_name] = list
	_save()


func _load() -> void:
	level = 1
	xp = 0
	played_heroes = []
	arkanite_fragments = {}
	owned_arkanites = []
	equipped_loadout = {}
	if not FileAccess.file_exists(_save_path):
		return
	var file := FileAccess.open(_save_path, FileAccess.READ)
	if file == null:
		return
	var content := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	level = clampi(int(parsed.get("level", 1)), 1, MAX_LEVEL)
	xp = maxi(0, int(parsed.get("xp", 0)))
	for hero_name in parsed.get("played_heroes", []):
		played_heroes.append(str(hero_name))
	var fragments_data: Variant = parsed.get("arkanite_fragments", {})
	if typeof(fragments_data) == TYPE_DICTIONARY:
		for card_id in fragments_data.keys():
			arkanite_fragments[str(card_id)] = int(fragments_data[card_id])
	for card_id in parsed.get("owned_arkanites", []):
		owned_arkanites.append(str(card_id))
	var loadout_data: Variant = parsed.get("equipped_loadout", {})
	if typeof(loadout_data) == TYPE_DICTIONARY:
		for hero_name in loadout_data.keys():
			var ids: Array[String] = []
			for card_id in loadout_data[hero_name]:
				ids.append(str(card_id))
			equipped_loadout[str(hero_name)] = ids


func _save() -> void:
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"level": level,
		"xp": xp,
		"played_heroes": played_heroes,
		"arkanite_fragments": arkanite_fragments,
		"owned_arkanites": owned_arkanites,
		"equipped_loadout": equipped_loadout,
	}))
	file.close()
