extends Control

var selected_mode := "DEATHMATCH"
## Boutons persistants (nœuds de scène) des 5 cartes de mode de
## %ArenaModesScreen, indexés par nom de mode — remplit dans _build_shell().
var _arena_mode_card_buttons: Dictionary = {}
## Héros réellement choisi pour la partie en cours — n'est plus modifié que
## par le lobby de sélection des champions (après matchmaking).
var selected_hero := "AERIS"
## Héros actuellement affiché dans le panneau de détail de l'onglet HEROES,
## indépendant de selected_hero : cet onglet n'est plus qu'une galerie de
## consultation, le vrai choix se fait dans le lobby au lancement d'une
## partie.
var _heroes_tab_focus_hero := "AERIS"
## Héros actuellement affiché dans l'onglet LOADOUT (indépendant de
## selected_hero, même principe que _heroes_tab_focus_hero).
var _loadout_focus_hero := "AERIS"
# Renseigné juste avant _launch() par le flux Custom Game (dépend de la map
# choisie dans le salon, pas du mode) : sans ça, _launch() ne connaissait
# que le cas "1V1 DUEL" et chargeait toujours arena.tscn pour tout le
# reste, y compris quand le salon avait choisi une autre map — le serveur
# recevait bien la bonne map (d'où des collisions cohérentes), mais le
# client affichait toujours arena.tscn.
var pending_arena_scene_path: String = ""

# Lobby de sélection de personnage (après matchmaking, avant l'arène).
var _lobby_active_screen: bool = false
var _lobby_ready_locked: bool = false
var _lobby_seconds_left_local: float = 30.0
var _lobby_countdown_label: Label
var _lobby_status_box: VBoxContainer
var _lobby_validate_button: Button
## Message affiché une fois en haut du prochain _show_arena_modes() (ex :
## annulation du lobby), puis effacé.
var _transient_status_message: String = ""

var page := "HOME"
var content: VBoxContainer
var title: Label
var menu_music: AudioStreamPlayer
var nav_buttons: Dictionary = {}
var controller_connected: bool = false
var _last_controller_connected: bool = false
## Contour de surbrillance unique, superposé par-dessus le contrôle qui a
## le focus clavier/manette — chaque bouton avait son propre style "focus"
## (souvent trop subtil, à peine différent du style normal, incohérent d'un
## écran à l'autre), rendant la navigation manette difficile à suivre à
## l'œil. Un seul contour, toujours identique et bien visible, réglé une
## fois pour toute la fenêtre plutôt que par bouton.
var _focus_ring: Panel

var steam_profile: Panel
var steam_avatar: TextureRect
var steam_avatar_fallback: Label
var steam_name_label: Label
var steam_status_label: Label
var level_label: Label
var xp_label: Label
var level_progress_fill: ColorRect
const LEVEL_BAR_WIDTH: float = 164.0
const NAV_BUTTON_FRAME := "res://assets/menu_design/champ_select/menu_left_button.png"

## Bannières illustrées par mode/catégorie, mêmes gabarit (icône à gauche
## dans un médaillon, flèche à droite dans un losange) mais couleurs et
## artwork différents par mode — fournies par le graphiste.
const MODE_CARD_ASSETS := {
	"MULTIJOUEUR ARENA": "res://assets/menu_design/champ_select/multijoueur_arena.png",
	"CO-OP DONJON": "res://assets/menu_design/champ_select/coop_donjon.png",
	"IMPOSTOR": "res://assets/menu_design/champ_select/impostor.png",
	"HIDE & SEEK": "res://assets/menu_design/champ_select/hide_and_seek.png",
	"DEATHMATCH": "res://assets/menu_design/champ_select/deathmatch_button.png",
	"1V1 DUEL": "res://assets/menu_design/champ_select/1v1_button.png",
	"2V2 CLASH": "res://assets/menu_design/champ_select/2v2_button.png",
	"3V3 RIVALRY": "res://assets/menu_design/champ_select/3v3_button.png",
	"CUSTOM GAME": "res://assets/menu_design/champ_select/custom_button.png",
}
## Le héros se choisit désormais dans le lobby de sélection des champions
## (après matchmaking), plus dans cet écran — ce panneau ne montre donc que
## des infos sur le mode choisi, pas un aperçu de héros.
const MODE_DETAILS := {
	"DEATHMATCH": {
		"desc": "Chacun pour soi dans l'arène. Le premier à atteindre le score fatal remporte le combat.",
		"players": "8 JOUEURS  •  FFA",
		"map": "ARÈNE CENTRALE",
	},
	"1V1 DUEL": {
		"desc": "Duel à mort, un contre un, sans échappatoire. Seule la maîtrise compte.",
		"players": "2 JOUEURS  •  DUEL",
		"map": "FOSSE DU DUEL",
	},
	"2V2 CLASH": {
		"desc": "Deux équipes de deux s'affrontent pour le contrôle de l'arène.",
		"players": "4 JOUEURS  •  2V2",
		"map": "ARÈNE CENTRALE",
	},
	"3V3 RIVALRY": {
		"desc": "Bataille d'équipe à trois contre trois, pour les affrontements les plus stratégiques.",
		"players": "6 JOUEURS  •  3V3",
		"map": "ARÈNE CENTRALE",
	},
	"CUSTOM GAME": {
		"desc": "Configure ta propre partie : carte, règles et joueurs invités à ta convenance.",
		"players": "JUSQU'À 8 JOUEURS",
		"map": "AU CHOIX",
	},
}
## Découpe un texte en lignes d'au plus `max_chars` caractères, en coupant
## uniquement entre les mots. Utilisé à la place de Label.autowrap_mode qui
## ne renvoyait pas le texte à la ligne correctement dans le panneau de
## détails du mode (débordement hors du panneau).
func _wrap_text_lines(text: String, max_chars: int) -> String:
	var lines: PackedStringArray = []
	var current := ""
	for word in text.split(" "):
		var candidate := (current + " " + word) if current != "" else word
		if candidate.length() > max_chars and current != "":
			lines.append(current)
			current = word
		else:
			current = candidate
	if current != "":
		lines.append(current)
	return "\n".join(lines)

const MODE_CARD_HEIGHT_CATEGORY: float = 110.0
## 5 cartes + le panneau latéral doivent tenir sous le bas du cadre
## principal : à 92px la liste débordait hors du cadre (visible en bas
## d'écran sur CUSTOM GAME) — 76px la fait rentrer avec un peu de marge.
const MODE_CARD_HEIGHT_LIST: float = 76.0
const CREATE_PARTY_BUTTON_ASSET := "res://assets/menu_design/champ_select/create_party_button.png"

## Les bannières font 2172x724 mais le cadre orné (médaillon + filet doré)
## n'occupe qu'une bande centrée d'environ 300-350px de haut — le reste
## n'est que du halo/glow transparent. Étirer l'image entière sur la
## hauteur réduite d'un bouton écrasait le médaillon en ovale ; on ne garde
## donc que cette bande avant de l'étirer, ce qui réduit fortement la
## déformation.
const BANNER_CROP_TOP: int = 170
const BANNER_CROP_HEIGHT: int = 370
var _banner_texture_cache: Dictionary = {}

func _cropped_banner_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _banner_texture_cache.has(path):
		return _banner_texture_cache[path]
	var base := load(path) as Texture2D
	if base == null:
		return null
	var image := base.get_image()
	if image == null:
		_banner_texture_cache[path] = base
		return base
	var top: int = clampi(BANNER_CROP_TOP, 0, image.get_height() - 1)
	var height: int = clampi(BANNER_CROP_HEIGHT, 1, image.get_height() - top)
	var cropped := image.get_region(Rect2i(0, top, image.get_width(), height))
	var result: Texture2D = base
	if cropped != null and cropped.get_width() > 0 and cropped.get_height() > 0:
		result = ImageTexture.create_from_image(cropped)
	_banner_texture_cache[path] = result
	return result

var party_panel: Panel
var party_title_label: Label
var party_status_label: Label
var party_members_box: VBoxContainer
var party_invite_button: Button
var party_leave_button: Button

## CUSTOM GAME : salon à code façon Among Us (aucun lien avec les lobbies
## Steam ci-dessus — n'importe qui peut rejoindre avec le code, ami Steam ou
## non). custom_room_state est la dernière réponse connue du serveur pour
## ce salon (membres, camps, map, mode, état du serveur dédié une fois
## lancé), rafraîchie par polling continu tant qu'on est dans le salon.
var custom_room_code: String = ""
var custom_room_state: Dictionary = {}
var custom_room_http: HTTPRequest
var custom_room_poll_http: HTTPRequest
var custom_room_poll_timer: Timer
var custom_room_join_input: LineEdit
var custom_room_home_status_label: Label
var custom_room_panel: Panel
var custom_room_status_label: Label
var custom_room_map_option: OptionButton
var custom_room_mode_option: OptionButton
var custom_room_random_button: Button
var custom_room_astral_panel: Panel
var custom_room_arcane_panel: Panel
var custom_room_astral_box: VBoxContainer
var custom_room_arcane_box: VBoxContainer
var custom_room_unassigned_label: Label
var custom_room_unassigned_box: VBoxContainer
var custom_room_ffa_box: VBoxContainer
var custom_room_launch_button: Button
var custom_room_pending_action: String = ""
# Le polling continu (GET toutes les 1s) et une action (POST settings/team/
# start) peuvent se terminer dans le désordre selon la latence réseau —
# sans ce garde, une réponse de poll "en retard" pouvait écraser un
# changement pourtant déjà appliqué avec l'état d'AVANT ce changement,
# donnant l'impression que la sélection de map/mode revenait en arrière
# toute seule. On applique donc uniquement les réponses dont la version
# est supérieure ou égale à la dernière appliquée.
var _custom_room_last_version: int = -1
var _custom_room_connect_triggered: bool = false
const CUSTOM_ROOM_MAPS := [["default", "CARTE PAR DÉFAUT"], ["1v1", "ARENA 1V1"], ["labyrinth", "LABYRINTHE D'ARKANOR"]]
const CUSTOM_ROOM_MODES := [["TEAM", "ÉQUIPES (ASTRAL VS ARCANE)"], ["FFA", "DEATHMATCH (CHACUN POUR SOI)"], ["EXPLORE", "DÉCOUVERTE (SANS COMBAT)"]]

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

	custom_room_http = HTTPRequest.new()
	custom_room_http.name = "CustomRoomActionHTTP"
	add_child(custom_room_http)
	custom_room_http.request_completed.connect(_on_custom_room_action_completed)

	custom_room_poll_http = HTTPRequest.new()
	custom_room_poll_http.name = "CustomRoomPollHTTP"
	add_child(custom_room_poll_http)
	custom_room_poll_http.request_completed.connect(_on_custom_room_poll_completed)

	custom_room_poll_timer = Timer.new()
	custom_room_poll_timer.name = "CustomRoomPollTimer"
	custom_room_poll_timer.wait_time = 1.0
	custom_room_poll_timer.one_shot = false
	add_child(custom_room_poll_timer)
	custom_room_poll_timer.timeout.connect(_poll_custom_room)

	var network_node: Node = get_node_or_null("/root/Network")
	if network_node != null:
		if not network_node.peer_arrived.is_connected(_on_matchmaking_peer_arrived):
			network_node.peer_arrived.connect(_on_matchmaking_peer_arrived)

	_show_home()
	_build_focus_ring()



func _process(_delta: float) -> void:
	_update_controller_connection()
	# Filet de sécurité manette : beaucoup d'écrans (MULTIJOUEUR ARENA, PARTY,
	# CUSTOM GAME, lobby de héros...) sont ouverts par un bouton connecté
	# directement (pas via _navigate()), donc sans réappliquer le focus après
	# _clear() — le bouton précédemment focus est détruit et plus rien n'a
	# le focus, ce qui bloquait totalement la navigation manette sur ces
	# écrans. Au lieu de patcher un par un tous les points d'entrée (et tous
	# ceux à venir), on revérifie chaque frame et on réapplique le focus dès
	# qu'il est perdu.
	if controller_connected:
		var viewport := get_viewport()
		if viewport != null:
			var focused := viewport.gui_get_focus_owner()
			if focused == null or not is_instance_valid(focused) or not focused.is_visible_in_tree():
				_focus_first_control()
	_update_focus_ring()
	if _lobby_active_screen and _lobby_countdown_label != null and is_instance_valid(_lobby_countdown_label):
		_lobby_seconds_left_local = maxf(0.0, _lobby_seconds_left_local - _delta)
		_lobby_countdown_label.text = str(int(ceil(_lobby_seconds_left_local)))


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
			# Le popup natif d'un OptionButton (PopupMenu) ne répond pas de
			# façon fiable au D-pad/A/B manette dans ce projet (testé : le
			# popup s'ouvre mais rien à l'intérieur ne réagit). Plutôt que de
			# compter dessus, on ne l'ouvre JAMAIS en manette : un menu
			# déroulant focus se pilote directement au D-pad gauche/droite
			# (cycle la valeur, sans jamais afficher de popup) — voir plus
			# bas. Ça évite complètement le popup cassé.
			if event.button_index == JOY_BUTTON_DPAD_LEFT or event.button_index == JOY_BUTTON_DPAD_RIGHT:
				var viewport := get_viewport()
				if viewport == null:
					return
				var focused := viewport.gui_get_focus_owner()
				if focused is OptionButton and focused.is_visible_in_tree() and not focused.disabled:
					var opt := focused as OptionButton
					if opt.item_count > 0:
						var step := -1 if event.button_index == JOY_BUTTON_DPAD_LEFT else 1
						var new_index := wrapi(opt.selected + step, 0, opt.item_count)
						viewport.set_input_as_handled()
						opt.select(new_index)
						opt.item_selected.emit(new_index)
				return

			if event.button_index == JOY_BUTTON_B:
				if page != "HOME":
					_show_home_deferred()
				return

			# START/Options : déclenche le CTA principal de l'écran actuel
			# (CRÉER LA PARTY, VALIDER MON CHOIX...), remplacé par ce prompt
			# tant qu'une manette est branchée (voir _apply_controller_primary_cta).
			if event.button_index == JOY_BUTTON_START:
				if _controller_primary_action.is_valid():
					get_viewport().set_input_as_handled()
					_controller_primary_action.call()
				return

			# Bouton A / bouton sud : valide toujours le contrôle actuellement
			# sélectionné — SAUF un OptionButton, dont le popup (cassé au
			# D-pad) est volontairement remplacé par le cycle gauche/droite
			# ci-dessus ; A n'a donc rien à y faire.
			if event.button_index == JOY_BUTTON_A:
				var viewport := get_viewport()
				if viewport == null:
					return

				var focused := viewport.gui_get_focus_owner()
				if focused is OptionButton:
					return
				if focused is BaseButton and focused.is_visible_in_tree() and not focused.disabled:
					# Marquer l'input AVANT le signal : le signal peut changer de scène
					# et supprimer ce menu pendant l'exécution.
					viewport.set_input_as_handled()
					(focused as BaseButton).emit_signal("pressed")


