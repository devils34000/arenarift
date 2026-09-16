extends CanvasLayer
## Salon Co-op Donjon : entièrement séparé du Custom Game de l'Arena
## (fichier neuf, pas de dépendance à main_menu.gd au-delà du signal de
## fermeture). Créé/affiché par-dessus le menu principal quand on clique
## sur "CO-OP DONJON".
##
## Flux : créer/rejoindre un salon (code partagé) -> chaque joueur choisit
## son perso (visible par les autres) et se marque "prêt" -> l'host ne
## peut lancer que si tout le monde est prêt -> écran de chargement (10s)
## + connexion réseau réelle en parallèle -> ArenaLabyrinth.tscn.

signal closed

const MATCHMAKING_BASE_URL := "http://149.202.91.92:8080"
const HEROES: Array[String] = ["AERIS", "MAYLINH", "KAITHLYN", "EREN"]
const HERO_ACCENTS := {
	"AERIS": Color("5b9bc4"),
	"MAYLINH": Color("4fae7d"),
	"KAITHLYN": Color("c98a3d"),
	"EREN": Color("d9691f"),
}

var _http_action: HTTPRequest
var _http_poll: HTTPRequest
var _poll_timer: Timer

var _room_code: String = ""
var _room_state: Dictionary = {}
var _last_version: int = -1
var _pending_action: String = ""
var _connect_triggered: bool = false
var _my_character: String = ""

var _root: Control
var _content: Control


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS

	_http_action = HTTPRequest.new()
	add_child(_http_action)
	_http_action.request_completed.connect(_on_action_completed)

	_http_poll = HTTPRequest.new()
	add_child(_http_poll)
	_http_poll.request_completed.connect(_on_poll_completed)

	_poll_timer = Timer.new()
	_poll_timer.wait_time = 1.0
	add_child(_poll_timer)
	_poll_timer.timeout.connect(_poll_room)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.015, 0.03, 0.92)
	_root.add_child(dim)

	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_content)

	_show_home()


func _my_steam_id_str() -> String:
	var steam_manager: Node = get_node_or_null("/root/SteamManager")
	if steam_manager == null:
		return ""
	return str(int(steam_manager.get("steam_id")))


func _my_steam_name() -> String:
	var steam_manager: Node = get_node_or_null("/root/SteamManager")
	if steam_manager == null:
		return "Joueur"
	var n: String = str(steam_manager.get("steam_username"))
	return n if n != "" else "Joueur"


func _clear_content() -> void:
	for child in _content.get_children():
		child.queue_free()


func _close() -> void:
	if _room_code != "":
		_leave_room()
	_poll_timer.stop()
	closed.emit()
	queue_free()


# =========================================================
# ÉCRAN D'ACCUEIL (créer / rejoindre)
# =========================================================

func _show_home() -> void:
	_clear_content()

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-220, -160)
	box.custom_minimum_size = Vector2(440, 320)
	box.add_theme_constant_override("separation", 16)
	_content.add_child(box)

	var title := Label.new()
	title.text = "CO-OP DONJON"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var create_btn := Button.new()
	create_btn.text = "CRÉER UN SALON"
	create_btn.custom_minimum_size = Vector2(0, 56)
	create_btn.pressed.connect(_create_room)
	box.add_child(create_btn)

	var sep := Label.new()
	sep.text = "— ou —"
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sep)

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	box.add_child(join_row)

	var code_input := LineEdit.new()
	code_input.placeholder_text = "CODE DU SALON"
	code_input.custom_minimum_size = Vector2(260, 48)
	code_input.max_length = 6
	join_row.add_child(code_input)

	var join_btn := Button.new()
	join_btn.text = "REJOINDRE"
	join_btn.custom_minimum_size = Vector2(150, 48)
	join_btn.pressed.connect(func(): _join_room(code_input.text))
	join_row.add_child(join_btn)

	var status := Label.new()
	status.name = "StatusLabel"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.modulate = Color("e06666")
	box.add_child(status)

	var back_btn := Button.new()
	back_btn.text = "RETOUR"
	back_btn.custom_minimum_size = Vector2(0, 44)
	back_btn.pressed.connect(_close)
	box.add_child(back_btn)

	create_btn.grab_focus()


func _set_home_error(text: String) -> void:
	var status := _content.find_child("StatusLabel", true, false)
	if status is Label:
		(status as Label).text = text


func _create_room() -> void:
	_pending_action = "create"
	var payload := {"steam_id": _my_steam_id_str(), "name": _my_steam_name()}
	_http_action.request(
		MATCHMAKING_BASE_URL + "/rooms",
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)


func _join_room(code: String) -> void:
	var clean := code.strip_edges().to_upper().trim_prefix("DJ-").trim_prefix("DJ")
	if clean.length() < 4:
		_set_home_error("CODE INVALIDE")
		return
	_pending_action = "join"
	var payload := {"steam_id": _my_steam_id_str(), "name": _my_steam_name()}
	_http_action.request(
		MATCHMAKING_BASE_URL + "/rooms/" + clean + "/join",
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)


