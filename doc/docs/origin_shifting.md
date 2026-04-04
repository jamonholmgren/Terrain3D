# Origin Shifting

When the player moves tens of thousands of units from the world origin, single-precision floating point math begins to break down. Positions jitter, rendering artifacts appear, and physics becomes unreliable. One common solution is **origin shifting** (also called origin rebasing): periodically teleporting the entire game world so the player stays near `(0, 0, 0)`.

This page describes an experimental origin shifting approach so that terrain visuals and collision remain correct after a rebase, without requiring a [double precision](double_precision.md) build of Godot.

```{note}
This feature is **highly experimental**. It covers terrain rendering and collision only. Other parts of the Terrain3D API — the instancer, navigation mesh generation, editor tools, region labels, and `get_intersection()` — are **not** shift-aware yet. See [Limitations](#limitations) for details.
```

**Table of Contents**

- [How It Works](#how-it-works)
- [Setup](#setup)
- [GDScript Usage](#gdscript-usage)
- [API Reference](#api-reference)
- [Data API Coordinate Conversion](#data-api-coordinate-conversion)
- [Multiplayer](#multiplayer)
- [Limitations](#limitations)
- [Troubleshooting](#troubleshooting)

## How It Works

Origin shifting introduces two coordinate spaces:

- **Shifted space** — the live game scene after rebasing. The camera, player, mesh instances, and collision shapes all live here, near `(0, 0, 0)`.
- **True-world space** — the stable absolute coordinate system. Terrain data (region lookups, height maps, texture sampling) always uses true-world positions.

The conversion is:

```
true_world = shifted + world_origin_shift
shifted    = true_world - world_origin_shift
```

For example: a player is truly at `(50000, 0, 50000)`. The world in Godot's 3D space has been shifted so the player renders at `(0, 0, 0)` in Godot (the `WorldRoot` node has been moved to `(-50000, 0, -50000)`). The `world_origin_shift` is `Vector3(50000, 0, 50000)` — the positive true-world offset.

When you call `set_world_origin_shift(Vector3(50000, 0, 50000))`, Terrain3D:

1. Stores the shift vector.
2. Re-snaps the clipmap, ocean, and displacement buffer around the current camera position.
3. Updates collision shapes — repositioning them in shifted space without regenerating height data.
4. Passes the shift to all shaders so texture sampling uses true-world UVs while rendering stays in shifted space.

You do **not** move the Terrain3D node itself. It always sits at the origin with an identity transform. The shift is handled internally.

### Performance by collision mode

All [collision modes](collision.md) are supported:

* **Dynamic / Game** (default) — Collision shapes are regenerated incrementally around the camera each physics frame. Shifting is handled through the normal update path and costs no more than the camera moving. **This is the recommended mode for origin shifting.**
* **Dynamic / Editor** — Same as above, with viewable collision nodes.
* **Full / Game** and **Full / Editor** — Collision shapes cover the entire terrain. On origin shift, only transforms are updated (a lightweight operation). Height data is **not** re-read, so shifting is fast even with many regions. However, the initial build at game start is still expensive on large terrains.
* **Disabled** — No collision processing.

## Setup

No special build or project settings are required. Origin shifting works with the standard single-precision Godot editor and export templates.

1. Make sure your Terrain3D node is in the scene.
2. Create a root `Node3D` (e.g. `WorldRoot`) that holds all shiftable game objects — player, enemies, props, etc. Terrain3D should **not** be a child of this node.
3. In your game script, call `set_world_origin_shift()` on the Terrain3D node whenever you shift the origin (e.g. when the player moves far enough from the current shift to trigger another shift).

A typical scene tree might look like:

```
Main
├── Terrain3D          ← stays at origin, receives set_world_origin_shift()
├── WorldRoot          ← moved by -delta when rebasing
│   ├── Player
│   ├── Enemies
│   └── Props
└── UI
```

## GDScript Usage

The core pattern: when the player moves far from the origin, compute a new shift, move all game objects by the negative delta, and tell Terrain3D about the new cumulative shift.

```gdscript
@export var terrain: Terrain3D
@export var world_root: Node3D  # Parent of all shiftable objects

var current_shift: Vector3= Vector3.ZERO
const SHIFT_THRESHOLD: float = 2048.0

func _physics_process(_delta: float) -> void:
    var player_pos: Vector3 = player.global_position
    if player_pos.length() > SHIFT_THRESHOLD:
        _apply_origin_shift(current_shift + player_pos)

func _apply_origin_shift(new_shift: Vector3) -> void:
    var delta: Vector3 = new_shift - current_shift
    current_shift = new_shift

    # Move all game objects in the OPPOSITE direction of the shift.
    # This brings them back near the origin.
    world_root.global_position -= delta

    # Tell Terrain3D about the new cumulative shift.
    terrain.set_world_origin_shift(current_shift)
```

**Why subtract?** The shift says "the true world origin is at this position." Everything in the scene needs to move _toward_ `(0, 0, 0)`, which means subtracting the delta from their positions.

## API Reference

### set_world_origin_shift(shift: Vector3)

Sets the cumulative origin shift. This re-snaps the clipmap and collision systems. Call this after moving your game objects.

```gdscript
terrain.set_world_origin_shift(Vector3(50000.0, 0.0, 50000.0))
```

### get_world_origin_shift() -> Vector3

Returns the current shift vector. Defaults to `Vector3.ZERO`.

### to_true_world_position(shifted_pos: Vector3) -> Vector3

Converts a shifted-space position to true-world space. Equivalent to `shifted_pos + world_origin_shift`.

```gdscript
var true_pos: Vector3 = terrain.to_true_world_position(player.global_position)
```

### to_shifted_position(true_world_pos: Vector3) -> Vector3

Converts a true-world position to shifted space. Equivalent to `true_world_pos - world_origin_shift`.

```gdscript
var shifted: Vector3 = terrain.to_shifted_position(Vector3(50000.0, 100.0, 50000.0))
```

## Data API Coordinate Conversion

Terrain3D's data APIs (`get_height()`, `get_normal()`, `get_color()`, etc.) always expect **true-world** coordinates. They are not affected by the shift. If you have a shifted-space position (e.g. from `global_position`), convert it first:

```gdscript
# WRONG after origin shifting — global_position is in shifted space:
var h: float = terrain.data.get_height(player.global_position)

# CORRECT — convert to true-world first:
var true_pos: Vector3 = terrain.to_true_world_position(player.global_position)
var h: float = terrain.data.get_height(true_pos)
```

This applies to all `Terrain3DData` queries: `get_height()`, `get_normal()`, `get_color()`, `get_control()`, `get_pixel()`, `get_regionp()`, etc.

With zero shift (`Vector3.ZERO`), the two spaces are identical, so existing code works without changes.

## Multiplayer

For network consistency, align shifts to fixed increments so all clients agree on the same shift:

```gdscript
# Integer-aligned origin shifts for network consistency
var origin_factor: Vector2i  # synced over network
var world_shift := Vector3(
    origin_factor.x * 1024.0,
    0.0,
    origin_factor.y * 1024.0
)
terrain.set_world_origin_shift(world_shift)

# Convert between local and network positions:
# network_pos = local_pos + world_shift
# local_pos   = network_pos - world_shift
```

## Limitations

This feature is experimental and intentionally does **not** cover the entire Terrain3D API. The following are not yet shift-aware:

- **get_intersection()** — Takes a source position and ray direction, and raymarches against `get_height()`. After shifting, the source position will be in shifted space, but `get_height()` expects true-world. Callers must convert manually:

```gdscript
var true_pos: Vector3 = terrain.to_true_world_position(camera.global_position)
var hit_true: Vector3 = terrain.get_intersection(true_pos, ray_dir)
var hit_shifted: Vector3 = terrain.to_shifted_position(hit_true)
```

- **Instancer** — MultiMeshInstance3D transforms are positioned at region origins in true-world. They will not render correctly after shifting. If you need instanced objects with origin shifting, manage them outside of Terrain3D's instancer.

- **Navigation mesh generation** — `_generate_triangles()` produces vertices in true-world. If you bake at runtime, convert the AABB to true-world before passing it.

- **Region labels** — Positioned in true-world. They will appear far from the camera after shifting. This is editor-only and low priority.

- **Editor tools** — Painting, sculpting, and other editor operations are not shift-aware. Origin shifting is a runtime feature. Keep `world_origin_shift` at `Vector3.ZERO` while editing.

- **Visual verification** — Automated tests verify data stability and collision alignment, but texture continuity, triplanar projection, displacement shimmer, and dual scaling should be verified visually in your specific project.

## Troubleshooting

### Terrain disappears after shifting

Make sure you are **not** moving the Terrain3D node. It must stay at the origin with an identity transform. Only move your game objects (via a shared parent node) and call `set_world_origin_shift()`.

### Heights return wrong values after shifting

Data APIs expect true-world coordinates. If you're passing `global_position` (shifted space) directly to `get_height()`, convert with `to_true_world_position()` first.

### Collision is misaligned

Verify that `set_world_origin_shift()` is called **after** moving your game objects. The collision system reads the current target position (camera or collision target) when it rebuilds, so the target should already be in its new shifted-space position.

### Textures slide or pop when shift is applied

This may indicate the shader uniform is not being propagated. Ensure you are using the built-in Terrain3D material, not a fully custom `ShaderMaterial`. The `_world_origin_shift` uniform is set automatically on the terrain and displacement buffer materials.

### Jittering at large coordinates

Origin shifting avoids precision issues by keeping the camera near `(0, 0, 0)`. If you still see jitter, your shift threshold may be too large. Try rebasing more frequently (e.g. every 1024–2048 units instead of 10000+).

## Further Reading

- [Double Precision](double_precision.md) — an alternative approach using 64-bit floats
- [Collision](collision.md) — general collision setup and modes
- [Large World Coordinates](https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html) — Godot's documentation on the problem space
