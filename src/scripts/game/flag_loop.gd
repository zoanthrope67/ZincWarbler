class_name FlagLoop
extends Node
## The flag and boss loop (docs/SPEC.md, Flags):
##   1. Touching a flag gives FLAG_SCORE and hides the flag.
##   2. When every flag has been touched, a random boss appears at a random
##      BossSpawnPoint of the flag touched last.
##   3. When the boss is defeated, every flag comes back except the one closest
##      to the player. Then the loop starts again.
##
## The boss's own score (e.g. 10 for Angry Greg) is given by the In Game scene,
## the same way as for every other enemy.

## Emitted when the player earns points from this loop. Game logic signal.
signal score_awarded(points: int)
## Emitted when a boss appears. Game logic signal.
signal boss_spawned(boss: Enemy)

## Score for touching one flag.
const FLAG_SCORE := 1

## Bosses that can appear, picked at random with equal chance. Change them by
## selecting the FlagLoop node in scn/in_game.tscn.
@export var boss_scenes: Array[PackedScene] = []

## The boss currently in play, or null.
var current_boss: Enemy = null

var _flags: Array[Flag] = []
var _player: Player
var _spawner: EnemySpawner
var _last_touched_flag: Flag = null
var _game: InGame


## Connects the loop to the game. Called by the In Game scene.
func setup(game: InGame, arena: Arena, player: Player, spawner: EnemySpawner) -> void:
	_player = player
	_spawner = spawner
	_flags = arena.get_flags()
	_game = game;
	for flag in _flags:
		flag.touched.connect(_on_flag_touched)


func _on_flag_touched(flag: Flag) -> void:
	score_awarded.emit(FLAG_SCORE)
	_game.increase_danger(10)
	_last_touched_flag = flag
	if _flags.all(func(f: Flag) -> bool: return not f.is_active):
		_spawn_boss()


func _spawn_boss() -> void:
	if boss_scenes.is_empty():
		push_warning("FlagLoop: no boss scenes are set, so no boss can appear.")
		return
	var point: Marker3D = _last_touched_flag.get_boss_spawn_points().pick_random()
	current_boss = _spawner.spawn_enemy(boss_scenes.pick_random(), point.global_position)
	current_boss.defeated.connect(_on_boss_defeated)
	boss_spawned.emit(current_boss)


func _on_boss_defeated(_boss: Enemy) -> void:
	current_boss = null
	var closest := _flag_closest_to_player()
	for flag in _flags:
		if flag != closest:
			flag.restore()


func _flag_closest_to_player() -> Flag:
	var closest: Flag = null
	var closest_distance := INF
	for flag in _flags:
		var offset := flag.global_position - _player.global_position
		var distance := Vector2(offset.x, offset.z).length()
		if distance < closest_distance:
			closest_distance = distance
			closest = flag
	return closest
