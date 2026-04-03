# JamminTestAssertions - Base class with assertion methods
# All assertions return bool: true = passed, false = failed
# Use with: if not assert_eq(...): return false
class_name JamminTestAssertions extends Object

static func assert_true(condition: bool, message: String = "Assertion failed") -> bool:
	if condition: return true
	push_error("ASSERT FAILED: %s" % message)
	return false

static func assert_false(condition: bool, message: String = "Expected false") -> bool:
	if not condition: return true
	push_error("ASSERT FAILED: %s" % message)
	return false

static func assert_eq(actual: Variant, expected: Variant, message: String = "") -> bool:
	if actual == expected: return true
	var msg: String = message if not message.is_empty() else "Expected '%s' but got '%s'" % [str(expected), str(actual)]
	push_error("ASSERT FAILED: %s" % msg)
	return false

static func assert_ne(actual: Variant, expected: Variant, message: String = "") -> bool:
	if actual != expected: return true
	var msg: String = message if not message.is_empty() else "Expected '%s' to not equal '%s'" % [str(actual), str(expected)]
	push_error("ASSERT FAILED: %s" % msg)
	return false

static func assert_null(value: Variant, message: String = "Expected null") -> bool:
	if value == null: return true
	push_error("ASSERT FAILED: %s" % message)
	return false

static func assert_not_null(value: Variant, message: String = "Expected not null") -> bool:
	if value != null: return true
	push_error("ASSERT FAILED: %s" % message)
	return false

static func assert_contains(haystack: String, needle: String, message: String = "") -> bool:
	if haystack.contains(needle): return true
	var msg: String = message if not message.is_empty() else "String '%s' does not contain '%s'" % [haystack, needle]
	push_error("ASSERT FAILED: %s" % msg)
	return false

static func assert_has(array: Array, value: Variant, message: String = "") -> bool:
	if array.has(value): return true
	var msg: String = message if not message.is_empty() else "Array does not contain '%s'" % str(value)
	push_error("ASSERT FAILED: %s" % msg)
	return false

static func assert_gt(actual: Variant, expected: Variant, message: String = "") -> bool:
	if actual > expected: return true
	var msg: String = message if not message.is_empty() else "Expected '%s' > '%s'" % [str(actual), str(expected)]
	push_error("ASSERT FAILED: %s" % msg)
	return false

static func assert_lt(actual: Variant, expected: Variant, message: String = "") -> bool:
	if actual < expected: return true
	var msg: String = message if not message.is_empty() else "Expected '%s' < '%s'" % [str(actual), str(expected)]
	push_error("ASSERT FAILED: %s" % msg)
	return false

static func fail(message: String = "Test failed") -> bool:
	push_error("ASSERT FAILED: %s" % message)
	return false
