@tool
extends Control

# Preload core resource types for the location graph.
const LocationGraph = preload("res://addons/location_graph_editor/resources/location_graph.gd")
const LocationNodeData = preload("res://addons/location_graph_editor/resources/location_node.gd")
const LocationEdgeData = preload("res://addons/location_graph_editor/resources/location_edge.gd")

# --- UI Node References ---
@onready var graph_edit: GraphEdit = $GraphEdit
const COLOR_GREEN := Color(0.15, 0.85, 0.3, 1.0)
const COLOR_AMBER := Color(1.0, 0.75, 0.25, 1.0)
const COLOR_RED := Color(0.85, 0.15, 0.15, 1.0)
const COLOR_BLUE := Color(0.15, 0.4, 0.85, 1.0)
const COLOR_PURPLE := Color(0.65, 0.15, 0.85, 1.0)
@onready var new_button: Button = $Toolbar/NewBtn
@onready var open_button: Button = $Toolbar/OpenBtn
@onready var reload_button: Button = $Toolbar/ReloadBtn
@onready var save_button: Button = $Toolbar/SaveBtn
@onready var save_as_button: Button = $Toolbar/SaveAsBtn
@onready var add_node_button: Button = $Toolbar/AddNodeBtn
@onready var delete_button: Button = $Toolbar/DeleteBtn
@onready var set_start_node_button: Button = $Toolbar/SetStartBtn
@onready var dirty_label: Label = $Toolbar/DirtyLabel
@onready var start_node_label: Label = $Toolbar/StartLabel
@onready var file_label: Label = $Toolbar/FileLabel

# --- Editor State ---
var selected_node_ids: Array[String] = []
var node_id_counter: int = 1
var is_graph_dirty: bool = false
var active_graph_resource: LocationGraph = null
var active_graph_path: String = ""
var editor_interface: EditorInterface = null
var _suppress_auto_start_assignment: bool = false

# --- Inspector Integration State ---
var _inspector_reference: Object = null
var _inspector_temp_resource: LocationNodeData = null
var _inspector_active_node: GraphNode = null
var _is_inspector_updating_internally: bool = false
var _is_inspector_apply_scheduled: bool = false

# --- Bidirectional Connection Management ---
# A dictionary to store the bidirectional state of connections.
# The key is a string formatted as "from_node|from_port|to_node|to_port".
var _bidirectional_connections: Dictionary = {}

# --- Locked Connection Management ---
# A dictionary to store the locked state of connections.
# The key is a string formatted as "from_node|from_port|to_node|to_port".
var _locked_connections: Dictionary = {}

# --- Hidden Connection Management ---
# A dictionary to store the hidden state of connections.
# The key is a string formatted as "from_node|from_port|to_node|to_port".
var _hidden_connections: Dictionary = {}

# --- Weight Connection Management ---
# A dictionary to store the weight of connections.
# The key is a string formatted as "from_node|from_port|to_node|to_port".
# Default weight is 1.0 if not present.
var _connection_weights: Dictionary = {}

## Generates a unique string key for an edge to store its bidirectional state.
func _get_edge_key(from_node_id: String, from_port_index: int, to_node_id: String, to_port_index: int) -> String:
	return "%s|%d|%s|%d" % [from_node_id, from_port_index, to_node_id, to_port_index]

## Checks if a given connection is marked as bidirectional.
func _is_connection_bidirectional(from_node_id: String, from_port_index: int, to_node_id: String, to_port_index: int) -> bool:
	var edge_key := _get_edge_key(from_node_id, from_port_index, to_node_id, to_port_index)
	return _bidirectional_connections.has(edge_key) and bool(_bidirectional_connections[edge_key])

## Sets the bidirectional state for a given connection.
func _set_connection_bidirectional(from_node_id: String, from_port_index: int, to_node_id: String, to_port_index: int, is_bidirectional: bool) -> void:
	var edge_key := _get_edge_key(from_node_id, from_port_index, to_node_id, to_port_index)
	if is_bidirectional:
		_bidirectional_connections[edge_key] = true
	else:
		if _bidirectional_connections.has(edge_key):
			_bidirectional_connections.erase(edge_key)

## Checks if a given connection is marked as locked.
func _is_connection_locked(from_node_id: String, from_port_index: int, to_node_id: String, to_port_index: int) -> bool:
	var edge_key := _get_edge_key(from_node_id, from_port_index, to_node_id, to_port_index)
	return _locked_connections.has(edge_key) and bool(_locked_connections[edge_key])

## Sets the locked state for a given connection.
func _set_connection_locked(from_node_id: String, from_port_index: int, to_node_id: String, to_port_index: int, is_locked: bool) -> void:
	var edge_key := _get_edge_key(from_node_id, from_port_index, to_node_id, to_port_index)
	if is_locked:
		_locked_connections[edge_key] = true
	else:
		if _locked_connections.has(edge_key):
			_locked_connections.erase(edge_key)

## Checks if a given connection is marked as hidden.
func _is_connection_hidden(from_node_id: String, from_port_index: int, to_node_id: String, to_port_index: int) -> bool:
	var edge_key := _get_edge_key(from_node_id, from_port_index, to_node_id, to_port_index)
	return _hidden_connections.has(edge_key) and bool(_hidden_connections[edge_key])

## Sets the hidden state for a given connection.
func _set_connection_hidden(from_node_id: String, from_port_index: int, to_node_id: String, to_port_index: int, is_hidden: bool) -> void:
	var edge_key := _get_edge_key(from_node_id, from_port_index, to_node_id, to_port_index)
	if is_hidden:
		_hidden_connections[edge_key] = true
	else:
		if _hidden_connections.has(edge_key):
			_hidden_connections.erase(edge_key)

## Gets the weight for a given connection. Returns 1.0 if not set.
func _get_connection_weight(from_node_id: String, from_port_index: int, to_node_id: String, to_port_index: int) -> float:
	var edge_key := _get_edge_key(from_node_id, from_port_index, to_node_id, to_port_index)
	if _connection_weights.has(edge_key):
		# Snap to 2 decimal places to avoid floating point display issues
		return snappedf(float(_connection_weights[edge_key]), 0.01)
	return 1.0

## Sets the weight for a given connection.
func _set_connection_weight(from_node_id: String, from_port_index: int, to_node_id: String, to_port_index: int, weight: float) -> void:
	var edge_key := _get_edge_key(from_node_id, from_port_index, to_node_id, to_port_index)
	if is_equal_approx(weight, 1.0):
		# Remove from dictionary if weight is default
		if _connection_weights.has(edge_key):
			_connection_weights.erase(edge_key)
	else:
		_connection_weights[edge_key] = weight

## Removes all bidirectional flags for connections associated with a given node ID.
## This is called when a node is deleted.
func _purge_bidirectional_flags_for_node(node_id: String) -> void:
	var keys_to_remove: Array[String] = []
	for connection_key in _bidirectional_connections.keys():
		var parts: Array = String(connection_key).split("|")
		if parts.size() == 4 and (parts[0] == node_id or parts[2] == node_id):
			keys_to_remove.append(String(connection_key))
	for key_to_remove in keys_to_remove:
		_bidirectional_connections.erase(key_to_remove)

## Removes all locked flags for connections associated with a given node ID.
## This is called when a node is deleted.
func _purge_locked_flags_for_node(node_id: String) -> void:
	var keys_to_remove: Array[String] = []
	for connection_key in _locked_connections.keys():
		var parts: Array = String(connection_key).split("|")
		if parts.size() == 4 and (parts[0] == node_id or parts[2] == node_id):
			keys_to_remove.append(String(connection_key))
	for key_to_remove in keys_to_remove:
		_locked_connections.erase(key_to_remove)

