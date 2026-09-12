extends Node3D

const PlayerScene := preload("res://scripts/player_3d.gd")

var player: ArenaPlayer3D
var camera: Camera3D
var world: Node3D
var camera_yaw: float = 0.0
var camera_pitch: float = -0.24
var camera_distance: float = 6.5
var camera_height: float = 2.0
var mouse_sensitivity: float = 0.004
var info_label: Label

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_build_world()
	_spawn_player()
	_build_camera()
	_build_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(3.5, camera_distance - 0.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(12.0, camera_distance + 0.5)
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera_yaw -= event.relative.x * mouse_sensitivity
		camera_pitch = clampf(camera_pitch - event.relative.y * mouse_sensitivity, -0.55, 0.05)

func _process(delta: float) -> void:
	_update_camera(delta)

func _build_world() -> void:
	world = Node3D.new()
	world.name = "World"
	add_child(world)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("07101d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8aa8c9")
	environment.ambient_light_energy = 0.85
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	world.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	world.add_child(sun)

	var floor_body := StaticBody3D.new()
	floor_body.name = "Ground"
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40.0, 0.2, 30.0)
	shape_node.shape = shape
	shape_node.position.y = -0.1
	floor_body.add_child(shape_node)

	var mesh := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(40.0, 0.2, 30.0)
	mesh.mesh = floor_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("263a59")
	mat.roughness = 0.88
	mesh.material_override = mat
	floor_body.add_child(mesh)
	world.add_child(floor_body)

	# Simple 3D landmarks to judge camera movement and depth.
	for p in [Vector3(-10.0, 0.0, -7.0), Vector3(10.0, 0.0, -7.0), Vector3(-10.0, 0.0, 7.0), Vector3(10.0, 0.0, 7.0)]:
		_add_pillar(p)

	for z in range(-12, 13, 2):
		_add_line(Vector3(0.0, 0.012, float(z)), Vector3(40.0, 0.012, 0.025))
	for x in range(-18, 19, 2):
		_add_line(Vector3(float(x), 0.013, 0.0), Vector3(0.025, 0.012, 30.0))

func _add_pillar(pos: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.55
	cylinder.bottom_radius = 0.65
	cylinder.height = 1.8
	mesh.mesh = cylinder
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("41658f")
	mesh.material_override = mat
	mesh.position = pos + Vector3.UP * 0.9
	world.add_child(mesh)

func _add_line(pos: Vector3, size: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("3c5578")
	mesh.material_override = mat
	mesh.position = pos
	world.add_child(mesh)

func _spawn_player() -> void:
	player = PlayerScene.new()
	player.name = "Player"
	player.is_bot = false
	add_child(player)
	player.global_position = Vector3.ZERO
	player.spell_cast.connect(_ignore_spell)

func _ignore_spell(_kind: String, _origin: Vector3, _direction: Vector3, _caster: CharacterBody3D) -> void:
	pass

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "ThirdPersonCamera"
	camera.current = true
	camera.fov = 68.0
	add_child(camera)
	_update_camera(1.0)

func _update_camera(delta: float) -> void:
	if player == null or camera == null:
		return
	var target := player.global_position + Vector3.UP * 1.15
	var behind := Vector3(sin(camera_yaw), 0.0, cos(camera_yaw))
	var desired := target + behind * camera_distance + Vector3.UP * camera_height
	camera.global_position = camera.global_position.lerp(desired, clampf(delta * 14.0, 0.0, 1.0))
	camera.look_at(target, Vector3.UP)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)

	info_label = Label.new()
	info_label.position = Vector2(28, 24)
	info_label.add_theme_font_size_override("font_size", 18)
	info_label.text = "ARENA RIFT — CAMÉRA THIRD PERSON\nWASD : déplacer le Mage\nSouris : tourner la caméra\nMolette : zoom\nÉchap : libérer la souris\n\nTEST : aucun bot / aucun combat"
	layer.add_child(info_label)

	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.position = Vector2(957, 520)
	crosshair.add_theme_font_size_override("font_size", 24)
	layer.add_child(crosshair)
