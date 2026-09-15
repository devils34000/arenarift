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
## Probabilité qu'un match termine sur un gain de fragments d'Arkanite (les
## Éclats de fin de match, eux, tombent toujours). Volontairement faible pour
## pousser à jouer davantage plutôt que de garantir un drop à chaque partie.
const FRAGMENT_DROP_CHANCE: float = 0.35
## Probabilité qu'un match termine sur le gain d'une Arkanite d'Éveil
## (consommable). Bien plus rare que les fragments d'équipable : c'est un
## bonus occasionnel, pas une ressource à farmer.
const CONSUMABLE_DROP_CHANCE: float = 0.12

signal level_up(new_level: int)
signal xp_changed(xp: int, level: int)
signal currency_changed(amount: int)
## Émis quand un coffre de palier (niveau multiple de CHEST_LEVEL_INTERVAL)
## octroie une Arkanite directement.
signal arkanite_chest_opened(card_id: String)

var level: int = 1
var xp: int = 0
## Monnaie in-game ("Éclats"), gagnée en fin de match (comme les PI/BE de
## League of Legends). Sert à payer le déblocage final d'une Arkanite une
## fois ses fragments complétés, et plus tard à acheter de nouveaux héros.
var currency: int = 0
## Héros déjà sélectionnés (validés) dans un lobby au moins une fois : sert à
## débloquer les Arkanites liées à un héros (hero_id), maintenant que le
## choix du personnage se fait dans le lobby de partie et plus dans le menu.
var played_heroes: Array[String] = []
## Fragments accumulés par Arkanite (id -> quantité), pour les Arkanites
## équipables (Maîtrise/Invocation), plafonnés à "fragments_required". Une
## fois le seuil atteint, la carte devient "prête" (is_arkanite_ready) mais
## ne rejoint owned_arkanites qu'après paiement de son unlock_cost en Éclats
## (try_unlock_arkanite) — les fragments seuls ne suffisent plus.
var arkanite_fragments: Dictionary = {}
## Arkanites équipables possédées en entier (fragments complétés, ou
## octroyées directement par un coffre de palier).
var owned_arkanites: Array[String] = []
## Arkanites équipées par héros : hero_name -> Array[String] d'ids de cartes
## (jusqu'à LOADOUT_MAX_SLOTS). Géré depuis l'onglet LOADOUT du menu.
var equipped_loadout: Dictionary = {}
## Stock d'Arkanites d'Éveil (consommables) possédées, par id de carte.
## Gagnées rarement en fin de match (CONSUMABLE_DROP_CHANCE) ; chaque
## utilisation (bouton UTILISER) en décrémente une.
var consumable_stock: Dictionary = {}
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


func get_currency() -> int:
	_ensure_loaded()
	return currency


func add_currency(amount: int) -> void:
	_ensure_loaded()
	if amount == 0:
		return
	currency = maxi(0, currency + amount)
	_save()
	currency_changed.emit(currency)


## Éclats attribués en fin de partie : une base pour avoir joué, un bonus de
## victoire — comme l'XP, mais un rythme plus lent (façon PI/BE de LoL) pour
## que débloquer un héros ou payer une Arkanite prenne plusieurs matchs.
func award_match_currency(player_won: bool) -> int:
	var amount: int = 15
	if player_won:
		amount += 10
	add_currency(amount)
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
## les équipables (Maîtrise/Invocation), possédée = achetée avec des Éclats
## (try_unlock_arkanite) ou octroyée directement (coffre de palier) — les
## fragments seuls ne suffisent plus, voir is_arkanite_ready().
func owns_arkanite(card: ArkaniteCard) -> bool:
	_ensure_loaded()
	if card == null:
		return false
	if not card.is_equipable:
		return true
	return owned_arkanites.has(card.id)


## Fragments complétés mais pas encore payée : prête à être débloquée contre
## des Éclats via try_unlock_arkanite().
func is_arkanite_ready(card: ArkaniteCard) -> bool:
	if card == null or not card.is_equipable or owns_arkanite(card):
		return false
	return get_arkanite_fragments(card.id) >= card.fragments_required


## Ajoute des fragments à une Arkanite équipable, plafonnés à
## fragments_required (elle devient alors "prête", voir is_arkanite_ready).
## Sans effet si déjà possédée.
func add_arkanite_fragments(card_id: String, amount: int) -> void:
	_ensure_loaded()
	if amount <= 0 or card_id == "" or owned_arkanites.has(card_id):
		return
	var card := ArkaniteDB.get_by_id(card_id)
	if card == null:
		return
	arkanite_fragments[card_id] = mini(get_arkanite_fragments(card_id) + amount, card.fragments_required)
	_save()


