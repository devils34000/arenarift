extends Node3D
class_name RiftMap

const CEMETERY_ROOT := "res://assets/map/cemetery/LowPolyCemeteryTombPack/Meshes/"
const PROPS_ROOT := "res://assets/map/props/Exports/glTF/"

func build(parent: Node3D) -> void:
	var map_root := Node3D.new()
	map_root.name = "RiftNecropolis"
	parent.add_child(map_root)

	_build_lighting(map_root)
	_build_perimeter(map_root)
	_build_cover(map_root)
	_build_props(map_root)
	_build_rift_landmark(map_root)
	_build_spawn_markers(map_root)

func _build_lighting(root: Node3D) -> void:
	var moon := DirectionalLight3D.new()
	moon.name = "MoonLight"
	moon.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	moon.light_color = Color("9ab8e8")
	moon.light_energy = 0.8
	moon.shadow_enabled = true
	root.add_child(moon)

	for data in [
		[Vector3(-11.0, 2.8, 0.0), Color("43aaff")],
		[Vector3(11.0, 2.8, 0.0), Color("a65cff")],
		[Vector3(0.0, 3.0, 0.0), Color("6de8ff")]
	]:
		var light := OmniLight3D.new()
		light.position = data[0]
		light.light_color = data[1]
		light.light_energy = 3.0
		light.omni_range = 8.0
		root.add_child(light)

func _build_perimeter(root: Node3D) -> void:
	# Tomb entrances create the visual identity of the two bases.
	_add_asset(root, CEMETERY_ROOT + "EA_Bld_Tomb_Entrance_Moss_Class_B_01a.fbx", Vector3(-10.8, 0.0, -7.4), Vector3(0.0, 0.0, 0.0), Vector3(1.05, 1.05, 1.05))
	_add_asset(root, CEMETERY_ROOT + "EA_Bld_Tomb_Entrance_Moss_Class_C_01b.fbx", Vector3(10.8, 0.0, 7.4), Vector3(0.0, PI, 0.0), Vector3(1.05, 1.05, 1.05))

	# Broken tombs frame the side lanes without closing them.
	_add_asset(root, CEMETERY_ROOT + "EA_Bld_Tomb_Mossy_Ruined_01a.fbx", Vector3(-11.0, 0.0, 4.8), Vector3(0.0, 0.35, 0.0), Vector3(0.9, 0.9, 0.9))
	_add_asset(root, CEMETERY_ROOT + "EA_Bld_Tomb_Mossy_Ruined_01c.fbx", Vector3(11.0, 0.0, -4.8), Vector3(0.0, -0.25, 0.0), Vector3(0.9, 0.9, 0.9))

	# Low wall segments give cover while preserving ranged sightlines.
	for data in [
		[Vector3(-10.0, 0.0, 0.0), 0.0],
		[Vector3(10.0, 0.0, 0.0), PI],
		[Vector3(-5.5, 0.0, -8.0), 0.0],
		[Vector3(5.5, 0.0, 8.0), PI]
	]:
		_add_asset(root, CEMETERY_ROOT + "EA_Bld_Tomb_Segment_Moss_1a.fbx", data[0], Vector3(0.0, data[1], 0.0), Vector3(1.0, 1.0, 1.0))

	# Collision volumes for perimeter structures.
	_add_box_obstacle(root, Vector3(-10.8, 1.0, -7.4), Vector3(3.8, 2.0, 2.6))
	_add_box_obstacle(root, Vector3(10.8, 1.0, 7.4), Vector3(3.8, 2.0, 2.6))
	_add_box_obstacle(root, Vector3(-11.0, 0.9, 4.8), Vector3(3.2, 1.8, 2.5))
	_add_box_obstacle(root, Vector3(11.0, 0.9, -4.8), Vector3(3.2, 1.8, 2.5))

