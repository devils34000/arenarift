class_name ArenaVFXManager
extends Node3D


# Maylinh — vrais VFX du pack Elemental Magic FX (version verte).
const MAYLINH_ELEMENTAL_PROJECTILE_VFX: PackedScene = preload("res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/projectile/vfx_fire_projectile_01.tscn")
const MAYLINH_ELEMENTAL_AREA_VFX: PackedScene = preload("res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/area/vfx_fire_area_01.tscn")
const EREN_EXPLOSION_GROUND_VFX: PackedScene = preload("res://assets/BinbunVFX_Vol2/ExplosionFX/effects/ground/vfx_ground_explosion_01.tscn")
const EREN_EXPLOSION_AIR_VFX: PackedScene = preload("res://assets/BinbunVFX_Vol2/ExplosionFX/effects/air/vfx_air_explosion_01.tscn")
const EREN_EXPLOSION_NUKE_VFX: PackedScene = preload("res://assets/BinbunVFX_Vol2/ExplosionFX/effects/nuke/vfx_nuke_explosion_01.tscn")
const EREN_FIRE_PROJECTILE_VFX: PackedScene = preload("res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/projectile/vfx_fire_projectile_01.tscn")
const EREN_FIRE_AREA_VFX: PackedScene = preload("res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/area/vfx_fire_area_01.tscn")
const EREN_FIRE_CAST_VFX: PackedScene = preload("res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/cast/vfx_fire_cast_01.tscn")
const EREN_BIG_IMPACT_VFX: PackedScene = preload("res://assets/BinbunVFX_Vol2/StylizedHitFX/effects/big_impact/vfx_big_impact_01.tscn")

# Pack Binbun générique — réutilisé pour toutes les autres compétences (Aeris, Kaithlyn,
# Maylinh, coups génériques) afin qu'elles aient le même niveau de finition que le feu d'Eren.
const BATTLE_CHARGE_VFX: PackedScene = preload("res://assets/BinbunVFX_Vol2/BattleFX/effects/charge/vfx_blank_charge.tscn")
const BATTLE_SHIELD_VFX: PackedScene = preload("res://assets/BinbunVFX_Vol2/BattleFX/effects/shield/vfx_blank_shield_01.tscn")
const BATTLE_SLASH_VFX: PackedScene = preload("res://assets/BinbunVFX_Vol2/BattleFX/effects/slash/vfx_blank_slash.tscn")
const BATTLE_SWING_VFX: PackedScene = preload("res://assets/BinbunVFX_Vol2/BattleFX/effects/swing/vfx_blank_swing.tscn")
const HIT_01_VFX: PackedScene = preload("res://assets/BinbunVFX_Vol2/StylizedHitFX/effects/hit/vfx_hit_01.tscn")
const HIT_02_VFX: PackedScene = preload("res://assets/BinbunVFX_Vol2/StylizedHitFX/effects/hit/vfx_hit_02.tscn")
const IMPACT_01_VFX: PackedScene = preload("res://assets/BinbunVFX_Vol2/StylizedHitFX/effects/impact/vfx_impact_01.tscn")
const IMPACT_02_VFX: PackedScene = preload("res://assets/BinbunVFX_Vol2/StylizedHitFX/effects/impact/vfx_impact_02.tscn")
const BIG_IMPACT_02_VFX: PackedScene = preload("res://assets/BinbunVFX_Vol2/StylizedHitFX/effects/big_impact/vfx_big_impact_02.tscn")
const ELEMENTAL_CAST_VFX: PackedScene = preload("res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/cast/vfx_fire_cast_01.tscn")
const ELEMENTAL_AREA_VFX: PackedScene = preload("res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/area/vfx_fire_area_01.tscn")

# Palettes par personnage — mêmes teintes que l'ancien rendu procédural, appliquées aux vrais VFX.
const MAYLINH_PRIMARY := Color("c45cff")
const MAYLINH_SECONDARY := Color("f2b6ff")
const COMBAT_PRIMARY := Color("ff9d2e")
const COMBAT_SECONDARY := Color("ffe8b0")
const COMBAT_TERTIARY := Color("ffb52e")
const DAMAGE_PRIMARY := Color("ff3b30")
const DAMAGE_SECONDARY := Color("ffb0a8")

# Palette glace pour Aeris — ses sorts (orbe, dash, téléportation) sont 100% distincts
# des autres héros : mailles/particules procédurales dédiées, pas du recolorage de VFX feu.
const ICE_CORE := Color("d8fbff")
const ICE_PRIMARY := Color("9fe9ff")
const ICE_SECONDARY := Color("eafeff")
const ICE_DEEP := Color("4fb8e0")

# Fumée de téléportation Maylinh (violet-gris, façon "poof" de ninja).
const SMOKE_LIGHT := Color("9a86a8")
const SMOKE_DARK := Color("2c2233")

# Zone de soin Maylinh — halo/pluie/fumée verte.
const HEAL_PRIMARY := Color("53f2a0")
const HEAL_SECONDARY := Color("c9ffdf")
const HEAL_SMOKE := Color("4fae7c")

var eren_trail_vfx_clock: float = 0.0

func spawn_teleport_start(parent: Node, position: Vector3, scale_value: float = 0.85) -> Node3D:
	_spawn_ice_vortex_charge(parent, position, scale_value)
	return _spawn_tinted(parent, BATTLE_CHARGE_VFX, position, Vector3.ZERO, scale_value, 0.55, ICE_PRIMARY, ICE_SECONDARY, ICE_DEEP, 3.6, 5.0)

func spawn_teleport_end(parent: Node, position: Vector3, scale_value: float = 0.85) -> Node3D:
	_spawn_ice_nova_burst(parent, position, scale_value)
	_camera_impact_punch(parent)
	return _spawn_tinted(parent, IMPACT_01_VFX, position, Vector3.ZERO, scale_value * 0.9, 0.4, ICE_PRIMARY, ICE_SECONDARY, Color(0, 0, 0, 0), 3.2, 5.0)

