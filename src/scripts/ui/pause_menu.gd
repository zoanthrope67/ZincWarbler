class_name PauseMenu
extends CanvasLayer
## The pause menu, and the "3, 2, 1" countdown before play resumes
## (docs/SPEC.md, Pausing).
##
## Pause (Escape / Start; these cannot be rebound) opens the menu while the
## player is alive. The whole game is paused with get_tree().paused. This node
## keeps running because its Process Mode is set to Always in the scene.
##
## Menu items:
##   Resume  - instant. Hides the menu and counts down 3, 2, 1, then play resumes.
##   Restart - hold Confirm for HOLD_SECONDS: starts a new game. The score is not saved.
##   Exit    - hold Confirm for HOLD_SECONDS: goes to the Main Menu. The score is not saved.
## A bar fills while Confirm is held. Releasing Confirm or moving the cursor
## cancels the hold.
##
## While the menu is open:
##   Pause - the same as choosing Resume
##   Back  - moves the cursor to Resume (does not choose it)
## Pausing is not possible during the countdown or once the player is dead.
##
## Layout and looks are in scn/ui/pause_menu.tscn. The countdown number plays the
## "countdown_tick" animation of the AnimationPlayer once for each number.

# --- FX signals (effects and sounds only; never used for game logic) -------
## The pause menu has opened.
signal fx_pause_menu_entered
## Resume was chosen (the countdown is starting).
signal fx_pause_resume
## Restart was chosen (the hold finished), just before the new game starts.
signal fx_pause_restart
## Exit was chosen (the hold finished), just before going to the Main Menu.
signal fx_pause_exit
## A countdown number appeared: 3, 2 and then 1, one second apart.
signal fx_countdown(number: int)

## Seconds Confirm must be held to choose Restart or Exit.
const HOLD_SECONDS := 0.5
## The number the countdown starts from. Each number shows for one second.
const COUNTDOWN_FROM := 3
## Shown when Restart or Exit is selected and the score would make the hi-score
## table. %s is replaced by the item's name.
const HISCORE_WARNING_TEXT := "Your score would make the hi-score table.\n%s will NOT save it."

## The menu items, in the same order as the Label children of the Menu node.
## If you reorder the labels in the scene, reorder this list to match.
enum Item {
	RESUME,
	RESTART,
	EXIT,
}

enum Mode {
	CLOSED,     ## The game is being played (or the player is dead).
	MENU,       ## The game is paused and the menu is showing.
	COUNTDOWN,  ## The game is still paused and the countdown is showing.
}

var _mode := Mode.CLOSED
var _game: InGame = null
var _player: Player = null

# Holding Confirm on Restart or Exit.
var _is_holding := false
var _hold_time := 0.0

# Seconds until play resumes, and the countdown number currently shown.
var _countdown_left := 0.0
var _shown_number := 0

@onready var _menu_screen: Control = %MenuScreen
@onready var _menu: MenuList = %Menu
@onready var _hold_bar: ProgressBar = %HoldBar
@onready var _warning: Label = %Warning
@onready var _countdown_screen: Control = %CountdownScreen
@onready var _number: Label = %PlaceholderCountdownNumber
@onready var _animation: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_menu_screen.visible = false
	_countdown_screen.visible = false
	_menu.item_chosen.connect(_on_item_chosen)
	_menu.selection_changed.connect(_on_selection_changed)
	# Scale the countdown number around its centre.
	_number.resized.connect(func() -> void: _number.pivot_offset = _number.size / 2.0)


## Connects the menu to the game. Called by the In Game scene. Until this is
## called (e.g. when the arena failed validation) the game cannot be paused.
func setup(game: InGame, player: Player) -> void:
	_game = game
	_player = player


## True while the game is paused by this menu (menu or countdown showing).
func is_open() -> bool:
	return _mode != Mode.CLOSED


func _unhandled_input(event: InputEvent) -> void:
	if InputHelper.is_fresh_press(event, &"pause"):
		match _mode:
			Mode.CLOSED:
				if _can_pause():
					get_viewport().set_input_as_handled()
					_open_menu()
			Mode.MENU:
				get_viewport().set_input_as_handled()
				_choose_resume()
			Mode.COUNTDOWN:
				# Cannot pause again during the countdown.
				get_viewport().set_input_as_handled()
		return

	if _mode == Mode.MENU and InputHelper.is_fresh_press(event, &"back"):
		get_viewport().set_input_as_handled()
		_cancel_hold()
		_menu.select(Item.RESUME)


