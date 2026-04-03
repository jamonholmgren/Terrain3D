class_name TestOriginShiftDynamic extends TestBase

static func test() -> bool:
	log_info("Testing dynamic re-shifting (5 consecutive shifts)")

	var test_positions: Array[Vector3] = _find_valid_positions(4)
	var heights_before: Array[float] = sample_heights(test_positions)

	var shifts: Array[Vector3] = [
		Vector3(512.0, 0.0, 512.0),
		Vector3(2048.0, 0.0, -1024.0),
		Vector3(-1024.0, 0.0, 4096.0),
		Vector3(50000.0, 0.0, 50000.0),
		Vector3.ZERO,  # return to zero
	]

	for shift: Vector3 in shifts:
		await apply_shift(shift, 15)
		if not check_heights_stable(test_positions, heights_before):
			log_error("Heights changed after shift %s" % str(shift))
			return false

	log_info("All %d dynamic shifts passed" % shifts.size())
	if _failed: return false
	return true

static func _find_valid_positions(count: int) -> Array[Vector3]:
	var valid: Array[Vector3] = []
	for x: int in range(-256, 257, 64):
		for z: int in range(-256, 257, 64):
			var pos := Vector3(float(x), 0.0, float(z))
			if not is_nan(terrain_data.get_height(pos)):
				valid.append(pos)
				if valid.size() >= count: return valid
	return valid
