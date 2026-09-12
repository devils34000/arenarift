class_name ArenaVFXManager
extends Node3D


# Téléportation — restaurée avec les VFX Binbun validés de la V14.
const TELEPORT_CHARGE_VFX: PackedScene = preload("res://assets/BinbunVFX_Vol2/BattleFX/effects/charge/vfx_blank_charge.tscn")
const TELEPORT_EXPLOSION_VFX: PackedScene = preload("res://assets/BinbunVFX_Vol2/ExplosionFX/effects/ground/vfx_ground_explosion_01.tscn")

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

var eren_trail_vfx_clock: float = 0.0

func spawn_teleport_start(parent: Node, position: Vector3, scale_value: float = 0.75) -> Node3D:
	return _spawn_external(parent, TELEPORT_CHARGE_VFX, position, Vector3.ZERO, scale_value, 2.5)

func spawn_teleport_end(parent: Node, position: Vector3, scale_value: float = 0.55) -> Node3D:
	return _spawn_external(parent, TELEPORT_EXPLOSION_VFX, position, Vector3.ZERO, scale_value, 2.5)

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

func spawn_maylinh_elemental_heal(parent: Node, position: Vector3) -> Node3D:
	if parent == null:
		return null

	# Nouveau cercle Free Magic pour le soin de Maylinh.
	# On le charge dynamiquement afin que le reste du VFX manager reste compatible.
	var circle_scene := load("res://scenes/vfx/free_magic_circle.tscn") as PackedScene
	if circle_scene != null:
		var circle := circle_scene.instantiate() as Node3D
		if circle != null:
			parent.add_child(circle)
			circle.global_position = position + Vector3.UP * 0.035
			circle.scale = Vector3.ONE * 1.55
			if circle.has_method("set"):
				circle.set("circle_color", Color("8cff65"))
				circle.set("circle_scale", 2.0)
				circle.set("spiral_count", 0)
				circle.set("duration", 2.15)
			get_tree().create_timer(2.2).timeout.connect(func():
				if is_instance_valid(circle):
					circle.queue_free()
			)
			return circle

	# Secours : ancien VFX si la scène Free Magic n'est pas présente.
	if MAYLINH_ELEMENTAL_AREA_VFX == null:
		return null
	var fx := MAYLINH_ELEMENTAL_AREA_VFX.instantiate() as Node3D
	if fx == null:
		return null
	parent.add_child(fx)
	fx.global_position = position + Vector3.UP * 0.02
	fx.set("area_radius", 3.0)
	fx.set("primary_color", Color("b8ff45"))
	fx.set("secondary_color", Color("55ff2e"))
	fx.set("tertiary_color", Color("0d7a35"))
	fx.set("emission", 3.5)
	fx.set("speed_scale", 1.0)
	get_tree().create_timer(2.15).timeout.connect(func():
		if is_instance_valid(fx):
			fx.queue_free()
	)
	return fx

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

# VFX procéduraux + VFX Binbun validés.
# Eren utilise désormais exclusivement les effets réels du pack ExplosionFXFree.

func spawn_orb(parent: Node, position: Vector3, direction: Vector3) -> Node3D:
	return _burst(parent, position, Color("b66cff"), 0.38, 0.22)

func spawn_hit(parent: Node, position: Vector3, big: bool = false) -> Node3D:
	return _impact(parent, position, Color("ff4d4d"), 1.15 if big else 0.8, 0.24)

func spawn_explosion(parent: Node, position: Vector3, scale_value: float = 1.0) -> Node3D:
	return _impact(parent, position, Color("ff8a18"), 1.0 * scale_value, 0.32)

func spawn_charge(parent: Node, position: Vector3, scale_value: float = 1.0) -> Node3D:
	return _impact(parent, position, Color("ff8a18"), 0.75 * scale_value, 0.22)

func spawn_dash(parent: Node, position: Vector3, direction: Vector3) -> Node3D:
	var root := _root(parent, position, "DashFX")
	var d := direction.normalized()
	if d.length_squared() < 0.001:
		d = Vector3(0, 0, -1)
	root.rotation.y = atan2(d.x, d.z)
	var mat := _mat(Color("ff7b18"), 7.0)
	for i in range(4):
		var streak := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.18, 0.12, 1.0 + i * 0.35)
		streak.mesh = box
		streak.position = Vector3(0, 0.18 + i * 0.05, 0.25 + i * 0.42)
		streak.rotation_degrees.y = (i - 1) * 8.0
		streak.material_override = mat
		root.add_child(streak)
	_tween_free(root, 0.28)
	return root

