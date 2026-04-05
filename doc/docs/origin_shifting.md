Origin Shifting
=================

When the player and camera move tens of thousands of units away from the world origin in a single precision engine, transforms begin to lose precision. Movement becomes jittery, rendering artifacts appear, and physics can become unreliable.

One way to solve this is by "shifting" or "rebasing" the world origin. Instead of letting the player continue moving farther and farther from `(0, 0, 0)`, the game periodically moves the world around the player so that the player remains near the origin.

This page describes how Terrain3D supports origin shifting at runtime so that terrain rendering, collision, data queries, instanced meshes, and navigation can continue working correctly without requiring a [double precision](double_precision.md) build of Godot.

## Caveats

* Only use origin shifting if you are dealing with large worlds and are seeing noticeable jittering due to floating point precision errors. It adds complexity to your game and is only worth doing if you need it.
* Origin shifting is currently supported only at runtime, not in the editor.
* Origin shifting only works on the XZ plane. Y-axis shifting is ignored.
* With zero shift, the shifted and true-world spaces are identical, so existing code continues to work normally.

## How It Works

Origin shifting introduces two coordinate spaces:

* **Shifted space** - The live game scene after rebasing. The camera, player, mesh instances, and collision shapes all live here, near `(0, 0, 0)`.
* **True-world space** - The stable absolute coordinate system used internally for terrain data storage such as region lookups, height maps, and texture sampling.

The conversion is:

```
true_world = shifted - world_origin_shift
shifted    = true_world + world_origin_shift
```

The `world_origin_shift` value matches `world_root.global_position`. Both are negative relative to the true world origin.

For example, a player may truly be at `(50000, 0, 50000)`. If your game shifts the world so that the player renders at `(0, 0, 0)` in Godot, then `world_root.global_position` would be `(-50000, 0, -50000)`, and `world_origin_shift` would also be `Vector3(-50000, 0, -50000)`.

When you call `set_world_origin_shift(Vector3(-50000, 0, -50000))`, Terrain3D offsets terrain rendering, collision, and data lookups to match. It also repositions instancer transforms and updates shader uniforms.

Do **not** move the Terrain3D node itself. It always remains at the origin with an identity transform. The shift is handled internally.

### Origin shifting and collision modes

All [collision modes](collision.md) are supported:

* **Dynamic / Game** (default) - Collision shapes are regenerated incrementally around the camera each physics frame. Shifting is handled through the normal update path and costs no more than the camera moving.
* **Dynamic / Editor** - Same as above, with viewable collision nodes.
* **Full / Game** and **Full / Editor** - Collision shapes cover the entire terrain. On origin shift, only transforms are updated. Height data is not re-read, so shifting remains fast even with many regions.
* **Disabled** - No collision processing.

## Setup

For now, you will need to compile Terrain3D from this branch's source code. Once this is integrated into Terrain3D core, no special Godot build or project settings should be required.

There are two common ways to set up your scene for origin shifting:

1. **Movable Root Node Method:** Create a root `Node3D` such as `WorldRoot` that contains all shiftable game objects such as the player, enemies, and props. When the player moves far enough from the origin, move this root node in the opposite direction. This is the easiest method, though at very large distances there can still be some jitter on the shifted objects themselves.
2. **Shift All Objects Method:** Move all shiftable objects individually by the same offset. This avoids having one large movable root, but if you forget to move something it will appear to teleport during a shift. It is also somewhat less efficient because every object must be moved individually.

With either method, call `set_world_origin_shift()` on the Terrain3D node whenever you shift the origin.

A typical scene tree:

```
Main
├── Terrain3D   <- stays at origin, call set_world_origin_shift() on it
├── WorldRoot   <- Movable Root
│   ├── Player  <- Shiftable Object
│   ├── Enemy   <- Shiftable Object
│   ├── Enemy   <- Shiftable Object
│   └── Tree    <- Shiftable Object
└── UI          <- Non-shiftable Object
```

If using method 1, move the `WorldRoot` node when shifting.
If using method 2, loop through all shiftable objects and move them individually instead of moving the root.

## GDScript Usage

The basic pattern is to move the world back toward the origin when the player moves too far away, then give Terrain3D the same cumulative shift value. This is typically done in `_physics_process`.

```gdscript
@export var terrain: Terrain3D
@export var world_root: Node3D  # Parent of all shiftable objects

const SHIFT_THRESHOLD: float = 2048.0

func _physics_process(_delta: float) -> void:
    var player_pos: Vector3 = player.global_position
    if player_pos.length() > SHIFT_THRESHOLD:
        # Move the world root so the player ends up near the origin.
        world_root.global_position -= player_pos

        # Tell Terrain3D the same value.
        terrain.set_world_origin_shift(world_root.global_position)
```

