// BorderStorm ring: a flat ring of see-through red TV static (white noise)
// lying on the floor just outside the edge of the circle, so the whole ring is
// in the storm. Its inner edge is exactly where the storm starts to hurt the
// player. Used by the StormRing in scn/game/border_storm.tscn.
//
// The ring follows the circle by itself: it reads the global shader settings
// storm_centre and storm_radius (Project Settings > Shader Globals), which
// scripts/game/border_storm.gd sets every frame. The mesh is a ring built once
// by that script with radius 1; this shader moves its points to the circle
// every frame, so the width stays `ring_width` meters at any radius and no
// mesh is rebuilt while the circle changes.
//
// ring_alpha and ring_width are set from the BorderStorm's Inspector settings,
// so change them on the BorderStorm node. The static's settings below are on
// the material: open scn/game/border_storm.tscn, select StormRing and look under
// Mesh > Material > Shader Parameters.
//
// The static is worked out in screen pixels, so its dots stay the same size
// however big the circle is.
shader_type spatial;
// Unshaded and see-through. world_vertex_coords: vertex() works in world
// meters. depth_draw_never: it does not hide what is under it.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, world_vertex_coords;

global uniform vec2 storm_centre;
global uniform float storm_radius;

// Set by border_storm.gd. How see-through the ring is: 0 invisible, 1 solid.
uniform float ring_alpha : hint_range(0.0, 1.0) = 1.0;
// Set by border_storm.gd. Width of the ring in meters, outwards from the edge.
uniform float ring_width = 1.0;
// Colour of the brightest dots. Darker dots are darker shades of it.
uniform vec3 ring_colour : source_color = vec3(1.0, 0.0, 0.0);
// Size of one dot of static, in screen pixels.
uniform float static_size = 2.0;
// How many times a second the static changes.
uniform float static_fps = 30.0;
// Darkest and brightest dots (0 = black, 1 = ring_colour).
uniform float static_min : hint_range(0.0, 1.0) = 0.0;
uniform float static_max : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	// The mesh's points lie on a circle of radius 1 around the node; UV.x is 0
	// for the inner edge and 1 for the outer edge.
	vec2 direction = normalize(VERTEX.xz - NODE_POSITION_WORLD.xz);
	float distance_from_centre = storm_radius + UV.x * ring_width;
	VERTEX.xz = storm_centre + direction * distance_from_centre;
}

// A random number from 0 to 1 for each point.
float random(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// One random brightness per dot, changing static_fps times a second.
	// (mod keeps the numbers small so the randomness stays good.)
	float frame = mod(floor(TIME * static_fps), 97.0);
	float noise = random(floor(FRAGCOORD.xy / max(static_size, 1.0)) + frame * vec2(13.7, 7.3));
	ALBEDO = ring_colour * mix(static_min, static_max, noise);
	ALPHA = ring_alpha;
}
