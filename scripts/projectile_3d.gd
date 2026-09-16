class_name ArenaProjectile3D
extends Area3D

signal hit(target: CharacterBody3D, orb: Area3D)

var velocity: Vector3 = Vector3.ZERO
var owner_player: CharacterBody3D
var lifetime: float = 2.0
var damage: int = 18
var spirit_color: Color = Color("79e8ff")

func _ready() -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = "OrbMesh"

	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	mesh.mesh = sphere

	var material := StandardMaterial3D.new()
	material.albedo_color = spirit_color.lightened(0.35)
	material.emission_enabled = true
	material.emission = spirit_color
	material.emission_energy_multiplier = 4.0
	mesh.material_override = material
	add_child(mesh)

	var light := OmniLight3D.new()
	light.light_color = spirit_color
	light.light_energy = 2.8
	light.omni_range = 2.4
	add_child(light)

func _physics_process(delta: float) -> void:
	var previous_position: Vector3 = global_position
	var next_position: Vector3 = previous_position + velocity * delta

	# Raycast continu entre l'ancienne et la nouvelle position.
	# On utilise TOUS les layers physiques pour détecter les collisions
	# existantes de la map, sans modifier les collisions des bâtiments.
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(previous_position, next_position)
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var excluded: Array[RID] = [get_rid()]
	if owner_player != null and is_instance_valid(owner_player):
		excluded.append(owner_player.get_rid())
	query.exclude = excluded

	var collision: Dictionary = space_state.intersect_ray(query)
	if not collision.is_empty():
		var collider: Object = collision.get("collider") as Object
		var fighter: CharacterBody3D = collider as CharacterBody3D
		if fighter != null and fighter != owner_player and is_instance_valid(fighter):
			global_position = collision.get("position", next_position) as Vector3
			hit.emit(fighter, self)
			# La copie visuelle diffusée aux autres clients (arena_3d.gd,
			# _network_client_spell_visual) ne connecte jamais ce signal —
			# sans ce queue_free, ce projectile continuait donc d'exister,
			# figé sur la cible, jusqu'à expiration de sa durée de vie.
			queue_free()
			return

		# Tout autre PhysicsBody3D est considéré comme décor/obstacle.
		# Le projectile s'arrête immédiatement sur sa collision existante.
		global_position = collision.get("position", next_position) as Vector3
		queue_free()
		return

	global_position = next_position
	lifetime -= delta

	# Conservation du comportement historique des wards.
	var arena: Node = get_parent().get_parent()
	if arena != null and arena.has_method("blocks_projectile"):
		if arena.blocks_projectile(global_position):
			queue_free()
			return

	# Fallback de proximité pour les fighters si leur collision n'est pas
	# disponible au moment précis du raycast. Ce filet de sécurité ignorait
	# les murs (juste une distance XZ) : un monstre de l'autre côté d'une
	# cloison fine pouvait donc quand même toucher, la distance à vol
	# d'oiseau restant sous le seuil. On revérifie donc qu'aucun mur ne
	# sépare réellement le projectile de la cible avant de valider le coup.
	for body_node in get_tree().get_nodes_in_group("fighters"):
		var fighter: CharacterBody3D = body_node as CharacterBody3D
		if fighter == null or fighter == owner_player or not is_instance_valid(fighter):
			continue

		var dx: float = fighter.global_position.x - global_position.x
		var dz: float = fighter.global_position.z - global_position.z
		if Vector2(dx, dz).length() < 0.85:
			var wall_query := PhysicsRayQueryParameters3D.create(global_position, fighter.global_position + Vector3.UP * 0.9)
			wall_query.collision_mask = 2
			wall_query.collide_with_bodies = true
			wall_query.collide_with_areas = false
			if not space_state.intersect_ray(wall_query).is_empty():
				continue
			hit.emit(fighter, self)
			queue_free()
			return

	if lifetime <= 0.0:
		queue_free()
