extends Control
## Name Entry state: the player enters a name for their hi-score.
##
## The screen shows a grid of the allowed characters (A-Z, 0-9) with a
## BACKSPACE and an END button underneath. The arrows move the cursor.
##   Confirm on a character - adds it (up to Hiscores.MAX_NAME_LENGTH)
##   Confirm on BACKSPACE   - removes the last character
##   Confirm on END         - saves the hi-score and goes to Game Over
##                            (ignored while the name is empty)
##   Back                   - removes the last character and moves the cursor to BACKSPACE
## When the name is full, the cursor jumps to END. There is no way to skip this screen.

signal fx_cursor_moved
signal fx_character_added(character: String)
signal fx_character_removed
## Emitted when a press does nothing (name full, or END with an empty name). FX only.
signal fx_press_refused
signal fx_name_saved(player_name: String)

## Characters per row of the grid.
const COLUMNS := 9
## Shown in place of characters not entered yet.
const EMPTY_SLOT := "_"
## Text colour of the item under the cursor.
const SELECTED_COLOR := Color(1.0, 0.85, 0.2)
## Text colour of the other items.
const NORMAL_COLOR := Color(0.65, 0.65, 0.7)

## The name entered so far.
var player_name := ""

# The cursor. Rows 0 to _character_rows - 1 are the character grid; the row
# after that holds the buttons (column 0 = BACKSPACE, column 1 = END).
var _row := 0
var _column := 0
var _character_rows := 0
var _character_labels: Array[Label] = []
var _saved := false

@onready var _grid: GridContainer = %Characters
@onready var _backspace: Label = %Backspace
@onready var _end: Label = %End
@onready var _name_label: Label = %NameLabel
@onready var _result_label: Label = %ResultLabel


func _ready() -> void:
	_grid.columns = COLUMNS
	for character in Hiscores.ALLOWED_NAME_CHARACTERS:
		var label := Label.new()
		label.text = character
		# Fixed cell size, so the grid does not shift when the selected
		# character is drawn larger.
		label.custom_minimum_size = Vector2(72, 72)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_grid.add_child(label)
		_character_labels.append(label)
	_character_rows = ceili(_character_labels.size() / float(COLUMNS))
	_result_label.text = "SCORE %d    TIME %s" % [GameState.last_score, TextFormat.time(GameState.last_seconds_survived)]
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if _saved:
		return
	var actions := [&"move_left", &"move_right", &"move_up", &"move_down", &"confirm", &"back"]
	var pressed: StringName = &""
	for action in actions:
		if InputHelper.is_fresh_press(event, action):
			pressed = action
			break
	if pressed.is_empty():
		return
	# Mark the input as used first: saving changes the scene, after which this
	# screen is no longer in the scene tree.
	get_viewport().set_input_as_handled()

	match pressed:
		&"move_left":
			_move(0, -1)
		&"move_right":
			_move(0, 1)
		&"move_up":
			_move(-1, 0)
		&"move_down":
			_move(1, 0)
		&"confirm":
			_press_selected()
		&"back":
			_remove_last_character()
			_put_cursor_on_button(0)
	if not _saved:
		_refresh()


## The character under the cursor, or "BACKSPACE" / "END".
func get_selected_item() -> String:
	if _on_button_row():
		return "BACKSPACE" if _column == 0 else "END"
	return _character_labels[_row * COLUMNS + _column].text


func _press_selected() -> void:
	match get_selected_item():
		"BACKSPACE":
			_remove_last_character()
		"END":
			if player_name.is_empty():
				fx_press_refused.emit()
			else:
				_save()
		var character:
			if player_name.length() >= Hiscores.MAX_NAME_LENGTH:
				fx_press_refused.emit()
				return
			player_name += character
			fx_character_added.emit(character)
			if player_name.length() == Hiscores.MAX_NAME_LENGTH:
				_put_cursor_on_button(1)


func _remove_last_character() -> void:
	if player_name.is_empty():
		fx_press_refused.emit()
		return
	player_name = player_name.left(-1)
	fx_character_removed.emit()


func _save() -> void:
	_saved = true
	Hiscores.add_entry(player_name, GameState.last_score, GameState.last_seconds_survived, GameState.last_datetime)
	fx_name_saved.emit(player_name)
	GameState.change_state(GameState.State.GAME_OVER)


# --- Cursor -------------------------------------------------------------------

func _on_button_row() -> bool:
	return _row == _character_rows


func _row_length(row: int) -> int:
	if row == _character_rows:
		return 2
	return mini(COLUMNS, _character_labels.size() - row * COLUMNS)


# Moves the cursor by one row or column, wrapping round at the edges.
func _move(row_step: int, column_step: int) -> void:
	if column_step != 0:
		_column = posmod(_column + column_step, _row_length(_row))
	elif row_step != 0:
		var was_on_buttons := _on_button_row()
		_row = posmod(_row + row_step, _character_rows + 1)
		if _on_button_row():
			# Left half of the grid leads to BACKSPACE, right half to END.
			_column = 0 if _column * 2 < COLUMNS else 1
		elif was_on_buttons:
			# BACKSPACE leads to the left side of the grid, END to the right side.
			_column = 1 if _column == 0 else COLUMNS - 2
		_column = mini(_column, _row_length(_row) - 1)
	fx_cursor_moved.emit()


func _put_cursor_on_button(button_column: int) -> void:
	if _on_button_row() and _column == button_column:
		return
	_row = _character_rows
	_column = button_column
	fx_cursor_moved.emit()


# --- Display ------------------------------------------------------------------

func _refresh() -> void:
	var slots := PackedStringArray()
	for i in Hiscores.MAX_NAME_LENGTH:
		slots.append(player_name[i] if i < player_name.length() else EMPTY_SLOT)
	_name_label.text = " ".join(slots)

	var selected := get_selected_item()
	for i in _character_labels.size():
		var is_selected := not _on_button_row() and i == _row * COLUMNS + _column
		_style(_character_labels[i], is_selected)
	_style(_backspace, selected == "BACKSPACE")
	_style(_end, selected == "END")


func _style(label: Label, is_selected: bool) -> void:
	label.add_theme_color_override("font_color", SELECTED_COLOR if is_selected else NORMAL_COLOR)
	label.add_theme_font_size_override("font_size", 52 if is_selected else 40)
