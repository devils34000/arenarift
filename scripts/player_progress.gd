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

signal level_up(new_level: int)
signal xp_changed(xp: int, level: int)

var level: int = 1
var xp: int = 0
## Héros déjà sélectionnés (validés) dans un lobby au moins une fois : sert à
## débloquer les Arkanites liées à un héros (hero_id), maintenant que le
## choix du personnage se fait dans le lobby de partie et plus dans le menu.
var played_heroes: Array[String] = []
var _save_path: String = ""
var _loaded: bool = false


func _ready() -> void:
	_ensure_loaded()


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


func _load() -> void:
	level = 1
	xp = 0
	played_heroes = []
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


func _save() -> void:
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"level": level, "xp": xp, "played_heroes": played_heroes}))
	file.close()
