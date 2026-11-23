class_name Player
extends CharacterBody3D
## The player character.
##
## Moves in 8 directions with no inertia, fires bullets while Confirm is held and
## dashes while Back is held. See docs/SPEC.md, "The Player".
##
## Firing and dashing cannot happen at the same time. Whichever started first
## carries on, and the other button is ignored until it is released and pressed
## again. If both are pressed on the same frame, firing wins.
##
## The visible model is the "Model" child. It is turned to face the direction the
## player is facing (or firing in), with its front along +Z, which is how models
## exported from Blender face by default.

# --- FX signals (for effects and sounds only; never used for game logic) -------
signal fx_shot_fired(position: Vector3, direction: Vector3)
signal fx_dash_started(position: Vector3, direction: Vector3)
signal fx_dash_ended(position: Vector3)
signal fx_dash_attempted_during_cooldown(position: Vector3)
signal fx_hurt(position: Vector3, health_left: int)
signal fx_invulnerability_started
signal fx_invulnerability_ended
signal fx_died(position: Vector3)

# --- Game logic signals ---------------------------------------------------------
## Emitted whenever health changes (used by the HUD).
signal health_changed(health: int)
## Emitted once when health reaches zero.
signal died

# --- Designer settings ----------------------------------------------------------

## Walking speed in meters per second.
const MOVE_SPEED := 15.0

## Seconds between shots while Confirm is held. Tapping cannot fire faster than this.
const FIRE_INTERVAL := 0.2
## How far in front of the player's centre new bullets appear, in meters.
## 1.0 is the edge of the player's 2 m sphere.
const BULLET_SPAWN_DISTANCE := 1.0

## Dash speed as a multiple of MOVE_SPEED.
const DASH_SPEED_MULTIPLIER := 3.0
## The longest a dash can travel, in meters.
const DASH_MAX_DISTANCE := 12.0
## Seconds from the START of a dash until the player can dash again.
const DASH_COOLDOWN := 2.0

## Health at the start of a game. Each hit removes 1.
const MAX_HEALTH := 3
## Seconds the player cannot be hurt after taking damage.
const INVULNERABLE_SECONDS := 2.0
## How fast the model blinks while invulnerable (seconds per on/off step).
const INVULNERABLE_BLINK_INTERVAL := 0.1

const BULLET_SCENE := preload("res://scn/game/player_bullet.tscn")

## If on, every dash travels the full DASH_MAX_DISTANCE and releasing Back does
## not end it early. Off by default (docs/SPEC.md).
@export var dash_always_full_distance := false

# --- State ----------------------------------------------------------------------

## Where new bullets are added. Set by the In Game scene; if empty, bullets are
## added next to the player.
var bullet_container: Node = null

var health := MAX_HEALTH
var is_dead := false
## The direction the player last moved in. Starts as if Right was pressed.
var facing := Vector3.RIGHT

enum Action { NONE, FIRING, DASHING }
var _action := Action.NONE

var _fire_direction := Vector3.RIGHT
var _fire_cooldown_left := 0.0

var _dash_direction := Vector3.RIGHT
var _dash_distance := 0.0
var _dash_cooldown_left := 0.0

# A "blocked" button is ignored until it is released, so it needs a fresh press.
var _confirm_blocked := false
var _back_blocked := false

var _invulnerable_left := 0.0

@onready var _model: Node3D = $Model
@onready var _animation: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	# Buttons still held from the previous screen (e.g. Confirm on "Start Game")
	# do not count until they are released and pressed again.
	_confirm_blocked = Input.is_action_pressed(&"confirm")
	_back_blocked = Input.is_action_pressed(&"back")
	_update_model_facing()


## Moves the player straight to a point (used for spawning).
func place_at(point: Vector3) -> void:
	global_position = Gameplay.on_plane(point)
	velocity = Vector3.ZERO
	reset_physics_interpolation()


## Called when play resumes after pausing. Stops firing, and makes Confirm and
## Back need a fresh press if they are still held (e.g. from choosing Resume in
## the pause menu). A dash that was under way carries on under the usual rules.
func ignore_held_buttons() -> void:
	if _action == Action.FIRING:
		_action = Action.NONE
	_confirm_blocked = Input.is_action_pressed(&"confirm")
	_back_blocked = Input.is_action_pressed(&"back")


## True while the player cannot be hurt.
func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


## True while dashing.
func is_dashing() -> bool:
	return _action == Action.DASHING


## True while firing.
func is_firing() -> bool:
	return _action == Action.FIRING


## Removes 1 health (or `amount`) unless the player is invulnerable or dead.
## Returns true if the hit counted.
func take_damage(amount := 1) -> bool:
	if is_dead or is_invulnerable():
		return false

	health = maxi(health - amount, 0)
	health_changed.emit(health)
	fx_hurt.emit(global_position, health)

	if health == 0:
		_die()
	else:
		_invulnerable_left = INVULNERABLE_SECONDS
		fx_invulnerability_started.emit()
	return true


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_read_buttons()

	if _action == Action.DASHING:
		_move_dashing(delta)
	else:
		_move_walking()

	if _action == Action.FIRING:
		_try_fire()

	_update_model_facing()


