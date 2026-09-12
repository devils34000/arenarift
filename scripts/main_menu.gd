extends Control

var selected_mode := "DEATHMATCH"
var selected_hero := "AERIS"
var page := "HOME"
var content: VBoxContainer
var title: Label
var menu_music: AudioStreamPlayer
var nav_buttons: Dictionary = {}
var controller_connected: bool = false
var _last_controller_connected: bool = false

var steam_profile: Panel
var steam_avatar: TextureRect
var steam_avatar_fallback: Label
var steam_name_label: Label
var steam_status_label: Label

var party_panel: Panel
var party_title_label: Label
var party_status_label: Label
var party_members_box: VBoxContainer
var party_invite_button: Button
var party_leave_button: Button

var matchmaking_action_http: HTTPRequest
var matchmaking_poll_http: HTTPRequest
var matchmaking_poll_timer: Timer
var matchmaking_in_progress: bool = false
var matchmaking_ticket_id: String = ""
var matchmaking_connecting: bool = false
# "search" ou "cancel" : dit à _on_matchmaking_action_completed quelle
# requête vient de se terminer, puisque les deux partagent le même noeud
# HTTPRequest.
var matchmaking_pending_action: String = ""
# Le bouton qui déclenche/affiche la recherche (change de texte et de rôle
# en cours de recherche : "RECHERCHER" -> "ANNULER LA RECHERCHE").
var matchmaking_search_button: Button

const MATCHMAKING_BASE_URL := "http://149.202.91.92:8080"

const SETTINGS_PATH := "user://settings.cfg"
const MENU_BG_PATH := "res://assets/menu_art/arena_rift_background.jpg"
const HERO_MODEL_PATHS := {
	"AERIS": "res://assets/kaykit/Mage.glb",
	"MAYLINH": "res://assets/kaykit/Rogue_Hooded.glb",
	"KAITHLYN": "res://assets/kaykit/Barbarian.glb",
	"EREN": "res://assets/kaykit/Knight.glb"
}

var settings := {
	"master_volume": 78.0,
	"music_volume": 64.0,
	"sfx_volume": 64.0,
	"fullscreen": false,
	"vsync": true,
	"screen_shake": true,
	"damage_numbers": true,
	"camera_fov": 65.0,
	"camera_height": 3.2,
	"controller_camera_sensitivity": 2.8,
	"controller_invert_y": false,
	"tutorials": true,
	"ability_hints": true,
	"autosave": true,
	"confirmations": true,
	"indicators": true
}


func _ready() -> void:
	_load_settings()
	_apply_settings()
	_build_shell()
	_setup_steam_profile()
	_connect_party_signals()
	_setup_menu_music()
	_update_controller_connection(true)

	matchmaking_action_http = HTTPRequest.new()
	matchmaking_action_http.name = "MatchmakingActionHTTP"
	add_child(matchmaking_action_http)
	matchmaking_action_http.request_completed.connect(_on_matchmaking_action_completed)

	matchmaking_poll_http = HTTPRequest.new()
	matchmaking_poll_http.name = "MatchmakingPollHTTP"
	add_child(matchmaking_poll_http)
	matchmaking_poll_http.request_completed.connect(_on_matchmaking_poll_completed)

	matchmaking_poll_timer = Timer.new()
	matchmaking_poll_timer.name = "MatchmakingPollTimer"
	matchmaking_poll_timer.wait_time = 1.0
	matchmaking_poll_timer.one_shot = false
	add_child(matchmaking_poll_timer)
	matchmaking_poll_timer.timeout.connect(_poll_matchmaking_status)

	var network_node: Node = get_node_or_null("/root/Network")
	if network_node != null:
		if not network_node.peer_arrived.is_connected(_on_matchmaking_peer_arrived):
			network_node.peer_arrived.connect(_on_matchmaking_peer_arrived)

	_show_home()



func _process(_delta: float) -> void:
	_update_controller_connection()


func _input(event: InputEvent) -> void:
		# Ferme la grande carte Arkanite avec Échap.
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if get_node_or_null("ArkanitePreviewOverlay") != null:
			_close_arkanite_preview()
			get_viewport().set_input_as_handled()
			return
			
			
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_update_controller_connection(true)

		if event is InputEventJoypadButton and event.pressed:
			if event.button_index == JOY_BUTTON_B:
				if page != "HOME":
					_show_home_deferred()
				return

			# Bouton A / bouton sud : valide toujours le contrôle actuellement sélectionné.
			if event.button_index == JOY_BUTTON_A:
				var viewport := get_viewport()
				if viewport == null:
					return

				var focused := viewport.gui_get_focus_owner()
				if focused is BaseButton and focused.is_visible_in_tree() and not focused.disabled:
					# Marquer l'input AVANT le signal : le signal peut changer de scène
					# et supprimer ce menu pendant l'exécution.
					viewport.set_input_as_handled()
					(focused as BaseButton).emit_signal("pressed")


func _update_controller_connection(force: bool = false) -> void:
	controller_connected = not Input.get_connected_joypads().is_empty()
	if not force and controller_connected == _last_controller_connected:
		return
	_last_controller_connected = controller_connected
	if controller_connected:
		print("ARENA RIFT : manette détectée")
		call_deferred("_focus_first_control")
	elif page == "SETTINGS":
		call_deferred("_show_settings")


func _focus_first_control() -> void:
	if not controller_connected:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var current := viewport.gui_get_focus_owner()
	if current != null and is_instance_valid(current) and current.is_visible_in_tree():
		return
	var nav_play := nav_buttons.get("PLAY") as Button
	if page == "HOME" and nav_play != null:
		nav_play.grab_focus()
		return
	var first := _find_first_focusable(content)
	if first != null:
		first.grab_focus()


func _find_first_focusable(root: Node) -> Control:
	for child in root.get_children():
		if child is Control and child.focus_mode != Control.FOCUS_NONE and child.visible:
			return child as Control
		var nested := _find_first_focusable(child)
		if nested != null:
			return nested
	return null


# =========================================================
# SHELL
# =========================================================

func _build_shell() -> void:
	# Grimoire vivant : fond sombre gravé, braises flottantes, cadre en
	# pierre/bronze plutôt que verre. Toute la logique de navigation reste
	# identique, seul l'habillage visuel change.
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_tex := load(MENU_BG_PATH) as Texture2D
	if bg_tex != null:
		bg.texture = bg_tex
	add_child(bg)

	# Vignette sombre façon crypte : assombrit les bords, garde le centre lisible.
	var cinematic_tint := ColorRect.new()
	cinematic_tint.color = Color("07050296")
	cinematic_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cinematic_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cinematic_tint)

	var ember_glow := ColorRect.new()
	ember_glow.color = Color("3a1a0640")
	ember_glow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	ember_glow.position = Vector2(0, 0)
	ember_glow.size.y = 180
	ember_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ember_glow)

	_build_ember_particles()

	var left_rail := Panel.new()
	left_rail.position = Vector2(0, 0)
	left_rail.size = Vector2(244, 720)
	left_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_rail.add_theme_stylebox_override("panel", _box(Color("0d0a07f0"), Color("4a3018"), 0, 1))
	add_child(left_rail)

	# Filet doré vertical qui longe le bord droit du rail, comme une
	# baguette de reliure sur un vieux grimoire.
	var rail_edge := ColorRect.new()
	rail_edge.color = Color("c9a24d")
	rail_edge.position = Vector2(242, 0)
	rail_edge.size = Vector2(2, 720)
	rail_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_rail.add_child(rail_edge)

		# Logo PNG ARENA RIFT dans le rail de navigation.
	var brand := TextureRect.new()
	brand.name = "ArenaRiftLogo"
	brand.position = Vector2(18, 22)
	brand.size = Vector2(208, 96)

	brand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	brand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var logo_texture := load(
		"res://assets/menu_art/logo_arena_rift.png"
	) as Texture2D

	if logo_texture != null:
		brand.texture = logo_texture
	else:
		push_warning(
			"Logo ARENA RIFT introuvable : res://assets/menu_art/logo_arena_rift.png"
		)

	left_rail.add_child(brand)

	var divider := _label("──────────────", 9, Color("4a3018"), Vector2(18, 132), Vector2(208, 16), HORIZONTAL_ALIGNMENT_CENTER)
	left_rail.add_child(divider)

	var nav := VBoxContainer.new()
	nav.position = Vector2(18, 170)
	nav.size = Vector2(208, 220)
	nav.add_theme_constant_override("separation", 9)
	left_rail.add_child(nav)

	for item in ["PLAY", "HEROES", "ARKANITES", "LOADOUT", "SETTINGS"]:
		var b := _aaa_nav_button(item, item == "PLAY")
		nav_buttons[item] = b
		b.pressed.connect(func(): _navigate_deferred(item))
		nav.add_child(b)

	left_rail.add_child(_label("V0.1 · PRÉ-ALPHA\nUNE NOUVELLE ÈRE\nSE LÈVE", 9, Color("6b5a3a"), Vector2(34, 650), Vector2(180, 55)))

	_build_steam_profile()

	# Cadre principal façon pierre gravée : coins asymétriques, filet bronze.
	var frame := Panel.new()
	frame.name = "MainFrame"
	frame.position = Vector2(262, 88)
	frame.size = Vector2(994, 614)
	frame.add_theme_stylebox_override("panel", _rune_box(Color("110c07eb"), Color("6b4a24"), 2))
	add_child(frame)

	title = _label("", 30, Color("f3e6c8"), Vector2(24, 20), Vector2(946, 40), HORIZONTAL_ALIGNMENT_CENTER)
	frame.add_child(title)

	# Séparateur orné : losange central entre deux filets, façon sceau.
	var accent_left := ColorRect.new()
	accent_left.color = Color("c9a24d")
	accent_left.position = Vector2(410, 65)
	accent_left.size = Vector2(58, 1)
	frame.add_child(accent_left)
	var accent_right := ColorRect.new()
	accent_right.color = Color("c9a24d")
	accent_right.position = Vector2(478, 65)
	accent_right.size = Vector2(58, 1)
	frame.add_child(accent_right)
	var accent_mark := _label("◆", 10, Color("e8b656"), Vector2(465, 58), Vector2(16, 16), HORIZONTAL_ALIGNMENT_CENTER)
	frame.add_child(accent_mark)

	content = VBoxContainer.new()
	content.position = Vector2(24, 72)
	content.size = Vector2(946, 525)
	content.add_theme_constant_override("separation", 12)
	frame.add_child(content)


