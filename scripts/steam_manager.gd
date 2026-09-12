extends Node

const STEAM_APP_ID: int = 480

var steam_id: int = 0
var steam_username: String = ""
var steam_online: bool = false

# Steam party / lobby
var current_lobby_id: int = 0
var party_max_members: int = 0
var pending_party_mode: String = "DEATHMATCH"

var _last_member_count: int = -1

# Signals consommés par le menu et, plus tard, par le matchmaking.
signal party_created(lobby_id: int)
signal party_joined(lobby_id: int)
signal party_members_changed()
signal party_failed(reason: String)


func _init() -> void:
	OS.set_environment("SteamAppId", str(STEAM_APP_ID))
	OS.set_environment("SteamGameId", str(STEAM_APP_ID))


func _ready() -> void:
	if OS.has_feature("dedicated_server"):
		print("SteamManager : mode serveur dédié, Steam désactivé.")
		return

	_initialize_steam()
	_connect_steam_signals()
	_check_launch_lobby_argument()


func _process(_delta: float) -> void:
	if steam_online:
		Steam.run_callbacks()
		_poll_party_members()


func _initialize_steam() -> void:
	var init_result: Dictionary = Steam.steamInitEx()

	print("========================================")
	print("ARENA RIFT - STEAM")
	print("Steam init : ", init_result)
	print("========================================")

	if init_result.get("status", 1) != 0:
		push_error("Steam n'a pas pu être initialisé : %s" % init_result.get("verbal", "Erreur inconnue"))
		return

	steam_online = true
	steam_id = Steam.getSteamID()
	steam_username = Steam.getPersonaName()

	print("Steam connecté !")
	print("Nom : ", steam_username)
	print("SteamID : ", steam_id)
	print("========================================")


func _connect_steam_signals() -> void:
	if not steam_online:
		return

	if Steam.has_signal("lobby_created") and not Steam.lobby_created.is_connected(_on_lobby_created):
		Steam.lobby_created.connect(_on_lobby_created)
	if Steam.has_signal("lobby_joined") and not Steam.lobby_joined.is_connected(_on_lobby_joined):
		Steam.lobby_joined.connect(_on_lobby_joined)
	if Steam.has_signal("join_requested") and not Steam.join_requested.is_connected(_on_join_requested):
		Steam.join_requested.connect(_on_join_requested)
	if Steam.has_signal("lobby_chat_update") and not Steam.lobby_chat_update.is_connected(_on_lobby_chat_update):
		Steam.lobby_chat_update.connect(_on_lobby_chat_update)


func create_party(max_members: int) -> void:
	if not steam_online:
		party_failed.emit("STEAM EST HORS LIGNE")
		return

	if current_lobby_id != 0:
		print("ARENA RIFT : une party Steam existe déjà : ", current_lobby_id)
		return

	party_max_members = clampi(max_members, 1, 6)
	_last_member_count = -1

	print("ARENA RIFT : création de la party Steam, max=", party_max_members)
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, party_max_members)


func _on_lobby_created(result: int, lobby_id: int) -> void:
	print("ARENA RIFT : lobby_created result=", result, " id=", lobby_id)

	if result != 1:
		party_failed.emit("IMPOSSIBLE DE CRÉER LA PARTY STEAM (%s)" % result)
		return

	current_lobby_id = int(lobby_id)

	# Ces données seront utiles au futur matchmaking Kimsufi.
	Steam.setLobbyData(current_lobby_id, "game", "ARENA_RIFT")
	Steam.setLobbyData(current_lobby_id, "mode", pending_party_mode)
	Steam.setLobbyData(current_lobby_id, "host_steam_id", str(steam_id))
	Steam.setLobbyData(current_lobby_id, "host_name", steam_username)
	Steam.setLobbyData(current_lobby_id, "max_members", str(party_max_members))
	Steam.setLobbyJoinable(current_lobby_id, true)

	print("ARENA RIFT : PARTY CRÉÉE : ", current_lobby_id)
	party_created.emit(current_lobby_id)
	party_members_changed.emit()


