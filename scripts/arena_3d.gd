extends Node3D

class MOBAAbilityIcon extends Control:
	var icon_texture: Texture2D
	var accent_color: Color = Color.WHITE
	var cooldown_left: float = 0.0
	var cooldown_max: float = 1.0
	var radius: float = 30.0

	func setup(texture: Texture2D, color: Color, size: float) -> void:
		icon_texture = texture
		accent_color = color
		custom_minimum_size = Vector2(size, size)
		self.size = Vector2(size, size)
		radius = size * 0.42
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func set_cooldown(value: float, maximum: float) -> void:
		cooldown_left = maxf(0.0, value)
		cooldown_max = maxf(0.01, maximum)
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		var style := StyleBoxFlat.new()
		style.bg_color = Color("07111feF")
		style.border_color = accent_color.darkened(0.28) if cooldown_left <= 0.05 else Color("243247")
		style.set_border_width_all(1)
		style.set_corner_radius_all(12)
		draw_style_box(style, rect)

		if icon_texture != null:
			var icon_rect := Rect2(Vector2(7, 7), size - Vector2(14, 14))
			var icon_modulate := Color.WHITE if cooldown_left <= 0.05 else Color("687486")
			draw_texture_rect(icon_texture, icon_rect, false, icon_modulate)

		if cooldown_left > 0.05:
			# Dark radial sweep, façon MOBA : le secteur se vide avec le cooldown.
			var progress := clampf(cooldown_left / cooldown_max, 0.0, 1.0)
			var center := size * 0.5
			var points := PackedVector2Array([center])
			var steps := 28
			for i in range(steps + 1):
				var t := float(i) / float(steps)
				var angle := -PI * 0.5 + TAU * progress * t
				points.append(center + Vector2(cos(angle), sin(angle)) * radius)
			draw_colored_polygon(points, Color(0.015, 0.025, 0.045, 0.72))

			var font := ThemeDB.fallback_font
			var text := str(ceili(cooldown_left))
			var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
			draw_string(font, center - text_size * 0.5 + Vector2(0, 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffffff"))
		else:
			# Petit halo/bordure quand le sort est prêt.
			draw_arc(size * 0.5, radius + 2.0, 0.0, TAU, 32, accent_color, 1.2, true)

## ARENA RIFT - arène 3D principale.
## Cette scène remplace l'ancien arena.gd 2D. Le menu et Network restent inchangés.

const PlayerScene := preload("res://scripts/player_3d.gd")
const ProjectileScene := preload("res://scripts/projectile_3d.gd")
const VFXManagerScene := preload("res://scripts/vfx_manager.gd")
const ORB_CAST_SFX := preload("res://audio/sfx/orb_cast.wav")
const HIT_SFX := preload("res://audio/sfx/hit.wav")
const DASH_SFX := preload("res://audio/sfx/dash.wav")
const TELEPORT_SFX := preload("res://audio/sfx/teleport.wav")
const DEATH_SFX := preload("res://audio/sfx/death.wav")

const ARENA_SIZE := Vector3(30.0, 0.2, 20.0)
const ROUND_DURATION := 45.0
const DUEL_KILL_LIMIT := 10
const DUEL_RESPAWN_DELAY := 3.0
const DUEL_ROUNDS_TO_WIN := 2
const ROUND_BREAK_DURATION := 5.0
const TEAM_ROUND_DURATION := 105.0
const TEAM_RESPAWN_BASE := 3.0
const TEAM_RESPAWN_STEP := 1.0
const TEAM_RESPAWN_MAX := 8.0

var player: ArenaPlayer3D
var selected_hero: String = "AERIS"
var enemies: Array[ArenaPlayer3D] = []
var kills: int = 0
var deaths: int = 0
var deathmatch_scores: Dictionary = {}
var deathmatch_deaths: Dictionary = {}
var round_time: float = ROUND_DURATION
var game_over: bool = false
var duel_round_number: int = 1
var duel_astral_rounds: int = 0
var duel_arcane_rounds: int = 0
var duel_astral_kills: int = 0
var duel_arcane_kills: int = 0
var duel_respawn_timers: Dictionary = {}
var duel_round_transition_left: float = 0.0
var team_round_number: int = 1
var team_astral_rounds: int = 0
var team_arcane_rounds: int = 0
var team_astral_kills: int = 0
var team_arcane_kills: int = 0
var team_respawn_timers: Dictionary = {}
var team_round_transition_left: float = 0.0
var team_sudden_death: bool = false
var duel_sudden_death_active: bool = false
var sudden_death_label: Label
var network_sudden_death_active: bool = false

var wards: Array[Vector3] = [
	Vector3(-5.5, 0.0, -3.0),
	Vector3(5.5, 0.0, 3.0),
	Vector3(6.5, 0.0, -4.0)
]
var objective_position := Vector3(0.0, 0.0, 0.0)

# Map externe : la scène Demo.tscn fournit désormais tout le décor et les collisions.
var map_root: Node3D
var map_bounds_min: Vector3 = Vector3(-15.0, 0.0, -10.0)
var map_bounds_max: Vector3 = Vector3(15.0, 0.0, 10.0)
var map_floor_y: float = 0.0

var world: Node3D
var projectiles: Node3D
var hud: CanvasLayer
var timer_label: Label
var score_label: Label
var subtitle_label: Label
var health_bar_bg: ColorRect
var health_bar_fill: ColorRect
const HERO_HEALTH_BAR_WIDTH: float = 174.0
var health_text: Label
var passive_label: Label
var passive_caption_label: Label
var passive_badge: Panel
var level_badge_label: Label
var health_max_label: Label
var hero_accent_color: Color = Color("58cfff")
var orb_cooldown_label: MOBAAbilityIcon
var nova_cooldown_label: MOBAAbilityIcon
var dash_cooldown_label: MOBAAbilityIcon
var respawn_overlay: Control
var respawn_countdown_label: Label

# =========================================================
# MENU PAUSE (ÉCHAP)
# =========================================================
var pause_menu_open: bool = false
var pause_menu: Control
var pause_root_panel: Control
var pause_options_panel: Control
var pause_master_slider: HSlider
var pause_music_slider: HSlider
var pause_sfx_slider: HSlider
var pause_fov_slider: HSlider
var pause_sensitivity_slider: HSlider
var pause_fullscreen_toggle: CheckButton
var pause_vsync_toggle: CheckButton
var pause_invert_y_toggle: CheckButton
var pause_keybind_orb_button: Button
var pause_keybind_nova_button: Button
var pause_keybind_dash_button: Button
var pause_keybind_move_up_button: Button
var pause_keybind_move_down_button: Button
var pause_keybind_move_left_button: Button
var pause_keybind_move_right_button: Button
var pause_screen_shake_toggle: CheckButton
var pause_damage_numbers_toggle: CheckButton
var pause_camera_height_slider: HSlider
var pause_tutorials_toggle: CheckButton
var pause_ability_hints_toggle: CheckButton
var pause_autosave_toggle: CheckButton
var pause_confirmations_toggle: CheckButton
var pause_indicators_toggle: CheckButton
var pause_screen_shake: bool = true
var pause_damage_numbers: bool = true
var pause_tutorials: bool = true
var pause_ability_hints: bool = true
var pause_autosave: bool = true
var pause_confirmations: bool = true
var pause_indicators: bool = true
var pause_master_volume: float = 78.0
var pause_music_volume: float = 64.0
var pause_sfx_volume: float = 64.0
var pause_fullscreen: bool = false
var pause_vsync: bool = true
# Côté client réseau uniquement : le serveur reste seul autoritaire sur la
# mort/respawn, mais ce timer purement cosmétique permet d'afficher l'écran
# de mort et son compte à rebours localement (piloté par la RPC
# arena_fighter_death, cf. _network_client_fighter_death).
var network_local_respawn_left: float = -1.0
var team_ring_materials: Dictionary = {}
var enemy_health_bars: Dictionary = {}
var vfx_manager: ArenaVFXManager
var thrown_axes: Array[Dictionary] = []
var thrown_daggers: Array[Dictionary] = []
var eren_fire_trails: Array[Dictionary] = []
var eren_trail_hit_cooldowns: Dictionary = {}
var round_end_label: Label
var axe_charge_bar: ProgressBar
var axe_charge_label: Label
var axe_preview: MeshInstance3D
var axe_preview_mesh: ImmediateMesh

var camera: Camera3D
var camera_yaw: float = 0.0
var camera_pitch: float = -0.40
var camera_distance: float = 7.5
var mouse_sensitivity: float = 0.004
var camera_fov: float = 65.0
var camera_height: float = 3.2
var controller_camera_sensitivity: float = 2.8
var controller_camera_deadzone: float = 0.18
var controller_invert_y: bool = false
var last_input_was_controller: bool = false
var controller_device_id: int = -1

# Multiplayer V2
var network_fighters: Dictionary = {}
var network_bot_ids: Array[int] = []
var network_next_bot_id: int = 1001
var network_sync_timer: float = 0.0
var network_server_initialized: bool = false
var network_match_countdown_active: bool = false
var network_match_countdown_left: float = 10.0
var network_match_started: bool = false
var network_round_serial: int = 1
var network_state_sequence: int = 0
var network_last_input_sequence: Dictionary = {}
var network_input_timeout: float = 0.35
var network_snapshot_accumulator: float = 0.0
const NETWORK_SNAPSHOT_RATE: float = 1.0 / 30.0
var network_countdown_display: Label = null
var network_round_time: float = ROUND_DURATION
var network_kills: int = 0
var network_deaths: int = 0
var network_astral_kills: int = 0
var network_arcane_kills: int = 0

func _ready() -> void:
	add_to_group("arena_network")
	var network_node := get_node_or_null("/root/Network")
	if network_node != null:
		selected_hero = str(network_node.get("selected_hero"))
		if selected_hero not in ["AERIS", "MAYLINH", "KAITHLYN", "EREN"]:
			selected_hero = "AERIS"

	_build_world()
	vfx_manager = VFXManagerScene.new()
	vfx_manager.name = "VFXManager"
	add_child(vfx_manager)

	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		if network_node != null and not network_node.arena_client_ready_signal.is_connected(_on_network_client_ready):
			network_node.arena_client_ready_signal.connect(_on_network_client_ready)
		if not multiplayer.peer_disconnected.is_connected(_on_network_peer_disconnected):
			multiplayer.peer_disconnected.connect(_on_network_peer_disconnected)
	else:
		_load_camera_settings()
		_build_camera()
		_build_hud()
		_build_pause_menu()
		_build_axe_preview()
		_create_network_countdown_display()
		if multiplayer.has_multiplayer_peer():
			call_deferred("_send_network_ready")
		else:
			_build_fighters()


func _process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		if not network_server_initialized or player == null or not is_instance_valid(player):
			return

		if network_match_countdown_active:
			network_match_countdown_left = maxf(0.0, network_match_countdown_left - delta)
			_update_network_countdown_display(network_match_countdown_left)
			if network_match_countdown_left <= 0.0:
				network_match_countdown_active = false
				network_match_started = true
				var network_node := get_node_or_null("/root/Network")
				if network_node != null:
					network_node.set("match_started", true)
					Network.arena_match_started.rpc()
				_begin_network_matchplay()
			return

		# Watchdog réseau : si un client cesse d'envoyer ses inputs, le serveur
		# arrête progressivement son mouvement au lieu de conserver le dernier input.
		for peer_id in network_fighters.keys():
			var remote_fighter := network_fighters[peer_id] as ArenaPlayer3D
			if remote_fighter != null and not remote_fighter.is_bot:
				var last_input_time := float(remote_fighter.get_meta("network_last_input_time", -INF))
				if Time.get_ticks_msec() / 1000.0 - last_input_time > network_input_timeout:
					remote_fighter.network_move_direction = Vector3.ZERO

		_update_thrown_axes(delta)
		_update_thrown_daggers(delta)
		_update_eren_fire_trails(delta)
		if _is_duel_mode():
			_update_duel(delta)
		elif _is_team_mode():
			_update_team_mode(delta)
		elif not _is_explore_mode():
			round_time = maxf(0.0, round_time - delta)

		for fighter_node in get_tree().get_nodes_in_group("fighters"):
			var fighter := fighter_node as ArenaPlayer3D
			if fighter != null and fighter.global_position.distance_to(objective_position) < 2.0:
				fighter.health = mini(fighter.max_health, fighter.health + delta * 9.0)

		if not _is_duel_mode() and not _is_team_mode() and not _is_explore_mode() and round_time <= 0.0 and not game_over:
			# En réseau, cette branche ne faisait auparavant que positionner
			# game_over sans jamais appeler _show_round_end() ni prévenir les
			# clients : la partie DEATHMATCH s'arrêtait silencieusement.
			game_over = true
			_show_round_end()
			_broadcast_deathmatch_result()
		network_snapshot_accumulator += delta
		if network_snapshot_accumulator >= NETWORK_SNAPSHOT_RATE:
			network_snapshot_accumulator = fmod(network_snapshot_accumulator, NETWORK_SNAPSHOT_RATE)
			_broadcast_network_state()
		return

	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		# CLIENT : le gameplay reste serveur-authoritaire, mais le compte à
		# rebours est rendu localement entre deux messages réseau.
		if network_match_countdown_active and not network_match_started:
			network_match_countdown_left = maxf(0.0, network_match_countdown_left - delta)
			_update_network_countdown_display(network_match_countdown_left)
		# Correctif : le client ne calculait jamais lui-même le décompte de
		# fin de round (duel_round_transition_left / team_round_transition_left)
		# ni celui de son écran de mort (network_local_respawn_left), car
		# _update_duel()/_update_team_mode() ne tournent que côté serveur.
		# Résultat avant ce correctif : le message "GAGNE LE ROUND" restait
		# affiché en boucle (jamais libéré) et l'écran de mort n'apparaissait
		# jamais chez le client. Ce tick est purement visuel : il ne rejoue
		# aucune logique de jeu (spawn, score...), qui reste 100% serveur.
		_update_client_round_transition_visual(delta)
		_update_network_visuals(delta)
		_update_hud()
		_update_camera(delta)
		_update_thrown_axes(delta)
		_update_thrown_daggers(delta)
		_update_axe_preview()
		_update_team_rings()
		_update_enemy_health_bars()
		_update_hud()
		return

	_update_controller_input(delta)
	if game_over:
		return

	if multiplayer.has_multiplayer_peer() and not network_match_started:
		network_match_countdown_left = maxf(0.0, network_match_countdown_left - delta)
		_update_network_countdown_display(network_match_countdown_left)
		return

	_update_camera(delta)
	_update_thrown_axes(delta)
	_update_thrown_daggers(delta)
	_update_eren_fire_trails(delta)
	_update_axe_preview()
	_update_team_rings()
	_update_enemy_health_bars()
	if _is_duel_mode():
		_update_duel(delta)
	elif _is_team_mode():
		_update_team_mode(delta)
	elif not _is_explore_mode():
		round_time = maxf(0.0, round_time - delta)

	for fighter_node in get_tree().get_nodes_in_group("fighters"):
		var fighter := fighter_node as ArenaPlayer3D
		if fighter != null and fighter.global_position.distance_to(objective_position) < 2.0:
			fighter.health = mini(fighter.max_health, fighter.health + delta * 9.0)

	_update_hud()

	if not _is_duel_mode() and not _is_team_mode() and not _is_explore_mode() and round_time <= 0.0:
		game_over = true
		_show_round_end()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_toggle_pause_menu()
	elif event is InputEventMouseButton and event.pressed:
		last_input_was_controller = false
		# Sans ce garde, cliquer sur un bouton du menu pause (clic gauche)
		# recapturait aussitôt la souris et masquait le curseur en plein
		# milieu du clic, rendant le menu inutilisable à la souris.
		if pause_menu_open:
			return
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(4.5, camera_distance - 0.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(11.0, camera_distance + 0.5)
	elif event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		last_input_was_controller = false
		camera_yaw -= event.relative.x * mouse_sensitivity
		camera_pitch = clampf(camera_pitch - event.relative.y * mouse_sensitivity, -0.62, -0.10)
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		last_input_was_controller = true
		if event is InputEventJoypadButton:
			controller_device_id = event.device
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _update_controller_input(delta: float) -> void:
	# Stick droit direct : aucune dépendance aux actions "look_*" de l'InputMap.
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return

	var device := int(pads[0])
	var look := Vector2(
		Input.get_joy_axis(device, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
	)
	if look.length() <= controller_camera_deadzone:
		return

	last_input_was_controller = true
	look = _apply_stick_deadzone(look, controller_camera_deadzone)
	camera_yaw -= look.x * controller_camera_sensitivity * delta

	var pitch_input: float = -look.y
	if controller_invert_y:
		pitch_input = -pitch_input
	camera_pitch = clampf(camera_pitch + pitch_input * controller_camera_sensitivity * delta, -0.62, -0.10)

func _apply_stick_deadzone(value: Vector2, deadzone: float) -> Vector2:
	var length := value.length()
	if length <= deadzone:
		return Vector2.ZERO
	var remapped := (length - deadzone) / (1.0 - deadzone)
	return value.normalized() * clampf(remapped, 0.0, 1.0)


func _load_camera_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") != OK:
		return
	camera_fov = clampf(float(config.get_value("camera", "fov", 65.0)), 55.0, 90.0)
	camera_height = clampf(float(config.get_value("camera", "height", 3.2)), 2.0, 5.5)
	controller_camera_sensitivity = clampf(float(config.get_value("controller", "camera_sensitivity", 2.8)), 0.5, 6.0)
	controller_invert_y = bool(config.get_value("controller", "invert_y", false))

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "ThirdPersonCamera"
	camera.current = true
	camera.fov = camera_fov
	add_child(camera)
	_update_camera(0.0)

func _update_camera(_delta: float) -> void:
	if player == null or camera == null:
		return

	var target: Vector3 = player.global_position + Vector3.UP * 1.15

	var horizontal_scale: float = cos(camera_pitch)
	var horizontal: Vector3 = Vector3(
		sin(camera_yaw) * horizontal_scale,
		0.0,
		cos(camera_yaw) * horizontal_scale
	)

	var desired: Vector3 = target \
		+ horizontal * camera_distance \
		+ Vector3.UP * (-sin(camera_pitch) * camera_distance)

	# Lissage indépendant des FPS.
	var smoothing: float = 1.0 - exp(-18.0 * _delta)
	camera.global_position = camera.global_position.lerp(desired, smoothing)

	camera.look_at(target, Vector3.UP)

func _build_world() -> void:
	# Si la scène de l'arène (arena.tscn / Arena1v1.tscn) contient déjà ses
	# propres nœuds 3D — une map construite à la main dans l'éditeur — on les
	# utilise tels quels et on NE charge PAS Demo.tscn par-dessus.
	# arena.tscn reste une coquille vide (aucun enfant à ce stade) et continue
	# donc de charger Demo.tscn comme avant. Arena1v1.tscn, elle, a maintenant
	# sa propre géométrie + son propre WorldEnvironment : les charger EN PLUS
	# de Demo.tscn empilait deux maps et deux WorldEnvironment au même
	# endroit, ce qui causait l'écran noir (un des deux WorldEnvironment est
	# ignoré par Godot quand il y en a plusieurs actifs à la fois).
	var custom_map_nodes: Array[Node] = get_children()
	var has_custom_map_content: bool = not custom_map_nodes.is_empty()

	world = Node3D.new()
	world.name = "World"
	add_child(world)

	if has_custom_map_content:
		for child in custom_map_nodes:
			remove_child(child)
			world.add_child(child)
		map_root = world
		# NOTE : la collision de sol et le calcul des limites de la map
		# cherchent un nœud nommé exactement "Terrain" (MeshInstance3D) en
		# enfant direct de la racine de la scène — comme dans Demo.tscn.
		# Nomme ton mesh de sol "Terrain" pour que ça fonctionne pareil.
		_update_map_bounds()
		_create_terrain_collision()
		_rebake_scaled_wall_collisions(map_root)
	else:
		# On ne génère plus l'ancienne arène procédurale bleue.
		# La vraie map est chargée depuis Demo.tscn sans toucher à arena.tscn.
		var demo_path := "res://scenes/Demo.tscn"
		var demo_scene: PackedScene = load(demo_path) as PackedScene if ResourceLoader.exists(demo_path) else null

		if demo_scene != null:
			var map_instance := demo_scene.instantiate()
			world.add_child(map_instance)
			map_root = map_instance as Node3D
			if map_root != null:
				map_root.name = "DemoMap"
				_update_map_bounds()
				_create_terrain_collision()
				_rebake_scaled_wall_collisions(map_root)
		else:
			push_warning("ARENA RIFT : aucune Demo.tscn trouvée dans res://. La partie démarre sans map externe.")

	# Éclairage de secours uniquement si la map (custom ou Demo) n'en fournit pas déjà.
	if world.get_node_or_null("WorldEnvironment") == null and map_root == null:
		var environment_node := WorldEnvironment.new()
		environment_node.name = "WorldEnvironment"
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color("07101d")
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color("8aa8c9")
		environment.ambient_light_energy = 0.72
		environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		environment_node.environment = environment
		world.add_child(environment_node)

	if world.get_node_or_null("Sun") == null:
		var sun := DirectionalLight3D.new()
		sun.name = "Sun"
		sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
		sun.light_energy = 1.35
		sun.shadow_enabled = true
		world.add_child(sun)

	objective_position = Vector3(
		(map_bounds_min.x + map_bounds_max.x) * 0.5,
		map_floor_y,
		(map_bounds_min.z + map_bounds_max.z) * 0.5
	)
	wards = [
		Vector3(lerpf(map_bounds_min.x, map_bounds_max.x, 0.25), map_floor_y, lerpf(map_bounds_min.z, map_bounds_max.z, 0.25)),
		Vector3(lerpf(map_bounds_min.x, map_bounds_max.x, 0.75), map_floor_y, lerpf(map_bounds_min.z, map_bounds_max.z, 0.75)),
		Vector3(lerpf(map_bounds_min.x, map_bounds_max.x, 0.75), map_floor_y, lerpf(map_bounds_min.z, map_bounds_max.z, 0.25))
	]

	projectiles = Node3D.new()
	projectiles.name = "Projectiles"
	add_child(projectiles)

func _find_demo_scene(root_path: String) -> String:
	var dir := DirAccess.open(root_path)
	if dir == null:
		return ""

	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if entry == "." or entry == "..":
			continue
		if dir.current_is_dir():
			if entry.begins_with(".") or entry == "addons":
				continue
			var nested := _find_demo_scene(root_path.path_join(entry))
			if not nested.is_empty():
				dir.list_dir_end()
				return nested
		else:
			if entry.to_lower() == "demo.tscn":
				dir.list_dir_end()
				return root_path.path_join(entry)
	dir.list_dir_end()
	return ""

func _find_terrain_mesh(root: Node) -> MeshInstance3D:
	if root.name == "Terrain" and root is MeshInstance3D:
		return root as MeshInstance3D
	for child in root.get_children():
		var found := _find_terrain_mesh(child)
		if found != null:
			return found
	return null

func _create_terrain_collision() -> void:
	if map_root == null:
		return

	# Recherche récursive : certaines cartes (ex. Arena1v1.tscn) imbriquent
	# Terrain plus profondément (Maps/Terrain) qu'un simple enfant direct de
	# map_root (comme dans Demo.tscn). Un get_node_or_null("Terrain") direct
	# échouait silencieusement pour ces cartes-là, laissant la carte sans
	# aucune collision de sol sur le bon calque.
	var terrain := _find_terrain_mesh(map_root)
	if terrain == null or terrain.mesh == null:
		push_warning("ARENA RIFT : Terrain introuvable dans la map, impossible de créer la collision du sol.")
		return

	# La Demo fournie contient le mesh du terrain mais pas de collider de sol.
	# On en crée un seul, sans toucher aux collisions déjà présentes des bâtiments.
	if terrain.get_node_or_null("ARENA_TerrainCollision") != null:
		return

	var shape: ConcavePolygonShape3D = terrain.mesh.create_trimesh_shape()
	if shape == null:
		push_warning("ARENA RIFT : impossible de générer la collision trimesh du Terrain.")
		return

	var body := StaticBody3D.new()
	body.name = "ARENA_TerrainCollision"
	body.collision_layer = 3
	body.collision_mask = 1

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	body.add_child(collision)
	terrain.add_child(body)

## Godot ne supporte pas correctement une échelle non-uniforme sur un corps
## physique (StaticBody3D) : quand un ancêtre du décor (ex. le nœud "Maps"
## d'Arena1v1.tscn, scale (2.24, 2.71, 2.43)) porte une échelle différente
## par axe, les CollisionShape3D générées à l'import FBX héritent de cette
## échelle et la physique se retrouve fausse — c'est ce qui laissait les
## joueurs traverser les murs intérieurs même quand leur mesh s'affichait
## correctement à l'écran. On reconstruit ici, pour chaque StaticBody3D
## trouvé sous la map, une forme figée en coordonnées MONDE (donc sans
## échelle) portée par un nouveau corps sans échelle, en désactivant
## l'ancien corps devenu inutile.
func _rebake_scaled_wall_collisions(root: Node) -> void:
	if root == null:
		return
	var bodies: Array[StaticBody3D] = []
	_collect_rebakeable_static_bodies(root, bodies)
	print("ARENA RIFT : REBAKE : ", bodies.size(), " StaticBody3D trouvés sous la map.")
	if bodies.is_empty():
		return
	var baked_root := Node3D.new()
	baked_root.name = "BakedWallCollisions"
	add_child(baked_root)
	var baked_count: int = 0
	var skipped_count: int = 0
	for body in bodies:
		var shape_children: Array[CollisionShape3D] = []
		for child in body.get_children():
			if child is CollisionShape3D:
				shape_children.append(child as CollisionShape3D)
		if shape_children.is_empty():
			print("ARENA RIFT : REBAKE : ", body.get_path(), " (", body.name, ") n'a AUCUN CollisionShape3D enfant.")
		for shape_node in shape_children:
			if shape_node.shape == null:
				print("ARENA RIFT : REBAKE : ", shape_node.get_path(), " a un CollisionShape3D sans shape assignée.")
				skipped_count += 1
				continue
			if shape_node.disabled:
				print("ARENA RIFT : REBAKE : ", shape_node.get_path(), " est désactivée (disabled=true), ignorée.")
				skipped_count += 1
				continue
			var world_shape: Shape3D = _bake_shape_to_world(shape_node)
			if world_shape == null:
				print("ARENA RIFT : REBAKE : type de shape non géré (", shape_node.shape.get_class(), ") sur ", shape_node.get_path())
				skipped_count += 1
				continue
			var new_body := StaticBody3D.new()
			new_body.collision_layer = 1
			new_body.collision_mask = 1
			var new_shape := CollisionShape3D.new()
			new_shape.shape = world_shape
			new_body.add_child(new_shape)
			baked_root.add_child(new_body)
			baked_count += 1
		body.collision_layer = 0
		body.collision_mask = 0
	print("ARENA RIFT : REBAKE : ", baked_count, " collisions reconstruites, ", skipped_count, " ignorées.")

func _collect_rebakeable_static_bodies(node: Node, out_list: Array[StaticBody3D]) -> void:
	for child in node.get_children():
		if child is StaticBody3D and child.name != "ARENA_TerrainCollision" and child.name != "MapBoundary":
			out_list.append(child as StaticBody3D)
		_collect_rebakeable_static_bodies(child, out_list)

func _bake_shape_to_world(shape_node: CollisionShape3D) -> Shape3D:
	var world_transform: Transform3D = shape_node.global_transform
	var shape: Shape3D = shape_node.shape
	if shape is ConcavePolygonShape3D:
		var faces: PackedVector3Array = (shape as ConcavePolygonShape3D).get_faces()
		for i in faces.size():
			faces[i] = world_transform * faces[i]
		var world_shape := ConcavePolygonShape3D.new()
		world_shape.set_faces(faces)
		return world_shape
	if shape is ConvexPolygonShape3D:
		var points: PackedVector3Array = (shape as ConvexPolygonShape3D).points.duplicate()
		for i in points.size():
			points[i] = world_transform * points[i]
		var convex_shape := ConvexPolygonShape3D.new()
		convex_shape.points = points
		return convex_shape
	if shape is BoxShape3D:
		var half: Vector3 = (shape as BoxShape3D).size * 0.5
		var local_points: PackedVector3Array = PackedVector3Array([
			Vector3(-half.x, -half.y, -half.z), Vector3(half.x, -half.y, -half.z),
			Vector3(-half.x, half.y, -half.z), Vector3(half.x, half.y, -half.z),
			Vector3(-half.x, -half.y, half.z), Vector3(half.x, -half.y, half.z),
			Vector3(-half.x, half.y, half.z), Vector3(half.x, half.y, half.z),
		])
		for i in local_points.size():
			local_points[i] = world_transform * local_points[i]
		var box_shape := ConvexPolygonShape3D.new()
		box_shape.points = local_points
		return box_shape
	return null

func _update_map_bounds() -> void:
	if map_root == null:
		return

	# Les limites de la map doivent venir du mesh Terrain uniquement.
	# Les bâtiments peuvent avoir des AABB très bas/hauts et fausser le Y de spawn.
	var terrain := _find_terrain_mesh(map_root)
	if terrain == null or terrain.mesh == null:
		return

	var aabb: AABB = terrain.get_aabb()
	var corners := [
		Vector3(aabb.position.x, aabb.position.y, aabb.position.z),
		Vector3(aabb.end.x, aabb.position.y, aabb.position.z),
		Vector3(aabb.position.x, aabb.end.y, aabb.position.z),
		Vector3(aabb.position.x, aabb.position.y, aabb.end.z),
		Vector3(aabb.end.x, aabb.end.y, aabb.position.z),
		Vector3(aabb.end.x, aabb.position.y, aabb.end.z),
		Vector3(aabb.position.x, aabb.end.y, aabb.end.z),
		Vector3(aabb.end.x, aabb.end.y, aabb.end.z)
	]

	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	var min_z := INF
	var max_z := -INF
	for corner in corners:
		var point: Vector3 = terrain.global_transform * corner
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)
		min_z = minf(min_z, point.z)
		max_z = maxf(max_z, point.z)

	map_bounds_min = Vector3(min_x, min_y, min_z)
	map_bounds_max = Vector3(max_x, max_y, max_z)
	map_floor_y = min_y
	print("ARENA NETWORK : TERRAIN BOUNDS ", map_bounds_min, " -> ", map_bounds_max)


const ORIGINAL_SPAWN_Y := 0.0

func _map_spawn_positions() -> Dictionary:
	# Si la map fournit son propre nœud "SpawnPoints" (Marker3D nommés
	# Ally_Astral_XX / Enemy_Arcane_XX / Deathmatch_XX, comme dans
	# Arena1v1.tscn), on les utilise en priorité. Sans ça, une map custom
	# héritait des coordonnées codées en dur ci-dessous — calibrées pour
	# Demo.tscn — et les joueurs spawnaient hors de la géométrie de la
	# nouvelle map (dans le vide, hors des murs).
	var spawn_points_node: Node = map_root.get_node_or_null("SpawnPoints") if map_root != null else null
	if spawn_points_node != null:
		var named_children: Array[Node3D] = []
		for child in spawn_points_node.get_children():
			var marker := child as Node3D
			if marker != null:
				named_children.append(marker)
		named_children.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.name < b.name)

		var ally_found: Array[Vector3] = []
		var enemy_found: Array[Vector3] = []
		var deathmatch_found: Array[Vector3] = []
		for marker in named_children:
			var marker_name := String(marker.name)
			if marker_name.begins_with("Ally"):
				ally_found.append(marker.global_position)
			elif marker_name.begins_with("Enemy"):
				enemy_found.append(marker.global_position)
			elif marker_name.begins_with("Deathmatch"):
				deathmatch_found.append(marker.global_position)

		if not ally_found.is_empty() and not enemy_found.is_empty():
			return {
				"ally": ally_found,
				"enemy": enemy_found,
				"deathmatch": deathmatch_found if not deathmatch_found.is_empty() else (ally_found + enemy_found)
			}

	# POINTS DE SPAWN ORIGINAUX D'ARENA RIFT (Demo.tscn), utilisés en repli
	# quand la map n'a pas de nœud "SpawnPoints" dédié.
	# Ne pas recalculer depuis les bounds du Terrain : ces positions ont été
	# placées manuellement sur la map et doivent rester stables entre les rounds.
	var ally_spawns: Array[Vector3] = [
		Vector3(-27.30, ORIGINAL_SPAWN_Y, 18.80),
		Vector3(-13.90, ORIGINAL_SPAWN_Y, 18.80),
		Vector3(-7.99, ORIGINAL_SPAWN_Y, 18.80)
	]
	var enemy_spawns: Array[Vector3] = [
		Vector3(12.39, ORIGINAL_SPAWN_Y, -23.20),
		Vector3(4.741, ORIGINAL_SPAWN_Y, -23.20),
		Vector3(-2.07, ORIGINAL_SPAWN_Y, -23.20)
	]
	var deathmatch_spawns: Array[Vector3] = [
		Vector3(12.59, ORIGINAL_SPAWN_Y, -23.20),
		Vector3(-4.25, ORIGINAL_SPAWN_Y, -23.20),
		Vector3(-20.30, ORIGINAL_SPAWN_Y, -23.20),
		Vector3(-27.90, ORIGINAL_SPAWN_Y, -10.20),
		Vector3(-27.90, ORIGINAL_SPAWN_Y, 9.004),
		Vector3(-21.60, ORIGINAL_SPAWN_Y, 23.78),
		Vector3(-0.74, ORIGINAL_SPAWN_Y, 23.78)
	]
	return {
		"ally": ally_spawns,
		"enemy": enemy_spawns,
		"deathmatch": deathmatch_spawns
	}

func _resolve_spawn_position(spawn_position: Vector3, fighter: ArenaPlayer3D = null) -> Vector3:
	# Les coordonnées X/Z sont volontairement conservées à l'identique (elles
	# ont été placées à la main). Le Y, lui, était figé à ORIGINAL_SPAWN_Y
	# car le Terrain serveur ne générait pas toujours son trimesh — sur
	# Demo.tscn (à peu près plat autour de Y=0) ça ne se voyait pas.
	# Sur une map custom (ex. Arena1v1.tscn) dont le relief varie franchement
	# (constaté : Y entre -1 et 6.3 sur le Terrain), garder Y figé à 0 peut
	# faire apparaître le joueur ENTERRÉ dans le relief ou en suspension loin
	# au-dessus — la caméra se retrouve alors à l'intérieur d'un mesh plein,
	# ce qui donne un écran tout noir malgré un décor qui existe bel et bien.
	# On essaie donc un raycast sol (même méthode/layer que pour les sorts
	# plus bas dans ce fichier) et on ne retombe sur l'ancien comportement
	# figé que si ce raycast échoue, pour ne rien casser sur Demo.tscn.
	var result := Vector3(spawn_position.x, ORIGINAL_SPAWN_Y, spawn_position.z)
	if map_root != null:
		var space_state := get_world_3d().direct_space_state
		var ray_from := Vector3(spawn_position.x, maxf(map_bounds_max.y + 20.0, 20.0), spawn_position.z)
		var ray_to := Vector3(spawn_position.x, minf(map_bounds_min.y - 20.0, -20.0), spawn_position.z)
		var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
		# Layer 2 = terrain, comme pour le raycast sol utilisé pour les sorts.
		query.collision_mask = 2
		query.collide_with_bodies = true
		query.collide_with_areas = false
		var hit: Dictionary = space_state.intersect_ray(query)
		if not hit.is_empty() and hit.has("position"):
			result.y = (hit["position"] as Vector3).y
	print("ARENA NETWORK : SPAWN FIXE ", result)
	return result

func _on_network_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var fighter := network_fighters.get(peer_id) as ArenaPlayer3D
	# Nettoyage immédiat de toutes les références : un objet queue_free peut
	# encore être présent dans un Array pendant quelques frames.
	network_fighters.erase(peer_id)
	if fighter != null:
		duel_respawn_timers.erase(fighter)
		if enemies.has(fighter):
			enemies.erase(fighter)
		if player == fighter:
			player = null
		if is_instance_valid(fighter):
			fighter.queue_free()

	# Choisir un joueur humain encore valide comme nouveau owner logique.
	if player == null:
		for id in network_fighters.keys():
			if int(id) >= 1000:
				continue
			var candidate := network_fighters[id] as ArenaPlayer3D
			if candidate != null and is_instance_valid(candidate) and not candidate.is_bot:
				player = candidate
				break

	for target_id in multiplayer.get_peers():
		var network_node := get_node_or_null("/root/Network")
		if network_node != null:
			network_node.arena_despawn_fighter.rpc_id(int(target_id), peer_id)
	_refresh_network_targets()

func _send_network_ready() -> void:
	var network_node := get_node_or_null("/root/Network")
	if network_node == null or multiplayer.is_server():
		return
	var team: String = str(network_node.get("pending_custom_team"))
	network_node.arena_client_ready.rpc_id(1, selected_hero, str(network_node.get("match_mode")), team)

func _on_network_client_ready(peer_id: int, hero: String, requested_mode: String, requested_team: String = "") -> void:
	if not multiplayer.is_server() or peer_id <= 0:
		return
	if network_fighters.has(peer_id):
		return

	var network_node := get_node_or_null("/root/Network")
	if network_node != null and requested_mode != "":
		network_node.set("match_mode", requested_mode)
	# Si un autre client arrive pendant la préparation, on redonne 10 secondes
	# afin qu'il puisse finir son chargement avant le lancement.
	if network_match_countdown_active:
		network_match_countdown_left = 10.0
		if network_node != null:
			network_node.arena_match_countdown.rpc(10.0)
		_update_network_countdown_display(10.0)
	selected_hero = hero if hero in ["AERIS", "MAYLINH", "KAITHLYN", "EREN"] else "AERIS"

	var spawn_sets: Dictionary = _map_spawn_positions()
	var spawns: Array[Vector3] = spawn_sets["deathmatch"]
	var fighter := PlayerScene.new() as ArenaPlayer3D
	fighter.name = "Player_%d" % peer_id
	fighter.is_bot = false
	fighter.network_peer_id = peer_id
	fighter.hero_id = selected_hero
	# En Custom Game, le camp est choisi par le joueur (ou tiré au sort côté
	# host) avant la connexion et transmis ici. Les autres modes gardent
	# l'ancienne assignation automatique : 1er connecté = ASTRAL, le reste
	# ARCANE (les slots manquants étant comblés par des bots).
	if requested_team == "ASTRAL":
		fighter.team_color = Color("48a9ff")
	elif requested_team == "ARCANE":
		fighter.team_color = Color("ff6276")
	else:
		fighter.team_color = Color("48a9ff") if network_fighters.is_empty() else Color("ff6276")
	fighter.set_multiplayer_authority(peer_id)
	add_child(fighter)
	fighter.global_position = _resolve_spawn_position(spawns[network_fighters.size() % spawns.size()], fighter)
	fighter.spell_cast.connect(_on_spell_cast)
	network_fighters[peer_id] = fighter
	# Sans cette ligne, les kills d'un client (par opposition à ceux de
	# l'hôte ou d'un bot) n'étaient jamais comptabilisés en DEATHMATCH :
	# _handle_combat_death ignore silencieusement tout killer absent de
	# deathmatch_scores (voir ligne ~2238).
	deathmatch_scores[fighter] = 0
	deathmatch_deaths[fighter] = 0
	if player == null:
		player = fighter
		_start_network_match()
	else:
		enemies.append(fighter)

	if not network_server_initialized:
		_start_network_bots()

	_network_broadcast_spawns()
	_refresh_network_targets()
	print("ARENA NETWORK V2 : PLAYER ", peer_id, " SPAWN")

func _start_network_match() -> void:
	# Le premier joueur est chargé, mais on laisse 10 secondes à tous les
	# clients pour terminer leur chargement avant de lancer la simulation.
	if network_match_started or network_match_countdown_active:
		return
	network_server_initialized = true
	network_match_countdown_active = true
	network_match_countdown_left = 10.0
	network_match_started = false
	var network_node := get_node_or_null("/root/Network")
	if network_node != null:
		network_node.set("match_started", false)
		network_node.arena_match_countdown.rpc(10.0)
	_update_network_countdown_display(10.0)
	print("ARENA NETWORK V2 : COMPTE A REBOURS 10 SECONDES")

func _begin_network_matchplay() -> void:
	# Point d'entrée UNIQUE du gameplay après le countdown.
	game_over = false
	if _is_duel_mode():
		_start_duel_round()
	elif _is_team_mode():
		_start_team_round()
	else:
		round_time = ROUND_DURATION
		duel_round_transition_left = 0.0
		team_round_transition_left = 0.0
		_broadcast_network_state()
	print("ARENA NETWORK V3 : GAMEPLAY DEMARRE")


## Panneau réutilisé pour toutes les grandes bannières au centre de l'écran
## (compte à rebours, fin de round, mort subite) : fond arrondi semi-
## transparent avec liseré coloré au lieu d'un simple texte flottant.
func _style_banner_label(label: Label, accent: Color, font_size: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.07, 0.78)
	style.border_color = accent
	style.set_border_width_all(3)
	style.set_corner_radius_all(20)
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 16
	label.add_theme_stylebox_override("normal", style)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", accent)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_constant_override("line_spacing", 6)

## Bannière "MORT SUBITE" : temps écoulé sans départager les deux camps, le
## prochain fighter tué fait perdre le round à son équipe. Reste affichée
## tant que la phase est active (contrairement au panneau de fin de round,
## qui n'apparaît qu'entre deux rounds).
func _show_sudden_death_banner() -> void:
	if hud == null or not is_instance_valid(hud):
		return
	if sudden_death_label != null and is_instance_valid(sudden_death_label):
		return
	sudden_death_label = Label.new()
	sudden_death_label.name = "SuddenDeathBanner"
	sudden_death_label.position = Vector2(390, 110)
	sudden_death_label.size = Vector2(500, 90)
	_style_banner_label(sudden_death_label, Color("ff3b3b"), 30)
	sudden_death_label.text = "MORT SUBITE"
	hud.add_child(sudden_death_label)

func _hide_sudden_death_banner() -> void:
	if sudden_death_label != null and is_instance_valid(sudden_death_label):
		sudden_death_label.queue_free()
	sudden_death_label = null

func _update_network_countdown_display(seconds_left: float) -> void:
	if network_countdown_display == null or not is_instance_valid(network_countdown_display):
		return
	var seconds: int = maxi(0, int(ceil(seconds_left)))
	network_countdown_display.text = "LA PARTIE COMMENCE DANS\n%d" % seconds

func _create_network_countdown_display() -> void:
	if hud == null or not is_instance_valid(hud):
		return
	if network_countdown_display != null and is_instance_valid(network_countdown_display):
		return
	network_countdown_display = Label.new()
	network_countdown_display.name = "NetworkCountdown"
	network_countdown_display.position = Vector2(390, 175)
	network_countdown_display.size = Vector2(500, 130)
	_style_banner_label(network_countdown_display, Color("fff1b8"), 26)
	network_countdown_display.visible = false
	hud.add_child(network_countdown_display)

func _on_network_match_countdown(seconds_left: float) -> void:
	_create_network_countdown_display()
	network_match_countdown_active = seconds_left > 0.0
	network_match_started = false
	network_match_countdown_left = maxf(0.0, seconds_left)
	if network_countdown_display == null:
		return
	network_countdown_display.visible = network_match_countdown_active
	_update_network_countdown_display(network_match_countdown_left)

func _on_network_match_started() -> void:
	network_match_started = true
	network_match_countdown_active = false
	if network_countdown_display != null and is_instance_valid(network_countdown_display):
		network_countdown_display.visible = false

func _start_network_bots() -> void:
	var mode_value := mode_value_for_bots()
	var bot_count := 4
	if mode_value == "1V1 DUEL":
		bot_count = 1
	elif mode_value == "2V2 CLASH":
		bot_count = 3
	elif mode_value == "3V3 RIVALRY":
		bot_count = 5
	elif mode_value == "CUSTOM GAME" or mode_value == "CUSTOM DEATHMATCH" or mode_value == "CUSTOM EXPLORE":
		# Custom Game (équipes, FFA ou Découverte) : uniquement des joueurs
		# réels, jamais de bot pour compléter.
		bot_count = 0

	var spawn_sets: Dictionary = _map_spawn_positions()
	var spawns: Array[Vector3] = spawn_sets["deathmatch"]
	for index in bot_count:
		var bot_id := network_next_bot_id
		network_next_bot_id += 1
		network_bot_ids.append(bot_id)
		var bot := PlayerScene.new() as ArenaPlayer3D
		bot.name = "Bot_%d" % (index + 1)
		bot.is_bot = true
		bot.network_peer_id = bot_id
		bot.network_round_serial = network_round_serial
		bot.hero_id = "AERIS"
		var mode_team := mode_value == "2V2 CLASH" or mode_value == "3V3 RIVALRY"
		var allies_needed := 1 if mode_value == "2V2 CLASH" else 2 if mode_value == "3V3 RIVALRY" else 0
		bot.team_color = player.team_color if mode_team and index < allies_needed else Color("ff6276")
		add_child(bot)
		bot.global_position = _resolve_spawn_position(spawns[(index + 1) % spawns.size()], bot)
		bot.spell_cast.connect(_on_spell_cast)
		enemies.append(bot)
		network_fighters[bot_id] = bot
		# Sans ces deux lignes, les kills/morts d'un bot en DEATHMATCH réseau
		# étaient ignorés silencieusement par _handle_combat_death (le garde
		# "if deathmatch_scores.has(killer)" échouait toujours pour un bot).
		deathmatch_scores[bot] = 0
		deathmatch_deaths[bot] = 0

func _network_receive_player_input(peer_id: int, move_direction: Vector3, aim_direction: Vector3, input_sequence: int = 0, jump_pressed: bool = false, sprint_held: bool = false) -> void:
	if not multiplayer.is_server() or peer_id <= 0:
		return
	var fighter := network_fighters.get(peer_id) as ArenaPlayer3D
	if fighter == null or not is_instance_valid(fighter) or fighter.is_bot:
		return
	var last_sequence: int = int(network_last_input_sequence.get(peer_id, -1))
	if input_sequence > 0 and input_sequence <= last_sequence:
		return
	network_last_input_sequence[peer_id] = input_sequence
	fighter.set_meta("network_last_input_time", Time.get_ticks_msec() / 1000.0)
	if move_direction.length_squared() > 1.0:
		move_direction = move_direction.normalized()
	fighter.network_move_direction = move_direction
	if aim_direction.length_squared() > 0.001:
		fighter.network_aim_direction = aim_direction.normalized()
	# "jump_pressed" est répété par le client tant que la touche est encore
	# fraîchement pressée (voir _jump_buffer_left côté ArenaPlayer3D) : sur un
	# canal "unreliable", un seul paquet isolé perdu ne doit pas faire rater
	# le saut. Le serveur ne déclenche le saut qu'une fois (cf. _try_jump).
	if jump_pressed:
		fighter.network_jump_requested = true
	fighter.network_sprint_held = sprint_held

func _network_receive_ability_request(peer_id: int, kind: String, direction: Vector3, value: float = 0.0, input_sequence: int = 0) -> void:
	if not multiplayer.is_server() or peer_id <= 0:
		return
	var fighter := network_fighters.get(peer_id) as ArenaPlayer3D
	if fighter == null or not is_instance_valid(fighter) or fighter.is_bot:
		return
	var allowed := ["dash", "teleport", "orb", "nova", "flee", "charge", "eren_charge", "spirit", "heal", "shield", "axe_throw", "dagger_throw"]
	if kind not in allowed:
		return
	if fighter.process_mode == Node.PROCESS_MODE_DISABLED or fighter.health <= 0.0:
		return
	if direction.length_squared() > 0.001:
		direction.y = 0.0
		direction = direction.normalized()
	fighter.network_aim_direction = direction if direction.length_squared() > 0.001 else fighter.network_aim_direction
	match kind:
		"dash": fighter.try_dash(direction)
		"teleport": fighter.try_teleport(direction)
		"orb": fighter.try_orb(direction)
		"nova": fighter.try_nova()
		"flee": fighter.try_flee()
		"charge": fighter.try_charge(direction)
		"eren_charge": fighter.try_eren_charge(direction)
		"spirit": fighter.try_spirit(direction)
		"heal": fighter.try_heal()
		"shield": fighter.try_shield()
		"axe_throw": fighter.try_throw_axe(direction, clampf(value, 0.0, 1.0))
		"dagger_throw": fighter.try_throw_dagger(direction)

func _refresh_network_targets() -> void:
	var fighters := get_tree().get_nodes_in_group("fighters")
	for node in fighters:
		var fighter := node as ArenaPlayer3D
		if fighter == null or not is_instance_valid(fighter) or not fighter.is_bot:
			continue
		var best: ArenaPlayer3D = null
		var best_distance := INF
		for other_node in fighters:
			var other := other_node as ArenaPlayer3D
			if other == null or other == fighter or not is_instance_valid(other):
				continue
			if other.process_mode == Node.PROCESS_MODE_DISABLED or other.team_color == fighter.team_color:
				continue
			var distance := fighter.global_position.distance_to(other.global_position)
			if distance < best_distance:
				best_distance = distance
				best = other
		fighter.target = best

func _network_broadcast_spawns() -> void:
	var network_node := get_node_or_null("/root/Network")
	if network_node == null or not multiplayer.is_server():
		return
	for target_id in multiplayer.get_peers():
		_network_send_all_to(int(target_id))

func _network_send_all_to(target_id: int) -> void:
	var network_node := get_node_or_null("/root/Network")
	if network_node == null:
		return
	for id in network_fighters.keys():
		var fighter := network_fighters[id] as ArenaPlayer3D
		if fighter == null or not is_instance_valid(fighter):
			continue
		network_node.arena_spawn_fighter.rpc_id(target_id, int(id), fighter.hero_id, fighter.team_color, fighter.global_position, fighter.global_rotation.y, fighter.is_bot)

func _network_client_spawn_fighter(fighter_id: int, hero: String, team: Color, pos: Vector3, rot_y: float, bot: bool) -> void:
	if multiplayer.is_server() or network_fighters.has(fighter_id):
		return
	var fighter := PlayerScene.new() as ArenaPlayer3D
	fighter.name = ("Bot_%d" % (fighter_id - 1000)) if bot else ("Player_%d" % fighter_id)
	fighter.is_bot = bot
	fighter.network_peer_id = fighter_id
	fighter.network_round_serial = network_round_serial
	fighter.hero_id = hero
	fighter.team_color = team
	fighter.set_multiplayer_authority(fighter_id if fighter_id > 0 else 1)
	add_child(fighter)
	fighter.global_position = pos
	fighter.rotation.y = rot_y

	# Garantit que le rendu initial est exactement sur la position réseau.
	var spawn_visual_root := fighter.get("_visual_root") as Node3D
	if spawn_visual_root != null and is_instance_valid(spawn_visual_root):
		spawn_visual_root.position = Vector3.ZERO
		spawn_visual_root.rotation = Vector3.ZERO

	fighter.spell_cast.connect(_on_spell_cast)
	network_fighters[fighter_id] = fighter
	if not bot and fighter_id == multiplayer.get_unique_id():
		player = fighter
	else:
		enemies.append(fighter)

func _network_client_transform(fighter_id: int, pos: Vector3, rot_y: float, net_velocity: Vector3, health_value: float = 100.0, round_serial: int = 1, state_sequence: int = 0) -> void:
	var fighter := network_fighters.get(fighter_id) as ArenaPlayer3D
	if fighter == null or not is_instance_valid(fighter):
		return
	# Le joueur local reste prédit côté client pour conserver une réponse instantanée.
	# Le serveur reste l'autorité : on ne snap que si l'erreur dépasse le seuil.
	if round_serial < fighter.network_round_serial:
		return
	if round_serial == fighter.network_round_serial and state_sequence > 0 and int(fighter.get_meta("network_state_sequence", -1)) >= state_sequence:
		return
	fighter.network_round_serial = round_serial
	fighter.set_meta("network_state_sequence", state_sequence)

	# Le RPC publie uniquement une cible. Le déplacement visuel est fait chaque
	# frame par _update_network_visuals(), ce qui évite le saut 20/30 Hz.
	fighter.network_target_position = pos
	fighter.network_target_rotation_y = rot_y
	fighter.network_visual_velocity = net_velocity
	fighter.velocity = net_velocity
	fighter.network_has_snapshot = true
	fighter.health = clampf(health_value, 0.0, fighter.max_health)

	# VisualRoot reste géré localement par le joueur et ne reçoit jamais de transform monde.

func _update_network_visuals(delta: float) -> void:
	for id in network_fighters.keys():
		var fighter := network_fighters[id] as ArenaPlayer3D
		if fighter == null or not is_instance_valid(fighter) or not fighter.network_has_snapshot:
			continue

		var is_local := int(id) == multiplayer.get_unique_id()
		var error := fighter.global_position.distance_to(fighter.network_target_position)

		if is_local:
			if error > 1.75:
				fighter.global_position = fighter.network_target_position
			else:
				var correction_blend := 1.0 - exp(-7.5 * delta)
				fighter.global_position = fighter.global_position.lerp(fighter.network_target_position, correction_blend)
			var rot_blend := 1.0 - exp(-12.0 * delta)
			fighter.rotation.y = lerp_angle(fighter.rotation.y, fighter.network_target_rotation_y, rot_blend)
		else:
			if error > 3.0:
				fighter.global_position = fighter.network_target_position
			else:
				var remote_blend := 1.0 - exp(-18.0 * delta)
				fighter.global_position = fighter.global_position.lerp(fighter.network_target_position, remote_blend)
			var remote_rot_blend := 1.0 - exp(-20.0 * delta)
			fighter.rotation.y = lerp_angle(fighter.rotation.y, fighter.network_target_rotation_y, remote_rot_blend)

		var visual_root := fighter.get("_visual_root") as Node3D
		if visual_root != null and is_instance_valid(visual_root):
			visual_root.position = Vector3.ZERO
			visual_root.rotation = Vector3.ZERO

func _network_client_hard_correction(fighter_id: int, pos: Vector3, rot_y: float, net_velocity: Vector3, health_value: float, round_serial: int, state_sequence: int) -> void:
	var fighter := network_fighters.get(fighter_id) as ArenaPlayer3D
	if fighter == null or not is_instance_valid(fighter):
		return
	if round_serial < fighter.network_round_serial:
		return
	fighter.network_round_serial = round_serial
	fighter.set_meta("network_state_sequence", state_sequence)
	fighter.global_position = pos
	fighter.rotation.y = rot_y
	fighter.velocity = net_velocity
	fighter.network_target_position = pos
	fighter.network_target_rotation_y = rot_y
	fighter.network_visual_velocity = net_velocity
	fighter.network_has_snapshot = true
	fighter.health = clampf(health_value, 0.0, fighter.max_health)
	var visual_root := fighter.get("_visual_root") as Node3D
	if visual_root != null and is_instance_valid(visual_root):
		visual_root.position = Vector3.ZERO
		visual_root.rotation = Vector3.ZERO

func _network_client_match_state(time_left: float, local_kills: int, local_deaths: int, astral_kills: int, arcane_kills: int, team_astral: int, team_arcane: int, serial: int, sudden_death: bool = false, match_kills: int = 0, match_damage_dealt: float = 0.0) -> void:
	if serial < network_round_serial:
		return
	network_round_serial = serial
	network_round_time = maxf(0.0, time_left)
	kills = local_kills
	deaths = local_deaths
	duel_astral_kills = astral_kills
	duel_arcane_kills = arcane_kills
	team_astral_kills = team_astral
	team_arcane_kills = team_arcane
	# "match_kills"/"match_damage_dealt" ne sont jamais calculés localement
	# côté client (les dégâts/kills restent autoritaires côté serveur) : sans
	# cette synchronisation, le tableau de score de fin de partie affichait
	# toujours 0 pour un client distant.
	if player != null and is_instance_valid(player):
		player.match_kills = match_kills
		player.match_damage_dealt = match_damage_dealt
	if sudden_death != network_sudden_death_active:
		network_sudden_death_active = sudden_death
		if sudden_death:
			_show_sudden_death_banner()
		else:
			_hide_sudden_death_banner()
	_update_hud()

func _network_client_damage_vfx(kind: String, position: Vector3, direction: Vector3) -> void:
	if vfx_manager == null or not is_instance_valid(vfx_manager):
		return
	match kind:
		"aeris": vfx_manager.spawn_aeris_hit(self, position)
		"maylinh": vfx_manager.spawn_maylinh_hit(self, position)
		"eren": vfx_manager.spawn_eren_fire_impact(self, position, 0.65)
		"damage": vfx_manager.spawn_damage_flash(self, position, direction)

func _broadcast_damage_vfx(kind: String, position: Vector3, direction: Vector3 = Vector3.ZERO) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var network_node := get_node_or_null("/root/Network")
	if network_node == null:
		return
	for peer_id in multiplayer.get_peers():
		network_node.arena_damage_vfx.rpc_id(int(peer_id), kind, position, direction)

func _network_client_despawn_fighter(fighter_id: int) -> void:
	var fighter := network_fighters.get(fighter_id) as ArenaPlayer3D
	if fighter != null and is_instance_valid(fighter):
		fighter.queue_free()
	network_fighters.erase(fighter_id)

func _broadcast_network_state() -> void:
	var network_node := get_node_or_null("/root/Network")
	if network_node == null or not multiplayer.is_server():
		return
	network_state_sequence += 1
	for id in network_fighters.keys():
		var fighter := network_fighters[id] as ArenaPlayer3D
		if fighter == null or not is_instance_valid(fighter):
			continue
		if fighter.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		network_node.arena_transform.rpc(int(id), fighter.global_position, fighter.global_rotation.y, fighter.velocity, fighter.health, network_round_serial, network_state_sequence)
		# En DEATHMATCH, chaque client doit recevoir SON PROPRE score, pas
		# celui de "player" (qui, sur un serveur dédié headless, correspond
		# en réalité au premier client connecté - cf. _on_network_client_ready).
		# Avant ce correctif, tout le monde recevait exactement les mêmes
		# valeurs de kills/deaths : seul le premier joueur connecté voyait
		# son vrai score, tous les autres voyaient CELUI DU PREMIER JOUEUR.
		var fighter_kills: int = int(deathmatch_scores.get(fighter, 0))
		var fighter_deaths: int = int(deathmatch_deaths.get(fighter, 0))
		network_node.arena_match_state.rpc_id(int(id), round_time, fighter_kills, fighter_deaths, duel_astral_kills, duel_arcane_kills, team_astral_kills, team_arcane_kills, network_round_serial, duel_sudden_death_active or team_sudden_death, fighter.match_kills, fighter.match_damage_dealt)

func _build_fighters() -> void:
	player = PlayerScene.new()
	player.name = "Player"
	player.is_bot = false
	player.team_color = Color("48a9ff")
	player.hero_id = selected_hero
	add_child(player)
	var spawn_sets: Dictionary = _map_spawn_positions()
	var ally_spawns: Array[Vector3] = spawn_sets["ally"]
	var enemy_spawns: Array[Vector3] = spawn_sets["enemy"]
	var deathmatch_spawns: Array[Vector3] = spawn_sets["deathmatch"]
	var mode_value := mode_value_for_bots()
	player.global_position = _resolve_spawn_position(deathmatch_spawns[0] if mode_value == "DEATHMATCH" else ally_spawns[0], player)
	player.spell_cast.connect(_on_spell_cast)

	var bot_count := 4
	if mode_value == "1V1 DUEL":
		bot_count = 1
	elif mode_value == "2V2 CLASH":
		bot_count = 3
	elif mode_value == "3V3 RIVALRY":
		bot_count = 5

	for index in bot_count:
		var enemy := PlayerScene.new()
		enemy.name = "Bot_%d" % (index + 1)
		enemy.is_bot = true
		var is_team_mode: bool = mode_value == "2V2 CLASH" or mode_value == "3V3 RIVALRY"
		var allies_needed: int = 1 if mode_value == "2V2 CLASH" else 2 if mode_value == "3V3 RIVALRY" else 0
		var is_ally: bool = is_team_mode and index < allies_needed
		enemy.team_color = player.team_color if is_ally else Color("ff6276")
		enemy.hero_id = "AERIS"
		add_child(enemy)
		if mode_value == "DEATHMATCH":
			enemy.global_position = _resolve_spawn_position(deathmatch_spawns[(index + 1) % deathmatch_spawns.size()], enemy)
		else:
			enemy.global_position = _resolve_spawn_position(ally_spawns[index + 1] if is_ally else enemy_spawns[index - allies_needed], enemy)
		enemy.spell_cast.connect(_on_spell_cast)
		enemies.append(enemy)

	deathmatch_scores.clear()
	deathmatch_scores[player] = 0
	deathmatch_deaths.clear()
	deathmatch_deaths[player] = 0
	for fighter in enemies:
		deathmatch_scores[fighter] = 0
		deathmatch_deaths[fighter] = 0

	if _is_team_mode():
		_start_team_round()
	else:
		var ally: ArenaPlayer3D = enemies[0] if not enemies.is_empty() and enemies[0].team_color == player.team_color else null
		if ally != null:
			ally.target = enemies[1] if enemies.size() > 1 else player
		for enemy in enemies:
			if enemy.team_color != player.team_color:
				enemy.target = player

func mode_value_for_bots() -> String:
	var network_node := get_node_or_null("/root/Network")
	return str(network_node.get("match_mode")) if network_node != null else "DEATHMATCH"

## Mode Découverte (Custom Game) : pas de round, pas de fin de partie, temps
## illimité pour tester une map librement.
func _is_explore_mode() -> bool:
	return mode_value_for_bots() == "CUSTOM EXPLORE"

func _is_duel_mode() -> bool:
	return mode_value_for_bots() == "1V1 DUEL"

func _is_team_mode() -> bool:
	var mode_value := mode_value_for_bots()
	return mode_value == "2V2 CLASH" or mode_value == "3V3 RIVALRY" or mode_value == "CUSTOM GAME"

func _team_size() -> int:
	return 2 if mode_value_for_bots() == "2V2 CLASH" else 3

func _update_team_rings() -> void:
	if player == null or not is_instance_valid(player):
		return

	for fighter_node in get_tree().get_nodes_in_group("fighters"):
		var fighter := fighter_node as ArenaPlayer3D
		if fighter == null or not is_instance_valid(fighter):
			continue

		var ring := fighter.get_node_or_null("TeamRing") as MeshInstance3D
		if ring == null:
			ring = _create_team_ring(fighter)

		ring.visible = fighter.process_mode != Node.PROCESS_MODE_DISABLED

func _create_team_ring(fighter: ArenaPlayer3D) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	ring.name = "TeamRing"
	ring.position = Vector3(0.0, 0.035, 0.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var torus := TorusMesh.new()
	torus.inner_radius = 0.72
	torus.outer_radius = 0.86
	torus.rings = 32
	torus.ring_segments = 12
	ring.mesh = torus

	var material := StandardMaterial3D.new()
	var is_ally: bool = fighter.team_color == player.team_color
	var ring_color: Color = Color("43ff9b") if is_ally else Color("ff3d55")
	material.albedo_color = ring_color
	material.emission_enabled = true
	material.emission = ring_color
	material.emission_energy_multiplier = 2.6
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.95
	ring.material_override = material

	fighter.add_child(ring)
	return ring

const ENEMY_HEALTH_BAR_MAX_RANGE: float = 26.0

## Petite barre de vie flottante au-dessus de la tête de chaque ennemi
## (les alliés n'en ont pas besoin, ils ont déjà l'anneau au sol + leur
## propre HUD). Projection écran mise à jour chaque frame, cachée si
## l'ennemi est mort, hors champ, derrière la caméra, trop loin ou masqué
## par un mur/obstacle (sinon elle se voyait à travers les murs).
func _update_enemy_health_bars() -> void:
	if hud == null or not is_instance_valid(hud) or player == null or not is_instance_valid(player):
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var seen: Dictionary = {}
	for fighter_node in get_tree().get_nodes_in_group("fighters"):
		var fighter := fighter_node as ArenaPlayer3D
		if fighter == null or not is_instance_valid(fighter) or fighter == player:
			continue
		if fighter.team_color == player.team_color:
			continue
		var bar := enemy_health_bars.get(fighter) as Control
		if fighter.process_mode == Node.PROCESS_MODE_DISABLED or fighter.health <= 0.0 or camera == null:
			if bar != null and is_instance_valid(bar):
				bar.visible = false
			continue
		if bar == null or not is_instance_valid(bar):
			bar = _create_enemy_health_bar()
			enemy_health_bars[fighter] = bar
		seen[fighter] = true
		var head_position: Vector3 = fighter.global_position + Vector3.UP * 2.15
		if camera.is_position_behind(head_position):
			bar.visible = false
			continue
		if camera.global_position.distance_to(head_position) > ENEMY_HEALTH_BAR_MAX_RANGE:
			bar.visible = false
			continue
		if not _raycast_map_obstacle(camera.global_position, head_position, player).is_empty():
			# Un mur/obstacle coupe la ligne de vue entre la caméra et
			# l'ennemi : on cache la barre plutôt que de la laisser
			# transparaître à travers le décor.
			bar.visible = false
			continue
		var screen_pos: Vector2 = camera.unproject_position(head_position)
		if screen_pos.x < -50.0 or screen_pos.x > viewport_size.x + 50.0 or screen_pos.y < -50.0 or screen_pos.y > viewport_size.y + 50.0:
			bar.visible = false
			continue
		bar.visible = true
		bar.position = screen_pos - Vector2(32.0, 6.0)
		var fill := bar.get_node("Fill") as ColorRect
		var ratio: float = clampf(fighter.health / maxf(1.0, fighter.max_health), 0.0, 1.0)
		fill.size.x = 60.0 * ratio
		fill.color = Color("62e6a7") if ratio > 0.5 else (Color("ffcc55") if ratio > 0.25 else Color("ff5c5c"))
	for fighter in enemy_health_bars.keys():
		if seen.has(fighter):
			continue
		var stale_fighter := fighter as ArenaPlayer3D
		if stale_fighter == null or not is_instance_valid(stale_fighter):
			var bar: Control = enemy_health_bars[fighter]
			if bar != null and is_instance_valid(bar):
				bar.queue_free()
			enemy_health_bars.erase(fighter)

func _create_enemy_health_bar() -> Control:
	var container := Control.new()
	container.name = "EnemyHealthBar"
	container.size = Vector2(64, 8)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.z_index = 10

	var background := ColorRect.new()
	background.name = "Background"
	background.size = Vector2(64, 8)
	background.color = Color(0.05, 0.03, 0.02, 0.85)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(background)

	var border := ColorRect.new()
	border.name = "Border"
	border.position = Vector2(-1, -1)
	border.size = Vector2(66, 10)
	border.color = Color(0.0, 0.0, 0.0, 0.6)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.z_index = -1
	container.add_child(border)

	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.position = Vector2(2, 2)
	fill.size = Vector2(60, 4)
	fill.color = Color("62e6a7")
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(fill)

	hud.add_child(container)
	return container

func _start_team_round() -> void:
	if player == null or not is_instance_valid(player):
		return
	network_round_serial += 1
	kills = 0
	deaths = 0
	team_astral_kills = 0
	team_arcane_kills = 0
	round_time = TEAM_ROUND_DURATION
	team_sudden_death = false
	_hide_sudden_death_banner()
	team_respawn_timers.clear()
	team_round_transition_left = 0.0
	if round_end_label != null and is_instance_valid(round_end_label):
		round_end_label.queue_free()
		round_end_label = null
	var spawn_sets: Dictionary = _map_spawn_positions()
	var ally_spawns: Array[Vector3] = spawn_sets["ally"]
	var enemy_spawns: Array[Vector3] = spawn_sets["enemy"]

	_reset_duel_fighter(player, ally_spawns[0])
	_network_round_reset_fighter(player)
	var ally_index := 1
	for enemy in enemies:
		if enemy.team_color == player.team_color:
			var ally_spawn_index: int = min(ally_index, ally_spawns.size() - 1)
			_reset_duel_fighter(enemy, ally_spawns[ally_spawn_index])
			_network_round_reset_fighter(enemy)
			ally_index += 1
	var enemy_index := 0
	for enemy in enemies:
		if enemy.team_color != player.team_color:
			var enemy_spawn_index: int = min(enemy_index, enemy_spawns.size() - 1)
			_reset_duel_fighter(enemy, enemy_spawns[enemy_spawn_index])
			_network_round_reset_fighter(enemy)
			enemy_index += 1
	_network_broadcast_spawns()
	_broadcast_network_state()
	_refresh_team_targets()

func _team_respawn_delay() -> float:
	if team_sudden_death:
		return -1.0
	var elapsed := TEAM_ROUND_DURATION - round_time
	var steps := int(floor(elapsed / 30.0))
	return minf(TEAM_RESPAWN_BASE + float(steps) * TEAM_RESPAWN_STEP, TEAM_RESPAWN_MAX)

func _refresh_team_targets() -> void:
	if not _is_team_mode():
		return
	for node in get_tree().get_nodes_in_group("fighters"):
		var fighter := node as ArenaPlayer3D
		if fighter == null or not is_instance_valid(fighter) or not fighter.is_bot or fighter.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		var best: ArenaPlayer3D = null
		var best_distance := INF
		for other_node in get_tree().get_nodes_in_group("fighters"):
			var other := other_node as ArenaPlayer3D
			if other == null or other == fighter or not is_instance_valid(other) or other.process_mode == Node.PROCESS_MODE_DISABLED:
				continue
			if other.team_color == fighter.team_color:
				continue
			var d := fighter.global_position.distance_to(other.global_position)
			if d < best_distance:
				best_distance = d
				best = other
		fighter.target = best

func _team_alive_count(team_color: Color) -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("fighters"):
		var fighter := node as ArenaPlayer3D
		if fighter != null and is_instance_valid(fighter) and fighter.team_color == team_color and fighter.process_mode != Node.PROCESS_MODE_DISABLED:
			count += 1
	return count

func _handle_team_death(victim: ArenaPlayer3D, killer: ArenaPlayer3D) -> void:
	if victim == null or not is_instance_valid(victim) or killer == null or not is_instance_valid(killer):
		return
	if killer.team_color == victim.team_color:
		return
	if killer.team_color == player.team_color:
		team_astral_kills += 1
		if killer == player:
			kills += 1
	else:
		team_arcane_kills += 1
		if victim == player:
			deaths += 1
	victim.visible = false
	victim.process_mode = Node.PROCESS_MODE_DISABLED
	victim.collision_layer = 0
	victim.collision_mask = 0
	victim.velocity = Vector3.ZERO
	var delay := _team_respawn_delay()
	if delay >= 0.0:
		team_respawn_timers[victim] = delay
		_broadcast_fighter_death(victim, delay)
	_check_team_elimination()

func _check_team_elimination() -> void:
	if team_round_transition_left > 0.0 or game_over:
		return
	if player == null or not is_instance_valid(player):
		return
	var astral_alive := _team_alive_count(player.team_color)
	var arcane_alive := _team_alive_count(Color("ff6276"))
	if arcane_alive <= 0:
		_finish_team_round(true)
	elif astral_alive <= 0:
		_finish_team_round(false)

func _finish_team_round(astral_wins: bool) -> void:
	if team_round_transition_left > 0.0 or game_over:
		return
	team_sudden_death = false
	_hide_sudden_death_banner()
	if astral_wins:
		team_astral_rounds += 1
	else:
		team_arcane_rounds += 1
	if team_astral_rounds >= DUEL_ROUNDS_TO_WIN or team_arcane_rounds >= DUEL_ROUNDS_TO_WIN:
		game_over = true
		_broadcast_round_result("TEAM", team_astral_rounds, team_arcane_rounds, team_round_number, true, astral_wins)
		_show_team_match_end(astral_wins)
		return
	team_round_number += 1
	team_round_transition_left = ROUND_BREAK_DURATION
	_broadcast_round_result("TEAM", team_astral_rounds, team_arcane_rounds, team_round_number, false, astral_wins)
	_show_team_round_winner(astral_wins)

func _show_team_round_winner(astral_wins: bool) -> void:
	if round_end_label != null and is_instance_valid(round_end_label):
		round_end_label.queue_free()

	round_end_label = Label.new()
	round_end_label.position = Vector2(340, 240)
	round_end_label.size = Vector2(600, 190)
	var team_accent: Color = Color("48a9ff") if astral_wins else Color("ff6276")
	_style_banner_label(round_end_label, team_accent, 30)
	round_end_label.text = "%s GAGNE LE ROUND\nBO3 : %d — %d\n\nPROCHAIN ROUND DANS %d" % [("ASTRAL" if astral_wins else "ARCANE"), team_astral_rounds, team_arcane_rounds, int(ROUND_BREAK_DURATION)]
	hud.add_child(round_end_label)

## Version client (purement visuelle) de la gestion du décompte affiché par
## round_end_label. Elle ne fait que rafraîchir/masquer le label ; le vrai
## changement de round (spawns, scores) arrive toujours via les RPC
## arena_round_result / arena_round_reset envoyées par le serveur. On calque
## volontairement la même durée (ROUND_BREAK_DURATION) que côté serveur pour
## rester synchronisé à l'affichage près.
func _update_client_round_transition_visual(delta: float) -> void:
	if duel_round_transition_left > 0.0:
		_update_round_transition_label(duel_round_transition_left)
		duel_round_transition_left = maxf(0.0, duel_round_transition_left - delta)
		if duel_round_transition_left <= 0.0 and round_end_label != null and is_instance_valid(round_end_label):
			round_end_label.queue_free()
			round_end_label = null
	elif team_round_transition_left > 0.0:
		_update_round_transition_label(team_round_transition_left)
		team_round_transition_left = maxf(0.0, team_round_transition_left - delta)
		if team_round_transition_left <= 0.0 and round_end_label != null and is_instance_valid(round_end_label):
			round_end_label.queue_free()
			round_end_label = null

	if network_local_respawn_left >= 0.0:
		network_local_respawn_left = maxf(0.0, network_local_respawn_left - delta)

## Reçu côté client uniquement, en réponse à la RPC arena_fighter_death.
## Avant ce correctif, la mort en cours de round n'était jamais signalée au
## réseau : le fighter mort restait visible/actif chez les autres clients,
## et la victime elle-même ne voyait jamais son écran de mort puisque
## duel_respawn_timers / team_respawn_timers ne sont peuplés que côté
## serveur et ne sont jamais répliqués.
func _network_client_fighter_death(fighter_id: int, respawn_delay: float) -> void:
	var fighter := network_fighters.get(fighter_id) as ArenaPlayer3D
	if fighter == null or not is_instance_valid(fighter):
		return
	fighter.visible = false
	fighter.process_mode = Node.PROCESS_MODE_DISABLED
	fighter.collision_layer = 0
	fighter.collision_mask = 0
	fighter.velocity = Vector3.ZERO
	if fighter == player:
		network_local_respawn_left = respawn_delay

func _update_round_transition_label(time_left: float) -> void:
	if round_end_label == null or not is_instance_valid(round_end_label):
		return
	var seconds_left: int = maxi(0, int(ceil(time_left)))
	var previous_text := round_end_label.text
	var lines := previous_text.split("\n")
	var result_text := previous_text
	if lines.size() > 0:
		result_text = lines[0]
		if lines.size() > 1:
			result_text += "\n" + lines[1]
	round_end_label.text = result_text + "\n\nPROCHAIN ROUND DANS %d" % seconds_left

func _update_team_mode(delta: float) -> void:
	if game_over:
		return
	if player == null or not is_instance_valid(player):
		return
	if team_round_transition_left > 0.0:
		_update_round_transition_label(team_round_transition_left)
		team_round_transition_left = maxf(0.0, team_round_transition_left - delta)
		if team_round_transition_left <= 0.0:
			_start_team_round()
		return
	round_time = maxf(0.0, round_time - delta)
	team_sudden_death = round_time <= 30.0
	if team_sudden_death:
		_show_sudden_death_banner()
	else:
		_hide_sudden_death_banner()
	var ready_respawns: Array[ArenaPlayer3D] = []
	for key in team_respawn_timers.keys():
		team_respawn_timers[key] = maxf(0.0, float(team_respawn_timers[key]) - delta)
		if float(team_respawn_timers[key]) <= 0.0:
			ready_respawns.append(key as ArenaPlayer3D)
	for fighter in ready_respawns:
		team_respawn_timers.erase(fighter)
		_respawn_team_fighter(fighter)
	_refresh_team_targets()
	_check_team_elimination()
	if round_time <= 0.0:
		var astral_alive := _team_alive_count(player.team_color)
		var arcane_alive := _team_alive_count(Color("ff6276"))
		if astral_alive != arcane_alive:
			_finish_team_round(astral_alive > arcane_alive)
		elif team_astral_kills != team_arcane_kills:
			_finish_team_round(team_astral_kills > team_arcane_kills)
		else:
			_finish_team_round(true)

func _respawn_team_fighter(fighter: ArenaPlayer3D) -> void:
	if fighter == null or not is_instance_valid(fighter):
		return
	if fighter == player and respawn_overlay != null:
		respawn_overlay.visible = false

	var spawn_sets: Dictionary = _map_spawn_positions()
	var ally_spawns: Array[Vector3] = spawn_sets["ally"]
	var enemy_spawns: Array[Vector3] = spawn_sets["enemy"]

	if fighter.team_color == player.team_color:
		var ally_index := 0
		if fighter != player:
			ally_index = 1
			for enemy in enemies:
				if enemy == fighter:
					break
				if enemy.team_color == player.team_color:
					ally_index += 1
		_reset_duel_fighter(fighter, ally_spawns[min(ally_index, ally_spawns.size() - 1)])
	else:
		var enemy_index := 0
		for enemy in enemies:
			if enemy == fighter:
				break
			if enemy.team_color != player.team_color:
				enemy_index += 1
		_reset_duel_fighter(fighter, enemy_spawns[min(enemy_index, enemy_spawns.size() - 1)])
	# Avant ce correctif, un respawn en cours de round (contrairement à un
	# reset de round complet) n'était jamais notifié aux clients : ils ne
	# récupéraient la nouvelle position/visibilité que via le prochain
	# snapshot périodique, avec plusieurs dizaines de ms de retard, et sans
	# jamais fermer l'écran de mort côté victime.
	_network_round_reset_fighter(fighter)

func _update_duel(delta: float) -> void:
	if game_over:
		return
	if duel_round_transition_left > 0.0:
		_update_round_transition_label(duel_round_transition_left)
		duel_round_transition_left = maxf(0.0, duel_round_transition_left - delta)
		if duel_round_transition_left <= 0.0:
			if round_end_label != null and is_instance_valid(round_end_label):
				round_end_label.queue_free()
				round_end_label = null
			_start_duel_round()
		return

	round_time = maxf(0.0, round_time - delta)
	var ready_respawns: Array[ArenaPlayer3D] = []
	for key in duel_respawn_timers.keys():
		duel_respawn_timers[key] = maxf(0.0, float(duel_respawn_timers[key]) - delta)
		if float(duel_respawn_timers[key]) <= 0.0:
			ready_respawns.append(key as ArenaPlayer3D)
	for fighter in ready_respawns:
		duel_respawn_timers.erase(fighter)
		_respawn_duel_fighter(fighter)

	if kills >= DUEL_KILL_LIMIT or duel_arcane_kills >= DUEL_KILL_LIMIT:
		_finish_duel_round()
	elif round_time <= 0.0:
		if duel_astral_kills != duel_arcane_kills:
			_finish_duel_round()
		elif not duel_sudden_death_active:
			# Avant : un round à égalité à 0:00 (0-0 la plupart du temps) ne
			# désignait aucun vainqueur et recommençait silencieusement. La
			# mort subite tranche désormais : le prochain fighter tué fait
			# perdre le round à son équipe (cf. _handle_duel_death).
			duel_sudden_death_active = true
			_show_sudden_death_banner()
			_broadcast_network_state()

func _start_duel_round() -> void:
	network_round_serial += 1
	network_state_sequence += 1
	kills = 0
	deaths = 0
	duel_astral_kills = 0
	duel_arcane_kills = 0
	round_time = ROUND_DURATION
	game_over = false
	duel_respawn_timers.clear()
	duel_round_transition_left = 0.0
	duel_sudden_death_active = false
	_hide_sudden_death_banner()
	if round_end_label != null and is_instance_valid(round_end_label):
		round_end_label.queue_free()
		round_end_label = null
	var spawn_sets: Dictionary = _map_spawn_positions()
	var ally_spawns: Array[Vector3] = spawn_sets["ally"]
	var enemy_spawns: Array[Vector3] = spawn_sets["enemy"]

	# Nettoyage des références mortes avant tout nouveau round.
	var valid_enemies: Array[ArenaPlayer3D] = []
	for candidate in enemies:
		if candidate != null and is_instance_valid(candidate):
			valid_enemies.append(candidate)
	enemies = valid_enemies

	if player != null and is_instance_valid(player):
		_reset_duel_fighter(player, ally_spawns[0])
		_network_round_reset_fighter(player)

	var enemy_index := 0
	for fighter in enemies:
		if fighter == null or not is_instance_valid(fighter):
			continue
		var spawn := enemy_spawns[min(enemy_index, enemy_spawns.size() - 1)]
		_reset_duel_fighter(fighter, spawn)
		_network_round_reset_fighter(fighter)
		enemy_index += 1

	# Resend complet après le reset : même si un snapshot unreliable est perdu,
	# les clients récupèrent immédiatement l'état du nouveau round.
	_network_broadcast_spawns()
	_broadcast_network_state()
	for id in network_fighters.keys():
		var reset_fighter := network_fighters[id] as ArenaPlayer3D
		if reset_fighter != null and is_instance_valid(reset_fighter):
			_broadcast_hard_correction(reset_fighter)

func _broadcast_round_result(mode: String, astral_rounds: int, arcane_rounds: int, round_number: int, match_over: bool, astral_wins: bool) -> void:
	var network_node := get_node_or_null("/root/Network")
	if network_node == null or not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	for target_id in multiplayer.get_peers():
		network_node.arena_round_result.rpc_id(int(target_id), mode, astral_rounds, arcane_rounds, round_number, match_over, astral_wins)

## Reçu côté client uniquement : synchronise le score de round (BO3) qui,
## avant ce correctif, n'existait que côté serveur. C'est ce qui faisait
## qu'un kill "ne comptait pas" pour les clients — le round se terminait
## bien mais le score et l'écran de fin de round ne leur parvenaient jamais.
func _network_client_round_result(mode: String, astral_rounds: int, arcane_rounds: int, round_number: int, match_over: bool, astral_wins: bool) -> void:
	if mode == "DUEL":
		duel_astral_rounds = astral_rounds
		duel_arcane_rounds = arcane_rounds
		duel_round_number = round_number
		if match_over:
			game_over = true
			_show_duel_match_end(astral_wins)
		else:
			duel_round_transition_left = ROUND_BREAK_DURATION
			_show_duel_round_winner(astral_wins)
	else:
		team_astral_rounds = astral_rounds
		team_arcane_rounds = arcane_rounds
		team_round_number = round_number
		if match_over:
			game_over = true
			_show_team_match_end(astral_wins)
		else:
			team_round_transition_left = ROUND_BREAK_DURATION
			_show_team_round_winner(astral_wins)

func _network_round_reset_fighter(fighter: ArenaPlayer3D) -> void:
	if fighter == null or not is_instance_valid(fighter):
		return
	var network_node := get_node_or_null("/root/Network")
	if network_node == null or not multiplayer.is_server():
		return
	for target_id in multiplayer.get_peers():
		network_node.arena_round_reset.rpc_id(int(target_id), fighter.network_peer_id, fighter.global_position, fighter.global_rotation.y, fighter.health, network_round_serial, network_state_sequence)

func _network_client_round_reset(fighter_id: int, pos: Vector3, rot_y: float, health_value: float, round_number: int, state_sequence: int = 0) -> void:
	var fighter := network_fighters.get(fighter_id) as ArenaPlayer3D
	if fighter == null or not is_instance_valid(fighter):
		return
	fighter.network_round_serial = max(fighter.network_round_serial, round_number)
	fighter.set_meta("network_state_sequence", state_sequence)
	fighter.process_mode = Node.PROCESS_MODE_INHERIT
	fighter.visible = true
	fighter.collision_layer = 1
	fighter.collision_mask = 1
	fighter.global_position = pos
	fighter.rotation.y = rot_y
	fighter.velocity = Vector3.ZERO
	fighter.network_target_position = pos
	fighter.network_target_rotation_y = rot_y
	fighter.network_visual_velocity = Vector3.ZERO
	fighter.network_has_snapshot = true
	fighter.health = clampf(health_value, 0.0, fighter.max_health)
	if fighter == player:
		# Le serveur vient de confirmer la réapparition : on ferme l'écran
		# de mort même si le décompte local n'était pas parfaitement à 0.
		network_local_respawn_left = -1.0
	var visual_root := fighter.get("_visual_root") as Node3D
	if visual_root != null and is_instance_valid(visual_root):
		# Même règle que pendant les snapshots : le VisualRoot reste
		# strictement local au fighter. Le positionner en GLOBAL ici
		# créait un transform différent au moment du changement de round.
		visual_root.position = Vector3.ZERO
		visual_root.rotation = Vector3.ZERO

func _reset_duel_fighter(fighter: ArenaPlayer3D, spawn_position: Vector3) -> void:
	if fighter == null or not is_instance_valid(fighter):
		return
	fighter.network_round_serial = network_round_serial
	fighter.process_mode = Node.PROCESS_MODE_INHERIT
	fighter.visible = true
	fighter.collision_layer = 1
	fighter.collision_mask = 1
	fighter.health = fighter.max_health
	fighter.shield_points = 0.0
	fighter.shield_left = 0.0
	fighter.invulnerable_left = 0.6
	fighter.velocity = Vector3.ZERO
	fighter.global_position = _resolve_spawn_position(spawn_position, fighter)

	# Le VisualRoot ne doit jamais conserver un ancien transform monde
	# entre deux rounds.
	var visual_root := fighter.get("_visual_root") as Node3D
	if visual_root != null and is_instance_valid(visual_root):
		visual_root.position = Vector3.ZERO
		visual_root.rotation = Vector3.ZERO

func _handle_duel_death(victim: ArenaPlayer3D, killer: ArenaPlayer3D) -> void:
	if victim == null or not is_instance_valid(victim):
		return
	if killer == null or not is_instance_valid(killer):
		return
	if killer.team_color == victim.team_color:
		return
	if killer.team_color == player.team_color:
		duel_astral_kills += 1
		kills = duel_astral_kills
	else:
		duel_arcane_kills += 1
		deaths = duel_arcane_kills

	victim.visible = false
	victim.process_mode = Node.PROCESS_MODE_DISABLED
	victim.collision_layer = 0
	victim.collision_mask = 0
	victim.velocity = Vector3.ZERO

	if duel_sudden_death_active:
		# En mort subite, la première mort tranche immédiatement le round :
		# pas de respawn, on ne repasse pas par le décompte normal.
		_broadcast_fighter_death(victim, -1.0)
		_hide_sudden_death_banner()
		_finish_duel_round()
		return

	duel_respawn_timers[victim] = DUEL_RESPAWN_DELAY
	_broadcast_fighter_death(victim, DUEL_RESPAWN_DELAY)

func _respawn_duel_fighter(fighter: ArenaPlayer3D) -> void:
	if fighter == null or not is_instance_valid(fighter):
		return
	var spawn_sets: Dictionary = _map_spawn_positions()
	var spawn: Vector3 = spawn_sets["ally"][0] if fighter == player else spawn_sets["enemy"][0]
	_reset_duel_fighter(fighter, spawn)
	# Cf. _respawn_team_fighter : on notifie le réseau du respawn en cours de
	# round pour synchroniser visibilité/position/vie côté client sans
	# attendre le prochain snapshot périodique.
	_network_round_reset_fighter(fighter)

func _finish_duel_round() -> void:
	if duel_round_transition_left > 0.0 or game_over:
		return
	duel_sudden_death_active = false
	_hide_sudden_death_banner()
	var astral_wins := duel_astral_kills > duel_arcane_kills
	if duel_astral_kills == duel_arcane_kills:
		# En cas d'égalité à 1:30, aucun round n'est accordé.
		duel_round_transition_left = ROUND_BREAK_DURATION
		return
	if astral_wins:
		duel_astral_rounds += 1
	else:
		duel_arcane_rounds += 1
	if duel_astral_rounds >= DUEL_ROUNDS_TO_WIN or duel_arcane_rounds >= DUEL_ROUNDS_TO_WIN:
		game_over = true
		_broadcast_round_result("DUEL", duel_astral_rounds, duel_arcane_rounds, duel_round_number, true, astral_wins)
		_show_duel_match_end(astral_wins)
		return
	duel_round_number += 1
	duel_round_transition_left = ROUND_BREAK_DURATION
	_broadcast_round_result("DUEL", duel_astral_rounds, duel_arcane_rounds, duel_round_number, false, astral_wins)
	_show_duel_round_winner(astral_wins)

func _show_duel_round_winner(astral_wins: bool) -> void:
	if round_end_label != null and is_instance_valid(round_end_label):
		round_end_label.queue_free()
	round_end_label = Label.new()
	round_end_label.position = Vector2(340, 240)
	round_end_label.size = Vector2(600, 190)
	var winner := "ASTRAL" if astral_wins else "ARCANE"
	var duel_accent: Color = Color("48a9ff") if astral_wins else Color("ff6276")
	_style_banner_label(round_end_label, duel_accent, 30)
	round_end_label.text = "%s GAGNE LE ROUND\nBO3 : %d — %d\n\nPROCHAIN ROUND DANS %d" % [winner, duel_astral_rounds, duel_arcane_rounds, int(ROUND_BREAK_DURATION)]
	hud.add_child(round_end_label)


func _show_team_match_end(astral_wins: bool) -> void:
	var winner := "ASTRAL" if astral_wins else "ARCANE"
	var player_won: bool = (player.team_color == Color("48a9ff")) == astral_wins
	_show_match_results(player_won, winner, "BO3 : %d — %d" % [team_astral_rounds, team_arcane_rounds])

func _show_duel_match_end(astral_wins: bool) -> void:
	var winner := "ASTRAL" if astral_wins else "ARCANE"
	var player_won := (player.team_color == Color("48a9ff")) == astral_wins
	_show_match_results(player_won, winner, "BO3 : %d — %d" % [duel_astral_rounds, duel_arcane_rounds])

func _show_match_results(player_won: bool, winner_name: String, score_text: String) -> void:
	var personal_kills: int = int(player.match_kills) if player != null and is_instance_valid(player) else 0
	var damage_dealt: int = int(round(player.match_damage_dealt)) if player != null and is_instance_valid(player) else 0
	var xp_gained: int = PlayerProgress.award_match_xp(player_won, personal_kills)
	if round_end_label != null and is_instance_valid(round_end_label):
		round_end_label.queue_free()
		round_end_label = null

	var overlay := Control.new()
	overlay.name = "MatchResultsOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(overlay)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.025, 0.055, 0.78)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(backdrop)

	var panel := Panel.new()
	panel.position = Vector2(340, 150)
	panel.size = Vector2(600, 420)
	panel.add_theme_stylebox_override("panel", _box(Color("071221f5"), Color("4b8dcc"), 24, 2))
	overlay.add_child(panel)

	var result := Label.new()
	result.position = Vector2(40, 30)
	result.size = Vector2(520, 52)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.text = "VICTOIRE" if player_won else "DÉFAITE"
	result.add_theme_font_size_override("font_size", 42)
	result.add_theme_color_override("font_color", Color("62e6a7") if player_won else Color("ff6276"))
	panel.add_child(result)

	var winner_label := Label.new()
	winner_label.position = Vector2(40, 88)
	winner_label.size = Vector2(520, 32)
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_label.text = ("JOUEUR VAINQUEUR : %s" if mode_value_for_bots() == "DEATHMATCH" else "ÉQUIPE VAINQUEUR : %s") % winner_name
	winner_label.add_theme_font_size_override("font_size", 18)
	winner_label.add_theme_color_override("font_color", Color("eef7ff"))
	panel.add_child(winner_label)

	var score_label_result := Label.new()
	score_label_result.position = Vector2(40, 122)
	score_label_result.size = Vector2(520, 26)
	score_label_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label_result.text = score_text
	score_label_result.add_theme_font_size_override("font_size", 15)
	score_label_result.add_theme_color_override("font_color", Color("8fb0d2"))
	panel.add_child(score_label_result)

	# Tableau de score personnel : kills, dégâts infligés, XP gagnée.
	var stats_panel := Panel.new()
	stats_panel.position = Vector2(70, 160)
	stats_panel.size = Vector2(460, 90)
	stats_panel.add_theme_stylebox_override("panel", _box(Color("0a1a2ecc"), Color("2c5a82"), 14, 1))
	panel.add_child(stats_panel)

	_add_match_stat_column(stats_panel, Vector2(10, 0), "ÉLIMINATIONS", str(maxi(0, personal_kills)), Color("ffd166"))
	_add_match_stat_column(stats_panel, Vector2(163, 0), "DÉGÂTS INFLIGÉS", str(damage_dealt), Color("ff8f6b"))
	_add_match_stat_column(stats_panel, Vector2(316, 0), "XP GAGNÉE", "+%d" % xp_gained, Color("62e6a7"))

	var return_button := Button.new()
	return_button.position = Vector2(145, 300)
	return_button.size = Vector2(310, 62)
	return_button.text = "RETOUR AU MENU"
	return_button.add_theme_font_size_override("font_size", 18)
	return_button.add_theme_stylebox_override("normal", _box(Color("102b49"), Color("58c8ff"), 14, 1))
	return_button.add_theme_stylebox_override("hover", _box(Color("16466d"), Color("9be2ff"), 14, 2))
	return_button.pressed.connect(_return_to_menu)
	panel.add_child(return_button)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

## Une colonne du tableau de score de fin de partie ("ÉLIMINATIONS", valeur, etc).
func _add_match_stat_column(parent: Control, pos: Vector2, label_text: String, value_text: String, accent: Color) -> void:
	var label := Label.new()
	label.position = pos + Vector2(0, 10)
	label.size = Vector2(150, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = label_text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("8fb0d2"))
	parent.add_child(label)

	var value := Label.new()
	value.position = pos + Vector2(0, 32)
	value.size = Vector2(150, 40)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.text = value_text
	value.add_theme_font_size_override("font_size", 26)
	value.add_theme_color_override("font_color", accent)
	parent.add_child(value)

func _return_to_menu() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Sans ceci, quitter la partie via ce bouton ne fermait jamais la connexion
	# ENet : le serveur ne recevait aucun signal de départ et devait attendre
	# le timeout ENet (bien plus long que le délai de grâce du serveur dédié)
	# avant de considérer le joueur comme parti. Résultat concret : relancer
	# une recherche juste après avoir quitté retombait sur l'ancienne partie,
	# puisque le serveur croyait encore le joueur connecté.
	if multiplayer.has_multiplayer_peer():
		var network_node := get_node_or_null("/root/Network")
		if network_node != null:
			network_node.call("close")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _network_receive_spell_event(kind: String, origin: Vector3, direction: Vector3, caster_id: int) -> void:
	if not multiplayer.is_server():
		return

	# Le serveur relaie uniquement l'événement visuel aux autres clients.
	# Le gameplay/dégâts autoritaires seront traités dans une étape dédiée.
	var network_node := get_node_or_null("/root/Network")
	if network_node == null:
		return

	for peer_id in multiplayer.get_peers():
		if int(peer_id) == caster_id:
			continue
		network_node.arena_spell_visual.rpc_id(int(peer_id), kind, origin, direction, caster_id)

func _network_client_spell_visual(kind: String, origin: Vector3, direction: Vector3, caster_id: int, value: float = 0.0) -> void:
	var caster := network_fighters.get(caster_id) as ArenaPlayer3D
	if caster == null or not is_instance_valid(caster):
		return

	# Le modèle distant est interpolé. Les événements de sort arrivent avec la
	# position autoritaire serveur : on conserve le décalage (hauteur + avant)
	# voulu par le sort, et on le replaque sur la position VISUELLE actuelle
	# du VisualRoot, qui peut légèrement différer à cause de l'interpolation.
	var visual_origin := origin
	var visual_root := caster.get("_visual_root") as Node3D
	if visual_root != null and is_instance_valid(visual_root):
		var offset_from_caster: Vector3 = origin - caster.global_position
		visual_origin = visual_root.global_position + offset_from_caster

	# Effets visuels uniquement : aucun dégât n'est appliqué ici.
	if kind == "orb":
		_play_sfx(ORB_CAST_SFX, visual_origin, -8.0)
		var orb := ProjectileScene.new()
		orb.name = "RemoteArcBolt"
		projectiles.add_child(orb)
		orb.global_position = visual_origin
		orb.velocity = direction.normalized() * 17.0
		orb.damage = 0
		if str(caster.get("hero_id")) == "EREN":
			vfx_manager.spawn_eren_fire_projectile(orb, direction)
		else:
			vfx_manager.spawn_aeris_orb(self, visual_origin, direction)
	elif kind == "spirit":
		_play_sfx(ORB_CAST_SFX, visual_origin, -7.0)
		var spirit := ProjectileScene.new()
		spirit.name = "RemoteSpiritBolt"
		projectiles.add_child(spirit)
		spirit.global_position = visual_origin
		spirit.velocity = direction.normalized() * 18.5
		spirit.damage = 0
		spirit.spirit_color = Color("55ff2e")
		vfx_manager.spawn_maylinh_elemental_projectile(spirit, direction)
	elif kind == "shield":
		vfx_manager.spawn_shield_bash(self, visual_origin, direction)
		_spawn_kaithlyn_shield_fx(caster)
		_play_sfx(HIT_SFX, visual_origin, -4.0)
	elif kind == "shield_hit":
		vfx_manager.spawn_shield_bash(self, visual_origin + Vector3.UP * 0.7, direction)
		_play_sfx(HIT_SFX, visual_origin, -7.0)
	elif kind == "berserk":
		vfx_manager.spawn_explosion(self, visual_origin, 0.8)
		vfx_manager.spawn_charge(self, visual_origin, 0.7)
		_play_sfx(DASH_SFX, visual_origin, -3.0)
	elif kind == "charge" or kind == "eren_charge":
		vfx_manager.spawn_charge(self, visual_origin, 1.25)
		vfx_manager.spawn_dash(self, visual_origin + direction.normalized() * 0.45, direction)
		vfx_manager.spawn_explosion(self, visual_origin + Vector3.UP * 0.08, 0.4)
		_play_sfx(DASH_SFX, visual_origin, -3.0)
	elif kind == "charge_trail" or kind == "eren_charge_trail":
		vfx_manager.spawn_dash(self, visual_origin, direction)
		vfx_manager.spawn_charge(self, visual_origin, 0.32)
	elif kind == "charge_hit" or kind == "eren_charge_hit":
		vfx_manager.spawn_charge(self, visual_origin, 0.55)
		vfx_manager.spawn_explosion(self, visual_origin, 0.35)
		_play_sfx(HIT_SFX, visual_origin, -6.0)
	elif kind == "nova":
		vfx_manager.spawn_eren_fire_cast(self, visual_origin, direction, 1.25)
		vfx_manager.spawn_eren_fire_nova(self, visual_origin, 1.45, false)
		_play_sfx(DASH_SFX, visual_origin, -3.0)
	elif kind == "heal":
		vfx_manager.spawn_maylinh_elemental_heal(self, visual_origin)
		_play_sfx(TELEPORT_SFX, visual_origin, -8.0)
	elif kind == "flee":
		vfx_manager.spawn_maylinh_flee(self, visual_origin)
		_play_sfx(TELEPORT_SFX, visual_origin, -4.0)
	elif kind == "dash":
		vfx_manager.spawn_aeris_dash(self, visual_origin, direction)
		_play_sfx(DASH_SFX, visual_origin, -6.0)
	elif kind == "teleport":
		vfx_manager.spawn_teleport_start(self, visual_origin, 0.75)
		vfx_manager.spawn_teleport_end(self, visual_origin, 0.55)
		_play_sfx(TELEPORT_SFX, visual_origin, -5.0)
	elif kind == "axe_throw":
		# Ce cas manquait : le serveur relaie bien l'event à tous les clients
		# (y compris au lanceur lui-même), mais personne ne le traitait ici.
		# On rejoue donc le lancer localement, de façon purement visuelle
		# (les dégâts restent gérés côté serveur, cf. _update_thrown_axes).
		# "value" porte le ratio de charge envoyé par le serveur : sans lui,
		# cette copie locale utilisait l'ancienne distance de lancer connue
		# du lanceur au lieu de la distance réellement choisie cette fois-ci.
		_spawn_thrown_axe(caster, direction, value)
	elif kind == "dagger_throw":
		_spawn_thrown_dagger(caster, direction)

func _on_spell_cast(kind: String, origin: Vector3, direction: Vector3, caster: CharacterBody3D) -> void:
	# En réseau, le client propriétaire ne simule jamais le gameplay du sort.
	# Il envoie une commande au serveur. Le serveur exécute ensuite cette même
	# fonction et diffuse uniquement le résultat visuel aux autres clients.
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server() and caster == player:
		var network_node := get_node_or_null("/root/Network")
		if network_node != null:
			var request_value := 1.0
			if kind == "axe_throw":
				request_value = inverse_lerp(
				player.kaithlyn_axe_min_distance,
				player.kaithlyn_axe_max_distance,
				player.axe_last_throw_distance
			)
			# C'était CETTE ligne qui manquait : sans elle, le client calculait
			# bien la requête mais ne l'envoyait jamais au serveur. Résultat :
			# plus aucun sort n'était exécuté côté serveur (donc aucun VFX ni
			# dégât en retour), sauf le dash dont l'effet de vitesse est
			# appliqué localement, indépendamment de cette RPC.
			network_node.arena_ability_request.rpc_id(1, kind, direction, request_value, player.network_input_sequence)
		return

	# Le serveur est la seule machine autorisée à produire les effets gameplay.
	# Les clients reçoivent un événement visuel fiable.
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		var network_node := get_node_or_null("/root/Network")
		if network_node != null:
			var caster_id: int = 0
			if caster is ArenaPlayer3D:
				caster_id = caster.network_peer_id
			var visual_value: float = 0.0
			if kind == "axe_throw" and caster is ArenaPlayer3D:
				# La distance de lancer (dépend de la charge du joueur) n'était
				# jamais transmise ici : les autres clients rejouaient donc le
				# lancer avec la distance par défaut de leur copie locale du
				# lanceur, au lieu de la distance réellement choisie.
				visual_value = inverse_lerp(
					caster.kaithlyn_axe_min_distance,
					caster.kaithlyn_axe_max_distance,
					caster.axe_last_throw_distance
				)
			for peer_id in multiplayer.get_peers():
				network_node.arena_spell_visual.rpc_id(int(peer_id), kind, origin, direction, caster_id, visual_value)

	if kind == "orb":
		_play_sfx(ORB_CAST_SFX, origin, -8.0)
		var orb := ProjectileScene.new()
		orb.name = "ArcBolt"

		projectiles.add_child(orb)

		orb.global_position = origin
		orb.velocity = direction.normalized() * 17.0
		var hero: String = str(caster.get("hero_id"))
		var aeris_empowered: bool = hero == "AERIS" and bool(caster.get("passive_active"))
		if hero == "EREN":
			orb.damage = int(caster.get("eren_orb_damage"))
		elif aeris_empowered:
			orb.damage = int(caster.get("aeris_orb_damage_empowered"))
		else:
			orb.damage = int(caster.get("aeris_orb_damage"))
		orb.owner_player = caster
		orb.hit.connect(_on_projectile_hit)
		if hero == "EREN":
			vfx_manager.spawn_eren_fire_projectile(orb, direction)
		else:
			vfx_manager.spawn_aeris_orb(self, origin, direction)

	elif kind == "axe_throw":
		_spawn_thrown_axe(caster, direction)
	elif kind == "dagger_throw":
		_spawn_thrown_dagger(caster, direction)
	elif kind == "shield":
		vfx_manager.spawn_shield_bash(self, caster.global_position, direction)
		_spawn_kaithlyn_shield_fx(caster)
		_play_sfx(HIT_SFX, caster.global_position, -4.0)
	elif kind == "shield_hit":
		vfx_manager.spawn_shield_bash(self, caster.global_position + Vector3.UP * 0.7, direction)
		_play_sfx(HIT_SFX, caster.global_position, -7.0)
	elif kind == "berserk":
		# Activation du passif Rage Berserk : aura rouge/orange pendant 5 secondes.
		vfx_manager.spawn_explosion(self, origin, 0.8)
		vfx_manager.spawn_charge(self, origin, 0.7)
		_play_sfx(DASH_SFX, origin, -3.0)
	elif kind == "charge":
		# Départ de charge : gros flash + cercle + traînée pour que la capacité soit immédiatement lisible.
		vfx_manager.spawn_charge(self, origin, 1.45)
		vfx_manager.spawn_dash(self, origin + direction.normalized() * 0.45, direction)
		vfx_manager.spawn_explosion(self, origin + Vector3.UP * 0.08, 0.45)
		_play_sfx(DASH_SFX, origin, -3.0)
	elif kind == "charge_trail":
		vfx_manager.spawn_dash(self, origin, direction)
		vfx_manager.spawn_charge(self, origin, 0.32)
	elif kind == "charge_hit":
		_melee_attack(caster, 2.0, int(caster.get("kaithlyn_charge_hit_damage")), 1.0, 10.0, "charge")

	elif kind == "nova":
		var attacker: ArenaPlayer3D = caster as ArenaPlayer3D
		if attacker == null:
			return
		var fury: int = attacker.consume_eren_fury()
		var nova_damage: int = attacker.eren_nova_damage_base
		if fury >= 300:
			nova_damage = attacker.eren_nova_damage_tier3
		elif fury >= 200:
			nova_damage = attacker.eren_nova_damage_tier2
		elif fury >= 100:
			nova_damage = attacker.eren_nova_damage_tier1
		vfx_manager.spawn_eren_fire_cast(self, attacker.global_position + Vector3.UP * 0.05, direction, 1.25)
		vfx_manager.spawn_eren_fire_nova(self, attacker.global_position, 1.45, fury >= 300)
		_play_sfx(DASH_SFX, attacker.global_position, -3.0)
		for node in get_tree().get_nodes_in_group("fighters"):
			var fighter: ArenaPlayer3D = node as ArenaPlayer3D
			if fighter == null or fighter == attacker or not is_instance_valid(fighter):
				continue
			if fighter.team_color == attacker.team_color:
				continue
			if attacker.global_position.distance_to(fighter.global_position) > 4.0:
				continue
			var push_dir: Vector3 = fighter.global_position - attacker.global_position
			push_dir.y = 0.0
			if push_dir.length_squared() < 0.001:
				push_dir = direction
			push_dir = push_dir.normalized()
			var killed: bool = bool(fighter.take_damage(nova_damage, push_dir * 5.5))
			var dealt: int = int(round(fighter.last_damage_dealt))
			if dealt > 0:
				attacker.register_eren_damage(dealt)
				attacker.match_damage_dealt += dealt
			vfx_manager.spawn_eren_fire_impact(self, fighter.global_position, 0.7 if nova_damage < 100 else 1.0)
			if killed:
				_handle_combat_death(fighter, attacker)
	
	elif kind == "eren_charge":
		vfx_manager.spawn_eren_fire_cast(self, origin, direction, 0.9)
		vfx_manager.spawn_eren_charge_burst(self, origin, direction)
		_play_sfx(DASH_SFX, origin, -3.0)
	elif kind == "eren_charge_hit":
		var attacker: ArenaPlayer3D = caster as ArenaPlayer3D
		if attacker == null:
			return
		var target_position: Vector3 = origin
		var target_fighter: ArenaPlayer3D = null
		var closest: float = 2.0
		for node in get_tree().get_nodes_in_group("fighters"):
			var fighter: ArenaPlayer3D = node as ArenaPlayer3D
			if fighter == null or fighter == attacker or not is_instance_valid(fighter) or fighter.team_color == attacker.team_color:
				continue
			var d: float = fighter.global_position.distance_to(target_position)
			if d < closest:
				closest = d
				target_fighter = fighter
		if target_fighter != null:
			var push_dir: Vector3 = (target_fighter.global_position - attacker.global_position)
			push_dir.y = 0.0
			if push_dir.length_squared() < 0.001:
				push_dir = direction
			push_dir = push_dir.normalized()
			var killed: bool = bool(target_fighter.take_damage(attacker.eren_charge_hit_damage, push_dir * 7.0))
			var dealt: int = int(round(target_fighter.last_damage_dealt))
			if dealt > 0:
				attacker.register_eren_damage(dealt)
				attacker.match_damage_dealt += dealt
			vfx_manager.spawn_eren_fire_impact(self, target_position, 0.75)
			if killed:
				_handle_combat_death(target_fighter, attacker)

	elif kind == "eren_charge_trail":
		var trail_position: Vector3 = origin
		trail_position.y = 0.03
		eren_fire_trails.append({"position": trail_position, "expires": 2.4, "owner": caster})
		vfx_manager.spawn_eren_fire_trail(self, trail_position, direction)
	elif kind == "spirit":
		_play_sfx(ORB_CAST_SFX, origin, -7.0)
		var spirit := ProjectileScene.new()
		spirit.name = "SpiritBolt"
		projectiles.add_child(spirit)
		spirit.global_position = origin
		spirit.velocity = direction.normalized() * 18.5
		spirit.owner_player = caster
		spirit.damage = int(caster.get("maylinh_spirit_damage"))
		spirit.spirit_color = Color("55ff2e")
		spirit.hit.connect(_on_projectile_hit)
		vfx_manager.spawn_maylinh_elemental_projectile(spirit, direction)
	elif kind == "heal":
		vfx_manager.spawn_maylinh_elemental_heal(self, origin)
		_play_sfx(TELEPORT_SFX, origin, -8.0)
	elif kind == "flee":
		vfx_manager.spawn_maylinh_flee(self, caster.global_position)
		_play_sfx(TELEPORT_SFX, caster.global_position, -4.0)
		var dir := direction.normalized()
		if dir.length_squared() < 0.001:
			dir = Vector3(0.0, 0.0, -1.0)
		var from_pos := caster.global_position
		var destination := _safe_movement_destination(caster, from_pos, dir, 7.0, 0.75)
		destination.x = clampf(destination.x, map_bounds_min.x + 1.0, map_bounds_max.x - 1.0)
		destination.z = clampf(destination.z, map_bounds_min.z + 1.0, map_bounds_max.z - 1.0)
		caster.global_position = destination
		vfx_manager.spawn_maylinh_flee(self, destination)
		_play_sfx(TELEPORT_SFX, destination, -6.0)
		if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and caster is ArenaPlayer3D:
			_broadcast_hard_correction(caster as ArenaPlayer3D)
	elif kind == "dash":
		vfx_manager.spawn_aeris_dash(self, origin, direction)
		_play_sfx(DASH_SFX, origin, -6.0)

	elif kind == "teleport":
		var dir := direction.normalized()
		if dir.length_squared() < 0.001:
			dir = Vector3(0.0, 0.0, -1.0)
		var from_pos := caster.global_position
		vfx_manager.spawn_teleport_start(self, from_pos + Vector3.UP * 0.15, 0.75)
		_play_sfx(TELEPORT_SFX, from_pos, -5.0)
		var destination := _safe_movement_destination(caster, from_pos, dir, 5.5, 0.75)
		destination.x = clampf(destination.x, map_bounds_min.x + 1.0, map_bounds_max.x - 1.0)
		destination.z = clampf(destination.z, map_bounds_min.z + 1.0, map_bounds_max.z - 1.0)
		caster.global_position = destination
		vfx_manager.spawn_teleport_end(self, destination + Vector3.UP * 0.08, 0.55)
		_play_sfx(TELEPORT_SFX, destination, -7.0)

	# Les déplacements discontinus doivent être propagés immédiatement.
	if kind == "teleport" or kind == "flee":
		if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and caster is ArenaPlayer3D:
			_broadcast_hard_correction(caster as ArenaPlayer3D)

func _broadcast_hard_correction(fighter: ArenaPlayer3D) -> void:
	if fighter == null or not is_instance_valid(fighter) or not multiplayer.is_server():
		return
	var network_node := get_node_or_null("/root/Network")
	if network_node == null:
		return
	network_state_sequence += 1
	for peer_id in multiplayer.get_peers():
		network_node.arena_hard_correction.rpc_id(int(peer_id), fighter.network_peer_id, fighter.global_position, fighter.global_rotation.y, fighter.velocity, fighter.health, network_round_serial, network_state_sequence)

## Prévient tous les clients qu'un fighter vient de mourir en cours de round
## (mort différente d'un reset de round complet). Sans cet appel, un fighter
## mort restait visible/actif chez les clients, et la victime elle-même
## n'avait jamais son écran de mort/respawn (cf. _network_client_fighter_death).
func _broadcast_fighter_death(fighter: ArenaPlayer3D, respawn_delay: float) -> void:
	if fighter == null or not is_instance_valid(fighter) or not multiplayer.is_server():
		return
	if not multiplayer.has_multiplayer_peer():
		return
	var network_node := get_node_or_null("/root/Network")
	if network_node == null:
		return
	for peer_id in multiplayer.get_peers():
		network_node.arena_fighter_death.rpc_id(int(peer_id), fighter.network_peer_id, respawn_delay)

func _safe_movement_destination(caster: CharacterBody3D, from_pos: Vector3, direction: Vector3, distance: float, clearance: float) -> Vector3:
	var dir := direction.normalized()

	if dir.length_squared() < 0.001:
		dir = Vector3(0.0, 0.0, -1.0)

	# Destination horizontale uniquement
	var target := from_pos + dir * distance
	target.y = from_pos.y

	# Vérification des obstacles sur le trajet
	var ray_from := from_pos + Vector3.UP * 0.8
	var ray_to := target + Vector3.UP * 0.8

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

	if space_state != null:
		var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
		query.collision_mask = 0xFFFFFFFF
		query.collide_with_bodies = true
		query.collide_with_areas = false

		if caster != null and is_instance_valid(caster):
			query.exclude = [caster.get_rid()]

		var hit: Dictionary = space_state.intersect_ray(query)

		if not hit.is_empty():
			var collider: Object = hit.get("collider") as Object

			if collider is PhysicsBody3D and not collider.is_in_group("fighters"):
				var hit_position: Vector3 = hit.get("position", target) as Vector3

				# On s'arrête légèrement avant l'obstacle
				target.x = hit_position.x - dir.x * clearance
				target.z = hit_position.z - dir.z * clearance

	# Recherche du vrai sol sous la destination
	var ground_from := Vector3(
		target.x,
		maxf(map_bounds_max.y + 20.0, 20.0),
		target.z
	)

	var ground_to := Vector3(
		target.x,
		minf(map_bounds_min.y - 20.0, -20.0),
		target.z
	)

	var ground_query := PhysicsRayQueryParameters3D.create(
		ground_from,
		ground_to
	)

	# Layer 2 = terrain
	ground_query.collision_mask = 2
	ground_query.collide_with_bodies = true
	ground_query.collide_with_areas = false

	if caster != null and is_instance_valid(caster):
		ground_query.exclude = [caster.get_rid()]

	var ground_hit := space_state.intersect_ray(ground_query)

	if not ground_hit.is_empty() and ground_hit.has("position"):
		var ground_position: Vector3 = ground_hit["position"]
		target.y = ground_position.y
	else:
		target.y = map_floor_y

	return target

func _spawn_thrown_axe(caster: CharacterBody3D, direction: Vector3, throw_ratio: float = -1.0) -> void:
	var owner_player: ArenaPlayer3D = caster as ArenaPlayer3D
	if owner_player == null:
		return
	var axe: Node3D = owner_player.release_axe_for_throw()
	if axe == null:
		return
	axe.reparent(self, true)
	axe.global_position = caster.global_position + Vector3.UP * 0.95 + direction.normalized() * 0.65
	axe.visible = true
	var throw_distance: float
	if throw_ratio >= 0.0:
		# Rejeu visuel côté client à partir du ratio reçu du serveur, plutôt
		# que de dépendre de la dernière distance connue localement.
		throw_distance = lerpf(owner_player.kaithlyn_axe_min_distance, owner_player.kaithlyn_axe_max_distance, clampf(throw_ratio, 0.0, 1.0))
	else:
		throw_distance = clampf(owner_player.axe_last_throw_distance, 3.5, 12.0)
	var state: Dictionary = {
		"axe": axe,
		"owner": owner_player,
		"velocity": direction.normalized() * 20.0,
		"remaining": throw_distance,
		"stuck": false,
		"life": 8.0,
		"pickup_fx": null
	}
	thrown_axes.append(state)
	vfx_manager.spawn_dash(self, axe.global_position, direction)
	_play_sfx(HIT_SFX, axe.global_position, -5.0)

func _update_thrown_axes(delta: float) -> void:
	for index in range(thrown_axes.size() - 1, -1, -1):
		var state: Dictionary = thrown_axes[index]
		var axe: Node3D = state.get("axe") as Node3D
		var owner_player: ArenaPlayer3D = state.get("owner") as ArenaPlayer3D
		if axe == null or not is_instance_valid(axe) or owner_player == null or not is_instance_valid(owner_player):
			thrown_axes.remove_at(index)
			continue

		var stuck: bool = bool(state.get("stuck", false))
		var life: float = float(state.get("life", 999999.0)) - delta
		state["life"] = life

		if not stuck:
			var velocity_axe: Vector3 = state.get("velocity", Vector3.ZERO) as Vector3
			var remaining: float = float(state.get("remaining", 0.0))
			var step_distance: float = minf(velocity_axe.length() * delta, remaining)
			var axe_dir := velocity_axe.normalized()
			var previous_axe_position: Vector3 = axe.global_position
			var next_axe_position: Vector3 = previous_axe_position + axe_dir * step_distance
			var obstacle_hit := _raycast_map_obstacle(previous_axe_position + Vector3.UP * 0.35, next_axe_position + Vector3.UP * 0.35, owner_player)
			var hit_map_obstacle: bool = not obstacle_hit.is_empty()
			if hit_map_obstacle:
				var hit_position: Vector3 = obstacle_hit.get("position", next_axe_position) as Vector3
				axe.global_position = hit_position - axe_dir * 0.22
				state["remaining"] = 0.0
			else:
				axe.global_position = next_axe_position
				state["remaining"] = remaining - step_distance
			axe.rotate_y(18.0 * delta)

			var reached_edge: bool = hit_map_obstacle or axe.global_position.x <= map_bounds_min.x + 0.5 or axe.global_position.x >= map_bounds_max.x - 0.5 or axe.global_position.z <= map_bounds_min.z + 0.5 or axe.global_position.z >= map_bounds_max.z - 0.5 or float(state.get("remaining", 0.0)) <= 0.01
			if reached_edge:
				axe.global_position.x = clampf(axe.global_position.x, map_bounds_min.x + 0.5, map_bounds_max.x - 0.5)
				axe.global_position.z = clampf(axe.global_position.z, map_bounds_min.z + 0.5, map_bounds_max.z - 0.5)
				axe.global_position.y = 0.34
				# La hache se plante verticalement dans le sol, lame vers le bas,
				# orientée dans son sens de lancer (retournée à 180° depuis sa
				# pose tenue en main, plutôt que couchée à 90°).
				axe.rotation_degrees = Vector3(180.0, rad_to_deg(atan2(velocity_axe.x, velocity_axe.z)), 0.0)
				state["stuck"] = true
				stuck = true
				vfx_manager.spawn_explosion(self, axe.global_position, 0.28)
				state["pickup_fx"] = _spawn_axe_pickup_fx(axe.global_position)
				_play_sfx(HIT_SFX, axe.global_position, -6.0)

			if not stuck:
				for fighter_node in get_tree().get_nodes_in_group("fighters"):
					var fighter: ArenaPlayer3D = fighter_node as ArenaPlayer3D
					if fighter == null or fighter == owner_player or not is_instance_valid(fighter):
						continue
					if fighter.team_color == owner_player.team_color:
						continue
					if axe.global_position.distance_to(fighter.global_position + Vector3.UP * 0.6) < 0.95:
						var push: Vector3 = (fighter.global_position - owner_player.global_position)
						push.y = 0.0
						if push.length_squared() < 0.001:
							push = Vector3(0.0, 0.0, -1.0)
						push = push.normalized()
						# Sur un client réseau, le serveur est déjà seul autoritaire sur les
						# dégâts (cf. _network_receive_ability_request) : on ne les rejoue pas
						# ici pour éviter de les appliquer deux fois. On garde en revanche
						# tout le rendu (VFX/SFX/plantage) pour que l'impact reste lisible.
						var is_authoritative: bool = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
						var killed: bool = false
						if is_authoritative:
							killed = bool(fighter.take_damage(owner_player.kaithlyn_axe_damage, push * 4.0))
							owner_player.match_damage_dealt += fighter.last_damage_dealt
						vfx_manager.spawn_axe_hit(self, fighter.global_position + Vector3.UP * 0.15, velocity_axe.normalized())
						vfx_manager.spawn_damage_flash(self, fighter.global_position, velocity_axe.normalized())
						_play_sfx(HIT_SFX, fighter.global_position, -5.0)
						if killed:
							vfx_manager.spawn_explosion(self, fighter.global_position, 0.45)
							_play_sfx(DEATH_SFX, fighter.global_position, -5.0)
							# Avant : on incrémentait juste "kills" sans jamais passer par
							# _handle_combat_death, donc ces kills n'alimentaient ni le score
							# de round DUEL/TEAM, ni le respawn de la victime, ni la mort
							# subite. Un kill à la hache pouvait laisser la victime bloquée
							# sans jamais respawn.
							_handle_combat_death(fighter, owner_player)
						axe.global_position.y = 0.34
						# Hache réellement plantée, lame vers le bas : on part de la pose
						# tenue en main (quasi verticale) et on la retourne à 180° plutôt
						# que de la coucher à 90°, qui la faisait juste "poser" à plat au sol.
						axe.rotation_degrees = Vector3(180.0, rad_to_deg(atan2(velocity_axe.x, velocity_axe.z)), 0.0)
						state["stuck"] = true
						stuck = true
						vfx_manager.spawn_axe_plant(self, axe.global_position)
						state["pickup_fx"] = _spawn_axe_pickup_fx(axe.global_position)
						break

		if stuck and owner_player.global_position.distance_to(axe.global_position) < 1.25:
			# Seul le serveur (ou une partie locale sans réseau) décide du moment
			# où la hache est ramassée. Avant ce garde-fou, chaque client
			# ramassait sa propre copie dès que SA simulation locale jugeait la
			# distance suffisante, remettant le cooldown à zéro indépendamment
			# du serveur : l'état "hache tenue en main" pouvait diverger d'un
			# pair à l'autre. Les clients attendent maintenant la confirmation
			# du serveur via arena_axe_recovered (cf. _network_client_axe_recovered).
			var is_authoritative_pickup: bool = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
			if not is_authoritative_pickup:
				continue
			var pickup_fx: Node3D = state.get("pickup_fx") as Node3D
			if pickup_fx != null and is_instance_valid(pickup_fx):
				pickup_fx.queue_free()
			owner_player.recover_axe(axe)
			vfx_manager.spawn_explosion(self, owner_player.global_position + Vector3.UP * 0.2, 0.25)
			_play_sfx(TELEPORT_SFX, owner_player.global_position, -8.0)
			thrown_axes.remove_at(index)
			if multiplayer.has_multiplayer_peer():
				var network_node := get_node_or_null("/root/Network")
				if network_node != null:
					for peer_id in multiplayer.get_peers():
						network_node.arena_axe_recovered.rpc_id(int(peer_id), owner_player.network_peer_id)
			continue


## Reçoit la confirmation serveur qu'une hache plantée vient d'être ramassée
## par son propriétaire, et rejoue localement le même effet (cf. le garde-fou
## d'autorité dans _update_thrown_axes).
func _network_client_axe_recovered(caster_id: int) -> void:
	var owner_player: ArenaPlayer3D = network_fighters.get(caster_id) as ArenaPlayer3D
	if owner_player == null or not is_instance_valid(owner_player):
		return
	for index in range(thrown_axes.size() - 1, -1, -1):
		var state: Dictionary = thrown_axes[index]
		if state.get("owner") != owner_player:
			continue
		var axe: Node3D = state.get("axe") as Node3D
		var pickup_fx: Node3D = state.get("pickup_fx") as Node3D
		if pickup_fx != null and is_instance_valid(pickup_fx):
			pickup_fx.queue_free()
		if axe != null and is_instance_valid(axe):
			owner_player.recover_axe(axe)
		vfx_manager.spawn_explosion(self, owner_player.global_position + Vector3.UP * 0.2, 0.25)
		_play_sfx(TELEPORT_SFX, owner_player.global_position, -8.0)
		thrown_axes.remove_at(index)
		break

## Dague de Maylinh : contrairement à la hache de Kaithlyn, elle revient
## automatiquement dans sa main (pas besoin de marcher dessus). Comme le
## cooldown se recharge normalement avec le temps (pas remis à zéro à la
## réception), un léger décalage entre pairs sur l'instant exact du retour
## est purement cosmétique : chaque pair peut donc décider localement sans
## RPC dédiée, contrairement à la hache (cf. _update_thrown_axes).
func _spawn_thrown_dagger(caster: CharacterBody3D, direction: Vector3) -> void:
	var owner_player: ArenaPlayer3D = caster as ArenaPlayer3D
	if owner_player == null:
		return
	var dagger: Node3D = owner_player.release_dagger_for_throw()
	if dagger == null:
		return
	dagger.reparent(self, true)
	dagger.global_position = caster.global_position + Vector3.UP * 0.95 + direction.normalized() * 0.55
	dagger.visible = true
	var state: Dictionary = {
		"dagger": dagger,
		"owner": owner_player,
		"velocity": direction.normalized() * owner_player.maylinh_dagger_throw_speed,
		"traveled": 0.0,
		"max_range": owner_player.maylinh_dagger_range,
		"returning": false,
		"hit_done": false,
	}
	thrown_daggers.append(state)
	vfx_manager.spawn_dash(self, dagger.global_position, direction)
	_play_sfx(HIT_SFX, dagger.global_position, -6.0)

func _update_thrown_daggers(delta: float) -> void:
	for index in range(thrown_daggers.size() - 1, -1, -1):
		var state: Dictionary = thrown_daggers[index]
		var dagger: Node3D = state.get("dagger") as Node3D
		var owner_player: ArenaPlayer3D = state.get("owner") as ArenaPlayer3D
		if dagger == null or not is_instance_valid(dagger) or owner_player == null or not is_instance_valid(owner_player):
			thrown_daggers.remove_at(index)
			continue

		var returning: bool = bool(state.get("returning", false))
		var velocity_dagger: Vector3 = state.get("velocity", Vector3.ZERO) as Vector3

		if not returning:
			var step: Vector3 = velocity_dagger * delta
			dagger.global_position += step
			dagger.rotate_y(24.0 * delta)
			state["traveled"] = float(state.get("traveled", 0.0)) + step.length()

			var hit_done: bool = bool(state.get("hit_done", false))
			if not hit_done:
				for fighter_node in get_tree().get_nodes_in_group("fighters"):
					var fighter: ArenaPlayer3D = fighter_node as ArenaPlayer3D
					if fighter == null or fighter == owner_player or not is_instance_valid(fighter):
						continue
					if fighter.team_color == owner_player.team_color:
						continue
					if dagger.global_position.distance_to(fighter.global_position + Vector3.UP * 0.6) < 0.85:
						var push: Vector3 = (fighter.global_position - owner_player.global_position)
						push.y = 0.0
						if push.length_squared() < 0.001:
							push = velocity_dagger.normalized()
						push = push.normalized()
						# Comme pour la hache : le serveur applique seul les
						# dégâts, les clients ne rejouent que le rendu.
						var is_authoritative: bool = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
						var killed: bool = false
						if is_authoritative:
							killed = bool(fighter.take_damage(owner_player.maylinh_dagger_damage, push * 3.5))
							owner_player.match_damage_dealt += fighter.last_damage_dealt
						vfx_manager.spawn_axe_hit(self, fighter.global_position + Vector3.UP * 0.15, velocity_dagger.normalized())
						vfx_manager.spawn_damage_flash(self, fighter.global_position, velocity_dagger.normalized())
						_play_sfx(HIT_SFX, fighter.global_position, -5.0)
						if killed:
							vfx_manager.spawn_explosion(self, fighter.global_position, 0.4)
							_play_sfx(DEATH_SFX, fighter.global_position, -5.0)
							# cf. hache : sans _handle_combat_death, ce kill n'alimentait ni
							# le score de round, ni le respawn de la victime, ni la mort subite.
							_handle_combat_death(fighter, owner_player)
						state["hit_done"] = true
						hit_done = true
						break

			if hit_done or float(state.get("traveled", 0.0)) >= float(state.get("max_range", 10.0)):
				state["returning"] = true
				returning = true

		if returning:
			var target_position: Vector3 = owner_player.global_position + Vector3.UP * 0.95
			var to_owner: Vector3 = target_position - dagger.global_position
			var distance: float = to_owner.length()
			if distance < 0.6:
				owner_player.recover_dagger(dagger)
				thrown_daggers.remove_at(index)
				continue
			var return_direction: Vector3 = to_owner.normalized()
			dagger.global_position += return_direction * owner_player.maylinh_dagger_return_speed * delta
			dagger.rotate_y(24.0 * delta)

func _raycast_map_obstacle(from_pos: Vector3, to_pos: Vector3, owner_player: ArenaPlayer3D) -> Dictionary:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_bodies = true
	query.collide_with_areas = false
	if owner_player != null and is_instance_valid(owner_player):
		query.exclude = [owner_player.get_rid()]
	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var collider: Object = hit.get("collider") as Object
	if collider is CharacterBody3D:
		return {}
	return hit

func _spawn_axe_pickup_fx(position: Vector3) -> Node3D:
	# Marqueur au sol : la hache est récupérable en passant dessus.
	var root := Node3D.new()
	root.name = "KaithlynAxePickupFX"
	add_child(root)
	root.global_position = position + Vector3.UP * 0.03
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ffb52e")
	mat.emission_enabled = true
	mat.emission = Color("ff6a00")
	mat.emission_energy_multiplier = 5.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.48
	torus.outer_radius = 0.56
	torus.rings = 32
	torus.ring_segments = 10
	ring.mesh = torus
	ring.material_override = mat
	root.add_child(ring)
	var pulse := root.create_tween()
	pulse.set_loops()
	pulse.tween_property(ring, "scale", Vector3.ONE * 1.25, 0.45)
	pulse.tween_property(ring, "scale", Vector3.ONE * 0.85, 0.45)
	return root

func _spawn_kaithlyn_shield_fx(caster: CharacterBody3D) -> void:
	# Bouclier visuel procédural : compatible GL Compatibility, sans particules/shaders externes.
	var root := Node3D.new()
	root.name = "KaithlynShieldFX"
	caster.add_child(root)
	root.position = Vector3(0.0, 0.95, 0.0)

	var shell_mat := StandardMaterial3D.new()
	shell_mat.albedo_color = Color(1.0, 0.48, 0.08, 0.16)
	shell_mat.emission_enabled = true
	shell_mat.emission = Color(1.0, 0.22, 0.02)
	shell_mat.emission_energy_multiplier = 4.0
	shell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var shell := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.05
	sphere.height = 2.10
	shell.mesh = sphere
	shell.scale = Vector3(1.05, 1.12, 1.05)
	shell.material_override = shell_mat
	root.add_child(shell)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color("ffb52e")
	ring_mat.emission_enabled = true
	ring_mat.emission = Color("ff6a00")
	ring_mat.emission_energy_multiplier = 7.0
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Trois anneaux donnent une silhouette de vrai bouclier énergétique.
	for i in range(3):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.86 + float(i) * 0.05
		torus.outer_radius = 0.91 + float(i) * 0.05
		torus.rings = 40
		torus.ring_segments = 10
		ring.mesh = torus
		ring.position.y = (float(i) - 1.0) * 0.38
		ring.rotation_degrees = Vector3(90.0, float(i) * 60.0, 0.0)
		ring.material_override = ring_mat
		root.add_child(ring)

	# Petit noyau lumineux au-dessus de la tête pour rendre l'activation évidente.
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.16
	core_mesh.height = 0.32
	core.mesh = core_mesh
	core.position.y = 1.25
	core.material_override = ring_mat
	root.add_child(core)

	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(shell, "scale", Vector3(1.12, 1.18, 1.12), 0.20)
	tween.tween_property(shell_mat, "emission_energy_multiplier", 1.5, 3.0)
	tween.tween_property(core, "scale", Vector3(1.7, 1.7, 1.7), 0.55)
	var rings := root.get_children()
	for child in rings:
		if child is MeshInstance3D and child != shell and child != core:
			tween.tween_property(child, "rotation_degrees:y", child.rotation_degrees.y + 360.0, 3.0)
	tween.set_parallel(false)
	tween.tween_interval(2.45)
	tween.tween_callback(root.queue_free)

func _handle_combat_death(victim: ArenaPlayer3D, killer: ArenaPlayer3D) -> void:
	if victim == null or killer == null:
		return
	killer.match_kills += 1
	if _is_duel_mode():
		_handle_duel_death(victim, killer)
	elif _is_team_mode():
		_handle_team_death(victim, killer)
	else:
		if deathmatch_scores.has(killer):
			deathmatch_scores[killer] = int(deathmatch_scores[killer]) + 1
		if deathmatch_deaths.has(victim):
			deathmatch_deaths[victim] = int(deathmatch_deaths[victim]) + 1
		if killer == player:
			kills += 1
		elif victim == player:
			deaths += 1

func _melee_attack(caster: CharacterBody3D, range_value: float, damage: int, stun: float, knockback: float, kind: String) -> void:
	var attacker := caster as ArenaPlayer3D
	if attacker == null or not is_instance_valid(attacker):
		return
	var aim: Vector3 = attacker.aim_direction.normalized()
	var best: ArenaPlayer3D = null
	var best_distance: float = range_value
	for node in get_tree().get_nodes_in_group("fighters"):
		var fighter := node as ArenaPlayer3D
		if fighter == null or fighter == attacker or not is_instance_valid(fighter):
			continue
		if fighter.team_color == attacker.team_color:
			continue
		var offset: Vector3 = fighter.global_position - attacker.global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance > range_value or distance < 0.01:
			continue
		var dot: float = aim.dot(offset.normalized())
		if dot < 0.15:
			continue
		if distance < best_distance:
			best_distance = distance
			best = fighter
	if best == null:
		return

	var force_direction: Vector3 = (best.global_position - attacker.global_position)
	force_direction.y = 0.0
	if force_direction.length_squared() < 0.001:
		force_direction = aim
	force_direction = force_direction.normalized()
	if kind == "axe":
		vfx_manager.spawn_axe_swing(self, best.global_position, aim)
	elif kind == "shield":
		vfx_manager.spawn_shield_bash(self, best.global_position, aim)
	else:
		vfx_manager.spawn_charge(self, best.global_position + Vector3.UP * 0.1, 0.55)
	var killed: bool = bool(best.take_damage(damage, force_direction * knockback))
	attacker.match_damage_dealt += best.last_damage_dealt
	_broadcast_damage_vfx("damage", best.global_position, force_direction)
	if stun > 0.0:
		best.apply_root(stun)
	if killed:
		vfx_manager.spawn_explosion(self, best.global_position + Vector3.UP * 0.1, 0.5)
		_play_sfx(DEATH_SFX, best.global_position, -5.0)
		_handle_combat_death(best, attacker)

func _on_projectile_hit(target: CharacterBody3D, orb: Area3D) -> void:
	var projectile := orb as ArenaProjectile3D

	if projectile == null:
		return

	if not is_instance_valid(target):
		return

	if target == projectile.owner_player:
		return

	var projectile_owner: ArenaPlayer3D = projectile.owner_player as ArenaPlayer3D
	var target_fighter: ArenaPlayer3D = target as ArenaPlayer3D

	if projectile_owner != null and target_fighter != null:
		if projectile_owner.team_color == target_fighter.team_color:
			orb.queue_free()
			return

	var push := projectile.velocity.normalized() * 3.3

	var projectile_hero: String = "AERIS"

	if projectile_owner != null:
		projectile_hero = projectile_owner.hero_id

	if projectile_hero == "EREN":
		var eren_hit_position := target.global_position

		vfx_manager.spawn_eren_fire_impact(
			self,
			eren_hit_position,
			0.65
		)

		_broadcast_damage_vfx(
			"eren",
			eren_hit_position
		)

	elif projectile_hero == "MAYLINH":
		var maylinh_hit_position := target.global_position + Vector3.UP * 0.8

		vfx_manager.spawn_maylinh_hit(
			self,
			maylinh_hit_position
		)

		_broadcast_damage_vfx(
			"maylinh",
			maylinh_hit_position
		)

	else:
		var aeris_hit_position := target.global_position + Vector3.UP * 0.8

		vfx_manager.spawn_aeris_hit(
			self,
			aeris_hit_position
		)

		_broadcast_damage_vfx(
			"aeris",
			aeris_hit_position
		)

	_play_sfx(
		HIT_SFX,
		target.global_position,
		-6.0
	)

	var damage: int = projectile.damage
	var owner_player: ArenaPlayer3D = projectile.owner_player as ArenaPlayer3D

	var empowered_aeris: bool = (
		owner_player != null
		and owner_player.hero_id == "AERIS"
		and owner_player.passive_active
	)

	var killed: bool = bool(
		target.take_damage(
			damage,
			push
		)
	)
	if owner_player != null:
		owner_player.match_damage_dealt += target.last_damage_dealt

	_broadcast_damage_vfx(
		"damage",
		target.global_position,
		push.normalized()
	)

	if owner_player != null:
		if owner_player.hero_id == "EREN":
			var dealt: int = int(
				round(target.last_damage_dealt)
			)

			if dealt > 0:
				owner_player.register_eren_damage(dealt)

		if owner_player.hero_id == "AERIS" and not empowered_aeris:
			owner_player.register_aeris_hit()

		if empowered_aeris:
			owner_player.passive_active = false
			owner_player.passive_timer = 0.0

	if killed:
		vfx_manager.spawn_explosion(
			self,
			target.global_position + Vector3.UP * 0.1,
			0.42
		)

		_play_sfx(
			DEATH_SFX,
			target.global_position,
			-5.0
		)

		_handle_combat_death(
			target_fighter,
			owner_player
		)

	orb.queue_free()

func _update_eren_fire_trails(delta: float) -> void:
	for i in range(eren_fire_trails.size() - 1, -1, -1):
		var trail: Dictionary = eren_fire_trails[i]
		trail["expires"] = float(trail.get("expires", 0.0)) - delta
		if float(trail["expires"]) <= 0.0:
			eren_fire_trails.remove_at(i)
		else:
			eren_fire_trails[i] = trail
	for key in eren_trail_hit_cooldowns.keys():
		eren_trail_hit_cooldowns[key] = maxf(0.0, float(eren_trail_hit_cooldowns[key]) - delta)
	for node in get_tree().get_nodes_in_group("fighters"):
		var fighter: ArenaPlayer3D = node as ArenaPlayer3D
		if fighter == null or not is_instance_valid(fighter):
			continue
		var best_owner: ArenaPlayer3D = null
		for trail in eren_fire_trails:
			var owner: ArenaPlayer3D = trail.get("owner") as ArenaPlayer3D
			if owner == null or not is_instance_valid(owner) or owner == fighter or owner.team_color == fighter.team_color:
				continue
			var pos: Vector3 = trail.get("position", Vector3.ZERO)
			if fighter.global_position.distance_to(pos) <= 1.05:
				best_owner = owner
				break
		if best_owner == null:
			continue
		var id: int = fighter.get_instance_id()
		if float(eren_trail_hit_cooldowns.get(id, 0.0)) > 0.0:
			continue
		const TRAIL_DAMAGE: int = 10
		var killed: bool = bool(fighter.take_damage(TRAIL_DAMAGE, Vector3.ZERO))
		var dealt: int = int(round(fighter.last_damage_dealt))
		if dealt > 0:
			best_owner.register_eren_damage(dealt)
			best_owner.match_damage_dealt += dealt
		eren_trail_hit_cooldowns[id] = 0.4
		vfx_manager.spawn_eren_fire_impact(self, fighter.global_position, 0.38)
		if killed:
			_handle_combat_death(fighter, best_owner)

func _spawn_heal_aoe(position: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 3.7
	torus.outer_radius = 3.9
	torus.rings = 48
	torus.ring_segments = 16
	ring.mesh = torus
	ring.position = position + Vector3.UP * 0.06
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("61f0b1")
	material.emission_enabled = true
	material.emission = Color("35d995")
	material.emission_energy_multiplier = 3.5
	ring.material_override = material
	add_child(ring)
	get_tree().create_timer(0.8).timeout.connect(ring.queue_free)

func _spawn_cage_fx(position: Vector3) -> void:
	# Cage visible et lisible sans dépendre d'un asset externe.
	var root := Node3D.new()
	root.name = "MaylinhCageFX"
	root.position = position
	add_child(root)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color("b85cff")
	material.emission_enabled = true
	material.emission = Color("8d35ff")
	material.emission_energy_multiplier = 4.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.72

	for i in range(8):
		var pillar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.12, 2.2, 0.12)
		pillar.mesh = box
		pillar.material_override = material
		var angle := TAU * float(i) / 8.0
		pillar.position = Vector3(cos(angle) * 1.15, 1.1, sin(angle) * 1.15)
		root.add_child(pillar)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.0
	torus.outer_radius = 1.16
	torus.rings = 32
	torus.ring_segments = 12
	ring.mesh = torus
	ring.position.y = 0.06
	ring.material_override = material
	root.add_child(ring)

	get_tree().create_timer(2.1).timeout.connect(root.queue_free)


func _spawn_flee_fx(position: Vector3) -> void:
	var root := Node3D.new()
	root.name = "MaylinhFleeFX"
	root.global_position = position + Vector3.UP * 0.04
	add_child(root)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color("b94cff")
	material.emission_enabled = true
	material.emission = Color("8f25ff")
	material.emission_energy_multiplier = 7.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.82

	for y in [0.15, 0.75, 1.35]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.48 + y * 0.08
		torus.outer_radius = 0.60 + y * 0.08
		torus.rings = 32
		torus.ring_segments = 12
		ring.mesh = torus
		ring.position.y = y
		ring.material_override = material
		root.add_child(ring)

	var light := OmniLight3D.new()
	light.light_color = Color("b94cff")
	light.light_energy = 5.0
	light.omni_range = 4.0
	light.position.y = 1.0
	root.add_child(light)

	get_tree().create_timer(0.45).timeout.connect(root.queue_free)


func _play_sfx(stream: AudioStream, position: Vector3, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var player_3d := AudioStreamPlayer3D.new()
	player_3d.stream = stream
	player_3d.bus = "SFX"
	player_3d.volume_db = volume_db
	player_3d.max_distance = 35.0
	player_3d.position = position
	add_child(player_3d)
	player_3d.play()
	player_3d.finished.connect(player_3d.queue_free)

func blocks_projectile(at_position: Vector3) -> bool:
	for ward in wards:
		var dx := ward.x - at_position.x
		var dz := ward.z - at_position.z
		if Vector2(dx, dz).length() < 0.8:
			return true
	return false

func _build_axe_preview() -> void:
	var root := Node3D.new()
	root.name = "KaithlynAxeAimPreview"
	add_child(root)
	axe_preview_mesh = ImmediateMesh.new()
	axe_preview = MeshInstance3D.new()
	axe_preview.name = "AxeAimArrow"
	axe_preview.mesh = axe_preview_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ff9f3f")
	mat.emission_enabled = true
	mat.emission = Color("ff5a18")
	mat.emission_energy_multiplier = 4.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.32, 0.04, 0.95)
	axe_preview.material_override = mat
	root.add_child(axe_preview)
	axe_preview.visible = false

	axe_charge_bar = ProgressBar.new()
	axe_charge_bar.name = "AxeCharge"
	axe_charge_bar.position = Vector2(490, 520)
	axe_charge_bar.size = Vector2(300, 18)
	axe_charge_bar.min_value = 0.0
	axe_charge_bar.max_value = 100.0
	axe_charge_bar.value = 0.0
	axe_charge_bar.show_percentage = false
	axe_charge_bar.add_theme_stylebox_override("background", _box(Color("111a2b"), Color("355b8e"), 8, 1))
	axe_charge_bar.add_theme_stylebox_override("fill", _box(Color("ff8c32"), Color("ffd07a"), 8, 0))
	hud.add_child(axe_charge_bar)
	axe_charge_bar.visible = false
	axe_charge_label = _label("", "PUISSANCE DU LANCER", Vector2(490, 492), Vector2(300, 20), 11, Color("ffd28d"), HORIZONTAL_ALIGNMENT_CENTER)
	hud.add_child(axe_charge_label)
	# Comme axe_preview juste au-dessus : visible par défaut = true tant que
	# _update_axe_preview() n'a pas encore tourné, ce qui laissait la barre
	# affichée en permanence pour les héros autres que Kaithlyn (ex. Aeris).
	axe_charge_label.visible = false

func _update_axe_preview() -> void:
	if axe_charge_bar == null or player == null or not is_instance_valid(player):
		return
	var active: bool = selected_hero == "KAITHLYN" and player.axe_charge_active
	axe_charge_bar.visible = active
	axe_charge_label.visible = active
	axe_preview.visible = active
	if not active:
		return

	var ratio: float = player.get_axe_charge_ratio()
	axe_charge_bar.value = ratio * 100.0
	axe_charge_label.text = "LANCER DE HACHE  •  %d%%  •  %.1f m" % [int(ratio * 100.0), player.get_axe_charge_distance()]

	var direction: Vector3 = player._get_camera_attack_direction()
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	direction = direction.normalized()
	var start: Vector3 = player.global_position + Vector3.UP * 0.24 + direction * 0.65
	var distance: float = player.get_axe_charge_distance()
	var end: Vector3 = start + direction * distance
	end.y = 0.24
	var side: Vector3 = Vector3(-direction.z, 0.0, direction.x)

	# Flèche 3D solide, volontairement très épaisse et double-face pour rester visible avec GL Compatibility.
	var shaft_half: float = 0.13
	var head_length: float = minf(1.05, distance * 0.28)
	var shaft_end: Vector3 = end - direction * head_length
	var shaft_left: Vector3 = start + side * shaft_half
	var shaft_right: Vector3 = start - side * shaft_half
	var shaft_end_left: Vector3 = shaft_end + side * shaft_half
	var shaft_end_right: Vector3 = shaft_end - side * shaft_half
	var tip_left: Vector3 = shaft_end + side * 0.58
	var tip_right: Vector3 = shaft_end - side * 0.58

	axe_preview_mesh.clear_surfaces()
	axe_preview_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# dessus
	axe_preview_mesh.surface_add_vertex(shaft_left)
	axe_preview_mesh.surface_add_vertex(shaft_end_left)
	axe_preview_mesh.surface_add_vertex(shaft_end_right)
	axe_preview_mesh.surface_add_vertex(shaft_left)
	axe_preview_mesh.surface_add_vertex(shaft_end_right)
	axe_preview_mesh.surface_add_vertex(shaft_right)
	axe_preview_mesh.surface_add_vertex(shaft_end_left)
	axe_preview_mesh.surface_add_vertex(tip_left)
	axe_preview_mesh.surface_add_vertex(end)
	axe_preview_mesh.surface_add_vertex(shaft_end_right)
	axe_preview_mesh.surface_add_vertex(end)
	axe_preview_mesh.surface_add_vertex(tip_right)
	# dessous, pour garantir la visibilité quel que soit l'angle caméra
	axe_preview_mesh.surface_add_vertex(shaft_left)
	axe_preview_mesh.surface_add_vertex(shaft_end_right)
	axe_preview_mesh.surface_add_vertex(shaft_end_left)
	axe_preview_mesh.surface_add_vertex(shaft_left)
	axe_preview_mesh.surface_add_vertex(shaft_right)
	axe_preview_mesh.surface_add_vertex(shaft_end_right)
	axe_preview_mesh.surface_add_vertex(shaft_end_left)
	axe_preview_mesh.surface_add_vertex(end)
	axe_preview_mesh.surface_add_vertex(tip_left)
	axe_preview_mesh.surface_add_vertex(shaft_end_right)
	axe_preview_mesh.surface_add_vertex(tip_right)
	axe_preview_mesh.surface_add_vertex(end)
	axe_preview_mesh.surface_end()
	axe_preview.global_position = Vector3.ZERO

# =========================================================
# MENU PAUSE (ÉCHAP) : reprendre / options / quitter la partie
# =========================================================

func _toggle_pause_menu() -> void:
	if pause_menu_open:
		_close_pause_menu()
	else:
		_open_pause_menu()

func _open_pause_menu() -> void:
	pause_menu_open = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_load_pause_settings()
	_show_pause_root()
	if pause_menu != null:
		pause_menu.visible = true

func _close_pause_menu() -> void:
	pause_menu_open = false
	if pause_menu != null:
		pause_menu.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _show_pause_root() -> void:
	if pause_root_panel != null:
		pause_root_panel.visible = true
	if pause_options_panel != null:
		pause_options_panel.visible = false

func _show_pause_options() -> void:
	if pause_root_panel != null:
		pause_root_panel.visible = false
	if pause_options_panel != null:
		pause_options_panel.visible = true
	if pause_master_slider != null:
		pause_master_slider.value = pause_master_volume
	if pause_music_slider != null:
		pause_music_slider.value = pause_music_volume
	if pause_sfx_slider != null:
		pause_sfx_slider.value = pause_sfx_volume
	if pause_fov_slider != null:
		pause_fov_slider.value = camera_fov
	if pause_sensitivity_slider != null:
		pause_sensitivity_slider.value = controller_camera_sensitivity
	if pause_fullscreen_toggle != null:
		pause_fullscreen_toggle.button_pressed = pause_fullscreen
	if pause_vsync_toggle != null:
		pause_vsync_toggle.button_pressed = pause_vsync
	if pause_invert_y_toggle != null:
		pause_invert_y_toggle.button_pressed = controller_invert_y
	if pause_keybind_orb_button != null:
		pause_keybind_orb_button.text = _get_pause_key_name("spell_orb")
	if pause_keybind_nova_button != null:
		pause_keybind_nova_button.text = _get_pause_key_name("spell_nova")
	if pause_keybind_dash_button != null:
		pause_keybind_dash_button.text = _get_pause_key_name("spell_dash")
	if pause_keybind_move_up_button != null:
		pause_keybind_move_up_button.text = _get_pause_key_name("move_up")
	if pause_keybind_move_down_button != null:
		pause_keybind_move_down_button.text = _get_pause_key_name("move_down")
	if pause_keybind_move_left_button != null:
		pause_keybind_move_left_button.text = _get_pause_key_name("move_left")
	if pause_keybind_move_right_button != null:
		pause_keybind_move_right_button.text = _get_pause_key_name("move_right")
	if pause_screen_shake_toggle != null:
		pause_screen_shake_toggle.button_pressed = pause_screen_shake
	if pause_damage_numbers_toggle != null:
		pause_damage_numbers_toggle.button_pressed = pause_damage_numbers
	if pause_camera_height_slider != null:
		pause_camera_height_slider.value = camera_height
	if pause_tutorials_toggle != null:
		pause_tutorials_toggle.button_pressed = pause_tutorials
	if pause_ability_hints_toggle != null:
		pause_ability_hints_toggle.button_pressed = pause_ability_hints
	if pause_autosave_toggle != null:
		pause_autosave_toggle.button_pressed = pause_autosave
	if pause_confirmations_toggle != null:
		pause_confirmations_toggle.button_pressed = pause_confirmations
	if pause_indicators_toggle != null:
		pause_indicators_toggle.button_pressed = pause_indicators

func _quit_match_from_pause() -> void:
	_close_pause_menu()
	_return_to_menu()

## Reprend les mêmes fichier/sections/clés que le menu principal
## (SETTINGS_PATH = "user://settings.cfg" dans main_menu.gd) : les deux
## écrans doivent éditer le même fichier, sinon un changement fait en jeu
## serait écrasé au prochain passage par le menu principal, et inversement.
func _load_pause_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") != OK:
		return
	pause_master_volume = float(config.get_value("audio", "master_volume", 78.0))
	pause_music_volume = float(config.get_value("audio", "music_volume", 64.0))
	pause_sfx_volume = float(config.get_value("audio", "sfx_volume", 64.0))
	pause_fullscreen = bool(config.get_value("video", "fullscreen", false))
	pause_vsync = bool(config.get_value("video", "vsync", true))
	pause_screen_shake = bool(config.get_value("video", "screen_shake", true))
	pause_damage_numbers = bool(config.get_value("video", "damage_numbers", true))
	pause_tutorials = bool(config.get_value("gameplay", "tutorials", true))
	pause_ability_hints = bool(config.get_value("gameplay", "ability_hints", true))
	pause_autosave = bool(config.get_value("gameplay", "autosave", true))
	pause_confirmations = bool(config.get_value("gameplay", "confirmations", true))
	pause_indicators = bool(config.get_value("gameplay", "indicators", true))
	_load_camera_settings()

func _save_pause_settings() -> void:
	var config := ConfigFile.new()
	# On recharge le fichier existant avant d'écrire : sans ça, les clés
	# gérées uniquement par le menu principal (gameplay/tutorials...)
	# seraient perdues à chaque sauvegarde faite depuis le menu pause.
	config.load("user://settings.cfg")
	config.set_value("audio", "master_volume", pause_master_volume)
	config.set_value("audio", "music_volume", pause_music_volume)
	config.set_value("audio", "sfx_volume", pause_sfx_volume)
	config.set_value("video", "fullscreen", pause_fullscreen)
	config.set_value("video", "vsync", pause_vsync)
	config.set_value("video", "screen_shake", pause_screen_shake)
	config.set_value("video", "damage_numbers", pause_damage_numbers)
	config.set_value("camera", "fov", camera_fov)
	config.set_value("camera", "height", camera_height)
	config.set_value("controller", "camera_sensitivity", controller_camera_sensitivity)
	config.set_value("controller", "invert_y", controller_invert_y)
	config.set_value("gameplay", "tutorials", pause_tutorials)
	config.set_value("gameplay", "ability_hints", pause_ability_hints)
	config.set_value("gameplay", "autosave", pause_autosave)
	config.set_value("gameplay", "confirmations", pause_confirmations)
	config.set_value("gameplay", "indicators", pause_indicators)
	config.save("user://settings.cfg")

func _set_pause_bus_volume(bus_name: String, value: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus == -1:
		return
	if value <= 0.0:
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, linear_to_db(value / 100.0))

func _on_pause_master_changed(value: float) -> void:
	pause_master_volume = value
	_set_pause_bus_volume("Master", value)
	_save_pause_settings()

func _on_pause_music_changed(value: float) -> void:
	pause_music_volume = value
	_set_pause_bus_volume("Music", value)
	_save_pause_settings()

func _on_pause_sfx_changed(value: float) -> void:
	pause_sfx_volume = value
	_set_pause_bus_volume("SFX", value)
	_save_pause_settings()

func _on_pause_fov_changed(value: float) -> void:
	camera_fov = value
	if camera != null:
		camera.fov = camera_fov
	_save_pause_settings()

func _on_pause_sensitivity_changed(value: float) -> void:
	controller_camera_sensitivity = value
	_save_pause_settings()

func _on_pause_fullscreen_toggled(pressed: bool) -> void:
	pause_fullscreen = pressed
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if pressed else DisplayServer.WINDOW_MODE_WINDOWED)
	_save_pause_settings()

func _on_pause_vsync_toggled(pressed: bool) -> void:
	pause_vsync = pressed
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if pressed else DisplayServer.VSYNC_DISABLED)
	_save_pause_settings()

func _on_pause_invert_y_toggled(pressed: bool) -> void:
	controller_invert_y = pressed
	_save_pause_settings()

func _on_pause_screen_shake_toggled(pressed: bool) -> void:
	pause_screen_shake = pressed
	_save_pause_settings()

func _on_pause_damage_numbers_toggled(pressed: bool) -> void:
	pause_damage_numbers = pressed
	_save_pause_settings()

func _on_pause_camera_height_changed(value: float) -> void:
	camera_height = value
	_save_pause_settings()

func _on_pause_tutorials_toggled(pressed: bool) -> void:
	pause_tutorials = pressed
	_save_pause_settings()

func _on_pause_ability_hints_toggled(pressed: bool) -> void:
	pause_ability_hints = pressed
	_save_pause_settings()

func _on_pause_autosave_toggled(pressed: bool) -> void:
	pause_autosave = pressed
	_save_pause_settings()

func _on_pause_confirmations_toggled(pressed: bool) -> void:
	pause_confirmations = pressed
	_save_pause_settings()

func _on_pause_indicators_toggled(pressed: bool) -> void:
	pause_indicators = pressed
	_save_pause_settings()

## Reprend le même schéma que main_menu.gd (_get_key_name / _rebind_action /
## _save_keybinds) : les deux écrans doivent éditer la même section
## "keybinds" de user://settings.cfg pour rester cohérents entre eux.
func _get_pause_key_name(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return "AUCUNE"
	var events := InputMap.action_get_events(action_name)
	if events.is_empty():
		return "AUCUNE"
	var event: InputEvent = events[0]
	if event is InputEventKey:
		return OS.get_keycode_string(event.physical_keycode)
	if event is InputEventMouseButton:
		return "SOURIS %d" % event.button_index
	return "INCONNU"

func _start_pause_key_rebind(button: Button, action_name: String) -> void:
	button.text = "APPUYEZ..."
	button.set_meta("waiting_for_key", true)
	button.gui_input.connect(
		func(event: InputEvent):
			if not button.get_meta("waiting_for_key", false):
				return
			if event is InputEventKey and event.pressed:
				_rebind_pause_action(action_name, event)
				button.text = _get_pause_key_name(action_name)
				button.set_meta("waiting_for_key", false)
				var viewport := get_viewport()
				if viewport != null:
					viewport.set_input_as_handled()
	)

func _rebind_pause_action(action_name: String, event: InputEventKey) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	InputMap.action_erase_events(action_name)
	var new_event := InputEventKey.new()
	new_event.physical_keycode = event.physical_keycode
	new_event.keycode = event.keycode
	InputMap.action_add_event(action_name, new_event)
	_save_pause_keybinds()

func _save_pause_keybinds() -> void:
	var config := ConfigFile.new()
	var error := config.load("user://settings.cfg")
	if error != OK and error != ERR_FILE_NOT_FOUND:
		return
	for action_name in ["move_up", "move_down", "move_left", "move_right", "spell_orb", "spell_nova", "spell_dash"]:
		if not InputMap.has_action(action_name):
			continue
		var events := InputMap.action_get_events(action_name)
		if events.is_empty():
			continue
		var event: InputEvent = events[0]
		if event is InputEventKey:
			config.set_value("keybinds", action_name, event.physical_keycode)
	config.save("user://settings.cfg")

func _pause_keybind_row(parent: Control, y: float, caption: String, action_name: String) -> Button:
	parent.add_child(_label("", caption, Vector2(0, y + 4), Vector2(220, 18), 10, Color("b7cbe5")))
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.position = Vector2(240, y)
	button.size = Vector2(120, 30)
	button.text = _get_pause_key_name(action_name)
	button.add_theme_font_size_override("font_size", 11)
	button.pressed.connect(
		func():
			_start_pause_key_rebind(button, action_name)
	)
	parent.add_child(button)
	return button

func _pause_slider_row(parent: Control, y: float, caption: String, min_value: float, max_value: float, step: float) -> HSlider:
	parent.add_child(_label("", caption, Vector2(0, y), Vector2(200, 18), 10, Color("b7cbe5")))
	var slider := HSlider.new()
	slider.position = Vector2(0, y + 20)
	slider.size = Vector2(360, 20)
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	parent.add_child(slider)
	return slider

func _pause_toggle_row(parent: Control, y: float, caption: String) -> CheckButton:
	parent.add_child(_label("", caption, Vector2(0, y + 4), Vector2(260, 18), 10, Color("b7cbe5")))
	var toggle := CheckButton.new()
	toggle.position = Vector2(280, y)
	toggle.size = Vector2(80, 26)
	parent.add_child(toggle)
	return toggle

func _build_pause_menu() -> void:
	pause_menu = Control.new()
	pause_menu.name = "PauseMenu"
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_menu.visible = false
	hud.add_child(pause_menu)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_menu.add_child(dim)

	# --- Écran racine : Reprendre / Options / Quitter la partie ---
	pause_root_panel = _panel(Vector2(390, 200), Vector2(300, 260), Color("07111ff2"), Color("315b8d"), 16)
	pause_menu.add_child(pause_root_panel)

	pause_root_panel.add_child(_label("", "PAUSE", Vector2(0, 24), Vector2(300, 30), 20, Color("f3f8ff"), HORIZONTAL_ALIGNMENT_CENTER))

	var resume_btn := Button.new()
	resume_btn.text = "REPRENDRE"
	resume_btn.position = Vector2(30, 80)
	resume_btn.size = Vector2(240, 44)
	resume_btn.pressed.connect(_close_pause_menu)
	pause_root_panel.add_child(resume_btn)

	var options_btn := Button.new()
	options_btn.text = "OPTIONS"
	options_btn.position = Vector2(30, 134)
	options_btn.size = Vector2(240, 44)
	options_btn.pressed.connect(_show_pause_options)
	pause_root_panel.add_child(options_btn)

	var quit_btn := Button.new()
	quit_btn.text = "QUITTER LA PARTIE"
	quit_btn.position = Vector2(30, 188)
	quit_btn.size = Vector2(240, 44)
	quit_btn.add_theme_color_override("font_color", Color("ff8a8a"))
	quit_btn.pressed.connect(_quit_match_from_pause)
	pause_root_panel.add_child(quit_btn)

	# --- Écran options : audio / vidéo / touches / gameplay, mêmes
	# réglages que le menu principal, persistés dans le même fichier. ---
	pause_options_panel = _panel(Vector2(330, 30), Vector2(420, 640), Color("07111ff2"), Color("315b8d"), 16)
	pause_options_panel.visible = false
	pause_menu.add_child(pause_options_panel)

	pause_options_panel.add_child(_label("", "OPTIONS", Vector2(30, 20), Vector2(360, 28), 18, Color("f3f8ff")))

	var tabs := TabContainer.new()
	tabs.position = Vector2(30, 60)
	tabs.size = Vector2(360, 490)
	tabs.add_theme_font_size_override("font_size", 12)
	pause_options_panel.add_child(tabs)

	# --- Onglet AUDIO ---
	var audio_tab := Control.new()
	audio_tab.name = "AUDIO"
	tabs.add_child(audio_tab)
	pause_master_slider = _pause_slider_row(audio_tab, 12, "VOLUME GÉNÉRAL", 0.0, 100.0, 1.0)
	pause_master_slider.value_changed.connect(_on_pause_master_changed)
	pause_music_slider = _pause_slider_row(audio_tab, 64, "MUSIQUE", 0.0, 100.0, 1.0)
	pause_music_slider.value_changed.connect(_on_pause_music_changed)
	pause_sfx_slider = _pause_slider_row(audio_tab, 116, "EFFETS SONORES", 0.0, 100.0, 1.0)
	pause_sfx_slider.value_changed.connect(_on_pause_sfx_changed)

	# --- Onglet VIDÉO ---
	var video_tab := Control.new()
	video_tab.name = "VIDÉO"
	tabs.add_child(video_tab)
	pause_fullscreen_toggle = _pause_toggle_row(video_tab, 12, "PLEIN ÉCRAN")
	pause_fullscreen_toggle.toggled.connect(_on_pause_fullscreen_toggled)
	pause_vsync_toggle = _pause_toggle_row(video_tab, 44, "VSYNC")
	pause_vsync_toggle.toggled.connect(_on_pause_vsync_toggled)
	pause_screen_shake_toggle = _pause_toggle_row(video_tab, 76, "SECOUSSE CAMÉRA")
	pause_screen_shake_toggle.toggled.connect(_on_pause_screen_shake_toggled)
	pause_damage_numbers_toggle = _pause_toggle_row(video_tab, 108, "NOMBRES DE DÉGÂTS")
	pause_damage_numbers_toggle.toggled.connect(_on_pause_damage_numbers_toggled)
	pause_fov_slider = _pause_slider_row(video_tab, 148, "CHAMP DE VISION CAMÉRA", 55.0, 90.0, 1.0)
	pause_fov_slider.value_changed.connect(_on_pause_fov_changed)
	pause_camera_height_slider = _pause_slider_row(video_tab, 200, "HAUTEUR CAMÉRA", 2.0, 5.5, 0.1)
	pause_camera_height_slider.value_changed.connect(_on_pause_camera_height_changed)

	# --- Onglet TOUCHES ---
	var keys_tab := Control.new()
	keys_tab.name = "TOUCHES"
	tabs.add_child(keys_tab)
	pause_keybind_move_up_button = _pause_keybind_row(keys_tab, 12, "AVANCER", "move_up")
	pause_keybind_move_down_button = _pause_keybind_row(keys_tab, 52, "RECULER", "move_down")
	pause_keybind_move_left_button = _pause_keybind_row(keys_tab, 92, "GAUCHE", "move_left")
	pause_keybind_move_right_button = _pause_keybind_row(keys_tab, 132, "DROITE", "move_right")
	pause_keybind_orb_button = _pause_keybind_row(keys_tab, 172, "ARC BOLT", "spell_orb")
	pause_keybind_nova_button = _pause_keybind_row(keys_tab, 212, "NOVA", "spell_nova")
	pause_keybind_dash_button = _pause_keybind_row(keys_tab, 252, "PHASE DASH", "spell_dash")
	pause_sensitivity_slider = _pause_slider_row(keys_tab, 300, "SENSIBILITÉ MANETTE", 0.5, 6.0, 0.1)
	pause_sensitivity_slider.value_changed.connect(_on_pause_sensitivity_changed)
	pause_invert_y_toggle = _pause_toggle_row(keys_tab, 364, "INVERSER AXE Y (MANETTE)")
	pause_invert_y_toggle.toggled.connect(_on_pause_invert_y_toggled)

	# --- Onglet GAMEPLAY ---
	var gameplay_tab := Control.new()
	gameplay_tab.name = "GAMEPLAY"
	tabs.add_child(gameplay_tab)
	pause_tutorials_toggle = _pause_toggle_row(gameplay_tab, 12, "TUTORIELS")
	pause_tutorials_toggle.toggled.connect(_on_pause_tutorials_toggled)
	pause_ability_hints_toggle = _pause_toggle_row(gameplay_tab, 44, "ASTUCES")
	pause_ability_hints_toggle.toggled.connect(_on_pause_ability_hints_toggled)
	pause_autosave_toggle = _pause_toggle_row(gameplay_tab, 76, "SAUVEGARDE AUTO")
	pause_autosave_toggle.toggled.connect(_on_pause_autosave_toggled)
	pause_confirmations_toggle = _pause_toggle_row(gameplay_tab, 108, "CONFIRMATIONS")
	pause_confirmations_toggle.toggled.connect(_on_pause_confirmations_toggled)
	pause_indicators_toggle = _pause_toggle_row(gameplay_tab, 140, "INDICATEURS")
	pause_indicators_toggle.toggled.connect(_on_pause_indicators_toggled)

	var back_btn := Button.new()
	back_btn.text = "RETOUR"
	back_btn.position = Vector2(30, 570)
	back_btn.size = Vector2(360, 40)
	back_btn.pressed.connect(_show_pause_root)
	pause_options_panel.add_child(back_btn)

func _build_hud() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	hud = CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)

	# =====================================================
	# TOP SCOREBOARD — MOBA / COMPETITIVE
	# =====================================================
	var top := _panel(Vector2(430, 14), Vector2(420, 112), Color("081321e8"), Color("315b8d"), 16)
	top.name = "ControlTop"
	hud.add_child(top)

	subtitle_label = _label("", ("%s  •  BO3" % mode_value_for_bots() if _is_team_mode() else "1V1 DUEL  •  BO3"), Vector2(10, 6), Vector2(400, 14), 8, Color("7294bd"), HORIZONTAL_ALIGNMENT_CENTER)
	top.add_child(subtitle_label)

	var astral_label := _label("", "ASTRAL", Vector2(16, 27), Vector2(120, 24), 16, Color("78cfff"), HORIZONTAL_ALIGNMENT_CENTER)
	top.add_child(astral_label)

	var arcane_label := _label("", "ARCANE", Vector2(284, 27), Vector2(120, 24), 16, Color("d29cff"), HORIZONTAL_ALIGNMENT_CENTER)
	top.add_child(arcane_label)

	timer_label = _label("", ("01:45" if _is_team_mode() else "00:45"), Vector2(140, 20), Vector2(140, 38), 28, Color("fff0b0"), HORIZONTAL_ALIGNMENT_CENTER)
	top.add_child(timer_label)

	var score_caption := _label("", "BO3", Vector2(18, 59), Vector2(35, 16), 7, Color("6786ad"), HORIZONTAL_ALIGNMENT_LEFT)
	top.add_child(score_caption)
	score_label = _label("", "0  —  0", Vector2(100, 62), Vector2(220, 22), 16, Color("f4f7ff"), HORIZONTAL_ALIGNMENT_CENTER)
	score_label.name = "Score"
	top.add_child(score_label)

	var kills_caption := _label("", "KILLS", Vector2(18, 88), Vector2(40, 14), 7, Color("6786ad"), HORIZONTAL_ALIGNMENT_LEFT)
	top.add_child(kills_caption)
	var kills_value := _label("", "0  —  0", Vector2(55, 85), Vector2(110, 17), 10, Color("e9f1ff"), HORIZONTAL_ALIGNMENT_LEFT)
	kills_value.name = "KillsValue"
	top.add_child(kills_value)

	var round_value := _label("", "ROUND 1 / 3", Vector2(270, 85), Vector2(130, 17), 9, Color("b7cbe5"), HORIZONTAL_ALIGNMENT_RIGHT)
	round_value.name = "RoundValue"
	top.add_child(round_value)

	# =====================================================
	# RESPAWN OVERLAY — CENTRE DE L'ECRAN
	# =====================================================
	respawn_overlay = Control.new()
	respawn_overlay.name = "RespawnOverlay"
	respawn_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	respawn_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	respawn_overlay.visible = false
	hud.add_child(respawn_overlay)

	var respawn_box := _panel(Vector2(0, 0), Vector2(250, 132), Color("07111fe8"), Color("7d8da8"), 18)
	respawn_box.position = Vector2(515, 285)
	respawn_overlay.add_child(respawn_box)

	var skull := _label("", "☠", Vector2(0, 10), Vector2(250, 48), 34, Color("e8edf5"), HORIZONTAL_ALIGNMENT_CENTER)
	respawn_box.add_child(skull)
	respawn_countdown_label = _label("", "RÉAPPARITION  3.0", Vector2(0, 61), Vector2(250, 26), 14, Color("fff0b0"), HORIZONTAL_ALIGNMENT_CENTER)
	respawn_box.add_child(respawn_countdown_label)

	# =====================================================
	# BOTTOM HUD — TRUE MOBA STYLE
	# =====================================================
	var bottom := Control.new()
	bottom.name = "BottomMOBA"
	bottom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Le HUD ne doit jamais intercepter la souris : la caméra 3D utilise les événements souris capturés.
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bottom)

	# =====================================================
	# BOTTOM HUD — COMPACT AAA / MOBA
	# =====================================================
	var hero_name := "EREN" if selected_hero == "EREN" else ("KAITHLYN" if selected_hero == "KAITHLYN" else ("MAYLINH" if selected_hero == "MAYLINH" else "AERIS"))
	var hero_role := "FIRE BURST" if selected_hero == "EREN" else ("BERSERKER" if selected_hero == "KAITHLYN" else ("HEALER" if selected_hero == "MAYLINH" else "ARCANE SKIRMISHER"))
	var accent := Color("ff7138") if selected_hero == "EREN" else (Color("ffad55") if selected_hero == "KAITHLYN" else (Color("54e1a7") if selected_hero == "MAYLINH" else Color("58cfff")))
	hero_accent_color = accent

	# Profil façon "carte de héros" compétitive : portrait circulaire avec
	# badge de niveau, gros chiffre de vie bien visible, et la ressource
	# passive en badge circulaire (comme une charge d'ultime) plutôt qu'en
	# simple bandeau de texte.
	var hero_panel := _panel(Vector2(20, 606), Vector2(360, 96), Color("07111ff2"), accent.darkened(0.35), 16)
	bottom.add_child(hero_panel)

	var portrait := _panel(Vector2(8, 8), Vector2(80, 80), Color("101e32"), accent, 40)
	hero_panel.add_child(portrait)
	portrait.add_child(_label("", hero_name.substr(0, 1), Vector2(0, 14), Vector2(80, 52), 32, accent, HORIZONTAL_ALIGNMENT_CENTER))

	# Badge de niveau, ajouté APRÈS le portrait pour se dessiner par-dessus
	# son coin bas-droit (comme le badge de niveau des jeux compétitifs).
	var level_badge := _panel(Vector2(60, 60), Vector2(28, 28), Color("0a1220"), Color("f4c977"), 14)
	hero_panel.add_child(level_badge)
	var player_progress := get_node_or_null("/root/PlayerProgress")
	var player_level: int = int(player_progress.call("get_level")) if player_progress != null else 1
	level_badge_label = _label("", str(player_level), Vector2(0, 5), Vector2(28, 18), 11, Color("f4c977"), HORIZONTAL_ALIGNMENT_CENTER)
	level_badge.add_child(level_badge_label)

	hero_panel.add_child(_label("", hero_name, Vector2(100, 10), Vector2(180, 16), 12, Color("f3f8ff")))
	hero_panel.add_child(_label("", hero_role, Vector2(100, 26), Vector2(180, 11), 7, Color("718eaf")))

	# Gros chiffre de vie courante, bien plus lisible qu'un simple texte
	# posé sur la barre — la barre elle-même devient un simple liseré fin
	# sous le chiffre plutôt que l'élément principal.
	health_text = _label("", "100", Vector2(100, 38), Vector2(62, 34), 26, Color("eafff5"))
	hero_panel.add_child(health_text)
	health_max_label = _label("", "/ 100", Vector2(162, 50), Vector2(100, 22), 13, Color("6fa593"))
	health_max_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hero_panel.add_child(health_max_label)

	# ColorRect plutôt que ProgressBar : sa taille minimale imposée par le
	# thème ignorait la .size qu'on lui donnait et débordait du cadre du
	# panneau (même bug déjà rencontré — et corrigé de la même façon —
	# sur la barre d'XP du menu principal).
	health_bar_bg = ColorRect.new()
	health_bar_bg.name = "HealthBg"
	health_bar_bg.position = Vector2(100, 76)
	health_bar_bg.size = Vector2(HERO_HEALTH_BAR_WIDTH, 6)
	health_bar_bg.color = Color("0c1626")
	health_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_panel.add_child(health_bar_bg)

	health_bar_fill = ColorRect.new()
	health_bar_fill.name = "HealthFill"
	health_bar_fill.position = Vector2(100, 76)
	health_bar_fill.size = Vector2(HERO_HEALTH_BAR_WIDTH, 6)
	health_bar_fill.color = Color("31d795")
	health_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_panel.add_child(health_bar_fill)

	# Badge de ressource passive, façon charge d'ultime : cercle avec le
	# libellé court en haut et la valeur en gros au centre. Le contour
	# s'accentue automatiquement (cf. _update_hud) quand la ressource est
	# prête, au lieu de rester terne en permanence.
	passive_badge = _panel(Vector2(284, 12), Vector2(68, 68), Color("101e32"), accent.darkened(0.4), 34)
	hero_panel.add_child(passive_badge)
	passive_caption_label = _label("", "PASSIF", Vector2(0, 8), Vector2(68, 12), 7, Color("8aa0bd"), HORIZONTAL_ALIGNMENT_CENTER)
	passive_badge.add_child(passive_caption_label)
	passive_label = _label("", "0/3", Vector2(0, 22), Vector2(68, 34), 17, Color("ffe6a3"), HORIZONTAL_ALIGNMENT_CENTER)
	passive_badge.add_child(passive_label)

	# Sorts : uniquement les icônes. Les touches LMB/RMB/SPACE sont volontairement retirées.
	var skill_y := 644.0
	var skill_size := 64.0
	var skill_gap := 9.0
	var skill_x := 536.0

	if selected_hero == "MAYLINH":
		_add_skill_card(hud, Vector2(skill_x, skill_y), "", "ÉCLAT SPIRITUEL", "22 DMG", Color("c45cff"), "Orb", skill_size, "res://assets/hud/spirit_projectile.svg")
		_add_skill_card(hud, Vector2(skill_x + skill_size + skill_gap, skill_y), "", "CERCLE DE SOIN", "+28 PV", Color("48e0a1"), "Teleport", skill_size, "res://assets/hud/spirit_heal.svg")
		_add_skill_card(hud, Vector2(skill_x + (skill_size + skill_gap) * 2, skill_y), "", "FUITE", "TP", Color("b94cff"), "Dash", skill_size, "res://assets/hud/teleport.svg")
	elif selected_hero == "KAITHLYN":
		_add_skill_card(hud, Vector2(skill_x, skill_y), "", "LANCER DE HACHE", "45 DMG", Color("ff9f3f"), "Orb", skill_size, "res://assets/hud/axe.svg")
		_add_skill_card(hud, Vector2(skill_x + skill_size + skill_gap, skill_y), "", "BOUCLIER", "35 SHIELD", Color("f0b35a"), "Teleport", skill_size, "res://assets/hud/shield.svg")
		_add_skill_card(hud, Vector2(skill_x + (skill_size + skill_gap) * 2, skill_y), "", "CHARGE BRUTALE", "30 DMG", Color("ff7043"), "Dash", skill_size, "res://assets/hud/charge.svg")
	elif selected_hero == "EREN":
		_add_skill_card(hud, Vector2(skill_x, skill_y), "", "BOULE DE FEU", "30 DMG", Color("ff6a32"), "Orb", skill_size, "res://assets/hud/fireball.svg")
		_add_skill_card(hud, Vector2(skill_x + skill_size + skill_gap, skill_y), "", "NOVA INCENDIAIRE", "45 DMG", Color("ff9b32"), "Teleport", skill_size, "res://assets/hud/nova.svg")
		_add_skill_card(hud, Vector2(skill_x + (skill_size + skill_gap) * 2, skill_y), "", "CHARGE ENFLAMMÉE", "25 DMG", Color("ff4b22"), "Dash", skill_size, "res://assets/hud/charge_fire.svg")
	else:
		_add_skill_card(hud, Vector2(skill_x, skill_y), "", "ARC BOLT", "18 DMG", Color("389eea"), "Orb", skill_size, "res://assets/hud/arc_bolt.svg")
		_add_skill_card(hud, Vector2(skill_x + skill_size + skill_gap, skill_y), "", "TELEPORT", "5.5 M", Color("b16cf2"), "Teleport", skill_size, "res://assets/hud/teleport.svg")
		_add_skill_card(hud, Vector2(skill_x + (skill_size + skill_gap) * 2, skill_y), "", "PHASE DASH", "MOBILITÉ", Color("42d6ad"), "Dash", skill_size, "res://assets/hud/dash.svg")

	var help := _label("ControllerHelp", "WASD  •  SOURIS", Vector2(1110, 704), Vector2(145, 10), 6, Color("526b89"), HORIZONTAL_ALIGNMENT_RIGHT)
	bottom.add_child(help)

