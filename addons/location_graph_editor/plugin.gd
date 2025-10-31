@tool
extends EditorPlugin

var dock: Control

func _enter_tree() -> void:
	# Add dock with GraphEdit-based editor
	var scene := load("res://addons/location_graph_editor/ui/LocationGraphDock.tscn")
	if scene:
		dock = scene.instantiate()
		if has_method("get_editor_interface"):
			if dock and dock.has_method("set_editor_interface"):
				dock.call("set_editor_interface", get_editor_interface())
		add_control_to_bottom_panel(dock, "Locations")

func _exit_tree() -> void:
	if dock:
		remove_control_from_bottom_panel(dock)
		dock.queue_free()
		dock = null
