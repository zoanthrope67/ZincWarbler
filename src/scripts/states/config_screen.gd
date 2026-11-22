extends Control
## Config Options state: volume, fullscreen, controls and clearing the hi-scores.
##
##   Move Up / Move Down    - choose an option
##   Move Left / Move Right - change volume or fullscreen
##   Confirm                - toggle / start rebinding / activate
##   Back                   - return to the Main Menu
##
## Every change is applied and saved straight away by the Settings autoload.
##
## Rebinding: choose a control and press Confirm, then press the new key or
## controller button. Escape and Start are reserved and are refused. If nothing
## is pressed within REBIND_TIMEOUT_SECONDS, rebinding is cancelled.

## Seconds to wait for a key or button when rebinding before giving up.
const REBIND_TIMEOUT_SECONDS := 5.0

## What each menu row does.
enum Option {
	MUSIC_VOLUME,
	SFX_VOLUME,
	FULLSCREEN,
	CONTROL,
	RESET_CONTROLS,
	CLEAR_HISCORES,
	BACK,
}

@onready var _menu: MenuList = %Menu
@onready var _status: Label = %Status

# One entry per menu row, in order: {"option": Option, "action": String}.
# "action" is only used by CONTROL rows.
var _rows: Array[Dictionary] = []
# The action waiting for a new key or button, or "" when not rebinding.
var _listening_action := ""
var _listen_time_left := 0.0
# Why the last key was refused while rebinding (shown above the countdown).
var _listen_problem := ""
# Clearing the hi-scores needs Confirm pressed twice in a row.
var _clear_armed := false


func _ready() -> void:
	_add_row(Option.MUSIC_VOLUME)
	_add_row(Option.SFX_VOLUME)
	_add_row(Option.FULLSCREEN)
	for action in Settings.REBINDABLE_ACTIONS:
		_add_row(Option.CONTROL, action)
	_add_row(Option.RESET_CONTROLS)
	_add_row(Option.CLEAR_HISCORES)
	_add_row(Option.BACK)

	_menu.item_chosen.connect(_on_item_chosen)
	_menu.item_adjusted.connect(_on_item_adjusted)
	_menu.selection_changed.connect(_on_selection_changed)
	Settings.controls_changed.connect(_refresh_all_rows)
	_set_status("")


func _process(delta: float) -> void:
	if _listening_action.is_empty():
		return
	_listen_time_left -= delta
	if _listen_time_left <= 0.0:
		_stop_listening()
		_set_status("Rebinding cancelled.")
	else:
		var prompt := "Press a key or controller button for %s (%d)" % [
				Settings.REBINDABLE_ACTIONS[_listening_action], ceili(_listen_time_left)]
		_set_status(prompt if _listen_problem.is_empty() else _listen_problem + "\n" + prompt)


# While rebinding, the next key or button press is captured here, before the
# menu or the Back handler can see it.
func _input(event: InputEvent) -> void:
	if _listening_action.is_empty():
		return
	var is_key_press: bool = event is InputEventKey and event.pressed and not event.echo
	var is_button_press: bool = event is InputEventJoypadButton and event.pressed
	if not (is_key_press or is_button_press):
		return

	get_viewport().set_input_as_handled()
	var problem := Settings.rebind(_listening_action, event)
	if problem.is_empty():
		_set_status("%s set." % Settings.REBINDABLE_ACTIONS[_listening_action])
		_stop_listening()
	else:
		# Keep listening so the player can try another key.
		_listen_problem = problem
		_listen_time_left = REBIND_TIMEOUT_SECONDS


func _unhandled_input(event: InputEvent) -> void:
	if _listening_action.is_empty() and InputHelper.is_fresh_press(event, &"back"):
		get_viewport().set_input_as_handled()
		GameState.change_state(GameState.State.MAIN_MENU)


func _on_item_chosen(index: int) -> void:
	var row := _rows[index]
	match row.option:
		Option.FULLSCREEN:
			Settings.set_fullscreen(not Settings.fullscreen)
		Option.CONTROL:
			_start_listening(row.action)
		Option.RESET_CONTROLS:
			Settings.reset_controls_to_default()
			_set_status("Controls reset to default.")
		Option.CLEAR_HISCORES:
			if _clear_armed:
				Hiscores.reset_to_starting_table()
				_clear_armed = false
				_set_status("Hi-scores cleared.")
			else:
				_clear_armed = true
				_set_status("Press Confirm again to clear the hi-scores.")
		Option.BACK:
			GameState.change_state(GameState.State.MAIN_MENU)
	_refresh_row(index)


func _on_item_adjusted(index: int, direction: int) -> void:
	match _rows[index].option:
		Option.MUSIC_VOLUME:
			Settings.set_music_volume(Settings.music_volume + direction * Settings.VOLUME_STEP)
		Option.SFX_VOLUME:
			Settings.set_sfx_volume(Settings.sfx_volume + direction * Settings.VOLUME_STEP)
		Option.FULLSCREEN:
			Settings.set_fullscreen(not Settings.fullscreen)
	_refresh_row(index)


func _on_selection_changed(_index: int) -> void:
	# Moving away cancels a half-finished "clear hi-scores".
	if _clear_armed:
		_clear_armed = false
		_refresh_all_rows()
	_set_status("")


func _start_listening(action: String) -> void:
	_listening_action = action
	_listen_time_left = REBIND_TIMEOUT_SECONDS
	_listen_problem = ""
	_menu.input_enabled = false


func _stop_listening() -> void:
	_listening_action = ""
	_menu.input_enabled = true
	_refresh_all_rows()


func _add_row(option: Option, action := "") -> void:
	_rows.append({"option": option, "action": action})
	_menu.add_item(_row_text(_rows.size() - 1))


func _refresh_row(index: int) -> void:
	_menu.set_item_text(index, _row_text(index))


func _refresh_all_rows() -> void:
	for i in _rows.size():
		_refresh_row(i)


# The text shown for a menu row.
func _row_text(index: int) -> String:
	var row := _rows[index]
	match row.option:
		Option.MUSIC_VOLUME:
			return "Music Volume:  < %d%% >" % roundi(Settings.music_volume * 100)
		Option.SFX_VOLUME:
			return "Sound Effects Volume:  < %d%% >" % roundi(Settings.sfx_volume * 100)
		Option.FULLSCREEN:
			return "Fullscreen:  < %s >" % ("On" if Settings.fullscreen else "Off")
		Option.CONTROL:
			return "%s:  %s" % [Settings.REBINDABLE_ACTIONS[row.action], Settings.get_binding_text(row.action)]
		Option.RESET_CONTROLS:
			return "Reset Controls to Default"
		Option.CLEAR_HISCORES:
			return "Clear Hi-scores (press again to confirm)" if _clear_armed else "Clear Hi-scores"
		Option.BACK:
			return "Back to Main Menu"
	return ""


func _set_status(text: String) -> void:
	_status.text = text
