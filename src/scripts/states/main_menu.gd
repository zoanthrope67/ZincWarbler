extends Control
## Main Menu state: the title splash and the main menu.

## The menu items, in the same order as the Label children of the Menu node.
## If you reorder the labels in the scene, reorder this list to match.
enum Item {
	START_GAME,
	VIEW_HISCORES,
	CONFIG_OPTIONS,
	QUIT_GAME,
}

@onready var _menu: MenuList = %Menu


func _ready() -> void:
	_menu.item_chosen.connect(_on_item_chosen)


func _on_item_chosen(index: int) -> void:
	match index:
		Item.START_GAME:
			GameState.change_state(GameState.State.IN_GAME)
		Item.VIEW_HISCORES:
			GameState.change_state(GameState.State.HISCORE)
		Item.CONFIG_OPTIONS:
			GameState.change_state(GameState.State.CONFIG_OPTIONS)
		Item.QUIT_GAME:
			GameState.quit_game()
