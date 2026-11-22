class_name Gameplay
## Values shared by all gameplay code.
##
## The game is drawn in 3D but played on a flat 2D plane:
##   +X is right on screen, -Z is up on screen, and everything that moves stays
##   at PLANE_HEIGHT above the floor (the floor itself is at y = 0).
##
## Collision layers (also named in Project Settings > Layer Names > 3D Physics):
##   1 Walls, 2 Player, 3 Enemies, 4 Player Bullets, 5 Enemy Bullets, 6 Flags
## The constants below are the bit values used in code and in the Inspector.

## Height above the floor, in meters, of the plane the game is played on.
## 1.0 puts the centre of a 2 m player sphere at the right height to sit on the floor.
const PLANE_HEIGHT := 1.0

const LAYER_WALLS := 1 << 0
const LAYER_PLAYER := 1 << 1
const LAYER_ENEMIES := 1 << 2
const LAYER_PLAYER_BULLETS := 1 << 3
const LAYER_ENEMY_BULLETS := 1 << 4
const LAYER_FLAGS := 1 << 5


## Returns `point` moved onto the gameplay plane.
static func on_plane(point: Vector3) -> Vector3:
	return Vector3(point.x, PLANE_HEIGHT, point.z)