func _update_controller_connection(force: bool = false) -> void:
	var was_connected := controller_connected
	controller_connected = not Input.get_connected_joypads().is_empty()
	if not force and controller_connected == _last_controller_connected:
		return
	_last_controller_connected = controller_connected
	if controller_connected:
		print("ARENA RIFT : manette détectée")
		call_deferred("_focus_first_control")
	elif page == "SETTINGS":
		call_deferred("_show_settings")
	# Bascule les CTA principaux (CRÉER LA PARTY, VALIDER MON CHOIX...) entre
	# leur forme cliquable et leur prompt "APPUIE SUR START" sans attendre
	# une prochaine navigation, si le branchement/débranchement arrive en
	# cours d'écran.
	if controller_connected != was_connected:
		call_deferred("_refresh_controller_ctas")


## Construit le contour de surbrillance unique (voir _focus_ring), une fois
## pour toute la durée de vie du menu — repositionné chaque frame par
## _update_focus_ring() sur le contrôle actuellement focus.
func _build_focus_ring() -> void:
	_focus_ring = Panel.new()
	_focus_ring.name = "ControllerFocusRing"
	_focus_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus_ring.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color("fff2d4")
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	_focus_ring.add_theme_stylebox_override("panel", style)
	add_child(_focus_ring)


## Repositionne le contour de surbrillance sur le contrôle qui a
## actuellement le focus (manette ou clavier), ou le masque s'il n'y a pas
## de focus valide / pas de manette connectée.
func _update_focus_ring() -> void:
	if _focus_ring == null:
		return
	if not controller_connected:
		_focus_ring.visible = false
		return
	var viewport := get_viewport()
	if viewport == null:
		_focus_ring.visible = false
		return
	var focused := viewport.gui_get_focus_owner()
	if focused == null or not is_instance_valid(focused) or not (focused is Control) or not focused.is_visible_in_tree():
		_focus_ring.visible = false
		return
	var control := focused as Control
	var rect := control.get_global_rect()
	var pad := 5.0
	_focus_ring.global_position = rect.position - Vector2(pad, pad)
	_focus_ring.size = rect.size + Vector2(pad * 2.0, pad * 2.0)
	_focus_ring.visible = true


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
	if first == null:
		var arena_screen: Control = %ArenaModesScreen
		if arena_screen.visible:
			first = _find_first_focusable(arena_screen)
	if first != null:
		first.grab_focus()


## "xbox" ou "playstation" selon le nom rapporté par la première manette
## connectée — sert uniquement à choisir la bonne icône de bouton (A/✕,
## START/Options...), pas une détection exhaustive de tous les modèles.
func _controller_brand() -> String:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return "xbox"
	var joy_name := Input.get_joy_name(pads[0]).to_lower()
	for needle in ["sony", "playstation", "dualshock", "dualsense", "ps3", "ps4", "ps5"]:
		if needle in joy_name:
			return "playstation"
	return "xbox"


# =========================================================
# CTA PRINCIPAUX EN MANETTE (façon Rocket League) : le gros bouton cliquable
# d'un écran (CRÉER LA PARTY, VALIDER MON CHOIX...) disparaît complètement
# manette branchée, remplacé par un simple prompt "bouton START/Options" —
# non cliquable, déclenché en appuyant sur START n'importe où sur l'écran.
# Redevient un bouton normal cliquable dès que la manette est débranchée.
# =========================================================

## Callable appelée quand START/Options est pressé, tant qu'un écran avec un
## CTA principal actif est affiché. Réinitialisée par _clear() à chaque
## changement d'écran, reposée par _apply_controller_primary_cta().
var _controller_primary_action: Callable = Callable()

func _set_controller_primary_action(action: Callable) -> void:
	_controller_primary_action = action

func _clear_controller_primary_action() -> void:
	_controller_primary_action = Callable()


func _controller_start_icon_path() -> String:
	return ("res://assets/input_controler/PlayStation Series/Default/playstation5_button_options.png"
		if _controller_brand() == "playstation"
		else "res://assets/input_controler/Xbox Series/Default/xbox_button_start.png")


## Construit (une seule fois par bouton, mis en cache via set_meta) le prompt
## "icône START + texte" affiché à la place du bouton manette branchée.
func _build_controller_cta_prompt(button: Button) -> HBoxContainer:
	var prompt := HBoxContainer.new()
	prompt.name = "ControllerPrompt"
	prompt.alignment = BoxContainer.ALIGNMENT_CENTER
	prompt.add_theme_constant_override("separation", 12)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.visible = false

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.add_child(icon)

	var label := _label("", 17, Color("fff2d4"), Vector2.ZERO, Vector2(240, 36), HORIZONTAL_ALIGNMENT_LEFT)
	label.name = "Label"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_use_title_font(label)
	prompt.add_child(label)

	button.get_parent().add_child(prompt)
	button.set_meta("controller_prompt", prompt)
	return prompt


## Bascule `button` entre sa forme cliquable normale (clavier/souris) et un
## prompt "APPUIE SUR START" non cliquable (manette). `parent` doit déjà
## contenir `button` (ajouté avant cet appel). `label_text` s'affiche à côté
## de l'icône START ; `action` est ce que déclenche START tant que ce CTA
## est affiché.
func _apply_controller_primary_cta(button: Button, label_text: String, action: Callable) -> void:
	# get_meta(key, null) : passer littéralement null comme défaut ne suffit
	# pas à éviter l'erreur "no meta values" dans Godot 4 si la clé n'existe
	# pas encore (null est traité comme "pas de défaut fourni") — il faut
	# vérifier avec has_meta() d'abord.
	var prompt: Control = null
	if button.has_meta("controller_prompt"):
		prompt = button.get_meta("controller_prompt")
	if prompt == null or not is_instance_valid(prompt):
		prompt = _build_controller_cta_prompt(button)

	prompt.position = button.position
	prompt.size = button.size
	var prompt_label := prompt.get_node("Label") as Label
	prompt_label.text = label_text
	var prompt_icon := prompt.get_node("Icon") as TextureRect
	var icon_path := _controller_start_icon_path()
	if ResourceLoader.exists(icon_path):
		prompt_icon.texture = load(icon_path) as Texture2D

	if controller_connected:
		button.visible = false
		prompt.visible = true
		_set_controller_primary_action(action)
	else:
		button.visible = true
		prompt.visible = false


## Ré-applique le basculement CTA cliquable/prompt START sur l'écran
## actuellement affiché, sans attendre une prochaine navigation — utile
## quand la manette est branchée/débranchée en cours d'écran.
func _refresh_controller_ctas() -> void:
	var arena_screen: Control = %ArenaModesScreen
	if arena_screen.visible:
		_show_arena_modes()
	elif _lobby_active_screen:
		_build_hero_select_lobby_ui()


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

## Le rail, le cadre principal, les bordures dorées et les cartes
## Steam/Niveau sont maintenant de VRAIS nœuds dans scenes/main_menu.tscn
## (retrouvés ici par nom unique, ex. %MainFrame) plutôt que créés par ce
## script : tu peux donc les sélectionner et les déplacer/redimensionner
## directement dans l'éditeur Godot, sans repasser par moi à chaque
## ajustement. Cette fonction ne fait plus que leur appliquer un style
## (couleurs, police) et remplir les parties dynamiques (boutons de nav,
## texture des bordures, titre d'écran...).
func _build_shell() -> void:
	_apply_global_fonts()

	_build_ember_particles()

	var left_rail: Panel = %LeftRail
	left_rail.add_theme_stylebox_override("panel", _box(Color("0d0a07f0"), Color("4a3018"), 0, 1))

	var nav: VBoxContainer = %Nav
	for item in ["PLAY", "HEROES", "ARKANITES", "LOADOUT", "SETTINGS"]:
		var b := _aaa_nav_button(item, item == "PLAY")
		nav_buttons[item] = b
		b.pressed.connect(func(): _navigate_deferred(item))
		nav.add_child(b)

	_build_steam_profile()

	var frame: Panel = %MainFrame
	frame.add_theme_stylebox_override("panel", _rune_box(Color("110c07eb"), Color("6b4a24"), 2))

	title = %Title
	_use_title_font(title)

	content = %Content

	# %ArenaModesScreen est un nœud persistant (pas recréé à chaque
	# affichage) : son bouton retour ne se connecte donc qu'une seule fois
	# ici, plutôt qu'à chaque appel de _show_arena_modes() qui empilerait
	# les connexions et déclencherait plusieurs fois le callback par clic.
	var arena_back_btn: Button = %BackButton
	arena_back_btn.pressed.connect(_show_home)

	# Les 5 cartes de mode sont elles aussi des nœuds persistants de la
	# scène (visibles/éditables dans Godot) plutôt que recréées à chaque
	# affichage — on ne connecte leur clic qu'une fois ici.
	_arena_mode_card_buttons = {
		"DEATHMATCH": %DeathmatchCard,
		"1V1 DUEL": %Duel1v1Card,
		"2V2 CLASH": %Clash2v2Card,
		"3V3 RIVALRY": %Rivalry3v3Card,
		"CUSTOM GAME": %CustomGameCard,
	}
	for mode in _arena_mode_card_buttons:
		var card_btn: Button = _arena_mode_card_buttons[mode]
		card_btn.pressed.connect(func():
			selected_mode = mode
			_show_arena_modes_deferred()
		)


const FONT_CINZEL_BOLD := "res://assets/menu_design/font/Cintel/static/Cinzel-Bold.ttf"
const FONT_CINZEL_SEMIBOLD := "res://assets/menu_design/font/Cintel/static/Cinzel-SemiBold.ttf"
const FONT_CINZEL_DECORATIVE_BOLD := "res://assets/menu_design/font/Cinzel_Decorative/CinzelDecorative-Bold.ttf"
const FONT_INTER_REGULAR := "res://assets/menu_design/font/Inter/static/Inter_18pt-Regular.ttf"
const FONT_INTER_MEDIUM := "res://assets/menu_design/font/Inter/static/Inter_18pt-Medium.ttf"

var _font_cache: Dictionary = {}

func _font(path: String) -> Font:
	if _font_cache.has(path):
		return _font_cache[path]
	var f := load(path) as FontFile
	_font_cache[path] = f
	if f == null:
		push_warning("Police introuvable : " + path)
	return f


## Applique Inter comme police par défaut de tout le menu (thème racine) :
## couvre automatiquement les petits textes (XP, Steam, stats...) sans
## avoir à toucher chaque _label(). Les titres/éléments premium reçoivent
## ensuite Cinzel / Cinzel Decorative au cas par cas via _use_title_font()
## et _use_decorative_font() sur les Controls concernés.
func _apply_global_fonts() -> void:
	var body_font := _font(FONT_INTER_REGULAR)
	if body_font == null:
		return
	var menu_theme := Theme.new()
	menu_theme.default_font = body_font
	theme = menu_theme


## Cinzel (empattements, majuscules) pour les titres d'écran, les boutons
## de mode/nav et tout ce qui doit avoir le côté "premium médiéval".
func _use_title_font(control: Control, weight_semibold: bool = false) -> void:
	var f := _font(FONT_CINZEL_SEMIBOLD if weight_semibold else FONT_CINZEL_BOLD)
	if f != null:
		control.add_theme_font_override("font", f)


## Cinzel Decorative pour les noms de héros et titres de cartes très mis en
## avant, plus ornée que Cinzel simple.
func _use_decorative_font(control: Control) -> void:
	var f := _font(FONT_CINZEL_DECORATIVE_BOLD)
	if f != null:
		control.add_theme_font_override("font", f)


var _border_texture_cache: Dictionary = {}

