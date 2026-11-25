// Placeholder hit flash: draws the whole model in one flat colour (red by
// default). Enemies show it for a moment when hit, through
// GfxEffects.apply_gfx_material() (scripts/game/gfx_effects.gd).
// Listed in docs/asset_tracking.txt.
//
// Used through the material gfx/placeholder/placeholder_hit_flash.tres. Change
// the colour there: select the .tres and open Shader Parameters in the Inspector.
shader_type spatial;
// Unshaded: lights and the sky do not change the colour, so it always reads clearly.
render_mode unshaded, shadows_disabled;

// The colour of the flash.
uniform vec3 flash_color : source_color = vec3(1.0, 0.0, 0.0);

void fragment() {
	ALBEDO = flash_color;
}
