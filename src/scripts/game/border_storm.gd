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
## Looks: the StormOverlay child draws the dark storm and the red ring with the
## shader gfx/shaders/border_storm.gdshader. Its colours and sizes are the
## Inspector settings below.

# --- FX signals (effects and sounds only; never used for game logic) -------
## The player has gone outside the circle, into the storm.
signal fx_player_entered_storm
## The player has come back inside the circle, out of the storm.
signal fx_player_left_storm

## Seconds the player can stay in the storm before it starts hurting them.
const DAMAGE_DELAY_SECONDS := 3.0
## The radius never goes below this, in meters (a safety minimum).
const MIN_RADIUS := 0.01

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
@export var storm_movement_speed := 4.0

@export_group("Looks")
## How see-through the storm is: 0 is invisible, 1 hides everything under it.
@export_range(0.0, 1.0) var storm_alpha := 0.6
## Colour of the storm.
@export var storm_color := Color(0.08, 0.06, 0.12)
## Colour of the ring drawn on the border.
@export var ring_color := Color(0.5, 0.1, 0.1)
## Width of the ring in meters.
@export var ring_width := 0.1
## How quickly the storm clouds drift. 0 stops them.
@export var cloud_speed := 1.0

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

@onready var _overlay: MeshInstance3D = $StormOverlay
@onready var _material: ShaderMaterial = _overlay.get_active_material(0)


func _ready() -> void:
	current_radius = maxf(current_radius, MIN_RADIUS)
	_previous_radius = current_radius
	# The overlay is placed in world space under the camera (see _process),
	# not relative to this node.
	_overlay.top_level = true
	_overlay.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_overlay.visible = true
	_update_looks()


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

# Keeps the overlay under the camera (so it always fills the screen) and passes
# the circle and the Inspector settings to the shader.
func _update_looks() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		_overlay.global_position = Vector3(camera.global_position.x, Gameplay.PLANE_HEIGHT, camera.global_position.z)
	else:
		_overlay.global_position = Vector3(global_position.x, Gameplay.PLANE_HEIGHT, global_position.z)

	# Blend between physics frames so the ring moves smoothly on fast screens.
	var centre := get_global_transform_interpolated().origin
	var radius := lerpf(_previous_radius, current_radius, Engine.get_physics_interpolation_fraction())
	_material.set_shader_parameter(&"centre", Vector2(centre.x, centre.z))
	_material.set_shader_parameter(&"radius", radius)
	_material.set_shader_parameter(&"storm_alpha", storm_alpha)
	_material.set_shader_parameter(&"storm_color", storm_color)
	_material.set_shader_parameter(&"ring_color", ring_color)
	_material.set_shader_parameter(&"ring_width", ring_width)
	_material.set_shader_parameter(&"cloud_speed", cloud_speed)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
