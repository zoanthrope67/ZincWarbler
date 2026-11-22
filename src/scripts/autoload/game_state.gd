extends Node
## GameState autoload.
##
## Tracks which state the game is in (see docs/SPEC.md, "States") and switches
## between the scene that belongs to each state.
##
## Every state change goes through change_state(), which:
##   1. records the previous and current state,
##   2. swaps to that state's scene (the old scene is freed automatically),
##   3. emits state_changed.
##
## Error is a terminal state: once entered, the game never leaves it.

## Emitted after every state change. This is a game logic signal, not an FX signal.
signal state_changed(previous: State, current: State)

## Every state in the game. Add new states at the end so saved values never shift.
enum State {
	BOOTSTRAP,
	MAIN_MENU,
	IN_GAME,
	NAME_ENTRY,
	GAME_OVER,
	HISCORE,
	CONFIG_OPTIONS,
	ERROR,
}

## The scene shown for each state. Bootstrap is the project's main scene, so it
## is not listed: the game never returns to it.
const STATE_SCENES := {
	State.MAIN_MENU: "res://scn/main_menu.tscn",
	State.IN_GAME: "res://scn/in_game.tscn",
	State.NAME_ENTRY: "res://scn/name_entry.tscn",
	State.GAME_OVER: "res://scn/game_over.tscn",
	State.HISCORE: "res://scn/hiscore.tscn",
	State.CONFIG_OPTIONS: "res://scn/config.tscn",
	State.ERROR: "res://scn/error.tscn",
}

## The state the game is in now.
var current_state: State = State.BOOTSTRAP
## The state the game was in before the last change.
var previous_state: State = State.BOOTSTRAP
## The message shown on the Error screen. Set by raise_error().
var error_message: String = ""


## Called once by the Bootstrap scene. Sets both states to Bootstrap.
func enter_bootstrap() -> void:
	previous_state = State.BOOTSTRAP
	current_state = State.BOOTSTRAP


## Moves the game to a new state and loads that state's scene.
func change_state(new_state: State) -> void:
	if current_state == State.ERROR:
		push_warning("GameState: ignored change to %s because Error is a terminal state." % State.keys()[new_state])
		return
	if new_state == State.BOOTSTRAP:
		push_error("GameState: the game never returns to Bootstrap.")
		return

	var scene_path: String = STATE_SCENES.get(new_state, "")
	if not ResourceLoader.exists(scene_path):
		# Not implemented yet, or the file was moved. Show the problem instead of crashing.
		raise_error("The scene for state %s was not found:\n%s" % [State.keys()[new_state], scene_path])
		return

	previous_state = current_state
	current_state = new_state
	# Godot frees the old scene at the end of this frame, so nothing leaks.
	get_tree().change_scene_to_file(scene_path)
	state_changed.emit(previous_state, current_state)


## Stops play and shows the Error screen with the given message.
## The message is also written to the log so it can be found later.
func raise_error(message: String) -> void:
	push_error("GameState error: " + message)
	error_message = message
	if current_state == State.ERROR:
		return
	previous_state = current_state
	current_state = State.ERROR
	get_tree().change_scene_to_file(STATE_SCENES[State.ERROR])
	state_changed.emit(previous_state, current_state)


## Closes the game.
func quit_game() -> void:
	get_tree().quit()
