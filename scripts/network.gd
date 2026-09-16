extends Node
## Couche ENet utilisée aussi par le futur serveur Godot headless.

signal session_started
signal session_joined
signal session_failed(reason: String)
signal peer_arrived(peer_id: int)
signal peer_left(peer_id: int)
signal arena_client_ready_signal(peer_id: int, hero: String, mode: String, team: String)
signal arena_player_input_received(peer_id: int, move_direction: Vector3, aim_direction: Vector3)

## Lobby de sélection de personnage (après matchmaking, avant le chargement
## de l'arène) : émis côté client à chaque mise à jour envoyée par le
## serveur (nouveau pick, joueur prêt, joueur qui rejoint/part).
signal lobby_state_changed(picks: Dictionary, seconds_left: float)
## Émis côté client quand le serveur donne le feu vert (tout le monde prêt,
## ou temps écoulé) : le menu doit alors lancer la partie (_launch()).
signal lobby_match_ready()
## Émis côté client quand le serveur annule la partie (un joueur n'a pas
## validé son héros à temps) : le menu doit se déconnecter et revenir en
## arrière avec le message donné en raison.
signal lobby_cancelled(reason: String)
## Émis côté serveur uniquement (dedicated_server.gd s'y abonne) pour
## déclencher la fermeture propre du process après annulation du lobby.
signal lobby_cancelled_server_side(reason: String)

const DEFAULT_PORT := 2456
const MAX_PLAYERS := 8
var peer: ENetMultiplayerPeer
var match_mode := "DEATHMATCH"
var selected_hero := "AERIS"
var match_started: bool = false

# =========================================================
# LOBBY DE SÉLECTION DE PERSONNAGE
# =========================================================
## État autoritaire (côté serveur) / miroir reçu (côté client) :
## peer_id -> {"hero": String, "ready": bool}.
var lobby_picks: Dictionary = {}
var lobby_active: bool = false
var lobby_seconds_left: float = 30.0
const LOBBY_DURATION := 30.0
var _lobby_timer: Timer
# Camp ("ASTRAL"/"ARCANE") choisi en Custom Game avant de rejoindre le
# serveur, transmis au serveur via arena_client_ready. Vide pour tous les
# autres modes, qui gardent l'assignation automatique par ordre de connexion.
var pending_custom_team: String = ""

func _ready() -> void:
	multiplayer.peer_connected.connect(func(id):
		print("=== NETWORK : PEER CONNECTED === ", id)
		peer_arrived.emit(id)
	)

	multiplayer.peer_disconnected.connect(func(id):
		print("=== NETWORK : PEER DISCONNECTED === ", id)
		peer_left.emit(id)
	)

	multiplayer.connection_failed.connect(func():
		print("=== NETWORK : CONNECTION FAILED ===")
		session_failed.emit("Connexion impossible")
	)

	multiplayer.server_disconnected.connect(func():
		print("=== NETWORK : SERVER DISCONNECTED ===")
		session_failed.emit("Serveur déconnecté")
	)

	_lobby_timer = Timer.new()
	_lobby_timer.name = "LobbyTimer"
	_lobby_timer.one_shot = true
	add_child(_lobby_timer)
	_lobby_timer.timeout.connect(_on_lobby_timeout)

	print("=== NETWORK : READY ===")

func host(port: int = DEFAULT_PORT) -> Error:
	match_started = false
	peer = ENetMultiplayerPeer.new()
	var result := peer.create_server(port, MAX_PLAYERS)
	if result == OK:
		multiplayer.multiplayer_peer = peer
		session_started.emit()
	return result

func join(address: String, port: int = DEFAULT_PORT) -> Error:
	match_started = false
	print("")
	print("=== NETWORK : JOIN ===")
	print("Adresse :", address)
	print("Port    :", port)

	peer = ENetMultiplayerPeer.new()

	var result := peer.create_client(address, port)

	print("Résultat create_client :", result)

	if result == OK:
		multiplayer.multiplayer_peer = peer
		session_joined.emit()
		print("=== NETWORK : CLIENT ENET CREE ===")
	else:
		print("=== NETWORK : ERREUR CLIENT === ", result)

	return result

func _get_network_arena() -> Node:
	var arenas := get_tree().get_nodes_in_group("arena_network")
	if arenas.is_empty():
		return null
	return arenas[0] as Node

@rpc("any_peer", "call_remote", "unreliable_ordered", 0)
func arena_player_input(move_direction: Vector3, aim_direction: Vector3, input_sequence: int = 0, jump_pressed: bool = false, sprint_held: bool = false) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return
	var arena := _get_network_arena()
	if arena != null:
		arena.call("_network_receive_player_input", sender, move_direction, aim_direction, input_sequence, jump_pressed, sprint_held)