func _update_hud() -> void:
	if player == null or not is_instance_valid(player):
		return

	var seconds := 0
	var display_time := 0.0
	if _is_explore_mode():
		timer_label.text = "∞"
	else:
		display_time = network_round_time if multiplayer.has_multiplayer_peer() and not multiplayer.is_server() else round_time
		seconds = int(ceil(display_time))
		timer_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	if _is_team_mode():
		seconds = int(ceil(display_time))
		timer_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	if _is_duel_mode():
		timer_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
		score_label.text = "%d  —  %d" % [duel_astral_rounds, duel_arcane_rounds]
		var top_node := hud.get_node_or_null("ControlTop")
		if top_node == null:
			top_node = hud.get_child(0)
		var kills_value := top_node.get_node_or_null("KillsValue")
		if kills_value != null:
			kills_value.text = "%d  —  %d" % [duel_astral_kills, duel_arcane_kills]
		var round_value := top_node.get_node_or_null("RoundValue")
		if round_value != null:
			round_value.text = "ROUND %d / 3" % duel_round_number
	elif _is_team_mode():
		score_label.text = "%d  —  %d" % [team_astral_rounds, team_arcane_rounds]
		var top_node := hud.get_node_or_null("ControlTop")
		if top_node == null:
			top_node = hud.get_child(0)
		var kills_value := top_node.get_node_or_null("KillsValue")
		if kills_value != null:
			kills_value.text = "%d  —  %d" % [team_astral_kills, team_arcane_kills]
		var round_value := top_node.get_node_or_null("RoundValue")
		if round_value != null:
			round_value.text = "ROUND %d / 3" % team_round_number
	else:
		score_label.text = "%d  —  %d" % [kills, deaths]

	var network_node := get_node_or_null("/root/Network")
	if network_node != null:
		subtitle_label.text = "%s // BO3" % str(network_node.get("match_mode")) if _is_team_mode() or _is_duel_mode() else "%s // 3D THIRD PERSON" % str(network_node.get("match_mode"))
	var controller_help := hud.get_node_or_null("BottomMOBA/ControllerHelp")
	if controller_help != null:
		controller_help.text = "MANETTE" if last_input_was_controller else "WASD  •  SOURIS"

	if respawn_overlay != null:
		var respawn_left: float = -1.0
		if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
			# Client réseau : duel_respawn_timers / team_respawn_timers ne
			# sont peuplés que côté serveur et ne sont jamais répliqués.
			# On utilise donc le timer cosmétique alimenté par la RPC
			# arena_fighter_death (cf. _network_client_fighter_death).
			respawn_left = network_local_respawn_left
		elif _is_team_mode() and team_respawn_timers.has(player):
			respawn_left = float(team_respawn_timers[player])
		elif _is_duel_mode() and duel_respawn_timers.has(player):
			respawn_left = float(duel_respawn_timers[player])
		respawn_overlay.visible = respawn_left >= 0.0 and player.process_mode == Node.PROCESS_MODE_DISABLED
		if respawn_overlay.visible and respawn_countdown_label != null:
			respawn_countdown_label.text = "RÉAPPARITION  %.1f" % respawn_left

	if health_bar_fill != null and is_instance_valid(health_bar_fill):
		var health_ratio: float = clampf(player.health / maxf(1.0, player.max_health), 0.0, 1.0)
		health_bar_fill.size.x = HERO_HEALTH_BAR_WIDTH * health_ratio
	health_text.text = "%d" % int(player.health)
	if health_max_label != null and is_instance_valid(health_max_label):
		health_max_label.text = "/ %d" % int(player.max_health)
	passive_caption_label.text = player.get_passive_short_label()
	passive_label.text = player.get_passive_value_text()
	if passive_badge != null and is_instance_valid(passive_badge):
		passive_badge.add_theme_stylebox_override(
			"panel",
			_box(Color("101e32"), Color("fff2c4") if player.is_passive_ready() else hero_accent_color.darkened(0.4), 34, 2)
		)
	if selected_hero == "MAYLINH":
		orb_cooldown_label.set_cooldown(player.orb_cooldown, 4.0)
		nova_cooldown_label.set_cooldown(player.heal_cooldown, 10.0)
		dash_cooldown_label.set_cooldown(player.flee_cooldown, 10.0)
	elif selected_hero == "KAITHLYN":
		orb_cooldown_label.set_cooldown(player.axe_cooldown, 0.55)
		nova_cooldown_label.set_cooldown(player.shield_cooldown, 6.0)
		dash_cooldown_label.set_cooldown(player.charge_cooldown, 8.0)
	elif selected_hero == "EREN":
		orb_cooldown_label.set_cooldown(player.orb_cooldown, 2.5)
		nova_cooldown_label.set_cooldown(player.teleport_cooldown, 8.0)
		dash_cooldown_label.set_cooldown(player.dash_cooldown, 7.0)
	else:
		orb_cooldown_label.set_cooldown(player.orb_cooldown, 0.48)
		nova_cooldown_label.set_cooldown(player.teleport_cooldown, 4.0)
		dash_cooldown_label.set_cooldown(player.dash_cooldown, 1.3)

