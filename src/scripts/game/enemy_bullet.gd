class_name EnemyBullet
extends Area3D
## A bullet fired by an enemy. Enemy bullets are never created or freed during
## play: they live in an EnemyBulletPool and are reused.
##
## A bullet goes back to the pool when it hits the player (dealing 1 damage),
## hits a wall, or after LIFETIME seconds. It passes through enemies and other
## bullets (its collision mask only includes walls and the player).

## Emitted just before the bullet returns to the pool after hitting a wall. FX only.
signal fx_hit_wall(position: Vector3)
## Emitted just before the bullet returns to the pool after hitting the player. FX only.
signal fx_hit_player(position: Vector3)
## Emitted just before the bullet returns to the pool because its lifetime ran out. FX only.
signal fx_expired(position: Vector3)

## Speed in meters per second used when an enemy does not choose its own.
const DEFAULT_SPEED := 2.0
## Seconds before an unused bullet returns to the pool on its own.
const LIFETIME := 10.0

## Unit vector the bullet travels along.
var direction := Vector3.RIGHT
## Meters per second.
var speed := DEFAULT_SPEED
## The pool this bullet belongs to. Set by the pool.
var pool: EnemyBulletPool = null
## True while the bullet is flying.
var in_use := false

var _time_left := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Godot switches physics processing on just before _ready(), so a bullet
	# waiting in the pool switches it back off here.
	set_physics_process(in_use)


## Starts the bullet flying. Called by the pool.
func launch(start: Vector3, new_direction: Vector3, new_speed: float) -> void:
	global_position = start
	direction = new_direction
	speed = new_speed
	_time_left = LIFETIME
	in_use = true
	visible = true
	monitoring = true
	set_physics_process(true)
	reset_physics_interpolation()


## Takes the bullet out of play and hands it back to the pool.
func recycle() -> void:
	if not in_use:
		return
	in_use = false
	visible = false
	set_physics_process(false)
	# Physics settings cannot change inside a collision callback, so the pool
	# finishes putting the bullet away at the end of the frame.
	pool.call_deferred("_take_back", self)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_time_left -= delta
	if _time_left <= 0.0:
		fx_expired.emit(global_position)
		recycle()


func _on_body_entered(body: Node3D) -> void:
	if not in_use:
		return
	if body.has_method("take_damage"):
		body.take_damage()
		fx_hit_player.emit(global_position)
	else:
		fx_hit_wall.emit(global_position)
	recycle()
