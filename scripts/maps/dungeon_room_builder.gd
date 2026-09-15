@tool
extends Node3D
## Salle générique pour le générateur Dungeon Crawler 3D (addons/dungeon_crawler_3d).
## Un seul script "kit de salle" piloté par exports, réutilisé pour toutes les
## variantes (entrée, boss, couloir, jonction, cul-de-sac) — chaque variante
## est une petite .tscn qui instancie ce script avec des valeurs différentes.
##
## Les RoomConnector3D sont placés automatiquement à chaque ouverture de
## porte ; l'algorithme d'alignement du plugin recolle deux salles en se
## basant uniquement sur la transform relative de leurs connecteurs, donc les
## dimensions n'ont pas besoin de correspondre entre types de salles.
##
## @tool : la géométrie se construit à l'ouverture dans l'éditeur (owner
## assigné à la racine de la scène pour être sauvegardée), exactement comme
## le MapBuilder de l'Arène du Colisée.

@export var room_size: Vector2 = Vector2(10.0, 10.0):
	set(value):
		room_size = value
		# is_inside_tree() : évite de reconstruire quand ce setter est appelé
		# par PackedScene.instantiate() au chargement d'une salle déjà
		# "bakée" (nœud encore orphelin à ce moment) — sinon ça duplique la
		# géométrie et assigne un owner à des nœuds pas encore dans l'arbre
		# ("Invalid owner"). Une édition manuelle dans l'Inspecteur sur une
		# salle déjà ouverte dans l'éditeur continue de reconstruire en direct.
		if Engine.is_editor_hint() and is_inside_tree():
			rebuild = true

@export var wall_height: float = 3.4
@export var wall_thickness: float = 0.4
@export var door_width: float = 2.3
@export var door_height: float = 2.6

# Bits : 1=Nord(-Z) 2=Est(+X) 4=Sud(+Z) 8=Ouest(-X)
@export_flags("Nord:1", "Est:2", "Sud:4", "Ouest:8") var doors: int = 15
@export var connection_type: String = "standard_door"
@export var accent_color: Color = Color("8a7a68")
@export var floor_color: Color = Color("6b5c4a")
@export var has_torch: bool = true

@export var rebuild: bool = false:
	set(value):
		rebuild = false
		if value:
			_clear_and_build()

var _scene_root: Node

const SIDE_NORTH := 1
const SIDE_EAST := 2
const SIDE_SOUTH := 4
const SIDE_WEST := 8

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
	_build_floor()
	_build_walls()
	_build_corner_pillars()
	if has_torch:
		_build_torch()

func _spawn(parent: Node, node: Node) -> void:
	parent.add_child(node)
	if Engine.is_editor_hint() and _scene_root != null:
		node.owner = _scene_root

