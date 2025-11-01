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
	
	# Add menu item to Project → Tools
	add_tool_menu_item("Location Graph Editor", _open_location_graph_editor)


func _exit_tree() -> void:
	# Remove menu item
	remove_tool_menu_item("Location Graph Editor")
	
	if dock:
		remove_control_from_bottom_panel(dock)
		dock.queue_free()
		dock = null


func _open_location_graph_editor() -> void:
	# Make the dock visible when menu item is clicked
	if dock:
		make_bottom_panel_item_visible(dock)
