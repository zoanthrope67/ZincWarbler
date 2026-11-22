class_name MenuList
extends VBoxContainer
## A simple menu for keyboard and controller.
##
## Each Label child of this node is one menu item. Items can also be added from
## code with add_item().
##   Move Up / Move Down    - choose an item
##   Confirm                - emits item_chosen
##   Move Left / Move Right - emits item_adjusted (used for things like volume)
##
## The menu uses the game's own actions (move_up, confirm, ...) rather than Godot's
## built-in ui_* actions, so it always follows the player's chosen controls and
## never reacts to Escape, which is reserved.

## The player pressed Confirm on an item.
signal item_chosen(index: int)
## The player pressed Move Left (-1) or Move Right (+1) on an item.
signal item_adjusted(index: int, direction: int)
## A different item is now selected.
signal selection_changed(index: int)

## Text colour of the selected item.
@export var selected_color := Color(1.0, 0.85, 0.2)
## Text colour of the other items.
@export var normal_color := Color(0.65, 0.65, 0.7)
## If true, moving past the last item goes back to the first (and the other way round).
@export var wrap_around := true

## The index of the selected item.
var selected_index := 0
## Set to false to stop the menu reacting to input (e.g. while waiting for a key to bind).
var input_enabled := true

var _labels: Array[Label] = []
var _texts: Array[String] = []


func _ready() -> void:
	for child in get_children():
		if child is Label:
			_labels.append(child)
			_texts.append(child.text)
	_refresh()


## Adds an item at the end of the menu and returns its index.
func add_item(text: String) -> int:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	_labels.append(label)
	_texts.append(text)
	_refresh()
	return _labels.size() - 1


## Changes the text of an item.
func set_item_text(index: int, text: String) -> void:
	_texts[index] = text
	_refresh()


## Selects an item.
func select(index: int) -> void:
	if _labels.is_empty():
		return
	var new_index := clampi(index, 0, _labels.size() - 1)
	if new_index == selected_index:
		return
	selected_index = new_index
	_refresh()
	selection_changed.emit(selected_index)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or not is_visible_in_tree() or _labels.is_empty():
		return

	if InputHelper.is_fresh_press(event, &"move_up"):
		get_viewport().set_input_as_handled()
		_move_selection(-1)
	elif InputHelper.is_fresh_press(event, &"move_down"):
		get_viewport().set_input_as_handled()
		_move_selection(1)
	elif InputHelper.is_fresh_press(event, &"move_left"):
		get_viewport().set_input_as_handled()
		item_adjusted.emit(selected_index, -1)
	elif InputHelper.is_fresh_press(event, &"move_right"):
		get_viewport().set_input_as_handled()
		item_adjusted.emit(selected_index, 1)
	elif InputHelper.is_fresh_press(event, &"confirm"):
		get_viewport().set_input_as_handled()
		item_chosen.emit(selected_index)


func _move_selection(step: int) -> void:
	var count := _labels.size()
	var target := selected_index + step
	if wrap_around:
		target = posmod(target, count)
	select(target)


# Redraws every item: the selected one is highlighted and marked with > <.
func _refresh() -> void:
	for i in _labels.size():
		var is_selected := i == selected_index
		_labels[i].text = ("> %s <" % _texts[i]) if is_selected else _texts[i]
		_labels[i].add_theme_color_override("font_color", selected_color if is_selected else normal_color)
