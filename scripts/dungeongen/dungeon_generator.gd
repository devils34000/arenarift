@tool
extends Node3D
class_name DungeonGenerator
## Générateur de donjon "maison" (remplace l'ancien plugin tiers) : assemble
## des blocs construits à la main (voir dungeon_piece.gd) porte contre
## porte, façon donjon procédural à la Diablo. Chemin principal + branches
## latérales optionnelles, avec anti-chevauchement.
##
## Usage : assigne "config", coche "Generate" dans l'Inspecteur. Le résultat
## est posé sous un nœud "Layout" (contenu statique, owner assigné pour être
## sauvegardé avec Ctrl+S — recoche "Generate" pour retirer et refaire).

signal generation_completed(room_count: int)
signal generation_failed(reason: String)

@export var config: DungeonGenConfig

@export var generate_button: bool = false:
	set(value):
		generate_button = false
		if value:
			generate()

@export var clear_button: bool = false:
	set(value):
		clear_button = false
		if value:
			_clear_layout()

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	generation_completed.connect(func(room_count: int) -> void:
		print("Dungeon Generator : génération réussie (%d salles)." % room_count)
	)
	generation_failed.connect(func(reason: String) -> void:
		push_error("Dungeon Generator : échec -> %s" % reason)
	)


class Placement:
	var piece_data: DungeonPieceData
	var category: String
	var world_transform: Transform3D
	var door_local_transforms: Array[Transform3D] = []
	var door_used: Array[bool] = []


var _placements: Array[Placement] = []
var _world_aabbs: Array[AABB] = []

## Cache par PackedScene : évite de ré-instancier (et de re-parcourir tous
## les meshes imbriqués) un même bloc à chaque tentative de placement — un
## bloc a toujours la même géométrie locale et les mêmes portes, donc on ne
## mesure qu'une fois par type de bloc, pas une fois par tentative. Sans ça,
## avec des vrais assets FBX (plus lourds que des boîtes de test), la
## génération peut devenir extrêmement lente (des milliers d'instanciations
## pour une seule génération complète).
var _piece_cache: Dictionary = {}


func generate() -> void:
	print("=== Dungeon Generator : generate() ===")
	if not config:
		generation_failed.emit("Aucune DungeonGenConfig assignée")
		return
	print("  entrance_pool: %d, corridor_pool: %d, room_pool: %d, dead_end_pool: %d, boss_pool: %d" % [
		config.entrance_pool.size(), config.corridor_pool.size(), config.room_pool.size(),
		config.dead_end_pool.size(), config.boss_pool.size()
	])
	if config.entrance_pool.is_empty():
		generation_failed.emit("entrance_pool est vide")
		return
	if config.boss_pool.is_empty():
		generation_failed.emit("boss_pool est vide")
		return
	if config.corridor_pool.is_empty() and config.room_pool.is_empty():
		generation_failed.emit("corridor_pool et room_pool sont vides")
		return

	var base_seed: int = config.random_seed
	if base_seed == 0:
		base_seed = int(Time.get_unix_time_from_system())

	var attempts := 0
	var success := false
	while attempts < config.max_generation_attempts and not success:
		_rng.seed = base_seed + attempts
		attempts += 1
		success = _try_generate()

	if not success:
		generation_failed.emit("Échec après %d tentative(s) — élargis les pools, augmente overlap_margin, ou réduis main_path_length/branch_count" % attempts)
		return

	_bake()
	generation_completed.emit(_placements.size())


func _try_generate() -> bool:
	_placements.clear()
	_world_aabbs.clear()

	var entrance_data := _pick_weighted(config.entrance_pool)
	if not entrance_data or not entrance_data.piece_scene:
		print("  _try_generate: pas de piece_scene valide dans entrance_pool")
		return false
	if not _place_first(entrance_data):
		print("  _try_generate: échec de placement de l'entrée (piece_scene invalide ou sans porte ?)")
		return false

	for step in range(1, config.main_path_length):
		var is_last := step == config.main_path_length - 1
		var pool: Array[DungeonPieceData] = config.boss_pool if is_last else _combined(config.corridor_pool, config.room_pool)
		if not _extend_from(_placements.size() - 1, pool):
			return false

	for _i in range(config.branch_count):
		var attach_idx := _find_branch_attachment()
		if attach_idx < 0:
			continue
		var depth := _rng.randi_range(config.branch_depth_min, config.branch_depth_max)
		_build_branch(attach_idx, depth)

	return true