func _camera_impact_punch(parent: Node) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var viewport := parent.get_viewport()
	if viewport == null:
		return
	var cam := viewport.get_camera_3d()
	if cam == null:
		return
	var base_fov := cam.fov
	var tween := cam.create_tween()
	tween.tween_property(cam, "fov", base_fov - 6.0, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(cam, "fov", base_fov, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _spawn_ice_vortex_charge(parent: Node, position: Vector3, scale_value: float = 1.0) -> void:
	if parent == null:
		return
	var s := scale_value * 1.8
	var root := Node3D.new()
	root.name = "IceVortexChargeFX"
	parent.add_child(root)
	root.global_position = position

	# Deux anneaux de particules à des rayons différents, en orbite rapide,
	# pour un vortex qui se referme visiblement avant la téléportation.
	for ring_i in range(2):
		var ring_particles := GPUParticles3D.new()
		ring_particles.amount = 90
		ring_particles.lifetime = 0.5
		ring_particles.one_shot = true
		ring_particles.emitting = true
		ring_particles.explosiveness = 0.2
		ring_particles.draw_pass_1 = _ice_sparkle_mesh()
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3.UP
		pm.emission_ring_radius = (1.6 - ring_i * 0.5) * s
		pm.emission_ring_inner_radius = (1.35 - ring_i * 0.5) * s
		pm.emission_ring_height = 0.0
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 8.0
		pm.initial_velocity_min = 0.5
		pm.initial_velocity_max = 1.4
		pm.orbit_velocity_min = 2.0 + ring_i * 1.2
		pm.orbit_velocity_max = 3.2 + ring_i * 1.4
		pm.gravity = Vector3(0, 1.2, 0)
		pm.scale_min = 0.6
		pm.scale_max = 1.5
		pm.color = ICE_SECONDARY if ring_i == 0 else ICE_CORE
		ring_particles.process_material = pm
		root.add_child(ring_particles)

	var light := OmniLight3D.new()
	light.light_color = ICE_PRIMARY
	light.light_energy = 0.0
	light.omni_range = 5.5 * s
	root.add_child(light)
	var light_tween := root.create_tween()
	light_tween.tween_property(light, "light_energy", 10.0, 0.18)
	light_tween.tween_property(light, "light_energy", 0.0, 0.35)

	get_tree().create_timer(0.8).timeout.connect(func():
		if is_instance_valid(root):
			root.queue_free()
	)

func _spawn_ice_nova_burst(parent: Node, position: Vector3, scale_value: float = 1.0) -> void:
	if parent == null:
		return
	# On gonfle nettement l'échelle réelle par rapport au paramètre reçu :
	# à scale_value=1 on veut un impact qui domine largement la silhouette du héros.
	var s := scale_value * 2.4
	var root := Node3D.new()
	root.name = "IceNovaBurstFX"
	parent.add_child(root)
	root.global_position = position

	# Flash lumineux central — le vrai coup d'œil "impact".
	var light := OmniLight3D.new()
	light.light_color = ICE_CORE
	light.light_energy = 0.0
	light.omni_range = 11.0 * s
	root.add_child(light)
	var light_tween := root.create_tween()
	light_tween.tween_property(light, "light_energy", 26.0, 0.05)
	light_tween.tween_property(light, "light_energy", 4.0, 0.25)
	light_tween.tween_property(light, "light_energy", 0.0, 0.35)

	# Colonne de glace qui jaillit du sol et explose vers le haut.
	_spawn_ice_pillar(root, s)

	# Nuage de givre semi-transparent qui gonfle et se dissipe.
	var mist := MeshInstance3D.new()
	var mist_sphere := SphereMesh.new()
	mist_sphere.radius = 0.4 * s
	mist_sphere.height = 0.8 * s
	mist.mesh = mist_sphere
	var mist_mat := StandardMaterial3D.new()
	mist_mat.albedo_color = Color(ICE_SECONDARY.r, ICE_SECONDARY.g, ICE_SECONDARY.b, 0.4)
	mist_mat.emission_enabled = true
	mist_mat.emission = ICE_PRIMARY
	mist_mat.emission_energy_multiplier = 2.0
	mist_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mist.material_override = mist_mat
	root.add_child(mist)
	var mist_tween := root.create_tween()
	mist_tween.set_parallel(true)
	mist_tween.tween_property(mist, "scale", Vector3.ONE * 9.0 * s, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	mist_tween.tween_property(mist_mat, "albedo_color:a", 0.0, 1.0)
	mist_tween.set_parallel(false)

	# Triple onde de choc glacée au sol — trois vagues décalées, la dernière très large.
	for ring_i in range(3):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.08 * s
		torus.outer_radius = (0.16 + ring_i * 0.08) * s
		torus.rings = 32
		torus.ring_segments = 12
		ring.mesh = torus
		ring.rotation_degrees.x = 90.0
		ring.position.y = 0.03
		var ring_mat := StandardMaterial3D.new()
		ring_mat.albedo_color = Color(ICE_SECONDARY.r, ICE_SECONDARY.g, ICE_SECONDARY.b, 0.9)
		ring_mat.emission_enabled = true
		ring_mat.emission = ICE_PRIMARY
		ring_mat.emission_energy_multiplier = 8.0
		ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = ring_mat
		root.add_child(ring)
		var ring_tween := root.create_tween()
		ring_tween.set_parallel(true)
		ring_tween.tween_property(ring, "scale", Vector3.ONE * (6.0 + ring_i * 4.0) * s, 0.6 + ring_i * 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(ring_i * 0.1)
		ring_tween.tween_property(ring_mat, "albedo_color:a", 0.0, 0.55).set_delay(ring_i * 0.1)

	_spawn_ice_frost_decal(root, s)

	# Grosse gerbe de particules — le vrai moment "Niagara".
	var burst := GPUParticles3D.new()
	burst.amount = 320
	burst.lifetime = 1.05
	burst.one_shot = true
	burst.emitting = true
	burst.explosiveness = 0.95
	burst.draw_pass_1 = _ice_sparkle_mesh()
	var burst_pm := ParticleProcessMaterial.new()
	burst_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	burst_pm.emission_sphere_radius = 0.2 * s
	burst_pm.direction = Vector3(0, 1, 0)
	burst_pm.spread = 180.0
	burst_pm.initial_velocity_min = 2.6 * s
	burst_pm.initial_velocity_max = 7.5 * s
	burst_pm.gravity = Vector3(0, -3.2, 0)
	burst_pm.damping_min = 1.2
	burst_pm.damping_max = 2.6
	burst_pm.scale_min = 0.6
	burst_pm.scale_max = 1.8
	burst_pm.color = ICE_SECONDARY
	burst.process_material = burst_pm
	root.add_child(burst)

	# Deuxième souffle décalé — un second temps qui relance l'attention.
	get_tree().create_timer(0.22).timeout.connect(func():
		if not is_instance_valid(root):
			return
		var burst2 := GPUParticles3D.new()
		burst2.amount = 140
		burst2.lifetime = 0.75
		burst2.one_shot = true
		burst2.emitting = true
		burst2.explosiveness = 1.0
		burst2.draw_pass_1 = _ice_sparkle_mesh()
		var pm2 := ParticleProcessMaterial.new()
		pm2.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm2.emission_sphere_radius = 0.3 * s
		pm2.direction = Vector3(0, 1, 0)
		pm2.spread = 90.0
		pm2.initial_velocity_min = 1.8 * s
		pm2.initial_velocity_max = 4.2 * s
		pm2.gravity = Vector3(0, -4.0, 0)
		pm2.scale_min = 0.5
		pm2.scale_max = 1.3
		pm2.color = ICE_CORE
		burst2.process_material = pm2
		root.add_child(burst2)
	)

	# Grands éclats de glace qui explosent dans toutes les directions puis retombent.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var shard_count := 26
	for i in range(shard_count):
		var shard := MeshInstance3D.new()
		var box := BoxMesh.new()
		var size_variant := rng.randf_range(0.8, 2.1)
		box.size = Vector3(0.08, 0.42, 0.08) * size_variant * s
		shard.mesh = box
		var shard_mat := StandardMaterial3D.new()
		shard_mat.albedo_color = Color(ICE_SECONDARY.r, ICE_SECONDARY.g, ICE_SECONDARY.b, 0.95)
		shard_mat.emission_enabled = true
		shard_mat.emission = ICE_PRIMARY
		shard_mat.emission_energy_multiplier = 9.0
		shard_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shard_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shard.material_override = shard_mat
		var azimuth := TAU * float(i) / float(shard_count) + rng.randf_range(-0.25, 0.25)
		var elevation := rng.randf_range(deg_to_rad(15.0), deg_to_rad(80.0))
		var dir := Vector3(cos(azimuth) * cos(elevation), sin(elevation), sin(azimuth) * cos(elevation))
		shard.position = dir * 0.1
		shard.rotation_degrees = Vector3(rng.randf_range(0, 360), rad_to_deg(azimuth), rng.randf_range(0, 360))
		root.add_child(shard)
		var dest := dir * rng.randf_range(2.2, 4.2) * s
		var shard_tween := root.create_tween()
		shard_tween.set_parallel(true)
		shard_tween.tween_property(shard, "position", dest, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		shard_tween.tween_property(shard, "position:y", dest.y - 1.1 * s, 0.5).set_delay(0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		shard_tween.tween_property(shard, "scale", Vector3.ZERO, 0.4).set_delay(0.5)
		shard_tween.tween_property(shard_mat, "albedo_color:a", 0.0, 0.4).set_delay(0.5)

	get_tree().create_timer(1.6).timeout.connect(func():
		if is_instance_valid(root):
			root.queue_free()
	)

func _spawn_ice_pillar(parent: Node, s: float) -> void:
	var pillar := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.02 * s
	cylinder.bottom_radius = 0.5 * s
	cylinder.height = 1.0
	cylinder.radial_segments = 6
	pillar.mesh = cylinder
	pillar.position.y = 0.0
	pillar.scale = Vector3(1.0, 0.01, 1.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(ICE_CORE.r, ICE_CORE.g, ICE_CORE.b, 0.85)
	mat.emission_enabled = true
	mat.emission = ICE_PRIMARY
	mat.emission_energy_multiplier = 7.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pillar.material_override = mat
	parent.add_child(pillar)
	var height := 4.2 * s
	var tween := pillar.create_tween()
	tween.tween_property(pillar, "scale", Vector3(1.0, height, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tween.parallel().tween_property(pillar, "scale:y", height * 1.15, 0.35)
	tween.tween_callback(pillar.queue_free)

func _spawn_ice_frost_decal(parent: Node, scale_value: float = 1.0) -> void:
	var decal := MeshInstance3D.new()
	decal.name = "IceFrostDecal"
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2.2, 2.2) * scale_value
	decal.mesh = mesh
	decal.rotation_degrees.x = -90.0
	decal.position.y = 0.02
	decal.scale = Vector3.ONE * 0.2
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, depth_test_disabled;

uniform vec4 tint : source_color = vec4(0.6, 0.95, 1.0, 1.0);
uniform float alpha_factor = 1.0;

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float edge = 1.0 - smoothstep(0.55, 1.0, d);
	float core = 1.0 - smoothstep(0.0, 0.5, d);
	float mask = max(edge * 0.6, core * 0.25);
	ALBEDO = tint.rgb;
	EMISSION = tint.rgb * 2.0;
	ALPHA = mask * alpha_factor;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tint", ICE_PRIMARY)
	mat.set_shader_parameter("alpha_factor", 1.0)
	decal.material_override = mat
	parent.add_child(decal)
	var tween := decal.create_tween()
	tween.tween_property(decal, "scale", Vector3.ONE * 1.6, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(mat, "shader_parameter/alpha_factor", 0.0, 0.5).set_delay(0.15)

func spawn_eren_fire_projectile(projectile: Node3D, direction: Vector3) -> Node3D:
	if projectile == null or EREN_FIRE_PROJECTILE_VFX == null:
		return null
	var fx := EREN_FIRE_PROJECTILE_VFX.instantiate() as Node3D
	if fx == null:
		return null
	projectile.add_child(fx)
	fx.position = Vector3.ZERO
	fx.scale = Vector3.ONE * 1.15
	if direction.length_squared() > 0.001:
		var d := direction.normalized()
		fx.rotation.y = atan2(d.x, d.z)
	# On conserve volontairement les couleurs, shaders et proportions du pack.
	fx.set("emission", 3.0)
	fx.set("light_energy", 6.0)
	return fx

func spawn_eren_fire_cast(parent: Node, position: Vector3, direction: Vector3, scale_value: float = 1.0) -> Node3D:
	return _spawn_eren_pack_fx(parent, EREN_FIRE_CAST_VFX, position + Vector3.UP * 0.08, direction, 1.15 * scale_value, 1.0)

func _spawn_eren_pack_fx(parent: Node, scene: PackedScene, position: Vector3, direction: Vector3, scale_value: float, lifetime: float) -> Node3D:
	if parent == null or scene == null:
		return null
	var fx := scene.instantiate() as Node3D
	if fx == null:
		return null
	parent.add_child(fx)
	fx.global_position = position
	fx.scale = Vector3.ONE * scale_value
	if direction.length_squared() > 0.001:
		var d := direction.normalized()
		fx.rotation.y = atan2(d.x, d.z)
	get_tree().create_timer(lifetime).timeout.connect(func():
		if is_instance_valid(fx):
			fx.queue_free()
	)
	return fx

func _configure_eren_fire_area(fx: Node3D, radius: float, emission: float = 3.0, lifetime: float = 1.15) -> void:
	if fx == null:
		return
	fx.set("area_radius", radius)
	fx.set("emission", emission)
	fx.set("lifetime", lifetime)
	fx.set("particles_amount", 64)
	# Couleurs natives du pack Elemental Magic FX : aucune recoloration artificielle.

func spawn_eren_fire_nova(parent: Node, position: Vector3, scale_value: float = 1.0, empowered: bool = false) -> Node3D:
	if parent == null:
		return null
	var fx: Node3D = null
	if empowered and EREN_EXPLOSION_NUKE_VFX != null:
		fx = _spawn_eren_pack_fx(parent, EREN_EXPLOSION_NUKE_VFX, position + Vector3.UP * 0.04, Vector3.ZERO, 0.72 * scale_value, 4.4)
	else:
		fx = _spawn_eren_pack_fx(parent, EREN_EXPLOSION_GROUND_VFX, position + Vector3.UP * 0.04, Vector3.ZERO, 1.25 * scale_value, 2.8)

	var fire := EREN_FIRE_AREA_VFX.instantiate() as Node3D
	if fire != null:
		parent.add_child(fire)
		fire.global_position = position + Vector3.UP * 0.025
		_configure_eren_fire_area(fire, 2.9 * scale_value, 3.2 if not empowered else 4.0, 1.25)
		fire.scale = Vector3.ONE
		get_tree().create_timer(1.3).timeout.connect(func():
			if is_instance_valid(fire):
				fire.queue_free()
		)
	return fx if fx != null else fire

func spawn_eren_fire_impact(parent: Node, position: Vector3, scale_value: float = 0.65) -> Node3D:
	var explosion := _spawn_eren_pack_fx(parent, EREN_EXPLOSION_AIR_VFX, position + Vector3.UP * 0.12, Vector3.ZERO, 0.75 * scale_value, 2.4)
	var impact := _spawn_eren_pack_fx(parent, EREN_BIG_IMPACT_VFX, position + Vector3.UP * 0.1, Vector3.ZERO, 0.85 * scale_value, 0.9)
	if impact != null:
		impact.set("primary_color", Color("ff9a24"))
		impact.set("secondary_color", Color("ff3b08"))
		impact.set("emission", 2.5)
		impact.set("light_color", Color("ff5a12"))
		impact.set("light_energy", 5.0)
	return explosion if explosion != null else impact

func spawn_eren_fire_trail(parent: Node, position: Vector3, direction: Vector3) -> Node3D:
	# La traînée utilise le vrai Fire Area du pack, allongé dans le sens de la charge.
	if parent == null or EREN_FIRE_AREA_VFX == null:
		return null
	if eren_trail_vfx_clock > 0.0:
		eren_trail_vfx_clock = maxf(0.0, eren_trail_vfx_clock - 0.055)
		return null
	eren_trail_vfx_clock = 0.09
	var fire := EREN_FIRE_AREA_VFX.instantiate() as Node3D
	if fire == null:
		return null
	parent.add_child(fire)
	fire.global_position = position + Vector3.UP * 0.025
	_configure_eren_fire_area(fire, 1.05, 3.4, 1.1)
	var d := direction.normalized()
	if d.length_squared() > 0.001:
		fire.rotation.y = atan2(d.x, d.z)
		fire.scale = Vector3(1.0, 1.0, 1.55)
	get_tree().create_timer(1.2).timeout.connect(func():
		if is_instance_valid(fire):
			fire.queue_free()
	)
	return fire

func spawn_eren_charge_burst(parent: Node, position: Vector3, direction: Vector3) -> Node3D:
	# Départ : vraie gerbe de feu du pack + explosion au sol du pack.
	spawn_eren_fire_cast(parent, position + Vector3.UP * 0.05, direction, 1.35)
	var fire := EREN_FIRE_AREA_VFX.instantiate() as Node3D
	if fire != null:
		parent.add_child(fire)
		fire.global_position = position + Vector3.UP * 0.03
		_configure_eren_fire_area(fire, 1.35, 4.0, 1.25)
		fire.scale = Vector3(1.0, 1.0, 1.3)
		get_tree().create_timer(1.3).timeout.connect(func():
			if is_instance_valid(fire):
				fire.queue_free()
		)
	return _spawn_eren_pack_fx(parent, EREN_EXPLOSION_GROUND_VFX, position + Vector3.UP * 0.04, Vector3.ZERO, 0.9, 2.8)

func spawn_maylinh_elemental_projectile(projectile: Node3D, direction: Vector3) -> Node3D:
	if projectile == null or MAYLINH_ELEMENTAL_PROJECTILE_VFX == null:
		return null
	var fx := MAYLINH_ELEMENTAL_PROJECTILE_VFX.instantiate() as Node3D
	if fx == null:
		return null
	projectile.add_child(fx)
	fx.position = Vector3.ZERO
	fx.scale = Vector3.ONE * 0.95
	if direction.length_squared() > 0.001:
		var d := direction.normalized()
		fx.rotation.y = atan2(d.x, d.z)
	# Même VFX Elemental Magic validé pour Maylinh, avec sa teinte verte.
	fx.set("primary_color", Color("b8ff45"))
	fx.set("secondary_color", Color("55ff2e"))
	fx.set("tertiary_color", Color("0d7a35"))
	fx.set("emission", 3.5)
	return fx

func spawn_maylinh_elemental_heal(parent: Node, position: Vector3, radius: float = 7.5) -> Node3D:
	if parent == null:
		return null

	# Garde-fou : si jamais le rayon reçu est invalide/nul, on garde une zone lisible.
	var r := radius if radius > 0.5 else 3.5
	var duration := 2.0
	var root := Node3D.new()
	root.name = "MaylinhHealZoneFX"
	parent.add_child(root)
	root.global_position = position + Vector3.UP * 0.02

	# Halo vert autour de la zone (contour posé au sol) — taille finale dès le
	# premier instant, seule l'intensité pulse pour ne jamais paraître "coincé" petit.
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(HEAL_PRIMARY.r, HEAL_PRIMARY.g, HEAL_PRIMARY.b, 0.95)
	ring_mat.emission_enabled = true
	ring_mat.emission = HEAL_PRIMARY
	ring_mat.emission_energy_multiplier = 3.0
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(r - 0.3, 0.05)
	torus.outer_radius = r
	torus.rings = 64
	torus.ring_segments = 12
	ring.mesh = torus
	ring.rotation_degrees.x = 90.0
	ring.material_override = ring_mat
	ring.position.y = 0.03
	root.add_child(ring)
	var ring_tween := root.create_tween()
	ring_tween.tween_property(ring_mat, "emission_energy_multiplier", 9.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring_mat, "emission_energy_multiplier", 5.0, 0.4)
	ring_tween.tween_interval(duration - 1.0)
	ring_tween.tween_property(ring_mat, "albedo_color:a", 0.0, 0.5)
	ring_tween.parallel().tween_property(ring_mat, "emission_energy_multiplier", 0.0, 0.5)

	# Pluie verte qui tombe dans toute la zone.
	var rain := GPUParticles3D.new()
	rain.amount = 140
	rain.lifetime = 1.1
	rain.one_shot = false
	rain.emitting = true
	rain.preprocess = 0.3
	rain.draw_pass_1 = _rain_drop_mesh(HEAL_SECONDARY)
	var rain_pm := ParticleProcessMaterial.new()
	rain_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	rain_pm.emission_ring_axis = Vector3.UP
	rain_pm.emission_ring_radius = r
	rain_pm.emission_ring_inner_radius = 0.0
	rain_pm.emission_ring_height = 0.0
	rain_pm.direction = Vector3(0, -1, 0)
	rain_pm.spread = 4.0
	rain_pm.initial_velocity_min = 5.0
	rain_pm.initial_velocity_max = 7.0
	rain_pm.gravity = Vector3(0, -6.0, 0)
	rain_pm.scale_min = 0.5
	rain_pm.scale_max = 1.1
	rain_pm.particle_flag_align_y = true
	rain_pm.color = HEAL_SECONDARY
	rain.process_material = rain_pm
	rain.position.y = 4.5
	root.add_child(rain)
	get_tree().create_timer(duration - 0.3).timeout.connect(func():
		if is_instance_valid(rain):
			rain.emitting = false
	)

	# Volutes de fumée verte qui montent depuis le sol, réparties dans la zone.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(8):
		var a := rng.randf_range(0.0, TAU)
		var dist := rng.randf_range(0.0, r * 0.85)
		var offset := Vector3(cos(a) * dist, 0.05, sin(a) * dist)
		var tint := HEAL_SMOKE.lerp(HEAL_SECONDARY, rng.randf_range(0.2, 0.6))
		tint.a = rng.randf_range(0.55, 0.8)
		var size := rng.randf_range(1.4, 2.6)
		var puff := MeshInstance3D.new()
		puff.mesh = _soft_puff_mesh(Vector2(size, size), tint)
		puff.position = offset
		puff.scale = Vector3.ONE * 0.15
		root.add_child(puff)
		var puff_mat := puff.mesh.material as ShaderMaterial
		var puff_tween := puff.create_tween()
		puff_tween.set_parallel(true)
		puff_tween.tween_property(puff, "scale", Vector3.ONE * rng.randf_range(1.3, 2.0), duration * 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		puff_tween.tween_property(puff, "position:y", offset.y + rng.randf_range(0.8, 1.6), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		puff_tween.tween_property(puff_mat, "shader_parameter/alpha_factor", 0.0, 0.6).set_delay(duration - 0.6)
		puff_tween.set_parallel(false)

	# Petit flash lumineux vert au centre pour marquer l'activation.
	var light := OmniLight3D.new()
	light.light_color = HEAL_PRIMARY
	light.light_energy = 0.0
	light.omni_range = r * 0.6
	root.add_child(light)
	var light_tween := root.create_tween()
	light_tween.tween_property(light, "light_energy", 4.0, 0.25)
	light_tween.tween_property(light, "light_energy", 0.0, duration - 0.25)

	get_tree().create_timer(duration + 0.4).timeout.connect(func():
		if is_instance_valid(root):
			root.queue_free()
	)
	return root

func _spawn_external(parent: Node, packed: PackedScene, position: Vector3, direction: Vector3, scale_value: float, lifetime: float) -> Node3D:
	if packed == null:
		return null
	var fx := packed.instantiate() as Node3D
	if fx == null:
		return null
	parent.add_child(fx)
	fx.global_position = position
	fx.scale = Vector3.ONE * scale_value
	if direction.length_squared() > 0.001:
		var d := direction.normalized()
		fx.rotation.y = atan2(d.x, d.z)
	get_tree().create_timer(lifetime).timeout.connect(func():
		if is_instance_valid(fx):
			fx.queue_free()
	)
	return fx

# VFX Binbun validés — tous les sorts (Eren, Aeris, Kaithlyn, Maylinh, coups génériques)
# utilisent désormais les vrais effets à particules du pack, simplement retintés par héros.

func _spawn_tinted(parent: Node, scene: PackedScene, position: Vector3, direction: Vector3, scale_value: float, lifetime: float, primary: Color, secondary: Color, tertiary: Color = Color(0, 0, 0, 0), emission_value: float = 3.0, light_energy_value: float = 5.0) -> Node3D:
	if parent == null or scene == null:
		return null
	var fx := scene.instantiate() as Node3D
	if fx == null:
		return null
	parent.add_child(fx)
	fx.global_position = position
	fx.scale = Vector3.ONE * scale_value
	if direction.length_squared() > 0.001:
		var d := direction.normalized()
		fx.rotation.y = atan2(d.x, d.z)
	fx.set("primary_color", primary)
	fx.set("secondary_color", secondary)
	if tertiary.a > 0.0:
		fx.set("tertiary_color", tertiary)
	fx.set("emission", emission_value)
	fx.set("light_color", primary)
	fx.set("light_energy", light_energy_value)
	get_tree().create_timer(lifetime).timeout.connect(func():
		if is_instance_valid(fx):
			fx.queue_free()
	)
	return fx

func spawn_orb(parent: Node, position: Vector3, direction: Vector3) -> Node3D:
	return _spawn_tinted(parent, IMPACT_01_VFX, position, direction, 0.7, 0.3, Color("b66cff"), Color("e6c9ff"), Color(0, 0, 0, 0), 3.0, 5.0)

func spawn_hit(parent: Node, position: Vector3, big: bool = false) -> Node3D:
	var scene := BIG_IMPACT_02_VFX if big else HIT_01_VFX
	return _spawn_tinted(parent, scene, position, Vector3.ZERO, 1.1 if big else 0.8, 0.4, DAMAGE_PRIMARY, DAMAGE_SECONDARY, Color(0, 0, 0, 0), 3.2, 5.5)

func spawn_explosion(parent: Node, position: Vector3, scale_value: float = 1.0) -> Node3D:
	return _spawn_tinted(parent, IMPACT_01_VFX, position + Vector3.UP * 0.05, Vector3.ZERO, 1.1 * scale_value, 0.55, COMBAT_PRIMARY, COMBAT_SECONDARY, Color(0, 0, 0, 0), 3.2, 6.0)

func spawn_charge(parent: Node, position: Vector3, scale_value: float = 1.0) -> Node3D:
	return _spawn_tinted(parent, BATTLE_CHARGE_VFX, position, Vector3.ZERO, 0.6 * scale_value, 0.5, COMBAT_PRIMARY, COMBAT_SECONDARY, COMBAT_TERTIARY, 3.0, 4.0)

func spawn_dash(parent: Node, position: Vector3, direction: Vector3) -> Node3D:
	return _spawn_tinted(parent, BATTLE_SWING_VFX, position, direction, 0.9, 0.32, COMBAT_PRIMARY, COMBAT_SECONDARY, COMBAT_TERTIARY, 3.2, 4.0)

func spawn_axe_plant(parent: Node, position: Vector3) -> Node3D:
	return _spawn_tinted(parent, BATTLE_SHIELD_VFX, position + Vector3.UP * 0.03, Vector3.ZERO, 1.05, 0.55, COMBAT_PRIMARY, COMBAT_TERTIARY, Color("ff5a12"), 3.4, 5.0)

func spawn_axe_hit(parent: Node, position: Vector3, direction: Vector3) -> Node3D:
	return _spawn_tinted(parent, BIG_IMPACT_02_VFX, position + Vector3.UP * 0.6, direction, 0.85, 0.5, DAMAGE_PRIMARY, Color("ff9a24"), Color(0, 0, 0, 0), 2.8, 5.5)

func spawn_damage_flash(parent: Node, position: Vector3, direction: Vector3) -> Node3D:
	return _spawn_tinted(parent, HIT_02_VFX, position + Vector3.UP * 0.65, direction, 0.6, 0.3, DAMAGE_PRIMARY, DAMAGE_SECONDARY, Color(0, 0, 0, 0), 3.0, 5.0)

func spawn_axe_swing(parent: Node, position: Vector3, direction: Vector3) -> Node3D:
	return _spawn_tinted(parent, BATTLE_SLASH_VFX, position + Vector3.UP * 0.6, direction, 1.15, 0.32, COMBAT_PRIMARY, COMBAT_SECONDARY, COMBAT_TERTIARY, 3.4, 4.5)

func spawn_shield_bash(parent: Node, position: Vector3, direction: Vector3) -> Node3D:
	return _spawn_tinted(parent, BATTLE_SHIELD_VFX, position, direction, 0.85, 0.4, Color("ffd36a"), COMBAT_TERTIARY, COMBAT_PRIMARY, 3.0, 4.5)

func spawn_shield_block(parent: Node, position: Vector3) -> Node3D:
	return _spawn_tinted(parent, BATTLE_SHIELD_VFX, position, Vector3.ZERO, 1.3, 0.7, Color("ffd36a"), COMBAT_TERTIARY, COMBAT_PRIMARY, 2.6, 4.0)

func spawn_shield_hit(parent: Node, position: Vector3) -> Node3D:
	return _spawn_tinted(parent, HIT_01_VFX, position, Vector3.ZERO, 0.95, 0.32, Color("ffd24a"), COMBAT_SECONDARY, Color(0, 0, 0, 0), 3.0, 5.0)


# =========================
# VFX HERO-SPECIFIQUES
# =========================
func spawn_aeris_orb(projectile: Node3D, direction: Vector3) -> Node3D:
	# Sphère de glace attachée directement au projectile : elle voyage avec lui
	# (contrairement à l'ancienne version qui ne faisait qu'un flash au point de tir).
	if projectile == null:
		return null
	var root := Node3D.new()
	root.name = "AerisIceOrbFX"
	projectile.add_child(root)

	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.24
	sphere.height = 0.48
	sphere.radial_segments = 10
	sphere.rings = 6
	core.mesh = sphere
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(ICE_CORE.r, ICE_CORE.g, ICE_CORE.b, 0.55)
	core_mat.emission_enabled = true
	core_mat.emission = ICE_PRIMARY
	core_mat.emission_energy_multiplier = 5.0
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	core.material_override = core_mat
	root.add_child(core)

	var shard_mat := StandardMaterial3D.new()
	shard_mat.albedo_color = ICE_SECONDARY
	shard_mat.emission_enabled = true
	shard_mat.emission = ICE_SECONDARY
	shard_mat.emission_energy_multiplier = 6.0
	shard_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var rng := RandomNumberGenerator.new()
	rng.seed = int(projectile.get_instance_id())
	for i in range(5):
		var shard := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.05, 0.20, 0.05)
		shard.mesh = box
		shard.material_override = shard_mat
		var a := TAU * float(i) / 5.0
		shard.position = Vector3(cos(a) * 0.20, sin(a) * 0.12, sin(a * 1.3) * 0.16)
		shard.rotation_degrees = Vector3(rng.randf_range(-60, 60), rng.randf_range(0, 360), rng.randf_range(-60, 60))
		root.add_child(shard)

	var particles := GPUParticles3D.new()
	particles.amount = 24
	particles.lifetime = 0.55
	particles.local_coords = false
	particles.draw_pass_1 = _ice_sparkle_mesh()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.16
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.35
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	pm.color = ICE_SECONDARY
	particles.process_material = pm
	root.add_child(particles)
	particles.restart()

	var light := OmniLight3D.new()
	light.light_color = ICE_PRIMARY
	light.light_energy = 3.0
	light.omni_range = 2.0
	root.add_child(light)

	var tween := root.create_tween()
	tween.set_loops()
	tween.tween_property(root, "rotation:y", TAU, 1.1)
	return root

func spawn_aeris_hit(parent: Node, position: Vector3) -> Node3D:
	_spawn_ice_shard_burst(parent, position, 0.55)
	return _spawn_tinted(parent, IMPACT_02_VFX, position, Vector3.ZERO, 0.85, 0.4, ICE_PRIMARY, ICE_SECONDARY, Color(0, 0, 0, 0), 3.2, 5.5)

func spawn_maylinh_hit(parent: Node, position: Vector3) -> Node3D:
	return _spawn_tinted(parent, HIT_01_VFX, position, Vector3.ZERO, 0.8, 0.36, MAYLINH_PRIMARY, MAYLINH_SECONDARY, Color(0, 0, 0, 0), 3.2, 5.0)

func spawn_aeris_dash(parent: Node, position: Vector3, direction: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "AerisIceDashFX"
	parent.add_child(root)
	root.global_position = position
	var d := direction.normalized()
	if d.length_squared() < 0.001:
		d = Vector3(0, 0, -1)
	root.rotation.y = atan2(d.x, d.z)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(ICE_PRIMARY.r, ICE_PRIMARY.g, ICE_PRIMARY.b, 0.85)
	mat.emission_enabled = true
	mat.emission = ICE_PRIMARY
	mat.emission_energy_multiplier = 6.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in range(4):
		var streak := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.14, 0.10, 0.9 + i * 0.3)
		streak.mesh = box
		streak.position = Vector3(0, 0.15 + i * 0.05, 0.2 + i * 0.4)
		streak.rotation_degrees.y = (i - 1.5) * 6.0
		streak.material_override = mat
		root.add_child(streak)

	var particles := GPUParticles3D.new()
	particles.amount = 22
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.emitting = true
	particles.draw_pass_1 = _ice_sparkle_mesh()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.2, 0.2, 1.0)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.4
	pm.scale_max = 0.9
	pm.color = ICE_SECONDARY
	particles.process_material = pm
	root.add_child(particles)

	var tween := root.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.32)
	tween.parallel().tween_property(mat, "emission_energy_multiplier", 0.0, 0.32)
	tween.tween_callback(root.queue_free)
	return root

func _ice_sparkle_mesh() -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.08, 0.08)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, depth_test_disabled;

uniform vec4 tint : source_color = vec4(0.85, 0.98, 1.0, 1.0);

void fragment() {
	vec2 c = UV - vec2(0.5);
	float d = length(c) * 2.0;
	float soft = 1.0 - smoothstep(0.3, 1.0, d);
	ALBEDO = tint.rgb;
	EMISSION = tint.rgb * 3.0;
	ALPHA = soft;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tint", ICE_SECONDARY)
	mesh.material = mat
	return mesh

func _soft_puff_mesh(size: Vector2, tint: Color) -> QuadMesh:
	# Nuage de fumée doux, billboardé (toujours face caméra), réutilisé pour
	# la fumée de téléportation de Maylinh et les volutes de sa zone de soin.
	var mesh := QuadMesh.new()
	mesh.size = size
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, depth_test_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform float alpha_factor = 1.0;

void vertex() {
	// Billboard manuel : pas de mot-clé "billboard" pour les shaders spatial,
	// on aligne donc la matrice modèle-vue sur les axes caméra nous-mêmes.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 c = UV - vec2(0.5);
	float d = length(c) * 2.0;
	float soft = 1.0 - smoothstep(0.15, 1.0, d);
	soft = pow(soft, 1.6);
	ALBEDO = tint.rgb;
	ALPHA = soft * tint.a * alpha_factor;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("alpha_factor", 1.0)
	mesh.material = mat
	return mesh

func _rain_drop_mesh(tint: Color) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.035, 0.28)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, depth_test_disabled;

uniform vec4 tint : source_color = vec4(0.4, 1.0, 0.55, 1.0);

void fragment() {
	float edge = 1.0 - abs(UV.x - 0.5) * 2.0;
	float vertical = smoothstep(0.0, 0.15, UV.y) * (1.0 - smoothstep(0.7, 1.0, UV.y));
	ALBEDO = tint.rgb;
	EMISSION = tint.rgb * 2.5;
	ALPHA = edge * vertical;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tint", tint)
	mesh.material = mat
	return mesh

func _spawn_ice_shard_burst(parent: Node, position: Vector3, scale_value: float = 1.0) -> void:
	if parent == null:
		return
	var root := Node3D.new()
	root.name = "IceShardBurstFX"
	parent.add_child(root)
	root.global_position = position

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(ICE_SECONDARY.r, ICE_SECONDARY.g, ICE_SECONDARY.b, 0.9)
	mat.emission_enabled = true
	mat.emission = ICE_PRIMARY
	mat.emission_energy_multiplier = 7.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.12 * scale_value
	torus.outer_radius = 0.22 * scale_value
	torus.rings = 28
	torus.ring_segments = 10
	ring.mesh = torus
	ring.rotation_degrees.x = 90.0
	ring.material_override = mat
	root.add_child(ring)

	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * 3.2, 0.4)
	for i in range(7):
		var shard := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.07, 0.36, 0.07) * scale_value
		shard.mesh = box
		shard.material_override = mat
		var a := TAU * float(i) / 7.0
		shard.position = Vector3.UP * 0.05
		shard.rotation_degrees = Vector3(75.0, rad_to_deg(a), 0.0)
		root.add_child(shard)
		var dest := Vector3(cos(a), 0.3, sin(a)) * 0.9 * scale_value
		tween.tween_property(shard, "position", dest, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(shard, "scale", Vector3.ZERO, 0.32).set_delay(0.18)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.set_parallel(false)
	tween.tween_callback(root.queue_free)

func spawn_maylinh_spirit(parent: Node, position: Vector3, direction: Vector3) -> Node3D:
	return _spawn_tinted(parent, BATTLE_SLASH_VFX, position, direction, 0.85, 0.34, MAYLINH_PRIMARY, MAYLINH_SECONDARY, Color("6a1fbf"), 3.2, 4.5)

func spawn_maylinh_heal(parent: Node, position: Vector3) -> Node3D:
	var circle_scene := load("res://scenes/vfx/free_magic_circle.tscn") as PackedScene
	if circle_scene == null:
		return null
	var circle := circle_scene.instantiate() as Node3D
	if circle == null:
		return null
	parent.add_child(circle)
	circle.global_position = position + Vector3.UP * 0.035
	circle.scale = Vector3.ONE * 1.6
	circle.set("circle_color", Color("63f3b0"))
	circle.set("circle_scale", 2.0)
	circle.set("spiral_count", 10)
	circle.set("duration", 1.6)
	get_tree().create_timer(1.7).timeout.connect(func():
		if is_instance_valid(circle):
			circle.queue_free()
	)
	return circle

func spawn_maylinh_flee(parent: Node, position: Vector3, scale_value: float = 1.0) -> Node3D:
	# Poof de fumée façon téléportation ninja — utilisé au départ ET à l'arrivée.
	if parent == null:
		return null
	var duration := 2.0
	var root := Node3D.new()
	root.name = "MaylinhSmokeFX"
	parent.add_child(root)
	root.global_position = position

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(7):
		var tint := SMOKE_LIGHT.lerp(SMOKE_DARK, rng.randf())
		tint.a = rng.randf_range(0.55, 0.85)
		var size := rng.randf_range(0.9, 1.7) * scale_value
		var puff := MeshInstance3D.new()
		puff.mesh = _soft_puff_mesh(Vector2(size, size), tint)
		var offset := Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.1, 0.5), rng.randf_range(-0.5, 0.5)) * scale_value
		puff.position = offset
		puff.scale = Vector3.ONE * 0.15
		root.add_child(puff)
		var puff_mat := puff.mesh.material as ShaderMaterial
		var rise := rng.randf_range(0.8, 1.6) * scale_value
		var tween := puff.create_tween()
		tween.set_parallel(true)
		tween.tween_property(puff, "scale", Vector3.ONE * rng.randf_range(1.2, 1.9), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(puff, "position:y", offset.y + rise, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(puff_mat, "shader_parameter/alpha_factor", 0.0, 0.7).set_delay(duration - 0.7)
		tween.set_parallel(false)

	# Bouffée dense au moment précis du "poof".
	var burst := GPUParticles3D.new()
	burst.amount = 40
	burst.lifetime = 0.5
	burst.one_shot = true
	burst.emitting = true
	burst.explosiveness = 0.9
	burst.draw_pass_1 = _soft_puff_mesh(Vector2(0.35, 0.35) * scale_value, Color(SMOKE_LIGHT.r, SMOKE_LIGHT.g, SMOKE_LIGHT.b, 0.8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.25 * scale_value
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 130.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, 0.4, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	burst.process_material = pm
	root.add_child(burst)

	get_tree().create_timer(duration + 0.2).timeout.connect(func():
		if is_instance_valid(root):
			root.queue_free()
	)
	return root

func spawn_maylinh_cage(parent: Node, position: Vector3) -> Node3D:
	return _spawn_tinted(parent, ELEMENTAL_AREA_VFX, position, Vector3.ZERO, 1.6, 2.0, MAYLINH_PRIMARY, Color("6a1fbf"), Color("e7c7ff"), 2.6, 4.0)
