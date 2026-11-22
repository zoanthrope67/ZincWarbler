# Designer Guide

Where to change things in Zinc Warbler. All paths are inside `src/`.

## Folder layout

| Folder | Contents |
|---|---|
| `scn/` | Scenes: one per game state, e.g. `main_menu.tscn`, `in_game.tscn` |
| `scn/game/` | Gameplay scenes: `arena.tscn`, `player.tscn`, `player_bullet.tscn`, `flag.tscn` |
| `scripts/autoload/` | Global scripts that are always running: `GameState`, `Settings`, `Hiscores` |
| `scripts/states/` | One script per state screen |
| `scripts/game/` | Gameplay scripts (player, bullets, arena, flags, camera) |
| `scripts/ui/` | Shared UI pieces (the keyboard/controller menu) |
| `gfx/placeholder/` | Placeholder art, see `docs/asset_tracking.txt` |
| `gfx/`, `bgm/`, `sfx/` | Final graphics, music and sound effects |

## Controls

- **Default controls:** Godot editor → Project → Project Settings → **Input Map**.
  The actions are `move_up`, `move_down`, `move_left`, `move_right`, `confirm`, `back` and `pause`.
  Changes here become the game's defaults and what "Reset Controls to Default" restores.
- Players can rebind one keyboard key and one controller button per action on the Config screen.
  The left stick on the move actions and everything on `pause` are fixed.
- Reserved inputs that can never be bound (Escape, Start): `RESERVED_KEYS` and
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
| Font size for all screens | `gfx/placeholder/placeholder_theme.tres` (placeholder) |
| Background colour | Project Settings → Rendering → Environment → Default Clear Color |

## The arena (`scn/game/arena.tscn`)

| Node | How to edit |
|---|---|
| `Walls` | GridMap. Select it and paint tiles with the GridMap panel at the bottom of the editor. Each cell is 4 x 4 m and 4 m tall. Tiles come from `gfx/placeholder/placeholder_wall_library.tres` |
| `PlayerSpawnPoints` | Add `Marker3D` children. The player starts on one at random |
| `EnemySpawnPoints` | Add `Marker3D` children (used from phase 3) |
| `Flags` | Add instances of `scn/game/flag.tscn`. Give each flag one or more `Marker3D` children: those are its BossSpawnPoints. Keep them a few meters from the flag |

Only the X and Z position of markers matters. When a game starts the arena is
checked (at least 1 PlayerSpawnPoint, 1 EnemySpawnPoint, 2 flags, and a
BossSpawnPoint on every flag). If anything is missing, the Error screen lists it.
The minimum counts are constants at the top of `scripts/game/arena.gd`.

The game is played on a flat plane 1 m above the floor (`PLANE_HEIGHT` in
`scripts/game/gameplay.gd`). +X is right on screen and -Z is up on screen.

## The player (`scripts/game/player.gd`)

| Constant | What it does |
|---|---|
| `MOVE_SPEED` | Walking speed, meters per second (3) |
| `FIRE_INTERVAL` | Seconds between shots while Confirm is held (0.2) |
| `BULLET_SPAWN_DISTANCE` | How far in front of the player bullets appear |
| `DASH_SPEED_MULTIPLIER` | Dash speed as a multiple of `MOVE_SPEED` (3) |
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
| `SPEED` | Meters per second (5) |
| `LIFETIME` | Seconds before a bullet disappears on its own (5) |

## Camera (`Camera` node in `scn/in_game.tscn`)

Select the Camera node and change these in the Inspector:

| Setting | What it does |
|---|---|
| `View Height Meters` | Meters of the arena visible from the top to the bottom of the screen (40) |
| `Field Of View Degrees` | Lower is flatter, with less perspective (50) |

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

## Where the user:// folder is

- Linux: `~/.local/share/godot/app_userdata/Zinc Warbler/`
- Windows: `%APPDATA%\Godot\app_userdata\Zinc Warbler\`

Delete `config.cfg` or `hiscores.json` there to reset settings or hi-scores.