func _leave_room() -> void:
	if _room_code == "":
		return
	var payload := {"steam_id": _my_steam_id_str()}
	var req := HTTPRequest.new()
	add_child(req)
	req.request(
		MATCHMAKING_BASE_URL + "/rooms/" + _room_code + "/leave",
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	req.request_completed.connect(func(_a, _b, _c, _d): req.queue_free())


func _on_action_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var action := _pending_action
	_pending_action = ""
	var parsed = JSON.parse_string(body.get_string_from_utf8())

	if action == "create" or action == "join":
		if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300 or typeof(parsed) != TYPE_DICTIONARY:
			var detail := ""
			if typeof(parsed) == TYPE_DICTIONARY:
				detail = str((parsed as Dictionary).get("detail", ""))
			_set_home_error(detail if detail != "" else "SALON INTROUVABLE OU SERVEUR INJOIGNABLE")
			return
		_room_state = parsed as Dictionary
		_room_code = str(_room_state.get("code", ""))
		_last_version = int(_room_state.get("version", 0))
		_connect_triggered = false
		if action == "create":
			# Verrouille la map sur le labyrinthe et le mode sur COOP — un
			# salon Co-op Donjon ne doit jamais pouvoir lancer autre chose.
			_apply_settings()
		_poll_timer.start()
		_show_lobby()
		return

	# ready / settings / start
	if typeof(parsed) == TYPE_DICTIONARY and result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		_apply_room_state(parsed as Dictionary)
	elif typeof(parsed) == TYPE_DICTIONARY:
		var detail := str((parsed as Dictionary).get("detail", ""))
		if detail != "":
			_flash_lobby_error(detail)


func _apply_settings() -> void:
	var payload := {"steam_id": _my_steam_id_str(), "map": "labyrinth", "mode": "COOP"}
	var req := HTTPRequest.new()
	add_child(req)
	req.request(
		MATCHMAKING_BASE_URL + "/rooms/" + _room_code + "/settings",
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	req.request_completed.connect(func(_a, _b, _c, _d): req.queue_free())


func _poll_room() -> void:
	if _room_code == "" or _http_poll.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	_http_poll.request(MATCHMAKING_BASE_URL + "/rooms/" + _room_code)


func _on_poll_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _room_code == "" or result != HTTPRequest.RESULT_SUCCESS:
		return
	if response_code == 404:
		_poll_timer.stop()
		_room_code = ""
		_show_home()
		_set_home_error("LE SALON A ÉTÉ FERMÉ")
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_apply_room_state(parsed as Dictionary)


func _apply_room_state(state: Dictionary) -> void:
	var v := int(state.get("version", 0))
	if v < _last_version:
		return
	_last_version = v
	_room_state = state
	_refresh_lobby()
	_check_server_ready()


func _flash_lobby_error(text: String) -> void:
	var status := _content.find_child("LobbyStatusLabel", true, false)
	if status is Label:
		(status as Label).text = text


# =========================================================
# ÉCRAN DE SALON
# =========================================================

func _is_host() -> bool:
	return str(_room_state.get("host_steam_id", "")) == _my_steam_id_str()


func _show_lobby() -> void:
	_clear_content()

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-320, -260)
	box.custom_minimum_size = Vector2(640, 520)
	box.add_theme_constant_override("separation", 14)
	_content.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)

	var code_label := Label.new()
	code_label.text = "SALON  DJ-" + _room_code
	code_label.add_theme_font_size_override("font_size", 26)
	header.add_child(code_label)

	var copy_btn := Button.new()
	copy_btn.text = "COPIER"
	copy_btn.pressed.connect(func(): DisplayServer.clipboard_set("DJ-" + _room_code))
	header.add_child(copy_btn)

	box.add_child(HSeparator.new())

	var players_label := Label.new()
	players_label.text = "JOUEURS"
	box.add_child(players_label)

	var players_list := VBoxContainer.new()
	players_list.name = "PlayersList"
	players_list.add_theme_constant_override("separation", 6)
	box.add_child(players_list)

	box.add_child(HSeparator.new())

	var hero_label := Label.new()
	hero_label.text = "CHOISIS TON PERSONNAGE"
	box.add_child(hero_label)

	var hero_row := HBoxContainer.new()
	hero_row.name = "HeroRow"
	hero_row.add_theme_constant_override("separation", 10)
	box.add_child(hero_row)

	for hero in HEROES:
		var btn := Button.new()
		btn.text = hero
		btn.custom_minimum_size = Vector2(130, 56)
		btn.toggle_mode = true
		btn.pressed.connect(func(): _pick_character(hero))
		hero_row.add_child(btn)

	var actions_row := HBoxContainer.new()
	actions_row.add_theme_constant_override("separation", 12)
	box.add_child(actions_row)

	var ready_btn := Button.new()
	ready_btn.name = "ReadyButton"
	ready_btn.text = "PRÊT"
	ready_btn.toggle_mode = true
	ready_btn.custom_minimum_size = Vector2(160, 56)
	ready_btn.pressed.connect(_toggle_ready)
	actions_row.add_child(ready_btn)

	var launch_btn := Button.new()
	launch_btn.name = "LaunchButton"
	launch_btn.text = "LANCER LA PARTIE"
	launch_btn.custom_minimum_size = Vector2(240, 56)
	launch_btn.pressed.connect(_start_room)
	actions_row.add_child(launch_btn)

	var leave_btn := Button.new()
	leave_btn.text = "QUITTER"
	leave_btn.custom_minimum_size = Vector2(140, 56)
	leave_btn.pressed.connect(_close)
	actions_row.add_child(leave_btn)

	var status := Label.new()
	status.name = "LobbyStatusLabel"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.modulate = Color("e06666")
	box.add_child(status)

	_refresh_lobby()
	ready_btn.grab_focus()


