class_name FollowCamera
extends Camera3D
## Perspective camera looking straight down, centred on a target (the player).
##
## The camera height is worked out so that exactly `view_height_meters` of the
## gameplay plane fit from the top of the screen to the bottom. Wider screens
## see more to the sides; the vertical view is always the same.
## It is allowed to show beyond the edge of the arena (docs/SPEC.md, Camera).

## Meters of the gameplay plane visible from the top to the bottom of the screen.
@export var view_height_meters := 40.0
## Vertical field of view in degrees. Lower values look flatter (less
## perspective) and put the camera higher up.
@export_range(10.0, 120.0) var field_of_view_degrees := 50.0

## The node to follow. Set by the In Game scene.
var target: Node3D = null


func _ready() -> void:
	# Look straight down, with -Z at the top of the screen.
	rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	keep_aspect = Camera3D.KEEP_HEIGHT
	fov = field_of_view_degrees
	# Follow after the player has moved this physics frame.
	process_physics_priority = 10


func _physics_process(_delta: float) -> void:
	_follow()


## Jumps straight to the target without smoothing (used when a game starts).
func snap_to_target() -> void:
	_follow()
	reset_physics_interpolation()


## Height above the gameplay plane needed to show `view_height_meters`.
func get_height_above_plane() -> float:
	return (view_height_meters * 0.5) / tan(deg_to_rad(fov) * 0.5)


func _follow() -> void:
	if target == null or not is_instance_valid(target):
		return
	fov = field_of_view_degrees
	var point := target.global_position
	global_position = Vector3(point.x, Gameplay.PLANE_HEIGHT + get_height_above_plane(), point.z)
