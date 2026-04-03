class_name TestOriginShiftNegative extends TestBase

static func test() -> bool:
	log_info("Testing negative origin shift (-2048, 0, -3072)")

	var test_positions: Array[Vector3] = _find_valid_positions(5)
	var heights_before: Array[float] = sample_heights(test_positions)

	var shift1 := Vector3(-2048.0, 0.0, -3072.0)
	await apply_shift(shift1)
	await wait_frames(30)

	if not check_heights_stable(test_positions, heights_before):
		return false

	# Also test with non-power-of-two negative shift (stress snap rounding)
	var shift2 := Vector3(-1337.0, 0.0, -4219.0)
	await apply_shift(shift2)
	await wait_frames(30)

	if not check_heights_stable(test_positions, heights_before):
		return false

	# Collision check near the shifted collision target
	# With shift (-1337, 0, -4219), true-world near collision target = (-1337, 0, -4219)
	# This is outside the demo terrain, so collision checks would fail. Use a smaller shift
	# that keeps the collision target inside terrain data coverage.
	var shift3 := Vector3(-128.0, 0.0, -128.0)
	await apply_shift(shift3)
	await wait_frames(60)

	# Positions near (-128, 0, -128) true-world should have data if demo terrain covers it
	var collision_positions: Array[Vector3] = _find_valid_positions_near(shift3, 2, 48.0)
	for i: int in range(collision_positions.size()):
		var true_pos: Vector3 = collision_positions[i]
		var shifted_pos: Vector3 = terrain.to_shifted_position(true_pos)
		var expected_h: float = terrain_data.get_height(true_pos)
		if not check_collision_height(
			Vector2(shifted_pos.x, shifted_pos.z),
			expected_h, 1.0,
			"negative shift pos %d" % i
		): return false

	if collision_positions.size() > 0:
		log_info("Negative shift: collision aligned (%d checks)" % collision_positions.size())
	else:
		log_warn("No terrain data near negative-shifted collision target")

	log_info("Negative shift: heights stable across all shifts")
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