## Removes all hidden flags for connections associated with a given node ID.
## This is called when a node is deleted.
func _purge_hidden_flags_for_node(node_id: String) -> void:
	var keys_to_remove: Array[String] = []
	for connection_key in _hidden_connections.keys():
		var parts: Array = String(connection_key).split("|")
		if parts.size() == 4 and (parts[0] == node_id or parts[2] == node_id):
			keys_to_remove.append(String(connection_key))
	for key_to_remove in keys_to_remove:
		_hidden_connections.erase(key_to_remove)

## Removes all weight values for connections associated with a given node ID.
## This is called when a node is deleted.
func _purge_weight_flags_for_node(node_id: String) -> void:
	var keys_to_remove: Array[String] = []
	for connection_key in _connection_weights.keys():
		var parts: Array = String(connection_key).split("|")
		if parts.size() == 4 and (parts[0] == node_id or parts[2] == node_id):
			keys_to_remove.append(String(connection_key))
	for key_to_remove in keys_to_remove:
		_connection_weights.erase(key_to_remove)

## Remaps bidirectional connection keys when a node's ID changes.
func _remap_bidirectional_node_id(old_id: String, new_id: String) -> void:
	if old_id == new_id:
		return
	var remapped_connections: Dictionary = {}
	for connection_key in _bidirectional_connections.keys():
		var parts: PackedStringArray = String(connection_key).split("|")
		if parts.size() == 4:
			var from_node: String = parts[0]
			var from_port: String = parts[1]
			var to_node: String = parts[2]
			var to_port: String = parts[3]
			if from_node == old_id:
				from_node = new_id
			if to_node == old_id:
				to_node = new_id
			var new_key := "%s|%s|%s|%s" % [from_node, from_port, to_node, to_port]
			remapped_connections[new_key] = true
	_bidirectional_connections = remapped_connections

## Remaps locked connection keys when a node's ID changes.
func _remap_locked_node_id(old_id: String, new_id: String) -> void:
	if old_id == new_id:
		return
	var remapped_connections: Dictionary = {}
	for connection_key in _locked_connections.keys():
		var parts: PackedStringArray = String(connection_key).split("|")
		if parts.size() == 4:
			var from_node: String = parts[0]
			var from_port: String = parts[1]
			var to_node: String = parts[2]
			var to_port: String = parts[3]
			if from_node == old_id:
				from_node = new_id
			if to_node == old_id:
				to_node = new_id
			var new_key := "%s|%s|%s|%s" % [from_node, from_port, to_node, to_port]
			remapped_connections[new_key] = true
	_locked_connections = remapped_connections

## Remaps weight connection keys when a node's ID changes.
func _remap_weight_node_id(old_id: String, new_id: String) -> void:
	if old_id == new_id:
		return
	var remapped_weights: Dictionary = {}
	for connection_key in _connection_weights.keys():
		var parts: PackedStringArray = String(connection_key).split("|")
		if parts.size() == 4:
			var from_node: String = parts[0]
			var from_port: String = parts[1]
			var to_node: String = parts[2]
			var to_port: String = parts[3]
			if from_node == old_id:
				from_node = new_id
			if to_node == old_id:
				to_node = new_id
			var new_key := "%s|%s|%s|%s" % [from_node, from_port, to_node, to_port]
			remapped_weights[new_key] = _connection_weights[connection_key]
	_connection_weights = remapped_weights

# --- Port Label Helpers ---

## Retrieves the output port labels from a GraphNode's metadata.
func _get_node_out_port_labels(node: GraphNode) -> Array[String]:
	var labels: Array[String] = []
	if node.has_meta("out_port_labels"):
		for label_text in node.get_meta("out_port_labels"):
			labels.append(String(label_text))
	if labels.is_empty():
		labels = [""] # Ensure there is at least one port.
	return labels

## Sets the output port labels in a GraphNode's metadata and rebuilds its ports.
func _set_node_out_port_labels(node: GraphNode, labels: Array[String]) -> void:
	var string_labels: Array[String] = []
	for label_text in labels:
		string_labels.append(String(label_text))
	if string_labels.is_empty():
		string_labels = [""]
	node.set_meta("out_port_labels", string_labels)
	_rebuild_node_ports(node)

## Retrieves the input port labels from a GraphNode's metadata.
func _get_node_in_port_labels(node: GraphNode) -> Array[String]:
	var labels: Array[String] = []
	if node.has_meta("in_port_labels"):
		for label_text in node.get_meta("in_port_labels"):
			labels.append(String(label_text))
	if labels.is_empty():
		labels = [""] # Ensure there is at least one port.
	return labels

## Sets the input port labels in a GraphNode's metadata and rebuilds its ports.
func _set_node_in_port_labels(node: GraphNode, labels: Array[String]) -> void:
	var string_labels: Array[String] = []
	for label_text in labels:
		string_labels.append(String(label_text))
	if string_labels.is_empty():
		string_labels = [""]
	node.set_meta("in_port_labels", string_labels)
	_rebuild_node_ports(node)

## Synchronizes the port labels of the temporary resource used by the Inspector.
func _sync_inspector_temp_labels_for_node(node: GraphNode) -> void:
	if _inspector_active_node != node or _inspector_temp_resource == null:
		return
	_is_inspector_updating_internally = true
	_inspector_temp_resource.out_port_labels = _get_node_out_port_labels(node)
	_inspector_temp_resource.in_port_labels = _get_node_in_port_labels(node)
	_inspector_temp_resource.emit_changed()
	_is_inspector_updating_internally = false

