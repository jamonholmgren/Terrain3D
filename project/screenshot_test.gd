extends Node

var terrain: Terrain3D
var frame_count := 0

func _ready():
	await get_tree().process_frame
	terrain = _find_node(get_tree().root, "Terrain3D") as Terrain3D
	if terrain:
		print("TEST: Found Terrain3D")

func _find_node(node: Node, p_name: String) -> Node:
	if node.name == p_name:
		return node
	for child in node.get_children():
		var result = _find_node(child, p_name)
		if result:
			return result
	return null

func _process(_delta):
	if not terrain:
		return
	frame_count += 1
	var mat_rid = terrain.material.get_material_rid()

	if frame_count == 5:
		print("TEST: === Call 1: XZ shift (500, 0, 500) ===")
		terrain.set_world_origin_shift(Vector3(500, 0, 500))
		print("TEST: C++ value = ", terrain.get_world_origin_shift())
	elif frame_count == 7:
		print("TEST: [+2 frames] uniform = ", RenderingServer.material_get_param(mat_rid, "_world_origin_shift"))
		_take_screenshot("/tmp/t3d_call1.png")

	elif frame_count == 10:
		print("TEST: === Call 2: XZ shift (2000, 0, 2000) ===")
		terrain.set_world_origin_shift(Vector3(2000, 0, 2000))
		print("TEST: C++ value = ", terrain.get_world_origin_shift())
	elif frame_count == 12:
		print("TEST: [+2 frames] uniform = ", RenderingServer.material_get_param(mat_rid, "_world_origin_shift"))
		_take_screenshot("/tmp/t3d_call2.png")

	elif frame_count == 15:
		print("TEST: === Call 3: XZ shift (0, 0, 0) reset ===")
		terrain.set_world_origin_shift(Vector3(0, 0, 0))
		print("TEST: C++ value = ", terrain.get_world_origin_shift())
	elif frame_count == 17:
		print("TEST: [+2 frames] uniform = ", RenderingServer.material_get_param(mat_rid, "_world_origin_shift"))
		_take_screenshot("/tmp/t3d_call3.png")

	elif frame_count == 19:
		print("TEST: Done!")
		get_tree().quit(0)

func _take_screenshot(path: String):
	var img = get_viewport().get_texture().get_image()
	if img:
		img.save_png(path)
		print("TEST: Saved ", path)
