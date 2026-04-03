# JamminTestReporter - Static logging methods for test output
# Extends JamminTestAssertions to inherit assertion methods
class_name JamminTestReporter extends JamminTestAssertions

const PREFIX_START: String = "[TEST:START]"
const PREFIX_PASS: String = "[TEST:PASS]"
const PREFIX_FAIL: String = "[TEST:FAIL]"
const PREFIX_PROGRESS: String = "[TEST:PROGRESS]"
const PREFIX_LOG: String = "[TEST:LOG]"
const PREFIX_WARN: String = "[TEST:WARN]"
const PREFIX_ERROR: String = "[TEST:ERROR]"
const PREFIX_SUMMARY: String = "[TEST:SUMMARY]"
const PREFIX_RESULT: String = "[TEST:RESULT]"

# Timing state (static)
static var _test_start_time: float = 0.0
static var _suite_start_time: float = 0.0

# Fail-fast state (static)
static var _failed: bool = false # Fail-fast flag - stops test execution on first failure
static var _failure_message: String = ""

# ------------------------------------------------------------
# Logging Methods
# ------------------------------------------------------------

static func log_header() -> void:
	_suite_start_time = Time.get_unix_time_from_system()
	print("==========================================")
	print("JamminTest E2E Testing Framework for Godot")
	print("==========================================")

static func log_progress(message: String) -> bool:
	if _failed: return false
	print("%s %s" % [PREFIX_PROGRESS, message])
	return true

static func log_info(message: String) -> bool:
	if _failed: return true # Silently exit to allow tests to fall through
	print("%s %s" % [PREFIX_LOG, message])
	return true

static func log_warn(message: String) -> bool:
	print("%s %s" % [PREFIX_WARN, message])
	return true

static func log_error(message: String) -> bool:
	print("%s %s" % [PREFIX_ERROR, message])
	return false

static func log_test_start(test_name: String) -> bool:
	_test_start_time = Time.get_unix_time_from_system()
	print("%s %s" % [PREFIX_START, test_name])
	return true

static func log_test_pass(test_name: String) -> bool:
	var duration: float = Time.get_unix_time_from_system() - _test_start_time
	print("%s %s (%.2fs)" % [PREFIX_PASS, test_name, duration])
	return true

static func log_test_fail(test_name: String, error: String = "") -> bool:
	var duration: float = Time.get_unix_time_from_system() - _test_start_time
	if error.is_empty():
		print("%s %s (%.2fs)" % [PREFIX_FAIL, test_name, duration])
	else:
		print("%s %s - %s (%.2fs)" % [PREFIX_FAIL, test_name, error, duration])
	return false

static func log_summary(passed: int, failed: int) -> bool:
	var total_duration: float = Time.get_unix_time_from_system() - _suite_start_time
	print("----------------------------------------")
	print("%s Passed: %d, Failed: %d (%.2fs total)" % [PREFIX_SUMMARY, passed, failed, total_duration])
	return true

static func log_final_result(success: bool) -> bool:
	print("========================================")
	print("%s %s" % [PREFIX_RESULT, "PASS" if success else "FAIL"])
	print("========================================")
	return true
