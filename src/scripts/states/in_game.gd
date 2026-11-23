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
##   HUD            - score, time, health and the "YOU DIED" banner
##
## When the player dies (docs/SPEC.md, In Game State):
##   - the score, time survived and the date/time the game ended are fixed,
##   - the "YOU DIED" banner appears while enemies carry on,
##   - after DEATH_SCREEN_MAX_SECONDS, or a fresh press of Confirm made once
##     DEATH_SCREEN_SKIP_AFTER_SECONDS have passed, the game ends and moves to
##     Name Entry (if the score makes the hi-score table) or Game Over.

## Emitted whenever the score changes (used by the HUD). Game logic signal.
signal score_changed(score: int)
## Emitted when the "YOU DIED" banner appears. FX only.
signal fx_you_died_shown
## Emitted when the player becomes able to skip the "YOU DIED" screen. FX only.
signal fx_continue_available

## Longest time, in seconds, the "YOU DIED" screen is shown before the game ends.
const DEATH_SCREEN_MAX_SECONDS := 90.0
## Seconds after dying before a fresh press of Confirm can end the game.
const DEATH_SCREEN_SKIP_AFTER_SECONDS := 5.0

## Seconds the player has survived this game. Stops counting when the player dies.
var time_survived := 0.0
## The player's score. Locked (no longer changes) once the player dies.
var score := 0
## Seconds since the player died, or -1 while they are alive.
var time_since_death := -1.0
## Current Danger Level. As Danger increases, more powerful enemy bags are used
## (see get_bag_via_danger() in scripts/game/enemy/enemy_spawner.gd).
## Danger increases by 1 every second the player is alive, and by 10 for each
## flag touched. Later features will add more ways to increase Danger.
var danger_level := 0.0

# Fixed at the moment the player dies.
var _seconds_survived_at_death := 0
var _datetime_at_death := ""
var _game_ended := false

@onready var _arena: Arena = $Arena
@onready var _player: Player = $Player
@onready var _player_bullets: Node3D = $PlayerBullets
@onready var _enemies: Node3D = $Enemies
@onready var _enemy_bullets: EnemyBulletPool = $EnemyBullets
@onready var _spawner: EnemySpawner = $EnemySpawner
@onready var _flag_loop: FlagLoop = $FlagLoop
@onready var _camera: FollowCamera = $Camera
@onready var _hud: Hud = $HUD


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

	_spawner.setup(self, _arena, _player, _enemies, _enemy_bullets)
	_spawner.enemy_spawned.connect(_on_enemy_spawned)
	_flag_loop.setup(self, _arena, _player, _spawner)
	_flag_loop.score_awarded.connect(add_score)

	_camera.target = _player
	_camera.snap_to_target()

	_hud.setup(Player.MAX_HEALTH)
	_player.health_changed.connect(_hud.set_health)
	score_changed.connect(_hud.set_score)

## Adds `danger_delta` to the danger level. Use this for every source of danger.
func increase_danger(danger_delta: float) -> void:
	danger_level += danger_delta;

func _physics_process(delta: float) -> void:
		
	if not _player.is_dead:
		time_survived += delta
		_hud.set_time(time_survived)
		increase_danger(delta);
		return

	if time_since_death < 0.0:
		return   # Arena validation failed; the player never spawned.
	var before := time_since_death
	time_since_death += delta
	if before < DEATH_SCREEN_SKIP_AFTER_SECONDS and time_since_death >= DEATH_SCREEN_SKIP_AFTER_SECONDS:
		_hud.show_continue_hint()
		fx_continue_available.emit()
	if time_since_death >= DEATH_SCREEN_MAX_SECONDS:
		_end_game()


# A Confirm press only counts if it starts after the skip time; holding Confirm
# down from earlier (e.g. while firing when the player died) does not count.
func _unhandled_input(event: InputEvent) -> void:
	if time_since_death >= DEATH_SCREEN_SKIP_AFTER_SECONDS and InputHelper.is_fresh_press(event, &"confirm"):
		get_viewport().set_input_as_handled()
		_end_game()


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

	# Fix the results now: time survived and the date/time are taken at death.
	_seconds_survived_at_death = floori(time_survived)
	_datetime_at_death = Time.get_datetime_string_from_system()
	time_since_death = 0.0
	_hud.show_you_died()
	fx_you_died_shown.emit()


func _end_game() -> void:
	if _game_ended:
		return
	_game_ended = true
	GameState.end_game(score, _seconds_survived_at_death, _datetime_at_death)