## Certaines bordures (bordure_menu.png, bordure_steam.png, bordure_level.png)
## ont un halo à alpha très faible qui traîne sur presque tout le canevas —
## Image.get_used_rect() seul (alpha > 0) ne l'exclut pas et laissait le
## trait doré flotter loin des bords réels du panneau une fois étiré. On
## calcule donc la bbox avec un vrai seuil d'alpha (40/255), sur une version
## réduite de l'image pour rester rapide au démarrage.
func _alpha_threshold_rect(image: Image, threshold: int) -> Rect2i:
	var src_w := image.get_width()
	var src_h := image.get_height()
	var scale := 0.15
	var small_w := maxi(1, int(src_w * scale))
	var small_h := maxi(1, int(src_h * scale))
	var small := image.duplicate() as Image
	small.resize(small_w, small_h, Image.INTERPOLATE_BILINEAR)

	var min_x := small_w
	var min_y := small_h
	var max_x := -1
	var max_y := -1
	for y in small_h:
		for x in small_w:
			if small.get_pixel(x, y).a8 >= threshold:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)

	if max_x < 0:
		return Rect2i(0, 0, src_w, src_h)

	var inv := 1.0 / scale
	var rx0 := clampi(int(min_x * inv), 0, src_w)
	var ry0 := clampi(int(min_y * inv), 0, src_h)
	var rx1 := clampi(int((max_x + 1) * inv), 0, src_w)
	var ry1 := clampi(int((max_y + 1) * inv), 0, src_h)
	return Rect2i(rx0, ry0, rx1 - rx0, ry1 - ry0)


func _cropped_border_texture(path: String) -> Texture2D:
	if _border_texture_cache.has(path):
		return _border_texture_cache[path]
	var base := load(path) as Texture2D
	if base == null:
		return null
	var image := base.get_image()
	var result: Texture2D = base
	if image != null:
		var used := _alpha_threshold_rect(image, 40)
		if used.size.x > 0 and used.size.y > 0:
			var cropped := image.get_region(used)
			if cropped != null and cropped.get_width() > 0 and cropped.get_height() > 0:
				result = ImageTexture.create_from_image(cropped)
	_border_texture_cache[path] = result
	return result


## Pose une bordure décorative (image fournie par le graphiste, transparente
## au centre) par-dessus un panneau créé dynamiquement (écrans reconstruits
## à chaque navigation, ex. le panneau de détails du mode), étirée
## exactement sur sa taille. Les bordures de la coquille statique du menu
## (rail, cadre, Steam, Niveau) sont maintenant collées directement dans
## scenes/main_menu.tscn (textures déjà recadrées) pour rester visibles à
## l'édition — celle-ci ne sert donc plus qu'aux écrans reconstruits.
func _add_border_overlay(parent: Control, path: String) -> void:
	var tex := _cropped_border_texture(path)
	if tex == null:
		push_warning("Bordure introuvable : " + path)
		return
	var overlay := TextureRect.new()
	overlay.position = Vector2.ZERO
	overlay.size = parent.size
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.texture = tex
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(overlay)


func _build_ember_particles() -> void:
	var layer: Control = %EmberLayer

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


## Cartes Steam et Niveau : nœuds réels dans scenes/main_menu.tscn (retrouvés
## par nom unique) — déplaçables/redimensionnables directement dans
## l'éditeur. Ici on ne fait plus qu'appliquer le style et remplir/mettre à
## jour le contenu dynamique (avatar, pseudo, XP...).
func _build_steam_profile() -> void:
	steam_profile = %SteamProfile
	steam_profile.add_theme_stylebox_override("panel", _simple_box(Color("140f09eb"), Color("6b4a24"), 12))

	var avatar_frame: Panel = %AvatarFrame
	avatar_frame.add_theme_stylebox_override("panel", _simple_box(Color("241a0d"), Color("e8b656"), 12))

	steam_avatar = %Avatar
	steam_avatar_fallback = %AvatarFallback

	steam_name_label = %NameLabel
	steam_status_label = %StatusLabel

	# Carte "Niveau" séparée, juste à gauche de la carte Steam, sur la même
	# rangée (même y, même hauteur) pour ne jamais empiéter sur le cadre
	# principal en dessous.
	var level_panel: Panel = %LevelPanel
	level_panel.add_theme_stylebox_override("panel", _simple_box(Color("140f09eb"), Color("6b4a24"), 12))

	level_label = %LevelLabel
	xp_label = %XpLabel
	level_progress_fill = %ProgressFill

	_update_level_display()
	if not PlayerProgress.xp_changed.is_connected(_on_player_xp_changed):
		PlayerProgress.xp_changed.connect(_on_player_xp_changed)


func _on_player_xp_changed(_xp: int, _level: int) -> void:
	_update_level_display()


func _update_level_display() -> void:
	if level_label == null or not is_instance_valid(level_label):
		return
	var current_level: int = PlayerProgress.get_level()
	level_label.text = "NIVEAU %d" % current_level
	if xp_label != null and is_instance_valid(xp_label):
		if current_level >= PlayerProgress.MAX_LEVEL:
			xp_label.text = "MAX"
		else:
			xp_label.text = "%d / %d XP" % [PlayerProgress.get_xp(), PlayerProgress.xp_to_next_level(current_level)]
	if level_progress_fill == null or not is_instance_valid(level_progress_fill):
		return
	if current_level >= PlayerProgress.MAX_LEVEL:
		level_progress_fill.size.x = LEVEL_BAR_WIDTH
		return
	var xp_needed: int = PlayerProgress.xp_to_next_level(current_level)
	var ratio: float = clampf(float(PlayerProgress.get_xp()) / float(maxi(1, xp_needed)), 0.0, 1.0)
	level_progress_fill.size.x = LEVEL_BAR_WIDTH * ratio


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
	elif item == "LOADOUT":
		_show_loadout()
	else:
		_show_placeholder(item)
	call_deferred("_focus_first_control")


func _set_nav_active(active_item: String) -> void:
	for item in nav_buttons.keys():
		var b := nav_buttons[item] as Button
		if b == null:
			continue
		var active: bool = (item == active_item)
		b.text = ("◆  " if active else "     ") + item
		b.add_theme_color_override("font_color", Color("fff2d4") if active else Color("c4b48a"))
		_apply_nav_button_style(b, active)


# =========================================================
# HOME
# =========================================================

## Écran d'accueil PLAY : choix de la catégorie de jeu (Multijoueur Arena,
## Co-op Donjon, Impostor, Hide & Seek). Seule la première catégorie est
## implémentée pour l'instant, les autres ouvrent un écran "à venir".
func _show_home() -> void:
	_clear()
	title.text = "PLAY"

	var categories_box := VBoxContainer.new()
	categories_box.custom_minimum_size = Vector2(600, 0)
	# categories_box (contrairement à modes_box sur l'écran MULTIJOUEUR
	# ARENA, contraint par le panneau latéral juste à côté) n'a pas de
	# voisin et s'étire donc sur toute la largeur de `content` (946px) — les
	# bannières doivent en tenir compte pour leurs marges de texte, d'où le
	# paramètre card_width plutôt qu'une largeur supposée fixe.
	categories_box.add_theme_constant_override("separation", 10)
	content.add_child(categories_box)
	categories_box.add_child(_label("SÉLECTIONNE UN MODE", 11, Color("8a7550"), Vector2.ZERO, Vector2(500, 22)))

	var category_card_width := 946.0

	var arena_card := _mode_card("MULTIJOUEUR ARENA", false, MODE_CARD_HEIGHT_CATEGORY, category_card_width)
	arena_card.pressed.connect(_show_arena_modes)
	categories_box.add_child(arena_card)

	var coop_card := _mode_card("CO-OP DONJON", false, MODE_CARD_HEIGHT_CATEGORY, category_card_width)
	coop_card.pressed.connect(func():
		_show_play_placeholder("CO-OP DONJON", "Mode coopératif roguelike en développement. Explorez un donjon généré à plusieurs contre des vagues d'ennemis — revenez bientôt !")
	)
	categories_box.add_child(coop_card)

	var impostor_card := _mode_card("IMPOSTOR", false, MODE_CARD_HEIGHT_CATEGORY, category_card_width)
	impostor_card.pressed.connect(func():
		_show_play_placeholder("IMPOSTOR", "Mode social façon Among Us en développement. Démasquez les imposteurs avant qu'ils ne sabotent la partie — revenez bientôt !")
	)
	categories_box.add_child(impostor_card)

	var hideseek_card := _mode_card("HIDE & SEEK", false, MODE_CARD_HEIGHT_CATEGORY, category_card_width)
	hideseek_card.pressed.connect(func():
		_show_play_placeholder("HIDE & SEEK", "Prop Hunt en développement. Cachez-vous en objet du décor ou traquez ceux qui s'y dissimulent — revenez bientôt !")
	)
	categories_box.add_child(hideseek_card)


## Écran de sélection du mode Arena (Deathmatch / 1v1 / 2v2 / 3v3 / Custom
## Game) — anciennement l'écran PLAY racine, maintenant sous-écran de
## "MULTIJOUEUR ARENA". Son ossature (bouton retour, panneau de détails,
## bordure...) vit dans scenes/main_menu.tscn (%ArenaModesScreen) et est
## donc déplaçable/redimensionnable directement dans l'éditeur ; cette
## fonction ne fait qu'afficher cet écran et remplir ses parties dynamiques
## (cartes de mode, texte du panneau de détails).
func _show_arena_modes() -> void:
	_clear()
	title.text = "MULTIJOUEUR ARENA"

	var screen: Control = %ArenaModesScreen
	screen.visible = true

	var transient_label: Label = %TransientMessage
	transient_label.text = _transient_status_message
	_transient_status_message = ""

	for mode in ["DEATHMATCH", "1V1 DUEL", "2V2 CLASH", "3V3 RIVALRY", "CUSTOM GAME"]:
		var card: Button = _arena_mode_card_buttons[mode]
		_apply_mode_card_style(card, mode, mode == selected_mode)

	var details: Dictionary = MODE_DETAILS.get(selected_mode, {})
	var mode_accent: Color = _mode_accent(selected_mode)

	var mode_name_label: Label = %ModeNameLabel
	mode_name_label.text = selected_mode
	mode_name_label.add_theme_color_override("font_color", mode_accent)
	_use_title_font(mode_name_label)

	# autowrap_mode seul ne suffisait pas ici (le texte débordait toujours
	# sur une seule ligne) : on découpe nous-mêmes le texte en lignes avant
	# de l'assigner, ce qui garantit le retour à la ligne quel que soit le
	# comportement du Label.
	var desc_label: Label = %DescLabel
	desc_label.text = _wrap_text_lines(str(details.get("desc", "")), 32)

	var players_value: Label = %PlayersValueLabel
	players_value.text = str(details.get("players", ""))

	var map_value: Label = %MapValueLabel
	map_value.text = str(details.get("map", ""))

	var launch: Button = %LaunchButton
	var launch_text := "SALON CUSTOM GAME" if selected_mode == "CUSTOM GAME" else "CRÉER LA PARTY"
	var launch_action: Callable = _show_custom_game_home if selected_mode == "CUSTOM GAME" else _create_party
	launch.text = launch_text
	_apply_banner_launch_style(launch)
	_apply_banner_text_style(launch, 16)
	if launch.pressed.is_connected(_show_custom_game_home):
		launch.pressed.disconnect(_show_custom_game_home)
	if launch.pressed.is_connected(_create_party):
		launch.pressed.disconnect(_create_party)
	launch.pressed.connect(launch_action)
	# Manette branchée : remplace le bouton cliquable par un prompt "START"
	# façon Rocket League (appelé après le connect ci-dessus, dont il a
	# besoin pour l'action START).
	_apply_controller_primary_cta(launch, launch_text, launch_action)

	var bottom_label: Label = %BottomLabel
	bottom_label.text = "MODE ACTIF  •  %s     |     LOCAL / PRACTICE" % selected_mode


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
	var steam_manager: Node = get_node_or_null("/root/SteamManager")
	if steam_manager != null:
		selected_mode = str(steam_manager.get("pending_party_mode"))
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
		
# =========================================================
# CUSTOM GAME : salon à code (façon Among Us)
# =========================================================

func _my_steam_id_str() -> String:
	var steam_manager: Node = get_node_or_null("/root/SteamManager")
	if steam_manager == null:
		return ""
	return str(int(steam_manager.get("steam_id")))


func _my_steam_name() -> String:
	var steam_manager: Node = get_node_or_null("/root/SteamManager")
	if steam_manager == null:
		return "Joueur"
	var name: String = str(steam_manager.get("steam_username"))
	return name if name != "" else "Joueur"


func _show_custom_game_home() -> void:
	_clear()
	title.text = "CUSTOM GAME"

	var wrapper := VBoxContainer.new()
	wrapper.custom_minimum_size = Vector2(560, 360)
	wrapper.add_theme_constant_override("separation", 14)
	content.add_child(wrapper)

	var panel := _panel(Vector2.ZERO, Vector2(560, 340), Color("140f09eb"), Color("6b4a24"), 16)
	panel.custom_minimum_size = Vector2(560, 340)
	wrapper.add_child(panel)

	panel.add_child(_label("CUSTOM GAME", 22, Color("f3e6c8"), Vector2(24, 20), Vector2(400, 32)))
	panel.add_child(_label(
		"Crée un salon et partage son code, ou entre le code d'un ami — comme dans Among Us, pas besoin d'être amis Steam.",
		10, Color("8a7550"), Vector2(24, 55), Vector2(510, 34)
	))

	custom_room_home_status_label = _label("", 10, Color("ff9d9d"), Vector2(24, 92), Vector2(510, 20))
	panel.add_child(custom_room_home_status_label)

	var create_btn := _button("CRÉER UN SALON", Vector2(510, 48), true)
	create_btn.position = Vector2(24, 120)
	create_btn.pressed.connect(_create_custom_room)
	panel.add_child(create_btn)

	panel.add_child(_label("— OU —", 10, Color("7a6a4a"), Vector2(24, 182), Vector2(510, 18), HORIZONTAL_ALIGNMENT_CENTER))

	custom_room_join_input = LineEdit.new()
	custom_room_join_input.position = Vector2(24, 208)
	custom_room_join_input.size = Vector2(300, 44)
	custom_room_join_input.placeholder_text = "CODE DU SALON"
	custom_room_join_input.max_length = 5
	custom_room_join_input.add_theme_font_size_override("font_size", 18)
	panel.add_child(custom_room_join_input)

	var join_btn := _button("REJOINDRE", Vector2(200, 44), true)
	join_btn.position = Vector2(334, 208)
	join_btn.pressed.connect(_join_custom_room)
	panel.add_child(join_btn)

	var back_btn := _button("RETOUR", Vector2(510, 40), false)
	back_btn.position = Vector2(24, 272)
	back_btn.pressed.connect(_show_arena_modes_deferred)
	panel.add_child(back_btn)


