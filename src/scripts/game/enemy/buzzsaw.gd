class_name Buzzsaw
extends Enemy
## Buzzsaw: aims at the player once, when it appears (at the end of its fade-in),
## then moves in a straight line and never aims again.
##
## When it runs into a wall it bounces off like a ball off a cushion: the angle it
## leaves the wall at mirrors the angle it hit it at (worked out from the wall's
## collision normal, the direction pointing straight out of the wall). Its speed
## does not change.
##
## Running into the player does not change its heading; it just pushes against
## them.

## Movement speed in meters per second.
const SPEED := 16.0
## The most walls it can bounce off in one physics frame. Two covers an inside
## corner (one wall, then the wall next to it). After that it carries on next frame.
const MAX_BOUNCES_PER_FRAME := 2

## The direction the Buzzsaw is moving in (on the gameplay plane, length 1).
var heading := Vector3.RIGHT


func _on_activated() -> void:
	var towards_player := direction_to_target()
	if towards_player != Vector3.ZERO:
		heading = towards_player
	face(heading)


func _active_physics_process(delta: float) -> void:
	# Pressed against the player and heading into them: it cannot get any
	# closer, so skip the move (it still faces and hurts the player).
	if is_pushing_into_player(heading):
		face(heading)
		return

	var distance_left := SPEED * delta
	for i in MAX_BOUNCES_PER_FRAME:
		var collision := move_and_collide(heading * distance_left)
		if collision == null or not is_wall(collision):
			break
		bounce_off_wall(collision.get_normal())
		# Use up the rest of this frame's movement in the new direction, so a
		# bounce does not slow the Buzzsaw down.
		distance_left = collision.get_remainder().length()
		if distance_left < 0.0001:
			break
	face(heading)


## Mirrors the heading off a wall. `wall_normal` points straight out of the wall.
## Does nothing if the Buzzsaw is not moving into the wall.
func bounce_off_wall(wall_normal: Vector3) -> void:
	# Only the flat part of the normal counts: the Buzzsaw stays on the plane.
	wall_normal.y = 0.0
	if wall_normal.length_squared() < 0.000001:
		return
	wall_normal = wall_normal.normalized()
	if heading.dot(wall_normal) >= 0.0:
		return
	heading = heading.bounce(wall_normal)
	heading.y = 0.0
	heading = heading.normalized()
