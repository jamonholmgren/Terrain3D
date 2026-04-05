# Origin Shifting

When the player moves tens of thousands of units from the world origin, single-precision floating point math begins to break down. Positions jitter, rendering artifacts appear, and physics becomes unreliable. One common solution is **origin shifting** (also called origin rebasing): periodically teleporting the entire game world so the player stays near `(0, 0, 0)`.

This page describes how Terrain3D supports origin shifting so that terrain rendering, collision, data queries, instanced meshes, and navigation all remain correct after shifting the world around the player, without requiring a [double precision](double_precision.md) build of Godot.

## Caveats

1. Only use origin shifting if you are dealing with large worlds and experiencing noticable jittering due to floating point precision errors. Origin shifting brings some complexity to your game and is only worth it if you are willing to invest the time to implement it correctly.
2. Currently, origin shifting is not supported in the editor, only in the game runtime.
3. Origin shifting only works on the XZ plane (flat along the terrain). Y-axis (up and down) shifting is ignored.

## How It Works

Origin shifting introduces two coordinate spaces:

- **Shifted space** — the live game scene after rebasing. The camera, player, mesh instances, and collision shapes all live here, near `(0, 0, 0)`.
- **True-world space** — the stable absolute coordinate system used internally for terrain data storage (region lookups, height maps, texture sampling).

The conversion is:

```
true_world = shifted - world_origin_shift
shifted    = true_world + world_origin_shift
```

The `world_origin_shift` value matches `world_root.global_position` — both are negative relative to the true world origin.

For example: a player is truly at `(50000, 0, 50000)`. Your game has shifted the world so the player renders at `(0, 0, 0)` in Godot. The `world_root.global_position` is `(-50000, 0, -50000)`, and the `world_origin_shift` is also `Vector3(-50000, 0, -50000)`.

When you call `set_world_origin_shift(Vector3(-50000, 0, -50000))`, Terrain3D offsets all terrain rendering, collision, and data lookups to match. It also repositions instancer transforms and updates shader uniforms.

You do **not** move the Terrain3D node itself. It always sits at the origin with an identity transform. The shift is handled internally.

### Origin shifting and collision modes

All [collision modes](collision.md) are supported:

- **Dynamic / Game** (default) — Collision shapes are regenerated incrementally around the camera each physics frame. Shifting is handled through the normal update path and costs no more than the camera moving.
- **Dynamic / Editor** — Same as above, with viewable collision nodes.
- **Full / Game** and **Full / Editor** — Collision shapes cover the entire terrain. On origin shift, only transforms are updated (a lightweight operation). Height data is **not** re-read, so shifting is fast even with many regions.
- **Disabled** — No collision processing.

## Setup

_For now, you'll need to compile Terrain3D from this branch's source code._ Once this is integrated into Terrain3D core, no special Godot build or project settings will be required. Origin shifting will work with the standard single-precision Godot editor and export templates.

1. Make sure your Terrain3D node is in the scene.
2. Create a root `Node3D` (e.g. `WorldRoot`) that holds all shiftable game objects — player, enemies, props, etc. Terrain3D should **not** be a child of this node, nor should this root node be a child of Terrain3D. Generally, they will be siblings, although this is not required.
3. In your game script, call `set_world_origin_shift()` on the Terrain3D node whenever you shift the origin.

A typical scene tree:

```
Main
├── Terrain3D          <- stays at origin, receives set_world_origin_shift()
├── WorldRoot          <- moved when the player moves far enough from the global origin
│   ├── Player
│   ├── Enemies
│   └── Other Objects
└── UI
```

## GDScript Usage

The core pattern: when the player moves far from the origin, move all game objects back toward zero and tell Terrain3D about the new cumulative shift. Both `world_root.global_position` and `world_origin_shift` use the same value. This is typically done in the `_physics_process` callback of the player or game controller.

```gdscript
@export var terrain: Terrain3D
@export var world_root: Node3D  # Parent of all shiftable objects

const SHIFT_THRESHOLD: float = 2048.0

func _physics_process(_delta: float) -> void:
    var player_pos: Vector3 = player.global_position
    if player_pos.length() > SHIFT_THRESHOLD:
        # Move the world root so the player ends up near the origin.
        world_root.global_position -= player_pos

        # Tell Terrain3D the same value — both track where the world root sits.
        terrain.set_world_origin_shift(world_root.global_position)
```

## API Reference

### set_world_origin_shift(shift: Vector3)

Sets the cumulative origin shift. Pass the same value as `world_root.global_position`. This re-snaps the clipmap and collision systems, and repositions instancer MMIs. Call this from `_physics_process` — calling from `_process` or elsewhere can cause visual glitches.

```gdscript
terrain.set_world_origin_shift(Vector3(-50000.0, 0.0, -50000.0))
```

### get_world_origin_shift() -> Vector3

Returns the current shift vector. Defaults to `Vector3.ZERO`.

### to_true_world_position(shifted_pos: Vector3) -> Vector3

Converts a shifted-space position to true-world space. Equivalent to `shifted_pos - world_origin_shift`.

```gdscript
var true_pos: Vector3 = terrain.to_true_world_position(player.global_position)
```

### to_shifted_position(true_world_pos: Vector3) -> Vector3

Converts a true-world position to shifted space. Equivalent to `true_world_pos + world_origin_shift`.

```gdscript
var shifted: Vector3 = terrain.to_shifted_position(Vector3(50000.0, 100.0, 50000.0))
```

## Data API

All `Terrain3DData` query and mutation functions accept **shifted-space** positions (i.e. `global_position` from your scene nodes) and internally convert to true-world before looking up terrain data. You do not need to convert positions yourself.

