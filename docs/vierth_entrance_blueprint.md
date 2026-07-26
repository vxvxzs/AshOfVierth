# Vierth Entrance - map blueprint

## Scope

- Grid: 30 x 20 cells.
- Tile size: 32 x 32 px.
- Play direction: Iven enters from the southern edge and follows a winding sandy road north toward the gate.
- Visual hierarchy: readable road in the middle, dense autumn forest on both sides, small fenced gate area at the northern edge.

## Spatial rhythm

1. **Arrival clearing (rows 17-19):** enough open space to read movement and the first camera zone.
2. **Lower bend (rows 12-16):** the road bends west around rocks and a stump.
3. **Forest throat (rows 7-11):** the narrowest section, framed by trees and shrubs.
4. **Upper bend (rows 3-6):** the road turns east toward the gate.
5. **Vierth gate (rows 0-2):** fence, entrance sign and two non-hostile NPC placeholders.

## Scene layers

- `GroundLayer/ContinuousGround`: one continuous 960 x 640 px image containing grass and a winding road. Its alpha edges are binary and it is rendered with nearest-neighbour filtering, so the terrain keeps the same texel density as the props.
- `World`: one Y-sorted world shared by Iven, NPCs and scenery.
- Large scenery objects are independent `StaticBody2D` nodes rather than 32 x 32 map cells. Trees, rocks, shrubs, stumps, fences and the entrance sign use transparent PNG sprites and compact collisions placed around their bases.
- The compatibility TileSet contains only the eight small terrain samples used by the build tools. Large scenery must never be packed back into that grid.

## Camera

`HLDCamera2D` follows Iven smoothly inside a small deadzone and clamps its
center to the active world rectangle. `CameraZone2D` nodes display their bounds
and focus point in the editor. Crossing their trigger temporarily detaches the
camera, performs a smoothstep pan to the new focus, then resumes follow mode.

To tune a zone, edit its `camera_bounds`, `transition_focus` and
`transition_duration_override` properties. The camera and generated world
objects are snapped to whole world pixels; the 2x integer zoom keeps one world
pixel aligned to two screen pixels.

## Editable data

Layout values live in `res://data/levels/vierth_entrance_blueprint.json`. Road centers, named landmarks, NPC positions, forest density, spawn point and camera behavior can be changed there without editing the generated scene by hand.

## Rebuild pipeline

Run the image processor after replacing `vierth_generated_source.png`. It removes the magenta background with binary transparency, creates the continuous ground image and exports large objects to `assets/tilesets/vierth_objects/`:

```powershell
python tools\build_vierth_tiles.py
```

Then let Godot import the generated images and rebuild the scene:

```powershell
Godot.exe --headless --path . --editor --quit
Godot.exe --headless --path . --script res://tools/build_vierth_scene.gd
```
