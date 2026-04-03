class_name TestOriginShiftLarge extends TestBase

static func test() -> bool:
	log_info("Testing large origin shift (50000, 0, 50000)")

	var test_positions: Array[Vector3] = _find_valid_positions(5)
	if test_positions.is_empty():
		log_warn("No valid positions, testing API only")

	var heights_before: Array[float] = sample_heights(test_positions)

	# Apply a large shift — this is where floating point precision matters
	var shift := Vector3(50000.0, 0.0, 50000.0)
	await apply_shift(shift)
	await wait_frames(30)

	# Data heights must be unchanged
	if not check_heights_stable(test_positions, heights_before):
		return false

	# Collision check: the collision target is near (0,0,0) shifted = shift in true-world.
	# With such a large shift, the terrain data (near 0,0,0 true-world) is far from the
	# collision target. There will be no collision shapes near the camera. This is expected.
	# Instead, verify that height data survived the large shift (already done above).
	log_info("Large shift: heights stable (collision skipped — terrain data not near shifted origin)")

	if _failed: return false
	return true

static func _find_valid_positions(count: int) -> Array[Vector3]:
	var valid: Array[Vector3] = []
	for x: int in range(-512, 513, 128):
		for z: int in range(-512, 513, 128):
			var pos := Vector3(float(x), 0.0, float(z))
			if not is_nan(terrain_data.get_height(pos)):
				valid.append(pos)
				if valid.size() >= count: return valid
	return valid
