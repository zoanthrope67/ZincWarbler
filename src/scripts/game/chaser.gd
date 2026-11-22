class_name Chaser
extends Enemy
## Chaser: picks a heading towards the player when it appears, then moves in a
## straight line.
##
## When it runs into a wall it checks whether it has a clear path to the player,
## by sweeping a sphere its own size towards them (checking walls only):
##   - clear path:   it turns to face the player
##   - path blocked: it turns around (180 degrees)
## Running into the player does not change its heading; it just pushes against them.

## Movement speed in meters per second.
const SPEED := 2.0
## How far the path check starts back from the wall it hit, in meters. A sweep
## that starts touching a wall can report "blocked" straight away.
const PATH_CHECK_BACKOFF := 0.05

## The direction the Chaser is moving in.
var heading := Vector3.RIGHT

var _path_check_shape := SphereShape3D.new()


func _on_activated() -> void:
	_path_check_shape.radius = body_radius
	var towards_player := direction_to_target()
	if towards_player != Vector3.ZERO:
		heading = towards_player
	face(heading)


func _active_physics_process(delta: float) -> void:
	var collision := move_and_collide(heading * SPEED * delta)
	if collision != null and is_wall(collision):
		if has_clear_path_to_target(collision.get_normal()):
			heading = direction_to_target()
		else:
			heading = -heading
	face(heading)


## True if a sphere the Chaser's size could travel straight to the target
## without touching a wall. `wall_normal` points away from the wall just hit.
func has_clear_path_to_target(wall_normal := Vector3.ZERO) -> bool:
	var start := global_position + Gameplay.on_plane(wall_normal).normalized() * PATH_CHECK_BACKOFF
	start.y = Gameplay.PLANE_HEIGHT
	var motion := get_target_position() - start
	motion.y = 0.0
	if motion.length() < 0.05:
		return true

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _path_check_shape
	query.transform = Transform3D(Basis.IDENTITY, start)
	query.motion = motion
	query.collision_mask = Gameplay.LAYER_WALLS
	# cast_motion returns how far along `motion` the sphere can travel safely
	# (1.0 = all the way).
	var result := get_world_3d().direct_space_state.cast_motion(query)
	return result[0] >= 1.0
