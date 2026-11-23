extends Control
## Game Over state: shows the score and time survived from the last game.
## A fresh press of Confirm, once CONFIRM_DELAY_SECONDS have passed, returns to
## the Main Menu. (The delay stops a press meant for the previous screen from
## skipping this one.)

## Seconds before Confirm is accepted.
const CONFIRM_DELAY_SECONDS := 0.5

var _time_on_screen := 0.0

@onready var _score_label: Label = %ScoreLabel
@onready var _time_label: Label = %TimeLabel
@onready var _hint: Label = %Hint


func _ready() -> void:
	_score_label.text = "SCORE %d" % GameState.last_score
	_time_label.text = "SURVIVED %s" % TextFormat.time(GameState.last_seconds_survived)
	# Hidden with transparency (not visibility) so the layout does not jump.
	_hint.modulate.a = 0.0


func _process(delta: float) -> void:
	_time_on_screen += delta
	if _time_on_screen >= CONFIRM_DELAY_SECONDS:
		_hint.modulate.a = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if _time_on_screen >= CONFIRM_DELAY_SECONDS and InputHelper.is_fresh_press(event, &"confirm"):
		get_viewport().set_input_as_handled()
		GameState.change_state(GameState.State.MAIN_MENU)