@rpc("any_peer", "call_remote", "reliable")
func arena_ability_request(kind: String, direction: Vector3, value: float = 0.0, input_sequence: int = 0) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return
	var arena := _get_network_arena()
	if arena != null:
		arena.call("_network_receive_ability_request", sender, kind, direction, value, input_sequence)

@rpc("any_peer", "call_remote", "reliable")
func arena_client_ready(hero: String, mode: String, team: String = "") -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	arena_client_ready_signal.emit(sender, hero, mode, team)

@rpc("any_peer", "call_remote", "reliable")
func arena_spawn_fighter(fighter_id: int, hero: String, team: Color, pos: Vector3, rot_y: float, bot: bool, monster_skin: String = "", model_scale: float = -1.0, max_health_value: float = -1.0, health_value: float = -1.0) -> void:
	print("NETWORK : SPAWN RPC RECU id=", fighter_id, " bot=", bot, " pos=", pos)
	if multiplayer.is_server():
		return
	var arena := _get_network_arena()
	if arena != null:
		arena.call("_network_client_spawn_fighter", fighter_id, hero, team, pos, rot_y, bot, monster_skin, model_scale, max_health_value, health_value)

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func arena_transform(fighter_id: int, pos: Vector3, rot_y: float, net_velocity: Vector3, health_value: float = 100.0, round_serial: int = 1, state_sequence: int = 0, aggroed: bool = false) -> void:
	if multiplayer.is_server():
		return
	var arena := _get_network_arena()
	if arena != null:
		arena.call("_network_client_transform", fighter_id, pos, rot_y, net_velocity, health_value, round_serial, state_sequence, aggroed)

@rpc("authority", "call_remote", "reliable")
func arena_hard_correction(fighter_id: int, pos: Vector3, rot_y: float, net_velocity: Vector3, health_value: float, round_serial: int, state_sequence: int) -> void:
	if multiplayer.is_server():
		return
	var arena := _get_network_arena()
	if arena != null:
		arena.call("_network_client_hard_correction", fighter_id, pos, rot_y, net_velocity, health_value, round_serial, state_sequence)

