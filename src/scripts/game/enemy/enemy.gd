class_name Enemy
extends CharacterBody3D
## Shared behaviour for every enemy and boss.
##
## Life of an enemy:
##   1. Fading in (FADE_IN_SECONDS): the model fades from invisible to visible.
##      It does not move, cannot hurt the player and cannot be hit. It has no
##      collision layer or mask, so bullets and the player pass through it.
##   2. Active: it moves and attacks (see each enemy's own script). It blocks
##      the player, and touching the player hurts them.
##   3. Defeated: after `max_hits` hits from player bullets it is removed.
##      Or removed when far away: a normal enemy (not a boss) that stays more
##      than FAR_AWAY_DISTANCE from the player for FAR_AWAY_SECONDS is removed
##      to save performance. That is not a defeat: no score, no `defeated`.
##
## To make a new enemy: make a scene like scn/game/chaser.tscn, and a script that
## extends Enemy and overrides _on_activated() and/or _active_physics_process().
## Use shoot_at_target() to fire an enemy bullet at the player, move_sliding() to
## move while gliding along walls, and is_pushing_into_player() to skip moving
## when already pressed against the player.
##
## Required child nodes:
##   CollisionShape3D - a SphereShape3D (its radius is the enemy's size)
##   Hurtbox          - an Area3D a little larger than the body; touching the
##                      player inside it hurts them
##   Model            - everything visible; turned to face +Z towards its heading

# --- FX signals (effects and sounds only) ----------------------------------------
signal fx_spawn_started(position: Vector3)
signal fx_activated(position: Vector3)
signal fx_hit(position: Vector3, hits_left: int)
signal fx_defeated(position: Vector3)
signal fx_shot_fired(position: Vector3, direction: Vector3)

# --- Game logic signals ------------------------------------------------------------
## Emitted once when the enemy is defeated, just before it is removed.
signal defeated(enemy: Enemy)

## Seconds an enemy takes to fade in before it becomes active.
const FADE_IN_SECONDS := 0.25
## How far from its edge an enemy's bullets appear, in meters.
const BULLET_SPAWN_GAP := 0.3
## How far (meters) an enemy may drift above or below the gameplay plane before
## it is moved back onto it.
const PLANE_TOLERANCE := 0.001
## An active normal enemy further than this from the player, in meters
## (measured flat, on X and Z), starts counting towards being removed.
const FAR_AWAY_DISTANCE := 150.0
## Seconds an enemy must stay further than FAR_AWAY_DISTANCE before it is
## removed. Coming back within FAR_AWAY_DISTANCE starts the count again.
const FAR_AWAY_SECONDS := 10.0

## Player bullet hits needed to defeat this enemy.
@export var max_hits := 2
## Score given to the player when this enemy is defeated.
@export var score_value := 0
## True for bosses (they are spawned by the flags, not by the enemy spawner).
## Bosses are never removed for being far from the player.
@export var is_boss := false
## Material shown on the model for a moment each time this enemy is hit (an
## effect only; see scripts/game/gfx_effects.gd). Empty = no flash.
@export var hit_flash_material: ShaderMaterial = preload("res://gfx/placeholder/placeholder_hit_flash.tres")
## How long the hit flash shows, in seconds.
@export var hit_flash_seconds := 0.1

## The player. Set by whoever spawns the enemy. When the player is dead their
## node stays where they died, so enemies keep aiming at the last known position.
var player: Player = null
## Where this enemy's bullets come from. Set by whoever spawns the enemy.
var bullet_pool: EnemyBulletPool = null

var hits_left := 0
var is_active := false
## True if the player was inside this enemy's Hurtbox on the last physics frame.
var touching_player := false
## The enemy's radius in meters, read from its CollisionShape3D.
var body_radius := 1.0

var _fade_time := 0.0
# True once the enemy has been defeated or removed for being far away. It does
# nothing more after that, while it waits to be freed.
var _is_removed := false
# Seconds this enemy has been further than FAR_AWAY_DISTANCE from the player
# without coming back.
var _far_away_time := 0.0
# Temporary see-through copies of the model's materials, used only while fading
# in: [{"mesh": MeshInstance3D, "surface": int, "material": BaseMaterial3D,
# "alpha": float (the material's own alpha)}]
var _fade_materials: Array[Dictionary] = []

