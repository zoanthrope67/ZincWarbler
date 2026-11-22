extends Control
## Error state: shows what went wrong. A fresh press of Confirm quits the game.
##
## Error is a terminal state: the game never leaves it.
## This screen is for development only and will be removed later (docs/SPEC.md).

@onready var _message: Label = %Message


func _ready() -> void:
	_message.text = GameState.error_message if not GameState.error_message.is_empty() else "Unknown error."


func _unhandled_input(event: InputEvent) -> void:
	if InputHelper.is_fresh_press(event, &"confirm"):
		get_viewport().set_input_as_handled()
		GameState.quit_game()
