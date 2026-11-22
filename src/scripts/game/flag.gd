class_name Flag
extends Area3D
## A flag in the arena.
##
## BossSpawnPoints: every Marker3D placed directly under a flag (in the arena
## scene) is one of that flag's BossSpawnPoints. When the flag that was touched
## last causes a boss to appear, the boss appears at one of these, chosen at
## random. Each flag needs at least one. Keep them a few meters away from the
## flag itself, so the boss does not appear on top of the player.
##
## Touching flags, scoring and the boss loop are added in phase 3.


## Returns this flag's BossSpawnPoints.
func get_boss_spawn_points() -> Array[Marker3D]:
	var points: Array[Marker3D] = []
	for child in get_children():
		if child is Marker3D:
			points.append(child)
	return points
