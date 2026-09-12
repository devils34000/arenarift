// EmacEArt - showroom backdrop.
//
// Not a sky: a graphite gradient behind the objects, the way a photographer's cyclorama works.
// A flat colour poured over the whole background reads as tar and swallows every silhouette
// (Maciej, 2026-09-08), so the value climbs towards the horizon, where the group stands, and
// falls off above and below it. There is no sun, no cloud and no horizon line - only the ramp.
//
// LICENCE
//   EmacEArt Asset License - free for personal and commercial use, but resale or
//   redistribution of the assets as standalone files or asset packs is prohibited.
//   No credit is required, though it is always welcome.
//   EmacEArt - https://emaceart.itch.io

shader_type sky;

uniform vec4 top_color : source_color = vec4(0.030, 0.031, 0.040, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.125, 0.128, 0.150, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.048, 0.050, 0.062, 1.0);
// how far above and below the horizon the bright band reaches
uniform float horizon_spread : hint_range(0.02, 1.0) = 0.34;
uniform float top_falloff : hint_range(0.3, 4.0) = 1.15;
// a wide, very soft pool of light centred behind the group, so the backdrop is never flat
uniform float pool_strength : hint_range(0.0, 1.0) = 0.30;
uniform float pool_width : hint_range(0.05, 2.0) = 0.55;
uniform vec3 pool_dir = vec3(0.0, 0.06, -1.0);

void sky() {
	float y = EYEDIR.y;
	float up = pow(clamp(y / horizon_spread, 0.0, 1.0), top_falloff);
	float down = pow(clamp(-y / horizon_spread, 0.0, 1.0), top_falloff);
	vec3 c = horizon_color.rgb;
	c = mix(c, top_color.rgb, up);
	c = mix(c, bottom_color.rgb, down);

	// the soft glow behind the group: a broad lobe, not a lamp
	float d = dot(normalize(EYEDIR), normalize(pool_dir));
	float lobe = pow(clamp(d, 0.0, 1.0), 1.0 / max(pool_width, 0.001));
	c += horizon_color.rgb * lobe * pool_strength;

	COLOR = c;
}
