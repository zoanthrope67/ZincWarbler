class_name AngryGreg
extends Enemy
## Angry Greg (boss): does not move. Turns to face the player and fires an enemy
## bullet at them every FIRE_INTERVAL. Hits needed and score are set on the root
## node of scn/game/angry_greg.tscn (Max Hits 5, Score Value 10).

## Seconds between shots. The first shot comes this long after the fade-in ends.
const FIRE_INTERVAL := 4.0
## Speed of Greg's bullets in meters per second.
const BULLET_SPEED := EnemyBullet.DEFAULT_SPEED

var _time_until_shot := FIRE_INTERVAL


func _on_activated() -> void:
	_time_until_shot = FIRE_INTERVAL
	face(direction_to_target())


func _active_physics_process(delta: float) -> void:
	face(direction_to_target())
	_time_until_shot -= delta
	if _time_until_shot <= 0.0:
		_time_until_shot += FIRE_INTERVAL
		shoot_at_target(BULLET_SPEED)
