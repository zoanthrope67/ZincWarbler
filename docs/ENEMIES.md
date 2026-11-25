# Adding a New Enemy

This guide shows how to add your own enemy or boss to Zinc Warbler:
- make its scene;
- write its behaviour;
- put it into waves (or the boss list);
- test it.

The worked example, a **Darter**, was tested in a copy of this project. The
section [Recipes](#recipes) has short pieces of code for common behaviours.

For making a real 3D model for the enemy, see `docs/BLENDER.md`.

---

## How enemies work

Every enemy is two files:

| File | What it holds |
|---|---|
| A scene, e.g. `scn/game/chaser.tscn` | Its size, hitboxes, look, and the Inspector settings (hits, score) |
| A script, e.g. `scripts/game/enemy/chaser.gd` | How it moves and attacks |

Every enemy script starts with `extends Enemy`. The shared script
`scripts/game/enemy/enemy.gd` already does everything all enemies have in
common, so your script only describes what makes this enemy different.

What the shared script does for you:
- the fade-in when the enemy appears;
- turning collision on when the fade-in ends;
- hurting the player on touch;
- counting hits and removing the enemy when defeated;
- giving its score;
- keeping it on the gameplay plane.

An enemy's life:

1. **Fading in** (0.25 s). It is see-through, does not move, cannot hurt or be
   hurt. Your code does not run yet.
2. **Active.** Your `_on_activated()` runs once, then your
   `_active_physics_process(delta)` runs every physics frame (60 times a
   second) until it is defeated.
3. **Defeated.** After `Max Hits` hits from player bullets it is removed, and
   the player gets its `Score Value`.

A normal enemy that stays more than 150 m from the player for 10 seconds is
also removed, to save performance (`FAR_AWAY_DISTANCE` and `FAR_AWAY_SECONDS`
in `enemy.gd`). That is not a defeat: no score, and `defeated` is not emitted.
Bosses are never removed this way.

Look at the existing enemies for examples; they are short and commented:
- `chaser.gd` moves in a straight line and turns at walls.
- `tank.gd` moves towards the player and shoots.
- `angry_greg.gd`, a boss, stands still and shoots.

---

## Step 1: Make the scene

1. In Godot's **FileSystem** dock, right-click the existing enemy closest to
   what you want, e.g. `scn/game/tank.tscn`. Choose **Duplicate…** and name it,
   e.g. `darter.tscn`.
2. Open the new scene. Rename the root node (double-click it), e.g. `Darter`.
3. **Give it its own script. Don't skip this step.** The copy still uses the
   Tank's script, and editing that would change the Tank too.
   - Right-click the root node and choose **Detach Script**.
   - Right-click it again and choose **Attach Script**.
   - Set **Inherits** to `Enemy`.
   - Set **Path** to `res://scripts/game/enemy/darter.gd`.
   - Click **Create**.
4. Check the root node's settings in the Inspector:

| Setting | What it does |
|---|---|
| `Max Hits` | Player bullet hits to defeat it |
| `Score Value` | Score when defeated (normal enemies use 0 in the spec) |
| `Is Boss` | Tick for bosses. Bosses are never removed for being far from the player. What makes something appear as a boss is being in the boss list (Step 3); bosses from that list are always treated as bosses, even if this is left unticked |
| `Hit Flash Material` | Shown on the model for a moment each time it is hit. The default is the red placeholder flash. Clear it for no flash |
| `Hit Flash Seconds` | How long the hit flash shows (0.1) |

5. **Size.** The enemy's size is the radius of the sphere in the root's
   `CollisionShape3D`: 1.0 for a 2 x 2 m enemy, 2.0 for a 4 x 4 m boss.
   - Set `Hurtbox > CollisionShape3D` to 0.1 bigger. Touching the player
     inside the Hurtbox hurts them.
   - Both must stay **spheres**.
6. **Look.** Everything visible goes under the **Model** node, with the front
   facing **+Z** (the blue arrow). The code turns Model to face where the enemy
   is heading.
   - For a quick placeholder, change the colour: select `PlaceholderBody` and
     open **Mesh > Material > Albedo > Color** in the Inspector. The copy has
     its own materials, so this does not change the Tank.
   - For a real model, see `docs/BLENDER.md`.

**Keep these node names exactly as they are.** The code looks them up by name:

| Node | Type | Notes |
|---|---|---|
| (root) | `CharacterBody3D` | Leave its Collision Layer and Mask empty; the code sets them when the fade-in ends |
| `CollisionShape3D` | `CollisionShape3D` with a `SphereShape3D` | The enemy's body |
| `Hurtbox` | `Area3D` (Mask: layer 2, Player) | With its own sphere `CollisionShape3D` |
| `Model` | `Node3D` | Everything visible |

---

## Step 2: Write the behaviour

### The basic shape of an enemy script

```gdscript
class_name Darter
extends Enemy
## Darter: one or two lines saying what this enemy does, for the designer.

## Movement speed in meters per second.
const SPEED := 3.0


## Runs once, when the fade-in ends.
func _on_activated() -> void:
	face(direction_to_target())


## Runs every physics frame while the enemy is active. `delta` is the time
## since the last frame in seconds (1/60). Move and attack here.
func _active_physics_process(delta: float) -> void:
	var direction := direction_to_target()
	move_sliding(direction * SPEED * delta)
	face(direction)
```

- `class_name` gives the enemy a name other scripts can use. It must be
  different from every other class name, including Godot's own (e.g. not
  `Timer` or `Area`).