@rpc("any_peer", "call_remote", "reliable")
func arena_spell_event(kind: String, origin: Vector3, direction: Vector3, caster_id: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0 or sender != caster_id:
		return
	var arena := _get_network_arena()
	if arena != null:
		arena.call("_network_receive_spell_event", kind, origin, direction, caster_id)

@rpc("authority", "call_remote", "reliable")
func arena_spell_visual(kind: String, origin: Vector3, direction: Vector3, caster_id: int, value: float = 0.0) -> void:
	if multiplayer.is_server():
		return
	var arena := _get_network_arena()
	if arena != null:
		arena.call("_network_client_spell_visual", kind, origin, direction, caster_id, value)

## Co-op Donjon : petit bandeau d'info transitoire (salle nettoyée, boss
## abattu, coffre ouvert...) diffusé par le serveur à tous les clients.
@rpc("authority", "call_remote", "reliable")
func arena_coop_notice(text: String) -> void:
	if multiplayer.is_server():
		return
	var arena := _get_network_arena()
	if arena != null:
		arena.call("_network_client_coop_notice", text)

## Co-op Donjon : fin de partie (portail ouvert = victoire, toute l'équipe
## à terre = défaite), diffusée à tous les clients.
@rpc("authority", "call_remote", "reliable")
func arena_coop_result(victory: bool) -> void:
	if multiplayer.is_server():
		return
	var arena := _get_network_arena()
	if arena != null:
		arena.call("_network_client_coop_result", victory)

## Co-op Donjon : état de la progression (salles nettoyées / clé du boss),
## poussé par le serveur — seul lui a coop_rooms_cleared/coop_key_dropped à
## jour, les clients affichent simplement ce qu'on leur envoie.
@rpc("authority", "call_remote", "reliable")
func arena_coop_progress(cleared: int, total: int, key_dropped: bool) -> void:
	if multiplayer.is_server():
		return
	var arena := _get_network_arena()
	if arena != null:
		arena.call("_network_client_coop_progress", cleared, total, key_dropped)

## Récupération de la hache de Kaithlyn : le serveur seul décide du moment
## exact où la hache est ramassée (position/cooldown remis à zéro), et le
## diffuse ici. Sans cette RPC, chaque client décidait indépendamment quand
## ramasser sa propre copie de la hache d'après sa simulation locale, ce qui
## pouvait désynchroniser son état (visible/tenue en main) entre pairs.
@rpc("authority", "call_remote", "reliable")
func arena_axe_recovered(caster_id: int) -> void:
	if multiplayer.is_server():
		return
	var arena := _get_network_arena()
	if arena != null:
		arena.call("_network_client_axe_recovered", caster_id)

@rpc("any_peer", "call_remote", "reliable")
func arena_sync_request() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var arena := _get_network_arena()
	if arena != null and sender > 0:
		arena.call("_network_send_all_to", sender)
		print("NETWORK : SYNC REQUEST FROM ", sender)

@rpc("authority", "call_remote", "reliable")
func arena_despawn_fighter(fighter_id: int) -> void:
	if multiplayer.is_server():
		return
	var arena := _get_network_arena()
	if arena != null:
		arena.call("_network_client_despawn_fighter", fighter_id)

@rpc("authority", "call_remote", "reliable")
func arena_round_reset(fighter_id: int, pos: Vector3, rot_y: float, health_value: float = 100.0, round_number: int = 0, state_sequence: int = 0) -> void:
	if multiplayer.is_server():
		return
	var arena := _get_network_arena()
	if arena != null:
		arena.call("_network_client_round_reset", fighter_id, pos, rot_y, health_value, round_number, state_sequence)

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func arena_match_state(time_left: float, kills: int, deaths: int, astral_kills: int, arcane_kills: int, team_astral: int, team_arcane: int, round_serial: int, sudden_death: bool = false, match_kills: int = 0, match_damage_dealt: float = 0.0) -> void:
	if multiplayer.is_server():
		return
	var arena := _get_network_arena()
	if arena != null:
		arena.call("_network_client_match_state", time_left, kills, deaths, astral_kills, arcane_kills, team_astral, team_arcane, round_serial, sudden_death, match_kills, match_damage_dealt)

@rpc("authority", "call_remote", "unreliable_ordered", 3)
func arena_damage_vfx(kind: String, position: Vector3, direction: Vector3) -> void:
	if multiplayer.is_server():
		return
	var arena := _get_network_arena()
	if arena != null:
		arena.call("_network_client_damage_vfx", kind, position, direction)

@rpc("authority", "call_remote", "reliable")
func arena_match_countdown(seconds_left: float) -> void:
	match_started = false
	var arena := _get_network_arena()
	if arena != null:
		arena.set("network_match_countdown_left", seconds_left)
		arena.call("_on_network_match_countdown", seconds_left)

## Score de round (BO3) pour les modes DUEL / TEAM. Sans cette RPC, les
## clients ne recevaient jamais duel_astral_rounds / team_astral_rounds :
## le round se terminait bien côté serveur (kills comptés, écran affiché
## localement chez l'hôte) mais chaque client restait bloqué sur un score
## de round à 0-0 et ne voyait jamais l'écran de fin de round/partie.
@rpc("authority", "call_remote", "reliable")
func arena_round_result(mode: String, astral_rounds: int, arcane_rounds: int, round_number: int, match_over: bool, astral_wins: bool) -> void:
	if multiplayer.is_server():
		return
	var arena := _get_network_arena()
	if arena != null:
		arena.call("_network_client_round_result", mode, astral_rounds, arcane_rounds, round_number, match_over, astral_wins)

## Notifie les clients qu'un fighter vient de mourir, avec son délai de
## respawn. Sans cette RPC, la mort en cours de round n'était jamais
## transmise au réseau : seule la valeur de vie (0) arrivait via
## arena_transform, mais rien n'indiquait au client concerné qu'il devait
## afficher son écran de mort / compte à rebours de réapparition, et rien
## ne cachait visuellement le fighter mort chez les autres clients.
@rpc("authority", "call_remote", "reliable")
func arena_fighter_death(fighter_id: int, respawn_delay: float) -> void:
	if multiplayer.is_server():
		return
	var arena := _get_network_arena()
	if arena != null:
		arena.call("_network_client_fighter_death", fighter_id, respawn_delay)

## Résultat de fin de partie DEATHMATCH (mode sans BO3). Avant cette RPC,
## la fin de partie en réseau ne déclenchait strictement rien côté client.
@rpc("authority", "call_remote", "reliable")
func arena_deathmatch_result(winner_peer_id: int, winner_hero: String, best_kills: int) -> void:
	if multiplayer.is_server():
		return
	var arena := _get_network_arena()
	if arena != null:
		arena.call("_network_client_deathmatch_result", winner_peer_id, winner_hero, best_kills)

@rpc("authority", "call_remote", "reliable")
func arena_match_started() -> void:
	match_started = true
	var arena := _get_network_arena()
	if arena != null:
		arena.call("_on_network_match_started")


# =========================================================
# LOBBY DE SÉLECTION DE PERSONNAGE
# =========================================================
## Appelé côté serveur dédié (dedicated_server.gd, sur peer_connected) :
## enregistre un joueur dans le lobby et démarre le compte à rebours de 30s
## au premier arrivant. Un pick par défaut (AERIS, non prêt) est posé tout
## de suite pour que ce joueur apparaisse dans l'état diffusé aux autres
## même s'il n'a encore rien choisi.
func lobby_register_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if lobby_picks.has(peer_id):
		return
	lobby_picks[peer_id] = {"hero": "AERIS", "ready": false}
	if not lobby_active:
		lobby_active = true
		lobby_seconds_left = LOBBY_DURATION
		_lobby_timer.start(LOBBY_DURATION)
	_broadcast_lobby_state()

## Appelé côté serveur dédié sur peer_disconnected.
func lobby_unregister_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if not lobby_picks.has(peer_id):
		return
	lobby_picks.erase(peer_id)
	_broadcast_lobby_state()

func _on_lobby_timeout() -> void:
	if not multiplayer.is_server() or not lobby_active:
		return
	# À partir de 2 joueurs (un vrai duel/équipe), si l'un d'eux n'a pas
	# validé à temps, la partie est annulée plutôt que lancée avec un choix
	# par défaut qu'il n'a pas fait lui-même. Un joueur seul (partie
	# complétée par des bots) n'est jamais annulé pour ça : il n'y a
	# personne d'autre en attente de lui.
	if lobby_picks.size() >= 2:
		var all_ready := true
		for pid in lobby_picks.keys():
			if not bool((lobby_picks[pid] as Dictionary).get("ready", false)):
				all_ready = false
				break
		if not all_ready:
			_cancel_lobby("Un joueur n'a pas validé son héros à temps.")
			return
	_finish_lobby()

## Annule le lobby (et donc la partie) : diffuse la raison à tous les
## clients puis prévient dedicated_server.gd (signal local) pour qu'il
## referme la partie côté matchmaking et éteigne le process.
func _cancel_lobby(reason: String) -> void:
	if not lobby_active:
		return
	lobby_active = false
	_lobby_timer.stop()
	lobby_cancel.rpc(reason)
	lobby_cancelled_server_side.emit(reason)
	lobby_picks.clear()

@rpc("authority", "call_remote", "reliable")
func lobby_cancel(reason: String) -> void:
	lobby_active = false
	lobby_cancelled.emit(reason)

## Envoyé par un client (rpc_id(1, ...)) à chaque changement de héros
## (ready=false, aperçu live pour les autres joueurs du lobby) et à la
## validation finale (ready=true).
@rpc("any_peer", "call_remote", "reliable")
func lobby_submit_pick(hero: String, ready: bool) -> void:
	if not multiplayer.is_server() or not lobby_active:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0 or not lobby_picks.has(sender):
		return
	var safe_hero := hero if hero in ["AERIS", "MAYLINH", "KAITHLYN", "EREN"] else "AERIS"
	lobby_picks[sender] = {"hero": safe_hero, "ready": ready}
	_broadcast_lobby_state()

	# Fin anticipée seulement à partir de 2 joueurs connectés (sinon un
	# joueur seul qui valide lancerait la partie tout de suite sans laisser
	# de chance à l'adversaire de se connecter).
	if lobby_picks.size() >= 2:
		var all_ready := true
		for pid in lobby_picks.keys():
			if not bool((lobby_picks[pid] as Dictionary).get("ready", false)):
				all_ready = false
				break
		if all_ready:
			_finish_lobby()

func _finish_lobby() -> void:
	if not lobby_active:
		return
	lobby_active = false
	_lobby_timer.stop()
	lobby_proceed.rpc()

## Diffusé par le serveur à tous les clients : le lobby est terminé, chacun
## doit lancer sa propre partie (change de scène vers l'arène) avec le héros
## qu'il a lui-même choisi localement.
@rpc("authority", "call_remote", "reliable")
func lobby_proceed() -> void:
	lobby_active = false
	lobby_match_ready.emit()

func _broadcast_lobby_state() -> void:
	if not multiplayer.is_server():
		return
	lobby_seconds_left = _lobby_timer.time_left if lobby_active else 0.0
	lobby_state_broadcast.rpc(lobby_picks, lobby_seconds_left)

@rpc("authority", "call_remote", "reliable")
func lobby_state_broadcast(picks: Dictionary, seconds_left: float) -> void:
	lobby_picks = picks
	lobby_seconds_left = seconds_left
	lobby_state_changed.emit(picks, seconds_left)


func close() -> void:
	# Sur un client, peer.close() détruit l'hôte ENet local directement, sans
	# garantie qu'un paquet de déconnexion propre parte vers le serveur : le
	# serveur devait alors attendre son propre timeout ENet (qui peut prendre
	# largement plus que quelques secondes) avant de remarquer le départ.
	# disconnect_peer(1) prévient explicitement le serveur (peer 1) tout de
	# suite ; on laisse une frame pour que ce paquet parte réellement avant
	# de détruire l'hôte local.
	if peer and multiplayer.multiplayer_peer == peer and not multiplayer.is_server():
		peer.disconnect_peer(1)
		await Engine.get_main_loop().process_frame
	if peer:
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
