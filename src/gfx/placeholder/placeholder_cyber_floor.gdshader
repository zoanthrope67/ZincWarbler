// Placeholder "cyber" floor: a dark blue surface with glowing blue grid lines
// and a slow pulse rippling outwards. Used by the PlaceholderFloor plane in
// scn/game/arena.tscn (docs/asset_tracking.txt).
//
// The grid is drawn in world meters, so it stays lined up with the wall tiles
// wherever the plane is and however big it is.
//
// Change the settings by selecting PlaceholderFloor in scn/game/arena.tscn and
// opening Mesh > Material > Shader Parameters in the Inspector.
shader_type spatial;
// Unshaded: the floor ignores lights and the sky, it is always these colours.
render_mode unshaded, shadows_disabled;

// Colour of the floor between the lines.
uniform vec3 base_color : source_color = vec3(0.02, 0.04, 0.13);
// Colour of the grid lines.
uniform vec3 line_color : source_color = vec3(0.1, 0.45, 1.0);
// Size of one grid square in meters. 4 matches the wall tiles.
uniform float cell_size = 4.0;
// Width of the grid lines in meters.
uniform float line_width = 0.12;
// How much the pulse brightens and darkens the lines. 0 turns the pulse off.
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.4;
// How fast the pulse ripples outwards.
uniform float pulse_speed = 2.0;
// Meters between one pulse ring and the next.
uniform float pulse_spacing = 30.0;
// Where the pulse ripples out from (X and Z in the world). The arena's middle.
uniform vec2 pulse_centre = vec2(40.0, 30.0);

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
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

	// Rings of brightness moving outwards from pulse_centre.
	float wave = sin(TIME * pulse_speed - distance(world_xz, pulse_centre) * TAU / pulse_spacing);
	float pulse = 1.0 + pulse_strength * wave;

	ALBEDO = mix(base_color, line_color * pulse, line);
}
