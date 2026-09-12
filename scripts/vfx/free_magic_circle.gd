@tool
class_name FreeMagicCircleVFX
extends Node3D

@export var circle_color := Color("8cff65"):
	set(value):
		circle_color = value
		_refresh_materials()

@export_range(0.1, 10.0, 0.1) var circle_scale := 2.0
@export_range(0.1, 30.0, 0.1) var duration := 6.0
@export_range(0, 64, 1) var spiral_count := 12:
	set(value):
		spiral_count = maxi(value, 0)
		if is_inside_tree() and _built:
			_rebuild_spirals()

@export_range(0, 32, 1) var smoke_count := 8:
	set(value):
		smoke_count = maxi(value, 0)
		if is_inside_tree() and _built:
			_rebuild_smoke()

@export_range(0.1, 10.0, 0.1) var spiral_lifetime := 1.4
@export_range(0.1, 10.0, 0.1) var smoke_lifetime := 3.2
@export var enable_smoke := true
@export var enable_particles := true

const CIRCLE_TEXTURE := "res://assets/FreeMagic/T_Free_Magic_Circle.PNG"
const NOISE_TEXTURE := "res://assets/FreeMagic/T_Free_Magic_Noise1.PNG"
const SMOKE_TEXTURE := "res://assets/FreeMagic/T_Free_Magic_Smoke.PNG"

var _time := 0.0
var _circle: MeshInstance3D
var _inner_glow: MeshInstance3D
var _spirals: Array[MeshInstance3D] = []
var _smoke: Array[MeshInstance3D] = []
var _particles: GPUParticles3D
var _rng := RandomNumberGenerator.new()
var _built := false

func _ready() -> void:
	_build_effect()

func _process(delta: float) -> void:
	if not _built:
		return

	_time += delta
	var life := maxf(duration, 0.1)
	var global_fade := clampf(1.0 - maxf(0.0, _time - life + 1.0), 0.0, 1.0)

	if is_instance_valid(_circle):
		var pulse := 1.0 + sin(_time * 2.2) * 0.035
		_circle.scale = Vector3.ONE * circle_scale * pulse
		_circle.rotation.y += delta * 0.12
		_set_alpha(_circle, global_fade)

	if is_instance_valid(_inner_glow):
		_inner_glow.scale = Vector3.ONE * circle_scale * (0.72 + sin(_time * 1.7) * 0.06)
		_inner_glow.rotation.y -= delta * 0.18
		_set_alpha(_inner_glow, global_fade * 0.42)

	for i in _spirals.size():
		var p := _spirals[i]
		if not is_instance_valid(p):
			continue
		var lifetime := maxf(spiral_lifetime, 0.01)
		var t := fmod(_time + float(i) * 0.19, lifetime) / lifetime
		p.rotation.y += delta * (0.8 + float(i % 5) * 0.12)
		p.rotation.z += delta * (0.4 + float(i % 3) * 0.1)
		p.scale = Vector3.ONE * lerpf(0.25, 0.95, t) * (0.8 + float(i % 4) * 0.08)
		_set_alpha(p, sin(t * PI) * global_fade * 0.65)

	for i in _smoke.size():
		var smoke := _smoke[i]
		if not is_instance_valid(smoke):
			continue
		var smoke_life := maxf(smoke_lifetime, 0.1)
		var t := fmod(_time + float(i) * 0.37, smoke_life) / smoke_life
		smoke.position.y = 0.025 + t * 0.22
		smoke.position.x += sin(_time * 0.7 + float(i)) * delta * 0.04
		smoke.position.z += cos(_time * 0.6 + float(i) * 1.7) * delta * 0.04
		smoke.rotation.y += delta * (0.12 + float(i % 3) * 0.06)
		smoke.rotation.z += delta * 0.08
		smoke.scale = Vector3.ONE * lerpf(0.18, 0.65, t) * (0.8 + float(i % 4) * 0.12)
		_set_alpha(smoke, sin(t * PI) * global_fade * 0.28)

	if is_instance_valid(_particles):
		_particles.amount_ratio = global_fade

func _build_effect() -> void:
	if _built:
		return
	_rng.randomize()
	_create_circle()
	_create_inner_glow()
	_create_spirals()
	if enable_smoke:
		_create_smoke()
	if enable_particles:
		_create_particles()
	_built = true

func _create_circle() -> void:
	_circle = _make_quad(
		"Circle",
		Vector2(2.0, 2.0),
		0.012,
		CIRCLE_TEXTURE,
		0.0
	)

	_circle.scale = Vector3.ONE * circle_scale
	add_child(_circle)

func _create_inner_glow() -> void:
	_inner_glow = _make_quad(
		"InnerGlow",
		Vector2(1.55, 1.55),
		0.014,
		NOISE_TEXTURE,
		0.035
	)

	_inner_glow.scale = Vector3.ONE * circle_scale
	_inner_glow.material_override = _make_material(
		NOISE_TEXTURE,
		0.035,
		0.22,
		0.12,
		true
	)

	add_child(_inner_glow)

func _create_spirals() -> void:
	for i in spiral_count:
		var ground_y := 0.018 + float(i) * 0.0002

		var p := _make_quad(
			"Spiral_%02d" % i,
			Vector2(1.4, 1.4),
			ground_y,
			NOISE_TEXTURE,
			0.08
		)

		p.position = Vector3(
			_rng.randf_range(-0.65, 0.65),
			ground_y,
			_rng.randf_range(-0.65, 0.65)
		)

		p.rotation.y = _rng.randf_range(-PI, PI)

		add_child(p)
		_spirals.append(p)