## Braises flottantes en fond de menu : quelques particules ambrées qui
## montent lentement, purement décoratif et non-bloquant (mouse_filter IGNORE).
func _build_ember_particles() -> void:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)

	for i in 22:
		var ember := ColorRect.new()
		var ember_size := randf_range(1.5, 3.5)
		ember.size = Vector2(ember_size, ember_size)
		ember.color = Color("e8a63d").lerp(Color("ff6a32"), randf())
		ember.color.a = randf_range(0.25, 0.65)
		ember.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ember.position = Vector2(randf_range(0, 1280), randf_range(0, 720))
		layer.add_child(ember)

		var tween := create_tween().set_loops()
		var rise_distance := randf_range(80, 220)
		var duration := randf_range(4.0, 9.0)
		tween.tween_property(ember, "position:y", ember.position.y - rise_distance, duration).from(ember.position.y).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(ember, "modulate:a", 0.0, duration).from(1.0)
		tween.tween_callback(func():
			ember.position = Vector2(randf_range(0, 1280), randf_range(600, 720))
			ember.modulate.a = 1.0
		)


func _build_steam_profile() -> void:
	steam_profile = _panel(Vector2(1050, 24), Vector2(206, 62), Color("140f09eb"), Color("6b4a24"), 12)
	steam_profile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(steam_profile)

	var avatar_frame := _panel(Vector2(8, 8), Vector2(45, 45), Color("241a0d"), Color("e8b656"), 12)
	avatar_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	steam_profile.add_child(avatar_frame)

	steam_avatar = TextureRect.new()
	steam_avatar.position = Vector2(1, 1)
	steam_avatar.size = Vector2(43, 43)
	steam_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	steam_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	steam_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_frame.add_child(steam_avatar)

	steam_avatar_fallback = _label("?", 20, Color("e8b656"), Vector2(8, 9), Vector2(28, 25), HORIZONTAL_ALIGNMENT_CENTER)
	steam_avatar_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_frame.add_child(steam_avatar_fallback)

	steam_name_label = _label("STEAM", 12, Color("f3e6c8"), Vector2(64, 8), Vector2(134, 18))
	steam_name_label.clip_text = true
	steam_profile.add_child(steam_name_label)
	steam_status_label = _label("STEAM  •  EN LIGNE", 9, Color("6fb88a"), Vector2(64, 31), Vector2(134, 16))
	steam_profile.add_child(steam_status_label)


func _setup_steam_profile() -> void:
	if steam_profile == null:
		return

	if Steam.has_signal("avatar_loaded") and not Steam.avatar_loaded.is_connected(_on_steam_avatar_loaded):
		Steam.avatar_loaded.connect(_on_steam_avatar_loaded)

	var steam_id: int = 0
	if Steam.has_method("getSteamID"):
		steam_id = int(Steam.getSteamID())

	if steam_id <= 0:
		steam_name_label.text = "STEAM"
		steam_status_label.text = "STEAM  •  HORS LIGNE"
		return

	var persona_name := str(Steam.getPersonaName())
	steam_name_label.text = persona_name if persona_name != "" else "STEAM"

	var persona_state := 1
	if Steam.has_method("getPersonaState"):
		persona_state = int(Steam.getPersonaState())

	var online_text := "EN LIGNE"
	var online_color := Color("6fb88a")
	match persona_state:
		0:
			online_text = "HORS LIGNE"
			online_color = Color("71829a")
		1:
			online_text = "EN LIGNE"
			online_color = Color("6fb88a")
		2:
			online_text = "OCCUPÉ"
			online_color = Color("ff6f7d")
		3, 4:
			online_text = "ABSENT"
			online_color = Color("f0c45a")

	steam_status_label.text = "STEAM  •  " + online_text
	steam_status_label.add_theme_color_override("font_color", online_color)

	var initial := steam_name_label.text.substr(0, 1).to_upper()
	steam_avatar_fallback.text = initial if initial != "" else "?"

	# 2 = avatar moyen (64x64), suffisant pour notre profil 45x45.
	Steam.getPlayerAvatar(2, steam_id)


func _on_steam_avatar_loaded(_avatar_id: int, size: int, data: Array) -> void:
	if steam_avatar == null or not is_instance_valid(steam_avatar):
		return
	if size <= 0 or data.is_empty():
		return

	var pixels := PackedByteArray(data)
	var expected_size := size * size * 4
	if pixels.size() < expected_size:
		return

	var image := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, pixels)
	if image == null or image.is_empty():
		return

	steam_avatar.texture = ImageTexture.create_from_image(image)
	steam_avatar_fallback.visible = false


# =========================================================
# NAVIGATION
# =========================================================

func _navigate(item: String) -> void:
	page = item
	_set_nav_active(item)
	if item == "PLAY":
		_show_home()
	elif item == "SETTINGS":
		_show_settings()
	elif item == "HEROES":
		_show_heroes()
	elif item == "ARKANITES":
		_show_arkanites()
	else:
		_show_placeholder(item)
	call_deferred("_focus_first_control")


func _set_nav_active(active_item: String) -> void:
	for item in nav_buttons.keys():
		var b := nav_buttons[item] as Button
		if b == null:
			continue
		var active: bool = (item == active_item)
		b.text = ("◆  " if active else "    ") + item
		b.add_theme_color_override("font_color", Color("f3e2b8") if active else Color("7a6a4a"))
		b.add_theme_stylebox_override("normal", _rune_box(Color("241a0d") if active else Color("140f09"), Color("c9a24d") if active else Color("352818"), 1))


# =========================================================
# HOME
# =========================================================

func _show_home() -> void:
	_clear()
	title.text = "PLAY"

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)
	content.add_child(row)

	var modes_box := VBoxContainer.new()
	modes_box.custom_minimum_size = Vector2(600, 0)
	modes_box.add_theme_constant_override("separation", 10)
	row.add_child(modes_box)
	modes_box.add_child(_label("SELECT MODE", 11, Color("8a7550"), Vector2.ZERO, Vector2(500, 22)))

	for mode in ["DEATHMATCH", "1V1 DUEL", "2V2 CLASH", "3V3 RIVALRY"]:
		var selected: bool = (mode == selected_mode)
		var card := _mode_card(mode, selected)
		card.pressed.connect(func():
			selected_mode = mode
			_show_home_deferred()
		)
		modes_box.add_child(card)

	var side := _panel(Vector2.ZERO, Vector2(290, 360), Color("1a140b"), Color("4a3018"), 14)
	side.custom_minimum_size = Vector2(290, 360)
	row.add_child(side)
	var hero_accent := _hero_accent(selected_hero)
	side.add_child(_label("READY", 10, Color("6fb88a"), Vector2(18, 16), Vector2(90, 18)))
	side.add_child(_label(selected_hero, 25, hero_accent, Vector2(18, 43), Vector2(250, 34)))
	side.add_child(_label(_hero_role(selected_hero), 10, Color("8a7a5a"), Vector2(20, 79), Vector2(250, 18)))
	var portrait := TextureRect.new()
	portrait.position = Vector2(150, 105)
	portrait.size = Vector2(120, 150)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait_path := _hero_art(selected_hero)
	if portrait_path != "":
		var image := Image.new()
		if image.load(portrait_path) == OK:
			portrait.texture = ImageTexture.create_from_image(image)
	side.add_child(portrait)
	side.add_child(_label("CURRENT LOADOUT", 9, Color("7a6a4a"), Vector2(18, 245), Vector2(150, 18)))
	side.add_child(_label(_hero_spells(selected_hero), 10, Color("c4b394"), Vector2(18, 270), Vector2(250, 42)))

	var launch := _button("CRÉER LA PARTY", Vector2(280, 48), true)
	launch.position = Vector2(18, 310)
	launch.size = Vector2(254, 40)
	launch.pressed.connect(_create_party)
	side.add_child(launch)

	content.add_child(_label("MODE ACTIF  •  %s     |     LOCAL / PRACTICE" % selected_mode, 10, Color("6b5a3a"), Vector2.ZERO, Vector2(850, 20)))


# =========================================================
# STEAM PARTY
# =========================================================

func _create_party() -> void:
	var steam_manager: Node = get_node_or_null("/root/SteamManager")
	if steam_manager == null:
		push_error("Autoload 'SteamManager' introuvable.")
		return

	# Une party existe déjà : on retourne simplement à son écran.
	if int(steam_manager.get("current_lobby_id")) != 0:
		_show_party()
		return

	var max_members := 1
	match selected_mode:
		"2V2 CLASH":
			max_members = 2
		"3V3 RIVALRY":
			max_members = 3
		"1V1 DUEL":
			max_members = 1
		_:
			max_members = 4

	steam_manager.set("pending_party_mode", selected_mode)
	steam_manager.create_party(max_members)


func _connect_party_signals() -> void:
	var steam_manager: Node = get_node_or_null("/root/SteamManager")
	if steam_manager == null:
		return

	if steam_manager.has_signal("party_created") and not steam_manager.party_created.is_connected(_on_party_created):
		steam_manager.party_created.connect(_on_party_created)
	if steam_manager.has_signal("party_joined") and not steam_manager.party_joined.is_connected(_on_party_joined):
		steam_manager.party_joined.connect(_on_party_joined)
	if steam_manager.has_signal("party_members_changed") and not steam_manager.party_members_changed.is_connected(_on_party_members_changed):
		steam_manager.party_members_changed.connect(_on_party_members_changed)
	if steam_manager.has_signal("party_failed") and not steam_manager.party_failed.is_connected(_on_party_failed):
		steam_manager.party_failed.connect(_on_party_failed)


func _on_party_created(_lobby_id: int) -> void:
	_show_party()


func _on_party_joined(_lobby_id: int) -> void:
	_show_party()


func _on_party_members_changed() -> void:
	if party_members_box != null and is_instance_valid(party_members_box):
		_refresh_party_members()


func _on_party_failed(reason: String) -> void:
	if party_status_label != null and is_instance_valid(party_status_label):
		party_status_label.text = reason


