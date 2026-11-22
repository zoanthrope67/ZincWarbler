class_name InputHelper
## Small input helpers shared by the menus and screens.


## True if `event` is a fresh press of `action`: the button went down just now.
##
## Held buttons, key repeats and a controller stick that is simply being held over
## do not count. This is what the spec means by "a fresh press", e.g. a Confirm
## that was held down from the previous screen will not trigger this screen.
static func is_fresh_press(event: InputEvent, action: StringName) -> bool:
	return event.is_action_pressed(action, false) and Input.is_action_just_pressed(action)
