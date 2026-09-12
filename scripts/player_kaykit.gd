extends CharacterBody2D
## ARENA RIFT - Player with a KayKit 3D visual rendered into the existing 2D game.
## Gameplay/collision remain 2D so arena.gd, projectiles, bots and HUD keep working.

signal spell_cast(kind: String, origin: Vector2, direction: Vector2, caster: CharacterBody2D)

const SPEED: float = 540.0
const DASH_SPEED: float = 1450.0
const DASH_TIME: float = 0.12

const MAX_HEALTH: int = 100
const VISUAL_SCENE: String = "res://assets/kaykit/Mage.glb"
const MOVEMENT_ANIMS: String = "res://assets/kaykit/Rig_Medium_MovementBasic.glb"
const GENERAL_ANIMS: String = "res://assets/kaykit/Rig_Medium_General.glb"
const ROTATION_SPEED: float = 18.0

var max_health: int = MAX_HEALTH
var health: int = MAX_HEALTH
var team_color: Color = Color("48a9ff")
var is_bot: bool = false
var target: CharacterBody2D
var dash_left: float = 0.0
var dash_cooldown: float = 0.0
var orb_cooldown: float = 0.0
var nova_cooldown: float = 0.0
var recoil: Vector2 = Vector2.ZERO
var flash_time: float = 0.0

var _visual_root: Node2D
var _viewport: SubViewport
var _visual_sprite: Sprite2D
var _model: Node3D
var _animation_player: AnimationPlayer
var _idle_anim: StringName = &"Idle_A"
var _walk_anim: StringName = &"Walking_A"
var _visual_ready: bool = false


func _ready() -> void:
	add_to_group("fighters")
	_setup_kaykit_visual()
	queue_redraw()


