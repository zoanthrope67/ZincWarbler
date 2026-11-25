# Zinc Warbler

# Overview

An arcade multi-directional shooter in Godot 4.7.2. The game will be rendered in 3d. Gameplay will be 2D and the camera will always be a top down view.

The menu screens stay centered. The final art style will use 3d models from Blender; this will be handled by a human separately at a later date. For this prototype, simple placeholders of simple shapes must be used which will be replaced later. The expected size of the player's model is 2x2 meters. The player's hitbox should be a sphere.

Gameplay takes place in a single arena. This should be a GridMap of walls which is able to be updated by the game designer via the Godot editor easily. Wall tiles block the player, enemies and all bullets. Each grid should have a 4x4 footprint and be 4 meters tall. The arena has no outer walls blocking the player in: the edge of the play area is the BorderStorm (see BorderStorm). Walls inside the arena are kept.

Godot UI nodes should be used to display the current score, health and time. Health is drawn as a lifebar of animated pips, one per point of health; a pip that is lost plays a short "lose" animation before showing as empty.

The project should be able to be exported to an executable.

In the final project, all graphical and audio assets will be authored by humans. It is required that any assets generated are clearly labelled by filename or some other process so that they can be removed later. Where possible, variables should be clearly commented so that human game designers can change them by feel.

## Controls

The game is controlled using the Arrow Keys, Z as a confirm button and X as a back button. In game, Confirm fires and Back dashes. Escape (or Start on a controller) is the Pause button. The Pause button cannot be rebound, and Escape and Start cannot be bound to any other action. The Input Map should be used to allow easy configuration of controls at a later date. Ideally, the Godot Input Mapping should also allow game controllers to be used.

## FX Signals

Actions in the game should trigger Godot signals with an fx_ prefix that will be used at a later date to control graphical effects and sound effects. Any signals used to control game logic must not be coupled with FX signals.

## States

The game contains the following states.

 * Bootstrap
 * Main Menu
 * In Game
 * Name Entry
 * Game Over
 * Hiscore
 * Config Options
 * Error

The current state and the previous state are stored in the GameState autoload, using its State enum, and are updated every time the state changes. Both start as Bootstrap. Error is a terminal state.

## Bootstrap State

Bootstrap is the first scene loaded when the game starts. It sets the current and previous state to Bootstrap, shows a "Loading..." graphic for 0.05 seconds and then moves to the Main Menu. The game never returns to Bootstrap. Any logic that needs to run once when the game first loads belongs here. The end user will most likely never see this screen but it is there in case future development requires a more detailed set up.

## Main Menu State

The Main Menu contains a title splash image and a keyboard controlled menu. The options in the menu are:
 * Start Game - This begins a new game, moving to the In Game state
 * View Hiscores - This moves to the hiscore state
 * Config Options - This moves to the config state
 * Quit Game - This closes the game

## In Game State

When in game, the player will enter the arena. The Arena is made up of a GridMap that contains the geometry, multiple flags, multiple PlayerSpawnPoints, multiple EnemySpawnPoints and a BorderStorm. When the player has no health then the game stays on the In Game screen and shows an animated "YOU DIED" banner over it. The player is hidden and disabled, all player bullets are removed and the score is locked. The time survived and the date and time the game ended are both taken at the moment the player dies. Enemies carry on moving and firing at the player's last known position. This lasts for 90 seconds, or until the player makes a fresh press of Confirm (not one held from before) once 5 seconds have passed. The game then ends. If the player's score makes the hi-score table, the game will change state to Name Entry, otherwise it will change state to a Game Over screen showing the player's score and how long they survived.

### Pausing

When the player presses Pause, all gameplay is paused and a pause menu is displayed. The player cannot pause while the player is dead. The menu contains:
 * Resume - the menu disappears and gameplay resumes after 3 seconds. Animated numbers show 3, 2 and 1, and an FX signal (fx_countdown) is emitted for each with the current number as its argument. The player cannot pause again during the countdown.
 * Restart - the game is reset to the beginning as if a new game was started. The score is not saved to the hi-score table.
 * Exit - the game is ended and goes back to the Main Menu. The score is not saved to the hi-score table.

