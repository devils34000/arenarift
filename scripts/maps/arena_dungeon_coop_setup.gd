@tool
extends Node3D
## Post-traitement après une génération du Dungeon Crawler 3D : ajoute ce
## que arena_3d.gd attend d'une map (un mesh "Terrain" pour le calcul des
## limites/collision de secours, un nœud "SpawnPoints", un environnement et
## un soleil) autour du donjon généré par le nœud DungeonGenerator3D frère.
##
## Usage dans l'éditeur : sélectionne ce nœud, configure le "Dungeon
## Generator" en dessous avec sa DungeonConfig, coche "Build" dans
## l'Inspecteur ici — ça déclenche la génération PUIS pose Terrain/
## SpawnPoints/environnement une fois les salles posées. Sauvegarde la scène
## ensuite (Ctrl+S) pour figer un donjon fixe, éditable comme le reste des
## maps du projet. Recoche "Build" pour régénérer un autre layout.

@export var generator_path: NodePath = NodePath("../DungeonGenerator3D")

@export var build: bool = false:
	set(value):
		build = false
		if value:
			_start_build()

var _scene_root: Node

func _spawn(parent: Node, node: Node) -> void:
	parent.add_child(node)
	if Engine.is_editor_hint() and _scene_root != null:
		node.owner = _scene_root

func _start_build() -> void:
	var generator := get_node_or_null(generator_path) as DungeonGenerator3D
	if generator == null:
		push_error("ArenaDungeonCoopSetup : DungeonGenerator3D introuvable à %s" % generator_path)
		return

	_scene_root = get_tree().edited_scene_root if Engine.is_editor_hint() else null

	# Nettoie ce qu'on a posé lors d'un build précédent.
	for child in get_children():
		child.queue_free()

	if not generator.generation_completed.is_connected(_on_generation_completed):
		generator.generation_completed.connect(_on_generation_completed, CONNECT_ONE_SHOT)
	if not generator.generation_failed.is_connected(_on_generation_failed):
		generator.generation_failed.connect(_on_generation_failed, CONNECT_ONE_SHOT)

	generator.generate()

func _on_generation_failed(reason: String) -> void:
	push_error("ArenaDungeonCoopSetup : génération du donjon échouée -> %s" % reason)

func _on_generation_completed(_dungeon_root: Node3D) -> void:
	var generator := get_node_or_null(generator_path) as DungeonGenerator3D
	if generator == null or generator.active_graph == null:
		return

	var bounds := AABB()
	var has_bounds := false
	var entrance_pos := Vector3.ZERO
	var boss_pos := Vector3.ZERO
	var has_entrance := false
	var has_boss := false

	for placement in generator.active_graph.placements:
		var origin: Vector3 = (placement.world_transform as Transform3D).origin
		var category: int = placement.category
		var room_aabb := AABB(origin - Vector3(6, 0, 6), Vector3(12, 1, 12))
		if not has_bounds:
			bounds = room_aabb
			has_bounds = true
		else:
			bounds = bounds.merge(room_aabb)

		if category == RoomData.RoomCategory.ENTRANCE and not has_entrance:
			entrance_pos = origin
			has_entrance = true
		elif category == RoomData.RoomCategory.BOSS and not has_boss:
			boss_pos = origin
			has_boss = true

	if not has_bounds:
		return

	_build_terrain(bounds)
	_build_spawn_points(entrance_pos if has_entrance else bounds.get_center(), boss_pos if has_boss else bounds.get_center())
	_build_environment()
	_build_sun()

func _build_terrain(bounds: AABB) -> void:
	# Simple dalle invisible sous tout le donjon : arena_3d.gd cherche un
	# nœud nommé exactement "Terrain" pour calculer les limites de la map et
	# créer une collision de secours (chaque salle a déjà sa propre collision
	# de sol/mur, ce Terrain ne sert qu'au contrat attendu par arena_3d.gd).
	var terrain := MeshInstance3D.new()
	terrain.name = "Terrain"
	var box := BoxMesh.new()
	box.size = Vector3(bounds.size.x, 0.1, bounds.size.z)
	terrain.mesh = box
	terrain.position = Vector3(bounds.get_center().x, bounds.position.y - 0.35, bounds.get_center().z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("2a2420")
	terrain.material_override = mat
	terrain.visible = false
	_spawn(self, terrain)

func _build_spawn_points(entrance_pos: Vector3, boss_pos: Vector3) -> void:
	var spawn_root := Node3D.new()
	spawn_root.name = "SpawnPoints"
	_spawn(self, spawn_root)

	# Mode coop : tout le monde spawn dans la salle d'entrée. On remplit
	# Ally ET Enemy avec les mêmes points pour rester compatible avec
	# _map_spawn_positions() (qui exige les deux groupes non-vides).
	for i in range(4):
		var offset := Vector3(cos(TAU * i / 4.0), 0, sin(TAU * i / 4.0)) * 1.5
		var ally := Marker3D.new()
		ally.name = "Ally_Astral_%02d" % (i + 1)
		ally.position = entrance_pos + offset + Vector3(0, 0.1, 0)
		_spawn(spawn_root, ally)

		var enemy := Marker3D.new()
		enemy.name = "Enemy_Arcane_%02d" % (i + 1)
		enemy.position = entrance_pos + offset + Vector3(0, 0.1, 0)
		_spawn(spawn_root, enemy)

	var objective := Marker3D.new()
	objective.name = "BossRoomMarker"
	objective.position = boss_pos
	_spawn(spawn_root, objective)

func _build_environment() -> void:
	if get_node_or_null("WorldEnvironment") != null:
		return
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0a0806")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("6a5842")
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("3a2f22")
	environment.fog_density = 0.01
	env_node.environment = environment
	_spawn(self, env_node)

func _build_sun() -> void:
	if get_node_or_null("Sun") != null:
		return
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("ffd9a0")
	sun.light_energy = 0.4
	sun.rotation_degrees = Vector3(-70.0, -20.0, 0.0)
	sun.shadow_enabled = true
	_spawn(self, sun)