func _ready_text(cooldown: float) -> String:
	return "PRÊT" if cooldown <= 0.05 else "%.1f s" % cooldown

func _find_deathmatch_winner() -> ArenaPlayer3D:
	var winner: ArenaPlayer3D = null
	var best_kills := -1
	for fighter in get_tree().get_nodes_in_group("fighters"):
		var fighter_node := fighter as ArenaPlayer3D
		if fighter_node == null or not is_instance_valid(fighter_node):
			continue
		var fighter_kills := int(deathmatch_scores.get(fighter_node, 0))
		if fighter_kills > best_kills:
			best_kills = fighter_kills
			winner = fighter_node
	return winner

func _show_round_end() -> void:
	var winner := _find_deathmatch_winner()
	var best_kills := int(deathmatch_scores.get(winner, 0)) if winner != null else -1
	var player_won := winner == player
	var winner_name := winner.hero_id if winner != null else "ÉGALITÉ"
	_show_match_results(player_won, winner_name, "KILLS : %d" % maxi(best_kills, 0))

## Diffuse le résultat DEATHMATCH aux clients : sans ça, seul l'hôte voyait
## un écran de fin de partie, les clients restaient bloqués sans rien.
func _broadcast_deathmatch_result() -> void:
	var network_node := get_node_or_null("/root/Network")
	if network_node == null or not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var winner := _find_deathmatch_winner()
	var best_kills := int(deathmatch_scores.get(winner, 0)) if winner != null else -1
	var winner_peer_id: int = winner.network_peer_id if winner != null else -1
	var winner_hero: String = winner.hero_id if winner != null else "ÉGALITÉ"
	for target_id in multiplayer.get_peers():
		network_node.arena_deathmatch_result.rpc_id(int(target_id), winner_peer_id, winner_hero, best_kills)