func _show_party() -> void:
	_clear()
	title.text = "PARTY"

	var steam_manager: Node = get_node_or_null("/root/SteamManager")
	if steam_manager == null:
		content.add_child(_label("STEAM MANAGER INTROUVABLE", 18, Color("ff6f7d")))
		return

	var wrapper := VBoxContainer.new()
	wrapper.custom_minimum_size = Vector2(946, 520)
	wrapper.add_theme_constant_override("separation", 12)
	content.add_child(wrapper)

	party_panel = _panel(Vector2.ZERO, Vector2(946, 470), Color("140f09eb"), Color("6b4a24"), 16)
	party_panel.custom_minimum_size = Vector2(946, 470)
	wrapper.add_child(party_panel)

	party_title_label = _label("PARTY STEAM", 22, Color("f3e6c8"), Vector2(24, 20), Vector2(430, 32))
	party_panel.add_child(party_title_label)

	party_status_label = _label("Création de la party...", 10, Color("6fb88a"), Vector2(24, 55), Vector2(600, 20))
	party_panel.add_child(party_status_label)

	party_panel.add_child(_label("MODE", 9, Color("7a6a4a"), Vector2(24, 105), Vector2(100, 18)))
	party_panel.add_child(_label(selected_mode, 17, _mode_accent(selected_mode), Vector2(24, 126), Vector2(300, 28)))

	party_panel.add_child(_label("MEMBRES", 9, Color("7a6a4a"), Vector2(24, 185), Vector2(150, 18)))

	party_members_box = VBoxContainer.new()
	party_members_box.position = Vector2(24, 212)
	party_members_box.size = Vector2(580, 190)
	party_members_box.add_theme_constant_override("separation", 8)
	party_panel.add_child(party_members_box)

	# Invitation Steam pour les parties en équipe.
	if selected_mode == "1V1 DUEL":
		party_invite_button = _button("LANCER LE DUEL", Vector2(230, 48), true)
		party_invite_button.position = Vector2(650, 205)
		matchmaking_search_button = party_invite_button
	else:
		party_invite_button = _button("INVITER DES AMIS", Vector2(230, 48), true)
		party_invite_button.position = Vector2(650, 205)
		party_invite_button.pressed.connect(_invite_party_members)

	party_panel.add_child(party_invite_button)

	if selected_mode != "1V1 DUEL":
		matchmaking_search_button = _button("RECHERCHER UN MATCH", Vector2(230, 48), true)
		matchmaking_search_button.position = Vector2(650, 265)
		party_panel.add_child(matchmaking_search_button)

	_update_search_button_ui(matchmaking_in_progress)

	party_leave_button = _button("QUITTER LA PARTY", Vector2(230, 42), false)
	party_leave_button.position = Vector2(650, 325)
	party_leave_button.pressed.connect(_leave_party)
	party_panel.add_child(party_leave_button)

	if selected_mode == "1V1 DUEL":
		party_panel.add_child(_label(
			"Le matchmaking Kimsufi cherchera automatiquement un adversaire.",
			10,
			Color("8a7550"),
			Vector2(650, 290),
			Vector2(250, 70)
		))
	else:
		party_panel.add_child(_label(
			"Invite tes amis via Steam puis lance la recherche de match.",
			10,
			Color("8a7550"),
			Vector2(650, 380),
			Vector2(250, 55)
		))

	_refresh_party_members()


func _refresh_party_members() -> void:
	if party_members_box == null or not is_instance_valid(party_members_box):
		return

	for child in party_members_box.get_children():
		child.queue_free()

	var steam_manager: Node = get_node_or_null("/root/SteamManager")
	if steam_manager == null:
		return

	var members: Array = steam_manager.get_party_members()
	var max_members := int(steam_manager.get("party_max_members"))

	if party_status_label != null and is_instance_valid(party_status_label):
		party_status_label.text = "%d / %d JOUEURS  •  STEAM" % [members.size(), max_members]

	for member in members:
		var row := _panel(Vector2.ZERO, Vector2(560, 42), Color("1a140b"), Color("4a3018"), 8)
		row.custom_minimum_size = Vector2(560, 42)
		party_members_box.add_child(row)

		var name_label := _label(
			str(member.get("name", "STEAM")),
			12,
			Color("f3e6c8"),
			Vector2(14, 8),
			Vector2(390, 20)
		)
		row.add_child(name_label)

		var role_text := "CHEF" if bool(member.get("owner", false)) else "MEMBRE"

		row.add_child(_label(
			role_text,
			9,
			Color("6fb88a") if role_text == "CHEF" else Color("8a7a5a"),
			Vector2(450, 10),
			Vector2(90, 18),
			HORIZONTAL_ALIGNMENT_RIGHT
		))

	for i in range(members.size(), max_members):
		var empty_row := _panel(
			Vector2.ZERO,
			Vector2(560, 42),
			Color("0d0a06"),
			Color("352818"),
			8
		)
		empty_row.custom_minimum_size = Vector2(560, 42)
		party_members_box.add_child(empty_row)

		empty_row.add_child(_label(
			"SLOT LIBRE",
			10,
			Color("4a3a28"),
			Vector2(14, 10),
			Vector2(520, 18)
		))
		
func _launch_party_match() -> void:
	if selected_mode != "1V1 DUEL":
		return

	var network_node: Node = get_node_or_null("/root/Network")
	if network_node != null:
		network_node.set("match_mode", selected_mode)

	print("ARENA RIFT : lancement du matchmaking 1V1")

	
func _start_matchmaking() -> void:
	var steam_manager: Node = get_node_or_null("/root/SteamManager")
	if steam_manager == null:
		push_error("Autoload 'SteamManager' introuvable.")
		return

	if matchmaking_action_http == null:
		push_error("HTTPRequest de matchmaking introuvable.")
		return

	if matchmaking_in_progress or matchmaking_connecting:
		return

	if not bool(steam_manager.get("steam_online")):
		_set_matchmaking_status("STEAM HORS LIGNE")
		return

	var lobby_id := int(steam_manager.get("current_lobby_id"))
	if lobby_id == 0:
		_set_matchmaking_status("CRÉE D'ABORD UNE PARTY")
		return

	if not bool(steam_manager.call("is_party_leader")):
		_set_matchmaking_status("EN ATTENTE DU LEADER")
		return

	matchmaking_in_progress = true
	matchmaking_connecting = false
	matchmaking_ticket_id = ""

	if matchmaking_poll_timer != null:
		matchmaking_poll_timer.stop()

	var network_node: Node = get_node_or_null("/root/Network")
	if network_node != null:
		network_node.set("match_mode", selected_mode)
		network_node.set("selected_hero", selected_hero)

	var payload: Dictionary = steam_manager.call("get_party_payload")
	var json_body := JSON.stringify(payload)
	var headers := PackedStringArray(["Content-Type: application/json"])

	print("========================================")
	print("ARENA RIFT : ENVOI MATCHMAKING")
	print("LOBBY : ", lobby_id)
	print("PAYLOAD : ", json_body)
	print("========================================")

	_set_matchmaking_status("RECHERCHE D'UN MATCH...")
	_update_search_button_ui(true)

	matchmaking_pending_action = "search"
	var error := matchmaking_action_http.request(
		MATCHMAKING_BASE_URL + "/matchmake",
		headers,
		HTTPClient.METHOD_POST,
		json_body
	)

	if error != OK:
		matchmaking_in_progress = false
		matchmaking_pending_action = ""
		_update_search_button_ui(false)
		_set_matchmaking_status("ERREUR MATCHMAKING : %s" % error)
		push_error("Impossible d'envoyer la requête matchmaking : %s" % error)


## Annule une recherche en cours. Peut être appelée par le bouton
## "ANNULER LA RECHERCHE" ou automatiquement en quittant la party. Ne laisse
## jamais le joueur bloqué : l'état repasse "idle" même si le serveur de
## matchmaking ne répond pas.
func _cancel_matchmaking() -> void:
	if matchmaking_connecting:
		# Le serveur de jeu est déjà en train d'être rejoint : trop tard
		# pour annuler proprement.
		return
	if not matchmaking_in_progress:
		return

	if matchmaking_poll_timer != null:
		matchmaking_poll_timer.stop()

	_set_matchmaking_status("ANNULATION DE LA RECHERCHE...")

	if matchmaking_ticket_id == "" or matchmaking_action_http == null:
		# Aucun ticket confirmé par le serveur pour l'instant (requête
		# initiale toujours en vol) : on annule simplement côté client.
		matchmaking_in_progress = false
		matchmaking_ticket_id = ""
		_update_search_button_ui(false)
		_set_matchmaking_status("RECHERCHE ANNULÉE")
		return

	matchmaking_pending_action = "cancel"
	var error := matchmaking_action_http.request(
		MATCHMAKING_BASE_URL + "/matchmaking/ticket/" + matchmaking_ticket_id + "/cancel",
		PackedStringArray(),
		HTTPClient.METHOD_POST
	)

	if error != OK:
		matchmaking_pending_action = ""
		matchmaking_in_progress = false
		matchmaking_ticket_id = ""
		_update_search_button_ui(false)
		_set_matchmaking_status("RECHERCHE ANNULÉE (LOCAL)")