## Rebuilds the entire port UI for a given GraphNode based on its label metadata.
func _rebuild_node_ports(node: GraphNode) -> void:
	# Get the current labels for both input and output ports.
	var out_labels: Array[String] = _get_node_out_port_labels(node)
	var in_labels: Array[String] = _get_node_in_port_labels(node)

	# Clear all existing port controls from the node.
	var children_to_remove: Array = []
	for child in node.get_children():
		children_to_remove.append(child)
	for child in children_to_remove:
		node.remove_child(child)
		child.queue_free()

	# Normalize label arrays to the same size to create matching rows.
	var max_ports := max(out_labels.size(), in_labels.size())
	while out_labels.size() < max_ports:
		out_labels.append("")
	while in_labels.size() < max_ports:
		in_labels.append("")

	# Rebuild each row of ports and controls.
	for i in range(max_ports):
		var port_index := i
		var row_container := HBoxContainer.new()
		row_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_container.mouse_filter = Control.MOUSE_FILTER_PASS

		# Left side: Input label LineEdit.
		var in_label_edit := LineEdit.new()
		in_label_edit.text = in_labels[port_index]
		in_label_edit.placeholder_text = "In label"
		in_label_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		in_label_edit.mouse_filter = Control.MOUSE_FILTER_STOP
		in_label_edit.text_changed.connect(func(new_text: String):
			var current_in_labels := _get_node_in_port_labels(node)
			if port_index >= 0 and port_index < current_in_labels.size():
				current_in_labels[port_index] = new_text
				node.set_meta("in_port_labels", current_in_labels)
				_mark_graph_as_dirty()
				_sync_inspector_temp_labels_for_node(node)
		)
		row_container.add_child(in_label_edit)

		

		# Remove Port button (only on the last row if there's more than one).
		if port_index == max_ports - 1 and max_ports > 1:
			var remove_button := Button.new()
			remove_button.text = "-"
			remove_button.tooltip_text = "Remove last port"
			remove_button.focus_mode = Control.FOCUS_NONE
			remove_button.pressed.connect(func():
				var current_out_labels := _get_node_out_port_labels(node)
				var current_in_labels := _get_node_in_port_labels(node)
				var port_count := max(current_out_labels.size(), current_in_labels.size())
				if port_count > 1:
					# Normalize arrays before removing to prevent mismatches.
					while current_out_labels.size() > port_count: current_out_labels.remove_at(current_out_labels.size() - 1)
					while current_in_labels.size() > port_count: current_in_labels.remove_at(current_in_labels.size() - 1)
					if current_out_labels.size() > current_in_labels.size():
						while current_out_labels.size() > current_in_labels.size(): current_out_labels.remove_at(current_out_labels.size() - 1)
					elif current_in_labels.size() > current_out_labels.size():
						while current_in_labels.size() > current_out_labels.size(): current_in_labels.remove_at(current_in_labels.size() - 1)
					
					# Remove the last port from both sides if possible.
					if current_out_labels.size() > 1: current_out_labels.remove_at(current_out_labels.size() - 1)
					if current_in_labels.size() > 1: current_in_labels.remove_at(current_in_labels.size() - 1)
					
					node.set_meta("out_port_labels", current_out_labels)
					node.set_meta("in_port_labels", current_in_labels)
					_sanitize_connections_for_node(node)
					_rebuild_node_ports(node)
					_mark_graph_as_dirty()
					_sync_inspector_temp_labels_for_node(node)
			)
			row_container.add_child(remove_button)

		# Add Port button (only on the last row).
		if port_index == max_ports - 1:
			var add_button := Button.new()
			add_button.text = "+"
			add_button.tooltip_text = "Add port"
			add_button.focus_mode = Control.FOCUS_NONE
			add_button.pressed.connect(func():
				var current_out_labels := _get_node_out_port_labels(node)
				var current_in_labels := _get_node_in_port_labels(node)
				current_out_labels.append("")
				current_in_labels.append("")
				node.set_meta("out_port_labels", current_out_labels)
				node.set_meta("in_port_labels", current_in_labels)
				_rebuild_node_ports(node)
				_mark_graph_as_dirty()
				_sync_inspector_temp_labels_for_node(node)
			)
			row_container.add_child(add_button)
			
		# Right side: Output label LineEdit.
		var out_label_edit := LineEdit.new()
		out_label_edit.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
		out_label_edit.text = out_labels[port_index]
		out_label_edit.placeholder_text = "Out label"
		out_label_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		out_label_edit.mouse_filter = Control.MOUSE_FILTER_STOP
		out_label_edit.text_changed.connect(func(new_text: String):
			var current_out_labels := _get_node_out_port_labels(node)
			if port_index >= 0 and port_index < current_out_labels.size():
				current_out_labels[port_index] = new_text
				node.set_meta("out_port_labels", current_out_labels)
				_mark_graph_as_dirty()
				_sync_inspector_temp_labels_for_node(node)
		)
		row_container.add_child(out_label_edit)

		# Bidirectional toggle button.
		var bidirectional_button := Button.new()
		bidirectional_button.text = "↔"
		bidirectional_button.tooltip_text = "Toggle bidirectional on connections from this port"
		bidirectional_button.focus_mode = Control.FOCUS_NONE
		bidirectional_button.mouse_filter = Control.MOUSE_FILTER_STOP
		bidirectional_button.pressed.connect(func():
			# Toggle bidirectional state for all connections from this node and port
			var node_id := String(node.name)
			for connection in graph_edit.get_connection_list():
				if connection.from_node == node_id and int(connection.from_port) == port_index:
					var current_state := _is_connection_bidirectional(String(connection.from_node), int(connection.from_port), String(connection.to_node), int(connection.to_port))
					_set_connection_bidirectional(String(connection.from_node), int(connection.from_port), String(connection.to_node), int(connection.to_port), not current_state)
			_mark_graph_as_dirty()
			_refresh_all_connection_activity()
		)
		row_container.add_child(bidirectional_button)
		
		node.add_child(row_container)
		
		# Enable the input and output slots for this row, defaulting to amber.
		node.set_slot(port_index, true, 0, COLOR_AMBER, true, 0, COLOR_AMBER)

	# After building all rows, refresh port colors to reflect any bidirectional links.
	_refresh_port_colors_for_node(node)



## Opens a dialog to manage bidirectional flags for all connections from a specific out-port.
func _open_bidirectional_connections_dialog(node: GraphNode, out_port_index: int) -> void:
	var node_id := String(node.name)
	var connections_from_port: Array = []
	for connection in graph_edit.get_connection_list():
		if connection.from_node == node_id and int(connection.from_port) == out_port_index:
			connections_from_port.append(connection)

	if connections_from_port.is_empty():
		var info_dialog := AcceptDialog.new()
		info_dialog.title = "No connections on this port"
		info_dialog.dialog_text = "There are no outgoing connections from this port."
		add_child(info_dialog)
		info_dialog.popup_centered()
		return

	var dialog := AcceptDialog.new()
	dialog.title = "Bidirectional connections"
	dialog.min_size = Vector2(360, 0)
	var vbox_container := VBoxContainer.new()
	var ui_rows: Array = []

	for connection in connections_from_port:
		var row_container := HBoxContainer.new()
		var to_node_title: String = String(connection.to_node)
		if graph_edit.has_node(String(connection.to_node)):
			var to_graph_node := graph_edit.get_node(String(connection.to_node))
			if to_graph_node is GraphNode:
				to_node_title = to_graph_node.get_meta("title") if to_graph_node.has_meta("title") else to_graph_node.title
		
		var label := Label.new()
		label.text = "→ %s (port %d)" % [to_node_title, int(connection.to_port)]
		row_container.add_child(label)
		
		var checkbox := CheckBox.new()
		checkbox.focus_mode = Control.FOCUS_NONE
		checkbox.button_pressed = _is_connection_bidirectional(String(connection.from_node), int(connection.from_port), String(connection.to_node), int(connection.to_port))
		row_container.add_child(checkbox)
		
		vbox_container.add_child(row_container)
		ui_rows.append({
			"connection": connection,
			"checkbox": checkbox
		})

	dialog.add_child(vbox_container)
	if dialog.get_ok_button():
		dialog.get_ok_button().text = "Save"

	dialog.confirmed.connect(func():
		for row_data in ui_rows:
			var connection_data = row_data["connection"]
			var ui_checkbox: CheckBox = row_data["checkbox"]
			_set_connection_bidirectional(String(connection_data.from_node), int(connection_data.from_port), String(connection_data.to_node), int(connection_data.to_port), ui_checkbox.button_pressed)
		_mark_graph_as_dirty()
		_refresh_all_connection_activity()
	)
	add_child(dialog)
	dialog.popup_centered()

## Removes connections from a node if its port count is reduced.
func _sanitize_connections_for_node(node: GraphNode) -> void:
	var labels := _get_node_out_port_labels(node)
	var valid_port_count := labels.size()
	var node_id := String(node.name)
	
	for connection in graph_edit.get_connection_list():
		var should_remove := false
		if connection.from_node == node_id and int(connection.from_port) >= valid_port_count:
			should_remove = true
		elif connection.to_node == node_id and int(connection.to_port) >= valid_port_count:
			should_remove = true
		
		if should_remove:
			_set_connection_bidirectional(String(connection.from_node), int(connection.from_port), String(connection.to_node), int(connection.to_port), false)
			_set_connection_locked(String(connection.from_node), int(connection.from_port), String(connection.to_node), int(connection.to_port), false)
			graph_edit.disconnect_node(connection.from_node, connection.from_port, connection.to_node, connection.to_port)

# --- Godot Lifecycle & UI Wiring ---

