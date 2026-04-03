class_name TestOriginShiftSmall extends TestBase

static func test() -> bool:
	log_info("Testing small positive origin shift (1024, 0, 1024)")

	# Find positions that have valid terrain data
	var test_positions: Array[Vector3] = _find_valid_positions(8)
	if test_positions.is_empty():
		log_warn("No valid terrain positions found in demo data, skipping height checks")
		await apply_shift(Vector3(1024.0, 0.0, 1024.0))
		await wait_frames(30)
		terrain.set_world_origin_shift(Vector3.ZERO)
		return not _failed

	# Sample heights BEFORE shift (true-world positions)
	var heights_before: Array[float] = sample_heights(test_positions)
	log_info("Sampled %d heights before shift" % heights_before.size())

	# Apply shift
	var shift := Vector3(1024.0, 0.0, 1024.0)
	await apply_shift(shift)
	await wait_frames(30)  # Let collision rebuild

	# Heights at the SAME true-world positions must be identical
	if not check_heights_stable(test_positions, heights_before):
		return false
	log_info("All heights stable after shift")

	# Collision check: The collision target (Player) is at its scene-tree position.
	# In a real game, the player would be moved when shifting. For this test, find
	# the actual collision target position and raycast near it in shifted space.
	var col_target_shifted: Vector3 = terrain.get_collision_target_position()
	var col_target_true: Vector3 = terrain.to_true_world_position(col_target_shifted)
	log_info("Collision target: shifted=%s true=%s" % [str(col_target_shifted), str(col_target_true)])

	# Find positions with valid terrain data near the collision target in true-world
	var collision_positions: Array[Vector3] = _find_valid_positions_near(
		col_target_true, 3, 48.0)
	for i: int in range(collision_positions.size()):
		var true_pos: Vector3 = collision_positions[i]
		var shifted_pos: Vector3 = terrain.to_shifted_position(true_pos)
		var expected_h: float = terrain_data.get_height(true_pos)
		if not check_collision_height(
			Vector2(shifted_pos.x, shifted_pos.z),
			expected_h, 1.0,
			"collision pos %d" % i
		): return false
	if collision_positions.size() > 0:
		log_info("Collision heights match data after shift (%d checks)" % collision_positions.size())
	else:
		log_warn("No valid terrain data near collision target after shift, skipping collision checks")

	if _failed: return false
	return true

## Find positions within the terrain that return valid (non-NaN) heights
static func _find_valid_positions(count: int) -> Array[Vector3]:
	var valid: Array[Vector3] = []
	for x: int in range(-512, 513, 64):
		for z: int in range(-512, 513, 64):
			var pos := Vector3(float(x), 0.0, float(z))
			var h: float = terrain_data.get_height(pos)
			if not is_nan(h):
				valid.append(pos)
				if valid.size() >= count:
					return valid
	return valid

## Find positions near a center that have valid terrain data
static func _find_valid_positions_near(center: Vector3, count: int, radius: float) -> Array[Vector3]:
	var valid: Array[Vector3] = []
	var step: float = 8.0
	var r: int = int(radius / step)
	for x: int in range(-r, r + 1):
		for z: int in range(-r, r + 1):
			var pos := Vector3(center.x + x * step, 0.0, center.z + z * step)
			var h: float = terrain_data.get_height(pos)
			if not is_nan(h):
				valid.append(pos)
				if valid.size() >= count:
					return valid
	return valid