Resume is instant. To avoid accidental button presses ending a game, the player must hold Confirm to choose Restart or Exit; a bar fills while the button is held and takes 0.5 seconds to fill. If the player's score would go into the hi-score table, a warning message is shown while Restart or Exit is selected.

Pressing Pause while the pause menu is open is treated as choosing Resume. Pressing Back while in the pause menu moves the cursor to Resume but does not choose it.

When gameplay resumes, Confirm and Back need a fresh press, so the press used to choose Resume does not start firing.

The FX signals fx_pause_menu_entered, fx_pause_resume, fx_pause_restart and fx_pause_exit are emitted for effects.

### Prestartup Validation

Arenas must have at least 1 PlayerSpawnPoint
Arenas must have at least 1 EnemySpawnPoint
Arenas must have at least 2 flags
Every flag must have at least 1 BossSpawnPoint
Arenas must have a BorderStorm

If any of these are breached then an error must be raised and play must be stopped. This must display an error screen.

It is the designer's responsibility to place spawn points in sensible places.

### The Player

The player begins play with 3 health and a score of 0. Each hit from an enemy or enemy bullet takes away 1 health. The player's facing at the start of the game is set as if the player pressed right.

The Player can move in 8 directions and can fire bullets in 8 directions. They can fire once every 0.2 seconds and will begin firing when the confirm button is held. Tapping does not make the player shoot faster. While the button is held, the direction that the player last moved is stored and the player will fire in this direction until they release the button. The player cannot change what direction they are firing in until they release the button. The player is blocked by walls and their bullets disappear when they hit a wall. Player bullets also disappear after 5 seconds, so a gap in the arena's walls cannot leave bullets flying forever. The player's speed must be a constant value that is clearly commented so that a game designer can change it at a later date.

Pressing Back starts a dash in the direction the player last moved, faster than their normal speed. The player cannot steer during a dash. The dash lasts until Back is released, the player collides with a wall or enemy or it has travelled 12 meters in total. The game designer will playtest different dash lengths, and a designer setting (off by default) makes every dash go the full maximum distance, so releasing Back does not end it. A dash also ends when the player dies. The player cannot dash again until 2 seconds after a dash is started, and needs a fresh press of Back once the cooldown is over. The dash does not protect the player: they can be hit while dashing as normal. The player cannot shoot and dash at the same time. Whichever started first carries on, and the other button is ignored until it is pressed again, so releasing Back while Confirm is held does not start firing, and holding Back while firing does not start a dash. If Confirm and Back are pressed on the same frame, shooting wins. The dash speed, cooldown and maximum distance are constants that the game designer can change. The fx_dash_started, fx_dash_ended and fx_dash_attempted_during_cooldown FX signals are emitted for effects, and the player plays a dash animation while dashing.

No inertia is to be applied to the player character.

If the player takes damage, they are invulnerable for 2 seconds.

When the game starts, the player is moved to a random PlayerSpawnPoint.

### Player Bullets

Player bullets are 0.5 meter yellow spheres. Their speed is a constant that the game designer can change. They disappear when they hit an enemy.

### Camera

The camera should be Perspective view and give a view of 40 meters around the player vertically in total. The game designer will need to manually adjust this often for taste. The camera follows the player and can scroll outside of the arena. The camera is angled straight down.

### Enemies

There are two types of normal enemy and one type of boss. The human game designer will add more enemies and bosses at a later date. All enemies and bosses use a sphere hitbox.

