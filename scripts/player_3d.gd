class_name ArenaPlayer3D
extends CharacterBody3D

signal spell_cast(kind: String, origin: Vector3, direction: Vector3, caster: CharacterBody3D)

## ------------------------------------------------------------------
## STATS DES PERSONNAGES — modifiables directement dans l'inspecteur Godot.
## Chaque héros a son propre bloc, complètement séparé des autres.
## Sélectionnez le nœud du joueur pour voir et modifier ces valeurs.
## ------------------------------------------------------------------

@export_group("AERIS")
@export var aeris_max_health: float = 100.0
@export var aeris_speed: float = 9.5
@export var aeris_dash_cooldown: float = 1.3
@export var aeris_dash_speed: float = 24.0
@export var aeris_dash_time: float = 0.14
@export var aeris_orb_cooldown: float = 0.48
@export var aeris_orb_damage: int = 18
@export var aeris_orb_damage_empowered: int = 27
@export var aeris_teleport_cooldown: float = 4.0
@export var aeris_passive_max_charges: int = 3
## Le bâton est accroché à l'os "handslot.r" du squelette (déjà bien orienté
## par l'artiste) : ces valeurs ne sont qu'un ajustement fin optionnel.
@export var aeris_staff_held_position: Vector3 = Vector3.ZERO
@export var aeris_staff_held_rotation_degrees: Vector3 = Vector3.ZERO
@export var aeris_staff_scale: float = 1.0
## Décalage local (par rapport à la main tenant le bâton) du point d'où
## partent ses sorts : sert à viser le bout du bâton plutôt que la main.
@export var aeris_staff_tip_local_offset: Vector3 = Vector3(0.0, 0.65, 0.0)

@export_group("MAYLINH")
@export var maylinh_max_health: float = 100.0
@export var maylinh_speed: float = 9.5
@export var maylinh_flee_cooldown: float = 10.0
@export var maylinh_flee_invulnerable_duration: float = 2.0
@export var maylinh_flee_speed_multiplier: float = 3.0
@export var maylinh_spirit_cooldown: float = 4.0
@export var maylinh_spirit_damage: int = 22
@export var maylinh_heal_cooldown: float = 10.0
@export var maylinh_heal_radius: float = 7.5
@export var maylinh_heal_amount: float = 28.0
@export var maylinh_passive_max_charges: int = 2
## Dague lancée (RMB) : part, touche le premier ennemi sur sa trajectoire
## (ou atteint sa portée max), puis revient automatiquement dans la main de
## Maylinh sans avoir besoin de marcher dessus.
@export var maylinh_dagger_throw_cooldown: float = 3.0
@export var maylinh_dagger_damage: int = 25
@export var maylinh_dagger_range: float = 14.0
@export var maylinh_dagger_throw_speed: float = 24.0
@export var maylinh_dagger_return_speed: float = 20.0
## La dague est accrochée à l'os "handslot.r" du squelette (déjà bien
## orienté par l'artiste) : ces valeurs ne sont qu'un ajustement fin optionnel.
@export var maylinh_dagger_held_position: Vector3 = Vector3.ZERO
@export var maylinh_dagger_held_rotation_degrees: Vector3 = Vector3.ZERO
@export var maylinh_dagger_scale: float = 1.0

@export_group("KAITHLYN")
@export var kaithlyn_max_health: float = 100.0
@export var kaithlyn_speed: float = 9.5
@export var kaithlyn_axe_cooldown: float = 0.55
@export var kaithlyn_axe_damage: int = 45
@export var kaithlyn_axe_charge_max_time: float = 0.9
@export var kaithlyn_axe_min_distance: float = 3.5
@export var kaithlyn_axe_max_distance: float = 12.0
@export var kaithlyn_shield_cooldown: float = 6.0
@export var kaithlyn_shield_duration: float = 3.0
@export var kaithlyn_shield_points: float = 35.0
@export var kaithlyn_shield_rage_on_absorb: float = 25.0
@export var kaithlyn_charge_cooldown: float = 8.0
@export var kaithlyn_charge_cooldown_enraged: float = 0.5
@export var kaithlyn_charge_duration: float = 0.35
@export var kaithlyn_charge_speed: float = 20.0
@export var kaithlyn_charge_hit_range: float = 1.8
@export var kaithlyn_charge_hit_damage: int = 30
@export var kaithlyn_rage_max: float = 100.0
@export var kaithlyn_rage_duration: float = 5.0
@export var kaithlyn_rage_on_damage_taken: float = 35.0
## Position/rotation de la hache et du bouclier tenus en main. Ajustables ici
## pour corriger leur orientation ("dans le bon sens") sans toucher au code :
## la scène se met à jour en direct dans l'éditeur/en jeu.
## L'arme est accrochée à l'os "handslot.r"/"handslot.l" du squelette (déjà
## bien orienté par l'artiste) : ces valeurs ne sont qu'un ajustement fin
## optionnel par-dessus, pas un positionnement absolu.
@export var kaithlyn_axe_held_position: Vector3 = Vector3.ZERO
@export var kaithlyn_axe_held_rotation_degrees: Vector3 = Vector3(0.0, 180.0, 0.0)
@export var kaithlyn_axe_scale: float = 1.25
@export var kaithlyn_shield_held_position: Vector3 = Vector3.ZERO
@export var kaithlyn_shield_held_rotation_degrees: Vector3 = Vector3.ZERO
@export var kaithlyn_shield_scale: float = 1.12

@export_group("EREN")
@export var eren_max_health: float = 100.0
@export var eren_speed: float = 9.5
@export var eren_orb_cooldown: float = 2.5
@export var eren_orb_damage: int = 30
@export var eren_charge_cooldown: float = 7.0
@export var eren_charge_duration: float = 0.35
@export var eren_charge_speed: float = 20.0
@export var eren_charge_hit_range: float = 1.8
@export var eren_charge_hit_damage: int = 25
@export var eren_nova_cooldown: float = 8.0
@export var eren_nova_damage_base: int = 45
@export var eren_nova_damage_tier1: int = 70
@export var eren_nova_damage_tier2: int = 95
@export var eren_nova_damage_tier3: int = 145
@export var eren_passive_fury_max: int = 300
## L'épée est accrochée à l'os "handslot.r" du squelette (déjà bien orienté
## par l'artiste) : ces valeurs ne sont qu'un ajustement fin optionnel.
@export var eren_sword_held_position: Vector3 = Vector3.ZERO
@export var eren_sword_held_rotation_degrees: Vector3 = Vector3.ZERO
@export var eren_sword_scale: float = 1.0

@export_group("Déplacement commun")
@export var acceleration: float = 42.0
@export var deceleration: float = 55.0
@export var jump_velocity: float = 9.5
@export var gravity: float = 28.0
@export var sprint_speed_multiplier: float = 1.35

