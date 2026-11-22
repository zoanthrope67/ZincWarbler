class_name Flag
extends Area3D
## A flag in the arena. When the player touches an active flag it is hidden and
## becomes inactive until the flag loop (scripts/game/flag_loop.gd) restores it.
##
## BossSpawnPoints: every Marker3D placed directly under a flag (in the arena
## scene) is one of that flag's BossSpawnPoints. When the flag that was touched
## last causes a boss to appear, the boss appears at one of these, chosen at
## random. Each flag needs at least one. Keep them a few meters away from the
## flag itself, so the boss does not appear on top of the player.

## Emitted when the player touches this flag while it is active. Game logic signal.
signal touched(flag: Flag)
## Emitted when the player touches this flag. FX only.
signal fx_touched(position: Vector3)
## Emitted when this flag comes back after a boss is defeated. FX only.
signal fx_restored(position: Vector3)

## False after the player touches the flag, until it is restored.
var is_active := true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Returns this flag's BossSpawnPoints.
func get_boss_spawn_points() -> Array[Marker3D]:
	var points: Array[Marker3D] = []
	for child in get_children():
		if child is Marker3D:
			points.append(child)
	return points


## Brings the flag back so it can be touched again.
func restore() -> void:
	if is_active:
		return
	is_active = true
	visible = true
	# Deferred: this can run inside a collision callback.
	set_deferred("monitoring", true)
	fx_restored.emit(global_position)


func _on_body_entered(body: Node3D) -> void:
	if not is_active or not body is Player:
		return
	is_active = false
	visible = false
	set_deferred("monitoring", false)
	fx_touched.emit(global_position)
	touched.emit(self)
