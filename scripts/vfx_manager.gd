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
const AERIS_PRIMARY := Color("62d8ff")
const AERIS_SECONDARY := Color("d9f7ff")
const AERIS_TERTIARY := Color("2f7fbf")
const MAYLINH_PRIMARY := Color("c45cff")
const MAYLINH_SECONDARY := Color("f2b6ff")
const COMBAT_PRIMARY := Color("ff9d2e")
const COMBAT_SECONDARY := Color("ffe8b0")
const COMBAT_TERTIARY := Color("ffb52e")
const DAMAGE_PRIMARY := Color("ff3b30")
const DAMAGE_SECONDARY := Color("ffb0a8")

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
func spawn_aeris_orb(parent: Node, position: Vector3, direction: Vector3) -> Node3D:
	return _spawn_tinted(parent, ELEMENTAL_CAST_VFX, position + Vector3.UP * 0.06, direction, 1.05, 0.5, AERIS_PRIMARY, AERIS_SECONDARY, AERIS_TERTIARY, 3.4, 5.0)

func spawn_aeris_hit(parent: Node, position: Vector3) -> Node3D:
	return _spawn_tinted(parent, IMPACT_02_VFX, position, Vector3.ZERO, 0.85, 0.4, AERIS_PRIMARY, AERIS_SECONDARY, Color(0, 0, 0, 0), 3.2, 5.5)

func spawn_maylinh_hit(parent: Node, position: Vector3) -> Node3D:
	return _spawn_tinted(parent, HIT_01_VFX, position, Vector3.ZERO, 0.8, 0.36, MAYLINH_PRIMARY, MAYLINH_SECONDARY, Color(0, 0, 0, 0), 3.2, 5.0)

func spawn_aeris_dash(parent: Node, position: Vector3, direction: Vector3) -> Node3D:
	return _spawn_tinted(parent, BATTLE_SWING_VFX, position, direction, 1.0, 0.34, AERIS_PRIMARY, AERIS_SECONDARY, AERIS_TERTIARY, 3.2, 4.5)

func spawn_aeris_teleport(parent: Node, position: Vector3, arriving: bool = false) -> Node3D:
	return _spawn_tinted(parent, BATTLE_SHIELD_VFX, position + Vector3.UP * 0.05, Vector3.ZERO, 1.5 if arriving else 1.1, 0.45, AERIS_PRIMARY, Color("8c6cff"), AERIS_SECONDARY, 3.4, 5.0)

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

func spawn_maylinh_flee(parent: Node, position: Vector3) -> Node3D:
	return _spawn_tinted(parent, ELEMENTAL_AREA_VFX, position + Vector3.UP * 0.04, Vector3.ZERO, 1.0, 0.4, MAYLINH_PRIMARY, Color("e7c7ff"), Color("6a1fbf"), 3.4, 4.5)

func spawn_maylinh_cage(parent: Node, position: Vector3) -> Node3D:
	return _spawn_tinted(parent, ELEMENTAL_AREA_VFX, position, Vector3.ZERO, 1.6, 2.0, MAYLINH_PRIMARY, Color("6a1fbf"), Color("e7c7ff"), 2.6, 4.0)