@export_group("Modèles 3D")
@export var mage_scene_path: String = "res://assets/kaykit/Mage.glb"
@export var maylinh_scene_path: String = "res://assets/kaykit/Rogue_Hooded.glb"
@export var kaithlyn_scene_path: String = "res://assets/kaykit/Barbarian.glb"
@export var eren_scene_path: String = "res://assets/kaykit/Knight.glb"
@export var kaithlyn_axe_scene_path: String = "res://assets/kaykit/axe_1handed.gltf"
@export var kaithlyn_shield_scene_path: String = "res://assets/kaykit/shield_round_barbarian.gltf"
@export var aeris_staff_scene_path: String = "res://assets/kaykit/staff.gltf"
@export var eren_sword_scene_path: String = "res://assets/kaykit/sword_1handed.gltf"
@export var maylinh_dagger_scene_path: String = "res://assets/kaykit/dagger.gltf"
@export var movement_anims_path: String = "res://assets/kaykit/Rig_Medium_MovementBasic.glb"
@export var general_anims_path: String = "res://assets/kaykit/Rig_Medium_General.glb"
@export var model_scale: float = 1.15

## ------------------------------------------------------------------
## FIN DES STATS ÉDITABLES. Le reste du fichier est la logique du jeu :
## ne pas modifier sauf si vous savez ce que vous faites.
## ------------------------------------------------------------------

func _hero_stat(aeris_value, maylinh_value, kaithlyn_value, eren_value):
	match hero_id:
		"MAYLINH": return maylinh_value
		"KAITHLYN": return kaithlyn_value
		"EREN": return eren_value
		_: return aeris_value

func _current_speed() -> float:
	var base_speed: float = _hero_stat(aeris_speed, maylinh_speed, kaithlyn_speed, eren_speed)
	if _sprint_active:
		return base_speed * sprint_speed_multiplier
	return base_speed

func _try_jump() -> void:
	if not is_grounded or rooted_left > 0.0 or charge_left > 0.0:
		return
	is_grounded = false
	vertical_velocity = jump_velocity
	_jump_start_timer = 0.18

var max_health: float = 100.0
var health: float = 100.0
var last_damage_dealt: float = 0.0
## Total des dégâts infligés / éliminations réalisées par CE fighter depuis
## le début de la PARTIE ENTIÈRE (contrairement à "kills"/"duel_astral_kills"
## etc. qui repartent à zéro à chaque round) : sert au tableau de score de
## fin de partie.
var match_damage_dealt: float = 0.0
var match_kills: int = 0
var is_bot: bool = false

# Multiplayer V2 : le serveur simule les joueurs et les bots.
var network_peer_id: int = 0
var network_move_direction: Vector3 = Vector3.ZERO
var network_aim_direction: Vector3 = Vector3(0.0, 0.0, -1.0)
var network_visual_velocity: Vector3 = Vector3.ZERO
# Etat réseau reçu côté client. Ces valeurs sont consommées par Arena
# pour interpoler le rendu sans dépendre des paquets réseau.
var network_target_position: Vector3 = Vector3.ZERO
var network_target_rotation_y: float = 0.0
var network_has_snapshot: bool = false
var network_round_serial: int = 1
var network_input_sequence: int = 0
var team_color: Color = Color("48a9ff")
var hero_id: String = "AERIS"
var target: ArenaPlayer3D
var dash_left: float = 0.0
var dash_cooldown: float = 0.0
var orb_cooldown: float = 0.0
var teleport_cooldown: float = 0.0
var cage_cooldown: float = 0.0
var heal_cooldown: float = 0.0
var flee_cooldown: float = 0.0
var rooted_left: float = 0.0
var flee_left: float = 0.0
var invulnerable_left: float = 0.0
var axe_cooldown: float = 0.0
var axe_charge_active: bool = false
var axe_charge_time: float = 0.0
var axe_last_throw_distance: float = 12.0
var shield_cooldown: float = 0.0
var shield_left: float = 0.0
var shield_points: float = 0.0
var charge_cooldown: float = 0.0
var charge_left: float = 0.0
var charge_direction: Vector3 = Vector3.ZERO
var charge_hit_done: bool = false
var charge_vfx_timer: float = 0.0
var recoil: Vector3 = Vector3.ZERO
var aim_direction: Vector3 = Vector3(0.0, 0.0, -1.0)
# Direction figée au moment du dash, comme charge_direction pour Kaithlyn/
# Eren : aim_direction est resynchronisée en continu depuis le réseau
# (network_aim_direction, basé caméra) à chaque frame côté serveur, ce qui
# écrasait quasi aussitôt la direction voulue par try_dash() si on la
# stockait dans aim_direction — le dash finissait presque toujours par
# repartir selon la caméra au lieu de l'orientation du personnage au moment
# de l'appui.
var dash_direction: Vector3 = Vector3.ZERO
var vertical_velocity: float = 0.0
var is_grounded: bool = true
var network_jump_requested: bool = false
var network_sprint_held: bool = false
var _sprint_active: bool = false
var _jump_buffer_left: float = 0.0
var _jump_start_timer: float = 0.0

# Contrôleur : états précédents pour garantir les "just pressed/released"
# sans dépendre de l'InputMap.
var _controller_prev_a := false
var _controller_prev_y := false
var _controller_prev_rt := false

# Passifs de héros
var passive_charges: int = 0
var passive_active: bool = false
var passive_timer: float = 0.0
var kaithlyn_rage: float = 0.0
var eren_fury: int = 0
var _model: Node3D
var _visual_root: Node3D
var _animation_player: AnimationPlayer
var _idle_anim: StringName = &"Idle_A"
var _walk_anim: StringName = &"Walking_A"
var _run_anim: StringName = &"Running_A"
var _jump_start_anim: StringName = &""
var _jump_air_anim: StringName = &"Idle_A"
var _landing_anim: StringName = &"Idle_A"
var _last_anim: StringName = &""
var _bot_orb_timer: float = 0.0
var _bot_nova_timer: float = 0.0
var _model_path: String = ""
var _skeleton: Skeleton3D
var _axe_weapon: Node3D
var _shield_weapon: Node3D
var _held_weapon: Node3D
var _held_weapon_attachment: BoneAttachment3D
var _axe_bone_index: int = -1
var _shield_bone_index: int = -1
var _axe_attachment: BoneAttachment3D
var _shield_attachment: BoneAttachment3D

func _ready() -> void:
	max_health = _hero_stat(aeris_max_health, maylinh_max_health, kaithlyn_max_health, eren_max_health)
	health = max_health
	add_to_group("fighters")
	_setup_collision()
	_setup_model()
	_find_best_animation_names()
	_play_animation(_idle_anim)