## API Reference

### set_world_origin_shift(shift: Vector3)

Sets the cumulative origin shift. In most projects this will be the same value as `world_root.global_position`. This re-snaps the clipmap and collision systems and repositions instancer MMIs.

```gdscript
terrain.set_world_origin_shift(world_root.global_position)
```

Call this from `_physics_process`. Avoid calling it every frame unless you are actually shifting the world.

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

`Terrain3DData` query and mutation functions accept shifted-space positions such as `global_position` from scene nodes and internally convert them to true-world before looking up terrain data. You do not need to convert these positions yourself.

```gdscript
# These all work directly with shifted scene-space positions:
var h: float = terrain.data.get_height(player.global_position)
var n: Vector3 = terrain.data.get_normal(player.global_position)
var c: Color = terrain.data.get_color(player.global_position)
var tex: Vector3 = terrain.data.get_texture_id(player.global_position)
var region_loc: Vector2i = terrain.data.get_region_location(player.global_position)
```

The following functions auto-convert, so they can be used directly with `global_position`:

* `get_height()`, `set_height()`
* `get_normal()`
* `get_pixel()`, `set_pixel()`
* `get_color()`, `set_color()`
* `get_control()`, `set_control()`
* `get_roughness()`, `set_roughness()`
* `get_texture_id()`
* `get_mesh_vertex()`
* `is_in_slope()`
* `get_region_location()`, `get_region_idp()`, `get_regionp()`
* `get_intersection()`

## Instancer

[Terrain3D's Instancer](./instancer.md) MultiMeshInstance3D (MMI) transforms are automatically repositioned into shifted space when you call `set_world_origin_shift()`. The underlying instance data is not regenerated. Only the MMI origin transform is updated, making the operation lightweight.

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

If you use a custom `ShaderMaterial` override such as for the ocean, the built-in `_world_origin_shift` uniform is only set on Terrain3D's own materials. To receive the shift in a custom shader:

1. Declare the uniform in your shader:

   ```glsl
   uniform vec3 _world_origin_shift;
   ```

2. Use it to convert vertex positions to true-world for texture sampling:

   ```glsl
   vec3 true_world_pos = VERTEX + _world_origin_shift;
   ```

3. Set it from GDScript when the shift changes. The shader uniform expects the positive true-world offset, so `to_true_world_position(Vector3.ZERO)` provides the value the shader needs:
   ```gdscript
   # to_true_world_position(ZERO) gives the positive offset the shader needs
   ocean_material.set_shader_parameter("_world_origin_shift", terrain.to_true_world_position(Vector3.ZERO))
   ```

## Limitations

* **Editor tools** - Painting, sculpting, and other editor operations are not shift-aware. Origin shifting is a runtime feature. Keep `world_origin_shift` at `Vector3.ZERO` while editing.
* **Region labels** - Positioned in true-world coordinates. They will appear far from the camera after shifting. This is editor-only and low priority.
* **Custom spatial data structures** - If your game maintains its own spatial indices such as tree grids or zone lookups in true-world coordinates, you will need to convert positions before querying them. Terrain3D provides `to_true_world_position()` and `to_shifted_position()` for this.
* **Visual verification** - Automated tests can verify data stability and collision alignment, but texture continuity, triplanar projection, displacement shimmer, and dual scaling should still be verified visually in your project.

## Troubleshooting

### Terrain disappears after shifting

Make sure you are **not** moving the Terrain3D node. It must remain at the origin with an identity transform. Only move your game objects and call `set_world_origin_shift()`.

### Heights return NAN after shifting

Verify that `set_world_origin_shift()` is being called with the correct cumulative shift. If the shift is wrong, data lookups can land outside of loaded regions and return NAN.

### Collision is misaligned

Verify that `set_world_origin_shift()` is called **after** moving your game objects. The collision system reads the current target position when it rebuilds, so the target should already be in its new shifted-space position.

### Textures slide or pop when shift is applied

This can indicate that the shader uniform is not being propagated. Ensure that you are using the built-in Terrain3D material, not a fully custom `ShaderMaterial`. The `_world_origin_shift` uniform is set automatically on the terrain and displacement buffer materials. If you are using a custom shader, see [Custom Shaders](#custom-shaders).

### Jittering at large coordinates

Origin shifting avoids precision issues by keeping the camera near `(0, 0, 0)`. If you still see jitter, your shift threshold may be too large. Try rebasing more frequently, for example every 1024-2048 units instead of 10000+.

## Further Reading

* [Double Precision](double_precision.md) - An alternative approach using 64-bit floats.
* [Collision](collision.md) - General collision setup and modes.
* [Large World Coordinates](https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html) - Godot's documentation on the problem space.
