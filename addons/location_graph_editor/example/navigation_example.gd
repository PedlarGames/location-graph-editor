# This script provides a simple example of how to navigate a LocationGraph.
# It allows loading a LocationGraph resource, displays the current location,
# and provides buttons to move to connected locations.
extends Control

# Preload the required custom resource types for type safety and efficiency.
const LocationGraph = preload("res://addons/location_graph_editor/resources/location_graph.gd")
const LocationNodeData = preload("res://addons/location_graph_editor/resources/location_node.gd")
const LocationEdgeData = preload("res://addons/location_graph_editor/resources/location_edge.gd")
const LocationGraphRuntime = preload("res://addons/location_graph_editor/runtime/location_graph_runtime.gd")

# --- UI Elements ---
# We use @onready to ensure the nodes are available when we access them.
@onready var load_graph_button: Button = %LoadGraphDataButton
@onready var loaded_graph_name_label: Label = %LoadedGraphNameLabel
@onready var current_location_label: Label = %CurrentLocationValueLabel
@onready var exits_vbox: VBoxContainer = %ExitsContainer
@onready var return_to_start_button: Button = %ReturnButton
@onready var all_locations_vbox: VBoxContainer = %AllLocationsContainer
@onready var path_from_location_input: LineEdit = %PathFromLocationInput
@onready var path_to_location_input: LineEdit = %PathToLocationInput
@onready var find_path_button: Button = %FindPathButton
@onready var route_list_label: Label = %RouteListLabel

# --- Navigation State ---
# The loaded LocationGraph resource.
var location_graph: LocationGraph
var runtime: LocationGraphRuntime = LocationGraphRuntime.new()
# The ID of the location the player is currently at.
var current_location_id: String = ""


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Connect UI signals to their respective handler functions.
	load_graph_button.pressed.connect(_on_load_graph_button_pressed)
	return_to_start_button.pressed.connect(_on_return_to_start_button_pressed)
	find_path_button.pressed.connect(_on_find_path_button_pressed)
	# Initialize the UI with default values.
	_update_ui()


# --- Signal Handlers ---

# Called when the "Load Graph" button is pressed.
# Opens a FileDialog to allow the user to select a LocationGraph resource file (*.tres).
func _on_load_graph_button_pressed() -> void:
	var file_dialog := FileDialog.new()
	add_child(file_dialog)
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.add_filter("*.tres ; LocationGraph")
	file_dialog.title = "Load Location Graph"
	# Connect to the file_selected signal and load the graph when a file is chosen.
	file_dialog.file_selected.connect(func(path: String):
		_load_graph_from_path(path)
	)
	# Show the dialog.
	file_dialog.popup_centered_ratio(0.6)


# Called when the "Return to Start" button is pressed.
# Resets the current location to the graph's defined start node.
func _on_return_to_start_button_pressed() -> void:
	if location_graph == null:
		return

	# Determine the start node ID using the runtime helper.
	if runtime and runtime.location_graph == location_graph:
		current_location_id = runtime.get_start_or_first_id()
	else:
		runtime.set_graph(location_graph)
		current_location_id = runtime.get_start_or_first_id()
	_update_ui()


# --- Private Logic ---

# Loads a LocationGraph resource from the given file path.
func _load_graph_from_path(path: String) -> void:
	var resource := ResourceLoader.load(path)
	if resource == null or not (resource is LocationGraph):
		loaded_graph_name_label.text = "Failed to load graph."
		return
	
	location_graph = resource as LocationGraph
	runtime.set_graph(location_graph)
	loaded_graph_name_label.text = String(path.get_file())
	
	# Set the current location to the graph's start node or fallback to first via runtime.
	current_location_id = runtime.get_start_or_first_id()
			
	# Refresh the UI to reflect the newly loaded graph.
	_update_ui()


# Updates all UI elements to reflect the current navigation state.
func _update_ui() -> void:
	_update_current_location_label()
	_rebuild_exit_buttons()
	_rebuild_all_locations_list()


# Updates the label showing the current location's ID and title.
func _update_current_location_label() -> void:
	if location_graph == null or current_location_id == "":
		current_location_label.text = "No location set"
		return
		
	var current_node_data := _get_node_by_id(current_location_id)
	if current_node_data:
		# Display both the ID and the custom title for clarity.
		current_location_label.text = "%s (%s)" % [String(current_node_data.id), String(current_node_data.title)]
	else:
		# If the node data can't be found, just show the ID.
		current_location_label.text = current_location_id