func _ready() -> void:
	if Engine.is_editor_hint():
		_wire_ui_signals()
		graph_edit.minimap_enabled = true
		graph_edit.right_disconnects = true
		
		# Connect core GraphEdit signals to their handlers.
		graph_edit.connection_request.connect(_on_connection_request)
		graph_edit.disconnection_request.connect(_on_disconnection_request)
		graph_edit.node_selected.connect(_on_graph_node_selected)
		graph_edit.node_deselected.connect(_on_graph_node_deselected)
		graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)
		# Listen for background GUI input so we can show a context menu on right-click
		graph_edit.gui_input.connect(Callable(self, "_on_graph_gui_input"))
		
		# Configure connection line appearance using theme overrides.
		# Locked connections will use activity system, bidirectional are green, one-way are amber.
		graph_edit.add_theme_color_override("connection_lines", COLOR_AMBER)
		graph_edit.add_theme_color_override("activity", COLOR_GREEN)
		graph_edit.connection_lines_thickness = 3.0
		
	# Double-click to add nodes is intentionally disabled for a cleaner UX.
	# graph_edit.gui_input.connect(_on_graph_gui_input)

## Refreshes the "activity" (color) of all connections on the graph.
func _refresh_all_connection_activity() -> void:
	if graph_edit == null:
		return
	
	for connection in graph_edit.get_connection_list():
		var from_node_id := String(connection.from_node)
		var from_port := int(connection.from_port)
		var to_node_id := String(connection.to_node)
		var to_port := int(connection.to_port)
		
		var is_locked := _is_connection_locked(from_node_id, from_port, to_node_id, to_port)
		var is_hidden := _is_connection_hidden(from_node_id, from_port, to_node_id, to_port)
		var is_bidirectional := _is_connection_bidirectional(from_node_id, from_port, to_node_id, to_port)
		
		# Determine the appropriate color based on connection state
		var connection_color := COLOR_AMBER
		
		if is_locked and is_hidden:
			# Both locked and hidden = purple
			connection_color = COLOR_PURPLE
		elif is_locked:
			# Only locked = red
			connection_color = COLOR_RED
		elif is_hidden:
			# Only hidden = blue
			connection_color = COLOR_BLUE
		elif is_bidirectional:
			# Bidirectional = green
			connection_color = COLOR_GREEN
		# else: default amber color for one-way connections
		
		# Set the connection line color using set_connection_line_color
		# This is the proper way to set individual connection colors in Godot 4
		if graph_edit.has_method("set_connection_line_color"):
			graph_edit.set_connection_line_color(StringName(connection.from_node), from_port, StringName(connection.to_node), to_port, connection_color)
		else:
			# Fallback: use activity for bidirectional (green) vs non-bidirectional
			if is_bidirectional and not is_locked and not is_hidden:
				graph_edit.set_connection_activity(StringName(connection.from_node), from_port, StringName(connection.to_node), to_port, 1.0)
			else:
				graph_edit.set_connection_activity(StringName(connection.from_node), from_port, StringName(connection.to_node), to_port, 0.0)
	
	# Also refresh the port dots to keep them consistent with the line colors.
	_refresh_all_port_colors()

## Iterates through all nodes and refreshes their port colors.
func _refresh_all_port_colors() -> void:
	for node in graph_edit.get_children():
		if node is GraphNode:
			_refresh_port_colors_for_node(node)

## Sets the color for each port on a node based on its connections.
func _refresh_port_colors_for_node(node: GraphNode) -> void:
	# Determine the color for each port based on connection state
	# Priority: purple (locked+hidden) > red (locked) > blue (hidden) > green (bidirectional) > amber (default)
	var out_labels := _get_node_out_port_labels(node)
	var in_labels := _get_node_in_port_labels(node)
	var port_count := max(out_labels.size(), in_labels.size())
	
	for i in range(port_count):
		var in_color := COLOR_AMBER
		var out_color := COLOR_AMBER
		
		# Check incoming connections for this port.
		for connection in graph_edit.get_connection_list():
			if String(connection.to_node) == String(node.name) and int(connection.to_port) == i:
				var is_locked := _is_connection_locked(String(connection.from_node), int(connection.from_port), String(connection.to_node), int(connection.to_port))
				var is_hidden := _is_connection_hidden(String(connection.from_node), int(connection.from_port), String(connection.to_node), int(connection.to_port))
				var is_bidirectional := _is_connection_bidirectional(String(connection.from_node), int(connection.from_port), String(connection.to_node), int(connection.to_port))
				
				if is_locked and is_hidden:
					in_color = COLOR_PURPLE
					break
				elif is_locked:
					in_color = COLOR_RED
					break
				elif is_hidden:
					in_color = COLOR_BLUE
					break
				elif is_bidirectional:
					in_color = COLOR_GREEN
					
		# Check outgoing connections for this port.
		for connection in graph_edit.get_connection_list():
			if String(connection.from_node) == String(node.name) and int(connection.from_port) == i:
				var is_locked := _is_connection_locked(String(connection.from_node), int(connection.from_port), String(connection.to_node), int(connection.to_port))
				var is_hidden := _is_connection_hidden(String(connection.from_node), int(connection.from_port), String(connection.to_node), int(connection.to_port))
				var is_bidirectional := _is_connection_bidirectional(String(connection.from_node), int(connection.from_port), String(connection.to_node), int(connection.to_port))
				
				if is_locked and is_hidden:
					out_color = COLOR_PURPLE
					break
				elif is_locked:
					out_color = COLOR_RED
					break
				elif is_hidden:
					out_color = COLOR_BLUE
					break
				elif is_bidirectional:
					out_color = COLOR_GREEN
					
		node.set_slot(i, true, 0, in_color, true, 0, out_color)

## Connects all toolbar button signals to their respective functions.
func _wire_ui_signals() -> void:
	new_button.pressed.connect(_on_new_graph_pressed)
	open_button.pressed.connect(_on_open_graph_pressed)
	reload_button.pressed.connect(_on_reload_graph_pressed)
	save_button.pressed.connect(_on_save_graph_pressed)
	save_as_button.pressed.connect(_on_save_as_graph_pressed)
	add_node_button.pressed.connect(_add_node_at_center)
	delete_button.pressed.connect(_on_delete_selection_pressed)
	set_start_node_button.pressed.connect(_on_set_start_node_pressed)
	_update_start_node_label()
	_update_file_label()
	_update_dirty_label()
	_refresh_all_node_rows()
	_refresh_all_connection_activity()

## Rebuilds the UI for all nodes currently in the graph.
func _refresh_all_node_rows() -> void:
	for child_node in graph_edit.get_children():
		if child_node is GraphNode:
			_rebuild_node_ports(child_node)

# --- Inspector Integration ---

## Sets the editor interface reference to allow Inspector manipulation.
func set_editor_interface(interface: EditorInterface) -> void:
	editor_interface = interface
	_disconnect_from_inspector()

## Disconnects signals from the Inspector to prevent memory leaks.
func _disconnect_from_inspector() -> void:
	if is_instance_valid(_inspector_reference) and _inspector_reference.has_signal("property_edited"):
		var callable := Callable(self, "_on_inspector_property_edited")
		if _inspector_reference.is_connected("property_edited", callable):
			_inspector_reference.disconnect("property_edited", callable)
	if is_instance_valid(_inspector_temp_resource):
		var callable := Callable(self, "_on_temp_resource_changed")
		if _inspector_temp_resource.is_connected("changed", callable):
			_inspector_temp_resource.disconnect("changed", callable)
	_inspector_reference = null
	_inspector_temp_resource = null
	_inspector_active_node = null
	_is_inspector_apply_scheduled = false

## Schedules an update from the Inspector to be applied on the next idle frame.
func _queue_apply_inspector_changes() -> void:
	if _is_inspector_apply_scheduled:
		return
	_is_inspector_apply_scheduled = true
	call_deferred("_apply_inspector_changes_now")

## Applies the pending changes from the Inspector to the actual GraphNode.
func _apply_inspector_changes_now() -> void:
	_is_inspector_apply_scheduled = false
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_inspector_temp_resource) and is_instance_valid(_inspector_active_node):
		_apply_inspector_changes_to_node(_inspector_temp_resource, _inspector_active_node)