func _on_matchmaking_action_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var action := matchmaking_pending_action
	matchmaking_pending_action = ""
	var response_text := body.get_string_from_utf8()

	print("========================================")
	print("ARENA RIFT : RÉPONSE MATCHMAKING (%s)" % action)
	print("RESULT : ", result)
	print("HTTP : ", response_code)
	print("BODY : ", response_text)
	print("========================================")

	if action == "cancel":
		# Que le serveur confirme ou non, on ne laisse jamais le joueur
		# bloqué : l'état local repasse "idle" dans tous les cas.
		matchmaking_in_progress = false
		matchmaking_ticket_id = ""
		_update_search_button_ui(false)
		_set_matchmaking_status("RECHERCHE ANNULÉE")
		return

	# action == "search"
	if result != HTTPRequest.RESULT_SUCCESS:
		matchmaking_in_progress = false
		if matchmaking_poll_timer != null:
			matchmaking_poll_timer.stop()
		_update_search_button_ui(false)
		_set_matchmaking_status("SERVEUR MATCHMAKING INJOIGNABLE")
		return

	if response_code < 200 or response_code >= 300:
		matchmaking_in_progress = false
		if matchmaking_poll_timer != null:
			matchmaking_poll_timer.stop()
		_update_search_button_ui(false)
		_set_matchmaking_status("SERVEUR MATCHMAKING : ERREUR %s" % response_code)
		return

	var parsed = JSON.parse_string(response_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		matchmaking_in_progress = false
		if matchmaking_poll_timer != null:
			matchmaking_poll_timer.stop()
		_update_search_button_ui(false)
		_set_matchmaking_status("RÉPONSE SERVEUR INVALIDE")
		return

	_handle_matchmaking_response(parsed as Dictionary)


func _on_matchmaking_poll_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if not matchmaking_in_progress or matchmaking_connecting:
		return

	if result != HTTPRequest.RESULT_SUCCESS:
		# Coupure réseau ponctuelle : on retente au prochain tick plutôt
		# que d'abandonner immédiatement.
		print("ARENA RIFT : POLL MATCHMAKING INJOIGNABLE, NOUVELLE TENTATIVE...")
		return

	if response_code == 404:
		# Le ticket n'existe plus côté serveur (redémarrage du service,
		# purge...) : plutôt que de laisser le joueur planté à interroger
		# un ticket mort indéfiniment, on relance une recherche fraîche.
		print("ARENA RIFT : TICKET INTROUVABLE, NOUVELLE RECHERCHE.")
		matchmaking_in_progress = false
		matchmaking_ticket_id = ""
		if matchmaking_poll_timer != null:
			matchmaking_poll_timer.stop()
		_start_matchmaking()
		return

	if response_code < 200 or response_code >= 300:
		return

	var response_text := body.get_string_from_utf8()
	var parsed = JSON.parse_string(response_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	_handle_matchmaking_response(parsed as Dictionary)


func _handle_matchmaking_response(response: Dictionary) -> void:
	var status := str(response.get("status", "unknown"))
	var ticket_id := str(response.get("ticket_id", ""))
	if ticket_id != "":
		matchmaking_ticket_id = ticket_id

	print("MATCHMAKING STATUS : ", status)

	if status == "searching":
		matchmaking_in_progress = true
		matchmaking_connecting = false
		_update_search_button_ui(true)

		var position := int(response.get("position", 0))
		if position > 0:
			_set_matchmaking_status("RECHERCHE D'UN MATCH • POSITION %d" % position)
		else:
			_set_matchmaking_status("RECHERCHE D'UN MATCH...")

		_start_matchmaking_poll()
		return

	if status == "matched":
		matchmaking_in_progress = true
		_update_search_button_ui(true)

		var match_id := str(response.get("match_id", ""))
		var server_data = response.get("server", null)

		print("########################################")
		print("MATCH TROUVÉ")
		print("MATCH ID : ", match_id)
		print("SERVER   : ", server_data)
		print("########################################")

		if typeof(server_data) != TYPE_DICTIONARY:
			_set_matchmaking_status("MATCH TROUVÉ • SERVEUR EN PRÉPARATION...")
			_start_matchmaking_poll()
			return

		var server: Dictionary = server_data
		var server_status := str(server.get("status", ""))
		var server_ip := str(server.get("ip", ""))
		var server_port := int(server.get("port", 0))

		print("SERVEUR STATUS : ", server_status)
		print("SERVEUR IP     : ", server_ip)
		print("SERVEUR PORT   : ", server_port)

		if server_ip == "" or server_port <= 0:
			_set_matchmaking_status("SERVEUR EN PRÉPARATION...")
			_start_matchmaking_poll()
			return

		if server_status != "online":
			_set_matchmaking_status("SERVEUR EN DÉMARRAGE...")
			_start_matchmaking_poll()
			return

		_connect_to_game_server(server_ip, server_port, match_id)
		return

	if status == "cancelled":
		matchmaking_in_progress = false
		matchmaking_ticket_id = ""
		if matchmaking_poll_timer != null:
			matchmaking_poll_timer.stop()
		_update_search_button_ui(false)
		_set_matchmaking_status("RECHERCHE ANNULÉE")
		return

	if status == "expired":
		# Recherche jamais aboutie, expirée côté serveur : on relance
		# automatiquement une recherche fraîche plutôt que de laisser le
		# joueur planté sur un message d'erreur.
		matchmaking_in_progress = false
		matchmaking_ticket_id = ""
		if matchmaking_poll_timer != null:
			matchmaking_poll_timer.stop()
		_start_matchmaking()
		return

	# Statut inattendu : on ne laisse jamais le joueur bloqué, l'état
	# repasse "idle" et il peut relancer une recherche manuellement.
	matchmaking_in_progress = false
	matchmaking_ticket_id = ""
	if matchmaking_poll_timer != null:
		matchmaking_poll_timer.stop()
	_update_search_button_ui(false)
	_set_matchmaking_status("MATCHMAKING : %s" % status.to_upper())


func _poll_matchmaking_status() -> void:
	if not matchmaking_in_progress or matchmaking_connecting:
		if matchmaking_poll_timer != null:
			matchmaking_poll_timer.stop()
		return

	if matchmaking_ticket_id == "":
		return

	if matchmaking_poll_http == null:
		return

	if matchmaking_poll_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return

	var url := MATCHMAKING_BASE_URL + "/matchmaking/ticket/" + matchmaking_ticket_id
	print("MATCHMAKING POLL : ", url)

	var error := matchmaking_poll_http.request(
		url,
		PackedStringArray(),
		HTTPClient.METHOD_GET
	)

	if error != OK:
		print("ERREUR POLLING MATCHMAKING : ", error)


func _start_matchmaking_poll() -> void:
	if matchmaking_poll_timer != null and matchmaking_poll_timer.is_stopped():
		matchmaking_poll_timer.start()


func _connect_to_game_server(ip: String, port: int, match_id: String) -> void:
	if matchmaking_connecting:
		return

	matchmaking_connecting = true
	matchmaking_in_progress = false
	_update_search_button_ui(true)

	if matchmaking_poll_timer != null:
		matchmaking_poll_timer.stop()

	var network_node: Node = get_node_or_null("/root/Network")
	if network_node == null:
		matchmaking_connecting = false
		_update_search_button_ui(false)
		_set_matchmaking_status("ERREUR : NETWORK INTROUVABLE")
		push_error("Autoload 'Network' introuvable.")
		return

	network_node.set("match_mode", selected_mode)
	network_node.set("selected_hero", selected_hero)

	_set_matchmaking_status("CONNEXION AU SERVEUR...")

	print("========================================")
	print("ARENA RIFT : CONNEXION SERVEUR")
	print("MATCH : ", match_id)
	print("IP    : ", ip)
	print("PORT  : ", port)
	print("========================================")

	var join_result = network_node.call("join", ip, port)
	print("NETWORK JOIN RESULT : ", join_result)

	if join_result != OK:
		matchmaking_connecting = false
		_update_search_button_ui(false)
		_set_matchmaking_status("CONNEXION SERVEUR ÉCHOUÉE")


func _on_matchmaking_peer_arrived(peer_id: int) -> void:
	if not matchmaking_connecting:
		return

	print("========================================")
	print("ARENA RIFT : SERVEUR JOINT")
	print("PEER SERVEUR : ", peer_id)
	print("========================================")

	matchmaking_connecting = false
	matchmaking_in_progress = false
	matchmaking_ticket_id = ""
	_update_search_button_ui(false)
	_set_matchmaking_status("MATCH TROUVÉ • CONNEXION OK")

	call_deferred("_launch")


## Bascule le bouton de recherche entre son rôle "RECHERCHER" (idle) et
## "ANNULER LA RECHERCHE" (recherche en cours) — comme Valorant/Rocket
## League : un seul bouton, deux rôles selon l'état.
func _update_search_button_ui(searching: bool) -> void:
	if matchmaking_search_button == null or not is_instance_valid(matchmaking_search_button):
		return

	if matchmaking_search_button.pressed.is_connected(_start_matchmaking):
		matchmaking_search_button.pressed.disconnect(_start_matchmaking)
	if matchmaking_search_button.pressed.is_connected(_cancel_matchmaking):
		matchmaking_search_button.pressed.disconnect(_cancel_matchmaking)

	if searching:
		matchmaking_search_button.text = "ANNULER LA RECHERCHE"
		matchmaking_search_button.pressed.connect(_cancel_matchmaking)
	else:
		matchmaking_search_button.text = "LANCER LE DUEL" if selected_mode == "1V1 DUEL" else "RECHERCHER UN MATCH"
		matchmaking_search_button.pressed.connect(_start_matchmaking)

	# Une fois la connexion au serveur de jeu commencée, il est trop tard
	# pour annuler : le bouton est désactivé plutôt que de proposer une
	# annulation qui ne servirait plus à rien.
	matchmaking_search_button.disabled = matchmaking_connecting


func _set_matchmaking_status(text: String) -> void:
	if party_status_label != null and is_instance_valid(party_status_label):
		party_status_label.text = text


func _invite_party_members() -> void:
	var steam_manager: Node = get_node_or_null("/root/SteamManager")
	if steam_manager != null:
		steam_manager.open_party_invite_overlay()


func _leave_party() -> void:
	# Si une recherche est en cours, on prévient le matchmaking avant de
	# quitter : sans ça, le ticket restait actif côté serveur (jusqu'à
	# expiration) alors que le joueur n'est plus dans l'écran party pour
	# le voir ou l'annuler lui-même.
	if matchmaking_in_progress and not matchmaking_connecting:
		_cancel_matchmaking()

	var steam_manager: Node = get_node_or_null("/root/SteamManager")
	if steam_manager != null:
		steam_manager.leave_party()
	_show_home_deferred()


func _mode_accent(mode: String) -> Color:
	match mode:
		"1V1 DUEL":
			return Color("a875c9")
		"2V2 CLASH":
			return Color("4fae7d")
		"3V3 RIVALRY":
			return Color("d9691f")
		_:
			return Color("c9a24d")


# =========================================================
# HEROES
# =========================================================

func _show_heroes() -> void:
	_clear()
	title.text = "HEROES"

	var subtitle := _label("CHOISISSEZ VOTRE CHAMPION", 10, Color("b8935a"), Vector2(0, 44), Vector2(946, 22), HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(subtitle)

	var main_row := HBoxContainer.new()
	main_row.position = Vector2(0, 68)
	main_row.size = Vector2(946, 438)
	main_row.add_theme_constant_override("separation", 12)
	content.add_child(main_row)

	var cards := HBoxContainer.new()
	cards.custom_minimum_size = Vector2(642, 438)
	cards.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cards.add_theme_constant_override("separation", 6)
	main_row.add_child(cards)

	cards.add_child(_hero_card("AERIS", "ARCANE SKIRMISHER", "DPS / BURST", Color("5b9bc4"), "ARC BOLT • TELEPORT • PHASE DASH"))
	cards.add_child(_hero_card("MAYLINH", "MYSTIC WARDEN", "HEALER / CONTROLLER", Color("4fae7d"), "ÉCLAT • SOIN • FUITE"))
	cards.add_child(_hero_card("KAITHLYN", "BARBARIAN", "BERSERKER / CONTROLLER", Color("c98a3d"), "HACHE • BOUCLIER • CHARGE"))
	cards.add_child(_hero_card("EREN", "CHEVALIER DE FEU", "FIRE BURST / CONTROLLER", Color("d9691f"), "BOULE DE FEU • NOVA • CHARGE"))

	main_row.add_child(_hero_detail_panel(selected_hero))

	content.add_child(_label("SÉLECTION  •  %s" % selected_hero, 12, _hero_accent(selected_hero), Vector2(0, 516), Vector2(946, 22), HORIZONTAL_ALIGNMENT_CENTER))
	content.add_child(_label(_hero_description(selected_hero), 9, Color("9a8760"), Vector2(0, 541), Vector2(946, 25), HORIZONTAL_ALIGNMENT_CENTER))


func _hero_card(hero_name: String, subtitle: String, role: String, accent: Color, spells: String) -> Panel:
	var card := _panel(Vector2.ZERO, Vector2(156, 438), Color("140f09eb"), Color("4a3018"), 13)
	card.custom_minimum_size = Vector2(156, 438)
	if hero_name == selected_hero:
		card.add_theme_stylebox_override("panel", _box(Color("2c2010f2"), accent, 13, 2))

	var preview := _hero_3d_preview(hero_name, Vector2(148, 238), Vector2(4, 4), false)
	card.add_child(preview)

	# L'artwork contient déjà son propre badge (i). On conserve uniquement
	# une zone de clic invisible par-dessus afin d'éviter un double "i".
	var info_hitbox := Button.new()
	info_hitbox.position = Vector2(120, 13)
	info_hitbox.size = Vector2(27, 27)
	info_hitbox.flat = true
	info_hitbox.focus_mode = Control.FOCUS_NONE
	info_hitbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	info_hitbox.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	info_hitbox.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	info_hitbox.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	info_hitbox.pressed.connect(func():
		selected_hero = hero_name
		_show_heroes_deferred()
	)
	card.add_child(info_hitbox)

	card.add_child(_label(hero_name, 18, accent, Vector2(8, 246), Vector2(140, 24), HORIZONTAL_ALIGNMENT_CENTER))
	card.add_child(_label(subtitle, 8, Color("d4c4a0"), Vector2(8, 270), Vector2(140, 17), HORIZONTAL_ALIGNMENT_CENTER))
	card.add_child(_label(role, 8, Color("9a8760"), Vector2(8, 291), Vector2(140, 17), HORIZONTAL_ALIGNMENT_CENTER))

	var spell_icons := HBoxContainer.new()
	spell_icons.position = Vector2(25, 318)
	spell_icons.size = Vector2(106, 32)
	spell_icons.add_theme_constant_override("separation", 5)
	for path in _hero_spell_icon_paths(hero_name):
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load(path) as Texture2D
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spell_icons.add_child(icon)
	card.add_child(spell_icons)

	var button := _button("SÉLECTIONNÉ" if hero_name == selected_hero else "CHOISIR", Vector2(136, 31), hero_name == selected_hero)
	button.position = Vector2(10, 397)
	button.size = Vector2(136, 31)
	button.pressed.connect(func():
		selected_hero = hero_name
		_show_heroes_deferred()
	)
	card.add_child(button)
	return card


func _hero_3d_preview(hero_name: String, viewport_size: Vector2, pos: Vector2, large: bool) -> TextureRect:
	var preview := TextureRect.new()
	preview.position = pos
	preview.size = viewport_size
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_path := _hero_art(hero_name)
	if art_path != "":
		preview.texture = load(art_path) as Texture2D
	return preview


func _add_menu_kaithlyn_weapons(root: Node3D) -> void:
	var axe_scene := load("res://assets/kaykit/axe_1handed.gltf") as PackedScene
	if axe_scene != null:
		var axe := axe_scene.instantiate() as Node3D
		if axe != null:
			axe.scale = Vector3.ONE * 1.15
			axe.position = Vector3(0.58, 0.55, -0.02)
			axe.rotation_degrees = Vector3(8, 0, -22)
			root.add_child(axe)
	var shield_scene := load("res://assets/kaykit/shield_round_barbarian.gltf") as PackedScene
	if shield_scene != null:
		var shield := shield_scene.instantiate() as Node3D
		if shield != null:
			shield.scale = Vector3.ONE * 1.05
			shield.position = Vector3(-0.5, 0.48, 0.02)
			shield.rotation_degrees = Vector3(8, 0, 14)
			root.add_child(shield)


func _hero_detail_panel(hero_name: String) -> Panel:
	var panel := _panel(Vector2.ZERO, Vector2(292, 438), Color("110c07eb"), Color("6b4a24"), 15)
	panel.custom_minimum_size = Vector2(292, 438)
	panel.clip_contents = true
	var accent := _hero_accent(hero_name)

	panel.add_child(_label(hero_name, 24, accent, Vector2(18, 14), Vector2(205, 31)))
	panel.add_child(_label(_hero_role(hero_name), 8, Color("9a8760"), Vector2(19, 42), Vector2(255, 18)))
	var info := _panel(Vector2(247, 13), Vector2(34, 34), Color("241a0d"), accent, 17)
	panel.add_child(info)
	info.add_child(_label("i", 17, Color("f3e6c8"), Vector2(0, 6), Vector2(34, 22), HORIZONTAL_ALIGNMENT_CENTER))

	var description := _label(_hero_description(hero_name), 8, Color("c4b394"), Vector2(18, 67), Vector2(255, 52))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.clip_text = true
	panel.add_child(description)

	var spells := _hero_spell_details(hero_name)
	var y := 126
	for spell in spells:
		var icon := TextureRect.new()
		icon.position = Vector2(18, y)
		icon.size = Vector2(36, 36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load(spell[2]) as Texture2D
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
		var spell_name := _label(spell[0], 9, accent, Vector2(64, y), Vector2(138, 17))
		spell_name.clip_text = true
		panel.add_child(spell_name)
		var spell_desc := _label(spell[1], 7, Color("8a7a5a"), Vector2(64, y + 17), Vector2(135, 24))
		spell_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		spell_desc.clip_text = true
		panel.add_child(spell_desc)
		y += 45

	var preview := _hero_3d_preview(hero_name, Vector2(256, 116), Vector2(18, 281), true)
	panel.add_child(preview)
	panel.add_child(_label("MODÈLE INGAME  •  APERÇU 3D", 8, Color("c9a24d"), Vector2(18, 401), Vector2(256, 16), HORIZONTAL_ALIGNMENT_CENTER))
	return panel

func _hero_spell_icon_paths(hero_name: String) -> Array[String]:
	if hero_name == "EREN":
		return ["res://assets/hud/fireball.svg", "res://assets/hud/nova.svg", "res://assets/hud/charge_fire.svg"]
	if hero_name == "KAITHLYN":
		return ["res://assets/hud/axe.svg", "res://assets/hud/shield.svg", "res://assets/hud/charge.svg"]
	if hero_name == "MAYLINH":
		return ["res://assets/hud/spirit_projectile.svg", "res://assets/hud/spirit_heal.svg", "res://assets/hud/dash.svg"]
	return ["res://assets/hud/arc_bolt.svg", "res://assets/hud/teleport.svg", "res://assets/hud/dash.svg"]


func _hero_spells_short(hero_name: String) -> String:
	if hero_name == "EREN": return "BOULE DE FEU\nNOVA • CHARGE"
	if hero_name == "KAITHLYN": return "HACHE • BOUCLIER\nCHARGE BRUTALE"
	if hero_name == "MAYLINH": return "ÉCLAT • SOIN\nFUITE"
	return "ARC BOLT • TELEPORT\nPHASE DASH"


func _hero_spell_details(hero_name: String) -> Array:
	if hero_name == "EREN":
		return [
			["BOULE DE FEU", "30 dégâts • CD 2,5s", "res://assets/hud/fireball.svg"],
			["NOVA INCENDIAIRE", "AOE 45 dégâts • rayon 4m", "res://assets/hud/nova.svg"],
			["CHARGE ENFLAMMÉE", "25 dégâts • repousse", "res://assets/hud/charge_fire.svg"]
		]
	if hero_name == "KAITHLYN":
		return [
			["LANCER DE HACHE", "45 dégâts • charge 0,9s", "res://assets/hud/axe.svg"],
			["BOUCLIER", "35 bouclier • durée 3s", "res://assets/hud/shield.svg"],
			["CHARGE BRUTALE", "30 dégâts • stun 1s", "res://assets/hud/charge.svg"]
		]
	if hero_name == "MAYLINH":
		return [
			["ÉCLAT SPIRITUEL", "22 dégâts • CD 4s", "res://assets/hud/spirit_projectile.svg"],
			["CERCLE DE SOIN", "+28 PV • AOE", "res://assets/hud/spirit_heal.svg"],
			["FUITE", "Téléportation • invulnérabilité", "res://assets/hud/dash.svg"]
		]
	return [
		["ARC BOLT", "18 dégâts • ralentit", "res://assets/hud/arc_bolt.svg"],
		["TELEPORT", "Repositionnement instantané", "res://assets/hud/teleport.svg"],
		["PHASE DASH", "Dash court • traverse les unités", "res://assets/hud/dash.svg"]
	]

func _aaa_nav_button(text_value: String, active: bool) -> Button:
	var b := Button.new()
	b.text = ("◆  " if active else "    ") + text_value
	b.custom_minimum_size = Vector2(166, 42)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", Color("f3e2b8") if active else Color("7a6a4a"))
	b.add_theme_color_override("font_hover_color", Color("fff2d4"))
	b.add_theme_stylebox_override("normal", _rune_box(Color("241a0d") if active else Color("140f09"), Color("c9a24d") if active else Color("352818"), 1))
	b.add_theme_stylebox_override("hover", _rune_box(Color("2c2010"), Color("e8b656"), 1))
	b.add_theme_stylebox_override("focus", _rune_box(Color("2c2010"), Color("f4c977"), 2))
	return b

func _mode_card(mode: String, selected: bool) -> Button:
	var b := Button.new()
	b.text = mode
	b.custom_minimum_size = Vector2(600, 68)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color("f3e6c8"))
	b.add_theme_stylebox_override("normal", _rune_box(Color("1a140b"), Color("4a3018"), 1))
	b.add_theme_stylebox_override("hover", _rune_box(Color("241a0d"), Color("c9a24d"), 1))
	if selected:
		b.add_theme_stylebox_override("normal", _rune_box(Color("2c2010"), Color("e8b656"), 2))
	b.add_theme_stylebox_override("focus", _rune_box(Color("241a0d"), Color("f4c977"), 2))
	return b

func _hero_accent(hero_name: String) -> Color:
	# Teintes patinées façon aura magique ancienne plutôt que néon.
	if hero_name == "EREN":
		return Color("d9691f")
	if hero_name == "KAITHLYN":
		return Color("c98a3d")
	if hero_name == "MAYLINH":
		return Color("4fae7d")
	return Color("5b9bc4")

func _hero_role(hero_name: String) -> String:
	if hero_name == "EREN": return "FIRE BURST / CONTROLLER"
	if hero_name == "KAITHLYN": return "BERSERKER / CONTROLLER"
	if hero_name == "MAYLINH": return "HEALER / CONTROLLER"
	return "ARCANE SKIRMISHER / DPS"

func _hero_spells(hero_name: String) -> String:
	if hero_name == "EREN": return "BOULE DE FEU  •  NOVA INCENDIAIRE  •  CHARGE ENFLAMMÉE"
	if hero_name == "KAITHLYN": return "LANCER DE HACHE  •  BOUCLIER  •  CHARGE BRUTALE"
	if hero_name == "MAYLINH": return "ÉCLAT SPIRITUEL  •  CERCLE DE SOIN  •  FUITE"
	return "ARC BOLT  •  TELEPORT  •  PHASE DASH"

func _hero_art(hero_name: String) -> String:
	if hero_name == "AERIS": return "res://assets/menu_art/heroes/aeris.png"
	if hero_name == "MAYLINH": return "res://assets/menu_art/heroes/maylinh.png"
	if hero_name == "KAITHLYN": return "res://assets/menu_art/heroes/kaithlyn.png"
	if hero_name == "EREN": return "res://assets/menu_art/heroes/eren.png"
	return ""

func _hero_description(hero_name: String) -> String:
	if hero_name == "EREN": return "Chevalier de feu spécialisé dans les explosions, la pression de zone et les charges offensives."
	if hero_name == "KAITHLYN": return "Berserker de mêlée avec hache, bouclier et contrôle brutal des engagements."
	if hero_name == "MAYLINH": return "Gardienne mystique capable de soigner ses alliés tout en contrôlant la zone."
	return "Skirmisher arcane à distance, rapide et mobile, construit autour du burst et du repositionnement."


# =========================================================
# SETTINGS
# =========================================================

func _show_settings() -> void:
	_clear()
	title.text = "SETTINGS"

	var columns := HBoxContainer.new()
	columns.custom_minimum_size = Vector2(0, 330)
	columns.add_theme_constant_override("separation", 12)
	content.add_child(columns)

	columns.add_child(_settings_column_audio())
	columns.add_child(_settings_column_input())
	columns.add_child(_settings_column_video())
	columns.add_child(_settings_column_gameplay())

	content.add_child(_label(
		"Les réglages sont sauvegardés automatiquement.  •  Les options manette apparaissent lorsqu’une manette est détectée.",
		10,
		Color("6b5a3a"),
		Vector2(0, 355),
		Vector2(950, 20),
		HORIZONTAL_ALIGNMENT_CENTER
	))


func _settings_column_gameplay() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(220, 300)
	box.add_theme_constant_override("separation", 8)
	box.add_child(_label("GAMEPLAY", 15, Color("e8b656")))
	box.add_child(_toggle_row("TUTORIELS", "tutorials"))
	box.add_child(_toggle_row("ASTUCES", "ability_hints"))
	box.add_child(_toggle_row("SAUVEGARDE AUTO", "autosave"))
	box.add_child(_toggle_row("CONFIRMATIONS", "confirmations"))
	box.add_child(_toggle_row("INDICATEURS", "indicators"))
	return box


# =========================================================
# AUDIO
# =========================================================

func _settings_column_audio() -> VBoxContainer:
	var box := VBoxContainer.new()

	box.custom_minimum_size = Vector2(220, 260)
	box.add_theme_constant_override("separation", 10)

	box.add_child(
		_label(
			"AUDIO",
			16,
			Color("e8b656")
		)
	)

	var master := _audio_row(
		"MASTER VOLUME",
		"master_volume"
	)

	box.add_child(master)

	var music := _audio_row(
		"MUSIC",
		"music_volume"
	)

	box.add_child(music)

	var sfx := _audio_row(
		"SFX",
		"sfx_volume"
	)

	box.add_child(sfx)

	return box


func _audio_row(label_text: String, setting_name: String) -> Panel:
	var row := _panel(
		Vector2.ZERO,
		Vector2(220, 42),
		Color("1a140b"),
		Color("4a3018"),
		9
	)

	row.custom_minimum_size = Vector2(220, 42)

	var label := _label(
		label_text,
		11,
		Color("d4c4a0"),
		Vector2(12, 12),
		Vector2(130, 18)
	)

	row.add_child(label)

	var slider := HSlider.new()
	slider.focus_mode = Control.FOCUS_ALL

	slider.position = Vector2(92, 9)
	slider.size = Vector2(90, 20)

	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = settings[setting_name]

	slider.value_changed.connect(
		func(value: float):
			settings[setting_name] = value
			_apply_audio_settings()
			_save_settings()
	)

	row.add_child(slider)

	var value_label := _label(
		"%d%%" % int(settings[setting_name]),
		10,
		Color("c9a24d"),
		Vector2(184, 12),
		Vector2(30, 18),
		HORIZONTAL_ALIGNMENT_RIGHT
	)

	row.add_child(value_label)

	slider.value_changed.connect(
		func(value: float):
			value_label.text = "%d%%" % int(value)
	)

	return row


# =========================================================
# VIDEO
# =========================================================

func _settings_column_video() -> VBoxContainer:
	var box := VBoxContainer.new()

	box.custom_minimum_size = Vector2(220, 320)
	box.add_theme_constant_override("separation", 10)

	box.add_child(
		_label(
			"VIDEO",
			16,
			Color("e8b656")
		)
	)

	box.add_child(
		_toggle_row(
			"FULLSCREEN",
			"fullscreen"
		)
	)

	box.add_child(
		_toggle_row(
			"V-SYNC",
			"vsync"
		)
	)

	box.add_child(
		_toggle_row(
			"SCREEN SHAKE",
			"screen_shake"
		)
	)

	box.add_child(
		_toggle_row(
			"DAMAGE NUMBERS",
			"damage_numbers"
		)
	)

	box.add_child(
		_camera_slider_row(
			"CHAMP DE VISION",
			"camera_fov",
			55.0,
			90.0,
			1.0,
			"°"
		)
	)

	box.add_child(
		_camera_slider_row(
			"HAUTEUR CAMÉRA",
			"camera_height",
			2.0,
			5.5,
			0.1,
			" m"
		)
	)

	return box


func _toggle_row(label_text: String, setting_name: String) -> Panel:
	var row := _panel(
		Vector2.ZERO,
		Vector2(220, 42),
		Color("1a140b"),
		Color("4a3018"),
		9
	)

	row.custom_minimum_size = Vector2(220, 42)

	row.add_child(
		_label(
			label_text,
			11,
			Color("d4c4a0"),
			Vector2(12, 12),
			Vector2(100, 18)
		)
	)

	var toggle := CheckButton.new()
	toggle.focus_mode = Control.FOCUS_ALL

	toggle.position = Vector2(142, 5)
	toggle.size = Vector2(70, 32)
	toggle.button_pressed = settings[setting_name]

	toggle.toggled.connect(
		func(enabled: bool):
			settings[setting_name] = enabled
			_apply_settings()
			_save_settings()
	)

	row.add_child(toggle)

	return row


func _camera_slider_row(
	label_text: String,
	setting_name: String,
	minimum: float,
	maximum: float,
	step: float,
	unit: String
) -> Panel:
	var row := _panel(
		Vector2.ZERO,
		Vector2(220, 32),
		Color("1a140b"),
		Color("4a3018"),
		9
	)

	row.custom_minimum_size = Vector2(220, 32)
	row.add_child(
		_label(
			label_text,
			10,
			Color("d4c4a0"),
			Vector2(12, 8),
			Vector2(100, 18)
		)
	)

	var slider := HSlider.new()
	slider.position = Vector2(90, 6)
	slider.size = Vector2(95, 20)
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = float(settings[setting_name])

	var value_label := _label(
		"",
		10,
		Color("c9a24d"),
		Vector2(184, 8),
		Vector2(32, 18),
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	value_label.text = "%.1f%s" % [slider.value, unit]

	slider.value_changed.connect(
		func(value: float):
			settings[setting_name] = value
			value_label.text = "%.1f%s" % [value, unit]
			_save_settings()
	)

	row.add_child(slider)
	row.add_child(value_label)
	return row


# =========================================================
# KEYBINDS
# =========================================================

func _settings_column_input() -> VBoxContainer:
	var box := VBoxContainer.new()

	box.custom_minimum_size = Vector2(220, 260)
	box.add_theme_constant_override("separation", 10)

	box.add_child(
		_label(
			"KEYBINDS",
			16,
			Color("e8b656")
		)
	)

	box.add_child(
		_keybind_row(
			"MOVE UP",
			"move_up"
		)
	)

	box.add_child(
		_keybind_row(
			"MOVE DOWN",
			"move_down"
		)
	)

	box.add_child(
		_keybind_row(
			"MOVE LEFT",
			"move_left"
		)
	)

	box.add_child(
		_keybind_row(
			"MOVE RIGHT",
			"move_right"
		)
	)

	box.add_child(
		_keybind_row(
			"ARC BOLT",
			"spell_orb"
		)
	)

	box.add_child(
		_keybind_row(
			"NOVA",
			"spell_nova"
		)
	)

	box.add_child(
		_keybind_row(
			"PHASE DASH",
			"spell_dash"
		)
	)

	if controller_connected:
		box.add_child(_label("MANETTE", 13, Color("e8b656")))
		box.add_child(_camera_slider_row("SENSIBILITÉ CAMÉRA", "controller_camera_sensitivity", 0.5, 6.0, 0.1, "x"))
		box.add_child(_toggle_row("INVERTIR AXE Y", "controller_invert_y"))

	return box


func _keybind_row(label_text: String, action_name: String) -> Panel:
	var row := _panel(
		Vector2.ZERO,
		Vector2(220, 42),
		Color("1a140b"),
		Color("4a3018"),
		9
	)

	row.custom_minimum_size = Vector2(220, 42)

	row.add_child(
		_label(
			label_text,
			11,
			Color("d4c4a0"),
			Vector2(12, 12),
			Vector2(105, 18)
		)
	)

	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL

	button.position = Vector2(112, 7)
	button.size = Vector2(95, 28)
	button.text = _get_key_name(action_name)

	button.add_theme_font_size_override(
		"font_size",
		10
	)

	button.pressed.connect(
		func():
			_start_key_rebind(button, action_name)
	)

	row.add_child(button)

	return row


func _get_key_name(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return "UNBOUND"

	var events := InputMap.action_get_events(action_name)

	if events.is_empty():
		return "UNBOUND"

	var event: InputEvent = events[0]

	if event is InputEventKey:
		return OS.get_keycode_string(event.physical_keycode)

	if event is InputEventMouseButton:
		return "MOUSE %d" % event.button_index

	return "UNKNOWN"


func _start_key_rebind(button: Button, action_name: String) -> void:
	button.text = "PRESS KEY"

	button.set_meta(
		"waiting_for_key",
		true
	)

	button.gui_input.connect(
		func(event: InputEvent):
			if not button.get_meta("waiting_for_key", false):
				return

			if event is InputEventKey and event.pressed:
				_rebind_action(
					action_name,
					event
				)

				button.text = _get_key_name(action_name)
				button.set_meta("waiting_for_key", false)

				var viewport := get_viewport()
				if viewport != null:
					viewport.set_input_as_handled()
	)


func _rebind_action(action_name: String, event: InputEventKey) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	InputMap.action_erase_events(action_name)

	var new_event := InputEventKey.new()

	new_event.physical_keycode = event.physical_keycode
	new_event.keycode = event.keycode

	InputMap.action_add_event(
		action_name,
		new_event
	)

	_save_keybinds()


func _save_keybinds() -> void:
	var config := ConfigFile.new()

	var error := config.load(SETTINGS_PATH)

	if error != OK and error != ERR_FILE_NOT_FOUND:
		return

	for action_name in [
		"move_up",
		"move_down",
		"move_left",
		"move_right",
		"spell_orb",
		"spell_nova",
		"spell_dash"
	]:
		if not InputMap.has_action(action_name):
			continue

		var events := InputMap.action_get_events(action_name)

		if events.is_empty():
			continue

		var event: InputEvent = events[0]

		if event is InputEventKey:
			config.set_value(
				"keybinds",
				action_name,
				event.physical_keycode
			)

	config.save(SETTINGS_PATH)


# =========================================================
# APPLY SETTINGS
# =========================================================

func _apply_settings() -> void:
	_apply_audio_settings()

	if settings["fullscreen"]:
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN
		)
	else:
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED
		)

	if settings["vsync"]:
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED
		)
	else:
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_DISABLED
	)


func _apply_audio_settings() -> void:
	_set_bus_volume(
		"Master",
		settings["master_volume"]
	)

	_set_bus_volume(
		"Music",
		settings["music_volume"]
	)

	_set_bus_volume(
		"SFX",
		settings["sfx_volume"]
	)


func _set_bus_volume(bus_name: String, value: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)

	if bus == -1:
		return

	if value <= 0.0:
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)

		var db := linear_to_db(value / 100.0)
		AudioServer.set_bus_volume_db(bus, db)