func spawn_axe_plant(parent: Node, position: Vector3) -> Node3D:
	var root := _root(parent, position + Vector3.UP * 0.03, "AxePlantFX")
	var mat := _mat(Color("ff9d2e"), 8.0)
	var ring := _torus(root, 0.18, 0.52, mat)
	ring.rotation_degrees.x = 90.0
	var shock := _torus(root, 0.42, 0.48, mat)
	shock.rotation_degrees.x = 90.0
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * 1.8, 0.26)
	tween.tween_property(shock, "scale", Vector3.ONE * 2.2, 0.22)
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.26)
	tween.set_parallel(false)
	tween.tween_callback(root.queue_free)
	return root

func spawn_axe_hit(parent: Node, position: Vector3, direction: Vector3) -> Node3D:
	return _impact(parent, position + Vector3.UP * 0.65, Color("ff3b30"), 1.05, 0.28)

func spawn_damage_flash(parent: Node, position: Vector3, direction: Vector3) -> Node3D:
	var root := _root(parent, position + Vector3.UP * 0.7, "DamageRedFlashFX")
	var mat := _mat(Color(1.0, 0.03, 0.02, 0.95), 10.0)
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.9
	flash.mesh = sphere
	flash.material_override = mat
	root.add_child(flash)
	var ring := _torus(root, 0.34, 0.5, mat)
	ring.rotation_degrees.x = 90.0
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * 0.08, 0.14)
	tween.tween_property(ring, "scale", Vector3.ONE * 1.8, 0.18)
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.18)
	tween.set_parallel(false)
	tween.tween_callback(root.queue_free)
	return root

func spawn_axe_swing(parent: Node, position: Vector3, direction: Vector3) -> Node3D:
	return _melee(parent, position, direction, Color("ff9b2f"), 1.35, 0.22)

func spawn_shield_bash(parent: Node, position: Vector3, direction: Vector3) -> Node3D:
	return _melee(parent, position, direction, Color("ffd36a"), 1.1, 0.24)

func spawn_shield_block(parent: Node, position: Vector3) -> Node3D:
	var root := _root(parent, position, "KaithlynShieldFX")
	var mat := _mat(Color("ffb52e"), 6.0)
	var ring := _torus(root, 0.95, 1.05, mat)
	ring.rotation_degrees.x = 90.0
	var ring2 := _torus(root, 0.72, 0.78, mat)
	ring2.rotation_degrees.x = 90.0
	ring2.position.y = 0.35
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "rotation_degrees", Vector3(90, 0, 360), 0.65)
	tween.tween_property(ring2, "rotation_degrees", Vector3(90, 360, 0), 0.65)
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.7)
	tween.set_parallel(false)
	tween.tween_callback(root.queue_free)
	return root

func spawn_shield_hit(parent: Node, position: Vector3) -> Node3D:
	return _impact(parent, position, Color("ffd24a"), 0.95, 0.2)


# =========================
# VFX HERO-SPECIFIQUES
# =========================
func spawn_aeris_orb(parent: Node, position: Vector3, direction: Vector3) -> Node3D:
	var root := _root(parent, position, "AerisArcBoltFX")
	var cyan := _mat(Color("62d8ff"), 9.0)
	var white := _mat(Color("d9f7ff"), 12.0)
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.30
	sphere.height = 0.60
	core.mesh = sphere
	core.material_override = white
	root.add_child(core)
	var ring := _torus(root, 0.36, 0.44, cyan)
	ring.rotation_degrees.x = 90.0
	var ring2 := _torus(root, 0.24, 0.30, cyan)
	ring2.rotation_degrees.y = 90.0
	var d := direction.normalized()
	if d.length_squared() < 0.001:
		d = Vector3(0, 0, -1)
	root.rotation.y = atan2(d.x, d.z)
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(core, "scale", Vector3.ONE * 0.18, 0.30)
	tween.tween_property(ring, "scale", Vector3.ONE * 1.9, 0.30)
	tween.tween_property(ring2, "scale", Vector3.ONE * 1.55, 0.30)
	tween.tween_property(cyan, "emission_energy_multiplier", 0.0, 0.30)
	tween.tween_property(white, "emission_energy_multiplier", 0.0, 0.30)
	tween.set_parallel(false)
	tween.tween_callback(root.queue_free)
	return root

func spawn_aeris_hit(parent: Node, position: Vector3) -> Node3D:
	return _arcane_impact(parent, position, Color("66dfff"), Color("e8fbff"), 1.0)

func spawn_maylinh_hit(parent: Node, position: Vector3) -> Node3D:
	return _arcane_impact(parent, position, Color("c45cff"), Color("f2b6ff"), 0.95)

