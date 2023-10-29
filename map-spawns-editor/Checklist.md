# Checklist

This checklist describes Map Spawns Editor functionality and can be used for testing purposes.

Updated for version 1.2.0

## General

- Activate and deactivate the editor

## CVARs

- amx_mse_safe_p2p
- amx_mse_safe_p2w
- amx_mse_rotation_angle
- amx_mse_z_offset
- amx_mse_unsafe_check

## Menu

- Turn on and off
- Change active page
- Trigger spawns counter to update
- Cycle through spawn type

## Visual indication

- Mouseover and mouseout a spawn (find and animate)
- Unsaved changes
- Safe and unsafe distance to a spawn
- Safe and unsafe distance to a world object

## Core functionality

- Add a T spawn
- Add a CT spawn
- Turn clockwise and counterclockwise
- Delete the active spawn
- Delete all T spawns
- Delete all CT spawns
- amx_map currentmap

## Interacting with the file system

- Write spawns config
- Write mirrored spawns config
- Delete spawns config
- Export as ENT
- Trigger _die.cfg to be written
