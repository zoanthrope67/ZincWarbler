class_name PlayerBullet
extends Area3D
## A bullet fired by the player.
##
## Travels in a straight line on the gameplay plane. It disappears when it hits
## a wall, when it hits an enemy (dealing one hit), or after LIFETIME seconds.

## Emitted just before the bullet disappears on a wall. FX only.
signal fx_hit_wall(position: Vector3)
## Emitted just before the bullet disappears on an enemy. FX only.
signal fx_hit_enemy(position: Vector3)
## Emitted just before the bullet disappears because its lifetime ran out. FX only.
signal fx_expired(position: Vector3)

## Speed in meters per second.
const SPEED := 30.0
## Seconds before the bullet disappears on its own, so bullets that escape
## through a gap in the arena's walls cannot fly forever.
const LIFETIME := 5.0

## Unit vector the bullet travels along. Set by whoever fires it.
var direction := Vector3.RIGHT

var _time_left := LIFETIME
var _finished := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction * SPEED * delta
	_time_left -= delta
	if _time_left <= 0.0:
		fx_expired.emit(global_position)
		_finish()


func _on_body_entered(body: Node3D) -> void:
	if _finished:
		return
	if body.has_method("take_hit"):
		# Enemies (phase 3) implement take_hit().
		body.take_hit()
		fx_hit_enemy.emit(global_position)
	else:
		fx_hit_wall.emit(global_position)
	_finish()


# Removes the bullet. A bullet can touch two things in the same frame, so this
# makes sure it only counts once.
func _finish() -> void:
	if _finished:
		return
	_finished = true
	set_deferred("monitoring", false)
	set_physics_process(false)
	queue_free()
