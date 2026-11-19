# Echo

A 2.5D puzzle platformer made in Godot 4.7 (GL Compatibility, works for web export).

Subject 712, call sign Black Dolphin, crash-lands on Nyx-4. The moon's magnetic field, the Echo,
remembers every life lost there and plays it back.

## How it plays
- **Q** ends your current life and leaves an **echo**. Next life, the echo replays exactly what you did,
  then stays where it stopped and becomes solid. Echoes hold plates, act as steps, and build staircases.
- **Dying** on spikes leaves a **crystal body** that is solid from the start of your next life: a bridge over pits.
- Plates open gates (and run lifts) only while something stands on them. Colours match plates to gates.
- Up to 3 echoes per level; a 4th replaces the oldest. Stars depend on how many lives you used (par).

### Chapter 2 mechanics (levels 9-16)
- **Grip walls** (green moss): jump into one while holding toward it to cling, SPACE to wall-jump.
  You can also leave an echo while clinging; it stays hanging on the wall as a ledge.
- **Vents**: updraft columns that lift you while you are inside them.
- **Acid**: dying in acid leaves a **slime body** that bounces you high, a bounce back.
- **Portals**: one way. Orange swirl in, violet swirl out.
- **Ferries**: carts that run back and forth on their own.
- **Dark levels**: only you, your echoes, plates, gates and hazards give light.

## Online co-op with room codes (desktop builds)
Players connect through a small **room server**. One player creates a room and gets a 5-letter code,
the friend types the code and joins. Only the server PC needs an open port.

### Run the room server (on your PC)
1. Double-click `run_server.bat` (or run `Godot_console.exe --headless --path . -- --server`;
   an exported build works too: `Echo.exe --headless -- --server`). Leave the window open.
2. On your router, forward **UDP port 7777** to this PC. Windows may ask to allow it through the firewall: allow it.
3. Your friends set the room server address (wrench icon in the Multiplayer screen) to your **public IP**
   or a free dynamic-DNS name. You play on the same PC as the server with `127.0.0.1`.
4. To ship a build where friends never type the address, change `DEFAULT_SERVER` at the top of
   `scripts/net.gd` to your public IP or DNS name before exporting.

### Playing
Main menu > **Multiplayer** > **Create room** (you get a code) or **Join room** (type the code).
The host picks a level. The host's game runs the level; the guest's inputs and the host's world state
travel through the room server.

Co-op rules:
- Both players use the normal controls on their own computer. Player 2 is the pink astronaut.
- You can stand on your partner's head.
- **x2 plates** need two weights (players or echoes).
- Shared timeline: when one of you presses Q or dies, that player waits. When both are done,
  the next life starts and both runs replay as echoes.
- Each player must stand at a **different beacon** to finish.
- 6 co-op levels: Hold the Door, Heavy Plate, Boost, Two Halves, Bridge for Two, Heavy Lifting.

Tests: `tools/test_coop.tscn` plays all co-op levels with two scripted players; `tools/test_net.tscn`
runs a host and a guest against a running room server (`ECHO_ROLE=host` / `guest`, `ECHO_CODE_FILE=<path>`).

## Controls
| Action | Keys |
|---|---|
| Move | A / D, arrow keys, left stick |
| Jump | Space, W, Up, pad A |
| Leave an echo | Q or E, pad X |
| Clear all echoes | R, pad Y |
| Pause | Esc, pad Start |

## Project layout
- `scripts/levels.gd`: all 16 levels as ASCII maps (`#` rock, `G` grip rock, `S` spawn, `X` beacon,
  `^` spikes, `%` acid, `~` vent, `1`/`3` portal in, `2`/`4` portal out, `a`-`d` plates, `A`-`D` gates,
  lifts and ferries in the `lifts` list as `[col, row, dx, dy, channel]`, channel `""` = always moving,
  `"dark": true` for a dark level).
- `scripts/level.gd`: builds a level from its map and runs the echo time loop.
- `scripts/player.gd`, `scripts/echo.gd`: player controller and recorded echoes.
- `scripts/hud.gd`, `main_menu.gd`, `level_select.gd`, `text_screen.gd`: UI.
- `tools/`: automated tests (not needed for the game).
  - Solutions: `godot --headless --fixed-fps 60 --path . res://tools/test_run.tscn`
  - Set `ECHO_NEG=1` to check that each level cannot be skipped.

## Credits
Alen Gevorgyan, David Ghazaryan & Koryun Gaboyan.
3D models, fonts and sound effects: Kenney (kenney.nl), CC0. License files are next to the assets.
Ambient music loop generated for this project.
