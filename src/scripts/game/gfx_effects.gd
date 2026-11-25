class_name GfxEffects
## Graphical effects that any script can use. Effects only: never use these
## for game logic.
##
## apply_gfx_material(model, material, effect_seconds)
##   Shows `material` on every mesh under `model` for `effect_seconds`, then puts
##   the model's own look back. For example, the hit flash in
##   scripts/game/enemy/enemy.gd:
##       GfxEffects.apply_gfx_material(_model, hit_flash_material, 0.1)
##
##   - Calling it again on the same model replaces the effect that is showing.
##     The old one is cancelled: when the new one ends the model goes back to
##     normal, not back to the old effect.
##   - A null material, or 0 seconds, removes any effect that is showing.
##   - A negative, infinite or NaN `effect_seconds` is a mistake: it logs a
##     warning and does nothing.
##   - The timer is game time: it stops while the game is paused.
##   - Every mesh under the model is covered, including the meshes inside an
##     imported .glb. Each mesh's Material Override is replaced while the effect
##     shows (this takes priority over all of its other materials) and restored
##     afterwards.
##   - If the model is freed while an effect is showing (e.g. the enemy is
##     defeated), the effect simply ends with it.
##
## One material can be shared by any number of models at once (that is cheap).
## Change its colours in the Inspector, not from code, or every model using it
## changes too.

# Metadata key on a model that holds its current effect (see apply_gfx_material).
const _EFFECT_META := &"gfx_material_effect"

# Gives every effect a different number, so a timer can tell whether the effect
# it was started for has since been replaced.
static var _next_effect_id := 1


## Shows `material` on `model` for `effect_seconds` (see the top of this file).
static func apply_gfx_material(model: Node3D, material: ShaderMaterial, effect_seconds: float) -> void:
	if is_nan(effect_seconds) or is_inf(effect_seconds) or effect_seconds < 0.0:
		push_warning("GfxEffects.apply_gfx_material: effect_seconds must be 0 or more, got %s. Nothing was changed." % effect_seconds)
		return
	if model == null or not is_instance_valid(model):
		push_warning("GfxEffects.apply_gfx_material: the model is null or has been freed. Nothing was changed.")
		return

	# Replacing or removing: take off the effect that is showing first.
	_remove_effect(model)
	if material == null or effect_seconds == 0.0:
		return
	if not model.is_inside_tree():
		push_warning("GfxEffects.apply_gfx_material: '%s' is not in the scene tree, so the effect cannot be timed. Nothing was changed." % model.name)
		return

	# Swap in the material, remembering each mesh's own Material Override.
	var saved: Array[Dictionary] = []
	for mesh in _meshes_under(model):
		saved.append({"mesh": mesh, "override": mesh.material_override})
		mesh.material_override = material
	var effect_id := _next_effect_id
	_next_effect_id += 1
	model.set_meta(_EFFECT_META, {"id": effect_id, "saved": saved})

	# A game-time timer: process_always = false makes it stop while the game is
	# paused, and process_in_physics = true keeps it in step with gameplay.
	var timer := model.get_tree().create_timer(effect_seconds, false, true)
	# Only the model's ID is kept, not the model, so a freed model is not an error.
	var model_id := model.get_instance_id()
	timer.timeout.connect(func() -> void: _end_effect(model_id, effect_id))


# Called when an effect's time is up. Does nothing if the model has been freed,
# or if a newer effect has replaced this one.
static func _end_effect(model_id: int, effect_id: int) -> void:
	var model := instance_from_id(model_id) as Node3D
	if model == null:
		return
	var effect: Dictionary = model.get_meta(_EFFECT_META, {})
	if effect.get("id", 0) == effect_id:
		_remove_effect(model)


# Puts back every mesh's own Material Override and forgets the effect.
static func _remove_effect(model: Node3D) -> void:
	if not model.has_meta(_EFFECT_META):
		return
	var effect: Dictionary = model.get_meta(_EFFECT_META)
	for entry in effect["saved"]:
		# Left untyped: a mesh freed since the effect started cannot be stored
		# in a typed variable.
		var mesh = entry["mesh"]
		if is_instance_valid(mesh):
			mesh.material_override = entry["override"]
	model.remove_meta(_EFFECT_META)


# Every visible mesh (GeometryInstance3D) under `node`, including `node` itself.
static func _meshes_under(node: Node) -> Array[GeometryInstance3D]:
	var meshes: Array[GeometryInstance3D] = []
	if node is GeometryInstance3D:
		meshes.append(node)
	for child in node.get_children():
		meshes.append_array(_meshes_under(child))
	return meshes