func _place_first(data: DungeonPieceData) -> bool:
	var info := _get_piece_info(data.piece_scene)
	if info == null or (info.door_local_transforms as Array).is_empty():
		return false

	var p := Placement.new()
	p.piece_data = data
	p.category = info.category
	p.world_transform = Transform3D.IDENTITY
	p.door_local_transforms = info.door_local_transforms
	p.door_used.resize(p.door_local_transforms.size())
	p.door_used.fill(false)

	var aabb := _world_aabb_from_local(info.local_aabb, Transform3D.IDENTITY)

	_placements.append(p)
	_world_aabbs.append(aabb)
	return true


func _extend_from(from_idx: int, pool: Array[DungeonPieceData]) -> bool:
	if pool.is_empty():
		return false

	var from_placement: Placement = _placements[from_idx]
	var from_door_idx := _find_unused_door(from_placement)
	if from_door_idx < 0:
		return false
	var from_door_world := from_placement.world_transform * from_placement.door_local_transforms[from_door_idx]

	var working_pool := pool.duplicate()
	var attempts := 0
	while attempts < config.max_attempts_per_step and not working_pool.is_empty():
		attempts += 1
		var idx := _pick_weighted_index(working_pool)
		if idx < 0:
			break
		var candidate: DungeonPieceData = working_pool[idx]
		working_pool.remove_at(idx)
		if not candidate or not candidate.piece_scene:
			continue

		var info := _get_piece_info(candidate.piece_scene)
		var doors: Array[Transform3D] = info.door_local_transforms
		if doors.is_empty():
			continue

		var door_order := range(doors.size())
		door_order.shuffle()

		var placed := false
		for door_idx in door_order:
			var candidate_local_door: Transform3D = doors[door_idx]
			var world_transform := _align(from_door_world, candidate_local_door)
			var world_aabb := _world_aabb_from_local(info.local_aabb, world_transform)
			if _overlaps(world_aabb):
				continue

			var p := Placement.new()
			p.piece_data = candidate
			p.category = info.category
			p.world_transform = world_transform
			p.door_local_transforms = doors
			p.door_used.resize(doors.size())
			p.door_used.fill(false)
			p.door_used[door_idx] = true

			_placements.append(p)
			_world_aabbs.append(world_aabb)
			from_placement.door_used[from_door_idx] = true
			placed = true
			break

		if placed:
			return true

	return false


func _find_branch_attachment() -> int:
	var candidates: Array[int] = []
	for i in range(_placements.size()):
		if _find_unused_door(_placements[i]) >= 0:
			candidates.append(i)
	if candidates.is_empty():
		return -1
	return candidates[_rng.randi() % candidates.size()]


func _build_branch(attach_idx: int, depth: int) -> void:
	var current_idx := attach_idx
	for i in range(depth):
		var is_last := i == depth - 1
		var pool: Array[DungeonPieceData] = config.dead_end_pool if is_last else _combined(config.corridor_pool, config.room_pool)
		if pool.is_empty() or not _extend_from(current_idx, pool):
			return
		current_idx = _placements.size() - 1


func _find_unused_door(p: Placement) -> int:
	for i in range(p.door_used.size()):
		if not p.door_used[i]:
			return i
	return -1


## Calcule la transform monde à donner au bloc candidat pour que sa porte
## locale "door_b_local" se retrouve exactement face à la porte déjà posée
## "door_a_world" (flip à 180° autour de Y pour que les deux se regardent).
static func _align(door_a_world: Transform3D, door_b_local: Transform3D) -> Transform3D:
	var flip := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	var door_a_flipped := door_a_world * flip
	return door_a_flipped * door_b_local.affine_inverse()


func _door_local_transforms(doors: Array[Marker3D]) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for d in doors:
		out.append(d.transform)
	return out


func _get_doors(inst: Node3D) -> Array[Marker3D]:
	var piece := inst as DungeonPiece
	if piece:
		return piece.get_doors()
	# Bloc sans script DungeonPiece (pas recommandé) : cherche quand même
	# les Marker3D nommés "Door*" pour rester tolérant.
	var doors: Array[Marker3D] = []
	_collect_doors_fallback(inst, doors)
	doors.sort_custom(func(a: Marker3D, b: Marker3D) -> bool: return a.name < b.name)
	return doors


func _collect_doors_fallback(node: Node, out: Array[Marker3D]) -> void:
	for child in node.get_children():
		if child is Marker3D and String(child.name).begins_with("Door"):
			out.append(child)
		_collect_doors_fallback(child, out)