func _process(delta: float) -> void:
	match _mode:
		Mode.MENU:
			_update_hold(delta)
		Mode.COUNTDOWN:
			_update_countdown(delta)


func _can_pause() -> bool:
	return _game != null and _player != null and not _player.is_dead


func _open_menu() -> void:
	_mode = Mode.MENU
	get_tree().paused = true
	_cancel_hold()
	_menu.select(Item.RESUME)
	_update_warning()
	_menu_screen.visible = true
	fx_pause_menu_entered.emit()


func _on_item_chosen(index: int) -> void:
	if _mode != Mode.MENU:
		return
	match index:
		Item.RESUME:
			_choose_resume()
		Item.RESTART, Item.EXIT:
			_start_hold()


func _on_selection_changed(_index: int) -> void:
	_cancel_hold()
	_update_warning()


# --- Holding Confirm for Restart / Exit ---------------------------------------

func _start_hold() -> void:
	_is_holding = true
	_hold_time = 0.0
	_hold_bar.value = 0.0
	_hold_bar.modulate.a = 1.0


func _cancel_hold() -> void:
	_is_holding = false
	_hold_time = 0.0
	_hold_bar.value = 0.0
	# Hidden with transparency (not visibility) so the layout does not jump.
	_hold_bar.modulate.a = 0.0


func _update_hold(delta: float) -> void:
	if not _is_holding:
		return
	if not Input.is_action_pressed(&"confirm"):
		_cancel_hold()
		return
	_hold_time += delta
	_hold_bar.value = minf(_hold_time / HOLD_SECONDS, 1.0)
	if _hold_time >= HOLD_SECONDS:
		_finish_hold()


func _finish_hold() -> void:
	_is_holding = false
	_mode = Mode.CLOSED
	# GameState un-pauses the game when it changes state. end_game() is not
	# called, so the score is not saved to the hi-score table.
	match _menu.selected_index:
		Item.RESTART:
			fx_pause_restart.emit()
			GameState.change_state(GameState.State.IN_GAME)
		Item.EXIT:
			fx_pause_exit.emit()
			GameState.change_state(GameState.State.MAIN_MENU)


# Shows the hi-score warning on Restart and Exit if the score would make the table.
func _update_warning() -> void:
	var item := _menu.selected_index
	var would_lose_hiscore := Hiscores.qualifies(_game.score, floori(_game.time_survived))
	if item != Item.RESUME and would_lose_hiscore:
		_warning.text = HISCORE_WARNING_TEXT % ("Restart" if item == Item.RESTART else "Exit")
		_warning.modulate.a = 1.0
	else:
		_warning.modulate.a = 0.0


# --- Resume and the countdown ---------------------------------------------------

func _choose_resume() -> void:
	_cancel_hold()
	_mode = Mode.COUNTDOWN
	_menu_screen.visible = false
	_countdown_screen.visible = true
	_countdown_left = COUNTDOWN_FROM
	_shown_number = 0
	fx_pause_resume.emit()
	_show_countdown_number(COUNTDOWN_FROM)


func _update_countdown(delta: float) -> void:
	_countdown_left -= delta
	if _countdown_left <= 0.0001:
		_resume_play()
		return
	# The tiny tolerance stops rounding errors in the frame times from showing a
	# number one frame late.
	var number := ceili(_countdown_left - 0.0001)
	if number != _shown_number:
		_show_countdown_number(number)


func _show_countdown_number(number: int) -> void:
	_shown_number = number
	_number.text = str(number)
	_animation.stop()
	_animation.play(&"countdown_tick")
	fx_countdown.emit(number)


func _resume_play() -> void:
	_mode = Mode.CLOSED
	_countdown_screen.visible = false
	_animation.stop()
	get_tree().paused = false
	# Confirm or Back may still be held from the menu. They should not start
	# firing or dashing until they are pressed again.
	_player.ignore_held_buttons()
