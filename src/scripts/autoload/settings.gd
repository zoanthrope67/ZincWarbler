extends Node
## Settings autoload: audio volumes, fullscreen and control bindings.
##
## Bootstrap calls load_settings() once when the game starts. After that, every
## change made on the Config screen is applied straight away and saved to disk.
##
## Controls
## --------
## The default controls are set in the Godot editor:
##   Project > Project Settings > Input Map
## This script reads those defaults when the game starts, so changing them in the
## editor changes the game's defaults (players' saved choices still override them).
##
## Each rebindable action has one keyboard key and one controller button that the
## player can change. Any other events on an action (for example the left stick on
## the move actions) are fixed and are kept as they are.
##
## If the player picks a key that another action already uses, the two actions
## swap keys, so no key is ever used twice and no action is ever left unbound.

## Emitted whenever a key or button binding changes. Game logic signal.
signal controls_changed

## Bump this when the save format changes. Files with a different version are
## ignored and replaced with the defaults.
const SAVE_VERSION := 1

# --- Designer defaults --------------------------------------------------------

## Starting music volume, from 0.0 (silent) to 1.0 (full).
const DEFAULT_MUSIC_VOLUME := 0.8
## Starting sound effects volume, from 0.0 (silent) to 1.0 (full).
const DEFAULT_SFX_VOLUME := 0.8
## Whether the game starts fullscreen. The spec says On by default.
const DEFAULT_FULLSCREEN := true
## How much one press of left/right changes a volume on the Config screen.
const VOLUME_STEP := 0.1

## Audio bus names. These buses are set up in res://default_bus_layout.tres
## (the Audio tab at the bottom of the Godot editor).
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

## Actions the player can rebind, and the name shown for each on the Config
## screen. They appear on the Config screen in this order.
const REBINDABLE_ACTIONS := {
	"move_up": "Move Up",
	"move_down": "Move Down",
	"move_left": "Move Left",
	"move_right": "Move Right",
	"confirm": "Confirm / Fire",
	"back": "Back / Dash",
}

## Keys that can never be bound. Escape is reserved for pausing (docs/SPEC.md, Controls).
const RESERVED_KEYS: Array[Key] = [KEY_ESCAPE]
## Controller buttons that can never be bound. Start is reserved for pausing.
const RESERVED_JOY_BUTTONS: Array[JoyButton] = [JOY_BUTTON_START]

## Names shown for controller buttons. Unlisted buttons show as "Button <number>".
const JOY_BUTTON_NAMES := {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_GUIDE: "Guide",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "Left Stick Click",
	JOY_BUTTON_RIGHT_STICK: "Right Stick Click",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-Pad Up",
	JOY_BUTTON_DPAD_DOWN: "D-Pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-Pad Left",
	JOY_BUTTON_DPAD_RIGHT: "D-Pad Right",
}

## Where settings are saved. user:// is the game's own folder on the player's machine.
var save_path := "user://config.cfg"

## Current volumes, from 0.0 to 1.0.
var music_volume := DEFAULT_MUSIC_VOLUME
var sfx_volume := DEFAULT_SFX_VOLUME
## Whether the game is fullscreen.
var fullscreen := DEFAULT_FULLSCREEN

# Current bindings. Keys are stored as physical keycodes (the key's position on
# the keyboard), so the controls work the same on any keyboard layout.
# 0 means "no key" and -1 means "no controller button".
var _key_bindings := {}
var _joy_bindings := {}
# The defaults from the Input Map, recorded before any saved settings are applied.
var _default_key_bindings := {}
var _default_joy_bindings := {}


func _ready() -> void:
	_record_default_bindings()


# --- Loading and saving -------------------------------------------------------

