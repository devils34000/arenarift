shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_opaque, specular_disabled, shadows_disabled;

// Bouclier hologramme : fresnel (bord lumineux selon l'angle de vue) +
// grille hexagonale animée, pour un rendu proche d'un "shield hologram"
// sans dépendre d'un asset externe (aucune texture, aucune depth_texture
// d'écran -> compatible avec le renderer GL Compatibility du projet).

uniform vec4 shield_color : source_color = vec4(1.0, 0.75, 0.25, 1.0);
uniform float fresnel_power : hint_range(0.1, 8.0) = 2.5;
uniform float rim_strength : hint_range(0.0, 6.0) = 2.2;
uniform float hex_scale : hint_range(2.0, 40.0) = 14.0;
uniform float hex_line_width : hint_range(0.01, 0.5) = 0.08;
uniform float hex_glow : hint_range(0.0, 4.0) = 1.4;
uniform float scroll_speed : hint_range(-2.0, 2.0) = 0.2;
uniform float effect_decay : hint_range(0.0, 1.0) = 0.0;

// Distance au centre de l'hexagone le plus proche (pavage par grille
// décalée : on choisit le plus proche des deux réseaux carrés imbriqués).
vec2 hex_local(vec2 p) {
	vec2 s = vec2(1.0, 1.7320508);
	vec2 a = mod(p, s) - s * 0.5;
	vec2 b = mod(p - s * 0.5, s) - s * 0.5;
	return (dot(a, a) < dot(b, b)) ? a : b;
}

float hex_edge_dist(vec2 gv) {
	vec2 q = abs(gv);
	return max(q.x * 0.8660254 + q.y * 0.5, q.y);
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);

	vec2 uv = UV;
	uv.y += TIME * scroll_speed;
	vec2 gv = hex_local(uv * hex_scale);
	float d = hex_edge_dist(gv);
	float edge = 1.0 - smoothstep(0.5 - hex_line_width, 0.5, d);

	float glow = edge * hex_glow;
	float rim = fresnel * rim_strength;

	vec3 glow_color = shield_color.rgb * (rim + glow);
	float alpha = clamp((rim * 0.6 + glow) * (1.0 - effect_decay), 0.0, 1.0);

	ALBEDO = shield_color.rgb;
	EMISSION = glow_color;
	ALPHA = alpha;
}
