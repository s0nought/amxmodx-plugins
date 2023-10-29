# Change Log

_**Note:** newer entries are added to the top._

## [1.2.0] 2023.10.29

### Added

- `amx_map currentmap` option to the menu
- Mirror spawns option to the menu

### Changed

- Getting menu item info
- Playing sound

### Removed

- Redundant get_mapname call

## [1.1.0] 2023.10.28

### Added

- CS translation
- CVAR `amx_mse_safe_p2p` (min distance between neighbouring points to consider them safe)
- CVAR `amx_mse_safe_p2w` (min distance between a world object and a spawn to consider latter one safe)
- CVAR `amx_mse_rotation_angle` (rotation angle to rotate spawns clockwise and counterclockwise)
- CVAR `amx_mse_z_offset` (Z offset to apply when creating spawns)
- CVAR `amx_mse_unsafe_check` (a toggle to enable and disable unsafe position check)
- [menu 2.0] A menu option to cycle through available entity types (T, CT)
- [menu 2.0] A single menu option to create T or CT spawns
- [menu 2.0] A single menu option to delete all of T or CT spawns

### Fixed

- A bug where CN and RU translations were displayed with artifacts
- A bug where pitch, yaw and roll from the exported ENT would not apply
- A number of typos in the dictionary keys
- [menu 2.0] A bug where a warning about unsaved changes would not appear when the before-after spawns counters match but spawns themselves differ
- [menu 2.0] A bug where CT spawn would be created twice

### Changed

- EN and RU translations (improvements)
- Simplified translations
- Code style (indent using 4 spaces and LF for EOL)
- Default value of SAFEp2p to 100
- [menu 2.0] Options grouping and order
- [menu 2.0] Client command to open MSE menu to `amx_mse_menu`
- [menu 2.0] Spawns counter format to `T: %d -> %d | CT: %d -> %d`
- [menu 2.0] The way a warning about unsaved changes is shown (it used to be below the spawns counter but now it is the SAVE button state)

### Removed

- Heredoc in Map_Spawns_Editor.sma
- Extra spaces and line breaks in ENT output
- Unused code
- [menu 2.0] Separate menu options for creating T and CT spawns
- [menu 2.0] Separate menu options for deleting all of T and CT spawns
- [menu 2.0] A toggle to enable and disable unsafe position check
- [menu 2.0] Unused dictionary keys

## [1.0.16] 2006.10.23

### Added

- A feature to change spawns' yaw (clockwise and counterclockwise).
- A feature to create a spawn above player's current position.
- A feature to make a directory for spawn configs if it does not exist.
- Multilingual support.
- CVAR `map_spawns` to store spawns count (supported by HLSW).

### Fixed

- The Del spawns can not be less than origin limit.  
_s0nought: I wasn't able to interpret this one._

## [0.5.0] 2006.08.23

Release of the first version of the plugin.