## Callback for when a property is edited in the Inspector.
func _on_inspector_property_edited(_property_name: String) -> void:
	_queue_apply_inspector_changes()

## Callback for when the temporary resource itself emits a 'changed' signal.
func _on_temp_resource_changed() -> void:
	if _is_inspector_updating_internally:
		return
	_queue_apply_inspector_changes()

## Pushes the selected node's data to the Inspector for editing.
func _push_selection_to_inspector() -> void:
	if editor_interface == null:
		return
	var inspector := editor_interface.get_inspector()
	if inspector == null:
		return
	
	# The inspector only works with a single selected node.
	if selected_node_ids.size() != 1:
		inspector.edit(null)
		_disconnect_from_inspector()
		return
		
	var node_id := selected_node_ids[0]
	var node := graph_edit.get_node_or_null(node_id)
	if node is GraphNode:
		_disconnect_from_inspector()
		
		# Create a temporary resource to back the Inspector.
		var temp_resource := LocationNodeData.new()
		temp_resource.id = node.get_meta("id")
		temp_resource.title = node.get_meta("title") if node.has_meta("title") else node.title
		temp_resource.position = node.position_offset
		temp_resource.size = node.custom_minimum_size
		var meta_tags: Array = node.get_meta("tags") if node.has_meta("tags") else []
		var tag_list: Array[String] = []
		for tag in meta_tags:
			tag_list.append(String(tag))
		temp_resource.tags = tag_list
		temp_resource.out_port_labels = _get_node_out_port_labels(node)
		temp_resource.in_port_labels = _get_node_in_port_labels(node)
		
		inspector.edit(temp_resource)
		
		# Store references and connect signals.
		_inspector_reference = inspector
		_inspector_temp_resource = temp_resource
		_inspector_active_node = node
		if inspector.has_signal("property_edited"):
			inspector.connect("property_edited", Callable(self, "_on_inspector_property_edited"))
		temp_resource.connect("changed", Callable(self, "_on_temp_resource_changed"))

## Applies property changes from the temporary Inspector resource to the actual GraphNode.
func _apply_inspector_changes_to_node(temp_resource: LocationNodeData, node: GraphNode) -> void:
	node.title = temp_resource.title
	node.set_meta("title", temp_resource.title)
	node.set_meta("tags", temp_resource.tags)
	if node.position_offset != temp_resource.position:
		node.position_offset = temp_resource.position
	
	_set_node_out_port_labels(node, temp_resource.out_port_labels)
	_set_node_in_port_labels(node, temp_resource.in_port_labels)
	
	if node.custom_minimum_size != temp_resource.size and temp_resource.size != Vector2.ZERO:
		node.custom_minimum_size = temp_resource.size
		
	# Handle node ID changes, which requires remapping connections.
	var old_id: String = String(node.get_meta("id"))
	var new_id: String = String(temp_resource.id)
	var was_start_node := active_graph_resource and String(active_graph_resource.start_node_id) == old_id
	if new_id != old_id and new_id != "" and not graph_edit.has_node(new_id):
		var connections := graph_edit.get_connection_list()
		for connection in connections:
			if connection.from_node == old_id:
				graph_edit.disconnect_node(connection.from_node, connection.from_port, connection.to_node, connection.to_port)
				graph_edit.connect_node(new_id, connection.from_port, connection.to_node, connection.to_port)
			elif connection.to_node == old_id:
				graph_edit.disconnect_node(connection.from_node, connection.from_port, connection.to_node, connection.to_port)
				graph_edit.connect_node(connection.from_node, connection.from_port, new_id, connection.to_port)
		_remap_bidirectional_node_id(old_id, new_id)
		_remap_locked_node_id(old_id, new_id)
		node.name = new_id
		node.set_meta("id", StringName(new_id))
		selected_node_ids.clear()
		selected_node_ids.append(new_id)
		# If this node was the start node, update the resource to use the new ID
		if was_start_node:
			active_graph_resource.start_node_id = StringName(new_id)
		
	_update_start_node_label()
	_mark_graph_as_dirty()

# --- Graph Operations ---

## Clears the entire graph canvas and resets state.
func _clear_graph_canvas() -> void:
	graph_edit.clear_connections()
	var nodes_to_remove: Array = []
	for child in graph_edit.get_children():
		if child is GraphNode:
			nodes_to_remove.append(child)
	for node in nodes_to_remove:
		graph_edit.remove_child(node)
		node.free()
	
	node_id_counter = 1
	_bidirectional_connections.clear()
	_locked_connections.clear()
	_hidden_connections.clear()
	_connection_weights.clear()
	selected_node_ids.clear()
	is_graph_dirty = false
	_update_dirty_label()

## Handles the "New" button press.
func _on_new_graph_pressed() -> void:
	_clear_graph_canvas()
	active_graph_resource = LocationGraph.new()
	active_graph_path = ""
	_update_start_node_label()
	_update_file_label()
	_update_dirty_label()

## Handles the "Open" button press, showing a file dialog.
func _on_open_graph_pressed() -> void:
	var file_dialog := EditorFileDialog.new()
	add_child(file_dialog)
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	file_dialog.add_filter("*.tres ; LocationGraph")
	file_dialog.title = "Open Location Graph"
	file_dialog.file_selected.connect(func(path): _load_graph_from_path(path))
	file_dialog.popup_centered_ratio(0.6)

## Builds a LocationGraph resource from the current state of the GraphEdit.
func _build_resource_from_graph() -> LocationGraph:
	var resource := LocationGraph.new()
	
	# Serialize nodes.
	for node in graph_edit.get_children():
		if node is GraphNode:
			var node_data := LocationNodeData.new()
			node_data.id = node.get_meta("id")
			node_data.title = node.get_meta("title") if node.has_meta("title") else node.title
			node_data.position = node.position_offset - graph_edit.scroll_offset
			node_data.size = node.custom_minimum_size
			
			var meta_tags: Array = node.get_meta("tags") if node.has_meta("tags") else []
			var tag_list: Array[String] = []
			for tag in meta_tags:
				tag_list.append(String(tag))
			node_data.tags = tag_list
			
			var out_labels: Array[String] = []
			if node.has_meta("out_port_labels"):
				for label in node.get_meta("out_port_labels"):
					out_labels.append(String(label))
			if out_labels.is_empty(): out_labels = [""]
			node_data.out_port_labels = out_labels
			
			var in_labels: Array[String] = []
			if node.has_meta("in_port_labels"):
				for label in node.get_meta("in_port_labels"):
					in_labels.append(String(label))
			if in_labels.is_empty(): in_labels = [""]
			node_data.in_port_labels = in_labels
			
			resource.nodes.append(node_data)
			
	# Set start node ID.
	if active_graph_resource and String(active_graph_resource.start_node_id) != "" and graph_edit.has_node(String(active_graph_resource.start_node_id)):
		resource.start_node_id = active_graph_resource.start_node_id
	elif resource.nodes.size() > 0:
		resource.start_node_id = resource.nodes[0].id
		
	# Serialize edges.
	for connection in graph_edit.get_connection_list():
		var edge_data := LocationEdgeData.new()
		edge_data.from_id = StringName(connection.from_node)
		edge_data.to_id = StringName(connection.to_node)
		edge_data.from_port = int(connection.from_port)
		edge_data.to_port = int(connection.to_port)
		edge_data.bidirectional = _is_connection_bidirectional(String(connection.from_node), int(connection.from_port), String(connection.to_node), int(connection.to_port))
		edge_data.locked = _is_connection_locked(String(connection.from_node), int(connection.from_port), String(connection.to_node), int(connection.to_port))
		edge_data.hidden = _is_connection_hidden(String(connection.from_node), int(connection.from_port), String(connection.to_node), int(connection.to_port))
		edge_data.weight = _get_connection_weight(String(connection.from_node), int(connection.from_port), String(connection.to_node), int(connection.to_port))
		resource.edges.append(edge_data)
		
	return resource