@onready var _model: Node3D = $Model
@onready var _hurtbox: Area3D = $Hurtbox


func _ready() -> void:
	hits_left = max_hits
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := ($CollisionShape3D as CollisionShape3D).shape
	if shape is SphereShape3D:
		body_radius = shape.radius

	# Start faded out with no collision.
	collision_layer = 0
	collision_mask = 0
	_hurtbox.monitoring = false
	_start_fade_materials(_model)
	_set_fade_amount(0.0)
	# The hit flash listens to this enemy's own FX signal, so the game logic in
	# take_hit() does not know about it.
	fx_hit.connect(_on_fx_hit)
	fx_spawn_started.emit(global_position)


func _physics_process(delta: float) -> void:
	if _is_removed:
		return
	if not is_active:
		_fade_time += delta
		_set_fade_amount(clampf(_fade_time / FADE_IN_SECONDS, 0.0, 1.0))
		if _fade_time >= FADE_IN_SECONDS:
			_activate()
		return

	_active_physics_process(delta)
	# A collision can nudge an enemy slightly off the gameplay plane. Only put it
	# back when that has happened: moving a physics body is not free, and doing it
	# every frame for every enemy adds up when there are hundreds of them.
	if absf(global_position.y - Gameplay.PLANE_HEIGHT) > PLANE_TOLERANCE:
		global_position.y = Gameplay.PLANE_HEIGHT
	_hurt_player_if_touching()
	_remove_if_far_away(delta)


## Called by player bullets. Does nothing while fading in.
func take_hit() -> void:
	if not is_active or _is_removed:
		return
	hits_left -= 1
	fx_hit.emit(global_position, hits_left)
	if hits_left <= 0:
		_defeat()


# Flashes the model when hit (hit_flash_material for hit_flash_seconds). Effects only.
func _on_fx_hit(_position: Vector3, _hits_left: int) -> void:
	if hit_flash_material != null:
		GfxEffects.apply_gfx_material(_model, hit_flash_material, hit_flash_seconds)


# --- For enemy scripts to override ---------------------------------------------------

## Called once when the fade-in finishes.
func _on_activated() -> void:
	pass


## Called every physics frame while active. Move and attack here.
func _active_physics_process(_delta: float) -> void:
	pass


# --- Helpers for enemy scripts ---------------------------------------------------------

## Where the enemy is aiming: the player, or where the player died.
func get_target_position() -> Vector3:
	if player != null and is_instance_valid(player):
		return Gameplay.on_plane(player.global_position)
	return global_position


## Unit vector on the gameplay plane towards the target, or zero if already there.
func direction_to_target() -> Vector3:
	var offset := get_target_position() - global_position
	offset.y = 0.0
	if offset.length() < 0.05:
		return Vector3.ZERO
	return offset.normalized()


## Fires one enemy bullet at the target. `speed` is in meters per second.
func shoot_at_target(speed := EnemyBullet.DEFAULT_SPEED) -> void:
	var direction := direction_to_target()
	if direction == Vector3.ZERO or bullet_pool == null:
		return
	var start := global_position + direction * (body_radius + BULLET_SPAWN_GAP)
	bullet_pool.fire(start, direction, speed)
	fx_shot_fired.emit(start, direction)


## Turns the model to face a direction on the gameplay plane.
func face(direction: Vector3) -> void:
	if direction == Vector3.ZERO:
		return
	_model.look_at(_model.global_position + direction, Vector3.UP, true)


## Moves by `motion` (meters, on the gameplay plane). If something is in the way,
## the rest of the motion slides along its surface, so enemies glide along walls
## instead of stopping dead. Returns the first collision, or null.
##
## This does one slide step, which is much cheaper than Godot's move_and_slide()
## (up to four steps plus extra checks). With hundreds of enemies that matters.
func move_sliding(motion: Vector3) -> KinematicCollision3D:
	var collision := move_and_collide(motion)
	if collision != null:
		var normal := collision.get_normal()
		normal.y = 0.0
		if normal != Vector3.ZERO:
			var rest := collision.get_remainder().slide(normal.normalized())
			rest.y = 0.0
			if rest.length_squared() > 0.000001:
				move_and_collide(rest)
	return collision


