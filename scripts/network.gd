extends Node
## Couche ENet utilisée aussi par le futur serveur Godot headless.

signal session_started
signal session_joined
signal session_failed(reason: String)
signal peer_arrived(peer_id: int)
signal peer_left(peer_id: int)
signal arena_client_ready_signal(peer_id: int, hero: String, mode: String)
signal arena_player_input_received(peer_id: int, move_direction: Vector3, aim_direction: Vector3)

const DEFAULT_PORT := 2456
const MAX_PLAYERS := 8
var peer: ENetMultiplayerPeer
var match_mode := "DEATHMATCH"
var selected_hero := "AERIS"
var match_started: bool = false

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
func arena_player_input(move_direction: Vector3, aim_direction: Vector3, input_sequence: int = 0) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return
	var arena := _get_network_arena()
	if arena != null:
		arena.call("_network_receive_player_input", sender, move_direction, aim_direction, input_sequence)

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
func arena_client_ready(hero: String, mode: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	arena_client_ready_signal.emit(sender, hero, mode)

@rpc("any_peer", "call_remote", "reliable")
func arena_spawn_fighter(fighter_id: int, hero: String, team: Color, pos: Vector3, rot_y: float, bot: bool) -> void:
	print("NETWORK : SPAWN RPC RECU id=", fighter_id, " bot=", bot, " pos=", pos)
	if multiplayer.is_server():
		return
	var arena := _get_network_arena()
	if arena != null:
		arena.call("_network_client_spawn_fighter", fighter_id, hero, team, pos, rot_y, bot)

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func arena_transform(fighter_id: int, pos: Vector3, rot_y: float, net_velocity: Vector3, health_value: float = 100.0, round_serial: int = 1, state_sequence: int = 0) -> void:
	if multiplayer.is_server():
		return
	var arena := _get_network_arena()
	if arena != null:
		arena.call("_network_client_transform", fighter_id, pos, rot_y, net_velocity, health_value, round_serial, state_sequence)

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
func arena_match_state(time_left: float, kills: int, deaths: int, astral_kills: int, arcane_kills: int, team_astral: int, team_arcane: int, round_serial: int) -> void:
	if multiplayer.is_server():
		return
	var arena := _get_network_arena()
	if arena != null:
		arena.call("_network_client_match_state", time_left, kills, deaths, astral_kills, arcane_kills, team_astral, team_arcane, round_serial)

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