## Adds a new GraphNode to the center of the current view.
func _add_node_at_center() -> void:
	var position: Vector2 = graph_edit.scroll_offset + graph_edit.size * 0.5
	_create_graph_node(position)

## Creates and configures a new GraphNode instance.
func _create_graph_node(position: Vector2, id: StringName = StringName(), title: String = "") -> void:
	var node := GraphNode.new()
	node.title = title if title != "" else "Location %d" % node_id_counter
	node.draggable = true
	node.resizable = true
	node.custom_minimum_size = Vector2(260, 150)
	node.position_offset = graph_edit.scroll_offset + position

	var node_id := id if String(id) != "" else StringName("loc_%d" % node_id_counter)
	node_id_counter += 1
	node.name = String(node_id)

	# Set default metadata.
	node.set_meta("id", node_id)
	node.set_meta("title", node.title)
	node.set_meta("tags", [])
	node.set_meta("out_port_labels", [""]) # Default to one out port.
	node.set_meta("in_port_labels", [""])  # Default to one in port.

	graph_edit.add_child(node)
	_rebuild_node_ports(node)

	# Always set as start node if this is the first node, unless suppressed (e.g., when loading a resource)
	if not _suppress_auto_start_assignment:
		if active_graph_resource and graph_edit.get_children().filter(func(n): return n is GraphNode).size() == 1:
			active_graph_resource.start_node_id = StringName(node.name)
	_update_start_node_label()

	# Connect signals for tracking changes.
	if node.has_signal("position_offset_changed"):
		node.connect("position_offset_changed", Callable(self, "_mark_graph_as_dirty"))
	elif node.has_signal("offset_changed"): # Fallback for older Godot versions
		node.connect("offset_changed", Callable(self, "_mark_graph_as_dirty"))

	# Mark dirty on resize and persist the new size.
	if node.has_signal("resize_request"):
		node.connect("resize_request", func(new_size: Vector2):
			node.custom_minimum_size = new_size
			_mark_graph_as_dirty()
		)

	# Right-click context menu for renaming and editing properties.
	node.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				# Show context menu for node title
				var menu := PopupMenu.new()
				menu.add_item("Edit Properties", 0)
				menu.connect("id_pressed", func(id):
					if id == 0:
						_open_node_properties_dialog(node)
				)
				add_child(menu)
				var global_pos: Vector2 = event.global_position
				menu.popup(Rect2(global_pos, Vector2.ZERO))
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
				# Double-click to open properties dialog
				_open_node_properties_dialog(node)
				get_viewport().set_input_as_handled()
		)

	_mark_graph_as_dirty()

## Opens a dialog to rename a node.
func _open_rename_node_dialog(node: GraphNode) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Rename Location"
	var line_edit := LineEdit.new()
	line_edit.text = node.title
	dialog.add_child(line_edit)
	if dialog.get_ok_button():
		dialog.get_ok_button().text = "OK"
	dialog.confirmed.connect(func():
		node.title = line_edit.text
		node.set_meta("title", line_edit.text)
		_update_start_node_label()
		_mark_graph_as_dirty()
	)
	add_child(dialog)
	dialog.popup_centered()

## Opens a dialog to edit a node's core properties (ID, Title, Tags).
func _open_node_properties_dialog(node: GraphNode) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Location Properties"
	var vbox_container := VBoxContainer.new()
	vbox_container.custom_minimum_size = Vector2(320, 0)

	# ID (editable in this dialog).
	var id_hbox := HBoxContainer.new()
	id_hbox.add_child(Label.new())
	id_hbox.get_child(0).text = "ID:"
	var id_line_edit := LineEdit.new()
	id_line_edit.text = String(node.get_meta("id"))
	id_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_hbox.add_child(id_line_edit)
	vbox_container.add_child(id_hbox)

	# Title.
	var title_hbox := HBoxContainer.new()
	title_hbox.add_child(Label.new())
	title_hbox.get_child(0).text = "Title:"
	var title_line_edit := LineEdit.new()
	title_line_edit.text = node.get_meta("title") if node.has_meta("title") else node.title
	title_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(title_line_edit)
	vbox_container.add_child(title_hbox)

	# Tags (dynamic fields).
	var tags_vbox := VBoxContainer.new()
	var tags_label := Label.new()
	tags_label.text = "Tags:"
	tags_vbox.add_child(tags_label)

	var tag_line_edits: Array = []
	var existing_tags: Array = node.get_meta("tags") if node.has_meta("tags") else []

	var add_tag_field = func(tag_text: String = ""):
		var hbox := HBoxContainer.new()
		var tag_edit := LineEdit.new()
		tag_edit.text = tag_text
		tag_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(tag_edit)
		var remove_btn := Button.new()
		remove_btn.text = "-"
		remove_btn.tooltip_text = "Remove tag"
		remove_btn.connect("pressed", func():
			tags_vbox.remove_child(hbox)
			tag_line_edits.erase(tag_edit)
		)
		hbox.add_child(remove_btn)
		tag_line_edits.append(tag_edit)
		tags_vbox.add_child(hbox)
		# Enter key triggers Save
		tag_edit.connect("text_submitted", func(_text):
			dialog.get_ok_button().emit_signal("pressed")
		)

	# Add initial tag fields
	if existing_tags.size() > 0:
		for tag in existing_tags:
			add_tag_field.call(tag)
	else:
		add_tag_field.call("")

	# Add button to add new tag field
	var add_tag_btn := Button.new()
	add_tag_btn.text = "+"
	add_tag_btn.tooltip_text = "Add tag"
	add_tag_btn.connect("pressed", func():
		add_tag_field.call("")
	)
	
	vbox_container.add_child(tags_vbox)
	vbox_container.add_child(add_tag_btn)

	# Enter key triggers Save for ID and Title fields
	id_line_edit.connect("text_submitted", func(_text):
		dialog.get_ok_button().emit_signal("pressed")
	)
	title_line_edit.connect("text_submitted", func(_text):
		dialog.get_ok_button().emit_signal("pressed")
	)

	dialog.add_child(vbox_container)
	if dialog.get_ok_button():
		dialog.get_ok_button().text = "Save"

	dialog.confirmed.connect(func():
		var new_id := id_line_edit.text.strip_edges()
		var old_id := String(node.get_meta("id"))
		var was_start_node := active_graph_resource and String(active_graph_resource.start_node_id) == old_id
		if new_id != old_id and new_id != "" and not graph_edit.has_node(new_id):
			# Remap connections and update node name/meta
			var connections := graph_edit.get_connection_list()
			for connection in connections:
				if connection.from_node == old_id:
					graph_edit.disconnect_node(connection.from_node, connection.from_port, connection.to_node, connection.to_port)
					graph_edit.connect_node(new_id, connection.from_port, connection.to_node, connection.to_port)
				elif connection.to_node == old_id:
					graph_edit.disconnect_node(connection.from_node, connection.from_port, connection.to_node, connection.to_port)
					graph_edit.connect_node(connection.from_node, connection.from_port, new_id, connection.to_port)
			_remap_bidirectional_node_id(old_id, new_id)
			_remap_locked_node_id(old_id, new_id)
			node.name = new_id
			node.set_meta("id", StringName(new_id))
			selected_node_ids.clear()
			selected_node_ids.append(new_id)
			# If this node was the start node, update the active resource to point to the new ID
			if was_start_node:
				if active_graph_resource == null:
					active_graph_resource = LocationGraph.new()
				active_graph_resource.start_node_id = StringName(new_id)
		# Update title and tags
		node.title = title_line_edit.text
		node.set_meta("title", title_line_edit.text)
		var cleaned_tags: Array[String] = []
		for tag_edit in tag_line_edits:
			var trimmed_tag: String = String(tag_edit.text.strip_edges())
			if trimmed_tag != "":
				cleaned_tags.append(trimmed_tag)
		node.set_meta("tags", cleaned_tags)
		_update_start_node_label()
		_mark_graph_as_dirty()
	)
	add_child(dialog)
	dialog.popup_centered()