func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	print("ARENA RIFT : lobby_joined id=", lobby_id, " response=", response)

	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		party_failed.emit("IMPOSSIBLE DE REJOINDRE LA PARTY (%s)" % response)
		return

	current_lobby_id = int(lobby_id)
	pending_party_mode = str(Steam.getLobbyData(current_lobby_id, "mode"))
	party_max_members = int(Steam.getLobbyData(current_lobby_id, "max_members"))
	if party_max_members <= 0:
		party_max_members = max(1, Steam.getNumLobbyMembers(current_lobby_id))

	print("ARENA RIFT : PARTY REJOINTE : ", current_lobby_id)
	party_joined.emit(current_lobby_id)
	party_members_changed.emit()


func _on_join_requested(lobby_id: int, _friend_id: int) -> void:
	print("ARENA RIFT : invitation Steam reçue, lobby=", lobby_id)
	if current_lobby_id == 0:
		Steam.joinLobby(int(lobby_id))


func _check_launch_lobby_argument() -> void:
	var args := OS.get_cmdline_args()
	for i in range(args.size()):
		if args[i] == "+connect_lobby" and i + 1 < args.size():
			var lobby_id := int(args[i + 1])
			if lobby_id > 0:
				print("ARENA RIFT : lancement via invitation Steam, lobby=", lobby_id)
				Steam.joinLobby(lobby_id)
				return


func open_party_invite_overlay() -> void:
	if not steam_online or current_lobby_id == 0:
		party_failed.emit("CRÉE D'ABORD UNE PARTY STEAM")
		return

	print("ARENA RIFT : demande d'ouverture de l'Overlay Steam pour inviter des amis")
	print("ARENA RIFT : lobby à inviter = ", current_lobby_id)

	# L'Overlay Steam peut ne pas être complètement accroché au processus
	# au moment exact du clic. On laisse une frame passer avant l'appel.
	call_deferred("_open_party_invite_overlay_deferred")


func _open_party_invite_overlay_deferred() -> void:
	if not steam_online or current_lobby_id == 0:
		return

	print("ARENA RIFT : tentative d'ouverture de l'Overlay Steam")
	print("ARENA RIFT : lobby=", current_lobby_id)

	if Steam.has_method("activateGameOverlayInviteDialog"):
		print("ARENA RIFT : appel activateGameOverlayInviteDialog()")
		Steam.activateGameOverlayInviteDialog(current_lobby_id)
	else:
		print("ARENA RIFT : activateGameOverlayInviteDialog indisponible")

		if Steam.has_method("activateGameOverlay"):
			print("ARENA RIFT : ouverture du panneau Amis Steam")
			Steam.activateGameOverlay("friends")
		else:
			party_failed.emit("API OVERLAY STEAM INDISPONIBLE")


func leave_party() -> void:
	if current_lobby_id != 0 and steam_online:
		Steam.leaveLobby(current_lobby_id)

	current_lobby_id = 0
	party_max_members = 0
	_last_member_count = -1
	party_members_changed.emit()


func get_party_members() -> Array:
	var members: Array = []
	if not steam_online or current_lobby_id == 0:
		return members

	var count := Steam.getNumLobbyMembers(current_lobby_id)
	for i in range(count):
		var member_id := int(Steam.getLobbyMemberByIndex(current_lobby_id, i))
		if member_id <= 0:
			continue

		var member_name := str(Steam.getFriendPersonaName(member_id))
		members.append({
			"steam_id": member_id,
			"name": member_name if member_name != "" else "STEAM",
			"owner": member_id == int(Steam.getLobbyOwner(current_lobby_id))
		})

	return members


func _poll_party_members() -> void:
	if current_lobby_id == 0:
		return

	var count := Steam.getNumLobbyMembers(current_lobby_id)
	if count != _last_member_count:
		_last_member_count = count
		party_members_changed.emit()


func _on_lobby_chat_update(_lobby_id: int, _changed_user_id: int, _making_change_id: int, _chat_state: int) -> void:
	party_members_changed.emit()
	
func get_party_payload() -> Dictionary:
	var payload: Dictionary = {
		"game": "ARENA_RIFT",
		"lobby_id": str(current_lobby_id),
		"leader_steam_id": str(Steam.getLobbyOwner(current_lobby_id)),
		"mode": pending_party_mode,
		"max_members": party_max_members,
		"members": get_party_members()
	}

	return payload


func is_party_leader() -> bool:
	if not steam_online or current_lobby_id == 0:
		return false

	return int(Steam.getLobbyOwner(current_lobby_id)) == steam_id


func get_party_lobby_id() -> int:
	return current_lobby_id
