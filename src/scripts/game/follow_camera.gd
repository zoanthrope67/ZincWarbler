class_name FollowCamera
extends Camera3D
## Perspective camera looking down at a target (the player), keeping it in the
## middle of the screen.
##
## The camera's distance from the target is worked out so that, when looking
## straight down, exactly `view_height_meters` of the gameplay plane fit from
## the top of the screen to the bottom. Wider screens see more to the sides; the
## vertical view is always the same.
## It is allowed to show beyond the edge of the arena (docs/SPEC.md, Camera).
##
## `tilt_degrees` leans the camera back towards the bottom of the screen, so the
## arena is seen at an angle. `turn_degrees` then swings the camera around the
## target (like walking around it). The camera always stays the same distance
## from the target, so the player stays in the middle and the same size on screen.
##
## With `turn_degrees` at 0, -Z is towards the top of the screen and the
## controls match the screen. Any other turn rotates the arena on screen but NOT
## the controls (Up still moves the player along -Z), so they will feel rotated.
##
## The settings are read every physics frame, so they can be changed in the
## remote Inspector while the game is running.

## Meters of the gameplay plane visible from the top to the bottom of the screen
## when the camera looks straight down. With a tilt, the top of the screen
## shows more than this and the bottom less.
@export var view_height_meters := 40.0
## Vertical field of view in degrees. Lower values look flatter (less
## perspective) and put the camera further away.
@export_range(10.0, 120.0) var field_of_view_degrees := 50.0
## How far the camera leans back from straight down, in degrees.
## 0 = straight down (docs/SPEC.md). Higher values show the arena more from
## the side. Above about 40 the top of the screen can reach past the camera's
## Far distance (Camera node, Far, 200 m) and the floor will be cut off.
@export_range(0.0, 80.0) var tilt_degrees := 0.0
## How far the camera swings around the target, in degrees. 0 = from the
## bottom of the screen (-Z at the top). Positive values swing it anticlockwise
## seen from above, so the arena turns clockwise on screen: at 90 the arena's
## right side (+X) is at the bottom of the screen. The controls do not turn
## with it.
@export_range(-180.0, 180.0) var turn_degrees := 0.0

## The node to follow. Set by the In Game scene.
var target: Node3D = null


func _ready() -> void:
	keep_aspect = Camera3D.KEEP_HEIGHT
	_apply_angle_and_fov()
	# Follow after the player has moved this physics frame.
	process_physics_priority = 10


func _physics_process(_delta: float) -> void:
	_follow()


## Jumps straight to the target without smoothing (used when a game starts).
func snap_to_target() -> void:
	_follow()
	reset_physics_interpolation()


## Distance from the camera to the target that shows `view_height_meters`
## when looking straight down.
func get_distance_to_target() -> float:
	return (view_height_meters * 0.5) / tan(deg_to_rad(fov) * 0.5)


# Points the camera: straight down (-90 degrees around X) leaned back by
# `tilt_degrees`, then swung around the vertical (Y) axis by `turn_degrees`.
# (Godot applies the Y rotation first, then X, so the turn is always around
# the vertical axis whatever the tilt.)
func _apply_angle_and_fov() -> void:
	fov = field_of_view_degrees
	rotation_degrees = Vector3(-90.0 + tilt_degrees, turn_degrees, 0.0)


func _follow() -> void:
	if target == null or not is_instance_valid(target):
		return
	_apply_angle_and_fov()
	# The point on the gameplay plane the camera looks at: under the target.
	var point := target.global_position
	var look_at_point := Vector3(point.x, Gameplay.PLANE_HEIGHT, point.z)
	# basis.z points backwards out of the camera, so stepping along it from the
	# look-at point puts the camera where it looks straight at that point.
	global_position = look_at_point + global_basis.z * get_distance_to_target()
