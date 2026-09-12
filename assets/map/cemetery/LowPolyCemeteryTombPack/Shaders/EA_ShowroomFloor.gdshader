// EmacEArt - showroom floor.
//
// The floor of a showroom is not a surface anyone should look at. It is a grey plate with a
// pool of light spreading from the middle outwards and dying into the background colour before
// its own edge is ever in frame, plus a grain fine enough to be felt and not seen. A tiling
// noise texture was tried first and read as water - the pattern was the problem, so there is
// no pattern here: the grain is per-pixel hash on the world position.
//
// LICENCE
//   EmacEArt Asset License - free for personal and commercial use, but resale or
//   redistribution of the assets as standalone files or asset packs is prohibited.
//   No credit is required, though it is always welcome.
//   EmacEArt - https://emaceart.itch.io

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_disabled;

group_uniforms Pool;
// centre of the light pool, in the plane's own UV space - 0.5, 0.5 is the middle of the plane
uniform vec2 pool_center = vec2(0.5, 0.5);
uniform float pool_radius : hint_range(0.05, 1.0) = 0.42;
uniform float pool_falloff : hint_range(0.5, 6.0) = 2.2;
uniform vec4 pool_color : source_color = vec4(0.34, 0.345, 0.36, 1.0);
uniform vec4 edge_color : source_color = vec4(0.055, 0.062, 0.082, 1.0);

group_uniforms Grain;
uniform float grain_amount : hint_range(0.0, 0.3) = 0.055;
uniform float grain_scale : hint_range(0.5, 60.0) = 11.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	// the pool: bright in the middle, gone by the time the plane ends
	float d = length((UV - pool_center) / vec2(pool_radius)) ;
	float k = pow(clamp(1.0 - d, 0.0, 1.0), pool_falloff);
	vec3 c = mix(edge_color.rgb, pool_color.rgb, k);

	// grain tied to world position, so it does not swim when the camera moves and does not
	// change size with the distance to the floor
	float g = hash12(floor(world_pos.xz * grain_scale));
	c *= 1.0 + (g - 0.5) * grain_amount * 2.0;

	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	METALLIC = 0.0;
}
