class_name Hud
extends CanvasLayer
## The in-game HUD: score, time survived, the health lifebar, the BorderStorm's
## DANGER warning and the "YOU DIED" banner. Layout and looks are in
## scn/ui/hud.tscn; animations are in its AnimationPlayer:
##   "you_died"      - plays once when the player dies (fades the banner in)
##   "you_died_loop" - plays on repeat afterwards (pulses the banner)

## Text of the score display. %d is replaced by the score.
const SCORE_TEXT := "SCORE %d"

const PIP_SCENE := preload("res://scn/ui/health_pip.tscn")

var _shown_seconds := -1

@onready var _score_label: Label = %ScoreLabel
@onready var _time_label: Label = %TimeLabel
@onready var _pips: HBoxContainer = %Pips
@onready var _storm_danger: Control = %StormDanger
@onready var _danger_bar: ProgressBar = %DangerBar
@onready var _you_died: Control = %YouDied
@onready var _continue_hint: Label = %ContinueHint
@onready var _animation: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_storm_danger.visible = false
	_you_died.visible = false
	# Hidden with transparency (not visibility) so the banner does not jump.
	_continue_hint.modulate.a = 0.0


## Builds one pip per point of health and resets the displays.
func setup(max_health: int) -> void:
	for pip in _pips.get_children():
		pip.free()
	for i in max_health:
		_pips.add_child(PIP_SCENE.instantiate())
	set_score(0)
	set_time(0.0)


func set_score(score: int) -> void:
	_score_label.text = SCORE_TEXT % score


## Shows the time survived. Only redraws when the whole second changes.
func set_time(seconds: float) -> void:
	var whole := floori(seconds)
	if whole == _shown_seconds:
		return
	_shown_seconds = whole
	_time_label.text = TextFormat.time(whole)


## Updates the lifebar. Pips beyond `health` play their "lose" animation.
func set_health(health: int) -> void:
	var index := 0
	for pip: HealthPip in _pips.get_children():
		if index >= health:
			pip.lose()
		elif not pip.is_full:
			pip.set_full()
		index += 1


## Shows the DANGER warning in the middle of the screen with its bar filled to
## `progress` (0 = empty, 1 = full), or hides it when `show_warning` is false.
## The bar fills while the player is in the BorderStorm and is full when the
## storm starts hurting them (see BorderStorm.get_danger_progress()).
func set_storm_danger(show_warning: bool, progress: float) -> void:
	_storm_danger.visible = show_warning
	if show_warning:
		_danger_bar.value = clampf(progress, 0.0, 1.0)


## Shows the animated "YOU DIED" banner.
func show_you_died() -> void:
	_you_died.visible = true
	_continue_hint.modulate.a = 0.0
	_animation.play(&"you_died")
	_animation.queue(&"you_died_loop")


## Shows the "Press Confirm to continue" line under the banner.
func show_continue_hint() -> void:
	_continue_hint.modulate.a = 1.0


## True while the "YOU DIED" banner is showing.
func is_showing_you_died() -> bool:
	return _you_died.visible
