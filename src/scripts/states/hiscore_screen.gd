extends Control
## Hiscore state: shows the top 10 hi-scores. Back returns to the Main Menu.

## Column headings, left to right.
const HEADINGS := ["#", "NAME", "SCORE", "TIME", "DATE"]
## Colour of the heading row.
const HEADING_COLOR := Color(1.0, 0.85, 0.2)

@onready var _table: GridContainer = %Table


func _ready() -> void:
	_table.columns = HEADINGS.size()
	for heading in HEADINGS:
		_add_cell(heading, HEADING_COLOR)

	var rank := 1
	for entry in Hiscores.get_entries():
		_add_cell(str(rank))
		_add_cell(entry.name)
		_add_cell(str(entry.score))
		_add_cell(TextFormat.time(entry.seconds_survived))
		_add_cell(entry.datetime.replace("T", " "))
		rank += 1


func _unhandled_input(event: InputEvent) -> void:
	if InputHelper.is_fresh_press(event, &"back"):
		get_viewport().set_input_as_handled()
		GameState.change_state(GameState.State.MAIN_MENU)


func _add_cell(text: String, color := Color.WHITE) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	_table.add_child(label)
