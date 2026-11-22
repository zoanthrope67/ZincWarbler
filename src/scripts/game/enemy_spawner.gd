class_name EnemySpawner
extends Node
## Makes a random enemy appear at a random EnemySpawnPoint every `spawn_interval`
## seconds, until the player is defeated. There is no cap on the number of enemies.
##
## Only EnemySpawnPoints between `min_spawn_distance` and `max_spawn_distance`
## from the player can be used. If none can, a message is logged and the spawn is
## tried again after `retry_delay` seconds; the following spawn is then timed from
## the moment this one finally happens, so two enemies never appear at once.
##
## Change the settings by selecting the EnemySpawner node in scn/in_game.tscn.

## Emitted for every enemy (and boss) this spawner creates. Game logic signal.
signal enemy_spawned(enemy: Enemy)

## Seconds between enemies.
@export var spawn_interval := 5.0
## EnemySpawnPoints closer to the player than this (meters) are not used.
@export var min_spawn_distance := 20.0
## EnemySpawnPoints further from the player than this (meters) are not used.
@export var max_spawn_distance := 100.0
## Seconds to wait before trying again when no EnemySpawnPoint can be used.
@export var retry_delay := 0.25
## The enemies that can appear, picked at random with equal chance. List a scene
## more than once to make it more common.
@export var enemy_scenes: Array[PackedScene] = []

var _arena: Arena
var _player: Player
var _enemy_container: Node3D
var _bullet_pool: EnemyBulletPool
var _time_until_spawn := 0.0


## Connects the spawner to the game. Called by the In Game scene.
func setup(arena: Arena, player: Player, enemy_container: Node3D, bullet_pool: EnemyBulletPool) -> void:
	_arena = arena
	_player = player
	_enemy_container = enemy_container
	_bullet_pool = bullet_pool
	_time_until_spawn = spawn_interval


func _physics_process(delta: float) -> void:
	if _player == null or _player.is_dead or enemy_scenes.is_empty():
		return
	_time_until_spawn -= delta
	if _time_until_spawn > 0.0:
		return

	var points := get_valid_spawn_points()
	if points.is_empty():
		print("EnemySpawner: no EnemySpawnPoint is between %.1f and %.1f m from the player. Trying again in %.2f s." % [min_spawn_distance, max_spawn_distance, retry_delay])
		_time_until_spawn = retry_delay
		return

	spawn_enemy(enemy_scenes.pick_random(), points.pick_random().global_position)
	_time_until_spawn = spawn_interval


## The EnemySpawnPoints that are currently far enough from (and close enough to) the player.
func get_valid_spawn_points() -> Array[Marker3D]:
	var valid: Array[Marker3D] = []
	var player_spot := Vector2(_player.global_position.x, _player.global_position.z)
	for point in _arena.get_enemy_spawn_points():
		var distance := player_spot.distance_to(Vector2(point.global_position.x, point.global_position.z))
		if distance >= min_spawn_distance and distance <= max_spawn_distance:
			valid.append(point)
	return valid


## Creates an enemy from `scene` at `point` (also used for bosses).
func spawn_enemy(scene: PackedScene, point: Vector3) -> Enemy:
	var enemy: Enemy = scene.instantiate()
	enemy.player = _player
	enemy.bullet_pool = _bullet_pool
	# The container sits at the origin, so position here is the world position.
	enemy.position = Gameplay.on_plane(point)
	_enemy_container.add_child(enemy)
	enemy.reset_physics_interpolation()
	enemy_spawned.emit(enemy)
	return enemy