func _physics_process(delta: float) -> void:
	# En multijoueur, le serveur bloque toute simulation pendant le compte à rebours.
	# Les clients restent également immobiles jusqu'au signal de démarrage serveur.
	if multiplayer.has_multiplayer_peer():
		var network_node := get_node_or_null("/root/Network")
		if network_node != null and not bool(network_node.get("match_started")):
			velocity = Vector3.ZERO
			_update_animation()
			return

	dash_left = maxf(0.0, dash_left - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	orb_cooldown = maxf(0.0, orb_cooldown - delta)
	teleport_cooldown = maxf(0.0, teleport_cooldown - delta)
	axe_cooldown = maxf(0.0, axe_cooldown - delta)
	shield_cooldown = maxf(0.0, shield_cooldown - delta)
	shield_left = maxf(0.0, shield_left - delta)
	if shield_left <= 0.0:
		shield_points = 0.0
	charge_cooldown = maxf(0.0, charge_cooldown - delta)
	charge_left = maxf(0.0, charge_left - delta)
	charge_vfx_timer = maxf(0.0, charge_vfx_timer - delta)
	cage_cooldown = maxf(0.0, cage_cooldown - delta)
	heal_cooldown = maxf(0.0, heal_cooldown - delta)
	flee_cooldown = maxf(0.0, flee_cooldown - delta)
	passive_timer = maxf(0.0, passive_timer - delta)
	if passive_active and passive_timer <= 0.0:
		passive_active = false
		passive_charges = 0
	if hero_id == "KAITHLYN" and kaithlyn_rage >= kaithlyn_rage_max and not passive_active:
		_activate_kaithlyn_berserk()
	rooted_left = maxf(0.0, rooted_left - delta)
	flee_left = maxf(0.0, flee_left - delta)
	invulnerable_left = maxf(0.0, invulnerable_left - delta)
	_jump_start_timer = maxf(0.0, _jump_start_timer - delta)
	_jump_buffer_left = maxf(0.0, _jump_buffer_left - delta)

	if is_bot:
		_bot_input(delta)
	elif multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			_network_server_input(delta)
		elif network_peer_id == multiplayer.get_unique_id():
			_player_input(delta)
		else:
			# Joueur distant : le CharacterBody est piloté par la position
			# logique serveur. Le rendu visible est interpolé séparément
			# par VisualRoot dans Arena._update_network_visuals(), qui inclut
			# déjà la hauteur Y (donc un saut distant est visible en position).
			# On déduit juste l'état "en l'air" de cette même position pour
			# choisir la bonne animation.
			velocity = network_visual_velocity
			is_grounded = network_target_position.y <= 0.05
			_sync_held_weapons()
			_update_animation()
			return
	else:
		_player_input(delta)

	if rooted_left > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * 2.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * 2.0 * delta)
	elif charge_left > 0.0:
		var current_charge_speed: float = _hero_stat(0.0, 0.0, kaithlyn_charge_speed, eren_charge_speed)
		velocity.x = charge_direction.x * current_charge_speed
		velocity.z = charge_direction.z * current_charge_speed
		if charge_vfx_timer <= 0.0:
			charge_vfx_timer = 0.055
			var trail_kind: String = "eren_charge_trail" if hero_id == "EREN" else "charge_trail"
			spell_cast.emit(trail_kind, global_position + Vector3.UP * 0.02, charge_direction, self)
	elif dash_left > 0.0:
		velocity.x = dash_direction.x * aeris_dash_speed
		velocity.z = dash_direction.z * aeris_dash_speed
	else:
		var horizontal: Vector2 = Vector2(velocity.x, velocity.z)
		if horizontal.length() > _current_speed():
			horizontal = horizontal.limit_length(_current_speed())
			velocity.x = horizontal.x
			velocity.z = horizontal.y

	velocity += recoil
	recoil = recoil.move_toward(Vector3.ZERO, 32.0 * delta)

	if not is_grounded:
		vertical_velocity -= gravity * delta
	velocity.y = vertical_velocity

	move_and_slide()

	# L'arène actuelle est plane autour de Y=0. Le serveur dédié n'a pas
	# toujours de collision Terrain exploitable : on ne bloque donc plus Y en
	# permanence (ce qui empêchait tout saut), seulement quand le personnage
	# atteint ou passe sous le niveau du sol, pour ne jamais tomber sous la map.
	if global_position.y <= 0.0 and vertical_velocity <= 0.0:
		global_position.y = 0.0
		vertical_velocity = 0.0
		velocity.y = 0.0
		if not is_grounded:
			is_grounded = true
			_play_animation(_landing_anim)
	elif multiplayer.has_multiplayer_peer() and multiplayer.is_server() and global_position.y < 0.0:
		global_position.y = 0.0

	if (hero_id == "KAITHLYN" or hero_id == "EREN") and charge_left > 0.0 and not charge_hit_done:
		for node in get_tree().get_nodes_in_group("fighters"):
			var fighter: ArenaPlayer3D = node as ArenaPlayer3D
			if fighter == null or fighter == self or not is_instance_valid(fighter):
				continue
			if fighter.team_color == team_color:
				continue
			var current_charge_hit_range: float = _hero_stat(0.0, 0.0, kaithlyn_charge_hit_range, eren_charge_hit_range)
			if global_position.distance_to(fighter.global_position) <= current_charge_hit_range:
				charge_hit_done = true
				var charge_hit_kind: String = "eren_charge_hit" if hero_id == "EREN" else "charge_hit"
				spell_cast.emit(charge_hit_kind, fighter.global_position + Vector3.UP * 0.65, charge_direction, self)
				break

	# Le joueur reste au niveau du sol sans téléporter sa position X/Z.

	_sync_held_weapons()
	_update_animation()

