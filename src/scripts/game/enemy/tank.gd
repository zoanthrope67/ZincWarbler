class_name Tank
extends Enemy
## Tank: moves slowly straight towards the player, sliding along any wall in the
## way (no pathfinding), and fires an enemy bullet at the player every FIRE_INTERVAL.

## Movement speed in meters per second.
const SPEED := 1.0
## Seconds between shots. The first shot comes this long after the fade-in ends.
const FIRE_INTERVAL := 4.0
## Speed of the Tank's bullets in meters per second.
const BULLET_SPEED := EnemyBullet.DEFAULT_SPEED

var _time_until_shot := FIRE_INTERVAL


func _on_activated() -> void:
	_time_until_shot = FIRE_INTERVAL
	face(direction_to_target())


func _active_physics_process(delta: float) -> void:
	var direction := direction_to_target()
	# Once pressed against the player there is nowhere further to go.
	if not is_pushing_into_player(direction):
		move_sliding(direction * SPEED * delta)
	face(direction)

	_time_until_shot -= delta
	if _time_until_shot <= 0.0:
		_time_until_shot += FIRE_INTERVAL
		shoot_at_target(BULLET_SPEED)