- Put every number you might want to change in a **constant at the top**, with
  a `##` comment saying what it does and its unit. That is how the other enemies
  do it, and the Designer Guide lists them.

### Helpers you can use

These all come from `Enemy`:

| Helper | What it does |
|---|---|
| `direction_to_target()` | A direction (length 1) towards the player on the gameplay plane, or `Vector3.ZERO` if right on top of them |
| `get_target_position()` | The player's position. Once the player has died, it stays where they died |
| `move_sliding(motion)` | Moves by `motion`, gliding along walls instead of stopping. Returns the collision, or `null` |
| `move_and_collide(motion)` | Godot's own: moves until it hits something and stops there. Returns the collision, or `null` |
| `is_wall(collision)` | True if a collision was with a wall (not the player) |
| `is_pushing_into_player(direction)` | True if moving that way would only push into the player it is already touching. Skip the move then |
| `face(direction)` | Turns the Model to face a direction |
| `shoot_at_target(speed)` | Fires one enemy bullet at the player (`speed` in m/s; leave it out for the default) |
| `bullet_pool.fire(start, direction, speed)` | Fires one enemy bullet in any direction (see [Recipes](#recipes)) |
| `GfxEffects.apply_gfx_material(_model, material, seconds)` | Shows a ShaderMaterial on the model for a while (effects only). See "Material effects" in `docs/DESIGNER_GUIDE.md` |

| Value | What it is |
|---|---|
| `body_radius` | The enemy's radius in meters, from its CollisionShape3D |
| `hits_left` | Hits still needed to defeat it |
| `touching_player` | True if it touched the player on the last frame |
| `global_position` | Where it is |

### Rules that keep things working

- **Multiply every speed by `delta`.** `SPEED * delta` is how far to move this
  frame. Without it the enemy moves 60 times too fast.
- **Use `_on_activated()` and `_active_physics_process()`.** Don't write your
  own `_ready()` or `_physics_process()`; they would replace the shared ones and
  break the fade-in, hits and hurting the player. If you really need `_ready()`,
  make its first line `super()`.
- **Movement stays flat.** Directions from `direction_to_target()` are already
  flat. If you make your own, set `y` to 0.
- **Count timers down with `-=` and restart them with `+=`**, as in the
  examples. This keeps the timing exact.
- Use `move_sliding()` or `move_and_collide()`, not Godot's `move_and_slide()`,
  which is much slower with hundreds of enemies. Never use RigidBody forces,
  impulses or gravity (a project rule).
- **Don't create new nodes every frame.** Fire bullets through `bullet_pool`,
  which reuses them, rather than making new bullet scenes.
- Signals starting with `fx_` are for effects and sounds only. Don't use them
  for game logic.

---

## Worked example: the Darter

The Darter waits while aiming at the player, then darts towards them. When the
dart ends it fires a fan of three bullets. This code was run in a copy of the
project:
- it waited 1.5 s;
- it darted about 4 m;
- it fired three bullets in a spread;
- it stayed on the gameplay plane;
- it was defeated by player hits.

`scripts/game/enemy/darter.gd`:

```gdscript
class_name Darter
extends Enemy
## Darter: waits while aiming at the player, then darts towards them in a
## straight line. When a dart ends it fires a spread of bullets at the player.

## Seconds the Darter waits (aiming) between darts.
const WAIT_SECONDS := 1.5
## Seconds each dart lasts.
const DART_SECONDS := 0.5
## Movement speed during a dart, in meters per second.
const DART_SPEED := 8.0
## Bullets in each spread (1 or more).
const SPREAD_BULLETS := 3
## Angle between neighbouring bullets in a spread, in degrees.
const SPREAD_ANGLE := 15.0
## Speed of the Darter's bullets in meters per second.
const BULLET_SPEED := EnemyBullet.DEFAULT_SPEED

## True while darting, false while waiting.
var _is_darting := false
## Seconds left of the current wait or dart.
var _time_left := WAIT_SECONDS
## The direction of the current dart. Chosen when the dart starts.
var _dart_direction := Vector3.ZERO


func _on_activated() -> void:
	_is_darting = false
	_time_left = WAIT_SECONDS
	face(direction_to_target())


func _active_physics_process(delta: float) -> void:
	_time_left -= delta

	if _is_darting:
		# Pressed against the player: it cannot get any closer, so skip the move.
		if not is_pushing_into_player(_dart_direction):
			move_sliding(_dart_direction * DART_SPEED * delta)
		if _time_left <= 0.0:
			_is_darting = false
			_time_left += WAIT_SECONDS
			_fire_spread()
	else:
		face(direction_to_target())
		if _time_left <= 0.0:
			_is_darting = true
			_time_left += DART_SECONDS
			_dart_direction = direction_to_target()


# Fires SPREAD_BULLETS bullets in a fan, with the middle of the fan aimed at the player.
func _fire_spread() -> void:
	var aim := direction_to_target()
	if aim == Vector3.ZERO or bullet_pool == null:
		return
	var first_angle := -SPREAD_ANGLE * (SPREAD_BULLETS - 1) / 2.0
	for i in SPREAD_BULLETS:
		var direction := aim.rotated(Vector3.UP, deg_to_rad(first_angle + SPREAD_ANGLE * i))
		var start := global_position + direction * (body_radius + BULLET_SPAWN_GAP)
		bullet_pool.fire(start, direction, BULLET_SPEED)
		fx_shot_fired.emit(start, direction)
```

The scene `scn/game/darter.tscn` was a duplicate of `tank.tscn` with this
script attached instead (Step 1).

---

## Step 3: Put it in the game

### As a normal enemy (in waves)

Open `scripts/game/enemy/enemy_spawner.gd`.

1. Next to `CHASER` and `TANK` near the top, add a constant for your scene:

   ```gdscript
   const DARTER := preload("res://scn/game/darter.tscn")
   ```

2. In `get_bag_via_danger()`, add waves of it to the bags where it should
   appear. Each bag is used at a range of danger levels, so pick when in the
   game it turns up:

   ```gdscript
   elif _game.danger_level < 50:
       current_bag = [
           EnemyWave.new(CHASER, 3, 0.2, 1.0),
           EnemyWave.new(DARTER, 2, 0.5, 2.0),   # 2 Darters, 0.5 s apart, next wave 2 s later
           ...
   ```

   The numbers are `EnemyWave.new(enemy, count, seconds between each enemy,
   seconds until the next wave starts)`. See "Enemy spawning" in
   `docs/DESIGNER_GUIDE.md`.

### As a boss

1. Tick **Is Boss**, and set **Max Hits** and **Score Value** on the root node.
2. Make it 4 x 4 m: sphere radius 2.0, Hurtbox 2.1.
3. Open `scn/in_game.tscn` and select the **FlagLoop** node.
4. In the Inspector, find **Boss Scenes**, click **Add Element** and drag your
   `.tscn` into the new slot. Each boss in the list has an equal chance to
   appear when all flags are touched.

---

## Step 4: Test it

Waiting for the right danger level is slow. To see your enemy straight away,
**temporarily** make the first bag (danger below 10) only your enemy:

```gdscript
if _game.danger_level < 10:
    current_bag = [
        EnemyWave.new(DARTER, 1, 0, 9999),   # TEST ONLY: one Darter, then nothing
    ]
```

Press **F5**. The Darter appears 1 second in. Things to check:

- It fades in, then starts moving.
- It faces the way it moves (if it moves backwards, the model's front is not +Z).
- It stops at walls, and the player's bullets hit it.
- Touching it hurts you, and it is defeated after `Max Hits` hits.
- There are no red errors in the **Debugger** panel at the bottom of Godot.

**Change the bag back** when you're done.

To test a boss quickly, temporarily put only your boss in **Boss Scenes** and
touch all the flags.

---

## Step 5: Tidy up

- **Designer Guide.** Add the new script's constants to the Enemies table in
  `docs/DESIGNER_GUIDE.md`, and its `Max Hits` / `Score Value` to the settings
  table.
- **Spec.** Describe the enemy in `docs/SPEC.md` (Enemies).
- **Placeholders.** If it uses placeholder shapes, name the nodes
  `Placeholder…` and list them in `docs/asset_tracking.txt`, so they are easy to
  find and replace later.
- **Credits.** Credit human-made models or sounds in `docs/credits.txt`.

---

## Recipes

Short pieces you can combine inside `_active_physics_process(delta)` (or
`_on_activated()`). Each needs its constants (e.g. `SPEED`) at the top of
the script.

**Walk towards the player, sliding along walls** (like the Tank):

```gdscript
var direction := direction_to_target()
if not is_pushing_into_player(direction):
	move_sliding(direction * SPEED * delta)
face(direction)
```

**Move in a straight line and bounce off walls:**

```gdscript
# var heading := Vector3.RIGHT   (at the top of the script; set it in _on_activated())
var collision := move_and_collide(heading * SPEED * delta)
if collision != null and is_wall(collision):
	var normal := collision.get_normal()
	normal.y = 0.0
	heading = heading.bounce(normal.normalized())
face(heading)
```

**Keep a distance from the player** (back away if too close):

```gdscript
var direction := direction_to_target()
var distance := global_position.distance_to(get_target_position())
if distance < KEEP_DISTANCE:
	direction = -direction
move_sliding(direction * SPEED * delta)
face(direction_to_target())
```

**Shoot at the player every few seconds** (like the Tank):

```gdscript
# var _time_until_shot := FIRE_INTERVAL   (at the top of the script)
_time_until_shot -= delta
if _time_until_shot <= 0.0:
	_time_until_shot += FIRE_INTERVAL
	shoot_at_target(BULLET_SPEED)
```

**Shoot in any direction**, e.g. the way it is heading:

```gdscript
var start := global_position + heading * (body_radius + BULLET_SPAWN_GAP)
bullet_pool.fire(start, heading, BULLET_SPEED)
fx_shot_fired.emit(start, heading)
```

**A ring of bullets in every direction:**

```gdscript
for i in RING_BULLETS:
	var direction := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / RING_BULLETS)
	var start := global_position + direction * (body_radius + BULLET_SPAWN_GAP)
	bullet_pool.fire(start, direction, BULLET_SPEED)
	fx_shot_fired.emit(start, direction)
```

**Behave differently when hurt**, using `hits_left`:

```gdscript
var speed := SPEED
if hits_left == 1:
	speed = SPEED * 2.0   # faster on its last hit
```

**Show a different look for a while**, e.g. glowing while charging up (needs
`@export var charge_material: ShaderMaterial` at the top of the script):

```gdscript
GfxEffects.apply_gfx_material(_model, charge_material, CHARGE_SECONDS)
```

This replaces any hit flash that is showing, and a hit during it replaces this.
For effects only; the enemy's behaviour should not depend on it.

**Randomness:** `randf_range(1.0, 3.0)` gives a random number between 1 and 3;
`[a, b, c].pick_random()` picks one of a list.

---

## Troubleshooting

| Problem | Likely cause |
|---|---|
| It never appears | It is not in a bag, or not in a bag for the danger levels you reached. Use the test bag in Step 4 |
| The Tank (or the enemy you copied) changed too | The new scene still uses the old script. Detach it and attach a new one (Step 1) |
| It appears but never fades in, can't be hit, or doesn't hurt the player | The script has its own `_ready()` or `_physics_process()`. Move the code into `_on_activated()` / `_active_physics_process()` |
| It moves far too fast | A speed was not multiplied by `delta` |
| It slowly sinks, floats, or moves strangely | A direction you made yourself has a `y` value. Set `y` to 0 |
| It faces backwards or sideways | The Model's front is not facing +Z |
| It pops in instead of fading | A mesh uses a ShaderMaterial. Use a StandardMaterial3D |
| "Class … hides a global script class" or similar | The `class_name` is already used. Pick another |
| Errors mention `CollisionShape3D`, `Hurtbox` or `Model` | One of those nodes was renamed or deleted (see the table in Step 1) |