func _network_server_input(delta: float) -> void:
	_sprint_active = network_sprint_held
	if network_jump_requested:
		network_jump_requested = false
		_try_jump()
	var move_direction := network_move_direction
	var current_speed: float = _current_speed() * (maylinh_flee_speed_multiplier if flee_left > 0.0 else 1.0)
	var target_velocity: Vector3 = move_direction * current_speed
	if move_direction.length_squared() > 0.001:
		velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
		_face_direction(move_direction, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
	if network_aim_direction.length_squared() > 0.001:
		aim_direction = network_aim_direction.normalized()

@rpc("any_peer", "call_remote", "unreliable")
func network_receive_input(move_direction: Vector3, aim_direction_value: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != network_peer_id:
		return
	network_move_direction = move_direction.normalized() if move_direction.length_squared() > 0.001 else Vector3.ZERO
	if aim_direction_value.length_squared() > 0.001:
		network_aim_direction = aim_direction_value.normalized()

func _player_input(delta: float) -> void:
	# Mouvement robuste : clavier direct + stick gauche direct.
	# On ne dépend pas de l'InputMap pour éviter qu'un réglage utilisateur
	# ou une action manquante casse W/Z ou le stick.
	var input_direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_Z):
		input_direction.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_direction.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q):
		input_direction.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_direction.x += 1.0

	var controller := _get_controller_device()
	if controller >= 0:
		var stick := Vector2(
			Input.get_joy_axis(controller, JOY_AXIS_LEFT_X),
			Input.get_joy_axis(controller, JOY_AXIS_LEFT_Y)
		)
		if stick.length() > 0.18:
			stick = stick.limit_length(1.0)
			input_direction = stick

	if input_direction.length_squared() > 1.0:
		input_direction = input_direction.normalized()
	var camera: Camera3D = get_viewport().get_camera_3d()
	var forward: Vector3 = Vector3(0.0, 0.0, -1.0)
	var right: Vector3 = Vector3(1.0, 0.0, 0.0)

	if camera != null:
		forward = -camera.global_transform.basis.z
		forward.y = 0.0
		if forward.length_squared() > 0.001:
			forward = forward.normalized()
		right = camera.global_transform.basis.x
		right.y = 0.0
		if right.length_squared() > 0.001:
			right = right.normalized()

	var move_direction: Vector3 = right * input_direction.x + forward * (-input_direction.y)
	if move_direction.length_squared() > 1.0:
		move_direction = move_direction.normalized()

	_sprint_active = Input.is_key_pressed(KEY_SHIFT)
	if Input.is_action_just_pressed("jump"):
		# On tamponne l'appui un court instant : la commande de saut voyage sur
		# un canal réseau non fiable (comme le déplacement), un seul paquet
		# perdu ne doit donc pas faire "rater" le saut.
		_jump_buffer_left = 0.15
		_try_jump()

	var current_speed: float = _current_speed() * (maylinh_flee_speed_multiplier if flee_left > 0.0 else 1.0)
	var target_velocity: Vector3 = move_direction * current_speed
	if move_direction.length_squared() > 0.001:
		velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
		_face_direction(move_direction, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)

	# La direction d'attaque reste liée à la caméra : indispensable pour le stick droit.
	var attack_direction := _get_camera_attack_direction()
	attack_direction.y = 0.0
	if attack_direction.length_squared() > 0.001:
		attack_direction = attack_direction.normalized()
		aim_direction = attack_direction

	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server() and network_peer_id == multiplayer.get_unique_id():
		var network_node := get_node_or_null("/root/Network")
		if network_node != null:
			network_input_sequence += 1
			network_node.arena_player_input.rpc_id(1, move_direction, aim_direction, network_input_sequence, _jump_buffer_left > 0.0, _sprint_active)

	var controller_dash_pressed := false
	var controller_nova_pressed := false
	var controller_orb_pressed := false
	var controller_orb_released := false
	if controller >= 0:
		var a_now := Input.is_joy_button_pressed(controller, JOY_BUTTON_A)
		var y_now := Input.is_joy_button_pressed(controller, JOY_BUTTON_Y)
		var rt_now := Input.get_joy_axis(controller, JOY_AXIS_TRIGGER_RIGHT) > 0.35
		controller_dash_pressed = a_now and not _controller_prev_a
		controller_nova_pressed = y_now and not _controller_prev_y
		controller_orb_pressed = rt_now and not _controller_prev_rt
		controller_orb_released = not rt_now and _controller_prev_rt
		_controller_prev_a = a_now
		_controller_prev_y = y_now
		_controller_prev_rt = rt_now

	if Input.is_action_just_pressed("spell_dash") or controller_dash_pressed:
		if hero_id == "MAYLINH":
			try_flee()
		elif hero_id == "KAITHLYN":
			try_charge(_character_forward())
		elif hero_id == "EREN":
			try_eren_charge(_character_forward())
		else:
			try_dash(_character_forward())

	if hero_id == "KAITHLYN":
		if Input.is_action_just_pressed("spell_orb") or controller_orb_pressed:
			start_axe_charge()
		elif axe_charge_active:
			axe_charge_time = minf(kaithlyn_axe_charge_max_time, axe_charge_time + delta)
			if Input.is_action_just_released("spell_orb") or controller_orb_released:
				release_axe_charge()
	elif Input.is_action_just_pressed("spell_orb") or controller_orb_pressed:
		if hero_id == "MAYLINH":
			try_heal()
		else:
			try_orb(aim_direction)

	if Input.is_action_just_pressed("spell_nova") or controller_nova_pressed:
		if hero_id == "MAYLINH":
			try_throw_dagger(aim_direction)
		elif hero_id == "KAITHLYN":
			try_shield()
		elif hero_id == "EREN":
			try_nova()
		else:
			try_teleport(_character_forward())

func _get_controller_device() -> int:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return -1
	return int(pads[0])


func _bot_input(delta: float) -> void:
	if not is_instance_valid(target):
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
		return

	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0.0
	var distance: float = to_target.length()
	if distance < 0.05:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
		return

	var forward: Vector3 = to_target.normalized()
	var side: Vector3 = Vector3(-forward.z, 0.0, forward.x)
	var strafe: float = sin(Time.get_ticks_msec() * 0.003) * 0.65
	var move_direction: Vector3
	if distance > 7.0:
		move_direction = (forward + side * strafe).normalized()
	else:
		move_direction = (-forward * 0.45 + side * strafe).normalized()

	var target_velocity: Vector3 = move_direction * (_current_speed() * 0.78)
	velocity.x = move_toward(velocity.x, target_velocity.x, 32.0 * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, 32.0 * delta)
	_face_direction(forward, delta)

	_bot_orb_timer = maxf(0.0, _bot_orb_timer - delta)
	_bot_nova_timer = maxf(0.0, _bot_nova_timer - delta)
	if hero_id == "KAITHLYN":
		if distance < 12.0 and _bot_orb_timer <= 0.0:
			_bot_orb_timer = 2.0
			try_throw_axe(forward, 1.0)
		if distance < 3.0 and _bot_nova_timer <= 0.0:
			_bot_nova_timer = 4.0
			try_shield()
		if distance < 2.4 and charge_cooldown <= 0.0:
			try_charge(forward)
	else:
		if distance < 14.0 and _bot_orb_timer <= 0.0:
			_bot_orb_timer = 0.85
			try_orb(forward)
		if distance < 3.4 and _bot_nova_timer <= 0.0:
			_bot_nova_timer = 4.2
			try_teleport()

