class_name Arena
extends Node3D
## The arena: walls, spawn points and flags.
##
## How to edit the arena (open scn/game/arena.tscn):
##   Walls             - the GridMap. Select it and paint wall tiles in the GridMap
##                       panel at the bottom of the editor. Each cell is 4 x 4 m and 4 m tall.
##   PlayerSpawnPoints - add Marker3D children. The player starts on one at random.
##   EnemySpawnPoints  - add Marker3D children. Enemies appear on these (phase 3).
##   Flags             - add instances of scn/game/flag.tscn. Give each flag one or
##                       more Marker3D children: those are its BossSpawnPoints.
##
## Only the X and Z position of markers matters; height is ignored.
## When a game starts, validate() checks the rules from docs/SPEC.md
## ("Prestartup Validation") and the game shows the Error screen if any are broken.

## Minimum counts required by the spec.
const MIN_PLAYER_SPAWN_POINTS := 1
const MIN_ENEMY_SPAWN_POINTS := 1
const MIN_FLAGS := 2


## Returns all PlayerSpawnPoints.
func get_player_spawn_points() -> Array[Marker3D]:
	return _markers_under(^"PlayerSpawnPoints")


## Returns all EnemySpawnPoints.
func get_enemy_spawn_points() -> Array[Marker3D]:
	return _markers_under(^"EnemySpawnPoints")


## Returns all flags.
func get_flags() -> Array[Flag]:
	var flags: Array[Flag] = []
	var container := get_node_or_null(^"Flags")
	if container != null:
		for child in container.get_children():
			if child is Flag:
				flags.append(child)
	return flags


## Checks the arena against the spec's rules. Returns a list of problems, one
## line each, or an empty list if the arena is fine.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()

	var player_points := get_player_spawn_points().size()
	if player_points < MIN_PLAYER_SPAWN_POINTS:
		problems.append("The arena needs at least %d PlayerSpawnPoint (Marker3D under PlayerSpawnPoints), found %d." % [MIN_PLAYER_SPAWN_POINTS, player_points])

	var enemy_points := get_enemy_spawn_points().size()
	if enemy_points < MIN_ENEMY_SPAWN_POINTS:
		problems.append("The arena needs at least %d EnemySpawnPoint (Marker3D under EnemySpawnPoints), found %d." % [MIN_ENEMY_SPAWN_POINTS, enemy_points])

	var flags := get_flags()
	if flags.size() < MIN_FLAGS:
		problems.append("The arena needs at least %d flags (flag.tscn instances under Flags), found %d." % [MIN_FLAGS, flags.size()])

	for flag in flags:
		if flag.get_boss_spawn_points().is_empty():
			problems.append("Flag '%s' has no BossSpawnPoint (add a Marker3D as a child of the flag)." % flag.name)

	return problems


func _markers_under(container_path: NodePath) -> Array[Marker3D]:
	var markers: Array[Marker3D] = []
	var container := get_node_or_null(container_path)
	if container != null:
		for child in container.get_children():
			if child is Marker3D:
				markers.append(child)
	return markers