## Loads saved settings (or the defaults if there are none) and applies them.
## Called once by Bootstrap.
func load_settings() -> void:
	_reset_all_to_defaults()

	var file := ConfigFile.new()
	var err := file.load(save_path)
	if err == ERR_FILE_NOT_FOUND:
		save_settings()
	elif err != OK:
		push_warning("Settings: could not read %s (error %d). Using defaults." % [save_path, err])
		save_settings()
	elif file.get_value("meta", "version", -1) != SAVE_VERSION:
		push_warning("Settings: %s is from a different version. Using defaults." % save_path)
		save_settings()
	else:
		_read_from_file(file)

	apply_all()


## Saves the current settings to disk.
func save_settings() -> void:
	var file := ConfigFile.new()
	file.set_value("meta", "version", SAVE_VERSION)
	file.set_value("audio", "music_volume", music_volume)
	file.set_value("audio", "sfx_volume", sfx_volume)
	file.set_value("display", "fullscreen", fullscreen)
	for action in REBINDABLE_ACTIONS:
		file.set_value("controls", action + "_key", _key_bindings[action])
		file.set_value("controls", action + "_joy", _joy_bindings[action])
	var err := file.save(save_path)
	if err != OK:
		push_error("Settings: could not save %s (error %d)." % [save_path, err])


## Applies every setting to the engine (audio buses, window mode, Input Map).
func apply_all() -> void:
	_apply_volume(MUSIC_BUS, music_volume)
	_apply_volume(SFX_BUS, sfx_volume)
	_apply_fullscreen()
	_apply_controls()


# --- Audio and display --------------------------------------------------------

## Sets the music volume (0.0 to 1.0), applies it and saves.
func set_music_volume(value: float) -> void:
	music_volume = clampf(snappedf(value, 0.01), 0.0, 1.0)
	_apply_volume(MUSIC_BUS, music_volume)
	save_settings()


## Sets the sound effects volume (0.0 to 1.0), applies it and saves.
func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(snappedf(value, 0.01), 0.0, 1.0)
	_apply_volume(SFX_BUS, sfx_volume)
	save_settings()


## Turns fullscreen on or off, applies it and saves.
func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_fullscreen()
	save_settings()


# --- Controls -----------------------------------------------------------------

## Binds a key or controller button to an action.
## Returns an empty string on success, or a message explaining why it was refused.
func rebind(action: String, event: InputEvent) -> String:
	if not REBINDABLE_ACTIONS.has(action):
		return "%s cannot be rebound." % action

	if event is InputEventKey:
		var code: int = event.physical_keycode
		if code == 0:
			return "That key cannot be used."
		if code in RESERVED_KEYS:
			return "%s is reserved and cannot be bound." % _key_name(code)
		_assign_with_swap(_key_bindings, action, code)
	elif event is InputEventJoypadButton:
		var button: int = event.button_index
		if button in RESERVED_JOY_BUTTONS:
			return "%s is reserved and cannot be bound." % _joy_name(button)
		_assign_with_swap(_joy_bindings, action, button)
	else:
		return "Only keys and controller buttons can be bound."

	_apply_controls()
	save_settings()
	controls_changed.emit()
	return ""


## Puts every rebindable action back to the Input Map defaults and saves.
func reset_controls_to_default() -> void:
	_key_bindings = _default_key_bindings.duplicate()
	_joy_bindings = _default_joy_bindings.duplicate()
	_apply_controls()
	save_settings()
	controls_changed.emit()


## Returns text describing an action's current key and button, e.g. "Z / A".
func get_binding_text(action: String) -> String:
	var key_text := _key_name(_key_bindings.get(action, 0))
	var joy_text := _joy_name(_joy_bindings.get(action, -1))
	return "%s / %s" % [key_text, joy_text]


# --- Internals ----------------------------------------------------------------

func _record_default_bindings() -> void:
	for action in REBINDABLE_ACTIONS:
		var key := 0
		var button := -1
		if InputMap.has_action(action):
			for event in InputMap.action_get_events(action):
				if event is InputEventKey and key == 0:
					key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
				elif event is InputEventJoypadButton and button == -1:
					button = event.button_index
		else:
			push_error("Settings: the Input Map has no action called '%s'." % action)
		_default_key_bindings[action] = key
		_default_joy_bindings[action] = button


