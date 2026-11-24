// BorderStorm overlay: darkens everything outside the circle and draws a ring
// on the border. Used by the StormOverlay plane in scn/game/border_storm.tscn.
//
// The plane lies on the gameplay plane, under the camera, and is drawn last and
// on top of everything (it ignores depth). Each pixel works out its flat X/Z
// position in the world and its distance from the circle's edge:
//   less than 0 = inside the circle, more than 0 = in the storm.
//
// The circle and colours are set from scripts/game/border_storm.gd every frame,
// so change them on the BorderStorm node in the Inspector, not here.
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, blend_mix, shadows_disabled;

// Set by border_storm.gd.
uniform vec2 centre = vec2(0.0, 0.0);
uniform float radius = 100.0;
uniform float storm_alpha : hint_range(0.0, 1.0) = 0.5;
uniform vec3 storm_color : source_color = vec3(0.08, 0.06, 0.12);
uniform vec3 ring_color : source_color = vec3(1.0, 0.1, 0.1);
uniform float ring_width = 0.6;
uniform float cloud_speed = 1.0;

// Set in the scene.
// Seamless noise used for the drifting clouds.
uniform sampler2D clouds : repeat_enable, filter_linear_mipmap, hint_default_white;
// How big the cloud shapes are: larger numbers give smaller clouds.
uniform float cloud_scale = 0.02;
// How much the clouds lighten and darken the storm colour.
uniform float cloud_strength = 1.0;
// Meters over which the storm fades in just outside the ring.
uniform float edge_softness = 1.5;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float d = distance(world_xz, centre) - radius;
	// fwidth = how much d changes across one pixel; used to keep the ring's edges smooth.
	float aa = max(fwidth(d), 0.0001);

	float outside = smoothstep(0.0, edge_softness, d);
	float half_width = ring_width * 0.5;
	float ring = 1.0 - smoothstep(half_width - aa, half_width + aa, abs(d));

	// Two layers of noise drifting in different directions make the clouds.
	float t = TIME * cloud_speed;
	float a = texture(clouds, world_xz * cloud_scale + t * vec2(0.010, 0.004)).r;
	float b = texture(clouds, world_xz * cloud_scale * 2.3 - t * vec2(0.006, 0.012)).r;
	vec3 storm = storm_color * mix(1.0, 0.4 + 1.6 * a * b, cloud_strength);

	ALBEDO = mix(storm, ring_color, ring);
	ALPHA = max(outside * storm_alpha, ring);
}
