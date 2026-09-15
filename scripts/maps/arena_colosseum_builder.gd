@tool
extends Node3D
## Arène "Colisée" — génération procédurale complète (sol circulaire à motif
## radial incrusté, tours périphériques avec braseros, colonnes intérieures,
## éclairage chaud). Ajoutée comme unique enfant d'une scène Arena (racine
## avec le script arena_3d.gd).
##
## Script en @tool : la géométrie se construit directement dans l'éditeur
## (visible sans lancer le jeu) et se sauvegarde comme de vrais nœuds dans
## ArenaColosseum.tscn quand tu enregistres la scène — donc éditable à la
## main ensuite (déplacer une tour, retoucher une couleur, etc.) exactement
## comme le reste des maps du projet.
##
## Pour régénérer depuis zéro (après avoir changé une constante ci-dessous) :
## supprime les enfants de MapBuilder dans l'éditeur, ou coche puis décoche
## "Rebuild" dans l'Inspecteur.

const PLATFORM_RADIUS := 22.0
const PLATFORM_HEIGHT := 1.0
const TOWER_COUNT := 8
const TOWER_RADIUS := PLATFORM_RADIUS - 1.2
const INNER_COLUMN_COUNT := 8
const INNER_COLUMN_RADIUS := PLATFORM_RADIUS - 4.6

const STONE_COLOR := Color("b98a5c")
const STONE_DARK := Color("7a5738")
const INLAY_RED := Color("7a1f1f")
const INLAY_GOLD := Color("d9a441")
const LANTERN_COLOR := Color("ffb04d")

@export var rebuild: bool = false:
	set(value):
		rebuild = false
		if value:
			_clear_and_build()

var _scene_root: Node

func _ready() -> void:
	if get_child_count() > 0:
		return
	_build_all()

func _clear_and_build() -> void:
	for child in get_children():
		child.queue_free()
	call_deferred("_build_all")

func _build_all() -> void:
	_scene_root = get_tree().edited_scene_root if Engine.is_editor_hint() else null
	_build_terrain()
	_build_floor_pattern()
	_build_parapet()
	_build_towers()
	_build_inner_columns()
	_build_spawn_points()
	_build_environment()
	_build_sun()

## Ajoute "node" comme enfant de "parent" et, en édition, l'attribue à la
## racine de la scène pour qu'il soit bien sauvegardé dans le fichier .tscn
## (sans owner, un nœud créé par script disparaît à la sauvegarde).
func _spawn(parent: Node, node: Node) -> void:
	parent.add_child(node)
	if Engine.is_editor_hint() and _scene_root != null:
		node.owner = _scene_root

