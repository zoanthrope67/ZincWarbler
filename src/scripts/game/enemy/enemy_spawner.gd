class_name EnemySpawner
extends Node
## Spawns enemies in waves (see EnemyWave). Waves come from bags: a bag is a
## list of waves played in a random order. When a bag runs out, the next one is
## chosen by the danger level (InGame.danger_level) in get_bag_via_danger().
##
## Waves can overlap. A new wave starts every `next_wave_delay` seconds (taken
## from the wave that just started), whether or not earlier waves have finished.
## Each running wave (an ActiveWave) spawns its own enemies at its own spawn
## point, `wave_delay_seconds` apart, until it has spawned `count` enemies.
##
## Everything happens in _physics_process, so spawning stops while the game is
## paused and once the player is dead.

## Emitted for every enemy (and boss) this spawner creates. Game logic signal.
signal enemy_spawned(enemy: Enemy)

## EnemySpawnPoints closer to the player than this (meters) are not used.
@export var min_spawn_distance := 20.0
## EnemySpawnPoints further from the player than this (meters) are not used.
@export var max_spawn_distance := 100.0
## Seconds to wait before trying again when no EnemySpawnPoint can be used.
@export var retry_delay := 0.25

var _game: InGame
var _arena: Arena
var _player: Player
var _enemy_container: Node3D
var _bullet_pool: EnemyBulletPool

## Timers count as finished when they are this close to zero. Adding up frame
## times gives tiny rounding errors, which would otherwise make a spawn one
## frame late (the player's fire timer does the same).
const TIMER_TOLERANCE := 0.0001

## One wave that is currently spawning its enemies.
class ActiveWave:
	## The wave's settings (enemy, count, delays).
	var wave: EnemyWave
	## Where every enemy of this wave appears. Chosen when the wave starts.
	var spawn_point: Vector3
	## Enemies of this wave still to spawn.
	var enemies_left: int
	## Seconds until this wave's next enemy appears.
	var time_until_next_enemy: float

## Seconds until the next wave starts.
var _time_until_next_wave := 0.0
## Waves that are still spawning enemies. Several can run at once.
var _active_waves: Array[ActiveWave] = []

var queued_waves: Array = []

const CHASER := preload("res://scn/game/chaser.tscn")
const TANK := preload("res://scn/game/tank.tscn")

## Connects the spawner to the game. Called by the In Game scene.
func setup(game: InGame, arena: Arena, player: Player, enemy_container: Node3D, bullet_pool: EnemyBulletPool) -> void:
	_game = game
	_arena = arena
	_player = player
	_enemy_container = enemy_container
	_bullet_pool = bullet_pool
	_time_until_next_wave = 1



func get_bag_via_danger():
	
	var current_bag = []
	
	if _game.danger_level < 10:
		current_bag = [
			EnemyWave.new(CHASER, 10, 0.2, 4.0),
		]
	elif _game.danger_level < 50:
		current_bag = [
			EnemyWave.new(CHASER, 3, 0.2, 1.0),
			EnemyWave.new(CHASER, 3, 0.2, 1.0),
			EnemyWave.new(TANK, 3, 0.2, 1.0),
		]
	elif _game.danger_level < 100:
		current_bag = [
			EnemyWave.new(CHASER, 3, 0.2, 1.0),
			EnemyWave.new(CHASER, 30, 0.1, 2.0),
			EnemyWave.new(TANK, 1, 0.2, 0),
			EnemyWave.new(TANK, 2, 0.2, 0.2),
		]
	else:
		# The most dangerous bag!
		current_bag = [
			EnemyWave.new(CHASER, 10, 0.2, 1.0)
		]

	assert(not current_bag.is_empty())
	current_bag.shuffle()
	return current_bag

func _physics_process(delta: float) -> void:
	if _player == null or _player.is_dead:
		return

	# 1. Every running wave spawns its next enemy when its own timer runs out.
	#    Loop backwards so finished waves can be removed while looping.
	for i in range(_active_waves.size() - 1, -1, -1):
		var active := _active_waves[i]
		active.time_until_next_enemy -= delta
		_spawn_due_enemies(active)
		if active.enemies_left <= 0:
			_active_waves.remove_at(i)

	# 2. Start the next wave when it's time. This comes after step 1 so a new
	#    wave's timer is not ticked on the frame it starts.
	_time_until_next_wave -= delta
	if _time_until_next_wave <= TIMER_TOLERANCE:
		_start_next_wave()


# Starts the next wave from the bag: chooses a valid spawn point for it, spawns
# its first enemy straight away and keeps it running until all its enemies
# have appeared. If no spawn point can be used, tries again after retry_delay.
func _start_next_wave() -> void:
	var points := get_valid_spawn_points()
	if points.is_empty():
		print("EnemySpawner: no EnemySpawnPoint is between %.1f and %.1f m from the player. Trying again in %.2f s." % [min_spawn_distance, max_spawn_distance, retry_delay])
		_time_until_next_wave = retry_delay
		return

	if queued_waves.is_empty():
		queued_waves = get_bag_via_danger()
	var wave: EnemyWave = queued_waves.pop_back()
	if wave == null or wave.enemy == null:
		# An empty bag, or a wave without an enemy scene. Skip it rather than crash.
		push_error("EnemySpawner: a bag is empty or has a wave with no enemy scene. Skipping it.")
		_time_until_next_wave = retry_delay
		return

	var active := ActiveWave.new()
	active.wave = wave
	active.spawn_point = points.pick_random().global_position
	active.enemies_left = wave.count
	active.time_until_next_enemy = 0.0
	_spawn_due_enemies(active)
	if active.enemies_left > 0:
		_active_waves.append(active)

	# "+=" keeps the timing exact: any time the timer overshot zero by is
	# taken off the next wait.
	_time_until_next_wave += wave.next_wave_delay


# Spawns every enemy of a running wave whose time has come. Usually that is one
# enemy; with a wave_delay_seconds of 0 it is the whole wave at once.
func _spawn_due_enemies(active: ActiveWave) -> void:
	while active.time_until_next_enemy <= TIMER_TOLERANCE and active.enemies_left > 0:
		spawn_enemy(active.wave.enemy, active.spawn_point)
		active.enemies_left -= 1
		active.time_until_next_enemy += active.wave.wave_delay_seconds


## Seconds the player has survived this game (InGame.time_survived), for
## spawning logic such as waves. Counts game time only: it does not count while
## the game is paused, and it stops when the player dies. Already includes the
## current physics frame, because the In Game scene updates it before this node.
## Use floori(get_time_survived()) for whole seconds, as the HUD shows.
func get_time_survived() -> float:
	if _game == null:
		return 0.0
	return _game.time_survived


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
