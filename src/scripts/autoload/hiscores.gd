extends Node
## Hiscores autoload: the top 10 hi-score table.
##
## Bootstrap calls load_or_create() once when the game starts. The table is saved
## on the player's machine only (user://). The game never sends scores anywhere.
##
## Each entry is a Dictionary:
##   name             - String, 1 to MAX_NAME_LENGTH characters
##   score            - int
##   seconds_survived - int, whole seconds
##   datetime         - String from Time.get_datetime_string_from_system(), local time,
##                      e.g. "2026-11-22T21:05:33"
##
## Order: highest score first, then most seconds survived, then the latest datetime.

## Bump this when the save format changes. Files saved with a different version
## (or damaged files) are ignored and replaced with the starting table.
const SAVE_VERSION := 1

## How many entries the table keeps.
const MAX_ENTRIES := 10

## Longest name allowed (docs/SPEC.md, Name Entry State).
const MAX_NAME_LENGTH := 8
## Characters allowed in a name.
const ALLOWED_NAME_CHARACTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

## The table used the first time the game runs and when the player clears the
## hi-scores from the Config screen. Designers can change these freely.
## Their datetimes are set to the moment the table is filled.
const STARTING_SCORES := [
	{"name": "AAA", "score": 100, "seconds_survived": 1},
	{"name": "BBB", "score": 90, "seconds_survived": 1},
	{"name": "CCC", "score": 80, "seconds_survived": 1},
	{"name": "DDD", "score": 70, "seconds_survived": 1},
	{"name": "EEE", "score": 67, "seconds_survived": 1},
	{"name": "FFF", "score": 60, "seconds_survived": 1},
	{"name": "GGG", "score": 50, "seconds_survived": 1},
	{"name": "III", "score": 40, "seconds_survived": 1},
	{"name": "JJJ", "score": 30, "seconds_survived": 1},
	{"name": "HHH", "score": 20, "seconds_survived": 1},
]

## Where the table is saved. user:// is the game's own folder on the player's machine.
var save_path := "user://hiscores.json"

# The current table, always sorted and never longer than MAX_ENTRIES.
var _entries: Array[Dictionary] = []


## Loads the saved table. If there is no valid saved table, fills it with the
## starting scores and saves it. Called once by Bootstrap.
func load_or_create() -> void:
	var loaded := _load_from_disk()
	if loaded.is_empty():
		reset_to_starting_table()
	else:
		_entries = loaded
		_sort_and_trim()


## Returns a copy of the table, best score first.
func get_entries() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for entry in _entries:
		copy.append(entry.duplicate())
	return copy


## Returns true if a game that ended now with this score and time would make the table.
## A new entry wins ties with older entries, because it has the latest datetime.
func qualifies(score: int, seconds_survived: int) -> bool:
	var entries_ahead := 0
	for entry in _entries:
		if entry.score > score:
			entries_ahead += 1
		elif entry.score == score and entry.seconds_survived > seconds_survived:
			entries_ahead += 1
	return entries_ahead < MAX_ENTRIES


## Adds an entry, keeps the best MAX_ENTRIES and saves.
## `datetime` should be taken at the moment the game ended.
func add_entry(player_name: String, score: int, seconds_survived: int, datetime: String) -> void:
	_entries.append({
		"name": player_name,
		"score": score,
		"seconds_survived": seconds_survived,
		"datetime": datetime,
	})
	_sort_and_trim()
	save()


## Replaces the table with STARTING_SCORES, dated now, and saves.
func reset_to_starting_table() -> void:
	var now := Time.get_datetime_string_from_system()
	_entries.clear()
	for starting_entry in STARTING_SCORES:
		var entry: Dictionary = starting_entry.duplicate()
		entry["datetime"] = now
		_entries.append(entry)
	_sort_and_trim()
	save()


## Saves the table to disk.
func save() -> void:
	var data := {"version": SAVE_VERSION, "entries": _entries}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Hiscores: could not save %s (error %d)." % [save_path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


# --- Internals ----------------------------------------------------------------

# Returns the saved entries, or an empty array if the file is missing, from
# another version, or damaged in any way.
func _load_from_disk() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not FileAccess.file_exists(save_path):
		return result

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("Hiscores: could not read %s. Using the starting table." % save_path)
		return result
	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()
	var data = json.data if parse_result == OK else null

	if typeof(data) != TYPE_DICTIONARY or data.get("version") != float(SAVE_VERSION):
		push_warning("Hiscores: %s is from another version or damaged. Using the starting table." % save_path)
		return result
	var saved_entries = data.get("entries")
	if typeof(saved_entries) != TYPE_ARRAY or saved_entries.is_empty():
		push_warning("Hiscores: %s has no valid entries. Using the starting table." % save_path)
		return result

	for saved in saved_entries:
		var entry := _validated_entry(saved)
		if entry.is_empty():
			push_warning("Hiscores: %s has a damaged entry. Using the starting table." % save_path)
			result.clear()
			return result
		result.append(entry)
	return result


# Returns a clean copy of one saved entry, or an empty Dictionary if it is invalid.
# JSON stores all numbers as floats, so whole numbers are converted back to ints.
func _validated_entry(saved) -> Dictionary:
	if typeof(saved) != TYPE_DICTIONARY:
		return {}
	var entry_name = saved.get("name")
	var score = saved.get("score")
	var seconds = saved.get("seconds_survived")
	var datetime = saved.get("datetime")
	if typeof(entry_name) != TYPE_STRING or entry_name.is_empty() or entry_name.length() > MAX_NAME_LENGTH:
		return {}
	if typeof(score) != TYPE_FLOAT or score < 0 or score != floorf(score):
		return {}
	if typeof(seconds) != TYPE_FLOAT or seconds < 0 or seconds != floorf(seconds):
		return {}
	if typeof(datetime) != TYPE_STRING:
		return {}
	return {
		"name": entry_name,
		"score": int(score),
		"seconds_survived": int(seconds),
		"datetime": datetime,
	}


func _sort_and_trim() -> void:
	_entries.sort_custom(_ranks_higher)
	if _entries.size() > MAX_ENTRIES:
		_entries.resize(MAX_ENTRIES)


# True if entry `a` belongs above entry `b` in the table.
func _ranks_higher(a: Dictionary, b: Dictionary) -> bool:
	if a.score != b.score:
		return a.score > b.score
	if a.seconds_survived != b.seconds_survived:
		return a.seconds_survived > b.seconds_survived
	# Datetimes are "YYYY-MM-DDTHH:MM:SS", so comparing the text compares the times.
	return a.datetime > b.datetime