func _build_cover(root: Node3D) -> void:
	# Symmetric central cover: enough for melee approach, but leaves a clean fight zone.
	var cover_positions := [
		Vector3(-5.2, 0.0, -3.5), Vector3(5.2, 0.0, -3.5),
		Vector3(-5.2, 0.0, 3.5), Vector3(5.2, 0.0, 3.5),
		Vector3(-8.0, 0.0, 0.0), Vector3(8.0, 0.0, 0.0)
	]
	var variants := ["EA_Bld_Tomb_Niche_Mossy_Class_A_01a.fbx", "EA_Bld_Tomb_Niche_Mossy_Class_B_01a.fbx", "EA_Bld_Tomb_Mossy_Ruined_01d.fbx"]
	for i in cover_positions.size():
		var p: Vector3 = cover_positions[i]
		var file: String = variants[i % variants.size()]
		var yaw: float = PI if p.x > 0.0 else 0.0
		_add_asset(root, CEMETERY_ROOT + file, p, Vector3(0.0, yaw, 0.0), Vector3(0.72, 0.72, 0.72))
		_add_box_obstacle(root, p + Vector3(0.0, 0.65, 0.0), Vector3(2.4, 1.3, 1.8))

	# Small tombs on the flanks.
	for p in [Vector3(-13.0, 0.0, -3.5), Vector3(-13.0, 0.0, 3.5), Vector3(13.0, 0.0, -3.5), Vector3(13.0, 0.0, 3.5)]:
		_add_asset(root, CEMETERY_ROOT + "EA_Bld_Tomb_Niche_Clean_Class_C_01a.fbx", p, Vector3.ZERO, Vector3(0.55, 0.55, 0.55))

func _build_props(root: Node3D) -> void:
	# Props from Fantasy Props MegaKit: visual dressing only, kept outside combat lanes.
	var props := [
		["Banner_1.gltf", Vector3(-13.7, 0.0, -7.0), 0.8],
		["Banner_2.gltf", Vector3(13.7, 0.0, 7.0), 0.8],
		["Lantern_Wall.gltf", Vector3(-12.8, 1.5, -6.3), 0.65],
		["Lantern_Wall.gltf", Vector3(12.8, 1.5, 6.3), 0.65],
		["Barrel.gltf", Vector3(-12.7, 0.0, 5.7), 0.65],
		["Barrel.gltf", Vector3(12.7, 0.0, -5.7), 0.65],
		["Chest_Wood.gltf", Vector3(-8.8, 0.0, -7.3), 0.45],
		["Chest_Wood.gltf", Vector3(8.8, 0.0, 7.3), 0.45]
	]
	for item in props:
		_add_asset(root, PROPS_ROOT + str(item[0]), item[1], Vector3.ZERO, Vector3.ONE * float(item[2]))

func _build_rift_landmark(root: Node3D) -> void:
	var crystal := MeshInstance3D.new()
	crystal.name = "RiftCrystal"
	var mesh := PrismMesh.new()
	mesh.size = Vector3(1.2, 3.2, 1.2)
	crystal.mesh = mesh
	crystal.position = Vector3(0.0, 1.6, 0.0)
	crystal.rotation_degrees = Vector3(0.0, 45.0, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("79d9ff")
	mat.emission_enabled = true
	mat.emission = Color("37a9ff")
	mat.emission_energy_multiplier = 4.5
	mat.metallic = 0.15
	mat.roughness = 0.25
	crystal.material_override = mat
	root.add_child(crystal)

	var ring := MeshInstance3D.new()
	ring.name = "RiftRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 1.35
	torus.outer_radius = 1.48
	torus.rings = 48
	torus.ring_segments = 16
	ring.mesh = torus
	ring.position.y = 0.06
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color("5edcff")
	rmat.emission_enabled = true
	rmat.emission = Color("36a9ff")
	rmat.emission_energy_multiplier = 5.0
	ring.material_override = rmat
	root.add_child(ring)

	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 2.0, 0.0)
	light.light_color = Color("45c8ff")
	light.light_energy = 5.0
	light.omni_range = 10.0
	root.add_child(light)

func _build_spawn_markers(root: Node3D) -> void:
	for p in [Vector3(-4.5, 0.02, 6.0), Vector3(0.0, 0.02, 6.0), Vector3(4.5, 0.02, 6.0)]:
		_add_spawn_marker(root, p, Color("43ff9b"))
	for p in [Vector3(-4.5, 0.02, -6.0), Vector3(0.0, 0.02, -6.0), Vector3(4.5, 0.02, -6.0)]:
		_add_spawn_marker(root, p, Color("ff4d68"))

func _add_spawn_marker(root: Node3D, p: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.45
	torus.outer_radius = 0.53
	mesh.mesh = torus
	mesh.position = p
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.35
	mesh.material_override = mat
	root.add_child(mesh)

func _add_asset(root: Node3D, path: String, position: Vector3, rotation: Vector3, scale: Vector3) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var instance := packed.instantiate() as Node3D
	if instance == null:
		return null
	instance.position = position
	instance.rotation = rotation
	instance.scale = scale
	root.add_child(instance)
	return instance

func _add_box_obstacle(root: Node3D, position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "MapObstacle"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.position = position
	body.add_child(collision)
	root.add_child(body)
