# Designer Guide

Where to change things in Zinc Warbler. All paths are inside `src/`.

## Folder layout

| Folder | Contents |
|---|---|
| `scn/` | Scenes: one per game state, e.g. `main_menu.tscn`, `config.tscn` |
| `scripts/autoload/` | Global scripts that are always running: `GameState`, `Settings`, `Hiscores` |
| `scripts/states/` | One script per state screen |
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

## Where the user:// folder is

- Linux: `~/.local/share/godot/app_userdata/Zinc Warbler/`
- Windows: `%APPDATA%\Godot\app_userdata\Zinc Warbler\`

Delete `config.cfg` or `hiscores.json` there to reset settings or hi-scores.
