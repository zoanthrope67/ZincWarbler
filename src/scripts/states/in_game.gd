class_name InGame
extends Node3D
## In Game state: the arena, the player, enemies, flags, bosses and the camera.
##
## When the scene starts it checks the arena (Arena.validate). If anything is
## wrong the game goes to the Error screen with a list of the problems.
##
## To use a different arena, replace the Arena child of this scene with another
## scene whose root uses scripts/game/arena.gd.
##
## Children:
##   Arena          - walls, spawn points and flags
##   Player         - the player
##   PlayerBullets  - player bullets are added here
##   Enemies        - enemies and bosses are added here
##   EnemyBullets   - the enemy bullet pool
##   EnemySpawner   - makes normal enemies appear
##   FlagLoop       - flags, scoring for flags and bosses appearing
##   Camera         - follows the player
##
## Still to come (phase 4): the HUD, the death sequence and the end of the game.

## Emitted whenever the score changes (used by the HUD). Game logic signal.
signal score_changed(score: int)

## Seconds the player has survived this game. Stops counting when the player dies.
var time_survived := 0.0
## The player's score. Locked (no longer changes) once the player dies.
var score := 0

@onready var _arena: Arena = $Arena
@onready var _player: Player = $Player
@onready var _player_bullets: Node3D = $PlayerBullets
@onready var _enemies: Node3D = $Enemies
@onready var _enemy_bullets: EnemyBulletPool = $EnemyBullets
@onready var _spawner: EnemySpawner = $EnemySpawner
@onready var _flag_loop: FlagLoop = $FlagLoop
@onready var _camera: FollowCamera = $Camera


func _ready() -> void:
	var problems := _arena.validate()
	if not problems.is_empty():
		_player.process_mode = Node.PROCESS_MODE_DISABLED
		_spawner.process_mode = Node.PROCESS_MODE_DISABLED
		GameState.raise_error("Arena validation failed:\n" + "\n".join(problems))
		return

	_player.bullet_container = _player_bullets
	_player.place_at(_arena.get_player_spawn_points().pick_random().global_position)
	_player.died.connect(_on_player_died)

	_spawner.setup(_arena, _player, _enemies, _enemy_bullets)
	_spawner.enemy_spawned.connect(_on_enemy_spawned)
	_flag_loop.setup(_arena, _player, _spawner)
	_flag_loop.score_awarded.connect(add_score)

	_camera.target = _player
	_camera.snap_to_target()


func _physics_process(delta: float) -> void:
	if not _player.is_dead:
		time_survived += delta


## Adds points to the score, unless the player is dead (the score is then locked).
func add_score(points: int) -> void:
	if _player.is_dead or points == 0:
		return
	score += points
	score_changed.emit(score)


func _on_enemy_spawned(enemy: Enemy) -> void:
	# Every enemy gives its own score_value when defeated (0 for normal enemies,
	# 10 for Angry Greg).
	enemy.defeated.connect(func(defeated_enemy: Enemy) -> void: add_score(defeated_enemy.score_value))


func _on_player_died() -> void:
	# The spec removes all player bullets when the player dies.
	for bullet in _player_bullets.get_children():
		bullet.queue_free()