# --- GraphEdit Signal Handlers ---

## Called when the user tries to create a connection.
func _on_connection_request(from_node_id: String, from_port_index: int, to_node_id: String, to_port_index: int) -> void:
	# Prevent connecting a node to itself.
	if from_node_id == to_node_id:
		return
	# Prevent duplicate connections.
	if graph_edit.is_node_connected(from_node_id, from_port_index, to_node_id, to_port_index):
		return

	# Prevent multiple connections to the same output port
	for connection in graph_edit.get_connection_list():
		if connection.from_node == from_node_id and int(connection.from_port) == from_port_index:
			return # Output port already has a connection

	# Prevent multiple connections to the same input port
	for connection in graph_edit.get_connection_list():
		if connection.to_node == to_node_id and int(connection.to_port) == to_port_index:
			return # Input port already has a connection

	graph_edit.connect_node(from_node_id, from_port_index, to_node_id, to_port_index)
	
	# Auto-populate empty labels for convenience.
	var from_node := graph_edit.get_node_or_null(from_node_id)
	var to_node := graph_edit.get_node_or_null(to_node_id)
	if from_node is GraphNode and to_node is GraphNode:
		var out_labels := _get_node_out_port_labels(from_node)
		if from_port_index >= 0 and from_port_index < out_labels.size():
			if String(out_labels[from_port_index]).strip_edges() == "":
				var to_title: String = to_node.get_meta("title") if to_node.has_meta("title") else to_node.title
				out_labels[from_port_index] = "To %s" % to_title
				from_node.set_meta("out_port_labels", out_labels)
				_rebuild_node_ports(from_node)
				
		var in_labels := _get_node_in_port_labels(to_node)
		if to_port_index >= 0 and to_port_index < in_labels.size():
			if String(in_labels[to_port_index]).strip_edges() == "":
				var from_title: String = from_node.get_meta("title") if from_node.has_meta("title") else from_node.title
				in_labels[to_port_index] = "From %s" % from_title
				to_node.set_meta("in_port_labels", in_labels)
				_rebuild_node_ports(to_node)
				
	_mark_graph_as_dirty()
	_refresh_all_connection_activity()

## Called when the user tries to disconnect a connection.
func _on_disconnection_request(from_node_id: String, from_port_index: int, to_node_id: String, to_port_index: int) -> void:
	if graph_edit.is_node_connected(from_node_id, from_port_index, to_node_id, to_port_index):
		# Ensure the bidirectional, locked, and hidden flags are cleared on disconnect.
		_set_connection_bidirectional(from_node_id, from_port_index, to_node_id, to_port_index, false)
		_set_connection_locked(from_node_id, from_port_index, to_node_id, to_port_index, false)
		_set_connection_hidden(from_node_id, from_port_index, to_node_id, to_port_index, false)
		graph_edit.disconnect_node(from_node_id, from_port_index, to_node_id, to_port_index)
		_mark_graph_as_dirty()
	_refresh_all_connection_activity()

## Called when a node is selected in the GraphEdit.
func _on_graph_node_selected(node: Node) -> void:
	var node_id := String(node.name)
	if not selected_node_ids.has(node_id):
		selected_node_ids.append(node_id)
	_update_start_node_label()
	_push_selection_to_inspector()

## Called when a node is deselected.
func _on_graph_node_deselected(node: Node) -> void:
	var node_id := String(node.name)
	selected_node_ids.erase(node_id)
	_update_start_node_label()
	_push_selection_to_inspector()

## Called when the user requests to delete nodes (e.g., by pressing Delete).
func _on_delete_nodes_request(_node_ids: Array = []) -> void:
	for node_id in selected_node_ids.duplicate():
		var node := graph_edit.get_node_or_null(node_id)
		if node:
			_purge_bidirectional_flags_for_node(String(node_id))
			_purge_locked_flags_for_node(String(node_id))
			_purge_hidden_flags_for_node(String(node_id))
			node.queue_free()
	selected_node_ids.clear()
	_mark_graph_as_dirty()

## Handles the "Delete" button press.
func _on_delete_selection_pressed() -> void:
	_on_delete_nodes_request()

## Handles double-click input on the graph background (currently disabled).
func _on_graph_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# Right-click on empty background -> show context menu to add node.
		# This only triggers if a child GraphNode hasn't already handled the event.
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Check if we right-clicked on a connection line using the built-in method
			var connection_under_mouse := graph_edit.get_closest_connection_at_point(event.position)
			if not connection_under_mouse.is_empty():
				_show_connection_context_menu(connection_under_mouse, event.global_position)
				get_viewport().set_input_as_handled()
				return
			
			# Otherwise show the add node context menu
			var menu := PopupMenu.new()
			menu.add_item("Add Node", 0)
			menu.connect("id_pressed", func(id):
				if id == 0:
					_create_graph_node(graph_edit.get_local_mouse_position())
				menu.queue_free()
			)
			add_child(menu)
			menu.popup(Rect2(event.global_position, Vector2.ZERO))
			get_viewport().set_input_as_handled()

## Shows a context menu for connection operations
func _show_connection_context_menu(connection: Dictionary, global_position: Vector2) -> void:
	var from_node_id := String(connection.from_node)
	var from_port := int(connection.from_port)
	var to_node_id := String(connection.to_node)
	var to_port := int(connection.to_port)
	
	var is_locked := _is_connection_locked(from_node_id, from_port, to_node_id, to_port)
	var is_hidden := _is_connection_hidden(from_node_id, from_port, to_node_id, to_port)
	var current_weight := _get_connection_weight(from_node_id, from_port, to_node_id, to_port)
	
	# Format weight display - show integer if whole number, otherwise 2 decimal places
	var weight_display: String
	if is_equal_approx(current_weight, round(current_weight)):
		weight_display = "%d" % int(round(current_weight))
	else:
		weight_display = "%.2f" % current_weight
	
	var menu := PopupMenu.new()
	menu.add_check_item("Lock Connection", 0)
	menu.set_item_checked(0, is_locked)
	menu.add_check_item("Hide Connection", 1)
	menu.set_item_checked(1, is_hidden)
	menu.add_separator()
	menu.add_item("Set Weight... (%s)" % weight_display, 2)
	
	menu.connect("id_pressed", func(id):
		if id == 0:
			# Toggle locked state
			_set_connection_locked(from_node_id, from_port, to_node_id, to_port, not is_locked)
			_mark_graph_as_dirty()
			_refresh_all_connection_activity()
		elif id == 1:
			# Toggle hidden state
			_set_connection_hidden(from_node_id, from_port, to_node_id, to_port, not is_hidden)
			_mark_graph_as_dirty()
			_refresh_all_connection_activity()
		elif id == 2:
			# Open weight edit dialog
			_open_weight_edit_dialog(from_node_id, from_port, to_node_id, to_port, current_weight)
		menu.queue_free()
	)
	
	add_child(menu)
	menu.popup(Rect2(global_position, Vector2.ZERO))


