# JamminTestAutoload - Node autoload that handles CLI parsing and test execution
# This is the autoload singleton; tests extend JamminTest (the static class hierarchy)
class_name JamminTestAutoloadNode extends Node

func _ready() -> void:
	# Only load in debug builds; free myself if not in debug build
	if not OS.is_debug_build(): return queue_free()

	# Check if we should run tests from CLI, otherwise unload self
	var test_name: String = _get_cmdline_option("--run-test")
	if test_name.is_empty(): return queue_free()

	JamminTest.is_testing = true
	JamminTest.allow_input = _has_cmdline_flag("--allow-input")

	# Force windowed mode for tests (no fullscreen)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	# Wait for game to be ready, then run tests
	_run_tests_when_ready(test_name)

func _get_cmdline_option(option: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_args()
	for arg: String in args:
		if arg.begins_with(option + "="):
			return arg.substr(option.length() + 1)
	return ""

func _has_cmdline_flag(flag: String) -> bool:
	return flag in OS.get_cmdline_args()

func _run_tests_when_ready(test_name: String) -> void:
	print("[JamminTest] Waiting for scene tree to be ready...")

	# Wait for the scene tree to be fully initialized
	await get_tree().process_frame
	await get_tree().process_frame

	# Give the game time to initialize (30 frames ~0.5s at 60fps)
	print("[JamminTest] Settling...")
	await JamminTest.wait_frames(30)

	print("[JamminTest] Starting test runner...")

	# Run the tests
	var success: bool = await JamminTest.run_test(test_name)

	# Exit with appropriate code
	if success:
		_exit_with_success()
	else:
		_exit_with_failure()

func _exit_with_success() -> void:
	JamminTest.log_final_result(true)
	get_tree().quit(0)

func _exit_with_failure() -> void:
	JamminTest.log_final_result(false)
	get_tree().quit(1)