## True if moving along `direction` would only push further into the player
## this enemy is already touching. Enemies skip their movement then: they cannot
## get any closer, and skipping it saves physics time when many enemies crowd
## the player. Moving away from the player is never skipped.
func is_pushing_into_player(direction: Vector3) -> bool:
	if not touching_player or direction == Vector3.ZERO:
		return false
	var to_player := get_target_position() - global_position
	to_player.y = 0.0
	return direction.dot(to_player) > 0.0


## True if a collision was with a wall.
func is_wall(collision: KinematicCollision3D) -> bool:
	var layer := PhysicsServer3D.body_get_collision_layer(collision.get_collider_rid())
	return layer & Gameplay.LAYER_WALLS != 0


# --- Internals -------------------------------------------------------------------

func _activate() -> void:
	is_active = true
	_end_fade_materials()
	collision_layer = Gameplay.LAYER_ENEMIES
	# Enemies stop at walls and at the player, but pass through each other.
	collision_mask = Gameplay.LAYER_WALLS | Gameplay.LAYER_PLAYER
	_hurtbox.monitoring = true
	_on_activated()
	fx_activated.emit(global_position)


# Touching the player hurts them. The player's invulnerability after a hit stops
# this from removing health every frame.
func _hurt_player_if_touching() -> void:
	touching_player = false
	for body in _hurtbox.get_overlapping_bodies():
		if body is Player:
			touching_player = true
			body.take_damage()


func _defeat() -> void:
	_stop_and_free()
	fx_defeated.emit(global_position)
	defeated.emit(self)


# Counts how long the enemy has been far from the player, and removes it once
# that reaches FAR_AWAY_SECONDS. Bosses are never removed: the flags only come
# back when the boss is defeated.
func _remove_if_far_away(delta: float) -> void:
	if is_boss:
		return
	var offset := get_target_position() - global_position
	offset.y = 0.0
	if offset.length_squared() <= FAR_AWAY_DISTANCE * FAR_AWAY_DISTANCE:
		_far_away_time = 0.0
		return
	_far_away_time += delta
	# The tiny tolerance stops floating point rounding from making it a frame late.
	if _far_away_time >= FAR_AWAY_SECONDS - 0.0001:
		# Not a defeat: no score, no `defeated` signal and no fx_defeated.
		_stop_and_free()


# Takes the enemy out of play and frees it at the end of the frame.
func _stop_and_free() -> void:
	_is_removed = true
	is_active = false
	# Deferred: a defeat runs inside a bullet's collision callback, where
	# physics settings cannot be changed.
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	_hurtbox.set_deferred("monitoring", false)
	queue_free()


# Gives every mesh surface under `node` a see-through copy of its material.
# Works with any StandardMaterial3D / ORMMaterial3D; surfaces using a
# ShaderMaterial are left as they are (they will pop in instead of fading).
func _start_fade_materials(node: Node) -> void:
	for child in node.get_children():
		var mesh_instance := child as MeshInstance3D
		if mesh_instance != null and mesh_instance.mesh != null:
			for surface in mesh_instance.get_surface_override_material_count():
				var original := mesh_instance.get_active_material(surface) as BaseMaterial3D
				if original != null:
					var copy: BaseMaterial3D = original.duplicate()
					copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					_fade_materials.append({
						"mesh": mesh_instance,
						"surface": surface,
						"material": copy,
						"alpha": original.albedo_color.a,
						"previous_override": mesh_instance.get_surface_override_material(surface),
					})
					mesh_instance.set_surface_override_material(surface, copy)
		_start_fade_materials(child)


# 0 = invisible, 1 = fully visible.
func _set_fade_amount(amount: float) -> void:
	for entry in _fade_materials:
		entry.material.albedo_color.a = entry.alpha * amount


# Removes the see-through copies so the model draws normally (and cheaply) again.
func _end_fade_materials() -> void:
	for entry in _fade_materials:
		entry.mesh.set_surface_override_material(entry.surface, entry.previous_override)
	_fade_materials.clear()