The normal enemies are:
 * Chaser: Faces towards the player on first spawn and then moves in that facing. If they collide with a wall then they attempt to shapecast towards the player using a get_world_3d().direct_space_state.cast_motion that only checks walls. If they can find an unobstructed path then they face towards the player, otherwise they flip their facing 180 degrees. Their speed is a constant that the game designer can change. Can take 2 hits before being defeated.
 * Tank: Moves towards the player. Their speed is a constant that the game designer can change. If they collide with a wall then they slide along it. No advanced pathfinding will be required for this enemy. Fires an enemy bullet every 4 seconds towards the player with the first shot 4 seconds after they finish spawning. Can take 2 hits before being defeated.

Enemies are 2x2 meters large. Score is not awarded for killing an enemy. There should be no cap on enemy spawns for now, future development will consider this.

The boss is:
 * Angry Greg: Static enemy. Fires an enemy bullet every 4 seconds towards the player with the first shot 4 seconds after they finish spawning. Can take 5 hits before being defeated. 10 points are awarded for defeating Greg.

Angry Greg is 4x4 meters large.

The human game designer will add more enemies at a later date, this is subject to change.

Normal enemies spawn in waves. A wave sets:
 * which enemy it spawns (one type per wave),
 * how many enemies it spawns (at least 1),
 * the seconds between each enemy of the wave (0 spawns the whole wave at once),
 * the seconds from the start of the wave until the next wave starts.

Waves can overlap: if the next wave starts before a wave has spawned all its enemies, both waves carry on spawning. Every enemy of a wave appears at the same EnemySpawnPoint, chosen at random from the valid EnemySpawnPoints when the wave starts. Later enemies of the wave still use that point, even if it is no longer valid. The list of valid EnemySpawnPoints is any EnemySpawnPoint that is:
 * Between 20 - 100 units of the player. This will be changed often by the human game designer for feel.

Waves are taken from bags. A bag is a list of waves played in a random order. When a bag runs out, the next bag is chosen by the current Danger Level (see Danger Level). A bag always plays all its waves, even if the Danger Level changes meanwhile. The bags, and the Danger Level thresholds that choose them, are written in code so that the game designer can change them often.

The first wave starts 1 second after the game starts. No wave starts and no enemy spawns once the player has been defeated.

If there is no valid EnemySpawnPoint when a wave is due to start then a debug message should be logged and the wave should be deferred for 0.25 seconds. The waves after it are pushed back by the same amount.

When an enemy appears it fades in over 0.25 seconds. During this time it does not move and cannot hurt or be hurt, so an enemy never hits the player the instant it appears. It then becomes active.

Enemies should block player collision. Fading-in enemies have no collision mask or layer until they have finished spawning in.

### Enemy Bullets

Enemy bullets are a 0.5 meter purple sphere. A bullet pooling system should be used to increase performance. More bullets must be added if required. The pool should start with 128 bullets. An enemy bullet will be recycled after 10 seconds, if it collides with a player or if it collides with a wall. Enemy bullets do not collide with enemies or with other bullets. Enemy bullets have a default speed, a constant that the game designer can change, which is used unless an enemy sets its own.

### Flags

The arena has multiple flags at static positions. When the player touches a flag, they should gain 1 score and 10 Danger, and the flag should be hidden and marked as inactive. Once all flags have been touched, a random Boss enemy should be spawned. Once the boss enemy is defeated, the flags should be restored, with the exception of the one flag that is closest to the player. If the player touches all flags again then a new boss should spawn. Play will continue in this loop until the player is defeated.

Each flag must have its own set of BossSpawnPoints. When a boss is spawned, a random BossSpawnPoint that belongs to the latest touched flag must be used to set the position of the Boss. If any flag in the arena does not have a BossSpawnPoint then the error must be raised and play should be stopped. The human game designer will then fix this manually.

### BorderStorm

Instead of outer walls, the play area is a circle called the BorderStorm. Everything outside the circle is "the storm". All BorderStorm distances are measured flat, on X and Z only.