```gdscript
# These all work directly with scene-space positions:
var h: float = terrain.data.get_height(player.global_position)
var n: Vector3 = terrain.data.get_normal(player.global_position)
var c: Color = terrain.data.get_color(player.global_position)
var tex: Vector3 = terrain.data.get_texture_id(player.global_position)
var region_loc: Vector2i = terrain.data.get_region_location(player.global_position)
```

The following functions all auto-convert:

- `get_height()`, `set_height()`
- `get_normal()`
- `get_pixel()`, `set_pixel()`
- `get_color()`, `set_color()`
- `get_control()`, `set_control()`
- `get_roughness()`, `set_roughness()`
- `get_texture_id()`
- `get_mesh_vertex()`
- `is_in_slope()`
- `get_region_location()`, `get_region_idp()`, `get_regionp()`

With zero shift (the default), the two spaces are identical, so existing code works without changes.

### get_intersection()

`Terrain3D.get_intersection()` also works with shifted-space positions. Pass your camera's `global_position` and ray direction directly — the returned hit point will be in shifted space:

```gdscript
var hit: Vector3 = terrain.get_intersection(camera.global_position, ray_dir)
# hit is in shifted space, ready to use in your scene
```

## Instancer

Instancer MultiMeshInstance3D (MMI) transforms are automatically repositioned into shifted space when you call `set_world_origin_shift()`. The underlying instance data (per-tree transforms within each MultiMesh) is not regenerated — only the MMI's origin transform is updated, making the operation lightweight.

No code changes are needed for instanced vegetation, rocks, or other mesh assets placed through the Terrain3D instancer.

## Navigation Mesh

`generate_nav_mesh_source_geometry()` accepts an AABB in shifted space and returns face vertices in shifted space. Internally it converts the AABB to true-world for data lookup, then shifts the output vertices back. No manual conversion is needed:

```gdscript
var nav_faces: PackedVector3Array = terrain.generate_nav_mesh_source_geometry(aabb)
# nav_faces are in shifted space, ready for NavigationMesh baking
```

## Multiplayer

For network consistency, align shifts to fixed increments so all clients agree on the same shift:

```gdscript
# Integer-aligned origin shifts for network consistency
var origin_factor: Vector2i  # synced over network
var world_shift := Vector3(
    -origin_factor.x * 1024.0,
    0.0,
    -origin_factor.y * 1024.0
)
world_root.global_position = world_shift
terrain.set_world_origin_shift(world_shift)

# Convert between local and network positions:
# network_pos = local_pos - world_shift  (true-world)
# local_pos   = network_pos + world_shift  (shifted)
```

## Custom Shaders

If you use a custom `ShaderMaterial` override (e.g. for the ocean), the built-in `_world_origin_shift` uniform is only set on Terrain3D's own materials. To receive the shift in a custom shader:

1. Declare the uniform in your shader:

   ```glsl
   uniform vec3 _world_origin_shift;
   ```

2. Use it to convert vertex positions to true-world for texture sampling:

   ```glsl
   vec3 true_world_pos = VERTEX + _world_origin_shift;
   ```

3. Set it from GDScript when the shift changes. The shader uniform expects a positive true-world offset:
   ```gdscript
   # to_true_world_position(ZERO) gives the positive offset the shader needs
   ocean_material.set_shader_parameter("_world_origin_shift", terrain.to_true_world_position(Vector3.ZERO))
   ```

## Limitations

- **Editor tools** — Painting, sculpting, and other editor operations are not shift-aware. Origin shifting is a runtime feature. Keep `world_origin_shift` at `Vector3.ZERO` while editing.

- **Region labels** — Positioned in true-world coordinates. They will appear far from the camera after shifting. This is editor-only and low priority.

- **Custom spatial data structures** — If your game maintains its own spatial indices (e.g. tree grids, zone lookups) stored in true-world coordinates, you will need to convert positions before querying them. Terrain3D provides `to_true_world_position()` and `to_shifted_position()` for this.

- **Visual verification** — Automated tests verify data stability and collision alignment, but texture continuity, triplanar projection, displacement shimmer, and dual scaling should be verified visually in your specific project.

## Troubleshooting

### Terrain disappears after shifting

Make sure you are **not** moving the Terrain3D node. It must stay at the origin with an identity transform. Only move your game objects (via a shared parent node) and call `set_world_origin_shift()`.

### Heights return NAN after shifting

Verify that `set_world_origin_shift()` is being called with the correct cumulative shift. If the shift is wrong, data lookups will land outside of loaded regions and return NAN.

### Collision is misaligned

Verify that `set_world_origin_shift()` is called **after** moving your game objects. The collision system reads the current target position (camera or collision target) when it rebuilds, so the target should already be in its new shifted-space position.

### Textures slide or pop when shift is applied

This may indicate the shader uniform is not being propagated. Ensure you are using the built-in Terrain3D material, not a fully custom `ShaderMaterial`. The `_world_origin_shift` uniform is set automatically on the terrain and displacement buffer materials. If using a custom shader, see [Custom Shaders](#custom-shaders).

### Jittering at large coordinates

Origin shifting avoids precision issues by keeping the camera near `(0, 0, 0)`. If you still see jitter, your shift threshold may be too large. Try rebasing more frequently (e.g. every 1024-2048 units instead of 10000+).

## Further Reading

- [Double Precision](double_precision.md) — an alternative approach using 64-bit floats
- [Collision](collision.md) — general collision setup and modes
- [Large World Coordinates](https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html) — Godot's documentation on the problem space