## Opens a dialog to edit the weight of a connection.
func _open_weight_edit_dialog(from_node_id: String, from_port: int, to_node_id: String, to_port: int, current_weight: float) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Set Connection Weight"
	dialog.min_size = Vector2(300, 0)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	var label := Label.new()
	label.text = "Weight (travel time/cost):"
	vbox.add_child(label)
	
	var spin_box := SpinBox.new()
	spin_box.min_value = 0.0
	spin_box.max_value = 9999.0
	spin_box.step = 0.01
	spin_box.value = current_weight
	spin_box.allow_greater = true
	spin_box.select_all_on_focus = true
	vbox.add_child(spin_box)
	
	var hint_label := Label.new()
	hint_label.text = "Default weight is 1.0"
	hint_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(hint_label)
	
	dialog.add_child(vbox)
	
	dialog.connect("confirmed", func():
		# Round to 2 decimal places to avoid floating point precision issues
		var new_weight := snappedf(spin_box.value, 0.01)
		_set_connection_weight(from_node_id, from_port, to_node_id, to_port, new_weight)
		_mark_graph_as_dirty()
		dialog.queue_free()
	)
	
	dialog.connect("canceled", func():
		dialog.queue_free()
	)
	
	add_child(dialog)
	dialog.popup_centered()

# --- Save & Load ---

## Loads a LocationGraph resource from a given file path.
func _load_graph_from_path(path: String) -> void:
	var resource := ResourceLoader.load(path)
	if resource == null:
		push_error("Failed to load LocationGraph resource from: %s" % path)
		return
	if resource is LocationGraph:
		active_graph_resource = resource as LocationGraph
		active_graph_path = path
		_populate_graph_from_resource(resource)
		_update_start_node_label()
		_update_file_label()
		is_graph_dirty = false
		_update_dirty_label()

## Populates the GraphEdit canvas from a loaded LocationGraph resource.
func _populate_graph_from_resource(resource: LocationGraph) -> void:
	_clear_graph_canvas()
	node_id_counter = 1
	# When populating from a resource, suppress the auto-start assignment done by _create_graph_node
	_suppress_auto_start_assignment = true
	
	# Create all nodes from the resource data.
	for node_data in resource.nodes:
		var typed_node_data: LocationNodeData = node_data as LocationNodeData
		var position: Vector2 = typed_node_data.position
		var id: StringName = typed_node_data.id
		var title := typed_node_data.title
		_create_graph_node(position, id, title)
		
		var graph_node := graph_edit.get_node_or_null(String(id))
		if graph_node is GraphNode:
			graph_node.set_meta("tags", typed_node_data.tags)
			if typed_node_data.size != Vector2.ZERO:
				graph_node.custom_minimum_size = typed_node_data.size
			graph_node.set_meta("out_port_labels", typed_node_data.out_port_labels if not typed_node_data.out_port_labels.is_empty() else [""])
			graph_node.set_meta("in_port_labels", typed_node_data.in_port_labels if not typed_node_data.in_port_labels.is_empty() else [""])
			_rebuild_node_ports(graph_node)
			
		# Keep the ID counter ahead of any loaded numeric IDs.
		var id_str := String(id)
		if id_str.begins_with("loc_"):
			var num_part := id_str.trim_prefix("loc_")
			if num_part.is_valid_int():
				node_id_counter = max(node_id_counter, int(num_part) + 1)
				
	# Create all edges from the resource data.
	for edge_data in resource.edges:
		if graph_edit.has_node(String(edge_data.from_id)) and graph_edit.has_node(String(edge_data.to_id)):
			graph_edit.connect_node(String(edge_data.from_id), int(edge_data.from_port), String(edge_data.to_id), int(edge_data.to_port))
			if edge_data.bidirectional:
				_set_connection_bidirectional(String(edge_data.from_id), int(edge_data.from_port), String(edge_data.to_id), int(edge_data.to_port), true)
			if edge_data.locked:
				_set_connection_locked(String(edge_data.from_id), int(edge_data.from_port), String(edge_data.to_id), int(edge_data.to_port), true)
			if "hidden" in edge_data and edge_data.hidden:
				_set_connection_hidden(String(edge_data.from_id), int(edge_data.from_port), String(edge_data.to_id), int(edge_data.to_port), true)
			if "weight" in edge_data and not is_equal_approx(edge_data.weight, 1.0):
				_set_connection_weight(String(edge_data.from_id), int(edge_data.from_port), String(edge_data.to_id), int(edge_data.to_port), edge_data.weight)
				
	_refresh_all_connection_activity()
	_refresh_all_port_colors()

	# Restore the start_node_id from the resource (if any) and re-enable auto-assignment
	if resource and String(resource.start_node_id) != "":
		if active_graph_resource == null:
			active_graph_resource = LocationGraph.new()
		active_graph_resource.start_node_id = resource.start_node_id

	_suppress_auto_start_assignment = false

## Handles the "Save" button press.
func _on_save_graph_pressed() -> void:
	if active_graph_path == "":
		_on_save_as_graph_pressed()
		return
	var built_resource := _build_resource_from_graph()
	var error: int = ResourceSaver.save(built_resource, active_graph_path)
	if error == OK:
		active_graph_resource = built_resource
		is_graph_dirty = false
		_update_dirty_label()
		_update_file_label()
		_update_start_node_label()

## Handles the "Save As" button press.
func _on_save_as_graph_pressed() -> void:
	var file_dialog := EditorFileDialog.new()
	add_child(file_dialog)
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	file_dialog.add_filter("*.tres ; LocationGraph")
	file_dialog.title = "Save Location Graph"
	file_dialog.file_selected.connect(func(path):
		var target_path: String = path
		if not target_path.ends_with(".tres"):
			target_path += ".tres"
		var built_resource := _build_resource_from_graph()
		var error: int = ResourceSaver.save(built_resource, target_path)
		if error == OK:
			active_graph_resource = built_resource
			active_graph_path = target_path
			is_graph_dirty = false
			_update_dirty_label()
			_update_file_label()
			_update_start_node_label()
	)
	file_dialog.popup_centered_ratio(0.6)

## Handles the "Reload" button press.
func _on_reload_graph_pressed() -> void:
	if active_graph_path == "":
		return
	_load_graph_from_path(active_graph_path)

# --- UI State Updaters ---

## Handles the "Set Start" button press.
func _on_set_start_node_pressed() -> void:
	if selected_node_ids.size() == 1:
		var id: String = selected_node_ids[0]
		if active_graph_resource == null:
			active_graph_resource = LocationGraph.new()
		active_graph_resource.start_node_id = StringName(id)
		_update_start_node_label()
		_mark_graph_as_dirty()
	elif selected_node_ids.is_empty():
		# Fallback for some Godot versions where selection signal might not be reliable.
		if "get_selected_nodes" in graph_edit:
			var selected_nodes_array: Array = graph_edit.get_selected_nodes()
			if selected_nodes_array.size() == 1:
				var node_id := String(selected_nodes_array[0])
				if active_graph_resource == null:
					active_graph_resource = LocationGraph.new()
				active_graph_resource.start_node_id = StringName(node_id)
				_update_start_node_label()
				_mark_graph_as_dirty()

## Updates the label showing the current start node.
func _update_start_node_label() -> void:
	var text := "Start: "
	if active_graph_resource and String(active_graph_resource.start_node_id) != "":
		var start_node_id := String(active_graph_resource.start_node_id)
		var title := start_node_id
		if graph_edit.has_node(start_node_id):
			var graph_node := graph_edit.get_node(start_node_id)
			if graph_node is GraphNode:
				title = graph_node.get_meta("title") if graph_node.has_meta("title") else graph_node.title
		text += "%s (%s)" % [start_node_id, title]
	else:
		text += "-"
	start_node_label.text = text

## Sets the dirty flag and updates the UI to show it.
func _mark_graph_as_dirty() -> void:
	is_graph_dirty = true
	_update_dirty_label()

## Shows or hides the "*" dirty indicator in the toolbar.
func _update_dirty_label() -> void:
	if is_instance_valid(dirty_label):
		dirty_label.visible = is_graph_dirty

## Updates the label showing the current file name.
func _update_file_label() -> void:
	var file_name := "-"
	if active_graph_path != "":
		file_name = String(active_graph_path).get_file()
	if is_instance_valid(file_label):
		file_label.text = "File: %s" % file_name
