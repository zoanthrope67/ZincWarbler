class_name BorderStorm
extends Node3D
## The BorderStorm (docs/SPEC.md, BorderStorm): a circle the player should stay
## inside. Everything outside the circle is "the storm".
##
## - The circle's centre is this node's position. It starts where the node is
##   placed in scn/game/arena.tscn (the middle of the arena).
## - It moves at `storm_movement_speed` towards a random uncollected flag. A new
##   random flag is chosen each time a flag is collected. While a boss is in
##   play it moves towards the boss instead. When a boss is defeated it goes
##   back to flags. It stops when it reaches its target.
## - `current_radius` grows or shrinks smoothly towards `target_radius`.
##   To add a time limit, lower `target_radius` (or change it from other code
##   during play). It never goes below MIN_RADIUS.
## - If the player stays in the storm for DAMAGE_DELAY_SECONDS, they lose 1
##   health every frame while they stay there. The player's invulnerability
##   after each hit means this is one hit every few seconds in practice.
##   Going back inside the circle resets the timer.
## - Enemies, bullets and flags are not affected by the storm.
##
## All distances are measured flat, on X and Z only.
##
## Looks (see docs/DESIGNER_GUIDE.md, BorderStorm):
## - The floor in the storm has its colours shifted (green to red, red to blue,
##   blue to green). Only the floor changes. This script passes the circle to
##   the floor's shader through the global shader settings `storm_centre` and
##   `storm_radius` (shader code: gfx/shaders/storm_floor.gdshaderinc).
## - The StormRing child is a flat ring of red static lying on the floor just
##   outside the edge (so it is in the storm), `ring_width` meters wide. Its
##   shader (gfx/shaders/storm_ring.gdshader) fits it to the circle every frame
##   from the same global shader settings; this script only builds its mesh once.
## - The HUD's DANGER warning reads get_danger_progress().

# --- FX signals (effects and sounds only; never used for game logic) -------
## The player has gone outside the circle, into the storm.
signal fx_player_entered_storm
## The player has come back inside the circle, out of the storm.
signal fx_player_left_storm

## Seconds the player can stay in the storm before it starts hurting them.
const DAMAGE_DELAY_SECONDS := 3.0
## The radius never goes below this, in meters (a safety minimum).
const MIN_RADIUS := 0.01

## The global shader settings this script sets (Project Settings > Shader Globals).
const SHADER_CENTRE := &"storm_centre"
const SHADER_RADIUS := &"storm_radius"
## The radius given to the floor shader when no storm is running, so the whole
## floor shows its normal colours. Matches the default in Shader Globals.
const NO_STORM_RADIUS := 1000000.0
## How many straight pieces the StormRing is made of. 256 keeps it within about
## 1 cm of a true circle at a 100 m radius.
const RING_SEGMENTS := 256
## How far above the floor the StormRing lies, in meters (just enough that the
## floor does not flicker through it).
const RING_LIFT := 0.01

@export_group("Radius")
## The radius of the circle in meters. This is the starting radius; it then
## changes during play, moving towards `target_radius`.
@export var current_radius := 100.0
## The radius the circle grows or shrinks towards, in meters.
@export var target_radius := 5.0
## How fast the radius grows when `target_radius` is larger, in meters per second.
@export var radius_grow_speed := 1.0
## How fast the radius shrinks when `target_radius` is smaller, in meters per second.
@export var radius_shrink_speed := 0.025

@export_group("Movement")
## How fast the circle moves towards its target (a flag or the boss), in meters per second.
@export var storm_movement_speed := 0.5

@export_group("Looks")
## How see-through the StormRing is: 0 invisible, 1 solid.
@export_range(0.0, 1.0) var ring_alpha := 1.0
## Width of the StormRing in meters, from the edge of the circle outwards.
@export var ring_width := 1.0

## True while the player is in the storm (outside the circle).
var player_in_storm := false

var _player: Player = null
var _flag_loop: FlagLoop = null
var _flags: Array[Flag] = []
## What the circle is moving towards: a flag, the boss, or null (stay put).
var _target: Node3D = null
var _time_in_storm := 0.0
# The radius at the previous physics frame, so the drawing can blend smoothly
# between physics frames on fast screens.
var _previous_radius := 0.0

@onready var _ring: MeshInstance3D = $StormRing
@onready var _ring_material: ShaderMaterial = _ring.material_override


func _ready() -> void:
	current_radius = maxf(current_radius, MIN_RADIUS)
	_previous_radius = current_radius
	# The ring's shader places it in the world itself (from the shader globals),
	# so the node stays still at the world origin, just above the floor.
	_ring.top_level = true
	_ring.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_ring.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, global_position.y + RING_LIFT, 0.0))
	_ring.mesh = _build_ring_mesh()
	# The shader moves the ring anywhere, so Godot cannot tell where it is from
	# the mesh. A huge box stops it being skipped as "off screen" by mistake.
	_ring.custom_aabb = AABB(Vector3(-1e6, -1.0, -1e6), Vector3(2e6, 2.0, 2e6))
	_update_looks()