# =========================================================
# SAVE / LOAD
# =========================================================

func _save_settings() -> void:
	var config := ConfigFile.new()

	config.set_value(
		"audio",
		"master_volume",
		settings["master_volume"]
	)

	config.set_value(
		"audio",
		"music_volume",
		settings["music_volume"]
	)

	config.set_value(
		"audio",
		"sfx_volume",
		settings["sfx_volume"]
	)

	config.set_value(
		"video",
		"fullscreen",
		settings["fullscreen"]
	)

	config.set_value(
		"video",
		"vsync",
		settings["vsync"]
	)

	config.set_value(
		"video",
		"screen_shake",
		settings["screen_shake"]
	)

	config.set_value(
		"video",
		"damage_numbers",
		settings["damage_numbers"]
	)

	config.set_value("gameplay", "tutorials", settings["tutorials"])
	config.set_value("gameplay", "ability_hints", settings["ability_hints"])
	config.set_value("gameplay", "autosave", settings["autosave"])
	config.set_value("gameplay", "confirmations", settings["confirmations"])
	config.set_value("gameplay", "indicators", settings["indicators"])

	config.set_value(
		"camera",
		"fov",
		settings["camera_fov"]
	)
	config.set_value(
		"camera",
		"height",
		settings["camera_height"]
	)
	config.set_value("controller", "camera_sensitivity", settings["controller_camera_sensitivity"])
	config.set_value("controller", "invert_y", settings["controller_invert_y"])

	config.save(SETTINGS_PATH)