The centre of the circle is a Node3D that is a child of the Arena. It starts in the middle of the arena, and the game designer can move its starting position. The area outside the circle is shown in greyscale with a TV static (white noise) effect over it. The effect has a hard edge exactly at the circle's radius, where the storm starts to hurt the player. The alpha of the static can be changed by the game designer.

The circle moves towards a random uncollected flag. Each time a flag is collected, another random uncollected flag is chosen. When a boss is spawned, the circle moves towards the boss instead. After the boss is defeated, it moves towards a random uncollected flag again. When the circle reaches its destination it stays in place. Its movement speed is a constant that the game designer can change.

The circle has a current radius and a target radius. The current radius changes smoothly towards the target radius, using a grow speed when it is getting larger and a shrink speed when it is getting smaller. The current radius, target radius, grow speed and shrink speed are settings the game designer can change, and the radius can also be changed during gameplay. The current radius never goes below 0.01 meters. With the target radius smaller than the starting radius, the storm acts as a soft time limit.

Game objects outside the circle work the same as inside it. Enemies can leave the circle and are not affected by the storm.

If the player stays in the storm for 3 seconds, they lose 1 health every frame for as long as they stay there. The storm respects invulnerability, so in practice the player is hit once each time their invulnerability ends. Going back inside the circle resets the 3 second timer. The FX signals fx_player_entered_storm and fx_player_left_storm are emitted when the player goes into and comes out of the storm.

### Danger Level

The Danger Level starts at 0 at the start of every game. It rises by 1 every second while the player is alive, and by 10 each time the player touches a flag. It stops rising once the player is defeated. The Danger Level chooses which bag of enemy waves is used next: the higher the Danger Level, the more dangerous the bag. More ways to raise the Danger Level will be added at a later date.

## Name Entry State

When a player's game ends with a score that makes the hi-score table, they are prompted to give a name. This uses a keyboard controlled character display where the user moves a cursor to select a character. The acceptable characters are the English letters A to Z and the numbers 0 to 9. Pressing Confirm adds the selected character and pressing Back removes the last one. There is also a "BACKSPACE" button that does the same as pressing Back, and an "END" button that saves the name and moves to the Game Over state.

A name must be at least 1 and at most 8 characters long. When the name reaches 8 characters the cursor automatically moves to the END button. When Back is pressed, the cursor moves to the BACKSPACE button if it is not already there. The user cannot skip entering a name. Entering a name of zero characters is invalid and the END press will be ignored.

## Game Over State

When in the game over state, the player's current score and how long they survived should be displayed on the screen. If the player freshly presses Confirm after 0.5 seconds of entering the screen then they should be moved to the Main Menu state.

## Hiscore State

When in the hi-score state, the user is shown the top 10 scores. The scores should be saved onto the user's local machine. The game should never try to save a hi-score onto the internet.

Each hi-score stores a name, the score, the number of seconds survived and the datetime the game ended (from get_datetime_string_from_system(), in the user's local timezone). Hi-scores are ordered by highest score first, then most time survived, then the latest datetime.

When the hi-scores are first saved, or are cleared via the Config menu, the table is filled with a starting set of scores hardcoded in the game.

The values should be

name,score,seconds_survived
AAA,100,1
BBB,90,1
CCC,80,1
DDD,70,1
EEE,67,1
FFF,60,1
GGG,50,1
III,40,1
JJJ,30,1
HHH,20,1

Their datetimes are set to the time the table was filled. Hi-score files saved by older versions of the game are ignored and replaced by the starting table. 

When in the hi-score state, the user can press Back to return to the main menu.

The hiscore file requires a VERSION number.

## Config options

The config options screen will show configuration options to change the audio levels of the background music and sound effects along with being able to change the game controls and clear the hi-scores. The user can also exit the config and go back to the main menu. The user should also be able to change the fullscreen setting from this menu. Fullscreen is On by default.

Config should be saved to a file.

### Error state

The error should be clearly stated and a fresh press of Confirm should quit the game. This state will be removed in later dev work when the project is closer to completion.