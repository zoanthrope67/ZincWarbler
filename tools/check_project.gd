extends SceneTree
## Checks that the whole project compiles. Used by tools/export.sh.
##
## Loads every script (.gd), scene (.tscn) and resource (.tres) in the project
## and lists any that fail. Godot's own export does NOT stop on a broken script
## (it exports the game anyway), so this is what catches script errors.
##
## Run it headless on the project:
##     godot --headless --path src --script "$PWD/tools/check_project.gd"
## It quits with exit code 0 if everything loaded, or 1 if anything failed.
## Godot prints the reason for each failure (e.g. "Parse Error: ...") above
## the list.
##
## It only loads files; it never runs the game. Settings and hi-scores are only
## loaded and saved by the Bootstrap screen, so the player's saved files are
## never touched.
##
## Not checked: shader code (.gdshader), which is only compiled when something
## is drawn, and headless Godot draws nothing.

## File types that are loaded and checked.
const CHECKED_EXTENSIONS := ["gd", "tscn", "tres"]

var _checked := 0
var _failed: PackedStringArray = []


func _initialize() -> void:
	_check_folder("res://")
	if _failed.is_empty():
		print("check_project: all %d scripts, scenes and resources loaded." % _checked)
		quit(0)
	else:
		print("check_project: %d of %d files failed to load:" % [_failed.size(), _checked])
		for path in _failed:
			print("    ", path)
		quit(1)


# Checks every file in `folder` and the folders inside it. Folders starting
# with "." (e.g. Godot's .godot import cache) are skipped.
func _check_folder(folder: String) -> void:
	for sub_folder in DirAccess.get_directories_at(folder):
		if not sub_folder.begins_with("."):
			_check_folder(folder.path_join(sub_folder))
	for file in DirAccess.get_files_at(folder):
		if file.get_extension() in CHECKED_EXTENSIONS:
			_check_file(folder.path_join(file))


func _check_file(path: String) -> void:
	_checked += 1
	var resource := load(path)
	if resource == null:
		_failed.append(path)
	elif resource is Script and not (resource as Script).can_instantiate():
		# A script with errors still loads, but cannot be used.
		_failed.append(path)