func spawn_aeris_dash(parent: Node, position: Vector3, direction: Vector3) -> Node3D:
	var root := _root(parent, position, "AerisDashFX")
	var mat := _mat(Color("55cfff"), 8.0)
	var d := direction.normalized()
	if d.length_squared() < 0.001:
		d = Vector3(0, 0, -1)
	root.rotation.y = atan2(d.x, d.z)
	for i in range(3):
		var ring := _torus(root, 0.42 + i * 0.18, 0.49 + i * 0.18, mat)
		ring.rotation_degrees.x = 90.0
		ring.position.z = 0.18 + i * 0.30
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "scale", Vector3(1.8, 1.8, 1.8), 0.28)
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.28)
	tween.set_parallel(false)
	tween.tween_callback(root.queue_free)
	return root

func spawn_aeris_teleport(parent: Node, position: Vector3, arriving: bool = false) -> Node3D:
	var root := _root(parent, position + Vector3.UP * 0.05, "AerisTeleportFX")
	var blue := _mat(Color("4caeff"), 8.0)
	var violet := _mat(Color("8c6cff"), 7.0)
	var ring := _torus(root, 0.55, 0.68, blue)
	ring.rotation_degrees.x = 90.0
	var ring2 := _torus(root, 0.85, 0.94, violet)
	ring2.rotation_degrees.x = 90.0
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * (2.0 if arriving else 1.4), 0.35)
	tween.tween_property(ring2, "scale", Vector3.ONE * 1.8, 0.42)
	tween.tween_property(blue, "emission_energy_multiplier", 0.0, 0.42)
	tween.tween_property(violet, "emission_energy_multiplier", 0.0, 0.42)
	tween.set_parallel(false)
	tween.tween_callback(root.queue_free)
	return root

func spawn_maylinh_spirit(parent: Node, position: Vector3, direction: Vector3) -> Node3D:
	var root := _root(parent, position, "MaylinhSpiritFX")
	var purple := _mat(Color("c05cff"), 9.0)
	var pink := _mat(Color("f0a1ff"), 8.0)
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.26
	sphere.height = 0.52
	core.mesh = sphere
	core.material_override = pink
	root.add_child(core)
	for i in range(4):
		var shard := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.10, 0.10, 0.52)
		shard.mesh = box
		shard.position = Vector3(cos(TAU * i / 4.0) * 0.38, sin(TAU * i / 4.0) * 0.25, 0.0)
		shard.rotation_degrees = Vector3(0, i * 90.0, 35.0)
		shard.material_override = purple
		root.add_child(shard)
	var d := direction.normalized()
	if d.length_squared() < 0.001:
		d = Vector3(0, 0, -1)
	root.rotation.y = atan2(d.x, d.z)
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(core, "scale", Vector3.ONE * 0.12, 0.34)
	tween.tween_property(root, "rotation:y", root.rotation.y + TAU * 0.75, 0.34)
	tween.tween_property(purple, "emission_energy_multiplier", 0.0, 0.34)
	tween.tween_property(pink, "emission_energy_multiplier", 0.0, 0.34)
	tween.set_parallel(false)
	tween.tween_callback(root.queue_free)
	return root

func spawn_maylinh_heal(parent: Node, position: Vector3) -> Node3D:
	var root := _root(parent, position + Vector3.UP * 0.04, "MaylinhHealFX")
	var green := _mat(Color("63f3b0"), 8.0)
	var gold := _mat(Color("d9ff9a"), 6.0)
	var ring := _torus(root, 1.0, 1.12, green)
	ring.rotation_degrees.x = 90.0
	var ring2 := _torus(root, 1.65, 1.75, gold)
	ring2.rotation_degrees.x = 90.0
	for i in range(6):
		var mote := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.07
		sphere.height = 0.14
		mote.mesh = sphere
		mote.position = Vector3(cos(TAU*i/6.0)*0.8, 0.15, sin(TAU*i/6.0)*0.8)
		mote.material_override = gold
		root.add_child(mote)
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * 1.45, 0.55)
	tween.tween_property(ring2, "scale", Vector3.ONE * 1.7, 0.65)
	tween.tween_property(root, "position:y", 0.65, 0.65)
	tween.tween_property(green, "emission_energy_multiplier", 0.0, 0.65)
	tween.tween_property(gold, "emission_energy_multiplier", 0.0, 0.65)
	tween.set_parallel(false)
	tween.tween_callback(root.queue_free)
	return root

