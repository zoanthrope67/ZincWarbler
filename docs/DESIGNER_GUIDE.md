# Designer Guide

Where to change things in Zinc Warbler. All paths are inside `src/`.

## Folder layout

| Folder | Contents |
|---|---|
| `scn/` | Scenes: one per game state, e.g. `main_menu.tscn`, `in_game.tscn` |
| `scn/game/` | Gameplay scenes: `arena.tscn`, `player.tscn`, `player_bullet.tscn`, `flag.tscn`, `chaser.tscn`, `tank.tscn`, `angry_greg.tscn`, `enemy_bullet.tscn`, `border_storm.tscn` |
| `scripts/autoload/` | Global scripts that are always running: `GameState`, `Settings`, `Hiscores` |
| `scripts/states/` | One script per state screen |
| `scripts/game/` | Gameplay scripts (player, player bullets, arena, flags, camera, BorderStorm) |
| `scripts/game/enemy/` | Enemies, enemy bullets and their pool, the enemy spawner and `EnemyWave` |
| `scripts/ui/` | Shared UI pieces (the keyboard/controller menu, the HUD, the pause menu) |
| `gfx/placeholder/` | Placeholder art, see `docs/asset_tracking.txt` |
| `gfx/shaders/` | Shaders (the BorderStorm's look) |
| `gfx/`, `bgm/`, `sfx/` | Final graphics, music and sound effects |

## Controls

- **Default controls:** Godot editor → Project → Project Settings → **Input Map**.
  The actions are `move_up`, `move_down`, `move_left`, `move_right`, `confirm`, `back` and `pause`.
  Changes here become the game's defaults and what "Reset Controls to Default" restores.
- Players can rebind one keyboard key and one controller button per action on the Config screen.
  The left stick on the move actions and everything on `pause` are fixed.
- `pause` (Escape, Start) opens the pause menu in game. Escape and Start are
  reserved and can never be bound to anything else: `RESERVED_KEYS` and
  `RESERVED_JOY_BUTTONS` in `scripts/autoload/settings.gd`.
- Which actions appear on the Config screen, and their names: `REBINDABLE_ACTIONS` in
  `scripts/autoload/settings.gd`.
- Controller button names shown on screen: `JOY_BUTTON_NAMES` in the same file.

## Settings defaults (`scripts/autoload/settings.gd`)

| Constant | What it does |
|---|---|
| `DEFAULT_MUSIC_VOLUME`, `DEFAULT_SFX_VOLUME` | Starting volumes, 0.0 to 1.0 |
| `DEFAULT_FULLSCREEN` | Whether the game starts fullscreen |
| `VOLUME_STEP` | How much one left/right press changes a volume |

Audio buses (`Music`, `SFX`) are in `default_bus_layout.tres`, which opens in the
**Audio** tab at the bottom of the Godot editor.

Saved settings live in `user://config.cfg` on the player's machine. Changing
`SAVE_VERSION` makes the game ignore old files and use the defaults.

## Hi-scores (`scripts/autoload/hiscores.gd`)

| Constant | What it does |
|---|---|
| `STARTING_SCORES` | The table used on first run and after "Clear Hi-scores" |
| `MAX_ENTRIES` | How many scores the table keeps |
| `MAX_NAME_LENGTH`, `ALLOWED_NAME_CHARACTERS` | Name rules for Name Entry |
| `SAVE_VERSION` | Change it to make the game ignore old hi-score files |

Saved hi-scores live in `user://hiscores.json`.

## Screens

| What | Where |
|---|---|
| How long "Loading..." shows | `LOADING_SCREEN_SECONDS` in `scripts/states/bootstrap.gd` |
| Main menu items | Labels under `Menu` in `scn/main_menu.tscn`. If you reorder them, reorder `Item` in `scripts/states/main_menu.gd` to match |
| Menu highlight colours, wrap-around | Select a `Menu` node; `Selected Color`, `Normal Color` and `Wrap Around` are in the Inspector |
| Rebinding timeout | `REBIND_TIMEOUT_SECONDS` in `scripts/states/config_screen.gd` |
| Hi-score table columns and heading colour | `HEADINGS`, `HEADING_COLOR` in `scripts/states/hiscore_screen.gd` |
| Name Entry grid width and colours | `COLUMNS`, `SELECTED_COLOR`, `NORMAL_COLOR` in `scripts/states/name_entry.gd` |
| Delay before Confirm works on Game Over | `CONFIRM_DELAY_SECONDS` in `scripts/states/game_over.gd` (0.5) |
| Font size for all screens | `gfx/placeholder/placeholder_theme.tres` (placeholder) |
| Background colour | Project Settings → Rendering → Environment → Default Clear Color |

## The arena (`scn/game/arena.tscn`)

| Node | How to edit |
|---|---|
| `Walls` | GridMap. Select it and paint tiles with the GridMap panel at the bottom of the editor. Each cell is 4 x 4 m and 4 m tall. Tiles come from `gfx/placeholder/placeholder_wall_library.tres` |
| `PlayerSpawnPoints` | Add `Marker3D` children. The player starts on one at random |
| `EnemySpawnPoints` | Add `Marker3D` children. Enemy waves start on these (see Enemy spawning) |
| `Flags` | Add instances of `scn/game/flag.tscn`. Give each flag one or more `Marker3D` children: those are its BossSpawnPoints. Keep them a few meters from the flag |
| `BorderStorm` | The edge of the play area (see BorderStorm below). Move it to where the circle should start |

Only the X and Z position of markers matters. When a game starts the arena is
checked (at least 1 PlayerSpawnPoint, 1 EnemySpawnPoint, 2 flags, a
BossSpawnPoint on every flag, and a BorderStorm). If anything is missing, the Error screen lists it.
The minimum counts are constants at the top of `scripts/game/arena.gd`.

The game is played on a flat plane 1 m above the floor (`PLANE_HEIGHT` in
`scripts/game/gameplay.gd`). +X is right on screen and -Z is up on screen.
The floor is not drawn, so the sky shows below the arena.

**Lighting:** select `PlaceholderEnvironment` and open its Environment in the
Inspector. It uses the sky image `gfx/sky/autumn_field_puresky_1k.hdr` for the
background, ambient light and reflections.
- To swap the image, open **Sky > Sky Material > Panorama**.
- **Background > Energy Multiplier** brightens only the background.
- **Ambient Light > Energy** brightens how the sky lights models.
- **Sky > Radiance Size** (128) is the quality of the reflections: keep it
  small for low spec machines.

`PlaceholderLight` is the sun.

There are no outer walls around the arena: the BorderStorm is the edge of the
play area. Paint walls only where you want obstacles.

## BorderStorm (`scn/game/border_storm.tscn`, `scripts/game/border_storm.gd`)

A circle the player should stay inside. Everything outside it is the storm.
- **Movement:** the circle moves towards a random uncollected flag, and picks a
  new one each time a flag is collected. While a boss is in play it moves
  towards the boss. It stops when it reaches its target.
- **Damage:** after 3 seconds in the storm, the player is hurt every time their
  invulnerability ends. Going back inside resets the timer.
- **Enemies** are not affected by the storm.

Select `BorderStorm` in `scn/game/arena.tscn` and change these in the Inspector:

| Setting | What it does |
|---|---|
| `Current Radius` | Starting radius in meters (changes during play) |
| `Target Radius` | The radius the circle grows or shrinks towards. Lower it for a time limit |
| `Radius Grow Speed`, `Radius Shrink Speed` | Meters per second the radius changes when growing / shrinking |
| `Storm Movement Speed` | Meters per second the circle moves towards its target |
| `Storm Alpha` | How see-through the storm is (0.5) |
| `Storm Color`, `Ring Color`, `Ring Width` | The storm's colour, the border ring's colour and width in meters |
| `Cloud Speed` | How fast the storm clouds drift (0 stops them) |

| Constant (`scripts/game/border_storm.gd`) | What it does |
|---|---|
| `DAMAGE_DELAY_SECONDS` | Seconds in the storm before it starts hurting the player (3) |
| `MIN_RADIUS` | The radius never goes below this (0.01) |

From code, change `current_radius` or `target_radius` on the BorderStorm (e.g.
`_arena.get_border_storm().target_radius = 20.0`). `is_in_storm(position)` says
whether a point is in the storm.

**Look:** the `StormOverlay` child is one large plane, kept under the camera,
drawn on top of everything with `gfx/shaders/border_storm.gdshader`.
- Cloud size, cloud strength and the soft edge of the storm are shader settings.
  Open `scn/game/border_storm.tscn`, select `StormOverlay` and look under
  **Mesh > Material > Shader Parameters**.
- The cloud texture is the `NoiseTexture2D` in the same place.
- The overlay is hidden in the editor and shown when the game runs.

Because the sky below the arena is already very dark, the storm is only a
little darker. It shows mostly through its clouds and the ring. Raise
`Storm Alpha` or change `Storm Color` to make it stand out more.

## The player (`scripts/game/player.gd`)

| Constant | What it does |
|---|---|
| `MOVE_SPEED` | Walking speed, meters per second |
| `FIRE_INTERVAL` | Seconds between shots while Confirm is held (0.2) |
| `BULLET_SPAWN_DISTANCE` | How far in front of the player bullets appear |
| `DASH_SPEED_MULTIPLIER` | Dash speed as a multiple of `MOVE_SPEED` |
| `DASH_MAX_DISTANCE` | Longest dash in meters (12) |
| `DASH_COOLDOWN` | Seconds from the start of one dash until the next is allowed (2) |
| `MAX_HEALTH` | Starting health (3) |
| `INVULNERABLE_SECONDS` | Time the player cannot be hurt after a hit (2) |
| `INVULNERABLE_BLINK_INTERVAL` | Blink speed while invulnerable |

**Dash Always Full Distance** is a checkbox in the Inspector on the Player node
(in `scn/game/player.tscn`). When on, releasing Back does not end a dash early.

To replace the player's look, put the model under the `Model` node with its front
facing +Z (Blender's front view exported to glTF faces this way). The `dash`
animation in the `AnimationPlayer` plays during a dash; `RESET` plays when it ends.

## Player bullets (`scripts/game/player_bullet.gd`)

| Constant | What it does |
|---|---|
| `SPEED` | Meters per second |
| `LIFETIME` | Seconds before a bullet disappears on its own (5) |

## Enemies

Every enemy scene has settings on its root node in the Inspector:

| Setting | What it does |
|---|---|
| `Max Hits` | Player bullet hits to defeat it (Chaser 2, Tank 2, Angry Greg 5) |
| `Score Value` | Score when defeated (Chaser 0, Tank 0, Angry Greg 10) |
| `Is Boss` | Marks bosses |

Behaviour numbers are constants at the top of each script:

| Script | Constants |
|---|---|
| `scripts/game/enemy/enemy.gd` (all enemies) | `FADE_IN_SECONDS` (0.25), `BULLET_SPAWN_GAP` |
| `scripts/game/enemy/chaser.gd` | `SPEED` |
| `scripts/game/enemy/tank.gd` | `SPEED`, `FIRE_INTERVAL` (4), `BULLET_SPEED` |
| `scripts/game/enemy/angry_greg.gd` | `FIRE_INTERVAL` (4), `BULLET_SPEED` |

Enemy size comes from the sphere in each scene's `CollisionShape3D`. The `Hurtbox`
sphere should be slightly bigger (0.1 m); touching the player inside it hurts them.
Enemies block the player but pass through each other.

**Adding a new enemy:** copy `scn/game/chaser.tscn`, give it a new script that
starts with `extends Enemy`, and fill in `_on_activated()` (runs once, when the
fade-in ends) and `_active_physics_process(delta)` (runs every frame after that).
Helpers you can use: `direction_to_target()`, `get_target_position()`,
`shoot_at_target(speed)`, `face(direction)`, `is_wall(collision)`,
`move_sliding(motion)` (move and glide along walls; cheaper than Godot's
`move_and_slide()`) and `is_pushing_into_player(direction)` (skip moving when
already pressed against the player). See the Tank script for an example.
Then use the scene in a wave in the spawner's bags, or add it to the flag
loop's boss list (both below). The full step-by-step guide, with a worked
example and recipes, is `docs/ENEMIES.md`.

## Enemy bullets (`scripts/game/enemy/enemy_bullet.gd`, `scripts/game/enemy/enemy_bullet_pool.gd`)

| Constant | What it does |
|---|---|
| `EnemyBullet.DEFAULT_SPEED` | Meters per second when an enemy does not set its own |
| `EnemyBullet.LIFETIME` | Seconds before an unused bullet disappears (10) |
| `EnemyBulletPool.STARTING_SIZE` | Bullets made when a game starts (128) |
| `EnemyBulletPool.GROW_BY` | Bullets added when the pool runs out (a message is logged when this happens) |

## Enemy spawning (`scripts/game/enemy/enemy_spawner.gd`)

Normal enemies arrive in **waves**, and waves come from **bags**. Which bag is
used depends on the **danger level**.

### Waves (`scripts/game/enemy/enemy_wave.gd`)

A wave is a group of one type of enemy, written in code as
`EnemyWave.new(enemy, count, wave_delay_seconds, next_wave_delay)`:

| Field | What it does |
|---|---|
| `enemy` | The enemy scene, e.g. `CHASER` or `TANK` (constants at the top of the spawner) |
| `count` | How many enemies the wave spawns (1 or more) |
| `wave_delay_seconds` | Seconds between each enemy of the wave. 0 spawns the whole wave at once |
| `next_wave_delay` | Seconds from the **start** of this wave until the next wave starts |

Every enemy of a wave appears at the same EnemySpawnPoint. The point is chosen
when the wave starts, from the points 20 to 100 m from the player. Later
enemies of the wave still use it even if the player has moved close to it since.

Waves can overlap: if `next_wave_delay` is shorter than the wave takes to
spawn, the next wave starts while this one is still spawning. A `next_wave_delay`
of 0 starts the next wave on the following frame.

### Bags and danger

A bag is a list of waves, played in a random order. When a bag runs out, the
next one is chosen by the danger level at that moment, in
`get_bag_via_danger()` in the spawner. The bags and their danger thresholds
(currently below 10, below 50, below 100, and 100 or more) are written out
there; edit that function to change them. A bag always plays all its waves,
even if danger crosses a threshold meanwhile.

The danger level is `danger_level` in `scripts/states/in_game.gd`:

- It goes up by 1 every second the player is alive.
- Touching a flag adds 10 (`increase_danger(10)` in `scripts/game/flag_loop.gd`).
- It stops rising when the player dies or the game is paused.

Call `increase_danger(amount)` on the In Game scene to add other sources of danger.

### Settings

Select the EnemySpawner node in `scn/in_game.tscn` and change these in the Inspector:

| Setting | What it does |
|---|---|
| `Min Spawn Distance`, `Max Spawn Distance` | Only EnemySpawnPoints this far from the player are used when a wave starts (20 to 100 m) |
| `Retry Delay` | Wait before trying again when no spawn point is usable (0.25) |

The first wave starts 1 second into the game (`_time_until_next_wave` in
`setup()`). Spawning stops while the game is paused and once the player is dead.

For time-based spawning logic, `get_time_survived()` in the spawner returns the
seconds the player has survived. It counts game time only (not while paused)
and stops when the player dies.

## Flags and bosses (`FlagLoop` node in `scn/in_game.tscn`)

| Setting | What it does |
|---|---|
| `Boss Scenes` (Inspector) | Bosses that can appear, equal chance each |
| `FLAG_SCORE` (constant in `scripts/game/flag_loop.gd`) | Score for touching a flag (1) |
| `increase_danger(10)` (in `_on_flag_touched()` in the same file) | Danger added for touching a flag (10) |

## Camera (`Camera` node in `scn/in_game.tscn`)

Select the Camera node and change these in the Inspector:

| Setting | What it does |
|---|---|
| `View Height Meters` | Meters of the arena visible from the top to the bottom of the screen (40) |
| `Field Of View Degrees` | Lower is flatter, with less perspective (50) |

## HUD (`scn/ui/hud.tscn`) and health pips (`scn/ui/health_pip.tscn`)

Open the scenes to restyle them; the code only sets text and plays animations.

| What | Where |
|---|---|
| Score text format | `SCORE_TEXT` in `scripts/ui/hud.gd` |
| Score / time / pip layout | `TopBar` in `scn/ui/hud.tscn` |
| "YOU DIED" banner and its hint | `YouDied` in `scn/ui/hud.tscn` |
| Banner animations | `AnimationPlayer` in `scn/ui/hud.tscn`: `you_died` plays once, then `you_died_loop` repeats |
| Pip look | `scn/ui/health_pip.tscn`. Its `AnimationPlayer` has `full`, `lose` (plays when health is lost) and `empty` (shown after `lose`) |

One pip is made per point of `MAX_HEALTH`.

## Pause menu (`scn/ui/pause_menu.tscn`, `scripts/ui/pause_menu.gd`)

Pause opens the menu while the player is alive and pauses the whole game.
- **Resume** is instant: the menu closes and a 3, 2, 1 countdown plays before
  the game carries on. Pause cannot be pressed again during the countdown.
- **Restart** and **Exit** need Confirm held until the bar fills. They start a
  new game or go to the Main Menu without saving the score.
- While the menu is open, Pause works like choosing Resume, and Back moves the
  cursor to Resume.

| What | Where |
|---|---|
| Hold time for Restart / Exit | `HOLD_SECONDS` in `scripts/ui/pause_menu.gd` (0.5) |
| Countdown start number (one number per second) | `COUNTDOWN_FROM` in the same file (3) |
| Hi-score warning text | `HISCORE_WARNING_TEXT` in the same file. It shows on Restart and Exit when the score would make the table |
| Menu items | Labels under `Menu` in `scn/ui/pause_menu.tscn`. If you reorder them, reorder `Item` in the script to match |
| Menu look (dim, title, hold bar, warning) | `MenuScreen` in `scn/ui/pause_menu.tscn` |
| Countdown number and its animation | `CountdownScreen` and the `AnimationPlayer` (`countdown_tick`, played once per number) in the same scene |

The pause menu node's **Process Mode** is **Always**, so it keeps running while
the rest of the game is paused. Anything you add that must move during the
pause (e.g. an animated background for the menu) must go under it.

When play resumes, Confirm and Back need a fresh press, so the Confirm used to
choose Resume does not start firing.

## End of a game (`scripts/states/in_game.gd`)

| Constant | What it does |
|---|---|
| `DEATH_SCREEN_MAX_SECONDS` | Longest the "YOU DIED" screen stays up (90) |
| `DEATH_SCREEN_SKIP_AFTER_SECONDS` | Seconds before a fresh Confirm press can end it (5) |

The score, time survived and date/time are fixed at the moment the player dies.
If the score makes the hi-score table the game goes to Name Entry, otherwise to
Game Over.

## Collision layers

Named in Project Settings → Layer Names → 3D Physics, and listed in
`scripts/game/gameplay.gd`: 1 Walls, 2 Player, 3 Enemies, 4 Player Bullets,
5 Enemy Bullets, 6 Flags. Enemies block the player; bullets pass through nothing
but walls and their targets.

## FX signals

Signals starting with `fx_` exist only for effects and sounds; game logic never
uses them. Connect to them to add effects.

| Node | Signals |
|---|---|
| Player | `fx_shot_fired`, `fx_dash_started`, `fx_dash_ended`, `fx_dash_attempted_during_cooldown`, `fx_hurt`, `fx_invulnerability_started`, `fx_invulnerability_ended`, `fx_died` |
| PlayerBullet | `fx_hit_wall`, `fx_hit_enemy`, `fx_expired` |
| Every enemy and boss | `fx_spawn_started`, `fx_activated`, `fx_hit`, `fx_defeated`, `fx_shot_fired` |
| EnemyBullet | `fx_hit_wall`, `fx_hit_player`, `fx_expired` |
| Flag | `fx_touched`, `fx_restored` |
| InGame | `fx_you_died_shown`, `fx_continue_available` |
| BorderStorm | `fx_player_entered_storm`, `fx_player_left_storm` |
| PauseMenu | `fx_pause_menu_entered`, `fx_pause_resume`, `fx_countdown(number)` (3, 2, 1), `fx_pause_restart`, `fx_pause_exit`. These run while the game is paused, so effects connected to them must have their Process Mode set to Always |
| Name Entry screen | `fx_cursor_moved`, `fx_character_added`, `fx_character_removed`, `fx_press_refused`, `fx_name_saved` |

To react to every enemy, connect to the EnemySpawner's `enemy_spawned(enemy)`
signal (a game logic signal) and connect to the new enemy's `fx_` signals there.

## Where the user:// folder is

- Linux: `~/.local/share/godot/app_userdata/Zinc Warbler/`
- Windows: `%APPDATA%\Godot\app_userdata\Zinc Warbler\`

Delete `config.cfg` or `hiscores.json` there to reset settings or hi-scores.