func _create_smoke() -> void:
	for i in smoke_count:
		var smoke := _make_quad(
			"Smoke_%02d" % i,
			Vector2(1.1, 1.1),
			0.025,
			SMOKE_TEXTURE,
			0.035
		)

		smoke.position = Vector3(
			_rng.randf_range(-0.55, 0.55),
			0.025,
			_rng.randf_range(-0.55, 0.55)
		)

		smoke.rotation.y = _rng.randf_range(-PI, PI)
		smoke.rotation.z = _rng.randf_range(-0.25, 0.25)

		add_child(smoke)
		_smoke.append(smoke)

func _create_particles() -> void:
	_particles = GPUParticles3D.new()
	_particles.name = "MagicDust"
	_particles.amount = 36
	_particles.lifetime = 2.4
	_particles.randomness = 0.85
	_particles.local_coords = true
	_particles.position.y = 0.025
	_particles.draw_pass_1 = _make_particle_quad()
	_particles.process_material = _make_particle_material()
	add_child(_particles)
	_particles.restart()

func _make_quad(node_name: String, size: Vector2, height: float, texture_path: String, scroll: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := QuadMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.rotation_degrees.x = -90.0
	node.position.y = height
	node.material_override = _make_material(texture_path, scroll, 0.0, 1.0, texture_path != CIRCLE_TEXTURE)
	return node

func _make_material(texture_path: String, scroll: float, threshold: float, emission_strength: float, radial_fade: bool = false) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, depth_test_disabled;

uniform sampler2D main_texture : source_color, filter_linear;
uniform vec4 tint : source_color;
uniform float alpha_factor = 1.0;
uniform float scroll_speed = 0.0;
uniform float mask_threshold = 0.02;
uniform float emission_strength = 1.0;
uniform bool radial_fade = false;

void fragment() {
    vec2 uv = UV;
    uv += vec2(TIME * scroll_speed, TIME * scroll_speed * 0.35);
    vec4 tex = texture(main_texture, uv);
    float luminance = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
    float mask = smoothstep(mask_threshold, mask_threshold + 0.10, luminance);
    if (radial_fade) {
        float edge = 1.0 - smoothstep(0.62, 0.98, length(UV - vec2(0.5)) * 2.0);
        mask *= edge;
    }
    if (mask <= 0.001) {
        discard;
    }
    ALBEDO = tint.rgb;
    EMISSION = tint.rgb * max(tex.rgb, vec3(mask)) * emission_strength;
    ALPHA = mask * tint.a * alpha_factor;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var tex := load(texture_path) as Texture2D
	if tex:
		mat.set_shader_parameter("main_texture", tex)
	mat.set_shader_parameter("tint", circle_color)
	mat.set_shader_parameter("alpha_factor", 1.0)
	mat.set_shader_parameter("scroll_speed", scroll)
	mat.set_shader_parameter("mask_threshold", threshold)
	mat.set_shader_parameter("emission_strength", emission_strength)
	mat.set_shader_parameter("radial_fade", radial_fade)
	return mat

func _make_particle_quad() -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.12, 0.12)

	# Matériau dédié aux particules : masque circulaire doux pour éviter les carrés.
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, depth_test_disabled;

uniform vec4 tint : source_color = vec4(0.55, 1.0, 0.35, 1.0);
uniform float alpha_factor = 1.0;

void fragment() {
    vec2 centered_uv = UV - vec2(0.5);
    float distance_from_center = length(centered_uv) * 2.0;
    float soft_circle = 1.0 - smoothstep(0.45, 1.0, distance_from_center);
    float core = 1.0 - smoothstep(0.0, 0.55, distance_from_center);
    float alpha = max(soft_circle * 0.75, core * 0.35);

    ALBEDO = tint.rgb;
    EMISSION = tint.rgb * 2.5;
    ALPHA = alpha * tint.a * alpha_factor;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("tint", circle_color)
	material.set_shader_parameter("alpha_factor", 1.0)
	mesh.material = material
	return mesh

func _make_particle_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	material.emission_ring_radius = 0.7
	material.emission_ring_inner_radius = 0.35
	material.direction = Vector3(0, 1, 0)
	material.spread = 25.0
	material.initial_velocity_min = 0.12
	material.initial_velocity_max = 0.35
	material.gravity = Vector3(0, 0.08, 0)
	material.scale_min = 0.35
	material.scale_max = 0.8
	material.color = Color(1, 1, 1, 0.75)
	return material

func _rebuild_spirals() -> void:
	for p in _spirals:
		if is_instance_valid(p):
			p.queue_free()
	_spirals.clear()
	_create_spirals()

func _rebuild_smoke() -> void:
	for p in _smoke:
		if is_instance_valid(p):
			p.queue_free()
	_smoke.clear()
	if enable_smoke:
		_create_smoke()

func _refresh_materials() -> void:
	for node in [_circle, _inner_glow]:
		if is_instance_valid(node):
			var mat := node.material_override as ShaderMaterial
			if mat:
				mat.set_shader_parameter("tint", circle_color)
	for node in _spirals:
		if is_instance_valid(node):
			var mat := node.material_override as ShaderMaterial
			if mat:
				mat.set_shader_parameter("tint", circle_color)
	for node in _smoke:
		if is_instance_valid(node):
			var mat := node.material_override as ShaderMaterial
			if mat:
				mat.set_shader_parameter("tint", circle_color)

func _set_alpha(node: MeshInstance3D, value: float) -> void:
	var mat := node.material_override as ShaderMaterial
	if mat:
		mat.set_shader_parameter("alpha_factor", clampf(value, 0.0, 1.0))
