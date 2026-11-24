// BorderStorm overlay: everything outside the circle is shown in greyscale
// with TV static (white noise) over it. Used by the StormOverlay plane in
// scn/game/border_storm.tscn.
//
// The plane lies on the gameplay plane, under the camera, and is drawn last and
// on top of everything (it ignores depth). Each pixel works out its flat X/Z
// position in the world and its distance from the circle's edge:
//   less than 0 = inside the circle, more than 0 = in the storm.
// The storm has a hard edge exactly at the radius, where it starts to hurt the
// player (BorderStorm.is_in_storm uses the same distance).
// In the storm it reads what is already on screen under it (the screen
// texture), turns that grey, and mixes the static over it by `storm_alpha`.
//
// The circle and alpha are set from scripts/game/border_storm.gd every frame,
// so change them on the BorderStorm node in the Inspector, not here.
//
// Cost: one copy of the screen per frame (Godot makes it for the screen
// texture), then one texture read and a little maths per pixel.
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, blend_mix, shadows_disabled;

// Set by border_storm.gd.
uniform vec2 centre = vec2(0.0, 0.0);
uniform float radius = 100.0;
uniform float storm_alpha : hint_range(0.0, 1.0) = 0.5;

// Set in the scene.
// What has been drawn on screen so far (everything under the storm).
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
// Size of one dot of static, in screen pixels.
uniform float static_size = 2.0;
// How many times per second the static changes.
uniform float static_fps = 30.0;
// Darkest and brightest dots of static (0 = black, 1 = white).
uniform float static_min : hint_range(0.0, 1.0) = 0.0;
uniform float static_max : hint_range(0.0, 1.0) = 1.0;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

// A random number from 0 to 1 for each point.
float random(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float d = distance(world_xz, centre) - radius;
	// fwidth = how much d changes across one pixel. The edge is blended over
	// just that one pixel so it is hard but not jagged.
	float aa = max(fwidth(d), 0.0001);
	float in_storm = smoothstep(-0.5 * aa, 0.5 * aa, d);

	// The scene under the storm, in grey.
	vec3 scene = texture(screen_texture, SCREEN_UV).rgb;
	float grey = dot(scene, vec3(0.299, 0.587, 0.114));

	// Static: one random grey per dot, changing static_fps times a second.
	// (mod keeps the numbers small so the randomness stays good.)
	float frame = mod(floor(TIME * static_fps), 97.0);
	float noise = random(floor(FRAGCOORD.xy / static_size) + frame * vec2(13.7, 7.3));
	float static_value = mix(static_min, static_max, noise);

	ALBEDO = vec3(mix(grey, static_value, storm_alpha));
	ALPHA = in_storm;
}
