class_name InGame
extends Node3D
## In Game state: the arena, the player and the camera.
##
## When the scene starts it checks the arena (Arena.validate). If anything is
## wrong the game goes to the Error screen with a list of the problems.
##
## To use a different arena, replace the Arena child of this scene with another
## scene whose root uses scripts/game/arena.gd.
##
## Still to come: enemies, flags and bosses (phase 3), and the HUD, death
## sequence and end of game (phase 4).

## Seconds the player has survived this game. Stops counting when the player dies.
var time_survived := 0.0

@onready var _arena: Arena = $Arena
@onready var _player: Player = $Player
@onready var _player_bullets: Node3D = $PlayerBullets
@onready var _camera: FollowCamera = $Camera


func _ready() -> void:
	var problems := _arena.validate()
	if not problems.is_empty():
		_player.process_mode = Node.PROCESS_MODE_DISABLED
		GameState.raise_error("Arena validation failed:\n" + "\n".join(problems))
		return

	_player.bullet_container = _player_bullets
	_player.place_at(_arena.get_player_spawn_points().pick_random().global_position)
	_player.died.connect(_on_player_died)

	_camera.target = _player
	_camera.snap_to_target()


func _physics_process(delta: float) -> void:
	if not _player.is_dead:
		time_survived += delta


func _on_player_died() -> void:
	# The spec removes all player bullets when the player dies.
	for bullet in _player_bullets.get_children():
		bullet.queue_free()
