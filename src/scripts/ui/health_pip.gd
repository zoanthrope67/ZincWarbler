class_name HealthPip
extends Control
## One point of health on the HUD lifebar.
##
## The look is driven by the AnimationPlayer in scn/ui/health_pip.tscn, so it can
## be restyled in the editor without touching code:
##   "full"  - a pip that still has health
##   "lose"  - plays once when this point of health is lost
##   "empty" - a lost pip (played automatically after "lose" finishes)

## True until this point of health is lost.
var is_full := true

@onready var _animation: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_animation.animation_finished.connect(_on_animation_finished)
	set_full()


## Shows the pip as full.
func set_full() -> void:
	is_full = true
	_animation.play(&"full")


## Plays the "lose" animation, after which the pip shows as empty.
func lose() -> void:
	if not is_full:
		return
	is_full = false
	_animation.play(&"lose")


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"lose":
		_animation.play(&"empty")