func _build_floor() -> void:
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	var box := BoxMesh.new()
	box.size = Vector3(room_size.x, 0.4, room_size.y)
	floor_mesh.mesh = box
	floor_mesh.position = Vector3(0, -0.2, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = floor_color
	mat.roughness = 0.9
	floor_mesh.material_override = mat
	_spawn(self, floor_mesh)

	var body := StaticBody3D.new()
	body.name = "FloorCollision"
	body.collision_layer = 3
	body.collision_mask = 1
	# body doit être dans l'arbre AVANT qu'on ajoute/owner-assigne collision
	# en dessous, sinon "Invalid owner" (edited_scene_root n'est pas encore
	# ancêtre de collision tant que body est orphelin).
	floor_mesh.add_child(body)
	if Engine.is_editor_hint() and _scene_root != null:
		body.owner = _scene_root
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	collision.shape = shape
	_spawn(body, collision)

func _build_walls() -> void:
	var walls := Node3D.new()
	walls.name = "Walls"
	_spawn(self, walls)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = accent_color
	mat.roughness = 0.88

	_build_wall_side(walls, SIDE_NORTH, mat)
	_build_wall_side(walls, SIDE_EAST, mat)
	_build_wall_side(walls, SIDE_SOUTH, mat)
	_build_wall_side(walls, SIDE_WEST, mat)

## Retourne la position exacte du bord de la salle pour un côté donné (c'est
## LÀ que doit se trouver le RoomConnector3D : les salles voisines se
## touchent à ce point précis, sans le dépasser), plus la direction "vers
## l'intérieur" utilisée pour reculer les murs de leur propre épaisseur.
func _side_info(side: int) -> Dictionary:
	match side:
		SIDE_NORTH:
			return {"length": room_size.x, "boundary": Vector3(0, 0, -room_size.y * 0.5), "inward": Vector3(0, 0, 1), "yaw": 180.0, "horizontal": true}
		SIDE_SOUTH:
			return {"length": room_size.x, "boundary": Vector3(0, 0, room_size.y * 0.5), "inward": Vector3(0, 0, -1), "yaw": 0.0, "horizontal": true}
		SIDE_EAST:
			return {"length": room_size.y, "boundary": Vector3(room_size.x * 0.5, 0, 0), "inward": Vector3(-1, 0, 0), "yaw": 90.0, "horizontal": false}
		_:
			return {"length": room_size.y, "boundary": Vector3(-room_size.x * 0.5, 0, 0), "inward": Vector3(1, 0, 0), "yaw": -90.0, "horizontal": false}

func _build_wall_side(parent: Node3D, side: int, mat: StandardMaterial3D) -> void:
	var info := _side_info(side)
	var length: float = info["length"]
	var boundary: Vector3 = info["boundary"]
	var yaw: float = info["yaw"]
	var horizontal: bool = info["horizontal"]
	var has_door := (doors & side) != 0

	# Le mur est reculé d'une demi-épaisseur vers l'intérieur : sa face
	# extérieure affleure exactement "boundary" sans jamais le dépasser.
	# Sans ça, deux salles voisines se recouvrent légèrement à leur jonction
	# (chaque mur déborde de boundary de sa propre demi-épaisseur) et le
	# générateur rejette la connexion pour "chevauchement".
	var center: Vector3 = boundary + (info["inward"] as Vector3) * (wall_thickness * 0.5)

	if not has_door:
		_add_wall_segment(parent, center, length, horizontal, mat, "Wall_%d" % side)
		return

	var half_gap := door_width * 0.5
	var seg_a_len := length * 0.5 - half_gap
	var seg_b_len := seg_a_len
	if seg_a_len > 0.05:
		var offset := (length * 0.5 + half_gap) * 0.5
		var offset_vec := Vector3(offset, 0, 0) if horizontal else Vector3(0, 0, offset)
		_add_wall_segment(parent, center - offset_vec, seg_a_len, horizontal, mat, "Wall_%d_A" % side)
		_add_wall_segment(parent, center + offset_vec, seg_b_len, horizontal, mat, "Wall_%d_B" % side)

	# Linteau au-dessus de la porte si le mur est plus haut que la porte.
	if wall_height > door_height:
		var lintel_height := wall_height - door_height
		var lintel := MeshInstance3D.new()
		lintel.name = "Lintel_%d" % side
		var box := BoxMesh.new()
		if horizontal:
			box.size = Vector3(door_width, lintel_height, wall_thickness)
		else:
			box.size = Vector3(wall_thickness, lintel_height, door_width)
		lintel.mesh = box
		lintel.position = center + Vector3(0, door_height + lintel_height * 0.5, 0)
		lintel.material_override = mat
		_spawn(parent, lintel)

	# Connecteur exactement sur le bord de la salle (pas sur le mur reculé) :
	# c'est ce point que le générateur fait coïncider avec celui de la salle
	# suivante.
	var connector := Node3D.new()
	connector.set_script(load("res://addons/dungeon_crawler_3d/nodes/room_connector_3d.gd"))
	connector.name = "Connector_%d" % side
	connector.set("connection_type", connection_type)
	connector.set("aperture_width", door_width)
	connector.set("aperture_height", door_height)
	connector.position = boundary
	connector.rotation_degrees.y = yaw
	_spawn(parent, connector)

func _add_wall_segment(parent: Node3D, center: Vector3, length: float, horizontal: bool, mat: StandardMaterial3D, seg_name: String) -> void:
	if length <= 0.02:
		return
	var wall := MeshInstance3D.new()
	wall.name = seg_name
	var box := BoxMesh.new()
	if horizontal:
		box.size = Vector3(length, wall_height, wall_thickness)
	else:
		box.size = Vector3(wall_thickness, wall_height, length)
	wall.mesh = box
	wall.position = center + Vector3(0, wall_height * 0.5, 0)
	wall.material_override = mat
	_spawn(parent, wall)

	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 3
	body.collision_mask = 1
	# Même précaution que dans _build_floor() : body doit être dans l'arbre
	# avant d'y attacher/owner-assigner collision.
	wall.add_child(body)
	if Engine.is_editor_hint() and _scene_root != null:
		body.owner = _scene_root
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	collision.shape = shape
	_spawn(body, collision)

func _build_corner_pillars() -> void:
	var pillars := Node3D.new()
	pillars.name = "Pillars"
	_spawn(self, pillars)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = accent_color.darkened(0.15)
	mat.roughness = 0.85

	# Inset des piliers depuis le coin exact : un pilier de rayon 0.4 posé pile
	# au coin dépasse du mur (qui ne fait que wall_thickness*0.5 de chaque côté
	# de la ligne du mur) — la boîte englobante de la salle devient alors plus
	# grande que son vrai contour, ce qui fait chevaucher les salles voisines
	# aux yeux du détecteur de collision du générateur et bloque toute
	# génération. On recule donc le pilier pour que son bord extérieur
	# affleure exactement le mur, sans le dépasser.
	var pillar_radius := 0.4
	var inset := pillar_radius
	var corners := [
		Vector3(room_size.x * 0.5 - inset, 0, room_size.y * 0.5 - inset),
		Vector3(-room_size.x * 0.5 + inset, 0, room_size.y * 0.5 - inset),
		Vector3(room_size.x * 0.5 - inset, 0, -room_size.y * 0.5 + inset),
		Vector3(-room_size.x * 0.5 + inset, 0, -room_size.y * 0.5 + inset),
	]
	for i in range(corners.size()):
		var pillar := MeshInstance3D.new()
		pillar.name = "Pillar_%d" % i
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.35
		mesh.bottom_radius = 0.4
		mesh.height = wall_height
		mesh.radial_segments = 10
		pillar.mesh = mesh
		pillar.position = corners[i] + Vector3(0, wall_height * 0.5, 0)
		pillar.material_override = mat
		_spawn(pillars, pillar)

func _build_torch() -> void:
	var light := OmniLight3D.new()
	light.name = "Torch"
	light.light_color = Color("ffaa55")
	light.light_energy = 2.0
	light.omni_range = maxf(room_size.x, room_size.y) * 0.8
	light.position = Vector3(0, wall_height * 0.75, 0)
	_spawn(self, light)