func _build_terrain() -> void:
	var terrain := MeshInstance3D.new()
	terrain.name = "Terrain"
	var cyl := CylinderMesh.new()
	cyl.top_radius = PLATFORM_RADIUS
	cyl.bottom_radius = PLATFORM_RADIUS
	cyl.height = PLATFORM_HEIGHT
	cyl.radial_segments = 64
	terrain.mesh = cyl
	terrain.position = Vector3(0, -PLATFORM_HEIGHT * 0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = STONE_COLOR
	mat.roughness = 0.85
	terrain.material_override = mat
	_spawn(self, terrain)

func _build_floor_pattern() -> void:
	# Motif radial incrusté (anneaux + rayons + rosace centrale) posé bien à
	# plat sur le sol, en alpha-blend normal (profondeur active) pour rester
	# correctement occulté par les personnages/objets qui marchent dessus.
	var deco := MeshInstance3D.new()
	deco.name = "FloorPattern"
	var quad := QuadMesh.new()
	quad.size = Vector2(PLATFORM_RADIUS * 2.0, PLATFORM_RADIUS * 2.0)
	deco.mesh = quad
	deco.rotation_degrees.x = -90.0
	deco.position = Vector3(0, 0.015, 0)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 inlay_color : source_color = vec4(0.48, 0.12, 0.12, 1.0);
uniform vec4 gold_color : source_color = vec4(0.85, 0.64, 0.25, 1.0);

void fragment() {
	vec2 c = UV - vec2(0.5);
	float r = length(c) * 2.0;
	float theta = atan(c.y, c.x);

	if (r > 1.0) {
		discard;
	}

	// Anneaux concentriques.
	float ring_a = 1.0 - smoothstep(0.0, 0.006, abs(r - 0.97));
	float ring_b = 1.0 - smoothstep(0.0, 0.008, abs(r - 0.60));
	float ring_c = 1.0 - smoothstep(0.0, 0.008, abs(r - 0.28));
	float rings = max(ring_a, max(ring_b, ring_c));

	// Rayons entre l'anneau du milieu et l'anneau extérieur.
	float spoke_count = 16.0;
	float seg = TAU / spoke_count;
	float ang = mod(theta, seg);
	float ang_dist = min(ang, seg - ang) * r;
	float spoke_band = step(0.60, r) * step(r, 0.97);
	float spokes = (1.0 - smoothstep(0.0, 0.012, ang_dist)) * spoke_band;

	// Rosace centrale : étoile à 8 branches par recouvrement de sinusoïdes.
	float star = 0.0;
	if (r < 0.30) {
		float petals = abs(sin(theta * 4.0));
		float star_edge = 0.10 + petals * 0.16;
		star = 1.0 - smoothstep(0.0, 0.015, abs(r - star_edge));
	}

	float mask = max(rings, max(spokes, star));
	ALBEDO = gold_color.rgb * 0.35 + inlay_color.rgb * 0.65;
	EMISSION = gold_color.rgb * 0.5;
	ALPHA = mask * 0.92;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("inlay_color", INLAY_RED)
	mat.set_shader_parameter("gold_color", INLAY_GOLD)
	deco.material_override = mat
	_spawn(self, deco)

func _build_parapet() -> void:
	var parapet := MeshInstance3D.new()
	parapet.name = "Parapet"
	var torus := TorusMesh.new()
	torus.inner_radius = PLATFORM_RADIUS - 0.35
	torus.outer_radius = PLATFORM_RADIUS + 0.35
	torus.rings = 64
	torus.ring_segments = 10
	parapet.mesh = torus
	parapet.position = Vector3(0, 0.22, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = STONE_DARK
	mat.roughness = 0.9
	parapet.material_override = mat
	_spawn(self, parapet)

func _build_towers() -> void:
	var towers := Node3D.new()
	towers.name = "Towers"
	_spawn(self, towers)

	var tower_mat := StandardMaterial3D.new()
	tower_mat.albedo_color = STONE_COLOR
	tower_mat.roughness = 0.8
	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = STONE_DARK
	trim_mat.roughness = 0.85
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = LANTERN_COLOR
	flame_mat.emission_enabled = true
	flame_mat.emission = LANTERN_COLOR
	flame_mat.emission_energy_multiplier = 4.0
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for i in range(TOWER_COUNT):
		var angle := TAU * float(i) / float(TOWER_COUNT)
		var pos := Vector3(cos(angle) * TOWER_RADIUS, 0.0, sin(angle) * TOWER_RADIUS)
		var tower := Node3D.new()
		tower.name = "Tower_%02d" % i
		tower.position = pos
		_spawn(towers, tower)

		var base := MeshInstance3D.new()
		var base_mesh := CylinderMesh.new()
		base_mesh.top_radius = 1.6
		base_mesh.bottom_radius = 1.8
		base_mesh.height = 5.0
		base_mesh.radial_segments = 16
		base.mesh = base_mesh
		base.position.y = 2.5
		base.material_override = tower_mat
		_spawn(tower, base)

		var upper := MeshInstance3D.new()
		var upper_mesh := CylinderMesh.new()
		upper_mesh.top_radius = 1.0
		upper_mesh.bottom_radius = 1.35
		upper_mesh.height = 4.6
		upper_mesh.radial_segments = 16
		upper.mesh = upper_mesh
		upper.position.y = 5.0 + 2.3
		upper.material_override = trim_mat
		_spawn(tower, upper)

		# Vasque au sommet, façon brasero.
		var bowl := MeshInstance3D.new()
		var bowl_mesh := CylinderMesh.new()
		bowl_mesh.top_radius = 1.15
		bowl_mesh.bottom_radius = 0.75
		bowl_mesh.height = 0.9
		bowl_mesh.radial_segments = 16
		bowl.mesh = bowl_mesh
		bowl.position.y = 5.0 + 4.6 + 0.45
		bowl.material_override = tower_mat
		_spawn(tower, bowl)

		# Flamme + lumière chaude.
		var flame_light := OmniLight3D.new()
		flame_light.name = "FlameLight"
		flame_light.light_color = LANTERN_COLOR
		flame_light.light_energy = 2.6
		flame_light.omni_range = 9.0
		flame_light.position.y = 5.0 + 4.6 + 0.9
		_spawn(tower, flame_light)

		var flame_mesh := MeshInstance3D.new()
		flame_mesh.name = "Flame"
		var flame_sphere := SphereMesh.new()
		flame_sphere.radius = 0.32
		flame_sphere.height = 0.64
		flame_mesh.mesh = flame_sphere
		flame_mesh.material_override = flame_mat
		flame_mesh.position.y = 5.0 + 4.6 + 0.75
		_spawn(tower, flame_mesh)

		# Collision : les tours bloquent le passage, comme sur la référence.
		var body := StaticBody3D.new()
		body.name = "TowerCollision"
		body.collision_layer = 3
		body.collision_mask = 1
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var shape := CylinderShape3D.new()
		shape.radius = 1.85
		shape.height = 10.0
		collision.shape = shape
		collision.position.y = 5.0
		_spawn(body, collision)
		_spawn(tower, body)

func _build_inner_columns() -> void:
	var columns := Node3D.new()
	columns.name = "InnerColumns"
	_spawn(self, columns)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = STONE_COLOR.lightened(0.08)
	mat.roughness = 0.75

	for i in range(INNER_COLUMN_COUNT):
		var angle := TAU * float(i) / float(INNER_COLUMN_COUNT) + (TAU / float(INNER_COLUMN_COUNT)) * 0.5
		var pos := Vector3(cos(angle) * INNER_COLUMN_RADIUS, 0.0, sin(angle) * INNER_COLUMN_RADIUS)

		var col := MeshInstance3D.new()
		col.name = "Column_%02d" % i
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.42
		mesh.bottom_radius = 0.5
		mesh.height = 5.4
		mesh.radial_segments = 12
		col.mesh = mesh
		col.position = pos + Vector3(0, 2.7, 0)
		col.material_override = mat
		_spawn(columns, col)

		var lantern_light := OmniLight3D.new()
		lantern_light.name = "Lantern_%02d" % i
		lantern_light.light_color = LANTERN_COLOR
		lantern_light.light_energy = 1.4
		lantern_light.omni_range = 5.0
		lantern_light.position = pos + Vector3(0, 5.5, 0)
		_spawn(columns, lantern_light)

func _build_spawn_points() -> void:
	# Convention attendue par arena_3d.gd::_map_spawn_positions() : un nœud
	# "SpawnPoints" avec des Marker3D nommés Ally_Astral_XX / Enemy_Arcane_XX,
	# de part et d'autre de la plateforme circulaire.
	var spawn_root := Node3D.new()
	spawn_root.name = "SpawnPoints"
	_spawn(self, spawn_root)

	var spawn_radius := PLATFORM_RADIUS * 0.55
	var ally_angles := [200.0, 180.0, 160.0]
	var enemy_angles := [20.0, 0.0, -20.0]

	for i in range(ally_angles.size()):
		var marker := Marker3D.new()
		marker.name = "Ally_Astral_%02d" % (i + 1)
		var a := deg_to_rad(ally_angles[i])
		marker.position = Vector3(cos(a) * spawn_radius, 0.05, sin(a) * spawn_radius)
		_spawn(spawn_root, marker)

	for i in range(enemy_angles.size()):
		var marker := Marker3D.new()
		marker.name = "Enemy_Arcane_%02d" % (i + 1)
		var a := deg_to_rad(enemy_angles[i])
		marker.position = Vector3(cos(a) * spawn_radius, 0.05, sin(a) * spawn_radius)
		_spawn(spawn_root, marker)

func _build_environment() -> void:
	if get_node_or_null("WorldEnvironment") != null:
		return
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("1a0f0a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d99a5c")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("c98a4a")
	environment.fog_density = 0.006
	env_node.environment = environment
	_spawn(self, env_node)

func _build_sun() -> void:
	if get_node_or_null("Sun") != null:
		return
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("ffcf9a")
	sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(-62.0, -35.0, 0.0)
	sun.shadow_enabled = true
	_spawn(self, sun)