func _load_settings() -> void:
	var config := ConfigFile.new()

	var error := config.load(SETTINGS_PATH)

	if error != OK:
		return

	settings["master_volume"] = config.get_value(
		"audio",
		"master_volume",
		78.0
	)

	settings["music_volume"] = config.get_value(
		"audio",
		"music_volume",
		64.0
	)

	settings["sfx_volume"] = config.get_value(
		"audio",
		"sfx_volume",
		64.0
	)

	settings["fullscreen"] = config.get_value(
		"video",
		"fullscreen",
		false
	)

	settings["vsync"] = config.get_value(
		"video",
		"vsync",
		true
	)

	settings["screen_shake"] = config.get_value(
		"video",
		"screen_shake",
		true
	)

	settings["damage_numbers"] = config.get_value(
		"video",
		"damage_numbers",
		true
	)

	settings["tutorials"] = config.get_value("gameplay", "tutorials", true)
	settings["ability_hints"] = config.get_value("gameplay", "ability_hints", true)
	settings["autosave"] = config.get_value("gameplay", "autosave", true)
	settings["confirmations"] = config.get_value("gameplay", "confirmations", true)
	settings["indicators"] = config.get_value("gameplay", "indicators", true)

	settings["camera_fov"] = float(config.get_value(
		"camera",
		"fov",
		65.0
	))
	settings["camera_height"] = float(config.get_value(
		"camera",
		"height",
		3.2
	))
	settings["controller_camera_sensitivity"] = float(config.get_value("controller", "camera_sensitivity", 2.8))
	settings["controller_invert_y"] = bool(config.get_value("controller", "invert_y", false))

	_load_keybinds(config)


