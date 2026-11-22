extends Control
## Bootstrap state: the first scene loaded when the game starts.
##
## Anything that must run once when the game first loads belongs in _ready() here.
## The game never comes back to this scene.

## How long the "Loading..." screen is shown, in seconds.
const LOADING_SCREEN_SECONDS := 0.05


func _ready() -> void:
	GameState.enter_bootstrap()

	# One-time setup.
	Settings.load_settings()
	Hiscores.load_or_create()

	await get_tree().create_timer(LOADING_SCREEN_SECONDS).timeout
	GameState.change_state(GameState.State.MAIN_MENU)