## Paye le coût en Éclats (unlock_cost) d'une Arkanite dont les fragments
## sont complétés, et la fait rejoindre owned_arkanites. Retourne false sans
## rien changer si elle n'est pas prête ou si les Éclats sont insuffisants.
func try_unlock_arkanite(card_id: String) -> bool:
	_ensure_loaded()
	var card := ArkaniteDB.get_by_id(card_id)
	if not is_arkanite_ready(card) or currency < card.unlock_cost:
		return false
	currency -= card.unlock_cost
	owned_arkanites.append(card_id)
	arkanite_fragments.erase(card_id)
	_save()
	currency_changed.emit(currency)
	return true


## Octroie directement une Arkanite équipable (coffre de palier), sans passer
## par les fragments ni les Éclats.
func grant_arkanite(card_id: String) -> void:
	_ensure_loaded()
	if card_id == "" or owned_arkanites.has(card_id):
		return
	owned_arkanites.append(card_id)
	arkanite_fragments.erase(card_id)
	_save()


## Choisit une Arkanite équipable ni possédée ni déjà prête, pertinente pour
## le héros joué (générique ou spécifique à ce héros), et lui attribue des
## fragments de fin de match — avec seulement FRAGMENT_DROP_CHANCE de chances
## de droper quelque chose à chaque match. Retourne un résumé pour
## l'affichage (vide si pas de chance cette fois, ou si tout est déjà
## possédé/prêt pour ce héros).
func award_match_arkanite_fragments(player_won: bool, hero_name: String) -> Dictionary:
	_ensure_loaded()
	if randf() >= FRAGMENT_DROP_CHANCE:
		return {}
	var locked: Array[ArkaniteCard] = []
	for card in ArkaniteDB.get_equipable_for_hero(hero_name):
		if not owns_arkanite(card) and not is_arkanite_ready(card):
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
		"ready": is_arkanite_ready(card),
	}


func get_consumable_stock(card_id: String) -> int:
	_ensure_loaded()
	return int(consumable_stock.get(card_id, 0))


func add_consumable(card_id: String, amount: int = 1) -> void:
	_ensure_loaded()
	if amount <= 0 or card_id == "":
		return
	consumable_stock[card_id] = get_consumable_stock(card_id) + amount
	_save()


## Consomme une Arkanite d'Éveil du stock (bouton UTILISER). Retourne false
## sans rien changer si le stock est déjà à 0.
func consume_arkanite(card_id: String) -> bool:
	_ensure_loaded()
	var current: int = get_consumable_stock(card_id)
	if current <= 0:
		return false
	if current <= 1:
		consumable_stock.erase(card_id)
	else:
		consumable_stock[card_id] = current - 1
	_save()
	return true


## Tire, rarement (CONSUMABLE_DROP_CHANCE), une Arkanite d'Éveil aléatoire en
## fin de match et l'ajoute au stock. Retourne un résumé pour l'affichage
## (vide si pas de chance cette fois).
func award_match_consumable() -> Dictionary:
	_ensure_loaded()
	if randf() >= CONSUMABLE_DROP_CHANCE:
		return {}
	var pool: Array[ArkaniteCard] = []
	for card in ArkaniteDB.get_all():
		if not card.is_equipable:
			pool.append(card)
	if pool.is_empty():
		return {}
	pool.shuffle()
	var card: ArkaniteCard = pool[0]
	add_consumable(card.id, 1)
	return {
		"card_id": card.id,
		"display_name": card.display_name,
		"stock": get_consumable_stock(card.id),
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
	currency = 0
	played_heroes = []
	arkanite_fragments = {}
	owned_arkanites = []
	equipped_loadout = {}
	consumable_stock = {}
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
	currency = maxi(0, int(parsed.get("currency", 0)))
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
	var stock_data: Variant = parsed.get("consumable_stock", {})
	if typeof(stock_data) == TYPE_DICTIONARY:
		for card_id in stock_data.keys():
			consumable_stock[str(card_id)] = int(stock_data[card_id])


func _save() -> void:
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"level": level,
		"xp": xp,
		"currency": currency,
		"played_heroes": played_heroes,
		"arkanite_fragments": arkanite_fragments,
		"owned_arkanites": owned_arkanites,
		"equipped_loadout": equipped_loadout,
		"consumable_stock": consumable_stock,
	}))
	file.close()