func _pick_character(hero: String) -> void:
	_my_character = hero
	var payload := {"steam_id": _my_steam_id_str(), "character": hero}
	_pending_action = "ready"
	_http_action.request(
		MATCHMAKING_BASE_URL + "/rooms/" + _room_code + "/ready",
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)


func _toggle_ready() -> void:
	var ready_btn := _content.find_child("ReadyButton", true, false) as Button
	var want_ready: bool = ready_btn.button_pressed if ready_btn else true
	if want_ready and _my_character == "":
		_flash_lobby_error("CHOISIS UN PERSONNAGE D'ABORD")
		if ready_btn:
			ready_btn.button_pressed = false
		return
	var payload := {"steam_id": _my_steam_id_str(), "ready": want_ready}
	_pending_action = "ready"
	_http_action.request(
		MATCHMAKING_BASE_URL + "/rooms/" + _room_code + "/ready",
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)


func _start_room() -> void:
	if not _is_host():
		return
	var payload := {"steam_id": _my_steam_id_str()}
	_pending_action = "start"
	_http_action.request(
		MATCHMAKING_BASE_URL + "/rooms/" + _room_code + "/start",
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)


func _refresh_lobby() -> void:
	var players_list := _content.find_child("PlayersList", true, false) as VBoxContainer
	if players_list == null:
		return
	for child in players_list.get_children():
		child.queue_free()

	var members: Array = _room_state.get("members", [])
	var all_ready := members.size() > 0
	for m_val in members:
		var m: Dictionary = m_val
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var name_label := Label.new()
		var is_host_member := str(m.get("steam_id", "")) == str(_room_state.get("host_steam_id", ""))
		name_label.text = str(m.get("name", "?")) + (" (HOST)" if is_host_member else "")
		name_label.custom_minimum_size = Vector2(220, 0)
		row.add_child(name_label)

		var character := str(m.get("character", ""))
		var hero_label := Label.new()
		hero_label.text = character if character != "" else "—"
		hero_label.custom_minimum_size = Vector2(140, 0)
		if character != "" and HERO_ACCENTS.has(character):
			hero_label.modulate = HERO_ACCENTS[character]
		row.add_child(hero_label)

		var ready := bool(m.get("ready", false))
		if not ready:
			all_ready = false
		var ready_label := Label.new()
		ready_label.text = "PRÊT" if ready else "..."
		ready_label.modulate = Color("6fcf6f") if ready else Color("8a7550")
		row.add_child(ready_label)

		players_list.add_child(row)

	var launch_btn := _content.find_child("LaunchButton", true, false) as Button
	if launch_btn:
		launch_btn.visible = _is_host()
		launch_btn.disabled = not all_ready

	var hero_row := _content.find_child("HeroRow", true, false) as HBoxContainer
	if hero_row:
		for child in hero_row.get_children():
			if child is Button:
				(child as Button).button_pressed = (child as Button).text == _my_character


# =========================================================
# LANCEMENT : écran de chargement + connexion réseau réelle
# =========================================================

func _check_server_ready() -> void:
	if _connect_triggered:
		return
	var server = _room_state.get("server", null)
	if typeof(server) != TYPE_DICTIONARY:
		return
	var server_dict: Dictionary = server
	if str(server_dict.get("status", "")) != "online":
		return
	var ip := str(server_dict.get("ip", ""))
	var port := int(server_dict.get("port", 0))
	if ip == "" or port <= 0:
		return

	_connect_triggered = true
	_poll_timer.stop()

	var loading_scene: PackedScene = load("res://scenes/LoadingScreen.tscn")
	var loading: Node = loading_scene.instantiate()
	get_tree().root.add_child(loading)
	loading.call("start_target_scene_after_connect", "res://scenes/ArenaLabyrinth.tscn")

	var network_node: Node = get_node_or_null("/root/Network")
	if network_node != null:
		network_node.set("match_mode", "CUSTOM COOP DUNGEON")
		network_node.set("selected_hero", _my_character)
		if network_node.has_signal("peer_arrived"):
			network_node.connect("peer_arrived", func(_id): loading.call("mark_connected"), CONNECT_ONE_SHOT)
		network_node.call("join", ip, port)

	queue_free()
