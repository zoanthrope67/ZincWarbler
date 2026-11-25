// BorderStorm floor colours: shared code for any floor shader (docs/SPEC.md,
// BorderStorm). Only the floor shows the storm; nothing else changes.
//
// Inside the circle the floor keeps its colours. In the storm (outside the
// circle) the colours are shifted: green becomes red, red becomes blue and
// blue becomes green. Black, white and greys do not change.
//
// To use it in a floor shader:
//   1. Under `shader_type spatial;` add:
//        #include "res://gfx/shaders/storm_floor.gdshaderinc"
//   2. Work out the floor's flat world position in vertex() (see world_xz in
//      gfx/placeholder/placeholder_noise_colour_floor.gdshader).
//   3. At the end of fragment(), pass the final colour through it:
//        ALBEDO = storm_floor_colour(my_colour, world_xz);
//
// storm_centre and storm_radius are global shader settings (Project Settings >
// Shader Globals). scripts/game/border_storm.gd sets them every frame while a
// game is running. Their default radius is huge, so outside a game (e.g. in the
// editor) the whole floor shows its normal colours.

global uniform vec2 storm_centre;
global uniform float storm_radius;

// `colour` with the storm's colour shift applied if `world_xz` (a flat X/Z
// world position) is in the storm.
vec3 storm_floor_colour(vec3 colour, vec2 world_xz) {
	float d = distance(world_xz, storm_centre) - storm_radius;
	// fwidth = how much d changes across one pixel. The edge is blended over
	// just that one pixel so it is hard but not jagged.
	float aa = max(fwidth(d), 0.0001);
	float in_storm = smoothstep(-0.5 * aa, 0.5 * aa, d);
	// The new red is the old green, the new green is the old blue and the new
	// blue is the old red.
	vec3 shifted = colour.gbr;
	return mix(colour, shifted, in_storm);
}