func _load_keybinds(config: ConfigFile) -> void:
	for action_name in [
		"move_up",
		"move_down",
		"move_left",
		"move_right",
		"spell_orb",
		"spell_nova",
		"spell_dash"
	]:
		if not config.has_section_key(
			"keybinds",
			action_name
		):
			continue

		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

		var keycode: int = int(config.get_value(
	"keybinds",
	action_name,
	0
))

		var event := InputEventKey.new()
		event.physical_keycode = keycode

		InputMap.action_erase_events(action_name)
		InputMap.action_add_event(
			action_name,
			event
		)


# =========================================================
# MENU MUSIC
# =========================================================

func _setup_menu_music() -> void:
	menu_music = AudioStreamPlayer.new()
	menu_music.name = "MenuMusic"

	var music_stream: AudioStream = load("res://audio/menu_music.ogg") as AudioStream

	if music_stream == null:
		push_warning("Impossible de charger res://audio/menu_music.ogg")
		return

	# Boucle automatique si le fichier est un OGG Vorbis.
	if music_stream is AudioStreamOggVorbis:
		(music_stream as AudioStreamOggVorbis).loop = true

	menu_music.stream = music_stream

	# Utilise le bus Music s'il existe.
	# Sinon, Master pour éviter que la musique soit muette.
	var music_bus := AudioServer.get_bus_index("Music")

	if music_bus >= 0:
		menu_music.bus = "Music"
	else:
		menu_music.bus = "Master"
		push_warning("Le bus 'Music' n'existe pas. La musique utilise Master.")

	menu_music.autoplay = false
	menu_music.volume_db = 0.0

	add_child(menu_music)

	# Le volume du bus est déjà appliqué par _apply_settings().
	menu_music.play()


# =========================================================
# PLACEHOLDER
# =========================================================

func _show_placeholder(item: String) -> void:
	_clear()

	title.text = item + " // IN DEVELOPMENT"

	content.add_child(
		_label(
			"Cette section sera connectée aux héros, cosmétiques et loadouts dès que la boucle de combat est verrouillée.",
			16,
			Color("b8a880")
		)
	)


# =========================================================
# LAUNCH
# =========================================================

func _launch() -> void:
	# Récupère l'Autoload Network sans dépendre de l'identifiant global
	# au moment de la compilation.
	var network_node: Node = get_node_or_null("/root/Network")
	if network_node != null:
		network_node.set("match_mode", selected_mode)
		network_node.set("selected_hero", selected_hero)
	else:
		push_warning("Autoload 'Network' introuvable. Le mode ne sera pas transmis au réseau.")

	# Avant ce correctif, la scène était toujours "res://scenes/arena.tscn",
	# quel que soit selected_mode : une map dédiée (ex. Arena1v1.tscn pour
	# le 1V1 DUEL) n'était donc jamais chargée en jouant depuis le menu.
	var arena_scene_path := "res://scenes/arena.tscn"
	if selected_mode == "1V1 DUEL" and ResourceLoader.exists("res://scenes/Arena1v1.tscn"):
		arena_scene_path = "res://scenes/Arena1v1.tscn"

	get_tree().change_scene_to_file(arena_scene_path)


# =========================================================
# UTILS
# =========================================================

func _clear() -> void:
	for child in content.get_children():
		child.queue_free()


func _navigate_deferred(item: String) -> void:
	call_deferred("_navigate", item)


func _show_home_deferred() -> void:
	call_deferred("_show_home")
	call_deferred("_focus_first_control")

func _show_heroes_deferred() -> void:
	call_deferred("_show_heroes")
	call_deferred("_focus_first_control")


func _show_settings_deferred() -> void:
	call_deferred("_show_settings")
	call_deferred("_focus_first_control")


## Style "sceau gravé" : bordures fines dorées/bronze, coins asymétriques,
## ombre profonde façon pierre ou cuir tanné plutôt que verre lisse.
func _box(background: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.shadow_color = Color(0, 0, 0, 0.65)
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 3)
	return box

## Variante avec coins asymétriques (motif "plaque gravée" : un coin plus
## carré que les autres, comme une plaque de métal martelée à la main).
func _rune_box(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(width)
	box.corner_radius_top_left = 2
	box.corner_radius_top_right = 14
	box.corner_radius_bottom_left = 14
	box.corner_radius_bottom_right = 2
	box.shadow_color = Color(0, 0, 0, 0.65)
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 3)
	return box


func _panel(
	panel_position: Vector2,
	panel_size: Vector2,
	bg: Color,
	border: Color,
	radius: int
) -> Panel:

	var node := Panel.new()

	node.position = panel_position
	node.size = panel_size

	var style := StyleBoxFlat.new()

	style.bg_color = bg
	style.border_color = border

	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)

	node.add_theme_stylebox_override(
		"panel",
		style
	)

	return node