func _network_client_deathmatch_result(winner_peer_id: int, winner_hero: String, best_kills: int) -> void:
	game_over = true
	var player_won := winner_peer_id == multiplayer.get_unique_id()
	_show_match_results(player_won, winner_hero, "KILLS : %d" % maxi(best_kills, 0))

func _add_skill_card(parent: Node, position: Vector2, key: String, skill_name: String, detail: String, color: Color, node_name: String, card_size: float, icon_path: String) -> void:
	var icon := MOBAAbilityIcon.new()
	icon.name = "SkillIcon_" + node_name
	icon.position = position
	var texture := load(icon_path) as Texture2D
	icon.setup(texture, color, card_size)
	parent.add_child(icon)

	match node_name:
		"Orb":
			orb_cooldown_label = icon
		"Nova", "Teleport":
			nova_cooldown_label = icon
		"Dash":
			dash_cooldown_label = icon

func _panel(position: Vector2, size: Vector2, background: Color, border: Color, radius: int) -> Panel:
	var panel := Panel.new()
	panel.position = position
	panel.size = size
	panel.add_theme_stylebox_override("panel", _box(background, border, radius, 1))
	return panel

func _box(background: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	return box

func _label(node_name: String, text_value: String, position: Vector2, size: Vector2, font_size: int, color: Color, alignment: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	if not node_name.is_empty():
		label.name = node_name
	label.text = text_value
	label.position = position
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	return label
