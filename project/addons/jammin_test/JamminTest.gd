# JamminTest - Main test class with UI helpers and wait helpers
# Extends JamminTestRunner to inherit runner, reporter, and assertion methods
# Tests should extend this class: class_name MyTest extends JamminTest
class_name JamminTest extends JamminTestRunner

static var is_testing: bool = false
static var allow_input: bool = false

# ------------------------------------------------------------
# UI Interaction Helpers
# ------------------------------------------------------------

static func fill_input(line_edit: LineEdit, value: String) -> void:
	_log("fill_input: '%s' -> \"%s\"" % [_node_path(line_edit), value])
	line_edit.text = value
	line_edit.text_changed.emit(value)

static func click(button: Button) -> void:
	_log("click: '%s' (\"%s\")" % [_node_path(button), button.text.strip_edges()])
	button.pressed.emit()

static func left_click(control: Control) -> void:
	_log("left_click: '%s'" % _node_path(control))
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	control.gui_input.emit(event)

static func select_option(option_button: OptionButton, idx: int) -> void:
	var item_text: String = option_button.get_item_text(idx) if idx < option_button.item_count else "?"
	_log("select_option: '%s' -> index %d (\"%s\")" % [_node_path(option_button), idx, item_text])
	option_button.select(idx)
	option_button.item_selected.emit(idx)

static func toggle(toggle_btn: BaseButton, pressed: bool) -> void:
	_log("toggle: '%s' -> %s" % [_node_path(toggle_btn), pressed])
	toggle_btn.button_pressed = pressed
	toggle_btn.toggled.emit(pressed)

static func set_slider(slider: Slider, value: float) -> void:
	_log("set_slider: '%s' -> %.2f" % [_node_path(slider), value])
	slider.value = value
	slider.value_changed.emit(value)

static func set_spin_box(spin_box: SpinBox, value: float) -> void:
	_log("set_spin_box: '%s' -> %.2f" % [_node_path(spin_box), value])
	spin_box.value = value
	spin_box.value_changed.emit(value)

# ------------------------------------------------------------
# Wait Helpers
# ------------------------------------------------------------

static func wait_for_visible(control: Control, timeout: float = 2.0) -> bool:
	_log("wait_for_visible: '%s'" % _node_path(control))
	return await wait_for_condition(func() -> bool: return control.visible, timeout)

static func wait_for_hidden(control: Control, timeout: float = 2.0) -> bool:
	_log("wait_for_hidden: '%s'" % _node_path(control))
	return await wait_for_condition(func() -> bool: return not control.visible, timeout)

static func wait_for_node(root: Node, node_name_or_path: String, timeout: float = 2.0) -> Node:
	_log("wait_for_node: '%s' in '%s'" % [node_name_or_path, _node_path(root)])
	var node: Node = null
	var found: bool = await wait_for_condition(func() -> bool:
		node = _find_node_by_name_or_path(root, node_name_or_path)
		return node != null
	, timeout)
	return node if found else null

static func wait_for_node_visible(root: Node, node_name_or_path: String, timeout: float = 2.0) -> Node:
	_log("wait_for_node_visible: '%s' in '%s'" % [node_name_or_path, _node_path(root)])
	var node: Node = null
	var found: bool = await wait_for_condition(func() -> bool:
		node = _find_node_by_name_or_path(root, node_name_or_path)
		return node != null and node is Control and (node as Control).visible
	, timeout)
	return node if found else null

static func _find_node_by_name_or_path(root: Node, node_name_or_path: String) -> Node:
	# If it looks like a path (contains /), use get_node_or_null
	if "/" in node_name_or_path:
		return root.get_node_or_null(node_name_or_path)
	# Otherwise search recursively by name
	return root.find_child(node_name_or_path, true, false)

static func wait_for_condition(condition: Callable, timeout: float = 2.0) -> bool:
	var start_time: float = Time.get_unix_time_from_system()
	while not condition.call():
		await JamminTestNode.get_tree().process_frame
		if Time.get_unix_time_from_system() - start_time > timeout:
			_log("wait_for_condition: TIMEOUT (%.1fs)" % timeout)
			return false
	return true

static func wait_frames(n: int) -> void:
	for i: int in range(n):
		await JamminTestNode.get_tree().process_frame

static func wait_for_signal(sig: Signal, timeout: float = 2.0) -> bool:
	_log("wait_for_signal: %s" % sig.get_name())
	var received: bool = false
	var callback: Callable = func() -> void: received = true
	sig.connect(callback, CONNECT_ONE_SHOT)
	var success: bool = await wait_for_condition(func() -> bool: return received, timeout)
	if not success and sig.is_connected(callback):
		sig.disconnect(callback)
	return success

# ------------------------------------------------------------
# Node Finding Helpers
# ------------------------------------------------------------

static func find_node(root: Node, node_name_or_path: String) -> Node:
	var node: Node = _find_node_by_name_or_path(root, node_name_or_path)
	_log("find_node: '%s' -> %s" % [node_name_or_path, "found" if node else "NOT FOUND"])
	return node

# ------------------------------------------------------------
# Logging Helpers
# ------------------------------------------------------------

static func _log(message: String) -> void:
	print("[JamminTest] %s\n%s" % [message, _frame_info()])

static func _frame_info() -> String:
	var mem_mb: int = OS.get_static_memory_usage() / (1024 * 1024)
	return "(%d frames, %d physics, %d fps, %d MB)" % [Engine.get_process_frames(), Engine.get_physics_frames(), Engine.get_frames_per_second(), mem_mb]

static func _node_path(node: Node) -> String:
	if not node: return "<null>"
	if node.name.begins_with("%"): return node.name
	var path: String = str(node.get_path())
	var parts: PackedStringArray = path.split("/")
	if parts.size() > 3: return ".../" + "/".join(parts.slice(-3))
	return path