func _reset_all_to_defaults() -> void:
	music_volume = DEFAULT_MUSIC_VOLUME
	sfx_volume = DEFAULT_SFX_VOLUME
	fullscreen = DEFAULT_FULLSCREEN
	_key_bindings = _default_key_bindings.duplicate()
	_joy_bindings = _default_joy_bindings.duplicate()


func _read_from_file(file: ConfigFile) -> void:
	music_volume = clampf(float(file.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME)), 0.0, 1.0)
	sfx_volume = clampf(float(file.get_value("audio", "sfx_volume", DEFAULT_SFX_VOLUME)), 0.0, 1.0)
	fullscreen = bool(file.get_value("display", "fullscreen", DEFAULT_FULLSCREEN))

	for action in REBINDABLE_ACTIONS:
		var key = file.get_value("controls", action + "_key", _default_key_bindings[action])
		var button = file.get_value("controls", action + "_joy", _default_joy_bindings[action])
		if typeof(key) == TYPE_INT and key > 0 and not key in RESERVED_KEYS:
			_key_bindings[action] = key
		if typeof(button) == TYPE_INT and button >= 0 and button < JOY_BUTTON_MAX and not button in RESERVED_JOY_BUTTONS:
			_joy_bindings[action] = button

	# A hand-edited or damaged file could give two actions the same input.
	if _has_duplicates(_key_bindings) or _has_duplicates(_joy_bindings):
		push_warning("Settings: saved controls had duplicate bindings. Using default controls.")
		_key_bindings = _default_key_bindings.duplicate()
		_joy_bindings = _default_joy_bindings.duplicate()


func _has_duplicates(bindings: Dictionary) -> bool:
	var seen := {}
	for value in bindings.values():
		if seen.has(value):
			return true
		seen[value] = true
	return false


# Gives `action` the new input. If another action already had that input, the
# other action gets `action`'s old input instead (a swap).
func _assign_with_swap(bindings: Dictionary, action: String, new_input: int) -> void:
	var old_input: int = bindings[action]
	for other in bindings:
		if other != action and bindings[other] == new_input:
			bindings[other] = old_input
	bindings[action] = new_input


# Rebuilds the key and controller button events of each rebindable action.
# Other events (such as the left stick on the move actions) are left alone.
func _apply_controls() -> void:
	for action in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey or event is InputEventJoypadButton:
				InputMap.action_erase_event(action, event)

		# device = -1 means "any keyboard / any controller".
		var key: int = _key_bindings[action]
		if key > 0:
			var key_event := InputEventKey.new()
			key_event.device = -1
			key_event.physical_keycode = key
			InputMap.action_add_event(action, key_event)

		var button: int = _joy_bindings[action]
		if button >= 0:
			var joy_event := InputEventJoypadButton.new()
			joy_event.device = -1
			joy_event.button_index = button
			InputMap.action_add_event(action, joy_event)


func _apply_volume(bus_name: String, volume: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus == -1:
		push_warning("Settings: there is no audio bus called '%s'." % bus_name)
		return
	AudioServer.set_bus_mute(bus, volume <= 0.0)
	if volume > 0.0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(volume))


func _apply_fullscreen() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func _key_name(code: int) -> String:
	if code <= 0:
		return "(none)"
	# Show the name printed on the player's own keyboard layout where possible.
	# The headless display server (used for automated runs) cannot do this.
	if DisplayServer.get_name() == "headless":
		return OS.get_keycode_string(code)
	return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code))


func _joy_name(button: int) -> String:
	if button < 0:
		return "(none)"
	return JOY_BUTTON_NAMES.get(button, "Button %d" % button)
