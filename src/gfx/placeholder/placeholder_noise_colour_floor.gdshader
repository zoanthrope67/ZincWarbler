// Placeholder floor: a straight grid whose lines slowly shift between two
// colours in drifting patches, using Perlin noise. Used by the PlaceholderFloor
// plane in scn/game/arena.tscn (docs/asset_tracking.txt).
//
// The grid and the noise are measured in world meters, so they stay fixed to
// the floor wherever the plane is and however big it is.
//
// Change the settings by selecting PlaceholderFloor in scn/game/arena.tscn and
// opening Mesh > Material > Shader Parameters in the Inspector.
shader_type spatial;
// Unshaded: the floor ignores lights and the sky, it is always these colours.
render_mode unshaded, shadows_disabled;

// Colour of the floor between the lines.
uniform vec3 base_color : source_color = vec3(0.84, 0.66, 0.37);
// The two colours the grid lines shift between.
uniform vec3 line_color : source_color = vec3(0.143, 0.137, 0.150);
uniform vec3 line_color_2 : source_color = vec3(0.55, 0.12, 0.10);
// Size of one grid square in meters. 4 matches the wall tiles.
uniform float cell_size = 1.0;
// Width of the grid lines in meters.
uniform float line_width = 0.1;

// Size of the colour patches in meters. Larger numbers give bigger patches.
uniform float noise_size = 10.0;
// How fast the patches drift and change shape, in meters per second. 0 freezes them.
uniform float noise_speed = 1.0;
// How sharp the change between the two colours is. 1 is a soft blend;
// higher numbers give harder-edged patches.
uniform float colour_contrast = 1.5;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

// A random direction for each corner of the noise grid.
vec2 corner_gradient(vec2 corner) {
	float angle = fract(sin(dot(corner, vec2(127.1, 311.7))) * 43758.5453) * TAU;
	return vec2(cos(angle), sin(angle));
}

// Classic 2D Perlin (gradient) noise. Smooth hills and valleys, roughly -0.7 to 0.7,
// with one hill or valley per unit of `p`.
float perlin(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	// Perlin's smooth fade curve, so the noise has no visible creases.
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(corner_gradient(cell), f);
	float b = dot(corner_gradient(cell + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(corner_gradient(cell + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(corner_gradient(cell + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	// Distance in meters to the nearest grid line, along X and along Z.
	vec2 to_line = abs(fract(world_xz / cell_size - 0.5) - 0.5) * cell_size;
	// fwidth = how far the world position changes across one pixel; used to
	// keep the lines' edges smooth at any screen size.
	vec2 aa = fwidth(world_xz);
	float half_width = line_width * 0.5;
	vec2 lines = 1.0 - smoothstep(vec2(half_width) - aa, vec2(half_width) + aa, to_line);
	float line = max(lines.x, lines.y);

	// Two noise layers drifting in different directions, averaged, so the
	// patches change shape as they move instead of just sliding.
	float drift = TIME * noise_speed;
	float n = 0.5 * (
		perlin((world_xz + vec2(drift, 0.0)) / noise_size)
		+ perlin((world_xz + vec2(17.3, 41.9) - vec2(0.0, drift)) / noise_size)
	);
	// Turn the noise (about -0.5 to 0.5 here) into 0..1: 0 = line_color, 1 = line_color_2.
	float shift = clamp(0.5 + n * colour_contrast * 2.0, 0.0, 1.0);
	vec3 lines_colour = mix(line_color, line_color_2, shift);

	ALBEDO = mix(base_color, lines_colour, line);
}
