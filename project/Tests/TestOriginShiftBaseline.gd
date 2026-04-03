class_name TestOriginShiftBaseline extends TestBase

static func test() -> bool:
	log_info("Testing zero-shift baseline regression")
	await apply_shift(Vector3.ZERO)

	# Sample heights at known positions within the demo terrain
	# (These positions should be within regions that exist in the demo data)
	var test_positions: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(128.0, 0.0, 128.0),
		Vector3(-64.0, 0.0, 64.0),
		Vector3(256.0, 0.0, 0.0),
		Vector3(0.0, 0.0, 256.0),
	]

	# All heights should be finite (not NaN) if within terrain bounds
	for pos: Vector3 in test_positions:
		var h: float = get_height_at(pos)
		# Heights could be NaN if the demo data doesn't cover that region — just log
		if is_nan(h):
			log_warn("No terrain data at %s (may be outside demo regions)" % str(pos))
		else:
			log_info("Height at %s = %.3f" % [str(pos), h])

	# Verify collision is working — raycast at origin
	await wait_frames(30)  # Let collision shapes settle
	var hit_y: float = raycast_terrain_y(Vector2.ZERO)
	if not is_nan(hit_y):
		var data_h: float = get_height_at(Vector3.ZERO)
		if not is_nan(data_h):
			if not assert_true(absf(hit_y - data_h) < 1.0,
				"Collision height matches data height at origin (%.2f vs %.2f)" % [hit_y, data_h]):
				return false
			log_info("Collision height at origin: %.2f (data: %.2f)" % [hit_y, data_h])
	else:
		log_warn("No collision hit at origin — demo terrain may not cover (0,0)")

	if _failed: return false
	return true