func spawn_maylinh_flee(parent: Node, position: Vector3) -> Node3D:
	var root := _root(parent, position + Vector3.UP * 0.04, "MaylinhFleeFX")
	var purple := _mat(Color("b95cff"), 9.0)
	var white := _mat(Color("e7c7ff"), 7.0)
	for i in range(3):
		var ring := _torus(root, 0.42 + i * 0.16, 0.50 + i * 0.16, purple if i < 2 else white)
		ring.rotation_degrees.x = 90.0
		ring.position.y = 0.15 + i * 0.28
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "scale", Vector3(1.8, 1.8, 1.8), 0.38)
	tween.tween_property(purple, "emission_energy_multiplier", 0.0, 0.38)
	tween.tween_property(white, "emission_energy_multiplier", 0.0, 0.38)
	tween.set_parallel(false)
	tween.tween_callback(root.queue_free)
	return root

func spawn_maylinh_cage(parent: Node, position: Vector3) -> Node3D:
	var root := _root(parent, position, "MaylinhSpiritCageFX")
	var purple := _mat(Color("a95cff"), 8.0)
	for i in range(8):
		var pillar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.10, 2.4, 0.10)
		pillar.mesh = box
		pillar.position = Vector3(cos(TAU*i/8.0)*1.15, 1.2, sin(TAU*i/8.0)*1.15)
		pillar.material_override = purple
		root.add_child(pillar)
	var ring := _torus(root, 1.0, 1.12, purple)
	ring.rotation_degrees.x = 90.0
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "rotation:y", TAU * 0.25, 2.0)
	tween.tween_property(purple, "emission_energy_multiplier", 0.0, 2.0)
	tween.set_parallel(false)
	tween.tween_callback(root.queue_free)
	return root

func _arcane_impact(parent: Node, position: Vector3, color_a: Color, color_b: Color, radius: float) -> Node3D:
	var root := _root(parent, position, "ArcaneImpactFX")
	var mat_a := _mat(color_a, 9.0)
	var mat_b := _mat(color_b, 10.0)
	var ring := _torus(root, radius * 0.35, radius * 0.48, mat_a)
	ring.rotation_degrees.x = 90.0
	var ring2 := _torus(root, radius * 0.58, radius * 0.68, mat_b)
	ring2.rotation_degrees.x = 90.0
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * 2.0, 0.22)
	tween.tween_property(ring2, "scale", Vector3.ONE * 1.5, 0.28)
	tween.tween_property(mat_a, "emission_energy_multiplier", 0.0, 0.28)
	tween.tween_property(mat_b, "emission_energy_multiplier", 0.0, 0.28)
	tween.set_parallel(false)
	tween.tween_callback(root.queue_free)
	return root

func _root(parent: Node, position: Vector3, node_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	parent.add_child(root)
	root.global_position = position
	return root

func _mat(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b, 1.0)
	mat.emission_energy_multiplier = energy
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func _torus(root: Node3D, inner: float, outer: float, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 12
	node.mesh = mesh
	node.material_override = mat
	root.add_child(node)
	return node

func _burst(parent: Node, position: Vector3, color: Color, radius: float, duration: float) -> Node3D:
	var root := _root(parent, position, "BurstFX")
	var mat := _mat(color, 7.0)
	var ring := _torus(root, radius * 0.55, radius, mat)
	ring.rotation_degrees.x = 90.0
	var sphere := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius * 0.45
	sm.height = radius * 0.9
	sphere.mesh = sm
	sphere.material_override = mat
	root.add_child(sphere)
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * 1.8, duration)
	tween.tween_property(sphere, "scale", Vector3.ONE * 0.1, duration)
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, duration)
	tween.set_parallel(false)
	tween.tween_callback(root.queue_free)
	return root

func _impact(parent: Node, position: Vector3, color: Color, radius: float, duration: float) -> Node3D:
	return _burst(parent, position, color, radius, duration)

func _melee(parent: Node, position: Vector3, direction: Vector3, color: Color, radius: float, duration: float) -> Node3D:
	var root := _root(parent, position + Vector3.UP * 0.75, "MeleeFX")
	var d := direction.normalized()
	if d.length_squared() < 0.001:
		d = Vector3(0, 0, -1)
	root.rotation.y = atan2(d.x, d.z)
	var mat := _mat(color, 6.0)
	var arc := _torus(root, radius * 0.55, radius, mat)
	arc.rotation_degrees.x = 90.0
	arc.scale = Vector3(1.0, 0.35, 1.0)
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(arc, "scale", Vector3(1.6, 0.15, 1.6), duration)
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, duration)
	tween.set_parallel(false)
	tween.tween_callback(root.queue_free)
	return root

func _tween_free(node: Node, duration: float) -> void:
	var tween := node.create_tween()
	tween.tween_callback(node.queue_free).set_delay(duration)
