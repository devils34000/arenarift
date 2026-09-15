extends Node

const DEFAULT_PORT := 2456
const MAX_PLAYERS := 8

const ARENA_DEFAULT := "res://scenes/arena.tscn"
const ARENA_1V1 := "res://scenes/Arena1v1.tscn"
const ARENA_LABYRINTH := "res://scenes/ArenaLabyrinth.tscn"

const DEFAULT_MATCHMAKING_URL := "http://149.202.91.92:8080"
# Délai max d'attente d'une réponse du matchmaking avant de quitter quand
# même : un service de matchmaking injoignable ne doit jamais empêcher le
# serveur dédié de s'éteindre.
const REPORT_TIMEOUT := 3.0

var match_id := ""
var server_port := DEFAULT_PORT
var game_mode := "default"
var matchmaking_url := DEFAULT_MATCHMAKING_URL

# Sans l'extinction automatique ci-dessous, le process du serveur dédié ne
# s'arrêtait JAMAIS une fois la partie terminée : le port restait ouvert et
# la scène Arena (terminée) restait chargée.
var _connected_peers: int = 0
var _has_had_a_player: bool = false
# Petit délai de grâce avant extinction, pour ne pas tuer le serveur sur une
# simple micro-coupure réseau le temps qu'un joueur se reconnecte.
const EMPTY_SERVER_SHUTDOWN_DELAY := 15.0
var _shutdown_timer: SceneTreeTimer = null

var _report_http: HTTPRequest
var _quit_called: bool = false


func _ready() -> void:
	print("")
	print("========================================")
	print("        ARENA RIFT DEDICATED SERVER")
	print("========================================")

	Network.peer_arrived.connect(_on_peer_arrived)
	Network.peer_left.connect(_on_peer_left)
	Network.lobby_cancelled_server_side.connect(_on_lobby_cancelled)

	_parse_arguments()

	print("Match ID    :", match_id)
	print("Port        :", server_port)
	print("Mode        :", game_mode)
	print("Matchmaking :", matchmaking_url)
	print("Max         :", MAX_PLAYERS)

	_report_http = HTTPRequest.new()
	_report_http.name = "MatchReportHTTP"
	add_child(_report_http)

	var result := Network.host(server_port)

	if result != OK:
		push_error("Impossible de démarrer le serveur ENet. Code : %s" % result)
		get_tree().quit(1)
		return

	print("")
	print("SERVEUR ENET DEMARRE")
	print("Port :", server_port)

	var arena_path := _get_arena_path(game_mode)

	print("Arena choisie :", arena_path)

	var arena_scene := load(arena_path) as PackedScene

	if arena_scene == null:
		push_error("ARENA NETWORK : IMPOSSIBLE DE CHARGER %s" % arena_path)
		get_tree().quit(1)
		return

	var arena := arena_scene.instantiate()
	arena.name = "Arena"
	add_child(arena)

	print("ARENA NETWORK : ARENA CHARGEE")
	print("En attente des joueurs...")
	print("========================================")
	print("")

	# Le serveur ENet écoute et l'arène est chargée : on prévient le
	# matchmaking qu'on est prêt à recevoir les joueurs. Avant ça, le
	# matchmaking déclarait le serveur "online" dès que le PROCESS existait
	# (poll() is None), ce qui pouvait laisser un client tenter de se
	# connecter avant même que Network.host() ait tourné.
	_report_match_event("ready")


func _get_arena_path(mode: String) -> String:
	match mode:
		"1v1":
			return ARENA_1V1

		"labyrinth":
			return ARENA_LABYRINTH

		"default":
			return ARENA_DEFAULT

		_:
			push_warning(
				"Mode inconnu : %s. Map par défaut utilisée." % mode
			)
			return ARENA_DEFAULT


func _parse_arguments() -> void:
	var args := OS.get_cmdline_user_args()

	print("ARGUMENTS GODOT :", args)

	var i := 0

	while i < args.size():
		var arg := str(args[i])

		if arg == "--port" and i + 1 < args.size():
			server_port = int(args[i + 1])
			i += 2
			continue

		if arg == "--match" and i + 1 < args.size():
			match_id = str(args[i + 1])
			i += 2
			continue

		if arg == "--mode" and i + 1 < args.size():
			game_mode = str(args[i + 1]).to_lower()
			i += 2
			continue

		if arg == "--matchmaking-url" and i + 1 < args.size():
			matchmaking_url = str(args[i + 1])
			i += 2
			continue

		i += 1


func _on_peer_arrived(peer_id: int) -> void:
	print("JOUEUR CONNECTE :", peer_id)
	_connected_peers += 1
	_has_had_a_player = true
	# Si une extinction était programmée (dernier joueur parti temporairement)
	# et que quelqu'un revient à temps, on l'annule.
	_shutdown_timer = null
	Network.lobby_register_peer(peer_id)


func _on_peer_left(peer_id: int) -> void:
	print("JOUEUR DECONNECTE :", peer_id)
	_connected_peers = maxi(0, _connected_peers - 1)
	Network.lobby_unregister_peer(peer_id)
	if _has_had_a_player and _connected_peers <= 0:
		print("SERVEUR VIDE : extinction dans %.0fs si personne ne revient." % EMPTY_SERVER_SHUTDOWN_DELAY)
		var timer := get_tree().create_timer(EMPTY_SERVER_SHUTDOWN_DELAY)
		_shutdown_timer = timer
		timer.timeout.connect(func():
			# Le timer capturé peut être devenu obsolète si quelqu'un est
			# revenu entre-temps (un nouveau timer aurait alors été créé,
			# ou _shutdown_timer aurait été remis à null).
			if _shutdown_timer != timer:
				return
			if _connected_peers > 0:
				return
			_shutdown()
		)


## Un joueur n'a pas validé son héros à temps dans le lobby : la partie est
## annulée avant même d'avoir commencé (Network a déjà prévenu les clients
## via la RPC lobby_cancel). Le serveur dédié n'a plus de raison d'exister.
func _on_lobby_cancelled(reason: String) -> void:
	print("LOBBY ANNULÉ :", reason)
	_shutdown()


func _shutdown() -> void:
	print("========================================")
	print("SERVEUR VIDE DEPUIS %.0fs : EXTINCTION." % EMPTY_SERVER_SHUTDOWN_DELAY)
	print("========================================")

	# On prévient le matchmaking AVANT de quitter : la partie est ainsi
	# marquée "finished" immédiatement côté service (au lieu de dépendre
	# uniquement du poll de process, qui reste un filet de sécurité en cas
	# de crash ou de matchmaking injoignable). On laisse un court délai pour
	# la réponse, mais on quitte de toute façon même sans réponse.
	_report_match_event("finished")

	var timeout := get_tree().create_timer(REPORT_TIMEOUT)
	timeout.timeout.connect(_quit_once)

	if _report_http != null:
		_report_http.request_completed.connect(
			func(_result, _code, _headers, _body): _quit_once(),
			CONNECT_ONE_SHOT
		)


func _quit_once() -> void:
	if _quit_called:
		return
	_quit_called = true
	get_tree().quit()


func _report_match_event(event: String) -> void:
	if match_id == "" or _report_http == null:
		return

	var url := matchmaking_url + "/matches/" + match_id + "/report"
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify({"event": event})

	print("MATCHMAKING REPORT : ", event, " -> ", url)

	var error := _report_http.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		push_warning("Impossible de rapporter l'event '%s' au matchmaking : %s" % [event, error])