func _exit_tree() -> void:
	# The shader globals outlive this node: put the floor back to normal.
	RenderingServer.global_shader_parameter_set(SHADER_RADIUS, NO_STORM_RADIUS)


## Connects the storm to the game. Called by the In Game scene. Until this is
## called the storm does nothing.
func setup(player: Player, flag_loop: FlagLoop, flags: Array[Flag]) -> void:
	_player = player
	_flag_loop = flag_loop
	_flags = flags
	_flag_loop.flag_collected.connect(func(_flag: Flag) -> void: _choose_target())
	_flag_loop.boss_spawned.connect(func(_boss: Enemy) -> void: _choose_target())
	_flag_loop.flags_restored.connect(_choose_target)
	_choose_target()


## True if `point` is outside the circle (in the storm). Measured flat.
func is_in_storm(point: Vector3) -> bool:
	return _flat_distance(point, global_position) > current_radius


## How close the storm is to hurting the player, from 0 to 1: 0 when the player
## is inside the circle (or has just gone out), 1 once they have been in the
## storm for DAMAGE_DELAY_SECONDS (it stays 1 while the storm hurts them).
## Used by the HUD's DANGER bar.
func get_danger_progress() -> float:
	if not player_in_storm:
		return 0.0
	return clampf(_time_in_storm / DAMAGE_DELAY_SECONDS, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_previous_radius = current_radius
	_update_radius(delta)
	_move_towards_target(delta)
	_hurt_player_in_storm(delta)


func _process(_delta: float) -> void:
	_update_looks()


# --- Radius ----------------------------------------------------------------

func _update_radius(delta: float) -> void:
	var goal := maxf(target_radius, MIN_RADIUS)
	if current_radius < goal:
		current_radius = minf(current_radius + (radius_grow_speed * delta), goal)
	elif current_radius > goal:
		current_radius = maxf(current_radius - (radius_shrink_speed * delta), goal)
	current_radius = maxf(current_radius, MIN_RADIUS)


# --- Movement --------------------------------------------------------------

# Picks what to move towards: the boss if there is one, otherwise a random
# uncollected flag. With neither, the circle stays where it is.
func _choose_target() -> void:
	if _flag_loop.current_boss != null and is_instance_valid(_flag_loop.current_boss):
		_target = _flag_loop.current_boss
		return
	var uncollected := _flags.filter(func(f: Flag) -> bool: return f.is_active)
	_target = uncollected.pick_random() if not uncollected.is_empty() else null


func _move_towards_target(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var here := Vector2(global_position.x, global_position.z)
	var there := Vector2(_target.global_position.x, _target.global_position.z)
	here = here.move_toward(there, storm_movement_speed * delta)
	global_position = Vector3(here.x, global_position.y, here.y)


# --- Hurting the player ------------------------------------------------------

func _hurt_player_in_storm(delta: float) -> void:
	if _player.is_dead:
		return
	var in_storm := is_in_storm(_player.global_position)
	if in_storm != player_in_storm:
		player_in_storm = in_storm
		_time_in_storm = 0.0
		if in_storm:
			fx_player_entered_storm.emit()
		else:
			fx_player_left_storm.emit()
	if not in_storm:
		return
	_time_in_storm += delta
	if _time_in_storm >= DAMAGE_DELAY_SECONDS:
		# Does nothing while the player is invulnerable.
		_player.take_damage()


# --- Looks -------------------------------------------------------------------

# Passes the circle to the floor and ring shaders, and the Inspector settings to
# the ring.
func _update_looks() -> void:
	# Blend between physics frames so the edge moves smoothly on fast screens.
	var centre := get_global_transform_interpolated().origin
	var radius := lerpf(_previous_radius, current_radius, Engine.get_physics_interpolation_fraction())
	RenderingServer.global_shader_parameter_set(SHADER_CENTRE, Vector2(centre.x, centre.z))
	RenderingServer.global_shader_parameter_set(SHADER_RADIUS, radius)
	_ring_material.set_shader_parameter(&"ring_alpha", ring_alpha)
	_ring_material.set_shader_parameter(&"ring_width", maxf(ring_width, 0.0))


# A flat ring of radius 1 around the origin, made of RING_SEGMENTS pieces. Each
# piece joins two points on the inner edge (UV.x = 0) and two on the outer edge
# (UV.x = 1). The shader (storm_ring.gdshader) moves the points to the storm's
# circle every frame, so the mesh is only built once.
func _build_ring_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in RING_SEGMENTS + 1:
		var angle := TAU * i / RING_SEGMENTS
		var point := Vector3(cos(angle), 0.0, sin(angle))
		vertices.append(point)
		uvs.append(Vector2(0.0, 0.0))
		vertices.append(point)
		uvs.append(Vector2(1.0, 0.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	return mesh


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