func _physics_process(delta: float) -> void:
	flash_time = maxf(0.0, flash_time - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	orb_cooldown = maxf(0.0, orb_cooldown - delta)
	nova_cooldown = maxf(0.0, nova_cooldown - delta)

	if is_bot:
		_bot_input(delta)
	else:
		_player_input()

	if dash_left > 0.0:
		dash_left -= delta
		velocity = velocity.normalized() * DASH_SPEED
	else:
		velocity = velocity.limit_length(SPEED)

	velocity += recoil
	recoil = recoil.move_toward(Vector2.ZERO, 2800.0 * delta)
	move_and_slide()

	position.x = clampf(position.x, 42.0, 2158.0)
	position.y = clampf(position.y, 42.0, 1358.0)

	_update_kaykit_visual(delta)
	queue_redraw()


func _player_input() -> void:
	var input_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_direction * SPEED

	# Aim is independent from movement: the player always faces the mouse.
	var mouse_position: Vector2 = get_global_mouse_position()
	if mouse_position.distance_squared_to(global_position) > 1.0:
		look_at(mouse_position)

	if Input.is_action_just_pressed("spell_dash"):
		try_dash(input_direction)
	if Input.is_action_just_pressed("spell_orb"):
		try_orb((get_global_mouse_position() - global_position).normalized())
	if Input.is_action_just_pressed("spell_nova"):
		try_nova()


func _bot_input(_delta: float) -> void:
	if not is_instance_valid(target):
		return

	var to_target: Vector2 = target.global_position - global_position
	var distance: float = to_target.length()
	var strafe: Vector2 = Vector2(-to_target.y, to_target.x).normalized() * sin(Time.get_ticks_msec() * 0.004)
	velocity = (to_target.normalized() * (1.0 if distance > 440.0 else -0.45) + strafe * 0.65).normalized() * SPEED * 0.65
	look_at(target.global_position)

	if distance < 850.0 and orb_cooldown <= 0.0:
		try_orb(to_target.normalized())
	if distance < 190.0 and nova_cooldown <= 0.0:
		try_nova()


func try_dash(direction: Vector2) -> void:
	if dash_cooldown > 0.0:
		return

	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT.rotated(rotation)

	velocity = direction.normalized() * DASH_SPEED
	dash_left = DASH_TIME
	dash_cooldown = 1.3


func try_orb(direction: Vector2) -> void:
	if orb_cooldown > 0.0 or direction == Vector2.ZERO:
		return

	orb_cooldown = 0.48
	spell_cast.emit("orb", global_position + direction * 38.0, direction, self)


func try_nova() -> void:
	if nova_cooldown > 0.0:
		return

	nova_cooldown = 4.0
	spell_cast.emit("nova", global_position, Vector2.ZERO, self)


func take_damage(amount: int, force: Vector2) -> void:
	health -= amount
	recoil += force
	flash_time = 0.10

	if health <= 0:
		if not is_bot:
			health = max_health
			position = Vector2(1100, 700)
			return

		health = max_health
		position = Vector2(1100, 700) + Vector2(
			randf_range(-360.0, 360.0),
			randf_range(-220.0, 220.0)
		)


func cooldown_text() -> String:
	return "Orbe %.1fs | Nova %.1fs | Dash %.1fs" % [
		orb_cooldown,
		nova_cooldown,
		dash_cooldown
	]


func _setup_kaykit_visual() -> void:
	_visual_root = Node2D.new()
	_visual_root.name = "KayKitVisual"
	_visual_root.position = Vector2(0.0, -10.0)
	add_child(_visual_root)

	_viewport = SubViewport.new()
	_viewport.name = "KayKitViewport"
	_viewport.size = Vector2i(256, 256)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.handle_input_locally = false
	_visual_root.add_child(_viewport)

	var world: World3D = World3D.new()
	_viewport.world_3d = world

	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dce9ff")
	environment.ambient_light_energy = 1.8
	world.environment = environment

	var camera: Camera3D = Camera3D.new()
	camera.name = "TopDownCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.2
	camera.position = Vector3(0.0, 4.8, 6.2)
	_viewport.add_child(camera)
	camera.look_at(Vector3(0.0, 0.75, 0.0), Vector3.UP)
	camera.current = true

	var key_light: DirectionalLight3D = DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	key_light.light_energy = 2.0
	key_light.shadow_enabled = true
	_viewport.add_child(key_light)

	var fill_light: OmniLight3D = OmniLight3D.new()
	fill_light.name = "FillLight"
	fill_light.position = Vector3(-2.5, 3.0, 2.5)
	fill_light.light_energy = 1.2
	fill_light.omni_range = 8.0
	_viewport.add_child(fill_light)

	var model_scene: PackedScene = load(VISUAL_SCENE) as PackedScene
	if model_scene == null:
		push_warning("KayKit Mage introuvable: " + VISUAL_SCENE)
		return

	_model = model_scene.instantiate() as Node3D
	if _model == null:
		push_warning("Impossible d'instancier KayKit Mage.")
		return

	_model.name = "Mage"
	_model.position = Vector3(0.0, 0.0, 0.0)
	_model.scale = Vector3(0.55, 0.55, 0.55)
	_viewport.add_child(_model)

	_animation_player = _find_animation_player(_model)

	if _animation_player == null:
		_animation_player = AnimationPlayer.new()
		_animation_player.name = "AnimationPlayer"
		_model.add_child(_animation_player)

	# IMPORTANT:
	# Mage.glb has the character mesh/rig but no animations.
	# The movement/general GLBs contain the actual AnimationLibraries.
	# We copy the libraries directly instead of calling get_animation_library()
	# on a missing library (which caused Ref<AnimationLibrary>() errors).
	_import_animation_libraries(MOVEMENT_ANIMS)
	_import_animation_libraries(GENERAL_ANIMS)

	_visual_sprite = Sprite2D.new()
	_visual_sprite.name = "RenderedMage"
	_visual_sprite.texture = _viewport.get_texture()
	_visual_sprite.centered = true
	_visual_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_visual_sprite.scale = Vector2(0.82, 0.82)
	_visual_root.add_child(_visual_sprite)

	_visual_ready = true
	_find_best_animation_names()
	_play_visual_animation(_idle_anim)


func _import_animation_libraries(path: String) -> void:
	if _animation_player == null:
		return

	var animation_scene: PackedScene = load(path) as PackedScene
	if animation_scene == null:
		push_warning("Animations KayKit introuvables: " + path)
		return

	var source_root: Node = animation_scene.instantiate()
	var source_player: AnimationPlayer = _find_animation_player(source_root)

	if source_player == null:
		source_root.queue_free()
		push_warning("Aucun AnimationPlayer dans: " + path)
		return

	var library_names: Array[StringName] = source_player.get_animation_library_list()

	for library_name in library_names:
		var source_library: AnimationLibrary = source_player.get_animation_library(library_name)
		if source_library == null:
			continue

		var destination: AnimationLibrary = null

		if _animation_player.has_animation_library(library_name):
			destination = _animation_player.get_animation_library(library_name)
		else:
			destination = AnimationLibrary.new()
			_animation_player.add_animation_library(library_name, destination)

		if destination == null:
			continue

		for animation_name in source_library.get_animation_list():
			var animation: Animation = source_library.get_animation(animation_name)
			if animation != null and not destination.has_animation(animation_name):
				destination.add_animation(animation_name, animation)

	# Animation resources are now owned by the destination player.
	source_root.queue_free()

func _find_best_animation_names() -> void:
	if _animation_player == null:
		return

	var available: Array[StringName] = []
	for animation_name in _animation_player.get_animation_list():
		available.append(StringName(animation_name))

	_idle_anim = _find_animation(available, [
		&"Idle_A",
		&"Idle_B",
		&"Idle",
		&"idle"
	])

	_walk_anim = _find_animation(available, [
		&"Walking_A",
		&"Walking_B",
		&"Walking_C",
		&"Walk_A",
		&"Walk_B",
		&"Walk",
		&"walking",
		&"Walking"
	])

	# Dash gets a real running animation when available.
	if _find_animation(available, [&"Running_A", &"Running_B"]) == StringName():
		# Keep walking as the fallback.
		pass

	if _idle_anim == StringName() and not available.is_empty():
		_idle_anim = available[0]

	if _walk_anim == StringName():
		_walk_anim = _idle_anim

func _find_animation(available: Array[StringName], candidates: Array[StringName]) -> StringName:
	for candidate in candidates:
		if candidate in available:
			return candidate
	return StringName()


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer

	for child in root.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found

	return null


func _play_visual_animation(animation_name: StringName) -> void:
	if not _visual_ready or _animation_player == null or animation_name == StringName():
		return

	if not _animation_player.has_animation(animation_name):
		return

	if _animation_player.current_animation == animation_name and _animation_player.is_playing():
		return

	_animation_player.play(animation_name, 0.10)


func _get_run_animation() -> StringName:
	if _animation_player == null:
		return StringName()

	var available: Array[StringName] = []
	for animation_name in _animation_player.get_animation_list():
		available.append(StringName(animation_name))
	return _find_animation(available, [&"Running_A", &"Running_B"])


func _update_kaykit_visual(delta: float) -> void:
	if not _visual_ready:
		return

	if _model != null:
		var facing_2d: Vector2 = Vector2.RIGHT

		if is_bot and is_instance_valid(target):
			facing_2d = (target.global_position - global_position).normalized()
		elif not is_bot:
			facing_2d = (get_global_mouse_position() - global_position).normalized()

		if facing_2d.length_squared() > 0.001:
			# KayKit Mage faces toward -Z at rotation 0.
			# Map the existing 2D aim vector directly to the 3D ground.
			var desired_angle: float = atan2(-facing_2d.x, -facing_2d.y)
			_model.rotation.y = desired_angle

	var moving: bool = velocity.length() > 55.0

	if dash_left > 0.0:
		var run_anim: StringName = _get_run_animation()
		if run_anim != StringName():
			_play_visual_animation(run_anim)
		else:
			_play_visual_animation(_walk_anim)
	elif moving:
		_play_visual_animation(_walk_anim)
	else:
		_play_visual_animation(_idle_anim)

func _draw() -> void:
	# Keep the 2D gameplay feedback that was useful in the original version.
	var shadow_alpha: float = 0.42 if not is_bot else 0.34
	draw_ellipse_safe(Vector2(0, 18), Vector2(28, 9), Color(0.02, 0.04, 0.08, shadow_alpha))

	var ring_color: Color = team_color
	if flash_time > 0.0:
		ring_color = Color("ffffff")

	draw_arc(Vector2(0, 7), 31.0, 0.0, TAU, 40, Color(ring_color, 0.85), 2.2)

	var health_ratio: float = clampf(float(health) / float(max_health), 0.0, 1.0)
	draw_arc(
		Vector2(0, 7),
		35.0,
		-PI * 0.5,
		-PI * 0.5 + TAU * health_ratio,
		40,
		Color("70f3a0"),
		3.5
	)


func draw_ellipse_safe(center: Vector2, radii: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(20):
		var angle: float = TAU * float(i) / 20.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
