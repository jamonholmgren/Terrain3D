class_name TestOriginShiftAPI extends TestBase

static func test() -> bool:
	log_info("Testing origin shift API correctness")

	# Default shift should be zero
	if not assert_eq(terrain.get_world_origin_shift(), Vector3.ZERO, "Default shift"): return false

	# Set and get
	var shift := Vector3(1000.0, 0.0, 2000.0)
	terrain.set_world_origin_shift(shift)
	if not assert_eq(terrain.get_world_origin_shift(), shift, "Set/get shift"): return false

	# to_true_world_position
	var shifted_pos := Vector3(50.0, 100.0, -30.0)
	var true_pos: Vector3 = terrain.to_true_world_position(shifted_pos)
	if not assert_eq(true_pos, shifted_pos + shift, "to_true_world_position"): return false

	# to_shifted_position (inverse)
	var back: Vector3 = terrain.to_shifted_position(true_pos)
	if not assert_eq(back, shifted_pos, "to_shifted_position roundtrip"): return false

	# Zero shift roundtrip
	terrain.set_world_origin_shift(Vector3.ZERO)
	var identity: Vector3 = terrain.to_true_world_position(shifted_pos)
	if not assert_eq(identity, shifted_pos, "Zero shift is identity"): return false

	if _failed: return false
	return true
