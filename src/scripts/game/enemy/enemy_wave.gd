class_name EnemyWave
extends Resource

## The enemy scene this wave spawns.
@export var enemy:PackedScene

## How many enemies this wave spawns. Always 1 or more.
@export_range(1, 100, 1, "or_greater") var count: int = 1:
	set(value):
		if value < 1:
			push_error("EnemyWave: count must be 1 or more, got %d. Using 1." % value)
		count = maxi(value, 1)

## Seconds between each enemy of this wave. 0 spawns the whole wave at once.
@export var wave_delay_seconds: float = 1.0:
	set(value):
		if value < 0.0:
			push_error("EnemyWave: wave_delay_seconds must be 0 or more, got %.2f. Using 1." % value)
			value = 1.0
		wave_delay_seconds = value

## Seconds from the START of this wave until the next wave starts. If this is
## shorter than the wave takes to spawn, the next wave overlaps this one.
@export var next_wave_delay: float = 2.0:
	set(value):
		if value < 0.0:
			push_error("EnemyWave: next_wave_delay must be 0 or more, got %.2f. Using 2." % value)
			value = 2.0
		next_wave_delay = value

func _init(p_enemy: PackedScene = null, p_count := 1, p_wave_delay_seconds := 1.0, p_next_wave_delay := 2.0) -> void:
	enemy = p_enemy
	count = p_count
	wave_delay_seconds = p_wave_delay_seconds
	next_wave_delay = p_next_wave_delay
