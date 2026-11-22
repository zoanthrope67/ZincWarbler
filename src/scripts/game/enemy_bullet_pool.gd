class_name EnemyBulletPool
extends Node3D
## Keeps a supply of enemy bullets so they never need to be created or freed
## during play, which keeps the frame rate steady on low spec machines.
##
## Enemies fire through fire(). If every bullet is already flying, the pool adds
## GROW_BY more bullets (and logs a message so the designer can raise STARTING_SIZE).

## Bullets made when a game starts.
const STARTING_SIZE := 128
## Bullets added whenever the pool runs out.
const GROW_BY := 32

## The bullet scene. Loaded in _ready() rather than preloaded, because the bullet
## script refers back to this script and a preload here would be a loop.
const BULLET_SCENE_PATH := "res://scn/game/enemy_bullet.tscn"

## Total bullets owned by the pool (flying + waiting).
var total_bullets := 0

var _bullet_scene: PackedScene
var _waiting: Array[EnemyBullet] = []


func _ready() -> void:
	_bullet_scene = load(BULLET_SCENE_PATH)
	_add_bullets(STARTING_SIZE)


## Fires a bullet from `start` along `direction` (a unit vector on the gameplay plane).
func fire(start: Vector3, direction: Vector3, speed := EnemyBullet.DEFAULT_SPEED) -> EnemyBullet:
	if _waiting.is_empty():
		print("EnemyBulletPool: all %d bullets in use, adding %d more." % [total_bullets, GROW_BY])
		_add_bullets(GROW_BY)
	var bullet: EnemyBullet = _waiting.pop_back()
	bullet.launch(Gameplay.on_plane(start), direction, speed)
	return bullet


## Number of bullets currently flying.
func get_active_count() -> int:
	return total_bullets - _waiting.size()


func _add_bullets(count: int) -> void:
	for i in count:
		var bullet: EnemyBullet = _bullet_scene.instantiate()
		bullet.pool = self
		bullet.visible = false
		bullet.monitoring = false
		add_child(bullet)
		_waiting.append(bullet)
	total_bullets += count


# Called (deferred) by a bullet when it leaves play.
func _take_back(bullet: EnemyBullet) -> void:
	bullet.monitoring = false
	_waiting.append(bullet)