func _label(
	value: String,
	font_size: int,
	color: Color,
	label_position := Vector2.ZERO,
	label_size := Vector2(500, 28),
	align := HORIZONTAL_ALIGNMENT_LEFT
) -> Label:

	var node := Label.new()

	node.text = value
	node.position = label_position
	node.size = label_size

	node.add_theme_font_size_override(
		"font_size",
		font_size
	)

	node.add_theme_color_override(
		"font_color",
		color
	)

	node.horizontal_alignment = align

	return node
## Snippet à coller dans main_menu.gd (voir GUIDE_installation_arkanites.md
## pour les deux petites modifications de routage à faire en plus).

const ARKANITE_DATA_DIR := "res://data/arkanites/"
const ARKANITE_FILES := [
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

## Stockage temporaire en mémoire (perdu à la fermeture du jeu). À remplacer
## par une vraie sauvegarde (ConfigFile local ou requête serveur) quand vous
## serez prêt à passer à l'étape de persistance.
var equipped_arkanites: Dictionary = {}


func _load_all_arkanites() -> Array[ArkaniteCard]:
	var cards: Array[ArkaniteCard] = []
	for file_name in ARKANITE_FILES:
		var card := load(ARKANITE_DATA_DIR + file_name) as ArkaniteCard
		if card != null:
			cards.append(card)
	return cards


func _show_arkanites() -> void:
	_clear()
	title.text = "ARKANITES"

	var player_level: int = PlayerProgress.get_level()
	var level_text: String = "NIVEAU MAX (%d)" % PlayerProgress.MAX_LEVEL
	if player_level < PlayerProgress.MAX_LEVEL:
		var player_xp: int = PlayerProgress.get_xp()
		var xp_needed: int = PlayerProgress.xp_to_next_level(player_level)
		level_text = "NIVEAU %d/%d  •  %d/%d XP" % [player_level, PlayerProgress.MAX_LEVEL, player_xp, xp_needed]

	var subtitle := _label(
		"FAÇONNE TON STYLE  •  HÉROS ACTUEL : %s  •  %s" % [selected_hero, level_text],
		10,
		Color("b8935a"),
		Vector2(0, 44),
		Vector2(946, 22),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	content.add_child(subtitle)

	var all_cards := _load_all_arkanites()

	var columns := HBoxContainer.new()
	columns.position = Vector2(0, 74)
	columns.size = Vector2(946, 480)
	columns.add_theme_constant_override("separation", 14)
	content.add_child(columns)

	columns.add_child(_arkanite_column("ÉVEIL", ArkaniteCard.Family.EVEIL, all_cards, Color("c9a24d")))
	columns.add_child(_arkanite_column("MAÎTRISE", ArkaniteCard.Family.MAITRISE, all_cards, Color("4fae7d")))
	columns.add_child(_arkanite_column("INVOCATION", ArkaniteCard.Family.INVOCATION, all_cards, Color("c0392b")))


func _arkanite_column(label_text: String, family: int, all_cards: Array[ArkaniteCard], accent: Color) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(306, 480)
	column.add_theme_constant_override("separation", 8)

	var header := _label(label_text, 14, accent, Vector2.ZERO, Vector2(300, 24), HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(306, 448)
	column.add_child(scroll)

	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(290, 0)
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	for card in all_cards:
		if card.family != family:
			continue
		list.add_child(_arkanite_card_row(card))

	return column


func _arkanite_card_row(card: ArkaniteCard) -> Panel:
	var relevant_to_selected_hero: bool = card.hero_id == "" or card.hero_id == selected_hero
	var accent := card.family_accent_color()

	var row := _panel(Vector2.ZERO, Vector2(290, 118), Color("140f09eb"), accent if relevant_to_selected_hero else Color("352818"), 10)
	row.custom_minimum_size = Vector2(290, 118)
	if not relevant_to_selected_hero:
		row.modulate.a = 0.55

	var thumbnail := TextureRect.new()
	thumbnail.position = Vector2(8, 8)
	thumbnail.size = Vector2(70, 102)
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if card.image_path != "":
		thumbnail.texture = load(card.image_path) as Texture2D
	row.add_child(thumbnail)

	var name_label := _label(card.display_name, 12, Color("f3e6c8"), Vector2(86, 8), Vector2(196, 32))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(name_label)

	if card.hero_id != "":
		row.add_child(_label(card.hero_id, 8, accent, Vector2(86, 40), Vector2(196, 16)))

	var effect_label := _label(card.effect_text, 8, Color("c4b394"), Vector2(86, 58), Vector2(196, 36))
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(effect_label)

	if card.is_equipable:
		# Consommables (Éveil) toujours disponibles ; Maîtrise/Invocation se
		# débloquent progressivement avec le niveau du joueur.
		var unlocked: bool = PlayerProgress.get_level() >= card.unlock_level
		var equipped: bool = bool(equipped_arkanites.get(card.id, false))
		var button_text: String = "ÉQUIPÉE" if equipped else "ÉQUIPER"
		if not unlocked:
			button_text = "NIVEAU %d REQUIS" % card.unlock_level
		var toggle_button := _button(button_text, Vector2(120, 26), equipped)
		toggle_button.position = Vector2(86, 92)
		toggle_button.size = Vector2(120, 22)
		toggle_button.add_theme_font_size_override("font_size", 9 if unlocked else 8)
		toggle_button.disabled = not relevant_to_selected_hero or not unlocked
		toggle_button.pressed.connect(func():
			equipped_arkanites[card.id] = not bool(equipped_arkanites.get(card.id, false))
			_show_arkanites_deferred()
		)
		row.add_child(toggle_button)
	else:
		var use_button := _button("UTILISER", Vector2(120, 26), false)
		use_button.position = Vector2(86, 92)
		use_button.size = Vector2(120, 22)
		use_button.add_theme_font_size_override("font_size", 9)
		use_button.pressed.connect(func():
			print("ARENA RIFT : Arkanite consommée -> ", card.id)
			# TODO : appliquer l'effet temporaire réel + retirer du stock.
		)
		row.add_child(use_button)
	# Petit bouton i : ouvre la carte dans son format original.
	var info_button := Button.new()
	info_button.text = "i"
	info_button.position = Vector2(258, 7)
	info_button.size = Vector2(24, 24)
	info_button.focus_mode = Control.FOCUS_ALL
	info_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	info_button.add_theme_font_size_override("font_size", 14)
	info_button.add_theme_color_override("font_color", accent)
	info_button.add_theme_color_override(
		"font_hover_color",
		Color("fff2d4")
	)

	info_button.add_theme_stylebox_override(
		"normal",
		_box(Color("1a140b"), accent, 12, 1)
	)

	info_button.add_theme_stylebox_override(
		"hover",
		_box(Color("2c2010"), Color("f4c977"), 12, 2)
	)

	info_button.pressed.connect(func():
		_show_arkanite_preview(card)
	)

	row.add_child(info_button)
	
	return row


func _show_arkanites_deferred() -> void:
	call_deferred("_show_arkanites")
	call_deferred("_focus_first_control")

func _show_arkanite_preview(card: ArkaniteCard) -> void:
	# Empêche d'ouvrir plusieurs popups simultanément.
	if get_node_or_null("ArkanitePreviewOverlay") != null:
		return

	# Overlay plein écran placé au-dessus de tout le menu.
	var overlay := Control.new()
	overlay.name = "ArkanitePreviewOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Fond sombre derrière la carte.
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.01, 0.008, 0.004, 0.86)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP

	# Clic hors de la carte = fermeture.
	backdrop.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_arkanite_preview()
	)

	overlay.add_child(backdrop)

	var accent := card.family_accent_color()

	# Cadre de présentation de la carte.
	var frame := Panel.new()
	frame.position = Vector2(390, 35)
	frame.size = Vector2(500, 650)
	frame.mouse_filter = Control.MOUSE_FILTER_STOP

	frame.add_theme_stylebox_override(
		"panel",
		_box(Color("110c07"), accent, 18, 2)
	)

	overlay.add_child(frame)

	# Carte originale affichée grande, sans la déformer.
	var card_image := TextureRect.new()
	card_image.position = Vector2(24, 18)
	card_image.size = Vector2(452, 600)
	card_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_image.texture = load(card.image_path) as Texture2D

	frame.add_child(card_image)

	# Bouton de fermeture X, au-dessus de l'image.
	var close_button := Button.new()
	close_button.text = "×"
	close_button.position = Vector2(452, 10)
	close_button.size = Vector2(38, 38)
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	close_button.add_theme_font_size_override("font_size", 24)
	close_button.add_theme_color_override(
		"font_color",
		Color("f3e6c8")
	)
	close_button.add_theme_color_override(
		"font_hover_color",
		Color("ffffff")
	)

	close_button.add_theme_stylebox_override(
		"normal",
		_box(Color("1a140b"), accent, 14, 1)
	)

	close_button.add_theme_stylebox_override(
		"hover",
		_box(Color("3a1a10"), Color("f4c977"), 14, 2)
	)

	close_button.pressed.connect(_close_arkanite_preview)
	frame.add_child(close_button)

	# Apparition légère : zoom + fondu.
	frame.pivot_offset = frame.size * 0.5
	frame.modulate.a = 0.0
	frame.scale = Vector2(0.92, 0.92)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(frame, "modulate:a", 1.0, 0.16)
	tween.tween_property(
		frame,
		"scale",
		Vector2.ONE,
		0.16
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _close_arkanite_preview() -> void:
	var overlay := get_node_or_null("ArkanitePreviewOverlay")

	if overlay != null:
		overlay.queue_free()

func _button(
	value: String,
	button_size: Vector2,
	highlighted: bool
) -> Button:

	var node := Button.new()

	node.text = value
	node.custom_minimum_size = button_size

	node.add_theme_font_size_override(
		"font_size",
		15
	)
	node.add_theme_constant_override("outline_size", 1)
	node.add_theme_color_override("font_outline_color", Color("0a0603"))

	# Plaque gravée : bronze allumé quand mise en avant, métal terne sinon.
	var bg_color := Color("6b3a12") if highlighted else Color("1c1712")
	var border_color := Color("e8b656") if highlighted else Color("4a3d28")
	var font_color := Color("fff2d4") if highlighted else Color("a89878")

	node.add_theme_color_override("font_color", font_color)
	node.add_theme_color_override("font_hover_color", Color("fff2d4"))

	var style := _rune_box(bg_color, border_color, 1)
	node.add_theme_stylebox_override("normal", style)
	node.add_theme_stylebox_override("hover", _rune_box(bg_color.lightened(0.08), Color("f4c977"), 1))
	node.add_theme_stylebox_override("focus", _rune_box(bg_color.lightened(0.08), Color("f4c977"), 2))

	return node
