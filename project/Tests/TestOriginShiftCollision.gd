class_name TestOriginShiftCollision extends TestBase

static func test() -> bool:
	log_info("Testing collision grid integrity with origin shift")

	# First, verify collision works at zero shift
	await apply_shift(Vector3.ZERO)
	await wait_frames(60)  # Extra settle for collision shapes to fully build

	var grid_hits_zero: int = 0
	var grid_errors_zero: int = 0
	var results_zero: Array[int] = _test_collision_grid(Vector3.ZERO)
	grid_hits_zero = results_zero[0]
	grid_errors_zero = results_zero[1]
	log_info("Zero shift: %d hits, %d errors" % [grid_hits_zero, grid_errors_zero])

	# Now apply a shift and retest
	await apply_shift(Vector3(2048.0, 0.0, 2048.0))
	await wait_frames(60)

	var grid_hits_shifted: int = 0
	var grid_errors_shifted: int = 0
	var results_shifted: Array[int] = _test_collision_grid(Vector3(2048.0, 0.0, 2048.0))
	grid_hits_shifted = results_shifted[0]
	grid_errors_shifted = results_shifted[1]
	log_info("Shifted: %d hits, %d errors" % [grid_hits_shifted, grid_errors_shifted])

	if grid_errors_shifted > 0:
		log_error("Collision errors detected after shift")
		return false

	if _failed: return false
	return true

static func _test_collision_grid(shift: Vector3) -> Array[int]:
	var hits: int = 0
	var errors: int = 0
	# Test a grid of points around the collision target
	for x: int in range(-128, 129, 32):
		for z: int in range(-128, 129, 32):
			var true_world := Vector3(float(x), 0.0, float(z))
			var data_h: float = terrain_data.get_height(true_world)
			if is_nan(data_h): continue

			var shifted_pos: Vector3 = true_world - shift
			var hit_y: float = raycast_terrain_y(Vector2(shifted_pos.x, shifted_pos.z))
			if is_nan(hit_y): continue

			hits += 1
			if absf(hit_y - data_h) > 1.0:
				errors += 1
				if errors <= 3:  # Only log first few
					log_error("Collision mismatch at true %s: data=%.2f collision=%.2f" % [
						str(true_world), data_h, hit_y])
	return [hits, errors]
