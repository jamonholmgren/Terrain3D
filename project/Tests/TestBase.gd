class_name TestBase extends JamminTest

# Shared terrain references (set during setup)
static var terrain: Terrain3D
static var terrain_data: Terrain3DData

# -----------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------

static func setup() -> void:
	_failed = false
	_failure_message = ""
	terrain = _find_terrain()
	if not terrain:
		fail("No Terrain3D node found in scene tree")
		return
	terrain_data = terrain.get_data()
	# Reset shift to zero before each test
	terrain.set_world_origin_shift(Vector3.ZERO)
	await wait_frames(5)

static func teardown() -> void:
	# Always reset shift after test
	if terrain:
		terrain.set_world_origin_shift(Vector3.ZERO)
	terrain = null
	terrain_data = null

# -----------------------------------------------------------
# Terrain Helpers
# -----------------------------------------------------------

static func _find_terrain() -> Terrain3D:
	var root: Node = JamminTestNode.get_tree().current_scene
	if root is Terrain3D:
		return root as Terrain3D
	return find_terrain_in_tree()

static func find_terrain_in_tree() -> Terrain3D:
	var nodes: Array[Node] = JamminTestNode.get_tree().current_scene.find_children("*", "Terrain3D")
	if nodes.size() > 0:
		return nodes[0] as Terrain3D
	return null

## Get terrain height at a true-world position
static func get_height_at(true_world_pos: Vector3) -> float:
	return terrain_data.get_height(true_world_pos)

## Get terrain height at a shifted-space position (auto-converts)
static func get_height_at_shifted(shifted_pos: Vector3) -> float:
	var true_pos: Vector3 = terrain.to_true_world_position(shifted_pos)
	return terrain_data.get_height(true_pos)

## Apply an origin shift and wait for terrain to re-snap
static func apply_shift(shift: Vector3, settle_frames: int = 10) -> void:
	log_info("Applying origin shift: %s" % str(shift))
	terrain.set_world_origin_shift(shift)
	await wait_frames(settle_frames)

## Sample heights at multiple positions, return as array
static func sample_heights(positions: Array[Vector3]) -> Array[float]:
	var heights: Array[float] = []
	for pos: Vector3 in positions:
		heights.append(terrain_data.get_height(pos))
	return heights

## Assert a height matches expected value within tolerance
static func check_height(true_world_pos: Vector3, expected: float,
		tolerance: float = 0.01, label: String = "") -> bool:
	var actual: float = terrain_data.get_height(true_world_pos)
	if is_nan(actual):
		log_error("Height is NaN at %s%s" % [str(true_world_pos), " (%s)" % label if label else ""])
		_failed = true
		return false
	if absf(actual - expected) > tolerance:
		log_error("Height mismatch at %s: expected %.3f, got %.3f (tol %.3f)%s" % [
			str(true_world_pos), expected, actual, tolerance,
			" (%s)" % label if label else ""])
		_failed = true
		return false
	return true

## Assert heights are identical before and after a shift
static func check_heights_stable(positions: Array[Vector3],
		before: Array[float], tolerance: float = 0.01) -> bool:
	for i: int in range(positions.size()):
		var after: float = terrain_data.get_height(positions[i])
		if is_nan(before[i]) and is_nan(after):
			continue  # Both NaN = both outside terrain, fine
		if is_nan(before[i]) != is_nan(after):
			log_error("Height NaN mismatch at %s: before=%s after=%s" % [
				str(positions[i]), str(before[i]), str(after)])
			_failed = true
			return false
		if absf(before[i] - after) > tolerance:
			log_error("Height changed at %s: before=%.3f after=%.3f" % [
				str(positions[i]), before[i], after])
			_failed = true
			return false
	return true

## Do a physics raycast downward at a shifted-space XZ position, return hit Y
static func raycast_terrain_y(shifted_xz: Vector2, from_y: float = 500.0) -> float:
	var space: PhysicsDirectSpaceState3D = terrain.get_world_3d().direct_space_state
	var from := Vector3(shifted_xz.x, from_y, shifted_xz.y)
	var to := Vector3(shifted_xz.x, -500.0, shifted_xz.y)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var result: Dictionary = space.intersect_ray(query)
	if result.is_empty():
		return NAN
	return result.position.y

## Assert collision raycast matches expected height
static func check_collision_height(shifted_xz: Vector2, expected_height: float,
		tolerance: float = 0.5, label: String = "") -> bool:
	var hit_y: float = raycast_terrain_y(shifted_xz)
	if is_nan(hit_y):
		log_error("Raycast missed terrain at shifted %s%s" % [
			str(shifted_xz), " (%s)" % label if label else ""])
		_failed = true
		return false
	if absf(hit_y - expected_height) > tolerance:
		log_error("Collision height mismatch at shifted %s: expected %.2f, got %.2f%s" % [
			str(shifted_xz), expected_height, hit_y,
			" (%s)" % label if label else ""])
		_failed = true
		return false
	return true