func _create_custom_room() -> void:
	if custom_room_http == null:
		return
	custom_room_pending_action = "create_room"
	var payload := {"steam_id": _my_steam_id_str(), "name": _my_steam_name()}
	var error := custom_room_http.request(
		MATCHMAKING_BASE_URL + "/rooms",
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if error != OK:
		custom_room_pending_action = ""
		_set_custom_room_home_error("ERREUR RÉSEAU : %s" % error)


func _join_custom_room() -> void:
	if custom_room_http == null or custom_room_join_input == null:
		return
	var code := custom_room_join_input.text.strip_edges().to_upper()
	if code.length() < 4:
		_set_custom_room_home_error("CODE INVALIDE")
		return
	custom_room_pending_action = "join_room"
	var payload := {"steam_id": _my_steam_id_str(), "name": _my_steam_name()}
	var error := custom_room_http.request(
		MATCHMAKING_BASE_URL + "/rooms/" + code + "/join",
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if error != OK:
		custom_room_pending_action = ""
		_set_custom_room_home_error("ERREUR RÉSEAU : %s" % error)


func _set_custom_room_home_error(text: String) -> void:
	if custom_room_home_status_label != null and is_instance_valid(custom_room_home_status_label):
		custom_room_home_status_label.text = text


func _on_custom_room_action_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var action := custom_room_pending_action
	custom_room_pending_action = ""
	var parsed = JSON.parse_string(body.get_string_from_utf8())

	if action == "create_room" or action == "join_room":
		if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300 or typeof(parsed) != TYPE_DICTIONARY:
			var detail := ""
			if typeof(parsed) == TYPE_DICTIONARY:
				detail = str(parsed.get("detail", ""))
			_set_custom_room_home_error(detail if detail != "" else "SALON INTROUVABLE OU SERVEUR INJOIGNABLE")
			return
		custom_room_state = parsed as Dictionary
		custom_room_code = str(custom_room_state.get("code", ""))
		_custom_room_last_version = int(custom_room_state.get("version", 0))
		_custom_room_connect_triggered = false
		_show_custom_room_lobby()
		if custom_room_poll_timer != null and custom_room_poll_timer.is_stopped():
			custom_room_poll_timer.start()
		return

	# "room_settings" / "room_team" / "room_start"
	if typeof(parsed) == TYPE_DICTIONARY and result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		_apply_custom_room_state(parsed as Dictionary)


func _poll_custom_room() -> void:
	if custom_room_code == "" or custom_room_poll_http == null:
		return
	if custom_room_poll_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	custom_room_poll_http.request(MATCHMAKING_BASE_URL + "/rooms/" + custom_room_code)


func _on_custom_room_poll_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if custom_room_code == "":
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		return
	if response_code == 404:
		# Salon expiré/fermé côté serveur : on ne laisse personne planté à
		# poller un salon mort.
		_leave_custom_room_local_only()
		_show_custom_game_home()
		_set_custom_room_home_error("LE SALON A ÉTÉ FERMÉ")
		return
	if response_code < 200 or response_code >= 300:
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_apply_custom_room_state(parsed as Dictionary)
	_check_custom_room_server_ready()


## N'applique une réponse de salon que si elle est au moins aussi récente
## que la dernière déjà appliquée — voir le commentaire sur
## _custom_room_last_version pour le problème que ça évite.
func _apply_custom_room_state(state: Dictionary) -> void:
	var version := int(state.get("version", 0))
	if version < _custom_room_last_version:
		return
	_custom_room_last_version = version
	custom_room_state = state
	_refresh_custom_room_lobby_ui()


func _is_custom_room_host() -> bool:
	return str(custom_room_state.get("host_steam_id", "")) == _my_steam_id_str()


func _show_custom_room_lobby() -> void:
	_clear()
	title.text = "CUSTOM GAME"

	var wrapper := VBoxContainer.new()
	wrapper.custom_minimum_size = Vector2(980, 560)
	wrapper.add_theme_constant_override("separation", 12)
	content.add_child(wrapper)

	custom_room_panel = _panel(Vector2.ZERO, Vector2(980, 520), Color("140f09eb"), Color("6b4a24"), 16)
	custom_room_panel.custom_minimum_size = Vector2(980, 520)
	wrapper.add_child(custom_room_panel)

	custom_room_panel.add_child(_label("SALON", 9, Color("7a6a4a"), Vector2(24, 18), Vector2(200, 16)))
	custom_room_panel.add_child(_label(custom_room_code, 30, Color("f4c977"), Vector2(24, 34), Vector2(220, 40)))

	var copy_btn := _button("COPIER LE CODE", Vector2(150, 32), false)
	copy_btn.position = Vector2(24, 78)
	copy_btn.pressed.connect(func(): DisplayServer.clipboard_set(custom_room_code))
	custom_room_panel.add_child(copy_btn)

	custom_room_status_label = _label("", 10, Color("6fb88a"), Vector2(210, 22), Vector2(400, 20))
	custom_room_panel.add_child(custom_room_status_label)

	var is_host := _is_custom_room_host()

	custom_room_panel.add_child(_label("MAP", 9, Color("7a6a4a"), Vector2(230, 60), Vector2(150, 16)))
	custom_room_map_option = OptionButton.new()
	custom_room_map_option.focus_mode = Control.FOCUS_ALL
	custom_room_map_option.position = Vector2(230, 78)
	custom_room_map_option.size = Vector2(240, 34)
	for map_def in CUSTOM_ROOM_MAPS:
		custom_room_map_option.add_item(map_def[1])
	custom_room_map_option.disabled = not is_host
	custom_room_map_option.item_selected.connect(_on_custom_room_map_selected)
	custom_room_panel.add_child(custom_room_map_option)

	custom_room_panel.add_child(_label("MODE", 9, Color("7a6a4a"), Vector2(490, 60), Vector2(150, 16)))
	custom_room_mode_option = OptionButton.new()
	custom_room_mode_option.focus_mode = Control.FOCUS_ALL
	custom_room_mode_option.position = Vector2(490, 78)
	custom_room_mode_option.size = Vector2(280, 34)
	for mode_def in CUSTOM_ROOM_MODES:
		custom_room_mode_option.add_item(mode_def[1])
	custom_room_mode_option.disabled = not is_host
	custom_room_mode_option.item_selected.connect(_on_custom_room_mode_selected)
	custom_room_panel.add_child(custom_room_mode_option)

	custom_room_random_button = _button("☐ RÉPARTITION ALÉATOIRE", Vector2(280, 34), false)
	custom_room_random_button.position = Vector2(24, 122)
	custom_room_random_button.disabled = not is_host
	custom_room_random_button.pressed.connect(_toggle_custom_room_random)
	custom_room_panel.add_child(custom_room_random_button)

	# --- Les deux blocs d'équipe, façon Among Us : ASTRAL à gauche, ARCANE
	# à droite, chacun listant les joueurs qui l'ont rejoint. ---
	custom_room_astral_panel = _panel(Vector2(24, 170), Vector2(455, 260), Color("101b26"), Color("2f6f9c"), 12)
	custom_room_panel.add_child(custom_room_astral_panel)
	custom_room_astral_panel.add_child(_label("ASTRAL", 16, Color("78cfff"), Vector2(16, 12), Vector2(200, 26)))
	var astral_join_btn := _button("REJOINDRE", Vector2(140, 32), false)
	astral_join_btn.position = Vector2(299, 12)
	astral_join_btn.pressed.connect(func(): _pick_custom_room_team("ASTRAL"))
	custom_room_astral_panel.add_child(astral_join_btn)
	custom_room_astral_box = VBoxContainer.new()
	custom_room_astral_box.position = Vector2(16, 52)
	custom_room_astral_box.size = Vector2(423, 200)
	custom_room_astral_box.add_theme_constant_override("separation", 6)
	custom_room_astral_panel.add_child(custom_room_astral_box)

	custom_room_arcane_panel = _panel(Vector2(501, 170), Vector2(455, 260), Color("1f1226"), Color("8a4fae"), 12)
	custom_room_panel.add_child(custom_room_arcane_panel)
	custom_room_arcane_panel.add_child(_label("ARCANE", 16, Color("d29cff"), Vector2(16, 12), Vector2(200, 26)))
	var arcane_join_btn := _button("REJOINDRE", Vector2(140, 32), false)
	arcane_join_btn.position = Vector2(299, 12)
	arcane_join_btn.pressed.connect(func(): _pick_custom_room_team("ARCANE"))
	custom_room_arcane_panel.add_child(arcane_join_btn)
	custom_room_arcane_box = VBoxContainer.new()
	custom_room_arcane_box.position = Vector2(16, 52)
	custom_room_arcane_box.size = Vector2(423, 200)
	custom_room_arcane_box.add_theme_constant_override("separation", 6)
	custom_room_arcane_panel.add_child(custom_room_arcane_box)

	custom_room_unassigned_label = _label("SANS ÉQUIPE", 9, Color("7a6a4a"), Vector2(24, 436), Vector2(200, 16))
	custom_room_panel.add_child(custom_room_unassigned_label)
	custom_room_unassigned_box = VBoxContainer.new()
	custom_room_unassigned_box.position = Vector2(24, 454)
	custom_room_unassigned_box.size = Vector2(700, 40)
	custom_room_unassigned_box.add_theme_constant_override("separation", 6)
	custom_room_panel.add_child(custom_room_unassigned_box)

	if is_host:
		custom_room_launch_button = _button("LANCER LA PARTIE", Vector2(220, 44), true)
		custom_room_launch_button.position = Vector2(740, 440)
		custom_room_launch_button.pressed.connect(_start_custom_room)
		custom_room_panel.add_child(custom_room_launch_button)
	else:
		custom_room_panel.add_child(_label(
			"En attente que le host lance la partie...",
			10, Color("8a7550"), Vector2(740, 440), Vector2(220, 40)
		))

	var leave_btn := _button("QUITTER LE SALON", Vector2(220, 36), false)
	leave_btn.position = Vector2(740, 486)
	leave_btn.pressed.connect(_leave_custom_room)
	custom_room_panel.add_child(leave_btn)

	_refresh_custom_room_lobby_ui()


func _refresh_custom_room_lobby_ui() -> void:
	if custom_room_panel == null or not is_instance_valid(custom_room_panel):
		return

	var members: Array = custom_room_state.get("members", [])
	var mode: String = str(custom_room_state.get("mode", "TEAM"))
	var map_key: String = str(custom_room_state.get("map", "default"))
	var random_teams: bool = bool(custom_room_state.get("random_teams", false))
	var is_host := _is_custom_room_host()

	if custom_room_status_label != null and is_instance_valid(custom_room_status_label):
		custom_room_status_label.text = "%d JOUEUR(S)" % members.size()

	# On ne touche à .select() que si la valeur affichée diffère vraiment de
	# l'état serveur, et jamais pendant que le menu déroulant est ouvert :
	# sinon, le poll (toutes les 1s) rappelait .select() avec l'ANCIENNE
	# valeur pendant que le joueur choisissait tout juste la nouvelle,
	# fermant/perturbant le popup avant que son clic ne soit pris en compte
	# — la sélection semblait alors "ne jamais se faire".
	if custom_room_map_option != null and is_instance_valid(custom_room_map_option):
		if not custom_room_map_option.get_popup().visible:
			for i in CUSTOM_ROOM_MAPS.size():
				if CUSTOM_ROOM_MAPS[i][0] == map_key:
					if custom_room_map_option.selected != i:
						custom_room_map_option.select(i)
					break
		custom_room_map_option.disabled = not is_host

	if custom_room_mode_option != null and is_instance_valid(custom_room_mode_option):
		if not custom_room_mode_option.get_popup().visible:
			for i in CUSTOM_ROOM_MODES.size():
				if CUSTOM_ROOM_MODES[i][0] == mode:
					if custom_room_mode_option.selected != i:
						custom_room_mode_option.select(i)
					break
		custom_room_mode_option.disabled = not is_host

	var team_mode := mode == "TEAM"
	if custom_room_random_button != null and is_instance_valid(custom_room_random_button):
		custom_room_random_button.visible = team_mode
		custom_room_random_button.text = "☑ RÉPARTITION ALÉATOIRE" if random_teams else "☐ RÉPARTITION ALÉATOIRE"
		custom_room_random_button.disabled = not is_host

	# Hors mode Équipes, les blocs ASTRAL/ARCANE (fond coloré compris, pas
	# seulement la liste de joueurs qu'ils contiennent) doivent disparaître
	# entièrement : les laisser visibles sans contenu faisait flotter la
	# liste FFA par-dessus les deux blocs encore affichés, donnant
	# l'impression que les pseudos "débordaient" sur les deux barres.
	if custom_room_astral_panel != null and is_instance_valid(custom_room_astral_panel):
		custom_room_astral_panel.visible = team_mode
	if custom_room_arcane_panel != null and is_instance_valid(custom_room_arcane_panel):
		custom_room_arcane_panel.visible = team_mode
	if custom_room_unassigned_label != null and is_instance_valid(custom_room_unassigned_label):
		custom_room_unassigned_label.visible = team_mode

	for box in [custom_room_astral_box, custom_room_arcane_box, custom_room_unassigned_box]:
		if box != null and is_instance_valid(box):
			box.visible = team_mode
			for child in box.get_children():
				child.queue_free()

	if custom_room_launch_button != null and is_instance_valid(custom_room_launch_button):
		var status := str(custom_room_state.get("status", "open"))
		custom_room_launch_button.disabled = status != "open"
		custom_room_launch_button.text = "DÉMARRAGE..." if status != "open" else "LANCER LA PARTIE"

	if not team_mode:
		# Mode FFA/Découverte : une seule liste à plat, pas de camp à choisir.
		if custom_room_ffa_box == null or not is_instance_valid(custom_room_ffa_box):
			custom_room_ffa_box = VBoxContainer.new()
			custom_room_ffa_box.position = Vector2(24, 170)
			custom_room_ffa_box.size = Vector2(932, 250)
			custom_room_ffa_box.add_theme_constant_override("separation", 6)
			custom_room_panel.add_child(custom_room_ffa_box)
		custom_room_ffa_box.visible = true
		for child in custom_room_ffa_box.get_children():
			child.queue_free()
		for member in members:
			custom_room_ffa_box.add_child(_custom_room_member_row(member))
		return
	elif custom_room_ffa_box != null and is_instance_valid(custom_room_ffa_box):
		custom_room_ffa_box.visible = false

	for member in members:
		var team: String = str(member.get("team", ""))
		var row := _custom_room_member_row(member)
		if team == "ASTRAL" and custom_room_astral_box != null and is_instance_valid(custom_room_astral_box):
			custom_room_astral_box.add_child(row)
		elif team == "ARCANE" and custom_room_arcane_box != null and is_instance_valid(custom_room_arcane_box):
			custom_room_arcane_box.add_child(row)
		elif custom_room_unassigned_box != null and is_instance_valid(custom_room_unassigned_box):
			custom_room_unassigned_box.add_child(row)


func _custom_room_member_row(member: Dictionary) -> Control:
	var row := _panel(Vector2.ZERO, Vector2(420, 32), Color("1a140b"), Color("4a3018"), 6)
	row.custom_minimum_size = Vector2(420, 32)
	var is_me := str(member.get("steam_id", "")) == _my_steam_id_str()
	var is_room_host := str(member.get("steam_id", "")) == str(custom_room_state.get("host_steam_id", ""))
	var display_name: String = str(member.get("name", "Joueur"))
	if is_room_host:
		display_name += "  •  HOST"
	row.add_child(_label(
		display_name, 11,
		Color("f4c977") if is_me else Color("f3e6c8"),
		Vector2(12, 6), Vector2(400, 20)
	))
	return row


func _on_custom_room_map_selected(index: int) -> void:
	if not _is_custom_room_host() or index < 0 or index >= CUSTOM_ROOM_MAPS.size():
		return
	_send_custom_room_settings({"map": CUSTOM_ROOM_MAPS[index][0]})


func _on_custom_room_mode_selected(index: int) -> void:
	if not _is_custom_room_host() or index < 0 or index >= CUSTOM_ROOM_MODES.size():
		return
	_send_custom_room_settings({"mode": CUSTOM_ROOM_MODES[index][0]})


func _toggle_custom_room_random() -> void:
	if not _is_custom_room_host():
		return
	var current := bool(custom_room_state.get("random_teams", false))
	_send_custom_room_settings({"random_teams": not current})


func _send_custom_room_settings(fields: Dictionary) -> void:
	if custom_room_http == null or custom_room_code == "":
		return
	var payload := {"steam_id": _my_steam_id_str()}
	for key in fields.keys():
		payload[key] = fields[key]
	custom_room_pending_action = "room_settings"
	custom_room_http.request(
		MATCHMAKING_BASE_URL + "/rooms/" + custom_room_code + "/settings",
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)


func _pick_custom_room_team(team: String) -> void:
	if custom_room_http == null or custom_room_code == "":
		return
	custom_room_pending_action = "room_team"
	var payload := {"steam_id": _my_steam_id_str(), "team": team}
	custom_room_http.request(
		MATCHMAKING_BASE_URL + "/rooms/" + custom_room_code + "/team",
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)


## Lancement par le host : l'assignation finale des camps (aléatoire ou
## choix individuels) est calculée côté service de matchmaking (source de
## vérité partagée par tout le monde), pas ici — on se contente de demander
## le lancement et de laisser le polling détecter le serveur une fois prêt.
func _start_custom_room() -> void:
	if not _is_custom_room_host() or custom_room_http == null or custom_room_code == "":
		return
	custom_room_pending_action = "room_start"
	var payload := {"steam_id": _my_steam_id_str()}
	custom_room_http.request(
		MATCHMAKING_BASE_URL + "/rooms/" + custom_room_code + "/start",
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if custom_room_status_label != null and is_instance_valid(custom_room_status_label):
		custom_room_status_label.text = "DÉMARRAGE DU SERVEUR..."


## Surveille l'apparition d'un serveur "online" dans l'état du salon et
## connecte le joueur local dès que c'est le cas — le polling continu (pas
## un mécanisme à part) fait à la fois vivre le lobby ET détecter le
## lancement, chez tous les membres y compris le host.
func _check_custom_room_server_ready() -> void:
	if _custom_room_connect_triggered or matchmaking_connecting:
		return
	var server = custom_room_state.get("server", null)
	if typeof(server) != TYPE_DICTIONARY:
		return
	var server_dict: Dictionary = server
	if str(server_dict.get("status", "")) != "online":
		return
	var ip := str(server_dict.get("ip", ""))
	var port := int(server_dict.get("port", 0))
	var match_id := str(server_dict.get("match_id", ""))
	if ip == "" or port <= 0:
		return

	var teams: Dictionary = server_dict.get("teams", {}) if typeof(server_dict.get("teams", {})) == TYPE_DICTIONARY else {}
	var my_team: String = str(teams.get(_my_steam_id_str(), ""))

	_custom_room_connect_triggered = true
	if custom_room_poll_timer != null:
		custom_room_poll_timer.stop()

	var network_node: Node = get_node_or_null("/root/Network")
	if network_node != null:
		network_node.set("pending_custom_team", my_team)

	var room_mode := str(custom_room_state.get("mode", "TEAM"))
	if room_mode == "FFA":
		selected_mode = "CUSTOM DEATHMATCH"
	elif room_mode == "EXPLORE":
		selected_mode = "CUSTOM EXPLORE"
	else:
		selected_mode = "CUSTOM GAME"

	match str(custom_room_state.get("map", "default")):
		"1v1":
			pending_arena_scene_path = "res://scenes/Arena1v1.tscn"
		"labyrinth":
			pending_arena_scene_path = "res://scenes/ArenaLabyrinth.tscn"
		_:
			pending_arena_scene_path = "res://scenes/arena.tscn"

	if custom_room_status_label != null and is_instance_valid(custom_room_status_label):
		custom_room_status_label.text = "CONNEXION AU SERVEUR..."

	_connect_to_game_server(ip, port, match_id)


## Quitte le salon localement (arrêt du polling, retour au menu) sans
## forcément prévenir le serveur — utilisé quand le salon est déjà mort
## côté service (404 au poll).
func _leave_custom_room_local_only() -> void:
	if custom_room_poll_timer != null:
		custom_room_poll_timer.stop()
	custom_room_code = ""
	custom_room_state = {}
	_custom_room_connect_triggered = false
	_custom_room_last_version = -1


func _leave_custom_room() -> void:
	if custom_room_http != null and custom_room_code != "":
		custom_room_http.request(
			MATCHMAKING_BASE_URL + "/rooms/" + custom_room_code + "/leave",
			PackedStringArray(["Content-Type: application/json"]),
			HTTPClient.METHOD_POST,
			JSON.stringify({"steam_id": _my_steam_id_str()})
		)
	_leave_custom_room_local_only()
	_show_arena_modes_deferred()


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

	if matchmaking_poll_http == null:
		return

	if matchmaking_poll_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return

	if matchmaking_ticket_id == "":
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

	call_deferred("_show_hero_select_lobby")


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
	_show_arena_modes_deferred()


func _mode_accent(mode: String) -> Color:
	match mode:
		"1V1 DUEL":
			return Color("a875c9")
		"2V2 CLASH":
			return Color("4fae7d")
		"3V3 RIVALRY":
			return Color("d9691f")
		"CUSTOM GAME":
			return Color("5fd0c0")
		_:
			return Color("c9a24d")


# =========================================================
# HEROES
# =========================================================

func _show_heroes() -> void:
	_clear()
	title.text = "HEROES"

	# Le choix du héros pour la partie se fait désormais dans le lobby de
	# sélection des champions (après matchmaking) — cet onglet n'est plus
	# qu'une galerie de consultation, d'où le vocabulaire neutre ("aperçu"
	# plutôt que "sélection") et l'absence de bouton "choisir".
	var subtitle := _label("GALERIE DES CHAMPIONS", 10, Color("b8935a"), Vector2(0, 44), Vector2(946, 22), HORIZONTAL_ALIGNMENT_CENTER)
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

	cards.add_child(_hero_card("AERIS", "ARCANE SKIRMISHER", "DPS / BURST", Color("5b9bc4"), "ARC BOLT • TELEPORT • PHASE DASH", _heroes_tab_focus_hero == "AERIS", func():
		_heroes_tab_focus_hero = "AERIS"
		_show_heroes_deferred()
	))
	cards.add_child(_hero_card("MAYLINH", "MYSTIC WARDEN", "HEALER / CONTROLLER", Color("4fae7d"), "ÉCLAT • SOIN • FUITE", _heroes_tab_focus_hero == "MAYLINH", func():
		_heroes_tab_focus_hero = "MAYLINH"
		_show_heroes_deferred()
	))
	cards.add_child(_hero_card("KAITHLYN", "BARBARIAN", "BERSERKER / CONTROLLER", Color("c98a3d"), "HACHE • BOUCLIER • CHARGE", _heroes_tab_focus_hero == "KAITHLYN", func():
		_heroes_tab_focus_hero = "KAITHLYN"
		_show_heroes_deferred()
	))
	cards.add_child(_hero_card("EREN", "CHEVALIER DE FEU", "FIRE BURST / CONTROLLER", Color("d9691f"), "BOULE DE FEU • NOVA • CHARGE", _heroes_tab_focus_hero == "EREN", func():
		_heroes_tab_focus_hero = "EREN"
		_show_heroes_deferred()
	))

	main_row.add_child(_hero_detail_panel(_heroes_tab_focus_hero))

	content.add_child(_label("APERÇU  •  %s" % _heroes_tab_focus_hero, 12, _hero_accent(_heroes_tab_focus_hero), Vector2(0, 516), Vector2(946, 22), HORIZONTAL_ALIGNMENT_CENTER))
	content.add_child(_label(_hero_description(_heroes_tab_focus_hero), 9, Color("9a8760"), Vector2(0, 541), Vector2(946, 25), HORIZONTAL_ALIGNMENT_CENTER))


## Lobby de sélection de personnage : affiché une fois le match trouvé et la
## connexion au serveur de partie établie, à la place du lancement direct.
## Le joueur choisit/confirme son héros ICI plutôt qu'à l'avance dans le
## menu principal — la connexion réseau est déjà active (join() a réussi).
## Écran léger façon League of Legends (gros aperçu central + rangée de
## portraits cliquables), synchronisé en réseau via Network.lobby_* : le
## serveur dédié (dedicated_server.gd) enregistre chaque pair connecté dans
## Network.lobby_picks dès l'arrivée et lance un compte à rebours de 30s ;
## la partie démarre dès que tous les joueurs présents ont validé, ou à
## l'expiration du délai (chacun garde alors son dernier choix, AERIS par
## défaut). _launch() (et donc l'envoi du RPC arena_client_ready) n'est
## déclenché qu'à la réception du signal lobby_match_ready.
func _show_hero_select_lobby() -> void:
	_lobby_active_screen = true
	_lobby_ready_locked = false
	_lobby_seconds_left_local = Network.LOBBY_DURATION
	if not Network.lobby_state_changed.is_connected(_on_lobby_state_changed):
		Network.lobby_state_changed.connect(_on_lobby_state_changed)
	if not Network.lobby_match_ready.is_connected(_on_lobby_match_ready):
		Network.lobby_match_ready.connect(_on_lobby_match_ready)
	if not Network.lobby_cancelled.is_connected(_on_lobby_cancelled):
		Network.lobby_cancelled.connect(_on_lobby_cancelled)
	_build_hero_select_lobby_ui()
	_refresh_lobby_status_ui(Network.lobby_picks)


## Charge le portrait d'un héros recadré sur la tête (les artworks sont des
## portraits pleine longueur avec la tête dans le tiers/moitié haute) au lieu
## de l'image entière rétrécie. Les 4 artworks partagent le même cadrage,
## donc un seul ratio de recadrage (haut de l'image) convient à tous.
const HERO_HEAD_CROP_RATIO := 0.46

## Chemin d'une vignette carrée dédiée (dessinée/recadrée à la main), si elle
## existe : res://assets/menu_art/heroes/square/<hero>.png (ex :
## square/aeris.png). Dépose une image carrée ici pour chaque héros et elle
## sera utilisée telle quelle à la place du recadrage automatique du grand
## artwork — pas besoin de toucher au code.
func _hero_art_square(hero_name: String) -> String:
	var base := "res://assets/menu_art/heroes/square/%s" % hero_name.to_lower()
	for ext in [".png", ".PNG"]:
		if ResourceLoader.exists(base + ext):
			return base + ext
	return ""

## Texture utilisée pour la vignette carrée de la rangée de portraits :
## priorité à l'artwork carré dédié s'il existe, sinon repli sur le
## recadrage automatique du grand artwork (_hero_head_texture).
func _hero_roster_texture(hero_name: String) -> Texture2D:
	var square_path := _hero_art_square(hero_name)
	if square_path != "":
		var square_texture := load(square_path) as Texture2D
		if square_texture != null:
			return square_texture
	return _hero_head_texture(hero_name)

func _hero_head_texture(hero_name: String) -> Texture2D:
	var path := _hero_art(hero_name)
	if path == "":
		return null
	# load() (pas Image.load()) : passe par le système de ressources importé
	# par Godot, seul garanti présent dans un .exe exporté. Image.load() lit
	# le fichier source brut sur disque, absent du build exporté (seule la
	# ressource importée .ctex l'est) — ça marchait dans l'éditeur (accès
	# direct aux fichiers du projet) mais donnait des vignettes vides une
	# fois exporté.
	var base_texture := load(path) as Texture2D
	if base_texture == null:
		push_warning("Portrait introuvable : " + path)
		return null
	var image := base_texture.get_image()
	if image == null:
		return base_texture
	var crop_height := int(image.get_height() * HERO_HEAD_CROP_RATIO)
	if crop_height > 0 and crop_height < image.get_height():
		var cropped := image.get_region(Rect2i(0, 0, image.get_width(), crop_height))
		if cropped != null and cropped.get_width() > 0 and cropped.get_height() > 0:
			return ImageTexture.create_from_image(cropped)
	# Repli : image entière si le recadrage échoue pour une raison ou une
	# autre, plutôt qu'une vignette totalement vide.
	return base_texture


## Reconstruit uniquement l'UI (sans toucher au minuteur / à l'état "prêt")
## — utilisé quand le joueur change de héros dans la rangée de portraits.
## Tout le contenu est posé sur un unique panneau "canvas" (pas un
## Container) : un VBoxContainer/HBoxContainer directement enfant de
## `content` ignore les positions manuelles de ses enfants (il les
## réempile verticalement en écrasant .position/.size), ce qui faisait
## disparaître/mal placer les panneaux ici — déjà rencontré ailleurs dans ce
## fichier, d'où le même contournement (_hero_card etc. vivent tous dans un
## panneau non-Container avec des tailles minimales explicites).
func _build_hero_select_lobby_ui() -> void:
	_clear()
	title.text = "SÉLECTION DES CHAMPIONS"

	# Le cadre (`frame`) qui contient `content` ne fait que ~542px de haut
	# utilisables sous le titre (614 de hauteur totale - 72 de décalage du
	# haut de `content`) : un canvas de 566+ px dépassait déjà du cadre, d'où
	# le bouton "VALIDER" qui sortait de la fenêtre. Mise en page resserrée
	# pour tenir confortablement dans ~500px.
	var canvas := _panel(Vector2.ZERO, Vector2(946, 530), Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0)
	canvas.custom_minimum_size = Vector2(946, 530)
	canvas.clip_contents = true
	content.add_child(canvas)

	# Fond thématique par héros (le grand artwork complet, pas le recadrage
	# tête) : change à chaque sélection puisque tout l'écran est reconstruit
	# par _build_hero_select_lobby_ui(). Assombri par un voile dessus pour
	# que le texte reste lisible.
	var bg_path := _hero_art(selected_hero)
	if bg_path != "":
		var bg := TextureRect.new()
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.texture = load(bg_path) as Texture2D
		canvas.add_child(bg)
		var veil := ColorRect.new()
		veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		veil.color = Color(0.04, 0.03, 0.02, 0.72)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(veil)

	_lobby_countdown_label = _label(str(int(ceil(_lobby_seconds_left_local))), 36, Color("f4c977"), Vector2(0, 0), Vector2(946, 42), HORIZONTAL_ALIGNMENT_CENTER)
	canvas.add_child(_lobby_countdown_label)

	canvas.add_child(_label("MATCH TROUVÉ  •  CHOISIS TON CHAMPION", 11, Color("8a7550"), Vector2(0, 42), Vector2(946, 18), HORIZONTAL_ALIGNMENT_CENTER))

	# Grand aperçu central, façon écran de sélection LoL.
	var preview := _panel(Vector2(323, 66), Vector2(300, 216), Color("140f09eb"), _hero_accent(selected_hero), 16)
	preview.custom_minimum_size = Vector2(300, 216)
	canvas.add_child(preview)

	var portrait := TextureRect.new()
	portrait.position = Vector2(20, 10)
	portrait.size = Vector2(260, 148)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.clip_contents = true
	portrait.texture = _hero_head_texture(selected_hero)
	preview.add_child(portrait)
	var lobby_hero_name_label := _label(selected_hero, 18, _hero_accent(selected_hero), Vector2(0, 162), Vector2(300, 26), HORIZONTAL_ALIGNMENT_CENTER)
	_use_decorative_font(lobby_hero_name_label)
	preview.add_child(lobby_hero_name_label)
	preview.add_child(_label(_hero_role(selected_hero), 9, Color("9a8760"), Vector2(0, 186), Vector2(300, 16), HORIZONTAL_ALIGNMENT_CENTER))

	# Rangée de portraits cliquables, légère (pas de fiche détaillée).
	var roster := HBoxContainer.new()
	roster.position = Vector2(323, 292)
	roster.custom_minimum_size = Vector2(300, 60)
	roster.add_theme_constant_override("separation", 8)
	canvas.add_child(roster)
	for hero_entry in [
		["AERIS", Color("5b9bc4")],
		["MAYLINH", Color("4fae7d")],
		["KAITHLYN", Color("c98a3d")],
		["EREN", Color("d9691f")],
	]:
		roster.add_child(_lobby_portrait_button(str(hero_entry[0]), hero_entry[1]))

	# Statut de chaque joueur connecté (toi / adversaire), mis à jour en
	# direct via Network.lobby_state_changed.
	_lobby_status_box = VBoxContainer.new()
	_lobby_status_box.position = Vector2(233, 356)
	_lobby_status_box.custom_minimum_size = Vector2(480, 48)
	_lobby_status_box.add_theme_constant_override("separation", 5)
	canvas.add_child(_lobby_status_box)

	_build_lobby_validate_button(canvas)


const VALIDATE_BUTTON_FRAME := "res://assets/menu_design/champ_select/button_menu_select_validation.png"

## Bouton "VALIDER MON CHOIX" habillé du cadre doré fourni par l'artiste
## (button_menu_select_validation.png). L'image reste à son ratio natif
## (~3:1) pour ne pas déformer les losanges/motifs du cadre — le Button lui
## -même est totalement transparent (juste le texte), posé PAR-DESSUS
## l'image de fond dans un Control englobant, puisqu'un enfant de Button
## se dessinerait par-dessus son texte s'il était mis dedans directement.
func _build_lobby_validate_button(parent: Control) -> Control:
	var frame_tex := load(VALIDATE_BUTTON_FRAME) as Texture2D
	if frame_tex == null:
		push_warning("Cadre du bouton VALIDER introuvable : " + VALIDATE_BUTTON_FRAME)
	var button_size := Vector2(320, 107)
	if frame_tex != null:
		var native_size := frame_tex.get_size()
		if native_size.x > 0.0:
			button_size.y = button_size.x * (native_size.y / native_size.x)

	_lobby_validate_button = Button.new()
	_lobby_validate_button.position = Vector2((946.0 - button_size.x) / 2.0, 400)
	_lobby_validate_button.size = button_size
	_lobby_validate_button.focus_mode = Control.FOCUS_ALL
	_lobby_validate_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Ajouté tout de suite : _apply_controller_primary_cta() a besoin que le
	# bouton soit déjà dans l'arbre pour poser son prompt "START" à côté.
	parent.add_child(_lobby_validate_button)

	# Habille le bouton directement avec l'image (StyleBoxTexture, le
	# mécanisme natif de Godot pour un bouton à fond illustré) plutôt que de
	# poser un TextureRect à côté : le bouton se charge lui-même de peindre
	# l'image ET le texte, sans ambiguïté d'ordre d'affichage entre nœuds.
	if frame_tex != null:
		# Une StyleBoxTexture par état avec sa propre teinte (modulate_color) :
		# plus lumineux au survol, assombri à l'appui, pour un vrai retour
		# visuel plutôt que la même image figée dans tous les états.
		var normal_style := StyleBoxTexture.new()
		normal_style.texture = frame_tex
		_lobby_validate_button.add_theme_stylebox_override("normal", normal_style)

		var hover_style := StyleBoxTexture.new()
		hover_style.texture = frame_tex
		hover_style.modulate_color = Color(1.25, 1.18, 0.95)
		_lobby_validate_button.add_theme_stylebox_override("hover", hover_style)
		_lobby_validate_button.add_theme_stylebox_override("focus", hover_style)

		var pressed_style := StyleBoxTexture.new()
		pressed_style.texture = frame_tex
		pressed_style.modulate_color = Color(0.72, 0.66, 0.55)
		_lobby_validate_button.add_theme_stylebox_override("pressed", pressed_style)

		var disabled_style := StyleBoxTexture.new()
		disabled_style.texture = frame_tex
		disabled_style.modulate_color = Color(0.55, 0.55, 0.55)
		_lobby_validate_button.add_theme_stylebox_override("disabled", disabled_style)
	else:
		# Repli visible si le cadre ne charge pas, plutôt qu'un bouton
		# totalement invisible.
		var fallback_style := _rune_box(Color("6b3a12"), Color("e8b656"), 2)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			_lobby_validate_button.add_theme_stylebox_override(state, fallback_style)

	_use_title_font(_lobby_validate_button)
	_lobby_validate_button.add_theme_color_override("font_color", Color("fff2d4"))
	_lobby_validate_button.add_theme_color_override("font_hover_color", Color("fffbe8"))
	_lobby_validate_button.add_theme_color_override("font_disabled_color", Color("c9b98a"))
	_lobby_validate_button.add_theme_constant_override("outline_size", 2)
	_lobby_validate_button.add_theme_color_override("font_outline_color", Color("0a0603"))
	if _lobby_ready_locked:
		_lobby_validate_button.text = "EN ATTENTE..."
		_lobby_validate_button.add_theme_font_size_override("font_size", 16)
		_lobby_validate_button.disabled = true
	else:
		_lobby_validate_button.text = "VALIDER MON CHOIX"
		_lobby_validate_button.add_theme_font_size_override("font_size", 19)
		_lobby_validate_button.pressed.connect(_on_lobby_validate_pressed)
		_apply_controller_primary_cta(_lobby_validate_button, "VALIDER MON CHOIX", _on_lobby_validate_pressed)
	return _lobby_validate_button


func _lobby_portrait_button(hero_name: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(60, 60)
	btn.focus_mode = Control.FOCUS_ALL
	var selected := hero_name == selected_hero
	# Cadre coloré (couleur du héros) sur CHAQUE portrait, pas seulement
	# celui sélectionné — plus épais/lumineux pour la sélection en cours.
	btn.add_theme_stylebox_override("normal", _box(Color("241a0df2") if selected else Color("140f09eb"), accent, 10, 3 if selected else 2))
	btn.add_theme_stylebox_override("hover", _box(Color("241a0d"), accent, 10, 3))
	btn.add_theme_stylebox_override("focus", _box(Color("241a0d"), accent, 10, 3))

	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.clip_contents = true
	icon.texture = _hero_roster_texture(hero_name)
	btn.add_child(icon)

	if selected:
		# Carré de surbrillance bien visible autour du portrait sélectionné —
		# le cadre coloré seul (juste 1px d'écart avec les autres) ne se
		# voyait pas assez pour repérer son propre choix d'un coup d'œil.
		var highlight := Panel.new()
		highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
		highlight.offset_left = -6
		highlight.offset_top = -6
		highlight.offset_right = 6
		highlight.offset_bottom = 6
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var highlight_style := StyleBoxFlat.new()
		highlight_style.bg_color = Color(0, 0, 0, 0)
		highlight_style.border_color = Color("fff2d4")
		highlight_style.set_border_width_all(3)
		highlight_style.set_corner_radius_all(13)
		highlight.add_theme_stylebox_override("panel", highlight_style)
		btn.add_child(highlight)

	btn.disabled = _lobby_ready_locked
	btn.pressed.connect(func():
		if _lobby_ready_locked:
			return
		selected_hero = hero_name
		Network.lobby_submit_pick.rpc_id(1, selected_hero, false)
		_build_hero_select_lobby_ui()
	)
	return btn


func _on_lobby_validate_pressed() -> void:
	if _lobby_ready_locked:
		return
	_lobby_ready_locked = true
	PlayerProgress.mark_hero_played(selected_hero)
	Network.lobby_submit_pick.rpc_id(1, selected_hero, true)
	_build_hero_select_lobby_ui()


## Reçu quand le serveur diffuse un nouvel état de lobby (un joueur a changé
## de héros, s'est déclaré prêt, ou a rejoint/quitté) — resynchronise aussi
## le minuteur local sur le minuteur autoritaire du serveur.
func _on_lobby_state_changed(picks: Dictionary, seconds_left: float) -> void:
	_lobby_seconds_left_local = seconds_left
	if _lobby_countdown_label != null and is_instance_valid(_lobby_countdown_label):
		_lobby_countdown_label.text = str(int(ceil(_lobby_seconds_left_local)))
	_refresh_lobby_status_ui(picks)


func _refresh_lobby_status_ui(picks: Dictionary) -> void:
	if _lobby_status_box == null or not is_instance_valid(_lobby_status_box):
		return
	for child in _lobby_status_box.get_children():
		child.queue_free()
	var my_id := multiplayer.get_unique_id()
	var ordered_ids := picks.keys()
	ordered_ids.sort()
	for peer_id in ordered_ids:
		var info: Dictionary = picks[peer_id]
		var hero_name: String = str(info.get("hero", "AERIS"))
		var ready: bool = bool(info.get("ready", false))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var who_text := "TOI" if int(peer_id) == my_id else "JOUEUR %d" % int(peer_id)
		row.add_child(_label(who_text, 10, Color("d4c4a0"), Vector2.ZERO, Vector2(120, 18)))
		row.add_child(_label(hero_name, 10, _hero_accent(hero_name), Vector2.ZERO, Vector2(140, 18)))
		row.add_child(_label("✔ PRÊT" if ready else "EN CHOIX...", 9, Color("6fb88a") if ready else Color("8a7a5a"), Vector2.ZERO, Vector2(120, 18)))
		_lobby_status_box.add_child(row)


## Reçu quand le serveur donne le feu vert (tout le monde prêt, ou temps
## écoulé) : on lance la partie avec le héros actuellement choisi.
func _on_lobby_match_ready() -> void:
	_lobby_active_screen = false
	_disconnect_lobby_signals()
	_launch()


## Un joueur n'a pas validé son héros à temps (à partir de 2 joueurs
## présents) : le serveur dédié annule et s'éteint. On se déconnecte
## proprement et on revient à l'écran de sélection de mode avec le motif.
func _on_lobby_cancelled(reason: String) -> void:
	_lobby_active_screen = false
	_disconnect_lobby_signals()
	Network.call("close")
	_transient_status_message = "PARTIE ANNULÉE  •  %s" % reason
	_show_arena_modes()


func _disconnect_lobby_signals() -> void:
	if Network.lobby_state_changed.is_connected(_on_lobby_state_changed):
		Network.lobby_state_changed.disconnect(_on_lobby_state_changed)
	if Network.lobby_match_ready.is_connected(_on_lobby_match_ready):
		Network.lobby_match_ready.disconnect(_on_lobby_match_ready)
	if Network.lobby_cancelled.is_connected(_on_lobby_cancelled):
		Network.lobby_cancelled.disconnect(_on_lobby_cancelled)


## Carte de consultation d'un héros dans la galerie HEROES : plus de notion
## de "choix" ici (le héros de la partie se sélectionne dans le lobby au
## lancement) — cliquer une carte l'affiche simplement en grand dans le
## panneau de détail à droite. `is_focused` reflète l'état d'affichage local
## de cet onglet (_heroes_tab_focus_hero), pas selected_hero.
func _hero_card(hero_name: String, subtitle: String, role: String, accent: Color, spells: String, is_focused: bool, on_focus: Callable) -> Panel:
	var card := _panel(Vector2.ZERO, Vector2(156, 438), Color("140f09eb"), Color("4a3018"), 13)
	card.custom_minimum_size = Vector2(156, 438)
	if is_focused:
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
	info_hitbox.pressed.connect(on_focus)
	card.add_child(info_hitbox)

	var hero_card_name_label := _label(hero_name, 18, accent, Vector2(8, 246), Vector2(140, 24), HORIZONTAL_ALIGNMENT_CENTER)
	_use_decorative_font(hero_card_name_label)
	card.add_child(hero_card_name_label)
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

	var button := _button("VOIR LES DÉTAILS", Vector2(136, 31), is_focused)
	button.position = Vector2(10, 397)
	button.size = Vector2(136, 31)
	button.pressed.connect(on_focus)
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

	var hero_detail_name_label := _label(hero_name, 24, accent, Vector2(18, 14), Vector2(205, 31))
	_use_decorative_font(hero_detail_name_label)
	panel.add_child(hero_detail_name_label)
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

## Hauteur des boutons de nav du rail gauche, calculée pour respecter le
## ratio natif de l'image menu_left_button.png (bannière large, pas carrée) :
## sans ça, l'étirer sur une hauteur arbitraire déforme le motif.
const NAV_BUTTON_WIDTH: float = 208.0

func _nav_button_height() -> float:
	var frame_tex := load(NAV_BUTTON_FRAME) as Texture2D
	if frame_tex == null:
		return 42.0
	var native_size := frame_tex.get_size()
	if native_size.x <= 0.0:
		return 42.0
	return NAV_BUTTON_WIDTH * (native_size.y / native_size.x)


## Applique le skin "menu_left_button.png" (StyleBoxTexture par état, même
## technique que le bouton VALIDER du lobby de sélection de champions) sur un
## bouton de nav, avec une teinte différente selon qu'il est actif ou non.
func _apply_nav_button_style(b: Button, active: bool) -> void:
	var frame_tex := load(NAV_BUTTON_FRAME) as Texture2D
	if frame_tex == null:
		push_warning("Cadre du bouton de navigation introuvable : " + NAV_BUTTON_FRAME)
		b.add_theme_stylebox_override("normal", _rune_box(Color("241a0d") if active else Color("140f09"), Color("c9a24d") if active else Color("352818"), 1))
		b.add_theme_stylebox_override("hover", _rune_box(Color("2c2010"), Color("e8b656"), 1))
		b.add_theme_stylebox_override("focus", _rune_box(Color("2c2010"), Color("f4c977"), 2))
		return

	var normal_style := StyleBoxTexture.new()
	normal_style.texture = frame_tex
	normal_style.modulate_color = Color(1.1, 1.0, 0.72) if active else Color(0.6, 0.55, 0.46)
	normal_style.content_margin_left = 34
	normal_style.content_margin_right = 18
	b.add_theme_stylebox_override("normal", normal_style)

	var hover_style := StyleBoxTexture.new()
	hover_style.texture = frame_tex
	hover_style.modulate_color = Color(1.3, 1.22, 0.95)
	hover_style.content_margin_left = 34
	hover_style.content_margin_right = 18
	b.add_theme_stylebox_override("hover", hover_style)
	b.add_theme_stylebox_override("focus", hover_style)

	var pressed_style := StyleBoxTexture.new()
	pressed_style.texture = frame_tex
	pressed_style.modulate_color = Color(0.68, 0.62, 0.5)
	pressed_style.content_margin_left = 34
	pressed_style.content_margin_right = 18
	b.add_theme_stylebox_override("pressed", pressed_style)


func _aaa_nav_button(text_value: String, active: bool) -> Button:
	var b := Button.new()
	b.text = ("◆  " if active else "     ") + text_value
	b.custom_minimum_size = Vector2(NAV_BUTTON_WIDTH, _nav_button_height())
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_constant_override("outline_size", 1)
	b.add_theme_color_override("font_outline_color", Color("0a0603"))
	b.add_theme_color_override("font_color", Color("fff2d4") if active else Color("c4b48a"))
	b.add_theme_color_override("font_hover_color", Color("fff2d4"))
	b.add_theme_color_override("font_focus_color", Color("fff2d4"))
	_use_title_font(b, true)
	_apply_nav_button_style(b, active)
	return b

## card_width doit correspondre à la largeur RÉELLEMENT rendue du bouton
## (946 sur l'écran PLAY où la bannière occupe tout `content` ; 600 sur
## l'écran MULTIJOUEUR ARENA où le panneau latéral la contraint) : la
## bannière est une image unique étirée sur toute la largeur du bouton, et
## la position du médaillon/flèche qu'elle contient est donc proportionnelle
## à cette largeur. Une marge de texte fixe en pixels convenait à une seule
## largeur mais chevauchait le médaillon dès que le bouton était plus
## large — d'où ces marges calculées en pourcentage de card_width.
## Applique le skin bannière (icône à gauche, flèche à droite) d'un mode/
## catégorie à un bouton EXISTANT — factorisé hors de _mode_card() pour
## pouvoir aussi styler les boutons persistants de %ArenaModesScreen (créés
## une fois dans la scène) sans les recréer à chaque rafraîchissement.
func _apply_mode_card_style(b: Button, mode: String, selected: bool, card_width: float = 600.0) -> void:
	_apply_banner_text_style(b, 19)

	var margin_left := card_width * 0.25
	var margin_right := card_width * 0.117

	var frame_tex: Texture2D = null
	if MODE_CARD_ASSETS.has(mode):
		frame_tex = _cropped_banner_texture(MODE_CARD_ASSETS[mode])

	if frame_tex != null:
		# Le médaillon d'icône occupe la partie gauche de la bannière et la
		# flèche la partie droite : on resserre la zone de texte au bandeau
		# central plutôt que de le laisser chevaucher l'artwork. Modulate
		# proche du blanc pour garder les couleurs vives de l'artwork
		# d'origine (un assombrissement marqué le rendait terne/sale).
		var normal_style := StyleBoxTexture.new()
		normal_style.texture = frame_tex
		normal_style.modulate_color = Color(1.05, 1.0, 0.9) if selected else Color(0.95, 0.95, 0.95)
		normal_style.content_margin_left = margin_left
		normal_style.content_margin_right = margin_right
		b.add_theme_stylebox_override("normal", normal_style)

		var hover_style := StyleBoxTexture.new()
		hover_style.texture = frame_tex
		hover_style.modulate_color = Color(1.18, 1.14, 1.0)
		hover_style.content_margin_left = margin_left
		hover_style.content_margin_right = margin_right
		b.add_theme_stylebox_override("hover", hover_style)
		b.add_theme_stylebox_override("focus", hover_style)

		var pressed_style := StyleBoxTexture.new()
		pressed_style.texture = frame_tex
		pressed_style.modulate_color = Color(0.8, 0.76, 0.66)
		pressed_style.content_margin_left = margin_left
		pressed_style.content_margin_right = margin_right
		b.add_theme_stylebox_override("pressed", pressed_style)
	else:
		push_warning("Cadre du bouton de mode introuvable pour : " + mode)
		b.add_theme_stylebox_override("normal", _rune_box(Color("1f160c"), Color("6b4a24"), 1))
		b.add_theme_stylebox_override("hover", _rune_box(Color("2c2010"), Color("c9a24d"), 2))
		if selected:
			b.add_theme_stylebox_override("normal", _rune_box(Color("6b3a12"), Color("e8b656"), 2))
		b.add_theme_stylebox_override("focus", _rune_box(Color("2c2010"), Color("f4c977"), 2))


func _mode_card(mode: String, selected: bool, card_height: float = MODE_CARD_HEIGHT_LIST, card_width: float = 600.0) -> Button:
	var b := Button.new()
	b.text = mode
	b.custom_minimum_size = Vector2(card_width, card_height)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_mode_card_style(b, mode, selected, card_width)
	return b

## Habillage texte lisible par-dessus une bannière illustrée chargée (photo
## + halo) : contour épais quasi noir + ombre portée, seul moyen fiable de
## garder le texte net quel que soit ce qu'il y a derrière, plutôt qu'un
## simple contour fin qui se noie dans l'artwork.
func _apply_banner_text_style(b: Button, font_size: int) -> void:
	_use_title_font(b)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_constant_override("outline_size", 3)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	b.add_theme_color_override("font_color", Color("fff6e0"))
	b.add_theme_color_override("font_hover_color", Color("ffffff"))
	b.add_theme_color_override("font_focus_color", Color("ffffff"))
	b.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	b.add_theme_constant_override("shadow_offset_x", 0)
	b.add_theme_constant_override("shadow_offset_y", 2)
	b.add_theme_constant_override("shadow_outline_size", 2)


## Skin bannière (icône groupe à gauche, flèche à droite) pour le bouton
## CRÉER LA PARTY / SALON CUSTOM GAME du panneau latéral — même famille
## d'asset et même technique que _mode_card().
func _apply_banner_launch_style(b: Button) -> void:
	var frame_tex := _cropped_banner_texture(CREATE_PARTY_BUTTON_ASSET)
	if frame_tex == null:
		push_warning("Cadre du bouton CRÉER LA PARTY introuvable : " + CREATE_PARTY_BUTTON_ASSET)
		return

	var normal_style := StyleBoxTexture.new()
	normal_style.texture = frame_tex
	normal_style.modulate_color = Color(1.05, 1.0, 0.9)
	normal_style.content_margin_left = 66
	normal_style.content_margin_right = 34
	b.add_theme_stylebox_override("normal", normal_style)

	var hover_style := StyleBoxTexture.new()
	hover_style.texture = frame_tex
	hover_style.modulate_color = Color(1.18, 1.14, 1.0)
	hover_style.content_margin_left = 66
	hover_style.content_margin_right = 34
	b.add_theme_stylebox_override("hover", hover_style)
	b.add_theme_stylebox_override("focus", hover_style)

	var pressed_style := StyleBoxTexture.new()
	pressed_style.texture = frame_tex
	pressed_style.modulate_color = Color(0.8, 0.76, 0.66)
	pressed_style.content_margin_left = 66
	pressed_style.content_margin_right = 34
	b.add_theme_stylebox_override("pressed", pressed_style)


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

## Écran "à venir" pour les modes PLAY pas encore implémentés
## (Co-op Donjon, Impostor, Hide & Seek).
func _show_play_placeholder(mode_title: String, description: String) -> void:
	_clear()
	title.text = mode_title + " // À VENIR"

	var back_btn := Button.new()
	back_btn.text = "←  PLAY"
	back_btn.flat = true
	back_btn.custom_minimum_size = Vector2(120, 26)
	back_btn.focus_mode = Control.FOCUS_ALL
	back_btn.add_theme_font_size_override("font_size", 11)
	back_btn.add_theme_color_override("font_color", Color("c9a24d"))
	back_btn.pressed.connect(_show_home)
	content.add_child(back_btn)

	content.add_child(_label(description, 16, Color("b8a880"), Vector2.ZERO, Vector2(700, 90)))


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
	if pending_arena_scene_path != "":
		# Custom Game : la map vient du salon, pas du mode.
		arena_scene_path = pending_arena_scene_path
	elif selected_mode == "1V1 DUEL" and ResourceLoader.exists("res://scenes/Arena1v1.tscn"):
		arena_scene_path = "res://scenes/Arena1v1.tscn"
	pending_arena_scene_path = ""

	get_tree().change_scene_to_file(arena_scene_path)


# =========================================================
# UTILS
# =========================================================

func _clear() -> void:
	content.visible = true
	# Les écrans convertis en nœuds de scène statiques (ex. %ArenaModesScreen)
	# ne repassent pas par ici pour se construire, mais doivent redevenir
	# invisibles dès qu'on quitte vers un écran encore procédural.
	var arena_screen: Control = %ArenaModesScreen
	arena_screen.visible = false
	for child in content.get_children():
		child.queue_free()
	# Le CTA "START" (s'il y en avait un) n'a plus de sens sur le nouvel
	# écran tant qu'il n'en repose pas un lui-même.
	_clear_controller_primary_action()


func _navigate_deferred(item: String) -> void:
	call_deferred("_navigate", item)


func _show_home_deferred() -> void:
	call_deferred("_show_home")
	call_deferred("_focus_first_control")

func _show_arena_modes_deferred() -> void:
	call_deferred("_show_arena_modes")
	call_deferred("_focus_first_control")

func _show_heroes_deferred() -> void:
	call_deferred("_show_heroes")
	call_deferred("_focus_first_control")


func _show_settings_deferred() -> void:
	call_deferred("_show_settings")
	call_deferred("_focus_first_control")


## Style "sceau gravé" : bordures fines dorées/bronze, coins asymétriques,
## ombre profonde façon pierre ou cuir tanné plutôt que verre lisse.
## Équivalent du style appliqué par l'ancien helper _panel() (bordure 1px,
## coins uniformes, sans ombre) — utilisé pour les panneaux qui sont
## maintenant de vrais nœuds de scène (Steam, Niveau, avatar) plutôt que
## créés par _panel() lui-même.
func _simple_box(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	return box


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
## Les 4 héros jouables, dans l'ordre affiché partout (galerie HEROES, lobby,
## LOADOUT). Utilisé pour construire les rangées de portraits sans dupliquer
## la liste à chaque écran.
const HERO_ROSTER: Array[String] = ["AERIS", "MAYLINH", "KAITHLYN", "EREN"]


func _show_arkanites() -> void:
	_clear()
	title.text = "ARKANITES"

	var player_level: int = PlayerProgress.get_level()
	var level_text: String = "NIVEAU MAX (%d)" % PlayerProgress.MAX_LEVEL
	if player_level < PlayerProgress.MAX_LEVEL:
		var player_xp: int = PlayerProgress.get_xp()
		var xp_needed: int = PlayerProgress.xp_to_next_level(player_level)
		level_text = "NIVEAU %d/%d  •  %d/%d XP" % [player_level, PlayerProgress.MAX_LEVEL, player_xp, xp_needed]

	var played_count: int = PlayerProgress.played_heroes.size()
	var subtitle := _label(
		"FAÇONNE TON STYLE  •  HÉROS JOUÉS : %d  •  %s  •  %d ÉCLATS" % [played_count, level_text, PlayerProgress.get_currency()],
		10,
		Color("b8935a"),
		Vector2(0, 44),
		Vector2(946, 22),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	content.add_child(subtitle)

	var all_cards := ArkaniteDB.get_all()

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
	# Une Arkanite liée à un héros (hero_id) se débloque en jouant ce héros
	# au moins une fois (choix validé dans le lobby), pas seulement en le
	# sélectionnant dans le menu (qui n'existe plus ici).
	var relevant_to_selected_hero: bool = card.hero_id == "" or PlayerProgress.has_played_hero(card.hero_id)
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
		# Maîtrise/Invocation se possèdent via les fragments gagnés en fin de
		# match (ou un coffre de palier), puis un paiement en Éclats une fois
		# les fragments complétés — l'équipement sur un héros se gère lui,
		# désormais, dans l'onglet LOADOUT, pas ici.
		var owned: bool = PlayerProgress.owns_arkanite(card)
		var ready: bool = PlayerProgress.is_arkanite_ready(card)
		if owned:
			var status_label := _label("POSSÉDÉE  •  ÉQUIPE-LA DANS LOADOUT", 8, Color("62e6a7"), Vector2(86, 90), Vector2(196, 16))
			status_label.clip_text = true
			row.add_child(status_label)
		elif ready:
			var can_afford: bool = PlayerProgress.get_currency() >= card.unlock_cost
			var unlock_button := _button("DÉBLOQUER (%d ÉCLATS)" % card.unlock_cost, Vector2(196, 22), true)
			unlock_button.position = Vector2(86, 88)
			unlock_button.clip_text = true
			unlock_button.add_theme_font_size_override("font_size", 8)
			unlock_button.disabled = not can_afford
			if not can_afford:
				unlock_button.text = "ÉCLATS INSUFFISANTS (%d)" % card.unlock_cost
			var card_id := card.id
			unlock_button.pressed.connect(func():
				PlayerProgress.try_unlock_arkanite(card_id)
				_show_arkanites_deferred()
			)
			row.add_child(unlock_button)
		else:
			var fragments: int = PlayerProgress.get_arkanite_fragments(card.id)
			var status_label := _label("%d/%d FRAGMENTS" % [fragments, card.fragments_required], 8, Color("9a8760"), Vector2(86, 90), Vector2(196, 16))
			status_label.clip_text = true
			row.add_child(status_label)
	else:
		# Consommable : gagné rarement en fin de match (stock persisté), une
		# utilisation en retire un du stock.
		var stock: int = PlayerProgress.get_consumable_stock(card.id)
		var use_button := _button("UTILISER (x%d)" % stock if stock > 0 else "AUCUNE EN STOCK", Vector2(140, 22), stock > 0)
		use_button.position = Vector2(86, 88)
		use_button.clip_text = true
		use_button.add_theme_font_size_override("font_size", 9)
		use_button.disabled = stock <= 0
		var card_id := card.id
		use_button.pressed.connect(func():
			if PlayerProgress.consume_arkanite(card_id):
				print("ARENA RIFT : Arkanite consommée -> ", card_id)
				# TODO : appliquer l'effet temporaire réel.
				_show_arkanites_deferred()
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


# =========================================================
# LOADOUT : équipement des Arkanites par héros (jusqu'à
# PlayerProgress.LOADOUT_MAX_SLOTS emplacements chacun).
# =========================================================

func _show_loadout() -> void:
	_clear()
	title.text = "LOADOUT"

	var subtitle := _label(
		"ÉQUIPE TES ARKANITES PAR HÉROS  •  %d EMPLACEMENTS  •  %d ÉCLATS" % [PlayerProgress.LOADOUT_MAX_SLOTS, PlayerProgress.get_currency()],
		10,
		Color("b8935a"),
		Vector2(0, 44),
		Vector2(946, 22),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	content.add_child(subtitle)

	var hero_row := HBoxContainer.new()
	hero_row.position = Vector2(0, 72)
	hero_row.size = Vector2(946, 96)
	hero_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_row.add_theme_constant_override("separation", 14)
	content.add_child(hero_row)

	for hero_name in HERO_ROSTER:
		hero_row.add_child(_loadout_hero_button(hero_name))

	var accent := _hero_accent(_loadout_focus_hero)

	content.add_child(_label(
		"ÉQUIPÉES SUR %s" % _loadout_focus_hero,
		12,
		accent,
		Vector2(0, 180),
		Vector2(946, 20),
		HORIZONTAL_ALIGNMENT_CENTER
	))

	var slots_row := HBoxContainer.new()
	slots_row.position = Vector2(0, 206)
	slots_row.size = Vector2(946, 96)
	slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_row.add_theme_constant_override("separation", 16)
	content.add_child(slots_row)

	var equipped_ids := PlayerProgress.get_equipped_loadout(_loadout_focus_hero)
	for i in range(PlayerProgress.LOADOUT_MAX_SLOTS):
		var card_id: String = equipped_ids[i] if i < equipped_ids.size() else ""
		slots_row.add_child(_loadout_slot(card_id, accent))

	content.add_child(_label(
		"ARKANITES ÉQUIPABLES  •  %s" % _loadout_focus_hero,
		12,
		accent,
		Vector2(0, 316),
		Vector2(946, 20),
		HORIZONTAL_ALIGNMENT_CENTER
	))

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(180, 342)
	scroll.size = Vector2(586, 210)
	content.add_child(scroll)

	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(570, 0)
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	var pool := ArkaniteDB.get_equipable_for_hero(_loadout_focus_hero)
	if pool.is_empty():
		list.add_child(_label(
			"AUCUNE ARKANITE ÉQUIPABLE POUR CE HÉROS.",
			10,
			Color("9a8760"),
			Vector2.ZERO,
			Vector2(570, 24),
			HORIZONTAL_ALIGNMENT_CENTER
		))
	for card in pool:
		list.add_child(_loadout_card_row(card, accent))


func _loadout_hero_button(hero_name: String) -> Button:
	var accent := _hero_accent(hero_name)
	var selected := hero_name == _loadout_focus_hero
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(130, 90)
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_stylebox_override("normal", _box(Color("241a0df2") if selected else Color("140f09eb"), accent, 10, 3 if selected else 1))
	btn.add_theme_stylebox_override("hover", _box(Color("241a0d"), accent, 10, 3))
	btn.add_theme_stylebox_override("focus", _box(Color("241a0d"), accent, 10, 3))

	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_bottom = -22
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.clip_contents = true
	icon.texture = _hero_roster_texture(hero_name)
	btn.add_child(icon)

	var name_label := _label(hero_name, 10, accent, Vector2(0, 68), Vector2(130, 18), HORIZONTAL_ALIGNMENT_CENTER)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(name_label)

	btn.pressed.connect(func():
		_loadout_focus_hero = hero_name
		_show_loadout_deferred()
	)
	return btn


func _loadout_slot(card_id: String, accent: Color) -> Panel:
	var slot := _panel(Vector2.ZERO, Vector2(180, 90), Color("140f09eb"), accent if card_id != "" else Color("352818"), 12)
	slot.custom_minimum_size = Vector2(180, 90)
	if card_id == "":
		slot.add_child(_label("EMPLACEMENT LIBRE", 9, Color("6b5d42"), Vector2(10, 34), Vector2(160, 24), HORIZONTAL_ALIGNMENT_CENTER))
		return slot

	var card := ArkaniteDB.get_by_id(card_id)
	if card == null:
		return slot

	var thumb := TextureRect.new()
	thumb.position = Vector2(8, 8)
	thumb.size = Vector2(54, 74)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if card.image_path != "":
		thumb.texture = load(card.image_path) as Texture2D
	slot.add_child(thumb)

	var name_label := _label(card.display_name, 10, Color("f3e6c8"), Vector2(70, 10), Vector2(104, 32))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot.add_child(name_label)

	var unequip_button := _button("RETIRER", Vector2(96, 20), false)
	unequip_button.position = Vector2(70, 62)
	unequip_button.add_theme_font_size_override("font_size", 8)
	unequip_button.clip_text = true
	var focus_hero := _loadout_focus_hero
	unequip_button.pressed.connect(func():
		PlayerProgress.unequip_arkanite(focus_hero, card_id)
		_show_loadout_deferred()
	)
	slot.add_child(unequip_button)
	return slot


func _loadout_card_row(card: ArkaniteCard, accent: Color) -> Panel:
	var owned := PlayerProgress.owns_arkanite(card)
	var equipped := PlayerProgress.is_arkanite_equipped(_loadout_focus_hero, card.id)

	# Contrairement à l'onglet ARKANITES, on ne réduit PAS l'opacité de toute
	# la ligne ici : sur le fond très sombre du menu, ça rendait les cartes
	# non possédées quasi invisibles au lieu de juste "moins mises en avant".
	# La bordure plus terne (352818) suffit à signaler l'état verrouillé.
	var row := _panel(Vector2.ZERO, Vector2(570, 64), Color("140f09eb"), accent if owned else Color("4a3d28"), 10)
	row.custom_minimum_size = Vector2(570, 64)

	var thumbnail := TextureRect.new()
	thumbnail.position = Vector2(6, 6)
	thumbnail.size = Vector2(40, 52)
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if card.image_path != "":
		thumbnail.texture = load(card.image_path) as Texture2D
	row.add_child(thumbnail)

	row.add_child(_label(card.display_name, 11, Color("f3e6c8"), Vector2(56, 6), Vector2(280, 20)))

	var effect_label := _label(card.effect_text, 8, Color("c4b394"), Vector2(56, 26), Vector2(280, 32))
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(effect_label)

	var action_button: Button
	if not owned:
		if PlayerProgress.is_arkanite_ready(card):
			action_button = _button("PRÊTE  •  VOIR ARKANITES", Vector2(140, 26), false)
		else:
			var fragments: int = PlayerProgress.get_arkanite_fragments(card.id)
			action_button = _button("%d/%d FRAGMENTS" % [fragments, card.fragments_required], Vector2(140, 26), false)
		action_button.disabled = true
		action_button.add_theme_font_size_override("font_size", 9)
	else:
		action_button = _button("RETIRER" if equipped else "ÉQUIPER", Vector2(110, 26), equipped)
		action_button.clip_text = true
		var card_id := card.id
		var focus_hero := _loadout_focus_hero
		action_button.pressed.connect(func():
			if PlayerProgress.is_arkanite_equipped(focus_hero, card_id):
				PlayerProgress.unequip_arkanite(focus_hero, card_id)
			else:
				PlayerProgress.equip_arkanite(focus_hero, card_id)
			_show_loadout_deferred()
		)
	action_button.position = Vector2(430, 18)
	row.add_child(action_button)

	return row


func _show_loadout_deferred() -> void:
	call_deferred("_show_loadout")
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