func _tick_timers(delta: float) -> void:
	_fire_cooldown_left = maxf(_fire_cooldown_left - delta, 0.0)
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)

	if _invulnerable_left > 0.0:
		_invulnerable_left -= delta
		if _invulnerable_left <= 0.0:
			_invulnerable_left = 0.0
			_model.visible = true
			fx_invulnerability_ended.emit()
		else:
			# Blink: on for one interval, off for the next.
			_model.visible = fmod(_invulnerable_left, INVULNERABLE_BLINK_INTERVAL * 2.0) > INVULNERABLE_BLINK_INTERVAL


# Starts and stops firing and dashing based on the Confirm and Back buttons.
func _read_buttons() -> void:
	var confirm_down := Input.is_action_pressed(&"confirm")
	var back_down := Input.is_action_pressed(&"back")
	if not confirm_down:
		_confirm_blocked = false
	if not back_down:
		_back_blocked = false
	var confirm_usable := confirm_down and not _confirm_blocked
	var back_usable := back_down and not _back_blocked

	match _action:
		Action.NONE:
			if confirm_usable:
				_start_firing()
				# Both pressed on the same frame: firing wins, Back needs a fresh press.
				if back_usable:
					_back_blocked = true
			elif back_usable:
				if _dash_cooldown_left > 0.0:
					_back_blocked = true
					fx_dash_attempted_during_cooldown.emit(global_position)
				else:
					_start_dash()

		Action.FIRING:
			# Back pressed while firing is ignored until pressed again.
			if back_down:
				_back_blocked = true
			if not confirm_down:
				_action = Action.NONE

		Action.DASHING:
			# Confirm pressed while dashing is ignored until pressed again.
			if confirm_down:
				_confirm_blocked = true
			if not back_down and not dash_always_full_distance:
				_end_dash()


# Returns the direction pressed as one of 8 unit vectors, or zero.
func _read_move_direction() -> Vector3:
	var x := signf(Input.get_axis(&"move_left", &"move_right"))
	var z := signf(Input.get_axis(&"move_up", &"move_down"))
	return Vector3(x, 0.0, z).normalized()


func _move_walking() -> void:
	var direction := _read_move_direction()
	if direction != Vector3.ZERO:
		facing = direction
	velocity = direction * MOVE_SPEED
	move_and_slide()
	_stay_on_plane()


func _start_firing() -> void:
	_action = Action.FIRING
	# The firing direction is locked until Confirm is released.
	_fire_direction = facing


# Fires if the fire cooldown has run out. The tiny tolerance stops floating point
# rounding from delaying a shot by a whole frame.
func _try_fire() -> void:
	if _fire_cooldown_left > 0.0001:
		return
	_fire_cooldown_left += FIRE_INTERVAL

	var bullet: PlayerBullet = BULLET_SCENE.instantiate()
	bullet.direction = _fire_direction
	var parent := bullet_container if bullet_container != null else get_parent()
	parent.add_child(bullet)
	bullet.global_position = global_position + _fire_direction * BULLET_SPAWN_DISTANCE
	bullet.reset_physics_interpolation()
	fx_shot_fired.emit(bullet.global_position, _fire_direction)


func _start_dash() -> void:
	_action = Action.DASHING
	_dash_direction = facing
	_dash_distance = 0.0
	_dash_cooldown_left = DASH_COOLDOWN
	_animation.play(&"dash")
	fx_dash_started.emit(global_position, _dash_direction)


func _move_dashing(delta: float) -> void:
	var dash_speed := MOVE_SPEED * DASH_SPEED_MULTIPLIER
	# Slow down on the last frame so the dash never goes past DASH_MAX_DISTANCE.
	var remaining := DASH_MAX_DISTANCE - _dash_distance
	velocity = _dash_direction * minf(dash_speed, remaining / delta)

	var start := global_position
	move_and_slide()
	_stay_on_plane()
	_dash_distance += start.distance_to(global_position)

	var hit_something := get_slide_collision_count() > 0
	if hit_something or _dash_distance >= DASH_MAX_DISTANCE - 0.001:
		_end_dash()


func _end_dash() -> void:
	if _action != Action.DASHING:
		return
	_action = Action.NONE
	velocity = Vector3.ZERO
	# If Back is still held, the next dash needs a fresh press.
	if Input.is_action_pressed(&"back"):
		_back_blocked = true
	_animation.play(&"RESET")
	fx_dash_ended.emit(global_position)


func _die() -> void:
	_end_dash()
	_action = Action.NONE
	is_dead = true
	velocity = Vector3.ZERO
	_invulnerable_left = 0.0
	visible = false
	# Deferred: the killing hit may arrive inside an enemy bullet's collision
	# callback, where physics settings cannot be changed.
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	set_physics_process(false)
	fx_died.emit(global_position)
	died.emit()


func _stay_on_plane() -> void:
	global_position.y = Gameplay.PLANE_HEIGHT


# Turns the model towards where the player is firing, or else where they face.
func _update_model_facing() -> void:
	var look_direction := _fire_direction if _action == Action.FIRING else facing
	_model.look_at(_model.global_position + look_direction, Vector3.UP, true)