func _face_direction(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	aim_direction = direction.normalized()
	var desired_angle: float = atan2(aim_direction.x, aim_direction.z)
	rotation.y = lerp_angle(rotation.y, desired_angle, clampf(delta * 18.0, 0.0, 1.0))

## Direction vers laquelle le PERSONNAGE (son modèle 3D, pas la caméra) est
## actuellement tourné. Utilisée pour les dash/charges : avant ça, ils
## partaient selon la direction d'entrée relative à la caméra (ou la caméra
## elle-même à l'arrêt), ce qui ne correspondait pas forcément à l'endroit
## où le personnage regardait visuellement, surtout en strafe.
func _character_forward() -> Vector3:
	return Vector3(sin(rotation.y), 0.0, cos(rotation.y))

func _get_camera_attack_direction() -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		var direction: Vector3 = -camera.global_transform.basis.z
		direction.y = 0.0
		if direction.length_squared() > 0.001:
			direction = direction.normalized()
			aim_direction = direction
			return direction
	return aim_direction.normalized()

func start_axe_charge() -> void:
	if hero_id != "KAITHLYN" or axe_charge_active:
		return
	if axe_cooldown > 0.0:
		return
	if _axe_weapon == null or not is_instance_valid(_axe_weapon):
		return
	axe_charge_active = true
	axe_charge_time = 0.0
	aim_direction = _get_camera_attack_direction()

func release_axe_charge() -> void:
	if not axe_charge_active:
		return
	var ratio: float = clampf(axe_charge_time / kaithlyn_axe_charge_max_time, 0.0, 1.0)
	var direction: Vector3 = _get_camera_attack_direction()
	axe_charge_active = false
	axe_charge_time = 0.0
	try_throw_axe(direction, ratio)

func get_axe_charge_ratio() -> float:
	if not axe_charge_active:
		return 0.0
	return clampf(axe_charge_time / kaithlyn_axe_charge_max_time, 0.0, 1.0)

func get_axe_charge_distance() -> float:
	return lerpf(kaithlyn_axe_min_distance, kaithlyn_axe_max_distance, get_axe_charge_ratio())

func try_throw_axe(direction: Vector3 = Vector3.ZERO, charge_ratio: float = 1.0) -> void:
	if axe_cooldown > 0.0:
		return
	if _axe_weapon == null or not is_instance_valid(_axe_weapon):
		return
	if direction.length_squared() < 0.001:
		direction = aim_direction
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	direction = direction.normalized()
	aim_direction = direction
	_face_direction(direction, 1.0)
	axe_cooldown = kaithlyn_axe_cooldown
	charge_ratio = clampf(charge_ratio, 0.0, 1.0)
	# Défini avant l'émission : le serveur réseau peut donc récupérer exactement
	# la distance demandée par le client au moment de la commande.
	axe_last_throw_distance = lerpf(kaithlyn_axe_min_distance, kaithlyn_axe_max_distance, charge_ratio)
	spell_cast.emit("axe_throw", global_position + Vector3.UP * 0.95 + direction * 0.55, direction, self)

func try_shield() -> void:
	if shield_cooldown > 0.0 or shield_left > 0.0:
		return
	shield_cooldown = kaithlyn_shield_cooldown
	shield_left = kaithlyn_shield_duration
	shield_points = kaithlyn_shield_points
	spell_cast.emit("shield", global_position + Vector3.UP * 0.8, aim_direction, self)

func get_shield_active() -> bool:
	return shield_left > 0.0 and shield_points > 0.0

func _reduce_kaithlyn_cooldowns(seconds: float) -> void:
	axe_cooldown = maxf(0.0, axe_cooldown - seconds)
	shield_cooldown = maxf(0.0, shield_cooldown - seconds)
	charge_cooldown = maxf(0.0, charge_cooldown - seconds)

func try_charge(direction: Vector3) -> void:
	if charge_cooldown > 0.0 or charge_left > 0.0:
		return
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		direction = aim_direction
	charge_direction = direction.normalized()
	aim_direction = charge_direction
	charge_left = kaithlyn_charge_duration
	charge_hit_done = false
	charge_cooldown = kaithlyn_charge_cooldown_enraged if passive_active else kaithlyn_charge_cooldown
	spell_cast.emit("charge", global_position + Vector3.UP * 0.15, charge_direction, self)

func try_dash(direction: Vector3) -> void:
	if dash_cooldown > 0.0:
		return
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		direction = aim_direction
	dash_direction = direction.normalized()
	dash_left = aeris_dash_time
	dash_cooldown = aeris_dash_cooldown
	spell_cast.emit("dash", global_position + Vector3.UP * 0.05, dash_direction, self)

## Pour Aeris, les sorts partent du bout du bâton (accroché à la main) plutôt
## que d'un point fixe deviné sur le corps : plus précis avec la caméra et
## cohérent quel que soit l'angle de vue.
func _aeris_spell_origin(fallback: Vector3) -> Vector3:
	if hero_id == "AERIS" and _held_weapon != null and is_instance_valid(_held_weapon):
		return _held_weapon.global_transform * aeris_staff_tip_local_offset
	return fallback

func try_orb(direction: Vector3) -> void:
	if orb_cooldown > 0.0:
		return
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	direction = direction.normalized()
	aim_direction = direction
	orb_cooldown = eren_orb_cooldown if hero_id == "EREN" else aeris_orb_cooldown
	var origin: Vector3 = _aeris_spell_origin(global_position + Vector3.UP * 1.05 + direction * 0.8)
	spell_cast.emit("orb", origin, direction, self)

func try_nova() -> void:
	if teleport_cooldown > 0.0:
		return
	teleport_cooldown = eren_nova_cooldown
	spell_cast.emit("nova", global_position + Vector3.UP * 0.04, aim_direction, self)

func try_eren_charge(direction: Vector3) -> void:
	if dash_cooldown > 0.0 or charge_left > 0.0:
		return
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		direction = aim_direction
	charge_direction = direction.normalized()
	aim_direction = charge_direction
	charge_left = eren_charge_duration
	charge_hit_done = false
	dash_cooldown = eren_charge_cooldown
	spell_cast.emit("eren_charge", global_position + Vector3.UP * 0.05, charge_direction, self)

func try_spirit(direction: Vector3) -> void:
	if orb_cooldown > 0.0:
		return
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	direction = direction.normalized()
	aim_direction = direction
	var empowered: bool = hero_id == "MAYLINH" and passive_active
	if empowered:
		passive_active = false
		passive_timer = 0.0
		passive_charges = 0
	orb_cooldown = maylinh_spirit_cooldown
	spell_cast.emit("spirit", global_position + Vector3.UP * 1.05 + direction * 0.8, direction, self)


func try_heal() -> void:
	if heal_cooldown > 0.0:
		return
	var healed_any: bool = false
	for node in get_tree().get_nodes_in_group("fighters"):
		var fighter: ArenaPlayer3D = node as ArenaPlayer3D
		if fighter == null or not is_instance_valid(fighter):
			continue
		if fighter.team_color != team_color:
			continue
		if global_position.distance_to(fighter.global_position) > maylinh_heal_radius:
			continue
		var old_health: float = fighter.health
		fighter.health = minf(fighter.max_health, fighter.health + maylinh_heal_amount)
		if fighter.health > old_health:
			healed_any = true

	# Le sort consomme quand même son cooldown : c'est une capacité de zone.
	heal_cooldown = maylinh_heal_cooldown
	if healed_any and hero_id == "MAYLINH":
		passive_charges += 1
		if passive_charges >= maylinh_passive_max_charges:
			passive_charges = 0
			passive_active = true
			passive_timer = 999.0
	spell_cast.emit("heal", global_position + Vector3.UP * 0.05, Vector3.ZERO, self)


func try_flee() -> void:
	if flee_cooldown > 0.0:
		return
	flee_cooldown = maylinh_flee_cooldown
	invulnerable_left = maylinh_flee_invulnerable_duration
	var direction: Vector3 = aim_direction.normalized()
	if direction.length_squared() < 0.001:
		direction = Vector3(0.0, 0.0, -1.0)
	spell_cast.emit("flee", global_position + Vector3.UP * 0.04, direction, self)


func apply_root(duration: float) -> void:
	rooted_left = maxf(rooted_left, duration)
	velocity.x = 0.0
	velocity.z = 0.0

func try_teleport(direction: Vector3 = Vector3.ZERO) -> void:
	if teleport_cooldown > 0.0:
		return
	teleport_cooldown = aeris_teleport_cooldown
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		direction = aim_direction
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		direction = Vector3(0.0, 0.0, -1.0)
	direction = direction.normalized()
	var origin: Vector3 = _aeris_spell_origin(global_position + Vector3.UP * 0.05)
	spell_cast.emit("teleport", origin, direction, self)

func try_throw_dagger(direction: Vector3 = Vector3.ZERO) -> void:
	if orb_cooldown > 0.0:
		return
	if _held_weapon == null or not is_instance_valid(_held_weapon):
		return
	if direction.length_squared() < 0.001:
		direction = aim_direction
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	direction = direction.normalized()
	aim_direction = direction
	_face_direction(direction, 1.0)
	orb_cooldown = maylinh_dagger_throw_cooldown
	spell_cast.emit("dagger_throw", global_position + Vector3.UP * 0.95 + direction * 0.55, direction, self)

func take_damage(amount: int, force: Vector3) -> bool:
	last_damage_dealt = 0.0
	# Mode Découverte (Custom Game) : aucun combat, on ignore silencieusement
	# tous les dégâts plutôt que de dupliquer ce garde à chaque source de
	# dégâts (mêlée, projectiles, hache, traînée de feu...).
	var network_node := get_node_or_null("/root/Network")
	if network_node != null and str(network_node.get("match_mode")) == "CUSTOM EXPLORE":
		return false
	if invulnerable_left > 0.0:
		return false
	var remaining_damage: float = float(amount)
	if get_shield_active():
		var absorbed: float = minf(remaining_damage, shield_points)
		shield_points -= absorbed
		remaining_damage -= absorbed
		_reduce_kaithlyn_cooldowns(1.0)
		if hero_id == "KAITHLYN":
			kaithlyn_rage = minf(kaithlyn_rage_max, kaithlyn_rage + kaithlyn_shield_rage_on_absorb)
		spell_cast.emit("shield_hit", global_position + Vector3.UP * 0.9, Vector3.ZERO, self)
		if shield_points <= 0.0:
			shield_points = 0.0
			shield_left = 0.0
	if remaining_damage <= 0.0:
		return false
	last_damage_dealt = minf(remaining_damage, health)
	health -= remaining_damage
	if hero_id == "KAITHLYN":
		kaithlyn_rage = minf(kaithlyn_rage_max, kaithlyn_rage + minf(remaining_damage, kaithlyn_rage_on_damage_taken))
	recoil += force
	if health > 0.0:
		return false
	health = max_health
	if hero_id == "EREN":
		eren_fury = 0
		passive_charges = 0
	if is_bot:
		global_position = Vector3(randf_range(-10.0, 10.0), 0.0, randf_range(-6.0, 6.0))
	else:
		global_position = Vector3(0.0, 0.0, 6.0)
	velocity = Vector3.ZERO
	return true

func _activate_kaithlyn_berserk() -> void:
	if hero_id != "KAITHLYN":
		return
	kaithlyn_rage = 0.0
	passive_active = true
	passive_timer = kaithlyn_rage_duration
	passive_charges = 0
	# La Charge disponible immédiatement puis toutes les 0,5 s pendant la rage.
	charge_cooldown = minf(charge_cooldown, kaithlyn_charge_cooldown_enraged)
	spell_cast.emit("berserk", global_position + Vector3.UP * 0.8, aim_direction, self)

func register_aeris_hit() -> void:
	if hero_id != "AERIS" or passive_active:
		return
	passive_charges += 1
	if passive_charges >= aeris_passive_max_charges:
		passive_charges = 0
		passive_active = true
		passive_timer = 999.0

func register_eren_damage(amount: int) -> void:
	if hero_id != "EREN" or amount <= 0:
		return
	eren_fury = mini(eren_passive_fury_max, eren_fury + amount)
	passive_charges = eren_fury

func consume_eren_fury() -> int:
	var fury: int = eren_fury
	eren_fury = 0
	passive_charges = 0
	return fury

func get_passive_text() -> String:
	if hero_id == "AERIS":
		return "FLUX ARCANÉ  %d/%d" % [passive_charges, aeris_passive_max_charges] if not passive_active else "FLUX ARCANÉ  PRÊT"
	if hero_id == "MAYLINH":
		return "ÉNERGIE SPIRITUELLE  %d/%d" % [passive_charges, maylinh_passive_max_charges] if not passive_active else "ÉNERGIE SPIRITUELLE  PRÊT"
	if hero_id == "EREN":
		return "FUREUR INCANDESCENTE  %d/300" % eren_fury
	if passive_active:
		return "RAGE BERSERK  %.1fs" % passive_timer
	return "RAGE BERSERK  %d%%" % int(kaithlyn_rage)

func cooldown_text() -> String:
	if hero_id == "MAYLINH":
		return "Éclat %.1fs | Soin %.1fs | Fuite %.1fs" % [orb_cooldown, heal_cooldown, flee_cooldown]
	if hero_id == "KAITHLYN":
		return "Hache %.1fs | Bouclier %.1fs | Charge %.1fs" % [axe_cooldown, shield_cooldown, charge_cooldown]
	if hero_id == "EREN":
		return "Boule de feu %.1fs | Nova %.1fs | Charge %.1fs" % [orb_cooldown, teleport_cooldown, dash_cooldown]
	return "Orbe %.1fs | Téléportation %.1fs | Dash %.1fs" % [orb_cooldown, teleport_cooldown, dash_cooldown]

func _setup_collision() -> void:
	# Joueur : layer 1, collision avec le terrain layer 2 et les obstacles layer 1.
	collision_layer = 1
	collision_mask = 3
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.name = "CollisionShape3D"
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	shape_node.shape = capsule
	shape_node.position.y = 0.9
	add_child(shape_node)

func _setup_model() -> void:
	if hero_id == "EREN":
		_model_path = eren_scene_path
	elif hero_id == "KAITHLYN":
		_model_path = kaithlyn_scene_path
	elif hero_id == "MAYLINH":
		_model_path = maylinh_scene_path
	else:
		_model_path = mage_scene_path
	var scene: PackedScene = load(_model_path) as PackedScene
	if scene == null:
		push_error("Modèle KayKit introuvable : " + _model_path)
		return
	# Conteneur visuel séparé du CharacterBody3D.
	# Les animations importées peuvent modifier le root du GLB sans
	# pouvoir casser la synchronisation réseau du personnage.
	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	_visual_root.position = Vector3.ZERO
	_visual_root.rotation = Vector3.ZERO
	_visual_root.top_level = false
	add_child(_visual_root)

	_model = scene.instantiate() as Node3D
	if _model == null:
		_visual_root.queue_free()
		_visual_root = null
		return
	_model.name = "Eren" if hero_id == "EREN" else ("Kaithlyn" if hero_id == "KAITHLYN" else ("Maylinh" if hero_id == "MAYLINH" else "Mage"))
	_model.scale = Vector3.ONE * model_scale
	_model.position = Vector3.ZERO
	_model.rotation = Vector3.ZERO
	_model.top_level = false
	_visual_root.add_child(_model)
	# Les rigs KayKit ont des os dédiés "handslot.r"/"handslot.l" prévus par
	# l'artiste pour porter exactement ce genre d'objet, avec la bonne
	# orientation déjà intégrée. On les utilise pour que les armes suivent la
	# vraie main du personnage (y compris pendant les animations) au lieu
	# d'un simple décalage fixe deviné à la main, qui les faisait apparaître
	# dans le dos ou sur le bras selon les personnages.
	_skeleton = _find_skeleton(_model)

	if hero_id == "KAITHLYN":
		_create_kaithlyn_weapons_independent()
	elif hero_id == "AERIS":
		_held_weapon = _create_simple_held_weapon(aeris_staff_scene_path, "AerisStaff", aeris_staff_held_position, aeris_staff_held_rotation_degrees, aeris_staff_scale)
	elif hero_id == "EREN":
		_held_weapon = _create_simple_held_weapon(eren_sword_scene_path, "ErenSword", eren_sword_held_position, eren_sword_held_rotation_degrees, eren_sword_scale)
	elif hero_id == "MAYLINH":
		_held_weapon = _create_simple_held_weapon(maylinh_dagger_scene_path, "MaylinhDagger", maylinh_dagger_held_position, maylinh_dagger_held_rotation_degrees, maylinh_dagger_scale)

	_animation_player = AnimationPlayer.new()
	_animation_player.name = "AnimationPlayer"
	_animation_player.root_node = NodePath("../VisualRoot/Eren" if hero_id == "EREN" else ("../VisualRoot/Kaithlyn" if hero_id == "KAITHLYN" else ("../VisualRoot/Maylinh" if hero_id == "MAYLINH" else "../VisualRoot/Mage")))
	add_child(_animation_player)

	_import_animation_libraries(movement_anims_path)
	_import_animation_libraries(general_anims_path)

func _create_kaithlyn_weapons_independent() -> void:
	_axe_weapon = _load_weapon_or_fallback(kaithlyn_axe_scene_path, "KaithlynAxe", true)
	_axe_weapon.scale = Vector3.ONE * kaithlyn_axe_scale
	_axe_attachment = _attach_weapon_node(_axe_weapon, "handslot.r", kaithlyn_axe_held_position, kaithlyn_axe_held_rotation_degrees)

	_shield_weapon = _load_weapon_or_fallback(kaithlyn_shield_scene_path, "KaithlynShield", false)
	_shield_weapon.scale = Vector3.ONE * kaithlyn_shield_scale
	_shield_attachment = _attach_weapon_node(_shield_weapon, "handslot.l", kaithlyn_shield_held_position, kaithlyn_shield_held_rotation_degrees)

func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found: Skeleton3D = _find_skeleton(child)
		if found != null:
			return found
	return null

## Accroche une arme déjà instanciée au socle de main du squelette KayKit
## ("handslot.r"/"handslot.l"), pensé par l'artiste pour porter ce genre
## d'objet avec la bonne orientation. Si le squelette ou le socle sont
## introuvables (modèle sans rig, ou nom d'os différent), on retombe sur un
## simple enfant du corps avec le décalage manuel fourni, pour ne jamais
## faire disparaître l'arme.
func _attach_weapon_node(weapon: Node3D, socket_bone_name: String, position_offset: Vector3, rotation_offset_degrees: Vector3) -> BoneAttachment3D:
	if weapon == null:
		return null
	weapon.position = position_offset
	weapon.rotation_degrees = rotation_offset_degrees
	weapon.visible = true
	var bone_index: int = -1
	if _skeleton != null and is_instance_valid(_skeleton):
		bone_index = _skeleton.find_bone(socket_bone_name)
	if _skeleton == null or bone_index < 0:
		add_child(weapon)
		return null
	var attachment := BoneAttachment3D.new()
	attachment.name = weapon.name + "Socket"
	_skeleton.add_child(attachment)
	attachment.bone_name = socket_bone_name
	attachment.add_child(weapon)
	return attachment

func _find_mesh_instance(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root as MeshInstance3D
	for child in root.get_children():
		var found: MeshInstance3D = _find_mesh_instance(child)
		if found != null:
			return found
	return null

func _weapon_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.35
	mat.roughness = 0.42
	return mat

func _build_fallback_axe() -> Node3D:
	var root := Node3D.new()
	var handle := MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.045
	handle_mesh.bottom_radius = 0.065
	handle_mesh.height = 1.25
	handle.mesh = handle_mesh
	handle.material_override = _weapon_material(Color("5a301c"))
	root.add_child(handle)

	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.62, 0.38, 0.09)
	blade.mesh = blade_mesh
	blade.position = Vector3(0.22, 0.38, 0.0)
	blade.material_override = _weapon_material(Color("bfc7d5"))
	root.add_child(blade)
	return root

func _build_fallback_shield() -> Node3D:
	var root := Node3D.new()
	var shield := MeshInstance3D.new()
	var shield_mesh := CylinderMesh.new()
	shield_mesh.top_radius = 0.43
	shield_mesh.bottom_radius = 0.43
	shield_mesh.height = 0.12
	shield.mesh = shield_mesh
	shield.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	shield.material_override = _weapon_material(Color("8a5a24"))
	root.add_child(shield)

	var boss := MeshInstance3D.new()
	var boss_mesh := SphereMesh.new()
	boss_mesh.radius = 0.11
	boss_mesh.height = 0.22
	boss.mesh = boss_mesh
	boss.material_override = _weapon_material(Color("d9a441"))
	boss.position = Vector3(0.0, 0.0, -0.09)
	root.add_child(boss)
	return root

func _load_weapon_or_fallback(scene_path: String, node_name: String, is_axe: bool) -> Node3D:
	var weapon: Node3D = null
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed != null:
		weapon = packed.instantiate() as Node3D
	if weapon == null or _find_mesh_instance(weapon) == null:
		weapon = _build_fallback_axe() if is_axe else _build_fallback_shield()
	weapon.name = node_name
	var mesh_node: MeshInstance3D = _find_mesh_instance(weapon)
	if mesh_node != null:
		mesh_node.visible = true
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return weapon

func _sync_held_weapons() -> void:
	# L'arme suit désormais la main réelle du squelette (BoneAttachment3D sur
	# "handslot.r"/"handslot.l"), y compris pendant les animations : il n'y a
	# donc plus besoin de la repositionner nous-mêmes chaque frame. On ne
	# réapplique ici que l'ajustement fin optionnel (@export), pour pouvoir
	# le régler en direct depuis l'inspecteur pendant que le jeu tourne.
	if hero_id == "KAITHLYN":
		# La hache n'est repositionnée ici que tant qu'elle est réellement
		# tenue (parent = son BoneAttachment3D). Une fois lancée, elle est
		# reparentée à l'arène et pilotée par _update_thrown_axes : il ne
		# faut surtout pas écraser sa position de vol ici.
		if _axe_weapon != null and is_instance_valid(_axe_weapon) and _axe_attachment != null and _axe_weapon.get_parent() == _axe_attachment:
			_axe_weapon.position = kaithlyn_axe_held_position
			_axe_weapon.rotation_degrees = kaithlyn_axe_held_rotation_degrees
		if _shield_weapon != null and is_instance_valid(_shield_weapon):
			_shield_weapon.position = kaithlyn_shield_held_position
			_shield_weapon.rotation_degrees = kaithlyn_shield_held_rotation_degrees
		return
	if _held_weapon == null or not is_instance_valid(_held_weapon):
		return
	if hero_id == "AERIS":
		_held_weapon.position = aeris_staff_held_position
		_held_weapon.rotation_degrees = aeris_staff_held_rotation_degrees
	elif hero_id == "EREN":
		_held_weapon.position = eren_sword_held_position
		_held_weapon.rotation_degrees = eren_sword_held_rotation_degrees
	elif hero_id == "MAYLINH":
		_held_weapon.position = maylinh_dagger_held_position
		_held_weapon.rotation_degrees = maylinh_dagger_held_rotation_degrees

func _create_simple_held_weapon(scene_path: String, node_name: String, held_position: Vector3, held_rotation_degrees: Vector3, weapon_scale: float) -> Node3D:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("Arme introuvable : " + scene_path)
		return null
	var weapon: Node3D = packed.instantiate() as Node3D
	if weapon == null:
		return null
	weapon.name = node_name
	weapon.scale = Vector3.ONE * weapon_scale
	var mesh_node: MeshInstance3D = _find_mesh_instance(weapon)
	if mesh_node != null:
		mesh_node.visible = true
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_held_weapon_attachment = _attach_weapon_node(weapon, "handslot.r", held_position, held_rotation_degrees)
	return weapon

func release_dagger_for_throw() -> Node3D:
	if _held_weapon == null or not is_instance_valid(_held_weapon):
		return null
	var dagger: Node3D = _held_weapon
	_held_weapon = null
	return dagger

func recover_dagger(dagger: Node3D) -> void:
	if dagger == null or not is_instance_valid(dagger) or hero_id != "MAYLINH":
		return
	if _held_weapon_attachment != null and is_instance_valid(_held_weapon_attachment):
		dagger.reparent(_held_weapon_attachment, false)
	else:
		dagger.reparent(self, true)
	dagger.position = maylinh_dagger_held_position
	dagger.rotation_degrees = maylinh_dagger_held_rotation_degrees
	dagger.scale = Vector3.ONE * maylinh_dagger_scale
	dagger.visible = true
	_held_weapon = dagger

func release_axe_for_throw() -> Node3D:
	if _axe_weapon == null or not is_instance_valid(_axe_weapon):
		return null
	var axe: Node3D = _axe_weapon
	_axe_weapon = null
	return axe

func recover_axe(axe: Node3D) -> void:
	if axe == null or not is_instance_valid(axe) or hero_id != "KAITHLYN":
		return
	if _axe_attachment != null and is_instance_valid(_axe_attachment):
		axe.reparent(_axe_attachment, false)
	else:
		axe.reparent(self, true)
	axe.position = kaithlyn_axe_held_position
	axe.rotation_degrees = kaithlyn_axe_held_rotation_degrees
	axe.scale = Vector3.ONE * kaithlyn_axe_scale
	axe.visible = true
	_axe_weapon = axe
	axe_cooldown = 0.0

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null

func _import_animation_libraries(path: String) -> void:
	if _animation_player == null:
		return
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		push_error("Animations KayKit introuvables : " + path)
		return
	var source_root: Node = scene.instantiate()
	var source_player: AnimationPlayer = _find_animation_player(source_root)
	if source_player == null:
		push_error("Aucun AnimationPlayer dans : " + path)
		source_root.queue_free()
		return

	var destination: AnimationLibrary
	if _animation_player.has_animation_library(&""):
		destination = _animation_player.get_animation_library(&"")
	else:
		destination = AnimationLibrary.new()
		_animation_player.add_animation_library(&"", destination)

	for library_name in source_player.get_animation_library_list():
		var source_library: AnimationLibrary = source_player.get_animation_library(library_name)
		if source_library == null:
			continue
		for animation_name in source_library.get_animation_list():
			if destination.has_animation(animation_name):
				continue
			var source_animation: Animation = source_library.get_animation(animation_name)
			if source_animation == null:
				continue
			var animation_copy: Animation = source_animation.duplicate(true) as Animation
			if animation_copy == null:
				continue
			if animation_name in [&"Walking_A", &"Walking_B", &"Walking_C", &"Running_A", &"Running_B", &"Idle_A", &"Idle_B"]:
				animation_copy.loop_mode = Animation.LOOP_LINEAR
			destination.add_animation(animation_name, animation_copy)

	source_root.queue_free()

func _find_best_animation_names() -> void:
	if _animation_player == null or not _animation_player.has_animation_library(&""):
		return
	var library: AnimationLibrary = _animation_player.get_animation_library(&"")
	if library == null:
		return
	var available: Array[StringName] = library.get_animation_list()
	_idle_anim = _find_animation(available, [&"Idle_A", &"Idle_B", &"Idle"])
	_walk_anim = _find_animation(available, [&"Walking_A", &"Walking_B", &"Walking_C"])
	_run_anim = _find_animation(available, [&"Running_A", &"Running_B"])
	_jump_start_anim = _find_animation(available, [&"Jump_Start"])
	_jump_air_anim = _find_animation(available, [&"Jump_Idle"])
	_landing_anim = _find_animation(available, [&"Jump_Land"])
	if _idle_anim == StringName() and not available.is_empty():
		_idle_anim = available[0]
	if _walk_anim == StringName():
		_walk_anim = _idle_anim
	if _run_anim == StringName():
		_run_anim = _walk_anim
	if _jump_air_anim == StringName():
		_jump_air_anim = _idle_anim
	if _landing_anim == StringName():
		_landing_anim = _idle_anim

func _find_animation(available: Array[StringName], candidates: Array[StringName]) -> StringName:
	for candidate in candidates:
		if available.has(candidate):
			return candidate
	return StringName()

func _play_animation(animation_name: StringName) -> void:
	if _animation_player == null or animation_name == StringName() or animation_name == _last_anim:
		return
	if not _animation_player.has_animation(animation_name):
		return
	_animation_player.play(animation_name, 0.12, 1.0)
	_last_anim = animation_name

func _update_animation() -> void:
	if not is_grounded:
		if _jump_start_timer > 0.0 and _jump_start_anim != StringName():
			_play_animation(_jump_start_anim)
		else:
			_play_animation(_jump_air_anim)
		return
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if horizontal_speed < 0.15:
		_play_animation(_idle_anim)
	elif horizontal_speed < _current_speed() * 0.82:
		_play_animation(_walk_anim)
	else:
		_play_animation(_run_anim)
