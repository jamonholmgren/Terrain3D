@tool
extends EditorPlugin

# Autoload "JamminTestNode" is registered in project.godot directly
# so it's available at runtime (not just in the editor).
# This plugin exists only for editor-time awareness.

func _enter_tree() -> void:
	pass

func _exit_tree() -> void:
	pass