func _get_category(inst: Node3D) -> String:
	var piece := inst as DungeonPiece
	return piece.category if piece else "room"


## Instancie une seule fois par PackedScene distincte, mesure sa géométrie
## locale (AABB) et ses portes, met en cache, et libère l'instance
## immédiatement (elle ne sert qu'à la mesure, jamais gardée en mémoire).
func _get_piece_info(piece_scene: PackedScene) -> Dictionary:
	if _piece_cache.has(piece_scene):
		return _piece_cache[piece_scene]

	var info := {
		"category": "room",
		"local_aabb": AABB(),
		"door_local_transforms": [] as Array[Transform3D],
	}
	var inst := piece_scene.instantiate() as Node3D
	if inst:
		info["category"] = _get_category(inst)
		info["local_aabb"] = _collect_mesh_aabb(inst, Transform3D.IDENTITY, true)
		info["door_local_transforms"] = _door_local_transforms(_get_doors(inst))
		inst.free()

	_piece_cache[piece_scene] = info
	return info


func _world_aabb_from_local(local_aabb: AABB, world_transform: Transform3D) -> AABB:
	var corners := [
		local_aabb.position,
		local_aabb.position + Vector3(local_aabb.size.x, 0, 0),
		local_aabb.position + Vector3(0, local_aabb.size.y, 0),
		local_aabb.position + Vector3(0, 0, local_aabb.size.z),
		local_aabb.position + Vector3(local_aabb.size.x, local_aabb.size.y, 0),
		local_aabb.position + Vector3(local_aabb.size.x, 0, local_aabb.size.z),
		local_aabb.position + Vector3(0, local_aabb.size.y, local_aabb.size.z),
		local_aabb.position + local_aabb.size,
	]
	var world_aabb := AABB(world_transform * corners[0], Vector3.ZERO)
	for i in range(1, corners.size()):
		world_aabb = world_aabb.expand(world_transform * corners[i])
	return world_aabb


func _collect_mesh_aabb(node: Node, parent_transform: Transform3D, is_root: bool) -> AABB:
	var current_transform := parent_transform
	if node is Node3D and not is_root:
		current_transform = parent_transform * (node as Node3D).transform

	var aabb := AABB()
	var first := true

	if node is MeshInstance3D:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh:
			var local_aabb := mesh.get_aabb()
			if local_aabb.has_surface():
				aabb = current_transform * local_aabb
				first = false

	for child in node.get_children():
		var child_aabb := _collect_mesh_aabb(child, current_transform, false)
		if child_aabb.has_surface():
			if first:
				aabb = child_aabb
				first = false
			else:
				aabb = aabb.merge(child_aabb)

	return aabb


func _overlaps(candidate: AABB) -> bool:
	var shrunk := candidate.grow(-config.overlap_margin)
	for existing in _world_aabbs:
		if shrunk.intersects(existing):
			return true
	return false


func _combined(a: Array[DungeonPieceData], b: Array[DungeonPieceData]) -> Array[DungeonPieceData]:
	var out: Array[DungeonPieceData] = a.duplicate()
	out.append_array(b)
	return out


func _pick_weighted(pool: Array[DungeonPieceData]) -> DungeonPieceData:
	var idx := _pick_weighted_index(pool)
	return pool[idx] if idx >= 0 else null


func _pick_weighted_index(pool: Array[DungeonPieceData]) -> int:
	var total := 0.0
	for entry in pool:
		if entry:
			total += maxf(entry.spawn_weight, 0.0)
	if total <= 0.0:
		return -1
	var roll := _rng.randf() * total
	var acc := 0.0
	for i in range(pool.size()):
		var entry: DungeonPieceData = pool[i]
		if not entry:
			continue
		acc += maxf(entry.spawn_weight, 0.0)
		if roll <= acc:
			return i
	return pool.size() - 1


func _clear_layout() -> void:
	var layout := get_node_or_null("Layout")
	if layout:
		layout.queue_free()


func _bake() -> void:
	_clear_layout()

	var layout := Node3D.new()
	layout.name = "Layout"
	add_child(layout)
	if Engine.is_editor_hint():
		layout.owner = get_tree().edited_scene_root

	for i in range(_placements.size()):
		var p: Placement = _placements[i]
		var inst := p.piece_data.piece_scene.instantiate() as Node3D
		if not inst:
			continue
		inst.name = "%s_%d" % [p.category.capitalize(), i]
		inst.transform = p.world_transform
		layout.add_child(inst)
		if Engine.is_editor_hint():
			inst.owner = get_tree().edited_scene_root
