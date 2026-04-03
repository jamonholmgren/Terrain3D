# JamminTestRunner - Static test discovery and execution
# Extends JamminTestReporter to inherit logging and assertion methods
#
# Test lifecycle:
#   setup()    - Called before test(), use for test isolation
#   test()     - The actual test code
#   teardown() - Called after test(), use for cleanup
class_name JamminTestRunner extends JamminTestReporter

# Registry of available tests
static var _available_tests: Dictionary = {}
static var _tests_discovered: bool = false

# Built-in test name
const JAMMIN_SMOKE_TEST: String = "TestJamminSmoke"

# ------------------------------------------------------------
# Test Discovery
# ------------------------------------------------------------

static func _discover_tests() -> void:
	if _tests_discovered: return
	_tests_discovered = true

	# Add built-in smoke test
	_available_tests[JAMMIN_SMOKE_TEST] = "builtin"

	# Scan Tests/ directory
	var tests_path: String = "res://Tests"
	var dir: DirAccess = DirAccess.open(tests_path)
	if not dir: return push_warning("JamminTestRunner: Tests directory not found at %s" % tests_path)

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if _is_test(file_name):
			var test_name: String = file_name.replace(".gd", "")
			var script_path: String = tests_path + "/" + file_name
			_available_tests[test_name] = script_path
		file_name = dir.get_next()
	dir.list_dir_end()

static func _is_test(file_name: String) -> bool:
	# Match Test*.gd only (exclude .gd.uid and TestBase)
	return file_name.ends_with(".gd") and file_name != "TestBase.gd" and file_name.begins_with("Test")

static func get_available_tests() -> Dictionary:
	_discover_tests()
	return _available_tests

# ------------------------------------------------------------
# Test Execution
# ------------------------------------------------------------

static func run_test(test_name: String) -> bool:
	log_header()

	if test_name == "all":
		return await _run_all_tests()
	elif test_name == "list":
		_list_tests()
		return true
	else:
		return await _run_single_test(test_name)

static func _run_all_tests() -> bool:
	log_info("Running all tests...")
	_discover_tests()

	var all_passed: bool = true
	var passed_count: int = 0
	var failed_count: int = 0

	for name: String in _available_tests.keys():
		var success: bool = await _run_single_test(name)
		if success:
			passed_count += 1
		else:
			failed_count += 1
			all_passed = false

	log_summary(passed_count, failed_count)
	return all_passed

static func _run_single_test(test_name: String) -> bool:
	_discover_tests()

	if not _available_tests.has(test_name):
		log_error("Test not found: %s" % test_name)
		log_info("Available tests: %s" % str(_available_tests.keys()))
		return false

	log_test_start(test_name)

	var success: bool = false

	# Handle built-in vs script tests
	if _available_tests[test_name] == "builtin":
		success = await _run_builtin_test(test_name)
	else:
		success = await _run_script_test(test_name)

	# Report result
	if success:
		log_test_pass(test_name)
	else:
		log_test_fail(test_name)

	return success

static func _run_builtin_test(test_name: String) -> bool:
	match test_name:
		JAMMIN_SMOKE_TEST:
			return await _run_jammin_smoke_test()
		_:
			log_error("Unknown built-in test: %s" % test_name)
			return false

static func _run_jammin_smoke_test() -> bool:
	# Generic smoke test: verify Godot engine basics are working
	log_info("TestJamminSmoke: verifying engine initialization")

	var tree: SceneTree = JamminTestNode.get_tree()
	if not tree:
		log_error("SceneTree not available")
		return false

	if not tree.root:
		log_error("SceneTree.root is null")
		return false

	# Wait a few frames to verify the engine is processing
	for i: int in range(5):
		await tree.process_frame

	log_info("TestJamminSmoke: engine is running")
	return true

static func _run_script_test(test_name: String) -> bool:
	var script_path: String = _available_tests[test_name]
	var script: GDScript = load(script_path)
	if not script:
		log_error("Failed to load test script: %s" % script_path)
		return false

	var success: bool = true

	# Call static setup() if it exists (use get_script_method_list for static methods)
	if _has_static_method(script, "setup"): await script.setup()

	# Call static test() - required
	if _has_static_method(script, "test"):
		success = await script.test()
	else:
		log_error("Test %s does not have a static test() method" % test_name)
		success = false

	# Call static teardown() if it exists
	if _has_static_method(script, "teardown"): await script.teardown()

	return success and not _failed

static func _has_static_method(script: GDScript, method_name: String) -> bool:
	for method: Dictionary in script.get_script_method_list():
		if method.name == method_name and method.flags & METHOD_FLAG_STATIC: return true
	return false

static func _list_tests() -> void:
	_discover_tests()
	log_info("Available tests:")
	for name: String in _available_tests.keys():
		var path: String = _available_tests[name]
		if path == "builtin":
			log_info("  - %s (built-in)" % name)
		else:
			log_info("  - %s" % name)