# Clears and rebuilds the list of buttons for navigating to adjacent locations.
func _rebuild_exit_buttons() -> void:
	# First, remove any previously generated exit buttons.
	# We iterate through the children of the container and free them.
	for child in exits_vbox.get_children():
		# We only want to remove the dynamically generated exit buttons.
		if child is Button and child != return_to_start_button and String(child.name).begins_with("ExitButton_"):
			exits_vbox.remove_child(child)
			child.queue_free()

	if location_graph == null or current_location_id == "":
		return

	var current_node := runtime.get_location_node(current_location_id)
	if current_node == null:
		return

	var button_index: int = 0
	
	# --- Create buttons for outgoing edges ---
	for edge in runtime.get_edges_from(current_location_id):
		var destination_node_id := String(edge.to_id)
		var destination_node := runtime.get_location_node(destination_node_id)
		# Determine the button's text. Use the port label if available, otherwise generate a default.
		var button_text := runtime.get_out_port_label(current_location_id, int(edge.from_port))
		if button_text.strip_edges() == "":
			var destination_title := destination_node_id if destination_node == null else String(destination_node.title)
			button_text = "To %s" % destination_title

		# Create and configure the button.
		var exit_button := Button.new()
		exit_button.name = "ExitButton_%d_%s" % [button_index, destination_node_id]
		exit_button.text = button_text
		exit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		exit_button.pressed.connect(func():
			current_location_id = destination_node_id
			_update_ui()
		)
		
		# Insert the new button before the "Return to Start" button for a consistent layout.
		exits_vbox.add_child(exit_button)
		var return_button_index: int = return_to_start_button.get_index()
		if return_button_index >= 0:
			exits_vbox.move_child(exit_button, return_button_index)
			
		button_index += 1

	# --- Create buttons for incoming bidirectional edges (allowing reverse travel) ---
	# Use edges lookup for incoming bidirectional edges by scanning all edges and
	# selecting those that are bidirectional and target the current location.
	for edge in runtime.get_edges_to(current_location_id):
		# edge is a LocationEdgeData that targets current_location_id
		if not edge.bidirectional:
			continue
		var source_node_id := String(edge.from_id)
		var source_node := runtime.get_location_node(source_node_id)
		var reverse_navigation_label := runtime.get_in_port_label(current_location_id, int(edge.to_port))
		if reverse_navigation_label.strip_edges() == "":
			var source_title := source_node_id if source_node == null else String(source_node.title)
			reverse_navigation_label = "From %s" % source_title
		var reverse_exit_button := Button.new()
		reverse_exit_button.name = "ExitButton_%d_%s_rev" % [button_index, source_node_id]
		reverse_exit_button.text = reverse_navigation_label
		reverse_exit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reverse_exit_button.pressed.connect(func():
			current_location_id = source_node_id
			_update_ui()
		)
		exits_vbox.add_child(reverse_exit_button)
		var return_button_index: int = return_to_start_button.get_index()
		if return_button_index >= 0:
			exits_vbox.move_child(reverse_exit_button, return_button_index)
		button_index += 1

# Rebuilds the list of all locations in the graph for reference.
func _rebuild_all_locations_list() -> void:
	# Clear existing entries.
	for child in all_locations_vbox.get_children():
		if child is Label and String(child.name).begins_with("LocationLabel_"):
			all_locations_vbox.remove_child(child)
			child.queue_free()
	if location_graph == null:
		return
	# Create a label for each location node in the graph.
	var label_index: int = 0
	for node in location_graph.nodes:
		var location_node: LocationNodeData = node
		var location_label := Label.new()
		location_label.name = "LocationLabel_%d_%s" % [label_index, String(location_node.id)]
		location_label.text = "%s (%s)" % [String(location_node.id), String(location_node.title)]
		location_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		all_locations_vbox.add_child(location_label)
		label_index += 1

# Called when the "Find Path" button is pressed.
# Finds and displays a path between two specified locations.
func _on_find_path_button_pressed() -> void:
	route_list_label.text = ""
	if location_graph == null:
		route_list_label.text = "No graph loaded."
		return
	var from_id := path_from_location_input.text.strip_edges()
	var to_id := path_to_location_input.text.strip_edges()
	if from_id == "" or to_id == "":
		route_list_label.text = "Please enter both From and To location IDs."
		return
	if _get_node_by_id(from_id) == null:
		route_list_label.text = "From location ID not found: %s" % from_id
		return
	if _get_node_by_id(to_id) == null:
		route_list_label.text = "To location ID not found: %s" % to_id
		return
	# Use bfs from location_graph_runtime.gd to find the path.
	var path: Array[String] = runtime.find_path_bfs(from_id, to_id) as Array[String]
	if path.size() == 0:
		route_list_label.text = "No path found from %s to %s." % [from_id, to_id]
		return
	# Display the found path.
	route_list_label.text = "Path: " + " -> ".join(path)
	route_list_label.show()


# --- Helper Functions ---

# Finds and returns a LocationNodeData from the graph by its ID.
# Returns null if the graph is not loaded or the node is not found.
func _get_node_by_id(id: String) -> LocationNodeData:
	return runtime.get_location_node(id)


# Retrieves the label for a specific outgoing port on a node.
func _get_outgoing_port_label(node: LocationNodeData, port_index: int) -> String:
	return runtime.get_out_port_label(String(node.id), port_index)


# Retrieves the label for a specific incoming port on a node.
func _get_incoming_port_label(node: LocationNodeData, port_index: int) -> String:
	return runtime.get_in_port_label(String(node.id), port_index)
